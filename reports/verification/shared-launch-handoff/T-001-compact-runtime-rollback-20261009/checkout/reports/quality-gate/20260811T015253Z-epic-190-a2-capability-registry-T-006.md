Task: Author the projection generator and stage the protected-file registration
Task ID: T-006
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0678
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-006-0678
Ledger Sequence: 678
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0678-manifest.json (sha256 3510a0c5ceb34c000257997a83b2eb2873889fb8c2df8fb3dd3872e52c3c1455)
Attempt: 5
VERDICT: NEEDS_WORK

Done is WITHHELD. `Status:` stays `Implementation Complete`. The task-plan
re-bind described in WFI-025 was NOT performed, because it is conditional on a
Done flip that did not happen.

This is the post-human-apply cycle. The three blockers the previous cycle
(sequence 674) raised are all genuinely resolved — each was re-verified here
from primary evidence, not accepted from the implementation report. The task
does not pass for a different and previously unmeasured reason: the human apply
that discharged Done-When #2 regressed two other features' live protected-file
gates, and every regression run recorded in the implementation report was
captured before the apply, so no cycle had yet measured the applied state.

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 678, stage `quality`, role `sdd-evaluator`,
  `task_id` T-006, `input_mode` file-manifest, `fallback_mode` none,
  `read_only` true, and the run ID / host-session ID assigned above. The
  v1.14.0 validator pins the key set exactly; no `attempt`/`round` keys were
  added.
- The validator made the reservation; no ledger record was hand-written.
  `validate-review-context-set.sh <manifest> . --reserve` returned
  `REVIEW_CONTEXT_OK f2d72698941024e8d49dd3f4079c5186b72ba36de11cdff7e0d085f4ab65a5be`,
  equal to the appended record's `record_sha256`.
- `previous_record_sha256` e2475a6776f0107b89d53a66148bb2a37697f9717b5932df40c15cb14e79a737
  is the task-reviewer-b record at sequence 677.
  `identity_ledger_sha256` 2dedc4a7f5294a8a0b54411285f6b5c73c3003aafd64c238c48e15be78983f56
  binds the PRE-reservation ledger and is stale by construction once the
  reservation lands (post-reservation file hash
  2a2e6d7e3090c833abba866e80861e6dc1eb53c2b592be0d8f1ed30148ff912f). The
  evaluator discharged the launch gate by dropping the tail record and
  re-hashing the remainder: exact match to the bound value. It then walked all
  678 records — 0 chain breaks, sequences 1..678 contiguous, its own run ID and
  host-session ID each present in exactly one record, and the five earlier
  T-006 evaluator identities (349, 664, 666, 669, 674) all distinct.
- 52 allowed-input entries: nine feature specification layer files
  (`investigation.md` excluded), `quality-gate-calibration.md`, the T-006
  implementation report, and all 41 paths the report's `## Outputs` table
  declares. `risk-gate-matrix.md` and `investigation.md` are absent by
  construction. Re-measured 52/52 by the evaluator at read time; the gate
  measured them independently when building the manifest.
- The evaluator's reported manifest hash (`3510a0c5…`) matches this gate's own
  `shasum -a 256` of the persisted manifest.
- Evaluator role provenance checked rather than assumed. Installed
  sdd-quality-loop is 1.10.0 against 1.14.0 in tree, and the installed copy is
  what executes, so `agents/evaluator.md` was diffed across the two:
  byte-identical. No stale-role input could have produced these findings.
- `git status --porcelain` was captured at the start of the cycle, again
  mid-cycle, and again after the evaluator returned. The only deltas across the
  whole run are this gate's own two artifacts (the pending manifest and the
  validator's ledger append). The evaluator wrote nothing.

## The three prior blockers: all resolved (independently re-verified)

**1. Human apply — LANDED and clean.** Verified by this gate directly, before
anything else, because a half-applied transaction must not be gated over:

- `shasum -a 256 -c MANIFEST.sha256` from inside `human-copy/`: 7/7 OK, exit 0.
- All seven live targets are byte-identical to their staged counterparts.
- `protected_gate_suffixes` 70 -> 77 (+7 / -0), `phase2_human_copy_targets`
  19 -> 26 (+7 / -0), top-level key set unchanged, and **zero removals across
  every key in the file**, not merely the two named arrays.
- `generate-guard-invariants.py --check` against the live applied tree: exit 0.
- The seven added paths are exactly the seven `tasks.md` Protected Files names.

**2. Contradictory Outputs declarations — resolved.** The cycle-3 addendum's
SHA-256 column is gone and the section is marked SUPERSEDED. All 41 `## Outputs`
rows were re-measured against live: 41 OK, 0 stale, 0 missing, 0 duplicate
paths. A whole-report scan for table-shaped `path | 64-hex` declarations outside
`## Outputs` found exactly one other table — the explicitly labelled
pre-apply/post-apply live-path table — and it conflicts with nothing: its
"Current (pre-apply)" column matches `HEAD` for all seven paths and its
"Expected post-apply" column matches both the live files and `MANIFEST.sha256`.
Exactly one authoritative declaration per path.

**3. Vendoring drift-lock `--check` step — real, and the assertion is armed.**
The mutation test was re-run by this gate rather than read from the log, across
the full 2x2 matrix (staged and drafts candidates x projection and vendor step
pairs), with the MANIFEST re-measured after each mutation so the hash assertion
could not mask the result:

| deleted step pair | file | what failed |
|---|---|---|
| projection | `human-copy/` | only the staged compound assertion (DESIGNED-RED) |
| vendor | `human-copy/` | only the staged vendoring assertion |
| projection | `drafts/` | only the candidate compound assertion |
| vendor | `drafts/` | only the candidate vendoring assertion |

Each mutation failed exactly one assertion, and the correct one. Critically,
residual occurrences of the deleted literal command string were **0 in every
case** — the comment block paraphrases rather than quotes, so the disarming
defect the previous attempt introduced and caught is genuinely absent. Run
without the MANIFEST fixup, each mutation additionally trips the manifest
self-consistency assertion, confirming that binding is live too. Baseline
restored to 23/0/0 afterward. Both runtimes pass 23/23.

## Blocking findings

- **[Critical] `tests/guard-invariants-epic-a1.tests.{sh,ps1}` (TEST-021 /
  TEST-022) regressed from green to 8 failures.** Differential measured by this
  gate independently of the evaluator: a pre-apply tree extracted with
  `git archive HEAD | tar -x` runs the suite at **81 PASS / 0 FAIL, rc=0**; the
  delivered worktree runs it at **73 PASS / 8 FAIL, rc=1**. Six of the eight are
  TEST-022 "live X is neither the pre-apply baseline nor the staged candidate",
  each quoting exactly T-006's post-apply hash (e.g. `639fa2cc…` for
  `guard-invariants.json`); the other two are TEST-021 on the staged
  `protected_gate_suffixes` and the frozen `PHASE2_TARGETS` constant. The suite
  is registered at `tests/run-all.sh:92` and in the applied workflow, so CI is
  red as delivered. The implementation report's cycle-4 "Targeted regression,
  all green after the change" lists this suite as rc=0 — a true measurement of
  the pre-apply tree, and false for the state Done-When #2 now requires.

- **[Critical] Two other features' staged bundles would now silently drop all
  seven newly-protected paths.** Measured by this gate against the live file:
  `specs/epic-189-a1-project-context/human-copy/.../guard-invariants.json` and
  `specs/epic-136-phase2-gates/human-copy/.../guard-invariants.json` each carry
  70/19 where live now has 77/26, and the set difference is exactly T-006's
  seven new paths in **both** arrays, in **both** bundles — 7 dropped, 0 added.
  Whichever is applied next un-protects them. This is the same destructive
  superset violation cycles 1-3 of this task were spent eliminating, now
  pointing the other way, and it is the cross-epic `PHASE2_TARGETS` sequencing
  hazard the report's own Unresolved Items #1 says a human must resolve
  *before* applying. T-006's delivered guards
  (`tests/generate-gate-capabilities.tests.sh:240-366`) only compare T-006's own
  two candidate trees against live, so no deterministic gate covers the bundles
  this edit just invalidated. The third staged bundle, T-006's own, is at 77/26
  and correct.

- **[Major] `tests/phase2-guard-invariants.tests.{sh,ps1}` WFI-016 regressed.**
  Pre-apply: 34 passed / 0 failed, rc=0. Delivered: **33 passed / 1 failed**,
  rc=1, on "staged targets are byte-identical to live (no stale staging)", with
  the out-of-sync list naming the paths the apply touched. Registered at
  `tests/run-all.sh:55`.

- **[Major] `tests/capability-registry-parity.tests.{sh,ps1}` fails Done-When
  #3.** 21 passed / 1 failed: "the live `.github/workflows/test.yml` has an
  uncommitted modification -- this task must never write to it". This is
  state-dependent and clears once the human commits the apply, but the tree
  handed to this gate is red, and Done-When #3 is this task's feature-wide CI
  and registration confirmation point.

- **[Minor] AC-030 count text drift.** `acceptance-tests.md:55` and
  `design.md:681,785` say "eight new `tests/*.tests.{sh,ps1}` pairs"; the
  feature decomposes into seven suite pairs (the provider-name-contamination
  check lives inside T-004's validator suite rather than getting its own file).
  All seven pairs are correctly registered in both runners and the applied
  workflow, so AC-030's substance holds; only the count drifts.

- **[Minor] Three post-apply assertions are now tautological.** The
  "human-copy/ … is a pure superset of live (human apply already landed)"
  checks in `tests/generate-gate-capabilities.tests.sh:390-400,515-519` compare
  a tree that is now byte-identical to live against itself. They retain value if
  live later drifts, but as of this tree they carry no signal and should not be
  read as independent confirmation of the apply.

## What this gate verified itself versus took from the evaluator

Verified first-hand by this gate, before and after the evaluator ran: the
manifest checksum verification and live/staged byte-identity; the +7/-0 count
deltas and the zero-removals-anywhere property; `generate-guard-invariants.py
--check` exit 0; all 41 Outputs rows re-measured; the whole-report conflicting-
hash scan; the Outputs population derived independently from
`git diff --name-only` over T-006's six commits (union 69 files, 41 after the
documented exclusions — matching the declared set exactly, 0 undeclared and 0
over-declared, with the three T-005-owned exclusions confirmed present in
T-005's own report); the full 2x2 drift-lock mutation matrix; the epic-a1 and
phase2 pre/post-apply differentials; the parity suite failure; and the
cross-epic bundle set-difference.

Taken from the evaluator and not independently re-derived: the line-level
reading of `generate-gate-capabilities.py:57-143` for projection authenticity;
the `_generated.sha256` equality against the canonical Registry; the
mtime-unchanged proof for `--check`; the YAML-parse job-preservation check; the
AC-030 count-drift reading of the spec text; and the clean results for the seven
other feature suites.

## Required before the next cycle

1. Resolve the cross-epic sequencing hazard: regenerate the
   `epic-189-a1-project-context` and `epic-136-phase2-gates` staged bundles
   against the now-live 77/26 state, or record an explicit human decision on
   apply ordering. This is Unresolved Items #1 and it is now live, not
   hypothetical.
2. Bring `guard-invariants-epic-a1` and `phase2-guard-invariants` back to green
   against the applied tree. Both encode "live equals pre-apply baseline OR
   staged candidate" expectations that the apply invalidated; whether the fix is
   to the suites' baselines or to the bundles is a design decision this gate
   does not make.
3. Have the human commit the applied protected files, which clears the parity
   suite's Done-When #3 failure.
4. Re-measure the report's regression table against the applied tree, not the
   pre-apply tree.

No new review ticket is filed for the stale task-plan binding: WFI-025 already
covers it, and no Done flip occurred, so the binding is untouched.
