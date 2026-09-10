# Issue #288: identity collision and incomplete integration

## Reviewer-B diagnostic extension (2026-09-08)

Eight additional direct, unmodified-validator invocations cover reviewer B in
spec and impl stages, on Bash and PowerShell on macOS. Four included-investigation
controls return 0 as expected; four omitted-existing-investigation cases also
return 0, reproducing the defect for reviewer B. This is four expected controls
and four missing rejections, NOT eight passing acceptance tests. Raw output is
in `reports/verification/issue288-reviewer-b-runtime-20260908.json`; manifests
are the four `*-b-*.json` files under the existing diagnostic fixture.

The synthetic ledger's final hash remains
`484cf6b9ba21c5d80b07a07ed9aee1909e3c72289250589df6472084ce778cad`,
matching the manifest pin and prior baseline. No reservation-write flags were
used. Both actual validator hashes match the earlier runtime report. Reviewer-A-only
repair coverage would therefore be insufficient: the new-identity completeness
requirement must cover both review roles without changing historical validation.
Native Windows, actual append, independent formal review and CI remain pending.

Read-only primary investigation. No sub-agent, source edit, test execution,
status transition, commit, push, merge, or issue closure.

## Authoritative anchors

- GitHub main: `4366438f3b243210a4ece5a17f873ca2d920600a`
  (live API result 102ba3).
- Issue #288 remains OPEN and describes investigation provenance/reservation
  completeness, naming commit `18a588101c64e746c0a7592b7c30f5761fcc94ee`
  (a212c2, 7fe519).
- That commit is NOT an ancestor of origin/main (9c8595, exit 1).
  Its locally known containing remote branch is
  `origin/feature/issue-137-sdd-context` (d96b4f), at
  `07d94ee6ddb9ae4b33b3ac539f0e0d6ea0bfd646` (05169c).
  GitHub PR query for that exact head name returned no PR (4d1811).
  This is evidence of an un-PR'd lane, not proof the local branch tip is current.

## Correct the number-only association

The WFI-027 document on main concerns the cross-epic activation contradiction
in A8, Category human-process, Mechanism instructions (96ad71). The same path
at 18a58810 concerns investigation provenance, Category plugin-improvement,
Mechanism tools, Meta-Change true (1aebc5). These are different proposals that
collide on one identifier. Main's Draft/Audit-Not-Started fields therefore
cannot be used as the task contract for Issue #288's implementation. Both
historical proposals must be preserved; renumbering/reconciliation must inspect
the shared namespace before choosing a new identifier. No identifier is allocated
or approval status inferred here.

## Behavior comparison, not whole-commit adoption

Main already implements contract-derived investigation pins in the shared
review precheck library (cf73da, lines 202-266). Main's spec suite has explicit
growth, later-creation, and partial-binding cases (f33015, lines 311-376).
Thus absence of the original commit does NOT imply the audit repair is absent.

The second half is not present in the direct source comparison: the
18a58810 reservation validator contains a spec/impl-only check rejecting a
manifest that omits an existing investigation.md. The two-endpoint diff
07e78f shows that exact block absent in main. Search 026f06 finds none of its
omission diagnostic or investigation variable names in either main validator.
This is a source-level missing-control finding, not yet a runtime reproduction.
The issue explicitly requires the audit change and new-reservation completeness
together; it cannot be closed based on the already-present audit tests alone.

## Next implementation boundary

1. Reconcile the colliding WFI identity with the source issue and approved
   change scope; do not overwrite main's unrelated WFI document.
2. Reproduce omitted-current-investigation acceptance using a controlled
   reservation fixture, preserving ledger isolation and both runtimes.
3. Add only the missing completeness check and regression coverage through the
   approved protected-file human-application path. Preserve main's newer
   normalized-task-hash, gate-declaration, and identity-chain checks; do not
   replace the validator with the older branch version.
4. Validate required presence/current hashes for spec and impl, legitimate
   absence, task-stage exclusion, stale hashes, and historical-contract audit
   cases. Complete formal review and all required CI before merge/closure.

## Other integration lanes

## Runtime follow-up: omission defect reproduced

The earlier source-only finding now has runtime evidence in
`reports/verification/issue288-runtime-20260908.json`; synthetic inputs are in
`reports/verification/issue288-fixture-20260908/`. This is diagnostic evidence,
not a formal gate or an identity reservation. No real ledger was used; both
synthetic ledgers retained their original SHA-256 after all calls.

Both unmodified validators match origin/main (db887f, empty diff). Invocations
used `bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
<manifest> <synthetic-root>` and `pwsh -NoLogo -NoProfile -File
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 -Manifest
<manifest> -RepositoryRoot <synthetic-root>`, each prefixed with `rtk proxy`.
Neither reservation-write option was supplied. New-identity validation still
ran with sequence 2 against the synthetic sequence-1 ledger.

| Input condition | Bash exit | PowerShell exit | Required behavior |
|---|---:|---:|---|
| spec: existing investigation omitted | 0 | 0 | Reject: defect reproduced |
| impl: existing investigation omitted | 0 | 0 | Reject: defect reproduced |
| spec: existing investigation and correct hash | 0 | 0 | Accept |
| impl: existing investigation and correct hash | 0 | 0 | Accept |
| spec: investigation stale hash | 1 | 1 | Reject with HASH |
| impl: investigation stale hash | 1 | 1 | Reject with HASH |
| spec: investigation genuinely absent | 0 | 0 | Accept |
| impl: investigation genuinely absent | 0 | 0 | Accept |
| task: investigation omitted | 0 | 0 | Accept |
| task: investigation included | 1 | 1 | Reject with PATH |

Twenty invocations completed: four demonstrate the missing rejection and
sixteen preserve the expected control behavior. This is NOT 20 passing product
tests. Actual ledger append, historical-contract audit regression, reviewer-B,
symlink/directory boundary cases, independent review, and CI remain unverified.
The next fix must apply only to new-reservation mode; historical verification
must not acquire a dependency on an investigation file created later.

## Current remote snapshot

### Persisted identity compatibility follow-up

Four additional actual-validator calls (fd539c, ebc531, 2f35ab, f24b6f) used
synthetic sequence-2 persisted identities and the same omitted-investigation
manifests. Both spec and impl passed on both runtimes, correctly emitting
`pre_append_tip_sequence=-`. Raw results are in
`reports/verification/issue288-historical-runtime-20260908.json`.
This validates the persisted-identity branch, not the entire precheck audit.

The old commit's added check (2f14e8) is unconditional for spec/impl. Current
source explicitly distinguishes new from persisted identities using ledger
membership, NOT the `--reserve`/`-Reserve` flag (SH lines 358-404; PS lines
313-382). Therefore cherry-picking that check unchanged risks regressing this
valid historical-verification path. The repair must condition the completeness
requirement on missing persisted identity, retaining dry-run new-reservation
checks and all existing identity, path, and hash checks. Do not gate it solely
on the append flag. No source repair or task approval is asserted here.

The search for existing Issue-288-specific review tickets found no match in
`docs/review-tickets` or `specs/workflow-state-integrity/tasks.md` (1de3f0).
An earlier search also included a missing review-cross-critique/tasks.md path
(7b330d); it is not evidence that such a task exists or is approved.

Live PR listing 426e28 still has six open PRs: 245, 371, 381, 390, 394, 400.
PR390 required checks remain terminal FAIL on Windows and aggregate at run
34008982110 (586184); no live run is being waited on or retried to obtain a
favorable sample. PR400's BL-005 evidence blocker remains separately tracked.
