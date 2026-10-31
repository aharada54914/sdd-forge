# Frontend Specification: epic-136-phase4-mcp

N/A — no change: the deliverables are additive TypeScript changes to an
existing Node.js MCP server package (`mcp/sdd-forge-mcp`) and an additive
JSON Schema change to `contracts/sdd-forge-mcp-tools.v1.schema.json`. There
is no browser or frontend application, and this feature adds no new
package, dependency, or build target.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| `mcp/sdd-forge-mcp/src/tools/evidence.ts`, `src/path-guard.ts`, `src/parsers/report-lookup.ts` | TypeScript (existing) | existing (`^5.9.0`, `mcp/sdd-forge-mcp/package.json`) | 3 narrow, additive function/interface extensions, no new module | must keep `npx tsc --noEmit` green; no new dependency |
| `contracts/sdd-forge-mcp-tools.v1.schema.json` | JSON Schema (draft 2020-12, existing) | existing (`$id` v1, unchanged) | 3 additive `required` property diffs on existing `$defs` entries | `additionalProperties: false` preserved on every new nested object (design.md API/Contract Plan) |
| `mcp/sdd-forge-mcp/dist/index.js` | esbuild bundle (existing) | existing (`^0.28.1`) | rebuilt via the existing `npm run build` script, no new build step | must reproduce byte-identical to the committed file (ADR-0003, dist-parity CI) |

## Component Tree, State Shape, Routes, and API Client

N/A — no change: no component tree, browser state, route, API client, or
frontend bundle exists.

## Performance and Size Budget

N/A — no change: no frontend asset is built. No runtime-budget assertion
applies to this feature's new tests (design.md Test Strategy) — every new
or changed test is pure fixture-driven function/unit testing, comparable in
cost to the existing suites in the same directories (`tests/evidence/`,
`tests/tools/`, `tests/path-security/`).

## Dependencies

No new runtime or dev dependency. This feature adds no new import beyond
`node:crypto`/`node:fs`/`node:path`, all already used elsewhere in
`mcp/sdd-forge-mcp/src/`. No new network call, subprocess, or external API.

## Testing

TEST-001 through TEST-012 in acceptance-tests.md cover the fixture-driven
unit/regression tests (3 changed tool response shapes + the new
`listGuardedFilesWithDiagnostics` function) and the ajv-based contract-
conformance checks. TEST-010 covers the existing `mcp-tests` CI job's
dist-parity/typecheck/audit steps, unchanged in shape. TEST-013/TEST-014
cover document conformance (`CHANGELOG.md`/`USERGUIDE.md`). No component,
accessibility, browser-performance, or frontend E2E test applies.

## Open Questions

None. Owner: maintainers; non-blocking.
