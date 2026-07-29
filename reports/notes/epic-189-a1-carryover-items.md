# epic-189-a1 持ち越し事項（最終フェーズで main が処理)

- **WFI 候補: installed role と repo role の乖離検出** (2026-07-29,
  task-review attempt-3 で顕在化): サブエージェントの system prompt は
  プラグインキャッシュ（`~/.claude/plugins/cache/…`)から供給されるため、
  repo 側で human-apply された役割ファイル改訂（WFI-018)がインストールに
  反映されず、レビュアーが正当にも installed 版を権威として改訂規則を
  不適用 → 2 実行が非受理となった。恒久修正候補: インストーラ/`codex-sync`
  または review 系 precheck に「repo の役割ファイル sha256 と installed 版の
  一致チェック（不一致なら STOP: cache sync required)」を追加。詳細:
  `reports/notes/epic-189-a1-seq0342-nonacceptance.md` Amendment 節、
  HUMAN-APPLY-STEPS「WFI-018 cache sync」節。

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

- **docs 整理候補: tasks.md Lifecycle 節ヘッダーの stale 文言** (2026-07-29,
  task-review attempt-4 round-1 reviewer-a の非ブロッキング観察): Lifecycle
  節の「Every task below carries Approval: Draft and Status: Planned」が
  T-001/T-002/T-004 の sudo Approved / Blocked 実態に対し stale。14 チェック
  の defect ではない。最終フェーズの docs 改訂（正規ゲート経由)で更新検討。

- **WFI 候補 + documented interim state: 実装進行に伴う tasks.md の正規 drift**
  (2026-07-29, T-002 Done 直後の workflow-state「task plan hash is stale」で
  顕在化): implement-task の正規ライフサイクル追記（unblock note・
  STAGING DEFERRED note・status 遷移)は task-review contract の束縛 hash
  （raw/normalized どちらの導出でも)を必然的に乖離させる。normalized_hash
  の task 正規化は 3 フィールド行のマスクのみで、ライフサイクルが要求する
  prose 追記を畳み込まない — つまり**実装フェーズ中の task-stage provenance
  は構造的に green を維持できない**（WFI-019 は re-binding 時点の一致を
  修復したが、その後の正規追記で再乖離する)。判断: (a)+(b) の両方 —
  当面は「documented interim state」として許容（4bd2ec3b 以来の同族、
  A1 実装完了時の最終 provenance re-binding で解消。check-task-state /
  check-contract / evidence bundle は green のまま)。恒久修正は WFI として
  最終フェーズへ: normalized_hash の task 正規化に「ライフサイクル公認の
  追記領域（Blockers prose 以下のノート等)の畳み込み」を追加する等、
  検証器側の設計変更（human-apply 経路)。検証器は編集しない。
