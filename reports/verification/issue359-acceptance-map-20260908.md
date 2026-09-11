# Issue #359 acceptance reconciliation

Date: 2026-09-08
Source: GitHub issue #359 body retrieved with `rtk proxy gh issue view 359 --repo aharada54914/sdd-forge --json title,body,state`; issue remains OPEN.
Candidate base: `4366438f3b243210a4ece5a17f873ca2d920600a`.

## Findings from current source and test coverage

1. CLI argument drift: current GPT runners build the `exec` invocation (`plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:293`, `run-panelist-gpt.ps1:230`). The freshly passing effort suites check assembled argv, but stub acceptance does not prove a current real CLI accepts it. Issue #359's suggested historic `project_doc_max_bytes` patch is not assumed to be the current design; live CLI compatibility and isolation must be evaluated against the approved runner contract.
2. Async stdin loss: the shell runners delegate bounded execution and explicitly refer to stdin duplication rationale (`run-panelist-gpt.sh:205`, `run-panelist-gemini.sh:102`). Comments alone do not prove the supervisor implementation. Fresh CL-016 verifies Gemini argv/stdin (`tests/collection-layer.tests.sh:449`, `:456`; PowerShell `:457`, `:464`). These results are not sufficient evidence for GPT stdin preservation; inspect the shared supervisor and run a source-bound GPT input-capture check before declaring this defect closed.
3. Greedy JSON extraction: current GPT shell and PowerShell runners scan brace-balanced candidates and retain the last schema-matching candidate (`run-panelist-gpt.sh:355-430`, `run-panelist-gpt.ps1:311-392`). Fresh CL-019 through CL-023 exercise distractors, fenced JSON, schema rejection, embedded closing braces and malformed JSON diagnostics. Gemini shell has analogous candidate scanning (`run-panelist-gemini.sh:203-278`), but that source resemblance does not establish equivalent Gemini coverage or PowerShell parity. Verify both twins before issue-level closure.

All repository paths and lines above refer to the main-based candidate worktree `/Users/jrmag/.local/share/sdd-forge-issue359-recovery-20260908`. Narrow collection-fixture repair success is not a substitute for the issue's three production-runner outcomes.

## Integration dependencies

The current CI workflow and `tests/run-all.ps1` contain no collection-layer PowerShell registration (read-only `rg -n 'collection-layer|workflow_dispatch' .github/workflows tests/run-all.ps1 tests/run-all.sh`; only `tests/run-all.sh:90` registers collection-layer). Dispatching unchanged CI therefore cannot establish the required Windows collection-fixture execution.

Ship preflight: candidate `bash scripts/check-sdd-structure.sh` exited 0 with `check-sdd-structure: OK`. Advisory MCP auto-selection reports multiple other features; the explicit repair target remains cross-model-verification/T-005. Track handshake, formal gate and task status transition have not been performed in this preflight.

PR #390 run 34008982110 and PR #394 run 34023439393 were rechecked and remain terminal failures in `test (windows-latest)` and aggregate `required-checks`. They are not live jobs to wait for and have not been rerun or bypassed.

Next actions: close the GPT stdin and Gemini extraction evidence gaps, exercise actual Windows fixture paths through an authorized CI registration, then complete the fix/gate lifecycle and integrate only after required CI succeeds. No issue closure or merge is justified by this report.

## Follow-up: confirmed remaining Gemini PowerShell defect

Further inspection found `run-panelist-gemini.ps1:192` still uses greedy `\{[\s\S]*\}` extraction. A PowerShell read-only probe extracted this actual pattern from the single matching source line, applied it to a distractor object followed by a valid verdict, and reproduced `Conversion from JSON failed with error: Additional text encountered after finished reading JSON content: {. Path '', line 2, position 0.` A single-verdict control was accepted. Tool e0fb50 exited 0 because reproduction and control succeeded; this is not a passing runner test. The earlier probe 14413c reproduced the same regex behavior but printed no source line; it is weaker evidence and is superseded by the source-bound probe, not silently treated as source-bound.

This changes the next action from merely collecting parity evidence to repairing a confirmed product defect. Proposed separate ticket: `docs/review-tickets/RT-20260908-002.yml`. It requires a human scope decision because the existing two approved repair tickets explicitly preserve production runners. No production repair or status approval was written.

The shared shell supervisor source does explicitly retain stdin duplication: `plugins/sdd-quality-loop/scripts/lib/panelist-common.sh:76` launches its asynchronous command with `<&0 &`. This closes the source-inspection uncertainty but does not replace an actual GPT input-capture test.
