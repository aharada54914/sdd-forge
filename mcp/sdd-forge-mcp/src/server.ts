/**
 * SDD Forge MCP v2 server construction (ADR-0052).
 *
 * Registers exactly 4 coarse-grained, read-only tools and 2 resources backed
 * directly by `v2-readonly-core.mjs` + `path-guard.ts` (Single Source of Truth)
 * and `DashboardReader`.
 *
 * Tool input schemas strictly enforce `additionalProperties: false` and never
 * accept a `root` or arbitrary path parameter: the resolved root is frozen
 * once at server startup.
 */

import { McpServer } from "@modelcontextprotocol/server";
import { z } from "zod";
import { DashboardReader } from "./dashboard/snapshot.js";
import { ok, type Result } from "./envelope.js";
import { registerResources } from "./resources.js";
import type { SddRoot } from "./root.js";
import { sddFeatureState, sddGateAudit, sddProjectOverview } from "./tools/v2.js";

const FEATURE_ARG = z
  .string()
  .regex(/^[A-Za-z0-9._-]+$/, "Feature must match ^[A-Za-z0-9._-]+$.")
  .refine((v) => v !== "." && v !== "..", "Feature must not be '.' or '..'.")
  .describe("Feature slug under specs/ (e.g. 'rate-limiter').");

const TASK_ID_ARG = z
  .string()
  .regex(/^T-[A-Za-z0-9._-]+$/, "taskId must match ^T-[A-Za-z0-9._-]+$.")
  .describe("Optional task ID in tasks.md (e.g. 'T-001').");

const READ_ONLY_ANNOTATIONS = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
} as const;

/** Wraps a `Result<T>` into the MCP `CallToolResult` shape: envelope JSON as `content[0].text`. */
function toCallToolResult<T>(result: Result<T>): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [{ type: "text", text: JSON.stringify(result) }],
  };
}

/** Builds the SDD Forge MCP v2 server against a fixed, already-resolved root. */
export function buildServer(root: SddRoot): McpServer {
  const server = new McpServer(
    {
      name: "sdd-forge-mcp",
      version: "2.2.0",
    },
    {
      cacheHints: {
        "tools/list": { ttlMs: 300_000, cacheScope: "private" },
        "resources/list": { ttlMs: 300_000, cacheScope: "private" },
        "resources/templates/list": { ttlMs: 300_000, cacheScope: "private" },
        "resources/read": { ttlMs: 5_000, cacheScope: "private" },
      },
    },
  );

  server.registerTool(
    "sdd_project_overview",
    {
      title: "SDD project overview",
      description:
        "Returns all active SDD Core v2 features with risk tier, task counts, Spec Drift status, next action, and optional sdd-doctor health summary in one read-only call.",
      inputSchema: z.strictObject({
        includeDoctor: z
          .boolean()
          .default(true)
          .optional()
          .describe("Include compact sdd-doctor summary (default true)."),
      }),
      annotations: READ_ONLY_ANNOTATIONS,
    },
    ({ includeDoctor }) => toCallToolResult(sddProjectOverview(root, { includeDoctor })),
  );

  server.registerTool(
    "sdd_feature_state",
    {
      title: "SDD feature state",
      description:
        "Returns complete SDD Core v2 state for one feature: REQ/AC/Task traceability, Spec Drift status, Open Questions, next action, and optional Decision View markdown.",
      inputSchema: z.strictObject({
        feature: FEATURE_ARG,
        includeDecisionViewMarkdown: z
          .boolean()
          .default(false)
          .optional()
          .describe("Include rendered Decision View markdown (default false)."),
      }),
      annotations: READ_ONLY_ANNOTATIONS,
    },
    ({ feature, includeDecisionViewMarkdown }) =>
      toCallToolResult(sddFeatureState(root, feature, { includeDecisionViewMarkdown })),
  );

  server.registerTool(
    "sdd_gate_audit",
    {
      title: "SDD gate audit",
      description:
        "Audits v2 sdd-gate readiness for a feature (or single task): checks deterministic .execution.json, independent G1-G5 report VERDICT, Spec Drift, and Risk: high Open Questions. For the next operation after a Concept Test stop, read sdd_feature_state.nextAction for the same feature.",
      inputSchema: z.strictObject({
        feature: FEATURE_ARG,
        taskId: TASK_ID_ARG.optional(),
      }),
      annotations: READ_ONLY_ANNOTATIONS,
    },
    ({ feature, taskId }) => toCallToolResult(sddGateAudit(root, feature, taskId)),
  );

  const dashboard = new DashboardReader(root);
  server.registerTool(
    "sdd_dashboard_snapshot",
    {
      title: "SDD dashboard snapshot",
      description:
        "Read-only dashboard snapshot with source freshness and last-good failure state for hosted/local status views.",
      inputSchema: z.strictObject({}),
      annotations: READ_ONLY_ANNOTATIONS,
    },
    () =>
      toCallToolResult(
        ok({
          kind: "dashboard-snapshot" as const,
          snapshot: dashboard.sample(),
        }),
      ),
  );

  registerResources(server, root);

  return server;
}
