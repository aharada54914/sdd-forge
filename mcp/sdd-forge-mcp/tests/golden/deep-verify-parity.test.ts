import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { findRepoRoot } from "./shell-runner.js";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { writeFile } from "../test-helpers.js";
import {
  buildParityFixtureBase,
  readBundleJson,
  type ParityFixtureFiles,
} from "./deep-verify-parity-helpers.js";

// These outputs were recorded by the retired host program. Point
// SDD_GOLDEN_EVIDENCE_CHECKER at that script in the identified revision to
// replay it on the very same fixtures, including its Git ancestry checks.
interface HostCase {
  fixtureCommit: string;
  exitCode: number;
  failures: string[];
}
const recordingPath = join(findRepoRoot(), "mcp/sdd-forge-mcp/tests/golden/fixtures/deep-verify-host.json");
const recording: { revision: string; blob: string; cases: Record<string, HostCase> } = JSON.parse(readFileSync(recordingPath, "utf8"));
const liveChecker = process.env.SDD_GOLDEN_EVIDENCE_CHECKER;
if (liveChecker) {
  const script = readFileSync(liveChecker);
  const blob = createHash("sha1").update(`blob ${script.length}\0`).update(script).digest("hex");
  assert.equal(blob, recording.blob, `Expected check-evidence-bundle.sh from ${recording.revision}`);
}

function buildFixture(taskId: string, options: { risk?: string; specRevisionOverride?: string } = {}) {
  const host = recording.cases[taskId];
  assert.ok(host, `missing historical host recording for ${taskId}`);
  return buildParityFixtureBase("golden-parity", "golden-parity", taskId, {
    ...options,
    fixtureCommit: liveChecker ? undefined : host.fixtureCommit,
  });
}

function assertHostAndToolAgree(fx: ParityFixtureFiles, expected: "pass" | "artifact mismatch" | "spec drift"): void {
  const host = recording.cases[fx.taskId];
  const hostFailures = {
    pass: [],
    "artifact mismatch": [`artifact sha256 mismatch for ${fx.artifactRel}`],
    "spec drift": ["high/critical bundle requires spec_revision (64-hex), got: (empty)"],
  }[expected];
  assert.deepEqual(host.failures, hostFailures);
  assert.equal(host.exitCode, expected === "pass" ? 0 : 1);

  if (liveChecker) {
    const replay = spawnSync("sh", [resolve(liveChecker), fx.bundleRel, fx.dir], { cwd: fx.dir, encoding: "utf8" });
    if (replay.error) throw replay.error;
    const output = replay.stdout + replay.stderr;
    assert.equal(replay.status, host.exitCode, output);
    const failures = output.split(/\r?\n/).filter(line => line.startsWith(" - ")).map(line => line.slice(3));
    assert.deepEqual(failures, host.failures, output);
    if (host.exitCode === 0) assert.ok(output.includes(`Evidence bundle passed for task ${fx.taskId}.`), output);
  }

  const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
  assert.ok(result.ok, JSON.stringify(result));
  assert.equal(result.data.verdict, host.exitCode === 0 ? "pass" : "fail", result.data.failures.join("\n"));
  assert.deepEqual(result.data.artifacts.filter(a => a.status !== "match").map(a => [a.path, a.status]),
    expected === "artifact mismatch" ? [[fx.artifactRel, "mismatch"]] : []);
  assert.equal(result.data.invariants.specRevision.status, expected === "spec drift" ? "mismatch" : "match");
}

test("AC-012: consistent bundle -- evidence_deep_verify matches the recorded host pass", () => {
  const fx = buildFixture("T-900");
  try {
    assertHostAndToolAgree(fx, "pass");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-012: tampered on-disk artifact -- evidence_deep_verify matches the recorded host failure", () => {
  const fx = buildFixture("T-901");
  try {
    // Tamper the on-disk file only; the bundle's recorded sha256 is
    // unchanged, so recorded != on-disk on both the host and tool side.
    writeFile(fx.dir, fx.artifactRel, `${fx.artifactContents}TAMPERED\n`);
    assertHostAndToolAgree(fx, "artifact mismatch");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-012: spec drift on a high-risk bundle -- evidence_deep_verify matches the recorded host failure", () => {
  const fx = buildFixture("T-902", {
    risk: "high",
    specRevisionOverride: "",
  });
  try {
    assertHostAndToolAgree(fx, "spec drift");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-012: tampered recorded artifact hash -- evidence_deep_verify matches the recorded host failure", () => {
  const fx = buildFixture("T-903");
  try {
    // Tamper the bundle's recorded sha256 only; the on-disk file is
    // unchanged, so recorded != on-disk on both the host and tool side --
    // the dual of the "tampered on-disk artifact" case above.
    const bundle = readBundleJson(fx);
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    const target = artifacts.find((a) => a.path === fx.artifactRel);
    assert.ok(target !== undefined, "expected an artifact.md entry in the fixture bundle");
    const realSha = target.sha256;
    target.sha256 = realSha === "0".repeat(64) ? "f".repeat(64) : "0".repeat(64);
    writeFileSync(join(fx.dir, fx.bundleRel), JSON.stringify(bundle, null, 2), "utf-8");

    assertHostAndToolAgree(fx, "artifact mismatch");
  } finally {
    fx.tempRoot.cleanup();
  }
});
