/**
 * Evidence bundle / verification contract structured-data extraction —
 * `specs/<feature>/verification/T-*.evidence.json` and `T-*.contract.json`.
 *
 * This module is *extraction*, not validation: `evidence-bundle.ts` already
 * reproduces `check-evidence-bundle.sh`'s pass/fail verdict logic
 * (`verifyEvidenceBundle`), which is untouched here. `parseEvidenceBundle`
 * only reads a bundle file, confirms its basic shape (JSON object, `task_id`
 * matches the requested task, and the required fields the contracts schema's
 * `evidenceBundleData` describes are present), and echoes the parsed object
 * back — including `signature` — without verifying any signature or reading
 * signing key material (path-guard denylists that file outright).
 *
 * Design.md "Data Plan": `specs/<feature>/verification/T-*.evidence.json` /
 * `T-*.contract.json` -> evidence.ts. Canonical shapes:
 * `contracts/sdd-forge-mcp-tools.v1.schema.json` `evidenceBundleData` /
 * `contractChecksSummaryData`.
 */

import { err, ok, type Result } from "../envelope.js";
import { guardedRead } from "../path-guard.js";
import type {
  ContractCheck,
  EvidenceBundle,
  VerificationContract,
} from "./evidence-bundle.js";
import type { SddRoot } from "../root.js";

/** Required top-level fields for a well-formed evidence bundle (evidenceBundleData). */
const REQUIRED_BUNDLE_FIELDS: ReadonlyArray<keyof EvidenceBundle> = [
  "task_id",
  "feature",
  "risk",
  "required_workflow",
];

function evidenceBundleRelPath(feature: string, taskId: string): string {
  return `specs/${feature}/verification/${taskId}.evidence.json`;
}

function verificationContractRelPath(feature: string, taskId: string): string {
  return `specs/${feature}/verification/${taskId}.contract.json`;
}

/**
 * Reads and parses `specs/<feature>/verification/<taskId>.evidence.json`.
 *
 * Failure modes (all `cannot-parse` unless noted, all carrying `file`):
 * - the path-guard read itself fails (propagated unchanged, e.g. `not-found`);
 * - the file is not valid JSON, or is not a JSON object;
 * - `task_id` in the bundle does not match the requested `taskId`;
 * - one of the required fields (`task_id`, `feature`, `risk`,
 *   `required_workflow`) is missing.
 *
 * The returned object is the parsed bundle as-is (all fields echoed,
 * including `signature`) — no signature verification and no reads of any
 * signing key are performed here.
 */
export function parseEvidenceBundle(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<EvidenceBundle> {
  const relPath = evidenceBundleRelPath(feature, taskId);
  const fileResult = guardedRead(root, relPath);
  if (!fileResult.ok) {
    return fileResult;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(fileResult.data.contents);
  } catch {
    return err("cannot-parse", `Evidence bundle is not valid JSON: ${relPath}`, {
      file: relPath,
      rule: "json-syntax",
    });
  }

  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return err("cannot-parse", `Evidence bundle is not a JSON object: ${relPath}`, {
      file: relPath,
      rule: "not-an-object",
    });
  }

  const bundle = parsed as EvidenceBundle;

  if (bundle.task_id !== taskId) {
    return err(
      "cannot-parse",
      `Evidence bundle task_id does not match requested task: ${String(bundle.task_id)} != ${taskId}`,
      { file: relPath, rule: "task-id-mismatch" },
    );
  }

  const missing = REQUIRED_BUNDLE_FIELDS.filter((field) => bundle[field] === undefined);
  if (missing.length > 0) {
    return err(
      "cannot-parse",
      `Evidence bundle is missing required field(s): ${missing.join(", ")} (${relPath})`,
      { file: relPath, rule: "missing-required-field" },
    );
  }

  return ok(bundle);
}

/** `contractChecksSummaryData.checks[]` entry shape (contracts v1). */
export interface ContractChecksSummaryEntry {
  id: string;
  required: boolean;
  passes: boolean;
  waiverReason?: string;
  requirementIds?: string[];
}

/** Parsed `contractChecksSummaryData` result of a single verification contract. */
export interface VerificationContractSummary {
  checks: ContractChecksSummaryEntry[];
}

/** Converts a raw contract check object into the contracts-schema camelCase shape. */
function toChecksSummaryEntry(check: ContractCheck, index: number): Result<ContractChecksSummaryEntry> {
  if (typeof check.id !== "string" || check.id.length === 0) {
    return err(
      "cannot-parse",
      `Verification contract check at index ${index} is missing a non-empty "id".`,
      { rule: "check-missing-id" },
    );
  }
  if (typeof check.required !== "boolean") {
    return err(
      "cannot-parse",
      `Verification contract check "${check.id}" is missing a boolean "required".`,
      { rule: "check-missing-required" },
    );
  }
  if (typeof check.passes !== "boolean") {
    return err(
      "cannot-parse",
      `Verification contract check "${check.id}" is missing a boolean "passes".`,
      { rule: "check-missing-passes" },
    );
  }

  const entry: ContractChecksSummaryEntry = {
    id: check.id,
    required: check.required,
    passes: check.passes,
  };
  if (typeof check.waiver_reason === "string") {
    entry.waiverReason = check.waiver_reason;
  }
  if (Array.isArray(check.requirement_ids)) {
    entry.requirementIds = check.requirement_ids.filter(
      (value): value is string => typeof value === "string",
    );
  }
  return ok(entry);
}

/**
 * Reads and parses `specs/<feature>/verification/<taskId>.contract.json`,
 * converting its `checks[]` array into the `contractChecksSummaryData.checks`
 * shape (`id`, `required`, `passes`, `waiverReason?`, `requirementIds?`).
 *
 * Failure modes (all `cannot-parse` unless noted, all carrying `file`):
 * - the path-guard read itself fails (propagated unchanged, e.g. `not-found`);
 * - the file is not valid JSON, or is not a JSON object;
 * - `task_id` in the contract does not match the requested `taskId`;
 * - `checks` is missing or not an array;
 * - any entry in `checks` is missing a non-empty `id`, boolean `required`, or
 *   boolean `passes`.
 */
export function parseVerificationContract(
  root: SddRoot,
  feature: string,
  taskId: string,
): Result<VerificationContractSummary> {
  const relPath = verificationContractRelPath(feature, taskId);
  const fileResult = guardedRead(root, relPath);
  if (!fileResult.ok) {
    return fileResult;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(fileResult.data.contents);
  } catch {
    return err("cannot-parse", `Verification contract is not valid JSON: ${relPath}`, {
      file: relPath,
      rule: "json-syntax",
    });
  }

  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return err("cannot-parse", `Verification contract is not a JSON object: ${relPath}`, {
      file: relPath,
      rule: "not-an-object",
    });
  }

  const contract = parsed as VerificationContract;

  if (contract.task_id !== taskId) {
    return err(
      "cannot-parse",
      `Verification contract task_id does not match requested task: ${String(contract.task_id)} != ${taskId}`,
      { file: relPath, rule: "task-id-mismatch" },
    );
  }

  if (!Array.isArray(contract.checks)) {
    return err("cannot-parse", `Verification contract "checks" is missing or not an array: ${relPath}`, {
      file: relPath,
      rule: "checks-not-array",
    });
  }

  const checks: ContractChecksSummaryEntry[] = [];
  for (let i = 0; i < contract.checks.length; i += 1) {
    const rawCheck = contract.checks[i];
    if (typeof rawCheck !== "object" || rawCheck === null) {
      return err("cannot-parse", `Verification contract check at index ${i} is not an object: ${relPath}`, {
        file: relPath,
        line: i,
        rule: "check-not-an-object",
      });
    }
    const converted = toChecksSummaryEntry(rawCheck as ContractCheck, i);
    if (!converted.ok) {
      return err(converted.error.code, converted.error.message, {
        ...converted.error.details,
        file: relPath,
      });
    }
    checks.push(converted.data);
  }

  return ok({ checks });
}
