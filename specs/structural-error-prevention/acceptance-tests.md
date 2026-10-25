# Acceptance Tests: Structural Error Prevention

Draft plan only; no implementation tests or formal reviews have run for this feature. Each row names an independently traceable assertion; suffixes split the former grouped TEST IDs without adding suites. Existing parameterized fixture assertions remain separately observable. A passing rejection test does not establish historical production causality.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target / Assertion | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001a | source inspection | C1: contributor map links WFI-039/043 recurrence to shared generator/classifier, fixture controls and retained pending/applied judgment. | Planned |
| AC-001 | REQ-001 | TEST-001b | source inspection | C2: map links WFI-044 and corrected #619 runtime facts to producer/consumer checks and unknown historical origin. | Planned |
| AC-001 | REQ-001 | TEST-001c | source inspection | C3: map links WFI-055/051 and #620 process failure to catalog/completion enforcement and retained causal judgment. | Planned |
| AC-002 | REQ-002 | TEST-002a | integration | Existing catalog local profile executes the focused classifier suite; receipt/output identifies its invocation. | Planned |
| AC-002 | REQ-002 | TEST-002b | integration | Existing CI profile and caller execute the focused classifier suite; metadata registration alone does not satisfy this check. | Planned |
| AC-002 | REQ-002 | TEST-002c | integration | An isolated assertion mutation in the selected focused suite makes its actual runner invocation fail; no production fixture is altered. | Planned |
| AC-003 | REQ-003 | TEST-003a | regression | Existing check_pins_never_waive: missing pin cannot waive mismatch (STALE). | Planned |
| AC-003 | REQ-003 | TEST-003b | regression | Existing check_pins_never_waive: duplicate pin entries cannot waive mismatch (STALE). | Planned |
| AC-003 | REQ-003 | TEST-003c | regression | Existing check_ship_successors: changed live bytes remain STALE. | Planned |
| AC-003 | REQ-003 | TEST-003d | regression | Existing check_manifest_digest_independent: incorrect manifest digest is reported even for a PUBLISHED classification. | Planned |
| AC-003 | REQ-003 | TEST-003e | regression | Existing check_ship_successors: unmutated equal predecessor remains FRESH. | Planned |
| AC-003 | REQ-003 | TEST-003f | regression | Existing check_ship_successors: exact reviewed successor pair remains PUBLISHED. | Planned |
| AC-003 | REQ-003 | TEST-003g | regression | Existing main pending control: legitimate new human-copy stays PENDING, without a write. | Planned |
| AC-003 | REQ-003 | TEST-003h | regression | Existing main missing control: absent previously published file remains MISSING, not legitimate pending work. | Planned |
| AC-003 | REQ-003 | TEST-003i | regression | Second-edit synthetic control in existing focused suite, added only if absent: ambiguous divergence does not authorize sync or modify bytes; retain existing safe classification/diagnostic. | Planned |
| AC-003 | REQ-003 | TEST-003j | regression | Existing check_ship_successors staged mutation case: changed staged bytes remain STALE. | Planned |
| AC-003 | REQ-003 | TEST-003k | regression | Existing check_manifest_digest_independent corrected-digest control: no manifest mismatch is reported. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-004a | producer/consumer integration | Existing cross-model-encoding helper under actual Core: strict Python accepts BOM-free actual producer output with exact result/non-ASCII projection; edition/version recorded. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-004b | producer/consumer integration | Existing helper under actual Core: strict Node accepts the same valid output with exact result/non-ASCII projection. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-004c | producer/consumer integration | Existing helper under actual Desktop: strict Python accepts valid actual producer output; record edition/version, or explicitly unverified when unavailable. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-004d | producer/consumer integration | Existing helper under actual Desktop: strict Node accepts valid actual producer output, or explicitly unverified when unavailable. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-004e | producer/consumer integration | PROPOSED helper addition: prepend EF BB BF to a temporary copy of an otherwise valid JSON control; the same strict Python consumer exits nonzero. This synthetic negative requires no Desktop runtime. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-004f | producer/consumer integration | PROPOSED helper addition: the same BOM-prefixed copy makes the same strict Node consumer exit nonzero. Keep the original BOM-free Node control successful; do not strip BOM before parsing. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005a | regression / evidence review | Existing self-improvement-guard partial completion mutation cannot emit complete=true. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005b | regression / evidence review | Existing malformed completion mutation cannot emit complete=true. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005c | regression / evidence review | Existing stale_run mutation cannot emit complete=true. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005d | regression / evidence review | Existing unrun-check mutation cannot emit complete=true; no execution is inferred from an absent result. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005e | regression / evidence review | Existing current-complete record emits complete=true only as a session assertion, not independent execution proof. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005f | regression / evidence review | HANDOFF REVIEW ONLY: incomplete audit with a real finding remains process failure, retains the finding, and permits unknown cause. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005g | regression / evidence review | HANDOFF REVIEW ONLY: completed audit with genuine execution evidence and zero findings remains a legitimate control. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005h | regression / evidence review | HANDOFF REVIEW ONLY: asserted completion without execution artifacts is not execution proof even if assertion validation accepts the shape. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005i | regression | Existing stale_attempt completion mutation cannot emit complete=true. | Planned |
| AC-003, AC-004 | REQ-003, REQ-004 | TEST-005j | regression | Existing stale_head completion mutation cannot emit complete=true. | Planned |
| AC-005 | REQ-005 | TEST-006a | compatibility / source inspection | Existing guard generator checks and mutation suite reject stale projections; no new guard authority. | Planned |
| AC-005 | REQ-005 | TEST-006b | compatibility / source inspection | Existing guard generator additive-evolution control remains accepted without relaxing protected invariants. | Planned |
| AC-005 | REQ-005 | TEST-006c | compatibility / source inspection | Existing Bash mirror freshness entry point still invokes shared classifier and retains its result semantics. | Planned |
| AC-005 | REQ-005 | TEST-006d | compatibility / source inspection | Existing PowerShell mirror freshness entry point still invokes shared classifier with equivalent policy. | Planned |
| AC-005 | REQ-005 | TEST-006e | compatibility / source inspection | Full approval consumer assessment preserves its critical two-person rule; reuse existing approval regression coverage. | Planned |
| AC-005 | REQ-005 | TEST-006f | compatibility / source inspection | Lite approval consumer assessment preserves its own lifecycle/evidence policy; do not substitute Full policy. | Planned |
| AC-005 | REQ-005 | TEST-006g | compatibility / source inspection | Strict-current review-context admission twins retain input, path and hash checks when assessing shared parsing candidates. | Planned |
| AC-005 | REQ-005 | TEST-006h | compatibility / source inspection | Historical panel parser remains intentionally tolerant; candidate analysis does not import that tolerance into current admission. | Planned |
| AC-005 | REQ-005 | TEST-006i | compatibility / source inspection | Diff/evidence inspection shows frozen historical bytes unchanged; corrections are append-only addenda. | Planned |
| AC-005 | REQ-005 | TEST-006j | compatibility / source inspection | Pending human-copy bytes remain unchanged; ambiguity never creates sync permission. | Planned |
| AC-005 | REQ-005 | TEST-006k | compatibility / source inspection | Change inspection finds no duplicated enforceable rule text across SKILL.md files, new classifier, validator deletion or weakened gate. | Planned |
| AC-005 | REQ-005 | TEST-006l | compatibility | Existing guard mutation suite rejects dropped protection independently of stale-output detection. | Planned |
| AC-005 | REQ-005 | TEST-006m | source inspection | Current implementation-report authoring validator keeps strict declaration grammar; candidate extraction does not substitute tolerant historical parsing. | Planned |
| AC-006 | REQ-006 | TEST-007a | integration | Existing catalog test_missing_runtime_is_failure_unless_profile_explicitly_optional: missing required runtime records failure and nonzero result. | Planned |
| AC-006 | REQ-006 | TEST-007b | integration | Same existing test optional-profile branch: declared optional absence records visible skipped result, not executed success. | Planned |
| AC-006 | REQ-006 | TEST-007c | integration | Existing test_failed_suite_does_not_hide_later_results_and_receipt: failed suite remains failed and later result is retained. | Planned |
| AC-006 | REQ-006 | TEST-007d | integration | Linux existing CI/native routes: applicable Bash/PowerShell mirror and generator suites execute; receipt identifies actual platform, or limitation remains explicit. | Planned |
| AC-006 | REQ-006 | TEST-007e | integration | macOS existing CI/native routes: applicable mirror and generator coverage is recorded as actually executed or unverified; Linux evidence cannot certify macOS. | Planned |
| AC-006 | REQ-006 | TEST-007f | integration | Windows existing CI/native routes: applicable PowerShell mirror and Desktop helper coverage is recorded as actually executed or unverified; Core cannot certify Desktop. | Planned |
| AC-007 | REQ-007 | TEST-008a | handoff inspection | C1 handoff delivers source, bad/control cases, artifact/tool-trace expectations and a grader mutation; pending/second-edit judgment is retained. | Planned |
| AC-007 | REQ-007 | TEST-008b | handoff inspection | C2 handoff delivers versioned sources, BOM negative/valid controls and a grader mutation; synthetic consumer tests and actual producer evidence remain distinct. | Planned |
| AC-007 | REQ-007 | TEST-008c | handoff inspection | C3 handoff delivers source, the three interpretation branches and a grader mutation; no behavior execution is claimed by this review. | Planned |
| AC-007 | REQ-007 | TEST-008d | handoff inspection | #600 owns held-out split/rubric/model/budget/repetitions/results; #601 deterministic completion does not claim those results or depend on their execution. | Planned |
| AC-004, AC-007 | REQ-004, REQ-007 | TEST-009a | evidence review | #619 correction cites official Windows PowerShell 5.1 UTF8 BOM semantics and actual or explicitly absent Desktop reproduction. | Planned |
| AC-004, AC-007 | REQ-004, REQ-007 | TEST-009b | evidence review | #619 correction cites PowerShell 7 utf8 no-BOM semantics; a successful old Core baseline is not labeled Red. | Planned |
| AC-004, AC-007 | REQ-004, REQ-007 | TEST-009c | evidence review | Historical BOM evidence leaves producer/cause unknown without confirming evidence; hypotheses and counterevidence stay linked rather than promoted by correlation. | Planned |
| AC-004, AC-007 | REQ-004, REQ-007 | TEST-009d | evidence review | Existing Meta-Change independent review remains required for measurement/grader/threshold/approval changes; PASS totals do not authorize promotion. | Planned |
| AC-004, AC-007 | REQ-004, REQ-007 | TEST-009e | evidence review | Retention remains Not evaluated until subsequent observations under existing Horizon/Retention; no local fixture total becomes recurrence improvement. | Planned |

## Coverage and Evidence Boundaries

TEST-002a and TEST-002b cover the local/CI branches of AC-006 as well as registration. Additional malformed/pin/completion variations already exercised by the referenced parameterized suites remain unchanged; the selected historical branches above each have their own row. Frozen correction preservation in AC-004 is covered by TEST-006i. The shared-state source map is reverified at the checkpoints in design.md#shared-state-reverification.

TEST-003a through TEST-003i use temporary fixture roots, never frozen/pending repository artifacts. TEST-004e and TEST-004f are new bounded consumer negatives, independent of Desktop availability; they are not native producer Red evidence. TEST-004c and TEST-004d require actual Desktop execution before claiming Desktop verified.

TEST-005f, TEST-005g and TEST-005h are reviewed handoff expectations, not executed model behavior. TEST-008a through TEST-008d verify delivery readiness, not #600 grader performance. Required runtime failure is not converted to optional skip, and existing checks remain mandatory. Missing supported-platform evidence remains visible and uses the existing platform CI route before that platform is claimed verified. No acceptance check grants approval or a formal gate verdict.
