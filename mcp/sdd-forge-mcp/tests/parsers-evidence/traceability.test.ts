/**
 * T-011: traceability.md table-extraction parser tests.
 *
 * `specs/<feature>/traceability.md` section headings vary by feature (see
 * design.md "Data Plan": `traceability.md -> traceability.ts`), so
 * `parseTraceability` identifies each markdown table by its header row's
 * column names rather than by section heading text. This suite is exercised
 * against both real traceability.md files under version control
 * (sdd-forge-refactor and sdd-forge-mcp) plus synthetic malformed fixtures.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseTraceability } from "../../src/parsers/traceability.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { makeRealRepoRoot } from "./test-helpers.js";

test("real repo: sdd-forge-refactor/traceability.md yields REQ->Task and AC->REQ rows", () => {
  const root = makeRealRepoRoot();
  const result = parseTraceability(root, "sdd-forge-refactor");
  assert.equal(result.ok, true);
  if (!result.ok) return;

  assert.ok(result.data.reqToTask.length >= 1);
  for (const row of result.data.reqToTask) {
    assert.ok(/^REQ-\d+$/.test(row.reqId));
    assert.ok(row.taskIds.length >= 1);
    for (const taskId of row.taskIds) {
      assert.ok(/^T-\d+/.test(taskId), `unexpected taskId shape: ${taskId}`);
    }
  }

  assert.ok(result.data.acToReq.length >= 1);
  for (const row of result.data.acToReq) {
    assert.ok(/^AC-\d+$/.test(row.acId));
    assert.ok(row.reqIds.length >= 1);
    for (const reqId of row.reqIds) {
      assert.ok(/^REQ-\d+$/.test(reqId), `unexpected reqId shape: ${reqId}`);
    }
  }

  // sdd-forge-refactor/traceability.md has no "AC -> TEST -> Task" table.
  assert.deepEqual(result.data.acToTestToTask, []);
});

test("real repo: sdd-forge-mcp/traceability.md yields REQ->Task, AC->REQ, and AC->TEST->Task rows", () => {
  const root = makeRealRepoRoot();
  const result = parseTraceability(root, "sdd-forge-mcp");
  assert.equal(result.ok, true);
  if (!result.ok) return;

  assert.ok(result.data.reqToTask.length >= 10, "expected REQ-001..REQ-011 rows");
  const req003 = result.data.reqToTask.find((row) => row.reqId === "REQ-003");
  assert.ok(req003 !== undefined);
  assert.deepEqual(req003?.taskIds, ["T-011", "T-005"]);

  assert.ok(result.data.acToReq.length >= 17, "expected AC-001..AC-017 rows");
  const ac014 = result.data.acToReq.find((row) => row.acId === "AC-014");
  assert.deepEqual(ac014?.reqIds, ["REQ-003"]);

  assert.ok(result.data.acToTestToTask.length >= 17);
  const ac014Test = result.data.acToTestToTask.find((row) => row.acId === "AC-014");
  assert.equal(ac014Test?.testId, "TEST-014");
  assert.deepEqual(ac014Test?.taskIds, ["T-005"]);
  assert.ok(ac014Test?.target?.includes("tests/evidence"));
});

test("synthetic: a REQ->Task table with comma-separated Task-ID cells splits into multiple taskIds", () => {
  const { root, cleanup } = makeTempSddRoot("traceability-req-task-multi");
  try {
    const md = [
      "# Traceability: demo",
      "",
      "## REQ -> Task",
      "",
      "| REQ-ID | Task-ID |",
      "|--------|---------|",
      "| REQ-001 | T-001, T-002 |",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/traceability.md", md);

    const result = parseTraceability(root, "demo");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.reqToTask, [{ reqId: "REQ-001", taskIds: ["T-001", "T-002"] }]);
  } finally {
    cleanup();
  }
});

test("synthetic: no tables at all in traceability.md yields empty arrays, not cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("traceability-no-tables");
  try {
    writeFile(root.path, "specs/demo/traceability.md", "# Traceability: demo\n\nNothing here yet.\n");

    const result = parseTraceability(root, "demo");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.reqToTask, []);
    assert.deepEqual(result.data.acToReq, []);
    assert.deepEqual(result.data.acToTestToTask, []);
  } finally {
    cleanup();
  }
});

test("synthetic: a REQ->Task table with a missing column in a data row is cannot-parse with a line number", () => {
  const { root, cleanup } = makeTempSddRoot("traceability-malformed-row");
  try {
    const md = [
      "## REQ -> Task",
      "",
      "| REQ-ID | Task-ID |",
      "|--------|---------|",
      "| REQ-001 | T-001 |",
      "| REQ-002 |",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/traceability.md", md);

    const result = parseTraceability(root, "demo");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.line, 6);
  } finally {
    cleanup();
  }
});

test("synthetic: an AC->REQ table with an empty Task-ID-like required cell is cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("traceability-empty-cell");
  try {
    const md = [
      "## AC -> REQ",
      "",
      "| AC-ID | REQ-ID | 検証内容 |",
      "|-------|--------|---------|",
      "| AC-001 |  | something |",
      "",
    ].join("\n");
    writeFile(root.path, "specs/demo/traceability.md", md);

    const result = parseTraceability(root, "demo");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.line, 5);
  } finally {
    cleanup();
  }
});

test("synthetic: propagates a not-found error when traceability.md is absent", () => {
  const { root, cleanup } = makeTempSddRoot("traceability-not-found");
  try {
    const result = parseTraceability(root, "demo");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "not-found");
  } finally {
    cleanup();
  }
});
