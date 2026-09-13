# Codemap: epic-197-a9-dogfood

## First-Stop Map

| Concern | First stop | Why |
|---|---|---|
| Project Context shape | `contracts/project-context.schema.json` | Normative schema for workflow, components, and shared paths. |
| Starter Context | `contracts/project-context.template.yaml` | Non-live seed demonstrating Phase-1 workflow values. |
| Capability Pack | `contracts/capability-registry.json` and schema sibling | Current Registry instance and contract. |
| Component ownership | A3 scripts under `plugins/sdd-quality-loop/scripts/` | Ownership resolution, coverage, and digest machinery; locate names fresh at implementation HEAD. |
| Resolver output | A5 artifacts after merge | Produces Facet Manifest, Summary, Projection, and evidence. |
| Approval and rollback | `docs/adr/0019-approval-sidecar-protection.md` | Binding sidecar, HMAC, two-party/cooldown policy. |
| Plugin surfaces | `plugins/*/` | Seven distributable workflow packages. |
| MCP surfaces | `sdd-forge-mcp/`, `local-env-mcp/`, `ci-mcp/` | Three read-only services with different data/credential characteristics. |
| Installation | `install.sh`, `install.ps1`, uninstall twins | Multi-OS, multi-host registration. |
| CI and release | `.github/workflows/test.yml`, `.github/workflows/release.yml` | Existing verification and publication topology. |
| Operational friction | `docs/workflow-improvements/` | Established WFI records and audits. |

## Change Boundaries

- A9's live Context belongs under `sdd/`, but no live file is created during
  bootstrap.
- Registry Pack changes belong to the existing Registry contract surface, not a
  second registry.
- Protected approval records and protected gate machinery require human-copy
  handling; implementation tasks must re-check the live guard inventory.
- `specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`, and
  `CHANGELOG.md` are starter cross-cutting candidates, not automatically the
  final A9 ownership policy (`contracts/project-context.template.yaml:18-30`).

## Re-verification Points

Before spec review and again before implementation, re-read the live Active Spec
list, A1–A8 task states, guard inventory, Registry, plugin/MCP directories, and
the A5 merge state. These are shared git-tracked surfaces and may change outside
this feature.
