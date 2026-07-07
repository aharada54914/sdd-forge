/**
 * Shared static-source-scanning helpers for T-006's write-boundary tests
 * (tests/readonly/static-check.test.ts). Walks the REAL (uncompiled) src/
 * tree — not the dist-test compiled output — so the checks inspect the
 * actual TypeScript source text, mirroring
 * mcp/local-env-mcp/tests/readonly/static-check.test.ts's approach.
 */

import { existsSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Walks upward from `startDir` until it finds the package root (identified
 * by package.json), so the check works regardless of whether it runs from
 * tests/ or dist-test/tests/.
 */
export function findPackageRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 10; i += 1) {
    if (existsSync(join(dir, "package.json"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate package root above ${startDir}`);
}

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));
export const PACKAGE_ROOT = findPackageRoot(THIS_FILE_DIR);
export const SRC_DIR = join(PACKAGE_ROOT, "src");

/** Recursively lists every `.ts` file under `dir`. */
export function listTsFiles(dir: string): string[] {
  const entries = readdirSync(dir);
  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = join(dir, entry);
    const stats = statSync(fullPath);
    if (stats.isDirectory()) {
      files.push(...listTsFiles(fullPath));
    } else if (entry.endsWith(".ts")) {
      files.push(fullPath);
    }
  }
  return files;
}

/**
 * Strips `//` line comments and block comments (including JSDoc) from
 * TypeScript source so the static checks only inspect executable code, not
 * prose that discusses these concepts (e.g. this very module's doc
 * comments, or github-client.ts's module doc mentioning "POST/PUT/PATCH/
 * DELETE").
 *
 * This is a small string-aware scanner, NOT a pair of naive
 * `/\/\*...\*\//` / `/\/\/.*$/` regexes. Naive regexes are not aware of
 * string/template-literal boundaries, which creates two classes of false
 * negative in the static checks that consume this output (T-006 evaluator
 * finding, Cycle 2):
 *
 *   1. A rogue string literal such as `"http://attacker.example.com/x"`
 *      contains a `//` that a naive line-comment regex treats as a comment
 *      start, truncating the literal to `"http:` and hiding the host from
 *      the SSRF host-fixing check (security-spec.md B2).
 *   2. Any `//` inside a string literal truncates the *rest of that
 *      physical line* as if it were a trailing comment, hiding whatever
 *      code follows on the same line (e.g. a `writeFileSync(...)` call
 *      after `const u = "sc://y";`) from the fs-write / child_process /
 *      eval checks.
 *
 * The scanner below walks the source one character at a time, tracking
 * whether it is inside a single-quoted string, a double-quoted string, a
 * template literal, a line comment, or a block comment (honoring `\`
 * escapes in the first three states), and strips characters only while in
 * one of the two comment states. String and template-literal contents
 * (including a `${...}` substitution's own `//`/`/* * /`-shaped text, which
 * is left untouched rather than precisely re-parsed as nested code — an
 * intentional, documented approximation) are copied through verbatim, so
 * the checks downstream see the real, unmodified string/host literals.
 */
type ScanState =
  | "normal"
  | "single-quote"
  | "double-quote"
  | "template-literal"
  | "line-comment"
  | "block-comment";

export function stripComments(source: string): string {
  let state: ScanState = "normal";
  let out = "";
  let i = 0;
  const n = source.length;

  while (i < n) {
    const ch = source[i];
    const next = i + 1 < n ? source[i + 1] : "";

    if (state === "single-quote" || state === "double-quote" || state === "template-literal") {
      const closingChar = state === "single-quote" ? "'" : state === "double-quote" ? '"' : "`";
      if (ch === "\\") {
        // Preserve the escape sequence verbatim; do not interpret `next`.
        out += ch + next;
        i += 2;
        continue;
      }
      if (ch === closingChar) {
        state = "normal";
      }
      out += ch;
      i += 1;
      continue;
    }

    if (state === "line-comment") {
      if (ch === "\n") {
        state = "normal";
        out += ch;
      }
      i += 1;
      continue;
    }

    if (state === "block-comment") {
      if (ch === "*" && next === "/") {
        state = "normal";
        i += 2;
        continue;
      }
      i += 1;
      continue;
    }

    // state === "normal"
    if (ch === "/" && next === "/") {
      state = "line-comment";
      i += 2;
      continue;
    }
    if (ch === "/" && next === "*") {
      state = "block-comment";
      i += 2;
      continue;
    }
    if (ch === "'") {
      state = "single-quote";
      out += ch;
      i += 1;
      continue;
    }
    if (ch === '"') {
      state = "double-quote";
      out += ch;
      i += 1;
      continue;
    }
    if (ch === "`") {
      state = "template-literal";
      out += ch;
      i += 1;
      continue;
    }
    out += ch;
    i += 1;
  }

  return out;
}
