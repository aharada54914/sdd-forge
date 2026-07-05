/**
 * AC-006 (TEST-006): src/ must never call a filesystem write API, must never
 * use `child_process.exec` / `execSync`, must never `spawn` with `shell: true`,
 * and must never use `eval`. Only `execFile` (no shell) is permitted for
 * process launching. This walks every .ts file under src/ and asserts none of
 * the denylisted patterns appear in executable code (comments stripped).
 *
 * Enforced by source-text inspection (no fs write side effects in this test).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Walks upward from this test file's compiled location until it finds the
 * package root (identified by package.json) so the check works regardless
 * of whether it runs from tests/ or dist-test/tests/.
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

/**
 * child_process / eval APIs that must never be *used* in src/. Only `execFile`
 * (and `execFileSync`) — which never spawn a shell — are permitted. `exec`,
 * `execSync`, `spawn`, `spawnSync`, `fork`, and `eval` are forbidden.
 *
 * Each is matched only in call / import / destructure position (e.g. `spawn(`,
 * `{ spawn }`, `child_process.spawn`) so that unrelated string content such as
 * the contract `"spawn-error"` probeError literal is not a false positive.
 */
const DENYLISTED_EXEC_APIS = [
  "execSync",
  "spawn",
  "spawnSync",
  "fork",
  "eval",
];

/**
 * Builds a regex that matches `api` only when it is invoked, imported, or
 * accessed as a member — i.e. followed by `(`, or preceded by `.`, or appearing
 * inside `{ ... }` import/destructure braces — never as part of a longer
 * hyphenated identifier or string like `spawn-error`.
 */
function usagePattern(api: string): RegExp {
  return new RegExp(
    // member access:  .spawn        call:  spawn(          import/destructure: { spawn }
    `(?:\\.${api}\\b|\\b${api}\\s*\\(|[{,]\\s*${api}\\s*[},])`,
  );
}

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
 * Strips `//` line comments and block comments (including JSDoc) from
 * TypeScript source so the API checks only inspect executable code, not prose
 * that discusses these concepts.
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
      const pattern = new RegExp(`\\b${apiName}\\b`);
      if (pattern.test(code)) {
        violations.push(`${relative(SRC_DIR, file)}: found "${apiName}"`);
      }
    }
  }

  assert.deepEqual(violations, [], `write API usage found in src/:\n${violations.join("\n")}`);
});

test("src/ uses no child_process.exec / spawn / fork / eval (execFile only)", () => {
  const files = listTsFiles(SRC_DIR);
  assert.ok(files.length > 0, "expected at least one .ts file under src/");

  const violations: string[] = [];
  for (const file of files) {
    const code = stripComments(readFileSync(file, "utf-8"));
    // Match the exec APIs only in usage position (call / member / import), so
    // that string literals like the `"spawn-error"` probeError value are not
    // flagged. `execFile` / `execFileSync` are never matched by these.
    for (const apiName of DENYLISTED_EXEC_APIS) {
      if (usagePattern(apiName).test(code)) {
        violations.push(`${relative(SRC_DIR, file)}: found "${apiName}" usage`);
      }
    }
    // Forbid a bare `exec` call/import/member that is NOT `execFile`. Negative
    // lookahead lets `execFile` / `execFileSync` through while catching
    // `exec(`, `.exec`, and `{ exec }`.
    if (/(?:\.exec(?!File)\b|\bexec(?!File)\s*\(|[{,]\s*exec\s*[},])/.test(code)) {
      violations.push(`${relative(SRC_DIR, file)}: found bare "exec" usage (only execFile permitted)`);
    }
    // Forbid `shell: true` anywhere (defense in depth even though spawn is
    // already denylisted).
    if (/shell\s*:\s*true/.test(code)) {
      violations.push(`${relative(SRC_DIR, file)}: found "shell: true"`);
    }
  }

  assert.deepEqual(violations, [], `exec/eval API usage found in src/:\n${violations.join("\n")}`);
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
