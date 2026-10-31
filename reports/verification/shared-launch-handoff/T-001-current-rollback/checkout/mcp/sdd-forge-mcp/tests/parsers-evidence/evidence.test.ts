/**
 * T-011: evidence bundle / verification contract structured-data extraction
 * parser tests — `specs/<feature>/verification/T-*.evidence.json` and
 * `T-*.contract.json`.
 *
 * These tests exercise `parseEvidenceBundle` / `parseVerificationContract`
 * (extraction, not validation — see `evidence-bundle.ts` for the
 * check-evidence-bundle.sh-equivalent validator, which is untouched here).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseEvidenceBundle, parseVerificationContract } from "../../src/parsers/evidence.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { makeRealRepoRoot } from "./test-helpers.js";

test("real repo: parseEvidenceBundle reads T-001.evidence.json for sdd-forge-refactor", () => {
  const root = makeRealRepoRoot();
  const result = parseEvidenceBundle(root, "sdd-forge-refactor", "T-001");
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.data.task_id, "T-001");
  assert.equal(result.data.feature, "sdd-forge-refactor");
  assert.ok(typeof result.data.risk === "string" && result.data.risk.length > 0);
  assert.ok(Array.isArray(result.data.artifacts));
  assert.ok((result.data.artifacts as unknown[]).length >= 1);
});

test("real repo: parseVerificationContract reads T-001.contract.json for sdd-forge-refactor", () => {
  const root = makeRealRepoRoot();
  const result = parseVerificationContract(root, "sdd-forge-refactor", "T-001");
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.ok(result.data.checks.length >= 1);
  for (const check of result.data.checks) {
    assert.ok(typeof check.id === "string" && check.id.length > 0);
    assert.equal(typeof check.required, "boolean");
    assert.equal(typeof check.passes, "boolean");
  }
  const placeholderScan = result.data.checks.find((c) => c.id === "placeholder-scan");
  assert.ok(placeholderScan !== undefined);
  assert.equal(placeholderScan?.passes, true);
  assert.ok(placeholderScan?.requirementIds?.includes("REQ-001"));
});

test("real repo: every existing T-*.evidence.json under sdd-forge-refactor parses without throwing", () => {
  const root = makeRealRepoRoot();
  const taskIds = ["T-001", "T-002", "T-003", "T-004", "T-005"];
  let parsedCount = 0;
  for (const taskId of taskIds) {
    const result = parseEvidenceBundle(root, "sdd-forge-refactor", taskId);
    if (result.ok) {
      parsedCount += 1;
      assert.equal(result.data.task_id, taskId);
    }
  }
  assert.ok(parsedCount >= 5, `expected at least 5 parsed evidence bundles, got ${parsedCount}`);
});

test("real repo: every existing T-*.contract.json under sdd-forge-refactor parses without throwing", () => {
  const root = makeRealRepoRoot();
  const taskIds = ["T-001", "T-002", "T-003", "T-004", "T-005"];
  let parsedCount = 0;
  for (const taskId of taskIds) {
    const result = parseVerificationContract(root, "sdd-forge-refactor", taskId);
    if (result.ok) {
      parsedCount += 1;
      assert.ok(result.data.checks.length >= 1);
    }
  }
  assert.ok(parsedCount >= 5, `expected at least 5 parsed contracts, got ${parsedCount}`);
});

test("synthetic: parseEvidenceBundle echoes the signature value without verifying it", () => {
  const { root, cleanup } = makeTempSddRoot("evidence-bundle-signature-echo");
  try {
    const bundle = {
      task_id: "T-009",
      feature: "demo",
      risk: "critical",
      required_workflow: "tdd",
      signature: { alg: "hmac-sha256", value: "deadbeef" },
    };
    writeFile(root.path, "specs/demo/verification/T-009.evidence.json", JSON.stringify(bundle));

    const result = parseEvidenceBundle(root, "demo", "T-009");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.signature, { alg: "hmac-sha256", value: "deadbeef" });
  } finally {
    cleanup();
  }
});

test("synthetic: parseEvidenceBundle rejects a task_id mismatch as cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("evidence-bundle-taskid-mismatch");
  try {
    const bundle = {
      task_id: "T-999",
      feature: "demo",
      risk: "low",
      required_workflow: "tdd",
    };
    writeFile(root.path, "specs/demo/verification/T-009.evidence.json", JSON.stringify(bundle));

    const result = parseEvidenceBundle(root, "demo", "T-009");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.file, "specs/demo/verification/T-009.evidence.json");
  } finally {
    cleanup();
  }
});

test("synthetic: parseEvidenceBundle rejects broken JSON as cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("evidence-bundle-broken-json");
  try {
    writeFile(root.path, "specs/demo/verification/T-009.evidence.json", "{ not valid json");

    const result = parseEvidenceBundle(root, "demo", "T-009");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
  } finally {
    cleanup();
  }
});

test("synthetic: parseEvidenceBundle rejects a bundle missing required fields as cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("evidence-bundle-missing-fields");
  try {
    writeFile(
      root.path,
      "specs/demo/verification/T-009.evidence.json",
      JSON.stringify({ task_id: "T-009" }),
    );

    const result = parseEvidenceBundle(root, "demo", "T-009");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.file, "specs/demo/verification/T-009.evidence.json");
  } finally {
    cleanup();
  }
});

test("synthetic: parseEvidenceBundle propagates a not-found error unchanged", () => {
  const { root, cleanup } = makeTempSddRoot("evidence-bundle-not-found");
  try {
    const result = parseEvidenceBundle(root, "demo", "T-404");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "not-found");
  } finally {
    cleanup();
  }
});

test("synthetic: parseVerificationContract converts checks[] into the contractChecksSummaryData shape", () => {
  const { root, cleanup } = makeTempSddRoot("verification-contract-shape");
  try {
    const contract = {
      task_id: "T-009",
      risk: "low",
      checks: [
        {
          id: "unit-tests",
          required: true,
          passes: true,
          evidence: "specs/demo/verification/T-009.green.log",
          waiver_reason: "",
          requirement_ids: ["REQ-001", "REQ-002"],
        },
        {
          id: "lint",
          required: false,
          passes: false,
          waiver_reason: "no lintable files",
          requirement_ids: [],
        },
      ],
    };
    writeFile(root.path, "specs/demo/verification/T-009.contract.json", JSON.stringify(contract));

    const result = parseVerificationContract(root, "demo", "T-009");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.checks, [
      {
        id: "unit-tests",
        required: true,
        passes: true,
        waiverReason: "",
        requirementIds: ["REQ-001", "REQ-002"],
      },
      {
        id: "lint",
        required: false,
        passes: false,
        waiverReason: "no lintable files",
        requirementIds: [],
      },
    ]);
  } finally {
    cleanup();
  }
});

test("synthetic: parseVerificationContract rejects a task_id mismatch as cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("verification-contract-taskid-mismatch");
  try {
    const contract = { task_id: "T-001", risk: "low", checks: [] };
    writeFile(root.path, "specs/demo/verification/T-009.contract.json", JSON.stringify(contract));

    const result = parseVerificationContract(root, "demo", "T-009");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
  } finally {
    cleanup();
  }
});

test("synthetic: parseVerificationContract rejects broken JSON as cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("verification-contract-broken-json");
  try {
    writeFile(root.path, "specs/demo/verification/T-009.contract.json", "[ broken");

    const result = parseVerificationContract(root, "demo", "T-009");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
  } finally {
    cleanup();
  }
});

test("synthetic: parseVerificationContract rejects a non-array checks field as cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("verification-contract-checks-not-array");
  try {
    const contract = { task_id: "T-009", risk: "low", checks: "not-an-array" };
    writeFile(root.path, "specs/demo/verification/T-009.contract.json", JSON.stringify(contract));

    const result = parseVerificationContract(root, "demo", "T-009");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
  } finally {
    cleanup();
  }
});
