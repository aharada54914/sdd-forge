/**
 * T-003: AGENTS.md parser tests — `## Active Spec Directories` and
 * `## Required Workflow` extraction.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { unlinkSync } from "node:fs";
import { join } from "node:path";
import { parseActiveSpecDirectories, parseRequiredWorkflow } from "../../src/parsers/agents-md.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { makeRealRepoRoot } from "./test-helpers.js";

test("real repo: Active Spec Directories has at least 3 entries with feature/path", () => {
  const root = makeRealRepoRoot();
  const result = parseActiveSpecDirectories(root);
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.ok(result.data.length >= 3, `expected >= 3 active specs, got ${result.data.length}`);
  for (const spec of result.data) {
    assert.ok(spec.feature.length > 0);
    assert.equal(spec.path, `specs/${spec.feature}/`);
  }
  assert.ok(result.data.some((s) => s.feature === "sdd-forge-mcp"));
});

test("real repo: Required Workflow has numbered steps with non-empty text", () => {
  const root = makeRealRepoRoot();
  const result = parseRequiredWorkflow(root);
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.ok(result.data.length >= 1, "expected at least one workflow step");
  for (const step of result.data) {
    assert.ok(Number.isInteger(step.step) && step.step >= 1);
    assert.ok(step.text.length > 0);
  }
  // Steps should be in ascending numeric order as written in AGENTS.md.
  for (let i = 1; i < result.data.length; i += 1) {
    const prev = result.data[i - 1];
    const curr = result.data[i];
    assert.ok(prev !== undefined && curr !== undefined && curr.step > prev.step);
  }
});

test("synthetic: well-formed Active Spec Directories bullets parse to feature/path pairs", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-pass");
  try {
    const agentsMd = [
      "# AGENTS.md",
      "",
      "## Active Spec Directories",
      "",
      "Update this list whenever a new spec directory is bootstrapped:",
      "- `specs/foo/`",
      "- `specs/bar-baz/`",
      "",
      "## Required Workflow",
      "",
      "1. Do the first thing.",
      "2. Do the second thing.",
      "",
    ].join("\n");
    writeFile(root.path, "AGENTS.md", agentsMd);

    const result = parseActiveSpecDirectories(root);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data, [
      { feature: "foo", path: "specs/foo/" },
      { feature: "bar-baz", path: "specs/bar-baz/" },
    ]);
  } finally {
    cleanup();
  }
});

test("synthetic: well-formed Required Workflow numbered steps parse in order", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-workflow-pass");
  try {
    const agentsMd = [
      "# AGENTS.md",
      "",
      "## Required Workflow",
      "",
      "1. First step text.",
      "2. Second step text.",
      "3. Third step text.",
      "",
      "## Sources Of Truth",
      "",
      "- something else",
      "",
    ].join("\n");
    writeFile(root.path, "AGENTS.md", agentsMd);

    const result = parseRequiredWorkflow(root);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data, [
      { step: 1, text: "First step text." },
      { step: 2, text: "Second step text." },
      { step: 3, text: "Third step text." },
    ]);
  } finally {
    cleanup();
  }
});

test("cannot-determine: AGENTS.md with no Active Spec Directories section", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-missing-section");
  try {
    writeFile(root.path, "AGENTS.md", "# AGENTS.md\n\n## Some Other Section\n\ntext\n");

    const result = parseActiveSpecDirectories(root);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-determine");
    assert.equal(result.error.details?.file, "AGENTS.md");
  } finally {
    cleanup();
  }
});

test("cannot-determine: AGENTS.md with no Required Workflow section", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-missing-workflow-section");
  try {
    writeFile(root.path, "AGENTS.md", "# AGENTS.md\n\n## Some Other Section\n\ntext\n");

    const result = parseRequiredWorkflow(root);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-determine");
    assert.equal(result.error.details?.file, "AGENTS.md");
  } finally {
    cleanup();
  }
});

test("cannot-parse: malformed Active Spec Directories bullet reports a line number", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-malformed-bullet");
  try {
    const agentsMd = [
      "# AGENTS.md",
      "",
      "## Active Spec Directories",
      "",
      "- `specs/good/`",
      "- not-a-valid-bullet",
      "",
      "## Required Workflow",
      "",
      "1. Step one.",
      "",
    ].join("\n");
    writeFile(root.path, "AGENTS.md", agentsMd);

    const result = parseActiveSpecDirectories(root);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.file, "AGENTS.md");
    assert.equal(result.error.details?.line, 6);
  } finally {
    cleanup();
  }
});

test("cannot-parse: Required Workflow section with no numbered steps", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-workflow-no-steps");
  try {
    const agentsMd = [
      "# AGENTS.md",
      "",
      "## Required Workflow",
      "",
      "Just some prose, no numbered list at all.",
      "",
      "## Sources Of Truth",
      "",
      "text",
      "",
    ].join("\n");
    writeFile(root.path, "AGENTS.md", agentsMd);

    const result = parseRequiredWorkflow(root);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.file, "AGENTS.md");
  } finally {
    cleanup();
  }
});

test("guardedRead failure (missing AGENTS.md) propagates unchanged as not-found", () => {
  const { root, cleanup } = makeTempSddRoot("agents-md-file-not-found");
  try {
    unlinkSync(join(root.path, "AGENTS.md"));

    const result = parseActiveSpecDirectories(root);
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "not-found");
  } finally {
    cleanup();
  }
});
