# epic-195-a7-compatibility: Phase 2 (task decomposition) scope determination

## Determination

**Phase 2 (task decomposition — `sdd-bootstrap-interviewer` Phase 2 →
`tasks.md`/`traceability.md` → `task-review-loop`) is out of scope for
this epic's own current work package.** It is explicitly, repeatedly
framed by this package's own requirements.md as a separate, later task,
gated on upstream Epics (A1, A4, A5, A6) merging — not an automatic next
step for this orchestrator to begin. This matches the precedent Epic A8
(epic-196) established: declare epic completion at `Impl-Review-Status:
Passed`, record Phase 2 as future work in `reports/notes/`, do not start
it.

## Evidence (verbatim citations)

**requirements.md, Overview** (this package's own self-description):
> This package is Phase 1 (specification) only: `investigation.md`,
> `requirements.md`, `design.md`, `acceptance-tests.md`. No test code,
> fixtures, or registry edits are produced by this task; `tasks.md` and
> `traceability.md` follow in a later phase once this package passes
> `spec-review-loop`.

**requirements.md, Non-goals**:
> Authoring the actual test code, fixtures, or registry/driver/run-record
> edits. Those are Phase 2/3 deliverables of **a later task** once this
> package passes `spec-review-loop`/`impl-review-loop`.

(emphasis added — "a later task," not "this task's own next phase.")

**requirements.md, Risks (Medium)**:
> this package's deliberate 4-file (no layer-spec, no Phase-2) scope
> deviates from `check-sdd-structure.sh`'s own full-profile expectation
> (INV-018)... A Phase 2 kickoff gate closes this deliberately rather than
> leaving it open-ended: **Phase 2's own first commit is expected to be
> the one that finally generates the six missing files** (layer specs +
> `tasks.md`/`traceability.md`), and a `check-sdd-structure.sh` run
> failing before that commit is the expected, self-documenting signal
> that Phase 2 has not yet started — never silence (Main Workflows step
> 1).

(Four of the six originally-missing files — `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, `security-spec.md` — were generated
during this epic's own impl-review phase, commit `b0df1797`, but *only*
to satisfy `impl-review-loop`'s own mechanical precondition #4 for a
`profile: full` registry entry — not as "Phase 2's own first commit."
`tasks.md`/`traceability.md` remain ungenerated, consistent with Phase 2
not having started.)

**requirements.md, Main Workflows, step 1**:
> A future Phase 2/3 task reads this package, captures the REQ-006 golden
> baseline against the fixed pre-capability merge-base commit (AC-018,
> never "current `main` HEAD"), and commits it as the initial canonical
> baseline.

(Task decomposition is bundled with starting the actual implementation —
golden-baseline capture, registry/driver edits — as belonging to this
same "future Phase 2/3 task," not a phase transition this orchestrator
continues into.)

**requirements.md, Assumptions**:
> Epics A1 (`sdd-forge-wt-epic-189`), A3 (`sdd-forge-wt-epic-191`), and A5
> (`sdd-forge-wt-epic-193`) remain unmerged and in active spec/task-review
> through this epic's own Phase 1; A4 (`sdd-forge-wt-epic-192`) has passed
> `spec-review-loop` but is also unmerged; A6 (`sdd-forge-wt-epic-194`) is
> in active spec-review... **This package re-verifies before Phase 2/3
> begins**, per investigation.md's Safety constraints.

(The re-verification of upstream epic state is itself assigned as a
*precondition* of Phase 2/3 starting — future work, not something this
orchestrator has done or should do now.)

**design.md, header**:
> Feature Type: test-infrastructure specification (Phase 1 — no code)

**Issue #195 (`https://github.com/aharada54914/sdd-forge/issues/195`),
依存 (Dependencies)**:
> Epic A1（フォールバック実装）、A5（Resolver 経路）

**Issue #195, Done 条件**:
> Context 不在フォールバックの3種テストが CI で green

(The issue's own Done condition requires the actual tests to exist and
pass in CI — necessarily Phase 2/3 work, contingent on the two
dependency epics above having merged. This is the parent GitHub issue's
own full-epic completion bar, distinct from this SDD work package's own
Phase-1-only scope.)

## Conclusion

epic-195-a7-compatibility, as the SDD work package this orchestrator has
driven through `spec-review-loop` (`Spec-Review-Status: Passed`,
`specs/epic-195-a7-compatibility/requirements.md`) and `impl-review-loop`
(`Impl-Review-Status: Passed`, `specs/epic-195-a7-compatibility/design.md`,
commit `9c076299`), is **complete as a Foundation-phase deliverable**: a
fully specified, independently double-reviewed, three-test-kind
compatibility test design, extending the existing loop-inventory/loop-driver/
run-record infrastructure rather than duplicating it, ready for a future
task to implement once its own stated preconditions hold.

Task decomposition (`tasks.md`/`traceability.md`) and the actual test-code
authoring GitHub issue #195 itself requires for full closure are **not**
undertaken by this orchestrator. They are future work, explicitly gated on
Epic A1 and Epic A5 merging (per issue #195's own Dependencies; Epic A4
and Epic A6 additionally relevant per requirements.md's own REQ-007
allowlist-manifest dependencies), to be picked up as a separate task
package once those land — matching the disposition Epic A8
(epic-196) recorded for the analogous situation.
