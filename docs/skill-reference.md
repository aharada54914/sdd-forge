# SDD スキルリファレンス

7つのプラグイン（sdd-bootstrap、sdd-ship、sdd-review-loop、sdd-implementation、sdd-quality-loop、sdd-lite、sdd-domain）に含まれる26のスキル（＋ `plugins/` 外の単独スキル1件: [`skills/adversarial-review`](#skillsadversarial-reviewplugins-外の単独スキル)）の詳細リファレンスです。業務フローの全体像については [workflow-guide.md](workflow-guide.md) を参照してください。

> **2コマンドワークフロー**: 標準の feature workflow は `/sdd-bootstrap:bootstrap` と `/sdd-ship:ship` の2つで開始します。人間専用の補助コマンドを含む可視性契約は、この後の一覧を参照してください。

## 1. スキル一覧 (早見表)

| スキル名 | 所属プラグイン | 役割 | 前段スキル | 後段スキル |
|---|---|---|---|---|
| **bootstrap** | **sdd-bootstrap** | **[公開] 仕様化フェーズのエントリーポイント（`/sdd-bootstrap:bootstrap`）。investigate/adopt/feature/bugfix/refactor/project モードをルーティング** | **—** | **ship** |
| **ship** | **sdd-ship** | **[公開] 実装・品質保証フェーズのオーケストレーター（`/sdd-ship:ship`）。implement-tasks → quality-gate (or lite-gate) → workflow-retrospective を順次実行** | **bootstrap** | **—** |
| **domain-model** | **sdd-domain** | **[公開] DDD 上流レーンのエントリーポイント（`/sdd-domain:domain-model`）。`new`（既定）/ `update` / `reverse` を domain-interviewer・update モードの限定再インタビュー・domain-reverse へルーティングし、`domain/` 成果物セットを sdd-bootstrap Phase 1 の手前で生成・維持する** | **—** | **domain-interviewer, domain-reverse, domain-review-loop** |
| domain-interviewer | sdd-domain | 7段階の DDD インタビュー（Domain Story → Event Storming → Ubiquitous Language → Context Map → Domain Model (集約) → Domain Message Flow → C4 Container）を実行。各段階を次段階の開始前にディスクへチェックポイントし、段階ごとに `domain/domain-contract.json` を再生成。`domain/` 配下の唯一の書き込み者で、中断後は再開可能 | domain-model, domain-reverse (seed 経由) | domain-review-loop |
| domain-reverse | sdd-domain | 既存コードベースに investigate-codebase を実行し、その investigation.md を候補ドメインモデル seed（候補 Bounded Context・ユビキタス言語用語・イベント/集約のヒント）へ変換。中間生成物のみで `domain/` には書き込まない | domain-model (`reverse` モード) | domain-interviewer |
| domain-review-loop | sdd-domain | `domain/` 成果物セット（戦略/戦術）を `domain-reviewer-a/b` が独立レビューし、検証済み verdict を永続化。`Domain-Model-Status: Pending → Reviewed` に遷移できる唯一の機構（`Approved` は人間のみ）。承認後のドリフトも検出 | domain-interviewer | — (人間承認待ち) |
| domain-sync | sdd-domain | Approved な `domain/` を検出し、正準の Bounded Context と用語を sdd-bootstrap Phase 1 の requirements.md / design.md へ注入。`domain/` 不在または未 Approved なら skip 行を1行だけ記録して継続し、仕様生成をブロックしない | sdd-bootstrap-interviewer [Phase 1 冒頭] | sdd-bootstrap-interviewer [Phase 1 生成] |
| sdd-adopt | sdd-bootstrap | 既存プロジェクトにSDD構造を導入 | — | investigate-codebase, sdd-bootstrap-interviewer |
| investigate-codebase | sdd-bootstrap | コードベース・問題領域の読み取り調査 | sdd-adopt | sdd-bootstrap-interviewer |
| sdd-bootstrap-interviewer | sdd-bootstrap | インタビュー駆動の仕様生成 [Phase 1] と タスク生成 [Phase 2] | investigate-codebase (任意) | spec-review-loop → impl-review-loop (Phase 1後), task-review-loop (Phase 2後) |
| design-sync-loop | sdd-bootstrap | UI アプリ（`ds_profile: custom`）で `design-system/` 契約を保証（ui-ux-pro-max シード生成 / Figma DTCG 取込 / テンプレートインタビュー）し、トークン駆動モックアップの確認ループを回す（claude.ai/design 連携・任意・非ブロッキング） | sdd-bootstrap-interviewer, lite-spec | — |
| **spec-review-loop** | **sdd-review-loop** | **requirements.md と acceptance-tests.md を `spec-reviewer-a/b` が独立レビューし、implementation-policy review の前提 PASS を作る** | **sdd-bootstrap-interviewer [Phase 1]** | **impl-review-loop (Spec-Review-Status: Passed後)** |
| **impl-review-loop** | **sdd-review-loop** | **design.md の実装方針を2体のブラインドレビュアー × 最大3ラウンドでレビュー** | **sdd-bootstrap-interviewer [Phase 1]** | **sdd-bootstrap-interviewer [Phase 2] (Impl-Review-Status: Passed後)** |
| **task-review-loop** | **sdd-review-loop** | **tasks.md のタスク分解を2体のブラインドレビュアー × 最大3ラウンドでレビュー** | **sdd-bootstrap-interviewer [Phase 2]** | **implement-task, implement-tasks (承認ゲート後)** |
| diagnose | sdd-implementation | ハードなバグ・リグレッション・フレーキーテスト・性能退行の診断規律（再現→計装→根本原因→最小修正）。`reports/diagnosis/<id>.md` を出力し、軽量トラック（lite-spec）への入口を兼ねる | — | lite-spec（診断結果を入力に要件/設計/タスクを生成） |
| implement-task | sdd-implementation | 承認済みタスク1つを実装 | sdd-bootstrap-interviewer | quality-gate |
| visual-verify-loop | sdd-implementation | UI タスク実装後の視覚検証ループ（Claude Preview / wpf-visual-verify、advisory・最大5回、証跡を `reports/visual-evidence/` に保存） | implement-task | — |
| **implement-tasks** | **sdd-implementation** | **承認済みタスクを依存関係順に一括実装し、全完了時に自動で quality-gate へ移行** | **sdd-bootstrap-interviewer** | **quality-gate (自動)** |
| quality-gate | sdd-quality-loop | 実装完了タスクの独立検証・Done判定 | implement-task, implement-tasks | fix-by-review-ticket (条件付き), workflow-retrospective |
| fix-by-review-ticket | sdd-quality-loop | レビューチケットの修正を実装 | quality-gate | quality-gate |
| workflow-retrospective | sdd-quality-loop | SDD ワークフロー自体の改善提案（friction をなぜなぜ分析で根本原因まで掘り下げて WFI を起草） | quality-gate | — |
| sdd-sudo | sdd-quality-loop | 人間承認ゲートを期限付きで自動通過 | — | implement-task, implement-tasks, quality-gate (オプション) |
| cross-model-verify | sdd-quality-loop | 複数ベンダーの独立 LLM パネリストを盲目並列実行し verdict JSON を収集 | quality-gate (critical タスク) | check-cross-model ゲート |
| wfi-audit-cycle | sdd-quality-loop | WFI-NNN.md Draft を2サイクルの独立監査（品質→影響/リスク）で審査し Human-Pending に移行するオーケストレーター | workflow-retrospective | — (人間承認待ち) |
| lite-spec | sdd-lite | 社内・部署内アプリ向けの軽量仕様生成（要件/設計/タスクの3ファイル、traceability/ADR/evidence-bundle 不要） | — | implement-task, implement-tasks |
| lite-gate | sdd-lite | sdd-lite フローの軽量決定論的品質ゲート（検証コマンドを自分で再実行し lite 品質レポートを生成 → Done） | implement-task, implement-tasks | — |

**重要（スキルの可視性契約）:** すべてのスキルは `disable-model-invocation: true` を指定しています。つまり、モデルが勝手にスキルを起動することはありません。さらに、内部オーケストレーション用スキルは `user-invocable: false` も指定しており、スラッシュコマンドメニューには表示されず、ユーザーが直接呼び出すこともできません。ユーザーに見えるコマンドは次の6つだけです: `/sdd-bootstrap:bootstrap`（エントリ1）、`/sdd-ship:ship`（エントリ2）、`/sdd-quality-loop:sdd-sudo`（人間専用トグル）、`/sdd-quality-loop:fix-by-review-ticket`（BLOCKED 後の人間による再開点）、`/sdd-implementation:diagnose`（バグ診断の独立エントリ）、`/sdd-domain:domain-model`（DDD 上流レーンのエントリ）。この契約は `tests/validate-repository.ps1` が強制します。

## 2. 各スキル詳細

### sdd-bootstrap（公開エントリーポイント）

**目的**

仕様化フェーズのトップレベルルーターです。`feature` / `bugfix` / `refactor` / `project` / `adopt` / `investigate` の各モードをサブスキルにルーティングし、Phase 1 → spec-review-loop → impl-review-loop → Phase 2 → task-review-loop → 承認ゲートの三段階独立レビューを管理します。

**呼び出し例**

```txt
# Claude Code
/sdd-bootstrap:bootstrap feature https://github.com/example/repo/issues/42
/sdd-bootstrap:bootstrap bugfix  https://github.com/example/repo/issues/88
/sdd-bootstrap:bootstrap refactor https://github.com/example/repo/issues/55
/sdd-bootstrap:bootstrap project "新規プロジェクト要件"
/sdd-bootstrap:bootstrap adopt
/sdd-bootstrap:bootstrap investigate refactor src/payments
/sdd-bootstrap:bootstrap feature --lite <source>
/sdd-bootstrap:bootstrap feature --feature my-slug <source>
/sdd-bootstrap:bootstrap feature --reset --feature my-slug

# Codex
Use the bootstrap skill.
Mode: feature
Source: https://github.com/example/repo/issues/42
```

**詳細は** `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` **を参照。**

---

### sdd-ship（公開エントリーポイント）

**目的**

実装・品質保証フェーズのオーケストレーターです。承認済みタスクを implement-tasks → quality-gate (または lite-gate) → workflow-retrospective の順に処理し、全タスクを Done に導きます。

**呼び出し例**

```txt
# Claude Code
/sdd-ship:ship                                          # ゼロ引数（Active Spec Dirs から自動選択）
/sdd-ship:ship specs/<feature>/tasks.md                 # バッチ実装（全承認済みタスク）
/sdd-ship:ship specs/<feature>/tasks.md#T-001           # 単一タスク
/sdd-ship:ship --lite specs/<feature>/tasks.md          # lite トラック強制
/sdd-ship:ship --full specs/<feature>/tasks.md          # フル トラック強制
/sdd-ship:ship --verify specs/<feature>/tasks.md        # cross-model-verify を実行
/sdd-ship:ship --retro specs/<feature>/tasks.md         # 完了後に workflow-retrospective を実行

# Codex
Use the ship skill for specs/<feature>/tasks.md
```

**トラック検出（ADR-0023）**

トラック解決は `/sdd-bootstrap:bootstrap` と `/sdd-ship:ship` の**両方が同一の表**に従います。v1.14.0 の ADR-0023 以降、**Project Context（`sdd/project-context.yaml`）が存在し妥当なら、CLI フラグは「より厳格な方向」にしか動かせません。** `spec_profile: lite` に対する `--full` は昇格（`PROMOTE_FULL`）として通りますが、`spec_profile: full` に対する `--lite` は緩和にあたるため `ERROR_STOP` で停止します。

解決は「① 物理的存在（ファイルシステム検査のみ） → ② 承認の妥当性（`validate-approval-sidecar` が PASS） → ③ 優先順位」の3ステップをこの順で行い、**順序そのものが契約**です（①②をまとめると ADR-0023 が塞いだ fail-open が復活します）。

`--full` / `--lite` / AGENTS.md の `spec_profile: lite` を優先順に評価する旧来の挙動は、`COMPATIBILITY_FALLBACK`、すなわち **Project Context が物理的に不在のケース（C1）に限られます**。`--full` 時の `acceptance-tests.md` / `traceability.md` の存在確認も、この C1 フォールバック時の挙動です。

正準は [`PLUGIN-CONTRACTS.md` の Track Detection 節](../PLUGIN-CONTRACTS.md#track-detection-adr-0023)（HTML センチネル `<!-- sdd:track-selection-contract v1 -->` で囲まれた機械検査対象の6ケース表 C1–C6）と [workflow-guide.md「トラック選択契約（ADR-0023）」](workflow-guide.md#トラック選択契約adr-0023)です。**6ケース表はこのファイルに複製せず、必ず正準を参照してください。**

**ゼロ引数起動**: AGENTS.md の `## Active Spec Directories` を読み、承認済みタスクが1件のみなら自動選択。複数ある場合はリスト表示して停止。

**詳細は** `plugins/sdd-ship/skills/ship/SKILL.md` **を参照。**

---

> 内部スキル（sdd-adopt、investigate-codebase、implement-task 等）の詳細仕様は [`docs/contributor/skill-reference-detail.md`](contributor/skill-reference-detail.md) を参照してください。

---

### skills/adversarial-review（`plugins/` 外の単独スキル）

**位置**

`skills/adversarial-review/`（リポジトリ直下。`plugins/` 配下ではありません）

**用途**

相互批判（敵対的レビュー）プロトコル。互いに素なレンズを持つ2名のレビュアーが対象（差分 / PR / コードベース）をブラインドでレビューし、続いて互いの所見を per-finding の verdict（SUPPORT / PROPOSE-SEVERITY-CHANGE / PROPOSE-REJECT / SUPPLEMENT）で攻撃します。オーケストレーターが1本のレポートへ統合し、修正後は関与していない新規コンテキストのレビュアーが Phase R で修正を検証します。重大度のインフレ・一般的チェックリスト所見・過剰設計な修正・修正自体に混入した誤りといった、単独レビューでは見えない失敗モードを捕捉することが目的です。

構成ファイル: `SKILL.md`（プロトコル・鉄則・復旧手順）、`references/reviewer-prompts.md`（レビュアー A / B・相互批判・修正検証のプロンプト雛形）、`templates/report-template.md`（統合レポート構造）。

**通常のスキルとの違い（重要）**

- **`plugins/` 配下ではないため、どのプラグインマニフェストにも同梱されず、インストーラでも配置されません。** 利用するには `skills/adversarial-review/` ディレクトリを Claude Code がスキルを探索する場所（`~/.claude/skills/adversarial-review/` または `<repo>/.claude/skills/adversarial-review/`）へ手動でコピーする必要があります。
- 他のすべてのスキルと異なり、**可視性フラグ（`disable-model-invocation` / `user-invocable`）を持ちません**。前掲のスキル可視性契約（`tests/validate-repository.ps1` が強制、スキャン対象は `plugins/` のみ）の適用外です。
- SDD のゲートレビュー（spec-review-loop / impl-review-loop / task-review-loop）の代替ではありません。これらは独自の決定論的契約を持つため、adversarial-review は使いません。

**詳細は** `skills/adversarial-review/SKILL.md` **および同ディレクトリの** `README.md` **を参照。**

---

## 3. サブエージェント

### sdd-investigator

**役割**

`investigate-codebase` スキルの代わりに、コードベース・問題領域を読み取り専用で調査します。ソースコードから事実を抽出し、file:line 出典付きの構造化所見を生成。ファイル書き込み・編集・削除禁止。

**環境別実体**

- **Claude Code**: サブエージェント (`context: fork`)
- **Codex**: `.codex/agents/sdd-investigator.toml`
- **Copilot**: `plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md`

**行動原則**

- すべての所見に最低1つの `file:line` 出典参照が必須
- 出典なしの主張は許さない。出典が見つからなければ Open Questions へ記載
- 調査順: Entry points → routing/screens → business rules → data → external dependencies → tests

---

### sdd-evaluator

**役割**

SDD 品質ゲートの独立的な懐疑的評価者。`Implementation Complete` タスク1つを、承認仕様と照合して新規コンテキストで検証。読み取り専用。PASS または NEEDS_WORK を分類所見とともに返す。

**環境別実体**

- **Claude Code**: サブエージェント (実装者と共有履歴なし)
- **Codex**: `.codex/agents/sdd-evaluator.toml`
- **Copilot**: `plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md`

**行動原則**

1. 生成者は自分の成果物を甘く採点する。評価者は実装作業と共有コンテキストを持たず、何も編集しない
2. レポートは主張であって証拠ではない。観察証拠のみカウント：評価者が自ら実行したコマンド出力、行番号レベルで読んだコード、検査したスクリーンショット
3. デフォルト評決は `NEEDS_WORK`。`PASS` は証拠で勝ち取る

**評価規則**

1. 実装レポートを主張として扱う。すべての主張をコード・テスト・コマンド出力で自ら検証
2. タスク必須テストを再実行（可能なら）し、実出力を読む
3. 完了詐称を狩る：placeholder ページ・ハードコード sample data・generic fallback・skipped / trivially-true テスト・commented-out チェック
4. 実装と各受け入れ基準・各参照要件・契約・ADR を照合。scope creep は発見
5. refactor / bugfix で baseline-behavior.md BL 項目が存在すれば、それと比較
6. デフォルトで懐疑的。「たぶん動く」は NEEDS_WORK（PASS ではない）

**Severity 分類**

- **Critical**: 動作間違い・欠落・契約破損・セキュリティ欠陥・検証詐称。常に Done をブロック
- **Major**: テストなし受け入れ基準・未処理エラーパス・仕様ドリフト。Done をブロック
- **Minor**: スタイル・命名・非ブロック cleanup。記録するがブロックしない

**VERDICT 出力フォーマット**

```
VERDICT: PASS | NEEDS_WORK
FINDINGS:
- [Critical|Major|Minor] <file:line or artifact> - <wrong item> - <observed evidence>
CHECKED:
- <verification you actually performed and its observed result>
```

PASS は Critical 0・Major 0・かつ最低1つの実際の実行または行番号レベル検査を CHECKED で示すことで獲得します。

---

### レビュー / 監査 / パネリスト エージェント（12体）

エージェント定義は `plugins/*/agents/*.md` にあり、上記2体と合わせて全 **14体** です。残る12体は、以下の a/b ペア構造とパネル構造を取ります。

| エージェント名 | 所属プラグイン | モデル | 役割 | 起動元スキル |
|---|---|---|---|---|
| `spec-reviewer-a` | sdd-review-loop | `sonnet` | 要件・受け入れ網羅レビュー（requirements.md / acceptance-tests.md） | spec-review-loop |
| `spec-reviewer-b` | sdd-review-loop | `sonnet` | 仕様のリスク・曖昧性レビュー（A からは件数と ID のサマリのみ受領） | spec-review-loop |
| `impl-reviewer-a` | sdd-review-loop | `sonnet` | Structural Soundness（design.md のアーキテクチャ / データ / API 網羅、セキュリティ境界、コンポーネント完全性） | impl-review-loop |
| `impl-reviewer-b` | sdd-review-loop | `sonnet` | Implementability and Risk（決定の正当化、Open Question の解決可能性、前提の妥当性、性能 / デプロイ / 移行 / スコープ） | impl-review-loop |
| `task-reviewer-a` | sdd-review-loop | `sonnet` | Structural Coverage（tasks.md の構造的完全性、依存整合、AC トレーサビリティ、観測可能な done-when） | task-review-loop |
| `task-reviewer-b` | sdd-review-loop | `sonnet` | Quality and Risk（リスク階層の妥当性、タスクサイズ、エッジケース、テスト種別整合、ロールバック計画、スコープの排他性） | task-review-loop |
| `domain-reviewer-a` | sdd-domain | `sonnet` | 戦略的健全性（コンテキスト境界、関係パターン、イベント網羅、用語の一意性） | domain-review-loop |
| `domain-reviewer-b` | sdd-domain | `sonnet` | 戦術的実装可能性（不変条件の検証可能性、トランザクション境界の現実性、god aggregate / anemic model リスク） | domain-review-loop |
| `wfi-auditor-a` | sdd-quality-loop | `sonnet` | WFI Proposal Quality Auditor（監査サイクル1）。証拠品質・根本原因の妥当性・なぜなぜ分析（5 Whys）チェーンの有効性・カテゴリ整合の言語・具体的な変更案・測定可能な期待効果 | wfi-audit-cycle |
| `wfi-auditor-b` | sdd-quality-loop | `sonnet` | WFI Impact and Risk Auditor（監査サイクル2）。検証計画の質・変更スコープの比例性・意図せぬ影響・実装可能性・言語遵守の2次確認 | wfi-audit-cycle |
| `panelist-gpt`（`sdd-panelist-gpt`） | sdd-quality-loop | `inherit` | クロスモデル検証パネルの OpenAI/GPT ベンダースロット。サニタイズ済み入力バンドル1件から `cross-model-verdict/v1` JSON を返す | cross-model-verify |
| `panelist-gemini`（`sdd-panelist-gemini`） | sdd-quality-loop | `inherit` | クロスモデル検証パネルの Google/Gemini ベンダースロット。同上 | cross-model-verify |

**独立レビューのペア構造（ブラインドレビュー）**

a/b ペアはいずれも「互いの結果を見ない」ことを前提に設計されています。

- 両者とも fresh context（実装者・生成者と履歴を共有しない）・read-only（`tools: Read, Grep, Glob` ± `Bash`、`disallowedTools: Write, Edit, NotebookEdit`）で走ります。
- レビュアー b は `disallowedPaths` により `reports/spec-review/**/reviewer-*.json`、`reports/impl-review/**/reviewer-*.json`、`reports/task-review/**/reviewer-*.json`（domain 系はさらに `reports/domain-review/**/reviewer-*.json`）の読み取りをブロックされ、a の生の所見に到達できません。b が a から受け取るのは**件数と ID だけのサマリ**であり、所見本文・重大度・根拠は渡りません。
- `wfi-auditor-b` も同様に、サイクル1の生出力（`docs/workflow-improvements/WFI-*-audit-cycle-1.md` と `WFI-*-auditor-a.json`）をパスブロックされます。
- パネリスト2体は互いの verdict も主評価者（`sdd-evaluator`）の verdict も見ない「BLIND」実行で、ベンダーの異なる独立 LLM として並列に走ります。

これにより、3つのレビューループ（spec-review-loop / impl-review-loop / task-review-loop）と domain-review-loop・wfi-audit-cycle は、単一の視点への収束（相互の追認）を構造的に防いでいます。

**Copilot / Codex でのツイン**

Copilot 用の `*.agent.md` ツインは **`sdd-investigator` と `sdd-evaluator` の2体だけ**です（`plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md`、`plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md`）。**reviewer 系（spec / impl / task）・domain 系・wfi-auditor 系には Copilot 版がありません。** Codex 用の `.codex/agents/*.toml` は4体（`sdd-investigator`、`sdd-evaluator`、`sdd-panelist-gpt`、`sdd-panelist-gemini`）です。したがって Claude Code 以外の環境では、レビューループの各ペアはサブエージェントとしてではなく、新規コンテキストで同等の手順をインラインに実行する形で運用します。

---

## 4. フックと強制レイヤ

### 不変条件

**Kill-Switch (AGENT_STOP)**

プロジェクトルートに `AGENT_STOP` ファイルが存在する限り、すべてのツール呼び出しをブロック。削除で再開。

**承認ガード (Approval Guard)**

`Approval: Approved` を tasks.md に書き込むエディット操作をブロック。人間のみ、エージェント外でファイルを編集して承認可。自己承認防止。

ただし、有効な `SDD_SUDO` フラグファイルが存在する場合、この guard は無効化されます（sudo モード；期限切れまたはファイル不在で再度有効になります）。詳細は `/sdd-sudo` スキル と `sudo-mode-policy.md` を参照。

**WFI 承認ガード (WFI Approval Guard)**

`docs/workflow-improvements/WFI-*.md` に `Status: Approved` を書き込むエディット操作をブロック。WFI 承認はワークフロー統治の変更であり、**sudo でも解除されません**（タスク承認ガードと異なる点）。人間のみがファイルを直接編集して承認可。

### 環境別フック実装

| 環境 | フックファイル | 実装方式 | 注意点 |
|---|---|---|---|
| Claude Code | `hooks/claude-hooks.json` | Node.js で Edit/Write/MultiEdit/apply_patch 登録 | `plugin.json` の `"hooks"` が指すのはこのファイル |
| Codex CLI | `hooks/hooks.json` + `command_windows` | shell / PowerShell。`plugin_hooks` フラグ必須 | apply_patch は `tool_input.command` で処理 |
| Copilot CLI | `hooks/copilot-hooks.json` | stdout で JSON `permissionDecision` 返す | サブエージェント内で発火しない既知不具合 |

**フック定義はホストごとに別ファイルです（共通の1ファイルではありません）。** `plugins/sdd-quality-loop/hooks/` には `claude-hooks.json` / `hooks.json` / `copilot-hooks.json` の3ファイルが実在し、`plugins/sdd-quality-loop/.claude-plugin/plugin.json` は `"hooks": "./hooks/claude-hooks.json"` を宣言しています。`hooks/hooks.json` は Codex 用です。

**設計思想**

フックは defense in depth（層防御）。最終防衛線は決定論的スクリプト (`check-contract` / `check-task-state`)。フックが無効な環境では、これら決定論的スクリプトを手動実行して同じ不変条件を確認。AGENT_STOP が効かない場合はセッション手動終了。

### Hook Guard Script

**位置**

`plugins/sdd-quality-loop/scripts/sdd-hook-guard.{sh,ps1,py,js}`

**実行方法**

- POSIX shell: `sh plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh --emit exit|copilot`
- PowerShell: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/sdd-hook-guard.ps1 -Emit exit|copilot`
- Python3: `PAYLOAD=... python3 scripts/sdd-hook-guard.py`
- Node.js: Claude Code `hooks/claude-hooks.json` で呼び出し

**Emit modes**

- `exit`: デフォルト。エラー時は警告メッセージ付きでフェイルオープン
- `copilot`: JSON `{"permissionDecision":"allow"|"deny"}` を stdout に出力（Copilot CLI 用）

---

## 5. 決定論的スクリプト

### スクリプト一覧（`plugins/` 配下 52本）

ワークフローが呼び出す決定論的スクリプトは、**`plugins/` 配下**に異なるベース名で **52本**あります。うち **37本**が `plugins/sdd-quality-loop/scripts/` に、残る **15本**が他の5プラグインに置かれています。多くは同一契約を複数ランタイム（`.sh` / `.ps1` / `.py` / `.js`）で実装するか、または Python マスタへ委譲する薄いディスパッチャの組で提供されます。「提供ランタイム」列は、そのベース名で実在する拡張子です。

この 52本には `plugins/` 外のリポジトリ運用スクリプトは含みません。別途、`scripts/`（`apply-branch-protection` / `bump-version` / `check-sdd-structure` / `rollback-1.5.0`）とリポジトリ直下の `render-agent-frontmatter.{sh,ps1}` があります。後者は生成されるエージェント定義ファイルの単一の真実源として `contracts/agent-model-capabilities.*` の `role_defaults` を参照するもので、独立した契約節が [`PLUGIN-CONTRACTS.md`](../PLUGIN-CONTRACTS.md) に置かれています。

**ゲート系（`check-*`、13本）** — 判定を返し、失敗時に exit 1 でフェイルクローズします。

| スクリプト名 | 提供ランタイム | 目的 |
|---|---|---|
| `check-component-coverage` | sh / ps1 / py | Reverse Coverage Gate。コンポーネントのパス所有関係から網羅性を判定し、`check-component-coverage-verdict/v1` 証跡レコードを常に発行する。**v1.15.0 の新ゲートで、`high`/`critical` の必須チェックセットに登録済み** |
| `check-contract` | sh / ps1 / py | Default-FAIL 検証契約 (JSON) の検証（[詳細](#check-contract)） |
| `check-cross-model` | sh / ps1 | クロスモデル合意検証。パネリスト verdict と主評価者 verdict の突き合わせ |
| `check-design-system` | sh / ps1 | デザインシステム準拠の warn フェーズゲート（[詳細](#check-design-system)） |
| `check-domain-conformance` | sh / ps1 | ドメイン適合の warn フェーズゲート。`domain/` 不在時は exit 0 でスキップ |
| `check-evidence-bundle` | sh / ps1 | Done 判定用 evidence bundle の存在・SHA-256・プロベナンス検証（[詳細](#check-evidence-bundle)） |
| `check-hook-activation-handshake` | sh / ps1 / py | ホストカナリア方式のチャレンジ/レスポンスでフック実装が実際に発火しているかを検証 |
| `check-placeholders` | sh / ps1 | placeholder / stub / generic-fallback 実装の検出（[詳細](#check-placeholders)） |
| `check-quality-gate-cycle-limit` | sh / ps1 | 現 feature スコープの quality-gate 反復回数上限を強制（無限ループ防止） |
| `check-risk` | sh / ps1 | `Risk:` 階層と `Risk Rationale:` の検証（[詳細](#check-risk)） |
| `check-task-state` | sh / ps1 | tasks.md 状態機械の検証（[詳細](#check-task-state)） |
| `check-traceability` | sh / ps1 | REQ→AC→TEST→証跡チェーンの検証（[詳細](#check-traceability)） |
| `check-workflow-state` | sh / ps1 | `specs/workflow-state-registry.json` をもとにリポジトリ全体の SDD ワークフロー状態を検証（診断行は API 安定） |

**生成系（`generate-*`、5本）** — 成果物・証跡・派生ファイルを決定論的に生成します。

| スクリプト名 | 提供ランタイム | 目的 |
|---|---|---|
| `generate-approval-sidecar` | sh / ps1 / py | Project Context / Provider Binding の `context_sha256` を計算し、HMAC-SHA256 署名した承認サイドカーを `sdd/.staging/` へ**候補として**書き出す（人間 / CI 専用） |
| `generate-evidence-bundle` | sh / ps1 | 検証契約と品質レポートから、参照成果物すべての SHA-256 を含むハッシュ検証済み evidence bundle を生成 |
| `generate-gate-capabilities` | sh / ps1 / py | 正準 Registry (`contracts/capability-registry.json`) から `generated/gate-capabilities.json` を射影生成 |
| `generate-guard-invariants` | py | `references/guard-invariants.json` から、各ランタイム native なガード不変条件モジュール (`generated/guard-invariants.generated.{sh,ps1,js}` / `guard_invariants.py`) をレンダリング |
| `generate-registry-digest` | sh / ps1 / py / js | Capability Registry の選択フラグメントの正準ダイジェストを生成（NFC 正規化・RFC 8785・ハッシュ化は canonicalize-sdd-yaml へ委譲） |

**検証系（`validate-*`、5本）** — 契約・マニフェスト・入力の妥当性を独立に再検証します。

| スクリプト名 | 提供ランタイム | 目的 |
|---|---|---|
| `validate-approval-sidecar` | sh / ps1 / py | 承認サイドカーを対応する内容ファイルに対して独立再検証。最初の失敗で短絡 |
| `validate-capability-registry` | sh / ps1 / py | Capability Registry の9つの独立チェック (a–i) を検証。失敗ごとに `registry: <check-id>: <detail>` を1行出力 |
| `validate-facet-manifest` | sh / ps1 / py | Facet Manifest のスキーマ + セマンティクス検証 |
| `validate-review-context-set` | sh / ps1 | レビュアー / 評価者の起動を時系列で1件ずつ検証（`--reserve` で予約）。コンテキスト独立性の強制点 |
| `validate_path` | py | 共有パス検証ユーティリティ（`validate_evidence_path()`）。現在 import しているのは `check-contract.py` のみ。import 失敗時、呼び出し側は exit 1 でフェイルクローズしなければならない |

**解決・正規化系（6本）** — 判定を返さず、正規化された事実や候補集合を返します。

| スクリプト名 | 提供ランタイム | 目的 |
|---|---|---|
| `resolve-component-paths` | sh / ps1 / py | コンポーネントのパス所有関係リゾルバ。glob 意味論・正規化・exclusive/shared 分類・重複 / 未所有の検出 |
| `canonicalize-sdd-yaml` | sh / ps1 / py / js | 制限付き YAML サブセット（または JSON）を解析し、RFC 8785 (JCS) 正準 JSON バイト列またはその SHA-256 を出力 |
| `evaluate-predicate` | sh / ps1 / py | Predicate DSL 評価器。閉じた8演算子文法（all/any/not, equals/not_equals/contains/in/exists）をフェイルクローズ規則付きで評価 |
| `detect-policy-weakening` | sh / ps1 / py | 候補 `project-context.yaml` / `provider-bindings.yaml` を**現在 APPROVED なアンカー**（git HEAD でも呼び出し側指定パスでもない）と比較し、9つの正準弱体化カテゴリへ分類 |
| `detect-panel` | sh / ps1 | 利用可能な非 Anthropic パネリスト CLI を検出し、slug を改行区切りで列挙 |
| `registry_discovery` | py | Registry 探索契約の共有ヘルパモジュール。パッケージ同梱コピー優先のフェイルクローズ解決順を実装 |

**運用・強制系（8本）** — フック・停止・公開・記録・外部パネリスト実行を担います。

| スクリプト名 | 提供ランタイム | 目的 |
|---|---|---|
| `sdd-hook-guard` | sh / ps1 / py / js | 統一 PreToolUse ガードのディスパッチャ（承認ガード / WFI 承認ガード。[詳細](#hook-guard-script)） |
| `kill-switch` | sh / ps1 / js | `AGENT_STOP` が存在する間、全ツール呼び出しを停止する PreToolUse フック |
| `apply-human-copy` | sh / ps1 | Anchored-publisher 相当の human-copy 公開ツール。sh / ps1 が**それぞれ独立に**完全な publisher ロジックを実装（Python マスタなし） |
| `emit-run-record` | sh / ps1 | WFI 効果測定用の run record を決定論的に発行（feature slug・トラック・モデル・effort・プラグインバージョン） |
| `vendor-capability-registry` | sh / ps1 / py | 正準の top-level `contracts/*` から `plugins/sdd-quality-loop/contracts/*` を再取り込み（vendored copy のドリフト検査 / リリースゲート） |
| `prepare-panelist-input` | sh / ps1 | サニタイズ済みパネリスト入力バンドルを同意ゲート付きで準備 |
| `run-panelist-gpt` | sh / ps1 | OpenAI GPT パネリストを `codex` CLI 経由で隔離スクラッチ内で実行 |
| `run-panelist-gemini` | sh / ps1 | Google Gemini パネリストを `gemini` CLI 経由で隔離スクラッチ内で実行 |

**他プラグインの決定論的スクリプト（15本）**

| スクリプト名 | 所属プラグイン | 提供ランタイム | 目的 |
|---|---|---|---|
| `check-sdd-structure` | sdd-bootstrap | sh / ps1 | SDD ディレクトリ構造の preflight 検証（[詳細](#check-sdd-structure)） |
| `design-sync-scan` | sdd-bootstrap | sh / ps1 | design-sync-loop のアップロード前 egress 衛生スキャン |
| `domain-review-precheck` | sdd-domain | sh / ps1 | domain-review 遷移の決定論的前提・プロベナンスをレビュアー起動前に検証 |
| `check-terminal-tier-resume` | sdd-implementation | sh / ps1 | `terminal-tier-recurrence` で Blocked になったタスクの再開可否を、永続化された `terminal-tier-resume/v1` 証跡から判定 |
| `prepare-task-snapshot` | sdd-implementation | sh / ps1 | タスク入力の不変スナップショットを公開（ハッシュ束縛） |
| `select-agent-model` | sdd-implementation | sh / ps1 | `contracts/agent-model-capabilities.json` を参照し、リスク階層・失敗履歴からエージェントのモデル / effort 階層を選択 |
| `validate-implementation-report` | sdd-implementation | sh | 実装レポートの構造検証 |
| `validate-task-input-manifest` | sdd-implementation | sh / ps1 | タスク入力マニフェスト（単体・バッチ）の検証。バッチはマニフェスト集合全体を起動前に検証 |
| `check-risk-upgrade` | sdd-lite | sh / ps1 | lite トラックのローカルなリスク昇格チェック（リモート読み取りは一切行わない） |
| `check-task-state-lite` | sdd-lite | sh / ps1 | lite 用の軽量状態ゲート（[詳細](#check-task-state-lite)） |
| `spec-review-precheck` | sdd-review-loop | sh / ps1 | 仕様レビュー遷移の前提・プロベナンス検証 |
| `impl-review-precheck` | sdd-review-loop | sh / ps1 | 実装方針レビュー遷移の前提・プロベナンス検証（attempt / round 単位） |
| `task-review-precheck` | sdd-review-loop | sh / ps1 | タスクレビュー遷移の前提・プロベナンス検証（attempt / round 単位） |
| `review-contract-validate` | sdd-review-loop | sh / ps1 | 3つの review-loop precheck の可搬な共通基盤。契約 ID とレポートルートの検証後にのみ正準 JSON を出力 |
| `validate-layer-traceability` | sdd-review-loop | ps1 / py | `traceability.md` と `requirements.md` の層別トレーサビリティ整合を検証（`.ps1` は `.py` へ委譲せず独立実装） |

以降は主要スクリプトの詳細です。ここに詳述が無いものは、各スクリプト先頭のコメント（`Usage:` 行と契約記述）が一次情報です。

### check-sdd-structure

**目的**

SDD プロジェクトディレクトリ構造を決定論的に検証。Preflight チェック。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-bootstrap/scripts/check-sdd-structure.sh [project-root]
```

```powershell
# PowerShell
.\plugins\sdd-bootstrap\scripts\check-sdd-structure.ps1 [project-root]
```

**検査内容**

**必須項目 (missing → exit code 1):**
- `AGENTS.md` (file)
- `specs/` (directory)
- `reports/implementation/` (directory)
- `reports/quality-gate/` (directory)
- `docs/adr/` (directory)
- `docs/review-tickets/` (directory)

**任意項目 (missing → warning のみ、exit 0):**
- `CLAUDE.md` (file)
- `contracts/` (directory)
- `docs/architecture/` (directory)

**ドリフト検査 (advisory、exit code に影響しない):**
- `specs/*/adr` に合致するディレクトリを検出。出力: `"drift: <path> (ADRs belong in docs/adr/)"`

**ホスト検出:**
- `.gitlab-ci.yml` または `.gitlab/` 存在 → `"host: gitlab"`
- `.github/` 存在 → `"host: github"`
- いずれもなし → `"host: local"`

**Exit codes**

- 0: 必須項目すべて存在 (OK)
- 1: missing 項目あり (FAIL)

---

### check-contract

**目的**

Default-FAIL 検証契約 (JSON) を決定論的に検証。quality-gate の必須ゲート。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-quality-loop/scripts/check-contract.sh <path-to-contract.json> [repo-root]
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-contract.ps1 <path-to-contract.json> [-RepoRoot <repo-root>]
```

**検査内容**

1. **Duplicate check IDs**: 同一契約内での重複 check id → FAIL

2. **チェック別ルール:**
   - `required: true` かつ `passes: false` → FAIL
   - `required: false` かつ `passes: false` → `waiver_reason` が非空でなければ FAIL
   - `passes: true` のチェックは非空の `evidence` (証拠ファイルパス) が必須
   - `evidence` は相対パスのみ（絶対パス・`../` トラバーサルは拒否）
   - `evidence` が指すファイルはリポジトリルート内に実在すること

3. **必須セット保護:**
   Baseline IDs (`lint`, `unit-tests`, `build`, `placeholder-scan`, `task-state-check`) は template に存在必須。存在するが `required: false` なら `waiver_reason` が非空でなければ FAIL

4. **リスク階層 superset 強制 (Pass 4):**
   contract に `risk` フィールドが存在する場合、`risk-gate-matrix.md` の階層最小セットを全て `required: true` で含むこと（contract は最小セットの superset であること）。`risk` フィールドが無い場合はレガシーモード（Pass 4 スキップ）。

5. **TDD Red→Green 証跡 (Pass 5):**
   `required_workflow: tdd` の場合、各テスト系チェックが非空・パスセーフな `red_evidence` と `green_evidence` ファイルパスを持つこと。

6. **`stack` 記述子:**
   contract に `"stack": "shell"` / `"docs"` / `"spec"` が設定されている場合、`lint` / `typecheck` / `build` の3チェックは `required: false` + 非空 `waiver_reason` で waive 可能。absent / `""` / `"code"` はデフォルト（waive 不可）。テスト/トレーサビリティ系チェックは全 stack で必須のまま。

**Exit codes**

- 0: すべてのチェック成功
- 1: 必須チェック失敗 or ルール違反

---

### check-task-state

**目的**

tasks.md 状態機械をディスク上で決定論的に検証。タスク遷移の整合性ゲート。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-quality-loop/scripts/check-task-state.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-task-state.ps1 <path-to-tasks.md> [-ReportsDir <reports-dir>] [-ImplReportsDir <impl-reports-dir>] [-RepoRoot <repo-root>]
```

**検査内容**

1. **Approval field**: `Draft` または `Approved` のみ許可

2. **Status field**: `Planned`, `In Progress`, `Blocked`, `Implementation Complete`, `Done` のいずれかのみ

3. **In Progress / Implementation Complete / Done は Approval: Approved 必須:**
   Status が該当するなら Approval は `Approved` であること

4. **Done 必須証跡:**
   - tasks.md ディレクトリ下に `verification/<task-id>.evidence.json` が存在
   - evidence bundle が `check-evidence-bundle` を通過
   - quality report に完全一致する `Task ID` と `VERDICT: PASS` が存在
   - verification contract が `check-contract` を通過し、全 passing evidence の SHA-256 が一致

5. **Implementation Complete 必須証跡:**
   - `reports/implementation/` に task id を言及する implementation レポート存在

6. **Blocked 必須フィールド:**
   - Non-empty `### Blockers` セクション（None / 空白 / bare list marker のみは不可）

7. **Duplicate task IDs**: `## T-001` の重複 → FAIL

**Exit codes**

- 0: すべてのタスク状態有効
- 1: ルール違反

---

### check-task-state-lite

**目的**

sdd-lite フロー用に `check-task-state` を fork した軽量状態ゲート。`Done` 遷移を evidence-bundle 非依存にし、「実装レポートがタスク ID に言及 + 品質レポートが `VERDICT: PASS` でタスク ID に言及」の2条件で許可する。共有ルール（Approval/Status 妥当値・In Progress/Impl Complete/Done の Approval 必須・Blocked の Blockers 必須・重複 ID 検出・CRLF 正規化）は `check-task-state` と同一。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-lite/scripts/check-task-state-lite.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
```

```powershell
# PowerShell
.\plugins\sdd-lite\scripts\check-task-state-lite.ps1 <path-to-tasks.md> [<reports-dir>] [<impl-reports-dir>] [<repo-root>]
```

**lite 差分（check-task-state との違い）**

- 除去: `Done` の `verification/<id>.evidence.json` 必須・`.contract.json` 必須・check-evidence-bundle 呼出
- 除去: critical 二者承認ロジック
- 変更: `Done` 要件を「`Approval: Approved` + 実装レポートがタスク ID に言及 + lite 品質レポートが `VERDICT: PASS` でタスク ID に言及」に置換

**Exit codes**

- 0: すべてのタスク状態有効
- 1: ルール違反

---

### check-risk

**目的**

タスクの `Risk:` 階層 (`low / medium / high / critical`) と `Risk Rationale:` フィールドの存在・値を決定論的に検証。`high`/`critical` タスクが `Required Workflow: tdd` を宣言していない場合にフェイルクローズ。

**使用法**

```bash
sh plugins/sdd-quality-loop/scripts/check-risk.sh <path-to-tasks.md> [task-id]
```

```powershell
.\plugins\sdd-quality-loop\scripts\check-risk.ps1 <path-to-tasks.md> [-TaskId <task-id>]
```

**Exit codes**

- 0: Risk フィールドが有効
- 1: 無効な階層値、`Risk Rationale:` 欠落、または `high`/`critical` で `Required Workflow: tdd` 未宣言

---

### check-traceability

**目的**

`traceability.json` の REQ→AC→TEST→証跡チェーンを決定論的に検証。第3引数 `require-evidence`（呼び出し側の quality-gate が `high`/`critical` 時に付与）を渡すと、各 link に証跡 (`evidence`) が列挙され実ファイルが存在することも検査。

**使用法**

```bash
sh plugins/sdd-quality-loop/scripts/check-traceability.sh <traceability.json> [repo-root] [require-evidence]
```

```powershell
.\plugins\sdd-quality-loop\scripts\check-traceability.ps1 -TracePath <traceability.json> [-RepoRoot <repo-root>] [-RequireEvidence]
```

**検査内容**

1. 各 link に非空の `req`、≥1件の `acs`（受け入れ条件）、≥1件の `tests` があること
2. `evidence` が列挙されている場合、各パスがリポジトリ内・実在・非空であること（`..` などの path traversal は拒否）
3. `require-evidence` モードでは、全 link が ≥1件の証跡ファイルを列挙していること（未列挙はフェイルクローズ）

**Exit codes**

- 0: トレーサビリティチェーン有効
- 1: チェーン断絶（`req`/`acs`/`tests` 欠落）、または `require-evidence` モードでの証跡欠落・不正パス

---

### check-evidence-bundle

**目的**

`Done` 判定に使う quality report、verification contract、passing evidence の存在と SHA-256 を検証。`high`/`critical` タスクでは `risk`・`required_workflow`・`spec_revision`・`build_env`・`builder`・`review_verdict` のプロベナンスフィールドを必須検証。`critical` タスクでは HMAC-SHA256 署名も検証（鍵は `SDD_EVIDENCE_KEY` / `SDD_EVIDENCE_KEY_FILE` / `~/.sdd/evidence-key` から解決）。

```bash
sh plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh <path-to-evidence.json> [repo-root]
```

```powershell
.\plugins\sdd-quality-loop\scripts\check-evidence-bundle.ps1 <path-to-evidence.json> [-RepoRoot <repo-root>]
```

---

### check-placeholders

**目的**

Placeholder・stub・generic-fallback 実装を検出。エージェントが完了を詐称する際に使用するパターンを狩る。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-quality-loop/scripts/check-placeholders.sh <file-or-dir> [<file-or-dir> ...]
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-placeholders.ps1 <file-or-dir> [<file-or-dir> ...]
```

**検索パターン**

```
TODO|FIXME|HACK\b|NotImplemented|not[ _-]implemented|PLACEHOLDER|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)|TODO_REPLACE_WITH_PROJECT_COMMANDS
```

**除外ディレクトリ**

- `.git`, `node_modules`, `bin`, `obj`, `dist`

**Exit codes**

- 0: placeholder / stub / fallback 検出なし
- 1: 1つ以上検出（各マッチ行を報告）

---

### check-design-system

デザインシステム準拠の決定論ゲート（warn フェーズ）。対象プロジェクトに
`design-system/` が存在するときのみ動作し、無ければ note 付きでスキップする
（exit 0）。① design-tokens.json の契約エンベロープ検証
（`design-system-contract/v1`・semver・generated_by・color/typography/spacing）、
② 変更ファイル中の生スタイル値（#hex / rgb() / hsl()）検出（design-system/・
build/・tests/・*.md・*.svg は除外）、③ design.md の
`## Design System Compliance` セクション確認。既定は WARN（exit 0）、
`SDD_DESIGN_SYSTEM_ENFORCE=error` で違反時に exit 1。

```txt
# Git Bash / WSL / macOS / Linux
plugins/sdd-quality-loop/scripts/check-design-system.sh <project-root> [<design-md>] [<changed-file>...]

# PowerShell
plugins/sdd-quality-loop/scripts/check-design-system.ps1 -ProjectRoot <path> [-DesignMd <path>] [-ChangedFiles <paths...>]
```

---

### check-component-coverage

**目的**

Reverse Coverage Gate。v1.15.0 で追加された新ゲートで、`risk-gate-matrix.md` の `high` / `critical` 必須チェックセットに登録済みです（`high = medium ∪ { requirement-traceability, check-component-coverage }`）。分類ロジックとgit-diff 収集は再実装せず、同ディレクトリの `resolve-component-paths.py` の公開関数を直接 import します。標準ライブラリ以外に依存しません。

**適用状態（3状態）**

適用可否は Facet Manifest ファイルの有無ではなく、**`workflow.capability_enforcement` の値からのみ**導出されます（ADR-0016）。`advisory` が暗黙に `required` のブロッキング強度へ昇格することはありません。

- `disabled-legacy`（`project-context.yaml` 不在、または当該フィールドが不在 / 不正）: 所有関係の Fail 条件評価をゼロ件で終え、実体のある N/A 証跡レコードを出力して exit 0。`--facet-manifest` は受理されるが存在確認はされない
- `advisory`: `--facet-manifest` が構造上必須（不在・読み取り不能はハードエラーで専用の exit code）。6つの Fail 条件をすべて評価・記録するが、**どれがトリガーしても exit は常に 0**
- `required`: 評価内容は `advisory` と同一だが、Fail 条件が1つでもトリガーしたときに限り非ゼロ exit

いずれの状態でも**必ず最後まで走り切り**、`producer.sha256` バインディングを持つ `check-component-coverage-verdict/v1` 証跡レコードを常に発行します。

**使用法**

```bash
sh plugins/sdd-quality-loop/scripts/check-component-coverage.sh \
  --config <project-context.yaml> --facet-manifest <manifest> \
  [--changed-paths-file <file>] [--source-rev HEAD] [--target-rev <rev>] [--repo-root <dir>]
```

`.sh` / `.ps1` は薄いディスパッチャ（python3 → pwsh/powershell → エラー終了）で、契約の一次情報は `check-component-coverage.py` です。

---

### resolve-component-paths

**目的**

コンポーネントのパス所有関係リゾルバ。glob 意味論・正規化・スキーマ適合（REQ-001）と、exclusive / shared 分類・overlap / unowned 検出・excluded-match 証跡（REQ-002）を実装します。`check-component-coverage` の基盤です。

**重要な性質**

分類結果は**データであって失敗ではありません**。出力 JSON に `UNOWNED` / `OVERLAP` が含まれていてもクリーンな resolve なら exit 0 で、分類結果を Gate Fail に変換するのは `check-component-coverage` だけです。非ゼロ exit になるのは config 形状エラー・未対応メタ文字パターン・NFC 衝突などです。

**使用法**

```bash
# 分類モード（--changed-paths-file 省略時は stdin から改行区切りの生パスを読む）
python3 plugins/sdd-quality-loop/scripts/resolve-component-paths.py \
  --config <project-context.yaml> [--changed-paths-file <file>]

# スキーマ適合モード（不在時はフェイルクローズ。スキップしない）
python3 plugins/sdd-quality-loop/scripts/resolve-component-paths.py \
  --check-schema-conformance [--schema contracts/project-context.template.yaml]
```

出力は全モードで JSON です（`--json` は受理される no-op）。

---

### apply-human-copy

**目的**

Anchored-publisher 相当の human-copy 公開ツール。ステージングされた候補ファイル群を、パス置換攻撃に耐える形で最終位置へ原子的に公開します。

**設計上の特徴**

- **Python マスタを持ちません。** `.sh` と `.ps1` が**それぞれ独立に**完全な publisher ロジックを実装しており、互いにディスパッチしません（T-007 のアーキテクチャ制約）
- POSIX には `openat()` / `renameat()` の束縛が無いため、POSIX 側では「保持したディレクトリハンドル経由で相対パスを1セグメントずつ解決する」保証を、プロセス自身の作業ディレクトリ束縛（相対名に対する `chdir(2)`）で実現しています
- 残存する窓（各セグメントの `-L` チェックと `cd` の間、および最終再チェックと `mv` システムコールの間）は単一のシステムコールでは閉じられず、これは FFI を持たない可搬 POSIX シェルで到達できる最強の保証である旨が明記されています。詳細は `docs/adr/0025-*`

**使用法**

```bash
# 公開
sh plugins/sdd-quality-loop/scripts/apply-human-copy.sh --staging-dir <dir> --manifest <file>

# 引数なし: 起動時に必須のクラッシュリカバリ走査だけを実行して終了
sh plugins/sdd-quality-loop/scripts/apply-human-copy.sh
```

`--staging-dir` / `--manifest` を与えない起動は、トランザクショナルバンドル契約が定める**起動時必須のクラッシュリカバリ走査のみ**を行います。

---

### sdd-hook-guard

統一 PreToolUse ガード（承認ガード / WFI 承認ガードの実体）。位置・実行方法・emit モードは [§4 Hook Guard Script](#hook-guard-script) を参照してください。`.sh` は POSIX ディスパッチャで、判定は隣接する Python または PowerShell のガードへ委譲されます。ガードが参照する不変条件は `references/guard-invariants.json` から `generate-guard-invariants.py` がレンダリングした `generated/guard-invariants.generated.{sh,ps1,js}` / `generated/guard_invariants.py` です。

---

### kill-switch

**目的**

PreToolUse フック。プロジェクトルートに `AGENT_STOP` が存在する間、すべてのツール呼び出しを停止します。人間が `AGENT_STOP` を作成すれば即座に停止し、削除すれば再開します。

**動作**

- ブロックは **exit 2** で行われ、日本語と英語の両方の警告メッセージを stderr に出力します
- `CLAUDE_PROJECT_DIR` が設定されていればそのディレクトリと `.` を検査します
- 未設定の場合は cwd から最大20階層まで親を遡り、各階層で `AGENT_STOP` を検査します。`.git`（ディレクトリ / worktree の `.git` ファイルの両方）に到達した時点で探索を打ち切ります

**提供ランタイム**

`kill-switch.sh` / `kill-switch.ps1` / `kill-switch.js`

## 6. テンプレート一覧

### sdd-bootstrap

| テンプレートパス | 生成物説明 |
|---|---|
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/investigation.template.md` | INV-xxx 所見付き調査レポート |
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/baseline-behavior.template.md` | BL-xxx 項目付き baseline 記録 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/AGENTS.template.md` | プロジェクト agent・role 定義 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/CLAUDE.template.md` | Claude インタラクションガイドライン |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/requirements.template.md` | 機能要件書 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md` | アーキテクチャ・設計決定 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/acceptance-tests.template.md` | 受け入れ基準・テスト |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/tasks.template.md` | タスク分割 (T-xxx) |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md` | トレーサビリティ行列 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json` | `design-system/` トークン契約の雛形（W3C DTCG、meta エンベロープは `contracts/design-system.contract.v1.schema.json` で検証） |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md` | UI 規約の雛形（3層構造: トークン / Do・Don't / レビューチェックリスト、WCAG 2.2 AA） |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md` | 言語非依存の普遍的 UX 規約（アクション / ダイアログ / アイコン / フロー / 状態 / 認知負荷 の6カテゴリ、既定値込み） |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/adr.template.md` | Architecture Decision Record |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ai-task.template.md` | AI 特化タスク template |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-context.template.md` | C4 Context diagram |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-container.template.md` | C4 Container diagram |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-component.template.md` | C4 Component diagram |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/openapi.template.yaml` | OpenAPI 仕様 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/json-schema.template.json` | JSON Schema 定義 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-github.template.yml` | GitHub Actions CI workflow |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-gitlab.template.yml` | GitLab CI pipeline |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/pull-request.template.md` | GitHub PR template |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/merge-request.template.md` | GitLab MR template |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/gitlab-issue.template.md` | GitLab Issue template |

### sdd-implementation

| テンプレートパス | 生成物説明 |
|---|---|
| `plugins/sdd-implementation/templates/implementation-report.template.md` | 実装進捗レポート（タスク サイクルごと） |
| `plugins/sdd-implementation/templates/diagnosis-report.template.md` | diagnose の診断レポート（再現手順・根本原因・回帰テスト） |

### sdd-quality-loop

| テンプレートパス | 生成物説明 |
|---|---|
| `plugins/sdd-quality-loop/templates/verification-contract.template.json` | Default-FAIL 契約 (lint / unit-tests / build 等チェック) |
| `plugins/sdd-quality-loop/templates/quality-report.template.md` | Quality gate 評価レポート |
| `plugins/sdd-quality-loop/templates/review-ticket.template.yml` | Review ticket YAML format |
| `plugins/sdd-quality-loop/templates/retrospective-report.template.md` | Workflow retrospective レポート |
| `plugins/sdd-quality-loop/templates/workflow-improvement.template.md` | Workflow improvement (WFI) 提案 |

---

## 7. Compatibility Matrix

各機能がどの実行環境で動作するかを示します。

| 機能 | Claude Code | Codex CLI | Copilot CLI |
|---|---|---|---|
| スキル本文 / テンプレート / references | ○ | ○ | ○ (SKILL.md互換) |
| scripts (.sh / .ps1) | ○ | ○ | ○ |
| `sdd-investigator` エージェント | ○ (`context: fork`) | ○¹ (`.codex/agents/`) | ○ (`*.agent.md`) |
| `sdd-evaluator` エージェント | ○ (サブエージェント) | ○¹ (`.codex/agents/`) | ○ (`*.agent.md`) |
| `panelist-gpt` / `panelist-gemini` エージェント | ○ (サブエージェント) | ○¹ (`.codex/agents/`) | — (ツインなし) |
| reviewer 系 (`spec` / `impl` / `task` / `domain`) ・`wfi-auditor` エージェント (10体) | ○ (サブエージェント) | — (ツインなし⁴) | — (ツインなし⁴) |
| フック定義 (承認ガード / AGENT_STOP) — ホストごとに別ファイル | ○ (`hooks/claude-hooks.json`) | ○² (`hooks/hooks.json`、`plugin_hooks` フラグ必要) | ○³ (`hooks/copilot-hooks.json`、plugin `preToolUse`) |
| `disable-model-invocation` | ○ | — | ○ |
| `context: fork` | ○ | — | — |

¹ `.codex/agents/` の TOML エージェントは Codex app / CLI のインタラクティブセッションで動作します。インストーラーはこれらを `~/.codex/agents/` へもコピーします。

² Codex は `hooks/hooks.json` の `command` / `command_windows` を `plugin_hooks` フィーチャーフラグが有効な場合に読み込みます。`apply_patch` ペイロードは `sdd-hook-guard` が処理します。

³ Copilot は `hooks/copilot-hooks.json` を使用します。stdout で `permissionDecision` を返すフォーマットを採用し、フェイルセーフ拒否を実装しています。既知の不具合: サブエージェント内では発火しない場合があります。

⁴ Copilot 用の `copilot-agents/*.agent.md` は `sdd-investigator` と `sdd-evaluator` の2体分しか存在せず、Codex 用の `.codex/agents/*.toml` は4体分（上記2体 + パネリスト2体）です。reviewer 系・domain 系・wfi-auditor 系にはどちらのツインもありません。これらの環境では、各ペアを新規コンテキストで同等の手順としてインライン実行し、`spec-review-precheck` / `impl-review-precheck` / `task-review-precheck` / `domain-review-precheck` と `validate-review-context-set` で独立性の前提を決定論的に確認してください。

**フックは補助線 (defense in depth)。決定論的スクリプト (`check-contract` / `check-task-state`) が最終防衛線です。**

**Codex / Copilot での運用:** `sdd-investigator` と `sdd-evaluator` はそれぞれ Codex の `.codex/agents/` TOML エージェント（`~/.codex/agents/` へインストーラーが自動コピー）および Copilot の `copilot-agents/*.agent.md` として利用できます。フックが無効な環境では、`scripts/check-task-state` と `scripts/check-contract` を手動実行して同じ不変条件を確認してください。

**併用時のハンドオフ:** ワークフロー状態はすべてリポジトリ内ファイル (`tasks.md` / `specs/` / `reports/` / 検証契約 JSON / `docs/review-tickets/`) に保存されます。Claude Code で生成した成果物を Codex / Copilot セッションでそのまま引き継ぐことができ、逆方向も同様です。

---

## 関連ドキュメント

- [../README.md](../README.md) — プロジェクト概要・フロー図
- [workflow-guide.md](workflow-guide.md) — SDD ワークフロー全体フロー・実行例
- [troubleshooting.md](troubleshooting.md) — よくあるエラー・解決方法
