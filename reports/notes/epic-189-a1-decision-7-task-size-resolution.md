# Decision record: epic-189-a1 判断7 — task-review attempt-2 TASK-SIZE finding の解決経路

**Date**: 2026-07-29
**Decider**: human (repository owner), coordinator (main) 経由で伝達
**Decision**: **選択肢 A**（非 frozen addendum + round-2)

## Question presented (判断7)

task-review attempt-2 round-1（Post-Implementation Provenance Re-Review)で
task-reviewer-b (seq0339) が TASK-SIZE Major を T-001 に対して起票
（merged verdict NEEDS_WORK、evidence commit `19b6b614`)。しかし:

- STEP 6 NEEDS_WORK の唯一の documented exit は「edit specs/<feature>/tasks.md
  → round-2」
- provenance re-review の再束縛境界は frozen artifact（tasks.md 本文)の
  content change を不許可（"it does not license content changes to frozen
  artifacts. Sanctioned post-review updates go to non-frozen addenda per
  AGENTS.md (see ADR 0007)"）
- findings waiver も不可（"never ... a findings waiver"; SDD_SUDO 適用外)
- 指摘対象 T-001 は実装完了・sudo Approved・attempt-1 round-2 (38d525f1)
  で byte-identical の sizing 内容が PASS 済み（TYPE-H 較正差)

の三すくみで、規則内で完結する経路がなく人間判断にエスカレートした
（詳細: `reports/task-review/epic-189-a1-project-context/attempt-2/round-1/tasks-round-1-proposed-changes.md`)。

## Options presented

- **(A) 非 frozen addendum + round-2**: `specs/epic-189-a1-project-context/verification/`
  （再束縛境界が ADR 0007 経由で認める経路)に accepted-deviation 記録を
  作成し、tasks.md 無変更で `--edit-summary` 付き round-2 を実施。
- (B) tasks.md 編集（T-001 遡及分割)を人間が明示認可 — 証跡完全性の観点で
  強く非推奨と整理。
- (C) 「実装完了済みタスクへの TYPE-H sizing 指摘は provenance re-review の
  スコープ外」と裁定し WFI で役割ファイルへ provenance-re-review 条項を追加。

## Decision content (A)

1. `specs/epic-189-a1-project-context/verification/` に T-001 sizing の
   accepted-deviation addendum を永続化（finding 逐語・経緯・本決定への
   参照つき)。tasks.md は無変更。
2. round-2 を `--edit-summary` 付きで実施。edit summary は「tasks.md 無変更・
   addendum 追加のみ・判断7=A の人間決定」を事実として中立に記載
   （reviewer への verdict 指示にしない)。
3. **round-2 の reviewer-b が再度 TASK-SIZE を FAIL した場合は追加ラウンドを
   起こさず停止・報告**（人間が C 案 = WFI 役割ファイル修正への切替を判断)。

## Constraint noted at execution time

`validate-review-context-set.sh` の `path_is_authorized`（task 系)は
`specs/<feature>/verification/` を reviewer manifest の認可パスに含まない
（9 spec .md + calibration + precheck + role別ファイルのみ)。よって addendum
は manifest 束縛ではなく、orchestrator の launch プロンプトに逐語引用 +
repo パス・sha256 を事実として記載する形で reviewer に提示する。

## Amendment — 判断7 更新 = A′ (2026-07-29)

**Decider**: human (repository owner), coordinator (main) 経由で伝達。

A の実行が決定論ゲートに deny された: `task-review-precheck.sh:520-533` は
round > 1 で前 round contract の `tasks_sha256` と現 tasks.md の一致を
無条件 exit 1 とし、`--provenance-rereview` の例外分岐が存在しない
（「tasks.md 無変更で round-2」は構造的に実行不可能)。迂回せず停止・
エスカレートした結果、人間が **A′ を明示認可**:

> frozen 例外として、tasks.md への **accepted-deviation 記録への1行
> ポインタ追記のみ**を人間が明示認可。

**スコープ（逐語で限定)**: 追記は次の1行のみ —
`Accepted-deviation record (decision-7 = A): specs/epic-189-a1-project-context/verification/T-001/sizing-accepted-deviation.md`
（T-001 Blockers prose 直下)。**意味内容・Approval/Status・タスク分解は
不変**。これ以外の tasks.md 本文変更は本認可の対象外。

**WFI 候補（最終フェーズ持ち越し)**: `task-review-precheck.sh` の
round>1 unchanged-tasks check に `--provenance-rereview` 例外がない設計漏れ
（provenance re-review の「frozen 無変更で re-bind」前提と矛盾)。
`reports/notes/epic-189-a1-carryover-items.md` にも登録。
