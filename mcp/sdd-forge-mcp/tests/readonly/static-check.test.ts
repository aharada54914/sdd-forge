/**
 * AC-011 (static part): src/ must never call a filesystem write API. This
 * walks every .ts file under src/ and asserts none of the denylisted API
 * names appear as a `fs.<name>` / destructured `<name>(` call. Enforced by
 * source-text inspection (no fs write side effects in this test itself).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Walks upward from this test file's compiled location until it finds the
 * package root (identified by package.json) so the check works regardless
 * of whether it runs from tests/ (tsx) or dist-test/tests/ (tsc output).
 */
function findPackageRoot(startDir: string): string {
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
const SRC_DIR = join(findPackageRoot(THIS_FILE_DIR), "src");

/**
 * fs write / mutate API names that must never appear in src/. Read-only APIs
 * (readFileSync, existsSync, statSync, realpathSync, readdirSync) are
 * intentionally excluded.
 */
const DENYLISTED_FS_APIS = [
  "writeFile",
  "writeFileSync",
  "appendFile",
  "appendFileSync",
  "mkdir",
  "mkdirSync",
  "rm",
  "rmSync",
  "rmdir",
  "rmdirSync",
  "unlink",
  "unlinkSync",
  "rename",
  "renameSync",
  "chmod",
  "chmodSync",
  "chown",
  "chownSync",
  "truncate",
  "truncateSync",
  "symlink",
  "symlinkSync",
  "link",
  "linkSync",
  "copyFile",
  "copyFileSync",
  "createWriteStream",
  "utimes",
  "utimesSync",
  "open",
  "openSync",
  "writev",
  "writevSync",
];

function listTsFiles(dir: string): string[] {
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
 * Strips `//` line comments and `/* *\/` block comments (including JSDoc)
 * from TypeScript source so the write-API check only inspects executable
 * code, not prose that merely discusses filesystem concepts (e.g. a comment
 * explaining symlink resolution should not trip a check for `symlinkSync`).
 * This is a best-effort stripper (no string/template-literal awareness), but
 * sdd-forge-mcp source has no string content that resembles a comment
 * delimiter, so it is sufficient here.
 */
function stripComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "");
}

test("src/ contains no filesystem write API references", () => {
  const files = listTsFiles(SRC_DIR);
  assert.ok(files.length > 0, "expected at least one .ts file under src/");

  const violations: string[] = [];
  for (const file of files) {
    const code = stripComments(readFileSync(file, "utf-8"));
    for (const apiName of DENYLISTED_FS_APIS) {
      // Match the API as a whole identifier (word boundary) to avoid
      // false positives from unrelated identifiers that merely contain the
      // substring.
      const pattern = new RegExp(`\\b${apiName}\\b`);
      if (pattern.test(code)) {
        violations.push(`${relative(SRC_DIR, file)}: found "${apiName}"`);
      }
    }
  }

  assert.deepEqual(violations, [], `write API usage found in src/:\n${violations.join("\n")}`);
});

test("src/ contains no TODO/FIXME/stub/placeholder markers", () => {
  const files = listTsFiles(SRC_DIR);
  const markerPattern = /\b(TODO|FIXME|stub|placeholder)\b/i;
  const violations: string[] = [];
  for (const file of files) {
    const contents = readFileSync(file, "utf-8");
    if (markerPattern.test(contents)) {
      violations.push(relative(SRC_DIR, file));
    }
  }
  assert.deepEqual(violations, [], `placeholder markers found in: ${violations.join(", ")}`);
});
