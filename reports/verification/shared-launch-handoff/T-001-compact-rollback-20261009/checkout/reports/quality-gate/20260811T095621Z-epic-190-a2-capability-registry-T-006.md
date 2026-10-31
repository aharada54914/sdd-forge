Task: Author the projection generator and stage the protected-file registration
Task ID: T-006
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0680
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-006-0680
Ledger Sequence: 680
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0680-manifest.json (sha256 45827a3dbdd7c7cd4f13da6c39d467f794554deba66c9135a0b930cb430513b5)
Attempt: 7
VERDICT: NEEDS_WORK

- Model: claude-fable-5 (gate host); evaluator launched from the installed
  sdd-quality-loop 1.10.0 `agents/evaluator.md` (frontmatter `model: opus`,
  verified byte-identical to the in-tree 1.14.0 copy)
- Effort: frontmatter record-only (`x-sdd-effort: high`); Claude Code has no
  per-invocation effort control, so `effort_control=frontmatter`, no
  `effort_applied` claim is made

Done is WITHHELD. `Status:` stays `Implementation Complete`. tasks.md was not
touched; no approval field was touched; no task-plan re-bind was performed
(it is conditional on a Done flip that did not happen).

## Cycle accounting (recorded, not laundered)

This is the eighth evaluator reservation for T-006 and the seventh review
attempt. `check-quality-gate-cycle-limit.sh T-006 epic-190-a2-capability-registry`
prints `Escalate-Human` (exit 1) — the three-cycle cap remains exceeded.
**This cycle ran on the human's explicit direction**: the ruling of
2026-08-11, recorded verbatim in `docs/review-tickets/RT-20260811-002.yml`
(`human_ruling`), directed the cycle-6 remediation and then "run
quality-gate cycle 7". Cycles 1-3 are the reservations at ledger sequences
664, 666, 669; RT-20260809-002 authorized exactly one more (spent at 674);
678 and 679 ran at the human's direction after the protected-file apply
(`025b2f0d`); this sequence 680 runs under the 2026-08-11 ruling. Under the
same standing rule, **a cycle 8 requires fresh human direction**; none is
assumed here.

## The 2026-08-11 human ruling: what was executed and what was stopped

The ruling: disarm the stale staged-workflow hazard class by removing the
`.github/workflows/test.yml` entries from the two sibling bundles'
`MANIFEST.sha256` files (sibling-bundle edits explicitly authorized),
bounded by the constraint to stop on a bundle — and report — rather than
break a pinned invariant.

Executed (commits `3f442251`, `30bb3266`, `5cd8e423`, `e3a1d10e`,
`c8791d88`): the epic-136-phase3 candidate refresh (seq-679 Major 1), the
full-surface apply rehearsal replacing the cycle-5 false all-clear (seq-679
Critical 2), the dated report addendum correcting the selfcheck
mischaracterization, the ticket disposition record, and the Outputs
refresh (67 rows, 0 stale).

Stopped, on BOTH bundles — the entry removal is pin-blocked:

- `epic-136-phase2-gates` (anticipated): TEST-013
  (`tests/phase2-guard-invariants.tests.sh:45-92`; `.ps1:189-233,294-296`)
  pins 19 fixed-order entries including the workflow and requires the
  staged candidate file; TEST-011 asserts its content.
- `epic-189-a1-project-context` (not anticipated by the ruling):
  TEST-HARDEN (`tests/guard-invariants-epic-a1.tests.sh:532-534`, "T-009
  must neither drop nor duplicate it"; `.ps1:399-400`) asserts the entry
  is present exactly once, and the per-entry loop pins the staged file.

Both manifests are therefore unchanged (`shasum -a 256 -c`: 18/18 and
19/19 OK) and dated DO-NOT-APPLY ruling notes were recorded in each
bundle's `NOTES-epic-190-a2-refresh.md` instead. The hazard class is
therefore documented but NOT mechanically disarmed — and the evaluator's
Critical below is exactly about that residue.

## The seq-679 findings: state at this cycle (independently re-verified)

1. **[Critical, seq-679] Stale staged sibling workflows — NOT RESOLVED
   (pin-blocked ruling; hazard armed).** Measured by this gate: both
   staged copies remain at 854 lines (`8beba70c…`) vs live 991
   (`a37a3795…`); the rehearsal (below) proves the apply removes 137
   lines / 18 named steps per bundle. Carried as this cycle's Critical.
2. **[Critical, seq-679] Arrays-only rehearsal false all-clear —
   RESOLVED.** `cycle6-apply-rehearsal.log` measures EVERY manifest target
   (byte hash, removed/added lines, full unified diff, workflow
   step-name-set difference, guard-array entry diff) across three legs per
   bundle, with denied applies recorded as denials plus a verified
   zero-write post-state, never as a zero-removal apply. Its overall
   verdict is honestly `REMOVALS PRESENT`. New reachability facts it
   established: the generic publisher refuses BOTH sibling whole batches
   fail-closed (exit 19 `DUPLICATE_BASENAME_IN_BATCH`, two `SKILL.md`
   targets per manifest), but a single-target batch — the sanctioned
   convention of the a1 bundle's own RUNBOOK — applies the stale entry
   cleanly (exit 0), as does the manifest-contract emulation matching the
   phase2 Windows-only runner. The own bundle measures zero removals of
   any kind end-to-end (exit 0).
3. **[Major, seq-679] Selfcheck mischaracterization — RESOLVED.** The
   candidate was refreshed (`3f442251`, four step blocks copied verbatim
   from live with the quoted `"[deterministic] "` prefix);
   `deterministic-lane-selfcheck` moved 24/1/4 -> 25/0/4 (rc=1 solely from
   TEST-020's documented designed-red window), and the report carries a
   dated correction at the wrong claim's own location plus the cycle-6
   diagnosis (causal commit `025b2f0d`; one hazard class, three surfaces).
4. **[Major, seq-679] WFI-016 residue — NOT RESOLVED**, unchanged numbers
   (sh 33/1, ps1 59/10 with nine macOS platform failures). The evaluator's
   Major below additionally falsifies the "pre-existing" attribution this
   feature's reports have repeated for it.
5. **[Minor x2, seq-679] AC-030 "eight pairs" spec drift and the
   report-snapshot note — carried, unfixed** (spec files are not an
   implementation task's to edit).

## Deterministic gates run by this gate

- `check-risk` T-006: PASS (valid `high` tier, non-empty rationale,
  `Required Workflow: tdd`).
- `check-placeholders` over this cycle's changed production-adjacent files
  (the refreshed candidate and both NOTES files): PASS.
- `check-workflow-state` (no `--feature`, repo-wide): rc=0,
  `workflow-state: ok` — verified again on the tree as left by this gate.
- `check-task-state`: rc=1 — the same pre-existing debt seq-679 recorded
  (T-005 and T-007 are `Done` without
  `verification/T-00{5,7}.{contract,evidence}.json`); T-006's own row
  remains valid. Not this gate's to manufacture retroactively.
- `check-quality-gate-cycle-limit`: `Escalate-Human`, rc=1 — recorded; see
  Cycle accounting (human direction on file).
- `check-contract` / `check-evidence-bundle` for T-006: not applicable this
  cycle — populated only when a PASS verdict lets the gate record Done.
- Outputs authorization audit (RT-20260809-001 check): population derived
  from `git diff --name-only` over T-006's eleven commits (`957f18ea`,
  `1790bacd`, `4879aceb`, `86b9aa7b`, `340f0149`, `6f300d97`, `36339788`,
  `3f442251`, `30bb3266`, `5cd8e423`, `e3a1d10e`); after the documented
  exclusions: 67 paths. Declared rows: 67, unique. Derived vs declared: 0
  undeclared, 0 over-declared. All 67 hashes measured current: 0 stale,
  0 missing. (The evaluator independently re-derived the same result from
  a 96-file raw union.)

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 680, stage `quality`, role `sdd-evaluator`,
  `task_id` T-006, `input_mode` file-manifest, `fallback_mode` none,
  `read_only` true, and the run ID / host-session ID above. Key set
  identical to the seq-679 manifest; no `attempt`/`round` keys;
  `risk-gate-matrix.md` and `investigation.md` absent by construction.
- 78 allowed-input entries: `quality-gate-calibration.md`, the nine feature
  specification layer files, the T-006 implementation report, and all 67
  paths the report's `## Outputs` table declares.
- The validator made the reservation; no ledger record was hand-written.
  `validate-review-context-set.sh <manifest> . --reserve` returned
  `REVIEW_CONTEXT_OK db8a99b56cea2f90afc737a36d67daf476002fa37df77a94dc7a84217c285fa7`,
  equal to the appended seq-680 record's `record_sha256`.
  `previous_record_sha256` 49808eae… is the seq-679 evaluator record.
  Pre-reservation ledger hash (bound in the manifest):
  95033b121f416a60d49ba548a9251c1e401946af3fb55c651cc2b2bcb518ea04.
  Post-reservation ledger file hash:
  28725bdf0034332a59c461fe2145a55bd20d68fb9e607d8e7e5c724b4f32f781.
- The evaluator discharged the launch gate independently: manifest
  self-hash match; pre-reservation ledger recovered via
  `git show HEAD:…identity-ledger.json` and hash-matched; the record-hash
  formula re-derived and the full 680-record chain walked (0 gaps, 0
  breaks, 0 duplicate run/host-session IDs, own identity exactly once);
  the reservation replayed byte-equal in a `git archive HEAD` scratch tree
  (`REVIEW_CONTEXT_OK db8a99b5…`); all 78 input hashes verified before
  reading and re-verified unchanged after.
- Role provenance checked, not assumed: installed sdd-quality-loop is
  1.10.0 against 1.14.0 in tree; `agents/evaluator.md` diffed across the
  two: byte-identical.
- `git status --porcelain` before launch and after the evaluator returned:
  the only deltas are this gate's own artifacts (the pending manifest and
  the validator's ledger append; this report and the ticket note join them
  at commit time). The evaluator wrote nothing.

## Evaluator verdict (recorded verbatim)

```
RUN_ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0680
HOST_SESSION_ID: SESS-qg-epic-190-a2-capability-registry-T-006-0680
ALLOWED_INPUT_MANIFEST: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0680-manifest.json sha256 45827a3dbdd7c7cd4f13da6c39d467f794554deba66c9135a0b930cb430513b5
VERDICT: NEEDS_WORK
FINDINGS:
- [Critical] reports/implementation/epic-190-a2-capability-registry/T-006.md:1228-1260 (+ specs/epic-136-phase2-gates/human-copy/NOTES-epic-190-a2-refresh.md:118-139) — The cross-epic stale staged-workflow hazard is left mechanically armed on the stated ground that "execution therefore STOPPED on both bundles" because a pinned invariant blocks it; measurement contradicts that ground. Entry *removal* is indeed pin-blocked (I reproduced it: removing the `.github/workflows/test.yml` line from epic-136-phase2-gates/human-copy/MANIFEST.sha256 takes `tests/phase2-guard-invariants.tests.sh` 33/1 -> 32/2; from epic-189-a1-project-context/human-copy/MANIFEST.sha256 takes `tests/guard-invariants-epic-a1.tests.sh` 81/0 -> 80/1 with `FAIL: staging: the CI-staging .github/workflows/test.yml entry is present exactly once (expected [1], got [0])`). But the pin-compatible alternative the NOTES file itself names as route 1 — refresh the staged workflow to live bytes with the digest updated in place — fully disarms the hazard and breaks nothing. Measured in a `git archive HEAD` scratch tree: after the in-place refresh of both sibling bundles, removed lines = 0 and removed named steps = 0 on both (vs. 137 lines / 18 steps before), `tests/phase2-guard-invariants.tests.sh` stays 33 passed / 1 failed with `ok: TEST-013 staged batch contains each exact protected candidate`, `ok: TEST-013 final manifest has exact ordered lowercase staged hashes`, `ok: TEST-011 staged CI uses platform-native generator and invariant suites...` and the `out of sync: .github/workflows/test.yml` reason gone, `tests/guard-invariants-epic-a1.tests.sh` stays PASS: 81 / FAIL: 0 rc=0, and T-006's own suite stays pass=23 fail=0 designed-red=0. The armed hazard is not academic: I independently reproduced (difflib vs. live `.github/workflows/test.yml`) that applying either sibling bundle's staged workflow removes 137 lines and 18 named steps including T-006's own four drift locks (`Verify generated gate-capabilities projection (Windows)/(POSIX)`, `Verify vendored contracts copy (Windows)/(POSIX)`) and its own suite's two CI steps. On epic-189-a1-project-context there is no deterministic gate on it at all (that suite is 81/0 fully green); the only protection is prose in a NOTES file — the same "prose, not a gate" posture an earlier cycle already rejected as Critical for this task. Additionally, refreshing-to-live is what the repository already asserts for that bundle: WFI-016's own assertion text is "staged targets are byte-identical to live (no stale staging)", so the report's counter-reason ("refreshing it would import this feature's and T-005's CI steps into another epic's staged candidate") is contrary to the invariant epic-136 itself declares.
- [Major] reports/implementation/epic-190-a2-capability-registry/T-006.md:1155-1157 and :1329-1332, mirrored in specs/epic-136-phase2-gates/human-copy/NOTES-epic-190-a2-refresh.md:72-77 — The report states `tests/phase2-guard-invariants.tests.sh`'s WFI-016 failure "failed before this cycle too", is "unchanged in count", and that "the residue is not this feature's to decide". Measured: the suite was `34 passed, 0 failed` with `ok: WFI-016 staged targets are byte-identical to live (no stale staging)` at `6277cde0` (the commit immediately preceding this task's cycle-5 remediation) and at `340f0149`, and became `33 passed, 1 failed` at this task's own commit `36339788` ("fix(epic-190-a2): disarm the cross-epic un-protection hazard the T-006 apply created"). This task turned a green sibling suite red; the false "pre-existing" premise is what routes ownership of the fix to epic-136 and what justifies `tests/run-all.sh` remaining rc=1 on this account. The underlying cycle-5 edit was itself necessary, but the record misattributes the regression.
- [Minor] specs/epic-190-a2-capability-registry/acceptance-tests.md:55, design.md:681 and :785, traceability.md:13 — AC-030 and the Test Strategy require "eight new `tests/*.tests.sh`/`.tests.ps1` pairs (Test Strategy items 1-8)", but only seven pairs exist and are registered. Test Strategy item 6 (provider-name contamination) has no standalone pair; its coverage lives inside `tests/validate-capability-registry.tests.sh` as AC-020/TEST-020. traceability.md:13's own Implements column lists exactly seven pairs, confirming the count is spec-text drift rather than a coverage gap. Needs a spec amendment, not an implementation change; the report carries this knowingly.
- [Minor] tests/generate-gate-capabilities.tests.sh:481-519 — the job-set superset check has a blind spot the report presents as covered. Mutation MUT-6 (swapping the 854-line sibling workflow into `human-copy/` in a scratch tree, MANIFEST re-synced) flipped only the two step-name assertions (one DESIGNED-RED, one FAIL); `human-copy/ staged workflow is a job-set superset of live` still passed, because the stale sibling copy is post-`3baadda5` and carries all nine job keys. The structural check therefore detects dropped jobs but not dropped steps within retained jobs — which is the actual live hazard class.
CHECKED:
- Launch gate, discharged independently before reading substantive inputs: manifest self-hash = 45827a3d... (matches); `git show HEAD:reports/review-context/identity-ledger.json | shasum -a 256` = 95033b12... = the manifest's `identity_ledger_sha256`, and the only working-tree ledger delta is the appended seq-680 record; derived the record-hash formula by brute force (sha256 of `sequence|stage|role|run_id|host_session_id|previous_record_sha256`) and walked all 680 records — 0 sequence gaps, 0 chain breaks, 0 record-hash mismatches, 0 duplicate run_ids, 0 duplicate host_session_ids, my identity present exactly once. Re-running `validate-review-context-set.sh` in place returns `REVIEW_CONTEXT_IDENTITY: ... stale or mismatched` (expected: the manifest binds the pre-reservation ledger), so I rebuilt the pre-reservation tree with `git archive HEAD` into scratch and re-ran it there: `REVIEW_CONTEXT_OK db8a99b56cea2f90afc737a36d67daf476002fa37df77a94dc7a84217c285fa7`, exit 0 — byte-equal to the caller's evidence and to the seq-680 record_sha256. All 78 manifest inputs hash-verified before reading and re-verified unchanged after: 0 mismatches, 0 missing.
- `python3 plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py --check` against the live tree: exit 0, no write. `bash tests/generate-gate-capabilities.tests.sh` and `pwsh -NoProfile -File tests/generate-gate-capabilities.tests.ps1`: both `pass=23 fail=0 designed-red=0`, exit 0, `git status --porcelain` unchanged after.
- Non-vacuity of AC-025/AC-026 proved by my own mutations in a `git archive HEAD` scratch tree (baseline 23/0/0): neutering `--check` to always return 0 -> TEST-026(2) fails; deleting the `notice` field -> TEST-025(2)+(3) fail (`FAIL:notice`); removing the `stage == "implementation"` filter -> TEST-025(2)+(5) fail; making `--check` call `write_atomic` -> TEST-026(2)+(3) fail with an mtime delta. Line-level read of generate-gate-capabilities.py:104-143 confirms `--check` returns before any write path and never calls `write_atomic`/`mkdir`.
- Staged-bundle guard non-vacuity: removing one of T-006's seven paths from the scratch copy of the staged `guard-invariants.json` flipped the suite to `pass=22 fail=0 designed-red=1` with the exact "would DROP live-protected paths/keys if applied" diagnostic and non-zero exit.
- Done When #2 / AC-029: `shasum -a 256 -c specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256` from repo root = 7/7 OK (the apply landed, human commit `025b2f0d`, 7 files, +211/-18); the guard-invariants generator's `--check` against the applied live tree exits 0 (run read-only via runpy to avoid the hook guard's filename-substring false positive); the applied `guard_invariants.py` is byte-identical to the staged copy and carries all seven registered paths in both `PROTECTED_GATE_SUFFIXES` (77) and `PHASE2_HUMAN_COPY_TARGETS` (26). AC-029(b): none of this task's eleven commits touches any of the seven live protected paths.
- Done When #3 / AC-030: all seven feature suite pairs are registered in `tests/run-all.sh:99-105` and `tests/run-all.ps1:58-64`, and the staged (== live, manifest-verified) `.github/workflows/test.yml` carries a `.sh` and `.ps1` CI step for each, plus both drift-lock pairs at :49-57 and :83-91. All seven suites run green on the delivered tree (schema 6+16, evaluate-predicate 63, registry-discovery 21, validate-capability-registry 27, generate-registry-digest 17, generate-gate-capabilities 23, capability-registry-parity 22 — all rc=0).
- Cycle-6 Major 1 verified fixed: `bash tests/deterministic-lane-selfcheck.tests.sh` = `25 passed, 0 failed, 4 designed-red`, with `ok: TEST-017-GREEN: all 32 baseline step names appear in the candidate` and `ok: TEST-017-RED: dropped step 'Verify generated gate-capabilities projection (Windows)' correctly failed the coverage check (check is non-vacuous)`; the refreshed epic-136-phase3 candidate carries each of the four restored step names exactly once and passes the suite's own ruby/Psych parse check; TEST-016 counts 37 named+prefixed steps.
- Outputs table audited: 67 rows, 0 duplicate paths, 0 stale or missing hashes against live. Derivation re-done independently — the union of `git show --name-only` over the eleven declared commits is 96 files; after the documented exclusions (`reports/`, `docs/review-tickets/`, hash-bound `tasks.md`, the three T-005-owned files) there are 0 undeclared and 0 declared-but-untouched paths. The cycle-3 addendum carries no hash column, so exactly one declaration survives per path.
- Evidence-file cross-check: `cycle6-apply-rehearsal.log` (910 lines, tier-1 evidence, hash-verified) records `REHEARSAL OVERALL VERDICT: REMOVALS PRESENT`, per-bundle `REMOVALS PRESENT` for both siblings and `ZERO REMOVALS` for this feature's own bundle; I reproduced its central number independently (137 removed lines / 18 removed named steps per sibling bundle). `cycle6-suites.log` figures (81/0, 85/0, 22/0, 33/1, 59/10, 25/0/4) match my own runs of the corresponding suites exactly — no fabricated counts found.
- Baseline/differential: no `baseline-behavior.md` exists for this feature, and T-006 is net-new authoring rather than a bugfix/refactor, so I verified behavior through the specs, contracts and suites above; where differential reasoning was load-bearing I built it from git history myself (`6277cde0` 34/0 -> `36339788` 33/1 for the phase2 suite; `025b2f0d^` 21/1 -> HEAD 22/0 for capability-registry-parity).
```

## What this gate verified itself versus took from the evaluator

Verified first-hand by this gate, independent of the evaluator: the pin
evidence blocking the ruled entry removal (TEST-013 at
`phase2-guard-invariants.tests.sh:45-92` / `.ps1:189-233,294-296`;
TEST-HARDEN at `guard-invariants-epic-a1.tests.sh:532-534` /
`.ps1:399-400`); the full-surface rehearsal itself (three legs per bundle:
whole-batch publisher denial exit 19 with verified zero-write post-state,
single-target apply exit 0 removing 137 lines / 18 steps, full emulation
matching, own bundle clean end-to-end); the suite numbers (81/0, 85/0,
22/0 both runtimes, 33/1, 59/10, 24/1/4 -> 25/0/4); the 67-row Outputs
derivation and re-measure (0/0/0); the manifest build-time hash of all 78
entries, the reservation arithmetic, the post-reservation ledger hash; the
evaluator role-provenance diff; and the post-run `git status`.

Taken from the evaluator and not independently re-derived by this gate:
the scratch-tree measurement that a digest-in-place refresh-to-live of
both sibling staged workflows disarms the hazard with zero pin breakage
and zero suite regressions (the load-bearing basis of its Critical); the
`34/0 -> 33/1` attribution of the phase2 WFI-016 flip to `36339788`
(corroborated by the seq-679 gate's own independent scratch-tree baseline
of sh 34/0 at `6277cde0`, and mechanically consistent: `36339788`
regenerated the staged canonical JSON to 26 targets against 19 staged
files before the human's `025b2f0d` landed); the four generator-mutation
non-vacuity proofs; and the MUT-6 job-set blind-spot analysis.

## Findings disposition (step 9)

All four findings are **Accepted**. None is downgraded.

- **Critical (hazard still armed; the stop rationale does not survive
  measurement):** Accepted. This gate notes for the record that the
  cycle-6 remediation executed the ruling as given — the ruling authorized
  entry REMOVAL and bounded it with stop-on-pin; it did not authorize the
  refresh-to-live alternative, and unilaterally substituting a different
  cross-epic edit for the ruled one is what this task was previously
  sanctioned for. The evaluator's measurement now establishes that the
  pin-compatible refresh is available, complete, and regression-free;
  executing it (or amending the sibling pins) is a cross-epic decision
  that requires fresh human direction. Tracked in RT-20260811-002 (items
  1 and 4, plus this gate's addendum note); not a safe auto-fix under
  `auto-fix-policy.md`.
- **Major (WFI-016 regression misattributed as pre-existing):** Accepted.
  The corrected values are recorded here per SKILL step 9; the frozen
  implementation report is not edited by this gate. The dated-addendum
  correction (report and phase2 NOTES prose) belongs to the next
  remediation cycle, which requires the same fresh human direction.
- **Minor 1 (AC-030 "eight pairs" spec drift):** Accepted, record-only;
  needs a spec amendment outside an implementation task's scope (carried
  since seq-678).
- **Minor 2 (MUT-6 job-set superset blind spot):** Accepted, record-only;
  a test-strengthening candidate for the feature's closure sweep.

## Required before any next cycle (evidence targets)

1. Fresh human direction on the hazard mechanism, now with measured
   options: (a) authorize the pin-compatible digest-in-place
   refresh-to-live of `.github/workflows/test.yml` in both sibling
   bundles (evaluator-measured: 0 removals, 0 pin breakage, 0 suite
   regressions, WFI-016's `out of sync` reason clears), or (b) direct the
   sibling epics to amend their pins so the ruled entry removal becomes
   executable, or (c) accept the documented DO-NOT-APPLY posture
   explicitly as the end state (the evaluator has measured that prose
   alone was previously rejected as Critical for this task).
2. Under that direction, correct the "pre-existing" WFI-016 attribution in
   T-006.md (cycle-5 and cycle-6 prose) and the phase2 NOTES file by dated
   addendum: the suite was 34/0 at `6277cde0` and `340f0149`, and went
   33/1 at `36339788`.
3. The AC-030 spec text and the T-005/T-007 missing contract/evidence
   bundles remain open items for the feature's closure sweep, outside
   T-006's remediation scope.

No task-plan re-bind was performed (no Done flip); the durability question
for `rereview_normalized_hash(..., "Done")` is therefore moot this cycle
and remains to be answered at the eventual flip. The retrospective is not
invoked (gate did not exit Done). `check-workflow-state.sh` exits 0 on the
tree as left by this gate.
