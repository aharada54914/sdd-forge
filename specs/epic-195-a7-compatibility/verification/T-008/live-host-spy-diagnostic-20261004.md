# T-008 live-host spy diagnostic (non-gate, not an AC verdict)

The approved T-008 requires a real host invocation to demonstrate the A5 Resolver no-call branches and positive exactly-one-call branch. The current static caller contract and fixture-only loop suites do not establish that result. This diagnostic did not set T-008 Done or claim AC-004/AC-021 passed.

## Isolated setup

- A fresh local clone of current PR #512 head `7a99573f928bcdf7d574ca23087463d31cff8157` was used; the dirty owner checkout was not used as the bootstrap working directory.
- The clone's `scripts/check-sdd-structure.sh` returned `check-sdd-structure: OK` in a **separate outer preflight**. This is not evidence that Claude performed the same required check inside its bootstrap turn. A synthetic v1 Project Context was placed only in the clone for the positive-control attempt.
- `live-host-spy-candidate.sh` records the raw Claude stream, structure log, invocation log and receipt outside the owner checkout. It explicitly invokes Sonnet and the canonical `/sdd-bootstrap:bootstrap` entry with the repository plugins. It always returns `UNVERIFIED` because a zero spy count without proven reachability is not acceptance evidence.
- The first diagnostic attempt produced only the CLI syntax error: stream JSON requires `--verbose`. It was preserved and the candidate corrected. The second attempt was a new output directory; no raw record was overwritten.

## Observed second attempt

- Host process returned 0 and the CLI result was `success/is_error=false`, but the host's own final response stopped before Phase 1; neither value is a workflow pass. The driver returns 3 and records `verdict=UNVERIFIED` regardless of that host exit code.
- The normal PreToolUse hook did run. An initial compound Bash command was rejected by the fact-forcing gate. After the host stated its purpose and retried, Bash commands were denied with `This command requires approval`. The optional MCP command also lacked permission; Glob was not present in that session.
- Because the required structure check and hook-activation handshake could not be performed within the model turn, no positive Resolver branch was reached. Spy invocation count was 0, which is **not** positive-control proof and cannot validate F1/F3/F4 zero-call claims.
- The host correctly stopped rather than bypassing the handshake. No alternate executor, permission-mode relaxation, hook disabling, or further model retry was used after this actual denial.

The CLI result's `permission_denials` array contains four entries: the compound Bash request twice (first receiving the fact-forcing PreToolUse hook error, then the approval-required rejection), the optional read-only `mcp__sdd-forge-mcp__get_next_sdd_command` lookup once, and the simplified read-only `bash scripts/check-sdd-structure.sh` once. The last denial says `This command requires approval`; therefore even the single prerequisite read-only structure check required approval in this Claude session. This does not prove the SDD hook rejected that check: the earlier compound command first hit a fact-forcing PreToolUse hook, then the normal Claude permission boundary refused execution. No handshake command was attempted or denied.

## Exact remaining conditions

1. A human must approve the normal Claude session's concrete `bash scripts/check-sdd-structure.sh` permission request, and then the required handshake operations as presented by that same session. Do not grant generic Bash or disable hooks. The hook-activation challenge and response must yield `HOOK_ACTIVE` in that same model session. The optional MCP preflight may remain advisory if unavailable.
2. Prove the spy intercepts the dispatcher's actual resolved path before treating a zero count as evidence. The skill names `resolve-project-context.{sh,ps1}` but not a fixed path. A PATH-only shim is insufficient if the host chooses an explicit plugin script path. A positive-control invocation must show exactly one intercepted call and the expected explicit `--config`, `--target-rev`, and `--feature` arguments before running the no-call cases.
3. Only then run isolated F1/F3/F4 host turns under the same accepted hook/permission contract, check each branch was reached, and require zero actual Resolver process invocations. No such turns were run here.

The candidate driver is a diagnostic starting point, not a complete acceptance test. Its raw records remain local-only and must be inspected for permission outcome, actual branch, and dispatcher path before use.

The driver invocation shape is `bash live-host-spy-candidate.sh positive <isolated-repo> <fresh-output-dir>` followed, only after positive interception proof, by each of `F1`, `F3`, and `F4` in separately prepared isolated repositories and fresh output directories. It refuses an output directory inside the owner checkout and refuses overwriting prior attempt artifacts. `bash -n` of the candidate returned 0. It was not rerun after the observed permission refusal.
