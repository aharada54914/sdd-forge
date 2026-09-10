# PR245 identity-ledger integration preflight

Status: read-only investigation; not a gate verdict or merge approval.

Exact endpoints: main `4366438f3b243210a4ece5a17f873ca2d920600a`, PR245
`54b1ff247081971e0560cf20d45f4369e01b5c0d`.

Primary parsed both committed JSON ledgers through `git show` (tool result
afe69d): main has 959 records, PR has 884, and the first 764 records are
identical. There are 120 PR-only run identities. No shared run ID maps to a
different host-session ID in this comparison. This last check is not a full
uniqueness or cryptographic validation.

The divergence begins at sequence 765, not merely at a textual formatting
conflict. Taking the PR ledger discards main history. Appending PR-only records
without rebuilding their sequence/hash chain violates the chain contract.
Rebuilding that chain alone is also insufficient: the exact main validator
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:383`–391
compares a persisted invocation's sequence and previous-record hash against its
manifest, even though its comment at line 362 mentions branch re-chaining.

Before choosing an integration operation, inventory the affected invocation
manifests and their evidence-freeze boundaries. Preserve original run/session
identities and historical verdicts. Do not silently renumber historical
manifests, synthesize replacement reviewer identities, or weaken validation.
No ledger, invocation, or protected script was changed during this preflight.

Registry reconciliation is separately straightforward at the data level:
retain main's Done status eligibility and all four current registrations
(sdd-domain-concept-contract, A6, A8, A7), and add A5 rather than replacing them.
This is a proposed resolution, not an applied or verified candidate.

## Invocation inventory follow-up

Primary inspected all JSON files directly under the committed review-context
tree, matching the 120 PR-only run IDs (tool result f5b01c). 117 have one
matching manifest, with sequence and previous-record hash equal to their
original branch ledger record. None has multiple matching manifests there.
Three have no matching manifest in that tree:

- spec reviewer A, a3r2, seq0772
- spec reviewer B, a3r2, seq0773
- task reviewer B, a13r1, seq0860

This is an inventory result, not proof those launches occurred or passed.
Investigate their historical disposition; do not fabricate missing manifests.

The final task-review invocation at
`reports/review-context/pending-epic-193-a5-capability-resolver-task-reviewer-a-a15r1-seq0883-manifest.json`
explicitly binds sequence 883 and its predecessor hash. Its run/session also
appears in the attempt-15 round-1 task-review contract and reviewer output.
These concrete references establish why blind ledger re-numbering is not a
complete integration operation. Historical verdicts remain unchanged.

## Existing archival integration procedure recovered

The PR's committed `reports/notes/epic-193-a5-merge-resolution.md` (v3,
commit aa3b39af8f6c2f39f7203968359208c0fa1c4e04) already specifies a distinct
archival approach: retain main's prefix, append branch identities changing
only sequence/predecessor/record hash, preserve historical invocation files
unchanged, and recover original chains from git history. It explicitly
acknowledges that old invocation pins cannot replay against the merged chain.
Thus the mismatch identified above is not automatically a reason to redesign
the validator or edit historical manifests. The earlier procedure's current
applicability still needs verification; its 92-record count and conflict list
are stale. The September 4 handoff updates the count to 120.

Primary read-only calculation (47b0dc) verified both original hash chains,
sequence continuity, and run/session uniqueness: 959 and 884 records. An
in-memory archival merge of the 120 branch-only identities yields a valid
1079-record chain, retains main's entire prefix unchanged, and retains all
branch stage/role/run/session fields. No ledger was written. This checks only
chain mechanics, NOT invocation replay, stage provenance, or repository gates.

Commit 2e9af4c6579521f23ecda48277c58ce99607050d explicitly records that
seq0772/0773 reviewers never ran after credits exhausted. Their skeleton
outputs and pending manifests were intentionally removed, while reservations
were retained. Do not reconstruct them or count them as reviews. For seq0860,
commit d731eb12b8101c7186823ac29523844138d6e7fc persists the reservation but
the actual attempt-13 reviewer B uses seq0861; its commit message does not
explain the abandoned seq0860. Preserve it without claiming a verdict.

The recovered recipe requires human application of protected conflicts.
Its suggested guard workaround in the separate handoff is NOT an authorized
execution method here. No hook bypass or protected-file modification occurred.

## Human-copy manifest conflict resolved at the content-selection level

For the same exact endpoints above, `git merge-tree --write-tree --name-only`
produced unresolved tree `715c587fa161e4583377f3e5717971bb97301517` (exit 1;
23 conflicts). This tree is NOT a finished merge or passing candidate.

Primary inspected all 12 rows in main's epic-191 human-copy manifest and
hashed both each live blob and its staged twin in that tree (tool b087d7).
All 24 SHA-256 comparisons match main's manifest. In particular the SH and
PowerShell spec-review prechecks auto-merge to main's exact bytes, including
their staged twins; neither requires a new hash. Therefore selecting main's
manifest is content-correct for this exact merge tree. The old recipe's
unresolved two-row escalation is superseded by this direct blob evidence,
not by assuming that a clean textual merge proves semantic correctness.

No manifest or protected file was modified. Re-run these 24 comparisons on
the final candidate after all conflicts are resolved, and if either endpoint
changes. This finding does not clear the other 22 conflicts or the quality
gate, and does not authorize an agent to apply protected merge resolutions.

## prepare-panelist test conflict selection

Primary compared the complete endpoint diff for `tests/prepare-panelist.tests.sh`
and `.ps1` (6d0bed). Selecting main preserves all behavior added on this PR:
the endpoint differences contain no PR-only test case to add. The PR side
instead removes SH PP-014's missing-key fail-closed test and its non-vacuity
control, restores early-exit grep in TEST-049/055/075, and pins TEST-061c in
both runtimes to the obsolete `there` wording. Keep main's two suites intact
alongside main's corresponding prepare-panelist implementation; do not union
the old assertions back in. This is a full textual-diff selection finding,
not a claim that the suites have been run on a resolved integration candidate.

## Runner inventory union verified against the exact merge tree

Primary endpoint inspection (8f118f) and path inventory (719024) confirm nine
PR-only resolver suites per runtime. Retain main's complete runner bodies and
registrations, adding only those nine entries: POSIX 136 + 9 = 145,
PowerShell 91 + 9 = 100. These unions have no duplicate paths and every
registered path exists in the merge tree. Counts refer to registered paths,
not executed/passing tests. Preserve main's wrapper functions and all A6/A7,
installer, ownership, lifecycle and evidence regression registrations.

`AGENTS.md` must retain main's canonical quality-report identity block and all
existing feature registrations, adding only A5. The workflow registry must
retain `Done` eligibility and main's existing entries, adding A5 with profile
`full`. Taking either PR file wholesale would regress these main contracts.

## Delegated provenance conclusion not accepted as proof

The follow-up agent asserted that check-workflow-state drives
validate-review-context-set, while also claiming historical sequence-pinned
manifests remain valid after re-chaining. The latter contradicts the exact
persisted-record comparison already documented above. Primary symbol/call-name
inspection of both main check-workflow-state files (b4c756) finds no
validate-review-context-set call or identity-ledger/sequence/hash-field access;
their stage-provenance logic is implemented within those files. Do not cite
the agent's wrapper claim or treat it as a passing archival-integration test.
Final candidate workflow-state execution and historical-manifest replay remain
distinct checks; no invocation replay is claimed by the archival recipe.

## Non-conflicting validator delta must be retained and verified

The auto-merged validate-review-context-set SH/PS twins are NOT byte-identical
to main (cdf917): they add positional parsing of annotated Outputs and
Post-Fix Artifacts rows. This is genuine PR code from commit
`9c789bd7cafd4b60662331602081ca3f378bbc27`, not an identity-chain repair.
The exact captured path/hash comparisons remain; annotations exclude pipe
separators. Preserve this delta for candidate verification rather than
overwriting every protected script with main wholesale.

The auto-merged `tests/review-agent-isolation.tests.sh:342`–475 retains
ANNOT-01 through ANNOT-08 fixtures (primary f92d8a): plain and annotated
rows, nested-backtick annotation, forged annotation hash rejection plus
real-hash control, wrong hash, undeclared path and longer-sibling confusion.
These invoke both runtimes when pwsh exists. They exercise implementation
Outputs; do not overstate this inspection as direct coverage of every
Post-Fix Artifacts annotation variant. Run review-agent-isolation and both
template-validator-parity suites on the resolved candidate, together with
the full required gates. Existing tests and commit-message claims have not
been substituted for a current candidate execution or independent verdict.

## 2026-09-08 primary test-conflict containment check

Endpoints remain main `4366438f3b243210a4ece5a17f873ca2d920600a` and
PR245 `54b1ff247081971e0560cf20d45f4369e01b5c0d`. GitHub still reports
PR245 DIRTY (96442d); no merge or protected-file edit occurred.

The workflow-state suite's apparently PR-added history-pin fixtures are
moved content, not missing coverage on main. Primary compared committed
blobs from `PIN_CONTRACT_REL=` through the final
`plugins-pin-multi-add fixture diverged:` assertion: both blocks are 114
lines and byte-identical (d5425a, exit 0). Main begins this block at line
1201. It covers amended contracts, uncommitted contracts, and multiple
introducing commits. The complete zero-context hunk inventory (bfae3b)
contains only this moved block, a four-line placement comment, and removals
of main's other fixtures. Select main's `tests/workflow-state.tests.sh`;
do not duplicate these fixtures or remove main's opening/layer-state tests.
This is content containment, not execution evidence.

For `tests/downstream-review-precheck.tests.ps1`, the endpoint diff has
exactly one hunk: removal of main lines 397–472 (6ba40f; body in 73d7d0).
Those 76 lines test AC coverage, its narrow Global exception, non-vacuity,
and refusal before evidence creation. There is no PR-added case to union.
Select main's file.

For the two `run-panelist-effort` suites, all endpoint hunks were inspected
(73d7d0 and complete hunk inventory 6ba40f). The PR replaces current exact
argv assertions with the superseded `--effort` / `project_doc_max_bytes`
invocation and removes the current argv helpers. Select main's suites,
together with its runner invocation contract, not both contradictory sets.

The complete GPT PowerShell runner endpoint diff (4a2e6f) also confirms
that adopting the PR version removes wrapper rejection, explicit read-only
scratch invocation, balanced/schema-selected JSON extraction, and the
case-sensitive lowercase digest check. These are not resolver additions.
Retain main's GPT PowerShell runner. The previous combined three-runner
output was truncated and is not cited as a complete review of both shell
runners.

Follow-up: both complete shell-runner endpoint diffs were subsequently
read without truncation (Gemini eae47c, GPT c7bdff), together with main's
complete `lib/panelist-common.sh` (0091a5). Their PR-side timeout, required
argument, completion-marker and process-group logic is present in the
shared main helper; it need not be re-inlined. The other deltas restore
superseded invocation/JSON handling or change comments and logging. Select
main's two shell runners, preserving Gemini's `-p` entry point and GPT's
read-only invocation and wrapper rejection. This resolves the earlier
truncated-review limitation for these two files only; it does not claim
that a read-only sandbox alone prevents all reading outside scratch.

Next: finish untruncated precheck containment, then prepare
the exact protected human-application integration package. Historical
ledger replay limitations and the required final candidate tests above
remain in force; none of these selections constitutes a quality-gate PASS.

### Shared precheck helper containment follow-up

At the same exact endpoints, a read-only comparison extracted
`require_persisted_pass` from each PR shell precheck and main's
`lib/review-precheck-common.sh`, removed blank/full-comment lines, and
reported all remaining differences using a line LCS (a41e0f, exit 0).
Against the PR implementation precheck, main adds canonical design/layer
input paths and requires layer manifest hashes when the persisted contract
contains layer hashes; the other difference joins two assignments with a
semicolon. Against the PR task precheck, the only difference is main's
additional `assert_contract_reviewer_agreement` call. The earlier separate
comparison found that agreement helper equal after blank/comment
normalization for the implementation precheck. No missing PR-only helper
behavior was identified by these comparisons. This is static inspection,
not shell execution or a formal verification verdict. Remaining caller
and graph-validation hunks must still be reviewed before finalizing the
four precheck selections.

Execution preference: following the user's latest direction, the primary
agent performs ordinary investigation, fixes and tests directly. Separate
agents are reserved for independently executed reviews required by the
formal workflow; no subagent was launched for this inspection.

### Four precheck conflict selections completed

The full PowerShell endpoint diffs were read without truncation:
task precheck c540e0, implementation precheck 147eef. Select main for both.
The PR implementation version removes reviewer agreement and AC coverage,
drops the explicit opening-round arguments, and relaxes lowercase digest
matching. The task version additionally removes lifecycle-normalized hashes
and frozen-Done-When diagnostics and replaces main's explicit-stack DFS
with its older queue/whole-edge-scan implementation. No resolver-specific
addition in these diffs requires union into main's files.

For the shell callers, a read-only, complete line-LCS comparison omitted
only the two helpers already inspected separately and normalized whitespace,
blank lines and full-comment lines (855761). This exposed all remaining
non-comment differences without the earlier oversized output: main retains
explicit missing-SHA-tool failure, shared hash/helper handling, opening-round
arguments, task lifecycle digest forms, frozen-Done-When diagnostics and
the indexed graph representation. The PR restores older inline hashing and
parallel-array graph state; it has no additional resolver caller path to
preserve. Select main for both shell prechecks. This analysis does not
execute shell code, prove graph performance, or replace regression tests.

Together with the preceding selections, this completes content-selection
analysis of the 23 reported conflict paths at these exact endpoints. The
human application package must enumerate the same conflict set, preserve
the existing uncommitted archive-test repair, stop on changed endpoints or
unexpected worktree changes, retain the original ledger evidence, and verify
the resolved candidate before any commit/push/merge. No protected conflict
has been applied and no formal gate has been marked passed.

GitHub refresh 3d5bec still reports the same six open PR heads, including
PR245 DIRTY; it is a state snapshot, not evidence of live CI execution.

## Human candidate package, 2026-09-08

Created `reports/verification/pr245-human-integrate-20260908.sh` for human
execution only. It pins both remote endpoints, creates a private independent
clone, starts an uncommitted merge, requires exactly the audited 23 conflicts,
applies the selections, saves both original ledgers outside the clone,
re-chains the archival tail, preserves the archive-test repair without
overwriting auto-merged main tests, and checks 24 manifest comparisons.
It stages the candidate only; no commit, push, product test, or main merge
is included. A failed run leaves its private directory available for diagnosis
and never resets or cleans the original recovery checkout.

Primary review found a transcription error in the inherited archive-repair
hash. Direct SHA-256 measurement c94cb9 and a failing pin check 48013a proved
it; the script now pins the actual 64-character hash ending `cec95a`.
The repaired pin check and JavaScript compilation pass (e859d1), and Bash
syntax validation passes (5812c7). These are not end-to-end execution.

The companion `pr245-human-integrate-dry-tests-20260908.cjs` exercises the
embedded integration logic with real committed blobs and an in-memory
filesystem/index adapter. Its first execution (72ea3f) exposed an earlier
report counting error: main has 136 shell registrations, not 135 (ae0ea7;
all end in `.sh`, none duplicated). The corrected union is 145, not 144;
the earlier inventory paragraph above is corrected accordingly. This did
not remove a test or change a merge resolution.

Final simulation 92c26b passes five scenarios: the exact-input candidate,
unexpected conflict, invalid ledger digest, changed repair bytes, and a
symlink destination. The normal scenario validates 23 resolutions, the
repair, 24 mirror comparisons, a 1079-record valid chain, and unique runner
counts 145/100. No protected filesystem file, index or working tree is
modified by this simulation; `merge-tree --write-tree` may add ordinary Git
objects. Its adapter does not exercise clone, shell orchestration, real
filesystem failures, Git staging or product behavior. Those remain unproven
until human application and subsequent candidate verification.
