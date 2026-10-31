# 自己改善フロー（WFI）の効果測定 — 2026 ベストプラクティス調査と実装提案

Status: Approved & Implemented (v1.7.0) / 作成日: 2026-07-02 / 承認: 2026-07-02（人間）
対象: workflow-retrospective → wfi-audit-cycle → WFI 適用 → 検証 のループ

実装状況（v1.7.0）:

| 提案 | 状態 | 実装物 |
|---|---|---|
| Phase A ランレコード | 実装済み | `plugins/sdd-quality-loop/scripts/emit-run-record.sh` / `.ps1`、workflow-retrospective の「Run Record」節 |
| Phase B 検証拘束力 + Meta-Change | 実装済み | WFI テンプレート（Target-Metric/Horizon/Rollback-Plan/Mechanism/Meta-Change）、retrospective の Horizon チェック、wfi-auditor-b の META-CHANGE-ANTI-GOODHART チェック、カテゴリガイド §5 |
| Phase C Retention | 実装済み | `docs/workflow-improvements/retention-checklist.md`、Regressed 状態、retrospective の Retention チェック |
| Phase D golden タスク | スキャフォールド | `tests/golden/README.md`（fixture は実失敗発生時に追加） |
| 分類2軸化（§2.3） | 実装済み | Category 4値 + Mechanism 5値（テンプレート・ガイド・retrospective） |
| 自動化⑥ バージョン同期 | 実装済み | `scripts/bump-version.sh` |
| 自動化④⑤・golden CI | 未実装 | 将来の WFI として起票可能 |

本書は 3 部構成:

1. 効果測定の 2026 年ベストプラクティス調査結果と、sdd-forge への実装案
2. 自己改善の対象分類（現行 2 分類の拡張案）
3. フロー全体の概観 — さらなる自動化候補とレビューすべき観点

---

## 1. 効果測定 — 調査結果と実装案

### 1.1 調査サマリ（確立済みプラクティス）

| プラクティス | 出典 | sdd-forge への適用性 |
|---|---|---|
| 実失敗由来の 20–50 件の小規模 eval + code-based grader、capability/regression の区別、pass@k vs pass^k | [Anthropic: Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) (2026-01) | ◎ fixture タスク + 決定論ゲートは既存資産で構成可能 |
| 本番失敗を eval ケース化し続ける「evaluation flywheel」 / trace grading | [OpenAI: Agent evals](https://developers.openai.com/api/docs/guides/agent-evals) | ◎ review-ticket / BLOCKED 事例がそのまま候補 |
| golden dataset を ship gate にする eval 駆動開発（CI で per-PR に改善/退行を報告） | [Braintrust](https://www.braintrust.dev/articles/eval-driven-development), [DeepEval](https://deepeval.com/blog/eval-driven-development) | ◎ git 内 golden set + GitHub Actions で telemetry サーバ不要 |
| 変更前後の同一タスク pairwise 比較を承認判断の材料にする | [LangSmith pairwise](https://blog.langchain.com/pairwise-evaluations-with-langsmith/) | ○ WFI 承認時の添付資料として移植可能 |
| 最終成否だけでなく sub-goal 進捗率（progress rate）を測る | [AgentBoard](https://arxiv.org/abs/2401.13178) | ◎ tasks.md の状態遷移が sub-goal に相当 |
| 「reflection が提案し、held-out 計測が採否を決める」規律 | [GEPA (ICLR 2026)](https://arxiv.org/abs/2507.19457) | ○ 完全自動最適化は過剰。規律のみ移植 |
| スコア閾値付き採用 + バージョン履歴ロールバック + 人間承認 | [OpenAI cookbook: Self-Evolving Agents](https://developers.openai.com/cookbook/examples/partners/self_evolving_agents/autonomous_agent_retraining) | ◎ WFI ループと構造一致。rollback の形式化が未実装 |
| 評価軸: Adaptivity / **Retention** / Generalization / Efficiency / Safety | [Self-Evolving Agents survey](https://arxiv.org/abs/2507.21046) | ◎ Retention（直した失敗が再発しない）が現行の最大の欠落 |
| 自己改善系は自分の評価をハックする（Goodhart / metric-hacking の実証） | [Darwin Gödel Machine](https://sakana.ai/dgm/) | ◎ grader・閾値・retrospective 自体を触る WFI は厳格レーンへ |
| 主観的な「速くなった感」は測定と 40pt 乖離しうる（RCT で体感+20% / 実測-19%） | [METR RCT](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) | ◎ 「体感改善」を Verified の根拠にしない、の根拠 |

### 1.2 現状とのギャップ

既にあるもの: WFI の検証計画（baseline / target / checkpoint）、次回 retrospective での
Result 追記（Verified / Needs-Followup / Rejected）、「Comparison With Previous
Retrospective」15+ 指標、reports/ からの読み取り専用メトリクス収集。

足りないもの（調査結果とのギャップ、優先順）:

1. **交絡メタデータ付きの機械可読ランレコードがない** — モデル ID・プラグイン
   バージョン・適用中 WFI 一覧を毎ランで記録しないと、いかなる帰属分析も後から
   不可能になる。コストほぼゼロで将来の分析可能性を買う最重要項目。
2. **Retention（回帰）チェックがない** — WFI-001 で直した失敗モードが WFI-005 適用後に
   再発しても、現行 retrospective は「直近期間の摩擦」しか見ないため検出できない。
3. **オフライン検証（golden task）がない** — 現行の検証は「次の実ランで観察する」
   のみ。実ランはタスク難易度が毎回異なるため、帰属が弱い。
4. **ロールバックが形式化されていない** — Rejected 後に「何を revert するか」が
   手続き化されていない。
5. **anti-Goodhart ガードがない** — grader・ゲート閾値・retrospective ロジックを
   変更する WFI に追加の審査レーンがない。

### 1.3 実装案（4 段階、各段階が独立に価値を持つ）

#### Phase A — ランレコード（小、最優先）

`workflow-retrospective` 実行時（または ship の COMPLETION_CHECK 時）に
`reports/runs/RUN-<timestamp>.json` を生成する:

```json
{
  "run_id": "2026-07-02T15:00:00Z-<feature>",
  "feature": "<feature>",
  "track": "full|lite",
  "model_ids": {"main": "...", "reviewers": "..."},
  "plugin_version": "1.7.0",
  "active_wfis": ["WFI-001", "WFI-003"],
  "task_type_labels": {"T-001": "high-risk", "T-002": "small"},
  "metrics": {
    "first_pass_gate_rate": {"passed": 3, "total": 4},
    "rework_cycles_per_task": {"median": 1, "max": 3},
    "blocked_tasks": 1,
    "review_tickets": {"critical": 0, "major": 2, "minor": 1},
    "human_interventions": 2
  }
}
```

- 比率は必ず分子/分母の**カウント**で持つ（小 n では % が誤解を生む）。
- `active_wfis` は WFI ledger の Applied 状態から機械的に導出。
- 実装先: workflow-retrospective SKILL.md に生成ステップ追加 +
  `scripts/emit-run-record.(sh|ps1)`（決定論スクリプト。LLM に集計させない）。

#### Phase B — WFI 検証の拘束力強化（小）

現行の検証計画を「事前登録」として拘束的にする:

- WFI テンプレートに必須フィールド追加: `Target-Metric`（ランレコードのキー名で指定）、
  `Expected-Direction`、`Horizon`（例: 「次の 5 ラン以内」）、`Rollback-Plan`
  （revert 対象コミット/ファイル）。
- retrospective は毎回、Applied 状態の全 WFI の Horizon を確認し、期限内に
  ランレコード上で目標未達なら **Rejected + Rollback-Plan の実行を人間に提案**する
  （実行自体は人間承認後）。
- WFI を適用するコミットのメッセージに `WFI-NNN` を必ず含める（lineage。
  DGM の教訓: 変更の追跡可能性が自己改善系の安全条件）。

#### Phase C — Retention スイート（中）

- `docs/workflow-improvements/retention-checklist.md` を新設: Verified になった
  WFI ごとに「再発検知条件」を 1 行で登録（例: 「WFI-001: 高リスクタスクで
  evidence-consistency 修正が発生したら再発」）。
- retrospective に Retention セクションを追加: チェックリストを走査し、
  再発を検知したら該当 WFI を `Regressed` 状態（新設）に落とし、WFI 再起票を提案。
- これは survey の 5 評価軸のうち最も忘れられがちで、git 履歴だけで測れる軸。

#### Phase D — golden task によるオフライン検証（大、任意）

- `tests/golden/` に実失敗由来の fixture タスク 5–15 件（Anthropic の 20–50 件
  ガイダンスの縮小版）。各 fixture = 入力（要件/コード断片）+ code-based grader
  （生成された spec/tasks が満たすべき決定論チェック）。
- instructions を変更する WFI の承認前に、影響ステージだけを fixture 上で
  変更前/変更後 × k=2–3 回実行し（pass^k）、diff を WFI に添付して人間が承認判断。
- CI 化する場合: `plugins/**` を触る PR でのみ実行（API コストのため opt-in ラベル推奨）。
- これが唯一、モデルバージョン・タスク難度などの時変交絡から WFI 効果を分離できる設計。

#### 帰属分析の運用規律（実装物なし、ルールのみ）

- WFI の採用は **1 ウィンドウ 1 件**（または明示的にラベル付けした 1 バッチ）。ラン途中の適用禁止。
- モデルバージョン変更は独立した「介入」としてランレコードに記録し、golden set を再ベースライン。
- n < 20 ランでは % でなくカウントで報告し、二値の狙い撃ち指標
  （「失敗モード X が再発したか」）を優先。
- Verified 判定の前に該当ランの transcript/レポートを人間が読む（eval スコアの
  額面受け取り禁止 — Anthropic ガイダンス）。「体感で良くなった」は根拠にしない（METR）。

### 1.4 anti-Goodhart ガード（Phase B に同梱可能）

`wfi-audit-cycle` に分類ステップを追加: WFI の Proposed-Change が
**grader / ゲート閾値 / retrospective・監査ロジック / ランレコード生成スクリプト**
のいずれかに触れる場合は `Meta-Change: true` を付与し、

- auditor-b のチェック項目に「この変更は測定自体を緩めていないか」を追加、
- 人間承認時に Meta-Change フラグを明示表示、
- ガード指標（ゲート本数・テスト数・チェック項目数が非減少）を diff で確認。

---

## 2. 自己改善の対象分類 — 拡張案

### 2.1 現行

| 現行カテゴリ | 実体 |
|---|---|
| `app-dev-efficiency` | プロジェクト固有（タスク分割、テスト方針、AGENTS.md 等） |
| `plugin-improvement` | SDD フロー自体（レビューゲート、ハンドオフ） |

### 2.2 調査結果: 公開分類法

自己進化エージェントの主要 survey（[2507.21046](https://arxiv.org/abs/2507.21046),
[2508.07407](https://arxiv.org/abs/2508.07407)）はほぼ 4 軸に収束:
**Models / Context (Prompt + Memory) / Tools / Architecture**。
これに実践知として **評価系そのもの**（DGM の metric-hacking 対策）と
**人間プロセス**（survey には無い。HITL 設計固有の拡張）を加えるのが 2026 実務の形。

### 2.3 提案: 「スコープ軸 × メカニズム軸」の 2 軸タグ

現行 2 分類は「変更がどこに着地するか」（スコープ軸）であり、survey の分類は
「何を変えるか」（メカニズム軸）。直交するので、置き換えではなく **両方タグ付け**する。

**スコープ軸（現行 2 + 新 2）:**

| スコープ | 例 | 監査レーン |
|---|---|---|
| `app-dev-efficiency`（既存） | プロジェクトのタスク分割指針 | 通常 |
| `plugin-improvement`（既存） | レビューゲートのラウンド構成 | 通常 + GitHub Issue |
| `human-process`（新） | 承認ポリシー、エスカレーション基準、人間が読む対象の絞り込み | 通常（適用は常に人間） |
| `measurement`（新） | grader・閾値・retrospective ロジック・ランレコード定義 | **厳格（Meta-Change レーン）** |

**メカニズム軸（参考タグ、集計用）:**
`instructions`（SKILL.md/プロンプト/ルーブリック）/ `memory`（AGENTS.md・CLAUDE.md・
テンプレート等の永続知識。※肥大化 = context bloat の監視対象）/ `tools`（スクリプト・
フック・エージェント定義・スキーマ）/ `architecture`（ゲート順序・レビュアー数・
承認位置）/ `model-routing`（ステージ別モデル選択）。

導入コスト: `wfi-category-guide.md` に 2 軸の定義を追記し、WFI テンプレートに
`Scope:` と `Mechanism:` の 2 フィールドを追加するだけ。集計はランレコードと同様
retrospective が行い、「どのメカニズムの改善が Verified 率が高いか」自体を
メタ指標として蓄積できる。

---

## 3. フロー概観 — 自動化候補とレビュー観点

### 3.1 フロー全体（現状）

```
bootstrap（仕様化）: interview → spec-review → impl-review → タスク分解 → task-review → 人間承認
ship（実装・QA）:   implement-tasks → quality-gate(×タスク) → [cross-model-verify] → retrospective
自己改善:           retrospective → WFI Draft → 2サイクル監査 → 人間承認 → 適用 → 検証
```

### 3.2 さらなる自動化の候補（費用対効果順）

1. **ランレコード自動生成**（§1.3 Phase A）— 決定論スクリプトで完結。LLM 不要。
2. **WFI Horizon の自動監視** — retrospective 冒頭で Applied WFI の期限切れ・目標未達を
   機械チェックし、Rejected/rollback 提案まで自動化（承認は人間）。
3. **Retention チェックの自動化**（§1.3 Phase C）。
4. **承認待ちの通知** — `Approval: Draft → Approved` 待ち、`Human-Pending` の WFI を
   検出したらホスト通知（Claude Code なら Stop hook / スケジュールタスク）。
   承認そのものは自動化しない（それは sdd-sudo の責務であり、既に存在する）。
5. **plugin-improvement WFI の Issue 起票後の追跡** — Issue クローズ時に WFI 状態を
   同期する GitHub Actions（`gh` 1 コマンド分の薄い workflow）。
6. **golden task CI**（§1.3 Phase D）— コストが乗るため opt-in ラベル方式。
7. **リリース面同期の自動化** — 6 プラグイン × 3 マニフェスト + marketplace + README +
   validator のバージョン同期は手作業起点（v1.6.0 リリースでも専用コミットが必要だった）。
   `scripts/bump-version.sh <ver>` に一本化する価値が高い。

### 3.3 レビューを強化すべき観点

1. **Meta-Change（測定系を触る変更）** — §1.4。自己改善ループの最大リスク。
2. **モデルバージョン変更** — 帰属分析の最大の交絡。ランレコードに記録し、
   変更時は「WFI の Verified 判定を跨がせない」運用に。
3. **sdd-sudo の使用履歴** — バイパスが常態化していないか retrospective で
   使用回数を集計対象に含める。
4. **lite トラックへの逃避** — 本来 full を通すべき変更が lite で流れていないか。
   `spec_profile: lite` の設定変更はレビュー対象イベントとして扱う。
5. **メモリ/テンプレート系ファイルの肥大化** — AGENTS.md・テンプレートへの追記型
   WFI が累積すると指示が薄まる（context bloat）。行数上限 or 定期的な統合
   （consolidation）を retrospective の定型チェックに追加。
6. **review-loop の合議の独立性** — reviewer a/b に同じ会話文脈が漏れていないか
   （現在は fresh context 設計。変更時の退行に注意）。

### 3.4 スラッシュメニュー可視性の残課題（今回修正の補足）

- Claude Code は `user-invocable: false` で非表示化済み。**Codex には per-skill の
  メニュー非表示機構が公式に存在しない**（[openai/codex#13893](https://github.com/openai/codex/issues/13893) で議論中）。
  Codex 側は entry スキルのリネーム（`bootstrap` / `ship`）による一意化のみ適用。
  Codex が可視性制御を出荷したら `agents/openai.yaml` で追随すること。
- `fix-by-review-ticket` と `diagnose` は「人間の再開点」として可視のまま残した。
  将来 `/sdd-ship:ship --fix RT-NNN` / `/sdd-bootstrap:bootstrap diagnose` として
  エントリに統合すれば、可視コマンドを 3（bootstrap / ship / sdd-sudo）まで減らせる。
