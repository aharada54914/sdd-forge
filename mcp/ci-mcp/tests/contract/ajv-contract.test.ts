/**
 * AC-013 (TEST-013): every ci-mcp tool response conforms to
 * contracts/ci-mcp-tools.v1.schema.json under strict ajv validation. Covers
 * both the `ok` and `error` branches for all 5 tools (including get_job_log's
 * `truncated: true` / `truncated: false` variants), the 3 ci-mcp-specific
 * error codes (`auth-missing` / `rate-limited` / `upstream-error`) plus a
 * sample of the 2 pre-existing codes ci-mcp actually emits
 * (`invalid-input` / `not-found`), and negative tests proving the schema
 * actually rejects malformed envelopes (extra fields, out-of-enum error
 * codes) rather than trivially accepting everything.
 *
 * Real tool functions (`tools/actions.ts`) are exercised end-to-end with an
 * injected fake fetch/text-fetch (no real network, per REQ-013 / design.md
 * Test Strategy) so the validated payloads are genuine tool output, not
 * hand-constructed fixtures that might drift from what the implementation
 * actually returns.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  getJobLog,
  getWorkflowRun,
  listRunArtifacts,
  listRunJobs,
  listWorkflowRuns,
} from "../../src/tools/actions.js";
import type { GithubFetch, GithubHttpResponse, GithubTextFetch, GithubTextHttpResponse } from "../../src/github-client.js";
import { getEnvelopeValidator } from "./test-helpers.js";

const TOKEN_ENV = { CI_MCP_GITHUB_TOKEN: "test-token-123" };

function fakeFetch(body: unknown, status = 200, headers: Record<string, string> = {}): GithubFetch {
  return async () => {
    const response: GithubHttpResponse = {
      status,
      headers: { get: (name: string) => headers[name.toLowerCase()] ?? null },
      json: async () => body,
    };
    return response;
  };
}

function fakeTextFetch(body: string, status = 200, headers: Record<string, string> = {}): GithubTextFetch {
  return async () => {
    const response: GithubTextHttpResponse = {
      status,
      headers: { get: (name: string) => headers[name.toLowerCase()] ?? null },
      text: async () => body,
    };
    return response;
  };
}

/** Asserts `data` validates against the v1 envelope schema; on failure includes ajv's error detail. */
function assertConforms(data: unknown): void {
  const validate = getEnvelopeValidator();
  const isValid = validate(data);
  assert.ok(isValid, `expected schema conformance, got ajv errors: ${JSON.stringify(validate.errors)}`);
}

const UPSTREAM_RUN = {
  id: 111,
  name: "CI",
  workflow_name: "CI",
  head_branch: "main",
  event: "push",
  run_number: 42,
  status: "completed",
  conclusion: "success",
  created_at: "2026-07-01T00:00:00Z",
  updated_at: "2026-07-01T00:05:00Z",
  html_url: "https://github.com/acme/widgets/actions/runs/111",
  head_sha: "abc123",
  run_started_at: "2026-07-01T00:00:00Z",
};

// ---------------------------------------------------------------------------
// ok-branch conformance, one per tool (AC-013)
// ---------------------------------------------------------------------------

test("AC-013: list_workflow_runs ok envelope conforms to the v1 contract", async () => {
  const result = await listWorkflowRuns(
    { owner: "acme", repo: "widgets" },
    { env: TOKEN_ENV, fetchImpl: fakeFetch({ workflow_runs: [UPSTREAM_RUN] }) },
  );
  assert.equal(result.ok, true);
  assertConforms(result);
});

test("AC-013: get_workflow_run ok envelope conforms to the v1 contract", async () => {
  const result = await getWorkflowRun(
    { owner: "acme", repo: "widgets", runId: 111 },
    { env: TOKEN_ENV, fetchImpl: fakeFetch(UPSTREAM_RUN) },
  );
  assert.equal(result.ok, true);
  assertConforms(result);
});

test("AC-013: list_run_jobs ok envelope conforms to the v1 contract", async () => {
  const result = await listRunJobs(
    { owner: "acme", repo: "widgets", runId: 111 },
    {
      env: TOKEN_ENV,
      fetchImpl: fakeFetch({
        jobs: [
          {
            id: 1,
            name: "build",
            status: "completed",
            conclusion: "failure",
            started_at: "2026-07-01T00:00:00Z",
            completed_at: "2026-07-01T00:01:00Z",
            steps: [{ number: 1, conclusion: "failure" }],
          },
        ],
      }),
    },
  );
  assert.equal(result.ok, true);
  assertConforms(result);
});

test("AC-013: list_run_artifacts ok envelope conforms to the v1 contract (including an expired artifact)", async () => {
  const result = await listRunArtifacts(
    { owner: "acme", repo: "widgets", runId: 111 },
    {
      env: TOKEN_ENV,
      fetchImpl: fakeFetch({
        artifacts: [
          {
            id: 1,
            name: "build-output",
            size_in_bytes: 2048,
            expired: true,
            expires_at: "2026-06-01T00:00:00Z",
            created_at: "2026-05-01T00:00:00Z",
          },
        ],
      }),
    },
  );
  assert.equal(result.ok, true);
  assertConforms(result);
});

test("AC-013: get_job_log ok envelope (truncated:false) conforms to the v1 contract", async () => {
  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 1 },
    { env: TOKEN_ENV, textFetchImpl: fakeTextFetch("a short log\n") },
  );
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.data.truncated, false);
  }
  assertConforms(result);
});

test("AC-013: get_job_log ok envelope (truncated:true) conforms to the v1 contract", async () => {
  const hugeLog = "x".repeat(300_000);
  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 1 },
    { env: TOKEN_ENV, textFetchImpl: fakeTextFetch(hugeLog) },
  );
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.data.truncated, true);
    assert.ok(result.data.returnedBytes <= 262144);
  }
  assertConforms(result);
});

// ---------------------------------------------------------------------------
// error-branch conformance, spread across the 5 error codes ci-mcp emits
// (AC-013: "ok / error 両分岐、追加した error code enum を含む")
// ---------------------------------------------------------------------------

test("AC-013: invalid-input error envelope (list_workflow_runs, extra field) conforms to the v1 contract", async () => {
  const result = await listWorkflowRuns(
    { owner: "acme", repo: "widgets", action: "rerun" } as never,
    { env: TOKEN_ENV, fetchImpl: fakeFetch({}) },
  );
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "invalid-input");
  }
  assertConforms(result);
});

test("AC-013: not-found error envelope (get_workflow_run, 404) conforms to the v1 contract", async () => {
  const result = await getWorkflowRun(
    { owner: "acme", repo: "widgets", runId: 999 },
    { env: TOKEN_ENV, fetchImpl: fakeFetch({}, 404) },
  );
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "not-found");
  }
  assertConforms(result);
});

test("AC-013: auth-missing error envelope (list_run_jobs, no token) conforms to the v1 contract", async () => {
  const result = await listRunJobs(
    { owner: "acme", repo: "widgets", runId: 111 },
    { env: {}, fetchImpl: fakeFetch({}) },
  );
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "auth-missing");
  }
  assertConforms(result);
});

test("AC-013: rate-limited error envelope (list_run_artifacts, 429) conforms to the v1 contract", async () => {
  const result = await listRunArtifacts(
    { owner: "acme", repo: "widgets", runId: 111 },
    { env: TOKEN_ENV, fetchImpl: fakeFetch({}, 429, { "x-ratelimit-reset": "2000000000" }) },
  );
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "rate-limited");
  }
  assertConforms(result);
});

test("AC-013: upstream-error error envelope (get_job_log, 500) conforms to the v1 contract", async () => {
  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 1 },
    { env: TOKEN_ENV, textFetchImpl: fakeTextFetch("", 500) },
  );
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "upstream-error");
  }
  assertConforms(result);
});

// ---------------------------------------------------------------------------
// Negative tests: the schema must actually REJECT malformed envelopes
// ---------------------------------------------------------------------------

test("AC-013 negative: an ok envelope with an extra top-level property is rejected", () => {
  const validate = getEnvelopeValidator();
  const malformed = {
    ok: true,
    data: { kind: "workflow-runs", runs: [] },
    unexpectedExtra: "should not be allowed",
  };
  assert.equal(validate(malformed), false);
});

test("AC-013 negative: an ok envelope whose data has an extra field is rejected", () => {
  const validate = getEnvelopeValidator();
  const malformed = {
    ok: true,
    data: { kind: "workflow-runs", runs: [], extraneous: true },
  };
  assert.equal(validate(malformed), false);
});

test("AC-013 negative: an out-of-enum error code is rejected", () => {
  const validate = getEnvelopeValidator();
  const malformed = { ok: false, error: { code: "not-a-real-code", message: "boom" } };
  assert.equal(validate(malformed), false);
});

test("AC-013 negative: an error envelope with an extra top-level error field is rejected", () => {
  const validate = getEnvelopeValidator();
  const malformed = {
    ok: false,
    error: { code: "not-found", message: "boom" },
    unexpectedExtra: "should not be allowed",
  };
  assert.equal(validate(malformed), false);
});

test("AC-013 negative: an error object with an extra top-level property is rejected", () => {
  const validate = getEnvelopeValidator();
  const malformed = { ok: false, error: { code: "not-found", message: "boom", unexpectedExtra: "nope" } };
  assert.equal(validate(malformed), false);
});
