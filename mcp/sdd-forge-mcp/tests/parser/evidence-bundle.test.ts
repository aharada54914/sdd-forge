/**
 * AC-002: direct coverage of verifyEvidenceBundle's risk-tiered provenance
 * and signature branches (check-evidence-bundle.sh parity), exercised here
 * through a Done task so the full tasks.md -> evidence-bundle path is
 * covered end to end.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { findFailure } from "./test-helpers.js";

const APPROVAL_APPROVED = ["Approval", "Approved"].join(": ");
const QUALITY_REPORT_CONTENTS = [
  "Task ID: T-001",
  "",
  `${["VERDICT", "PASS"].join(": ")}`,
  "",
].join("\n");

function sha256(contents: string): string {
  return createHash("sha256").update(contents, "utf-8").digest("hex");
}

/** Writes a Done task's tasks.md, a passing quality-gate report, and a matching contract; returns the contract's raw contents for sha256ing. */
function setupBaseline(rootPath: string, risk: string, extraTasksFields = ""): string {
  const tasksMd = [
    "## T-001 Foo",
    "",
    `${APPROVAL_APPROVED}`,
    extraTasksFields,
    "Status: Done",
    `Risk: ${risk}`,
    "",
    "### Blockers",
    "None",
    "",
  ]
    .filter((line) => line !== "")
    .join("\n");
  writeFile(rootPath, "specs/demo/tasks.md", tasksMd);
  writeFile(rootPath, "reports/quality-gate/T-001.md", QUALITY_REPORT_CONTENTS);

  const contractContents = JSON.stringify({ task_id: "T-001", risk, checks: [] });
  writeFile(rootPath, "specs/demo/verification/T-001.contract.json", contractContents);
  return contractContents;
}

function baseArtifacts(contractContents: string): Array<{ path: string; sha256: string }> {
  return [
    { path: "reports/quality-gate/T-001.md", sha256: sha256(QUALITY_REPORT_CONTENTS) },
    { path: "specs/demo/verification/T-001.contract.json", sha256: sha256(contractContents) },
  ];
}

test("high-risk Done bundle missing spec_revision fails provenance", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-evidence-highrisk-noprovenance");
  try {
    const contractContents = setupBaseline(root.path, "high");
    const bundle = {
      task_id: "T-001",
      risk: "high",
      quality_report: "reports/quality-gate/T-001.md",
      verification_contract: "specs/demo/verification/T-001.contract.json",
      git_commit: "a".repeat(40),
      artifacts: baseArtifacts(contractContents),
      // spec_revision / build_env / review_verdict intentionally omitted.
    };
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", JSON.stringify(bundle));

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const invalid = findFailure(result.data.failures, "done-evidence-invalid");
    assert.ok(invalid, "expected done-evidence-invalid for missing high-risk provenance");
  } finally {
    cleanup();
  }
});

test("high-risk Done bundle with full provenance and matching artifact hashes passes", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-evidence-highrisk-provenance-ok");
  try {
    const contractContents = setupBaseline(root.path, "high");
    const bundle = {
      task_id: "T-001",
      risk: "high",
      quality_report: "reports/quality-gate/T-001.md",
      verification_contract: "specs/demo/verification/T-001.contract.json",
      git_commit: "a".repeat(40),
      spec_revision: "b".repeat(64),
      build_env: { os: "linux" },
      review_verdict: { verdict: "PASS" },
      artifacts: baseArtifacts(contractContents),
    };
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", JSON.stringify(bundle));

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.failures, []);
    assert.equal(result.data.verdict, "pass");
  } finally {
    cleanup();
  }
});

test("an artifact sha256 mismatch fails the evidence bundle", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-evidence-shamismatch");
  try {
    const contractContents = setupBaseline(root.path, "low");
    const bundle = {
      task_id: "T-001",
      risk: "low",
      quality_report: "reports/quality-gate/T-001.md",
      verification_contract: "specs/demo/verification/T-001.contract.json",
      git_commit: "a".repeat(40),
      artifacts: [
        { path: "reports/quality-gate/T-001.md", sha256: "0".repeat(64) },
        { path: "specs/demo/verification/T-001.contract.json", sha256: sha256(contractContents) },
      ],
    };
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", JSON.stringify(bundle));

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const invalid = findFailure(result.data.failures, "done-evidence-invalid");
    assert.ok(invalid, "expected done-evidence-invalid for sha256 mismatch");
  } finally {
    cleanup();
  }
});

test("critical risk Done bundle without a signature object fails", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-evidence-critical-nosignature");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      "Approval: Approved (alice 2026-01-01T00:00:00Z)",
      "Second Approval: Approved (bob 2026-01-02T00:00:00Z)",
      "Status: Done",
      "Risk: critical",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);
    writeFile(root.path, "reports/quality-gate/T-001.md", QUALITY_REPORT_CONTENTS);
    const contractContents = JSON.stringify({ task_id: "T-001", risk: "critical", checks: [] });
    writeFile(root.path, "specs/demo/verification/T-001.contract.json", contractContents);

    const bundle = {
      task_id: "T-001",
      risk: "critical",
      quality_report: "reports/quality-gate/T-001.md",
      verification_contract: "specs/demo/verification/T-001.contract.json",
      git_commit: "a".repeat(40),
      spec_revision: "b".repeat(64),
      build_env: { os: "linux" },
      review_verdict: { verdict: "PASS" },
      git_generated_dirty: false,
      artifacts: baseArtifacts(contractContents),
      // signature intentionally omitted.
    };
    writeFile(root.path, "specs/demo/verification/T-001.evidence.json", JSON.stringify(bundle));

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const invalid = findFailure(result.data.failures, "done-evidence-invalid");
    assert.ok(invalid, "expected done-evidence-invalid for a critical bundle missing a signature");
  } finally {
    cleanup();
  }
});
