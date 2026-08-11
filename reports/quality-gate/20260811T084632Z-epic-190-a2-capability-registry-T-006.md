Task: Author the projection generator and stage the protected-file registration
Task ID: T-006
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0679
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-006-0679
Ledger Sequence: 679
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0679-manifest.json (sha256 bbde68ead8ed29fb62a30a218689e3f988f51b5654fac89129760f0ea16c7444)
Attempt: 6
VERDICT: NEEDS_WORK

- Model: claude-fable-5 (gate host); evaluator launched from the installed
  sdd-quality-loop 1.10.0 `agents/evaluator.md` (frontmatter `model: opus`,
  byte-identical to the in-tree 1.14.0 copy)
- Effort: frontmatter record-only (`x-sdd-effort: high`); Claude Code has no
  per-invocation effort control, so `effort_control=frontmatter`, no
  `effort_applied` claim is made

Done is WITHHELD. `Status:` stays `Implementation Complete`. tasks.md was not
touched; no approval field was touched; the WFI-025 task-plan re-bind is
conditional on a Done flip that did not happen and was not performed.

## Cycle accounting (recorded, not laundered)

This is the seventh evaluator reservation for T-006 and the sixth review
attempt. `check-quality-gate-cycle-limit.sh T-006 epic-190-a2-capability-registry`
prints `Escalate-Human` (exit 1). Cycles 1-3 were the reservations now
recorded at ledger sequences 664, 666, and 669; RT-20260809-002's
`proposed_resolution` authorized exactly one further reserve-and-launch, which
was spent at sequence 674 (NEEDS_WORK); sequence 678 (NEEDS_WORK) and this
sequence 679 ran beyond that authorization at the human's explicit direction —
the human performed and committed the protected-file apply (`025b2f0d`) and
directed this re-run of the gate. The attempt-1 identity
(`RUN-…-qg-T-006-seq0349`, 2026-07-22) sits at ledger sequence 660 after the
merge-sweep re-chain; ledger sequence 349 today holds an epic-136-phase3
impl-review record. The seq-678 report's phrase "evaluator identities (349,
664, 666, 669, 674)" named run-ID suffixes, not current ledger sequences; the
uniqueness invariant that matters — no run ID or host-session ID appears in
more than one record — was re-proven this cycle over all 679 records.

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 679, stage `quality`, role `sdd-evaluator`,
  `task_id` T-006, `input_mode` file-manifest, `fallback_mode` none,
  `read_only` true, and the run ID / host-session ID above. Key set identical
  to the seq-678 manifest; no `attempt`/`round` keys.
- The validator made the reservation; no ledger record was hand-written.
  `validate-review-context-set.sh <manifest> . --reserve` returned
  `REVIEW_CONTEXT_OK 49808eae922f9ed6bb4518f80619d5915a39c8cf1f7841b7dcb8449be25fe976`,
  equal to the appended seq-679 record's `record_sha256`.
  `previous_record_sha256` f2d72698941024e8d49d… is the seq-678 evaluator
  record. Post-reservation ledger file hash:
  95033b121f416a60d49ba548a9251c1e401946af3fb55c651cc2b2bcb518ea04.
- `identity_ledger_sha256` 2a2e6d7e3090c833abba866e80861e6dc1eb53c2b592be0d8f1ed30148ff912f
  binds the PRE-reservation ledger by construction. The evaluator discharged
  the launch gate by dropping the tail record and re-hashing: exact match. It
  then walked all 679 records — sequences contiguous 1..679, 0 chain breaks,
  its own run and host-session IDs each in exactly one record, 0 duplicate
  run IDs or host-session IDs globally, and the six earlier T-006 evaluator
  identities plus its own pairwise distinct.
- 74 allowed-input entries: `quality-gate-calibration.md`, the nine feature
  specification layer files (`investigation.md` excluded), the T-006
  implementation report, and all 63 paths the report's `## Outputs` table
  declares. `risk-gate-matrix.md` and `investigation.md` absent by
  construction. The evaluator re-hashed 74/74 OK at read time; the gate had
  measured all 74 independently when building the manifest.
- The evaluator's reported manifest hash (`bbde68ea…`) matches this gate's own
  `shasum -a 256` of the persisted manifest.
- Role provenance checked, not assumed: installed sdd-quality-loop is 1.10.0
  against 1.14.0 in tree; `agents/evaluator.md` diffed across the two:
  byte-identical.
- `git status --porcelain` captured before launch, after the evaluator
  returned, and at report time: the only deltas the whole cycle are this
  gate's own artifacts (the pending manifest, the validator's ledger append,
  this report, and review ticket RT-20260811-001). The evaluator wrote
  nothing. The human-applied live protected files are committed in the
  human's own `025b2f0d` and appear in no commit this gate makes.

## The seq-678 findings: state at this cycle (independently re-verified)

Every item below was re-measured by this gate from primary evidence before
the evaluator launched; none was accepted from the implementation report.

1. **[Critical, seq-678] Sibling `guard-invariants.json` bundles at 70/19 —
   RESOLVED** by `36339788`. Measured: both sibling bundles' arrays moved
   70→77 and 19→26, +7/−0 each, top-level key set unchanged, zero removals
   across every key, and both files are now byte-identical to live. All five
   repo copies of `guard-invariants.json` are at 77/26.
2. **[Critical, seq-678] `guard-invariants-epic-a1` suites red 73/8 —
   RESOLVED without editing any assertion.** Measured: sh 81 PASS / 0 FAIL
   rc=0; ps1 85 PASS / 0 FAIL rc=0. The evaluator proved both suite files are
   byte-unchanged since `4e682587` (2026-08-04, before the fix commit): the
   suites returned to green on data change alone, i.e. they were correctly
   detecting the seq-678 Critical 1 and stopped firing when it was fixed.
3. **[Major, seq-678] `capability-registry-parity` red on the uncommitted
   live workflow — RESOLVED** by the human's `025b2f0d` (exactly the 7 live
   protected files). Measured: sh 22/0 rc=0, ps1 22/0 rc=0; live
   `.github/workflows/test.yml` byte-unchanged relative to its committed
   state; `shasum -a 256 -c MANIFEST.sha256` 7/7 OK from inside
   `human-copy/`; `generate-guard-invariants.py --check` exit 0.
4. **[Major, seq-678] `phase2-guard-invariants` WFI-016 — NOT RESOLVED**, as
   forecast. Measured, delivered tree: sh 33/1 rc=1; ps1 59/10 rc=1.
   Pre-apply baseline on this host (scratch `git archive 6277cde0` tree): sh
   34/0 rc=0; ps1 60/9 rc=1, the nine being macOS-environmental TEST-013
   failures (`apply-protected-files: Windows is required`). The
   T-006-attributable delta is exactly one check per runtime: WFI-016
   staged-vs-live sync. Ownership analysis is in the evaluator's Major 2
   below.
5. **[Minor, seq-678] AC-030 "eight pairs" count drift — carried, unfixed**
   (spec files are not an implementation task's to edit).
6. **[Minor, seq-678] Tautological post-apply assertions — carried**; they
   regain signal only if live drifts.

## Deterministic gates run by this gate

- `check-risk` T-006: PASS (valid `high` tier, non-empty rationale,
  `Required Workflow: tdd`).
- `check-placeholders` over the production files T-006's seven commits
  changed: PASS. Two scoping notes: (a) a whole-directory sweep of the
  sibling bundles additionally flags
  `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:425`
  — a file T-006 never touched, carrying a deliberate, previously
  human-accepted annotation from epic-189-a1's own gate history; (b)
  `specs/epic-190-a2-capability-registry/tasks.md:940` trips the scanner on a
  legitimate scope note in a spec file, which is outside the "changed
  production files" remit.
- `check-workflow-state` (no `--feature`, repo-wide): rc=0, `workflow-state: ok`.
- `check-task-state` on this feature's tasks.md: rc=1 — **pre-existing debt,
  not T-006's**: T-005 and T-007 are `Done` without
  `verification/T-00{5,7}.{contract,evidence}.json`, artifacts their own PASS
  gates (seq0673 and the 2026-08-09 T-007 gate) never produced. T-001..T-004
  validate contract+bundle green. T-006's own row (Implementation Complete,
  Approved) is valid. Recorded here and left to a follow-up; manufacturing
  those two tasks' contracts retroactively is not this gate's to do.
- `check-contract` / `check-evidence-bundle` for T-006: not applicable this
  cycle — the Default-FAIL contract is populated and the bundle generated
  only when a PASS verdict lets the gate record Done, which did not happen.
- Outputs authorization audit (the RT-20260809-001 check): population derived
  from `git diff --name-only` over T-006's seven commits (`957f18ea`,
  `1790bacd`, `4879aceb`, `86b9aa7b`, `340f0149`, `6f300d97`, `36339788`):
  raw union 91 paths, 63 after the report's documented exclusions
  (review-process artifacts, the hash-bound tasks.md, the three T-005-owned
  files of the shared commit, and the seven human-applied live files recorded
  only in the human's `025b2f0d`). Declared rows: 63, unique, 0 duplicates.
  Derived vs declared: 0 undeclared, 0 over-declared. All 63 hashes measured
  current: 0 stale, 0 missing.

## Evaluator verdict (recorded verbatim)

The evaluator's findings, checks, and Done-When assessment follow verbatim.

**Critical: 2**

- [Critical] `specs/epic-136-phase2-gates/human-copy/.github/workflows/test.yml` and `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml` (both sha256 `8beba70cd04800f9ab79c24b911c9f43043968edf3362bbcd2ac50e76c380998`, 854 lines) — **the prior cycle's Critical 2 hazard is only half-disarmed: the same two whole-file-replacement bundles still stage a workflow whose application would delete this task's own CI enforcement steps.** Measured: at `6277cde0` (pre-apply) both bundles were 100% in sync with live — 18/18 and 19/19 manifest targets byte-identical, 0 differing. At HEAD each bundle differs from live on exactly one manifest target: `.github/workflows/test.yml` (live is now 991 lines, sha `a37a3795…`). Applying either bundle via its own `MANIFEST.sha256` (which lists `.github/workflows/test.yml`; `shasum -c` passes 18/18 and 19/19) would overwrite live and remove **18 named live steps**, including all four drift locks T-006 itself added — `Verify generated gate-capabilities projection (Windows)`, `… (POSIX)`, `Verify vendored contracts copy (Windows)`, `… (POSIX)` — plus the 14 CI-registration steps for all seven epic-190 suites. This is not hypothetical: `tests/deterministic-lane-selfcheck.tests.sh` TEST-020 is DESIGNED-RED precisely *because* epic-136's bundle is still awaiting its apply. The cycle-5 remediation regenerated the other six files in both bundles for exactly this reason but left the seventh; the report discusses it only for epic-136 (T-006.md:1170-1174) as a WFI-016 accounting item, never as an un-registration hazard, and **does not mention epic-189-a1's identical stale copy anywhere**. The report's sweep claim (T-006.md:1068-1070) "A repository-wide sweep confirms no other copy remains" is scoped to `guard-invariants.json` only.

- [Critical] `specs/epic-190-a2-capability-registry/verification/T-006/cycle5-apply-rehearsal.log:1-22` — **the evidence artifact the report relies on to certify the apply is safe measures the wrong surface and issues a false all-clear.** The log records `seeded 18/18 manifest targets from live` / `applied 18 staged candidates` for epic-189-a1 and `19/19` for epic-136 — i.e. the rehearsal *did* apply the stale 854-line workflow in its scratch tree — but the only property it then measured was `protected_gate_suffixes` and `phase2_human_copy_targets` counts, concluding `REHEARSAL OVERALL: ZERO REMOVALS ACROSS ALL BUNDLES` (line 21). It never compared the workflow file, so the 18 removed CI steps documented in the finding above are invisible to it. The report reproduces this as the "Safety property, measured" table (T-006.md:1056-1066, all rows `77 -> 77 / 26 -> 26 / removals 0`). Per the evidence ladder, a tier-1 saved-output artifact whose stated conclusion exceeds what it measured is worse than no artifact, because it terminates the inquiry.

**Major: 2**

- [Major] `reports/implementation/epic-190-a2-capability-registry/T-006.md:1122-1125` — factually wrong characterization of a new, genuine test failure. The report lists `tests/deterministic-lane-selfcheck.tests.sh` under "The ten that remain were **all failing before this cycle and are unrelated to it**" and describes it as "24 passed / 1 failed / 4 designed-red, unchanged. This suite is **structurally red until the human-copy application completes; it is a fail-closed self-check, not a defect**." Measured: the single genuine `FAIL` is `TEST-017-GREEN: the candidate omits baseline step name(s): Verify generated gate-capabilities projection (Windows) / (POSIX) / Verify vendored contracts copy (Windows) / (POSIX)` — four step names created by T-006's own apply. It is separate from the four `DESIGNED-RED` results and it will **not** clear when the human-copy application completes; it clears only when the sibling candidate is refreshed. The report's own cycle-4 section (T-006.md:886-888) recorded this suite at "25 passed, 0 failed, 4 designed-red", so the FAIL is new since the apply. Labelling a task-caused regression "unrelated" and "not a defect" is the kind of framing this gate exists to catch.

- [Major] `tests/phase2-guard-invariants.tests.sh` WFI-016 — red, caused by this task, split ownership, no tracking artifact cited. Observed output: `out of sync: .github/workflows/test.yml` plus seven `missing:` lines that are exactly T-006's seven newly registered paths. The `out of sync` half is T-006's own (see Critical 1). The seven `missing:` half is **owned by `epic-136-phase2-gates`**: WFI-016 reads `phase2_human_copy_targets` (now 26) as that bundle's per-bundle staging inventory (19), and closing it requires editing `TEST-013`, which pins 19 entries in fixed order. The report analyses this correctly and honestly at T-006.md:1144-1168, and I concur the array-semantics half is not T-006's to decide — but it is recorded here as an unresolved red deterministic gate with no ticket named, and it **does not by itself block T-006's five Done-When items**.

**Minor: 2**

- [Minor] `specs/epic-190-a2-capability-registry/acceptance-tests.md:55` and `specs/epic-190-a2-capability-registry/tasks.md:1177-1179` both say "**eight** `tests/*.tests.sh`/`.tests.ps1` pairs"; the parenthetical itself enumerates seven (T-001..T-006 plus T-007). Measured: seven pairs registered — `tests/run-all.sh:99-105`, `tests/run-all.ps1:58-64`. Carried over unfixed from the prior cycle.
- [Minor] `reports/implementation/epic-190-a2-capability-registry/T-006.md:208-210` states the seven human-applied live files "remain unstaged". They were committed by the human in `025b2f0d` on 2026-08-11. The report's last edit is `36339788`, which precedes that commit, so the Snapshot Notice covers it; recorded for the gate-time record only.

**DONE_WHEN (evaluator's assessment, verbatim):**

- **#1 Generated-header + drift detection (AC-025/AC-026) — SATISFIED.** 23/23 in both runtimes with TEST-025(1-5) and TEST-026(1-4) all `ok`; `_generated` carries `source`/`schema_version`/`sha256`/"This file is generated. Do not edit."; `sha256` provably equals the canonical Registry digest; no comment-line convention; mutated fixture fails `--check`, clean file passes, mtime-unchanged assertion present and the source confirms no write path under `--check`.
- **#2 HUMAN APPLY STEP (AC-029) — SATISFIED as written, but the hazard it was gated on is only half-disarmed.** The human applied and committed all seven files (`025b2f0d`); all six guard-family live files equal their `MANIFEST.sha256` entries (`shasum -c` 7/7 OK); `generate-guard-…py --check` exits 0 against the applied tree; the change is +7/−0 on both arrays with the keyset intact; AC-029(c)'s constants carry all seven paths. Note for the record: the report's own Unresolved Items #1 required the cross-epic sequencing decision *before* any apply, and T-006.md:1009-1016 concedes that ordering was not honoured. The predicted consequence materialised, and Critical 1 is the un-remediated remainder of it.
- **#3 Test-registration procedure proof (AC-030) — SATISFIED for this feature's own bundle.** Seven suite pairs registered directly in `tests/run-all.sh:99-105` and `tests/run-all.ps1:58-64`; the staged `human-copy/.github/workflows/test.yml` carries all seven suites' CI steps plus both drift-lock pairs, and its `MANIFEST.sha256` verifies 7/7. Spec text says "eight" (Minor 1).
- **#4 Suite registration + structural checks — SATISFIED.** `ok: run-all.sh registers this suite` / `ok: run-all.ps1 registers this suite`; `ok: Done When #4: no version string was hand-mutated in this task's production files (grep self-check)` in both runtimes.
- **#5 TDD evidence + independent quality-gate PASS — NOT SATISFIED.** RED/GREEN transcripts exist and all hash-match their declarations, and the human-applied `--check` exit-0 proofs are reproduced above; but this item explicitly requires "An independent quality-gate verdict records PASS", and this evaluation returns NEEDS_WORK on 2 Critical / 2 Major.

The evaluator's full CHECKED list (24 itemized self-executed measurements,
including: both projection suites 23/0/0 in both runtimes; both epic-a1
suites green; byte-identity proofs that no test assertion changed across the
fix commit; the +7/−0 array diffs; `shasum -c` over all three bundle
manifests, 7/7, 18/18, 19/19 OK; the three live drift locks all exit 0; the
job/step-set diff finding 18 live step names absent from each sibling
candidate; full `run-all.sh` with 9 failing suites, three of them
`rg: command not found` environmental; and the 63-row Outputs re-measure at
0 stale / 0 missing) is preserved in the run transcript and was
cross-checked by this gate where load-bearing (next section).

## What this gate verified itself versus took from the evaluator

Verified first-hand by this gate, independent of the evaluator: the sibling
bundles' staged workflow hashes (`8beba70c…`, 854 lines each) against live
(`a37a3795…`, 991 lines); that each sibling `MANIFEST.sha256` lists
`.github/workflows/test.yml` as an apply target; that all four T-006
drift-lock step names occur once in live and zero times in either sibling
candidate; `deterministic-lane-selfcheck` at 24 passed / 1 failed / 4
designed-red rc=1 with the FAIL naming T-006's step names, against the
report's own cycle-4 record of 25/0/4 (the FAIL is new since the apply); the
seq-678 resolution measurements listed above (suites, +7/−0 diffs, MANIFEST
checks, generator `--check`); the phase2 pre-apply baselines from a scratch
`git archive 6277cde0` tree (sh 34/0, ps1 60/9 with the nine
Windows-required platform failures); the 63-row Outputs derivation and
re-measure; the manifest build-time re-hash of all 74 entries; the ledger
tip, reservation arithmetic, and post-reservation hash; and the evaluator
role provenance diff.

Taken from the evaluator and not independently re-derived: the line-level
reading of `generate-gate-capabilities.py:61-143`; the `_generated.sha256`
equality against the canonical Registry; the fixture non-vacuity readings;
the enumeration of all 18 absent step names (this gate spot-checked the four
T-006-owned ones); the TEST-020 DESIGNED-RED rationale; and the epic-a1
suite-file last-touch attribution to `4e682587`.

## Findings disposition (step 9)

All six findings are **Accepted**. None is downgraded.

- Critical 1 and Critical 2: the fix — refreshing the staged
  `.github/workflows/test.yml` inside `specs/epic-136-phase2-gates/human-copy/`
  and `specs/epic-189-a1-project-context/human-copy/` (or an explicit owner
  decision on apply ordering), plus regenerating the rehearsal evidence over
  every manifest target — imports this feature's and T-005's CI steps into
  two other epics' staged candidates. That is a cross-epic scope decision,
  not a safe auto-fix under `auto-fix-policy.md` (forbidden: "unrelated
  changes", "ambiguous business decisions"); per that policy a review ticket
  is created instead: **RT-20260811-001** (severity critical), which also
  names the WFI-016 residue and its epic-136-owned TEST-013 pin question.
- Major 1 (report mischaracterization): recorded here with the corrected
  values per SKILL step 9; the frozen implementation report is not edited by
  this gate. The correction itself — and the rehearsal-log falsified-scope
  correction — belongs to the next remediation cycle.
- Major 2 (WFI-016): accepted with the evaluator's ownership split; now
  tracked in RT-20260811-001.
- Minor 1 and Minor 2: accepted, record-only.

## Required before the next cycle

Stated as evidence targets, per the evaluator:

1. Refresh `.github/workflows/test.yml` in both sibling `human-copy/` bundles
   to live's `a37a3795…` with their `MANIFEST.sha256` digests re-measured in
   place (the technique already proven for the six guard files in
   `36339788`), **or** record the owners' explicit apply-ordering decision in
   RT-20260811-001 — either way the 18-step deletion hazard must stop being
   silently appliable.
2. Re-run the apply rehearsal with the safety property extended to **every**
   manifest target (byte or step-set comparison of the workflow included),
   replacing `cycle5-apply-rehearsal.log`'s arrays-only all-clear.
3. Correct the `deterministic-lane-selfcheck` characterization (new
   TEST-017-GREEN failure caused by the apply; clears on sibling candidate
   refresh, not on human-copy application).
4. The AC-030 "eight pairs" spec text and the T-005/T-007 missing
   contract/evidence bundles remain open items outside T-006's remediation
   scope, recorded here for the feature's closure sweep.

No task-plan re-bind was performed (no Done flip). The retrospective is not
invoked (gate did not exit Done). `check-workflow-state.sh` exits 0 on the
tree as left by this gate.
