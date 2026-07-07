/**
 * ci-mcp entrypoint.
 *
 * Builds the MCP server and connects it over stdio. Startup performs NO
 * GitHub API call and NO token validation (design.md: startup <= 1s SLO) —
 * token resolution (T-003) and GitHub calls (T-002) happen only when a tool
 * is invoked, and no tool is registered yet in T-001. stdout is reserved
 * exclusively for the MCP JSON-RPC stdio transport; on a fatal startup error
 * a single line is written to stderr and the process exits non-zero.
 *
 * A dedicated redaction-safe diagnostics logger (mirroring local-env-mcp's
 * `diagnostics.ts`) is introduced in T-003 alongside token handling; T-001
 * has no secret material to scrub (no env var is read here), so the fatal
 * handler below writes the bare error message.
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { buildServer } from "./server.js";

async function main(): Promise<void> {
  const server = buildServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${JSON.stringify({ event: "fatal", message })}\n`);
  process.exitCode = 1;
});
