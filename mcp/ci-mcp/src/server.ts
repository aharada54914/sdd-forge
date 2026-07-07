/**
 * MCP server construction for ci-mcp.
 *
 * Builds the `McpServer` and registers the read-only GitHub Actions tools
 * (`list_workflow_runs` / `get_workflow_run` / `list_run_jobs` /
 * `get_job_log` / `list_run_artifacts`) as they land: T-005 registers
 * `list_workflow_runs` and `get_workflow_run`; T-012 adds `list_run_jobs` and
 * `list_run_artifacts`; T-013 adds `get_job_log` (the final tool). Each
 * handler composes github-client (T-002), auth's `withToken` gate (T-003),
 * and repo-resolve's `resolveRepo` (T-004) via `tools/actions.ts`.
 *
 * Every tool response is the common `Result<T>` envelope
 * (contracts/ci-mcp-tools.v1.schema.json), serialized as JSON text into
 * `content[0].text` — both `ok` and `error` envelopes are returned as an
 * ordinary (non-error) tool result, matching sdd-forge-mcp/local-env-mcp's
 * convention. Construction here performs no I/O, no environment-variable
 * read, and no network call — it only builds the `McpServer` instance and
 * registers tool metadata, keeping the <=1s startup SLO (design.md
 * "Architecture"); all env reads and GitHub calls happen only when a tool is
 * actually invoked.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import type { Result } from "./envelope.js";
import {
  getWorkflowRun,
  listWorkflowRuns,
  GET_WORKFLOW_RUN_INPUT_SHAPE,
  LIST_WORKFLOW_RUNS_INPUT_SHAPE,
} from "./tools/actions.js";

/** Wraps a `Result<T>` into the MCP `CallToolResult` shape: envelope JSON as `content[0].text`. */
function toCallToolResult<T>(result: Result<T>): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [{ type: "text", text: JSON.stringify(result) }],
  };
}

/** Builds the ci-mcp MCP server and registers the read-only Actions tools implemented so far. */
export function buildServer(): McpServer {
  const server = new McpServer({
    name: "ci-mcp",
    version: "0.1.0",
  });

  server.registerTool(
    "list_workflow_runs",
    {
      title: "List workflow runs",
      description:
        "Lists GitHub Actions workflow runs for a repository, optionally " +
        "filtered by branch/status/event and capped at perPage results. " +
        "Read-only: issues a single GET against the GitHub Actions REST API.",
      inputSchema: LIST_WORKFLOW_RUNS_INPUT_SHAPE,
    },
    async (args) => toCallToolResult(await listWorkflowRuns(args)),
  );

  server.registerTool(
    "get_workflow_run",
    {
      title: "Get workflow run",
      description:
        "Fetches a single GitHub Actions workflow run's detail (metadata, " +
        "workflow name, run start time, commit SHA) by run id. Read-only: " +
        "issues a single GET against the GitHub Actions REST API. A " +
        "non-existent run id returns a not-found error envelope.",
      inputSchema: GET_WORKFLOW_RUN_INPUT_SHAPE,
    },
    async (args) => toCallToolResult(await getWorkflowRun(args)),
  );

  return server;
}
