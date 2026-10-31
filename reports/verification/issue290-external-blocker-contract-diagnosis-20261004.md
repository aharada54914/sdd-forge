# Issue #290 external Blocked-state contract diagnosis (2026-10-04)

Status: diagnosis and repair candidate only; no gate implementation, task status, reviewer result, or frozen artifact changed.

## Symptom and bounded RED evidence

T-001 has an actual external execution refusal, not a dependency on another `T-NNN`. The current reviewed plan has `Status: In Progress` and `### Blockers` = `None`. Two local, reverted probes of only those fields establish the contradiction:

1. Set `Status: Blocked` but retain `### Blockers` = `None`; run `bash plugins/sdd-quality-loop/scripts/check-task-state.sh specs/sdd-domain-concept-test/tasks.md`. Exit 1: `T-001 is Blocked but ### Blockers section has no content (not None or empty)`.
2. Set `Status: Blocked` and put the actual external refusal as prose under `### Blockers`; run `bash plugins/sdd-review-loop/scripts/task-review-precheck.sh sdd-domain-concept-test 5 1 --provenance-rereview`. Exit 1: `T-001 Blockers has invalid format: ...` and `Blockers format is invalid`.

Both probes were reverted; they are not claims of a passing formal round. They test the exact T-001 transition needed before starting an independent Approved task. No protected refusal was retried through another tool or host.

## Root cause and contract evidence

- `plugins/sdd-quality-loop/scripts/check-task-state.sh:16,178-182` and `plugins/sdd-quality-loop/scripts/check-task-state.ps1:212-216` require nonempty `### Blockers` content for `Blocked`, but do not distinguish external reasons from task dependencies. The MCP state parser mirrors this at `mcp/sdd-forge-mcp/src/parsers/task-validation.ts:93-103`.
- `plugins/sdd-review-loop/scripts/task-review-precheck.sh:264-291` accepts only `None` or comma-separated `T-NNN` values, and converts IDs to dependency-graph edges. Its PowerShell twin has the same ID-only rule. `plugins/sdd-review-loop/agents/task-reviewer-a.md:120-130` and `plugins/sdd-review-loop/references/phase-review-checklist.md:824-844` prohibit prose there.
- Existing state-checker regressions explicitly pass prose under Blockers (`tests/scripts.tests.ps1:945-953`; shell parity at `:1192-1194`). MCP has a similar test at `mcp/sdd-forge-mcp/tests/parser/field-validation.test.ts:164-190`. Those fixtures are individually green but incompatible with the task-review contract.
- The current parsers keep collecting Blockers through any `###` subsection until a `##` section or a recognized top-level field. Thus merely appending a new `### Blocked Reason` heading would falsely count its text as Blockers; the parser boundary must change as part of the repair (`check-task-state.sh:72-85`, PowerShell counterpart `:49-88`, MCP `parsers/tasks.ts:118-150`).

The cause is incompatible field ownership: a single `Blockers` section serves both a dependency graph and an unconstrained stop reason.

## Minimal repair candidate (not applied)

Final candidate: `reports/verification/issue290-external-blocker-contract-final-20261004.patch` is a genuine unified diff fixed to the current source bytes. `git apply --check` returned exit 0 on 2026-10-04; no patch was applied, no protected target was written, and no runtime test or formal review was run. Earlier `...-candidate-20261004.patch` and `...-unified-20261004.patch` are superseded drafts, not the recommended candidate.

Proposed specification addendum (not yet a passed specification): `Blockers` represents only inter-task prerequisites (`None` or canonical T-ID list) and is the sole input to the dependency graph. `Blocked Reason` represents an external/non-task stop cause, is a single nonempty line on the same T-NNN record, and never creates an edge. A Blocked task needs either at least one valid dependency or a reason. `None`, whitespace, and marker-only (`-`, `*`, `#`) are not reasons. A Planned or In Progress task may omit the reason. T-001's actual refusal belongs in this field and in its implementation addendum, with `Blockers` still `None`. This proposed contract needs a formal feature/task amendment and re-review before being relied upon as a passed gate.

1. Keep `### Blockers` strictly `None` or comma-separated task IDs. Do not reinterpret prose as an edge, insert a fictional T-ID, remove the dependency-cycle check, or let `Blocked + None` pass without a documented cause.
2. Add an independent, single-line `Blocked Reason: <nonempty external cause>` field to the task record. A `Blocked` task passes state validation iff it has a nonempty canonical T-ID blocker list **or** a nonempty Blocked Reason; `Blocked + None + empty/missing reason` still fails. The reason is not a dependency edge. An in-progress task may leave it absent.
3. Implement the same parsing/validation in the full shell/PowerShell state checkers and the MCP state consumer. These consume the #290 full-SDD task; lite checkers do not, so the final candidate leaves them unchanged. In the three actual consumers, terminate `### Blockers` collection at the next `###` heading or recognized top-level field; parse `Blocked Reason:` independently. The MCP `blockersNonEmpty` field remains the raw Blockers-section presence flag for compatibility; it must not be used as a dependency graph without task-review validation. No public MCP schema addition is needed for the reason itself.
4. Add cross-runtime RED fixtures: (a) `Blocked + None + reason` passes state but preserves an empty dependency set and passes task-review precheck; (b) `Blocked + None + no reason` fails; (c) `Blocked + T-002 + no reason` passes (with a real T-002); (d) prose under Blockers still fails task-review; (e) heading text, blank, `None`, or marker-only reason fails. Replace the current prose-under-Blockers positive fixtures with the separate reason form. Run shell, PowerShell, MCP, and precheck suites for parity.
5. Only after the repair is admitted through the protected-file workflow, amend the T-001 task-plan body to record the external reason while preserving its original dependency `None` and the actual refusal in the non-frozen implementation report. Because the task plan body is hash-bound, a new task-stage provenance review must bind this amendment. The human Approval field remains untouched. Then set `Status: Blocked`, verify both gates, and only then consider T-005's ordinary preflight.

### Regression candidates and expected checks

| Fixture | State checker | Task-review precheck | Dependency graph |
|---|---|---|---|
| `Blocked`, `Blockers=None`, `Blocked Reason=external host refused execution` | PASS | PASS | no edge |
| `Blocked`, `Blockers=None`, no reason | FAIL | PASS | no edge |
| `Blocked`, `Blockers=None`, reason empty/`None`/marker-only | FAIL | PASS | no edge |
| `Blocked`, `Blockers=T-002`, no reason, with real T-002 node | PASS | PASS | one edge to T-002 |
| `Blocked`, prose under `Blockers`, no reason | Existing checker behavior until separately tightened | FAIL | no accepted graph |
| `Blocked`, `Blockers=None`, reason after an unrelated `###` heading | PASS only when the field belongs to that task | PASS | no edge |

The final candidate changes `tests/scripts.tests.ps1:925-953,1188-1194` for full shell/PowerShell parity, `mcp/sdd-forge-mcp/tests/parser/field-validation.test.ts:136-190` for MCP parity, and `tests/task-review-precheck.tests.sh:100-130` to prove the new field is ignored by the graph precheck. The old prose-under-Blockers positive fixture is replaced, not accepted as proof of the new joint contract. No post-repair GREEN check has been run.

## Scope and stop condition

The protected gate scripts and test files have a recorded real PreToolUse refusal in `reports/verification/issue290-t001-red-blocked-handoff-20261002.md:10-15`. This diagnosis does not treat a patch file, local RED, or static review as permission to bypass that refusal or as formal PASS. The required next implementation is a separately admitted workflow repair with its own spec/task approval and independent review; until then T-001 remains `In Progress` and T-005 has not started.
