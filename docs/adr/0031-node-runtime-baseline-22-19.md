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

## 2026-11-07: Node 26 LTS migration

The supported runtime floor is now Node **26.13.0** (Lithium LTS), including
MCP servers, Claude hooks, installer preflight and CI. The earlier decision above
records historical compatibility; Node 22 and 24 are no longer supported by the
installer. All three MCP packages use Node 26 type definitions and Inspector
2.14.0. Dependency update checks remain quarterly.

The AWS local compiler pins the official Linux x64 Node 26.13.0 executable and
archive separately. Its existing CDK package lock is retained and must pass native
synthesis and dependency checks on Node 26; the synthetic AWS execution fixture is regenerated through real local synthesis,
including its dependency lock and content-addressed compiled artifacts.

Dependency audit on 2026-11-07 includes development dependencies. All three MCP
lockfiles resolve Inspector 2.14.0 and patched Vite, with no npm audit findings.
The qualified AWS CDK toolchain retains one upstream advisory,
[GHSA-g3hv-75wg-m249](https://github.com/advisories/GHSA-g3hv-75wg-m249),
for bundled minimatch 10.2.5 (moderate denial of service); npm counts both
minimatch and its dependent aws-cdk-lib as two affected packages. Installing
aws-cdk-lib 2.275.0 separately still reproduces the advisory. The suggested
2.239.0 downgrade is not applied because it would replace the qualified compiler
and schema contract. Do not treat successful Node 26 synthesis as resolution of
this advisory. Requalify the toolchain when an upstream fixed bundle is available.
Routine dependency updates remain quarterly; vulnerability remediation is tracked
separately from the routine cadence.

Runtime source: [official Node release index](https://nodejs.org/dist/index.json)
and [v26.13.0 checksums](https://nodejs.org/dist/v26.13.0/SHASUMS256.txt).

Local validation used Linux x64 with Node 26.13.0 and PowerShell 7.6.7:
all three MCP builds/typechecks and 530 tests; strict-engine clean installs;
CI planning/aggregation tests (61 + 92); native AWS preparation (28); cloud
execution (88, with the Windows-only case skipped); Bash and PowerShell
installer and idempotency suites; coding standards tests and diff scan.
Native Windows/macOS execution remains a CI check rather than local evidence.
