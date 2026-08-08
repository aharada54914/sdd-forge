# Traceability: mcp-readonly-preflight

Authored at Phase 2, alongside `tasks.md`. Every row below is transcribed
from `requirements.md` and `acceptance-tests.md`; no mapping is invented
here. **AC-003 is intentionally vacant** (retired in the sweep-4 expansion;
`requirements.md` REQ-003, `acceptance-tests.md`'s own "AC-003 is
intentionally vacant" note) and is deliberately absent from every table
below, exactly as those two source documents state — its absence is a
recorded decision, not a gap.

## Requirement Coverage

The Layer Spec column names the layer document that carries this
requirement's normative refinement, by anchor. Anchors are derived from
`security-spec.md`'s and `infra-spec.md`'s own heading text using this
repository's existing anchor convention (matching the exact anchor form
`specs/epic-136-phase4-docs/traceability.md` already uses for its own
`security-spec.md#b3--…` citations), not invented independently.
`N/A — cross-layer only` is used where a requirement has no single owning
layer, with the reason stated rather than left blank.

| Requirement | Summary | Layer Spec | AC | Test ID | Task |
|---|---|---|---|---|---|
| REQ-001 | `bootstrap` performs a read-only, advisory MCP preflight probe near the start of the run | security-spec.md#b1--the-agent--mcp-server-process-boundary-stream-a | AC-001 | TEST-001 | T-001 |
| REQ-002 | `ship` performs the same read-only, advisory MCP preflight probe | security-spec.md#b1--the-agent--mcp-server-process-boundary-stream-a | AC-002 | TEST-002, TEST-003 | T-002 |
| REQ-003 | The probe instruction is runtime-agnostic — no dependency on any registration surface | security-spec.md#b1--the-agent--mcp-server-process-boundary-stream-a | AC-004, AC-005, AC-006, AC-007 | TEST-004, TEST-005, TEST-006, TEST-007 | T-001, T-002 |
| REQ-004 | The file-based flow is reachable, with no error surfaced as a failure, when the probe cannot be performed | security-spec.md#b1--the-agent--mcp-server-process-boundary-stream-a | AC-008, AC-009, AC-010, AC-011 | TEST-008, TEST-009, TEST-010, TEST-011 | T-001, T-002 |
| REQ-005 | The probe cannot change the outcome; on divergence the disagreement is reported and the file-based conclusion governs | security-spec.md#b2--the-workflows-decision-authority-stream-a | AC-012, AC-013, AC-027a, AC-027b | TEST-012, TEST-013, TEST-027a, TEST-027b | T-001, T-002 |
| REQ-006 | No write capability is added to any MCP server — a preservation obligation, not a construction one | security-spec.md#b2--the-workflows-decision-authority-stream-a | AC-014, AC-015, AC-016 | TEST-014, TEST-015, TEST-016 | T-005 |
| REQ-007 | The dual-runtime probe→fallback obligation is verified on both Claude Code and Codex | infra-spec.md#cicd-sequence | AC-017, AC-018, AC-019, AC-020 | TEST-017, TEST-018, TEST-019, TEST-020 | T-001, T-002 |
| REQ-008 | `USERGUIDE.md` states the advisory / no-auto-advance and no-write-tools policy | security-spec.md#b4--the-documentation-as-a-capability-inventory-stream-b | AC-021, AC-022 | TEST-021, TEST-022 | T-003 |
| REQ-009 | `README.md` states the same two claims | security-spec.md#b4--the-documentation-as-a-capability-inventory-stream-b | AC-023, AC-024 | TEST-023, TEST-024 | T-004 |
| REQ-010 | The staged protected-file change (`ship/SKILL.md` human-copy candidate) is conformant | security-spec.md#b3--the-protected-file-boundary-stream-a | AC-025, AC-026 | TEST-025, TEST-026 | T-002 |
| REQ-011 | Existing consumers stay green — `tests/workflow-documentation.tests.sh` passes unmodified | infra-spec.md#cicd-sequence | AC-027 | TEST-027 | T-001, T-004 |

**Anchor note.** REQ-001 through REQ-004 all cite `security-spec.md#b1`
because that boundary's own text and STRIDE table directly name each of
them: B1's prose states the probe crosses no new trust boundary and reads
the fourteen-tool read-only guarantee; the STRIDE table's B1 Denial-of-
Service row cites REQ-004 by name. REQ-005 and REQ-006 both cite
`security-spec.md#b2` because the STRIDE table attributes both the
Elevation-of-Privilege row (REQ-005) and the Tampering/write-tool row
(REQ-006) to boundary B2 explicitly, not because the two requirements share
subject matter. These are the anchors the layer documents' own text
supports, not a convenience simplification.

`ux-spec.md` and `frontend-spec.md` are recorded N/A for this feature and
are therefore not cited above. That N/A is justified rather than assumed:
the feature edits two skill Markdown documents (instructional text an agent
reads, not code), two human-facing Markdown documents, and (conditionally)
a staged human-copy candidate plus its manifest — no rendered, interactive,
or bundled artifact exists anywhere in it, and `design.md`'s own Data Plan
confirms the probe writes no file and leaves no artifact.

## Acceptance Mapping

| AC | Test ID | Test Type | Target | Task |
|---|---|---|---|---|
| AC-001 | TEST-001 | integration (real file read) | `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | T-001 |
| AC-002 | TEST-002 | integration (real file read) | ship's probe-carrying artifact | T-002 |
| AC-002 | TEST-003 | integration (guard/provenance) | live `plugins/sdd-ship/skills/ship/SKILL.md` | T-002 |
| AC-004 | TEST-004 | unit (literal-absence, both skills) | both skills | T-001, T-002 |
| AC-005 | TEST-005 | unit (literal-absence, both skills) | both skills | T-001, T-002 |
| AC-006 | TEST-006 | unit (literal-absence, both skills) | both skills | T-001, T-002 |
| AC-007 | TEST-007 | unit (literal-absence, both skills) | both skills | T-001, T-002 |
| AC-008 | TEST-008 | integration (no MCP registered) | `bootstrap` | T-001 |
| AC-009 | TEST-009 | integration (registered, call fails) | `bootstrap` | T-001 |
| AC-010 | TEST-010 | integration (no MCP registered) | `ship` | T-002 |
| AC-011 | TEST-011 | integration (registered, call fails) | `ship` | T-002 |
| AC-012 | TEST-012 | integration (differential) | `bootstrap` | T-001 |
| AC-013 | TEST-013 | integration (differential) | `ship` | T-002 |
| AC-014 | TEST-014 | unit (static, tool registry) | `mcp/sdd-forge-mcp/src/server.ts` | T-005 |
| AC-015 | TEST-015 | unit (static, tool registry) | `mcp/local-env-mcp` | T-005 |
| AC-016 | TEST-016 | unit (static, tool registry + HTTP method) | `mcp/ci-mcp` | T-005 |
| AC-017 | TEST-017 | runtime exercise (Claude Code) — method open, OQ-009 | both skills | T-001, T-002 |
| AC-018 | TEST-018 | runtime exercise (Claude Code) — method open, OQ-009 | both skills | T-001, T-002 |
| AC-019 | TEST-019 | runtime exercise (Codex) — method open, OQ-009 | both skills | T-001, T-002 |
| AC-020 | TEST-020 | runtime exercise (Codex) — method open, OQ-009 | both skills | T-001, T-002 |
| AC-021 | TEST-021 | integration (real file read) | `USERGUIDE.md` | T-003 |
| AC-022 | TEST-022 | integration (real file read) | `USERGUIDE.md` | T-003 |
| AC-023 | TEST-023 | integration (real file read) | `README.md` | T-004 |
| AC-024 | TEST-024 | integration (real file read) | `README.md` | T-004 |
| AC-025 | TEST-025 | integration (hash conformance) | `specs/mcp-readonly-preflight/human-copy/` | T-002 |
| AC-026 | TEST-026 | integration (hash conformance) | live ship SKILL.md | T-002 |
| AC-027 | TEST-027 | regression | `tests/workflow-documentation.tests.sh` | T-001, T-004 |
| AC-027a | TEST-027a | integration (probe/file divergence) | both skills | T-001, T-002 |
| AC-027b | TEST-027b | integration (probe/file divergence) | both skills | T-001, T-002 |

Twenty-eight live ACs (`AC-003` vacant, per `design.md`'s own count:
"Twenty-eight live ACs, twenty-nine TEST rows"), twenty-nine TEST rows
(AC-002 alone carries two — TEST-002 and TEST-003), every one claimed by at
least one task above. The mapping was produced by a mechanical sweep of
every `AC-` and `TEST-` identifier in `requirements.md` and
`acceptance-tests.md`, not by reading the task list and writing down what it
appeared to cover — the reverse direction is exactly how `epic-136-phase4-docs`
lost AC-013 and AC-012 from its design plan and cost that feature's impl
review a BLOCKED attempt.

## Task Mapping

| Task | Requirements | Stream | Touches |
|---|---|---|---|
| T-001 | REQ-001, REQ-003 (bootstrap leg), REQ-004 (bootstrap leg), REQ-005 (bootstrap leg), REQ-007 (bootstrap leg), REQ-011 | A (#129 probe) | `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` |
| T-002 | REQ-002, REQ-003 (ship leg), REQ-004 (ship leg), REQ-005 (ship leg), REQ-007 (ship leg), REQ-010 | A (#129 probe) | `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`, `specs/mcp-readonly-preflight/human-copy/MANIFEST.sha256` (agent); live `plugins/sdd-ship/skills/ship/SKILL.md` (human, separate commit) |
| T-003 | REQ-008 | B (#129 policy) | `USERGUIDE.md` |
| T-004 | REQ-009, REQ-011 | B (#129 policy) | `README.md` |
| T-005 | REQ-006 | Preservation (#129 write-tool obligation) | none — verification-only; reads `mcp/sdd-forge-mcp`, `mcp/local-env-mcp`, `mcp/ci-mcp` source |

Three requirements (REQ-003, REQ-004, REQ-005, REQ-007) are split across
T-001 and T-002 by **skill**, not by acceptance criterion — mirroring how
`epic-136-phase4-docs` split its own cross-runtime requirements by
*runtime* rather than by AC. No AC is half-satisfied by one task and half
by the other: `requirements.md` REQ-003 itself states each of AC-004…AC-007
"is asserted independently against **both** skills," so both tasks
independently satisfy the full AC for their own skill, and the AC is only
fully closed once both tasks are Done.

**Task independence, stated plainly.** Unlike `epic-136-phase4-docs`, no
two tasks above share a committed test-suite file (this feature adds none;
`tests/workflow-documentation.tests.sh` is touched only as a read-only
regression check, never edited), so there is no shared-artifact
serialization requirement and every task above carries `Blockers: None` in
`tasks.md`. The one real ordering constraint in this feature — T-002's
human-applied second commit — is a **handoff**, not a task dependency: no
other task's Done-When depends on that commit having landed.

## Baseline Constraints

| Constraint | Where it is checked | Task |
|---|---|---|
| BL-001 — no `mcp/` server implementation changes | verified by diff (T-001–T-004: no `mcp/` file touched at all); actively read (never written) by T-005 | all |
| BL-002 — existing file-based flows preserved exactly | `bootstrap`'s and `ship`'s Preconditions/Routing/Step-1 meaning and outcome unchanged; enforced as a landing condition in `tasks.md` Global Constraints | T-001, T-002 |
| BL-003 — existing read-only prose preserved | verified by diff against the cited line ranges in `README.md` / `USERGUIDE.md` | T-003, T-004 |
| BL-004 — `ship/SKILL.md` never written by an agent | staged human-copy candidate only, live path diffed/provenance-checked, never opened for write | T-002 |
| BL-005 — `specs/mcp-readonly-preflight/` registered in `specs/workflow-state-registry.json` | **already satisfied** at task-authoring time (grep-confirmed; see `tasks.md` Predecessor Gate Status) — no task adds or edits a registry entry | none (pre-existing) |
