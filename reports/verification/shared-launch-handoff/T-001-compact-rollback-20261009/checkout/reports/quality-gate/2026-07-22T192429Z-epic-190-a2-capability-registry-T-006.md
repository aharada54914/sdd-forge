Task: T-006 Author the projection generator and stage the protected-file registration
Task ID: T-006
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-006-seq0349
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-006-0349
VERDICT: NEEDS_WORK
Decision: Retain "Implementation Complete" (Done withheld — human-gated Done-When #2/#5 unmet). Only quality-gate may set Done; this gate does not set it.

## Isolation & Input Integrity
- REVIEW_CONTEXT_OK confirmed by reading the ledger directly (not re-running the validator): seq 349, stage=quality, role=sdd-evaluator; record_sha256 recomputed from the seq-349 preimage = 485061c3…260b (matches); previous_record_sha256 = seq-348 record (765bbb…); chain consistent through 348/347.
- Allowed-input manifest (34 entries) hash = b70cd3d8… (matches); every entry's content hash recomputed and matched immediately before use. No file outside the manifest was read as substantive input. SKILL.md is not in the manifest and was not read; this gate was run from the in-manifest calibration reference plus the supplied verification steps.
- Contract/report binding: manifest task_id, sole implementation-report path (reports/implementation/epic-190-a2-capability-registry/T-006.md), report heading, and "Task ID" field all name T-006. No cross-task substitution.

## Default-FAIL Verification Contract (Risk: high → medium set + requirement-traceability; Workflow: tdd)
| Check | Type | Disposition | Evidence |
|---|---|---|---|
| unit-tests | tdd (red+green required) | PASS | red-sh/ps1 (7 pass/5 fail, substantive & distinct) + green-sh/ps1 (12/12); reran both runtimes myself → 12/12. |
| acceptance-tests | tdd (red+green required) | PASS | AC-025 → TEST-025(1-5); AC-026 → TEST-026(1-4); non-vacuous RED→GREEN; independently reproduced incl. own fixture. |
| requirement-traceability | high-tier add-on | PASS (with caveat) | AC-025 (_generated header, no comment-line) ✓; AC-026 (--check drift + no-write) ✓ incl. my mtime/real-repo proof; AC-030 (eight suite pairs in run-all + staged test.yml + MANIFEST) ✓; AC-029(a)(b) ✓ (staged candidate + MANIFEST; live byte-unchanged). AC-029(c) (new paths present in the regenerated LIVE guard_invariants.py after human cp) NOT yet satisfied — human-apply pending. |
| interface/contract | projection-generator contract (design.md/REQ-005) | PASS | Reads canonical registry via fixed script-relative offset (not the vendored copy it produces); _generated{source,schema_version,sha256,notice}; gates=implementation-only sorted; capability_gate_map drops non-implementation gate refs (verified via own promotion+artifact fixture). |
| error-paths | fail-closed | PASS | Missing canonical registry → non-zero + "not found" (TEST-026(4), reproduced); invalid/non-object/wrong-schema JSON raises ValueError → exit 1. |
| security-sensitive surface | protected-file registration | PASS (agent-side) | Exact-match arrays +7/-0 in guard-invariants.json (both arrays) and PHASE2_TARGETS; overlay generate-guard-invariants.py --check exit 0; live files never touched; 7 MANIFEST hashes match. Registration takes effect only on human cp. |
| regression | shared-file appends | PASS | run-all/test.yml appends are additive and correctly positioned after T-004; no live guard/protected file disturbed; report's T-001..T-004 re-run claims consistent with additive registration. |
| Done gate (Done-When #2 & #5) | human-apply + applied-tree --check exit 0 | FAIL (default-FAIL) | Human cp of the six-file bundle and applied-tree re-verification have not occurred and are coordination-gated; required by the task's own Done-When "before this task is marked Done (AC-029)". |

## Evidence-Ladder Notes
All PASS dispositions rest on ladder rank 1-3 evidence I produced myself (reran suites; own fixture; git object comparison; overlay --check; direct hash recompute), never on report statements. The single blocking item (human-apply) is a rank-1 cannot-verify: the artifact state I can observe (live files unchanged) affirmatively shows it has not happened.

## Independent Judgment — Coordinator Framing Decision #1 (Global-Constraints serialized-order deviation)
Adequately and honestly recorded — I concur it is acceptable. T-005 is Blocked (Epic A1 canonicalizer absent, itself blocked on an unresolved parser-library decision in epic-189 T-002) and made zero shared-file edits before blocking; T-006 appended its run-all/test.yml entries directly after T-004's. The deviation is recorded in three places (T-006 report Summary + Specification-Differences #2; tasks.md T-005 Blockers cross-ref lines 1041-1047; tasks.md T-006 Blockers lines 1258-1261). The future-task obligation is concrete and honorable: I independently confirmed the current ordering is T-004 → (gap) → T-006 in run-all.sh:57-61, run-all.ps1:40-44, and test.yml:249-269, so the insertion point for T-005's future registration is unambiguous and mechanical. Serializing on a zero-edit, hard-blocked predecessor would add no value; the deviation does not affect determinism or correctness.

## Independent Judgment — Coordinator Framing Decision #2 (guard-invariants bundle "Blocked" sub-item)
The classification is correct and, if anything, understated. The staged six-file bundle is mechanically self-consistent (my overlay --check exit 0), the seven new paths exactly match tasks.md Protected Files (+7/-0 in both JSON arrays and PHASE2_TARGETS, no typos), and the live files are byte-unchanged. The report frames the cross-epic risk as prospective (epic-189's future T-009). I verified epic-189 currently has NO divergent staged guard bundle — but I additionally found branch fix/hookguard-cwd-verdict presently edits the same live guard files. Because each epic/branch stages a whole-file replacement (not a diff), applying T-006's candidate out of sequence could silently revert those edits. So a human coordination decision genuinely gates the cp. Marking Done-When #2 "Blocked pending human coordination" (distinct from routine "staged, pending cp") is well-founded and honestly recorded.

## Why this Blocked sub-item DOES prevent an overall Done verdict (and why it differs from T-001..T-005)
It differs by the task's own text. T-001..T-005's Done-When required only that the .github/workflows/test.yml candidate be STAGED with a correct MANIFEST entry and that the LIVE test.yml be "byte-unchanged before/after" — i.e., their human-cp items were satisfied by staging and explicitly required NON-application at task time; that is why those items never blocked their Done. T-006 is the protected-file REGISTRATION task, and its Done-When #2 ("a human maintainer runs cp … runs generate-guard-invariants.py --check against the applied tree (exit 0) — confirmed before this task is marked Done (AC-029)") and #5 ("confirmation that the protected-file bundle has been human-applied and verified") REQUIRE the actual application and re-verification before Done. The registration's purpose (paths becoming R-10 protected) only takes effect on the human cp, and AC-029(c) (new paths in the regenerated live guard_invariants.py) is objectively unmet today. Therefore Done is not available now — by design (AC-029/TEST-029: "Status resolves through a human cp action, not automation alone"), not because of any implementation defect.

## Completion-Faking Scan
No placeholder/hardcoded/sample-data faking. The real projection is derived from the real registry (one real gate/one real capability), filtering is genuine logic (proven by my independent promotion+artifact fixture), wrappers are real python3-forwarding shims, the mutated canary is a realistic single-field drift, and RED failures are substantive. No scope creep: 957f18ea stayed within T-006's Planned Files and mutated no version string.

## Outstanding before Done (all human/coordination, none are agent code defects)
1. Human coordination decision on cross-branch/cross-epic PHASE2_TARGETS whole-file-replacement sequencing (fix/hookguard-cwd-verdict currently edits the same live files; epic-189 T-009 is a future consumer).
2. Human cp of the six-file bundle from human-copy/, per-file SHA-256 verification against MANIFEST, and generate-guard-invariants.py --check exit 0 on the applied tree (Done-When #2, AC-029c).
3. (Minor) Add the release-gating generate-gate-capabilities.py --check CI step to the staged test.yml during the eventual consolidation (REQ-005/Main-Workflow-4), so the committed projection is drift-gated in CI.

## Post-Done
Not applicable — task is not Done. T-007 remains correctly un-startable regardless (its genuine functional Depends-On T-005 is still Blocked). Retrospective is not triggered.
