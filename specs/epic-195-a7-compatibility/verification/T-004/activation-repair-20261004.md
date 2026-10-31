# T-004 F3 activation repair

Run ID: epic-195-a7-compatibility-t004-f3-activation-20261004
Task Attempt Count: 3

This implementation addendum preserves historical evidence and frozen specifications.
Scope: activate the existing recorded F3 full-track structural assertions after
the AC-042 allowlist condition becomes true, matching the existing F4 branch.
No corpus refresh, native-host execution claim, commit, push, or Done decision.

## High-risk preflight (before implementation)

| Persisted claim | Counterpart | Failing mismatch check |
|---|---|---|
| F3 active output and successful suite exit | AC-042 / TEST-042; AC-042 allowlist condition | activation regression requires active F3 output and exit 0; existing obsolete F3 skip fails |
| F3 full-track structure | AC-005 full-track templates and unchanged f3-advisory corpus | existing validate_track assertions fail on required-file, AST, status or malformed content mismatch |
| No F3 skip after activation | REQ-007 emitted-line audit | regression rejects any emitted F3/AC-042 SKIP; existing audit rejects obsolete skip |
| Invalid activation evidence fails closed | evaluator condition exit contract (0 active, 1 inactive, other invalid) | suite with missing evidence repository must fail instead of emitting active success |
| Bash/PowerShell parity | same AC-042 condition and recorded corpus | both runtimes must independently pass activation regression |

## Results

- Genuine RED: `activation-red-valid-sh-20261004.log` has 60 passed / 1 failed;
  `activation-red-valid-ps1-20261004.log` has 67 passed / 1 failed. Both suites
  emitted F3/AC-042 after activation and failed their allowlist audit; the new
  regression also rejected the absent active marker and obsolete skip.
- The earlier `activation-red-{sh,ps1}-20261004.log` files are harness path
  mistakes (exit 127 / 64), not behavioral RED evidence. The driver root was
  corrected before the genuine RED above and before suite implementation.
- GREEN: `activation-green-sh-20261004.log` has 77/0;
  `activation-green-ps1-20261004.log` has 84/0, both exit 0. The added regression
  passes with the AC-042 active marker and no F3 skip. F5/F6 remain allowlisted.
- Invalid evidence negative: `activation-invalid-evidence-{sh,ps1}-20261004.log`
  use `STRUCTURAL_COMPAT_EVIDENCE_REPO=/nonexistent/t004-evidence`. Both exit 1
  and explicitly report F3 activation evidence unavailable or invalid. Counts
  are Bash 42/3 and PowerShell 49/3; these expected failures are not GREEN.
- `git diff --check` passes. No diff exists in the recorded corpus or frozen
  requirements/design/acceptance/traceability documents.

Commands: `bash specs/epic-195-a7-compatibility/verification/T-004/activation-regression-20261004.sh sh`
and the same command with `ps1`; all shell entry points used `rtk proxy`.

## Implementation and scoped self-review

The Bash twin adds the existing F4 condition pattern for AC-042. PowerShell
generalizes its existing F4 condition block to select AC-042 and the F3 entry.
Both use the unchanged full-track validator and recorded corpus, preserving
schema, exact paths, frontmatter/headings, status names and fail-closed parsing.
Condition exit 0 executes structural assertions, 1 emits the existing governed
skip, and other exit codes fail. No activation predicate or fingerprint changed.

WFI-015: the newly reachable branch is F3 full-track recorded-artifact validation
after AC-042 activation. It was exercised offline on this macOS host in both Bash
and PowerShell, not claimed as live model or native agent-host evidence.

WFI-012 operator sweep: added fixture comparisons use `-ceq`; `-eq`/`-ne`
remaining in the changed block compare integer process exit codes. Separate
cmdlet/language sweep: no new regex, split, switch, sorting, file-filtering or
string-instance matching was introduced. Existing operator-state and
language-anchor miscase negatives both pass in each fresh GREEN log. Existing
reserved-vocabulary checks retain their deliberately case-insensitive behavior.

## Current output hashes

| Path | SHA-256 |
|---|---|
| tests/structural-compatibility.tests.sh | 8c763a5f321f6eaed481cc7d4b7756f074a1df562a7c3f3c15c318580ce76222 |
| tests/structural-compatibility.tests.ps1 | f4a18da6ce7f898572d6a166bc303bd2866bb5df630aff1ce52b52110089af60 |
| activation-regression-20261004.sh (this directory) | 4754101d5a06faea03fa9c23ab27c8d46eb8ce25966b5b9a5d911d520c906f81 |

## Session handoff and limitations

Scoped implementation and focused regressions complete; parent owns lifecycle
fields. Independent review/quality gate, whole-repository CI and Done remain
unverified. Historical mutation totals were not rerun or relabelled. This is a
focused activation repair, not renewed proof for every historical T-004 claim.
Existing unrelated changes, including T-010 evaluator changes consumed by these
runs, remain outside this repair. No commit or push performed.
