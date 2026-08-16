# ADR 0031: Node Runtime Baseline 22.19.0

Status: Accepted

Date: 2026-08-15

Supersedes: the Node runtime minimum recorded in ADR-0005 and ADR-0014

## Context

The MCP servers in this repository depend on the Inspector CLI and on the
Node runtime shipped in CI, local installs, and installer-driven MCP
placement. The prior baseline of Node 20 had become too loose for the
current contract: the installers needed an exact floor, the package
manifests needed to match it, and CI needed to exercise the supported
runtime rather than an older compatibility target.

This ADR only records the runtime baseline decision. It does not change
the Inspector dependency version, which remains pinned at 0.22.0 for the
current implementation contract.

## Decision

1. The supported Node runtime baseline for all three MCP packages is
   `>=22.19.0`.
2. Installer gating in Bash and PowerShell must reject malformed version
   output and any Node version below `22.19.0`, while accepting `22.19.0`
   and newer releases.
3. CI must run the MCP lanes on Node 22 and include a limited Ubuntu-only
   Node 24 forward-compatibility check.

## Consequences

- The package manifests and generated lockfiles must advertise the new
  floor.
- Documentation and changelog entries must describe the new minimum so
  users can install against the supported runtime without guesswork.
- Older historical ADRs remain unchanged; this decision is recorded only
  in this new ADR.
