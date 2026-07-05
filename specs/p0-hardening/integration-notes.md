# 統合メモ: feat/p0-hardening → main

作成: 2026-07-01。目的: `feat/p0-hardening` を（他ブランチと共に）main へ統合する際の、`codex/review-loop-prompt-calibration` の WIP との整合を明文化する。

## ブランチ関係

- **feat/p0-hardening**: 分岐元 = `codex/review-loop-prompt-calibration` の HEAD（`0dea66c`）。コミット: P0-1/2/3 + specs/tests + `diagnose` スキル + workflow-guide 追記 + 本メモ。
- **codex/review-loop-prompt-calibration の WIP**（未コミット, 43ファイル, 現在 stash 退避中）: plugin.json 版上げ・reviewer トリム・テスト簡素化・docs 更新。

## ファイル競合の有無

feat が触るファイルと WIP が触るファイルは、**1ファイルを除き重複なし**（＝git マージは概ねクリーン）。

- **重複する唯一のファイル: `docs/workflow-guide.md`** — feat は末尾に「バグ修正トラック（diagnose）」節を追加。WIP も同ファイルを変更。→ **マージ時に doc コンフリクトの可能性（解決容易: 両方の変更を残す）**。

## 唯一の意味的競合（要判断・最重要）

WIP は `plugins/sdd-review-loop/agents/task-reviewer-b.md` から **`BUGFIX-DIAGNOSTIC-PATH` チェックを完全削除**（実測: WIP=0件 / HEAD=存在）。

feat の `diagnose` スキルはこのゲートに診断証跡を供給する設計。**両方を main にマージすると診断ゲートが消え、diagnose の証跡を検査するゲートが無くなる。**

### 推奨: ゲートを残す

削除が意図的でない限り、`BUGFIX-DIAGNOSTIC-PATH` を task-reviewer-b.md に復元する。当ファイルは hook-guard R-10 で**エージェント編集不可（人間専用）**のため、作者が直接復元する。以下のブロックを Checks セクション末尾（DEPENDENCY-OVERLAP の後）に戻し、Output Format の checks 配列順の最後に `BUGFIX-DIAGNOSTIC-PATH` を含める:

```
## BUGFIX-DIAGNOSTIC-PATH (Major, TYPE-H)

Apply this check only to tasks explicitly scoped as bugfix, regression fix,
debugging, failure diagnosis, flaky-test resolution, or incident remediation
(based on title, Goal, Scope, or Done When text). For those tasks, verify the
task includes:
- Reproduction evidence or exact reproduction command/symptom.
- A diagnostic or root-cause investigation step before implementation.
- A regression test, verification command, or evidence artifact proving the
  original failure is fixed.

If no bugfix/debugging task exists, emit SKIP with finding
"SKIP: no bugfix or debugging task in scope." A bugfix/debugging task that
starts directly with an implementation change and lacks diagnostic or regression
evidence is a Major finding.
```

> 削除が意図的なら、代わりに `diagnose/SKILL.md` と `workflow-guide.md` の「BUGFIX-DIAGNOSTIC-PATH に証跡を供給」という記述を「実行規律のみ（検査ゲートなし）」に改める。どちらを採るかは作者判断。

## 推奨マージ順

1. **先に WIP を確定**: reviewer トリムの是非、特に `BUGFIX-DIAGNOSTIC-PATH` の去就を決める（上記）。
2. **次に feat/p0-hardening をマージ**: workflow-guide.md のコンフリクトは両変更を残す形で解決。ゲートを残す方針なら diagnose と整合。
3. **main の遅延に注意**: local `main` は `origin/main` から120コミット遅れ。**stale な local main への直接マージは避け**、先に `origin/main` を取り込んでから統合する（`git switch main && git pull` 相当の後）。
4. 統合後、`bash tests/p0-hardening.tests.sh` が VERDICT: PASS を維持することを確認。

## 検証

- feat 単体では `tests/p0-hardening.tests.sh` = VERDICT: PASS（REQ-001/002/003）。
- 統合後も上記テスト + 既存テストスイートを回すこと。
