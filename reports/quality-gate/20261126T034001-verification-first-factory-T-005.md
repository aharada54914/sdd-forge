Task ID: T-005
Feature: verification-first-factory
Run ID: 354ba976-dd04-4822-a8bd-d3191feb7086
VERDICT: NEEDS_WORK
Critical: 0
Major: 5
Minor: 0

# Independent review of formal verification and replay

- **VERDICT**: FAIL
- Evaluators A (ledger 1200) and B (ledger 1201, run `d2c4b0ab-1f90-4a8d-b03c-91c17ade5003`) each verified all 33 admitted inputs for `cf53793720d0f3eb996e154627ace69dac893793`.
- Four mechanical commands passed and specification drift was CLEAN. G2 reported six shared-file scope warnings. The independent review confirmed the Green run. The submitted material described the historical Red without its original machine log.

| Perspective | Finding | Impact |
|---|---|---|
| G1 | The five-step reservation replay was hand-authored. | The passing replay did not establish that the implementation emitted the observed transition sequence. |
| G1, G3 | After baseline success the next phase can exhaust the total time budget and return before the common failure handling. | At repair round 4 with limit 3, a failed run produced no open question for the decision view. Both evaluators found this independently. |
| G5 | Trace generation discarded the configuration's choice of transition relation. | A baseline with `NEXT Permitted` generated a replay using `Next` and allowed a step excluded by the configured relation. |
| G3 | Structural validation rejected any operator defined as TRUE. | An unrelated helper `Enabled == TRUE` prevented a model with a genuine selected invariant from running. |
| G4 | Explicitly disabling formal verification in configuration could still trigger a checker search in CI. | A missing JAR caused an exit status of 1 on the disabled path. |

Each row is a distinct major finding. T-005 remains Implementation Complete pending repairs and independent re-evaluation.
