/**
 * AC-001: golden tests comparing `parseTaskState`'s verdict/failures against
 * `check-task-state.sh`'s exit code and failure messages for every feature
 * under specs/ that this task's golden set covers (sdd-forge-mcp itself is
 * excluded — its own tasks.md is still moving during this implementation).
 *
 * Two comparison modes:
 *  - `describe("live shell comparison")`: only runs on POSIX platforms (this
 *    repo's dev/CI environment) and shells out to check-task-state.sh live.
 *  - `describe("recorded fixture comparison")`: always runs, comparing
 *    against the committed tests/golden/fixtures/<feature>.expected.json
 *    snapshots recorded by `npm run golden:record`. This is the mode Windows
 *    CI uses (no POSIX shell available there).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { realpathSync } from "node:fs";
import { parseTaskState } from "../../src/parsers/tasks.js";
import type { SddRoot } from "../../src/root.js";
import {
  extractOwnFailureMessages,
  findRepoRoot,
  loadRecordedFixture,
  runCheckTaskState,
  shellReportsFileNotFound,
  type RecordedFixture,
} from "./shell-runner.js";

const GOLDEN_FEATURES = [
  "bootstrap-interviewer-enhancement",
  "ci-mcp",
  "claude-workflow-compatibility",
  "cross-model-verification",
  "evidence-deep-verify",
  "risk-adaptive-layer",
  "sdd-forge-refactor",
  "sdd-lite",
] as const;

function makeRepoRoot(repoRoot: string): SddRoot {
  return Object.freeze({ path: realpathSync(repoRoot), source: "cwd" as const });
}

/** The shell verifies git ancestry, which the read-only parser leaves to the host. */
function isHostDeferredAncestryOnlyFailure(
  feature: string,
  exitCode: number,
  combinedOutput: string,
): boolean {
  if (feature !== "risk-adaptive-layer" || exitCode !== 1) {
    return false;
  }
  const failureLines = combinedOutput.split("\n").filter((line) => line.startsWith(" - "));
  return (
    failureLines.length === 2 &&
    /^ - git_commit does not exist in repository: [0-9a-f]{40}$/.test(failureLines[0] ?? "") &&
    failureLines[1] ===
      " - T-010 evidence bundle failed validation: specs/risk-adaptive-layer/verification/T-010.evidence.json"
  );
}

test("host-deferred ancestry exception requires the sole T-010 shell failure", () => {
  const output = [
    "Evidence bundle FAILED for task T-010:",
    ` - git_commit does not exist in repository: ${"a".repeat(40)}`,
    " - T-010 evidence bundle failed validation: specs/risk-adaptive-layer/verification/T-010.evidence.json",
  ].join("\n");
  assert.equal(isHostDeferredAncestryOnlyFailure("risk-adaptive-layer", 1, output), true);
  assert.equal(isHostDeferredAncestryOnlyFailure("ci-mcp", 1, output), false);
  assert.equal(isHostDeferredAncestryOnlyFailure("risk-adaptive-layer", 0, output), false);
  assert.equal(isHostDeferredAncestryOnlyFailure("risk-adaptive-layer", 1, `${output}\n - hash mismatch`), false);
});

/**
 * Asserts that a parser result matches a shell-side verdict summary,
 * regardless of which side (live shell run or recorded fixture) produced it.
 */
function assertParserMatchesShell(
  feature: string,
  parserResult: ReturnType<typeof parseTaskState>,
  shellExitCode: number,
  shellFileNotFound: boolean,
  shellOwnFailureMessages: string[],
): void {
  if (shellFileNotFound) {
    assert.equal(
      parserResult.ok,
      false,
      `${feature}: shell reported file-not-found, expected parser envelope error`,
    );
    if (!parserResult.ok) {
      assert.equal(parserResult.error.code, "not-found", `${feature}: expected not-found code`);
    }
    return;
  }

  assert.equal(
    parserResult.ok,
    true,
    `${feature}: expected parser to succeed` +
      (parserResult.ok ? "" : ` — envelope error: ${JSON.stringify(parserResult.error)}`),
  );
  if (!parserResult.ok) {
    return;
  }

  const expectedVerdict = shellExitCode === 0 ? "pass" : "fail";
  assert.equal(
    parserResult.data.verdict,
    expectedVerdict,
    `${feature}: verdict mismatch (shell exit ${shellExitCode})`,
  );

  const parserMessages = parserResult.data.failures.map((f) => f.message).sort();
  const shellMessages = [...shellOwnFailureMessages].sort();
  assert.deepEqual(
    parserMessages,
    shellMessages,
    `${feature}: failure message set mismatch`,
  );
}

test("live shell comparison: parseTaskState matches check-task-state.sh for every golden feature", (t) => {
  if (process.platform === "win32") {
    t.skip("POSIX shell not exercised on Windows; see recorded fixture comparison below");
    return;
  }

  const repoRoot = findRepoRoot();
  const root = makeRepoRoot(repoRoot);

  for (const feature of GOLDEN_FEATURES) {
    const { exitCode, combinedOutput } = runCheckTaskState(repoRoot, feature);
    const fileNotFound = shellReportsFileNotFound(combinedOutput);
    const ownFailureMessages = extractOwnFailureMessages(combinedOutput);

    // POSIX separators by contract: path-guard rejects backslashes, so the
    // platform-dependent join() must not build this path (Windows would
    // produce specs\<feature>\tasks.md and be denied).
    const relTasksPath = `specs/${feature}/tasks.md`;
    const parserResult = parseTaskState(root, feature, relTasksPath);

    if (isHostDeferredAncestryOnlyFailure(feature, exitCode, combinedOutput)) {
      // The sole shell failure is a missing historical commit. The parser
      // intentionally checks evidence shape, not repository ancestry.
      assert.equal(parserResult.ok, true, `${feature}: expected parser to read task state`);
      if (parserResult.ok) {
        assert.equal(parserResult.data.verdict, "pass", `${feature}: shape-only verdict`);
        assert.deepEqual(parserResult.data.failures, [], `${feature}: shape-only failures`);
      }
      continue;
    }

    assertParserMatchesShell(feature, parserResult, exitCode, fileNotFound, ownFailureMessages);
  }
});

test("recorded fixture comparison: parseTaskState matches the committed golden fixtures", () => {
  const repoRoot = findRepoRoot();
  const root = makeRepoRoot(repoRoot);

  for (const feature of GOLDEN_FEATURES) {
    const fixture: RecordedFixture = loadRecordedFixture(feature);
    assert.equal(fixture.feature, feature, `fixture file for ${feature} has mismatched feature field`);

    // POSIX separators by contract: path-guard rejects backslashes, so the
    // platform-dependent join() must not build this path (Windows would
    // produce specs\<feature>\tasks.md and be denied).
    const relTasksPath = `specs/${feature}/tasks.md`;
    const parserResult = parseTaskState(root, feature, relTasksPath);

    assertParserMatchesShell(
      feature,
      parserResult,
      fixture.exitCode,
      fixture.fileNotFound,
      fixture.ownFailureMessages,
    );
  }
});
