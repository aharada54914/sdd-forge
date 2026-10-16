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

## Completion diagnostic scope (2026-10-14, before editing)

- Issue: #559; owner: `weekly_recovery_oct14`; isolated checkout on branch `codex/issue559-bounded-audit`; HEAD: `6b1e62242267bf0ea1c17a3f78a4adcdf19e5188`; dirty changes: none.
- Authorized scope: diagnose the newly failed completion step and add safe, allowlisted diagnostics if exact evidence is unavailable. The existing completion and recovery predicates, mandatory checks, prompt, permissions, and external writes remain unchanged.
- Risk: diagnostic-only correction within the explicitly authorized workflow recovery. The workflow is a protected surface; this is not authority to relax a gate or change evidence/identity semantics. Output must contain only fixed field names, booleans, and fixed categories, never raw completion values, arbitrary keys, payloads, or exception details.
- Affected surfaces: inline completion validator in `.github/workflows/self-improvement.yml`, its existing extracted-step fixtures in `tests/self-improvement-guard.tests.sh`, and this development record. The finalizer consumes the same `complete=true` output.
- Evidence: run `38562507923`, HEAD `bee54eb248b381f89d6badeb7d92a43359460ab9`, exited the Claude session successfully after 60 turns with zero permission denials; completion JSON reading/parsing succeeded and the combined predicate failed. The run has no artifacts. Issue #563 reports five passed checks and a protected improvement deferred for human judgment; this does not establish the completion record's actual status or any other field.
- Required validation: existing positive/negative completion and recovery fixtures, new exact allowlisted-diagnostic and hostile-value fixtures, shell syntax, YAML parsing, whitespace, independent parent diff review. Exact-head CI and a new real Actions run are still needed to identify the failing field and establish recovery. No commit/push/merge or issue closure in this subtask.

## Completion diagnostic validation

- Root cause remains unconfirmed: the real run reached the combined completion predicate, but its original JSON is unavailable. The prompt's mandatory `partial` status for a protected stop is one plausible explanation of the #563 report, not a finding about the missing record.
- Change: preserve the original completion predicate and `complete=true` publication exactly; add fixed diagnostic categories for read/JSON failures and allowlisted booleans/status categories for predicate failures. Raw values, arbitrary keys, and exception payloads are not logged. No prompt, mandatory-check, finalizer, or permission change.
- RED: newly added diagnostic assertions against the original validator produced 46 passed / 16 failed; existing completion and recovery assertions continued to pass.
- GREEN: `bash tests/self-improvement-guard.tests.sh` produced 66 passed / 0 failed, including missing, malformed, duplicate, hostile duplicate, invalid UTF-8, partial/unknown status, each identity mismatch, failed/unrun/boolean checks, hostile payload values, non-object records/checks, and successful completion.
- `bash -n tests/self-improvement-guard.tests.sh`, `git diff --check`, and Ruby `YAML.load_file` of the workflow: PASS. The first YAML check using Python failed because local PyYAML is not installed; no dependency was added, and Ruby's installed YAML parser succeeded.
- Repair iteration: 1. Fresh-context independent Codex review found no issues and independently repeated all 66 checks, shell syntax, YAML parsing, and whitespace checks successfully. Exact-head CI and real Actions execution remain pending. Local fixtures do not establish runtime audit recovery or authorize issue closure.
- Next: independently review this diff; publish the reviewed candidate through the authorized workflow; run `workflow_dispatch` at its exact ref, inspect `Audit completion diagnostic`, and address only the observed failure. A `partial` record must remain failed under the current contract. #559 remains open until full-run success; #563's protected-change decision remains separate.
