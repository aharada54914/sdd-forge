/**
 * MCP server construction: builds the `McpServer` and registers exactly the 3
 * local-env-mcp tools (design.md "Architecture" / "API / Contract Plan"):
 *   - get_os_info            (no input)
 *   - get_toolchain_versions (optional `names` filter — the 14-name enum only)
 *   - list_available_clis    (no input)
 *
 * Every tool response is the common `Result<T>` envelope
 * (contracts/local-env-mcp-tools.v1.schema.json), serialized as JSON text into
 * `content[0].text`. Both `ok` and `error` envelopes are returned as an
 * ordinary (non-error) tool result: the MCP protocol has no structured-error
 * shape that would carry our v1 envelope, so any client parses the same
 * envelope regardless of whether the read succeeded (mirrors sdd-forge-mcp).
 *
 * Tool input schemas intentionally never include a command / args / path
 * field (REQ-003 / AC-003): the only accepted input is the `names` enum filter
 * on get_toolchain_versions. The server performs NO environment probing at
 * construction time — probes run only when a tool is invoked.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import type { Result } from "./envelope.js";
import {
  getOsInfo,
  getToolchainVersions,
  listAvailableClis,
  TOOLCHAIN_TOOL_INPUT_SHAPE,
} from "./tools/env.js";

/** Wraps a `Result<T>` into the MCP `CallToolResult` shape: envelope JSON as `content[0].text`. */
function toCallToolResult<T>(result: Result<T>): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [{ type: "text", text: JSON.stringify(result) }],
  };
}

/** Builds the MCP server and registers the 3 read-only environment tools. */
export function buildServer(): McpServer {
  const server = new McpServer({
    name: "local-env-mcp",
    version: "0.1.0",
  });

  server.registerTool(
    "get_os_info",
    {
      title: "Get OS info",
      description:
        "Reports platform, arch, OS type/release, logical CPU count, total " +
        "memory, and the Node runtime version from os/process APIs. Never " +
        "returns hostname, username, home directory, or environment values.",
    },
    () => toCallToolResult(getOsInfo()),
  );

  server.registerTool(
    "get_toolchain_versions",
    {
      title: "Get toolchain versions",
      description:
        "Probes the fixed 14-CLI allowlist (or the subset named in `names`) " +
        "with execFile --version and returns a normalized version string per " +
        "available CLI. Missing CLIs are reported available:false; the whole " +
        "response stays ok:true. Accepts no command, argument, or path input.",
      inputSchema: TOOLCHAIN_TOOL_INPUT_SHAPE,
    },
    async ({ names }) => toCallToolResult(await getToolchainVersions({ names })),
  );

  server.registerTool(
    "list_available_clis",
    {
      title: "List available CLIs",
      description:
        "Reports availability (present/absent) for each CLI in the fixed " +
        "14-CLI allowlist, without version strings. Takes no input.",
    },
    async () => toCallToolResult(await listAvailableClis()),
  );

  return server;
}
