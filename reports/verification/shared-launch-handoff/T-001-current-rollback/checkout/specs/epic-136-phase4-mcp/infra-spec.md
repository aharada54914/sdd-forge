# Infrastructure Specification: epic-136-phase4-mcp

No cloud service, deployment target, IaC resource, network route, or data
store is added or changed. The only infrastructure-facing effect is that
`mcp/sdd-forge-mcp/dist/index.js` must be rebuilt and committed alongside
this feature's `src/` changes (ADR-0003), and the EXISTING `mcp-tests` CI
job continues to exercise the changed package with no modification to the
job itself — this feature adds no new CI step and touches no protected
workflow file (design.md Protected-File Statement).

## Deployment Topology

```mermaid
flowchart LR
  SRC["mcp/sdd-forge-mcp/src/**.ts (edited: evidence.ts, path-guard.ts, report-lookup.ts)"] -->|npm run build (esbuild)| DIST["mcp/sdd-forge-mcp/dist/index.js (committed, ADR-0003)"]
  SCHEMA["contracts/sdd-forge-mcp-tools.v1.schema.json (edited, additive)"] -.->|validated by| AJV["getEnvelopeValidator() (ajv, tests/evidence/test-helpers.ts:73)"]

  CI["test.yml 3-OS matrix (windows / macos / ubuntu)"] --> MCPJOB["mcp-tests job (existing, UNCHANGED steps)"]
  MCPJOB --> TC["npx tsc --noEmit"]
  MCPJOB --> NT["npm test (node:test, includes this feature's new/updated suites)"]
  MCPJOB -->|ubuntu-latest only| PARITY["npm run build && git diff --exit-code -- dist/"]
  MCPJOB -->|ubuntu-latest only| AUDIT["npm audit --omit=dev --audit-level=high"]
```

## CI/CD Sequence

`.github/workflows/test.yml`'s existing `mcp-tests` job
(`:385-432`) is unchanged in shape by this feature — no new step, no new
job, no new OS leg. The 4 existing steps (`npm ci`, `npx tsc --noEmit`,
`npm test`, then `ubuntu-latest`-only dist rebuild/parity and `npm audit`)
run against this feature's changed `src/`/`tests/`/`contracts/` files
exactly as they run against any other `mcp/sdd-forge-mcp` change. Because
`contracts/sdd-forge-mcp-tools.v1.schema.json` is read at test-time
(`tests/evidence/test-helpers.ts:73`'s `getEnvelopeValidator()` loads it
directly), no separate schema-publishing or schema-registry step exists or
is needed — the schema is a plain repository file, versioned with the code
that implements it.

`dist/index.js` (design.md Deployment / CI Plan) must be regenerated and
committed in the SAME commit as any `src/` change — until that lands, the
`ubuntu-latest` leg's `git diff --exit-code -- dist/` step fails red, the
designed fail-closed state, mirroring `evidence-deep-verify`'s own
Deployment / CI Plan precedent (no staged-candidate fallback, since
`dist/index.js` is not `PROTECTED_GATE_SUFFIXES`-listed and needs none).

No `.github/workflows/test.yml` edit exists in this feature — unlike
`epic-136-phase3`'s Streams A/B/D, this feature adds no new CI step and
therefore has no human-copy staging surface at all.

## Runtime Dependencies

| Dependency | Used by | Absence behavior |
|---|---|---|
| Node.js >= 20 | `mcp/sdd-forge-mcp` (existing `engines` constraint, `package.json:7-9`) | already a hard existing dependency; unchanged |
| `ajv` (devDependency) | contract-conformance tests (`getEnvelopeValidator()`) | already a hard existing test-time dependency (`package.json` devDependencies); unchanged |
| `esbuild` (devDependency) | `npm run build` (dist rebuild) | already a hard existing build-time dependency; unchanged |

No new services, containers, or package installations of any kind. No new
production dependency (`@modelcontextprotocol/sdk`, `js-yaml`, `zod` are
unaffected).

## Environments

| Environment | URL | Auth | Trigger | Classification | Promotion Rule |
|---|---|---|---|---|---|
| local | repository checkout | none / synthetic fixtures | `npm test` inside `mcp/sdd-forge-mcp` | internal fixtures only | all new/updated tests green |
| CI matrix (`test.yml` `mcp-tests` job) | no network use by this feature's own code beyond checkout/npm-install | scoped `GITHUB_TOKEN` (unchanged) | push / PR / merge_group | synthetic + repository-real fixtures (golden tests read this repo's own committed evidence artifacts, unchanged usage) | `mcp-tests` job green on all 3 OSes |

## Runtime Budget

No runtime-budget assertion applies (design.md Test Strategy item 6): every
new/changed test in this feature is pure fixture-driven function/unit
testing — no live network call, no new subprocess, no new large-fixture
scan beyond what `path-security`/`evidence` suites already exercise.

## Infrastructure as Code, Scaling, SLOs, and Residency

N/A — no change: no deployed service. `mcp/sdd-forge-mcp` is a stdio-based
MCP server package, distributed as a committed `dist/` bundle (ADR-0003),
not a hosted/scaled service.

## Observability

| Logs | Traces | Metrics | Alert | Owner | Runbook |
|---|---|---|---|---|---|
| test output (per-suite pass/fail, `node:test`'s own reporter); GitHub Actions `mcp-tests` job status (unchanged mechanism) | N/A | pass/fail per suite per OS (`test.yml`, unchanged mechanism) | none new — this feature adds no new alerting surface | maintainers | re-run `npm test` inside `mcp/sdd-forge-mcp` locally against a fresh fixture if a CI failure needs reproduction; if the dist-parity step fails, run `npm run build` locally and commit the regenerated `dist/index.js` |

## Rollback

Since this feature's contract change is purely additive (3 new `required`
fields, no removed/renamed field or tool) and its schema + implementation
land together in every commit (design.md Global Constraints), a single
reviewed revert of this feature's commit(s) returns both the schema and the
implementation to their exact pre-feature state — no partial-revert hazard,
no protected-file round-trip, and no second human-copy application needed
(unlike `epic-136-phase3`'s Streams that shared a protected
`.github/workflows/test.yml` batch).

## Open Questions

None. Owner: maintainers; non-blocking.
