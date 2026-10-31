/**
 * ci-mcp entrypoint.
 *
 * Builds the MCP server and connects it over stdio. Startup performs NO
 * GitHub API call and NO token validation (design.md: startup <= 1s SLO) —
 * token resolution (auth.ts) and GitHub calls (github-client.ts) happen only
 * when a tool is invoked, and no tool is registered yet (tools start at
 * T-005). stdout is reserved exclusively for the MCP JSON-RPC stdio
 * transport; the only startup diagnostic is a single JSON line on stderr,
 * and a fatal startup error writes one more before the process exits
 * non-zero.
 *
 * Both lines are routed through the redaction-safe diagnostics logger
 * (`diagnostics.ts`, same shape as local-env-mcp's): `logStartup` emits only
 * a fixed field allowlist, and `logFatal`'s single free-form field (the
 * message) is scrubbed of secrets (env-variable values — including any
 * resolved GitHub token — home directory, username, hostname, and any
 * `Bearer <token>` pattern).
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { buildServer } from "./server.js";
import { logStartup, logFatal } from "./diagnostics.js";

async function main(): Promise<void> {
  logStartup({ name: "ci-mcp", version: "0.1.0", transport: "stdio" });

  const server = buildServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  logFatal(error);
  process.exitCode = 1;
});
