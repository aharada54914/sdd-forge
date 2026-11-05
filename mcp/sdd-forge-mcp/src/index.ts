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
import { startStatusView } from "./status-view.js";
import { DashboardReader, selectPresentation } from './dashboard/snapshot.js';
import { dashboardPage } from '../ui/dashboard-page.js';

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

  const args = process.argv.slice(2);
  if (args.includes('--dashboard-snapshot') || args.includes('--dashboard-stream') || args.includes('--dashboard-monitor-stream')) {
    const reader = new DashboardReader(root);
    const emit = () => {
      const started = performance.now();
      const snapshot = reader.sample();
      const output = args.includes('--dashboard-monitor-stream') ? { ...snapshot, _collectionMs: Math.round(performance.now() - started) } : snapshot;
      process.stdout.write(JSON.stringify(output) + '\n');
    };
    emit();
    if (args.includes('--dashboard-stream') || args.includes('--dashboard-monitor-stream')) setInterval(emit, 5000);
    return;
  }
  if (args.includes('--dashboard-html')) {
    const parent = args[args.indexOf('--parent-service') + 1];
    if (!args.includes('--parent-service') || !parent) throw new Error('--parent-service is required');
    process.stdout.write(dashboardPage(selectPresentation(parent) === 'artifacts' ? 'artifacts' : 'http'));
    return;
  }
  if (args.includes("--status-ui") || args.includes('--dashboard')) {
    const view = await startStatusView(root, args.includes('--dashboard'));
    process.stderr.write(`Read-only status view: ${view.url}\n`);
    return;
  }

  const server = buildServer(root);
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${JSON.stringify({ ok: false, error: { code: "cannot-determine", message } })}\n`);
  process.exitCode = 1;
});
