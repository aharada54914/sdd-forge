# T-010 AC-016 consumer activation check (non-gate)

This is a focused implementation/regression record, not T-008 host-spy evidence, an Implementation Complete decision, or a quality-gate verdict.

## Change and observed boundary

- `tests/loop-escalation.tests.sh` and `.ps1` now invoke their allowlist evaluators for both AC-004 and AC-021. Invalid activation evidence fails closed. If either merged dependency is active, the test fails because no real interviewer invocation was driven. Only when both remain unmerged does the consumer render its named manifest-derived SKIP. Executable source text or a comment is no longer accepted as a caller proxy.
- `tests/escalation-skip-activation.tests.sh` copies the current manifest into its isolated clone and resets it between runtimes. The prior PowerShell ancestry error was test-state contamination: Bash's invalid-evidence mutation left a zero merged-commit value for PowerShell. Temporary diagnostic code was removed.
- The isolated regression exercises each Bash and PowerShell consumer with an unmerged A5 ref (named SKIP), merged refs without a caller (failure), and merged refs with a synthetic executable caller (still failure without a real invocation). It separately checks clean/unmerged, merged, and invalid manifest audits. All 12 cases passed (exit 0).

## Focused checks

| Command | Result |
|---|---|
| `bash tests/escalation-skip-activation.tests.sh` | exit 0, 12 cases passed (Bash and PowerShell) |
| `bash tests/loop-escalation.tests.sh` | exit 1, 36 passed / 1 failed: active dependency but no real interviewer invocation |
| `pwsh -NoProfile -File tests/loop-escalation.tests.ps1` | exit 1, 35 passed / 1 failed: same intentional unmet T-008 condition |
| `bash tests/skip-allowlist-manifest.tests.sh` | exit 0, 29 passed / 0 failed |
| `pwsh -NoProfile -File tests/skip-allowlist-manifest.tests.ps1` | exit 0, 32 passed / 0 failed |
| `bash scripts/check-sdd-structure.sh` | exit 0, structure OK |
| `git diff --check` | exit 0 |

The isolated premerge fixture is not proof that the current merged checkout should SKIP. The current checkout's loop-escalation test remains RED by design until T-008 drives a genuine interviewer invocation and observes the resolver-call policy. The previous T-008 live-host attempt recorded Claude permission denials in `verification/T-008/live-host-spy-diagnostic-20261004.md`; do not rerun the same denied launch or replace the host observation with a static marker. The next T-008 operation is an authorized, normal host launch with the required narrowly scoped tool permissions, then capture the actual call trace and negative/positive controls under its own task contract. T-010 consumer wiring must not be called GREEN or merge-ready on fixture-only evidence.
