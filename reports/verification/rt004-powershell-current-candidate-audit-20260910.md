# RT004 PowerShell current candidate audit — 2026-09-10

Status: incomplete static review, not application authorization or formal PASS.

Current DATA patch:
`adr-workflow-powershell-history-composed-candidate-20260909.patch`
SHA-256: `9763f14b18310c9f83cd29788c849a3e272608e380f4ff65596d5bf4fe3cbfb1`.
The root reviewer read all 713 patch lines. `git apply --numstat` returned 0,
695 additions / 6 deletions. This proves patch format only: no source
application, PowerShell syntax validation, candidate extraction or execution.

## Coverage observations

The candidate contains explicit ordinal required check sequences, strict raw
JSON member validation, throwing UTF-8 decoding, saved core/manifest/output/
summary binding, and case-exact path/reparse checks. These address the classes
in the human-observed 52 PowerShell failures, but inclusion is not runtime proof.

`tests/impl-review-adr-inputs.tests.sh:296` explicitly excludes PowerShell from
the `late-contract-*` cases: their observer intercepts Bash's real jq call.
Consequently the latest 5/0 late-contract selector proves no PowerShell mutation
rejection. A real PowerShell read-boundary regression remains required; copied
validators or synthesized parser output cannot replace original-path evidence.

## Caller completeness not yet proven

The patch has only three hunks: helper insertion at original line 985,
contract/verdict acquisition at 1024, and reviewer/summary acquisition at 1037.
It does not show later precheck reads, current-input hashing, historical
calibration/investigation reconciliation or stage return/caller control flow.
The returned binding includes parsed Precheck, but the visible caller hunks
consume only Contract, Verdict, ReviewerA, ReviewerB and Summary. Full original
PowerShell source is needed to determine whether later consumers re-open the
originals or already retain verified values. Do not infer a definite bypass
solely from unavailable source context.

Before human application, review all downstream consumers against the verified
snapshot and preserve logical Git identities separately from data reads. Also
retain the explicit non-atomic acquisition warning: before/after path checks do
not prove an atomic no-follow open or immunity to transient substitution.

Independent advisory review of this exact hash was requested from the existing
`/root/rt004_snapshot_static_review` reviewer, under RT004's explicit independent
security/contract-review requirement. It may read the patch and evidence reports
only; no protected-source reread, candidate execution or official verdict change.
The review outcome must be recorded separately when received.

Prior human-supplied full source attachments cover Bash, not this PowerShell
caller. Do not repeat denied source retrieval via another executor. If no
authorized full PowerShell source is available, request a human read-only dump
with before/after hashes rather than sending an unreviewed apply command.

## Independent advisory outcome received

Reviewer `/root/rt004_snapshot_static_review` confirmed the exact candidate
hash and found no definite Critical/Major in the self-contained helper delta.
This is not a whole-candidate approval. The reviewer independently flagged the
missing downstream source context and PowerShell mutation/platform evidence.
Conditional finding: patch lines 207–215 omit risk-gate-matrix.md and
risk-classification-policy.md from the allowed manifest set; establish whether
the governing ADR extension permits these before labeling a false rejection.
Minor: line 696 changes non-impl diagnostics too; preserve the original error
message outside the impl branch. No candidate/source changes were made in this
review, and no formal gate result was issued.

## Conditional allowlist concern resolved

The Bash DATA candidate
`adr-workflow-bash-snapshot-composed-candidate-20260909.patch:242–245`
admits risk-gate-matrix.md and risk-classification-policy.md only when
`$stage == "task"` and `$role == "task-reviewer-b"`. These are not impl
review inputs. The PowerShell helper under review handles impl history, so
their omission is not the alleged impl false rejection. Do not broaden its
allowlist to include them. The ADR documentation DATA candidate at lines
121 and 145 explicitly extends existing input permissions only by the exact
admitted ADR set. This resolves this conditional finding, not the downstream
snapshot continuity or runtime verification gaps. No candidate bytes changed.

## Human PowerShell source received — caller gaps confirmed

The human supplied
`/Users/jrmag/.codex/attachments/9797d8fe-7e59-49ba-8ad3-7261258bafa4/pasted-text.txt`.
Its first and last reported original-source digests both equal
`7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644`.
These are human-reported hashes, not a fresh protected-path hash by this agent.
The source-context blocker is resolved. References below are attachment line
numbers (the leading hash line adds one to original source line numbers).

Two concrete caller gaps now prevent application of candidate 9763f14b:

1. Lines 1320 and 1327 read precheck JSON and hash its live path after the
   candidate already validated its snapshot. Lines 1112–1145 also check and
   hash manifest inputs, including current/previous summaries and precheck,
   from live paths. The candidate returns no snapshot hash map. Route these
   exact evidence identities to saved data/digests; retain live source-input
   freshness checks and original contract path for Git introducing-commit
   lookup. A generic basename match would incorrectly alias previous and
   current summaries and must not be used.
2. Lines 1080–1082 still call Test-ManifestPaths, whose allowlist at 614–670
   includes no ADR paths. An otherwise valid extended impl manifest would
   therefore be rejected after the new helper admitted it. Integrate the
   strict extension-aware path validation without widening legacy/spec/task
   input permissions or dropping their checks.

The task-only precheck read at 1203 is outside this impl snapshot change.
The downstream contract consumers use the retained parsed object, and Git
helpers receive the logical contract path: unlike the Bash defect, the
visible PowerShell caller does not reparse that contract after the snapshot.
The remaining mutation regression must target the actual PowerShell precheck
read/hash boundary, not claim that Bash's jq observer proves this behavior.

No source/candidate application, regression run, PASS, commit, push or merge
was performed for this source audit. Next: revise the DATA candidate's caller
integration, review it independently, then prepare the protected human apply
and original-path regression steps. Preserve the existing 73/52 failure record.

## Caller integration candidate revision

Candidate SHA256:
`ef71d0804613bf8f1cbc97fee4f448fb2cf1e669c71d06424ec41b3da73b1aaa`.
This supersedes candidate 9763f14b for static review only, not its execution status.

- Evidence hashes are retained by full canonical repository-relative path.
  Current and previous summaries cannot alias by basename.
- Legacy previous summaries are captured only when declared in the contract;
  extended rounds after round one continue to require them.
- Extended impl manifests use the helper's strict validation. Legacy impl,
  spec and task manifests retain their existing path validator.
- Downstream impl manifest evidence hashes and precheck data/digest consume
  retained snapshots. Source-input freshness and the logical contract path
  used for Git history remain unchanged.
- The non-impl malformed-evidence diagnostic is restored.

Patch DATA format inspection (`git apply --numstat`, no application) reports
734 additions and 9 deletions. Source-context comparison caught a one-line
hunk offset, which was corrected from 1101 to 1100 before independent review.
Independent static review was requested from the existing RT004 reviewer.
PowerShell runtime, mutation regressions, formal review, CI and main integration
remain unverified. Protected source was not applied or executed by this agent.

Post-correction DATA checks: all seven hunk source contexts match the human
attachment, and all old/new hunk counts match (zero failures). This is not a
PowerShell syntax or execution check.

Independent review preliminary findings (not yet a formal gate verdict):

1. The candidate does not compare current design ADR declarations with the
   retained EntriesJson. The existing downstream design-hash tolerance can
   therefore admit a changed declaration set while opening the spec stage.
   Add the explicit current-declaration comparison before any such tolerance.
2. Current ADR content falls through to the generic live manifest hash path.
   The evidence snapshot safe-path helper does not inspect ADR parent
   components. A linked parent leading to identical content is not rejected
   by that generic leaf check. Require canonical non-reparse parents for ADR
   consumption as well as the content hash.

Application remains withheld pending correction and independent re-review.

## Current declaration and ADR path revision — static re-review

Candidate SHA256:
`2b90cefbbffebb8daeeedc37da23d8b8c7c9dd02e91734588b4697dabbd52791`.
This supersedes ef71d080 for the next verification, not the historical results.
The DATA patch has 839 additions, 9 deletions and seven hunks. Its hunk counts,
offsets and original contexts were checked against the human attachment; this
does not establish PowerShell syntax, runtime compatibility or safe application.

The revision adds an ordinal current-design ADR declaration comparison for
extended impl evidence after the existing own-stage opening return. A changed
declaration set is rejected rather than admitted by downstream stale tolerance.
It also gives live ADR inputs a dedicated full-component safe-path and repeated
hash check; failures cannot fall through to generic stale tolerance. These
checks do not claim atomic no-follow access or protection against ABA races.

The existing independent reviewer `rt004_snapshot_static_review` checked this
exact digest as DATA only and reported that both previous Major findings were
addressed, with no new Critical/Major identified in the limited static review.
This is not a formal gate PASS, runtime result or authorization to weaken tests.

Required execution evidence still includes spec-opening declaration additions
and removals, own-stage opening behavior, legacy evidence, equal-content ADR
parent links, empty and singleton declaration sets, and a PowerShell-specific
snapshot mutation test. PowerShell 5.1/7 and native Windows claims require their
respective real execution evidence. The earlier 73-pass/52-fail result remains
unchanged. No production application, commit, push or merge was performed.

## Current-consumption regression candidate and human handoff

Test DATA patch:
`reports/verification/adr-current-consumption-tests-candidate-20260910.patch`,
SHA256 `5f927cbc1ff7d1bd13f3c0fb15c12c04424b635b68743da9b2899d0cf7344975`.
Adds six modes per runtime without removing prior modes: singleton and empty
current PASS, declaration addition/removal, equal-content parent link, and a
legitimate own-stage opening with consistent NEEDS_WORK evidence. Current
negative cases require the singleton and legacy positive controls to succeed.
The two original validator paths remain the execution targets.

The existing independent reviewer found no Critical/Major in the limited test
DATA review. Its Minor about broad diagnostic matching was addressed by
printing each current case's runtime, mode and actual validator log before
the unchanged outcome check; the exact updated digest was independently
rechecked. This preserves concrete diagnostics for human assessment rather
than asserting that any ADR-related error proves the intended branch.

Static DATA checks: 13 hunk contexts/counts/new offsets match current test
source, zero errors; numstat is 112 additions/5 deletions. No candidate was
applied, extracted or executed by the agent. The 14 current-selector outcomes
and all previous tests remain unmeasured for the candidate.

Human instructions are in
`reports/verification/rt004-current-consumption-human-steps-20260910.md`.
They bind original and candidate hashes, validate exact patch targets, preserve
backups and pre-existing diff, measure before/after, retain full logs and run
related suites. They do not change review verdicts or commit/push/merge. The
PowerShell-specific snapshot mutation and native Windows evidence remain
separate outstanding requirements even if this sequence passes.

GitHub read-only recheck in this continuation: 11 open PRs, no active CheckRun
on their heads. Required-check failures remain on 404/402/401/394/390/381/371;
405/403/245 are DIRTY, and 400 is BLOCKED. Absence of a failed check on these
other PRs is not proof of complete required CI or review readiness.
