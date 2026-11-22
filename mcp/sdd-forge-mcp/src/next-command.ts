import type { ReportLookup } from './parsers/report-lookup.js';
/**
 * `get_next_sdd_command`'s deterministic state -> next-command mapping
 * (design.md "Architecture" / "API / Contract Plan", REQ-011, AC-012).
 *
 * Given a `feature`, walks `specs/<feature>/`'s Phase 1/2 artifacts and
 * tasks.md state machine in the same order as AGENTS.md's Required Workflow
 * (bootstrap -> spec-review -> impl-review -> bootstrap Phase 2 ->
 * task-review -> human approval -> implement-task -> quality-gate -> done),
 * and reports the single next command a human or agent should run. Without a
 * `feature`, reproduces `sdd-ship:run`'s zero-argument auto-selection rule
 * (SKILL.md "Step 1 — Target Selection"): scan AGENTS.md's Active Spec
 * Directories for the one feature (if exactly one) whose tasks.md has an
 * Approved task that is Planned or In Progress.
 *
 * Never guesses: any artifact that fails to read or parse in a way this
 * module cannot interpret propagates as `cannot-determine` rather than
 * assuming a phase.
 */

import { beforeTaskApproval } from "./pre-approval-review.js";
import { workflowProfile } from "./profile.js";
import { err, ok, type Result } from "./envelope.js";
import { parseActiveSpecDirectories } from "./parsers/agents-md.js";
import { parseTaskState } from "./parsers/tasks.js";
import type { TaskEntry } from "./parsers/task-types.js";
import { guardedRead } from "./path-guard.js";
import type { SddRoot } from "./root.js";

export interface NextCommandData {
  kind: "next-command";
  feature?: string;
  phase: string;
  nextCommand: string;
  rationale: string;
}

function isApprovedShape(approval: string): boolean {
  return approval === "Approved" || approval.startsWith("Approved (");
}

function isActiveStatus(status: TaskEntry["status"]): boolean {
  return status === "Planned" || status === "In Progress";
}

/** Every Approved-shaped task, in tasks.md document order. */
function approvedTasks(tasks: readonly TaskEntry[]): TaskEntry[] {
  return tasks.filter((task) => isApprovedShape(task.approval));
}

/**
 * Determines the next-command phase for a single feature whose tasks.md has
 * already been parsed into a `pass`/`fail` verdict with entries. The caller
 * considers the feature’s pre-implementation review before recommending approval.
 */
function phaseFromTasks(
  feature: string,
  tasks: readonly TaskEntry[],
): NextCommandData {
  const blocked = tasks.filter((task) => task.status === "Blocked");
  if (blocked.length > 0) {
    const ids = blocked.map((task) => task.id).join(", ");
    return {
      kind: "next-command",
      feature,
      phase: "blocked",
      nextCommand: "human: resolve blockers",
      rationale: `Task(s) ${ids} in specs/${feature}/tasks.md are Blocked; review their ` +
        "### Blockers entries and resolve them before further automated progress.",
    };
  }

  const approved = approvedTasks(tasks);
  if (approved.length < tasks.length && approved.every((task) => task.status === "Done")) {
    return {
      kind: "next-command",
      feature,
      phase: "approval-gate",
      nextCommand: "human: approve tasks in tasks.md",
      rationale: `Remaining tasks in specs/${feature}/tasks.md need human approval before implementation.`,
    };
  }

  if (approved.some((task) => isActiveStatus(task.status))) {
    return {
      kind: "next-command",
      feature,
      phase: "implementation",
      nextCommand: `/sdd-ship:ship specs/${feature}/tasks.md`,
      rationale: `specs/${feature}/tasks.md has an Approved task that is Planned or In Progress ` +
        "(AGENTS.md Required Workflow step 6).",
    };
  }

  const implComplete = approved.filter((task) => task.status === "Implementation Complete");
  const firstImplComplete = implComplete[0];
  if (firstImplComplete !== undefined) {
    const targetCommand = approved.every((task) => task.status === "Implementation Complete")
      ? `/sdd-ship:ship specs/${feature}/tasks.md`
      : `/sdd-ship:ship specs/${feature}/tasks.md#${firstImplComplete.id}`;
    return {
      kind: "next-command",
      feature,
      phase: "sdd-gate",
      nextCommand: targetCommand,
      rationale: approved.every((task) => task.status === "Implementation Complete")
        ? `Every Approved task in specs/${feature}/tasks.md is Implementation Complete; run /sdd-ship:ship to execute sdd-gate and transition passed tasks to Done.`
        : `Approved task ${firstImplComplete.id} in specs/${feature}/tasks.md is Implementation Complete; run /sdd-ship:ship to execute sdd-gate and transition passed tasks to Done.`,
    };
  }

  if (approved.every((task) => task.status === "Done")) {
    return {
      kind: "next-command",
      feature,
      phase: "done",
      nextCommand: "feature complete",
      rationale: `Every Approved task in specs/${feature}/tasks.md has reached Done.`,
    };
  }

  return {
    kind: "next-command",
    feature,
    phase: "cannot-determine",
    nextCommand: "cannot-determine",
    rationale: `specs/${feature}/tasks.md's Approved tasks are in an unrecognized mixture of statuses ` +
      "that does not map to a single next command.",
  };
}

/**
 * Determines the next-command phase/command for one feature by walking
 * Required Workflow steps 1-8 in order, stopping at the first gate that has
 * not yet passed.
 */
function nextCommandForFeature(root: SddRoot, feature: string, reports?: ReportLookup): Result<NextCommandData> {
  const profile = workflowProfile(root);
  if (!profile.ok) return profile;
  const requirementsPath = `specs/${feature}/requirements.md`;
  const requirementsResult = guardedRead(root, requirementsPath);
  if (!requirementsResult.ok) {
    if (requirementsResult.error.code !== "not-found") {
      return requirementsResult;
    }
    return ok({
      kind: "next-command",
      feature,
      phase: "bootstrap-not-started",
      nextCommand: `/sdd-bootstrap:bootstrap feature ${feature}`,
      rationale: `${requirementsPath} does not exist yet; run /sdd-bootstrap:bootstrap to generate SDD Core specifications (requirements, design, tasks) and run spec-check.`,
    });
  }

  const designPath = `specs/${feature}/design.md`;
  const designResult = guardedRead(root, designPath);
  if (!designResult.ok) {
    if (designResult.error.code !== "not-found") {
      return designResult;
    }
    return ok({
      kind: "next-command",
      feature,
      phase: "design-missing",
      nextCommand: `/sdd-bootstrap:bootstrap feature ${feature}`,
      rationale: `${designPath} does not exist yet; run /sdd-bootstrap:bootstrap to complete the SDD Core specification package.`,
    });
  }

  const tasksPath = `specs/${feature}/tasks.md`;
  const tasksReadResult = guardedRead(root, tasksPath);
  if (!tasksReadResult.ok) {
    if (tasksReadResult.error.code !== "not-found") {
      return tasksReadResult;
    }
    return ok({
      kind: "next-command",
      feature,
      phase: "tasks-missing",
      nextCommand: `/sdd-bootstrap:bootstrap feature ${feature}`,
      rationale: `${tasksPath} does not exist yet; run /sdd-bootstrap:bootstrap to generate tasks.md and run spec-check.`,
    });
  }

  const taskStateResult = parseTaskState(root, feature, tasksPath, undefined, undefined, reports);
  if (!taskStateResult.ok) {
    return taskStateResult;
  }
  if (taskStateResult.data.verdict === "fail") {
    return err(
      "cannot-determine",
      `${tasksPath} failed its state-machine validation (${taskStateResult.data.failures
        .map((failure) => failure.message)
        .join("; ")}); the next command cannot be determined until this is fixed.`,
      { file: tasksPath, rule: "task-state-verdict-fail" },
    );
  }

  const phase = phaseFromTasks(feature, taskStateResult.data.tasks);
  if (phase.phase === "approval-gate") {
    const review = beforeTaskApproval(root, feature, taskStateResult.data.tasks.every((task) => task.risk === "low"));
    if (review) return ok({ kind: "next-command", feature, phase: review.phase, nextCommand: review.command, rationale: review.rationale });
  }
  return ok(phase);
}

/**
 * Reproduces `sdd-ship:run`'s zero-argument auto-selection rule: exactly one
 * Active Spec Directory feature with an Approved+Planned/In-Progress task ->
 * use it; zero or multiple -> `cannot-determine` naming the candidates.
 */
function autoSelectFeature(root: SddRoot): Result<string> {
  const specsResult = parseActiveSpecDirectories(root);
  if (!specsResult.ok) {
    return specsResult;
  }

  const candidates: string[] = [];
  for (const spec of specsResult.data) {
    const taskStateResult = parseTaskState(root, spec.feature, `specs/${spec.feature}/tasks.md`);
    if (!taskStateResult.ok) {
      continue;
    }
    const hasActiveApproved = approvedTasks(taskStateResult.data.tasks).some((task) =>
      isActiveStatus(task.status),
    );
    if (hasActiveApproved) {
      candidates.push(spec.feature);
    }
  }

  if (candidates.length === 0) {
    return err(
      "cannot-determine",
      "No feature in AGENTS.md's Active Spec Directories has an Approved task that is " +
        "Planned or In Progress; run /sdd-bootstrap:bootstrap first, or pass a feature name.",
      { rule: "auto-select-none-active" },
    );
  }

  if (candidates.length > 1) {
    return err(
      "cannot-determine",
      `Multiple features have an Approved task that is Planned or In Progress: ` +
        `${candidates.join(", ")}. Pass a feature name to disambiguate.`,
      { rule: "auto-select-multiple-active", candidates },
    );
  }

  const selected = candidates[0];
  if (selected === undefined) {
    return err("cannot-determine", "Auto-selection produced no candidate feature.", {
      rule: "auto-select-multiple-active",
    });
  }
  return ok(selected);
}

/**
 * `get_next_sdd_command`'s implementation: with a `feature`, walks that
 * feature's Required Workflow gates in order. Without one, auto-selects a
 * single active feature first (sdd-ship:run's zero-argument rule) and then
 * applies the same gate walk.
 */
export function getNextSddCommand(root: SddRoot, feature?: string, reports?: ReportLookup): Result<NextCommandData> {
  if (feature !== undefined) {
    return nextCommandForFeature(root, feature, reports);
  }

  const selected = autoSelectFeature(root);
  if (!selected.ok) {
    return selected;
  }
  return nextCommandForFeature(root, selected.data, reports);
}
