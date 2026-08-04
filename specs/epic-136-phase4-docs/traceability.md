# Traceability: epic-136-phase4-docs

Authored at Phase 2, alongside `tasks.md`. Every row below is transcribed from
`requirements.md` and `acceptance-tests.md`; no mapping is invented here.

## Requirement Coverage

The Layer Spec column names the layer document that carries this requirement's
normative refinement, by anchor. `N/A — cross-layer only` is used where a
requirement has no single owning layer, with the reason stated rather than left
blank.

| Requirement | Summary | Layer Spec | AC | Test ID | Task |
|---|---|---|---|---|---|
| REQ-001 | The policy document states a complete panelist failure taxonomy, including the mode nobody wrote down: a CLI that neither succeeds nor exits | security-spec.md#b3--the-threat-model-as-a-control-inventory-stream-b-134 | AC-001, AC-002 | TEST-001, TEST-002 | T-003 |
| REQ-002 | Every panelist invocation is bounded in wall-clock time, configurable via `SDD_PANELIST_TIMEOUT`, default 600s | security-spec.md#b1--the-vendor-cli-process-boundary-stream-a-133 | AC-003, AC-004 | TEST-003, TEST-004 | T-001, T-002 |
| REQ-003 | A timeout is fail-closed and indistinguishable downstream from a CLI error: exit 1, no verdict file, gate fails | security-spec.md#b2--the-cross-model-consensus-as-an-assurance-signal-stream-a-133 | AC-005, AC-006 | TEST-005, TEST-006 | T-001 |
| REQ-004 | The threat model carries an OWASP LLM Top 10 mapping and an MCP server cross-reference | security-spec.md#b3--the-threat-model-as-a-control-inventory-stream-b-134 | AC-007, AC-008, AC-013 | TEST-007, TEST-008, TEST-013 | T-004 |
| REQ-005 | The threat model documents the five absent runtime trust surfaces, including the hook-trust bypass and this release's own closed residual risk | security-spec.md#b4--the-hook-trust-surface-the-threat-model-omits-stream-b-134 | AC-009, AC-010, AC-014 | TEST-009, TEST-010, TEST-014 | T-005 |
| REQ-006 | Both test suites gain the cases, pass unmodified alongside their existing ones, and assert the default from its source rather than a copy | infra-spec.md#cicd-sequence | AC-011, AC-012 | TEST-011, TEST-012 | T-001, T-002 |

`ux-spec.md` and `frontend-spec.md` are recorded N/A for this feature and are
therefore not cited above. That N/A is justified rather than assumed: the feature
ships four CLI scripts and two Markdown documents, with a single stderr
diagnostic line as its only human-perceivable surface — no rendered, interactive,
or bundled artifact exists anywhere in it.

## Acceptance Mapping

| AC | Test ID | Test Type | Target | Task |
|---|---|---|---|---|
| AC-001 | TEST-001 | integration (real file read) | `cross-model-verification-policy.md` | T-003 |
| AC-002 | TEST-002 | integration (real file read) | same | T-003 |
| AC-003 | TEST-003 | unit (stub CLI, 7 sub-cases) | 4 runners | T-001, T-002 |
| AC-004 | TEST-004 | integration (stub CLI, real process) | 4 runners | T-001, T-002 |
| AC-005 | TEST-005 | integration (stub CLI) | 4 runners | T-001, T-002 |
| AC-006 | TEST-006 | integration (composed with the gate) | runner then `check-cross-model` | T-001 |
| AC-007 | TEST-007 | integration (real file read) | `docs/THREAT-MODEL.md` | T-004 |
| AC-008 | TEST-008 | integration (real file read) | same | T-004 |
| AC-009 | TEST-009 | integration (real file read) | same | T-005 |
| AC-010 | TEST-010 | integration (real file read) | same | T-005 |
| AC-011 | TEST-011 | regression | `tests/cross-model.tests.{sh,ps1}` | T-001, T-002 |
| AC-012 | TEST-012 | unit | test suites | T-001, T-002 |
| AC-013 | TEST-013 | integration (real file read) | `docs/THREAT-MODEL.md` | T-004 |
| AC-014 | TEST-014 | integration (real file read) | same | T-005 |

All 14 acceptance criteria and all 14 tests are claimed by at least one task. The
mapping was produced by a mechanical sweep of every `AC-` and `TEST-` identifier
in `requirements.md` and `acceptance-tests.md`, not by reading the task list and
writing down what it appeared to cover — that reverse direction is exactly how
AC-013 and AC-012 went missing from the design plan and cost impl review a
BLOCKED attempt.

## Task Mapping

| Task | Requirements | Stream | Shares |
|---|---|---|---|
| T-001 | REQ-002 (POSIX legs), REQ-003, REQ-006 (POSIX legs) | A (#133) | `tests/cross-model.tests.sh` |
| T-002 | REQ-002 (PowerShell legs), REQ-003 (PowerShell leg), REQ-006 (PowerShell legs), BL-004 | A (#133) | `tests/cross-model.tests.ps1` |
| T-003 | REQ-001 | A (#133) | both test suites |
| T-004 | REQ-004 | B (#134) | `docs/THREAT-MODEL.md`, both test suites |
| T-005 | REQ-005 | B (#134) | `docs/THREAT-MODEL.md`, both test suites |

Three requirements are split across two tasks rather than owned by one, because
BL-004 requires the same behaviour in two runtimes and this plan does not land
both in a single commit. The split is by runtime, never by acceptance criterion:
no AC is half-satisfied by T-001 and half by T-002. Each runtime's legs are
independently checkable in its own suite.

The one asymmetry is deliberate and is recorded here so it is not later read as a
coverage gap: **TEST-004 sub-case (b) exists in the POSIX suite only.** The
PowerShell termination step cannot be trapped, so a (b) case there would be a
test that cannot fail. BL-004 parity is satisfied at the level of outcome — both
runtimes end the child and leave no orphan — not by mirroring a POSIX signal
model onto a platform that has no equivalent.

## Baseline Constraints

| Constraint | Where it is checked | Task |
|---|---|---|
| BL-001 behaviour preservation on the absent/error path | every pre-existing suite case passes unmodified | T-001, T-002 |
| BL-002 `check-cross-model` untouched | verified by diff, not assertion | T-001 |
| BL-003 existing policy text intact | verified by diff against the cited line ranges | T-003 |
| BL-004 dual-runtime parity at outcome level | the two suites, with the one stated (b) exception | T-002 |
| BL-005 no protected gate file written | re-verified against `PROTECTED_GATE_SUFFIXES` at task-authoring time; see tasks.md Protected Files | all |
