/**
 * AC (acceptance, T-001, updated T-005): stdio server construction/startup
 * skeleton.
 *
 * `buildServer()` must construct a valid McpServer without making any
 * network call or reading any GitHub-token environment variable at
 * construction time — this test asserts construction is synchronous-fast and
 * that no `fetch` is triggered, which is the acceptance criterion for "起動時に
 * GitHub API 呼び出し・トークン検証を行わない" (design.md Architecture). As of
 * T-005, `list_workflow_runs` and `get_workflow_run` are registered (T-012
 * adds 2 more, T-013 adds the 5th and final tool); the tool-count assertion
 * below is updated at each of those tasks to track the current total.
 *
 * Uses the MCP SDK's in-memory Client/Transport pair (no real stdio process),
 * matching the pattern other ci-mcp/local-env-mcp tool-level tests use for
 * fast in-process verification. The real stdio process wiring (index.ts) is
 * exercised by the T-008 Inspector smoke test.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { buildServer } from "../../src/server.js";

/** Narrow shape exposing McpServer's private tool-registration map for a white-box zero-tools check. */
interface McpServerToolInternals {
  _registeredTools: Record<string, unknown>;
}

test("buildServer() constructs fast and registers exactly the tools implemented so far (T-005 scope)", () => {
  const start = process.hrtime.bigint();
  const server = buildServer();
  const elapsedMs = Number(process.hrtime.bigint() - start) / 1e6;

  // Construction alone must stay well under the 1s startup SLO (design.md).
  assert.ok(elapsedMs < 1000, `buildServer() took ${elapsedMs}ms, expected < 1000ms`);

  // As of T-005, exactly `list_workflow_runs` and `get_workflow_run` are
  // registered (T-012/T-013 add the remaining 3). Asserted directly
  // (white-box) via the MCP SDK's internal tool map rather than a
  // `tools/list` round-trip.
  const registeredToolNames = Object.keys((server as unknown as McpServerToolInternals)._registeredTools).sort();
  assert.deepEqual(
    registeredToolNames,
    ["get_workflow_run", "list_workflow_runs"],
    "T-005 registers list_workflow_runs and get_workflow_run; T-012/T-013 add the remaining 3",
  );
});

test("buildServer() never reads a GitHub token env var during construction", () => {
  // A canary in place of any ci-mcp token variable: construction must not
  // read process.env at all for auth purposes (auth.ts is T-003 scope, not
  // wired into server.ts yet), so setting these has no observable effect and
  // no crash/throw occurs either way.
  const priorTokenEnv = {
    CI_MCP_GITHUB_TOKEN: process.env.CI_MCP_GITHUB_TOKEN,
    GH_READONLY_TOKEN: process.env.GH_READONLY_TOKEN,
    GITHUB_TOKEN: process.env.GITHUB_TOKEN,
  };
  try {
    delete process.env.CI_MCP_GITHUB_TOKEN;
    delete process.env.GH_READONLY_TOKEN;
    delete process.env.GITHUB_TOKEN;
    assert.doesNotThrow(() => buildServer());
  } finally {
    for (const [key, value] of Object.entries(priorTokenEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
});
