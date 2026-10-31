# PR381 scratch follow-up: current work, not approval evidence

Target: PR #381, base implementation 3b15996b288ef75b741ab2afe4b403109fac2721.
Authorization: existing user instruction to resolve review findings and preserve checks.
No review verdict, task status or historical identity record is to be rewritten.

## Reproduction

The expanded scratch-history fixtures run against both installed source validators:
20 cases pass and 6 fail. Legacy missing history is rejected; modifying a saved
scratch root permits a later reservation of the originally reserved root. Two
additional failures expose the not-yet-supported bound-ledger extension.

The metric test fails before correction (3 counted instead of 1), and passes
after reconciling identities with the reservation ledger and deduplicating copies.

## Bounded repair plan / high-risk persisted-field preflight

| Persisted field | Counterpart | Failing mismatch or boundary test |
| --- | --- | --- |
| optional ledger scratch_declaration_sha256 | SHA256(feature + LF + scratch_root), no terminal LF | snapshot-tampered in each runtime |
| record_sha256 for bound records | old chain text plus tagged declaration digest | prior-missing and altered digest chain tests |
| saved invocation scratch_root | bound declaration digest | snapshot-tampered; snapshot-deleted |
| metric declared/auditable | unique reserved run/session identity, not files | evaluator-scratch-metrics.tests.py |

Legacy ledger records retain their existing bytes and hash formula. Only new
quality evaluator reservations declaring a root add the optional digest and
hash it into the chain. Records without this extension may lack invocation
history; they are not evidence of verified isolation. New bound records must
have matching history, including on verification without a newly declared root.
Known legacy roots still prevent overlap; unknown historical roots cannot be
reconstructed or claimed safe.

Both runtime validators, the reviewer hash-verification contract and regressions
must change together. All existing checks and CI remain required. A green CI on
3b15996 is not validation of these working changes. WFI-034 application reporting
must distinguish code applied from its five genuine quality runs still pending.

## Applied repair and verification (2026-09-14)

The human ran the pinned five-file repair successfully. Its isolated boundary
tests verified all 31 citations, both runtime reservation/verification controls,
26 scratch-history cases (zero failures), and the metric regression including
the duplicate/reserved-identity unit test. The five resulting SHA-256 values
were independently checked against the actual worktree and match the receipt.

The main-agent code review checked the legacy hash path, optional binding field,
new reservation hash, persisted verification, snapshot history and duplicate
metric behavior. This is code review, not an independent SDD gate verdict.
No task status, review verdict or live identity ledger was changed.

The expanded tests also reject omission of an already-bound scratch root. The
original missing-history failures above describe the pre-repair reproduction,
not the current isolated test result. Full actual-worktree POSIX verification
and new-commit CI remain separate requirements; prior green CI is not reused.

Preserve the unrelated existing staged-patch README edit and untracked review
reconciliation note outside this repair commit. No backups or historical
evidence are deleted. Issue #311 still needs five genuine auditable runs.
