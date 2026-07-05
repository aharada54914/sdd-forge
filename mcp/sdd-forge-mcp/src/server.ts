/**
 * MCP server construction: builds the `McpServer` and registers the 8 core
 * tools, 5 evidence tools, and 5 resources (design.md "Architecture" /
 * "API / Contract Plan").
 *
 * Every tool response is the common `Result<T>` envelope
 * (contracts/sdd-forge-mcp-tools.v1.schema.json), serialized as JSON text
 * into `content[0].text` — the MCP protocol has no first-class "structured
 * error" concept for `isError: true` results that would let us return the
 * v1 envelope shape directly, so both `ok` and `error` envelopes are always
 * returned as a normal (non-error) tool result whose text is the envelope
 * JSON. This lets any MCP client parse the same envelope shape regardless of
 * whether the underlying read succeeded.
 *
 * Tool input schemas intentionally never include a `root` parameter
 * (REQ-007 / AC-016): the resolved root is captured once in this module's
 * closure and is not accepted as tool input.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { Result } from "./envelope.js";
import { registerResources } from "./resources.js";
import type { SddRoot } from "./root.js";
import {
  getNextSddCommand,
  getQualityGateSummary,
  getSpecStatus,
  getTaskState,
  listActiveSpecs,
  listApprovedTasks,
  listBlockedTasks,
  listReviewTicketsTool,
} from "./tools/core.js";
import {
  evidenceCompareToTraceability,
  evidenceFindMissing,
  evidenceGetBundle,
  evidenceSummarizeContractChecks,
  evidenceValidatePaths,
} from "./tools/evidence.js";

const FEATURE_ARG = z
  .string()
  .describe("Feature directory name under specs/ (e.g. 'sdd-forge-mcp').");

const TASK_ID_ARG = z.string().describe("Task id in tasks.md (e.g. 'T-005').");

/** Wraps a `Result<T>` into the MCP `CallToolResult` shape: the envelope JSON as `content[0].text`. */
function toCallToolResult<T>(result: Result<T>): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [{ type: "text", text: JSON.stringify(result) }],
  };
}

/** Builds the MCP server and registers every core tool against a fixed, already-resolved root. */
export function buildServer(root: SddRoot): McpServer {
  const server = new McpServer({
    name: "sdd-forge-mcp",
    version: "0.1.0",
  });

  server.registerTool(
    "list_active_specs",
    {
      title: "List active spec directories",
      description:
        "Lists every feature under AGENTS.md's Active Spec Directories, each " +
        "flagged with whether its tasks.md has an Approved task that is " +
        "Planned or In Progress.",
    },
    () => toCallToolResult(listActiveSpecs(root)),
  );

  server.registerTool(
    "get_spec_status",
    {
      title: "Get spec status",
      description:
        "Reports which Phase 1/2 artifacts exist under specs/<feature>/ and the " +
        "review-status header of requirements.md/design.md/tasks.md.",
      inputSchema: { feature: FEATURE_ARG },
    },
    ({ feature }) => toCallToolResult(getSpecStatus(root, feature)),
  );

  server.registerTool(
    "get_task_state",
    {
      title: "Get task state",
      description:
        "Parses specs/<feature>/tasks.md's state machine, shell-equivalent to " +
        "check-task-state.sh (pass/fail verdict and per-task failures).",
      inputSchema: { feature: FEATURE_ARG },
    },
    ({ feature }) => toCallToolResult(getTaskState(root, feature)),
  );

  server.registerTool(
    "list_approved_tasks",
    {
      title: "List approved tasks",
      description: "Lists every task in specs/<feature>/tasks.md with an Approved-shaped Approval.",
      inputSchema: { feature: FEATURE_ARG },
    },
    ({ feature }) => toCallToolResult(listApprovedTasks(root, feature)),
  );

  server.registerTool(
    "list_blocked_tasks",
    {
      title: "List blocked tasks",
      description: "Lists every task in specs/<feature>/tasks.md whose Status is Blocked.",
      inputSchema: { feature: FEATURE_ARG },
    },
    ({ feature }) => toCallToolResult(listBlockedTasks(root, feature)),
  );

  server.registerTool(
    "list_review_tickets",
    {
      title: "List review tickets",
      description: "Lists every parsed docs/review-tickets/RT-*.yml review ticket.",
    },
    () => toCallToolResult(listReviewTicketsTool(root)),
  );

  server.registerTool(
    "get_quality_gate_summary",
    {
      title: "Get quality gate summary",
      description:
        "Lists every reports/quality-gate/*.md report that has a VERDICT line, " +
        "with its finding counts.",
    },
    () => toCallToolResult(getQualityGateSummary(root)),
  );

  server.registerTool(
    "get_next_sdd_command",
    {
      title: "Get next SDD command",
      description:
        "Determines the next SDD workflow command for a feature (or, with no " +
        "feature argument, auto-selects the single active feature the same way " +
        "sdd-ship:run does) by walking AGENTS.md's Required Workflow gates.",
      inputSchema: { feature: FEATURE_ARG.optional() },
    },
    ({ feature }) => toCallToolResult(getNextSddCommand(root, feature)),
  );

  server.registerTool(
    "evidence_get_bundle",
    {
      title: "Get evidence bundle",
      description:
        "Reads and echoes specs/<feature>/verification/<taskId>.evidence.json " +
        "as-is (including its signature field); never verifies the signature " +
        "or reads any signing key.",
      inputSchema: { feature: FEATURE_ARG, taskId: TASK_ID_ARG },
    },
    ({ feature, taskId }) => toCallToolResult(evidenceGetBundle(root, feature, taskId)),
  );

  server.registerTool(
    "evidence_validate_paths",
    {
      title: "Validate evidence artifact paths",
      description:
        "For every artifact path in <taskId>.evidence.json, reports whether " +
        "it is a safe repo-relative path within the path-guard allowlist and " +
        "whether it currently exists.",
      inputSchema: { feature: FEATURE_ARG, taskId: TASK_ID_ARG },
    },
    ({ feature, taskId }) => toCallToolResult(evidenceValidatePaths(root, feature, taskId)),
  );

  server.registerTool(
    "evidence_find_missing",
    {
      title: "Find missing Done-transition evidence",
      description:
        "Reports which Done-transition requirements (evidence bundle, " +
        "verification contract, a passing quality-gate report) are present " +
        "vs. missing for a task, shell-equivalent to check-task-state.sh's " +
        "Done evidence checks.",
      inputSchema: { feature: FEATURE_ARG, taskId: TASK_ID_ARG },
    },
    ({ feature, taskId }) => toCallToolResult(evidenceFindMissing(root, feature, taskId)),
  );

  server.registerTool(
    "evidence_summarize_contract_checks",
    {
      title: "Summarize verification contract checks",
      description:
        "Reads <taskId>.contract.json and summarizes each check's " +
        "required/passes/waiverReason/requirementIds fields.",
      inputSchema: { feature: FEATURE_ARG, taskId: TASK_ID_ARG },
    },
    ({ feature, taskId }) => toCallToolResult(evidenceSummarizeContractChecks(root, feature, taskId)),
  );

  server.registerTool(
    "evidence_compare_to_traceability",
    {
      title: "Compare verification artifacts to traceability",
      description:
        "Cross-checks traceability.md's REQ -> Task and AC -> TEST -> Task " +
        "tables against tasks.md's task ids, and each task's verification " +
        "contract requirementIds against traceability.md's declared REQ-IDs.",
      inputSchema: { feature: FEATURE_ARG },
    },
    ({ feature }) => toCallToolResult(evidenceCompareToTraceability(root, feature)),
  );

  registerResources(server, root);

  return server;
}
