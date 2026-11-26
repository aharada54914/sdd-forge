# GateLifecycle correspondence after the implementation report review change

The comparison uses `e2f726ab4808eb01afdd7d289bc34669e7940685`. The mapped gate skill and formal inputs have identical bytes at the reported failing revision `d1f4fde1c`. At the comparison revision, the source-pin assertion in `tests/v2-formal-gate.test.mjs:277` failed for one of eight mapped paths. The observed SHA-256 of `plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md` was `7b8553a16516332bd3145526faca813d3396d6870f1ea35b3d1d9737a8f9e7d9`. The previous pin, `3e6809da0054a512c43962dca81e2762ed236f6898ecdb6e5627447ecd9c5f41`, matches that file at `329e838e9`, the parent of `481eb948a`.

## Transition review

Commit `481eb948a` added a paragraph in step 2 of the gate skill (line 47). The independent evaluator now checks the recorded runtime model and effort and runs the existing implementation-report validator. Missing fields can hold a task at Implementation Complete. The validator checks their presence and format.

| Implementation observation | GateLifecycle consequence |
|---|---|
| Step 1 produces the machine verdict. The gate runner, model and baseline configuration show an empty diff from `329e838e9` to the comparison revision. | `RunGatePass` and `RunGateFail` still project `execution.json` at `tests/v2-formal-gate.test.mjs:969–991`. The captured traces end at this verdict. |
| Steps 3–5 still require a final PASS before writing Done. A report deficiency can prevent completion after the machine passes. | `MarkDone` requires ImplComplete and PASS. Waiting in that state is allowed by `Spec`. `DoneRequiresGatePass` is a one-way safety property. These five finite safety checks cover approval, gate verdict, retry bounds, tamper, drift and escalation (`GateLifecycle.tla:55–64`). Runtime metadata accuracy is verified by the reviewer. |

The added reviewer check can delay the gate’s transition to Done, without adding a state or transition to this bounded safety model. The mapping update records the new source digest and comparison revision.

## Local verification

- On macOS arm64, `node --test --test-name-pattern="validates TaskLock.tla" tests/v2-formal-gate.test.mjs` failed the source comparison before the pin update and passed 1/1 afterward. All eight recorded source digests now match their files.
- The real `bash plugins/sdd-implementation/scripts/validate-implementation-report.sh <report>` accepted the complete AC-026 fixture from `tests/emit-run-record-feature-scope.tests.sh:516` with exit 0 (`IMPLEMENTATION_REPORT_OK`). Deleting only Model or only Effort produced exit 1 with `missing or invalid Model` or `missing or invalid Effort`, respectively.
- `python3 tests/project-skill-formal.tests.py` passed 8/8.

### TLC

The checker ran on Temurin 21.0.13.1+2 with the CI-pinned TLA+ tools v1.7.4 JAR (SHA-256 `936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`). With the JRE on `PATH`, the JAR supplied in `TLA2TOOLS_JAR`, and the locked dependencies installed by `npm ci --prefix plugins/sdd-quality-loop/rules`, `node --test --test-reporter=tap tests/v2-formal-gate.test.mjs` passed 22/22, with zero skips.

| GateLifecycle case | TLC result |
|---|---|
| Baseline, at most two automatic repairs | All five invariants held across 38 distinct states, depth 12, exit 0. |
| Named mutants | Each exited 12 on its expected property. Counterexample depths were 5 for DoneRequiresGatePass, 12 for RetryBound, 5 for EscalationRequiresOQ, 6 for NoTamperRepair and 5 for NoDriftPass. |
| Real gate PASS and FAIL with tamper, drift and a provisional question | Both five-state projections reached their final observation at depth 5 (expected TraceIncomplete counterexample). |
| Change the observed retry count at StartTask | Both replay attempts stopped matching before step 2. TLC exited 0 without a completed projection, and the formal gate returned FAIL with StartTask identified as unreachable. |
