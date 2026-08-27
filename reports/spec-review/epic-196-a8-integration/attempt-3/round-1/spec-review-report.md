# Specification Review Report: epic-196-a8-integration

- Attempt: 3
- Round: 1 (opened with `--reset` after attempt 2 round 2's terminal PASS)
- Reset reason: the spec stage's reviewer manifest input hash went stale.
  `specs/epic-196-a8-integration/investigation.md` moved from
  `742c27bbace6767d82863defb5c40606ba9c16d7914b993d5f4ef01841a22184` (pinned by the attempt-2
  round-2 manifests) to `469b26f986577fd253a4649a1e49552dff077334f81149a11402866365afc6f4` when the
  Amendment Re-Review Context entry was extended with `e36a4436f7d12cc368d36e17dcdba04748b4547e` in
  commit `27649768501a2b6e9c78a48ef411d20d4eea8210`. `check-workflow-state.sh` checks that pin
  strictly at the spec stage (its `diagnostic_or_tolerate` tolerance applies only to stages strictly
  downstream of a verified `--opening` slot, and `spec` is the most upstream stage), so the pin can
  only be refreshed by re-reviewing at a new attempt. `requirements.md` also moved
  (`eb1e4c0f…` → `f31c2518…`), but that change is exactly the one-line
  `Spec-Review-Status: Pending` → `Passed` flip the attempt-2 round-2 PASS gate itself wrote, and
  `check-workflow-state.sh` exempts `specs/<feature>/requirements.md` from this per-manifest
  freshness check by design; it is not a body change and did not contribute to the staleness.
- Authorization: the human's frozen-document amendment approval,
  「194/195/196の凍結文書について人間は承認する」(2026-08-23), and the ruling
  「A①B①C①でやれ」(2026-08-24), both recorded verbatim and dated in
  `specs/epic-196-a8-integration/investigation.md`'s `## Amendment Re-Review Context` section.
- Amendment Re-Review Context: verified complete before the precheck and left unextended. Every
  amendment commit through `e36a4436` / `27649768` is present in full with per-document SHA-256
  values, both approvals are quoted verbatim and dated, and every later-phase artifact carries a
  commit reference or fingerprint. No commit was missing, so no extension was made — extending the
  entry would have re-staled the very pins this round exists to refresh.
- Fixed-point procedure: `--reset` makes the precheck re-validate the previous terminal contract
  (attempt 2 round 2, PASS), and that validation rebuilds the expected manifest using the *live*
  `investigation.md` bytes. The prior-pinned `742c27bb…` bytes were therefore restored for the
  duration of the precheck and the current `469b26f9…` bytes restored immediately afterwards,
  before any manifest was built. `git status` confirmed the file returned to its committed state.
- Input hashes: requirements `eb1e4c0fb2b0c2304ebedc1d8d27b1fbec3354f5cde5be4c15436ed599f99476`, acceptance tests `eccb74b87747529947540ff290184b5bc7f3111f49d18252b2f8b1bbc5d872cb`, investigation `469b26f986577fd253a4649a1e49552dff077334f81149a11402866365afc6f4`
- Reviewer A: run `RUN-epic-196-a8-integration-spec-reviewer-a-a3r1-seq785`, host session `SESS-spec-a-epic-196-a8-integration-a3r1-seq785`, identity-ledger sequence 785, allowed input manifest: `specs/epic-196-a8-integration/requirements.md`, `specs/epic-196-a8-integration/acceptance-tests.md`, `specs/epic-196-a8-integration/investigation.md`, `plugins/sdd-review-loop/references/spec-review-calibration.md`, `reports/spec-review/epic-196-a8-integration/attempt-3/round-1/precheck-result.json`
- Reviewer B: run `RUN-epic-196-a8-integration-spec-reviewer-b-a3r1-seq786`, host session `SESS-spec-b-epic-196-a8-integration-a3r1-seq786`, identity-ledger sequence 786, allowed input manifest: same 5 files as Reviewer A plus `reports/spec-review/epic-196-a8-integration/attempt-3/round-1/integrated-summary.json` (sanitized counts/IDs only)
- Verdict: `NEEDS_WORK`
- Warning count: `0`
- Finding counts: Critical 1, Major 1, Minor 0

Reviewer A: 5 PASS, 1 FAIL, 1 SKIP — `REQ-TESTABILITY` FAIL (Critical). Reviewer B: 5 PASS, 1 FAIL,
1 SKIP — `CONTRADICTION` FAIL (Major). Both reviewers ran in fresh isolated contexts; B received
only the sanitized counts-and-IDs summary and never saw A's report.

Both findings are the same structural class the recovery has hit repeatedly: a rule or fact was
amended in one document and its sibling statements elsewhere in the package were left behind. They
are new to this attempt because they concern passages neither prior attempt's findings touched, and
neither rests on phase-sequencing, so the Amendment Re-Review Context suppression does not apply to
either.

- Reviewer A's Critical is a scope conflict over design.md's normative Automated / Manual
  Classification Table: `requirements.md:180` and `:483` scope it to "every check REQ-001 through
  REQ-005 name", while `acceptance-tests.md`'s closing paragraph calls the same table "this
  package's single normative classification source (REQ-007), fixed once and covering every check in
  this document", and that document's own AC-025, AC-026, AC-027, AC-029 and AC-030 rows each cite
  the table for their `Test Type` classification. Whether the table must enumerate the REQ-001–REQ-005
  lineage or all thirty checks is unresolved, which makes AC-025's own "exhaustive … never partial"
  criterion untestable.
- Reviewer B's Major is a stale package-inventory claim: `requirements.md:28-32` states `tasks.md`
  and `traceability.md` "follow in a later phase once this package passes `spec-review-loop`", and
  `investigation.md`'s INV-018 (`:57`) states a `check-sdd-structure.sh` run "is expected to report
  exactly six `missing:` lines (`ux-spec.md`, `frontend-spec.md`, `infra-spec.md`,
  `security-spec.md`, `tasks.md`, `traceability.md`)". The same `investigation.md`'s Amendment
  Re-Review Context cites commit hashes and SHA-256 values proving several of those files exist.

Reviewer B judged that "at most one file (`ux-spec.md`) is actually missing". The orchestrator's
independent check of the repository state is that the finding is broader than B could see from
inside its five-file manifest: all nine of `check-sdd-structure.sh`'s counted per-feature files —
`ux-spec.md` included — are present in `specs/epic-196-a8-integration/`, so the expected count is
zero `missing:` lines, not six and not one. This note records the orchestrator's observation only;
it does not alter B's persisted finding, which stands verbatim as returned.

No status field was changed. `Spec-Review-Status` remains `Pending` for attempt 3, per the loop's
rule that only a validated merged PASS may update it. No finding was waived. Remediation belongs to
a human edit followed by attempt 3 round 2 with an `--edit-summary`; it was not applied inside this
round.
