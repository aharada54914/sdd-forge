/** Synthetic bundles shared by the recorded and live historical AC-012 comparisons. */

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { makeTempSddRoot, writeFile, type TempSddRoot } from "../test-helpers.js";

/** SHA-256 hex of a UTF-8 string — mirrors the tool's `sha256OfContents`. */
export function sha256Of(contents: string): string {
  return createHash("sha256").update(contents, "utf-8").digest("hex");
}

/**
 * `git init`s a fixture directory, commits its current contents with a fixed
 * throwaway identity (no dependency on the host's global git config —
 * `commit.gpgsign` is explicitly disabled so a machine with global signing
 * configured cannot hang this test waiting for a passphrase), and returns
 * the resulting 40-hex `HEAD` commit — a real, resolvable git object that
 * `check-evidence-bundle.sh`'s `git cat-file -e` / `merge-base
 * --is-ancestor` checks can validate.
 */
function commitFixture(dir: string): string {
  const runGit = (args: string[]): void => {
    execFileSync("git", ["-C", dir, ...args], { stdio: ["ignore", "pipe", "pipe"] });
  };
  runGit(["init", "--quiet"]);
  runGit(["add", "-A"]);
  runGit([
    "-c",
    "commit.gpgsign=false",
    "-c",
    "user.email=golden-fixture@sdd-forge.local",
    "-c",
    "user.name=Golden Fixture",
    "commit",
    "--quiet",
    "-m",
    "golden fixture baseline",
  ]);
  return execFileSync("git", ["-C", dir, "rev-parse", "HEAD"], { encoding: "utf-8" }).trim();
}

/**
 * Baseline check ids required by `check-contract.sh`'s required-set
 * protection pass (`plugins/sdd-quality-loop/scripts/check-contract.py`'s
 * `BASELINE_IDS`), downgraded to `required: false` with a non-empty
 * `waiver_reason` so the synthetic contract passes `check-contract.sh`
 * cleanly without needing real lint/build/test tooling output inside a
 * throwaway fixture repo. This keeps contract validation orthogonal to the
 * per-fixture tamper this suite is actually exercising.
 */
const BASELINE_CHECK_IDS = [
  "lint",
  "typecheck",
  "unit-tests",
  "build",
  "placeholder-scan",
  "task-state-check",
] as const;

function waivedBaselineChecks(): Array<Record<string, unknown>> {
  return BASELINE_CHECK_IDS.map((id) => ({
    id,
    required: false,
    passes: false,
    waiver_reason: "golden fixture: synthetic repo has no live tooling to run this check",
  }));
}

export interface ParityFixtureOptions {
  /** Reuse the recorded host input when replaying without a Git checkout. */
  fixtureCommit?: string;
  /** Bundle `risk` field. Defaults to `"low"`. */
  risk?: string;
  /**
   * Overrides the bundle's recorded `spec_revision`. Omit to use the
   * correctly-recomputed value (matching `specs/<feature>/{requirements,
   * design,acceptance-tests}.md`'s actual on-disk content, host
   * `compute_spec_revision` formula, ADR-0009). Pass `""` to simulate a
   * stale/drifted bundle recorded before the spec files existed.
   */
  specRevisionOverride?: string;
}

export interface ParityFixtureFiles {
  feature: string;
  taskId: string;
  tempRoot: TempSddRoot;
  dir: string;
  reportRel: string;
  reportContents: string;
  contractRel: string;
  contractContents: string;
  artifactRel: string;
  artifactContents: string;
  requirementsRel: string;
  designRel: string;
  acceptanceRel: string;
  bundleRel: string;
  gitCommit: string;
}

/**
 * Builds a temp SDD root containing a fully self-consistent
 * evidence bundle: every artifact's recorded sha256 matches its on-disk
 * contents, the quality report and contract cross-bind to the bundle,
 * `git_commit` comes from the host fixture recording or a fresh fixture
 * commit for live historical replay, and `specs/<feature>/{requirements,design,
 * acceptance-tests}.md` exist so the recomputed `spec_revision` is
 * non-empty and (by default) matches the recorded value.
 *
 * Callers layer a tamper on top by either mutating the returned files
 * in-place (on-disk artifact content — `writeFile` from
 * `tests/test-helpers.ts`) or the written bundle JSON (recorded sha256), or
 * by passing `specRevisionOverride` up front (recorded spec_revision).
 */
export function buildParityFixtureBase(
  prefix: string,
  feature: string,
  taskId: string,
  options: ParityFixtureOptions = {},
): ParityFixtureFiles {
  const tempRoot = makeTempSddRoot(prefix);
  const dir = tempRoot.dir;
  const risk = options.risk ?? "low";

  const requirementsRel = `specs/${feature}/requirements.md`;
  const requirementsContents = `# Requirements: ${feature}\n\nSynthetic golden fixture requirements body.\n`;
  writeFile(dir, requirementsRel, requirementsContents);

  const designRel = `specs/${feature}/design.md`;
  const designContents = `# Design: ${feature}\n\nSynthetic golden fixture design body.\n`;
  writeFile(dir, designRel, designContents);

  const acceptanceRel = `specs/${feature}/acceptance-tests.md`;
  const acceptanceContents = `# Acceptance Tests: ${feature}\n\nSynthetic golden fixture acceptance body.\n`;
  writeFile(dir, acceptanceRel, acceptanceContents);

  // Mirrors `compute_spec_revision` (generate-evidence-bundle.sh, ADR-0009
  // point (3)): SHA-256 of the three files' bytes concatenated in this
  // order.
  const computedSpecRevision = sha256Of(requirementsContents + designContents + acceptanceContents);

  const artifactRel = `specs/${feature}/artifact.md`;
  const artifactContents = "# Artifact\n\nGolden fixture artifact body.\n";
  writeFile(dir, artifactRel, artifactContents);

  const reportRel = `reports/quality-gate/${feature}-${taskId}.md`;
  const reportContents = [
    `# Quality Gate — ${taskId}`,
    "",
    `Task ID: ${taskId}`,
    `Feature: ${feature}`,
    "",
    "VERDICT: PASS",
    "Critical: 0",
    "Major: 0",
    "Minor: 0",
    "",
  ].join("\n");
  writeFile(dir, reportRel, reportContents);

  const contractRel = `specs/${feature}/verification/${taskId}.contract.json`;
  const contractContents = JSON.stringify({
    task_id: taskId,
    feature,
    checks: waivedBaselineChecks(),
  });
  writeFile(dir, contractRel, contractContents);

  const gitCommit = options.fixtureCommit ?? commitFixture(dir);

  const bundleRel = `specs/${feature}/verification/${taskId}.evidence.json`;
  const specRevision = options.specRevisionOverride ?? computedSpecRevision;

  const bundle: Record<string, unknown> = {
    task_id: taskId,
    feature,
    risk,
    required_workflow: "tdd",
    spec_revision: specRevision,
    quality_report: reportRel,
    verification_contract: contractRel,
    git_commit: gitCommit,
    git_generated_dirty: false,
    build_env: { os: process.platform, python: "", git: "", lockfile_sha256: null },
    review_verdict: { verdict: "PASS", critical: 0, major: 0, minor: 0, reviewer: "sdd-evaluator" },
    artifacts: [
      { path: reportRel, sha256: sha256Of(reportContents) },
      { path: contractRel, sha256: sha256Of(contractContents) },
      { path: artifactRel, sha256: sha256Of(artifactContents) },
    ],
  };
  writeFile(dir, bundleRel, JSON.stringify(bundle, null, 2));

  return {
    feature,
    taskId,
    tempRoot,
    dir,
    reportRel,
    reportContents,
    contractRel,
    contractContents,
    artifactRel,
    artifactContents,
    requirementsRel,
    designRel,
    acceptanceRel,
    bundleRel,
    gitCommit,
  };
}

/** Reads and parses a fixture's evidence bundle JSON from disk. */
export function readBundleJson(fx: ParityFixtureFiles): Record<string, unknown> {
  return JSON.parse(readFileSync(join(fx.dir, fx.bundleRel), "utf-8")) as Record<string, unknown>;
}
