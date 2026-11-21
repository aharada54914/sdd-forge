---
name: diagnose
description: Structured 5-phase bug diagnosis discipline (red feedback loop, minimize, falsifiable hypotheses, single-variable instrumentation, regression test). Run before /sdd-bootstrap:bootstrap bugfix for hard bugs, regressions, flaky tests, or performance issues.
disable-model-invocation: true
---

# Diagnose

再現困難なバグ・回帰・フレーキーテスト・性能退行に対する 5 フェーズの診断規律。推測で修正に入らず、確認済みの根本原因と回帰テストを揃えてから `bootstrap bugfix` へ渡す。

> **鉄則**: **赤になる再現ループを作る前に仮説を立てない。**

## Invocation

```txt
/sdd-implementation:diagnose <issue URL | symptom + reproduction steps>
```

## Preconditions

- `AGENTS.md` および影響モジュールの既存設計・テストを確認する。
- `diagnose` では失敗する再現テスト／一時プローブの作成までにとどめ、本番コードの修正適用は承認後の `implement-task` で行う。

## The Five Phases

各フェーズは正当な理由がない限り順番に実行する:

1. **再現ループ構築（最重要）**: このバグで確実に**赤（失敗）になる単一コマンド**を作る（失敗テスト / curl / CLI+フィクスチャ / ヘッドレスブラウザ / bisect 等。詳細は `references/diagnosis-loop-policy.md`）。高速・決定論的・エージェント再実行可能であること。
2. **再現確認と最小化**: 再現出力が報告された症状そのものであることを確認し、依然として赤になる最小ケースへ削ぎ落とす（これが回帰テストの原型になる）。
3. **仮説立案（3〜5 件・反証可能・優先順位付き）**: `X が原因なら、Y を変えると消え / Z で悪化する` の形式で並べる。
4. **1 変数ずつ計測・切り分け**: 仮説境界に絞ったデバッガ／プローブで 1 変数ずつ検証する。一時ログには `[DEBUG-<tag>]` の一意接頭辞を付け、後で一括削除できるようにする（性能問題はログではなく実測・bisect を使う）。
5. **回帰テスト設計と後片付け**: 正しい境界（seam）に回帰テストを書き、赤になることを確認する（適切な seam が無ければ設計課題として記録）。`[DEBUG-*]` プローブはすべて除去する。同種の不具合が過去にも再発している場合（2 回以上）は、個別修正に加えて共通規約・自動検査（lint / `sdd-doctor` 等）への昇格案を診断レポートへ併記する。

## Output

`../../templates/diagnosis-report.template.md` を使い `reports/diagnosis/<id>.md` を作成する（再現コマンド・赤出力・最小ケース・仮説検証結果・根本原因・回帰テスト）。

## Handoff

診断レポートを元に `/sdd-bootstrap:bootstrap bugfix` へ引き継ぐ:
- **通常の不具合修正**: `/sdd-bootstrap:bootstrap bugfix --risk low reports/diagnosis/<id>.md` → 人間承認 → `/sdd-ship:ship`（`spec-check` 自動スキップで迅速に完了）。
- **重要領域（認証/認可・決済・PII・DB 移行・公開契約）に触れる修正**: `--risk high` を指定し、`spec-check` の 2 視点並列レビューと高リスク検証を通す。

## Boundaries

- 本スキル内で本番修正を確定させない（修正適用は人間承認後の `implement-task`）。
- `Approval:` / `Status: Done` を変更しない。
- `[DEBUG-*]` プローブや使い捨てハーネスをコミット対象に残さない。
- 再現ループをどうしても構築できない場合は推測で進まず、試したことと不足している環境・権限・ログを人間へ報告して停止する。
