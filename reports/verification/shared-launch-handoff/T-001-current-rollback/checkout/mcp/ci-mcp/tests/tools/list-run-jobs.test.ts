/**
 * AC-003: `list_run_jobs` returns the contract's `run-jobs` envelope (job
 * id/name/status/conclusion/startedAt/completedAt/failedStep), deriving
 * `failedStep` as the first step whose conclusion is "failure" (or null when
 * none failed). Uses an injected fake `GithubFetch` (no real network).
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { listRunJobs } from "../../src/tools/actions.js";
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

test("AC-003: returns a run-jobs envelope, deriving failedStep from the first failed step", async () => {
  const upstreamBody = {
    jobs: [
      {
        id: 1,
        name: "build",
        status: "completed",
        conclusion: "failure",
        started_at: "2026-07-01T00:00:00Z",
        completed_at: "2026-07-01T00:01:00Z",
        steps: [
          { number: 1, conclusion: "success" },
          { number: 2, conclusion: "failure" },
          { number: 3, conclusion: "cancelled" },
        ],
      },
      {
        id: 2,
        name: "test",
        status: "completed",
        conclusion: "success",
        started_at: "2026-07-01T00:00:00Z",
        completed_at: "2026-07-01T00:02:00Z",
        steps: [{ number: 1, conclusion: "success" }],
      },
    ],
  };
  const { fetchImpl, calls } = fakeFetch(upstreamBody);

  const result = await listRunJobs({ owner: "acme", repo: "widgets", runId: 111 }, { env: TOKEN_ENV, fetchImpl });

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.kind, "run-jobs");
    assert.deepEqual(result.data.jobs, [
      {
        id: 1,
        name: "build",
        status: "completed",
        conclusion: "failure",
        startedAt: "2026-07-01T00:00:00Z",
        completedAt: "2026-07-01T00:01:00Z",
        failedStep: 2,
      },
      {
        id: 2,
        name: "test",
        status: "completed",
        conclusion: "success",
        startedAt: "2026-07-01T00:00:00Z",
        completedAt: "2026-07-01T00:02:00Z",
        failedStep: null,
      },
    ]);
  }
  assert.ok(calls[0]?.endsWith("/repos/acme/widgets/actions/runs/111/jobs"), `url was ${calls[0]}`);
});

test("AC-003: a job with no steps at all yields failedStep: null", async () => {
  const { fetchImpl } = fakeFetch({
    jobs: [
      {
        id: 5,
        name: "lint",
        status: "in_progress",
        conclusion: null,
        started_at: "2026-07-01T00:00:00Z",
        completed_at: null,
        steps: [],
      },
    ],
  });

  const result = await listRunJobs({ owner: "acme", repo: "widgets", runId: 111 }, { env: TOKEN_ENV, fetchImpl });

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.jobs[0]?.failedStep, null);
  }
});

test("runId is required: missing runId is rejected with invalid-input", async () => {
  const { fetchImpl, calls } = fakeFetch({ jobs: [] });

  const result = await listRunJobs({ owner: "acme", repo: "widgets" } as never, { env: TOKEN_ENV, fetchImpl });

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "invalid-input");
  }
  assert.equal(calls.length, 0);
});

test("AC-008: missing token short-circuits to auth-missing without calling GitHub", async () => {
  const { fetchImpl, calls } = fakeFetch({ jobs: [] });

  const result = await listRunJobs({ owner: "acme", repo: "widgets", runId: 111 }, { env: {}, fetchImpl });

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "auth-missing");
  }
  assert.equal(calls.length, 0);
});
