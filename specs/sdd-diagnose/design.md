# 設計提案: バグ修正実行スキル `diagnose`（item② / 設計のみ）

- **出典**: 監査 P1-1 + mattpocock/skills `skills/engineering/diagnosing-bugs/SKILL.md`（`gh api` で実取得・確認済み）
- **状態**: 設計のみ（本 spec では実装しない）。承認後に別 feature として lite/full で実装。

## 1. なぜ必要か（既存機構との差分）

sdd-forge には既に **バグ修正の「レビュー検査」**がある:
- `task-reviewer-b.md:167-181` の `BUGFIX-DIAGNOSTIC-PATH` — バグ修正タスクが「再現エビデンス / 根本原因調査ステップ / 回帰テスト」を持つか**検査**する Major チェック。

しかし**「実際にどう診断するか」という実行規律スキル**は無い。mattpocock の `diagnosing-bugs` はまさにこの実行規律であり、両者は補完関係:

| | 役割 | 既存/新規 |
|---|---|---|
| `BUGFIX-DIAGNOSTIC-PATH`（task-reviewer-b） | タスクが診断経路を**持つか検査** | 既存（HEAD） |
| `diagnose`（本提案） | **実際に診断を遂行**し、上の検査が要求する証跡を**生成** | 新規 |

つまり `diagnose` が生む「tight な再現ループ・最小再現・回帰テスト」が、そのまま `BUGFIX-DIAGNOSTIC-PATH` が検査する証跡になる。片方が要求し、もう片方が供給する。

さらに監査は「バグ修正でフルフロー（spec→spec-review→impl-review→tasks→task-review→承認→quality-gate）は過剰」と指摘した。`diagnose` はこの**軽量バグ修正トラック**の入口も兼ねる。

## 2. 配置と呼び出し

- プラグイン: **`sdd-implementation`**（実装フェーズの一部）。新スキル `diagnose`。
- 起動: `disable-model-invocation: true`（sdd-forge 全スキル同様 user-invoked。context load ゼロ）。
  - Claude Code: `/sdd-implementation:diagnose <issue|再現手順>`
  - Codex: `Use the diagnose skill. Symptom: <...>`
- 位置づけ: バグ修正 issue を受けたら **spec 化の前**に `diagnose` を回し、得た根本原因・最小再現・回帰テストを requirements/tasks の入力にする（診断が仕様を駆動する）。

## 3. 実行規律（diagnosing-bugs を SDD に適応した5フェーズ）

各フェーズは「Skip は明示的正当化があるときのみ」。

1. **Phase 1 — feedback loop を1本作る（これがスキルの本体）**
   - *this bug* で赤になる**1コマンド**（失敗テスト / curl / CLI+fixture / headless browser / trace 再走 / 使い捨て harness / property・fuzz / bisect harness / 差分ループ / 最後の手段 HITL）を作る。
   - 完了基準: red-capable（ユーザーの正確な症状を assert）・deterministic・fast（秒）・agent-runnable。**赤にできるコマンドが無いうちは仮説を立てない**（このスキルが防ぐ最大の失敗）。
2. **Phase 2 — 再現 + 最小化**: ループを赤にして、load-bearing な要素だけ残るまで縮小。
3. **Phase 3 — 仮説（3–5個・反証可能）**: `If X is the cause, then changing Y will…` の形。テスト前に人間へ提示（ドメイン知識で即再ランクされることが多い。AFK なら自ランクで続行）。
4. **Phase 4 — 計測（1変数ずつ）**: debugger/REPL > 境界での targeted log（`[DEBUG-xxxx]` タグで後で一括 grep 削除）> 「全部 log して grep」は禁止。性能退行は log でなく計測（baseline→bisect）。
5. **Phase 5 — 修正 + 回帰テスト（修正の前にテスト）**: 正しい seam があるときのみ回帰テストを先に書く。**正しい seam が無ければ、それ自体が finding**（アーキがバグを封じ込められない → `improve-codebase-architecture` 相当へハンドオフ）。

## 4. 既存 SDD 機構への接続

- **証跡供給**: Phase1 の再現コマンド・Phase5 の回帰テストが `BUGFIX-DIAGNOSTIC-PATH` の「再現/根本原因/回帰」要求を満たす。`diagnose` の出力（診断レポート）を `reports/diagnosis/<id>.md` に残し、bugfix タスクの `Done When` から参照。
- **軽量トラック**: バグ修正は既定で `spec_profile: lite`（lite-spec → 単一承認 → implement-task → lite-gate）に流す短絡経路を workflow-guide に明示。full の3レビューループは強制しない（監査「バグ修正の過剰処理」への対応）。ただし Risk: high/critical に昇格したら full の階層強制へ加算移行。
- **移譲/トークン**: 大規模な調査 Phase は read-only サブエージェント（`sdd-investigator` 相当）へ委譲し、メイン文脈に診断ログを溜めない。
- **kill-switch/承認**: 既存ガード（AGENT_STOP、Approval 自己承認禁止）はそのまま有効。`diagnose` は read-mostly で、修正コミットは implement-task 経由。

## 5. cross-platform

- 3環境ともスキル本文＋`references/diagnosis-loop-policy.md`（10種の loop 構築法）で共通化。
- HITL loop は mattpocock の `scripts/hitl-loop.template.sh` に相当するテンプレを `scripts/` に同梱（人間がクリックする必要がある場合も構造化）。

## 6. 成果物（実装時）

- `plugins/sdd-implementation/skills/diagnose/SKILL.md`
- `plugins/sdd-implementation/skills/diagnose/references/diagnosis-loop-policy.md`
- `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh`
- `plugins/sdd-implementation/templates/diagnosis-report.template.md`
- workflow-guide.md にバグ修正軽量トラックの節を追記
- （任意）`task-reviewer-b` の `BUGFIX-DIAGNOSTIC-PATH` finding 文言に「`diagnose` スキルの証跡を参照」を追記

## 7. Open Questions

- [resolved] `diagnose` は §2 のとおり `plugins/sdd-implementation/skills/diagnose/` に配置済み（独立プラグイン案は不採用）。
- バグ修正軽量トラックの既定を `lite` にするか、`diagnose` 専用の最小トラックを新設するか。
- Phase3 の「人間へ仮説提示」を SDD の承認ゲートとして扱うか、助言に留めるか。
