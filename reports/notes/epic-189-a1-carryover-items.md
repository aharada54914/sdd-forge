# epic-189-a1 持ち越し事項（最終フェーズで main が処理)

- **WFI 候補: task-review-precheck の provenance-rereview 例外欠如**
  (2026-07-29, 判断7-A 実行時に顕在化): `task-review-precheck.sh:520-533`
  の round>1 unchanged-tasks check（前 round contract の tasks_sha256 と
  一致なら無条件 exit 1)に `--provenance-rereview` の例外分岐がなく、
  「frozen 無変更で re-bind する」という Post-Implementation Provenance
  Re-Review 自身の前提と矛盾。今回は人間認可の frozen 例外（判断7=A′、
  1行ポインタ追記)で通したが、恒久修正は precheck への例外追加
  （gate script 変更のため WFI → human-apply 経路)。詳細:
  `reports/notes/epic-189-a1-decision-7-task-size-resolution.md` Amendment 節。

- **investigation.md の一時パス引用の恒久化** (2026-07-28, impl-review
  attempt-3 round-2 の reviewer-b 異常報告より): `investigation.md:244-245`
  が preserved-draft の所在としてセッション固有の scratchpad パス
  (`/private/tmp/claude-501/...`) を引用している。設計ドラフト作成時の
  provenance 記録で既知の由来（悪性ではない)だが、リポジトリ外の一時
  パスはセッション終了後に無効になる。最終フェーズの docs 改訂時に、
  permanent な記述（git 履歴のコミット参照等)へ置換するか要検討。
  investigation.md は凍結 spec 層のため、本改訂は正規の改訂ゲートを
  通すこと。
- **ADR 0025 クロスブランチ番号衝突** (既知・再掲): 本ブランチの
  `docs/adr/0025-human-copy-transactional-bundle.md` と epic-191 ブランチの
  path-ownership ADR (0025) が衝突。マージ段で renumber
  （design.md Design Decisions の cross-branch citation contract 参照)。
