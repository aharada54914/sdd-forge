# Acceptance Tests: epic-159-pillar-a2

TEST IDs (TEST-001..TEST-019) are namespaced to this feature
(`specs/epic-159-pillar-a2/`) and do not collide with epic-159-pillar-a's
own TEST-001..TEST-018 (different spec folder, different suite files,
different CI step names — design.md Test Strategy).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | integration (real script) | `tests/hitl-wfi-terminal.tests.sh`/`.ps1`: `hitl-loop.template.sh` copied to a fixture, `CHECK` stub never returns true, 5 lines of piped stdin; asserts 5 iterations, exit 0, terminal string `loop finished without reproducing (5 iterations)` | Planned |
| AC-002 | REQ-001 | TEST-002 | negative-branch canary | same suite: `CHECK` returns 0 on iteration 3; asserts exit 1, `RED: symptom reproduced on iteration 3`, proving the harness observes the non-terminal branch (also guards against a broken `CHECK` wiring silently passing TEST-001 for the wrong reason) | Planned |
| AC-003 | REQ-001 | TEST-003 | reference-check / drift lock | same suite: `assert_wfi_audit_transition` applies the documented one-directional rule `Audit-Attempt >= 3 -> Audit-Status: Human-Blocked` (SKILL.md:44-50, 119-135, 186-203) to fixture-scoped WFI-NNN.md copies across attempt 0→1→2→3 (below the threshold the synthetic sweep asserts `Not-Started`, the state STEP 4/7 literally prescribe for a BLOCKED verdict); negative self-check mutates the threshold in a temp copy and asserts red | Planned |
| AC-004 | REQ-001 | TEST-004 | construction proof | same suite: a grep-based self-check over every new file in this feature asserts no `gh` invocation exists anywhere; the WFI-audit fixture's `Category:` field is never `plugin-improvement`, making SKILL.md STEP 8 unreachable by construction | Planned |
| AC-005 | REQ-001 | TEST-005 | reference smoke (real data) | same suite: fixture-scoped, read-only copies of `docs/workflow-improvements/WFI-010.md` and `WFI-011.md` are parsed; each recorded Audit-Attempt/Audit-Status pair (an absent `Audit-Attempt:` field is treated as 0) is asserted to satisfy the one-directional invariant (`Audit-Attempt >= 3` implies `Audit-Status == Human-Blocked`; `Audit-Attempt < 3` implies `Audit-Status != Human-Blocked`, permitting `Not-Started`/`Cycle-1-In-Progress`/`Cycle-2-In-Progress`/`Human-Pending` — SKILL.md:34-43, 61-65, INV-005/INV-006); the suite asserts the SHA-256 of the real `docs/workflow-improvements/WFI-010.md` and `WFI-011.md` is unchanged before vs. after the suite run | Planned |
| AC-006 | REQ-001, REQ-005 | TEST-006 | configuration conformance + runtime budget | same suite: self-registration grep against `tests/run-all.sh`/`.ps1`/`.github/workflows/test.yml` (mirrors `tests/second-approval-mask.tests.sh:285-289`); wall-clock measured via `tests/lib/loop-driver.sh`'s `assert_runtime_budget`/`LOOP_SUITE_BUDGET_SECONDS=300`, printed in the summary line, self-FAILs above 300s; threshold-0 negative self-check proves the assertion is live | Planned |
| AC-007 | REQ-002 | TEST-007 | fixture existence + integration | `tests/fixtures/loops/brownfield-seed/` committed with all three documented categories; `loop_fixture_init brownfield <feature>` with `LOOP_FIXTURE_SEED` pointed at it succeeds and the seed content is present verbatim under `$LOOP_FIXTURE_ROOT` | Planned |
| AC-008 | REQ-002 | TEST-008 | behavior lock (positive) | `tests/check-placeholders-brownfield.tests.sh`/`.ps1`, Case A: `check-placeholders.sh`/`.ps1` invoked with only the seed's changed files (excluding BOTH marker-bearing files: the `NotImplementedError` base-class file and the `TODO` file) exits 0 | Planned |
| AC-009 | REQ-002 | TEST-009 | behavior lock (negative) | same suite, Case B: `check-placeholders.sh`/`.ps1` invoked with the full seed directory exits 1, detecting the pre-existing markers | Planned |
| AC-010 | REQ-002, REQ-005 | TEST-010 | integration (profile parity) | `tests/loop-consistency.tests.sh`/`.ps1` TEST-008's new brownfield-profile leg: `loop_fixture_init brownfield` seeded from the AC-007 fixture drives spec-review round 1 and matches the same inventory `terminal` the greenfield leg already asserts | Planned |
| AC-011 | REQ-003 | TEST-011 | port completeness | `plugins/sdd-domain/scripts/domain-review-precheck.ps1` exists; accepts `-Attempt`/`-Round`/`-EditSummary`/`-Reset` (no `-Feature`, matching `domain-review-precheck.sh:9`); implements attempt/round bounds, round-1 `--edit-summary` restriction, and the post-approval drift-detection precondition documented as the sdd-domain feature's own AC-014 (`specs/sdd-domain/requirements.md:120`, referenced by `domain-review-precheck.sh:5` — not this feature's AC-014) | Planned |
| AC-012 | REQ-003 | TEST-012 | hygiene | `domain-review-precheck.ps1` added to `tests/guard-ps1-ascii.tests.sh`'s `TARGETS` array; passes zero-non-ASCII-bytes, no-BOM, no-CR-byte checks | Planned |
| AC-013 | REQ-003, REQ-005 | TEST-013 | self-healing (external observable) | `pwsh tests/loop-consistency.tests.ps1` TEST-008's domain leg converts from a named SKIP citing #147 to real, green execution, with zero edits to `tests/loop-consistency.tests.ps1` itself; before/after SKIP count recorded in T-003's implementation report | Planned |
| AC-014 | REQ-004 | TEST-014 | port completeness | `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` exists; accepts `-Feature`/`-Attempt`/`-Round`/`-EditSummary`/`-Reset`; implements feature-slug validation, attempt/round bounds, and the rounds-2/3 non-empty `--edit-summary` rule the `.sh` original implements | Planned |
| AC-015 | REQ-004 | TEST-015 | hygiene | `spec-review-precheck.ps1` added to `tests/guard-ps1-ascii.tests.sh`'s `TARGETS` array; passes the same hygiene checks as AC-012 | Planned |
| AC-016 | REQ-004, REQ-005 | TEST-016 | self-healing (external observable, broad) | `pwsh tests/loop-driver.tests.ps1` TEST-006 AND `pwsh tests/loop-consistency.tests.ps1` TEST-008's spec/impl/task legs all convert from named SKIPs citing #174 to real, green execution, with zero edits to either suite; before/after SKIP counts recorded in T-004's implementation report | Planned |
| AC-017 | REQ-005 | TEST-017 | twin / parity audit | `hitl-wfi-terminal` and `check-placeholders-brownfield` exist as `.sh`/`.ps1` twins from creation; both lanes run on the 3-OS CI matrix; any remaining host/runtime-unsupported capability degrades with a named, reason-carrying SKIP | Planned |
| AC-018 | REQ-001, REQ-002 | TEST-018 | CI resilience conformance | new suites never expand a possibly-empty bash array under `set -u` (INV-029); every new mktemp fixture root uses `pwd -P` (INV-030); all new jq output consumption pipes through `tr -d '\r'` unconditionally (INV-031); any leg driving the real validator (the AC-010 brownfield-profile leg, transitively) goes through `loop_validator_capability_probe`/`loop_validator_skip` (INV-032) | Planned |
| AC-019 | REQ-006 | TEST-019 | document conformance | same-PR doc updates for affected docs; `CHANGELOG.md` `## Unreleased` cites #145/#146/#147/#174; `validate-repository` and skill-reference count sync green; no manual version bump (release via `scripts/bump-version.sh` only) | Planned |

Notes:

- Every suite this feature adds is red-demonstrable at the granularity that
  applies to it: TEST-001/TEST-002 form a positive/negative pair, TEST-003
  and TEST-006 embed explicit negative self-checks, TEST-008/TEST-009 form a
  positive/negative pair, and TEST-013/TEST-016 rely on an externally
  observable SKIP-to-green transition instead of an internal negative
  self-check (design.md Test Strategy item 3) — there is no meaningful way
  to "mutate" a `.ps1` port and re-assert red without reintroducing the
  very gap #147/#174 close, so the RED state that already exists at HEAD
  (the named SKIP) IS the red side of this pair.
- `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  and `tests/constant-parity.tests.sh` are enforcement-chain protected
  files; nothing in this feature touches them.
- Fixtures are synthetic and mktemp-scoped except two read-only copies of
  real `docs/workflow-improvements/*.md` files (TEST-005); no test writes a
  real repo path, invokes `gh`, invokes `sdd-sudo`, or emits an approval
  string (security-spec.md).
- This is test-infrastructure and precheck-script work with no user-facing
  entry point; the UI integration checklist is not applicable.
