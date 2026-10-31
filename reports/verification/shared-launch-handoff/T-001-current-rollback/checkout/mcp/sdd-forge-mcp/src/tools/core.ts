/**
 * Core tool implementations (8 tools) — pure functions of `(root, input)` to
 * `Result<...>`, independent of the MCP transport/protocol layer so they can
 * be unit-tested directly and wrapped by `server.ts` for MCP registration.
 *
 * Canonical response shapes: contracts/sdd-forge-mcp-tools.v1.schema.json.
 * Canonical tool list: design.md "Architecture" (`tools/core.ts`) and
 * "API / Contract Plan".
 *
 * Every tool validates its own `feature`/`taskId` arguments against the
 * contract's `feature` (`^[A-Za-z0-9][A-Za-z0-9._-]*$`) and `taskId`
 * (`^T-[0-9]+$`) patterns before touching the filesystem — a malformed
 * argument is `invalid-input`, never silently coerced. No tool accepts a
 * `root` parameter (REQ-007): the resolved root is a constructor-time value
 * supplied by the caller (`server.ts`), never client input.
 */

import { err, ok, type Result } from "../envelope.js";
import { parseActiveSpecDirectories } from "../parsers/agents-md.js";
import { listQualityReports, type QualityReportEntry } from "../parsers/quality-report.js";
import { listReviewTickets, type ReviewTicketEntry } from "../parsers/review-ticket.js";
import { extractHeaderValue } from "../parsers/spec-header.js";
import { parseTaskState } from "../parsers/tasks.js";
import type { TaskEntry, TaskStateData } from "../parsers/task-types.js";
import { guardedRead } from "../path-guard.js";
import { getNextSddCommand as computeNextSddCommand, type NextCommandData } from "../next-command.js";
import type { SddRoot } from "../root.js";

const FEATURE_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const TASK_ID_PATTERN = /^T-[0-9]+$/;

/** Validates a `feature` argument against the contract's `feature` pattern. */
export function validateFeature(feature: string): Result<string> {
  if (!FEATURE_PATTERN.test(feature)) {
    return err("invalid-input", `Invalid feature name: ${feature}`, {
      rule: "feature-shape",
    });
  }
  return ok(feature);
}

/** Validates a `taskId` argument against the contract's `taskId` pattern. */
export function validateTaskId(taskId: string): Result<string> {
  if (!TASK_ID_PATTERN.test(taskId)) {
    return err("invalid-input", `Invalid task id: ${taskId}`, {
      rule: "task-id-shape",
    });
  }
  return ok(taskId);
}

// --- list_active_specs ------------------------------------------------

export interface ActiveSpecEntry {
  feature: string;
  path: string;
  hasApprovedPlannedOrInProgress: boolean;
}

export interface ActiveSpecsData {
  kind: "active-specs";
  specs: ActiveSpecEntry[];
}

/** True if at least one task is Approved-shaped and Status Planned or In Progress. */
function hasApprovedPlannedOrInProgress(tasks: TaskEntry[]): boolean {
  return tasks.some(
    (task) =>
      (task.status === "Planned" || task.status === "In Progress") &&
      (task.approval === "Approved" || task.approval.startsWith("Approved (")),
  );
}

/**
 * `list_active_specs`: reads AGENTS.md's `## Active Spec Directories` and,
 * for each listed feature, evaluates whether its tasks.md has at least one
 * Approved task that is Planned or In Progress. A feature whose tasks.md is
 * missing or fails to parse is reported with `hasApprovedPlannedOrInProgress:
 * false` rather than failing the whole tool — the list of active specs itself
 * comes from AGENTS.md, not from tasks.md.
 */
export function listActiveSpecs(root: SddRoot): Result<ActiveSpecsData> {
  const specsResult = parseActiveSpecDirectories(root);
  if (!specsResult.ok) {
    return specsResult;
  }

  const specs: ActiveSpecEntry[] = specsResult.data.map((spec) => {
    const taskStateResult = parseTaskState(root, spec.feature, `specs/${spec.feature}/tasks.md`);
    const flag = taskStateResult.ok ? hasApprovedPlannedOrInProgress(taskStateResult.data.tasks) : false;
    return {
      feature: spec.feature,
      path: spec.path,
      hasApprovedPlannedOrInProgress: flag,
    };
  });

  return ok({ kind: "active-specs", specs });
}

// --- get_spec_status ----------------------------------------------------

export interface SpecArtifactStatus {
  name: string;
  exists: boolean;
  reviewStatus?: string;
}

export interface SpecStatusData {
  kind: "spec-status";
  feature: string;
  artifacts: SpecArtifactStatus[];
}

/** Phase 1/2 artifacts checked by `get_spec_status`, in design.md Data Plan order. */
const SPEC_ARTIFACTS: ReadonlyArray<{ name: string; file: string; reviewStatusKey?: string }> = [
  { name: "requirements", file: "requirements.md", reviewStatusKey: "Spec-Review-Status" },
  { name: "acceptance-tests", file: "acceptance-tests.md" },
  { name: "design", file: "design.md", reviewStatusKey: "Impl-Review-Status" },
  { name: "tasks", file: "tasks.md", reviewStatusKey: "Task-Review-Status" },
  { name: "traceability", file: "traceability.md" },
  { name: "ux-spec", file: "ux-spec.md" },
  { name: "frontend-spec", file: "frontend-spec.md" },
  { name: "infra-spec", file: "infra-spec.md" },
  { name: "security-spec", file: "security-spec.md" },
];

/**
 * `get_spec_status`: reports which Phase 1/2 artifacts exist under
 * `specs/<feature>/` and, for the three that carry a review-status header
 * (requirements/design/tasks), the header's value. A missing artifact is
 * simply `exists: false` with no `reviewStatus` — this is not an error, since
 * many artifacts are legitimately absent early in a feature's lifecycle.
 */
export function getSpecStatus(root: SddRoot, feature: string): Result<SpecStatusData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }

  const artifacts: SpecArtifactStatus[] = SPEC_ARTIFACTS.map(({ name, file, reviewStatusKey }) => {
    const relPath = `specs/${feature}/${file}`;
    const readResult = guardedRead(root, relPath);
    if (!readResult.ok) {
      return { name, exists: false };
    }
    const artifact: SpecArtifactStatus = { name, exists: true };
    if (reviewStatusKey !== undefined) {
      const reviewStatus = extractHeaderValue(readResult.data.contents, reviewStatusKey);
      if (reviewStatus !== undefined) {
        artifact.reviewStatus = reviewStatus;
      }
    }
    return artifact;
  });

  return ok({ kind: "spec-status", feature, artifacts });
}

// --- get_task_state ------------------------------------------------------

/** `get_task_state`: shell-equivalent tasks.md state-machine verdict (T-002's parser, unchanged). */
export function getTaskState(root: SddRoot, feature: string): Result<TaskStateData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  return parseTaskState(root, feature, `specs/${feature}/tasks.md`);
}

// --- list_approved_tasks / list_blocked_tasks ----------------------------

export interface TaskListData {
  kind: "approved-tasks" | "blocked-tasks";
  feature: string;
  tasks: TaskEntry[];
}

function isApprovedShape(approval: string): boolean {
  return approval === "Approved" || approval.startsWith("Approved (");
}

/** `list_approved_tasks`: every task whose Approval is Approved-shaped. */
export function listApprovedTasks(root: SddRoot, feature: string): Result<TaskListData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  const stateResult = parseTaskState(root, feature, `specs/${feature}/tasks.md`);
  if (!stateResult.ok) {
    return stateResult;
  }
  const tasks = stateResult.data.tasks.filter((task) => isApprovedShape(task.approval));
  return ok({ kind: "approved-tasks", feature, tasks });
}

/** `list_blocked_tasks`: every task whose Status is Blocked. */
export function listBlockedTasks(root: SddRoot, feature: string): Result<TaskListData> {
  const featureResult = validateFeature(feature);
  if (!featureResult.ok) {
    return featureResult;
  }
  const stateResult = parseTaskState(root, feature, `specs/${feature}/tasks.md`);
  if (!stateResult.ok) {
    return stateResult;
  }
  const tasks = stateResult.data.tasks.filter((task) => task.status === "Blocked");
  return ok({ kind: "blocked-tasks", feature, tasks });
}

// --- list_review_tickets --------------------------------------------------

export interface ReviewTicketsData {
  kind: "review-tickets";
  tickets: ReviewTicketEntry[];
}

/**
 * `list_review_tickets`: every `docs/review-tickets/RT-*.yml` file that
 * parses successfully. Files that fail to parse are silently excluded from
 * the result rather than failing the whole tool — the contract's
 * `reviewTicketsData` shape carries no `failures` array, so a single
 * malformed ticket file must not prevent every other ticket from being
 * listed (see `review-ticket.ts`'s `listReviewTickets` for the underlying
 * per-file failure detail, which this tool does not surface).
 */
export function listReviewTicketsTool(root: SddRoot): Result<ReviewTicketsData> {
  const scan = listReviewTickets(root);
  return ok({ kind: "review-tickets", tickets: scan.tickets });
}

// --- get_quality_gate_summary ---------------------------------------------

export interface QualityGateSummaryData {
  kind: "quality-gate-summary";
  reports: QualityReportEntry[];
}

/**
 * `get_quality_gate_summary`: every `reports/quality-gate/*.md` file that has
 * a `VERDICT:` line. Files without one are silently excluded (see
 * `list_review_tickets` doc for why: the contract shape carries no
 * `failures` array).
 */
export function getQualityGateSummary(root: SddRoot): Result<QualityGateSummaryData> {
  const scan = listQualityReports(root);
  return ok({ kind: "quality-gate-summary", reports: scan.reports });
}

// --- get_next_sdd_command --------------------------------------------------

export type { NextCommandData } from "../next-command.js";

/**
 * `get_next_sdd_command`: validates the optional `feature` argument against
 * the contract's `feature` pattern, then delegates the deterministic
 * state -> next-command mapping to `next-command.ts` (design.md
 * "Architecture" / "API / Contract Plan", REQ-011).
 */
export function getNextSddCommand(root: SddRoot, feature?: string): Result<NextCommandData> {
  if (feature !== undefined) {
    const featureResult = validateFeature(feature);
    if (!featureResult.ok) {
      return featureResult;
    }
  }
  return computeNextSddCommand(root, feature);
}
