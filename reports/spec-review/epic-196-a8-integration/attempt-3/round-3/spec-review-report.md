# Specification Review Report: epic-196-a8-integration

- Attempt: 3
- Round: 3 (terminal round of attempt 3; re-invocation after the round-2 remediation; rounds 1 and 2 were both NEEDS_WORK)
- Remediation commits: `78ffa5e2a53114d7f6adca4342f2330d3cd46a23` (requirements.md and acceptance-tests.md, reviewer A's finding), `42e3d0b75fd99cef12bacf3189e9402b5c021969` (deferral of the investigation.md amendment out of the pre-precheck tree), `a7b46d218cb13a839194afdf1009813fe39d3634` (investigation.md, reviewer B's finding, landed inside this round's own window after its precheck and before any reviewer identity was reserved)
- Authorization: 「194/195/196の凍結文書について人間は承認する」(2026-08-23), recorded verbatim and dated in investigation.md; plus the human's 2026-08-24 option-① ruling on reviewer A's `REQ-TESTABILITY` Major, recorded in the same section and explicitly flagged there as the substance of the ruling as relayed rather than as a verbatim transcript string.
- Input hashes: requirements `a240355ad5b237fd6502782423e00497365535272668d79289e48c0473236363`, acceptance tests `4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1`, investigation `2eea3d8020f931986705322596d55cd315971e7e1ed690a1b4100a81be578d57`
- Reviewer A: run `RUN-epic-196-a8-integration-spec-reviewer-a-a3r3-seq789`, host session `SESS-spec-a-epic-196-a8-integration-a3r3-seq789`, ledger sequence 789
- Reviewer B: run `RUN-epic-196-a8-integration-spec-reviewer-b-a3r3-seq790`, host session `SESS-spec-b-epic-196-a8-integration-a3r3-seq790`, ledger sequence 790, manifest adds only the sanitized counts/IDs summary
- Verdict: `PASS`
- Warning count: `0`
- Finding counts: Critical 0, Major 0, Minor 0

Reviewer A: 6 PASS, 0 FAIL, 1 SKIP — declared `PASS`.
Reviewer B: 6 PASS, 0 FAIL, 1 SKIP — declared `PASS`.
Integrated at round 3: `PASS`.

Both `DOMAIN-CONFORMANCE` checks are SKIP for the same, independently reproduced
reason: this repository has no `domain/` directory, so the Approved domain-model
precondition the check requires is absent. Reviewer B reached that conclusion
without seeing reviewer A's report.

## Round-2 findings: both closed

**Reviewer A — `REQ-TESTABILITY`, Major (round 2).** AC-006 had been left out of
the Epic-A1 activation sweep: `requirements.md:307` gave it the same "until Epic A1
merges" trigger AC-015 carries, Main Workflows item 7 grouped "un-skips
AC-006/AC-015/AC-016" together, but the amended Assumptions bullet activated only
AC-015/AC-016, and `acceptance-tests.md:10` still read "named SKIP until Epic A1
merges" with no activation note. Whether AC-006's `SKIP` was hard-failure-enforced
was undetermined.

Closed in `78ffa5e2`. Under the human's option-① ruling, every statement of AC-006's
rule now records that Epic A1's 2026-08-08 merge crossed AC-006's own trigger:
requirements.md's AC-006 bullet, Main Workflows items 2 and 7, the Assumptions
Epic-A1-superseded bullet, and acceptance-tests.md's AC-006 row. The amended text
states that AC-006's substantive claim — the canary case's presence as a named,
mandatory case inside the REQ-001 fixture chain — is live and verified directly by
TEST-006 against this package's own fixture chain, never against Epic A1's
artifacts; that AC-006 carries no "a surviving `SKIP` is a hard failure" clause of
its own, so AC-015's clause is deliberately not copied onto it; and that the
mechanical trigger converting a surviving AC-006 `SKIP` into a non-zero-exit hard
failure is design.md's own two-clause SKIP Allowlist Activation Gate predicate,
whose artifact clause holds as of the merge and whose T-005 task-start clause does
not yet. That is exactly the determination round 2 found missing: the mechanism is
named and machine-checkable rather than absent.

Reviewer A returned `REQ-TESTABILITY` PASS this round.

**Reviewer B — `APPROVAL-BOUNDARY`, Critical (round 2).** `requirements.md:37`
named `ux-spec.md` among the nine per-feature files that now exist, but the
`## Amendment Re-Review Context` section cited it nowhere. The calibration's
evidence bar item 4 is all-or-nothing, so that single uncited artifact voided the
whole declaration and returned the package to the default Phase-1 phase-sequencing
rule.

Closed in `a7b46d21`. The section's "Later-phase artifacts this package references"
list now carries `ux-spec.md`'s creating commit
`7f50a58acfa87b1ee2fb0a548aa626dad66d6d11` and SHA-256
`c4dfe23795970cdcd3e6afe1bb8bd4cd512b14d638040598722c8b13d416e286`. It was checked
against the amended Overview's nine-file inventory that `ux-spec.md` was the only
counted per-feature file the section referenced by bare path alone; the other eight
already carried a commit or a SHA-256 there.

Reviewer B returned `APPROVAL-BOUNDARY` PASS this round and recorded that the
section now meets the full evidence bar.

## Sequencing note (why three commits, not one)

`plugins/sdd-review-loop/scripts/spec-review-precheck.sh`'s `validate_contract`
rebuilds the prior round's expected reviewer-A manifest from that contract's own
requirements/acceptance hashes but from `investigation.md`'s **live** SHA-256. A
round therefore cannot be opened while `investigation.md` differs from what the
prior round's contract pinned. `78ffa5e2` initially carried all three amended
documents together and the round-3 precheck refused with "prior round contract is
malformed or does not require work"; a `bash -x` trace isolated the single
differing manifest entry as `investigation.md` (`883d6045…` pinned versus
`da0160c8…` live). `--reset` to attempt 4 was not an escape either — it requires
the previous attempt's terminal contract verdict to be `PASS` or `BLOCKED`, and
attempt 3 round 2 integrated to `NEEDS_WORK`.

`42e3d0b7` therefore restored `investigation.md` to the round-2-pinned bytes, the
round-3 precheck opened the round against a tree that genuinely matched round 2's
evidence, and `a7b46d21` then landed the amendment inside round 3's own window —
before any reviewer identity was reserved, so this round's manifests pin the
amended bytes. That is the same window every prior Amendment Re-Review Context
entry occupies for itself: an `investigation.md` amendment is pinned by the
reviewer invocation manifests of the round that reviews it, never by that round's
own precheck.

`investigation.md` must not be touched again for the remainder of the
spec → impl → task cascade: `impl-review-precheck.sh:241-243` and
`task-review-precheck.sh:210-213` require the predecessor stage's persisted
contract to pin it at its current SHA-256 in every mode.

## Documents deliberately not amended

`design.md`, `tasks.md`, `traceability.md`, `infra-spec.md`, `frontend-spec.md`
and `security-spec.md` already state the identical AC-006 rule (design.md's SKIP
Allowlist Activation Gate and Risks; tasks.md T-001's Done When and Out of Scope;
infra-spec.md:21, :95, :144-146, :154; frontend-spec.md:47; security-spec.md's B3
Trust Boundary and STRIDE rows). requirements.md and acceptance-tests.md were the
only two documents the earlier activation sweep left behind, so this remediation
brings those two into line with the other six rather than moving the rule.

Disclosed rather than swept: the remaining Epic-A1-conditional phrasings for
AC-015/AC-016/AC-028 (requirements.md's REQ-003 goal text, AC-016, AC-028 and Main
Workflows item 4; acceptance-tests.md's AC-015/AC-016/AC-028 rows) state those
cases' own rule and not AC-006's, were already superseded by the Assumptions bullet
in `4aafb7f6120cd20ba89dd1949a474c264ff3c593`, and were raised by neither round-2
reviewer. Also disclosed: design.md's raw `requirements.md` line citations
(`:283-287`, `:389`, `:536`, `:665-670`) were already stale by roughly twenty lines
before this remediation and drift further; design.md is hash-pinned by the impl
attempt-5 PASS contract and is not amended here.

## Downstream consequence

`requirements.md` moved from `598dcf73…` to `a240355a…`. `check-workflow-state.sh`
hashes `requirements.md` raw for the non-spec stages, so the impl attempt-5 and
task attempt-2 round-3 PASS contracts are stale and both stages require
re-review before this feature's workflow state walks clean.
