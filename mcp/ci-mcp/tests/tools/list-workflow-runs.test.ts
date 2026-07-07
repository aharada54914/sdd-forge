/**
 * AC-001: `list_workflow_runs` returns the contract's `workflow-runs`
 * envelope (id/name/status/conclusion/branch/event/createdAt/updatedAt/
 * runNumber/htmlUrl) and accepts branch/status/event/perPage filters, which
 * are forwarded as GitHub REST query params. Uses an injected fake
 * `GithubFetch` (no real network, per REQ-013 / design.md Test Strategy).
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { listWorkflowRuns } from "../../src/tools/actions.js";
import { isOk } from "../../src/envelope.js";
import type { GithubFetch, GithubHttpResponse } from "../../src/github-client.js";

const TOKEN_ENV = { CI_MCP_GITHUB_TOKEN: "test-token-123" };

interface RecordedCall {
  url: string;
}

function fakeFetch(body: unknown, status = 200): { fetchImpl: GithubFetch; calls: RecordedCall[] } {
  const calls: RecordedCall[] = [];
  const fetchImpl: GithubFetch = async (url) => {
    calls.push({ url });
    const response: GithubHttpResponse = {
      status,
      headers: { get: () => null },
      json: async () => body,
    };
    return response;
  };
  return { fetchImpl, calls };
}

test("AC-001: returns a workflow-runs envelope mapped from the upstream GitHub shape", async () => {
  const upstreamBody = {
    workflow_runs: [
      {
        id: 111,
        name: "CI",
        head_branch: "main",
        event: "push",
        run_number: 42,
        status: "completed",
        conclusion: "success",
        created_at: "2026-07-01T00:00:00Z",
        updated_at: "2026-07-01T00:05:00Z",
        html_url: "https://github.com/acme/widgets/actions/runs/111",
      },
    ],
  };
  const { fetchImpl } = fakeFetch(upstreamBody);

  const result = await listWorkflowRuns(
    { owner: "acme", repo: "widgets" },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.kind, "workflow-runs");
    assert.deepEqual(result.data.runs, [
      {
        id: 111,
        name: "CI",
        status: "completed",
        conclusion: "success",
        branch: "main",
        event: "push",
        runNumber: 42,
        createdAt: "2026-07-01T00:00:00Z",
        updatedAt: "2026-07-01T00:05:00Z",
        htmlUrl: "https://github.com/acme/widgets/actions/runs/111",
      },
    ]);
  }
});

test("AC-001: branch/status/event/perPage filters are forwarded as GitHub query params", async () => {
  const { fetchImpl, calls } = fakeFetch({ workflow_runs: [] });

  await listWorkflowRuns(
    {
      owner: "acme",
      repo: "widgets",
      branch: "main",
      status: "completed",
      event: "push",
      perPage: 10,
    },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.equal(calls.length, 1);
  const url = new URL(calls[0]!.url);
  assert.equal(url.searchParams.get("branch"), "main");
  assert.equal(url.searchParams.get("status"), "completed");
  assert.equal(url.searchParams.get("event"), "push");
  assert.equal(url.searchParams.get("per_page"), "10");
  assert.ok(url.pathname.endsWith("/repos/acme/widgets/actions/runs"), `pathname was ${url.pathname}`);
});

test("Codex P2 (PR #98): a conclusion-value status filter (e.g. \"failure\") is accepted and forwarded, not rejected as invalid input", async () => {
  const { fetchImpl, calls } = fakeFetch({ workflow_runs: [] });

  const result = await listWorkflowRuns(
    { owner: "acme", repo: "widgets", status: "failure" },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.ok(isOk(result), "a conclusion value like \"failure\" must be a valid status filter, not invalid-input");
  assert.equal(calls.length, 1);
  const url = new URL(calls[0]!.url);
  assert.equal(url.searchParams.get("status"), "failure");
});

test("AC-008: missing token short-circuits to auth-missing without calling GitHub", async () => {
  const { fetchImpl, calls } = fakeFetch({ workflow_runs: [] });

  const result = await listWorkflowRuns({ owner: "acme", repo: "widgets" }, { env: {}, fetchImpl });

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "auth-missing");
  }
  assert.equal(calls.length, 0, "GitHub must never be called when the token is missing");
});

test("invalid input (extra field) is rejected with invalid-input before any GitHub call", async () => {
  const { fetchImpl, calls } = fakeFetch({ workflow_runs: [] });

  const result = await listWorkflowRuns(
    { owner: "acme", repo: "widgets", method: "POST" } as never,
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "invalid-input");
  }
  assert.equal(calls.length, 0);
});
