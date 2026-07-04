/**
 * sdd-forge-mcp entrypoint.
 *
 * Resolves the project root once (CLI `--root` > `SDD_FORGE_ROOT` > cwd),
 * builds the MCP server with all 8 core tools registered (T-004), and
 * connects it over stdio. Diagnostics (root resolution outcome, fatal
 * startup errors) are always written to stderr — stdout is reserved
 * exclusively for the MCP JSON-RPC stdio transport.
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { isSddRoot, resolveRoot, type SddRoot } from "./root.js";
import { buildServer } from "./server.js";

async function main(): Promise<void> {
  let root: SddRoot;
  try {
    root = resolveRoot();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(
      `${JSON.stringify({ ok: false, error: { code: "not-sdd-root", message } })}\n`,
    );
    process.exitCode = 1;
    return;
  }

  const startupInfo = {
    ok: true,
    data: {
      root: root.path,
      rootSource: root.source,
      isSddRoot: isSddRoot(root),
    },
  };
  process.stderr.write(`${JSON.stringify(startupInfo)}\n`);

  const server = buildServer(root);
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${JSON.stringify({ ok: false, error: { code: "cannot-determine", message } })}\n`);
  process.exitCode = 1;
});
