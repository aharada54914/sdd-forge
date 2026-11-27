# T-010 ローカルプロファイルの検証（2026-11-26 JST）

## 判定

実行レシートを指定する CLI の回帰検査は成功した。実カタログの計画は195件。今回の実行対象は合成プロファイル2件であり、AC-013 の実プロファイル全件の終了コード比較、SELF-AC-005 の純増時間・誤検知率は未検証。

## コマンドと合成プロファイル

`tasks.md` の T-010 は `--profile local-posix --receipt <path>` を指定する。修正前の統合ツリーでこの形式を実行すると、終了コード0で `verification-plan/v1` を標準出力に返し、指定先にはファイルがなかった。v2.1.3 ではカタログ検証の終了コード2でファイルがなかった。

`tests/verification.py` は、動作を明示せず `--receipt` を指定したときに選択済みのスイートを実行する。動作もレシートも指定しない場合は従来どおり計画を返す。`--plan` と `--list` を明示した場合は、レシートの指定があってもプレビューを返す。

| 確認項目 | 観測結果 |
|---|---|
| 新規 CLI 回帰テストの修正前実行 | 期待する終了コード1に対して0。1件失敗 |
| 修正後の関連テスト | `tests/verification-catalog.tests.py` の CLI 回帰、失敗後の継続、レシートの原子的な保存、並列結果の順序、分割とプレビューの5件がすべて成功 |
| 一時ディレクトリでの独立実行 | `python3 tests/verification.py --profile synthetic-t010 --receipt synthetic.json` で終了コード1。単一の `verification-receipt/v1` に、選択順で `tests/a.tests.py`（failed, 7）、`tests/b.tests.py`（passed, 0）の両方を記録 |

合成カタログの SHA-256 は `652552bb3c0d95e0fdfc78f04db3003e18030f574a99f02f2f3b904a5337147b`。テスト時の基点は `e9f3e3e00cb85d4c039d88582d7ba541925c3d00`、未コミットのランナーの SHA-256 は `2e56fcd6a1fa3f751b87d2ee2536e82ce6a9cdf2ab93b1dc6f347cb2a24c996a`。

## 実カタログと過去の実行結果

| 対象 | 選択と実行結果 |
|---|---|
| v2.1.3（`484cbe7ae`） | カタログ424件。local-posix の登録237件中42件が同じコミットのツリーに存在せず、実行前に計画が失敗 |
| `fc166bd1a` を基点とする変更ありのスナップショット | 最初の実行は182件の終了ログ（成功78、失敗104）を残して停止し、全体のレシートは未出力。別実行のレシートは残り13件（成功4、失敗9）。選択は重複しない |
| 統合後 `e9f3e3e00` | カタログ348件。main の追加スイートと CI 割当を取り込み、ファイルが消えていた77登録の削除を維持した。local-posix の195件すべてが存在し、順序も `4fa6e2bb2` と一致。内訳は Bash 129、Python 65、PowerShell 1 |

過去の失敗113件のうち40件のログに、v2.1.3 と統合前の `4fa6e2bb2` の両ツリーに存在しない計41パスの読み込みエラーがあった。旧 `quality-gate/SKILL.md` や `run-panelist-gpt.sh` が該当する。変更済みワークフローの検査を含む失敗3件、仕様ディレクトリの登録漏れを報じた失敗7件もあった。これらの分類には重複があり、各スイートの全失敗原因は確定していない。

文書・定数の検査2件を v2.1.3 と今回の統合ツリーで直接比較した。`tests/constant-parity.tests.sh` は双方0、`tests/p0-hardening.tests.sh` は双方1だった。実プロファイル全体にはホスト環境を継承したコード注入・サンドボックス境界の再現試験も含まれるため、今回の調査では実行していない。

## 既存レシートの探索

`reports/`、当該仕様の検証ディレクトリ、過去の T-010 用一時ディレクトリ直下とその recording ディレクトリにある JSON を確認した。該当する `verification-receipt/v1` は13件の部分実行分だった。GitHub Actions でも過去スナップショットの基点 `fc166bd1a` の2 run はどちらも artifact 0件で、確認時のブランチの8 run にある artifact 名は `shadow-findings` と `formal-verification` だった。リポジトリの artifact 名 `local-posix` の検索結果は0件。現行ワークフローに `local-posix` プロファイルの起動はない。[テスト run](https://github.com/aharada54914/sdd-forge/actions/runs/45642907784) · [ガードレール run](https://github.com/aharada54914/sdd-forge/actions/runs/45642907895)

再照合した初回ログの SHA-256 は `f98c593f97d71b5ca7f83f6a89ef6968f0d4eb7e24f97a88657046c3962c0568`、残り13件のレシートは `45b8fb123d4dccb1a039739d6b554d95ca3dc870ccf27b9c6824d70000cee300`。いずれも既存の T-010 再検証記録と一致した。
