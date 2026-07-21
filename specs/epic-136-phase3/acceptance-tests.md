# Acceptance Tests: epic-136-phase3

TEST IDs (TEST-001..TEST-023) are namespaced to this feature
(`specs/epic-136-phase3/`) and do not collide with any other spec folder's
own TEST numbering (different suite files — design.md Test Strategy).
TEST-NNN numbers match their AC-NNN counterpart 1:1 (requirements.md
Acceptance Criteria). TEST-012..015 (Stream C) are Planned-but-Blocked: no
suite exists to run them until ADR-0010 unblocks Stream C
(requirements.md OQ-2); they are listed here so Phase 2 task decomposition
inherits complete traceability the moment Stream C unblocks, not so they
can be executed today.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | unit (fixture-driven, real script, PATH-restricted subshell) | `tests/guard-dispatch-fallback.tests.sh`: `python3` present (control) -> `sdd-hook-guard.sh` selects the `.py` branch; decision matches a direct `sdd-hook-guard.py` invocation for the same payload | Planned |
| AC-002 | REQ-001 | TEST-002 | unit (fixture-driven, real script, PATH-restricted subshell) | same suite: `python3` absent + `pwsh` stub present -> `.ps1` branch selected via `pwsh`; decision matches a direct `sdd-hook-guard.ps1` invocation | Planned |
| AC-003 | REQ-001 | TEST-003 | unit (fixture-driven, real script, PATH-restricted subshell) | same suite: `python3`+`pwsh` absent, `powershell.exe` stub present -> `.ps1` branch selected via `powershell.exe`; same decision-parity assertion as TEST-002 | Planned |
| AC-004 | REQ-001 | TEST-004 | unit (fixture-driven, real script, PATH-restricted subshell) | same suite: `python3`+`pwsh`+`powershell.exe` absent, `powershell` stub present -> `.ps1` branch selected via `powershell`; same decision-parity assertion | Planned |
| AC-005 | REQ-001 | TEST-005 | unit (fixture-driven, real script) — 2 named sub-cases | same suite: all four (`python3`,`pwsh`,`powershell.exe`,`powershell`) absent -> `deny_unavailable`; sub-case (a) `--emit exit` returns exit 2; sub-case (b) `--emit copilot` returns a copilot-shaped deny JSON — both sub-cases required, neither may be skipped | Planned |
| AC-006 | REQ-001 | TEST-006 | unit (fixture-driven, real script) — precedence-order proof | same suite: `python3` absent + `pwsh`/`powershell.exe`/`powershell` ALL simultaneously present (each a marker-writing stub) -> only the `pwsh`-named stub's marker is observed, proving `sdd-hook-guard.sh:41`'s iteration order (`pwsh` first) holds under a real `PATH` lookup | Planned |
| AC-007 | REQ-001 | TEST-007 | unit (fixture-driven, real script) — 2 emit modes x 4 fallback branches = 8 named sub-cases | same suite: TEST-002/003/004/006 (every branch reaching the `.ps1` fallback) each re-run under BOTH `--emit exit` and `--emit copilot`; 8 total named assertions (4 branches x 2 emit modes), none combined into a single pass/fail | Planned |
| AC-008 | REQ-002 | TEST-008 | unit (fixture-driven, real script) — 12 named sub-cases | `tests/guard-negative-corpus.tests.sh`: `cd&&rm` R-10 bypass corpus (reused from `guard-cwd-bypass.tests.sh`) denied across 4 runtimes (`.py`,`.js`,`.ps1`, `.sh` dispatcher) x 3 `tool_name` shapes (`Bash`,`exec_command`,`apply_patch`) = 12 named fixture+assertion pairs, each independently reported PASS/FAIL | Planned |
| AC-009 | REQ-002 | TEST-009 | unit (fixture-driven, real script) — 12 named sub-cases | same suite: triple-quote-shaped (`"""`) command-text payload correctly classified (no tokenizer confusion, no read/write misclassification) across the same 4-runtime x 3-tool_name-shape, 12-combination matrix | Planned |
| AC-010 | REQ-002 | TEST-010 | unit (fixture-driven, real script) — 12 named sub-cases + 1 control | same suite: task-id-substring-collision payload (task-id-shaped token adjacent to a protected basename) decided purely on the basename match across the same 12-combination matrix, PLUS 1 control sub-case proving the numeric substring alone (no protected basename present) never triggers a false DENY | Planned |
| AC-011 | REQ-002 | TEST-011 | cross-runtime parity aggregation | same suite: for every payload in TEST-008/009/010, every runtime surface that reached a decision agrees with every other runtime surface for that same payload; a divergence names both disagreeing runtimes in the failure message | Planned |
| AC-012 | REQ-003 | TEST-012 | — Blocked pending ADR-0010 `Status: Accepted` | `tests/workflow-scenarios/` scenario schema: fixture-classification field is exactly `greenfield`\|`brownfield`; all 10 representative classes from issue #125's body have a mapped scenario id (8 referencing existing coverage per investigation.md INV-017, 2 net-new: refactor-baseline-missing, inbound-prompt-injection) | Blocked |
| AC-013 | REQ-003 | TEST-013 | — Blocked, same precondition | same target: scenario PreToolUse payloads driven with both a Claude-Code-shaped `tool_name` (`Edit`/`Write`/`MultiEdit`/`Bash`) and a Codex-shaped `tool_name` (`apply_patch`/`exec_command`/`shell`/`exec`) | Blocked |
| AC-014 | REQ-003 | TEST-014 | — Blocked, same precondition | same target: scenario class 5 (prompt injection) targets the INBOUND direction — a fixture GitHub issue body with adversarial instruction-shaped text, fetched by the named `plugins/sdd-bootstrap` entry point, is proven NOT executed/followed by the reading agent session | Blocked |
| AC-015 | REQ-003 | TEST-015 | — Blocked, same precondition | `tests/workflow-scenarios/` and `tests/scenario.tests.sh` each carry an explicit cross-reference comment naming the other and the scope difference | Blocked |
| AC-016 | REQ-004 | TEST-016 | document/YAML conformance (staged candidate vs. live) | `.github/workflows/test.yml`'s `test` job steps each gain a `[deterministic]` name prefix; the restructuring is staged under `specs/epic-136-phase3/human-copy/.github/workflows/test.yml` with a `MANIFEST.sha256` entry; the LIVE file is confirmed unmodified by the agent at staging time | Planned |
| AC-017 | REQ-004 | TEST-017 | self-check (text-marker technique) — RED-demonstrable | same staged candidate: every step name enumerated from the CURRENT (pre-Stream-D) live `test.yml` is confirmed present (with its `[deterministic]` prefix) in the staged candidate — captured as a fixture list BEFORE the candidate is authored (RED: an intentionally-dropped step name fails this check first, proving the check can catch a real omission; GREEN: the actual candidate passes); `required-checks: needs: [test, cli-hook-enforcement]` membership confirmed unchanged | Planned |
| AC-018 | REQ-004 | TEST-018 | non-regression | `self-improvement.yml` and `model-freshness-check.yml` remain absent from `required-checks`' `needs:` list and from the restructured job boundary — unchanged isolation | Planned |
| AC-019 | REQ-005 | TEST-019 | CI/registration conformance (grep-based self-check) | both new suites (Streams A + B): basename present in `tests/run-all.sh`; absence from `tests/run-all.ps1` reviewed and confirmed as the correct exemption (neither ships a native `.ps1` twin) | Planned |
| AC-020 | REQ-005 | TEST-020 | CI/registration conformance (grep-based self-check) | staged `.github/workflows/test.yml` candidate (the ONE shared batch, Streams A + B + D) contains a CI step for each new suite from Streams A and B; the LIVE file's self-check for each new suite's basename is red until the human-copy commit lands (no staged-candidate fallback) | Planned |
| AC-021 | REQ-006 | TEST-021 | CI resilience conformance (grep/review) | every new `.sh` file (Streams A, B): grep-based self-check confirms no `declare -A` and no unguarded array expansion under `set -u`; this feature adds no new native `.ps1` file (design.md Global Constraints), so the ASCII/BOM/`exit N` sub-check is reviewed as N/A for Streams A/B and deferred to Stream C once unblocked | Planned |
| AC-022 | REQ-006 | TEST-022 | document conformance | `CHANGELOG.md`'s `## Unreleased` section contains 3 independent entries citing #123, #124, and #126 respectively; Stream C's entry (#125) is confirmed ABSENT while Blocked (a premature entry would be a FAIL, not merely a missing one); review-time check confirms no version-literal edit exists outside `scripts/bump-version.sh` | Planned |
| AC-023 | REQ-006 | TEST-023 | document conformance (per-stream review) | each of Streams A/B/D's implementation report states explicitly whether any epic-#136-Done-condition doc surface (`README.md`/`USERGUIDE.md`/`docs/workflow-guide.md`/`docs/skill-reference.md`/`docs/agent-capability-matrix.md`/`PLUGIN-CONTRACTS.md`/`docs/troubleshooting.md`/`docs/contributor/*`) is affected; expected answer "none" recorded explicitly, not silently assumed | Planned |

Notes:

- WFI-014 branch enumeration is applied explicitly throughout: REQ-001's
  fallback chain (5 distinct PATH-availability combinations + 1
  precedence-order combination) is split into TEST-001..006, each its own
  fixture and assertion, rather than one combined "fallback works"
  assertion; TEST-007 then separately enumerates the 2 emit modes across
  the 4 branches that reach `.ps1` (8 named sub-cases) instead of asserting
  emit-mode coverage informally. REQ-002's "3 classes x 4 runtimes x 3
  tool_name shapes" language is honored literally: TEST-008/009/010 each
  enumerate their own 12-combination matrix as 12 independently
  PASS/FAIL-reported fixture+assertion pairs (36 total leaf assertions
  across the 3 classes), not a single loop whose internal per-combination
  results are invisible to the suite's own summary output.
- TEST-001..004 and TEST-017 are this feature's RED-demonstrable proofs.
  TEST-001..004 are RED-demonstrable in the sense that, before this
  feature exists, no suite can observe the fallback-selection behavior at
  all (a "the assertion has never been possible to make" RED state,
  distinct from a "the assertion currently fails" RED state — design.md
  Test Strategy item 1 records this distinction explicitly, since Stream A
  is preventive/structural work, not a bugfix). TEST-017 is a
  literal RED-then-GREEN pair: an intentionally-dropped step name in a
  throwaway pre-candidate fixture must fail the self-check before the
  real staged candidate (which drops nothing) passes it.
- TEST-008..011 are deliberately OS-independent: every payload and every
  runtime invocation is driven via mktemp-scoped fixtures and
  `PATH`/env-var indirection, so the full 3-class x 4-runtime x
  3-tool_name-shape matrix runs identically on macOS/Linux/Windows CI —
  not gated behind any one OS's toolchain happening to have every
  interpreter installed (a host lacking `node`, for example, causes only
  the `.js`-runtime sub-cases to SKIP with a named reason, mirroring
  `guard-parity.tests.sh`'s own SKIP convention, never a silent PASS).
- TEST-012..015 (Stream C) are recorded as `Blocked`, not `Planned` — this
  is a distinct Status value from every other row in this table,
  deliberately visible so a reader scanning this file cannot mistake
  Stream C's rows for ready-to-implement work. No suite file exists for
  them; design.md's API/Contract Plan names the target shape only.
- This is CI/script/scenario-schema work with no user-facing entry point;
  the UI integration checklist is not applicable (ux-spec.md,
  frontend-spec.md — both N/A stubs, mirroring `quality-loop-fixes`' and
  `epic-136-phase2-gates`' own convention for non-UI features).
- AC-016's document/YAML conformance and AC-017's self-check are both
  reviewed against the STAGED candidate under
  `specs/epic-136-phase3/human-copy/`, never the live protected
  `.github/workflows/test.yml` — consistent with every other
  human-copy-staged AC in this repository's prior features
  (`quality-loop-fixes` TEST-006/007, `epic-136-phase2-gates` TEST-013).
