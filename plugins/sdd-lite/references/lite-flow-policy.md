# Lite Flow Policy

sdd-lite は影響範囲が限定された通常の不具合修正や社内・部署内アプリ向けの軽量トラック。完全版 SDD の部分集合であり、加算的に昇格できる。

## 維持するもの（核）
- 単一の人間承認。AI は `tasks.md` の `Approval: Approved` を増やせない。既存 hook-guard が保護する。
- kill-switch（`AGENT_STOP`）常時有効。
- 一度の独立した実装後レビュー。lite-gate が検証コマンドを自分で実行し、短い受け入れ条件と関連回帰を確認する。実行証跡は共通実行器で生成し、レポートから参照する。
- 既存のリスク昇格・Project Context 検証。full 指定は格下げしない。タスクが low と自己申告しても Lite の許可根拠にはならない。フック・認証・証跡・配布などの重大な変更や影響不明な変更は full を使用する。

## 省くもの
- traceability.md、ADR 必須化、受入テストの厳密記述。
- evidence.json バンドル（SHA256/git_commit/署名/provenance）。
- contract.json（lite 品質レポートで代替）。
- cross-model 検証、critical 階層、二者承認、WFI/retrospective、品質ゲート多重サイクル、リスク階層強制。

## 状態モデル
- `Approval: Draft|Approved`、`Status: Planned|In Progress|Implementation Complete|Blocked|Done`。
- 遷移検証は `check-task-state-lite` が行う。Done は impl報告 + 品質レポート VERDICT:PASS を要求し、evidence.json は不要。

## 昇格（full SDD へ）
| 追加 | 有効化 |
|---|---|
| `Risk:` + `Risk Rationale:` | 階層強制（check-risk / check-contract Pass4） |
| 本体 `check-task-state` を使用 | evidence-bundle 必須・Done の機械的証明 |
| `cross_model: required` | クロスモデル検証 |
| critical タスク | 二者承認 + 署名 + provenance |
| `traceability.md` | REQ→AC→TEST→証跡チェーン |

成果物の場所・命名は full SDD と同一（`specs/<feature>/`, `reports/`）。sdd-lite を外して sdd-bootstrap / quality-loop の本フローへ連続的に移行できる。
