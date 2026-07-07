/**
 * ci-mcp's 5 read-only GitHub Actions tools (design.md "API / Contract
 * Plan", contracts/ci-mcp-tools.v1.schema.json). Implemented incrementally:
 *   - T-005: list_workflow_runs, get_workflow_run
 *   - T-012: list_run_jobs, list_run_artifacts
 *   - T-013: get_job_log
 *
 * Every tool follows the same composition: `withToken` (auth.ts) gates the
 * call so a missing token never reaches GitHub; `resolveRepo`
 * (repo-resolve.ts) resolves owner/repo from explicit args or CI_MCP_REPO;
 * `githubGet` (github-client.ts) issues the GET-only, host-fixed request and
 * normalizes upstream errors. Handlers then map GitHub's raw snake_case JSON
 * field names onto the contract's camelCase field names before wrapping the
 * result in `ok(...)`. Zod input schemas are `.strict()` and intentionally
 * carry only read-scoped filters (owner/repo/branch/status/event/perPage/
 * runId/jobId) — no action/method/body-type field ever exists on any of
 * these schemas (write-boundary discipline enforced upstream by T-002's
 * GET-only github-client).
 *
 * Upstream JSON shape note: GitHub's real REST API does not literally emit a
 * `workflow_name` field on a workflow-run object (the parent workflow's
 * display name normally requires a second call to the workflow endpoint).
 * Since this module owns both the fake-fetch fixtures used in tests and the
 * mapping code, it treats the upstream run object as carrying an OPTIONAL
 * `workflow_name` string (mapped to the contract's optional `workflowName`)
 * for internal consistency between `list_workflow_runs` and
 * `get_workflow_run` — this is a deliberate, documented shape choice, not a
 * literal transcription of GitHub's API docs.
 */

import { z } from "zod";

import { err, ok, isOk, type Result } from "../envelope.js";
import { withToken } from "../auth.js";
import { resolveRepo, type RepoResolveArgs, type ResolvedRepo } from "../repo-resolve.js";
import { githubGet, type GithubFetch } from "../github-client.js";

/** Shared options every tool function accepts for test injection (fetch) and env override. */
export interface ActionsToolOptions {
  env?: NodeJS.ProcessEnv;
  fetchImpl?: GithubFetch;
}

// ---------------------------------------------------------------------------
// Contract-shaped output types (contracts/ci-mcp-tools.v1.schema.json)
// ---------------------------------------------------------------------------

/** `$defs/runStatus`. */
export type RunStatus = "queued" | "in_progress" | "completed" | "waiting" | "requested" | "pending";

/** `$defs/runConclusion`. */
export type RunConclusion =
  | "success"
  | "failure"
  | "cancelled"
  | "skipped"
  | "timed_out"
  | "action_required"
  | "neutral"
  | "stale"
  | "startup_failure"
  | null;

/** `$defs/workflowRun`. */
export interface WorkflowRun {
  id: number;
  name: string;
  workflowName?: string;
  status: RunStatus;
  conclusion: RunConclusion;
  branch: string | null;
  event: string;
  runNumber: number;
  headSha?: string;
  createdAt: string;
  updatedAt: string;
  runStartedAt?: string | null;
  htmlUrl: string;
}

/** `$defs/workflowRunsData` (`list_workflow_runs` output). */
export interface WorkflowRunsData {
  kind: "workflow-runs";
  runs: WorkflowRun[];
}

/** `$defs/workflowRunData` (`get_workflow_run` output). */
export interface WorkflowRunData {
  kind: "workflow-run";
  run: WorkflowRun;
}

// ---------------------------------------------------------------------------
// Upstream (GitHub REST API) raw shapes — see module doc comment for the
// `workflow_name` shape decision.
// ---------------------------------------------------------------------------

interface UpstreamWorkflowRun {
  id: number;
  name: string;
  workflow_name?: string;
  head_branch: string | null;
  event: string;
  run_number: number;
  status: string;
  conclusion: string | null;
  created_at: string;
  updated_at: string;
  html_url: string;
  head_sha?: string;
  run_started_at?: string | null;
}

interface UpstreamWorkflowRunsResponse {
  workflow_runs: UpstreamWorkflowRun[];
}

/** Maps a raw upstream run object onto the contract's `WorkflowRun` shape. */
function mapUpstreamRun(raw: UpstreamWorkflowRun): WorkflowRun {
  const run: WorkflowRun = {
    id: raw.id,
    name: raw.name,
    status: raw.status as RunStatus,
    conclusion: raw.conclusion as RunConclusion,
    branch: raw.head_branch,
    event: raw.event,
    runNumber: raw.run_number,
    createdAt: raw.created_at,
    updatedAt: raw.updated_at,
    htmlUrl: raw.html_url,
  };
  if (raw.workflow_name !== undefined) {
    run.workflowName = raw.workflow_name;
  }
  if (raw.head_sha !== undefined) {
    run.headSha = raw.head_sha;
  }
  if (raw.run_started_at !== undefined) {
    run.runStartedAt = raw.run_started_at;
  }
  return run;
}

/**
 * Runs `withToken` (auth gate) then `resolveRepo` (repo resolution) before
 * invoking `handler`. This is the shared composition spine every tool in
 * this file routes through, so a missing token or an unresolved repo never
 * reaches `githubGet`.
 */
function withRepoAndToken<T>(
  args: RepoResolveArgs,
  options: ActionsToolOptions,
  handler: (token: string, repo: ResolvedRepo) => Promise<Result<T>>,
): Promise<Result<T>> {
  return withToken(async (token) => {
    const repoResult = resolveRepo(args, options.env);
    if (!isOk(repoResult)) {
      return repoResult;
    }
    return handler(token, repoResult.data);
  }, options.env);
}

// ---------------------------------------------------------------------------
// list_workflow_runs
// ---------------------------------------------------------------------------

const RUN_STATUS_VALUES = [
  "queued",
  "in_progress",
  "completed",
  "waiting",
  "requested",
  "pending",
] as const;

/** Raw shape registered with the MCP SDK's `registerTool` for `list_workflow_runs`. */
export const LIST_WORKFLOW_RUNS_INPUT_SHAPE = {
  owner: z.string().optional().describe("Repository owner. Must be given together with `repo`."),
  repo: z.string().optional().describe("Repository name. Must be given together with `owner`."),
  branch: z.string().optional().describe("Filter runs by branch name."),
  status: z.enum(RUN_STATUS_VALUES).optional().describe("Filter runs by status."),
  event: z.string().optional().describe("Filter runs by triggering event (e.g. push, pull_request)."),
  perPage: z.number().int().min(1).max(100).optional().describe("Max number of runs to return (1-100)."),
};

const listWorkflowRunsInputSchema = z.object(LIST_WORKFLOW_RUNS_INPUT_SHAPE).strict();

export type ListWorkflowRunsInput = z.infer<typeof listWorkflowRunsInputSchema>;

/**
 * AC-001: lists workflow runs for a repository, returning the contract's
 * `workflow-runs` envelope. Accepts optional branch/status/event/perPage
 * filters, forwarded as GitHub REST query params.
 */
export async function listWorkflowRuns(
  input: ListWorkflowRunsInput,
  options: ActionsToolOptions = {},
): Promise<Result<WorkflowRunsData>> {
  const parsed = listWorkflowRunsInputSchema.safeParse(input);
  if (!parsed.success) {
    return err("invalid-input", "list_workflow_runs: invalid input", {
      rule: "owner/repo/branch/status/event must be strings, status must be a valid run status, perPage must be 1-100; no other fields are accepted",
    });
  }
  const { owner, repo, branch, status, event, perPage } = parsed.data;

  return withRepoAndToken({ owner, repo }, options, async (token, resolvedRepo) => {
    const outcome = await githubGet<UpstreamWorkflowRunsResponse>(
      {
        pathSegments: ["repos", resolvedRepo.owner, resolvedRepo.repo, "actions", "runs"],
        searchParams: { branch, status, event, per_page: perPage },
        token,
      },
      options.fetchImpl,
    );
    if (!outcome.ok) {
      return outcome;
    }
    return ok<WorkflowRunsData>({
      kind: "workflow-runs",
      runs: outcome.data.workflow_runs.map(mapUpstreamRun),
    });
  });
}

// ---------------------------------------------------------------------------
// get_workflow_run
// ---------------------------------------------------------------------------

/** Raw shape registered with the MCP SDK's `registerTool` for `get_workflow_run`. */
export const GET_WORKFLOW_RUN_INPUT_SHAPE = {
  owner: z.string().optional().describe("Repository owner. Must be given together with `repo`."),
  repo: z.string().optional().describe("Repository name. Must be given together with `owner`."),
  runId: z.number().int().min(1).describe("The workflow run id to fetch."),
};

const getWorkflowRunInputSchema = z.object(GET_WORKFLOW_RUN_INPUT_SHAPE).strict();

export type GetWorkflowRunInput = z.infer<typeof getWorkflowRunInputSchema>;

/**
 * AC-002: fetches a single workflow run's detail (metadata + workflow name +
 * run start time + commit SHA), returning the contract's `workflow-run`
 * envelope. A non-existent run id yields `not-found` (GitHub 404, already
 * mapped by error-normalizer.ts).
 */
export async function getWorkflowRun(
  input: GetWorkflowRunInput,
  options: ActionsToolOptions = {},
): Promise<Result<WorkflowRunData>> {
  const parsed = getWorkflowRunInputSchema.safeParse(input);
  if (!parsed.success) {
    return err("invalid-input", "get_workflow_run: invalid input", {
      rule: "runId is required and must be a positive integer; owner/repo are optional strings",
    });
  }
  const { owner, repo, runId } = parsed.data;

  return withRepoAndToken({ owner, repo }, options, async (token, resolvedRepo) => {
    const outcome = await githubGet<UpstreamWorkflowRun>(
      {
        pathSegments: ["repos", resolvedRepo.owner, resolvedRepo.repo, "actions", "runs", String(runId)],
        token,
      },
      options.fetchImpl,
    );
    if (!outcome.ok) {
      return outcome;
    }
    return ok<WorkflowRunData>({ kind: "workflow-run", run: mapUpstreamRun(outcome.data) });
  });
}
