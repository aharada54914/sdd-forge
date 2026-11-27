/**
 * Task ids are unique only within a feature, so Done evidence must not come
 * from a quality-gate report that declares another feature. A report with no
 * `Feature:` line (written before the identity block was required) still
 * counts.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { evidenceFindMissing } from "../../src/tools/evidence.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { findFailure } from "./test-helpers.js";

const DONE_TASK = ["## T-001 Foo", "", ["Approval", "Approved"].join(": "), "Status: Done", "Risk: low", "", "### Blockers", "None", ""].join("\n");

function report(feature: string | null): string {
  return ["# Quality Gate Report", "", "Task ID: T-001", ...(feature === null ? [] : [`Feature: ${feature}`]), "VERDICT: PASS", ""].join("\n");
}

function v2Feature(rootPath: string): void {
  writeFile(rootPath, "specs/demo/tasks.md", DONE_TASK);
  writeFile(rootPath, "specs/demo/.spec-baseline.json", "{}");
}

test("v2 Done: a PASS report that declares another feature is not evidence", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-other");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other"));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.verdict, "fail");
    assert.ok(findFailure(result.data.failures, "done-quality-gate-report-missing"), JSON.stringify(result.data.failures));
  } finally {
    cleanup();
  }
});

test("v2 Done: another feature's FAIL report does not hide this feature's PASS", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-mixed");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/demo-T-001.md", report("demo"));
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other").replace("VERDICT: PASS", "VERDICT: FAIL"));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.failures, []);
  } finally {
    cleanup();
  }
});

test("v2 Done: a PASS report without a Feature line still counts", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-legacy");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/T-001.md", report(null));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data.failures, []);
  } finally {
    cleanup();
  }
});

test("v2 Done: a report naming another feature only after its identity block is not evidence", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-first-line");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other") + "\nFeature: demo\n");
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(findFailure(result.data.failures, "done-quality-gate-report-missing"), JSON.stringify(result.data.failures));
  } finally {
    cleanup();
  }
});

test("lite Done: a PASS report that declares another feature is not evidence", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-lite");
  try {
    writeFile(root.path, "AGENTS.md", "# A\n\n## Project Settings\n\nspec_profile: lite\n");
    writeFile(root.path, "specs/demo/tasks.md", DONE_TASK);
    writeFile(root.path, "reports/implementation/T-001.md", "T-001\n");
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other"));
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(findFailure(result.data.failures, "done-quality-gate-verdict-fail"), JSON.stringify(result.data.failures));
  } finally {
    cleanup();
  }
});

test("evidence_find_missing: another feature's PASS report does not satisfy the requirement", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-find-missing");
  try {
    v2Feature(root.path);
    writeFile(root.path, "reports/quality-gate/other-T-001.md", report("other"));
    const result = evidenceFindMissing(root, "demo", "T-001");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.ok(result.data.missing.includes("quality-gate-report-pass"), JSON.stringify(result.data));
  } finally {
    cleanup();
  }
});

function doneFails(name: string, files: Record<string, string>, expected: boolean): void {
  const { root, cleanup } = makeTempSddRoot(`sdd-done-scope-${name}`);
  try {
    v2Feature(root.path);
    writeFile(root.path, "specs/other/tasks.md", DONE_TASK);
    writeFile(root.path, "specs/demo-extra/tasks.md", DONE_TASK);
    for (const [path, contents] of Object.entries(files)) writeFile(root.path, path, contents);
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.failures.length > 0, expected, `${name}: ${JSON.stringify(result.data.failures)}`);
  } finally {
    cleanup();
  }
}

const OTHER_REPORT_SHAPES: Record<string, string> = {
  "gate-template": "# SDD Gate Report: other / T-001\n\n- **Task ID**: T-001\n- **Feature**: other\n- **VERDICT**: PASS\n",
  "bullet": "- Task ID: T-001\n- Feature: other\nVERDICT: PASS\n",
  "bold-colon-inside": "**Task ID:** T-001\n**Feature:** other\nVERDICT: PASS\n",
  "backticks": "Task ID: T-001\nFeature: `other`\nVERDICT: PASS\n",
  "bom": "﻿Feature: other\nTask ID: T-001\nVERDICT: PASS\n",
  "lowercase": "task id: T-001\nfeature: other\nVERDICT: PASS\n",
};

for (const [shape, contents] of Object.entries(OTHER_REPORT_SHAPES)) {
  test(`v2 Done: another feature's report in the ${shape} shape is not evidence`, () => {
    doneFails(shape, { "reports/quality-gate/r.md": contents }, true);
  });
}

test("v2 Done: this feature's report in the gate-template shape is evidence", () => {
  doneFails("own-template", {
    "reports/quality-gate/demo-T-001.md": "# SDD Gate Report: demo / T-001\n\n- **Task ID**: T-001\n- **Feature**: demo\n- **VERDICT**: PASS\n",
  }, false);
});

test("v2 Done: block-quoted and fenced Feature lines are not the declaration", () => {
  doneFails("quoted", {
    "reports/quality-gate/r.md": "Task ID: T-001\n> Feature: other\n```\nFeature: other\n```\nFeature: demo\nVERDICT: PASS\n",
  }, false);
});

test("v2 Done: a report file named for another feature is not evidence", () => {
  doneFails("filename", { "reports/quality-gate/2026-07-15T133723Z-other-T-001.md": report(null) }, true);
});

test("v2 Done: the longest feature name in the file name wins", () => {
  doneFails("filename-longest", { "reports/quality-gate/2026-07-15T133723Z-demo-extra-T-001.md": report(null) }, true);
  doneFails("filename-own", { "reports/quality-gate/2026-07-15T133723Z-demo-T-001.md": report(null) }, false);
});

test("v2 Done: a file name whose prefix is no spec directory still counts", () => {
  doneFails("filename-unknown", { "reports/quality-gate/2026-07-15T133723Z-T-001.md": report(null) }, false);
});

test("Done failure names the feature it looked for", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-done-scope-message");
  try {
    v2Feature(root.path);
    const result = parseTaskState(root, "demo", "specs/demo/tasks.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(findFailure(result.data.failures, "done-quality-gate-report-missing")?.message,
      "T-001 is Done but no quality-gate report for feature demo in reports/quality-gate mentions it");
  } finally {
    cleanup();
  }
});

test("a long run of spaces in a Feature line is read in linear time", () => {
  const started = Date.now();
  doneFails("long-line", { "reports/quality-gate/r.md": "Task ID: T-001\nFeature: other" + " ".repeat(200_000) + "x\nVERDICT: PASS\n" }, true);
  assert.ok(Date.now() - started < 2000, `took ${Date.now() - started} ms`);
});
