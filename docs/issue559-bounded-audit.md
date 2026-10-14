# Issue 559: bounded weekly Actions audit

## Scope recorded before editing (2026-10-14)

- Issue: https://github.com/aharada54914/sdd-forge/issues/559
- Owner: `issue559_root_cause`; isolated checkout on the branch below.
- Branch: `codex/issue559-bounded-audit`; initial HEAD: `71eede42ebf81b9e4097ea1a441f58f91d265829`; initial dirty changes: none.
- Risk: routine prompt correction, aiming to reduce discovery exhaustion within the existing 75-turn limit. No authorization, enforcement, required-check, task-state, or evidence-schema changes.
- Scope: Actions audit discovery budget, progress checkpoints, and truthful incomplete reporting; focused prompt regression in the existing self-improvement test suite.
- Preserved contracts: both mandatory shell suites, Python/Node syntax checks, all JSON/YAML parsing, existing guard and recovery workflow, external-write permissions, 75-turn cap. No workflow or guard edits, installed baseline changes, commits, or push.
- Validation: existing self-improvement suite plus new prompt-contract assertions and a negative fixture using the original prompt; shell syntax; diff whitespace. Parent performs independent diff review. Exact-head CI and actual Actions execution remain required before claiming recovery.

## Evidence and limits

Run `38200520193` on `9b16ffba39a090cd3cf2305e986341e24096b835` ended with `error_max_turns`, `num_turns: 76`, `duration_ms: 882802`, and `Reached maximum number of turns (75)`. The workflow has a 45-minute timeout (`.github/workflows/self-improvement.yml:70`) and 75-turn cap (`:133`). The original prompt required all WFI bodies (`.github/self-improvement-prompt.md` before this change, lines 42–45), seven audit areas (46–55), mandatory checks (56–58), then implementation and PR work (59–67), with no discovery stopping budget. The individual operations responsible for consuming the turns have not been established.

Prompt checks cannot prove model compliance, actual Actions success, or recovery. In particular, the existing finalizer checks job success, not the completeness of the model's report (`.github/workflows/self-improvement.yml:248–250`); a truthful incomplete report alone is not a deterministic failure signal. Changing that behavior is outside this repair. No recovery claim or issue closure is authorized by local prompt checks.

## Validation results

- `bash -n tests/self-improvement-guard.tests.sh`: PASS.
- `bash tests/self-improvement-guard.tests.sh`: 25 passed, 0 failed. This includes seven negative prompt-contract fixtures and all existing guard/recovery checks.
- Original HEAD prompt copied to an isolated regular file, then `TARGET_PROMPT` pointed there: expected RED, 24 passed, 1 failed (only the new Issue 559 contract check).
- An earlier diagnostic passed a process-substitution stream as `TARGET_PROMPT`: 23 passed, 2 failed. That fixture was invalid because repeated grep reads consumed the stream and the existing regular-file test failed. It is not regression evidence; the regular-file rerun above supersedes it.
- `git diff --check`: PASS.
- Repair iterations: 1. Fresh-context independent Codex diff review: no blocking findings; independently reran the 25 checks, shell syntax and whitespace checks successfully. Exact-head CI and live Actions execution: NOT RUN.
- Status: candidate prompt repair only; Issue 559 root-cause closure is unresolved pending a separately scoped machine completion criterion and real Actions evidence. No workflow completion logic was changed.
