/**
 * Evidence tool implementations (5 tools) — pure functions of
 * `(root, feature, taskId?)` to `Result<...>`, mirroring `tools/core.ts`'s
 * shape so they can be unit-tested directly and wrapped by `server.ts` for
 * MCP registration.
 *
 * Canonical response shapes: contracts/sdd-forge-mcp-tools.v1.schema.json
 * (`evidenceBundleData`, `evidencePathsData`, `evidenceMissingData`,
 * `contractChecksSummaryData`, `traceabilityComparisonData`). Canonical tool
 * list: design.md "Architecture" (`tools/evidence.ts`) and
 * "API / Contract Plan".
 *
 * These tools never verify evidence-bundle signatures and never read signing
 * key material — `parseEvidenceBundle` already echoes `signature` as-is
 * (path-guard denylists the key file outright), and nothing in this module
 * changes that. `evidence_find_missing` reproduces the same Done-transition
 * requirements `task-validation.ts`'s `validateDoneEvidence` checks
 * (check-task-state.sh parity), so its `missing` list is empty for exactly
 * the tasks whose `Status: Done` transition `parseTaskState` already accepts.
 */

import { ok, type Result } from "../envelope.js";
import { validateFeature, validateTaskId } from "./core.js";
import {
  parseEvidenceBundle,
  parseVerificationContract,
  type ContractChecksSummaryEntry,
} from "../parsers/evidence.js";
import type { EvidenceArtifact, EvidenceBundle } from "../parsers/evidence-bundle.js";
import { anyFileContaining, hasQualityGateVerdictPass } from "../parsers/report-lookup.js";
import { parseTaskState } from "../parsers/tasks.js";
import { parseTraceability, type TraceabilityData } from "../parsers/traceability.js";
import { guardedExists, resolveGuarded } from "../path-guard.js";
import type { SddRoot } from "../root.js";

// --- evidence_get_bundle --------------------------------------------------

export interface EvidenceBundleData {
  kind: "evidence-bundle";
  feature: string;
  taskId: string;
  bundle: EvidenceBundle;
}

/**
 * `evidence_get_bundle`: reads and echoes
 * `specs/<feature>/verification/<taskId>.evidence.json` via
 * `parseEvidenceBundle` (T-011) without verifying its signature or reading
 * any signing key.
 */
export function evidenceGetBundle(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<EvidenceBundleData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  const taskIdResult = validateTaskId(taskId);
  if (!taskIdResult.ok) {
    return taskIdResult;
  }

  const bundleResult = parseEvidenceBundle(root, feature, taskId);
  if (!bundleResult.ok) {
    return bundleResult;
  }

  return ok({ kind: "evidence-bundle", feature, taskId, bundle: bundleResult.data });
}

// --- evidence_validate_paths -----------------------------------------------

export interface EvidencePathResult {
  path: string;
  safe: boolean;
  exists: boolean;
  reason?: string;
}

export interface EvidencePathsData {
  kind: "evidence-paths";
  feature: string;
  taskId: string;
  results: EvidencePathResult[];
}

/**
 * Classifies one artifact path recorded in an evidence bundle: `safe` is true
 * when the raw string is repo-relative (non-empty, not absolute, no `..`
 * segment, no backslash) and falls within path-guard's allowlisted
 * directories/files, independent of whether the file actually exists yet.
 * `exists` is a full path-guard existence check (`guardedExists`), which also
 * folds in the denylist and the 2 MiB size limit.
 */
function classifyArtifactPath(root: SddRoot, rawPath: string): EvidencePathResult {
  if (typeof rawPath !== "string" || rawPath.length === 0) {
    return { path: String(rawPath), safe: false, exists: false, reason: "path is missing or empty" };
  }

  const guardResult = resolveGuarded(root, rawPath);
  if (guardResult.ok) {
    return { path: rawPath, safe: true, exists: true };
  }

  // `not-found` / `too-large` mean the path shape, allowlist, and denylist
  // checks all passed — only existence/size failed, so the path is still
  // "safe" (repo-relative and within the allowlist), just not present (or
  // present but oversized, which guardedExists also reports as not-existing).
  const safe = guardResult.error.code === "not-found" || guardResult.error.code === "too-large";
  return {
    path: rawPath,
    safe,
    exists: safe && guardedExists(root, rawPath),
    reason: guardResult.error.message,
  };
}

/**
 * `evidence_validate_paths`: for every `artifacts[].path` recorded in
 * `<taskId>.evidence.json`, reports whether the path is safe (repo-relative,
 * no traversal, within the path-guard allowlist) and whether it currently
 * exists — without ever reading outside path-guard's own rules.
 */
export function evidenceValidatePaths(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<EvidencePathsData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  const taskIdResult = validateTaskId(taskId);
  if (!taskIdResult.ok) {
    return taskIdResult;
  }

  const bundleResult = parseEvidenceBundle(root, feature, taskId);
  if (!bundleResult.ok) {
    return bundleResult;
  }

  const artifacts: EvidenceArtifact[] = Array.isArray(bundleResult.data.artifacts)
    ? bundleResult.data.artifacts
    : [];
  const results = artifacts.map((artifact) => classifyArtifactPath(root, String(artifact.path ?? "")));

  return ok({ kind: "evidence-paths", feature, taskId, results });
}

// --- evidence_find_missing -------------------------------------------------

export interface EvidenceMissingData {
  kind: "evidence-missing";
  feature: string;
  taskId: string;
  required: string[];
  present: string[];
  missing: string[];
}

const EVIDENCE_BUNDLE_REQUIREMENT = "evidence-bundle";
const VERIFICATION_CONTRACT_REQUIREMENT = "verification-contract";
const QUALITY_GATE_REPORT_REQUIREMENT = "quality-gate-report-pass";

/**
 * `evidence_find_missing`: reports which Done-transition requirements
 * (check-task-state.sh's `validateDoneEvidence`, reproduced in
 * `task-validation.ts`) are present vs. missing for a task, independent of
 * that task's actual current `Status:` value in tasks.md — this lets a
 * caller check "would this task pass Done evidence requirements" before or
 * after the Status line itself is edited.
 *
 * `required` always lists the same three baseline requirements: the evidence
 * bundle file, the verification contract file, and a quality-gate report
 * that mentions the task id with `VERDICT: PASS`. Each is reported by a
 * relative path (bundle/contract) or a requirement name (quality-gate
 * report, since "which of possibly several reports" is not a single path).
 */
export function evidenceFindMissing(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<EvidenceMissingData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  const taskIdResult = validateTaskId(taskId);
  if (!taskIdResult.ok) {
    return taskIdResult;
  }

  const bundleRelPath = `specs/${feature}/verification/${taskId}.evidence.json`;
  const contractRelPath = `specs/${feature}/verification/${taskId}.contract.json`;
  const reportsDir = "reports/quality-gate";

  const required = [EVIDENCE_BUNDLE_REQUIREMENT, VERIFICATION_CONTRACT_REQUIREMENT, QUALITY_GATE_REPORT_REQUIREMENT];
  const present: string[] = [];
  const missing: string[] = [];

  if (guardedExists(root, bundleRelPath)) {
    present.push(EVIDENCE_BUNDLE_REQUIREMENT);
  } else {
    missing.push(EVIDENCE_BUNDLE_REQUIREMENT);
  }

  if (guardedExists(root, contractRelPath)) {
    present.push(VERIFICATION_CONTRACT_REQUIREMENT);
  } else {
    missing.push(VERIFICATION_CONTRACT_REQUIREMENT);
  }

  const qgMatches = anyFileContaining(root, reportsDir, taskId);
  if (qgMatches.length > 0 && hasQualityGateVerdictPass(root, reportsDir, taskId)) {
    present.push(QUALITY_GATE_REPORT_REQUIREMENT);
  } else {
    missing.push(QUALITY_GATE_REPORT_REQUIREMENT);
  }

  return ok({ kind: "evidence-missing", feature, taskId, required, present, missing });
}

// --- evidence_summarize_contract_checks ------------------------------------

export interface ContractChecksSummaryData {
  kind: "contract-checks";
  feature: string;
  taskId: string;
  checks: ContractChecksSummaryEntry[];
}

/**
 * `evidence_summarize_contract_checks`: reads and converts
 * `specs/<feature>/verification/<taskId>.contract.json` via
 * `parseVerificationContract` (T-011).
 */
export function evidenceSummarizeContractChecks(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<ContractChecksSummaryData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  const taskIdResult = validateTaskId(taskId);
  if (!taskIdResult.ok) {
    return taskIdResult;
  }

  const contractResult = parseVerificationContract(root, feature, taskId);
  if (!contractResult.ok) {
    return contractResult;
  }

  return ok({ kind: "contract-checks", feature, taskId, checks: contractResult.data.checks });
}

// --- evidence_compare_to_traceability ---------------------------------------

export interface TraceabilityMismatch {
  subject: string;
  issue: string;
}

export interface TraceabilityComparisonData {
  kind: "traceability-comparison";
  feature: string;
  matches: number;
  mismatches: TraceabilityMismatch[];
}

const TASK_ID_PREFIX_PATTERN = /^T-\d+/;

/**
 * Extracts the leading `T-NNN` task id from a traceability-table cell token.
 * Real traceability.md data uses free-text annotations after the task id
 * (e.g. `T-002 Phase 2`, `T-011（静的）`), so this only requires the token to
 * *start with* a well-formed task id rather than matching it exactly.
 * Returns `undefined` if no such prefix is present.
 */
function extractTaskIdPrefix(token: string): string | undefined {
  const match = TASK_ID_PREFIX_PATTERN.exec(token.trim());
  return match?.[0];
}

/**
 * Cross-checks `traceability.md`'s REQ -> Task and AC -> TEST -> Task tables
 * against `tasks.md`'s actual task ids, and each Done task's verification
 * contract `requirementIds` against the REQ-IDs traceability.md declares.
 *
 * Matching rules (documented here as the single source of truth for this
 * tool's `mismatches`):
 *   1. Every taskId token referenced by a REQ -> Task row must name a task
 *      that exists in tasks.md (matched by its `T-NNN` prefix — see
 *      `extractTaskIdPrefix`). A token with no such prefix, or naming a task
 *      absent from tasks.md, is a mismatch on subject `REQ-ID -> Task-ID`.
 *   2. Every taskId token referenced by an AC -> TEST -> Task row is checked
 *      the same way, subject `AC-ID/TEST-ID -> Task-ID`.
 *   3. For every task that has a readable `<taskId>.contract.json`, every
 *      `requirementIds` entry on its checks must appear as a REQ-ID somewhere
 *      in the REQ -> Task table; a requirement id the contract cites but
 *      traceability.md never declares is a mismatch on subject
 *      `<taskId> contract -> REQ-ID`.
 * `matches` counts every one of the above checks that did *not* produce a
 * mismatch (i.e. total checks performed minus `mismatches.length`).
 */
export function evidenceCompareToTraceability(
  root: SddRoot,
  feature: string,
): Result<TraceabilityComparisonData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }

  const traceabilityResult = parseTraceability(root, feature);
  if (!traceabilityResult.ok) {
    return traceabilityResult;
  }

  const taskStateResult = parseTaskState(root, feature, `specs/${feature}/tasks.md`);
  if (!taskStateResult.ok) {
    return taskStateResult;
  }

  const knownTaskIds = new Set(taskStateResult.data.tasks.map((task) => task.id));
  const traceability: TraceabilityData = traceabilityResult.data;

  let totalChecks = 0;
  const mismatches: TraceabilityMismatch[] = [];

  const checkTaskIdToken = (subject: string, token: string): void => {
    totalChecks += 1;
    const prefix = extractTaskIdPrefix(token);
    if (prefix === undefined) {
      mismatches.push({ subject, issue: `Task-ID cell "${token}" does not start with a well-formed T-NNN id` });
      return;
    }
    if (!knownTaskIds.has(prefix)) {
      mismatches.push({ subject, issue: `Task-ID "${prefix}" (from "${token}") is not a task in tasks.md` });
    }
  };

  for (const row of traceability.reqToTask) {
    for (const token of row.taskIds) {
      checkTaskIdToken(`REQ-ID -> Task-ID (${row.reqId})`, token);
    }
  }

  for (const row of traceability.acToTestToTask) {
    for (const token of row.taskIds) {
      checkTaskIdToken(`AC-ID/TEST-ID -> Task-ID (${row.acId}/${row.testId})`, token);
    }
  }

  const declaredReqIds = new Set(traceability.reqToTask.map((row) => row.reqId));
  for (const taskId of knownTaskIds) {
    const contractResult = parseVerificationContract(root, feature, taskId);
    if (!contractResult.ok) {
      continue; // no readable contract for this task -- nothing to cross-check
    }
    for (const check of contractResult.data.checks) {
      for (const reqId of check.requirementIds ?? []) {
        totalChecks += 1;
        if (!declaredReqIds.has(reqId)) {
          mismatches.push({
            subject: `${taskId} contract -> REQ-ID`,
            issue: `check "${check.id}" cites requirement "${reqId}", which traceability.md's REQ -> Task table never declares`,
          });
        }
      }
    }
  }

  return ok({
    kind: "traceability-comparison",
    feature,
    matches: totalChecks - mismatches.length,
    mismatches,
  });
}
