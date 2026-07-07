/**
 * MCP server construction for ci-mcp (T-001 scope: skeleton only).
 *
 * Builds the `McpServer` with NO tools registered yet. The 5 read-only
 * GitHub Actions tools (`list_workflow_runs` / `get_workflow_run` /
 * `list_run_jobs` / `get_job_log` / `list_run_artifacts`) are registered in
 * later tasks (T-005 / T-012 / T-013), once github-client (T-002), auth
 * (T-003), and repo-resolve (T-004) exist. Construction here performs no I/O,
 * no environment-variable read, and no network call — it only builds the
 * `McpServer` instance, keeping the <=1s startup SLO (design.md
 * "Architecture").
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

/** Builds the ci-mcp MCP server. T-001: no tools registered yet. */
export function buildServer(): McpServer {
  return new McpServer({
    name: "ci-mcp",
    version: "0.1.0",
  });
}
