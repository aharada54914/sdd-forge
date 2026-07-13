# Acceptance Tests: epic-159-pillar-a

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | conformance / registration-forcing | `tests/loop-inventory.tests.sh`/`.ps1`: inventory validates as `loop-inventory/v1`; every `plugins/**/scripts/*-review-precheck.sh` appears in `driver_scripts`; every `validate-review-context-set.sh` stage:role pair maps to an entry; negative self-check removes one entry from a mktemp inventory copy and asserts the verification function fails | Planned |
| AC-002 | REQ-001 | TEST-002 | drift lock | same suite: for each `cap_source: script` entry, cap value greps to the driver source limit (`round <= 3` guards; `count >= 3` in `check-quality-gate-cycle-limit.sh:14-15`); negative self-check mutates a cap in a temp copy and asserts red | Planned |
| AC-003 | REQ-001 | TEST-003 | schema / exemption | same suite: wfi-audit and hitl-diagnosis entries carry `cap_source: skill-instruction` + `driver_scripts: []` without producing a red; `fixture_profiles` values restricted to `greenfield`/`brownfield` | Planned |
| AC-004 | REQ-001, REQ-005 | TEST-004 | configuration conformance | same suite: greps `tests/run-all.sh`, `tests/run-all.ps1`, `.github/workflows/test.yml` for all four new suite registrations (self-registration forcing) | Planned |
| AC-005 | REQ-002 | TEST-005 | integration | `tests/loop-driver.tests.sh`/`.ps1`: `loop_fixture_init greenfield` builds under mktemp, `brownfield` copies a synthetic seed; genesis identity-ledger passes REAL `validate-review-context-set.sh` hash-chain validation (formula per INV-006); fixture root asserted outside the repository working tree | Planned |
| AC-006 | REQ-002 | TEST-006 | integration (smoke) | same suite: spec-review rounds 1→3 green via `drive_review_round`; round-N manifest entries compared against the on-disk round-(N-1) output set; a manifest naming a nonexistent artifact fails | Planned |
| AC-007 | REQ-002 | TEST-007 | negative self-check | same suite: `assert_artifacts_schema` red on a jq-mutated artifact; `assert_terminal` red on an end state contradicting the inventory `terminal` field | Planned |
| AC-008 | REQ-003, REQ-005 | TEST-008 | integration (loop consistency) | `tests/loop-consistency.tests.sh`/`.ps1`: spec/impl/task/domain rounds 1→3 with NEEDS_WORK transitions, cap-reached BLOCKED, spec round-3 Minor-only PASS merge; per-leg end state equals inventory `terminal`; pwsh domain leg emits recorded SKIP naming #147 while `domain-review-precheck.ps1` is absent | Planned |
| AC-009 | REQ-003 | TEST-009 | RED differential (regression lock) | impl-review round-2 leg: green at HEAD every CI run; demonstrated red at `2d8c6a5^` via the design.md differential procedure (`git worktree` + `SDD_LOOP_REPO_ROOT` override); failing output recorded in the owning task's implementation report | Planned |
| AC-010 | REQ-003 | TEST-010 | invariant check | every driven round asserts the bidirectional invariant (downstream-required inputs ⊆ upstream-authorized inputs); a synthetic required-but-unauthorized manifest entry turns the check red | Planned |
| AC-011 | REQ-004 | TEST-011 | integration (escalation leg) | `tests/loop-escalation.tests.sh`/`.ps1`: 0/1/2 gate reports → `continue`, 3 → `Escalate-Human` (`check-quality-gate-cycle-limit.sh`); `select-agent-model.sh` escalation output carries expected `next_tier`; terminal-tier-recurrence artifact validates against `contracts/terminal-tier-blocked-state.schema.json`; `check-terminal-tier-resume.sh` denies without and permits with a human approval record | Planned |
| AC-012 | REQ-004 | TEST-012 | parity extension | same suite: `implementation-report.template.md` rendered with real `T-NNN` passes quality:sdd-evaluator identity checks (exact path, heading, full-line `- Task ID:`, `## Outputs`-section scan per INV-014/INV-015); deleting the `- Task ID:` line from the rendered fixture turns red; no assertion duplicated from `tests/template-validator-parity.tests.sh` | Planned |
| AC-013 | REQ-004, REQ-005 | TEST-013 | degradation path | same suite: with python3 removed from a restricted PATH, the leg observes `deterministic-runtime-unavailable` (INV-017) and reports a named SKIP-with-reason, not silent green or unrelated failure | Planned |
| AC-014 | REQ-005 | TEST-014 | twin / parity audit | every new file has an `.sh`/`.ps1` twin; existing `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh` pass over the new files; CI 3-OS matrix runs both lanes | Planned |
| AC-015 | REQ-005 | TEST-015 | degradation conformance | all new suites use recorded SKIP-with-reason for unsupported host/runtime capabilities (pwsh absent, python3 absent, #147 gap); Codex-side degradation notes present in the docs updated under REQ-006 | Planned |
| AC-016 | REQ-006 | TEST-016 | document conformance | same-PR doc updates for affected docs; `CHANGELOG.md` `## Unreleased` cites #141/#142/#143/#144; `validate-repository` and skill-reference count sync green; no manual version bump (release via `scripts/bump-version.sh` only) | Planned |

Notes:

- Every suite is red-demonstrable: TEST-001, TEST-002, TEST-007, TEST-010,
  and TEST-012 embed negative self-checks that run the verification against
  a mutated temporary copy and assert failure inside the normally-green run;
  TEST-009 is the one-time recorded RED differential against `2d8c6a5^`.
- `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  and `tests/constant-parity.tests.sh` are enforcement-chain protected files;
  all new coverage lands in the new, unprotected suites named above, so the
  agent can author them directly (same convention as epic-136-phase1-guards).
- Fixtures are synthetic and mktemp-scoped; no test writes a real repo path,
  invokes sdd-sudo, or emits an approval string (security-spec.md).
- This is test-infrastructure work with no user-facing entry point; the UI
  integration checklist is not applicable.
