/**
 * evidence_deep_verify core (T-001) — exception-safe read/record failures
 * (REQ-011). Every failing artifact resolves to a per-artifact status; the
 * tool never throws, and the verdict is always "fail".
 *
 * - AC-004: an artifact path absent on disk -> "missing".
 * - AC-005: an artifact over the 2 MiB limit -> "too-large"; an allowlist-
 *   escaping path -> "path-denied".
 * - AC-017: a non-64-hex recorded sha -> "invalid-recorded-sha" (never
 *   misclassified as "mismatch"), even when the file exists, and even when it
 *   co-occurs with a missing file the verdict still converges to "fail".
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "../test-helpers.js";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { seedDeepVerifyRepo } from "../tools/deep-verify-helpers.js";

const TWO_MIB = 2 * 1024 * 1024;

test("AC-004: an artifact absent on disk is classified missing without throwing (verdict fail)", () => {
  const fx = seedDeepVerifyRepo("deep-verify-missing");
  try {
    const bundle = fx.baseBundle();
    const missingRel = `specs/${fx.feature}/does-not-exist.md`;
    (bundle.artifacts as Array<{ path: string; sha256: string }>).push({
      path: missingRel,
      // A well-formed recorded sha so the missing-file path (not
      // invalid-recorded-sha) is exercised.
      sha256: "0".repeat(64),
    });
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const missing = result.data.artifacts.find((a) => a.path === missingRel);
    assert.equal(missing?.status, "missing");
    assert.equal(missing?.computedSha256, undefined);
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-005: an oversize artifact is too-large and an allowlist-escaping path is path-denied (no throw)", () => {
  const fx = seedDeepVerifyRepo("deep-verify-toolarge-denied");
  try {
    const bigRel = `specs/${fx.feature}/big.md`;
    writeFile(fx.dir, bigRel, "a".repeat(TWO_MIB + 1));

    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    artifacts.push({ path: bigRel, sha256: "0".repeat(64) });
    // Absolute path escapes the allowlist at the path-guard shape check.
    artifacts.push({ path: "/etc/passwd", sha256: "0".repeat(64) });
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const big = result.data.artifacts.find((a) => a.path === bigRel);
    assert.equal(big?.status, "too-large");

    const denied = result.data.artifacts.find((a) => a.path === "/etc/passwd");
    assert.equal(denied?.status, "path-denied");

    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-017: a non-64-hex recorded sha is invalid-recorded-sha (not mismatch) even when the file exists", () => {
  const fx = seedDeepVerifyRepo("deep-verify-invalid-sha");
  try {
    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    // The real file exists, but the recorded sha is malformed.
    const target = artifacts.find((a) => a.path === fx.artifactRel);
    assert.ok(target !== undefined);
    target!.sha256 = "not-a-valid-sha";
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const invalid = result.data.artifacts.find((a) => a.path === fx.artifactRel);
    assert.equal(invalid?.status, "invalid-recorded-sha");
    assert.notEqual(invalid?.status, "mismatch");
    // AC-017: the disk file is not read for an invalid recorded sha.
    assert.equal(invalid?.computedSha256, undefined);
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-017: a malformed recorded sha co-occurring with a missing file still converges to invalid-recorded-sha + fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-invalid-sha-compound");
  try {
    const bundle = fx.baseBundle();
    const compoundRel = `specs/${fx.feature}/also-missing.md`;
    (bundle.artifacts as Array<{ path: string; sha256: string }>).push({
      path: compoundRel,
      sha256: "",
    });
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const compound = result.data.artifacts.find((a) => a.path === compoundRel);
    // Invalid recorded sha takes precedence over the missing-file classification.
    assert.equal(compound?.status, "invalid-recorded-sha");
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});
