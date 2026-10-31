/**
 * Shared (non-test) helpers for the T-001 evidence_deep_verify suites.
 * Deliberately not named `*.test.ts` so `scripts/run-tests.mjs` (which globs
 * `*.test.js`) does not execute it as a test file.
 *
 * `seedDeepVerifyRepo` writes a fully consistent evidence bundle into a fresh
 * temp SDD root: every recorded artifact's on-disk sha256 matches, the
 * quality report and contract cross-bind to the bundle, git_commit is 40-hex,
 * and no `specs/<feature>/{requirements,design,acceptance-tests}.md` exist so
 * the recomputed spec_revision is `""` (matching the omitted recorded value).
 * A caller can then tamper with one dimension and rewrite the bundle to drive
 * a specific failure classification.
 */

import { createHash } from "node:crypto";
import { makeTempSddRoot, writeFile, type TempSddRoot } from "../test-helpers.js";

export const DEEP_VERIFY_FEATURE = "demo";
export const DEEP_VERIFY_TASK_ID = "T-001";

/** SHA-256 hex of a UTF-8 string — mirrors the tool's `sha256OfContents`. */
export function sha256Of(contents: string): string {
  return createHash("sha256").update(contents, "utf-8").digest("hex");
}

export interface DeepVerifyFixture {
  tempRoot: TempSddRoot;
  dir: string;
  feature: string;
  taskId: string;
  artifactRel: string;
  artifactContents: string;
  contractRel: string;
  contractContents: string;
  reportRel: string;
  reportContents: string;
  bundleRel: string;
  /** Serializes and writes a bundle object to the canonical evidence path. */
  writeBundle: (bundle: unknown) => void;
  /** A fresh copy of the fully consistent baseline bundle object. */
  baseBundle: () => Record<string, unknown>;
}

/**
 * Creates a temp SDD root pre-populated with a consistent bundle and writes
 * that bundle to disk. The returned handles let a test tamper with the disk
 * artifact, the recorded shas, or the invariants and rewrite the bundle.
 */
export function seedDeepVerifyRepo(prefix: string): DeepVerifyFixture {
  const feature = DEEP_VERIFY_FEATURE;
  const taskId = DEEP_VERIFY_TASK_ID;
  const tempRoot = makeTempSddRoot(prefix);
  const dir = tempRoot.dir;

  const artifactRel = `specs/${feature}/artifact.md`;
  const artifactContents = "# Artifact\n\nDeterministic body line.\n";
  writeFile(dir, artifactRel, artifactContents);

  const reportRel = `reports/quality-gate/${feature}-${taskId}.md`;
  const reportContents = [
    `# Quality Gate — ${taskId}`,
    "",
    `Task ID: ${taskId}`,
    `Feature: ${feature}`,
    "",
    "VERDICT: PASS",
    "",
  ].join("\n");
  writeFile(dir, reportRel, reportContents);

  const contractRel = `specs/${feature}/verification/${taskId}.contract.json`;
  const contractContents = JSON.stringify({
    task_id: taskId,
    feature,
    risk: "low",
    required_workflow: "tdd",
    checks: [],
  });
  writeFile(dir, contractRel, contractContents);

  const bundleRel = `specs/${feature}/verification/${taskId}.evidence.json`;
  const writeBundle = (bundle: unknown): void => {
    writeFile(dir, bundleRel, JSON.stringify(bundle, null, 2));
  };

  const baseBundle = (): Record<string, unknown> => ({
    task_id: taskId,
    feature,
    risk: "low",
    required_workflow: "tdd",
    quality_report: reportRel,
    verification_contract: contractRel,
    git_commit: "0".repeat(40),
    git_generated_dirty: false,
    artifacts: [
      { path: reportRel, sha256: sha256Of(reportContents) },
      { path: contractRel, sha256: sha256Of(contractContents) },
      { path: artifactRel, sha256: sha256Of(artifactContents) },
    ],
  });

  writeBundle(baseBundle());

  return {
    tempRoot,
    dir,
    feature,
    taskId,
    artifactRel,
    artifactContents,
    contractRel,
    contractContents,
    reportRel,
    reportContents,
    bundleRel,
    writeBundle,
    baseBundle,
  };
}
