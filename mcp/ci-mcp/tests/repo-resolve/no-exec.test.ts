/**
 * AC-012 (TEST-012, static half): `repo-resolve.ts` must never exec to read
 * a git remote (REQ-007 Non-goal / security-spec.md: exec is a static-check
 * banned pattern). This inspects the actual source text rather than
 * behavior, since a static check is the only way to prove an import was
 * never written, independent of whether any code path happens to invoke it
 * at test time.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Compiled location: dist-test/tests/repo-resolve/. tsconfig.test.json
// compiles with rootDir "." so dist-test mirrors the whole package layout
// (dist-test/src/*.js, dist-test/tests/*.js) — walk up 3 levels
// (repo-resolve -> tests -> dist-test) to the ci-mcp package root, then into
// the REAL (uncompiled) src/repo-resolve.ts.
const SOURCE_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
  "src",
  "repo-resolve.ts",
);

function readSource(): string {
  return readFileSync(SOURCE_PATH, "utf8");
}

test("repo-resolve.ts source contains no child_process import", () => {
  const source = readSource();
  // Matches an actual import/require of the module specifier, not an
  // English-language mention of the module name in a doc comment.
  const importPattern =
    /from\s+["'](?:node:)?child_process["']|require\(\s*["'](?:node:)?child_process["']\s*\)/;
  assert.ok(!importPattern.test(source), "must never import node:child_process");
});

test("repo-resolve.ts source contains no exec/spawn/execFile call patterns", () => {
  const source = readSource();
  for (const banned of ["exec(", "execSync(", "spawn(", "spawnSync(", "execFile(", "execFileSync("]) {
    assert.ok(!source.includes(banned), `must not call ${banned}`);
  }
});
