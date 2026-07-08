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

import { createHash } from "node:crypto";
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
import { guardedExists, guardedRead, resolveGuarded } from "../path-guard.js";
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

// --- evidence_deep_verify (T-001 core) -------------------------------------

/**
 * Per-artifact recomputation status. Deterministic classification of one
 * `artifacts[]` entry against its on-disk file (REQ-002):
 * - `match` / `mismatch`: file read, sha256 recomputed and compared;
 * - `missing`: path-guard reported the file absent (`not-found`);
 * - `too-large`: path-guard reported the file over the 2 MiB limit;
 * - `path-denied`: path failed shape / allowlist / denylist checks;
 * - `invalid-recorded-sha`: the recorded sha256 is not 64-char lowercase hex
 *   (AC-017 — never misclassified as `mismatch`, and the disk file is not
 *   read).
 */
export type ArtifactVerifyStatus =
  | "match"
  | "mismatch"
  | "missing"
  | "too-large"
  | "path-denied"
  | "invalid-recorded-sha";

export interface ArtifactVerifyResult {
  path: string;
  recordedSha256: string;
  computedSha256?: string;
  status: ArtifactVerifyStatus;
  reason?: string;
}

export interface ArtifactsDigestInvariant {
  recorded: string;
  onDisk: string;
  status: "match" | "mismatch";
}

export interface SpecRevisionInvariant {
  recorded: string;
  computed: string;
  status: "match" | "mismatch";
  filesHashed: string[];
}

export interface GitCommitInvariant {
  value: string;
  shapeValid: boolean;
  ancestryVerified: false;
  reason: string;
}

export interface CrossBindingInvariant {
  subject: string;
  status: "match" | "mismatch";
  detail: string;
}

export interface DeepVerifyInvariants {
  artifactsDigest: ArtifactsDigestInvariant;
  specRevision: SpecRevisionInvariant;
  gitCommit: GitCommitInvariant;
  crossBindings: CrossBindingInvariant[];
}

export interface DeepVerifySignature {
  present: boolean;
  alg?: string;
  verified: false;
  note: string;
}

export interface EvidenceDeepVerifyData {
  kind: "evidence-deep-verify";
  feature: string;
  taskId: string;
  verdict: "pass" | "fail";
  artifacts: ArtifactVerifyResult[];
  invariants: DeepVerifyInvariants;
  signature: DeepVerifySignature;
  failures: string[];
}

/** 64-char lowercase hex — the shape of a valid recorded / recomputed sha256. */
const RECORDED_SHA256_PATTERN = /^[a-f0-9]{64}$/;
/** 40-char lowercase hex — `check-evidence-bundle.sh`'s git_commit shape rule. */
const GIT_COMMIT_PATTERN = /^[0-9a-f]{40}$/;

/** Recomputes a guarded file's sha256 the same way `sha256OfGuardedFile` does. */
function sha256OfContents(contents: string): string {
  return createHash("sha256").update(contents, "utf-8").digest("hex");
}

/** Escapes a string for safe interpolation into a `RegExp` source. */
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Canonical artifacts digest — a verbatim re-implementation of the host
 * scripts' `evidence_canonical` (generate/check-evidence-bundle.sh, ADR-0009):
 * each artifact is rendered as `path + "\x00" + sha256(lowercase)`, the pairs
 * are sorted, joined with `"\n"`, and hashed with SHA-256. An empty artifact
 * list therefore digests the empty string (AC-018's empty-set digest).
 */
export function canonicalArtifactsDigest(
  pairs: ReadonlyArray<{ path: string; sha256: string }>,
): string {
  const lines = pairs.map((pair) => `${pair.path}\u0000${pair.sha256}`);
  lines.sort();
  return sha256OfContents(lines.join("\n"));
}

/**
 * Classifies one recorded artifact against its on-disk file (REQ-002 /
 * REQ-011). Never throws: every read failure (missing / oversize / denied)
 * and every malformed recorded sha resolves to a status. AC-017 takes
 * precedence — a non-64-hex recorded sha is `invalid-recorded-sha` and the
 * disk file is not read.
 */
export function classifyArtifact(
  root: SddRoot,
  artifact: EvidenceArtifact,
): ArtifactVerifyResult {
  const path = String(artifact.path ?? "").trim();
  const recordedSha256 = String(artifact.sha256 ?? "").trim().toLowerCase();

  if (!RECORDED_SHA256_PATTERN.test(recordedSha256)) {
    return {
      path,
      recordedSha256,
      status: "invalid-recorded-sha",
      reason: "recorded sha256 is not 64-char lowercase hex",
    };
  }

  const read = guardedRead(root, path);
  if (!read.ok) {
    const status: ArtifactVerifyStatus =
      read.error.code === "too-large"
        ? "too-large"
        : read.error.code === "path-denied"
          ? "path-denied"
          : "missing";
    return { path, recordedSha256, status, reason: read.error.message };
  }

  const computedSha256 = sha256OfContents(read.data.contents);
  if (computedSha256 === recordedSha256) {
    return { path, recordedSha256, computedSha256, status: "match" };
  }
  return {
    path,
    recordedSha256,
    computedSha256,
    status: "mismatch",
    reason: "on-disk sha256 does not match recorded sha256",
  };
}

/**
 * Recomputes the `spec_revision` invariant (REQ-005 / ADR-0009): SHA-256 over
 * the concatenated bytes of `specs/<feature>/{requirements,design,
 * acceptance-tests}.md` in that order, restricted to the files that exist.
 * When none exist the canonical value is `""` (host `found_any=false`). Reads
 * go through path-guard and never throw (AC-019).
 */
function recomputeSpecRevision(
  root: SddRoot,
  feature: string,
  bundle: EvidenceBundle,
): SpecRevisionInvariant {
  const specFiles = [
    `specs/${feature}/requirements.md`,
    `specs/${feature}/design.md`,
    `specs/${feature}/acceptance-tests.md`,
  ];
  const hasher = createHash("sha256");
  const filesHashed: string[] = [];
  let foundAny = false;
  for (const relPath of specFiles) {
    const read = guardedRead(root, relPath);
    if (read.ok) {
      hasher.update(read.data.contents, "utf-8");
      filesHashed.push(relPath);
      foundAny = true;
    }
  }
  const computed = foundAny ? hasher.digest("hex") : "";
  const recorded = String(bundle.spec_revision ?? "");
  return {
    recorded,
    computed,
    status: recorded === computed ? "match" : "mismatch",
    filesHashed,
  };
}

/**
 * Verifies the `git_commit` invariant (REQ-006 / ADR-0008): the recorded value
 * must be 40 lowercase hex. HEAD/ancestor verification requires a git
 * subprocess and is host-deferred, so `ancestryVerified` is always `false` and
 * only the shape contributes to the verdict.
 */
function verifyGitCommit(bundle: EvidenceBundle): GitCommitInvariant {
  const value = String(bundle.git_commit ?? "");
  const shapeValid = GIT_COMMIT_PATTERN.test(value);
  return {
    value,
    shapeValid,
    ancestryVerified: false,
    reason: shapeValid
      ? "git_commit shape is valid (40 lowercase hex); HEAD/ancestor verification is host-deferred (no git subprocess in-process)"
      : "git_commit is not 40 lowercase hex; HEAD/ancestor verification is host-deferred",
  };
}

/**
 * Cross-binds the `verification_contract` file's task_id / feature to the
 * bundle's (REQ-007). An unreadable or unparsable contract is a mismatch.
 */
function verifyContractBinding(
  root: SddRoot,
  bundle: EvidenceBundle,
): CrossBindingInvariant {
  const subject = "verification_contract";
  const contractPath = String(bundle.verification_contract ?? "").trim();
  if (contractPath.length === 0) {
    return { subject, status: "mismatch", detail: "verification_contract path is missing" };
  }
  const read = guardedRead(root, contractPath);
  if (!read.ok) {
    return { subject, status: "mismatch", detail: `verification_contract unreadable: ${read.error.message}` };
  }
  let contract: { task_id?: unknown; feature?: unknown };
  try {
    contract = JSON.parse(read.data.contents) as { task_id?: unknown; feature?: unknown };
  } catch {
    return { subject, status: "mismatch", detail: "verification_contract is not valid JSON" };
  }
  const contractTaskId = String(contract.task_id ?? "").trim();
  const contractFeature = String(contract.feature ?? "").trim();
  const bundleTaskId = String(bundle.task_id ?? "").trim();
  const bundleFeature = String(bundle.feature ?? "").trim();
  if (contractTaskId !== bundleTaskId) {
    return {
      subject,
      status: "mismatch",
      detail: `contract task_id '${contractTaskId}' != bundle task_id '${bundleTaskId}'`,
    };
  }
  if (contractFeature !== bundleFeature) {
    return {
      subject,
      status: "mismatch",
      detail: `contract feature '${contractFeature}' != bundle feature '${bundleFeature}'`,
    };
  }
  return { subject, status: "match", detail: "contract task_id and feature match the bundle" };
}

/**
 * Cross-binds the `quality_report` file's `Task ID:` / `Feature:` lines to the
 * bundle's (REQ-007). An unreadable report is a mismatch.
 */
function verifyReportBinding(
  root: SddRoot,
  bundle: EvidenceBundle,
): CrossBindingInvariant {
  const subject = "quality_report";
  const reportPath = String(bundle.quality_report ?? "").trim();
  const bundleTaskId = String(bundle.task_id ?? "").trim();
  const bundleFeature = String(bundle.feature ?? "").trim();
  if (reportPath.length === 0) {
    return { subject, status: "mismatch", detail: "quality_report path is missing" };
  }
  const read = guardedRead(root, reportPath);
  if (!read.ok) {
    return { subject, status: "mismatch", detail: `quality_report unreadable: ${read.error.message}` };
  }
  const text = read.data.contents;
  const taskIdMatches = new RegExp(`^Task ID:\\s*${escapeRegExp(bundleTaskId)}\\s*$`, "m").test(text);
  if (!taskIdMatches) {
    return { subject, status: "mismatch", detail: `quality_report is missing 'Task ID: ${bundleTaskId}'` };
  }
  if (bundleFeature.length > 0) {
    const featureMatches = new RegExp(`^Feature:\\s*${escapeRegExp(bundleFeature)}\\s*$`, "m").test(text);
    if (!featureMatches) {
      return { subject, status: "mismatch", detail: `quality_report Feature does not match '${bundleFeature}'` };
    }
  }
  return { subject, status: "match", detail: "quality_report Task ID and Feature match the bundle" };
}

/** Echoes the bundle `signature` block without reading keys or verifying it. */
function echoSignature(bundle: EvidenceBundle): DeepVerifySignature {
  const signature = bundle.signature;
  const present = signature !== undefined && signature !== null;
  const note =
    "signature is echoed only; no signing key is read and no HMAC/crypto verification is performed (host responsibility, ADR-0008)";
  if (present && typeof signature.alg === "string") {
    return { present, alg: signature.alg, verified: false, note };
  }
  return { present, verified: false, note };
}

/**
 * `evidence_deep_verify` core (REQ-002/003/004/005/006/007/008/011): reads the
 * evidence bundle, recomputes every artifact's sha256 from disk, recomputes
 * the canonical artifacts digest / spec_revision / git_commit shape /
 * cross-bindings, echoes the signature (never verified), and reduces the whole
 * set to a deterministic pass/fail verdict plus a human-readable `failures[]`
 * enumeration.
 *
 * The verdict is `pass` iff every artifact is `match`, the artifacts digest and
 * spec_revision are `match`, git_commit's shape is valid, and every
 * cross-binding is `match`. `gitCommit.ancestryVerified` and
 * `signature.verified` are always `false` and never affect the verdict.
 */
export function evidenceDeepVerify(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<EvidenceDeepVerifyData> {
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
  const bundle = bundleResult.data;

  const recordedArtifacts: EvidenceArtifact[] = Array.isArray(bundle.artifacts) ? bundle.artifacts : [];
  const artifacts = recordedArtifacts.map((artifact) => classifyArtifact(root, artifact));

  const recordedDigest = canonicalArtifactsDigest(
    recordedArtifacts.map((artifact) => ({
      path: String(artifact.path ?? "").trim(),
      sha256: String(artifact.sha256 ?? "").trim().toLowerCase(),
    })),
  );
  const onDiskDigest = canonicalArtifactsDigest(
    artifacts.map((result) => ({ path: result.path, sha256: result.computedSha256 ?? "" })),
  );
  const artifactsDigest: ArtifactsDigestInvariant = {
    recorded: recordedDigest,
    onDisk: onDiskDigest,
    status: recordedDigest === onDiskDigest ? "match" : "mismatch",
  };

  const specRevision = recomputeSpecRevision(root, feature, bundle);
  const gitCommit = verifyGitCommit(bundle);
  const crossBindings = [verifyContractBinding(root, bundle), verifyReportBinding(root, bundle)];

  const failures: string[] = [];
  for (const result of artifacts) {
    if (result.status !== "match") {
      failures.push(
        `artifact ${result.path}: ${result.status}${result.reason ? ` (${result.reason})` : ""}`,
      );
    }
  }
  if (artifactsDigest.status !== "match") {
    failures.push(
      `artifacts digest mismatch: recorded ${artifactsDigest.recorded} != on-disk ${artifactsDigest.onDisk}`,
    );
  }
  if (specRevision.status !== "match") {
    failures.push(
      `spec_revision mismatch: recorded ${specRevision.recorded || "(empty)"} != computed ${specRevision.computed || "(empty)"}`,
    );
  }
  if (!gitCommit.shapeValid) {
    failures.push(`git_commit shape invalid: ${gitCommit.value || "(missing)"}`);
  }
  for (const binding of crossBindings) {
    if (binding.status !== "match") {
      failures.push(`cross-binding ${binding.subject}: ${binding.detail}`);
    }
  }

  return ok({
    kind: "evidence-deep-verify",
    feature,
    taskId,
    verdict: failures.length === 0 ? "pass" : "fail",
    artifacts,
    invariants: { artifactsDigest, specRevision, gitCommit, crossBindings },
    signature: echoSignature(bundle),
    failures,
  });
}
