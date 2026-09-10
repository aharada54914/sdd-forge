# PR381 loop registration follow-up — 2026-09-08

This is primary-run integration diagnostics and ordinary code review, not an
independent SDD quality-gate verdict. No task status, frozen evidence, ticket
resolution, commit, push, or merge was changed.

## Candidate and bounded change

Checkout: /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
Base HEAD: 3971c93a5705dc15f86ba56cc62118613e4b19db
Changed file: tests/loop-inventory.tests.sh
SHA256: 327c391bb42f89f8be733601998bbdb58b6d33ae0f1b0cd897161b447089a62f

The old assertion searched the runner source for static registration strings.
The actual runner reads tests/suite-inventory.posix. The assertion now requires
successful `bash "$RUN_ALL_SH" --list`, exact whole-line path membership, and
the existing CI registration check. PowerShell checks and all other assertions
remain. No mandatory check or test was removed.

TDD sequence: original suite 67 passed / 4 failed; after adding controls but
before changing the predicate, 71 passed / 5 failed (dynamic exact registration
rejected, plus the original four). After correction: 76 passed / 0 failed.
The five new controls cover dynamic exact success, missing entry, .bak
near-match, exit-7 listing with correct stdout, and missing CI registration.

Primary review: no Critical findings in this diff. Shell-local fixture
variables restore the actual runner/workflow paths after the controls; command
failure short-circuits before membership; whole-line fixed-string matching
does not interpret path punctuation. The unchanged workflow grep is a textual
registration check, not proof of job execution. Formal gate remains pending.
Bash syntax and git diff --check both returned 0.

## Broader regression failures retained

Related suites were run concurrently on macOS:
- loop-driver: 19 passed / 3 failed, exit 1.
- loop-consistency: 31 passed / 2 failed, exit 1.
- loop-escalation: 32 passed / 0 failed, exit 0; existing named SKIPs remain.

Driver and consistency reported mktemp collision at
tests/lib/loop-driver.sh:440 (`loop-manifest.XXXXXX.json`), followed by an
empty-path write at line 441. Consistency also reported
`no requirement rows found in traceability.md` and
`ERROR: task-review-precheck: traceability Layer Spec values are invalid`.
These failures are not waived and not attributed to this one-file diff
without baseline evidence. Diagnose the temporary-file portability and task
fixture separately before claiming the whole loops-routing lane passes.

PR394 and PR390 remote checks were freshly inspected: each still fails the
Windows test job and required-checks; their other reported checks pass. Neither
is mergeable under the user's all-required-CI-success condition.

## Full final scoped test output

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

