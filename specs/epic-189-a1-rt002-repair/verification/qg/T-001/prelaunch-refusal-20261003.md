# T-001 quality-gate prelaunch refusal — 2026-10-03

T-001 remains **Implementation Complete**. This is a prelaunch observation, not an independent quality-gate verdict. No evaluator manifest was reserved, no evaluator was spawned, and neither PASS nor Done was recorded.

The quality-gate startup requires a live-selector result to be cross-checked against `.codex/agents/sdd-evaluator.toml` reference comments. The read-only command below was refused by the active PreToolUse hook before it ran:

```text
rtk proxy rg -n '^# x-sdd-(model|effort)|^model|^effort' .codex/agents/sdd-evaluator.toml
```

The hook reported: `SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました` and its English explanation that writes to `.codex/agents/` without `developer_instructions` are denied. This command was an `rg` read, but the actual denial is binding. No alternative route to that protected file was attempted; the required cross-check remains unverified. The live-selector command itself had not yet run, so no selected model or TOML-drift conclusion is claimed.

Before the refusal, the following direct checks ran with exit 0; their unmodified command output is preserved locally under this directory:

| Check | Evidence | SHA-256 | Measured result |
|---|---|---|---|
| T-001 risk | `risk.log` | `0eda7d79ba20116673a4644a5b3ddd237d0fbc1595209612ab56f431c86be834` | pass |
| changed production placeholders | `placeholder.log` | `3786ea13bcd82f362d4c7039731b2dadc932eef395ce8af5856e033fc4df26b1` | pass |
| task state | `task-state.log` | `d915350ca202e1e939f5fd4253edaec695ee2c7af2df0af80fb10a66ef1aa5af` | pass; two tasks |
| global workflow state | `workflow-state.log` | `8ea982255942f7f86535d011fadc3a596e0cccc598e72cf636045cf18226c9f7` | pass; tolerated unrelated amendment records |
| component coverage | `component.log` | `5c94806043b3bb89199f95190c1dca31080118fc6589b5d4b210499d3293383c` | N/A, disabled-legacy; exit 0 |
| T-001 traceability | `traceability.log` | `cc138b3a7f8834af5b4757ad7de9f7df0e89bd5ec817ed00d8aaf080e8e79c81` | pass; five links |
| original Bash suite | `owner-bash-20261003.log` | `b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d` | 984 PASS / 0 FAIL; exit 0 |
| original PowerShell suite | `owner-pwsh-20261003.log` | `ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040` | 985 PASS / 0 FAIL; exit 0 |

`../T-001.contract.json` was created Default-FAIL and remains unpassed. The fresh gate logs were not added to the frozen implementation report and no Post-Fix declaration was manufactured. Resume only after the protected read operation is legitimately permitted, then perform model selection/cross-check, complete the contract and verification gates, reserve a hash-bound manifest, and launch a fresh independent evaluator. A refusal must not be worked around by another tool or path.
