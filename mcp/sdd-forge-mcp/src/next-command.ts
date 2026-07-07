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

import { err, ok, type Result } from "./envelope.js";
import { parseActiveSpecDirectories } from "./parsers/agents-md.js";
import { extractHeaderValue } from "./parsers/spec-header.js";
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
 * already been parsed into a `pass`/`fail` verdict with entries. Assumes
 * requirements.md/design.md/tasks.md review-status gates have already passed
 * (the caller checks those first) — this function only walks the task state
 * machine itself (Required Workflow steps 5-8).
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
  if (approved.length === 0) {
    return {
      kind: "next-command",
      feature,
      phase: "approval-gate",
      nextCommand: "human: approve tasks in tasks.md",
      rationale: `specs/${feature}/tasks.md has no Approved-shaped task; a human must set ` +
        "Approval: Approved on the tasks to be implemented next (AGENTS.md Required Workflow step 5).",
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

  if (approved.every((task) => task.status === "Implementation Complete")) {
    return {
      kind: "next-command",
      feature,
      phase: "quality-gate",
      nextCommand: `/sdd-quality-loop:quality-gate specs/${feature}/tasks.md`,
      rationale: `Every Approved task in specs/${feature}/tasks.md is Implementation Complete ` +
        "(AGENTS.md Required Workflow step 7).",
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
    rationale: `specs/${feature}/tasks.md's Approved tasks are in a mixture of statuses ` +
      "(some Implementation Complete, some Done, none Planned/In Progress/Blocked) that " +
      "does not map to a single next command.",
  };
}

/**
 * Determines the next-command phase/command for one feature by walking
 * Required Workflow steps 1-8 in order, stopping at the first gate that has
 * not yet passed.
 */
function nextCommandForFeature(root: SddRoot, feature: string): Result<NextCommandData> {
  const requirementsPath = `specs/${feature}/requirements.md`;
  const requirementsResult = guardedRead(root, requirementsPath);
  if (!requirementsResult.ok) {
    // A denied/invalid/too-large path is a distinct failure from "the
    // artifact legitimately does not exist yet" (`not-found`) — never guess
    // phase1-not-started for a path the guard refused to even evaluate.
    if (requirementsResult.error.code !== "not-found") {
      return requirementsResult;
    }
    return ok({
      kind: "next-command",
      feature,
      phase: "phase1-not-started",
      nextCommand: `/sdd-bootstrap:bootstrap feature ${feature}`,
      rationale: `${requirementsPath} does not exist yet; Phase 1 (requirements, design, ` +
        "acceptance tests) has not been started (AGENTS.md Required Workflow step 1).",
    });
  }

  const specReviewStatus = extractHeaderValue(requirementsResult.data.contents, "Spec-Review-Status");
  if (specReviewStatus !== "Passed") {
    return ok({
      kind: "next-command",
      feature,
      phase: "spec-review",
      nextCommand: `/sdd-review-loop:spec-review-loop --feature ${feature}`,
      rationale: `${requirementsPath}'s Spec-Review-Status is ` +
        `${specReviewStatus === undefined ? "missing" : `"${specReviewStatus}"`}, not Passed ` +
        "(AGENTS.md Required Workflow step 2).",
    });
  }

  const designPath = `specs/${feature}/design.md`;
  const designResult = guardedRead(root, designPath);
  if (!designResult.ok) {
    if (designResult.error.code !== "not-found") {
      return designResult;
    }
    return err(
      "cannot-determine",
      `${requirementsPath} has Spec-Review-Status: Passed but ${designPath} does not exist ` +
        "or cannot be read; this combination is not a recognized workflow state.",
      { file: designPath, rule: "design-missing-after-spec-review-passed" },
    );
  }

  const implReviewStatus = extractHeaderValue(designResult.data.contents, "Impl-Review-Status");
  if (implReviewStatus !== "Passed") {
    return ok({
      kind: "next-command",
      feature,
      phase: "impl-review",
      nextCommand: `/sdd-review-loop:impl-review-loop --feature ${feature}`,
      rationale: `${designPath}'s Impl-Review-Status is ` +
        `${implReviewStatus === undefined ? "missing" : `"${implReviewStatus}"`}, not Passed ` +
        "(AGENTS.md Required Workflow step 3).",
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
      phase: "phase2-not-started",
      nextCommand: "/sdd-bootstrap:bootstrap feature",
      rationale: `${tasksPath} does not exist yet; Phase 2 (Draft tasks) has not been started ` +
        "(AGENTS.md Required Workflow step 4).",
    });
  }

  const taskReviewStatus = extractHeaderValue(tasksReadResult.data.contents, "Task-Review-Status");
  if (taskReviewStatus !== "Passed") {
    return ok({
      kind: "next-command",
      feature,
      phase: "task-review",
      nextCommand: `/sdd-review-loop:task-review-loop --feature ${feature}`,
      rationale: `${tasksPath}'s Task-Review-Status is ` +
        `${taskReviewStatus === undefined ? "missing" : `"${taskReviewStatus}"`}, not Passed ` +
        "(AGENTS.md Required Workflow step 4).",
    });
  }

  const taskStateResult = parseTaskState(root, feature, tasksPath);
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

  return ok(phaseFromTasks(feature, taskStateResult.data.tasks));
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
export function getNextSddCommand(root: SddRoot, feature?: string): Result<NextCommandData> {
  if (feature !== undefined) {
    return nextCommandForFeature(root, feature);
  }

  const selected = autoSelectFeature(root);
  if (!selected.ok) {
    return selected;
  }
  return nextCommandForFeature(root, selected.data);
}
