# Codemap: SDD context continuity

| Field | Value |
|-------|-------|
| Feature | sdd-context-continuity |
| Date | 2026-09-26 |
| Derived From | investigation.md, INV-001–INV-017 |
| Baseline | `5d5ada70636b3c4774095b8e4139ed83c21f30c3` |

## Entry Points

| Path | Role | Evidence |
|------|------|----------|
| `plugins/sdd-quality-loop/hooks/claude-hooks.json` | Claude PreToolUse enforcement | line 1 |
| `plugins/sdd-quality-loop/hooks/hooks.json` | Codex-oriented PreToolUse enforcement | line 1 |
| `mcp/sdd-forge-mcp/src/index.ts` | Read-only MCP startup/root selection | line 15 |

## Module Topology

| Module | Responsibility | Boundary |
|--------|----------------|----------|
| `mcp/sdd-forge-mcp/src/parsers/` | Interpret authoritative specification/evidence files | Reuse interpretation; do not introduce another task-state source |
| `mcp/sdd-forge-mcp/src/tools/core.ts` | Expose active specifications and task state | Read-only |
| `mcp/sdd-forge-mcp/src/root.ts` | Resolve and validate SDD root | Not journal identity |
| `mcp/sdd-forge-mcp/src/path-guard.ts` | Validate paths and guarded reads | Not journal write authorization |

## Key Symbols

| Symbol | Kind | Location | Referenced By |
|--------|------|----------|---------------|
| `resolveRoot` | function | `mcp/sdd-forge-mcp/src/root.ts:39` | MCP startup |
| `isSddRoot` | function | `mcp/sdd-forge-mcp/src/root.ts:74` | Root validation |
| `guardedRead` | function | `mcp/sdd-forge-mcp/src/path-guard.ts:240` | Parsers |
| `parseTaskState` | function | `mcp/sdd-forge-mcp/src/parsers/tasks.ts:67` | Core task reader |
| `listActiveSpecs` | function | `mcp/sdd-forge-mcp/src/tools/core.ts:82` | Core tools |
| `getTaskState` | function | `mcp/sdd-forge-mcp/src/tools/core.ts:163` | Core tools |

## External Dependencies

Existing MCP dependencies are declared in `mcp/sdd-forge-mcp/package.json` and
its lockfile. No dependency was added or selected for the journal. Installed
CLI observations and their limits are recorded in investigation INV-013–014.
The existing build bundles only the stdio startup entry (`package.json:11`);
reuse needs a separate read-only build entry, not import of `src/index.ts`.
See INV-017 before relying on `getSpecStatus` for a safety decision.

## Test Map

| Test Suite | Covers | Location |
|------------|--------|----------|
| Static read-only checks | Prohibited write APIs | `mcp/sdd-forge-mcp/tests/readonly/static-check.test.ts:37` |
| Core snapshots | Core-tool responses remain unchanged | `mcp/sdd-forge-mcp/tests/readonly/core-tools-snapshot.test.ts:37` |

## Not Covered

- Journal implementation: not found in bounded search A; no implementation generated.
- Actual lifecycle event payloads and installed candidate registration: pending probes.
- Retention, redaction and append-failure policy: pending product decisions.
- Cross-platform durability, retry identity and recovery tests: pending design.

Recheck shared registrations and path guards before consuming this map in review.
