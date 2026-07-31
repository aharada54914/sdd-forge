# 裁定記録: T-007 QG サイクル上限と round-4 継続手順 (2026-07-31)

## 論点

T-007 の quality gate が seq0357/0358/0359 の 3 ラウンド NEEDS_WORK に達した。
以前 orchestrator は「round 3 = attempt 1 終端」と述べたが、これは
review-loop（spec/impl/task)の 3 ラウンド終端規則を QG に誤って適用した
もの。QG の実規則を実文で裁定した。

## 裁定（実文根拠)

- **QG SKILL.md `## Process` 項 11（逐語)**:
  > Repeat critical review for a maximum of 3 cycles. Stop earlier when
  > the remaining issue requires human decision, missing evidence cannot
  > be produced, or the fix belongs to `fix-by-review-ticket` or an
  > upstream review loop. Do not downgrade a finding merely to end the
  > loop.
- **決定論スクリプト `check-quality-gate-cycle-limit.sh`**: 当該 task を
  参照する `reports/quality-gate/` 内レポート数を `grep -rlwF` で数え、
  `>= 3` で `Escalate-Human`（exit 1)、それ未満で `continue`（exit 0)。
- **T-007 実測**: `check-quality-gate-cycle-limit.sh T-007` →
  **`Escalate-Human` / exit 1**（seq0357/0358/0359 で閾値到達)。

**結論**: 上限は「3 サイクルで自動失格」ではなく **「3 到達で人間
エスカレーション」**。exit 1 = 「人間判断を仰げ」であり禁止ではない
（SKILL 11 の "Stop ... when the remaining issue requires human decision"
と整合)。T-002 が QG 4 ラウンドで PASS した前例（レポート 21 本）は、その
人間判断下での継続として矛盾しない。以前の「終端」発言は誤りとして撤回。

## 承認された手順（人間逐語「orchestrator 推奨に同意」2026-07-31)

1. remedy-3 の独立検証を先に実施（hostile 文字行列 spot-check +
   journal round-trip + T-005 reader 照会を必須)。
2. 検証結果サマリを coordinator(main)へ。main が人間への判断提示
   パッケージを作成（second-approver 署名 + human-copy/ untracked 解消の
   human 接点も同梱)。
3. 人間が **round-4(seq0360)継続 or review-ticket 経路(SKILL 13)で残件を
   切り出して T-007 を close** を判断。
4. **この承認は「手順への同意」であり round-4 継続の認可そのものではない**
   — 継続認可は検証結果提示後の別判断。認可までは seq0360 を予約しない。

## 背景（判断材料として記録)

- 3 ラウンドとも評価者が実在の重大欠陥を発見し、implementer が根本修正で
  応答（品質ループは機能中)。指摘は毎回**新規クラス**（0 バイト backup →
  IFS 空白 → JSON エスケープ/glob)で堂々巡りではない。
- ただし 3 連続で**同型のパリティ破れ**（sh 側のみ破綻・ps1 正常)= sh の
  path 処理全般の構造的脆弱性。main は remedy-3 で**クラス根絶**を指示済み
  （reader/writer round-trip 完全性 + glob 無効化 + hostile-path property
  行列)。効けば収束、効かなければ sh 側 path 運搬機構の設計見直し。
- seq0359 報告で 3 defect が Unresolved Items 非開示だった点も評価者が
  記録（implementer 自己申告品質として人間が把握すべき事項)。

## 人間承認（2026-07-31、逐語)

> orchestrator 推奨に同意

**承認の範囲（明確化)**: これは**手順への同意**であり、**round-4 継続の
認可そのものではない**。round-4(seq0360)の継続認可は、remedy-3 の独立
検証結果を提示した後の別判断。

**確定した運用**:
1. remedy-3 完了報告受領 → 独立検証（hostile 文字行列 spot-check +
   journal round-trip + T-005 reader 照会を必須)。
2. 検証結果サマリを coordinator(main)へ。main が人間への判断提示
   パッケージを作成（second-approver 署名 + human-copy/ untracked 解消の
   human 接点も同梱)。
3. 人間が round-4 継続 or review-ticket 経路(SKILL 13)で close を判断。
4. **認可までは seq0360 を予約しない**。

## 人間の round-4 継続認可（2026-07-31、AskUserQuestion 回答)

**判断**: 「round-4 継続を認可」。`check-quality-gate-cycle-limit.sh T-007`
の `Escalate-Human`（cycle-limit 3 到達)に対し、人間が QG round-4
(seq0360)の実施を正式認可した。

**判断材料**: orchestrator の remedy-3（commit `25d5728c`)独立検証サマリ —
diff は Planned Files 内（ps1 全面再構築含む)、Outputs 26/26 live 一致、
両レーン 130/130・72/72、hostile 文字行列の 4 指定ケース（`"`/`}`/glob/
backslash)全てで journal round-trip + T-005 reader 照会 + ALL-PRE 収束 +
litter なし + パリティ、backslash は両レーン同一 `UNSUPPORTED_PATH_CHARACTER`
(exit 20)拒否を実測。留意点として exit 20 の `--help` 未記載・ps1 anchoring
再構築への敵対検証未実施・3 ラウンド連続の sh 側新規クラスを提示済み。

**根拠整合**: cycle-limit の `Escalate-Human` は禁止でなく人間判断要求
（本ノート上部の裁定)。品質ループが機能中（毎回新規クラス発見 → 根本修正)
かつ remedy-3 はクラス単位の対処（AWK パーサ・行列検証)であることから
継続が妥当と人間が判断。round-4 で収束しなければ review-ticket 経路(SKILL
13)への切替を再検討する。

## 人間の remedy-4 + round-5 継続認可（2026-07-31、AskUserQuestion 回答)

**判断**: 「remedy-4 + round-5 を認可」。round-4（seq0360)の verdict は
NEEDS_WORK（Critical 1 / Major 3 / Minor 1、報告書 =
`reports/quality-gate/2026-07-31T113826Z-T-007.md`、commit `3f57c485`、
sha256 `0d8510e2a28bda0a55562529b93d65d17d2cfd3cabf3534ec2b913167863ba2b`)
だったが、人間が remedy-4 実施と QG round-5（seq0361)の継続を明示認可した。

**判断材料**（= seq0360 報告書):
- Critical: probe 失敗の 'ABSENT' 強制変換（両レーン同一のため非パリティ
  ゆえ過去 3 ラウンドのパリティ中心検証の構造的盲点)+
  design.md:1055-1056 の PRE 復帰確認ステップ不存在。
- Major 3: C0 制御文字の raw 出力（sh)/ CR の両レーン能力乖離 /
  glob 修正の回帰ロック欠落（評価者の mutation で実証されたギャップ)。
- Minor 1: `--help` に exit 20 等の文書化不存在（非ブロッキング判定、
  carryover 登録)。
- 好材料: ps1 anchoring 再構築は評価者の敵対検証（自作 decoy 5 種)を
  全通過、crash-injection 4 シナリオ green、cmdlet 残余なし確認。

**継続根拠**: 検証ループは機能し続けており（round-4 も新規クラスを発見)、
Critical は fail-closed 化 + 設計手順追記で対処可能なクラス。remedy-4 の
方針 = Critical: probe 失敗の fail-closed 化 + PRE 復帰確認ステップ /
Major 1+2: per-character ポリシー（escape-or-reject 対称)/ Major 3:
SEGMENT glob fixture + mutation 証明。round-5（seq0361)の予約は remedy-4
の orchestrator 独立検証完了後・実行→実値→報告の順で行う。
