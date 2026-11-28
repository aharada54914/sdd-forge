/**
 * SDD Forge MCP v2 resource registration (ADR-0052): 2 read-only `sdd://`
 * resources backed directly by the same v2 functions as the MCP tools.
 *
 * - `sdd://overview`          <-> `sdd_project_overview({ includeDoctor: true })`
 * - `sdd://feature/{feature}` <-> `sdd_feature_state({ feature, includeDecisionViewMarkdown: true })`
 */

import { McpServer, ResourceTemplate } from "@modelcontextprotocol/server";
import type { Result } from "./envelope.js";
import type { SddRoot } from "./root.js";
import { sddFeatureState, sddProjectOverview } from "./tools/v2.js";

function firstValue(value: string | string[] | undefined): string {
  return Array.isArray(value) ? (value[0] ?? "") : (value ?? "");
}

function toResourceContents<T>(
  uri: string,
  result: Result<T>,
): { contents: Array<{ uri: string; mimeType: string; text: string }> } {
  return {
    contents: [{ uri, mimeType: "application/json", text: JSON.stringify(result) }],
  };
}

export function registerResources(server: McpServer, root: SddRoot): void {
  server.registerResource(
    "overview",
    "sdd://overview",
    {
      title: "SDD project overview",
      description: "Read-only SDD Core v2 overview including sdd-doctor summary.",
      mimeType: "application/json",
    },
    (uri) => toResourceContents(uri.href, sddProjectOverview(root, { includeDoctor: true })),
  );

  server.registerResource(
    "feature-state",
    new ResourceTemplate("sdd://feature/{feature}", { list: undefined }),
    {
      title: "SDD feature state",
      description: "Read-only SDD Core v2 feature state including rendered Decision View.",
      mimeType: "application/json",
    },
    (uri, variables) =>
      toResourceContents(
        uri.href,
        sddFeatureState(root, firstValue(variables.feature), {
          includeDecisionViewMarkdown: true,
        }),
      ),
  );
}
