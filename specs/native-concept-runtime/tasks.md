# タスク　Codex の版別プラグインから Concept Test を実行する

## T-001 正規の版別パッケージに Concept Test の実行資材を揃え、署名・固定レビューの境界を検証する
Approval: Draft
Status: Planned
Risk: high

### Scope

- `plugins/sdd-domain/skills/concept-test/SKILL.md`
- `plugins/sdd-domain/scripts/`、`plugins/sdd-domain/contracts/`。Concept Testのラッパー、実装、同梱依存とschema。
- `plugins/sdd-quality-loop/scripts/`、`plugins/sdd-quality-loop/contracts/`。同機能・署名／読取の依存、Nodeゲートの資材選択。
- `plugins/sdd-review-loop/scripts/launch-impl-review.py`。同機能を読む既存の固定実行資材inventory。
- `contracts/` は既存6スキーマの正本として参照。配布同期／バイト差分検査とそれを実行する既存の配布検査。既存署名／承認の意味・schema内容の変更は対象外。
- `tests/concept-test.tests.py`、`tests/concept-review-continuity.tests.py`、`tests/fixed-review-launch.tests.py`、`tests/v2-sdd-core-flow.test.mjs` と公式sourceのインストール・パッケージ回帰試験。人による手順、端末fixtureでの検収、ソースのみの照合を区別する。

### Done When

- AC-001、AC-002。事前の実Codex版別キャッシュで正常FITSが3経路とも失敗するREDを固定し、修正後に同じ手順で登録先のPOSIX、PowerShell、Nodeが通ることを示す。プラグイン単位の独立配置と平坦な対照で、起動ファイル、選択版、プロジェクト、表示・終了値を記録。実Codexに元のsourceを渡した公開入口の対話を1件以上採取する。未確認の区別でseed保存・質問待ちになる対照を取り、別の区別確認済みNon-FITSでホストが使った検証器・schemaと本人に表示した確認コマンド原文を記録。空白入りの利用者プロジェクトを指すその一行を本人が対応シェルにそのまま渡し、対象を確認しEOFまたは中断で記録なしとなることを示す。
- AC-003、AC-004。各Non-FITS分類×3選択×2ラッパーで確認・再読取・実ゲートを通し、期待する後続回数、記録の各ハッシュと非通過時の不変性を確かめる。不足／不一致／取消／再確認の各条件は独立ケースで確認。
- AC-005、AC-006。版別domainの合成署名の正負と、平坦な既存製品配置の旧packetのsigned-only正負を区別する。4段階すべてのlive／固定の相反するケースとネストを検査。従来の固定レビュー前提を満たすPとランチャー配布元Rに、同じ名前・同じバイトの条件読取モジュールを置き、実際にロードしたRの実パス・SHA-256がinventoryに含まれることを示す。Pを維持したままRだけが欠落／変更する各ケース、従来固定するPの資材だけが欠落／変更する各ケースで失敗し、予約追記・審査開始が0であることを記録。無効な入力によって成功扱いした結果は受け入れない。
- AC-007、AC-008。公式sourceの資材チェックの成功と非0の各条件、複数版・代替ファイルのある対照、リンク経由の同版、別リポジトリ、DDDなし／indexの対象別結果を確認。正常v2とPython不在で両ラッパーの終了3・空のstdout・診断stderr、ゲートの1／FAIL／BLOCK／後続0を確認し、人の却下およびDDDなしの正常対照と区別。Unix系NodeのshとWindowsネイティブNodeのpwsh経路を実環境別に記録する。環境がなければ未実行と記し、別OSのpwshや配置fixtureを実ホスト合格に含めない。
- 着手時に高リスクpreflightを記録する。永続化される `concept-test.decision.json` と提案・選択、`checks.conceptTest` と child の終了値・後続件数、固定 `inputs[].sha256` と選択したGit blob、固定 `dependencies.json` の実パス・SHA-256とRでの実ロード先・バイト、配布資材ダイジェストと正本の各組について、片方だけ違う入力が不合格となる試験を先に定める。最終候補の独立検収を引き渡す。

### Blockers

- None

## Spec Amendments

2026-11-23　第1回独立審査の指摘に合わせ、T-001の実ホスト・署名互換・物理パスおよびOS別の検収記録を具体化した。
