/**
 * evidence_deep_verify internal invariants (T-002) — spec_revision recompute,
 * git_commit shape-only validation, and contract/report cross-binding.
 *
 * These drive the pure `evidenceDeepVerify(root, feature, taskId)` function
 * directly (server.ts registration is T-004) and assert on the returned
 * envelope's `data`.
 *
 * - AC-006: a spec file drifts -> `specRevision.status: "mismatch"` (computed
 *   holds the recompute value, `filesHashed` the concatenated spec files) and
 *   `verdict: "fail"`.
 * - AC-007: a non-40-hex `git_commit` (missing / short / non-hex) ->
 *   `gitCommit.shapeValid: false` and `verdict: "fail"`.
 * - AC-008: a well-formed 40-hex not in the repo (foreign/future) ->
 *   `gitCommit.shapeValid: true`, `ancestryVerified: false`, echoed `value`,
 *   host-deferred `reason`; ancestry never drags the verdict down, and NO
 *   git subprocess is spawned (ADR-0008 no-exec boundary).
 * - AC-009: `verification_contract` task_id / feature != bundle -> that
 *   `crossBindings[]` `status: "mismatch"` and `verdict: "fail"`.
 * - AC-010: `quality_report` `Task ID:` / `Feature:` != bundle, or an
 *   unreadable report -> that `crossBindings[]` `status: "mismatch"` and
 *   `verdict: "fail"`.
 * - AC-019: all three `specs/<feature>/{requirements,design,acceptance-tests}.md`
 *   absent -> `spec_revision` recomputes to `""`; a `""` recorded value is
 *   `"match"`, a non-empty recorded value is `"mismatch"` + `verdict: "fail"`.
 *   File absence never throws.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { rmSync } from "node:fs";
import { join } from "node:path";
import { writeFile } from "../test-helpers.js";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { seedDeepVerifyRepo, sha256Of, type DeepVerifyFixture } from "./deep-verify-helpers.js";

/**
 * child_process entry points that could launch a git subprocess. AC-008 /
 * ADR-0008 forbid any of them during evidence_deep_verify.
 */
const CHILD_PROCESS_METHODS = [
  "spawn",
  "spawnSync",
  "exec",
  "execSync",
  "execFile",
  "execFileSync",
  "fork",
] as const;

type MutableChildProcess = Record<string, (...args: unknown[]) => unknown>;

/**
 * Runs `fn` with every child_process spawn/exec entry point replaced by a trap
 * that records the call and throws. Returns the function's value plus the list
 * of any intercepted method names. The traps are always restored.
 */
function runWithChildProcessTrap<T>(fn: () => T): { value: T; spawned: string[] } {
  const cp = childProcess as unknown as MutableChildProcess;
  const spawned: string[] = [];
  const originals = new Map<string, (...args: unknown[]) => unknown>();
  for (const name of CHILD_PROCESS_METHODS) {
    originals.set(name, cp[name]);
    cp[name] = (..._args: unknown[]): never => {
      spawned.push(name);
      throw new Error(`evidence_deep_verify must not call child_process.${name}`);
    };
  }
  try {
    return { value: fn(), spawned };
  } finally {
    for (const name of CHILD_PROCESS_METHODS) {
      const original = originals.get(name);
      if (original) {
        cp[name] = original;
      }
    }
  }
}

/**
 * Writes the three spec files under `specs/<feature>/` and returns the
 * `spec_revision` a host `compute_spec_revision` (ADR-0009) would produce:
 * SHA-256 over the concatenated bytes of requirements.md, design.md,
 * acceptance-tests.md in that order.
 */
function seedSpecFiles(
  fx: DeepVerifyFixture,
  contents: { requirements: string; design: string; acceptance: string },
): string {
  writeFile(fx.dir, `specs/${fx.feature}/requirements.md`, contents.requirements);
  writeFile(fx.dir, `specs/${fx.feature}/design.md`, contents.design);
  writeFile(fx.dir, `specs/${fx.feature}/acceptance-tests.md`, contents.acceptance);
  return sha256Of(contents.requirements + contents.design + contents.acceptance);
}

// --- AC-006: spec drift -----------------------------------------------------

test("AC-006: a drifted spec file maps to specRevision mismatch (recompute + filesHashed) + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-spec-drift");
  try {
    const recorded = seedSpecFiles(fx, {
      requirements: "# Requirements\n\nR1.\n",
      design: "# Design\n\nD1.\n",
      acceptance: "# Acceptance\n\nA1.\n",
    });
    const bundle = fx.baseBundle();
    bundle.spec_revision = recorded;
    fx.writeBundle(bundle);

    // Sanity: recorded value matches before drift.
    const before = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(before.ok, true);
    if (before.ok) {
      assert.equal(before.data.invariants.specRevision.status, "match");
    }

    // Drift the middle spec file on disk; the recorded value is now stale.
    const drifted = seedSpecFiles(fx, {
      requirements: "# Requirements\n\nR1.\n",
      design: "# Design\n\nD1 tampered.\n",
      acceptance: "# Acceptance\n\nA1.\n",
    });
    assert.notEqual(drifted, recorded);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const specRevision = result.data.invariants.specRevision;
    assert.equal(specRevision.status, "mismatch");
    assert.equal(specRevision.recorded, recorded);
    assert.equal(specRevision.computed, drifted);
    assert.deepEqual(specRevision.filesHashed, [
      `specs/${fx.feature}/requirements.md`,
      `specs/${fx.feature}/design.md`,
      `specs/${fx.feature}/acceptance-tests.md`,
    ]);
    assert.equal(result.data.verdict, "fail");
    assert.ok(result.data.failures.some((f) => f.includes("spec_revision")));
  } finally {
    fx.tempRoot.cleanup();
  }
});

// --- AC-007: malformed git_commit shape -------------------------------------

for (const malformed of [
  { label: "missing", value: undefined },
  { label: "short", value: "0".repeat(39) },
  { label: "too-long", value: "0".repeat(41) },
  { label: "non-hex", value: `g${"0".repeat(39)}` },
  { label: "uppercase", value: "A".repeat(40) },
]) {
  test(`AC-007: a ${malformed.label} git_commit is shape-invalid + verdict fail`, () => {
    const fx = seedDeepVerifyRepo(`deep-verify-git-${malformed.label}`);
    try {
      const bundle = fx.baseBundle();
      if (malformed.value === undefined) {
        delete bundle.git_commit;
      } else {
        bundle.git_commit = malformed.value;
      }
      fx.writeBundle(bundle);

      const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
      assert.equal(result.ok, true);
      if (!result.ok) {
        return;
      }
      assert.equal(result.data.invariants.gitCommit.shapeValid, false);
      assert.equal(result.data.invariants.gitCommit.ancestryVerified, false);
      assert.equal(result.data.verdict, "fail");
      assert.ok(result.data.failures.some((f) => f.includes("git_commit")));
    } finally {
      fx.tempRoot.cleanup();
    }
  });
}

// --- AC-008: foreign 40-hex, ancestry host-deferred, no git subprocess ------

test("AC-008: a foreign well-formed 40-hex is shapeValid with ancestryVerified false and does not fail the verdict", () => {
  const fx = seedDeepVerifyRepo("deep-verify-git-foreign");
  try {
    const foreign = "f".repeat(40); // 40-hex, not a commit in any repo
    const bundle = fx.baseBundle();
    bundle.git_commit = foreign;
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const gitCommit = result.data.invariants.gitCommit;
    assert.equal(gitCommit.shapeValid, true);
    assert.equal(gitCommit.ancestryVerified, false);
    assert.equal(gitCommit.value, foreign);
    assert.match(gitCommit.reason, /host-deferred/);
    // Ancestry is unknown but must not drag the verdict down (all else holds).
    assert.equal(result.data.verdict, "pass");
    assert.ok(result.data.failures.every((f) => !f.includes("git_commit")));
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-008: evidence_deep_verify never spawns a git subprocess (no-exec boundary, ADR-0008)", () => {
  const fx = seedDeepVerifyRepo("deep-verify-no-exec");
  try {
    const bundle = fx.baseBundle();
    // A foreign 40-hex is exactly the case a naive impl might try to resolve
    // via `git cat-file` / `git merge-base` — assert it does not.
    bundle.git_commit = "a".repeat(40);
    fx.writeBundle(bundle);

    const { value: result, spawned } = runWithChildProcessTrap(() =>
      evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId),
    );

    assert.deepEqual(spawned, [], "no child_process entry point may be called");
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    assert.equal(result.data.invariants.gitCommit.shapeValid, true);
    assert.equal(result.data.invariants.gitCommit.ancestryVerified, false);
  } finally {
    fx.tempRoot.cleanup();
  }
});

// --- AC-009: verification_contract cross-binding ----------------------------

test("AC-009: a verification_contract task_id mismatch maps to crossBinding mismatch + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-contract-taskid");
  try {
    // Rewrite the contract with a foreign task_id, then re-record its artifact
    // sha so ONLY the cross-binding (not an artifact digest) drives the fail.
    const contract = JSON.stringify({
      task_id: "T-999",
      feature: fx.feature,
      risk: "low",
      required_workflow: "tdd",
      checks: [],
    });
    writeFile(fx.dir, fx.contractRel, contract);

    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    const contractArtifact = artifacts.find((a) => a.path === fx.contractRel);
    assert.ok(contractArtifact !== undefined);
    contractArtifact!.sha256 = sha256Of(contract);
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const binding = result.data.invariants.crossBindings.find((b) => b.subject === "verification_contract");
    assert.ok(binding !== undefined);
    assert.equal(binding?.status, "mismatch");
    assert.match(binding?.detail ?? "", /task_id/);
    assert.equal(result.data.verdict, "fail");
    assert.ok(result.data.failures.some((f) => f.includes("verification_contract")));
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-009: a verification_contract feature mismatch maps to crossBinding mismatch + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-contract-feature");
  try {
    const contract = JSON.stringify({
      task_id: fx.taskId,
      feature: "some-other-feature",
      risk: "low",
      required_workflow: "tdd",
      checks: [],
    });
    writeFile(fx.dir, fx.contractRel, contract);

    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    const contractArtifact = artifacts.find((a) => a.path === fx.contractRel);
    contractArtifact!.sha256 = sha256Of(contract);
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const binding = result.data.invariants.crossBindings.find((b) => b.subject === "verification_contract");
    assert.equal(binding?.status, "mismatch");
    assert.match(binding?.detail ?? "", /feature/);
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

// --- AC-010: quality_report cross-binding -----------------------------------

test("AC-010: a quality_report Task ID mismatch maps to crossBinding mismatch + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-report-taskid");
  try {
    const report = [
      `# Quality Gate — ${fx.taskId}`,
      "",
      "Task ID: T-999",
      `Feature: ${fx.feature}`,
      "",
      "VERDICT: PASS",
      "",
    ].join("\n");
    writeFile(fx.dir, fx.reportRel, report);

    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    const reportArtifact = artifacts.find((a) => a.path === fx.reportRel);
    reportArtifact!.sha256 = sha256Of(report);
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const binding = result.data.invariants.crossBindings.find((b) => b.subject === "quality_report");
    assert.equal(binding?.status, "mismatch");
    assert.match(binding?.detail ?? "", /Task ID/);
    assert.equal(result.data.verdict, "fail");
    assert.ok(result.data.failures.some((f) => f.includes("quality_report")));
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-010: a quality_report Feature mismatch maps to crossBinding mismatch + verdict fail", () => {
  const fx = seedDeepVerifyRepo("deep-verify-report-feature");
  try {
    const report = [
      `# Quality Gate — ${fx.taskId}`,
      "",
      `Task ID: ${fx.taskId}`,
      "Feature: not-the-bundle-feature",
      "",
      "VERDICT: PASS",
      "",
    ].join("\n");
    writeFile(fx.dir, fx.reportRel, report);

    const bundle = fx.baseBundle();
    const artifacts = bundle.artifacts as Array<{ path: string; sha256: string }>;
    const reportArtifact = artifacts.find((a) => a.path === fx.reportRel);
    reportArtifact!.sha256 = sha256Of(report);
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const binding = result.data.invariants.crossBindings.find((b) => b.subject === "quality_report");
    assert.equal(binding?.status, "mismatch");
    assert.match(binding?.detail ?? "", /Feature/);
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-010: an unreadable quality_report maps to crossBinding mismatch + verdict fail (no throw)", () => {
  const fx = seedDeepVerifyRepo("deep-verify-report-unreadable");
  try {
    // Delete the report and drop it from artifacts so only the cross-binding
    // (unreadable report), not a missing artifact, is under test.
    rmSync(join(fx.dir, fx.reportRel));
    const bundle = fx.baseBundle();
    bundle.artifacts = (bundle.artifacts as Array<{ path: string }>).filter(
      (a) => a.path !== fx.reportRel,
    );
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const binding = result.data.invariants.crossBindings.find((b) => b.subject === "quality_report");
    assert.equal(binding?.status, "mismatch");
    assert.match(binding?.detail ?? "", /unreadable/);
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});

// --- AC-019: absent specs -> canonical "" spec_revision ---------------------

test("AC-019: all specs absent with recorded spec_revision '' is a match (no throw)", () => {
  // The baseline fixture writes NO requirements/design/acceptance-tests.md and
  // omits spec_revision, so recorded and computed are both "".
  const fx = seedDeepVerifyRepo("deep-verify-absent-specs-match");
  try {
    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const specRevision = result.data.invariants.specRevision;
    assert.equal(specRevision.computed, "");
    assert.equal(specRevision.recorded, "");
    assert.equal(specRevision.status, "match");
    assert.deepEqual(specRevision.filesHashed, []);
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-019: all specs absent with a non-empty recorded spec_revision is a mismatch + verdict fail (no throw)", () => {
  const fx = seedDeepVerifyRepo("deep-verify-absent-specs-mismatch");
  try {
    const bundle = fx.baseBundle();
    bundle.spec_revision = "a".repeat(64); // non-empty recorded value, no spec files
    fx.writeBundle(bundle);

    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const specRevision = result.data.invariants.specRevision;
    assert.equal(specRevision.computed, "");
    assert.equal(specRevision.recorded, "a".repeat(64));
    assert.equal(specRevision.status, "mismatch");
    assert.equal(result.data.verdict, "fail");
  } finally {
    fx.tempRoot.cleanup();
  }
});
