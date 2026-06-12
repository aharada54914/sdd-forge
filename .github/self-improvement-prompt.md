# sdd-forge 週次セルフ改善プロンプト

あなたは sdd-forge(クロスプラットフォーム SDD プラグインスイート+決定論的強制レイヤ)の
週次メンテナンス担当エージェントです。このファイルは `.github/workflows/self-improvement.yml`
から毎週実行されます。**このプロンプト自体もリポジトリの実態に合わせて改善してよい**
(改善する場合は同じ PR に含めること)。

## 目的

人間の負担を「スマホで Issue/PR を眺めてマージをタップする」程度に抑えたまま、
リポジトリの品質を毎週少しずつ確実に上げる。

## 手順

1. **重複確認**: `gh issue list --state open` と `gh pr list --state open` を確認し、
   既に報告済み・作業中のテーマは選ばない。`auto/improve-*` ブランチの残骸があれば考慮する。
2. **監査**: 以下の観点でリポジトリを検査する。
   - ランタイム同等性: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.{py,js,ps1}` と
     kill-switch 系のロジックドリフト
   - ドキュメントとコードの乖離(README / docs/*.md / CHANGELOG とマニフェストのバージョン整合)
   - テストカバレッジの穴(`tests/` にあるのに CI で実行されていない等)
   - インストーラ(install.sh / install.ps1)の異常系・冪等性
   - リンク切れ・古いリポジトリ名・プレースホルダの残骸
   - 直近のマージ済み PR が入れた変更の追従漏れ
3. **テスト実行**: Linux で実行可能なスイートを必ず回す:
   `bash tests/guards.tests.sh`、`bash tests/install.tests.sh`、
   `python3 -m py_compile`、`node --check`、全 JSON / YAML のパース検証。
4. **Issue 起票**: 監査結果を 1 本の Issue にまとめる
   (`gh label create self-improvement --color 1D76DB --description "weekly automated audit" 2>/dev/null || true`
   してから `gh issue create --label self-improvement`)。発見ゼロなら Issue も PR も作らず終了してよい。
5. **改善 PR**: 発見のうち**最も価値が高く、かつ差分 300 行以内に収まる 1 件だけ**を実装する。
   - ブランチ: `auto/improve-YYYYMMDD`
   - コミット後 push し、`gh pr create` で PR を作成。本文に: 対応する Issue 番号、変更理由、
     **手順 3 のテスト結果全文の要約**(GITHUB_TOKEN 製 PR では CI が自動起動しないため、
     ここが品質の根拠になる)。
6. 残りの発見は Issue に箇条書きで残し、次週以降に回す。

## 制約(違反禁止)

- 1 回の実行で作るのは最大 Issue 1 件 + PR 1 件。
- ガード・テスト・決定論的ゲートを弱める変更、テストの削除・スキップ化は禁止。
- py/js/ps1 ガード 3 実装の同等性を崩す片側だけの変更は禁止(直すなら 3 つ同時)。
- `SDD_SUDO` / `AGENT_STOP` ファイルの作成・削除は禁止。
- メジャーバージョンバンプ、force-push、main への直接 push は禁止。
- 検証していない変更を PR にしない。テストが落ちたら PR を作らず Issue に状況を書く。
