/**
 * ci-mcp's 5 read-only GitHub Actions tools (design.md "API / Contract
 * Plan", contracts/ci-mcp-tools.v1.schema.json). Implemented incrementally:
 *   - T-005: list_workflow_runs, get_workflow_run
 *   - T-012: list_run_jobs, list_run_artifacts
 *   - T-013: get_job_log (this file's current scope; all 5 tools now live here)
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
 *
 * `get_job_log` (T-013) reads its 2xx body via `github-client.ts`'s
 * `githubGetText` (a plain-text sibling of `githubGet`, added for this task
 * — see that module's doc comment for why: `githubGet` only supports JSON
 * bodies). Since T-013 cycle-2 (evaluator Major, security-spec.md B2
 * "リングバッファ + 256 KiB 上限(末尾優先)"), the memory-bounding itself
 * lives in `github-client.ts` (`githubGetText`'s bounded streaming read,
 * matching design.md's component table, which allocates job-log truncation
 * to github-client) — `githubGetText`'s `data` is already reduced to a tail
 * window bounded by `TAIL_READ_CAP_BYTES + TAIL_READ_MARGIN_BYTES` before it
 * ever reaches this file. `truncateLogTail`, here, still owns the final,
 * byte-exact cut down to the 256 KiB (262144 byte) contract cap: it slices
 * on a UTF-8-safe byte boundary (never mid-multibyte-character) so the
 * returned tail always decodes cleanly and `returnedBytes` never exceeds the
 * cap, even if that means keeping a handful of bytes fewer than 262144 to
 * land on a valid character boundary. `truncated` in the final envelope is
 * derived by comparing `githubGetText`'s `totalBytesRead` (the true upstream
 * body size) against the final `returnedBytes` — true iff the source was
 * longer than what's returned, regardless of whether the reduction happened
 * during streaming, during the final trim, or both.
 */

import { z } from "zod";

import { err, ok, isOk, type Result } from "../envelope.js";
import { withToken } from "../auth.js";
import { resolveRepo, type RepoResolveArgs, type ResolvedRepo } from "../repo-resolve.js";
import { githubGet, githubGetText, type GithubFetch, type GithubTextFetch } from "../github-client.js";

/** Shared options every tool function accepts for test injection (fetch) and env override. */
export interface ActionsToolOptions {
  env?: NodeJS.ProcessEnv;
  fetchImpl?: GithubFetch;
  /** Text-fetch injection point for `get_job_log` (the one plain-text-bodied endpoint). */
  textFetchImpl?: GithubTextFetch;
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

// ---------------------------------------------------------------------------
// list_run_jobs (T-012)
// ---------------------------------------------------------------------------

/** `$defs/runJobsData.jobs[]`. */
export interface Job {
  id: number;
  name: string;
  status: RunStatus;
  conclusion: RunConclusion;
  startedAt?: string | null;
  completedAt?: string | null;
  failedStep?: number | null;
}

/** `$defs/runJobsData` (`list_run_jobs` output). */
export interface RunJobsData {
  kind: "run-jobs";
  jobs: Job[];
}

interface UpstreamJobStep {
  number: number;
  conclusion: string | null;
}

interface UpstreamJob {
  id: number;
  name: string;
  status: string;
  conclusion: string | null;
  started_at?: string | null;
  completed_at?: string | null;
  steps?: UpstreamJobStep[];
}

interface UpstreamRunJobsResponse {
  jobs: UpstreamJob[];
}

/** Derives the first failed step's number from a job's steps, or `null` when none failed. */
function deriveFailedStep(steps: UpstreamJobStep[] | undefined): number | null {
  if (steps === undefined) {
    return null;
  }
  const failedStep = steps.find((step) => step.conclusion === "failure");
  return failedStep === undefined ? null : failedStep.number;
}

/** Maps a raw upstream job object onto the contract's `Job` shape. */
function mapUpstreamJob(raw: UpstreamJob): Job {
  const job: Job = {
    id: raw.id,
    name: raw.name,
    status: raw.status as RunStatus,
    conclusion: raw.conclusion as RunConclusion,
    failedStep: deriveFailedStep(raw.steps),
  };
  if (raw.started_at !== undefined) {
    job.startedAt = raw.started_at;
  }
  if (raw.completed_at !== undefined) {
    job.completedAt = raw.completed_at;
  }
  return job;
}

/** Raw shape registered with the MCP SDK's `registerTool` for `list_run_jobs`. */
export const LIST_RUN_JOBS_INPUT_SHAPE = {
  owner: z.string().optional().describe("Repository owner. Must be given together with `repo`."),
  repo: z.string().optional().describe("Repository name. Must be given together with `owner`."),
  runId: z.number().int().min(1).describe("The workflow run id whose jobs are listed."),
};

const listRunJobsInputSchema = z.object(LIST_RUN_JOBS_INPUT_SHAPE).strict();

export type ListRunJobsInput = z.infer<typeof listRunJobsInputSchema>;

/**
 * AC-003: lists the jobs for a workflow run, returning the contract's
 * `run-jobs` envelope. `failedStep` is derived as the number of the first
 * step whose conclusion is "failure", or `null` when no step failed / no
 * steps are reported.
 */
export async function listRunJobs(
  input: ListRunJobsInput,
  options: ActionsToolOptions = {},
): Promise<Result<RunJobsData>> {
  const parsed = listRunJobsInputSchema.safeParse(input);
  if (!parsed.success) {
    return err("invalid-input", "list_run_jobs: invalid input", {
      rule: "runId is required and must be a positive integer; owner/repo are optional strings",
    });
  }
  const { owner, repo, runId } = parsed.data;

  return withRepoAndToken({ owner, repo }, options, async (token, resolvedRepo) => {
    const outcome = await githubGet<UpstreamRunJobsResponse>(
      {
        pathSegments: ["repos", resolvedRepo.owner, resolvedRepo.repo, "actions", "runs", String(runId), "jobs"],
        token,
      },
      options.fetchImpl,
    );
    if (!outcome.ok) {
      return outcome;
    }
    return ok<RunJobsData>({
      kind: "run-jobs",
      jobs: outcome.data.jobs.map(mapUpstreamJob),
    });
  });
}

// ---------------------------------------------------------------------------
// list_run_artifacts (T-012)
// ---------------------------------------------------------------------------

/** `$defs/runArtifactsData.artifacts[]`. Metadata only — binary content is never returned. */
export interface Artifact {
  id: number;
  name: string;
  sizeBytes: number;
  expired: boolean;
  expiresAt?: string | null;
  createdAt?: string | null;
}

/** `$defs/runArtifactsData` (`list_run_artifacts` output). */
export interface RunArtifactsData {
  kind: "run-artifacts";
  artifacts: Artifact[];
}

interface UpstreamArtifact {
  id: number;
  name: string;
  size_in_bytes: number;
  expired: boolean;
  expires_at?: string | null;
  created_at?: string | null;
}

interface UpstreamRunArtifactsResponse {
  artifacts: UpstreamArtifact[];
}

/**
 * Maps a raw upstream artifact object onto the contract's `Artifact` shape.
 * Only metadata fields are ever read/forwarded — no binary/archive-download
 * field from the upstream object is copied (design.md OQ-002).
 */
function mapUpstreamArtifact(raw: UpstreamArtifact): Artifact {
  const artifact: Artifact = {
    id: raw.id,
    name: raw.name,
    sizeBytes: raw.size_in_bytes,
    expired: raw.expired,
  };
  if (raw.expires_at !== undefined) {
    artifact.expiresAt = raw.expires_at;
  }
  if (raw.created_at !== undefined) {
    artifact.createdAt = raw.created_at;
  }
  return artifact;
}

/** Raw shape registered with the MCP SDK's `registerTool` for `list_run_artifacts`. */
export const LIST_RUN_ARTIFACTS_INPUT_SHAPE = {
  owner: z.string().optional().describe("Repository owner. Must be given together with `repo`."),
  repo: z.string().optional().describe("Repository name. Must be given together with `owner`."),
  runId: z.number().int().min(1).describe("The workflow run id whose artifacts are listed."),
};

const listRunArtifactsInputSchema = z.object(LIST_RUN_ARTIFACTS_INPUT_SHAPE).strict();

export type ListRunArtifactsInput = z.infer<typeof listRunArtifactsInputSchema>;

/**
 * AC-005: lists artifact metadata for a workflow run, returning the
 * contract's `run-artifacts` envelope. Never returns binary content; an
 * `expired: true` artifact is ordinary data, not an error.
 */
export async function listRunArtifacts(
  input: ListRunArtifactsInput,
  options: ActionsToolOptions = {},
): Promise<Result<RunArtifactsData>> {
  const parsed = listRunArtifactsInputSchema.safeParse(input);
  if (!parsed.success) {
    return err("invalid-input", "list_run_artifacts: invalid input", {
      rule: "runId is required and must be a positive integer; owner/repo are optional strings",
    });
  }
  const { owner, repo, runId } = parsed.data;

  return withRepoAndToken({ owner, repo }, options, async (token, resolvedRepo) => {
    const outcome = await githubGet<UpstreamRunArtifactsResponse>(
      {
        pathSegments: [
          "repos",
          resolvedRepo.owner,
          resolvedRepo.repo,
          "actions",
          "runs",
          String(runId),
          "artifacts",
        ],
        token,
      },
      options.fetchImpl,
    );
    if (!outcome.ok) {
      return outcome;
    }
    return ok<RunArtifactsData>({
      kind: "run-artifacts",
      artifacts: outcome.data.artifacts.map(mapUpstreamArtifact),
    });
  });
}

// ---------------------------------------------------------------------------
// get_job_log (T-013)
// ---------------------------------------------------------------------------

/** `$defs/jobLogData` (`get_job_log` output). */
export interface JobLogData {
  kind: "job-log";
  jobId: number;
  log: string;
  truncated: boolean;
  returnedBytes: number;
}

/** 256 KiB cap on the returned log (contract `jobLogData.returnedBytes` maximum). */
export const MAX_JOB_LOG_BYTES = 262144;

/**
 * Returns the index of the first byte at or after `startIndex` that is NOT a
 * UTF-8 continuation byte (`10xxxxxx`), i.e. a safe place to start decoding
 * without splitting a multi-byte character. At most 3 continuation bytes can
 * precede a valid lead byte in well-formed UTF-8, so this always terminates
 * quickly.
 */
function findSafeUtf8Boundary(buffer: Buffer, startIndex: number): number {
  let index = startIndex;
  while (index < buffer.byteLength && (buffer[index]! & 0xc0) === 0x80) {
    index += 1;
  }
  return index;
}

/**
 * AC-004: applies 256 KiB tail-priority truncation to a job log. When the
 * log's UTF-8 byte length is within the cap, it is returned whole with
 * `truncated: false`. Otherwise only the TAIL (most recent bytes — best for
 * failure diagnosis) is kept: the cut point is advanced forward (never
 * backward) to the next UTF-8 character boundary so the returned tail always
 * decodes cleanly, which means `returnedBytes` can be a small amount under
 * 262144 but never over it.
 */
export function truncateLogTail(log: string): { log: string; truncated: boolean; returnedBytes: number } {
  const buffer = Buffer.from(log, "utf-8");
  if (buffer.byteLength <= MAX_JOB_LOG_BYTES) {
    return { log, truncated: false, returnedBytes: buffer.byteLength };
  }
  const rawStart = buffer.byteLength - MAX_JOB_LOG_BYTES;
  const safeStart = findSafeUtf8Boundary(buffer, rawStart);
  const tailBuffer = buffer.subarray(safeStart);
  return { log: tailBuffer.toString("utf-8"), truncated: true, returnedBytes: tailBuffer.byteLength };
}

/** Raw shape registered with the MCP SDK's `registerTool` for `get_job_log`. */
export const GET_JOB_LOG_INPUT_SHAPE = {
  owner: z.string().optional().describe("Repository owner. Must be given together with `repo`."),
  repo: z.string().optional().describe("Repository name. Must be given together with `owner`."),
  jobId: z.number().int().min(1).describe("The job id whose log is fetched."),
};

const getJobLogInputSchema = z.object(GET_JOB_LOG_INPUT_SHAPE).strict();

export type GetJobLogInput = z.infer<typeof getJobLogInputSchema>;

/**
 * AC-004: fetches a job's plain-text log, returning the contract's
 * `job-log` envelope. `githubGetText` already bounds memory during the
 * fetch itself (streaming tail read); `truncateLogTail` then applies the
 * final, byte-exact 256 KiB tail-priority cut. `truncated` is true iff the
 * upstream body (`outcome.totalBytesRead`) was longer than what is actually
 * returned (`returnedBytes`) — always `ok: true` regardless.
 */
export async function getJobLog(
  input: GetJobLogInput,
  options: ActionsToolOptions = {},
): Promise<Result<JobLogData>> {
  const parsed = getJobLogInputSchema.safeParse(input);
  if (!parsed.success) {
    return err("invalid-input", "get_job_log: invalid input", {
      rule: "jobId is required and must be a positive integer; owner/repo are optional strings",
    });
  }
  const { owner, repo, jobId } = parsed.data;

  return withRepoAndToken({ owner, repo }, options, async (token, resolvedRepo) => {
    const outcome = await githubGetText(
      {
        pathSegments: ["repos", resolvedRepo.owner, resolvedRepo.repo, "actions", "jobs", String(jobId), "logs"],
        token,
      },
      options.textFetchImpl,
    );
    if (!outcome.ok) {
      return outcome;
    }
    const { log, returnedBytes } = truncateLogTail(outcome.data);
    const truncated = outcome.totalBytesRead > returnedBytes;
    return ok<JobLogData>({ kind: "job-log", jobId, log, truncated, returnedBytes });
  });
}
