---
name: lite-gate
description: Lightweight deterministic quality gate for the sdd-lite flow. Runs placeholder-scan, the project's lint/typecheck/build/test commands, and check-task-state-lite, then writes a lite quality report and moves the task to Done. Use after implement-task in the lite flow.
disable-model-invocation: true
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

1. 変更範囲に対し `plugins/sdd-quality-loop/scripts/check-placeholders.sh`（または `.ps1`）を実行。
2. プロジェクトの lint / typecheck / build / test コマンドを**自分で実行**し、出力を捕捉する（コマンドはプロジェクトの AGENTS.md / 設定から判定）。コマンドが無い種別は「N/A」と記録し理由を添える。
3. `plugins/sdd-lite/scripts/check-task-state-lite.sh`（または `.ps1`）を実行し状態機械を検証。
4. `reports/quality-gate/<task-id>.md` を `templates/quality-report-lite.md` から生成する。先頭に `Task ID: <task-id>` と `VERDICT: PASS|FAIL` を必ず置く（`check-task-state-lite` の Done 判定が依存）。各チェックの PASS/FAIL と根拠を列挙。
5. すべて PASS のときのみ `tasks.md` の対象タスクを `Status: Done` にする。1つでも FAIL なら `VERDICT: FAIL` を記録し Done にしない（実装者に差し戻す）。

## Boundaries

- evidence-bundle / contract.json / cross-model-verify / 二者承認 / リスク階層強制は行わない（昇格時は full quality-gate に切替）。
- `Approval` を変更しない（人間のみ）。
- Done は本スキルのみが設定する（implement-task は設定しない）。

## Handoff

VERDICT と各チェック結果、Done 化の有無を報告する。FAIL 時は不足点を明示し implement-task への差し戻しを案内する。
