/**
 * AC-001: golden tests comparing `parseTaskState`'s verdict/failures against
 * `check-task-state.sh`'s exit code and failure messages for every feature
 * under specs/ that this task's golden set covers (sdd-forge-mcp itself is
 * excluded — its own tasks.md is still moving during this implementation).
 *
 * These historical fixtures model a repository before Context activation.
 * Both live implementations read an isolated copy with no Context/sidecar.
 * Full current contract enforcement is outside the parser contract and is
 * checked separately below; this is not full parity under active policies.
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
import { cpSync, existsSync, mkdirSync, readFileSync, realpathSync } from "node:fs";
import { parseTaskState } from "../../src/parsers/tasks.js";
import type { SddRoot } from "../../src/root.js";
import {
  environmentDependentBundleFailures,
  extractOwnFailureMessages,
  findRepoRoot,
  historicalGoldenRoot,
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

  const fixture = historicalGoldenRoot(findRepoRoot());
  t.after(fixture.cleanup);
  const repoRoot = fixture.path;
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

    // Environment-dependent shell failures are reported, never compared. The
    // shell validates evidence bundles against the checkout's git object graph;
    // parseTaskState never runs git, so when a bundle's recorded commit has
    // become unreachable the two sides disagree for a reason that says nothing
    // about the parser and that flips between machines for the same tree.
    // Comparing anyway produced a red CI on 2026-08-31 that was green on the
    // developer machine holding the orphaned object.
    //
    // The parser is still required to have produced a usable result, and the
    // cause is printed so a degraded checkout can never look like a clean run.
    const environmentCauses = environmentDependentBundleFailures(combinedOutput, ownFailureMessages);
    if (environmentCauses.length > 0) {
      assert.equal(
        parserResult.ok,
        true,
        `${feature}: parser must still succeed when the shell fails for environment-only reasons`,
      );
      t.diagnostic(
        `${feature}: verdict comparison skipped — the shell failed only on ` +
          `checkout-dependent evidence-bundle causes the parser cannot observe: ` +
          environmentCauses.join("; "),
      );
      continue;
    }

    assertParserMatchesShell(feature, parserResult, exitCode, fileNotFound, ownFailureMessages);
  }
});

test("recorded fixture comparison: parseTaskState matches the committed golden fixtures", (t) => {
  const fixture = historicalGoldenRoot(findRepoRoot());
  t.after(fixture.cleanup);
  const repoRoot = fixture.path;
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

// Active Context changes the shell contract policy, which the read-only parser
// explicitly does not reimplement. Keep that refusal visible instead of masking it.
test("active Context still rejects historical high-risk contracts without coverage", (t) => {
  if (process.platform === "win32") {
    t.skip("POSIX shell policy check");
    return;
  }
  const repository = findRepoRoot();
  const fixture = historicalGoldenRoot(repository);
  t.after(fixture.cleanup);
  assert.equal(existsSync(`${fixture.path}/sdd/project-context.yaml`), false);
  assert.equal(existsSync(`${fixture.path}/sdd/project-context.approval.json`), false);
  const originalContext = readFileSync(`${repository}/sdd/project-context.yaml`);
  mkdirSync(`${fixture.path}/sdd`);
  cpSync(`${repository}/sdd/project-context.yaml`, `${fixture.path}/sdd/project-context.yaml`);
  const result = runCheckTaskState(fixture.path, "bootstrap-interviewer-enhancement");
  assert.deepEqual(readFileSync(`${repository}/sdd/project-context.yaml`), originalContext);
  assert.equal(result.exitCode, 1);
  assert.match(result.combinedOutput, /requires check 'check-component-coverage' present and required:true \(missing\)/);
  assert.ok(extractOwnFailureMessages(result.combinedOutput).some(message => message.startsWith("T-004 evidence bundle failed validation:")));
});
