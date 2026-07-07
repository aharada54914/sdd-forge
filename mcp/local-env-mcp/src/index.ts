/**
 * local-env-mcp entrypoint.
 *
 * Builds the MCP server (3 read-only environment tools) and connects it over
 * stdio. NO environment scanning or version probing happens at startup — probes
 * run only when a tool is invoked (design.md: startup performs no scan, keeping
 * the <=1s startup SLO). stdout is reserved exclusively for the MCP JSON-RPC
 * stdio transport; the only startup diagnostic is a single JSON line on stderr.
 *
 * That line is emitted through the redaction-safe diagnostics logger
 * (`logStartup`), which serializes only a fixed field allowlist and never
 * writes an environment-variable value, username, hostname, or home-directory
 * path. Fatal startup errors are routed through `logFatal`, whose single
 * free-form field (the message) is scrubbed of those same secrets.
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { buildServer } from "./server.js";
import { logStartup, logFatal } from "./diagnostics.js";

async function main(): Promise<void> {
  logStartup({ name: "local-env-mcp", version: "0.1.0", transport: "stdio" });

  const server = buildServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  logFatal(error);
  process.exitCode = 1;
});
