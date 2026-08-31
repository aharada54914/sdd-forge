# Infrastructure Specification: epic-197-a9-dogfood

## Deployment Topology

The live Context and Registry remain repository files consumed locally by
installed plugins and CI. No service or infrastructure resource is provisioned.
Release remains the existing GitHub workflow (`.github/workflows/release.yml:26-50`).

## CI/CD Sequence

1. Run dependency/shared-state preflight.
2. Validate Context, component ownership, Registry, and resolver outputs.
3. Run Bash/PowerShell parity and existing cross-OS matrices.
4. In Phase 1, report Pack findings advisory-only.
5. After separately approved promotion, enforce Pack-required gates.
6. Keep release publication behind its existing loop gate.

## Environments

| Environment | Purpose |
|---|---|
| Linux | shell path, installer, CI compatibility |
| macOS | shell path, installer, CI compatibility |
| Windows | PowerShell path, installer, CI compatibility |
| Claude/Codex/Copilot | installed consumer registration/regression |

## Infrastructure as Code

N/A. Existing workflow edits, if required, are protected human-copy candidates.

## Scaling Strategy

Repository-size path resolution and deterministic fixture execution only. Avoid
network calls and bound tests to tracked paths/fixture sets.

## Service Level Objectives

No runtime SLO. Determinism objective: identical semantic Context/Registry input
produces equivalent resolver evidence across supported entry points.

## Data Residency and Retention

Evidence and Draft WFIs are git-tracked. Tests use synthetic data and must not
capture tokens, home paths, usernames, or hostnames. CI-MCP token behavior stays
as documented (`README.md:132-144`).

## Observability

Saved preflight, resolver, promotion, rollback, parity, and regression logs with
stable run identity and bound revisions/digests.

## Cost Estimate

No new hosted service. Incremental three-OS CI time only.

## Rollback

Required-to-advisory is not a plain deploy rollback; it is policy weakening and
must follow ADR-0019 plus OQ-004. Code/release rollback does not waive Context
approval (`docs/adr/0019-approval-sidecar-protection.md:83-112`).

## Open Questions

OQ-003 fixes evidence thresholds; OQ-004 fixes operational rollback steps.

