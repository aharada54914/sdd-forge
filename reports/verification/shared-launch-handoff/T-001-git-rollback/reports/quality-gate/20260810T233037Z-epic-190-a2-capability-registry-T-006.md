Task: Author the projection generator and stage the protected-file registration
Task ID: T-006
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0674
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-006-0674
Ledger Sequence: 674
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-006-seq0674-manifest.json (sha256 fc3c20aa6ce470c87a815aa719fa015b84f8da585d6d29a252120123117aed82)
Attempt: 4
VERDICT: NEEDS_WORK

Done is WITHHELD. `Status:` stays `Implementation Complete`.

This is the post-escalation cycle RT-20260809-002 prescribes. Three prior
cycles (ledger sequences 664, 666, 668/669) returned NEEDS_WORK, the cap was
reached, and the ticket directs one further reserve-and-launch with Done
recorded only on PASS. It did not PASS.

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 674, stage `quality`, role `sdd-evaluator`,
  `task_id` T-006, `input_mode` file-manifest, `fallback_mode` none,
  `read_only` true, and the run ID / host-session ID assigned above.
- The validator made the reservation; no ledger record was hand-written.
  `validate-review-context-set.sh <manifest> . --reserve` returned
  `REVIEW_CONTEXT_OK 63379d7c220b2c1904ad09fce42fcb4d8244519f79a22f80857a93cc37770e89`,
  equal to the appended record's `record_sha256`.
- `previous_record_sha256` 8d37794b7c8573924e1fa761ec752e605a65c8feca836ecd9addfdbfbc7dd662
  (the T-005 evaluator record at sequence 673, reserved earlier in this same
  session and committed before this reservation was made — the two gates ran
  strictly sequentially, never concurrently).
  `identity_ledger_sha256` 777da81ea5347ca973a1fdc336dfd18054533c563d5fa3ec87e8592e0afe984a
  binds the PRE-reservation ledger. The evaluator discharged the launch gate
  by reconstructing that ledger (`jq 'del(.records[-1])' | shasum -a 256`,
  exact match) and then recomputing all 674 record hashes and links: 0 bad
  hashes, 0 chain breaks, 674/674 run IDs and host-session IDs unique.
- 47 allowed-input entries: nine feature specification layer files,
  `quality-gate-calibration.md`, the T-006 implementation report, and all 36
  paths the report's `## Outputs` table declares. Re-measured 47/47 at the
  start of the evaluation and again at the end.
- The evaluator's reported manifest hash matches the gate's own measurement
  (`fc3c20aa…`).
- Evaluator role provenance checked rather than assumed. Installed
  sdd-quality-loop is 1.10.0 against 1.14.0 in tree, and the installed copy
  is what executes, so `agents/evaluator.md` and the five references it
  leans on were diffed across the two: byte-identical. No stale-role input
  could have produced these findings.
- Working tree carried no evaluator writes; `git status --porcelain` was
  compared before and after the suite runs.

## Default-FAIL Verification Contract (Risk: high; Required Workflow: tdd)

| Check | Type | passes | red_evidence | green_evidence / evidence |
|---|---|---|---|---|
| projection suite (sh) | acceptance-tests (tdd) | true | verification/T-006/red-sh.log (pass=7 fail=5, concrete failure text) | Evaluator re-ran `bash tests/generate-gate-capabilities.tests.sh` -> pass=21 fail=0 designed-red=0, exit 0 |
| projection suite (ps1) | acceptance-tests (tdd) | true | verification/T-006/red-ps1.log | Evaluator re-ran it under PowerShell 7.6.2 -> identical 21 ok lines, same counts |
| generated-header conformance (AC-025) | output-binding | true | n/a | Line-read of generate-gate-capabilities.py:40-143; `_generated` block genuinely derived, `load_registry` hashes raw source bytes |
| drift detection (AC-026) | negative | true | verification/T-006/red-sh.log TEST-026(4) | `--check` re-renders in memory, compares bytes, returns 1, reaches no write path; sh/ps1/py all exited 0 against the committed projection with no write observed |
| golden-fixture non-vacuity | fixture-integrity | true | n/a | The clean fixture carries a `promotion`-stage gate that a capability references; the golden omits it from both arrays and re-orders `check-alpha-impl` ahead of source-order `check-zeta-impl`. Real filtering, not fixture-shaped |
| staged-bundle superset (AC-029(a)) | output-binding | true | verification/T-006/cycle3-red-sh.log mutation proof | All 7 MANIFEST entries present and hash-matching; the seven new paths appear in both staged JSON arrays and in the staged PHASE2_TARGETS; `guard-invariants.generated.sh` carries `GUARD_INVARIANTS_SOURCE_SHA256=639fa2cc…`, the staged JSON's own hash, proving regeneration rather than hand-editing |
| suite registration (AC-030 part) | ci-resilience | true | n/a | Both runners list all seven feature suites; the staged workflow registers each as a bash+pwsh pair |
| **protected-file bundle applied to live (AC-029(c), Done-When 2)** | **deployment** | **false** | n/a | **Not applied. See Major 1** |
| **vendoring drift-lock `--check` step (Done-When 3 / AC-030)** | **ci-resilience** | **false** | n/a | **Absent. See "Ticket item not re-raised" below** |
| report-internal Outputs consistency | output-binding | false | n/a | Two competing hash sets for three paths. See Major 2 |

## Findings

Critical: 0
Major: 2
Minor: 4

Verbatim, as returned:

- [Major] `specs/epic-190-a2-capability-registry/tasks.md` T-006 Done-When #2 and #5 (AC-029(c)) — the protected-file registration bundle has NOT been applied to the live tree, so the criterion that Done-When #5 makes a precondition of a PASS verdict ("confirmation that the protected-file bundle has been human-applied and verified") cannot be confirmed. Observed: `git diff --name-only origin/main...HEAD` restricted to `plugins/sdd-quality-loop/references/guard-invariants.json`, `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, the four `generated/guard-invariants*` siblings and `.github/workflows/test.yml` returns an empty list, and `git status --porcelain` is clean for those paths — none of the seven live protected-file targets changed on this branch. Independently, `git log --diff-filter=A origin/main...HEAD -- contracts/capability-registry.json plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` shows both were *added* on this branch (`e48c9008`, `957f18ea`), so the unchanged live `guard-invariants.json` cannot be protecting them. Missing evidence needed to clear this: a human `cp` of the seven `MANIFEST.sha256`-listed files from `specs/epic-190-a2-capability-registry/human-copy/` into place, per-file SHA-256 verification against that manifest, and `generate-guard-invariants.py --check` exit 0 against the applied tree. This is a human action, not agent rework — per `quality-gate-calibration.md` "Loop Stop Conditions", the review loop should stop rather than run another implementation cycle.
- [Major] `reports/implementation/epic-190-a2-capability-registry/T-006.md:163-165` vs `:649-651` — the report declares two different SHA-256 values for the same three canonical paths inside its Outputs surface, and states at `:480-484` that the first table was "left as-authored ... not edited after the fact", which git contradicts. Observed: `git log -S'| \`specs/.../drafts/human-copy-candidate/README.md\` | \`b11052f1'` on the report returns `340f0149 feat(epic-190-a2): pass T-007, escalate T-005 and T-006, re-bind the plan`, i.e. the "original" table was rewritten after cycle 3. Live measurement: `README.md`=`b11052f1…`, `test.yml.candidate`=`0b2ee030…`, `MANIFEST.sha256.candidate`=`5368a4f6…` (first table), while the "Corrected Outputs (cycle 3)" values `f22079ec…`/`803be998…`/`742f695b…` match no file in the tree. The `## Outputs` table is the sole authorization surface the review-context validator uses to bind reviewable files; two competing hashes for one path make that binding depend on which table a manifest builder reads. Remedy is a report annotation marking the cycle-3 table superseded, not a code change.
- [Minor] `tests/generate-gate-capabilities.tests.sh:294-339` (`py_tuple_superset_check`) — the check `exec_module()`s the staged, delivery-destined `specs/.../human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`, executing its module-level code and byte-compiling it into the delivery tree. Observed: `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/__pycache__/generate-guard-invariants.cpython-314.pyc` exists (mtime Aug 9 09:57), gitignored via `.gitignore:3`. Never committed, and the repo does this elsewhere, but it drops an untracked artifact inside the human-`cp` source tree.
- [Minor] `tests/generate-gate-capabilities.tests.sh:256-260,342-346,364-374,470-480` — since the human apply of `drafts/` into `human-copy/` landed (`86b9aa7b`), the two locations are byte-identical (`cmp` reports no difference for `test.yml`/`MANIFEST`; manifest hashes `639fa2cc…`/`3a7b718d…`/`5b152b9f…`/`588f607b…`/`b253ed97…`/`26858e3e…` are shared by both trees). The four "drafts candidate" assertions and the four "human-copy" assertions therefore now test the same bytes, halving the independent value the cycle-3 remediation intended.
- [Minor] `specs/epic-190-a2-capability-registry/acceptance-tests.md:55` (AC-030) says "each of the eight new `tests/*.tests.sh`/`.tests.ps1` pairs (Test Strategy items 1-8)", but only seven pairs exist for this feature. `traceability.md:13` itself enumerates exactly seven, and design.md Test Strategy item 6 (provider-name contamination) is implemented as TEST-020 *inside* T-004's `validate-capability-registry` suite (`tasks.md` T-004 Scope), not as its own pair. T-006 registered all seven that exist; the count belongs to the spec and should be reconciled there.
- [Minor] `reports/implementation/epic-190-a2-capability-registry/T-006.md:293-305,674-682,698-705` — "Current Status", "Test Evidence (cycle 3)" (`pass=17 fail=0 designed-red=4`, exit 1) and "What remains for a human" item 2 no longer describe the tree: the drafts→human-copy apply landed and the suite is now `pass=21 fail=0 designed-red=0`, exit 0. Covered by the Snapshot Notice, but the report now understates completion.

### Independent confirmation of Major 1 by the gate

Major 1 is the load-bearing one and it was re-measured directly rather than
accepted. Parsing both JSON files:

| array | live | staged | staged-only | live-only |
|---|---|---|---|---|
| `protected_gate_suffixes` | 70 | 77 | 7 | 0 |
| `phase2_human_copy_targets` | 19 | 26 | 7 | 0 |

The seven staged-only entries are exactly the seven paths `tasks.md`'s
Protected Files section names. The staged bundle is a clean superset of live
— which is the cycle-3 remediation working — but live itself is unchanged,
so none of the seven is protected yet. `capability-registry-parity` and
`generate-gate-capabilities` each appear 0 times in the live
`.github/workflows/test.yml` and 4 and 6 times respectively in the staged
candidate. The apply has not happened.

### Ticket item not re-raised by this cycle's evaluator

RT-20260809-002 carried two Majors. Major 1 above is the ticket's item 2.
The ticket's item 1 — the missing **vendoring** drift-lock `--check` step —
was not named by this evaluator, which verified the projection drift-lock
step at the staged workflow's `:52,57` and did not separately look for the
vendoring one.

That gap is recorded here as the ticket's own open finding, re-measured, not
as a new gate finding; a quality gate does not add findings its evaluator did
not make. Measured 2026-08-10, case-insensitive count of `vendor`:

    0  .github/workflows/test.yml                     (live)
    0  human-copy/.github/workflows/test.yml          (staged)
    0  drafts/human-copy-candidate/…/test.yml.candidate
    0  tests/run-all.sh

`tasks.md:1088-1090` assigns both steps to this task in one breath — "the
`generate-gate-capabilities.py --check` step **and the vendoring step's
`--check` step**" — and design.md's Deployment / CI Plan (`:964-967`) and
infra-spec.md (`:16`, `:37`, `:109`) both require the vendored-copy drift
check as a release gate. One of the two required steps exists. The verdict
is NEEDS_WORK regardless, so this does not change the outcome, but it should
not be lost when the remediation is scoped: closing only Major 1 would leave
RT-20260809-002 half-addressed.

## Domain Surfaces

- Security: materially engaged, and this is the crux. The task's own Risk
  Rationale names two harm surfaces. The first — a wrong projection feeding
  the Implementation Gate — is verified sound: the generator derives rather
  than hardcodes, `--check` is byte-exact and write-free in all three
  runtimes, and the golden fixture proves promotion-stage filtering with a
  real dangling reference. The second — the protected-file registration —
  is precisely what remains unmet. Until the bundle is applied, seven paths
  this Epic created, including `generated/gate-capabilities.json` (the file
  the Implementation Gate reads) and the three `contracts/` files, sit
  outside R-10 enforcement.
- Performance / Accessibility: not touched — out of scope.

## Decision

Two Major findings. Done is withheld; `Status:` remains `Implementation
Complete`. Done-When items 1, 3 (partially), 4 and the TDD half of 5 are
satisfied and independently reproduced. Done-When item 2 and the
protected-file half of item 5 are not, and cannot be satisfied by an agent:
the apply is a human `cp` into R-10-protected paths that `sdd-hook-guard`
denies to agents by design.

Per `quality-gate-calibration.md`'s Loop Stop Conditions, and consistent with
RT-20260809-002's own `proposed_resolution`, the correct next move is the
human action, not another implementation cycle. Nothing in the agent-owned
surface is failing.

### What has to happen before T-006 can reach Done

1. **Human action.** Copy the seven `MANIFEST.sha256`-listed files from
   `specs/epic-190-a2-capability-registry/human-copy/` into their live
   locations, verify each file's SHA-256 against that manifest, and run
   `generate-guard-invariants.py --check` against the applied tree (expect
   exit 0). The staged bundle is verified a pure superset of live with zero
   removals, so this apply is additive: 70 -> 77 protected suffixes,
   19 -> 26 human-copy targets, no key dropped.
2. **Agent action.** Add the vendoring drift-lock `--check` step to the
   staged CI candidate and make the suite require both `--check` steps
   independently, with a mutation showing that removing either one fails its
   own check and only its own check. Note that `human-copy/` is
   agent-writable via the guard's staging exemption, so this does not need
   the `drafts/` detour that produced earlier findings.
3. **Agent action.** Annotate the cycle-3 "Corrected Outputs" table in
   T-006's report as superseded, so one path never carries two hashes.
   Derive the refreshed table from `git diff --name-only` over the task's own
   commits, once, after every other edit.

## Checked (self-executed by the gate, independent of the evaluator)

- Re-measured all 36 `## Outputs` rows in T-006's report against the live
  tree before reserving: rows=36 ok=36 stale=0 missing=0. The reservation
  was made only after that came back clean.
- Derived the real file population from `git show --name-only` over
  `957f18ea`, `1790bacd`, `4879aceb`, `86b9aa7b` and `340f0149`, filtered
  spec/plan/evidence paths, and diffed it against the declared set. The only
  apparent extras are the T-005 half of the shared remediation commit
  `1790bacd` (`registry-digest-fragment-multi-cap.json` and T-005's two
  suites), each declared in T-005's own report. Attributed correctly, T-006's
  population is exactly its 36 declared rows: zero undeclared, zero orphaned.
- Confirmed independently that the cycle-3 addendum table is the stale one,
  not the main table: `b11052f1…`, `0b2ee030…` and `5368a4f6…` are the live
  measurements, matching the `## Outputs` table. This matters for manifest
  construction and is why the manifest was built from the `## Outputs`
  section alone, which is also the only section the validator's awk reads.
- Ran `bash tests/generate-gate-capabilities.tests.sh` myself: pass=21
  fail=0 designed-red=0, exit 0. All four checks the report records as
  DESIGNED-RED now read `ok (human apply already landed)` — that refers to
  the `drafts/` -> `human-copy/` refresh in `86b9aa7b`, which is a different
  action from the `human-copy/` -> live apply Done-When 2 requires.
- Parsed live and staged `guard-invariants.json` and produced the
  superset table above.
- Counted `vendor` across the live workflow, the staged candidate, the
  drafts candidate and `tests/run-all.sh`: 0 everywhere.
- Diffed the installed sdd-quality-loop 1.10.0 evaluator role and its five
  supporting references against the repository's 1.14.0 copies: identical.
- Confirmed the ledger reconstruction procedure reproduces the pinned
  pre-reservation hash before handing it to the evaluator as its launch-gate
  instruction.

## Follow-ups this gate does NOT perform

- No `Status:` edit was made for T-006. Recording Done is the gate's action
  alone, and this gate did not earn it.
- The task plan hash is stale after T-005's Done flip. A task-review re-bind
  is needed; that is a separate gate with its own reviewer invocations and a
  quality gate does not manufacture a task-review verdict as a side effect.
  WFI-025 already covers the underlying matching rule.
- RT-20260809-002 stays open, both items.
