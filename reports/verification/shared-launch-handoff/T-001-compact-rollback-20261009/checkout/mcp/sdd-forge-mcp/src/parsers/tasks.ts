/**
 * tasks.md state-machine parser — shell-equivalent of
 * `plugins/sdd-quality-loop/scripts/check-task-state.sh`.
 *
 * This module must reproduce that shell script's verdict and failure
 * messages 1:1 (AC-001, design.md "API / Contract Plan"). The shell script is
 * read-only reference material; it is never modified or shelled out to from
 * this module (per task instructions, only test code may invoke it).
 *
 * Per-task field validation (the awk script's `finish()` function) lives in
 * `./task-validation.ts`; `Done` evidence-bundle validation (which
 * check-task-state.sh performs by shelling out to check-evidence-bundle.sh)
 * lives in `./evidence-bundle.ts`, reproduced as pure TypeScript so this
 * parser never spawns a child process. This module itself is only the line
 * scanner that walks tasks.md and accumulates each task's raw field text,
 * mirroring the awk script's top-level pattern/action rules.
 *
 * `parseTaskState` never fabricates a fallback value: reading tasks.md itself
 * (not-found / too-large / path-denied) propagates the path-guard error
 * envelope unchanged, and an empty parse (no `## T-NNN` headers found) is a
 * valid-but-failing state — mirroring the shell script's own `no tasks found`
 * exit 1 — surfaced as a `fail` verdict rather than `cannot-parse`.
 */

import { ok, type Result } from "../envelope.js";
import { guardedRead } from "../path-guard.js";
import type { SddRoot } from "../root.js";
import { finishTask } from "./task-validation.js";
import { newDraft, type TaskDraft, type TaskEntry, type TaskFailure, type TaskStateData } from "./task-types.js";

export type { Approval, Risk, Status, TaskEntry, TaskFailure, TaskStateData } from "./task-types.js";

const TASK_HEADER_PATTERN = /^## (T-\d+)/;

/** Strips a trailing CR so CRLF-encoded tasks.md parses identically to LF (shell parity). */
function stripTrailingCr(line: string): string {
  return line.endsWith("\r") ? line.slice(0, -1) : line;
}

/**
 * Splits file contents into lines the same way the awk script consumes
 * records: a trailing newline does not produce a spurious empty final line.
 */
function splitLines(contents: string): string[] {
  const normalized = contents.endsWith("\n") ? contents.slice(0, -1) : contents;
  if (normalized.length === 0) {
    return [];
  }
  return normalized.split("\n");
}

/** Directory containing `relTasksFilePath`, using `.` when the file is at the root (mirrors the awk script's `sub` trick). */
function parentDir(relTasksFilePath: string): string {
  const idx = relTasksFilePath.lastIndexOf("/");
  return idx === -1 ? "." : relTasksFilePath.slice(0, idx);
}

/**
 * Parses and validates a tasks.md state machine, shell-equivalent to
 * `check-task-state.sh <tasksFile> [reportsDir] [implReportsDir]`.
 *
 * @param feature the feature name this tasks.md belongs to (echoed in the result)
 * @param relTasksFilePath path-guard-relative path to tasks.md (e.g. `specs/<feature>/tasks.md`)
 * @param reportsDir path-guard-relative quality-gate reports directory (default `reports/quality-gate`)
 * @param implReportsDir path-guard-relative implementation reports directory (default `reports/implementation`)
 */
export function parseTaskState(
  root: SddRoot,
  feature: string,
  relTasksFilePath: string,
  reportsDir = "reports/quality-gate",
  implReportsDir = "reports/implementation",
): Result<TaskStateData> {
  const fileResult = guardedRead(root, relTasksFilePath);
  if (!fileResult.ok) {
    return fileResult;
  }

  const lines = splitLines(fileResult.data.contents);
  const tasksDir = parentDir(relTasksFilePath);

  const failures: TaskFailure[] = [];
  const tasks: TaskEntry[] = [];
  const seen = new Set<string>();
  let draft: TaskDraft | undefined;

  const finish = (): void => {
    if (draft !== undefined) {
      finishTask(draft, root, tasksDir, reportsDir, implReportsDir, failures, tasks);
    }
  };

  for (const rawLine of lines) {
    const line = stripTrailingCr(rawLine);

    const headerMatch = TASK_HEADER_PATTERN.exec(line);
    if (headerMatch?.[1] !== undefined) {
      finish();
      const newId = headerMatch[1];
      if (seen.has(newId)) {
        failures.push({
          taskId: newId,
          rule: "duplicate-task-id",
          message: `duplicate task id ${newId}`,
        });
      }
      seen.add(newId);
      draft = newDraft(newId);
      continue;
    }

    if (draft === undefined) {
      continue;
    }

    if (line.startsWith("Approval:")) {
      draft.approval = line.slice("Approval:".length).trim();
      draft.inBlockers = false;
      continue;
    }
    if (line.startsWith("Status:")) {
      draft.status = line.slice("Status:".length).trim();
      draft.inBlockers = false;
      continue;
    }
    if (line.startsWith("Risk:")) {
      draft.risk = line.slice("Risk:".length).trim().toLowerCase();
      draft.inBlockers = false;
      continue;
    }
    if (line.startsWith("Second Approval:")) {
      draft.second = line.slice("Second Approval:".length).trim();
      draft.inBlockers = false;
      continue;
    }
    if (/^### Blockers/.test(line)) {
      draft.inBlockers = true;
      continue;
    }
    if (/^## [^#]/.test(line) && !TASK_HEADER_PATTERN.test(line)) {
      draft.inBlockers = false;
      continue;
    }

    if (draft.inBlockers && !/^### Blockers/.test(line)) {
      const stripped = line.replace(/^[ \t]*[-*][ \t]*/, "").replace(/^[ \t]+/, "");
      if (stripped !== "" && stripped.toLowerCase() !== "none") {
        draft.blockersContent += stripped;
      }
    }
  }
  finish();

  if (seen.size === 0) {
    // Shell-equivalent: `if (count == 0) { print "no tasks found"; exit 1 }`.
    // This is a valid (empty) parse, not a malformed-input case, so it
    // surfaces as a `fail` verdict rather than `cannot-parse`.
    failures.push({
      rule: "no-tasks-found",
      message: "check-task-state: no tasks found",
    });
  }

  return ok({
    kind: "task-state",
    feature,
    tasksFile: relTasksFilePath,
    verdict: failures.length > 0 ? "fail" : "pass",
    taskCount: seen.size,
    tasks,
    failures,
  });
}
