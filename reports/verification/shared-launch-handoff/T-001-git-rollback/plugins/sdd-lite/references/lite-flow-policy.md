# Lite Flow Policy

sdd-lite は社内・部署内アプリ向けの「中量」トラック。完全版 SDD の部分集合であり、加算的に昇格できる。

## 維持するもの（核）
- 単一の人間承認（AI は `tasks.md` の `Approval: Approved` を増やせない。既存 hook-guard が保護）。
- kill-switch（`AGENT_STOP`）常時有効。
- 独立した軽量ゲート（lite-gate が検証コマンドを自分で再実行）。

## 省くもの
- traceability.md、ADR 必須化、受入テストの厳密記述。
- evidence.json バンドル（SHA256/git_commit/署名/provenance）。
- contract.json（lite 品質レポートで代替）。
- cross-model 検証、critical 階層、二者承認、WFI/retrospective、品質ゲート多重サイクル、リスク階層強制。

## 状態モデル
- `Approval: Draft|Approved`、`Status: Planned|In Progress|Implementation Complete|Blocked|Done`。
- 遷移検証は `check-task-state-lite`（Done は impl報告 + 品質レポート VERDICT:PASS を要求、evidence.json は不要）。

## 昇格（full SDD へ）
| 追加 | 有効化 |
|---|---|
| `Risk:` + `Risk Rationale:` | 階層強制（check-risk / check-contract Pass4） |
| 本体 `check-task-state` を使用 | evidence-bundle 必須・Done の機械的証明 |
| `cross_model: required` | クロスモデル検証 |
| critical タスク | 二者承認 + 署名 + provenance |
| `traceability.md` | REQ→AC→TEST→証跡チェーン |

成果物の場所・命名は full SDD と同一（`specs/<feature>/`, `reports/`）。sdd-lite を外して sdd-bootstrap / quality-loop の本フローへ連続的に移行できる。
