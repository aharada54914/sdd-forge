/**
 * AC-006 (TEST-006, behavioral half): for all 5 ci-mcp tools, passing an
 * unexpected write-inducing field (action/method/body/command) alongside
 * otherwise-valid input is rejected with `invalid-input` — and, crucially,
 * GitHub is never called (zero fetch / zero text-fetch invocations) — proving
 * a write-inducing field cannot smuggle a request through even if a caller
 * tries. zod's `.strict()` mode drives this (tools/actions.ts), so an unknown
 * field always fails validation before `githubGet`/`githubGetText` is ever
 * reached.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  getJobLog,
  getWorkflowRun,
  listRunArtifacts,
  listRunJobs,
  listWorkflowRuns,
  type ActionsToolOptions,
} from "../../src/tools/actions.js";
import type { Result } from "../../src/envelope.js";
import type { GithubFetch, GithubHttpResponse, GithubTextFetch, GithubTextHttpResponse } from "../../src/github-client.js";
import { WRITE_INDUCING_FIELD_NAMES } from "./support/write-inducing-fields.js";

const TOKEN_ENV = { CI_MCP_GITHUB_TOKEN: "test-token-123" };
const PROBE_FIELDS = ["action", "method", "body", "command"] as const;

function recordingFetch(): { fetchImpl: GithubFetch; callCount: () => number } {
  let calls = 0;
  const fetchImpl: GithubFetch = async () => {
    calls += 1;
    const response: GithubHttpResponse = { status: 200, headers: { get: () => null }, json: async () => ({}) };
    return response;
  };
  return { fetchImpl, callCount: () => calls };
}

function recordingTextFetch(): { textFetchImpl: GithubTextFetch; callCount: () => number } {
  let calls = 0;
  const textFetchImpl: GithubTextFetch = async () => {
    calls += 1;
    const response: GithubTextHttpResponse = { status: 200, headers: { get: () => null }, text: async () => "" };
    return response;
  };
  return { textFetchImpl, callCount: () => calls };
}

interface ToolCase {
  name: string;
  run: (
    extra: Record<string, unknown>,
    options: ActionsToolOptions,
  ) => Promise<Result<unknown>>;
}

const TOOL_CASES: ToolCase[] = [
  {
    name: "list_workflow_runs",
    run: (extra, options) => listWorkflowRuns({ owner: "acme", repo: "widgets", ...extra } as never, options),
  },
  {
    name: "get_workflow_run",
    run: (extra, options) =>
      getWorkflowRun({ owner: "acme", repo: "widgets", runId: 1, ...extra } as never, options),
  },
  {
    name: "list_run_jobs",
    run: (extra, options) => listRunJobs({ owner: "acme", repo: "widgets", runId: 1, ...extra } as never, options),
  },
  {
    name: "list_run_artifacts",
    run: (extra, options) =>
      listRunArtifacts({ owner: "acme", repo: "widgets", runId: 1, ...extra } as never, options),
  },
  {
    name: "get_job_log",
    run: (extra, options) => getJobLog({ owner: "acme", repo: "widgets", jobId: 1, ...extra } as never, options),
  },
];

test("AC-006: the probe field list is drawn from the shared write-inducing-field denylist", () => {
  for (const field of PROBE_FIELDS) {
    assert.ok(
      WRITE_INDUCING_FIELD_NAMES.has(field),
      `"${field}" must be present in the shared write-inducing-field denylist`,
    );
  }
});

for (const toolCase of TOOL_CASES) {
  for (const field of PROBE_FIELDS) {
    test(`AC-006: ${toolCase.name} rejects a "${field}" field with invalid-input and never calls GitHub`, async () => {
      const { fetchImpl, callCount: fetchCallCount } = recordingFetch();
      const { textFetchImpl, callCount: textCallCount } = recordingTextFetch();

      const result = await toolCase.run(
        { [field]: "irrelevant-value" },
        { env: TOKEN_ENV, fetchImpl, textFetchImpl },
      );

      assert.equal(result.ok, false, `expected ${toolCase.name} to reject the "${field}" field`);
      if (!result.ok) {
        assert.equal(result.error.code, "invalid-input");
      }
      assert.equal(fetchCallCount(), 0, `${toolCase.name} must never call githubGet when input is invalid`);
      assert.equal(textCallCount(), 0, `${toolCase.name} must never call githubGetText when input is invalid`);
    });
  }
}
