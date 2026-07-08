/**
 * AC-005: `list_run_artifacts` returns the contract's `run-artifacts`
 * envelope (id/name/sizeBytes/expired/expiresAt/createdAt), never binary
 * content. An `expired: true` artifact is data, not an error.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { listRunArtifacts } from "../../src/tools/actions.js";
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

test("AC-005: returns a run-artifacts envelope mapped from the upstream GitHub shape", async () => {
  const upstreamBody = {
    artifacts: [
      {
        id: 10,
        name: "build-output",
        size_in_bytes: 2048,
        expired: false,
        expires_at: "2026-08-01T00:00:00Z",
        created_at: "2026-07-01T00:00:00Z",
      },
    ],
  };
  const { fetchImpl, calls } = fakeFetch(upstreamBody);

  const result = await listRunArtifacts(
    { owner: "acme", repo: "widgets", runId: 111 },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.kind, "run-artifacts");
    assert.deepEqual(result.data.artifacts, [
      {
        id: 10,
        name: "build-output",
        sizeBytes: 2048,
        expired: false,
        expiresAt: "2026-08-01T00:00:00Z",
        createdAt: "2026-07-01T00:00:00Z",
      },
    ]);
  }
  assert.ok(calls[0]?.endsWith("/repos/acme/widgets/actions/runs/111/artifacts"), `url was ${calls[0]}`);
});

test("AC-005: an expired artifact is returned as data with expired:true, not an error", async () => {
  const { fetchImpl } = fakeFetch({
    artifacts: [
      {
        id: 11,
        name: "old-logs",
        size_in_bytes: 512,
        expired: true,
        expires_at: "2026-01-01T00:00:00Z",
        created_at: "2025-12-01T00:00:00Z",
      },
    ],
  });

  const result = await listRunArtifacts(
    { owner: "acme", repo: "widgets", runId: 111 },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.artifacts[0]?.expired, true);
  }
});

test("AC-005: no binary content field is ever present in the response", async () => {
  const { fetchImpl } = fakeFetch({
    artifacts: [
      {
        id: 12,
        name: "artifact-with-content",
        size_in_bytes: 100,
        expired: false,
        expires_at: null,
        created_at: null,
      },
    ],
  });

  const result = await listRunArtifacts(
    { owner: "acme", repo: "widgets", runId: 111 },
    { env: TOKEN_ENV, fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    const artifact = result.data.artifacts[0] as unknown as Record<string, unknown>;
    assert.equal("content" in artifact, false);
    assert.equal("data" in artifact, false);
    assert.equal("archive_download_url" in artifact, false);
  }
});

test("runId is required: missing runId is rejected with invalid-input", async () => {
  const { fetchImpl, calls } = fakeFetch({ artifacts: [] });

  const result = await listRunArtifacts({ owner: "acme", repo: "widgets" } as never, {
    env: TOKEN_ENV,
    fetchImpl,
  });

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "invalid-input");
  }
  assert.equal(calls.length, 0);
});
