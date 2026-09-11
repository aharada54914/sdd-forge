# RT004: PowerShell root-resolution deferral

Status: DATA candidate updated; protected application and runtime verification pending.
This is not a formal review verdict or ticket resolution.

## Approved scope and observed defect

RT-20260908-004 and proposed ADR-0034 require retaining the supplied root for
safe acquisition. Original `validate-review-context-set.ps1:170-174` performs
Test-Path, Resolve-Path and GetFullPath before manifest stage selection.
The prior DATA candidate only calls Assert-AdrRepositoryRootSyntax near original
line 508: it does not remove the earlier resolution. Ordinary source reads and
`rg` confirmed the first subsequent executable `$root` use is the ledger at
line 248; lines 175-247 parse/validate manifest fields and identities.

## Candidate delta

`adr-runtime-lexical-candidate-20260909.patch` now removes original lines 170-174
and initializes the root immediately before original line 248. For validated
impl stage it checks raw root syntax and preserves RepositoryRoot verbatim.
Other stages retain the original container check and resolution. Both branches
initialize rootPrefix before its consumers. Existing Bash hunks are unchanged.

Candidate SHA-256: `43d8c1fdef60e91bd90852743dde99b368fdb97dffa4eecaee900fcaabcac45d`.
Original PowerShell SHA-256: `832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187`.

## Checks

- Literal DATA assertion for deletion of the early Resolve-Path assignment:
  absent before edit (grep exit 1), present after edit (exit 0).
- `rtk proxy git apply --check --unidiff-zero reports/verification/adr-runtime-lexical-candidate-20260909.patch`: exit 0, without recount.
- Scoped `git diff --check`: exit 0.
- No candidate execution, extraction, reconstruction, or protected application.
  These checks establish patch applicability, not runtime correctness.
- Independent reviewer `/root/rt004_check_contract_review` requested for this
  exact delta and hash; result pending when this note was created.

## Remaining boundaries

This partial fix does not establish safe acquisition. Bash ledger hashing and
JSON reads at original lines 308-355, PowerShell ledger reads at 266-268, and
the later manifest loops still use pathnames. Do not replace only ledger reads
with an unrelated snapshot without preserving reservation concurrency semantics:
PowerShell lines 627-659 lock, recheck the canonical ledger hash and publish an
updated ledger. The full input-reader and identity writer are distinct concerns.

Mount/firmlink correspondence, native Windows drive/UNC acquisition, exact-name
race tests, original-path regression and formal review remain mandatory. No
human application request is appropriate for this incomplete combined candidate.
No commit, push, merge, issue closure, or verdict change was performed.

## Independent finding and correction

The independent reviewer confirmed the initial SHA and identified a possible
Major Windows separator regression: raw `C:/repo` would produce a prefix unlike
the GetFullPath-normalized candidate. Main confirmed the actual consumer at
original lines 522-525 with a direct source read. The candidate now applies
GetFullPath only to the comparison prefix, matching that consumer. Raw root
remains unchanged for acquisition; Resolve-Path is not reintroduced for impl.

Current candidate SHA-256:
`8af353703ed532f2b6e9f6a7211db4f4435a03cd0c3117a2be67ad65588dab66`.
The preceding 43d8 hash identifies the superseded separator-defective revision.
Normal `git apply --check --unidiff-zero` again exited 0. Follow-up independent
static review found the separator issue addressed and no new Critical/Major;
it relied on main's original consumer excerpt and did not independently
recompute the new hash. No native Windows or candidate execution is implied.

Fresh GitHub inspection found 11 open PRs and no queued/in-progress CheckRuns.
CI is terminal, not being waited on; existing failures require repaired inputs
and fresh verification. PR400's old green head does not validate local changes.
