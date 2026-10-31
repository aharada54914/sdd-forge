# T-004 fresh launch handoff

Allocation succeeded; first model turn has NOT been sent. The idle app-server was subsequently terminated by Ctrl-C at the coordinator's request; transport exit code 1 was observed. This ephemeral identity is no longer an executable launch target and must not be reused for a future implementation.

- Native transport: closed PTY session 75705.
- Native thread.id and thread.sessionId: `01a107bc-472e-7b51-a137-5b2667e49051`.
- Model: `gpt-6-astra`, effort `high`; v2 registry strong tier. No permission override.
- Identity receipt: `allocation-receipt.json`.
- Manifest and snapshot: NOT CREATED. Implementation/evaluator reservation: NOT performed.
- Candidate input inventory: `planned-inputs.json`, paths only, not a validated manifest.
- Selection estimate: historical source-backed API-equivalent USD 48.22 from `reports/verification/issue137-model-registration-candidate-20260928/launch-candidates.json` and its report. Not current actual cost or subscription billing; no paid API request used to obtain the estimate.
- Ship canary was genuinely denied by PreToolUse. Missing surfaced plugin flag metadata produced verifier exit 65, not a live activation PASS. Physically absent project context selects G4/C1 DISABLED_LEGACY compatibility full only; this proves no A8 live-host activation success.

## Stop boundary

The attempted `rtk proxy node -e` command enumerated the 47 exact paths in planned-inputs.json and performed only `fs.readFileSync` plus SHA-256 hashing to stdout. It was rejected before execution. No hashes were collected by that command. It was not retried through another command or interpreter.

Verbatim refusal:

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.
```

The original full attempted command remains in this helper's native tool transcript. Resolve an authorized read/hash path before completing the manifest, snapshot validation, and first `turn/start`. Do not claim the idle thread ran implementation. Keep historical reports, frozen inputs, task state and approval intact.
