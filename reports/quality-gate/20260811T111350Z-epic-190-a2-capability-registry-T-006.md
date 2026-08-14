Task: Author the projection generator and stage the protected-file registration
Task ID: T-006
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0681
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-006-0681
Ledger Sequence: 681
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0681-manifest.json (sha256 72288b231f1f5352fd39578905f4ef5473bbe26fdb621965b8da0ac3f60d6498)
Attempt: 8
VERDICT: PASS
Critical: 0
Major: 0
Minor: 3

- Model: claude-fable-5 (gate host); evaluator launched from the installed
  sdd-quality-loop 1.10.0 `agents/evaluator.md` (verified byte-identical to
  the in-tree copy, sha256 prefix fa173e289d332112 on both)
- Effort: frontmatter record-only (`x-sdd-effort: high`); Claude Code has no
  per-invocation effort control, so `effort_control=frontmatter`, no
  `effort_applied` claim is made

Done is RECORDED. `Status:` flips `Implementation Complete` -> `Done` for
T-006 in tasks.md — the Status line is the only tasks.md edit; no approval
field was touched by this gate. The task-plan re-bind that this flip
necessitates (the attempt-6 binding recorded the raw bytes of a
status-mixed plan and its own contract predicted it would go stale on this
flip) is executed as attempt-7 and recorded below.

## Cycle accounting (recorded, not laundered)

This is the ninth evaluator reservation for T-006 and the eighth review
attempt. `check-quality-gate-cycle-limit.sh T-006 epic-190-a2-capability-registry`
prints `Escalate-Human` (exit 1) — the three-cycle cap remains exceeded.
**This cycle ran on the human's explicit direction, under ruling (b)**: after
the seq-0680 gate presented the three measured options for the stale
staged-workflow hazard, the human ruled option (b) DIRECTLY — amend the
sibling epics' pins so the shared-file snapshot is evicted from per-epic
bundles entirely (the class fix, not the instance fix), explicitly accepting
that this feature's completion waits on it, with the cross-epic edits
human-authorized and quality-gate cycle 8 run on the same direction. The
ruling and its execution are recorded in
`docs/review-tickets/RT-20260811-002.yml` (`human_ruling_2`,
`disposition_2`) and in the T-006 implementation report's "Quality-gate
cycle 7 remediation (2026-08-11, gate seq0680)" section. Prior reservations:
664, 666, 669 (cycles 1-3), 674 (RT-20260809-002's one authorized extra),
678, 679, 680 (human-directed), and this 681.

## The 2026-08-11 ruling (b): what was executed before this cycle

Commits `7f02df24`, `c8ac93a2`, `3ad767ad`, `da667fc0`, `321804e2`:

- Both sibling bundles' `.github/workflows/test.yml` snapshots EVICTED:
  manifest entries removed (epic-136-phase2-gates 19 -> 18, 18/18 OK;
  epic-189-a1-project-context 18 -> 17, 17/17 OK), staged files deleted.
- The pinning assertions amended in step, sh/ps1 twins together: phase2
  TEST-013 pins the 18-entry inventory plus a new class lock asserting
  ABSENCE of the snapshot (staged file and manifest entry); TEST-011
  retargeted to the LIVE workflow; WFI-016 iterates the bundle's own
  staging inventory instead of the now-repository-wide registry (the
  RT-20260811-002 item-4 semantics decision). a1 TEST-HARDEN's "present
  exactly once" replaced by an ABSENCE class lock (manifest entry + staged
  file).
- Proof persisted:
  `specs/epic-190-a2-capability-registry/verification/T-006/cycle8-apply-rehearsal.log`
  (non-vacuity of every amended assertion; real-publisher rehearsal, three
  legs x three bundles — the cycle-6 hazard leg is now a no-op by
  construction, an adversarial replay of the evicted entry is REFUSED with
  the live workflow byte-unchanged) and `cycle8-suites.log`.
- The seq-0680 Major corrected by dated CORRECTION addenda (report x3 and
  phase2 NOTES): the phase2 suite was 34/0 at `6277cde0` and `340f0149`
  and went 33/1 at T-006's own `36339788`; now 35/0.
- The Outputs table refreshed last: 73 rows derived from the fourteen task
  commits, 0 undeclared / 0 over-declared / 0 stale.

## Deterministic gates run by this gate

- `check-risk` tasks.md T-006: PASS (`Risk check passed for task T-006`,
  valid `high` tier, `Required Workflow: tdd`).
- `check-placeholders` over this cycle's changed production-adjacent files
  (the four amended suite twins and both NOTES files): PASS.
- `check-workflow-state` (repo-wide): rc=0 `workflow-state: ok` before the
  flip; re-run after the flip and the attempt-7 re-bind: rc=0 (recorded in
  the re-bind section below).
- `check-task-state` tasks.md: rc=1 — the same pre-existing debt seq-679
  and seq-680 recorded (T-005 and T-007 are `Done` without
  `verification/T-00{5,7}.{contract,evidence}.json`), 4 items, unchanged.
  T-006's own row is valid, and this gate populates T-006's contract and
  evidence bundle at the flip so the debt does not grow.
- `check-quality-gate-cycle-limit`: `Escalate-Human`, rc=1 — recorded; see
  Cycle accounting (human direction on file).
- Outputs authorization audit: population derived from `git diff
  --name-only` over T-006's fourteen commits; after the documented
  exclusions and the two recorded eviction deletions: 73 paths. Declared
  rows: 73, unique. 0 undeclared, 0 over-declared, 0 stale, 0 missing.
  (The evaluator independently re-derived the same 104 -> 75 -> 73 result.)

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 681, stage `quality`, role `sdd-evaluator`,
  `task_id` T-006, `input_mode` file-manifest, `fallback_mode` none,
  `read_only` true, and the run ID / host-session ID above. Key set
  identical to the seq-680 manifest; no `attempt`/`round` keys;
  `risk-gate-matrix.md` and `investigation.md` absent by construction.
- 84 allowed-input entries: `quality-gate-calibration.md`, the nine feature
  specification layer files, the T-006 implementation report, and all 73
  paths the report's `## Outputs` table declares.
- The validator made the reservation; no ledger record was hand-written.
  `validate-review-context-set.sh <manifest> . --reserve` returned
  `REVIEW_CONTEXT_OK 1a3c4847512e400afa1590a71cfa09756f2e007ed73dcd0c3f2843b9b5535318`,
  equal to the appended seq-681 record's `record_sha256`.
  `previous_record_sha256` db8a99b5… is the seq-680 evaluator record.
  Pre-reservation ledger hash (bound in the manifest):
  28725bdf0034332a59c461fe2145a55bd20d68fb9e607d8e7e5c724b4f32f781.
  Post-reservation ledger file hash:
  14f1c135f880c1b1aa22059b3210583d1a05815d8267fdf4438e4633e1a6be16.
- The evaluator discharged the launch gate independently: manifest
  self-hash match; pre-reservation ledger recovered via
  `git show HEAD:…identity-ledger.json` and hash-matched; the record-hash
  formula re-derived by brute force and the full 681-record chain walked
  (0 gaps, 0 breaks, 0 duplicate run/host-session IDs, own identity
  exactly once); the reservation replayed byte-equal in a `git archive
  HEAD` scratch tree (`REVIEW_CONTEXT_OK 1a3c4847…`); all 84 input hashes
  verified before reading and re-verified unchanged after.
- Role provenance checked, not assumed: installed sdd-quality-loop 1.10.0
  `agents/evaluator.md` byte-identical to the in-tree copy.
- `git status --porcelain` before launch and after the evaluator returned:
  the only deltas are this gate's own artifacts (the pending manifest and
  the validator's ledger append; this report, the flip, the contract and
  evidence bundle, and the attempt-7 re-bind join them at commit time).
  The evaluator wrote nothing.

## Evaluator verdict (recorded verbatim)

```
RUN_ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0681
HOST_SESSION_ID: SESS-qg-epic-190-a2-capability-registry-T-006-0681
ALLOWED_INPUT_MANIFEST: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0681-manifest.json sha256 72288b231f1f5352fd39578905f4ef5473bbe26fdb621965b8da0ac3f60d6498
VERDICT: PASS
FINDINGS:
- [Minor] specs/epic-190-a2-capability-registry/acceptance-tests.md:55 (and traceability.md:13) — AC-030 and the REQ-006 traceability row both say "eight `tests/*.tests.sh`/`.tests.ps1` pairs", but only seven exist. I enumerated them and confirmed each is registered once in both runners: capability-registry-schema, evaluate-predicate, registry-discovery, validate-capability-registry, generate-registry-digest, generate-gate-capabilities, capability-registry-parity — run-all.sh=1 / run-all.ps1=1 for all seven. traceability.md:13's own artifact column lists exactly those seven while its prose says eight. Spec-side drift, carried record-only from seq0680; unchanged and correctly not fixed by an implementation task.
- [Minor] tests/generate-gate-capabilities.tests.sh — the MUT-6 job-set-superset blind spot persists, and I reproduced it rather than taking it on report. In a `git archive HEAD` scratch tree I deleted both CI step blocks registering `tests/capability-registry-schema.tests.{sh,ps1}` (staged candidate lines 667-678) and re-synced the manifest digest so only content assertions could move: the suite still reported `pass=23 fail=0 designed-red=0`, rc=0. The job-set check only asserts job-key superset, and the step-name greps cover only this task's own two drift-lock pairs, so a candidate silently dropping another epic-190 suite's registration goes undetected. AC-030's substance is nonetheless satisfied in fact — I measured 2 step refs per suite for all seven plus 2 refs each for both drift locks, manifest 7/7 OK — so this is a test-strengthening item, not an unverified criterion.
- [Minor] specs/epic-189-a1-project-context/tasks.md (16 refs), traceability.md (13 refs), requirements.md:1487 — the authorized eviction deleted `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`, leaving that epic's frozen spec layer naming it as a delivered artifact for T-001..T-013. The report's cycle-7 "Scoping before any edit" swept `tests/` and `plugins/*/scripts/` consumers only, and "Known residue" records the phase2 frozen runner and this feature's own staged candidate but not this. Consequence-free today and I verified why: all 13 a1 tasks are `Status: Done` (no task will re-stage), the bundle's own `PROTECTED-MANIFEST.md` and `RUNBOOK-pr229.md` carry 0 references to the path, no verification contract or evidence bundle byte-pins any edited or deleted file (2689 tracked files scanned for the six pre-eviction blob hashes: zero pins), and the new class lock makes any re-add fail loudly. Closure-sweep documentation item.
CHECKED:
- Launch gate 1-2: hashed the manifest myself = 72288b23…d6498 (matches). `git show HEAD:reports/review-context/identity-ledger.json | shasum -a 256` = 28725bdf…2781, equal to the manifest's `identity_ledger_sha256`; `git diff` on the ledger shows exactly one hunk, the 9-line appended seq-681 record and nothing else.
- Launch gate 3: re-derived the record-hash formula by brute force against record 1 rather than reading the validator — unique solution `sha256("<sequence>|<stage>|<role>|<run_id>|<host_session_id>|<previous_record_sha256>")`. Walked all 681 records with it: 0 sequence gaps, 0 chain breaks, 0 record-hash mismatches, 0 duplicate run_ids, 0 duplicate host_session_ids; my run_id and host_session_id each occur exactly once (at seq 681); `previous_record_sha256` of my record = db8a99b5…5fa7 = the seq-680 record_sha256.
- Launch gate 4: replayed the reservation in a `git archive HEAD` scratch tree (pre-reservation ledger verified 28725bdf… in-tree) with `validate-review-context-set.sh <manifest-copy> <scratch-root> --reserve` → `REVIEW_CONTEXT_OK 1a3c4847512e400afa1590a71cfa09756f2e007ed73dcd0c3f2843b9b5535318`, exit 0, byte-equal to the caller's evidence and to the appended `record_sha256`. The scratch post-reserve ledger hashed 14f1c135… — identical to the working-tree ledger, confirming the only delta is my own record.
- Launch gate 5: verified all 84 manifest input hashes before reading (0 mismatches) and re-verified them unchanged after evaluation (0 mismatches). `git status --porcelain` is byte-identical to its state at session start.
- Eviction state, both bundles: `specs/epic-136-phase2-gates/human-copy/.github/workflows/` and `specs/epic-189-a1-project-context/human-copy/.github/workflows/` do not exist; manifests are 18 and 17 lines with 0 `test.yml` entries; `shasum -a 256 -c MANIFEST.sha256` exits 0 in both (18/18, 17/17 OK).
- Class-lock non-vacuity, measured myself in scratch trees across all four lanes (not taken from cycle8-apply-rehearsal.log). phase2 sh: re-creating the staged snapshot → 34/1 (class lock fails); adding a 19th manifest line → 33/2 (class lock **and** the ordered pin fail); restore → 35/0. a1 sh: staged file → 81/1; manifest entry → 80/2 (class lock **and** the per-entry staged-bytes loop fail); restore → 82/0. phase2 ps1: 61/9 → 60/10 → 59/11 → restore 61/9. a1 ps1: 86/0 → 85/1 → 84/2 → restore 86/0.
- Apply-path behavior, real publisher, scratch trees seeded from `git archive HEAD`. Whole batch: phase2 rc=19 `DUPLICATE_BASENAME_IN_BATCH` 0 targets written; a1 rc=19 same; own bundle rc=0, all 7 targets published, 0 bytes changed (true no-op). Adversarial replay of the evicted manifest line (recovered from `7f02df24^` / `c8ac93a2^`, digest `8beba70c…`): rc=10 denied "staged candidate … is missing", live workflow byte-unchanged at a37a3795… on both. Full manifest-contract emulation: every target digest-verified and UNCHANGED — 18/18, 17/17, 7/7, zero removals anywhere.
- Suite numbers re-run at HEAD, all matching cycle8-suites.log: phase2 sh 35/0 rc=0; phase2 ps1 61/9 rc=1; a1 sh 82/0 rc=0; a1 ps1 86/0 rc=0; capability-registry-parity 22/0/0 rc=0; generate-gate-capabilities 23/0/0 rc=0; deterministic-lane-selfcheck 25/0/4 rc=1 (TEST-020 designed-red window only); check-workflow-state.sh `workflow-state: ok` rc=0; plus guard-staging-exemption 33/0 and apply-human-copy 247/0.
- Corrected WFI-016 history, re-measured by running the suite in per-commit scratch trees: 6277cde0 = 34/0 rc=0, 340f0149 = 34/0 rc=0, 36339788 = 33/1 rc=1 (FAIL: WFI-016), 025b2f0d/5cd8e423/e52d02a6 = 33/1, HEAD = 35/0 rc=0. The seq0680 Major (regression misattributed as pre-existing) is factually corrected and the regression is resolved.
- Differential/no-regression check on the ps1 lane: the 9 remaining phase2 ps1 failures at HEAD are byte-identical in name to the 9 at pre-fix e52d02a6 (which had 10, the extra being WFI-016), and the same 9 were already failing at 6277cde0 and 340f0149 (60/9) — i.e. pre-existing macOS `apply-protected-files: Windows is required` platform failures, not introduced by the class fix.
- Assertion-strength review of the amendments (checking for test-gaming, not just green): WFI-016's population changed from the staged canonical JSON's now-repository-wide `phase2_human_copy_targets` (26) to the TEST-013 inventory (18), which I confirmed is coextensive with the bundle's actual staging surface — the manifest is exactly 18 lines and the only unlisted bundle files are `MANIFEST.sha256`, the NOTES, the nested self-path copy, and a gitignored `__pycache__` artifact. No staged file escapes the byte-identity check. TEST-011's retarget to the live workflow is non-vacuous: renaming `Verify generated guard invariants (POSIX)` in live → 34/1, and renaming the `actions/checkout` marker → 34/1.
- AC-025/AC-026 re-verified directly against the generator: `_generated` carries exactly `source`/`schema_version`/`sha256`/`notice` ("This file is generated. Do not edit."), top-level keys are `_generated`/`capability_gate_map`/`gates`, no comment-line convention, `gates` contains only stage `implementation`; `--check` exits 0 clean with mtime unchanged (no write), exits 1 on a one-token mutation of the committed projection, exits 1 fail-closed with the canonical Registry removed.
- AC-029 human-apply state: all six guard-invariants-family live files plus `.github/workflows/test.yml` hash-match their staged `human-copy/` counterparts exactly; `generate-guard-invariants.py --check` against the live tree exits 0; all seven newly-registered paths appear in both `generated/guard_invariants.py` and `references/guard-invariants.json`.
- Outputs table re-derived independently from `git diff --name-status` over the fourteen task commits with the report's documented exclusions: raw union 104 → 25 review-process + 3 T-005-owned + 1 tasks.md excluded → 75 kept → 2 net deletions (the two evicted staged workflows) → 73 rows. The `## Outputs` table declares 73 unique paths: 0 undeclared, 0 over-declared, 0 stale hashes, 0 missing files. Exactly one authoritative hash declaration per path (the cycle-3 addendum carries no hashes).
```

Evaluator verdict rationale, verbatim: "The seq0680 Critical (stale
staged-workflow hazard mechanically armed) is genuinely disarmed, not
merely asserted: on every apply path I exercised, the outcome is now a
refusal or a byte-exact no-op, and the eviction is held in place by class
locks I proved non-vacuous in all four lanes. The seq0680 Major (WFI-016
misattribution) is corrected against history I re-measured myself, and the
regression it concealed is resolved — with the fix being a principled
semantics correction, not an assertion weakened to reach green. Three
Minors remain, all record-only closure-sweep items; none blocks Done."

## What this gate verified itself versus took from the evaluator

Verified first-hand by this gate, independent of the evaluator: the
scoping record (installed-guard predicate evaluation per target;
hash-consumer mapping over the sibling contracts, the four signed evidence
bundles, and every `test.yml` consumer in `tests/` and
`plugins/*/scripts/`; no HMAC boundary crossed); the eviction edits and
their baselines (pre-fix 33/1, 59/10, 81/0, 85/0 re-measured before
editing); the cycle-8 rehearsal and non-vacuity battery
(`cycle8-apply-rehearsal.log`, run twice — the first transcript was
discarded for two inaccurate own-bundle prose lines and re-run, not
hand-edited); the suite numbers with baselines (`cycle8-suites.log`); the
73-row Outputs derivation (104 -> 75 -> 73); the manifest build-time hash
of all 84 entries, the reservation arithmetic, the post-reservation ledger
hash; the evaluator role-provenance hash; and the post-run `git status`.

Taken from the evaluator and not independently re-derived by this gate:
the four-lane class-lock mutation matrix (this gate's own non-vacuity runs
covered sh fully and ps1 for the manifest-entry mutation only); the
per-commit scratch-tree WFI-016 history re-measurement (corroborating the
seq-680 evaluator and this cycle's corrections); the MUT-6 reproduction;
the a1 spec-layer reference scan behind Minor 3 (2689-file blob-hash pin
scan included); and the AC-025/AC-026/AC-029 re-verification battery.

## Findings disposition (step 9)

All three findings are **Minor** and **Accepted, record-only**. None
blocks Done; none is negotiated away.

- **Minor 1 (AC-030 "eight pairs" spec drift):** carried since seq-678;
  needs a spec amendment outside an implementation task's scope. Feature
  closure-sweep item (already recorded in RT-20260811-002 disposition_2).
- **Minor 2 (MUT-6 job-set-superset blind spot):** test-strengthening
  candidate, carried from seq-680, feature closure-sweep item.
- **Minor 3 (a1 spec-layer references to the evicted staged path, NEW):**
  documentation residue of the authorized eviction in a frozen sibling
  spec layer; consequence-free today for the measured reasons the
  evaluator recorded (all a1 tasks Done, zero byte-pins, class lock catches
  re-adds). Recorded here and in RT-20260811-002 as a closure-sweep
  documentation item for epic-189-a1's owner; editing a sibling epic's
  frozen spec layer is not authorized by ruling (b), which named the
  pinning assertions and bundles only.

## Done flip, contract, and evidence bundle

- tasks.md: T-006 `Status: Implementation Complete` -> `Status: Done`.
  The Status line is the ONLY edit; `Approval:` untouched (no approval
  word was written by this gate); no other task's fields touched.
- `specs/epic-190-a2-capability-registry/verification/T-006.contract.json`
  populated from this gate's and the evaluator's verification results
  (risk high => required set = medium ∪ {requirement-traceability}; tdd =>
  red/green evidence on unit-tests and acceptance-tests from T-006's own
  recorded RED->GREEN logs).
- `specs/epic-190-a2-capability-registry/verification/T-006.evidence.json`
  generated by `generate-evidence-bundle.sh` from that contract and this
  report (risk high: unsigned per the critical-only signature rule).
- `check-contract` and `check-evidence-bundle` both exit 0 on the
  populated artifacts (recorded in the re-bind section's final gate runs).

## Task-plan re-bind (attempt 7) and durability

The attempt-6 task-review binding recorded the raw bytes of a
status-mixed plan (its own `human_edit_summary`: "this attempt again binds
the raw form and will itself go stale on T-006's eventual Done flip").
This gate's flip made all seven tasks `Done`, so the re-bind is executed
as attempt-7 round-1 with fresh validator reservations and both task
reviewers run synchronously; its seven artifacts, the reviewers'
verdicts, and the final `check-workflow-state.sh` exit 0 are recorded in
`reports/task-review/epic-190-a2-capability-registry/attempt-7/round-1/`.
Durability: with every task `Done` and approvals granted, the plan's raw
bytes coincide with `rereview_normalized_hash(tasks.md, "Done")` — the
canonical form check-workflow-state accepts for a task-stage re-review —
and no further lifecycle flip exists for this feature, so the attempt-7
binding cannot go stale the way attempts 5 and 6 did. Measured and
reported with the re-bind artifacts.

The retrospective (gate exits Done) is a separate follow-up under the
feature's closure sweep, per the standing convention for this feature's
multi-cycle tasks.
