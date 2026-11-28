# mcp/AGENTS.md — MCP Server Scoped Guidelines

- All packages under `mcp/*/` (`sdd-forge-mcp`, `ci-mcp`, `local-env-mcp`) follow fixed monorepo versioning from `contracts/release-manifest.json` (`node scripts/sync-ssot.mjs --target release`).
- Runtime floor: Node.js `>=26.13.0` (`engines.node` synced automatically).
- Keep all MCP servers strictly read-only: zero filesystem write APIs, zero secret leakage to stdout/stderr, and frozen project root.
- After editing any MCP server source, run `npm run typecheck && npm run build && npm test` inside its directory so committed `dist/index.js` stays fresh.
- Shared diagnostics live in `mcp/shared/diagnostics-core.ts` (verified by `node scripts/sync-ssot.mjs --target diagnostics --check`).
