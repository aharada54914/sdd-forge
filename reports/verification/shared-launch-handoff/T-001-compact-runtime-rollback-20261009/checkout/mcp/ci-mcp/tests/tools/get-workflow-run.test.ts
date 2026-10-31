/**
 * AC-002: `get_workflow_run` returns a single run's contract-shaped detail
 * (metadata + workflow name + run start time + commit SHA) for a real run
 * id, and a non-existent run id yields `not-found` (GitHub 404 is already
 * mapped by error-normalizer.ts, exercised here end-to-end through the tool).
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { getWorkflowRun } from "../../src/tools/actions.js";
import { isOk } from "../../src/envelope.js";
import type { GithubFetch, GithubHttpResponse } from "../../src/github-client.js";

const TOKEN_ENV = { CI_MCP_GITHUB_TOKEN: "test-token-123" };

function fakeFetch(body: unknown, status = 200): { fetchImpl: GithubFetch; calls: string[] } {
  const calls: string[] = [];
  const fetchImpl: GithubFetch = async (url) => {
    calls.push(url);
    const response: GithubHttpResponse = {
      status,
      headers: { get: () => null },
      json: async () => body,
    };
    return response;
  };
  return { fetchImpl, calls };
}

test("AC-002: returns a workflow-run envelope with workflowName/headSha/runStartedAt mapped", async () => {
  const upstreamBody = {
    id: 999,
    name: "CI",
    workflow_name: "Build and Test",
    head_branch: "main",
    event: "push",
    run_number: 7,
    status: "completed",
    conclusion: "failure",
    created_at: "2026-07-01T00:00:00Z",
    updated_at: "2026-07-01T00:05:00Z",
    html_url: "https://github.com/acme/widgets/actions/runs/999",
    head_sha: "abc123def456",
    run_started_at: "2026-07-01T00:00:10Z",
  };
  const { fetchImpl, calls } = fakeFetch(upstreamBody);

  const result = await getWorkflowRun(
    { owner: "acme", repo: "widgets", runId: 999 },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.kind, "workflow-run");
    assert.deepEqual(result.data.run, {
      id: 999,
      name: "CI",
      workflowName: "Build and Test",
      status: "completed",
      conclusion: "failure",
      branch: "main",
      event: "push",
      runNumber: 7,
      headSha: "abc123def456",
      createdAt: "2026-07-01T00:00:00Z",
      updatedAt: "2026-07-01T00:05:00Z",
      runStartedAt: "2026-07-01T00:00:10Z",
      htmlUrl: "https://github.com/acme/widgets/actions/runs/999",
    });
  }
  assert.ok(calls[0]?.endsWith("/repos/acme/widgets/actions/runs/999"), `url was ${calls[0]}`);
});

test("AC-002: a non-existent run id yields not-found", async () => {
  const { fetchImpl } = fakeFetch({ message: "Not Found" }, 404);

  const result = await getWorkflowRun(
    { owner: "acme", repo: "widgets", runId: 404404 },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "not-found");
  }
});

test("runId is required: missing runId is rejected with invalid-input", async () => {
  const { fetchImpl, calls } = fakeFetch({});

  const result = await getWorkflowRun(
    { owner: "acme", repo: "widgets" } as never,
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "invalid-input");
  }
  assert.equal(calls.length, 0);
});
