/**
 * Per-task field validation — the awk script's `finish()` function,
 * reproduced 1:1 (message text included) for shell-equivalent failures.
 */

import { verifyEvidenceBundle } from "./evidence-bundle.js";
import { anyFileContaining, hasAnyFileMentioning, hasQualityGateVerdictPass } from "./report-lookup.js";
import { guardedExists, guardedExistsNonEmpty, guardedRead } from "../path-guard.js";
import type { SddRoot } from "../root.js";
import {
  isRisk,
  STATUS_VALUES,
  type Approval,
  type Status,
  type TaskDraft,
  type TaskEntry,
  type TaskFailure,
} from "./task-types.js";

const APPROVED_ANNOTATION_PATTERN = /^Approved \((.+)\)$/;
const APPROVER_ID_PATTERN = /^Approved \(([^ )]+) \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\)$/;

/** Extracts the `Approved (<id> <ISO-8601>)` approver id, or "" if the shape does not match. */
function approverId(value: string): string {
  const match = APPROVER_ID_PATTERN.exec(value);
  return match?.[1] ?? "";
}

export function isApprovedShape(value: string): boolean {
  return value === "Approved" || APPROVED_ANNOTATION_PATTERN.test(value);
}

/** Finishes validating one task's accumulated fields, appending to `failures`/`tasks`. */
export function finishTask(
  draft: TaskDraft,
  root: SddRoot,
  tasksDir: string,
  reportsDir: string,
  implReportsDir: string,
  failures: TaskFailure[],
  tasks: TaskEntry[],
): void {
  const taskId = draft.id;
  const fail = (rule: string, message: string): void => {
    failures.push({ taskId, rule, message });
  };

  let approval: Approval | undefined;
  if (draft.approval === "") {
    fail("approval-missing", `${taskId} has no Approval line`);
  } else if (!isApprovedShape(draft.approval) && draft.approval !== "Draft") {
    fail("approval-invalid", `${taskId} has invalid Approval: ${draft.approval}`);
  } else {
    approval = draft.approval as Approval;
  }
  const isApproved = isApprovedShape(draft.approval);

  let status: Status | undefined;
  if (draft.status === "") {
    fail("status-missing", `${taskId} has no Status line`);
  } else if (!STATUS_VALUES.includes(draft.status as Status)) {
    fail("status-invalid", `${taskId} has invalid Status: ${draft.status}`);
  } else {
    status = draft.status as Status;
  }

  if (
    status !== undefined &&
    (status === "In Progress" || status === "Implementation Complete" || status === "Done") &&
    !isApproved
  ) {
    fail("approval-required", `${taskId} is '${status}' without Approval: Approved`);
  }

  if (status === "Done") {
    validateDoneEvidence(root, taskId, tasksDir, reportsDir, fail);
  }

  if (status === "Implementation Complete") {
    if (!hasAnyFileMentioning(root, implReportsDir, taskId)) {
      fail(
        "impl-complete-report-missing",
        `${taskId} is Implementation Complete but no implementation report in ${implReportsDir} mentions it`,
      );
    }
  }

  let blockersNonEmpty = false;
  if (status === "Blocked") {
    if (draft.blockersContent === "") {
      fail(
        "blocked-no-blockers",
        `${taskId} is Blocked but ### Blockers section has no content (not None or empty)`,
      );
    } else {
      blockersNonEmpty = true;
    }
  } else {
    blockersNonEmpty = draft.blockersContent !== "";
  }

  if (status === "Done" && draft.risk === "critical") {
    validateCriticalTwoPersonApproval(taskId, draft, fail);
  }

  if (status !== undefined && approval !== undefined) {
    tasks.push(buildTaskEntry(taskId, draft, approval, status, blockersNonEmpty));
  }
}

/** Reproduces the awk `finish()` function's `status == "Done"` block: evidence bundle + contract + quality-gate report checks. */
function validateDoneEvidence(
  root: SddRoot,
  taskId: string,
  tasksDir: string,
  reportsDir: string,
  fail: (rule: string, message: string) => void,
): void {
  const bundleRelPath = `${tasksDir}/verification/${taskId}.evidence.json`;
  const contractRelPath = `${tasksDir}/verification/${taskId}.contract.json`;

  if (!guardedExists(root, bundleRelPath)) {
    fail(
      "done-evidence-missing",
      `${taskId} is Done but verification/${taskId}.evidence.json does not exist in ${tasksDir}`,
    );
  } else {
    const bundleFailures = verifyEvidenceBundle(root, bundleRelPath, taskId);
    if (bundleFailures.length > 0) {
      fail("done-evidence-invalid", `${taskId} evidence bundle failed validation: ${bundleRelPath}`);
    }
  }

  if (!guardedExists(root, contractRelPath)) {
    fail(
      "done-contract-missing",
      `${taskId} is Done but verification/${taskId}.contract.json does not exist in ${tasksDir}`,
    );
  } else if (!guardedExistsNonEmpty(root, contractRelPath)) {
    fail(
      "done-contract-empty",
      `${taskId} is Done but verification/${taskId}.contract.json is empty in ${tasksDir}`,
    );
  } else {
    const contractRead = guardedRead(root, contractRelPath);
    let contractTaskIdMatches = false;
    if (contractRead.ok) {
      try {
        const parsed = JSON.parse(contractRead.data.contents) as { task_id?: unknown };
        contractTaskIdMatches = String(parsed.task_id ?? "") === taskId;
      } catch {
        contractTaskIdMatches = false;
      }
    }
    if (!contractTaskIdMatches) {
      fail(
        "done-contract-task-id-mismatch",
        `${taskId} is Done but verification/${taskId}.contract.json has mismatched task_id`,
      );
    }
  }

  const qgMatches = anyFileContaining(root, reportsDir, taskId);
  if (qgMatches.length === 0) {
    fail(
      "done-quality-gate-report-missing",
      `${taskId} is Done but no quality-gate report in ${reportsDir} mentions it`,
    );
  } else if (!hasQualityGateVerdictPass(root, reportsDir, taskId)) {
    fail(
      "done-quality-gate-verdict-fail",
      `${taskId} is Done but quality-gate report does not contain VERDICT: PASS: ${qgMatches[0]}`,
    );
  }
}

/** Reproduces the awk `finish()` function's critical-Done two-person-approval block. */
function validateCriticalTwoPersonApproval(
  taskId: string,
  draft: TaskDraft,
  fail: (rule: string, message: string) => void,
): void {
  const primId = approverId(draft.approval);
  const secId = approverId(draft.second);

  if (primId === "") {
    fail(
      "critical-primary-approver-missing",
      `${taskId} is critical Done but primary Approval lacks a named approver (need 'Approved (<id> <ISO>)')`,
    );
  }
  if (primId.toLowerCase() === "sudo") {
    fail(
      "critical-primary-approver-sudo",
      `${taskId} is critical Done but primary approver is 'sudo'; critical requires a named human approver`,
    );
  }
  if (draft.second === "" || secId === "") {
    fail(
      "critical-second-approval-missing",
      `${taskId} is critical Done but Second Approval is missing or not a named 'Approved (<id> <ISO>)'`,
    );
  }
  if (secId.toLowerCase() === "sudo") {
    fail(
      "critical-second-approver-sudo",
      `${taskId} is critical Done but Second Approval approver is 'sudo'; critical requires a named human second approver`,
    );
  }
  if (primId !== "" && primId.toLowerCase() === secId.toLowerCase()) {
    fail(
      "critical-same-approver",
      `${taskId} is critical Done but both approvals are by the same approver '${primId}'; two distinct approvers required`,
    );
  }
}

function buildTaskEntry(
  taskId: string,
  draft: TaskDraft,
  approval: Approval,
  status: Status,
  blockersNonEmpty: boolean,
): TaskEntry {
  const entry: TaskEntry = {
    id: taskId,
    approval,
    status,
    blockersNonEmpty,
  };
  const annotationMatch = APPROVED_ANNOTATION_PATTERN.exec(draft.approval);
  if (annotationMatch?.[1] !== undefined) {
    entry.approvalAnnotation = annotationMatch[1];
  }
  if (draft.risk !== "" && isRisk(draft.risk)) {
    entry.risk = draft.risk;
  }
  if (draft.second !== "") {
    entry.secondApproval = draft.second;
  }
  return entry;
}
