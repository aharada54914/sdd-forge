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

## Track Detection

本スキルはトラック選択を読む Capability Mode 関連のエントリポイントである。
lite ゲートとして実行してよいか、full quality-gate に切り替えるべきかは、
ここで解決したトラックが決める。まず hook-activation ハンドシェイクを実行する:

<!-- sdd:handshake-wiring v1 -->

1. `check-hook-activation-handshake --emit-challenge` — 新しい nonce と
   カナリア対象 `sdd/.hook-canary-sentinel` を返す。
2. エージェント自身が、チャレンジに含まれるランタイム別テンプレートを用いて
   そのカナリア対象への**実際の**ツール呼び出しを試み、生の結果をそのまま記録する。
3. `check-hook-activation-handshake --verify-response --nonce <nonce>
   --recorded-result <path> --runtime <claude-code|codex-cli|copilot-cli>`。
4. `HOOK_ACTIVE` なら続行。それ以外の結果はすべて
   `CAPABILITY_RUNTIME_UNAVAILABLE` で停止する。レガシー動作へ黙って
   フォールバックしない。

<!-- /sdd:handshake-wiring -->

次にトラックを解決する。**物理的存在の確認が先、承認検証が後**である。
`sdd/project-context.yaml` が存在するのに `validate-approval-sidecar` に
失敗する状態は、ファイルが存在しない状態とは**別物**として扱う。両者を同一
視することが ADR-0023 の塞ぐ fail-open である。

<!-- sdd:track-selection-contract v1 -->

| Case | Project Context | Flag | Resolution |
|---|---|---|---|
| C1 | physically absent | `--full`, `--lite`, or none | `COMPATIBILITY_FALLBACK` |
| C2 | physically present, REQ-005 validation fails | `--full`, `--lite`, or none | `PROJECT_CONTEXT_INVALID` |
| C3 | physically present and valid, `spec_profile: lite` | `--full` | `PROMOTE_FULL` |
| C4 | physically present and valid, `spec_profile: lite` | `--lite` | `NO_OP_LITE` |
| C5 | physically present and valid, `spec_profile: full` | `--lite` | `ERROR_STOP` |
| C6 | physically present and valid, `spec_profile: full` | `--full` | `NO_OP_FULL` |

<!-- /sdd:track-selection-contract -->

- `COMPATIBILITY_FALLBACK`（C1 のみ）— 従来の優先順位（`--lite` → lite、
  `AGENTS.md` の `spec_profile: lite` → lite、既定 → full）をそのまま適用する。
- `PROJECT_CONTEXT_INVALID`（C2）— その名前を報告して停止する。品質レポートを
  生成せず、`Status` も変更せず、C1 のフォールバックへ落とさない。
- `PROMOTE_FULL` / `NO_OP_FULL` — 解決トラックは `full`。本スキルは実行せず、
  full quality-gate に切り替える。
- `NO_OP_LITE` — 解決トラックは `lite`。以下の Process を実行する。
- `ERROR_STOP` — 明示的なエラーで停止する。`--lite` が `full` プロファイルを
  格下げすることは決してない。

この表の正本は `PLUGIN-CONTRACTS.md` の Track Detection セクションである。

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
