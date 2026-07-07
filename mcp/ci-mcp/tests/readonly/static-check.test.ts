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

/**
 * Cycle 2 (evaluator finding fix, T-006): regression tests proving
 * `stripComments` is string-aware, using the evaluator's exact
 * reproductions on synthetic source strings. Before the fix, the naive
 * `/\/\*...\*\//` + `/\/\/.*$/gm` regex pair truncated string literals at
 * their first embedded `//`, which (a) made the host-literal enforcement
 * above vacuously true (a rogue `http://` host inside a string literal was
 * silently chopped down to `"http:` before the host-literal regex ever ran)
 * and (b) hid same-line code that followed a `//`-containing string literal
 * from every denylist check. These tests exercise `stripComments` directly
 * on synthetic text, independent of the real src/ tree, so they keep
 * failing red if the scanner regresses to a non-string-aware implementation
 * even if src/ itself never grows an actual violation.
 */
test("Cycle 2: a rogue host literal embedded in a string is preserved (not truncated at its own //) and is caught by the host-literal scan", () => {
  const synthetic = 'const BAD = "http://attacker.example.com/x";\n';
  const stripped = stripComments(synthetic);
  const matches = [...stripped.matchAll(/["'](https?:\/\/[^"'/]+)/g)].map((match) => match[1]);
  assert.ok(
    matches.includes("http://attacker.example.com"),
    `expected the rogue host literal to survive stripComments intact, got stripped text: ${JSON.stringify(stripped)}`,
  );
  const nonGithubHosts = matches.filter((host) => host !== FIXED_GITHUB_API_BASE_URL);
  assert.ok(
    nonGithubHosts.length > 0,
    "expected the host-literal scan to detect a non-GitHub host in the synthetic source",
  );
});

test("Cycle 2: same-line code after a string containing // is not swallowed as a false comment", () => {
  const synthetic = 'const u = "sc://y"; writeFileSync(p, d);\n';
  const stripped = stripComments(synthetic);
  assert.ok(
    /\bwriteFileSync\s*\(/.test(stripped),
    `expected writeFileSync(...) to survive stripComments on the same line as a "//"-bearing string, got: ${JSON.stringify(stripped)}`,
  );
  // The string literal's contents must also survive verbatim (not be
  // truncated at its embedded //).
  assert.ok(stripped.includes('"sc://y"'), `expected the string literal to survive intact, got: ${JSON.stringify(stripped)}`);
});

test("Cycle 2: genuine // and /* */ comments are still stripped (no false positive from real comments)", () => {
  const synthetic = '// writeFileSync(x)\nconst y = 1;\n/* http://evil.com */\nconst z = 2;\n';
  const stripped = stripComments(synthetic);
  assert.ok(
    !/writeFileSync/.test(stripped),
    `expected the line-commented writeFileSync mention to be stripped, got: ${JSON.stringify(stripped)}`,
  );
  assert.ok(
    !/evil\.com/.test(stripped),
    `expected the block-commented host mention to be stripped, got: ${JSON.stringify(stripped)}`,
  );
  assert.ok(stripped.includes("const y = 1;"), "expected surrounding real code to survive");
  assert.ok(stripped.includes("const z = 2;"), "expected surrounding real code to survive");
});
