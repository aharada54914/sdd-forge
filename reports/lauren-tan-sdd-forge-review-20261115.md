# Lauren Tan 講演と SDD Forge の照合調査

調査日: 2026-11-15 UTC。対象: v1.23.1、`08e56b843203ad5dc86b25ec4481d0d7497591b8`。
種別: 調査と改善提案。製品コード・仕様承認・タスク状態は変更していない。

## 結論

既存機能を活用し、実利用の網羅性と、失敗から決定論的検査への接続を改善するのが妥当。
機能マップ、検証手順の保守、形式検証、失敗由来の評価セットは既に存在する。
これらを「未実装」として再導入すると重複する。今回確認した具体的な改善候補は、
Python の起動名に依存するテスト、機能単位の実行カバレッジ、限定モデルの対象拡張、
再発条件から回帰検査への接続である。効果量は未測定。

## 外部根拠と取得限界

- 入力動画: https://www.youtube.com/watch?v=O_zcc6Xl12g
- 主催者による講演ページ・機械生成全文字幕: https://ai.engineer/code/2026/talks/lauren-tan
- 参照先の公開実装: https://github.com/cursor/plugins/tree/main/pstack

登壇者は Lauren Tan。主催者ページの主要点は、設計と検査への制約の埋め込み、
実動作の証拠、十分な検証を先行させた自動化である。字幕の時計はライブ配信基準。
1:03:27付近が制約の優先順位、1:11:00付近が動作検証の説明。
字幕には認識誤りがあり、切り出し動画の秒数には換算していない。
PR数・revert率は登壇者の自己報告であり、SDD Forgeの目標値や因果的根拠にはしない。

YouTube本体はWeb取得制限、環境からのHTTP取得は403で利用できなかった。
主催者ページを検索して本文を確認し、そこから実装参照先pstackへ進んだ。
GitHubはWeb取得制限があったが、接続済みGitHub経由でディレクトリを確認できた。
動画の視聴・音声照合・字幕原本のハッシュ検証は未実施。検索断片だけを原文検証済みとは扱わない。

## スキル・プラグイン

- 既存のローカル `pstack-how` を適用して、実装と既存テストを照合した。
  場所: `/workspace/.tools/sdd-forge-dev/pstack-codex/skills/pstack-how/SKILL.md`。
  Codex向けローカル適合版であり、公式Codex版の導入とは異なる。
- プラグイン管理スキルでYouTube字幕対応を検索。vidIQが候補として見つかり、導入を提案済み。
  接続は確認できていないため、使用済み・導入完了とは扱わない。
- pstack/ECCは環境に存在する既存資産を優先。新しい外部コードのインストールはしていない。

## 実装との対応

| 調査観点 | 確認した既存実装 | 評価と残る確認 |
|---|---|---|
| 制約の機械化 | `plugins/sdd-quality-loop/references/verification-policy.md`、検証契約、証拠ハッシュ検査 | 文書のみの仕組みではない。全規則が自動検査されるとは確認していない |
| 機能マップと実動作 | `plugins/sdd-bootstrap/skills/create-project-skill/SKILL.md` 手順3–7、`scripts/project-skill.py` | 3–5機能の入口・操作・観測・失敗条件を要求。作成時に実行するのは1機能であり、全機能保証ではない |
| 変更後の保守 | `plugins/sdd-bootstrap/skills/maintain-project-skill/SKILL.md` 手順2–5 | 全機能の再実行、未実行のblocked扱いを既に規定。通常開発でどの程度使われているかは未測定 |
| 証拠の真正な対象範囲 | `plugins/sdd-quality-loop/scripts/validate-project-skill.py:313`以降 | trialとtask、現在ソース・実行環境・証跡を分離。試行成功をタスク完了とは扱わない |
| 形式検証 | `tests/fixtures/project-skills/formal-review-reservation/Reservation.tla` と `mapping.json`、`tests/verify-review-reservation.py` | 同じ初期台帳ハッシュを持つ2競合者の一意受付。クラッシュ回復・Windows・ネットワークFS等は対象外 |
| 実失敗からの学習 | `tests/golden/README.md`、7ケース、`tests/golden-eval.py`、`plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md:221`以降 | 回帰・保持評価とWFIは既存。決定論テスト成功とモデルの行動改善は別 |
| 計測 | `plugins/sdd-quality-loop/scripts/run_measurement.py` | 所要時間・token/costと欠測理由を記録可能。実運用の品質向上は今回測定していない |

## 優先順位付き提案

### P1: Python起動名による偽の失敗を切り分ける

今回、`python tests/project-skill-observation.tests.py` は40件中1件失敗し、
同じファイルを `python3` で起動すると40件すべて成功した。
失敗は `test_cli_and_shell` の `runtime-changed`。
`validate-project-skill.py:47` の `runtime_environment()` は `sys.executable` のパスも
指紋に含める。一方、シェルラッパーはpython3で検査を起動するため、同一実体でも
起動名の異なる経路が不一致となる可能性が高い。これは製品のfail-openの証拠ではない。

推奨: まずテスト・カタログの起動契約をpython3に合わせ、異なる起動名を意図的に
拒否するのか仕様化する。実行環境検査の緩和は先に行わない。
受け入れ条件: 同一バイナリの別名と本当に異なるバイナリを区別し、後者・実行後の
バイナリ差替え・環境変化の拒否が引き続き成功すること。

### P1: 既存の機能マップを通常開発の証拠へ結ぶ

新しいマップ形式を作る必要はない。既存の `features/README.md` とCheck IDを使い、
変更の影響を受ける機能ごとに「実行済み／未実行／到達不能・理由」を報告する。
create時の1機能成功やcheck数を、全機能の成功に読み替えない。
まず1つのCLI利用経路で、入力→実行→生成物→失敗経路→cleanupを実証する。
観測の追記は既存の `project-verification-observation` の所有者・互換性に従う。

受け入れ条件: 正常系・前提不足・途中失敗・cleanup失敗を識別でき、未実行の
必須機能を残したまま完了扱いにしない。既存のFull/Lite判定権限は維持する。
この接続が全利用先で不足していると断定するには、別途利用実績の監査が必要。

### P2: 繰り返した修正を回帰チェックへ接続する

既存のWFI・Retention・review ticketを入口に、再発した失敗について
「既存検査で防げる／新検査が必要／設計で除去／判断に依存」を記録する。
同じ機械化可能な失敗を指示文だけで直す場合は、その理由をレビューする。
独立した新台帳を増やさず、既存レコードからテストのパスへ参照を張る。

受け入れ条件: 実失敗1件で旧実装のRED・修正後のGREENを保持し、同型の別入力でも
検出できる。規則を増やした数ではなく、同一失敗の再発と回帰を測る。
承認済みWFIやレビューの状態をこの報告で書き換えない。

### P2: 形式検証を、失敗時の状態遷移へ限定的に広げる

現在の予約モデルは安全性の小さなモデルである。次候補はキャンセル後の結果受付、
古い入力ハッシュを持つ結果の拒否、失敗後の再試行。既存の関連回帰を調べてから、
1つの不変条件を選び、モデルと実装の対応・仮定・除外を明示する。
クラッシュ回復など現在の除外を暗黙に保証範囲へ含めない。

受け入れ条件: 正しいモデルが成功し、意図的に壊したモデルが反例を生成すること。
加えて公開入口を通る実装の負例を持つ。モデル検査成功だけを全アプリ保証にしない。

## 今回実行した検証

| コマンド | 結果 | 解釈 |
|---|---|---|
| `python tests/project-skill-observation.tests.py` | 39/40、1失敗 | 起動名に依存する環境一致失敗を記録 |
| `python3 tests/project-skill-observation.tests.py` | 40/40成功 | 環境・証跡バリデータの回帰。利用者経路全体の検証ではない |
| `python tests/project-skill-formal.tests.py` | 6/6成功 | 実ソース対応と予約のbaseline/負例等。TLCモデル検査本体は未実行 |
| `python tests/golden-eval.tests.py` | 20/20成功 | graderの回帰。新たなモデル比較は未実施 |
| `python tests/run-measurement.tests.py` | 20/20成功 | 計測器の回帰。実運用の改善効果は未測定 |

テスト出力は本報告に結果を要約した。新たなモデルによる独立評価、ネイティブホスト
全体の利用検証、TLC本体、UI fuzz、全テストスイートは未実施。
製品の修正は行っていないため、提案の効果が検証済みとは主張しない。

## 保存時の運用注記

指定の `work/YYYYMMDD-...` は既存ブランチ `work` とGit参照名が衝突し作成できなかった。
既存ブランチを削除せず、`work-20261115-130924-lauren-talk-research` を使用した。
