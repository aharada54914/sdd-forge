/**
 * local-env-mcp entrypoint.
 *
 * Builds the MCP server (3 read-only environment tools) and connects it over
 * stdio. NO environment scanning or version probing happens at startup — probes
 * run only when a tool is invoked (design.md: startup performs no scan, keeping
 * the <=1s startup SLO). stdout is reserved exclusively for the MCP JSON-RPC
 * stdio transport; the only startup diagnostic is a single JSON line on stderr.
 *
 * That line is deliberately trivial — a fixed server name/version and a ready
 * flag — and carries no environment-variable value, username, hostname, or
 * home-directory path. The full redaction-aware diagnostic logger is T-003's
 * scope; index.ts keeps its own output trivially clean.
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { buildServer } from "./server.js";

async function main(): Promise<void> {
  const startupInfo = {
    ok: true,
    data: { server: "local-env-mcp", version: "0.1.0", ready: true },
  };
  process.stderr.write(`${JSON.stringify(startupInfo)}\n`);

  const server = buildServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(
    `${JSON.stringify({ ok: false, error: { code: "cannot-determine", message } })}\n`,
  );
  process.exitCode = 1;
});
