# Decision record: epic-189-a1 判断8 — provenance re-review 非収束の解決経路

**Date**: 2026-07-29
**Decider**: human (repository owner), coordinator (main) 経由で伝達
**Decision**: **選択肢 C**（WFI 収束規則 → human-apply → 新 attempt-3)

## Question presented (判断8)

task-review attempt-2（Post-Implementation Provenance Re-Review)が非収束:

- round-1: task-reviewer-b (seq0339) が TASK-SIZE Major（T-001)→ 判断7=A/A′
  で addendum + 認可済み1行ポインタ追記により round-2 へ。
- round-2: task-reviewer-a (seq0340) が OBSERVABLE-DONE Major（9 タスクの
  Done-When 文言)。**round-1 で同役割 (seq0338) が同チェックを明示 PASS
  した byte-identical 内容**（差分は認可済みポインタ行のみ、Done-When 節は
  無変更)への新規指摘 — 同一役割・同一内容・fresh instance 間の純粋な
  TYPE-H 較正差が 2 ラウンド連続で発生。

構造診断: frozen 内容 + TYPE-H ヒューリスティック + fresh instance の独立
抽選により、ラウンドごとに別の新規 Major が湧く。round-3 は終端
（SKILL STEP 6: 「Round == 3, Critical or Major findings remain →
BLOCKED … Use --reset」)で、--reset は「set to Pending」が
check-workflow-state の pending-review 規則（Draft/Planned のみ許容)と
衝突し Approved/Blocked 状態では構造的に使用不能。規則追加なしでは収束
しない。

round-2 は second reviewer 未実施のまま中断（適法性分析は 2026-07-29 の
orchestrator 報告参照: merge 式により round 結末は既に非 PASS で確定、
新 attempt の precheck は attempt-1 の persisted PASS のみを参照、未完
attempt ディレクトリの残置は STEP 7 の archive-by-convention が正当化)。

## Options and dispositions

- **(C) 採択**: WFI で task-review の役割ファイル2本と task-review-loop
  SKILL に収束規則を追加 — 「宣言された post-implementation provenance
  re-review において、TYPE-H チェックが prior attempt の persisted
  task-review PASS evidence が束縛した byte-identical 内容（人間認可の
  status/approval/pointer 行を除く)へ新規 finding を起こす場合、当該
  チェックは result/status: PASS とし、観察を finding テキスト内の
  advisory として記録（prior PASS evidence のパス引用付き)。TYPE-D
  チェックは対象外」。設計上の要点: 「Minor advisory 化」では収束しない
  （役割の verdict 規則は findings 空のみ PASS、STEP 5 に round<3 の
  minors>0 PASS 分岐が存在しない)ため、**check 自体を PASS とし advisory
  は finding テキスト内に置く**形式が必須。3 ファイルとも R-10 保護対象
  のため staged patch + HUMAN-APPLY-STEPS 方式（先例 6ecb818b)。
- (A″ 反復) 却下: OBSERVABLE-DONE の指摘対象は 9 タスクの Done-When
  文言そのもので addendum/ポインタでは治せず、文言編集は A′ 認可スコープ
  を大きく超える frozen 本文改変。続行は round-3 BLOCKED → --reset 不能の
  袋小路で、結局 C に合流する。
- (B/waiver) 却下: 「never … a findings waiver」+ Sudo 適用外。

## Deliverables (this session)

- WFI 文書: `docs/workflow-improvements/WFI-018.md`（採番注意: WFI-016/
  WFI-017 は他ブランチで既使用のため 018 を採用、番号照合はマージ段 —
  ADR-0025 と同型のクロスブランチ運用)
- patch: `reports/implementation/epic-189-a1-project-context/wfi-018-provenance-convergence.patch`
  （git-apply-ready、対象 3 保護ファイル、`git apply --check` 検証済み)
- 適用手順: `reports/implementation/epic-189-a1-project-context/HUMAN-APPLY-STEPS.md`
  の「WFI-018」節（適用 → sha256 照合 → コミット → attempt-3 round-1 開始
  までの手順書を兼ねる)
- precheck の `--provenance-rereview` 例外欠如（round>1 unchanged-tasks
  check)は attempt-3 round-1 に不要のため本 patch から分離し、持ち越し
  WFI 候補のまま（`reports/notes/epic-189-a1-carryover-items.md`)。
