# SDD スキルリファレンス

3つのプラグイン（sdd-bootstrap、sdd-implementation、sdd-quality-loop）に含まれる9つのスキルの詳細リファレンスです。業務フローの全体像については [workflow-guide.md](workflow-guide.md) を参照してください。

## 1. スキル一覧 (早見表)

| スキル名 | 所属プラグイン | 役割 | 前段スキル | 後段スキル |
|---|---|---|---|---|
| sdd-adopt | sdd-bootstrap | 既存プロジェクトにSDD構造を導入 | — | investigate-codebase, sdd-bootstrap-interviewer |
| investigate-codebase | sdd-bootstrap | コードベース・問題領域の読み取り調査 | sdd-adopt | sdd-bootstrap-interviewer |
| sdd-bootstrap-interviewer | sdd-bootstrap | インタビュー駆動の仕様・タスク作成 | investigate-codebase (任意) | implement-task |
| implement-task | sdd-implementation | 承認済みタスク1つを実装 | sdd-bootstrap-interviewer | quality-gate |
| quality-gate | sdd-quality-loop | 実装完了タスクの独立検証・Done判定 | implement-task | fix-by-review-ticket (条件付き), workflow-retrospective |
| fix-by-review-ticket | sdd-quality-loop | レビューチケットの修正を実装 | quality-gate | quality-gate |
| workflow-retrospective | sdd-quality-loop | SDD ワークフロー自体の改善提案 | quality-gate | — |
| sdd-sudo | sdd-quality-loop | 人間承認ゲートを期限付きで自動通過 | — | implement-task, quality-gate (オプション) |
| cross-model-verify | sdd-quality-loop | 複数ベンダーの独立 LLM パネリストを盲目並列実行し verdict JSON を収集 | quality-gate (critical タスク) | check-cross-model ゲート |
| lite-spec | sdd-lite | 社内・部署内アプリ向けの軽量仕様生成（要件/設計/タスクの3ファイル、traceability/ADR/evidence-bundle 不要） | — | implement-task |
| lite-gate | sdd-lite | sdd-lite フローの軽量決定論的品質ゲート（検証コマンドを自分で再実行し lite 品質レポートを生成 → Done） | implement-task | — |

**重要:** すべてのスキルは `disable-model-invocation: true` を指定しています。つまり、モデルが勝手にスキルを起動することはなく、ユーザーが明示的に `/sdd-bootstrap:sdd-adopt` のようなコマンドで呼び出す必要があります。このため、実装途中の誤った自動実行を防げます。

## 2. 各スキル詳細

### sdd-adopt

**目的**

既存プロジェクトにSDD構造を導入します。ディレクトリ、AGENTS.md、CLAUDE.md、ホスト別のCI/Issue/PRテンプレートを作成し、仕様やアプリケーションコードは書きません。

**呼び出し例**

```txt
Use the sdd-adopt skill for the current project root
```

**前提条件**

なし。既存プロジェクトで実行します。

**処理の流れ**

1. `scripts/check-sdd-structure.sh` (または `.ps1`) を実行して不足ディレクトリ・ファイルを確認
2. 不足ディレクトリを作成: `reports/implementation/`、`reports/quality-gate/`、`docs/adr/`、`docs/review-tickets/` (必須)；`contracts/schemas/`、`docs/architecture/` (任意)
3. `AGENTS.md` を `templates/AGENTS.template.md` から生成
4. `CLAUDE.md` を `templates/CLAUDE.template.md` から生成
5. ホスト検出（GitHub / GitLab / Local）に基づいてCI/Issue/PRテンプレートを配置
6. `specs/*/adr/` ディレクトリ内のADRを `docs/adr/NNNN-<slug>.md` へ移動 (4桁リポジトリワイド連番)
7. 既存ファイルとの競合があれば報告して変更しない

**生成物**

- `AGENTS.md`
- `CLAUDE.md`
- `.github/workflows/*.yml` (GitHub) または `.gitlab-ci.yml` (GitLab)
- `.github/ISSUE_TEMPLATE/` 配下のテンプレート (GitHub) または `.gitlab/issue_templates/` (GitLab)
- `.github/pull_request_template.md` (GitHub) または `.gitlab/merge_request_templates/` (GitLab)
- `docs/adr/NNNN-<slug>.md` (ADRの移動)

**停止・Blocked になる条件**

- `scripts/check-sdd-structure.sh` が `missing:` 行を報告しない場合、「already compliant」を報告して停止
- 既存ファイルとの競合時は変更せず、競合を報告して停止

**人間の関与ポイント**

- 任意ディレクトリ (`contracts/schemas/`、`docs/architecture/`) の作成確認

**やらないこと (Boundaries)**

- 仕様生成（feature specification を書かない）
- アプリケーションソースコード・テストの修正
- コミット・プッシュ・PR/MR作成（明示要求がない限り）

---

### investigate-codebase

**目的**

既存コードベースまたは問題領域を読み取り専用で調査します。仕様作成前の現状把握として、`investigation.md` (INV-xxx 所見) と `baseline-behavior.md` (BL-xxx 観察) を生成します。

**呼び出し例**

```txt
Use the investigate-codebase skill.
Mode: refactor
Target: src/reservation
```

**モード**

- `feature`: 新機能に関連する既存スクリーン・API・ビジネスルール・データフロー・依存関係・テストカバレッジ・確立されたパターンを検査
- `bugfix`: 影響範囲を特定し、実行パス・ビジネスルール・保持すべき観察可能な動作 (BL-xxx) を抽出
- `refactor`: 変更対象のすべてのコードをマップし、確立されたパターン・テストカバレッジ・リファクタリング前のすべての観察可能な動作をBL-xxx として記録
- `greenfield`: 類似実装・候補ライブラリ・技術的制約を調査。既存コードベース不要

**前提条件**

なし（フォーク可能な環境でサポート）

**処理の流れ**

1. 指定モードに応じて調査対象を決定
2. コードベースを読み取り専用で探索 (ファイル修正・削除禁止)
3. すべての所見に `file:line` 出典を付与
4. `specs/<feature>/investigation.md` に INV-NNN ID を付けて記録
5. bugfix・refactor モードの場合、`specs/<feature>/baseline-behavior.md` に BL-NNN ID を付けて記録
6. 不明点は「Open Questions」セクションに記載（推測を記述しない）

**生成物**

- `specs/<feature>/investigation.md` (各所見に INV-NNN ID と file:line 出典付き)
- `specs/<feature>/baseline-behavior.md` (bugfix・refactor モードのみ、各所見に BL-NNN ID 付き)

**停止・Blocked になる条件**

- 読み取り専用制約に違反（ファイル作成・編集・削除）
- 投機的記述を発見（出典なしの主張）

**人間の関与ポイント**

なし（読み取り専用スキル）

**やらないこと (Boundaries)**

- ファイル、設定の書き込み・編集・削除
- 推測による記述（すべて file:line で根拠付け）

---

### sdd-bootstrap-interviewer

**目的**

インタビュー駆動で仕様とタスク契約を作成します。GitHub/GitLab Issue または供給された要件から、承認済みで実装対応可能な仕様を生成します。

**呼び出し例**

```txt
Use the sdd-bootstrap-interviewer skill.
Mode: feature
Source: https://github.com/example/product/issues/42
```

**モード**

- `project`: プロジェクト憲章と最初の機能仕様を作成
- `feature`: 既存リポジトリに新機能仕様を追加
- `bugfix`: 観察された動作・期待される動作・回帰テスト・影響範囲・最小安全修正を仕様化
- `refactor`: 観察可能な動作を変えない構造改善を仕様化。`specs/<feature>/investigation.md` と `specs/<feature>/baseline-behavior.md` が必須

**前提条件**

- `feature`、`bugfix`、`refactor` モードでは、処理開始前に `scripts/check-sdd-structure.sh` (または `.ps1`) を実行し、`missing:` 項目がないことを確認。ある場合は `sdd-adopt` を実行してから続行
- `refactor` モードでは `specs/<feature>/investigation.md` と `specs/<feature>/baseline-behavior.md` が必須

**処理の流れ**

1. GitHub/GitLab Issue URL または要件テキストを受け入れ
2. URL がある場合は読み取り専用で取得。なければ要件を聞く
3. リポジトリホストを GitHub / GitLab / Local で特定
4. `feature`、`bugfix`、`refactor` モードで関連コード・テスト・契約・パターンを検査
5. `specs/<feature>/investigation.md` が存在すれば読み込み、INV-xxx と BL-xxx を要件・トレーサビリティへ引き継ぐ
6. 大規模・未知のコードベースでは先に `investigate-codebase` を実行してその出力を引き継ぐ
7. 不明な仕様決定は「Open Questions」に記録（推測なし）
8. 要件・設計・契約・受け入れ基準・スコープ・重要なリスク が曖昧な間は承認しない

**生成物**

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/tasks.md` (各タスクは `Approval: Draft`、`Status: Planned`)
- `specs/<feature>/traceability.md`
- `docs/adr/NNNN-<slug>.md` (新規ADR。4桁リポジトリワイド連番；`specs/<feature>/adr/` は作らない)
- 関連API・データ契約

**停止・Blocked になる条件**

- `scripts/check-sdd-structure.sh` が `missing:` を報告
- 要件・契約が曖昧
- スコープが不明確

**人間の関与ポイント**

- タスク承認: 仕様・事前実装レビューを提示。`Draft` → `Approved` への変更は人間のみ可能

**やらないこと (Boundaries)**

- コミット・プッシュ・PR/MR作成（明示要求がない限り）

---

### implement-task

**目的**

承認済みタスク1つを実装し、独立検証の準備をします。`sdd-bootstrap-interviewer` 後、`quality-gate` 前に使用。

**呼び出し例**

```txt
Use the implement-task skill for specs/reservation/tasks.md#T-001
```

**前提条件**

1. `AGENTS.md` がリポジトリルートに存在することを確認
2. `scripts/check-sdd-structure.sh` (または `.ps1`) が `missing:` 項目を報告していないことを確認
3. どちらかが失敗なら、ユーザーに `/sdd-bootstrap:sdd-adopt` の実行を指示して停止

**処理の流れ**

1. `AGENTS.md`、対象機能の要件・設計・タスク・受け入れテスト・トレーサビリティ・関連ADR・契約・`references/implementation-policy.md`・`references/agent-delegation-policy.md` を読む
2. `tasks.md` を検査し、指定タスク、または最初の `Approval: Approved` かつ `Status: Planned` タスクを選択
3. `git status` と `git diff` を確認。無関係な既存変更を保持。タスク範囲と競合するなら `Blocked` として停止
4. `Approval: Approved` でないタスクは開始しない
5. タスクを `In Progress` に設定
6. Scope と Done When のみを実装
7. タスク必須テストを追加・更新、関連既存回帰テストを実行
8. 承認仕様に対するスコープ限定の自己レビューを実施
9. `reports/implementation/<task-id>.md` をテンプレートから生成
10. 実装・テスト・レポートがすべて完了したら、タスクを `Implementation Complete` に設定

**生成物**

- 実装されたコード・テスト
- `reports/implementation/<task-id>.md`

**停止・Blocked になる条件**

以下の場合、タスクを `Blocked` に設定し、ブロッカーを記録して停止：

- 要件・設計が曖昧
- 要件・アーキテクチャ・認証・認可・API破壊的変更の決定が必要
- 無関係な変更がタスク範囲と競合
- 必須テストが実行できない
- 要求される作業が承認スコープを超過

**人間の関与ポイント**

- タスク承認: タスクは `Approval: Approved` である必要がある

**やらないこと (Boundaries)**

- リポジトリ全体の品質ゲート実行（タスク必須でなければ）
- 独立的な重要レビュー実施・Playwright 視覚検証
- タスクを `Done` に設定（`quality-gate` のみ可能）
- コミット・プッシュ・PR/MR作成（明示要求がない限り）

---

### quality-gate

**目的**

`implement-task` が `Implementation Complete` にしたタスクを独立検証します。Default-FAIL 検証契約・決定論的チェック・隔離された重要レビューを実行し、Done 判定するか Blocked に戻すかを判断します。

**呼び出し例**

```txt
Use the quality-gate skill for specs/reservation/tasks.md#T-001
```

**前提条件**

- `AGENTS.md` がリポジトリルートに存在。なければ `/sdd-bootstrap:sdd-adopt` を指示して停止
- `reports/quality-gate/` と `docs/review-tickets/` ディレクトリは処理中に必要に応じて作成可

**処理の流れ**

1. タスク・実装レポート・要件・設計・受け入れテスト・トレーサビリティ・契約・ADR・Git diff・すべてのバンドルリファレンスを読む
2. 対象が `Implementation Complete` でなければ拒否
3. `templates/verification-contract.template.json` から Default-FAIL 検証契約を作成。実装レポートは主張として扱う（証拠ではない）
4. `verification-policy.md` に従い利用可能なCI同等チェック（lint、unit-tests、build等）をすべて検出・実行。実コマンド出力を証拠として保存し契約を更新
5. `test-policy.md` に従いテストを検証
6. `scripts/check-placeholders.sh`（変更ファイル）と `scripts/check-task-state.sh`（tasks.md）を実行
7. `refactor` / `bugfix` タスクで `baseline-behavior.md` が存在すれば、`differential-test-policy.md` を適用。すべての BL 差分を分類
8. 隔離された評価者で重要レビューを実行。Claude Code ではサブエージェント `sdd-evaluator` を使用。Codex では同梱の sdd-evaluator TOML を使用（`~/.codex/agents/` 直下の新規ロールファイル不可）。それ以外は新規セッションで実施
9. 発見を `Accepted`、`Rejected`、`Deferred` で分類
10. `auto-fix-policy.md` で許可される安全な修正のみ適用
11. 重要レビューを最大3サイクル繰り返す
12. UI 変更がある場合、ブラウザ / Playwright で画面・DOM・コンソールを検証。可能なら `deterministic-check-policy.md` のスモークラン実行
13. 未解決または自動修正不可の発見について review-ticket YAML を作成
14. `integrity-policy.md` に従いトレーサビリティを更新・ドリフト検出
15. `reports/quality-gate/<timestamp>.md` を生成（タスク id を記載）

**Done 判定条件**

以下をすべて満たす場合のみ `Done` に設定。それ以外は `Blocked` または `Implementation Complete` を保持：

- `check-contract` が成功（すべての必須契約チェックが真で、証拠ファイル存在）
- 受け入れ基準にテストがある
- Unresolved Critical / Major 発見がない
- 必須UI検証が成功
- 契約・ADRが実装と一致
- トレーサビリティが現在形

**停止・Blocked になる条件**

- Target が `Implementation Complete` でない
- `check-contract` が失敗
- Unresolved Critical / Major 発見がある
- 受け入れテストがない
- UI 検証失敗
- トレーサビリティが現在形でない

**人間の関与ポイント**

- 自動修正不可の場合、Review ticket 作成と人間審査が必要（`requires_human_decision: true` は sudo でも人間判断）
- `refactor`/`bugfix` で BL 差分が `accepted` の場合、人間承認が必要（sudo 中は自動通過。`fix-required` は自動通過しない）

**やらないこと (Boundaries)**

- コミット・プッシュ・PR/MR作成（明示要求がない限り）

---

### fix-by-review-ticket

**目的**

人間が承認した `docs/review-tickets/` の review-ticket YAML を適用します。スコープ限定の修正を実行し、タスクを `Implementation Complete` に戻して再度 `quality-gate` にかけます。

**呼び出し例**

```txt
Use the fix-by-review-ticket skill for docs/review-tickets/RT-001.yml
```

**処理の流れ**

1. チケットと参照タスク・仕様・コード・テストを読む
2. `requires_human_decision: true` または対象が不明確またはチケットの範囲を超過なら停止
3. チケットが説明する最小限の修正を適用
4. 必須テスト追加・更新、スコープ限定チェック実行
5. 要求される修正とテストが成功したら `resolved` に標記
6. タスクを `Implementation Complete` に戻す
7. 再度 `quality-gate` を実行してからタスク `Done` 可能

**停止・Blocked になる条件**

- `requires_human_decision: true`
- ターゲットが不明確
- 要求される変更がチケットの範囲を超過

**人間の関与ポイント**

- Review ticket は人間により承認される必要がある（`requires_human_decision: true` は sudo でも人間判断のまま）

**やらないこと (Boundaries)**

- 無関連の改善
- 仕様の無言変更
- 破壊的変更
- コミット・プッシュ・PR/MR作成（明示要求がない限り）

---

### workflow-retrospective

**目的**

SDD ワークフロー自体のパフォーマンスを観測・改善します。リワーク・Blocked・review-tickets・quality-gate 失敗を測定し、プロジェクト側ワークフロー設定の改善を人間の承認の下で提案します。

**呼び出し例**

```txt
Use the workflow-retrospective skill for specs/reservation/
```

**処理の流れ**

1. 以下を読み取り専用で収集（修正しない）：
   - `reports/implementation/` — タスク サイクルごとのレポート
   - `reports/quality-gate/` — quality-gate 実行ごとのレポート
   - `docs/review-tickets/` — 機能全体の review-ticket
   - `git log --oneline` — 機能パスにスコープした commit 履歴

2. 各タスクについて以下を導出：
   - **QG Cycles**: そのタスクの quality-gate レポート数
   - **Blocked Count**: 各レポート間の `Blocked` 決定数
   - **Tickets**: severity 別 (critical / major / minor) の review-ticket 数
   - **Auto-fixed**: `auto_fix_allowed: true` かつ `status: resolved` のチケット数
   - **Outcome**: 最終タスク状態 (`Done` or 未完了)

3. `reports/retrospective/<timestamp>.md` を `templates/retrospective-report.template.md` から生成

4. 摩擦を特定。以下パターンが2タスク以上で繰り返されたら Flag：
   - 同じ `type` の review-ticket が繰り返される
   - ある段階で `Blocked` が複数発生
   - チケット type の自動修正率が 50 % 未満

5. 各特定された摩擦について、`docs/workflow-improvements/WFI-NNN.md` を `templates/workflow-improvement.template.md` から作成。`status: Draft` で。NNN は既存最大から incrementして付与（なければ 001）

6. 人間が WFI の `status` を `Approved` に設定するまで待機。適用は人間 Approved 後。retrospective レポートの「Proposed Improvements」に保留中WFI参照を記録

7. 承認された改善を適用。変更対象はプロジェクト側ファイルのみ：
   - `AGENTS.md` または `CLAUDE.md` (プロジェクトルート)
   - `specs/` template ファイル・タスク分割ガイドライン
   - タスク粒度ガイダンス文書
   - **インストールプラグインファイル（skills / references / templates in plugins/）は修正しない**

8. 次タスク サイクル完了後、メトリクス再収集。WFI ドキュメントに `Result` セクション追記。前 retrospective と比較し摩擦低減を確認

**生成物**

- `reports/retrospective/<timestamp>.md`
- `docs/workflow-improvements/WFI-NNN.md` (status: Draft; 人間が Approved 後に有効化)

**停止・Blocked になる条件**

- インストールプラグインファイルの変更を試みた
- タスク状態フィールド の変更を試みた

**人間の関与ポイント**

- WFI は人間により `status: Approved` に設定される必要がある（ワークフロー統治の変更のため sudo でも自動通過しない）

**やらないこと (Boundaries)**

- アプリケーションコード修正
- タスク状態フィールド変更
- コミット・プッシュ（明示要求がない限り）
- review-ticket 作成・解決・修正
- `quality-gate` / `fix-by-review-ticket` 起動

---

### sdd-sudo

**目的**

人間の **承認待ち**（`Approval: Approved`、quality-gate の定型サインオフ、`accepted` 差分承認）を期限付きで自動通過させます。**判断フォーク**（`requires_human_decision`、アーキ/認証/セキュリティ決定、WFI 承認）と AGENT_STOP・すべての決定論的ゲートは常に人間/有効。ソロワーク・低リスク作業の効率向上。**人間専用**（エージェントは有効化不可）。

**呼び出し例**

```txt
/sdd-sudo 8h
/sdd-sudo status
/sdd-sudo off
```

**前提条件**

なし。任意の時点で有効化可能。

**動作**

1. `/sdd-sudo [duration]` で指定期間（デフォルト 8h、最大 24h）有効なトークンを生成
   - `SDD_SUDO` ファイルをプロジェクトルートに書き込み
   - `enabled-by`, `enabled-at`, `expires-epoch`, `duration` フィールド記録
2. `/sdd-sudo status` で現在の状態と残り時間を報告
3. `/sdd-sudo off` で即座に無効化

**Bypass 対象（sudo モード中は自動通過）＝承認ゲートのみ**

- `Approval: Approved` 書き込みガード（hook、タスク承認）
- quality-gate の定型サインオフ（contract 承認・定型 Done）
- `refactor`/`bugfix` の baseline 差分 `accepted` 承認（`baseline-behavior.md` 更新）

各 approval gate 通過時に `Approval: Approved (sudo <ISO8601>)` と記録（audit trail）

**sudo でも通さない＝判断・統治（常に人間）**

- `requires_human_decision: true` レビューチケット（業務判断）
- architecture / auth / authz / breaking-API / security 決定（ADR 級の判断）
- WFI `status: Approved`（ワークフロー統治の変更）

**非Bypass 対象（常に有効）**

- AGENT_STOP kill switch：存在時すべてのツール呼び出し拒否
- Agent-role guard：エージェントロール検証
- すべての決定論的スクリプト：`check-contract`、`check-placeholders`、`check-task-state`、`check-sdd-structure`

**hard policy**

- エージェントが自分で `SDD_SUDO` を作成・延長してはいけない（人間明示的呼び出しのみ）
- 期限切れ後の自動再有効化はしない
- 不明な場合は人間に質問

詳細は `plugins/sdd-quality-loop/references/sudo-mode-policy.md` を参照。

---

### cross-model-verify

**目的**

critical タスクの意味的検証を単一ベンダーに依存せず、複数の独立 LLM ベンダーによる並列盲目検証で補強します。`disable-model-invocation: true`（ユーザーが明示起動）。CI では実行しません。

**2層分離**

- **収集層**（非決定的・外部・opt-in・ローカル専用・**CI 非送信**）: `prepare-panelist-input`（同意確認 + 秘密情報サニタイズ）→ 盲目並列パネリスト呼び出し（Claude は Agent tool、GPT/Gemini は CLI ランナー）→ 各ベンダーの `T-NNN.panelist-<vendor>.verdict.json` を `specs/<feature>/verification/` に保存。
- **ゲート層**（決定論的・ネットワーク不要・CI fixture 検証）: `check-cross-model.{sh,ps1}` が verdict JSON を集約し `T-NNN.cross-model.json`（aggregate）を生成。終了コード 0/1/2。

**多様性要件と consensus ポリシー**

- distinct ベンダー数 ≥ 2 かつ 非 Anthropic ベンダー ≥ 1 が必須（unmet → FAIL）。
- 全パネリスト PASS かつ Critical 所見なし → 集約 `result: PASS`（exit 0）。
- いずれかが NEEDS_WORK または Critical 所見あり → `result: FAIL`（exit 1）。
- パネリスト consensus と sdd-evaluator verdict が乖離 → `requires_human_decision: true`、`result: NEEDS_HUMAN`（exit 1）。

**consent とサニタイズ**

`prepare-panelist-input` は `tasks.md` の `Cross-Model: enabled` フラグまたは有効な `SDD_SUDO` トークンがない限りフェイルクローズ。外部送信前に `.env` 内容・鍵素材・絶対パス・プライベート URL を除去し、サニタイズ済みバンドルの SHA-256 を `input_digest` として各 verdict に埋め込みます。

**check-contract との統合**

`check-contract` は contract の `cross_model` ディスクリプタ（`required` / `waived` / `legacy`）を読み Pass 6 で条件付き強制。`required` → aggregate JSON が evidence として必須。`waived` → `waiver_reason` 非空で OK。absent / `"legacy"` → 強制なし（後方互換）。`cross_model` は `RISK_TIERS` の機械形セットには含まれません（`signature` / 二者承認と同様の条件付き制御）。

**呼び出し例**

```txt
Use the cross-model-verify skill for specs/cross-model-verification/tasks.md#T-001
```

**関連スクリプト・エージェント**

| ファイル | 層 |
|---|---|
| `plugins/sdd-quality-loop/scripts/prepare-panelist-input.{sh,ps1}` | 収集 |
| `plugins/sdd-quality-loop/scripts/detect-panel.{sh,ps1}` | 収集 |
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.{sh,ps1}` | 収集 |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.{sh,ps1}` | 収集 |
| `plugins/sdd-quality-loop/scripts/check-cross-model.{sh,ps1}` | ゲート |
| `plugins/sdd-quality-loop/agents/panelist-gpt.md` | 収集 |
| `plugins/sdd-quality-loop/agents/panelist-gemini.md` | 収集 |
| `.codex/agents/sdd-panelist-gpt.toml` / `sdd-panelist-gemini.toml` | 収集 (Codex) |

詳細は `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` を参照。

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
| Claude Code | `hooks/hooks.json` | Node.js で Edit/Write/MultiEdit/apply_patch 登録 | — |
| Codex CLI | `hooks/hooks.json` + `command_windows` | shell / PowerShell。`plugin_hooks` フラグ必須 | apply_patch は `tool_input.command` で処理 |
| Copilot CLI | `hooks/copilot-hooks.json` | stdout で JSON `permissionDecision` 返す | サブエージェント内で発火しない既知不具合 |

**設計思想**

フックは defense in depth（層防御）。最終防衛線は決定論的スクリプト (`check-contract` / `check-task-state`)。フックが無効な環境では、これら決定論的スクリプトを手動実行して同じ不変条件を確認。AGENT_STOP が効かない場合はセッション手動終了。

### Hook Guard Script

**位置**

`plugins/sdd-quality-loop/scripts/sdd-hook-guard.{sh,ps1,py,js}`

**実行方法**

- POSIX shell: `sh plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh --emit exit|copilot`
- PowerShell: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/sdd-hook-guard.ps1 -Emit exit|copilot`
- Python3: `PAYLOAD=... python3 scripts/sdd-hook-guard.py`
- Node.js: Claude Code `hooks.json` で呼び出し

**Emit modes**

- `exit`: デフォルト。エラー時は警告メッセージ付きでフェイルオープン
- `copilot`: JSON `{"permissionDecision":"allow"|"deny"}` を stdout に出力（Copilot CLI 用）

---

## 5. 決定論的スクリプト

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
| `hooks/hooks.json` (承認ガード / AGENT_STOP) | ○ | ○² (`plugin_hooks` フラグ必要) | ○³ (plugin `preToolUse`) |
| `disable-model-invocation` | ○ | — | ○ |
| `context: fork` | ○ | — | — |

¹ `.codex/agents/` の TOML エージェントは Codex app / CLI のインタラクティブセッションで動作します。インストーラーはこれらを `~/.codex/agents/` へもコピーします。

² Codex は `hooks/hooks.json` の `command` / `command_windows` を `plugin_hooks` フィーチャーフラグが有効な場合に読み込みます。`apply_patch` ペイロードは `sdd-hook-guard` が処理します。

³ Copilot は `hooks/copilot-hooks.json` を使用します。stdout で `permissionDecision` を返すフォーマットを採用し、フェイルセーフ拒否を実装しています。既知の不具合: サブエージェント内では発火しない場合があります。

**フックは補助線 (defense in depth)。決定論的スクリプト (`check-contract` / `check-task-state`) が最終防衛線です。**

**Codex / Copilot での運用:** `sdd-investigator` と `sdd-evaluator` はそれぞれ Codex の `.codex/agents/` TOML エージェント（`~/.codex/agents/` へインストーラーが自動コピー）および Copilot の `copilot-agents/*.agent.md` として利用できます。フックが無効な環境では、`scripts/check-task-state` と `scripts/check-contract` を手動実行して同じ不変条件を確認してください。

**併用時のハンドオフ:** ワークフロー状態はすべてリポジトリ内ファイル (`tasks.md` / `specs/` / `reports/` / 検証契約 JSON / `docs/review-tickets/`) に保存されます。Claude Code で生成した成果物を Codex / Copilot セッションでそのまま引き継ぐことができ、逆方向も同様です。

---

## 関連ドキュメント

- [../README.md](../README.md) — プロジェクト概要・インストール方法
- [workflow-guide.md](workflow-guide.md) — SDD ワークフロー全体フロー・実行例
- [troubleshooting.md](troubleshooting.md) — よくあるエラー・解決方法
