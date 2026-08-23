# Manual Precheck Note: epic-193-a5-capability-resolver / attempt 3 / round 1

Date: 2026-08-23T22:42:12Z

## Deviation

The automated reset command
`spec-review-precheck.sh epic-193-a5-capability-resolver 3 1 --reset` stopped
before creating the round with `previous terminal contract is invalid`.
Attempt 2 has a persisted terminal PASS verdict and contract, but its own
`precheck-result.json` records `requirements_sha256:
c7cfbe1a5b8fc34bd7df3acffbaf0f7f33a33a327784a8579110897832574547` — the
pre-reset (`Spec-Review-Status: Passed`) bytes — while the contract and both
reviewer manifests pin
`d0e66eaff2344b4f1f4edb9093dc45755630d74786bc5f66faa4ed767d5a7c6c`, the
post-reset (`Pending`) bytes the reviewers actually reviewed (verified: the
`Pending`-substituted variant of the committed `Passed` bytes hashes to
exactly the contract value). That is the pre-`7e0c1598` precheck defect shape
("recompute input hashes after --reset status mutation", PR #209) frozen into
attempt-2's evidence, which today's shipped validator rejects. The
attempt-2 evidence is retained unchanged (its precheck-result bytes are
pinned by both reviewer manifests, so correcting it is structurally
impossible); no gate finding is waived. Precedent:
`reports/spec-review/epic-136-phase2-gates/attempt-2/round-1/manual-precheck-note.md`
(the issue-#61 manual-precheck fallback).

## Authorization

The human ruled, dated 2026-08-24: 「A①B①C①でやれ」 (following the standing
2026-08-23 「194/195/196の凍結文書について人間は承認する」 approval family),
directing spec re-review of the A①/B① frozen-document amendments at the next
attempt via the reset lane. The automated reset is structurally impossible
against attempt-2's legacy evidence shape, so this narrowly scoped manual
precheck performs the identical validations and transitions by hand.
Independent blind reviewers, identity reservations, deterministic
validation, and all quality decisions remain mandatory and unmodified.

## Manual checks performed

- Feature slug, attempt 3, round 1, `--reset` shape (attempt N+1, round 1)
  checked directly; `requirements.md`/`acceptance-tests.md` exist and are
  regular files.
- Non-replay destination: `attempt-3/` did not exist before this note's
  round directory was created.
- Attempt 2 contains a terminal PASS `integrated-verdict.json` and
  `spec-review-contract.json`; both are retained unchanged. Its
  requirements/acceptance pins were additionally cross-checked against git
  history as described above; `acceptance_sha256` and the investigation.md
  manifest pin verify cleanly against the pre-amendment bytes
  (`581cc5e9…`, `4b63f379…`).
- `Spec-Review-Status` was restored to `Pending` as the reset transition
  (`sed` on the status line only), and `requirements_sha256`/`input_sha256`
  in `precheck-result.json` were computed from the post-reset bytes — the
  bytes reviewers will actually see — per `7e0c1598`'s recompute rule.
- Current requirements, acceptance, calibration
  (`plugins/sdd-review-loop/references/spec-review-calibration.md`, which
  now includes the `## Amendment Re-Review Context` lane cherry-picked as
  `3bdedf98`/`b906d143`), and composite hashes are recorded in
  `precheck-result.json` beside this note.
- The shared portable foundation was exercised for real:
  `review-contract-validate.sh --feature epic-193-a5-capability-resolver
  --attempt 3 --round 1 --stage spec` against the canonical composite-input
  stub contract returned verdict PASS, exit 0.
- Reviewer identities will be reserved sequentially in the canonical
  identity ledger via `validate-review-context-set.sh --reserve`
  immediately before their fresh isolated launches.

## Result

Manual precheck passed under the narrowly scoped legacy-evidence fallback
documented above.
