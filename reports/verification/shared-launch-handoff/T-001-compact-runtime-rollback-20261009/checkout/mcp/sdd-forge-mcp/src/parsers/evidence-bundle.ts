/**
 * Evidence bundle validation — shell-equivalent of
 * `plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh` (the Python
 * implementation branch), reproduced as pure TypeScript so `tasks.ts` can
 * decide a `Done` task's verdict without spawning a child process.
 *
 * This is read-only reference material re-implemented for parity with the
 * shell script; the shell script itself is never modified or shelled out to
 * from this module (only test code under tests/golden may invoke it).
 *
 * Two deliberate simplifications are documented at their call sites because
 * they cannot be reproduced without shelling out, and — verified against
 * every evidence bundle currently under version control in this repo — do
 * not change the verdict for any of them:
 *   1. check-contract.sh's own validation of the verification contract is
 *      not re-run; only the contract's JSON shape / task_id match (the part
 *      check-evidence-bundle.sh checks directly) is verified here.
 *   2. `git merge-base --is-ancestor` is not run; only git_commit's 40-hex
 *      shape is validated (ancestry is assumed true).
 */

import { createHash } from "node:crypto";
import { guardedExists, guardedRead } from "../path-guard.js";
import type { SddRoot } from "../root.js";

const SHA256_HEX_PATTERN = /^[a-f0-9]{64}$/;

/**
 * Raw shapes shared with `evidence.ts` (T-011's structured-data extraction
 * parsers): both modules read the same `T-*.evidence.json` /
 * `T-*.contract.json` file shapes, so the field-level interfaces are defined
 * once here and re-exported rather than duplicated. Only these *type*
 * declarations are shared — `verifyEvidenceBundle`'s validation logic below
 * is untouched by T-011.
 */
export interface ContractCheck {
  id?: string;
  required?: boolean;
  passes?: boolean;
  evidence?: string;
  waiver_reason?: string;
  requirement_ids?: string[];
  red_evidence?: string;
  green_evidence?: string;
}

export interface VerificationContract {
  task_id?: string;
  feature?: string;
  risk?: string;
  required_workflow?: string;
  checks?: ContractCheck[];
}

export interface EvidenceArtifact {
  path?: string;
  sha256?: string;
}

export interface EvidenceReviewVerdict {
  verdict?: string;
}

export interface EvidenceBuildEnv {
  os?: string;
}

export interface EvidenceSignature {
  alg?: string;
  value?: string;
}

export interface EvidenceBundle {
  task_id?: string;
  feature?: string;
  risk?: string;
  required_workflow?: string;
  quality_report?: string;
  verification_contract?: string;
  artifacts?: EvidenceArtifact[];
  git_commit?: string;
  git_generated_dirty?: boolean;
  spec_revision?: string;
  build_env?: EvidenceBuildEnv;
  review_verdict?: EvidenceReviewVerdict;
  signature?: EvidenceSignature;
}

/** Computes the sha256 hex digest of a guarded file's contents (used for artifact manifest checks). */
function sha256OfGuardedFile(root: SddRoot, relPath: string): string | undefined {
  const result = guardedRead(root, relPath);
  if (!result.ok) {
    return undefined;
  }
  return createHash("sha256").update(result.data.contents, "utf-8").digest("hex");
}

/**
 * Normalizes an artifact/report path recorded in an evidence bundle or
 * contract into a repo-relative, path-guard-checkable form. Returns
 * `undefined` if the raw value is missing, empty, absolute, or escapes the
 * root via `..` — mirroring check-evidence-bundle.sh's `normalize_rel_path`.
 */
function normalizeRelPath(raw: unknown): string | undefined {
  if (typeof raw !== "string") {
    return undefined;
  }
  let path = raw.trim().replace(/\\/g, "/");
  if (path.length === 0) {
    return undefined;
  }
  if (path.startsWith("/") || /^[A-Za-z]:/.test(path)) {
    return undefined;
  }
  if (/(^|\/)\.\.(\/|$)/.test(path)) {
    return undefined;
  }
  while (path.startsWith("./")) {
    path = path.slice(2);
  }
  return path.length > 0 ? path : undefined;
}

/**
 * Reproduces check-evidence-bundle.sh's validation of a Done task's evidence
 * bundle. Returns the list of shell-equivalent failure strings (empty when
 * the bundle passes). `bundleRelPath` must already be known to exist via
 * `guardedExists` before this is called.
 */
export function verifyEvidenceBundle(
  root: SddRoot,
  bundleRelPath: string,
  taskId: string,
): string[] {
  const failures: string[] = [];

  const bundleRead = guardedRead(root, bundleRelPath);
  if (!bundleRead.ok) {
    return [`evidence bundle is unreadable: ${bundleRelPath}`];
  }

  let bundle: EvidenceBundle;
  try {
    bundle = JSON.parse(bundleRead.data.contents) as EvidenceBundle;
  } catch {
    return [`evidence bundle is not valid JSON: ${bundleRelPath}`];
  }

  const bundleTaskId = String(bundle.task_id ?? "").trim();
  if (!/^T-\d+$/.test(bundleTaskId)) {
    failures.push(`task_id is invalid: ${bundleTaskId}`);
  }

  const artifacts = Array.isArray(bundle.artifacts) ? bundle.artifacts : [];
  if (!Array.isArray(bundle.artifacts)) {
    failures.push("artifacts must be an array");
  } else if (artifacts.length === 0) {
    failures.push("artifacts must not be empty");
  }

  const expectedBasename = `${taskId}.evidence.json`;
  if (!bundleRelPath.endsWith(`/${expectedBasename}`) && bundleRelPath !== expectedBasename) {
    failures.push(
      `bundle filename does not match task_id: ${bundleRelPath} vs ${bundleTaskId}`,
    );
  }

  const qualityRel = normalizeRelPath(bundle.quality_report);
  if (qualityRel === undefined) {
    failures.push("quality_report is missing or invalid");
  } else if (!guardedExists(root, qualityRel)) {
    failures.push(`quality_report missing: ${bundle.quality_report}`);
  } else if (!qualityRel.endsWith(".md")) {
    failures.push(`quality_report must point to a markdown report: ${bundle.quality_report}`);
  }

  const contractRel = normalizeRelPath(bundle.verification_contract);
  if (contractRel === undefined) {
    failures.push("verification_contract is missing or invalid");
  } else if (!guardedExists(root, contractRel)) {
    failures.push(`verification_contract missing: ${bundle.verification_contract}`);
  } else if (!contractRel.endsWith(".contract.json")) {
    failures.push(
      `verification_contract must point to a contract JSON file: ${bundle.verification_contract}`,
    );
  }

  let contract: VerificationContract | undefined;
  if (qualityRel !== undefined && guardedExists(root, qualityRel)) {
    const qualityRead = guardedRead(root, qualityRel);
    if (qualityRead.ok) {
      const text = qualityRead.data.contents;
      if (!new RegExp(`^Task ID:\\s*${taskId}\\s*$`, "m").test(text)) {
        failures.push(`quality_report missing Task ID: ${taskId}`);
      }
      if (!/^VERDICT:\s*PASS\s*$/m.test(text)) {
        failures.push("quality_report missing VERDICT: PASS");
      }
    }
  }

  if (contractRel !== undefined && guardedExists(root, contractRel)) {
    const contractRead = guardedRead(root, contractRel);
    if (!contractRead.ok) {
      failures.push(`verification_contract could not be read: ${bundle.verification_contract}`);
    } else {
      try {
        contract = JSON.parse(contractRead.data.contents) as VerificationContract;
      } catch {
        failures.push(
          `verification_contract could not be parsed as JSON: ${bundle.verification_contract}`,
        );
      }
      if (contract !== undefined) {
        const contractTaskId = String(contract.task_id ?? "").trim();
        if (contractTaskId !== taskId) {
          failures.push(
            `verification_contract task_id mismatch: ${contractTaskId} != ${taskId}`,
          );
        }
      }
      // NOTE: check-contract.sh's own validation of the contract is not
      // re-run here (see module doc, simplification 1) — this module only
      // reproduces check-evidence-bundle.sh's direct checks.
    }
  }

  const requiredArtifacts = new Map<string, string>();
  if (qualityRel !== undefined) {
    requiredArtifacts.set(qualityRel, "quality_report");
  }
  if (contractRel !== undefined) {
    requiredArtifacts.set(contractRel, "verification_contract");
  }
  if (contract?.checks !== undefined) {
    for (const check of contract.checks) {
      if (check.passes === true) {
        const evidenceRel = normalizeRelPath(check.evidence);
        if (evidenceRel !== undefined) {
          requiredArtifacts.set(
            evidenceRel,
            `passing evidence for check '${check.id ?? "?"}'`,
          );
        }
      }
    }
  }

  const artifactIndex = new Map<string, string>();
  for (const artifact of artifacts) {
    const artifactRel = normalizeRelPath(artifact.path);
    const sha = String(artifact.sha256 ?? "").trim().toLowerCase();
    if (artifactRel === undefined) {
      failures.push(`artifact path is missing or invalid: ${String(artifact.path)}`);
      continue;
    }
    if (!guardedExists(root, artifactRel)) {
      failures.push(`artifact path missing: ${artifact.path}`);
      continue;
    }
    if (!SHA256_HEX_PATTERN.test(sha)) {
      failures.push(`artifact sha256 is invalid for ${artifact.path}: ${artifact.sha256}`);
      continue;
    }
    if (artifactIndex.has(artifactRel)) {
      failures.push(`duplicate artifact path in manifest: ${artifactRel}`);
      continue;
    }
    artifactIndex.set(artifactRel, sha);
    const actualSha = sha256OfGuardedFile(root, artifactRel);
    if (actualSha !== sha) {
      failures.push(`artifact sha256 mismatch for ${artifactRel}`);
    }
  }

  for (const [requiredPath, label] of requiredArtifacts) {
    if (!artifactIndex.has(requiredPath)) {
      failures.push(`manifest is missing ${label}: ${requiredPath}`);
    }
  }

  // --- git_commit binding (shape only; ancestry is assumed — simplification 2) ---
  const gitCommit = bundle.git_commit;
  if (gitCommit === undefined || gitCommit === null) {
    failures.push("git_commit is required but missing");
  } else if (!/^[0-9a-f]{40}$/.test(String(gitCommit))) {
    failures.push(`git_commit is invalid (must be 40 lowercase hex): ${gitCommit}`);
  }

  // --- risk-tiered provenance ---
  const bundleRisk = String(bundle.risk ?? "").trim();
  const contractRisk = contract?.risk !== undefined ? String(contract.risk).trim() : "";
  if (contractRisk.length > 0 && contractRisk !== bundleRisk) {
    failures.push(
      `bundle risk '${bundleRisk || "(empty)"}' != contract risk '${contractRisk}'`,
    );
  }
  const effectiveRisk = contractRisk.length > 0 ? contractRisk : bundleRisk;

  if (effectiveRisk === "high" || effectiveRisk === "critical") {
    const specRevision = String(bundle.spec_revision ?? "").trim();
    if (!SHA256_HEX_PATTERN.test(specRevision)) {
      failures.push(
        `high/critical bundle requires spec_revision (64-hex), got: ${specRevision || "(empty)"}`,
      );
    }
    const buildEnvOs = bundle.build_env?.os;
    if (typeof buildEnvOs !== "string" || buildEnvOs.trim().length === 0) {
      failures.push("high/critical bundle requires build_env.os");
    }
    const reviewVerdict = bundle.review_verdict;
    if (reviewVerdict === undefined || reviewVerdict === null) {
      failures.push("high/critical bundle requires review_verdict object");
    } else if (String(reviewVerdict.verdict ?? "").trim() !== "PASS") {
      failures.push(
        `high/critical bundle requires review_verdict.verdict == PASS, got: ${reviewVerdict.verdict ?? "(empty)"}`,
      );
    }
  }

  if (effectiveRisk === "critical") {
    if (bundle.git_generated_dirty === true) {
      failures.push(
        "critical bundle must not be generated with a dirty working tree (git_generated_dirty=true)",
      );
    }
    const signature = bundle.signature;
    if (signature === undefined || signature === null) {
      failures.push("critical bundle requires a signature object");
    } else {
      const alg = String(signature.alg ?? "").trim();
      const value = String(signature.value ?? "").trim();
      if (alg.length === 0 || value.length === 0) {
        failures.push("critical bundle signature requires non-empty alg and value");
      } else if (alg === "hmac-sha256") {
        // This module never reads the evidence signing key (path-guard
        // denylists it), so an HMAC signature cannot be verified here; treat
        // as unverifiable and fail closed, matching the shell's fail-closed
        // posture when no key is available.
        failures.push(
          "critical bundle signature cannot be verified: no evidence key available",
        );
      } else if (alg === "sigstore") {
        failures.push(
          "critical bundle uses sigstore signature but SDD_EVIDENCE_SIGSTORE_VERIFIED is not set",
        );
      } else {
        failures.push(`critical bundle has unsupported signature alg: ${alg}`);
      }
    }
  }

  return failures;
}
