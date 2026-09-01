/**
 * Non-vacuity controls for `environmentDependentBundleFailures`.
 *
 * The live golden comparison skips its verdict assertion when this predicate
 * fires, so the predicate is the only thing standing between "ignore one cause
 * the parser structurally cannot observe" and "ignore evidence-bundle failures
 * in general". These tests pin that boundary: one positive case built from the
 * verbatim shell output measured on 2026-08-31, and four negative controls that
 * must keep the strict comparison in force.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { environmentDependentBundleFailures, extractOwnFailureMessages } from "./shell-runner.js";

/** The exact output `check-task-state.sh` produced in a fresh clone on 2026-08-31. */
const ORPHANED_COMMIT_OUTPUT = [
  "Task state check FAILED:",
  "Verification contract passed for task T-010.",
  "WARNING: evidence bundle for task T-010 was generated with a dirty working tree",
  "Evidence bundle FAILED for task T-010:",
  " - git_commit does not exist in repository: a3a5c66c905211a3ad2dfe21814c6f6a9d8ba38d",
  " - T-010 evidence bundle failed validation: specs/risk-adaptive-layer/verification/T-010.evidence.json",
  "",
].join("\n");

test("fires on the measured orphaned-commit output and names the cause", () => {
  const own = extractOwnFailureMessages(ORPHANED_COMMIT_OUTPUT);
  assert.deepEqual(own, [
    "T-010 evidence bundle failed validation: specs/risk-adaptive-layer/verification/T-010.evidence.json",
  ]);

  const causes = environmentDependentBundleFailures(ORPHANED_COMMIT_OUTPUT, own);
  assert.deepEqual(causes, [
    "git_commit does not exist in repository: a3a5c66c905211a3ad2dfe21814c6f6a9d8ba38d",
  ]);
});

test("negative control: a shell failure the parser CAN see is still compared", () => {
  // A sha256 mismatch is bundle content, not checkout state — the parser folds
  // it into done-evidence-invalid, so the comparison must stay strict.
  const output = [
    "Task state check FAILED:",
    "Evidence bundle FAILED for task T-010:",
    " - artifact sha256 mismatch: specs/f/verification/T-010.green.log",
    " - T-010 evidence bundle failed validation: specs/f/verification/T-010.evidence.json",
    "",
  ].join("\n");
  const own = extractOwnFailureMessages(output);
  assert.equal(own.length, 1);
  assert.deepEqual(environmentDependentBundleFailures(output, own), []);
});

test("negative control: an orphaned commit alongside an in-scope failure is still compared", () => {
  // The tasks.md-level failure is squarely the parser's job. One unobservable
  // cause must not buy amnesty for a second, observable one.
  const output = [
    "Task state check FAILED:",
    " - T-003 is Done but verification/T-003.evidence.json does not exist in specs/f",
    "Evidence bundle FAILED for task T-010:",
    " - git_commit does not exist in repository: a3a5c66c905211a3ad2dfe21814c6f6a9d8ba38d",
    " - T-010 evidence bundle failed validation: specs/f/verification/T-010.evidence.json",
    "",
  ].join("\n");
  const own = extractOwnFailureMessages(output);
  assert.equal(own.length, 2);
  assert.deepEqual(environmentDependentBundleFailures(output, own), []);
});

test("negative control: a clean shell run never suppresses anything", () => {
  const output = ["Task state check passed for 12 task(s).", ""].join("\n");
  assert.deepEqual(environmentDependentBundleFailures(output, []), []);
});

test("negative control: the cause must appear as a detail line, not as prose", () => {
  // Guards against a message that merely quotes the phrase (a report body, a
  // commit subject) being read as the machine-emitted detail line.
  const output = [
    "Task state check FAILED:",
    "note: an earlier run said git_commit does not exist in repository: deadbeef",
    " - T-010 evidence bundle failed validation: specs/f/verification/T-010.evidence.json",
    "",
  ].join("\n");
  const own = extractOwnFailureMessages(output);
  assert.equal(own.length, 1);
  assert.deepEqual(environmentDependentBundleFailures(output, own), []);
});
