/**
 * Task ids are unique only within a feature, so Done evidence must not come
 * from a quality-gate report that declares another feature. A report with no
 * `Feature:` line (written before the identity block was required) still
 * counts.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { evidenceFindMissing } from "../../src/tools/evidence.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { findFailure } from "./test-helpers.js";

const DONE_TASK = ["## T-001 Foo", "", ["Approval", "Approved"].join(": "), "Status: Done", "Risk: low", "", "### Blockers", "None", ""].join("\n");

function report(feature: string | null): string {
  return ["# Quality Gate Report", "", "Task ID: T-001", ...(feature === null ? [] : [`Feature: ${feature}`]), "VERDICT: PASS", ""].join("\n");
}

function v2Feature(rootPath: string): void {
  writeFile(rootPath, "specs/demo/tasks.md", DONE_TASK);
  writeFile(rootPath, "specs/demo/.spec-baseline.json", "{}");
}

test("v2 Done: a PASS report that declares another feature is not evidence", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-other");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other"));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    assert.ok(findFailure(result.data.failures, "done-quality-gate-report-missing"), JSON.stringify(result.data.failures));
  } finally {
    cleanup();
  }
});

test("v2 Done: another feature's FAIL report does not hide this feature's PASS", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-mixed");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/demo-T-001.md", report("demo"));
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other").replace("VERDICT: PASS", "VERDICT: FAIL"));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.failures, []);
  } finally {
    cleanup();
  }
});

test("v2 Done: a PASS report without a Feature line still counts", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-legacy");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/T-001.md", report(null));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.failures, []);
  } finally {
    cleanup();
  }
});

test("v2 Done: a report naming another feature only after its identity block is not evidence", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-first-line");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other") + "\nFeature: demo\n");
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(findFailure(result.data.failures, "done-quality-gate-report-missing"), JSON.stringify(result.data.failures));
  } finally {
    cleanup();
  }
});

test("lite Done: a PASS report that declares another feature is not evidence", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-lite");
  try {
    writeFile(root.path, "AGENTS.md", "# A\n\n## Project Settings\n\nspec_profile: lite\n");
    writeFile(root.path, "specs/demo/tasks.md", DONE_TASK);
    writeFile(root.path, "reports/implementation/T-001.md", "T-001\n");
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other"));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(findFailure(result.data.failures, "done-quality-gate-verdict-fail"), JSON.stringify(result.data.failures));
  } finally {
    cleanup();
  }
});

test("evidence_find_missing: another feature's PASS report does not satisfy the requirement", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-find-missing");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other"));
    const result = evidenceFindMissing(root, "demo", "T-001");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(result.data.missing.includes("quality-gate-report-pass"), JSON.stringify(result.data));
  } finally {
    cleanup();
  }
});
