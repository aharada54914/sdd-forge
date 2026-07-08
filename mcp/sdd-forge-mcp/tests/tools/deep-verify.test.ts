/**
 * evidence_deep_verify core (T-001) — tamper and empty-artifacts behavior.
 *
 * These call the pure `evidenceDeepVerify(root, feature, taskId)` function
 * directly (no server.ts registration — that is T-004), asserting on the
 * returned envelope's `data`.
 *
 * - AC-001 (baseline): a fully consistent bundle -> verdict "pass", no failures.
 * - AC-002: a 1-byte on-disk tamper -> that artifact "mismatch", digest
 *   "mismatch", verdict "fail", the path appears in `failures`.
 * - AC-003: a recorded sha rewritten to a different 64-hex -> "mismatch"
 *   (computed != recorded), verdict "fail".
 * - AC-018: empty `artifacts[]` -> vacuous pass when other invariants hold,
 *   and "fail" when another invariant fails; never throws.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "../test-helpers.js";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { seedDeepVerifyRepo, sha256Of } from "./deep-verify-helpers.js";

test("AC-001: a fully consistent bundle verifies as pass with no failures", () => {
  const fx = seedDeepVerifyRepo("deep-verify-consistent");
  try {
    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const data = result.data;
    assert.equal(data.kind, "evidence-deep-verify");
    assert.equal(data.verdict, "pass");
    assert.deepEqual(data.failures, []);
    assert.equal(data.artifacts.length, 3);
    assert.ok(data.artifacts.every((a) => a.status === "match"));
    assert.equal(data.invariants.artifactsDigest.status, "match");
    assert.equal(data.invariants.specRevision.status, "match");
    assert.equal(data.invariants.gitCommit.shapeValid, true);
    assert.equal(data.invariants.gitCommit.ancestryVerified, false);
    assert.ok(data.invariants.crossBindings.every((b) => b.status === "match"));
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-002: a 1-byte on-disk artifact tamper maps to mismatch + digest mismatch + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-tamper-disk");
  try {
    // Tamper the on-disk file only; the bundle's recorded sha is unchanged.
    writeFile(fx.dir, fx.artifactRel, `${fx.artifactContents}X`);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const data = result.data;
    assert.equal(data.verdict, "fail");

    const tampered = data.artifacts.find((a) => a.path === fx.artifactRel);
    assert.ok(tampered !== undefined);
    assert.equal(tampered?.status, "mismatch");
    assert.notEqual(tampered?.computedSha256, tampered?.recordedSha256);

    assert.equal(data.invariants.artifactsDigest.status, "mismatch");
    assert.ok(data.failures.some((f) => f.includes(fx.artifactRel)));
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-003: a recorded sha rewritten to a different 64-hex maps to mismatch + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-tamper-recorded");
  try {
    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    const target = artifacts.find((a) => a.path === fx.artifactRel);
    assert.ok(target !== undefined);
    // A well-formed 64-hex that differs from the real on-disk hash.
    target!.sha256 = "b".repeat(64);
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const data = result.data;
    assert.equal(data.verdict, "fail");

    const tampered = data.artifacts.find((a) => a.path === fx.artifactRel);
    assert.equal(tampered?.status, "mismatch");
    assert.equal(tampered?.recordedSha256, "b".repeat(64));
    assert.equal(tampered?.computedSha256, sha256Of(fx.artifactContents));
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-018: empty artifacts[] is a vacuous pass when the remaining invariants hold, without throwing", () => {
  const fx = seedDeepVerifyRepo("deep-verify-empty-pass");
  try {
    const bundle = fx.baseBundle();
    bundle.artifacts = [];
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const data = result.data;
    assert.deepEqual(data.artifacts, []);
    // Empty artifacts digest is the sha256 of the empty string on both sides.
    assert.equal(data.invariants.artifactsDigest.recorded, sha256Of(""));
    assert.equal(data.invariants.artifactsDigest.onDisk, sha256Of(""));
    assert.equal(data.invariants.artifactsDigest.status, "match");
    assert.equal(data.verdict, "pass");
    assert.deepEqual(data.failures, []);
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-018: empty artifacts[] still fails when another invariant fails (malformed git_commit)", () => {
  const fx = seedDeepVerifyRepo("deep-verify-empty-fail");
  try {
    const bundle = fx.baseBundle();
    bundle.artifacts = [];
    bundle.git_commit = "not-a-40-hex-commit";
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const data = result.data;
    assert.equal(data.invariants.artifactsDigest.status, "match");
    assert.equal(data.invariants.gitCommit.shapeValid, false);
    assert.equal(data.verdict, "fail");
    assert.ok(data.failures.some((f) => f.includes("git_commit")));
  } finally {
    fx.tempRoot.cleanup();
  }
});
