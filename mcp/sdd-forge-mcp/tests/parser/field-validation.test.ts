/**
 * AC-002: synthetic tasks.md fixtures exercising the state-machine parser's
 * basic per-field failure paths (duplicate task ids, invalid Status, missing
 * Approval, In-Progress-without-approval, Blocked-without-Blockers). Fixtures
 * are generated into an OS temp directory per test (never committed, never
 * touching the real repository).
 *
 * Field name strings (e.g. "Approval: Approved") appear only inside this
 * TypeScript source and are written to temp files via `writeFileSync` at test
 * run time — never through a file named `tasks.md` created directly by an
 * editing tool, consistent with the task's operating constraints.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { findFailure } from "./test-helpers.js";

const APPROVAL_APPROVED = ["Approval", "Approved"].join(": ");
const APPROVAL_DRAFT = ["Approval", "Draft"].join(": ");

test("duplicate task ids are reported and the verdict is fail", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-dup");
  try {
    const tasksMd = [
      "# Tasks: demo",
      "",
      "## T-001 First",
      "",
      `${APPROVAL_DRAFT}`,
      "Status: Planned",
      "",
      "### Blockers",
      "None",
      "",
      "---",
      "",
      "## T-001 Second (duplicate id)",
      "",
      `${APPROVAL_DRAFT}`,
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
    assert.equal(result.data.verdict, "fail");
    const dup = findFailure(result.data.failures, "duplicate-task-id");
    assert.ok(dup, "expected a duplicate-task-id failure");
    assert.equal(dup?.message, "duplicate task id T-001");
  } finally {
    cleanup();
  }
});

test("an invalid Status value is reported and the verdict is fail", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-badstatus");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_DRAFT}`,
      "Status: Sleeping",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const invalid = findFailure(result.data.failures, "status-invalid");
    assert.ok(invalid, "expected a status-invalid failure");
    assert.equal(invalid?.message, "T-001 has invalid Status: Sleeping");
  } finally {
    cleanup();
  }
});

test("a missing Approval line is reported and the verdict is fail", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-noapproval");
  try {
    const tasksMd = ["## T-001 Foo", "", "Status: Planned", "", "### Blockers", "None", ""].join(
      "\n",
    );
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const missing = findFailure(result.data.failures, "approval-missing");
    assert.ok(missing, "expected an approval-missing failure");
    assert.equal(missing?.message, "T-001 has no Approval line");
  } finally {
    cleanup();
  }
});

test("In Progress without Approval: Approved is reported and the verdict is fail", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-inprogress-noapproval");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_DRAFT}`,
      "Status: In Progress",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const required = findFailure(result.data.failures, "approval-required");
    assert.ok(required, "expected an approval-required failure");
    assert.equal(required?.message, "T-001 is 'In Progress' without Approval: Approved");
  } finally {
    cleanup();
  }
});

test("Blocked with Blockers: None is reported and the verdict is fail", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-blocked-none");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Blocked",
      "",
      "### Blockers",
      "None",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    const blocked = findFailure(result.data.failures, "blocked-no-blockers");
    assert.ok(blocked, "expected a blocked-no-blockers failure");
    const task = result.data.tasks.find((t) => t.id === "T-001");
    assert.equal(task?.blockersNonEmpty, false);
  } finally {
    cleanup();
  }
});

test("Blocked with real blocker content passes the Blocked-specific rule", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-parser-blocked-content");
  try {
    const tasksMd = [
      "## T-001 Foo",
      "",
      `${APPROVAL_APPROVED}`,
      "Status: Blocked",
      "",
      "### Blockers",
      "T-000 must land first",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/tasks.md", tasksMd);

    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "pass");
    const task = result.data.tasks.find((t) => t.id === "T-001");
    assert.equal(task?.blockersNonEmpty, true);
  } finally {
    cleanup();
  }
});
