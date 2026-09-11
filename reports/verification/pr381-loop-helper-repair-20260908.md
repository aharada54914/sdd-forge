# PR381 approved loop helper repair — 2026-09-08

Checkout: /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
Base: 3971c93a5705dc15f86ba56cc62118613e4b19db

Human approval: this turn explicitly permits only trailing-XXXXXX allocation with immediate failure return, the synthetic Requirement header, and regression tests. No validator, acceptance criterion, historical evidence or review status was changed.

Files:
- tests/lib/loop-driver.sh: 2fad25470065c7a9a644fff8c526ce9a96c1778069053ede77601f5ae7adc082
- tests/loop-driver.tests.sh: c04cb4e2d5417481b5771227457600e85ff4b00270fc6b1188b9d317fd4725b8

TDD: tests-only run failed with 23 passed / 3 failed: generated traceability rejected, allocation failure continued into construction, and portable template control rejected the suffix. Minimal helper correction yielded 26 passed / 0 failed. Four added checks include obsolete-header rejection by the unchanged real validator. Fault injection is subshell-local; the real allocator and validator are used in the success case. The failure case runs in conditional context, so errexit cannot hide a missing explicit return.

Primary review (not independent quality gate): no Critical findings in the two-file diff. No product verifier changed. Temporary-file cleanup remains unchanged. Warning retained: allocation control counts the two existing pre-allocation jq reads, so a future helper refactor may require updating this test. Existing task-fixture risk-check warnings and A5-dependent SKIPs are not passes; task-stage execution is now reached on this macOS run and those coverage limits remain explicit.

Verification: bash syntax and git diff --check exit 0. Four suites repeated concurrently to exercise shared temporary allocation; full outputs below. Formal independent review/QG, native Windows and complete CI remain pending. No commit/push/merge, task Done or ticket resolution performed.

## loop-driver

Command: rtk proxy bash tests/loop-driver.tests.sh
Exit: 0

```text
=== TEST-005: loop_fixture_init (greenfield + brownfield) ===
ok: TEST-005.1: loop_fixture_init greenfield succeeds
ok: TEST-005.2: greenfield fixture root (/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/loop-fixture.9bMMFe) lies outside the repository working tree
ok: TEST-005.3: greenfield genesis identity-ledger has exactly one well-formed record
ok: TEST-005.4: genesis record hash matches the canonical INV-006 formula (validate-review-context-set.sh:245)
ok: TEST-005.5: loop_fixture_init writes no real repository path for the fixture feature
ok: TEST-005.6: loop_fixture_init brownfield succeeds
ok: TEST-005.7: brownfield fixture copies the caller-supplied seed content
ok: TEST-005.8: brownfield fixture also synthesizes the genesis identity-ledger
ok: TEST-005.9 (negative self-check): an unknown fixture profile fails loop_fixture_init
=== helper regression: traceability contract and manifest allocation ===
ok: helper: generated traceability satisfies the real layer contract
ok: helper: obsolete traceability header rejected by real validator
ok: helper: allocation failure returns before manifest construction
ok: helper: portable manifest allocation reaches the real validator
=== TEST-006: drive_review_round (spec-review rounds 1->3) ===
ok: TEST-006.1: drive_review_round spec attempt 1 round 1 (NEEDS_WORK/Major) succeeds
ok: TEST-006.2: round-1 contract records verdict NEEDS_WORK
ok: TEST-006.3: drive_review_round spec attempt 1 round 2 (NEEDS_WORK/Major) succeeds
ok: TEST-006.4: drive_review_round spec attempt 1 round 3 (PASS/Minor) succeeds
ok: TEST-006.5: round-3 contract records verdict PASS with warningCount 1 (Minor-only)
ok: TEST-006.6: assert_prior_round_complete recognizes round-1's genuine on-disk output set
ok: TEST-006.7 (negative self-check): a manifest referencing a nonexistent artifact (missing spec-review-contract.json) turns assert_prior_round_complete red
=== TEST-007: assert_artifacts_schema / assert_terminal ===
ok: TEST-007.1: assert_artifacts_schema passes on genuine, inventory-registered artifact schemas
ok: TEST-007.2 (negative self-check): a jq-mutated artifact schema turns assert_artifacts_schema red
ok: TEST-007.3: assert_terminal confirms spec-review's genuine PASS state matches the inventory
ok: TEST-007.4 (negative self-check): an end state contradicting the inventory (BLOCKED vs PASS) turns assert_terminal red
=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=300) ===
ok: TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red
ok: TEST-017.2: suite completed within the 300s runtime budget

loop-driver.tests.sh: 26 passed, 0 failed, 2s elapsed
```

## loop-consistency

Command: rtk proxy bash tests/loop-consistency.tests.sh
Exit: 0

```text
=== TEST-008: drive spec/impl/task/domain rounds 1->3 ===
ok: TEST-008.1: loop_fixture_init (spec leg fixture) succeeds
ok: TEST-008.2: spec leg drives rounds 1->3 (NEEDS_WORK, NEEDS_WORK, PASS/Minor-only) green
ok: TEST-008.3: spec leg observed end state PASS matches the loop-inventory terminal
ok: TEST-008.4: loop_fixture_init (impl leg fixture) succeeds
ok: TEST-008.5: impl leg drives (genuine spec PASS prereq, then) rounds 1->3 green
ok: TEST-008.6: impl leg observed end state PASS matches the loop-inventory terminal
ok: TEST-008.7: impl round-2 reviewer-a manifest carries round-1's integrated-summary.json (INV-012/2d8c6a5 fix in effect)
ok: TEST-008.8: loop_fixture_init (task leg fixture) succeeds
WARNING: task-review-precheck: plugins/sdd-quality-loop/scripts/check-risk.sh not found or not executable; skipping risk check.
WARNING: task-review-precheck: plugins/sdd-quality-loop/scripts/check-risk.sh not found or not executable; skipping risk check.
WARNING: task-review-precheck: plugins/sdd-quality-loop/scripts/check-risk.sh not found or not executable; skipping risk check.
ok: TEST-008.9: task leg drives (genuine spec+impl PASS prereqs, then) rounds 1->3 green
ok: TEST-008.10: task leg observed end state PASS matches the loop-inventory terminal
ok: TEST-008.11: loop_fixture_init (domain leg fixture) succeeds
ok: TEST-008.12: domain leg drives rounds 1->3 (NEEDS_WORK, NEEDS_WORK, cap-reached BLOCKED) green
ok: TEST-008.13: domain leg observed end state BLOCKED matches the loop-inventory terminal (round-cap behavior; no Minor-only PASS exception)
NOTE: TEST-008.14: domain-review-precheck.ps1 now exists upstream -- tests/loop-consistency.tests.ps1's named SKIP self-heals; no action needed here.
=== TEST-008 brownfield-profile leg: canonical seed drives spec-review round 1 (AC-007, AC-010) ===
ok: TEST-008.15 (AC-007): loop_fixture_init brownfield succeeds with LOOP_FIXTURE_SEED pointed at the canonical seed
ok: TEST-008.16 (AC-007): the canonical seed content is present verbatim under $LOOP_FIXTURE_ROOT
ok: TEST-008.17 (AC-010): brownfield-profile leg drives spec-review round 1 (PASS/Minor) green
ok: TEST-008.18 (AC-010): brownfield-profile leg observed end state PASS matches the same inventory terminal the greenfield leg (TEST-008.3) already asserts
=== TEST-009: impl-review round-2 leg green at HEAD (RED differential regression lock) ===
ok: TEST-009.1: impl-review round-2 leg is green at HEAD (2d8c6a5/INV-012 fix in effect; see TEST-008.5/.7 above)
ok: TEST-009.2: the one-time RED differential evidence against 2d8c6a5^ is recorded at specs/epic-159-pillar-a/verification/T-003/red-differential.log
=== TEST-010: bidirectional invariant (downstream-required inputs are upstream-authorized) ===
ok: TEST-010.0: loop_fixture_init (bidirectional-invariant fixture) succeeds
ok: TEST-010.1: spec-review reviewer-a manifest satisfies the bidirectional invariant
ok: TEST-010.2: impl-review round-2 reviewer-a manifest (carrying round-1's integrated-summary.json) satisfies the bidirectional invariant
ok: TEST-010.3: task-review reviewer-a manifest satisfies the bidirectional invariant
ok: TEST-010.4: domain-review reviewer-a manifest satisfies the bidirectional invariant
REVIEW_CONTEXT_PATH: domain-reviewer-a contains a real but role-unlisted path: specs/loop-consistency-inv-73507/requirements.md
ok: TEST-010.5 (negative self-check): a synthetic required-but-unauthorized manifest entry (specs/.../requirements.md for a domain reviewer) turns assert_bidirectional_invariant red
=== TEST-018: Context-absent round event trace matches the golden trace (AC-022, AC-023, AC-024, AC-026, AC-032) ===
ok: TEST-018.1: loop_fixture_init (Context-absent event-trace fixture) succeeds
ok: TEST-018.2 (AC-032): Context-absent round drives a single spec-review round (PASS/none) green
ok: TEST-018.3: observed end state PASS matches the loop-inventory terminal
ok: TEST-018.4 (AC-022, AC-023, AC-024, AC-026, AC-032): observed event trace matches the recorded golden trace via assert_event_trace
=== TEST-018.5 (AC-036): anchor-fingerprint drift check (named SKIP until Epic A5 merges) ===
ok: TEST-018.5a (positive self-check): the anchor-fingerprint checker matches a non-drifted window and ordinal
ok: TEST-018.5b (negative self-check): the anchor-fingerprint checker correctly detects a heading relocated ahead of an otherwise byte-identical window
SKIP: TEST-018.5c: AC-036 anchor-fingerprint drift check against the live SKILL.md -- Epic A5 has not merged (local ad hoc probe: specs/epic-193-a5-capability-resolver/ absent from this tree; design.md Test Strategy item 6, 'once Epic A5's caller insertion point is implemented' -- never merely once the digest happens to still match); current informational recomputation: DRIFT sha256=2344c098f3e715e93eb180c2f2afaf7778f730d037311fd86d14b8860cec4cf0 (expected d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64) ordinal=3 (expected 3)
=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=300) ===
ok: TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red
ok: TEST-017.2: suite completed within the 300s runtime budget

loop-consistency.tests.sh: 33 passed, 0 failed, 16s elapsed
```

## loop-inventory

Command: rtk proxy bash tests/loop-inventory.tests.sh
Exit: 0

```text
=== TEST-001: inventory schema + registration forcing ===
ok: TEST-001.0: loop-inventory.json exists at /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908/tests/loops/loop-inventory.json
ok: TEST-001.1: schema field is loop-inventory/v1
ok: TEST-001.2: inventory carries exactly eight loop entries
ok: TEST-001.3: plugins/sdd-domain/scripts/domain-review-precheck.sh is registered in some entry's driver_scripts
ok: TEST-001.3: plugins/sdd-review-loop/scripts/impl-review-precheck.sh is registered in some entry's driver_scripts
ok: TEST-001.3: plugins/sdd-review-loop/scripts/spec-review-precheck.sh is registered in some entry's driver_scripts
ok: TEST-001.3: plugins/sdd-review-loop/scripts/task-review-precheck.sh is registered in some entry's driver_scripts
ok: TEST-001.4: stage:role pair spec:spec-reviewer-a maps to inventory entry spec-review
ok: TEST-001.4: stage:role pair spec:spec-reviewer-b maps to inventory entry spec-review
ok: TEST-001.4: stage:role pair impl:impl-reviewer-a maps to inventory entry impl-review
ok: TEST-001.4: stage:role pair impl:impl-reviewer-b maps to inventory entry impl-review
ok: TEST-001.4: stage:role pair task:task-reviewer-a maps to inventory entry task-review
ok: TEST-001.4: stage:role pair task:task-reviewer-b maps to inventory entry task-review
ok: TEST-001.4: stage:role pair quality:sdd-evaluator maps to inventory entry quality-gate
ok: TEST-001.4: stage:role pair domain:domain-reviewer-a maps to inventory entry domain-review
ok: TEST-001.4: stage:role pair domain:domain-reviewer-b maps to inventory entry domain-review
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/check-task-state.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh
ok: TEST-001.5: cross_gates path exists: plugins/sdd-implementation/scripts/select-agent-model.sh
ok: TEST-001.6 (negative self-check): removing a registered entry turns registration validation red
=== TEST-002: numeric cap-drift lock (cap_source:script + cap_kind:numeric) ===
ok: TEST-002.1: spec-review cap value greps to its driver source's limit
ok: TEST-002.1: domain-review cap value greps to its driver source's limit
ok: TEST-002.1: quality-gate cap value greps to its driver source's limit
ok: TEST-002.2: terminal-tier is cap_kind:state and excluded from the numeric grep
ok: TEST-002.3: exactly one cap_kind:state entry exists in the inventory
ok: TEST-002.4 (negative self-check): a mutated cap value turns the drift lock red
=== TEST-003: skill-instruction exemption + fixture_profiles vocabulary lock ===
ok: TEST-003.1: impl-review carries no cap_kind field (skill-instruction is exempt from the numeric grep)
ok: TEST-003.1: task-review carries no cap_kind field (skill-instruction is exempt from the numeric grep)
ok: TEST-003.1: wfi-audit carries no cap_kind field (skill-instruction is exempt from the numeric grep)
ok: TEST-003.1: hitl-diagnosis carries no cap_kind field (skill-instruction is exempt from the numeric grep)
ok: TEST-003.2: wfi-audit carries cap_source:skill-instruction and driver_scripts: []
ok: TEST-003.2: hitl-diagnosis carries cap_source:skill-instruction and driver_scripts: []
ok: TEST-003.3: every fixture_profiles value is greenfield or brownfield
ok: TEST-003.4: every entry declares a non-empty fixture_profiles list
=== TEST-004: registration forcing (run-all.sh / run-all.ps1 / test.yml) ===
ok: TEST-004.3: dynamic exact registration is accepted
ok: TEST-004.4: missing registration is rejected
ok: TEST-004.4: near-match registration is rejected
ok: TEST-004.4: failed-list registration is rejected
ok: TEST-004.4: missing-ci registration is rejected
ok: TEST-004.1: loop-inventory.tests.sh is registered in run-all.sh and test.yml
ok: TEST-004.2: loop-inventory.tests.ps1 is registered in run-all.ps1 and test.yml
ok: TEST-004.1: loop-driver.tests.sh is registered in run-all.sh and test.yml
ok: TEST-004.2: loop-driver.tests.ps1 is registered in run-all.ps1 and test.yml
ok: TEST-004.1: loop-consistency.tests.sh is registered in run-all.sh and test.yml
ok: TEST-004.2: loop-consistency.tests.ps1 is registered in run-all.ps1 and test.yml
ok: TEST-004.1: loop-escalation.tests.sh is registered in run-all.sh and test.yml
ok: TEST-004.2: loop-escalation.tests.ps1 is registered in run-all.ps1 and test.yml
=== TEST-008: quality-gate capability applicability ===
ok: TEST-008.1: a pre-epic-195 copy without capability_applicability remains base-valid
ok: TEST-008.2: only quality-gate carries the exact three-state applicability mapping
ok: TEST-008.3 (negative self-check): an incorrect applicability value is rejected
=== TEST-009: event trace API + legacy helper non-regression ===
ok: TEST-009.1: assert_artifacts_schema remains byte-identical
ok: TEST-009.2: assert_terminal remains byte-identical
ok: TEST-009.3 (negative self-check): a deliberately changed legacy function is rejected
ok: TEST-009.4: _loop_trace_emit is available
ok: TEST-009.4: assert_capability_applicability is available
ok: TEST-009.4: assert_event_trace is available
ok: TEST-009.5: loop_fixture_init resets the trace and sequence per fixture
ok: TEST-009.6: capability applicability compares exactly and emits one canonical event
ok: TEST-009.7: an unknown fixture state is rejected
ok: TEST-009.7: applicability comparison is case-sensitive
ok: TEST-009.8: the collector assigns one trace-wide monotonic sequence
ok: TEST-009.9: invalid event JSON is rejected without consuming sequence state
ok: TEST-009.10: comparator normalizes values, matches the golden trace, and is pure
ok: TEST-009.11: kind mismatch is rejected
ok: TEST-009.11: producer mismatch is rejected
ok: TEST-009.11: value mismatch is rejected
ok: TEST-009.11: count mismatch is rejected
ok: TEST-009.12: assert_event_trace is a pure reader and never calls the appender
ok: TEST-009.13: path canonicalization is case-sensitive
=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=300) ===
ok: TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red
ok: TEST-017.2: suite completed within the 300s runtime budget

loop-inventory.tests.sh: 76 passed, 0 failed, 1s elapsed
```

## loop-escalation

Command: rtk proxy bash tests/loop-escalation.tests.sh
Exit: 0

```text
=== TEST-011: quality-gate cycle-limit / select-agent-model escalation / terminal-tier / resume ===
ok: TEST-011.1: 0 gate reports (absent reports/quality-gate/ dir) -> continue
ok: TEST-011.2: 1 gate report -> continue
ok: TEST-011.3: 2 gate reports -> continue
ok: TEST-011.4: 3 gate reports -> Escalate-Human/exit1
ok: TEST-011.5: select-agent-model.sh escalates lightweight->standard on a repeated failure class
ok: TEST-011.6: select-agent-model.sh escalates standard->strong on a repeated failure class
ok: TEST-011.7: select-agent-model.sh reports BLOCKED terminal-tier-recurrence on a strong-tier repeat (next_tier null)
ok: TEST-011.8: terminal-tier-recurrence blocked-state artifact validates against contracts/terminal-tier-blocked-state.schema.json
ok: TEST-011.9: assert_terminal confirms terminal-tier's BLOCKED end state matches the loop-inventory terminal
ok: TEST-011.10: check-terminal-tier-resume.sh denies resume when tasks.md carries no human-approval record
ok: TEST-011.11: check-terminal-tier-resume.sh permits resume once tasks.md carries a matching human-approval record
=== TEST-018: task-ID prefix collision (T-001 vs T-0010) + unanchored-identity mutation ===
ok: TEST-018.1: 3 gate reports referencing T-0010 leave the T-001 count at 0 (anchored identity match)
ok: TEST-018.2: temp copy mutation removed the end anchor from the identity regex
ok: TEST-018.3 (negative self-check): the unanchored-identity mutation turns the T-0010-vs-T-001 fixture red (wrongly escalates)
=== TEST-012: implementation-report.template.md rendered into a loop-driver fixture, driven through the REAL quality:sdd-evaluator identity checks ===
ok: TEST-012.1: loop_fixture_init (parity-extension fixture) succeeds
ok: TEST-012.2: rendered implementation report carries the real T-NNN heading and Task ID field
ok: TEST-012.3: the REAL validate-review-context-set.sh accepts the rendered implementation report and its declared ## Outputs row (quality:sdd-evaluator identity checks pass)
ok: TEST-012.4 (negative self-check): deleting the '- Task ID:' line turns the quality:sdd-evaluator identity check red
ok: TEST-012.5 (negative self-check, INV-014): a | path | sha256 | row outside the ## Outputs section boundary is NOT authorized as a declared output
=== TEST-013: python3-absent degradation (restricted PATH) ===
ok: TEST-013.0: python3 is present under this suite's normal PATH (the restricted-PATH legs below are a deliberate simulation, not an accidental gap)
SKIP: TEST-013.1: check-terminal-tier-resume.sh reports deterministic-runtime-unavailable under a restricted PATH lacking python3 (INV-017); recorded degradation, rc=1
SKIP: TEST-013.2: select-agent-model.sh reports deterministic-runtime-unavailable under a restricted PATH lacking python3 (INV-017); recorded degradation
=== TEST-019: quality-gate-outcome + done-transition event trace (F1) ===
ok: TEST-019.1: loop_fixture_init (Context-absent F1 event-trace fixture) succeeds
ok: TEST-019.2: check-quality-gate-cycle-limit.sh's real Escalate-Human decision (3 gate reports) recorded as quality-gate-outcome:escalation
ok: TEST-019.3: select-agent-model.sh's real lightweight->standard escalation recorded as quality-gate-outcome:escalation
ok: TEST-019.4: select-agent-model.sh's real standard->strong escalation recorded as quality-gate-outcome:escalation
ok: TEST-019.5: quality-gate-outcome:capability-applicability recorded for F1's own disabled-legacy fixture state, last within the kind
ok: TEST-019.6: done-transition:assert-terminal recorded as the round's own last event (terminal-tier BLOCKED)
ok: TEST-019.7: observed quality-gate-outcome + done-transition event trace matches the committed golden trace
SKIP: TEST-019.8: F3-invalid PROJECT_CONTEXT_INVALID skip-stop-message:stop event (AC-019, AC-027) -- the producer call site does not exist anywhere in the tree yet (design.md's own 'future task'); SKIP-with-activation until Epic A1 merges (design.md Compatibility Matrix, F3-invalid row)
SKIP: TEST-019.9: F4-invalid PROJECT_CONTEXT_INVALID skip-stop-message:stop event, and 'never reaches the Context-absent compatibility-fallback path' (AC-019, AC-020, AC-027) -- same unwired-producer reasoning as TEST-019.8; SKIP-with-activation until Epic A1 merges
=== TEST-019.10 (AC-004, AC-021): Resolver-non-invocation spy-harness (named SKIP until Epic A5 merges) ===
ok: TEST-019.10a (negative self-check): the spy-harness mechanism itself records a direct invocation (no false negative)
SKIP: TEST-019.10b: AC-004/AC-021 Resolver-non-invocation spy-harness against a real interviewer fixture -- Epic A5 has not merged (local ad hoc probe: specs/epic-193-a5-capability-resolver/ absent from this tree; AC-021 additionally needs Epic A1, already merged into this tree) and no caller anywhere in the tree yet invokes resolve-project-context.sh at all (SKIP-with-activation until Epic A5's caller insertion point is implemented, design.md Test Strategy item 6). The spy observes 0 invocation(s) across the F1/F3-invalid/F4-invalid fixture construction above -- a VACUOUSLY true zero, not evidence of correct non-invocation policy, since no call site exists yet to have been correctly declined; reported for provenance only.
=== TEST-019.11 (AC-037): REQ-002 Block surfaces, never falls back silently (named SKIP until Epic A5 merges) ===
ok: TEST-019.11a (negative self-check): a silently-falling-back Block (no skip-stop-message:stop event) is correctly detected as NOT surfaced
ok: TEST-019.11b (negative self-check): a Block that correctly surfaces (skip-stop-message:stop recorded) is detected as surfaced
SKIP: TEST-019.11c: AC-037 REQ-002 Block-surfaces-not-fallback check against a real interviewer fixture -- Epic A5 has not merged (local ad hoc probe: specs/epic-193-a5-capability-resolver/ absent from this tree) and the skip-stop-message:stop producer call site does not exist anywhere in the tree yet (same unwired-producer reasoning as TEST-019.8/.9); SKIP-with-activation until Epic A5 merges (design.md Test Strategy item 6)
=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=300) ===
ok: TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red
ok: TEST-017.2: suite completed within the 300s runtime budget

loop-escalation.tests.sh: 32 passed, 0 failed, 2s elapsed
```

