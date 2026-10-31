# A8 BLOCKED continuation v3 — candidate only

Date: 2026-10-05
Owner: a8-release-sync-oct01/sdd-forge.
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
Risk: high (review-history admission and evidence semantics).

## Scope and preflight

This third bounded candidate repairs the legacy regression in
`a8-blocked-continuation-v2-independent-review-20261005.md`. V1 and v2 files
remain historical evidence. The four-file scope, original source hash pins,
evidence-field mismatch preflight, and application restrictions in
`a8-blocked-continuation-v2-result-20261005.md:56` remain applicable.
No source application, design edit, old-verdict edit, reservation, review launch,
status change, installation, Git operation, or human helper is performed.
The four target product paths have an empty `git diff --stat`.

## Root correction

The original Bash precheck checks the contract/precheck extension pair at
`plugins/sdd-review-loop/scripts/impl-review-precheck.sh:408`, then enters the
ADR branch. The original PowerShell helper checks that pair at
`plugins/sdd-review-loop/scripts/impl-review-precheck.ps1:212` and returns null
for legacy at line 222. V3 places the additional BLOCKED history validation
after these existing pairing checks and only inside the ADR-extended branch.
The existing legacy design-only progress path is preserved. The explicit
history-only mode and its canonical count/verdict/hash validation remain as v2.

PowerShell child-validator stdout is discarded with `Out-Null` so that the
helper's JSON return value is not contaminated; its exit code is still checked.
The earlier v3 draft without this output isolation is not final-byte evidence.
The first v3 runner also wrote literal backslash+n in its added legacy fixtures;
independent review identified this test defect. That draft run ended with six
fixture failures (exit 1). The final runner below writes an actual LF and is
rerun in full; draft failures are not counted as product regressions or hidden.

## Fixed candidate hashes

| File | SHA-256 |
|---|---|
| `a8-blocked-continuation-v3-20261005.patch` | `5d9463812a38d4a85f26e82fc10c4f194f4a4f95f04b13b45831bfd5ac4d803b` |
| `a8-blocked-continuation-v3.tests.py` | `1c6ac6f754cb844fe26aeade69328d149b31540e08a7774cf4723995644e65b3` |

## Validation

Executed through `rtk proxy`:

```text
git apply --check reports/verification/a8-blocked-continuation-v3-20261005.patch
python3 reports/verification/a8-blocked-continuation-v3.tests.py
```

Read-only patch check: exit 0. Final-byte fixture run: exit 0, 2 expected RED
reproductions, 42 GREEN precheck assertions, 30 unchanged ADR-generation
assertions, and 18 CLI assertions; all expected outcomes satisfied. Final output:
`owner_history_unchanged=true; failures=0`. The non-PII outcome projection is
saved in `a8-blocked-continuation-v3-outcomes-20261005.txt` (diagnostic bodies
omitted; case identities, exit codes, expectations and outcomes retained).
The runner retains v2's both-runtime Pending and Passed/provenance coverage,
canonical mismatch negatives, round-limit checks, unchanged ADR generation
regressions and explicit CLI argument checks. It adds legacy BLOCKED success
and contract-only/precheck-only extension rejection in both runtimes (6 cases).
These legacy cases use Pending/no-tasks in disposable copies, not owner state.

Independent technical re-review: no actionable defect in the bounded final
candidate; see `a8-blocked-continuation-v3-independent-review-20261005.md`.
The reviewer independently reran all 92 assertions and 24 additional negative
cases successfully. This is not formal gate approval or application authority.
Product application: NOT APPLIED. Native Windows, full workflow regression,
formal gate approval, exact-final-head CI and Done are not claimed.

## Human helper candidate — not executed

After independent review, `a8-blocked-continuation-v3-human-apply.py` was prepared
at the owner's request. SHA-256:
`1570655fa4a9e36c36e3862dffffd204a8b7393210654a3078c4286ea7e3f343`.
Only AST syntax parsing was run (exit 0); neither check nor apply mode was run.
The helper pins owner checkout, HEAD, candidate patch, original bytes and final
four-file hashes. Default/`--check` is read-only. Separately authorized human
`--apply` backs up all four originals before target writes, rechecks originals,
applies once and checks all four resulting hashes. Any mismatch or rejection
stops; no retry/bypass, automatic rollback, historical edit or status mutation.
Backups retain original bytes/modes and a manifest under a unique verification
directory. A partial/uncertain apply requires inspection, never blind rerun.

No protected application was attempted or refused during this candidate work.
The earlier v1 record states the same at
`a8-blocked-continuation-candidate-result-20261005.md:15`. There is no rejection
record to cite, and current application permissibility has not been tested or
inferred. The helper is a proposal, not a claimed alternate authorized executor.
