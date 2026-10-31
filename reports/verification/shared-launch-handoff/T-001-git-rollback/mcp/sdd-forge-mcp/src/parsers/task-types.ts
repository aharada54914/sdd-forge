/**
 * Shared types for the tasks.md state-machine parser, matching the
 * `taskStateData` / `taskEntry` shapes in
 * contracts/sdd-forge-mcp-tools.v1.schema.json.
 */

/** `Approval:` field value, restricted to the shapes the shell script accepts. */
export type Approval = "Draft" | "Approved" | `Approved (${string})`;

export type Status =
  | "Planned"
  | "In Progress"
  | "Blocked"
  | "Implementation Complete"
  | "Done";

export type Risk = "low" | "medium" | "high" | "critical";

export const STATUS_VALUES: readonly Status[] = [
  "Planned",
  "In Progress",
  "Blocked",
  "Implementation Complete",
  "Done",
];

export interface TaskEntry {
  id: string;
  approval: Approval;
  approvalAnnotation?: string;
  status: Status;
  risk?: Risk;
  requiredWorkflow?: string;
  secondApproval?: string;
  blockersNonEmpty: boolean;
}

export interface TaskFailure {
  taskId?: string;
  rule: string;
  message: string;
}

export interface TaskStateData {
  kind: "task-state";
  feature: string;
  tasksFile: string;
  verdict: "pass" | "fail";
  taskCount: number;
  tasks: TaskEntry[];
  failures: TaskFailure[];
}

/** Mutable per-task accumulator mirroring check-task-state.sh's awk per-task state. */
export interface TaskDraft {
  id: string;
  approval: string;
  status: string;
  risk: string;
  second: string;
  blockersContent: string;
  inBlockers: boolean;
}

export function newDraft(id: string): TaskDraft {
  return {
    id,
    approval: "",
    status: "",
    risk: "",
    second: "",
    blockersContent: "",
    inBlockers: false,
  };
}

export function isRisk(value: string): value is Risk {
  return value === "low" || value === "medium" || value === "high" || value === "critical";
}
