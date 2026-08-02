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

- **T-003 QG Minor carryover** (2026-07-30, seq0350 NEEDS_WORK 報告より):
  ① `resolve_evidence_key` の既存 `_resolve_sudo_key` 系との**実行的**
  パリティ証明（ソース検査を超える independent import/exercise、AC-013
  4-case 行列)は未実施のまま — T-006 の validator 側 key 解決実装時に
  合同で証明するのが自然な合流点。② もう 1 件の Minor は seq0350 報告書
  （reports/quality-gate/2026-07-30T142236Z-T-003.md)参照。Major
  （staging 経路 OSError の未分類 exit 1)は remedy 対応中で carryover
  対象外。

- **T-004 QG Minor 4件の処遇** (2026-07-30, seq0351 PASS 報告より、全て非ブロッキング):
  ① T-004.md:101-106 の「run-all/CHANGELOG は landing 以来 unchanged」注記は
  事実誤認（T-003 系コミットが接触。宣言 hash は live 一致で無害)—
  **報告書は編集しない**: quality-gate SKILL 自身の規則（「record the
  current values directly in this quality-gate report … do not edit the
  frozen implementation report to reconcile it」)に従い、正値は QG 報告書
  （2026-07-30T143105Z-T-004.md)が記録済み。carryover 記録のみ。
  ② red ログが existence-based（評価者の mutation runs で束縛性補償済み)
  — 記録のみ。③ green ログ両レーン byte-identical（区別性は red 側)—
  記録のみ。④ **traceability.md:95 の AC-045 に split 注記なし**（AC-046
  は 3 分割注記あり)— **T-005/T-006 への carry-forward**: T-005 は AC-046
  verdict 半分の production check、T-006 は AC-045 の semantic-validator
  本体 + ordering assertion の義務を実装時に明示すること。traceability.md
  は凍結のため注記追加は最終 re-binding 時に検討。

- **T-007 carry-forward: TRANSACTION.json shape の準拠義務** (2026-07-30,
  T-005 implementer relay): `sdd/.staging/*/TRANSACTION.json` の shape
  （`targets[]` 各 `{live_path, pre_hash, post_hash}`)は T-005 が定義した。
  T-007（apply-human-copy)はこの shape に**準拠するか、明示的に改訂**する
  義務がある — T-007 launch プロンプトに織り込むこと。関連記録:
  project-context.schema.json の components[] に additionalProperties:false
  が無い件は曖昧性源ではなかった（T-005 relay #3、記録のみ)。

- **T-005 QG seq0353 の carryover 群** (2026-07-30):
  ① **T-007 carry-forward への統合**: TRANSACTION.json shape 準拠義務に
  加え、**shape 不一致 journal の拒否**を義務化 — 現行 reader は valid
  JSON だが `targets` list を欠く journal で fail-OPEN
  (detect-policy-weakening.py:201-203、L203 未実行) → T-007 の publisher/
  recovery 実装はこの shape を強制し、不一致は fail-closed で拒否すること。
  ② `--approved-context`（test-only flag)の不存在パス silent bootstrap
  降格 — 記録のみ。
  ③ **評価者 observation（finding 外・重要)**: 単一 `--approver` でも
  `two_person_required: true` verdict を埋めた署名が成功する — tasks.md
  T-005 Out of Scope の「T-003 already ships that behavior」は署名時点で
  不成立。正当な置き場所は REQ-005/T-006 の
  `validate-approval-sidecar --verify-provenance`。**T-006 が実装する義務**
  として launch プロンプトに明記済み（gate の既強制誤認防止)。
  ④ relay 判定の記録: #1 TRANSACTION.json shape = design-conformant、
  #2 glob-narrowing 拡張 = 方向性 conformant（欠落はテストのみ・remedy 中)、
  #3 additionalProperties = 非問題確定。

- **T-005 QG round-2 (seq0354) carry-forward 注記 2 件** (2026-07-30):
  (a) two_person gap は T-006 着地まで unguarded — T-006 launch プロンプト
  義務 4b として**登録済み確認**（validate-approval-sidecar が強制点)。
  (b) **tasks.md:1215 付近の T-005 Out of Scope 括弧書き「(T-003 already
  ships that behavior…)」は事実不正確**（署名時点で two-person 整合は
  未強制)— tasks.md は凍結境界のため本 note で訂正を記録し、実文修正は
  最終 re-binding 時の候補とする（正値: 強制点は T-006 の
  --verify-provenance / 標準検証経路)。

- **T-006 implementer relay の carryover** (2026-07-30):
  ① T-005 residual: detector の distinct-count は重複 id を silent dedupe
  したまま（T-005 out-of-scope 記録済み)。T-006 validator 側 gate は
  `DUPLICATE_APPROVER_REGISTRY_ID` で registry 重複自体を拒否するため
  count 依存なしで discharge — detector 側の dedupe 挙動是正は最終フェーズ
  検討事項として記録。
  ② **design-vs-decomposition gap**: design.md REQ-004 文の「staged
  (pre-publish) candidate の provenance 再導出」記述に対応する TEST id が
  T-006 の凍結 Done-When に無く、意図的未実装（TDD 駆動不能・guess 回避)。
  **T-007（publisher の publish 前再検証経路)の関心事の可能性** — T-007
  実装時に design 実文と照合し、T-007 スコープ外なら residual として
  最終 re-binding 判断へ。
  ③ regression runner: tests/prepare-panelist.tests.sh の失敗は
  T-006 非起因を orchestrator が独立確認（最終変更 298cf22b/2f93edd6 =
  #108/#185 系、env -i でも再現、既知 run-all 失敗連鎖の一部)。T-006 Done
  チェーンの regression 段は直接関連スイートの個別実行で代替記録する。

- **T-006 QG seq0355 Minor carryover 2 件** (2026-07-30):
  ① UnicodeDecodeError が INTERNAL_ERROR(90) に誤分類（意図されたカテゴリは
  37。fail-closed は維持されており実害なし)— 将来の分類精緻化候補。
  ② HMAC 比較が uppercase-hex を `.lower()` で受理（contract は lowercase
  64-hex)— T-013 系の仕上げ or 最終 re-binding 時の修正候補。
  （Major = 「同一 approver × --verify-provenance」セルの未テスト
  (py:678 到達不能 by 標準経路 gate 3 先行遮断) は remedy 対応中で
  carryover 対象外。評価者の好材料記録: bootstrap-downgrade 攻撃の HMAC
  ゲート捕捉実証・key-parity 3 実装 AST 検証・hostile 20 ケース全分類。)

- **T-006 QG round-2 (seq0356) carryover** (2026-07-30):
  ① **新規 hardening 候補**: `--verify-provenance` 限定で primary_approval
  が非 dict（例: 文字列)の two-person weakening sidecar が gate5 を回避
  （標準経路は SIDECAR_MALFORMED(38) で捕捉・要署名鍵・全 AC/TEST 範囲外)
  — validator hardening 候補として最終フェーズ or 将来タスクへ。
  ② **feature 完了判定用の明示記録**: **AC-019 の generator 半分は
  feature-wide で未充足のまま**（T-003 gap・TEST-019(a) が現挙動を
  regression lock)。**feature 完了判定時に AC-019 を「充足」とマークしては
  ならない** — 充足には T-003 側のクローズ判断（design/decomposition の
  正規経路)が必要。placeholder scan がこの残余を説明する suite コメントを
  検出する事象は qg/T-006/placeholder.log の受理注記で処理済み。

- **T-007 QG seq0357 の carryover** (2026-07-30/31):
  ① Minor 3 件（QG 報告書 2026-07-30T204328Z-T-007.md 参照): dead な
  dev/inode 検査 + 過大なコメント主張 / ps1 コメントの誤記述 + cmdlet 残余
  / symlink 拒否のカテゴリ混同 + unknown-flag の exit 差 — いずれも
  非ブロッキング、最終フェーズの仕上げ候補。
  ② **reader 耐性（T-007 スコープ外・実測済み)**: detector の journal 読取は
  `open(..., encoding='utf-8')`（detect-policy-weakening.py:192)で、BOM 付き
  JSON は `JSONDecodeError` になることを実測確認（`utf-8-sig` なら OK)。
  現状この失敗は `HUMAN_COPY_PUBLISH_IN_PROGRESS` に分類され **fail-closed**
  （安全側)だが、正当な publisher journal を「torn」と誤判定する偽陽性に
  なりうる。T-007 Major 3（ps1 の BOM 除去)修正後は T-007 起因としては
  moot。**reader 側の耐性強化（utf-8-sig 受理)は carryover 候補**（安全性を
  下げない緩和 = BOM のみ許容し、それ以外の不整合は現行どおり fail-closed)。
  detect-policy-weakening.py は T-005 の凍結成果物のため、変更は正規の
  タスク/ゲート経路で。

- **T-007 QG round-2 (seq0358) carryover** (2026-07-31):
  ① ps1 スイートの 5 アサーション非対称（挙動自体は正・カバレッジ表現の
  対称性課題)② backup found/not-found シグナルの不精密（機能は正)
  ③ ADR-0025 関連 Done-When 文言との軽微な逸脱（開示済み・substance 充足)
  — いずれも非ブロッキング、最終フェーズ仕上げ候補。
  ④ **評価者 observation（third-state probe)**: 回復時に target が PRE でも
  POST でもない（外部編集された)第三状態にある場合の扱いは design の
  収束列挙（all-pre / all-post)の外だが、両レーンが同挙動 — design 明文化
  候補として記録（現挙動の是非判断は将来の design 改訂ゲートで)。
  （新規 Major = 空白入り path の sh IFS 構造破壊 journal は remedy-2
  対応中で carryover 対象外。round-1 の 4 指摘は評価者の fixture 再構築 +
  revert-mutation で全解消実証済み。)

## T-007 seq0360 Minor: apply-human-copy `--help` 文書化不存在

- **出所**: QG round-4（seq0360、`reports/quality-gate/2026-07-31T113826Z-T-007.md`)
  の Minor 所見。評価者は非ブロッキングと判定。
- **内容**: `apply-human-copy.sh` / `.ps1` に `--help`（usage 出力)が存在せず、
  分類済み exit code 体系（特に remedy-3 で新設された
  `UNSUPPORTED_PATH_CHARACTER` = exit 20)が CLI 上から発見できない。
  兄弟タスクの先例（T-002 の exit 3 / T-003 の exit 16)は `--help` に記載あり。
- **対処方針**: T-007 のフォローアップ（epic 内の後続タスクまたは別 feature)で
  `--help` を追加し exit code 表を記載する。R-10 非対象のため通常編集で可。
  remedy-4 のスコープには含めない（remedy-4 は seq0360 の Critical/Major のみ)。

## 既存不具合: phase2-guard-invariants の pwsh レーンが macOS で 9 件失敗

- **出所**: T-009 の Done チェーン生成時（コミット `2ff3e609`)に発見。当該
  エージェントが**補足セクション**として隣接 guard スイート3種を追加実行した
  ところ判明した。T-009 の必須 regression セット（8 スイート × 2 レーン、全
  green)には含まれない。
- **内容**: `pwsh -NoProfile -File tests/phase2-guard-invariants.tests.ps1` が
  **59 passed / 9 failed**（exit 1)。bash 版 `tests/phase2-guard-invariants.tests.sh`
  は 33/0 で green。失敗 9 件はすべて TEST-013 系で、junction・保持ハンドル・
  インベントリ外ハードリンク別名・固定のネイティブ置換 API といった
  **Windows/NTFS 固有セマンティクス**を macOS 上で実行していることに由来する。
- **T-009 起因ではないことの証明**: `git archive 15b53914`（T-008 の Done
  コミット = T-009 のコミットが1つも存在しない時点)を使い捨てディレクトリへ
  展開して再実行したところ、**バイト単位で同一の 9 件失敗**を再現（FAIL 行の
  `diff` が空)。
- **注意**: seq0364/seq0365 の評価者はこのスイートの **bash 版のみ**を実行して
  いたため、この pwsh 側の失敗は QG レポートには現れていない。
- **対処方針**: (a) 当該 9 件を非 Windows ホストで明示スキップする（他スイートの
  `$IsWindows` 分岐の先例に倣う)か、(b) macOS でも成立する形へ書き換えるか、
  (c) CI が Windows レーンを持つならホスト限定テストとして正式に宣言する、の
  いずれか。**epic-189-a1 のスコープ外**（`tests/phase2-guard-invariants.tests.ps1`
  はどのタスクの Planned Files にも含まれない)。
