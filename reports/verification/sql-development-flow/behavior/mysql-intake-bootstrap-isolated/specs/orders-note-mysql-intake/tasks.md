# タスク（lite）: orders-note-mysql-intake

今回の出力はDraftのみ。全タスクは未承認・未着手。未決事項の解決と仕様確認前に実装承認を求めない。人間だけが各Approvalを変更できる。

## T-001 実装前のSQL・アプリ・検証設定を確定する
Approval: Draft
Status: Planned

### Scope
- requirements.md Q-01〜07を人間と確認し、design.mdの契約・変更パス・検証手順を具体化する。
- 旧CLIのSQLとtransaction境界、既存schema/Flyway導入状況を確認する。DB接続やSQL実装は含めない。

### Done When
- 全Qの決定、根拠、実行上限、専用DBの作成/破棄責任と識別手順、回復/損失範囲が記載されている。
- Unicodeと文字数、厳密拒否、driverのbinding、旧CLI互換性、前版取り込み、実行可能な検証コマンド・schema比較方法・fixtureが確定している。
- 人間が確定仕様を確認し、後続タスクの実装承認範囲が明確である。

### Blockers
- Q-01〜07未確定。設定を推測して補わない。

## T-002 note追加とid検索を実装する
Approval: Draft
Status: Planned

### Scope
- T-001の確定設計に従いFlyway版付きmigration、Pythonのid値binding検索、必要な検証コード/fixtureを実装する。
- 追加列のみとし、既存列・行を保持する。承認済みの専用資源のみ使用する。

### Done When
- REQ-001〜005のコードと境界/互換性検証が実装されている。
- 旧CLIの読取・登録・更新、note省略、既存note保持、新検索の3列と一致/不一致が実測で一致する。
- NULL/空文字/Unicode/100文字を保持し101文字を拒否。金額0受理・負値拒否・主キー重複拒否を確認する。
- ownerはFlywayのみ、適用済み版の変更や独自runnerがない。

### Blockers
- T-001完了、確定仕様の確認、当タスクの人間承認が必要。

## T-003 隔離DBで移行・失敗回復を検証する
Approval: Draft
Status: Planned

### Scope
- T-002後にrequirements.md受入表の全件を実MySQL 8.4.0/Flyway 13.12.1で検証する。
- プロジェクトチェックを既存gate共通実行器へ登録し、毎回固有の.run-temp配下へ証跡を保存する。

### Done When
- 新規/更新のschema・制約一致と100件の全キー/金額保持・追加後NULLを確認している。
- 履歴/checksum異常と実schema driftを別々に検出できる。
- 二重/並行適用、途中失敗、lock待ち、timeout/切断後の残存処理・transaction・lock・schema・履歴を確認している。
- 承認された回復で最終schemaと値が一致し、状態不明の再実行や自動repair/clean/baselineで異常を隠していない。
- 版、fixture、実行コマンド/終了状態、期待値と実結果、副作用、未実施項目、execution.jsonが既存報告から確認できる。作成IDに一致する資源のみ後片付けする。
- 独立したlite-gateによる確認へ引き渡せる。必須試験未実施/失敗をPASSやDoneとしない。

### Blockers
- T-001/T-002完了と当タスクの人間承認。専用資源/実tool/比較手段がなければBlockedとして停止する。
