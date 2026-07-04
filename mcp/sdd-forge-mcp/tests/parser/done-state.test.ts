/**
 * AC-002: synthetic tasks.md fixtures exercising the Done / Implementation
 * Complete / critical-risk-Done validation paths (evidence bundle presence,
 * contract presence/shape, quality-gate VERDICT lookup, implementation
 * report word-boundary lookup, two-person critical approval).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { findFailure } from "./test-helpers.js";

const APPROVAL_APPROVED = ["Approval", "Approved"].join(": ");

test("Done without a verification/<task-id>.evidence.json file fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-done-noevidence");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Done",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "done-evidence-missing");
    assert.ok(missing, "expected a done-evidence-missing failure");
    assert.equal(
      missing?.message,
      "T-001 is Done but verification/T-001.evidence.json does not exist in specs/demo",
    );
  } finally {
    cleanup();
  }
});

test("Done with evidence.json but missing contract.json fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-done-nocontract");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Done",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(
      root.path,
      "specs/demo/verification/T-001.evidence.json",
      JSON.stringify({ task_id: "T-001", artifacts: [] }),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "done-contract-missing");
    assert.ok(missing, "expected a done-contract-missing failure");
  } finally {
    cleanup();
  }
});

test("Done with an empty contract.json fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-done-emptycontract");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Done",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(root.path, "specs/demo/verification/T-001.contract.json", "");

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const empty = findFailure(result.data.failures, "done-contract-empty");
    assert.ok(empty, "expected a done-contract-empty failure");
  } finally {
    cleanup();
  }
});

test("Done with a contract.json whose task_id does not match fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-done-contractmismatch");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Done",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(
      root.path,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({ task_id: "T-999" }),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const mismatch = findFailure(result.data.failures, "done-contract-task-id-mismatch");
    assert.ok(mismatch, "expected a done-contract-task-id-mismatch failure");
  } finally {
    cleanup();
  }
});

test("Done with no quality-gate report mentioning the task id fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-done-noqg");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Done",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(
      root.path,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({ task_id: "T-001" }),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "done-quality-gate-report-missing");
    assert.ok(missing, "expected a done-quality-gate-report-missing failure");
  } finally {
    cleanup();
  }
});

test("Done with a quality-gate report present but no VERDICT: PASS fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-done-qgfail");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Done",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(
      root.path,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({ task_id: "T-001" }),
    );
    writeFile(
      root.path,
      "reports/quality-gate/T-001.md",
      ["Task ID: T-001", "", `${["VERDICT", "FAIL"].join(": ")}`, ""].join("\n"),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const verdictFail = findFailure(result.data.failures, "done-quality-gate-verdict-fail");
    assert.ok(verdictFail, "expected a done-quality-gate-verdict-fail failure");
  } finally {
    cleanup();
  }
});

test("Implementation Complete without a matching implementation report fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-implcomplete-noreport");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Implementation Complete",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "impl-complete-report-missing");
    assert.ok(missing, "expected an impl-complete-report-missing failure");
  } finally {
    cleanup();
  }
});

test("Implementation Complete with a word-boundary match in an implementation report passes that rule", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-implcomplete-match");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Implementation Complete",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(
      root.path,
      "reports/implementation/demo-T-001.md",
      ["# Implementation Report: T-001", "", "- Task ID: T-001", ""].join("\n"),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "pass");
  } finally {
    cleanup();
  }
});

test("T-001 does not falsely match a report that only mentions T-0010 (word boundary)", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-implcomplete-wordboundary");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Implementation Complete",
      "Risk: low",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(
      root.path,
      "reports/implementation/demo-T-0010.md",
      ["# Implementation Report: T-0010", "", "- Task ID: T-0010", ""].join("\n"),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "impl-complete-report-missing");
    assert.ok(missing, "expected T-001 to NOT match a T-0010-only report");
  } finally {
    cleanup();
  }
});

test("critical Done without a distinct Second Approval fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-critical-nosecond");
  try {
    const approvedNamed = "Approved (alice 2026-01-01T00:00:00Z)";
    const tasksMd = [
      "## T-001 Foo",
      "",
      `Approval: ${approvedNamed}`,
      "Status: Done",
      "Risk: critical",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(
      root.path,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({ task_id: "T-001" }),
    );
    writeFile(
      root.path,
      "reports/quality-gate/T-001.md",
      ["Task ID: T-001", "", `${["VERDICT", "PASS"].join(": ")}`, ""].join("\n"),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "critical-second-approval-missing");
    assert.ok(missing, "expected a critical-second-approval-missing failure");
  } finally {
    cleanup();
  }
});

test("critical Done where both approvals are the same person fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-critical-sameapprover");
  try {
    const approvedNamed = "Approved (alice 2026-01-01T00:00:00Z)";
    const tasksMd = [
      "## T-001 Foo",
      "",
      `Approval: ${approvedNamed}`,
      `Second Approval: ${approvedNamed}`,
      "Status: Done",
      "Risk: critical",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(
      root.path,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({ task_id: "T-001" }),
    );
    writeFile(
      root.path,
      "reports/quality-gate/T-001.md",
      ["Task ID: T-001", "", `${["VERDICT", "PASS"].join(": ")}`, ""].join("\n"),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const sameApprover = findFailure(result.data.failures, "critical-same-approver");
    assert.ok(sameApprover, "expected a critical-same-approver failure");
  } finally {
    cleanup();
  }
});

test("critical Done where either approver is 'sudo' fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-critical-sudo");
  try {
    const approvedSudo = "Approved (sudo 2026-01-01T00:00:00Z)";
    const approvedNamed = "Approved (bob 2026-01-02T00:00:00Z)";
    const tasksMd = [
      "## T-001 Foo",
      "",
      `Approval: ${approvedSudo}`,
      `Second Approval: ${approvedNamed}`,
      "Status: Done",
      "Risk: critical",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", "{}");
    writeFile(
      root.path,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({ task_id: "T-001" }),
    );
    writeFile(
      root.path,
      "reports/quality-gate/T-001.md",
      ["Task ID: T-001", "", `${["VERDICT", "PASS"].join(": ")}`, ""].join("\n"),
    );

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const sudoFail = findFailure(result.data.failures, "critical-primary-approver-sudo");
    assert.ok(sudoFail, "expected a critical-primary-approver-sudo failure");
  } finally {
    cleanup();
  }
});
