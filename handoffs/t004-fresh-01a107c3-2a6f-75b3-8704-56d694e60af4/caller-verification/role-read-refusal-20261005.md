# Exact role-read refusal — 2026-10-05

Operation: tool `exec_command`, `login: false`, cwd `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`, max_output_tokens 4500.

Exact command string:

```text
rtk proxy cat .codex/agents/sdd-investigator.toml .codex/agents/sdd-evaluator.toml
```

Raw tool refusal (verbatim):

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました。.codex/agents/ 配下のファイルは developer_instructions を定義する必要があり、無い場合 Codex は起動時にこれを無視します（\'Ignoring malformed agent role definition\'）。新規作成せず、同梱の sdd-investigator / sdd-evaluator ロールを使用してください。
[EN] SDD deterministic gate: refusing to write a Codex agent role file without developer_instructions. Files under .codex/agents/ must define developer_instructions or Codex ignores them at startup (\'Ignoring malformed agent role definition\'). Use the shipped sdd-investigator/sdd-evaluator roles instead of creating new ones.. Command: rtk proxy cat .codex/agents/sdd-investigator.toml .codex/agents/sdd-evaluator.toml
```

The command did not execute. No alternate syntax, executor or direct file API retried it. This is a new caller-side refusal, NOT the old native worker rg refusal. The exact submitted shell string is available; a post-shell argv array does not exist because launch was blocked. The refusal text classifies a read command as a role write, but this alone does not identify which internal parser branch is responsible.

The subsequent executable-path ls in the same orchestration cell was not reached. No native process, initialize, allocation or formal turn occurred in this follow-up. Current native role/tool-read compatibility remains unverified, so allocation was not attempted.

Prior limited configuration-key read succeeded: /Users/jrmag/.codex/config.toml lines 3/5/7 reported model_reasoning_effort high, approval_policy never, sandbox_mode danger-full-access. This was a selected-key read, not a full environment/config collection; no auth material was requested. These settings do not establish hook permission for the denied read.

Independently completed adapter fix: correlated initialize/thread-start responses now take a separate explicit allowlist projection through durable audit before onResponse; uncorrelated responses remain excluded. Synthetic response/event mixing reproduced missing responses (expected 2, observed 0), then passed all 14 tests. rpc-red.log and rpc-green.log preserve outputs. No model or RPC integration success is inferred from these synthetic tests. Native direct-pipe integration remains pending.
