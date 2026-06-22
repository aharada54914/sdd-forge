# SDD 内部スキルリファレンス（コントリビューター向け）

内部スキルの詳細仕様です。ユーザー向けリファレンスは [../skill-reference.md](../skill-reference.md) を参照してください。

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

### implement-tasks

**目的**

承認済みタスクを依存関係順に一括実装し、全タスクが `Implementation Complete` になった時点で `quality-gate` を自動起動します。`implement-task` を1タスクずつ手動で実行する代わりに、承認済みタスクをまとめて処理したい場合に使用します。

**呼び出し例**

```txt
# Claude Code
/sdd-implementation:implement-tasks specs/<feature>/tasks.md

# Codex
Use the implement-tasks skill for specs/<feature>/tasks.md
```

**前提条件**

`implement-task` と同一: `AGENTS.md` の存在確認 + `scripts/check-sdd-structure.sh` が `missing:` を報告しないこと。

**タスク選択アルゴリズム**

1. `tasks.md` を読み込み、`Approval: Approved` かつ `Status: Planned` または `In Progress` のタスクを収集
2. **依存関係フィルタ**: 各タスクの `### Blockers` セクションを解析し、参照先タスク (`T-NNN` パターン) が `Implementation Complete` / `Done` 未満なら選択対象から除外
3. `tasks.md` に登場する順序で最初の対象タスクを選択

**処理の流れ**

1. タスク選択アルゴリズムで次のタスクを決定
2. タスクを `In Progress` に設定
3. `implement-task` と同じロジックで Scope と Done When を実装
4. テスト追加・回帰テスト実行・自己レビュー・実装レポート生成
5. タスクを `Implementation Complete` に設定
6. 依存関係を再評価（完了タスクにより新たに選択可能になったタスクが出る可能性あり）
7. 次の選択可能タスクがあればループ（1 へ戻る）、なければ **全完了チェック** へ

**全完了チェックと quality-gate 自動移行**

`Approval: Approved` の全タスクが `Implementation Complete` または `Done` になった時点で:

1. 完了タスク一覧をユーザーに報告
2. **`quality-gate` を自動起動** し、`tasks.md` の順に全タスクを処理

一部のタスクが依存関係でブロックされていたり未承認の場合は、その状況をレポートして停止する（全完了条件を満たすまで quality-gate は起動しない）。

**停止・Blocked になる条件**

`implement-task` と同一: 要件曖昧・アーキテクチャ決定必要・無関係変更の競合・テスト実行不可・スコープ超過。Blocked になったタスクを記録してバッチ全体を停止。再開は本スキルを再実行すれば、最初の選択可能タスクから自動的に再開する。

**人間の関与ポイント**

- タスク承認: タスクは `Approval: Approved` である必要がある
- Blocked 解消: ブロッカーを解消した後、スキルを再実行

**やらないこと (Boundaries)**

- バッチ途中での個別タスク quality-gate 実行（全タスク完了後にまとめて実行する）
- タスクを `Done` に設定（`quality-gate` のみ可能）
- コミット・プッシュ・PR/MR作成（明示要求がない限り）
- `Approval: Approved` でないタスクの開始

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

### lite-spec

**目的**

社内・部署内アプリ向けの軽量仕様を作ります（`sdd-lite` プラグイン）。`sdd-bootstrap-interviewer` の縮約版で、要件・設計・タスクの3ファイルのみを生成し、traceability・ADR・受け入れテストの厳密記述は任意とします。アプリのコードは実装しません。低ステークスの社内開発向け。より高い厳格さが要るなら `sdd-bootstrap-interviewer` に切り替えます。

**呼び出し例**

```txt
# Claude Code
/sdd-lite:lite-spec <issue URL または 要件テキスト>

# Codex
Use the lite-spec skill.
Source: <issue URL または 要件テキスト>
```

**前提条件**

1. `AGENTS.md` がリポジトリルートに存在
2. `scripts/check-sdd-structure.sh` (または `.ps1`) が `missing:` を報告しない
3. 未整備なら `/sdd-bootstrap:sdd-adopt` を案内して停止（lite でも SDD 構造は前提）

**処理の流れ**

1. Issue URL か要件テキストを受け取る（読み取り専用取得を試み、不可なら本文を尋ねる）
2. 関連コード・既存パターンを軽く調査（大規模調査は委譲可）
3. `specs/<feature>/` に `requirements.md` / `design.md` / `tasks.md` を本プラグインの `templates/` から生成
4. 各タスクは `Approval: Draft` / `Status: Planned` で生成。`Risk:` 行は付けない（lite は階層強制を使わない）
5. 不明な製品判断は `Open Questions` に残す（勝手に埋めない）

**生成物**

- `specs/<feature>/requirements.md` / `design.md` / `tasks.md`

**人間の関与ポイント**

- タスク承認: 人間のみが `tasks.md` の `Approval:` を `Approved` にできる（AI は不可。既存 hook-guard が承認マーカーの増加をブロック）

**やらないこと (Boundaries)**

- traceability.md・ADR・evidence-bundle・受け入れテストの厳密記述の生成（必要なら `sdd-bootstrap-interviewer` へ）
- アプリのコード実装（`implement-task` が担当）
- 承認・Done 化

**昇格**

lite 成果物はフル SDD の部分集合。複数人開発や高ステークスへ移る際は `design.md` §6 / `plugins/sdd-lite/references/lite-flow-policy.md` の手順で加算的に厳格化できます。

---

### lite-gate

**目的**

`sdd-lite` フローの軽量品質ゲート（`sdd-lite` プラグイン）。実装者の自己申告ではなく、ゲート自身が検証コマンドを再実行して結果を記録します（自己採点防止の核を低コストで維持）。evidence-bundle・contract.json・cross-model・署名は扱いません。`implement-task` の後、lite フローの最終段で使用します。

**呼び出し例**

```txt
# Claude Code
/sdd-lite:lite-gate specs/<feature>/tasks.md#T-001

# Codex
Use the lite-gate skill for specs/<feature>/tasks.md#T-001
```

**前提条件**

- 対象タスクが `Status: Implementation Complete` かつ `Approval: Approved`
- `reports/implementation/<task-id>.md` が存在
- 望ましくは別コンテキスト/別セッション（または委譲）で実行し、実装者の主張を独立に再検証

**処理の流れ**

1. 変更範囲に対し `check-placeholders.{sh,ps1}` を実行
2. プロジェクトの lint / typecheck / build / test コマンドを**ゲート自身が実行**し出力を捕捉（コマンドが無い種別は「N/A」と理由を記録）
3. `check-task-state-lite.{sh,ps1}` を実行し状態機械を検証
4. `reports/quality-gate/<task-id>.md` を `templates/quality-report-lite.md` から生成。先頭に `Task ID: <task-id>` と `VERDICT: PASS|FAIL` を必ず置く（`check-task-state-lite` の Done 判定が依存）
5. すべて PASS のときのみ対象タスクを `Status: Done` にする。1つでも FAIL なら `VERDICT: FAIL` を記録し Done にせず実装者へ差し戻す

**生成物**

- `reports/quality-gate/<task-id>.md`（VERDICT 付き）
- 成功時の `Status: Done` 遷移

**人間の関与ポイント**

- なし（`Approval` は変更しない。承認は人間専管）

**やらないこと (Boundaries)**

- evidence-bundle / contract.json / cross-model-verify / 二者承認 / リスク階層強制（昇格時はフルの `quality-gate` へ）
- `Approval` の変更
- `Done` は本スキルのみが設定（`implement-task` は設定しない）

**昇格**

より強い保証が要るときは `quality-gate`（evidence-bundle・独立批判レビュー・cross-model 等）へ切り替えます。差分の全体像は [軽量トラック（sdd-lite）](../workflow-guide.md#軽量トラックsdd-lite) を参照。

---

### impl-review-loop

**目的**

`design.md` の実装方針を、2体の独立したブラインドレビュアー（A: 構造健全性、B: 実装可能性/リスク）による最大3ラウンドのレビューで品質保証します。`Impl-Review-Status: Passed` が `design.md` に書き込まれるまで、Phase 2（タスク生成）はブロックされます。

**呼び出し例**

```txt
# Codex
Use the impl-review-loop skill for feature <slug>

# Claude Code
/sdd-review-loop:impl-review-loop --feature <slug>
/sdd-review-loop:impl-review-loop --feature <slug> --edit-summary "Security Boundaries セクション追記"
/sdd-review-loop:impl-review-loop --feature <slug> --reset
```

**前提条件**

1. `specs/<feature>/design.md` が存在し、`Impl-Review-Status: Pending` ヘッダーフィールドがある。
2. 仕様レビュー（spec-review-loop）が通過済み（`Spec-Review-Status: Passed` が requirements.md に存在）。

**処理の流れ**

| ステップ | 処理 | 出力 |
|---|---|---|
| 1. Precheck | `impl-review-precheck.sh` 実行 | `precheck-result.json`（sha256・drift 検知・legacy_design フラグ） |
| 2. Reviewer-A | impl-reviewer-a を独立エージェントとして呼び出し | `reviewer-a.json`（9チェック: ARCH-COVERAGE など） |
| 3. integrated-summary | Reviewer-A の件数+IDのみを抽出（定見なし） | `integrated-summary.json` |
| 4. Reviewer-B | impl-reviewer-b を独立エージェントとして呼び出し（reviewer-a.json 読み取り不可） | `reviewer-b.json`（9チェック: DECISION-JUSTIFIED など） |
| 5. Verdict 統合 | Critical/Major/Minor 件数で判定 | `integrated-verdict.json`、`impl-review-contract.json` |
| 6. 状態遷移 | PASS/PASS-with-warnings/NEEDS_WORK/BLOCKED に分岐 | design.md 更新 or 提案レポート |

**判定ルール**

| 判定 | 条件 |
|---|---|
| PASS | Critical=0, Major=0, Minor=0 |
| PASS-with-warnings | ラウンド3 + Critical=0, Major=0, Minor>0 |
| NEEDS_WORK | ラウンド<3 + (Critical>0 または Major>0) |
| BLOCKED | ラウンド3 + (Critical>0 または Major>0) → `--reset` で新attempt |

**Reviewer-A の 9 チェック (TYPE-D 構造)**

ARCH-COVERAGE, NO-CIRCULAR-DEPS, DATA-COVERAGE, API-COVERAGE, SECURITY-COVERAGE, FRONTEND-BACKEND-CONSISTENCY, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT, ADR-PRESENT

**Reviewer-B の 9 チェック (TYPE-H 品質/実装可能性)**

DECISION-JUSTIFIED, OPEN-QUESTIONS-RESOLVABLE, ASSUMPTIONS-VALID, NO-REQ-CONTRADICTION, PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED, INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE

**backward compatibility**

既存 design.md に新フィールド（`## Components` 等）が無い場合は `[LEGACY COMPAT]` Minor 通知のみで失敗しない（`legacy_design: true` が contract に記録される）。

**Sudo モード**

Sudo モードは適用外。`--edit-summary` 要件も sudo では免除されない。

**LITE-SKIP**

acceptance-tests.md が不在で design.md に `Impl-Review-Status:` フィールドもない場合はスキップ警告を発して停止（PASS と見なさない）。

---

### task-review-loop

**目的**

`tasks.md` のタスク分解を、2体の独立したブラインドレビュアー（A: 構造カバレッジ、B: 品質/リスク）による最大3ラウンドのレビューで品質保証します。依存関係サイクル検出・Blockers 正準形式検証を含みます。

**呼び出し例**

```txt
# Codex
Use the task-review-loop skill for feature <slug>

# Claude Code
/sdd-review-loop:task-review-loop --feature <slug>
/sdd-review-loop:task-review-loop --feature <slug> --edit-summary "T-003のBlockers修正"
/sdd-review-loop:task-review-loop --feature <slug> --reset
```

**前提条件**

1. `specs/<feature>/tasks.md` と `specs/<feature>/requirements.md` が存在する。
2. spec-review-loop が通過済み（`Spec-Review-Status: Passed`）。
3. impl-review-loop が通過済み（`Impl-Review-Status: Passed` が design.md にある）。

**処理の流れ**

| ステップ | 処理 | 出力 |
|---|---|---|
| 1. Precheck | `task-review-precheck.sh` 実行 | `precheck-result.json`（WORKFLOW-MATCH、Blockers 形式検証、sha256）、`dependency-graph.json` |
| 2. Reviewer-A | task-reviewer-a を独立エージェントとして呼び出し | `reviewer-a.json`（14チェック） |
| 3. integrated-summary | 件数+IDのみ抽出 | `integrated-summary.json` |
| 4. Reviewer-B | task-reviewer-b を独立エージェントとして呼び出し（reviewer-a.json 読み取り不可） | `reviewer-b.json`（8チェック） |
| 5. Verdict 統合 | Critical/Major/Minor 件数で判定 | `integrated-verdict.json`、`task-review-contract.json` |
| 6. 状態遷移 | PASS/PASS-with-warnings/NEEDS_WORK/BLOCKED に分岐 | tasks.md 更新 or 提案レポート |

**Reviewer-A の 14 チェック (TYPE-D 構造)**

PREREQ-AC-IDS, BLOCKERS-FORMAT, REQ-COVERAGE, AC-COVERAGE, ORPHAN-TASK, ORPHAN-TEST, INITIAL-STATE, RISK-WORKFLOW-FORMAT, NO-DUPLICATE-AC, DEPENDENCY-COMPLETE (A.10), DEPENDENCY-CYCLE (A.11), SINGLE-CONCERN, OBSERVABLE-DONE, TRACEABILITY-SYNC

> DEPENDENCY-COMPLETE (A.10) は DEPENDENCY-CYCLE (A.11) より先に実行する（dependency-graph.json が完成してからサイクル検出を行うため）。

**Reviewer-B の 8 チェック (TYPE-H 品質/リスク)**

RISK-APPROPRIATE, HIGH-CRITICAL-EVIDENCE, TASK-SIZE, EDGE-CASE-COVERAGE, TEST-TYPE-MATCH, ROLLBACK-PLAN, SCOPE-DISJOINT, DEPENDENCY-OVERLAP

**Blockers 正準形式**

`None`、`T-NNN`、`T-NNN, T-MMM`（カンマ区切り T-NNN IDのみ）。range 記法（`T-001..T-003`）は Major で棄却。`precheck.sh` が事前検証し、依存グラフを `dependency-graph.json` として生成。

**LITE-SKIP**

acceptance-tests.md が不在の場合は即時 PASS を返してスキップ。

**Sudo モード**

Sudo モードは適用外。

---
