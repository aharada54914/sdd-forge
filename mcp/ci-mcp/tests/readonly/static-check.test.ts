/**
 * AC-007 (TEST-007): static enforcement of ci-mcp's read-only write boundary
 * (REQ-001, REQ-003; security-spec.md B1/B2). Walks every REAL (uncompiled)
 * src/**\/*.ts file with comments stripped and asserts, across the whole
 * tree:
 *
 *   - zero filesystem write API references (writeFile/appendFile/mkdir/rm/
 *     etc. and their Sync variants)
 *   - zero `child_process` usage IN ANY FORM — exec/execSync/execFile/
 *     execFileSync/spawn/spawnSync/fork, and no import of the
 *     `child_process` module at all. Unlike local-env-mcp (which permits
 *     `execFile` for its own process-launching needs), ci-mcp's design.md
 *     "Non-goal" bans process-spawning outright: repo-resolve.ts must never
 *     exec to read a git remote, and no other module has any legitimate
 *     reason to spawn a process.
 *   - zero `eval` usage
 *   - zero write-method HTTP literals (POST/PUT/PATCH/DELETE) anywhere
 *   - the only `fetch(` call sites in the whole tree are in
 *     github-client.ts, and every `method:` value that appears in that file
 *     is the literal "GET"
 *   - the only scheme://host literal present anywhere in src/ is the fixed
 *     GitHub API base URL (`https://api.github.com`) — no other host is
 *     ever reachable (SSRF host-fixing, security-spec.md B2)
 *
 * This mirrors mcp/local-env-mcp/tests/readonly/static-check.test.ts's
 * source-text-inspection approach, adapted to ci-mcp's stricter (no
 * execFile exception) write boundary and its GET-only/host-fixed HTTP
 * requirement.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { relative } from "node:path";

import { SRC_DIR, listTsFiles, stripComments } from "./support/source-scan.js";

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
 * ALL child_process process-spawning APIs are banned for ci-mcp (no
 * execFile exception, unlike local-env-mcp) — see module doc comment.
 */
const DENYLISTED_CHILD_PROCESS_APIS = [
  "execFileSync",
  "execFile",
  "execSync",
  "exec",
  "spawnSync",
  "spawn",
  "fork",
];

const CHILD_PROCESS_IMPORT_PATTERN =
  /from\s+["'](?:node:)?child_process["']|require\(\s*["'](?:node:)?child_process["']\s*\)/;

/**
 * Builds a regex that matches `api` only when it is invoked, imported, or
 * accessed as a member — never as part of a longer identifier or an
 * unrelated string literal.
 */
function usagePattern(api: string): RegExp {
  return new RegExp(`(?:\\.${api}\\b|\\b${api}\\s*\\(|[{,]\\s*${api}\\s*[},])`);
}

const GITHUB_CLIENT_FILE = "github-client.ts";
const FIXED_GITHUB_API_BASE_URL = "https://api.github.com";

function allSourceFiles(): { file: string; relPath: string; code: string }[] {
  return listTsFiles(SRC_DIR).map((file) => ({
    file,
    relPath: relative(SRC_DIR, file),
    code: stripComments(readFileSync(file, "utf-8")),
  }));
}

test("src/ contains no filesystem write API references", () => {
  const violations: string[] = [];
  for (const { relPath, code } of allSourceFiles()) {
    for (const apiName of DENYLISTED_FS_APIS) {
      if (new RegExp(`\\b${apiName}\\b`).test(code)) {
        violations.push(`${relPath}: found "${apiName}"`);
      }
    }
  }
  assert.deepEqual(violations, [], `write API usage found in src/:\n${violations.join("\n")}`);
});

test("src/ contains no child_process usage in any form (no execFile exception)", () => {
  const violations: string[] = [];
  for (const { relPath, code } of allSourceFiles()) {
    if (CHILD_PROCESS_IMPORT_PATTERN.test(code)) {
      violations.push(`${relPath}: imports node:child_process`);
    }
    for (const apiName of DENYLISTED_CHILD_PROCESS_APIS) {
      if (usagePattern(apiName).test(code)) {
        violations.push(`${relPath}: found "${apiName}" usage`);
      }
    }
  }
  assert.deepEqual(violations, [], `child_process usage found in src/:\n${violations.join("\n")}`);
});

test("src/ contains no eval usage", () => {
  const violations: string[] = [];
  for (const { relPath, code } of allSourceFiles()) {
    if (usagePattern("eval").test(code)) {
      violations.push(`${relPath}: found "eval" usage`);
    }
  }
  assert.deepEqual(violations, [], `eval usage found in src/:\n${violations.join("\n")}`);
});

test("src/ contains no write-method HTTP literals (POST/PUT/PATCH/DELETE)", () => {
  const violations: string[] = [];
  for (const { relPath, code } of allSourceFiles()) {
    for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
      if (new RegExp(`\\b${method}\\b`).test(code)) {
        violations.push(`${relPath}: found "${method}"`);
      }
    }
  }
  assert.deepEqual(violations, [], `write-method HTTP literal found in src/:\n${violations.join("\n")}`);
});

test("the only fetch(...) call sites in src/ are in github-client.ts", () => {
  const violations: string[] = [];
  for (const { relPath, code } of allSourceFiles()) {
    if (relPath === GITHUB_CLIENT_FILE) {
      continue;
    }
    if (/\bfetch\s*\(/.test(code) || /XMLHttpRequest/.test(code) || /\bundici\b/.test(code)) {
      violations.push(`${relPath}: found a fetch/XHR/undici call site outside github-client.ts`);
    }
  }
  assert.deepEqual(violations, [], violations.join("\n"));
});

test("github-client.ts fixes every HTTP method literal to GET", () => {
  const githubClientFile = allSourceFiles().find((entry) => entry.relPath === GITHUB_CLIENT_FILE);
  assert.ok(githubClientFile, "expected src/github-client.ts to exist");
  const methodLiterals = [...githubClientFile!.code.matchAll(/method\s*:\s*["']([A-Z]+)["']/g)].map(
    (match) => match[1],
  );
  assert.ok(methodLiterals.length > 0, "expected at least one method: literal in github-client.ts");
  for (const literal of methodLiterals) {
    assert.equal(literal, "GET", `found non-GET method literal "${literal}" in github-client.ts`);
  }
});

test("the only scheme://host literal anywhere in src/ is the fixed GitHub API base URL", () => {
  const violations: string[] = [];
  for (const { relPath, code } of allSourceFiles()) {
    const matches = [...code.matchAll(/["'](https?:\/\/[^"'/]+)/g)].map((match) => match[1]);
    for (const hostLiteral of matches) {
      if (hostLiteral !== FIXED_GITHUB_API_BASE_URL) {
        violations.push(`${relPath}: found host literal "${hostLiteral}"`);
      }
    }
  }
  assert.deepEqual(violations, [], `unexpected host literal found in src/:\n${violations.join("\n")}`);
});
