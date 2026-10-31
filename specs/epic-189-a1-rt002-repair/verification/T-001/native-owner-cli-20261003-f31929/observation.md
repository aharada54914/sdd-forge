# T-001 fresh native owner activation, 2026-10-03

Scope: TEST-089 evidence only. This record does not set a task status, reserve a reviewer identity, or claim independent quality-gate acceptance. The owner checkout was `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge` at HEAD `1e86fb272643e798db4e1ca0c89f0402317a2fc8`. Native CLI: `/Users/jrmag/.nvm/versions/node/v24.13.0/bin/codex`, version `0.160.0`; `codex exec -C <owner checkout> -m gpt-5.6-sol --json` kept the existing approval, sandbox, hook trust, and config settings. No setting was changed for this attempt.

Original installed wrapper: `/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/check-hook-activation-handshake.sh`. Installed Python verifier and checkout source both SHA-256 `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`. The first native tool call invoked that wrapper with `--emit-challenge` and exited 0. It emitted nonce `f319296577f0515fb95f3b29cf131580` and the `codex-cli` relative `apply_patch` template targeting `sdd/.hook-canary-sentinel`.

The next native tool call submitted that template once, unchanged, through `tools.apply_patch`. The PreToolUse hook refused the write before execution. No canary retry, alternate tool, cleanup, or second challenge occurred. The sentinel remained absent (`rtk proxy test ! -e sdd/.hook-canary-sentinel`, exit 0). The native child final message is **not** the raw-result source.

Raw host provenance: `/Users/jrmag/.codex/sessions/2026/10/03/rollout-2026-10-03T15-28-49-01a10073-7788-7b23-bad8-a95fe349f8c8.jsonl`, SHA-256 `62debaeafd4a8c7147c1d529bc67e23349c47d0f46a4baeb3215864aa55dcbd6`. At `2026-10-03T06:29:07.425Z`, `response_item.custom_tool_call` with call ID `call_jYd2fUMbj9DbKYQJL68YgadA` contains the nonce-bound patch. At `06:29:07.509Z`, the corresponding `response_item.custom_tool_call_output.output[1].text` is the host's wrapped `Script error:\nCommand blocked by PreToolUse hook: ...` result. `host-response.json` stores that field after JSON string decoding only, with the contract's five fields and `executed: false`. A `jq` strict string equality check against that original JSONL field returned `true`, exit 0. `host-response.json` SHA-256: `4b6a5bd7ac5c2ec04f3a2d89e0ca9ca3bcb7775a1a8608c3e92a6f99a37f6e42`.

The installed original wrapper was then invoked with `--verify-response --nonce f319296577f0515fb95f3b29cf131580 --recorded-result specs/epic-189-a1-rt002-repair/verification/T-001/native-owner-cli-20261003-f31929/host-response.json --runtime codex-cli`. It exited 0 and returned exactly `schema: sdd-hook-verify-result/v1`, `runtime: codex-cli`, the same nonce, and `status: HOOK_ACTIVE`.

Current owner-checkout full original-path regressions, after activation:

- `rtk proxy bash tests/check-hook-activation-handshake.tests.sh`: 984 PASS, 0 FAIL, exit 0.
- `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`: 985 PASS, 0 FAIL, exit 0 (macOS PowerShell, not native Windows).

At test time the Bash suite SHA-256 was `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c`; the PowerShell suite SHA-256 was `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd`. This fresh local result does not certify latest-head CI or native Windows. T-001 remains In Progress pending independent quality-gate review; T-002 release and final AC-006 acceptance are separate.
