/**
 * T-003: quality gate report parser tests — `reports/quality-gate/*.md`.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { listQualityReports, parseQualityReport } from "../../src/parsers/quality-report.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { makeRealRepoRoot } from "./test-helpers.js";

test("real repo: every reports/quality-gate/*.md file is scanned without throwing", () => {
  const root = makeRealRepoRoot();
  const scan = listQualityReports(root);
  assert.ok(
    scan.reports.length + scan.failures.length >= 1,
    "expected at least one quality-gate report file",
  );
  for (const report of scan.reports) {
    assert.ok(report.file.endsWith(".md"));
    assert.ok(report.verdict.length > 0);
  }
  for (const failure of scan.failures) {
    assert.ok(failure.file.endsWith(".md"));
    assert.ok(failure.rule === "verdict-not-found" || failure.rule === "unreadable");
  }
});

test("real repo: at least one report has taskId, critical/major/minor counts, and a PASS-shaped verdict", () => {
  const root = makeRealRepoRoot();
  const scan = listQualityReports(root);
  const withCounts = scan.reports.find(
    (r) => r.critical !== undefined && r.major !== undefined && r.minor !== undefined,
  );
  assert.ok(withCounts !== undefined, "expected at least one report with finding counts");
  assert.ok(withCounts?.taskId !== undefined && /^T-\d+$/.test(withCounts.taskId));
});

test("synthetic: well-formed report with all fields parses every value", () => {
  const { root, cleanup } = makeTempSddRoot("quality-report-pass");
  try {
    const md = [
      "# Quality Gate Report",
      "",
      "Task ID: T-042",
      "Feature: demo-feature",
      "Risk: high",
      "",
      "VERDICT: PASS",
      "Critical: 0",
      "Major: 1",
      "Minor: 2",
      "",
      "## Summary",
      "",
      "All good.",
      "",
    ].join("\n");
    writeFile(root.path, "reports/quality-gate/T-042.md", md);

    const result = parseQualityReport(root, "reports/quality-gate/T-042.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.entry, {
      file: "reports/quality-gate/T-042.md",
      taskId: "T-042",
      feature: "demo-feature",
      verdict: "PASS",
      critical: 0,
      major: 1,
      minor: 2,
    });
  } finally {
    cleanup();
  }
});

test("synthetic: VERDICT repeated later in the file uses the first occurrence", () => {
  const { root, cleanup } = makeTempSddRoot("quality-report-repeated-verdict");
  try {
    const md = [
      "Task ID: T-002",
      "VERDICT: NEEDS_WORK",
      "",
      "## Follow-up",
      "",
      "Follow-up verdict: PASS.",
      "",
    ].join("\n");
    writeFile(root.path, "reports/quality-gate/T-002-followup.md", md);

    const result = parseQualityReport(root, "reports/quality-gate/T-002-followup.md");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.entry.verdict, "NEEDS_WORK");
    assert.equal(result.entry.feature, undefined);
    assert.equal(result.entry.critical, undefined);
  } finally {
    cleanup();
  }
});

test("synthetic: report with no VERDICT line is reported as verdict-not-found, not cannot-parse", () => {
  const { root, cleanup } = makeTempSddRoot("quality-report-no-verdict");
  try {
    const md = ["# Quality Gate Report", "", "Task ID: T-099", "", "no verdict here", ""].join(
      "\n",
    );
    writeFile(root.path, "reports/quality-gate/T-099.md", md);

    const result = parseQualityReport(root, "reports/quality-gate/T-099.md");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.failure.rule, "verdict-not-found");
    assert.equal(result.failure.file, "reports/quality-gate/T-099.md");
  } finally {
    cleanup();
  }
});

test("listQualityReports aggregates reports and failures across a directory", () => {
  const { root, cleanup } = makeTempSddRoot("quality-report-scan-mixed");
  try {
    writeFile(
      root.path,
      "reports/quality-gate/T-001.md",
      ["Task ID: T-001", "VERDICT: PASS", "Critical: 0", "Major: 0", "Minor: 0", ""].join("\n"),
    );
    writeFile(
      root.path,
      "reports/quality-gate/T-002.md",
      ["Task ID: T-002", "no verdict line at all", ""].join("\n"),
    );
    writeFile(root.path, "reports/quality-gate/.gitkeep", "");

    const scan = listQualityReports(root);
    assert.equal(scan.reports.length, 1);
    assert.equal(scan.reports[0]?.taskId, "T-001");
    assert.equal(scan.failures.length, 1);
    assert.equal(scan.failures[0]?.file, "reports/quality-gate/T-002.md");
    assert.equal(scan.failures[0]?.rule, "verdict-not-found");
  } finally {
    cleanup();
  }
});
