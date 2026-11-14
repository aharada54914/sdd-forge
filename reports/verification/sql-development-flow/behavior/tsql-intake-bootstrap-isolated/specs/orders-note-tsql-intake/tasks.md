# タスク（lite）: orders-note-tsql-intake

仕様生成のみ。各タスクは実行未承認。OQ-01〜06を解決し、要件・設計・対象範囲を具体化してから人間が承認する。

## T-001 実装前契約と検証経路を確定する
Approval: Draft
Status: Planned

### Scope
- 要件OQ-01〜06を人間と確定し、requirements.md・design.mdへ反映する。
- 実CLIソース／旧版、SQL型・Unicode境界、正確な環境・tool版、コマンド・fixture・timeout・排他・接続先確認・回復手順を特定する。

### Done When
- 未決事項について決定内容と根拠が記録され、CLIと旧版検証方法、対象パス、実行可能なproject checks、隔離と所有確認の方法が明確である。
- 同一スキーマownerが維持され、Lite適格性を再確認できる。範囲変更時は再仕様化する。
- 後続の実装タスクに曖昧な型・対象・コマンドが残らず、変更後の契約が人間の承認対象となる。

### Blockers
- OQ-01〜06。仕様確定の作業であり、DB接続・SQL実装の承認を兼ねない。

## T-002 project管理スキーマとCLIのnote／検索を実装する
Approval: Draft
Status: Planned

### Scope
- T-001で確定したproject sourceへnullable noteを追加し、既存制約を保持する。
- 確定したCLIソース／検索配置で整数idのtyped binding、note読み書き・境界拒否を実装する。

### Done When
- project buildが成功し、DACPACが確定した型・制約を持つ。変更計画・pre/post scriptをレビューしデータ損失防止設定を保持する。
- 検索はid・amount_cents・noteを返し、一致時1行、欠損時空集合。値のSQL連結がない。
- 確定した100文字境界を実装し、101文字は黙って切り詰めない。既存id・金額制約が保持される。
- 新旧CLIで必要な読み書き経路が用意され、互換性・配置の実DB受入はT-003で検証する。

### Blockers
- T-001の契約確定、実ソース提供、具体化された本タスクへの人間の実装承認。

## T-003 隔離DBで配置・互換性・境界・回復を検証する
Approval: Draft
Status: Planned

### Scope
- 承認範囲の専用ローカルDBのみで、design.mdのテスト方針をproject checksとして実行する。
- 今回とは別の新規実行ディレクトリを`.run-temp`配下に作成し、他invocationの証跡を再利用しない。

### Done When
- 新規構築と前版更新で最終schema・制約が一致し、既存合成100件の全キー・金額とnote=NULLが確認される。
- 実旧CLIの読み取り・追加・更新、新CLIのnote往復、旧CLI更新時の既存note保持が確認される。
- NULL・空文字・100／101文字・確定したUnicode境界、金額0／負数、重複id、欠損idが期待どおりとなる。
- DACPAC整合と実schema driftを別検査し、二重適用・途中失敗・並行適用・lock／timeout・中断後の状態観測と回復を確認する。
- 所有資源・権限分離・秘密除外と片付け対象が記録され、共通実行器のexecution.jsonと観測根拠が既存品質レポートから参照される。
- 必須未実施・失敗・Blockedを明記し、品質判定はlite-gateの独立検証へ渡す。性能改善やAzure受入を主張しない。

### Blockers
- T-001、T-002、実DB／実CLI／fixture／toolの利用可能性、専用資源の所有・接続先確認、本タスクへの人間承認。
