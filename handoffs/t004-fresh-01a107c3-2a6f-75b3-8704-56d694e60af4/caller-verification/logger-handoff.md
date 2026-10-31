# Task-local native audit recorder preparation

Scope: non-protected diagnostic files only. No guard, SDD contract, model registry, frozen input, task status, native permission, or external worktree changed. No new native process or role turn was started.

## Root cause of missing diagnostic evidence

The earlier observer was inline `functions.exec` JavaScript, not a repository logger implementation. It read native process output, filtered for `item/completed`, `turn/completed`, and `error`, and emitted only selected summaries without preserving the input stream. Legacy `codex/event/exec_command_begin` and `codex/event/exec_command_end` events were outside that filter. This explains a demonstrated evidence-loss path, not the precise guard rejection cause or proof of the actual discarded event types.

The explicit `--legacy` test reproduces that filter against synthetic request/refusal events: expected 2, observed 0, exit 1. The replacement is a task-local importable recorder, not a product plugin change. `native-audit.mjs` never starts processes, executes commands, reads settings, reads environment variables, or changes permissions. It accepts supplied JSONL protocol events only.

## Verification

Commands, both with login=false:

```text
rtk proxy node handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/native-audit.test.mjs --legacy
rtk proxy node handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/native-audit.test.mjs
```

RED: 0 passed / 1 failed, intentional lost-event assertion (not syntax/environment failure), logger-red.log.
GREEN: 10 passed / 0 failed, logger-green.log. Tests cover exact request/refusal fields, split/Unicode/long output, tool lifecycle and approval request, exclusion of account/config/environment/reasoning notifications, secret-key redaction, invalid JSON, exclusive 0600 file creation, persistence before summary failure, matching client tool result, and unfinished-frame failure.

Fixtures are entirely synthetic. The command text inside tests is data and is never executed. Temporary test logs live beneath this diagnostic directory and are removed after each test; persisted RED/GREEN logs remain. No old refusal command was replayed.

## Next normal controller integration (not executed)

Import `AuditLog` from the absolute native-audit.mjs path into the approved native transport controller. Create it with a new absolute task-local audit filename before receiving any tool events. For every complete raw JSON line, call `audit.capture('server', line)` BEFORE parsing it for a UI/model summary. For arbitrary chunk boundaries, call `audit.feed('server', chunk)` instead. For outgoing replies to server-issued tool requests, call `audit.capture('client', JSON.stringify(reply))` before sending. Use untruncated direct transport chunks; do not first route them through a max-output-token or summary filter. Decode UTF-8 across transport buffer boundaries correctly before feed. A standard pipe-based existing transport avoids PTY echo/line limits; this recorder itself neither creates nor changes the transport or permissions.

The recorder synchronously writes and fsyncs each selected event. A disk error, invalid frame, oversized frame, or unfinished frame is a hard diagnostic failure: stop the launch/transport workflow and retain partial evidence, never proceed with a silently incomplete audit. Close the recorder when the controller ends. Existing files are not replaced. Request/result correlation is recorded, not inferred from final assistant prose. Retain separate first-turn/allocation receipts under their existing contracts.

Selection includes command tool start/end/output, tool lifecycle items, tool/approval requests, matching client results, generic legacy function/tool events, errors, and reduced turn status. Reasoning, account/rate-limit, arbitrary config/environment notifications and unrelated RPC replies are not collected. Turn histories are deliberately omitted. Sensitive keyed fields and common bearer/key strings are explicitly redacted; the event records whether redaction happened. Nonsecret command/argv strings and refusal bodies are preserved without summary or truncation.

## Safety and remaining limits

This is not a universal secret detector. Do not instruct the next worker to dump configuration/environment/credential files, do not subscribe to full settings/account streams, and do not feed known sensitive source content into the recorder. Ordinary output could contain an unlabelled secret that regex redaction cannot recognize; such requests must be excluded at the launch/input boundary. If redaction affects a command or refusal, the redacted record is not exact-argv evidence. No guarantee is made for undocumented event shapes: compare the next host's actual tool-event schema before approving a launch and extend only this diagnostic allowlist if required. No real-host logging integration has been exercised yet.

The current unknown refusal is still unresolved. This logger repair makes a future approved observation auditable; it does not authorize replaying the refused operation, bypassing a guard, or declaring #536 coverage. Another fresh implementation launch remains pending the parent's normal startup conditions. The stopped worker has no new implementation report and no review/Done evidence.
