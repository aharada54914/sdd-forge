# PR381 complete POSIX baseline

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db` plus existing uncommitted recovery changes.
Result: **FAIL**, exit 1, 43 failing suites. No formal gate status changed.

Command: `rtk proxy bash -o pipefail -c 'bash tests/run-all.sh 2>&1 | tee /tmp/pr381-posix-20260909.WaPopD/full.log'`
Session 75815 reached terminal exit 1; do not resume or restart it as if still live.
Complete log: `/tmp/pr381-posix-20260909.WaPopD/full.log`
SHA256: `c0a7f8cdee888b03f42d4dee1a0c273cc6b81ecfaece673014a233dd508a4b0e`

No candidate source or dependency changes were made during this run. The runner continued through all inventory entries and its final PowerShell guard suite. Individual PASS counts do not turn this run into a PASS; platform/A5 skips and designed-red outcomes remain separately reported in the complete log.

## Confirmed successful bounded repairs

- loop-driver: 26 passed / 0 failed; includes real traceability validator, obsolete-header negative control, injected allocation failure in conditional context, and real allocation with trailing XXXXXX.
- loop-consistency: 33 passed / 0 failed; existing skips remain.
- loop-inventory: 76 passed / 0 failed.
- loop-escalation: 32 passed / 0 failed.
- bump-version-gate: 18 passed / 0 failed; existing BSD-sed skipped branch remains.
- generate-gate-capabilities: 30 passed / 0 failed / 0 designed-red.
- final guard-r10-port PowerShell suite: 60 passed / 0 failed.

## Triage, not deemed resolution

1. `adversarial-review-contracts`: Ajv unavailable. Current workflow `.github/workflows/test.yml:33` prescribes `npm ci --prefix mcp/ci-mcp --ignore-scripts`. Install only after this baseline terminated, then rerun the actual suite and preserve the original failure.
2. Multiple registration consumers search literal runner source, while `tests/run-all.sh:13` loads `tests/suite-inventory.posix`. See `pr381-registration-sweep-20260909.md`. Interpret each consumer independently: retain exact membership, uniqueness/order requirements, PowerShell twin and CI checks. Some additional consumers are not covered by the initial 35-file grep.
3. `human-copy-mirror-freshness`: A6 `.github/workflows/test.yml` mirror/manifest is stale; 13 pending mirrors are informational, not automatically applied.
4. `deterministic-lane-selfcheck`: candidate job set lacks live `posix-regression`; this is distinct from the now-passing A2 generator candidate. Preserve all live checks.
5. `review-context-boundary`: `review-context-boundary.md` cites `validate-review-context-set.sh:245`, no longer containing the cited schema construct. Confirm current location before any scoped edit.
6. `design-system-contract`: TEST-039 CI reachability remains failing, even though documented as designed red. Must assess actual transitive CI wiring rather than waive it.
7. Remaining failures require individual diagnostics; do not assume all 43 have the same cause.

## Terminal failing-suite list

```text
tests/adversarial-review-contracts.tests.sh
tests/agent-model-routing.tests.sh
tests/agent-capabilities-v2.tests.sh
tests/render-agent-frontmatter.tests.sh
tests/quality-gate-cycle-limit.tests.sh
tests/human-copy-mirror-freshness.tests.sh
tests/deterministic-lane-selfcheck.tests.sh
tests/review-context-boundary.tests.sh
tests/design-system-contract.tests.sh
tests/hitl-wfi-terminal.tests.sh
tests/check-placeholders-brownfield.tests.sh
tests/release-loop-gate.tests.sh
tests/run-panelist-effort.tests.sh
tests/model-freshness-check.tests.sh
tests/facet-manifest-schema.tests.sh
tests/facet-manifest-semantics.tests.sh
tests/capability-summary-schema.tests.sh
tests/facet-manifest-staleness.tests.sh
tests/facet-manifest-parity.tests.sh
tests/canonicalize-sdd-yaml.tests.sh
tests/generate-approval-sidecar.tests.sh
tests/detect-policy-weakening.tests.sh
tests/validate-approval-sidecar.tests.sh
tests/apply-human-copy.tests.sh
tests/check-hook-activation-handshake.tests.sh
tests/guard-invariants-epic-a1.tests.sh
tests/hook-guard-epic-a1-boundary.tests.sh
tests/plugin-contracts-track-selection.tests.sh
tests/ship-track-selection-migration.tests.sh
tests/design-sync-standing-consent.tests.sh
tests/design-sync-scan.tests.sh
tests/structural-compatibility.tests.sh
tests/human-copy-runner-contract.tests.sh
tests/evaluate-predicate.tests.sh
tests/registry-discovery.tests.sh
tests/validate-capability-registry.tests.sh
tests/generate-registry-digest.tests.sh
tests/capability-registry-parity.tests.sh
tests/component-path-resolver.tests.sh
tests/component-path-diff-basis.tests.sh
tests/ownership-digest.tests.sh
tests/check-component-coverage.tests.sh
tests/component-path-ownership-parity.tests.sh
```

## Post-baseline dependency correction

After session 75815 terminated, the exact CI prerequisite command `rtk proxy npm ci --prefix mcp/ci-mcp --ignore-scripts` exited 0 (200 packages added; npm audit reported 0 vulnerabilities). No dependency version/lockfile edit was requested.

`rtk proxy bash -o pipefail -c 'bash tests/adversarial-review-contracts.tests.sh 2>&1 | tee /tmp/pr381-posix-20260909.WaPopD/adversarial-after-ci-deps.log'` then exited 0: `adversarial-review contract tests passed`. `rtk proxy git diff --check` exited 0.

This resolves one environment prerequisite failure only. The original complete run remains FAIL; the other 42 failing suites have not been fixed by installing Ajv, and a new full run has not yet passed.

Formal review, QG, mandatory native CI, commit/push/merge remain pending.

## Subsequent citation repair

See `pr381-boundary-citations-20260909.md`: review-context-boundary now passes all 31 citation anchors and 22 Bash/macOS-PowerShell runtime cases after citation-position-only updates. This resolves a second baseline failing suite, leaving 41 unresolved baseline failures. The historical full-run FAIL above is unchanged; a new complete run has not passed.
