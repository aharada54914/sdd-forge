# Operational status for Issue 678

T-678 is Approved / In Progress pending independent final review. It is the prospective acceptance work originally
reviewed as packet T-001; relocation.json retains the identity/path mapping.
No retrospective specification-first development or TDD is claimed.

## Actual signing and publication

The owner configured the independent GitHub environment secret and approved the
protected job in [run 41258114242](https://github.com/aharada54914/sdd-forge/actions/runs/41258114242).
The fixed issuer and exact approved candidate produced a signature and VALID.
The environment requires the actual owner reviewer, disables administrator
bypass and restricts deployment to main. The agent obtained only public artifacts;
it did not obtain the new signing key. Owner-controlled key generation is reported
by the owner, not independently audited by this repository.

The original artifact digest, manifest and candidate bytes were verified. The
existing transactional publisher applied Context, registry, approval and approved
snapshot on this activation branch. See
[publication observation](../../verification/T-678/phase1-publication.json).
Local byte/hash verification is not independent HMAC verification; the protected
CI run supplies that separate authentication provenance. The earlier agent-key
signature in PR #681 is retained as history and is not used for live publication.

## Current verification

Historical MCP typecheck/build/309-test evidence remains byte-identical to the
review packet. Current source comparison retains its original scope. Actual
component coverage was added because it becomes required with live Context.
Its record retains the initial activation/version-bump diff and actual times;
final-head replay equality and authentic CI association are separate checks.
No ownership failure was observed in that execution. Missing optional provider
bindings were reported N/A, not represented as configured or verified.

The v1.19.0 bootstrap version update uses the existing bump script and its
mandatory loop suites. Release-validation parity also passed. The version heading
is preparation; no GitHub Release has yet been published by this change.

## Actual acceptance progress

PR #693 merged the signed activation. Its required CI and capability-mode Gate
passed, and its merge tree matches the tested final head. The public association
in ../../verification/T-678/acceptance-20261101/activation-ci-association.json
binds the original check and collector digest; full API/log/observation exports
remain private. Hash consistency is not independent HMAC authentication.

Fresh execution on tracked-clean a811f6a8 used npm ci, typecheck, build, the full
310-test suite (zero skips) and production audit (zero vulnerabilities). Actual
stdio MCP calls on the real repository returned three successful envelopes,
including 11 passing sdd-forge-mcp tasks and zero failures, without changing the
worktree. Source/lock/command/time/output bindings are recorded under
../../verification/T-678/acceptance-20261101/.

This is genuine pre-bootstrap task acceptance work. The earlier plan to defer
execution until after bootstrap publication was scheduling, not an additional
T-678 Done condition. Independent final quality review is still pending; do not
mark Done or manufacture a passing evidence bundle before it completes.

## Parent release acceptance still required

Publish a genuine bootstrap Release after exact-commit CI succeeds, then observe
real PR work between that start boundary and a final published Release. Every
first-parent commit in the interval must map to its actual PR and latest
advisory observation. There was no prior GitHub Release to invent as the start.
Use the existing contributor release runbook, artifact/SBOM/checksum/attestation
workflow and release-cycle preflight; release work is already authorized.

Finally record an evidence-based retain-advisory or promotion decision. Promotion
requires its existing independent signing, compatibility/live-host and rollback
proofs; retaining advisory does not claim Phase-2 or post-promotion execution.
Issue #678 remains open until actual acceptance is complete.

## Preserved preparation friction

The original task-state/contract preparation rejected non-Z timestamp notation;
its failed and successful records remain unchanged. CI later detected an
unregistered prospective-feature directory, corrected by placing the acceptance
under existing A9 without inventing full-stage review provenance. PR #683's
Pester installation failure passed on one same-head retry. These are preparation
observations, not invented live advisory findings. Owner key enrollment and
actual protected-job review were required admission steps; no human-only timing
measurement is claimed from CI queue durations.
