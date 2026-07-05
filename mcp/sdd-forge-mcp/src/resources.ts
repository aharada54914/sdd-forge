/**
 * MCP resource registration: 5 read-only `sdd://` resources (design.md
 * "Architecture" `resources.ts`, "API / Contract Plan"). Every resource is a
 * thin view over the same pure functions `tools/core.ts` uses for the
 * equivalent tool — no logic is re-implemented here, so a resource's JSON
 * body is always byte-for-byte the same envelope a client would get from
 * calling the corresponding tool.
 *
 * - `sdd://active-specs`        <-> `list_active_specs`
 * - `sdd://spec/{feature}`      <-> `get_spec_status`
 * - `sdd://tasks/{feature}`     <-> `get_task_state`
 * - `sdd://review-tickets`      <-> `list_review_tickets`
 * - `sdd://quality-reports`     <-> `get_quality_gate_summary`
 *
 * `feature` path parameters are passed straight through to the same
 * `get_spec_status` / `get_task_state` functions the tools call, which
 * validate the shape internally (`validateFeature`) — a malformed value
 * yields the same `invalid-input` envelope a tool call would, rather than a
 * transport-level error.
 */

import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Result } from "./envelope.js";
import type { SddRoot } from "./root.js";
import {
  getQualityGateSummary,
  getSpecStatus,
  getTaskState,
  listActiveSpecs,
  listReviewTicketsTool,
} from "./tools/core.js";

/** A URI template variable value, normalized to the single string a `feature` path segment always is. */
function firstValue(value: string | string[] | undefined): string {
  return Array.isArray(value) ? (value[0] ?? "") : (value ?? "");
}

/** Wraps a `Result<T>` as a single JSON text resource content entry. */
function toResourceContents<T>(
  uri: string,
  result: Result<T>,
): { contents: Array<{ uri: string; mimeType: string; text: string }> } {
  return {
    contents: [{ uri, mimeType: "application/json", text: JSON.stringify(result) }],
  };
}

/** Registers every read-only `sdd://` resource against a fixed, already-resolved root. */
export function registerResources(server: McpServer, root: SddRoot): void {
  server.registerResource(
    "active-specs",
    "sdd://active-specs",
    {
      title: "Active spec directories",
      description: "Same data as the list_active_specs tool.",
      mimeType: "application/json",
    },
    (uri) => toResourceContents(uri.href, listActiveSpecs(root)),
  );

  server.registerResource(
    "spec-status",
    new ResourceTemplate("sdd://spec/{feature}", { list: undefined }),
    {
      title: "Spec status",
      description: "Same data as the get_spec_status tool.",
      mimeType: "application/json",
    },
    (uri, variables) => toResourceContents(uri.href, getSpecStatus(root, firstValue(variables.feature))),
  );

  server.registerResource(
    "task-state",
    new ResourceTemplate("sdd://tasks/{feature}", { list: undefined }),
    {
      title: "Task state",
      description: "Same data as the get_task_state tool.",
      mimeType: "application/json",
    },
    (uri, variables) => toResourceContents(uri.href, getTaskState(root, firstValue(variables.feature))),
  );

  server.registerResource(
    "review-tickets",
    "sdd://review-tickets",
    {
      title: "Review tickets",
      description: "Same data as the list_review_tickets tool.",
      mimeType: "application/json",
    },
    (uri) => toResourceContents(uri.href, listReviewTicketsTool(root)),
  );

  server.registerResource(
    "quality-reports",
    "sdd://quality-reports",
    {
      title: "Quality gate reports",
      description: "Same data as the get_quality_gate_summary tool.",
      mimeType: "application/json",
    },
    (uri) => toResourceContents(uri.href, getQualityGateSummary(root)),
  );
}
