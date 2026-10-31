# D-001 / D-002 bounded repair preflight

Run ID: a8-d001-d002-20261014
Task Attempt Count: 1

Owner: a8-release-sync-oct01/sdd-forge; HEAD:
495c88d67af44530687ecea3ce9fb0a90a336539 (detached).
Existing dirty changes are preserved. No other checkout is in scope.
Parent relayed explicit scoped authority on 2026-10-14 to repair D-001/D-002,
including target-specific T-002/T-003 implementation and regressions.
Risk: high (existing evidence contract). No formal ledger or Passed/status
mutation; old review verdicts and preimages remain historical.

Contract: caller-supplied, case-sensitive All|Codex|Claude|Copilot target;
omission means All. Codex surfaces are checked for All/Codex only; other
targets do not acquire Codex assets to make verification pass. Shared plugin
and hook file checks remain mandatory for every target. JSON v1 is unchanged.
D-002 requires both Claude producer and Codex consumer headless confirmation.

## Persisted-field mismatch preflight (WFI-001)

| Field | Counterpart | Failing mismatch oracle |
|---|---|---|
| schema, mode, install_root | installed-plugin-drift-report/v1 and invocation | existing fixture contract_mismatch_self_check mutates each field |
| state | target-specific required surfaces and exit code | new target cases: absent Codex surfaces pass only Claude/Copilot, fail All/Codex/default |
| diverged[].surface/source_ref/installed_ref/change_type | installed/source node and selected surface | existing exact report_entry comparisons and per-field self-check |
| diverged[].installed_sha256/repo_sha256 | installed/source bytes | existing exact report_entry comparisons and per-field self-check |
| matrix target/drift result | same explicit installer/checker target | fresh target cells with no seeded Codex agents or managed regions |
| AC-002 classification | producer AND consumer capability | design consistency sweep; independent design review (not runtime proof) |

Required: RED new target regression, affected checker tests in bash/pwsh,
fresh matrix runs in both wrappers, identifier sweep, independent design
and implementation review. macOS pwsh is not native Windows evidence;
CI remains parent-owned. No native CLI claims follow from fake CLI fixtures.
