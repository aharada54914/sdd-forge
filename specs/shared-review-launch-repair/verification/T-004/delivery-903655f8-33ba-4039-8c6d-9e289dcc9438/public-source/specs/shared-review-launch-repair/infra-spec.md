# Infrastructure Specification: shared-review-launch-repair

## Deployment topology

This is a local reviewer-launch integration with existing host CLI, canonical repository/ledger, and existing CI. No new service or infrastructure is provisioned. The launcher checks dependencies and a native probe before reservation (`plugins/sdd-review-loop/scripts/launch-impl-review.py:321-365`); protection sources and generated projections remain paired (`plugins/sdd-quality-loop/references/guard-invariants.json:56-62`, `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:130-136`).

## CI/CD sequence

Run focused suites from `tests/run-all.sh:70-76`, the applicable PowerShell runner `tests/run-all.ps1:135`, and the permanent workflow `.github/workflows/test.yml:39-42`. Validate the exact submitted HEAD, report platform SKIPs and native-Windows execution separately, then independently review the diff. Merging or installing is not implied by local tests or a gate PASS. Re-verify these shared registrations against the final HEAD; a concurrent branch may change them.

## Runtime dependencies and environment

The existing route requires `rtk`, Claude CLI, Node, Bash, jq, and shasum according to `plugins/sdd-review-loop/scripts/launch-impl-review.py:321-344`; this document does not install or replace them. Production-like native permission proof belongs to the actual host environment, not a disposable fixture. Test copies must not write the live ledger.

## Observability and rollback

Preserve precheck, native proof, receipt, and exact final output as separate records. On failure stop before any further reservation or status change; a consumed identity is not reused. Reverting a candidate or protecting a path follows the existing guarded path and human authority, not an alternate executor.

## Open questions

None for the six-item scope; external CI/native availability may remain a delivery blocker.
