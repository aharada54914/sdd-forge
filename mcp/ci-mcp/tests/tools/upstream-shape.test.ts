import { test } from "node:test";
import assert from "node:assert/strict";
import { getWorkflowRun, listWorkflowRuns, listRunJobs, listRunArtifacts } from "../../src/tools/actions.js";
import type { GithubFetch } from "../../src/github-client.js";

for (const body of [null, [], { message: "private-upstream-marker" }, { workflow_runs: [null], jobs: [null], artifacts: [null] }]) {
  test(`malformed upstream JSON is a sanitized error: ${JSON.stringify(body)}`, async () => {
    const fetchImpl: GithubFetch = async () => ({ status: 200, headers: { get: () => null }, json: async () => body });
    const options = { env: { CI_MCP_GITHUB_TOKEN: "test-token" }, fetchImpl };
    const input = { owner: "acme", repo: "widgets", runId: 1 };
    for (const call of [getWorkflowRun, listRunJobs, listRunArtifacts]) {
      const result = await call(input, options);
      assert.equal(result.ok, false);
      if (!result.ok) assert.equal(result.error.code, "upstream-error");
      assert.ok(!JSON.stringify(result).includes("private-upstream-marker"));
    }
    const result = await listWorkflowRuns({ owner: "acme", repo: "widgets" }, options);
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.error.code, "upstream-error");
  });
}
