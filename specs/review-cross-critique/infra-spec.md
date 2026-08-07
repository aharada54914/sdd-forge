# Infrastructure Spec: review-cross-critique

## CI/CD Sequence

**No new CI step is planned, and no CI file is edited.**
`.github/workflows/test.yml` is on `PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`), so an agent
cannot write it. The plan avoids requiring a workflow change for exactly that
reason; if one turns out to be needed, it becomes a `human-copy/` staging item
alongside the six protected targets in `design.md`'s Components table
(OQ-15).

The existing `test` job is authoritative. `tests/run-all.sh` is the registration
point for new suites and runs on a 3-OS matrix, so the AC-001 … AC-021 cases are
picked up by registering there. The PowerShell legs of the suite run on the
Windows leg of that matrix.

Sequence at merge time:

1. `test` job, 3-OS matrix — `tests/run-all.sh`, now including the new suite.
2. No `dist/` rebuild step applies. This feature changes shell, PowerShell,
   Markdown and JSON only; there is no esbuild bundle in scope, so ADR-0003's
   same-commit rebuild obligation does not attach and `git diff --exit-code --
   dist/` is not a leg of any acceptance criterion.
3. No `npm audit` interaction. No package manifest or lockfile is touched.

### Two CI-specific hazards this feature actually has

**Cross-runtime legs that only ever run on one OS.** AC-009 requires four
independent derivations of the merged verdict to agree, and two of them
(`spec-review-precheck.ps1`, `check-workflow-state.ps1`) execute only on the
Windows leg. AC-017 has the same shape. A green Linux run therefore proves half
of two acceptance criteria. This is called out here because a PowerShell-only
regression is invisible until the Windows leg runs, and the repository's recorded
case-sensitivity defect class (WFI-012, `AGENTS.md:174-188`) lives in exactly
that gap.

**Newly-reachable SKIP branches (BL-008, `AGENTS.md:224-236`, WFI-015).** Several
planned cases are conditionally gated today: TEST-013a–d cannot execute until a
Codex reviewer role exists (OQ-12), and TEST-019b executes only where PowerShell
is available. If this delivery changes a condition such that a previously-SKIPped
branch newly executes for real — a CI runner's actual OS, or a first real run
rather than a fixture — the implementation report must name the branch and the
environment and either exercise it in a matching environment before merging or
flag it explicitly as pending first real execution.

**Timing.** Every planned case drives fixture artifacts and local scripts. No case
waits on a network, a vendor CLI, or a credential, so no case contributes
unbounded wall-clock to the job. Cases that launch real reviewer agents (AC-001's
launch and reservation counts) are the exception in cost terms and should be
scoped to the smallest fixture that still exercises a full round.

## Deployment Topology

Nothing is deployed. The changed artifacts are:

| Artifact | Consumed by | Distribution |
|---|---|---|
| `sdd-review-loop` SKILL files | read by the orchestrating agent at invocation | shipped inside the plugin, no build step |
| `sdd-review-loop` reviewer role files | read by the host when spawning a reviewer | same; four of six are guard-protected |
| `validate-review-context-set.{sh,ps1}` | run by the orchestrator before every reviewer launch | shipped inside `sdd-quality-loop`, no build step |
| `{spec,impl,task}-review-precheck.{sh,ps1}` | run by the orchestrator at round open and before each launch | same |
| `check-workflow-state.{sh,ps1}` | run as the persisted-state validator | same |
| `review-context-boundary.md` and the calibration references | hash-bound reviewer inputs | same |
| the new test suite | `tests/run-all.sh` | repository-only, not shipped |

There is no service, no container, no IaC resource, and no external endpoint.

**The one piece of persistent state this feature grows.**
`reports/review-context/identity-ledger.json` is append-only and chain-verified
(`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:239-258`), with
globally unique `run_id` and `host_session_id` per record (`:234-235`). Every
cross-critique participant launch appends one record. That is intended on a
triggering round; on a **non-triggering** round the count must be exactly two,
which is AC-001's assertion and the only cost contract this feature can offer,
since no cost telemetry exists anywhere in the review loop (INV-021).

A design that reserves an identity before deciding whether to fire will grow the
ledger on every routine run. Those orphan records are legitimate and no existing
gate flags them (`plugins/sdd-review-loop/references/review-context-boundary.md:90-101`),
so nothing except AC-001 would catch it.

## Rollback

The change is additive to gate control flow and additive to orchestration prose,
so a revert is mechanically complete — but it is **not** uniformly safe, and the
asymmetry is the point of this section.

**Revertible cleanly:** the test suite, the orchestration prose in the three
SKILL files, the reviewer role text, and the calibration/boundary reference
updates. Nothing parses them mechanically, so reverting them breaks nothing at
runtime.

**Revertible with a caveat:** any change to `validate-review-context-set.{sh,ps1}`,
the three prechecks, or `check-workflow-state.{sh,ps1}`. These validate
*persisted* evidence. Round evidence written while the new code was in place may
carry artifacts or field sets the reverted validators do not recognise, and
replay is forbidden (`spec-review-precheck.sh:138`, `:314`) so a round cannot
simply be re-run in place. A revert therefore needs a stated position on
in-flight evidence: either the affected attempts are reset (`--reset`, which
requires a terminal PASS or BLOCKED contract, `spec-review-precheck.sh:290-299`),
or the reverted validators must tolerate the newer artifacts. This must be
decided at delivery, not discovered during an incident.

**Ordering constraint.** The five enforcement layers must revert together, for
the same reason they must land together (REQ-003, AC-007). Reverting the
agent-writable half (L3 validator, L4 prechecks, L5 calibration) while the
human-applied half (L1 role prose, L2 capability frontmatter in the four
protected role files) stays forward leaves the role text permitting what the gate
again forbids — the mirror image of the live drift recorded as INV-023. Because
the protected half can only move at human speed, a partial revert is the
*default* outcome unless it is planned against.

**Partial rollback direction.** Test-suite-only and documentation-only reverts
are safe in isolation. A revert of the enforcement layers without the prose, or
of the prose without the enforcement, is not.

No state, cache, or build artifact persists across the revert beyond the identity
ledger, which is append-only by design and is not rewritten by a revert.
