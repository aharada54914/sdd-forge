---
name: lite-gate
description: Lightweight deterministic quality gate for the sdd-lite flow. Runs placeholder-scan and the project's lint/typecheck/build/test commands, writes a lite quality report, moves the task to Done, then validates the final Done state with check-task-state-lite. Use after implement-task in the lite flow.
disable-model-invocation: true
user-invocable: false
---

# Lite Gate

sdd-lite の軽量品質ゲート。実装者の自己申告でなく、ゲート自身が検証コマンドを再実行して結果を記録する（自己採点防止の核を低コストで維持）。evidence-bundle / contract.json / cross-model / 署名は扱わない。

## Invocation

Codex:

```txt
Use the lite-gate skill for specs/<feature>/tasks.md#T-001
```

Claude Code:

```txt
/sdd-lite:lite-gate specs/<feature>/tasks.md#T-001
```

## Preconditions

- 対象タスクが `Status: Implementation Complete` かつ `Approval: Approved`。
- `reports/implementation/<task-id>.md` が存在する。
- 望ましくは別コンテキスト/別セッション（または委譲）で実行し、実装者の主張を独立に再検証する。

## Process

> **順序が重要**: `check-task-state-lite` の `Done` 専用検証（実装レポート + 品質レポート `VERDICT: PASS` の存在）は、品質レポートを生成し `Status: Done` に遷移した**後**に実行する。先に実行すると（タスクがまだ `Implementation Complete` でレポート未生成のため）Done 専用検証が一度も実走せず、不正・別タスク向けの PASS レポートでも Done が残る。

1. 変更範囲に対し `plugins/sdd-quality-loop/scripts/check-placeholders.sh`（または `.ps1`）を実行。
2. プロジェクトの lint / typecheck / build / test コマンドを**自分で実行**し、出力を捕捉する（コマンドはプロジェクトの AGENTS.md / 設定から判定）。コマンドが無い種別は「N/A」と記録し理由を添える。
3. `reports/quality-gate/<task-id>.md` を `templates/quality-report-lite.md` から生成する。先頭に `Task ID: <task-id>` と `VERDICT: PASS|FAIL` を必ず置く（`check-task-state-lite` の Done 判定が依存）。各チェックの PASS/FAIL と根拠を列挙。Step 1–2 に1つでも FAIL があれば `VERDICT: FAIL` を記録し、`Status` は変えず実装者へ差し戻して終了。
4. `VERDICT: PASS` のときのみ `tasks.md` の対象タスクを `Status: Done` にする。
5. **最終検証**: Done 化と品質レポート生成の**後**に `plugins/sdd-lite/scripts/check-task-state-lite.sh`（または `.ps1`）を実行し、`Done` 状態を決定論的に検証する（実装レポートのタスク ID 言及 + 品質レポートの `VERDICT: PASS` 言及を含む Done 専用チェックがここで初めて実走する）。失敗したら `Status` を `Implementation Complete` に戻し、レポートに失敗理由を記録して差し戻す（`Done` のまま残さない）。

## Boundaries

- evidence-bundle / contract.json / cross-model-verify / 二者承認 / リスク階層強制は行わない（昇格時は full quality-gate に切替）。
- `Approval` を変更しない（人間のみ）。
- Done は本スキルのみが設定する（implement-task は設定しない）。

## Handoff

VERDICT と各チェック結果、Done 化の有無を報告する。FAIL 時は不足点を明示し implement-task への差し戻しを案内する。
