/**
 * AC-006 (TEST-006, static half): none of ci-mcp's 5 tool input schemas
 * declares a write-inducing field (action/method/body/command and close
 * synonyms — REQ-003), and every field the schemas DO declare is one of the
 * allowed read-scoped names (owner/repo + read filters, design.md "API /
 * Contract Plan"). This inspects the actual exported zod input SHAPE
 * objects (not just behavior), so an added write-inducing field is caught
 * even if it happened not to change any currently-tested behavior.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  GET_JOB_LOG_INPUT_SHAPE,
  GET_WORKFLOW_RUN_INPUT_SHAPE,
  LIST_RUN_ARTIFACTS_INPUT_SHAPE,
  LIST_RUN_JOBS_INPUT_SHAPE,
  LIST_WORKFLOW_RUNS_INPUT_SHAPE,
} from "../../src/tools/actions.js";
import { WRITE_INDUCING_FIELD_NAMES } from "./support/write-inducing-fields.js";

const TOOL_INPUT_SHAPES: Record<string, Record<string, unknown>> = {
  list_workflow_runs: LIST_WORKFLOW_RUNS_INPUT_SHAPE,
  get_workflow_run: GET_WORKFLOW_RUN_INPUT_SHAPE,
  list_run_jobs: LIST_RUN_JOBS_INPUT_SHAPE,
  list_run_artifacts: LIST_RUN_ARTIFACTS_INPUT_SHAPE,
  get_job_log: GET_JOB_LOG_INPUT_SHAPE,
};

/** Read-scoped field names the 5 tool schemas are allowed to declare (design.md "API / Contract Plan"). */
const ALLOWED_READ_SCOPED_FIELD_NAMES = new Set([
  "owner",
  "repo",
  "branch",
  "status",
  "event",
  "perPage",
  "runId",
  "jobId",
]);

test("AC-006: no tool input schema declares a write-inducing field", () => {
  const violations: string[] = [];
  for (const [toolName, shape] of Object.entries(TOOL_INPUT_SHAPES)) {
    for (const fieldName of Object.keys(shape)) {
      if (WRITE_INDUCING_FIELD_NAMES.has(fieldName.toLowerCase())) {
        violations.push(`${toolName}.${fieldName}`);
      }
    }
  }
  assert.deepEqual(violations, [], `write-inducing field(s) found: ${violations.join(", ")}`);
});

test("AC-006: every declared input field is a read-scoped allowlisted name", () => {
  const violations: string[] = [];
  for (const [toolName, shape] of Object.entries(TOOL_INPUT_SHAPES)) {
    for (const fieldName of Object.keys(shape)) {
      if (!ALLOWED_READ_SCOPED_FIELD_NAMES.has(fieldName)) {
        violations.push(`${toolName}.${fieldName}`);
      }
    }
  }
  assert.deepEqual(violations, [], `non-allowlisted field(s) found: ${violations.join(", ")}`);
});

test("AC-006: all 5 tools are present and each schema has at least one field", () => {
  assert.equal(Object.keys(TOOL_INPUT_SHAPES).length, 5);
  for (const [toolName, shape] of Object.entries(TOOL_INPUT_SHAPES)) {
    assert.ok(Object.keys(shape).length > 0, `${toolName}'s input shape must declare at least one field`);
  }
});
