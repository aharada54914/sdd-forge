/**
 * MCP server construction for ci-mcp.
 *
 * Builds the `McpServer` and registers all 5 read-only GitHub Actions tools:
 * `list_workflow_runs`, `get_workflow_run`, `list_run_jobs`,
 * `list_run_artifacts`, and `get_job_log` (landed across T-005 / T-012 /
 * T-013 respectively). Each handler composes github-client (T-002), auth's
 * `withToken` gate (T-003), and repo-resolve's `resolveRepo` (T-004) via
 * `tools/actions.ts`.
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
  getJobLog,
  getWorkflowRun,
  listRunArtifacts,
  listRunJobs,
  listWorkflowRuns,
  GET_JOB_LOG_INPUT_SHAPE,
  GET_WORKFLOW_RUN_INPUT_SHAPE,
  LIST_RUN_ARTIFACTS_INPUT_SHAPE,
  LIST_RUN_JOBS_INPUT_SHAPE,
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

  server.registerTool(
    "list_run_jobs",
    {
      title: "List run jobs",
      description:
        "Lists the jobs for a GitHub Actions workflow run, including each " +
        "job's status/conclusion/timestamps and the number of its first " +
        "failed step (null if none failed). Read-only: issues a single GET " +
        "against the GitHub Actions REST API.",
      inputSchema: LIST_RUN_JOBS_INPUT_SHAPE,
    },
    async (args) => toCallToolResult(await listRunJobs(args)),
  );

  server.registerTool(
    "list_run_artifacts",
    {
      title: "List run artifacts",
      description:
        "Lists artifact metadata (id/name/size/expired/expiresAt/createdAt) " +
        "for a GitHub Actions workflow run. Never returns binary artifact " +
        "content; expired artifacts are reported as expired:true, not an " +
        "error. Read-only: issues a single GET against the GitHub Actions " +
        "REST API.",
      inputSchema: LIST_RUN_ARTIFACTS_INPUT_SHAPE,
    },
    async (args) => toCallToolResult(await listRunArtifacts(args)),
  );

  server.registerTool(
    "get_job_log",
    {
      title: "Get job log",
      description:
        "Fetches a GitHub Actions job's plain-text log by job id. Logs over " +
        "256 KiB (262144 bytes) are truncated to their TAIL (most recent " +
        "bytes, best for failure diagnosis); `truncated` and `returnedBytes` " +
        "report whether/how much was cut. Always returns ok:true regardless " +
        "of truncation. Read-only: issues a single GET against the GitHub " +
        "Actions REST API.",
      inputSchema: GET_JOB_LOG_INPUT_SHAPE,
    },
    async (args) => toCallToolResult(await getJobLog(args)),
  );

  return server;
}
