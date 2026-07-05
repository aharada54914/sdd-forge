/**
 * AC-002: baseline passing-path fixtures plus path-guard/no-tasks-found
 * propagation checks for the tasks.md state-machine parser.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { findFailure } from "./test-helpers.js";

const APPROVAL_DRAFT = ["Approval", "Draft"].join(": ");

test("a well-formed tasks.md with a Planned task passes with an empty failures array", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-pass-planned");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_DRAFT}`,
      "Status: Planned",
      "Risk: medium",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.failures, []);
    assert.equal(result.data.verdict, "pass");
    assert.equal(result.data.taskCount, 1);
    assert.deepEqual(result.data.tasks, [
      {
        id: "T-001",
        approval: "Draft",
        status: "Planned",
        risk: "medium",
        blockersNonEmpty: false,
      },
    ]);
  } finally {
    cleanup();
  }
});

test("Approved (<annotation>) is accepted and the annotation is echoed back", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-annotation");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      "Approval: Approved (waived pending human sign-off)",
      "Status: Planned",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "pass");
    const task = result.data.tasks.find((t) => t.id === "T-001");
    assert.equal(task?.approvalAnnotation, "waived pending human sign-off");
  } finally {
    cleanup();
  }
});

test("a tasks.md with no ## T-NNN headers at all fails with no-tasks-found", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-notasks");
  try {
    writeFile(root.path, "specs/demo/tasks.md", "# Tasks: demo\n\nNothing here yet.\n");

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    assert.equal(result.data.taskCount, 0);
    const noTasks = findFailure(result.data.failures, "no-tasks-found");
    assert.ok(noTasks, "expected a no-tasks-found failure");
  } finally {
    cleanup();
  }
});

test("a nonexistent tasks.md path propagates the path-guard not-found error", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-missingfile");
  try {
    mkdirSync(join(root.path, "specs", "demo"), { recursive: true });
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "not-found");
  } finally {
    cleanup();
  }
});

test("a tasks.md path outside the allowlist propagates path-denied", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-denied");
  try {
    mkdirSync(join(root.path, "plugins"), { recursive: true });
    writeFileSync(join(root.path, "plugins", "tasks.md"), "## T-001 Foo\n", "utf-8");
    const result = parseTaskState(root, "demo", "plugins/tasks.md");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "path-denied");
  } finally {
    cleanup();
  }
});
