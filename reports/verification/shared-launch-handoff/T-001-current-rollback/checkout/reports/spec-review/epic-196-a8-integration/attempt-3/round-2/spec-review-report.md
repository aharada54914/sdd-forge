# Specification Review Report: epic-196-a8-integration

- Attempt: 3
- Round: 2 (re-invocation after the round-1 remediation; round 1 was NEEDS_WORK)
- Remediation commit: `fa861f510d5bbd6485a4d21ac209487865876bd0`; Amendment Re-Review Context
  extended with it in `09751348fd0d32a767093afe10836041f2c248ef`, before this round's precheck.
- Authorization: 「194/195/196の凍結文書について人間は承認する」(2026-08-23) and
  「A①B①C①でやれ」(2026-08-24), recorded verbatim and dated in investigation.md.
- Input hashes: requirements `598dcf737dc2544fc81b59e84a0b1ad201ee4201d03edc38ef9f21b068cd29cf`, acceptance tests `0324cdaa476f9657a5380fdfe788d156d62640bd74c409c05e8d4b5b41b074ad`, investigation `883d6045437377b56dee4631b82ebc458365c57a3fcc7704c97925da80845852`
- Reviewer A: run `RUN-epic-196-a8-integration-spec-reviewer-a-a3r2-seq787`, host session `SESS-spec-a-epic-196-a8-integration-a3r2-seq787`, ledger sequence 787
- Reviewer B: run `RUN-epic-196-a8-integration-spec-reviewer-b-a3r2-seq788`, host session `SESS-spec-b-epic-196-a8-integration-a3r2-seq788`, ledger sequence 788, manifest adds only the sanitized counts/IDs summary
- Verdict: `NEEDS_WORK`
- Warning count: `0`
- Finding counts: Critical 1, Major 1, Minor 0

Reviewer A: 5 PASS, 1 FAIL (Major), 1 SKIP — declared `NEEDS_WORK`.
Reviewer B: 5 PASS, 1 FAIL (Critical), 1 SKIP — declared `BLOCKED`.
Integrated at round 2: `NEEDS_WORK` (a round-3 Major or Critical would integrate to `BLOCKED`).

## Round-1 findings: both closed

Neither round-1 finding recurred. Reviewer A's `REQ-TESTABILITY` and reviewer B's
`CONTRADICTION` both returned PASS this round, and B's `ASSUMPTIONS-RESOLVABLE` and
`AMBIGUITY` also passed. The classification-table scope conflict and the stale phase
framing / six-`missing:`-line expectation are resolved.

## Round-2 findings: two fresh, one of them self-inflicted

**Reviewer A — `REQ-TESTABILITY`, Major (pre-existing package defect).** AC-006's
`SKIP` carries the same "until Epic A1 merges" trigger as AC-015 (`requirements.md:307`),
and Main Workflows item 7 (`:689`) groups "un-skips AC-006/AC-015/AC-016" together — but
the amended Assumptions bullet (`:752-755`) activates only AC-015/AC-016 ("AC-015/AC-016's
own un-skip trigger is crossed … activated now"), and AC-028's aggregate gate covers only
AC-015's five live-host cells. `acceptance-tests.md:10` still reads "named SKIP until Epic
A1 merges" with no activation note. Whether AC-006's SKIP is now hard-failure-enforced is
undetermined.

Verified independently: every cited line reads as quoted. This is the same
left-behind-sibling class as the earlier findings — the `e36a4436` discharged-state sweep
and the subsequent Assumptions amendment both propagated the activation rule to AC-015 and
AC-016 and left AC-006 behind. It predates this round's remediation.

**Reviewer B — `APPROVAL-BOUNDARY`, Critical (introduced by this round's own
remediation).** The calibration's Amendment Re-Review Context evidence bar, item 4,
requires a commit reference or SHA-256 for *every* later-phase artifact the entry or the
amended text references, and is explicitly all-or-nothing. The round-1 remediation added a
nine-file list to `requirements.md:37` that names `ux-spec.md` as now existing — and
`ux-spec.md` is cited nowhere in the Amendment Re-Review Context, by commit or by hash.
Verified: the section contains no `ux-spec` string at all. One uncited artifact voids the
whole declaration, which would drop the package back to the default phase-sequencing rule
under which its pervasive later-phase content reads as an unauthorized boundary violation.

This finding is a direct consequence of the fix for round 1's finding B: naming the full
nine-file inventory was what made the package assert a later-phase artifact it had never
fingerprinted. It is narrowly repairable — cite `ux-spec.md`'s commit and SHA-256 in the
amendment entry — but it is recorded here as a fix that carried a new defect, not as a
pre-existing gap.

## Round 3 is the last round

Under the loop's state-transition rule, attempt 3 round 3 with any surviving Major or
Critical integrates to `BLOCKED`; only a Minor-only round 3 can PASS (with
`warningCount > 0`). Both open findings are Major/Critical, so round 3 must clear both or
the attempt terminates BLOCKED and a fourth attempt (`--reset`) is required. No
remediation was applied inside this round, and no finding was waived.

## Recorded consequence of the round-1 remediation

`check-workflow-state.sh:899` hashes `requirements.md` raw for non-spec stages (only the
spec stage calls `normalized_hash`), and the impl attempt-5 round-1 and task attempt-2
round-3 PASS contracts both pin `requirements_sha256 = f31c2518…` — the Passed-state bytes
of the *unamended* body. Measured directly: flipping the status back on the unamended body
reproduced exactly `f31c2518…`, so those pins were satisfiable by the status flip alone
before this remediation and are not satisfiable after it. Both stages will need re-review.

Independently of that, the impl stage was already permanently stale: its attempt-5
manifests pin `investigation.md` at `742c27bb…` while live is `883d6045…`, a divergence
created by commit `27649768` after impl attempt 5 ran, and the spec stage's own
`diagnostic_or_tolerate` tolerance is unavailable to impl without an `--opening` slot. A
clean workflow-state on the spec flip alone was therefore never reachable.

`Spec-Review-Status` remains `Pending`.
