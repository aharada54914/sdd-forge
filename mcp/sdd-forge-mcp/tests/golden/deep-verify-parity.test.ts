/**
 * AC-012 (T-005, ADR-0009): host-script parity goldens. For each of four
 * fixture classes — consistent bundle (pass), tampered on-disk artifact
 * (fail), spec drift on a high-risk bundle (fail), tampered recorded
 * artifact hash (fail) — this asserts that the real
 * `check-evidence-bundle.sh` and `evidenceDeepVerify()` agree on pass vs.
 * fail for the exact same bundle + on-disk artifact state.
 *
 * Only this test file (via `deep-verify-parity-helpers.ts`) ever shells out
 * to git or `check-evidence-bundle.sh` — `evidence_deep_verify` itself never
 * spawns a subprocess (ADR-0008; also exercised statically by
 * `tests/readonly`). Every fixture is a throwaway, git-backed synthetic SDD
 * root; none of its content is derived from real repository files (REQ-009).
 *
 * "Spec drift" is modeled as a `risk: "high"` bundle whose recorded
 * `spec_revision` is `""` even though `specs/<feature>/{requirements,
 * design,acceptance-tests}.md` exist on disk (i.e. the bundle predates the
 * spec files / was never regenerated after they were added). This is the
 * one dimension where `check-evidence-bundle.sh` and `evidenceDeepVerify()`
 * reach the same "fail" conclusion via genuinely different logic:
 * `check-evidence-bundle.sh` never recomputes `spec_revision` from the spec
 * files at all — for `high`/`critical` risk it only enforces that the
 * *recorded* value is present and 64-hex-shaped (an empty string fails that
 * shape check), while `evidenceDeepVerify()` recomputes the canonical value
 * and compares it to the recorded one directly (REQ-005). A low-risk bundle
 * would not exercise this on the host side at all, since
 * `check-evidence-bundle.sh` only gates `spec_revision` for `high`/`critical`
 * bundles.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { writeFile } from "../test-helpers.js";
import {
  buildParityFixtureBase,
  readBundleJson,
  runCheckEvidenceBundle,
  type ParityFixtureFiles,
} from "./deep-verify-parity-helpers.js";

/**
 * Runs both sides against the same fixture and asserts they agree with each
 * other *and* with the fixture's intended verdict — the latter guards
 * against a fixture-construction bug that happens to make both sides wrong
 * in the same direction.
 */
function assertHostAndToolAgree(fx: ParityFixtureFiles, expectedVerdict: "pass" | "fail"): void {
  const shellResult = runCheckEvidenceBundle(fx.dir, fx.bundleRel);
  const hostVerdict = shellResult.exitCode === 0 ? "pass" : "fail";
  assert.equal(
    hostVerdict,
    expectedVerdict,
    `check-evidence-bundle.sh verdict mismatch for ${fx.taskId} ` +
      `(exit ${shellResult.exitCode}, expected ${expectedVerdict}): ${shellResult.combinedOutput}`,
  );

  const toolResult = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
  assert.equal(
    toolResult.ok,
    true,
    `evidenceDeepVerify envelope error for ${fx.taskId}: ${
      toolResult.ok ? "" : JSON.stringify(toolResult.error)
    }`,
  );
  if (!toolResult.ok) {
    return;
  }
  assert.equal(
    toolResult.data.verdict,
    expectedVerdict,
    `evidenceDeepVerify verdict mismatch for ${fx.taskId}: failures=${JSON.stringify(toolResult.data.failures)}`,
  );

  assert.equal(toolResult.data.verdict, hostVerdict, `host/tool disagreement for ${fx.taskId}`);
}

test("AC-012: consistent bundle -- check-evidence-bundle.sh and evidence_deep_verify both pass", () => {
  const fx = buildParityFixtureBase("golden-parity-pass", "golden-parity", "T-900");
  try {
    assertHostAndToolAgree(fx, "pass");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-012: tampered on-disk artifact -- check-evidence-bundle.sh and evidence_deep_verify both fail", () => {
  const fx = buildParityFixtureBase("golden-parity-tamper-disk", "golden-parity", "T-901");
  try {
    // Tamper the on-disk file only; the bundle's recorded sha256 is
    // unchanged, so recorded != on-disk on both the host and tool side.
    writeFile(fx.dir, fx.artifactRel, `${fx.artifactContents}TAMPERED\n`);
    assertHostAndToolAgree(fx, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-012: spec drift on a high-risk bundle -- check-evidence-bundle.sh and evidence_deep_verify both fail", () => {
  const fx = buildParityFixtureBase("golden-parity-spec-drift", "golden-parity", "T-902", {
    risk: "high",
    specRevisionOverride: "",
  });
  try {
    assertHostAndToolAgree(fx, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-012: tampered recorded artifact hash -- check-evidence-bundle.sh and evidence_deep_verify both fail", () => {
  const fx = buildParityFixtureBase("golden-parity-tamper-recorded", "golden-parity", "T-903");
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

    assertHostAndToolAgree(fx, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});
