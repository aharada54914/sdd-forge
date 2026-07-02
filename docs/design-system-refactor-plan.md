# 統一デザインシステム統合リファクタリング計画

Status: Draft（人間レビュー待ち）
作成日: 2026-07-03 / 改訂: 2026-07-03（SmartHR Design System 連携を追加）
根拠調査: 本文末尾の「調査ソース」参照

## 1. 目的とスコープ

sdd-forge のワークフローで開発されるアプリケーションに対して、**プログラミング言語・フレームワークをまたいで統一されたデザインシステム**を提供・強制する仕組みを、既存の 6 プラグイン（bootstrap / review-loop / implementation / quality-loop / lite / ship）に非破壊で組み込む。

- **Ship する**: デザイントークン契約スキーマ、design-system 成果物の生成・レビュー・実装強制・決定論的検証の各フェーズ統合、WCAG 2.2 への更新。
- **Ship しない**: 特定のデザインシステム実体（色・フォントの具体値）、特定言語専用の lint プラグイン実装、Figma 連携ツールの内製。sdd-forge は「対象アプリのデザインシステムを生成・強制するワークフロー層」に徹する。

## 2. 設計方針（調査結果からの決定）

### D1. 単一ソースは DTCG JSON トークン

W3C Design Tokens 仕様（v2025.10 で初の安定版）に準拠した `design-tokens.json` を対象アプリの唯一の真実源とする。言語横断の統一は **トークン層** で実現する: Terrazzo / Style Dictionary v4+ で CSS変数 / TypeScript / Swift / Kotlin / Flutter 等へ変換する構成を bootstrap が対象アプリに生成する。Save Medical 事例（Figma → JSON → 言語別テーマ → パッケージ配布）と同型。

### D2. 「ガイドラインではなく機械強制」

eslint-plugin-smarthr（56ルール: a11y 18 / best-practice 23 / design-system-guideline 4 ほか）の核心は、デザインシステム準拠を **AST レベルで機械強制** する点にある。sdd-forge では次の 3 層に翻訳する:

1. **プロンプト規約層**: implementation-policy に UI 実装規則を追記（トークン参照のみ許可、生値禁止、コンポーネント再利用優先）。
2. **レビュー観点層**: impl-reviewer / evaluator のチェックリストに design-system conformance を追加。
3. **決定論的ゲート層**: `check-design-system` スクリプト（言語非依存: DTCG schema 検証 + 変更差分内の生カラーコード等の検出）+ 対象アプリ側 lint 設定の生成（TS なら ESLint flat config、他言語は相当ツール）。

### D3. 形骸化防止は DX 優先

Save Medical 事例と zeroheight 2026 レポート（満足度 42%→32% 低下、原因は官僚化）の両方が示す教訓: 強制だけでは形骸化する。生成される design-system 成果物は「守らせる文書」ではなく「実装者（AI エージェント）が最短で正解を引ける参照」として設計し、UI を含まないタスクには一切のオーバーヘッドを課さない（条件付きロード）。

### D4. a11y 基準は WCAG 2.2 AA に更新

現行の `accessibility-checklist.md` は WCAG 2.1 AA。2026-06-28 に EU アクセシビリティ法の適用が始まっており（施行済み）、WCAG 2.2 は ISO/IEC 40500:2025 として国際標準化済み。2.2 AA へ更新する（タッチターゲット 24×24px、Focus Not Obscured、認証での認知負荷排除など）。

### D5. DS プロファイル戦略 — SmartHR Design System 公式 AI プラグインとの連携

kufu/smarthr-design-system は **AI コーディングエージェント向け公式スキルプラグイン** を配布している（`.claude-plugin/marketplace.json`、Claude Code / Cursor / Codex 対応。導入: `/plugin marketplace add kufu/smarthr-design-system` → `/plugin install smarthr-design-system@smarthr-design-system`）。内容は 2 スキル:

- **component-guidelines**: smarthr-ui 全 104 コンポーネントのガイド。各ガイドは 3 層構成 — Layer 1: Props/型（`smarthr-ui/metadata.json` から自動生成）/ Layer 2: Do・Don't（eslint-plugin-smarthr のルール README から自動生成）/ Layer 3: 使い方チェックリスト（`checklist.yaml`、人手レビュー済み）。Progressive Disclosure で必要時のみロード。
- **design-pattern-guidelines**: ページレイアウト・UI パターン 22 件のガイド。

sdd-forge はゼロから DS を生成するだけでなく、**「実績ある公開 DS の公式 AI プラグインを併用する」を第一級の選択肢**とする。bootstrap の初期化で `ds_profile` を選択させる:

| プロファイル | 内容 | 適用条件 |
|---|---|---|
| `smarthr` | smarthr-ui + eslint-plugin-smarthr + 公式スキルプラグイン併用。トークンは createTheme でブランド差し替え可 | TS/React スタック。SmartHR 系ルックで良い社内・業務アプリ（sdd-lite の主対象と一致） |
| `custom` | 元計画どおり DTCG トークン + design-system.md を生成 | 独自ブランド必須、または非 React スタック |
| `none` | DS 統合なし | UI を持たないプロジェクト |

ライセンス: smarthr-ui / tamatebako（eslint-plugin-smarthr 等）/ smarthr-design-system とも **MIT を原文確認済み**（smarthr-design-system は LICENSE ファイル無しだが package.json で MIT 宣言）。ただしロゴ・イラスト等のブランド資産は別扱いの可能性があるため流用しない。スキル文書も sdd-forge へのコピー同梱はせず、**マーケットプレイス経由の併存インストール**とする。

`custom` プロファイルにも SmartHR の構造を借用する: design-system.md 生成テンプレートを同じ 3 層（機械抽出の Props/トークン層 → lint/Do・Don't 層 → 人手チェックリスト層）+ Progressive Disclosure で設計し、対象アプリ独自の component-guidelines を将来スキル化できる形にしておく。

### D6. トークンを超える普遍的 UI/UX パターンの規約化

色・数値のトークンだけでは「見やすく・わかりやすい」UI は保証できない。**言語・フレームワーク非依存の普遍的インタラクション規約**を第一級の成果物として扱う（SmartHR の design-pattern-guidelines 22 パターンと eslint-plugin-smarthr の design-system-guideline 系ルールが実証している領域）。`custom` プロファイル向けにデフォルト規約集 `ui-patterns.md` をテンプレート化し、最低限次のカテゴリを収録する:

| カテゴリ | 規約の例（デフォルト値として同梱） |
|---|---|
| アクション配置 | プライマリ/セカンダリボタンの順序と位置の一貫性（プラットフォーム慣習に従い全画面で統一）、破壊的アクションは物理的に分離し色+確認で二重防衛、画面内のプライマリアクションは 1 つ |
| ダイアログの出しどころ | 不可逆・破壊的操作の確認時のみモーダルを使用。通知・進捗はモーダルにしない（トースト/インライン）。乱発禁止。ダイアログ内ボタンはアイコンのみ禁止・テキスト必須（smarthr ルール借用） |
| アイコン | アイコン単独使用は普遍的意味を持つもの（検索・閉じる等）に限定し、原則テキスト併記。1 要素に複数アイコン禁止（smarthr ルール借用）。同一概念には全画面で同一アイコン |
| フロー整合 | 画面遷移・ウィザードの「次へ/戻る」位置固定、ユーザーの作業順（読む→入力→確定）に沿った上→下・左→右配置、送信後のフィードバックとエラー時の復帰経路を必ず設計 |
| 状態設計 | 空状態・ローディング・エラーの 3 状態を全ビューで定義。エラーメッセージは発生箇所の近くに表示し、次の行動を示す |
| 認知負荷 | 1 画面 1 目的、選択肢は 7±2 以内を目安にグルーピング、既定値の提供 |

これらは Web/PyQt/GTK/Qt/組み込み UI のいずれにも適用可能な言語非依存規約であり、実装ポリシー層（生成時）と design-system-checklist（検証時）の両方から参照する。`smarthr` プロファイルでは同梱テンプレートの代わりに公式 design-pattern-guidelines スキルを正とする。

## 3. 新規成果物の定義

### `design-system/`（対象アプリのプロジェクトレベル成果物）

feature 単位の `specs/<feature>/` とは別に、プロジェクトに 1 つ:

```
design-system/
├── design-tokens.json    # DTCG 形式。色/タイポグラフィ/スペーシング/角丸など
├── design-system.md      # UI 規約: コンポーネント規約・禁止事項・a11y 要件(WCAG 2.2 AA)
├── ui-patterns.md        # 普遍的 UX 規約(§2 D6): ボタン配置/ダイアログ/アイコン/フロー/状態設計
└── build/                # (任意) Terrazzo/Style Dictionary 設定と言語別出力
```

トークンの言語別出力形式（build/ の対象。対象アプリのスタックに応じて選択）:

| スタック | 出力形式 |
|---|---|
| Web (React/Vue/テンプレート系) | CSS 変数 / `tokens.ts` |
| Python (PyQt/PySide) | QSS スタイルシート + `tokens.py` 定数モジュール |
| Python (Django/Flask テンプレート, Streamlit) | CSS 変数 + `tokens.py` |
| C/C++ (Qt) | QSS + ヘッダ生成 |
| C/C++ (GTK) | GTK-CSS |
| C (組み込み UI: LVGL 等) | `#define` ヘッダファイル（Style Dictionary カスタムフォーマット） |
| iOS / Android / Flutter | Swift / Kotlin / Dart（Style Dictionary 標準出力） |

### `contracts/design-system.contract.v1.schema.json`

design-tokens.json のメタ検証（DTCG 必須フィールド、semver、`generated_by`）と design-system.md の必須セクション定義。既存の `review-contract.v1.schema.json` と同列に置く。

## 4. フェーズ別リファクタリング計画

### Phase 0 — 契約とテンプレート（基盤・依存なし）

| # | 変更 | 対象 |
|---|---|---|
| 0-1 | `design-system.contract.v1.schema.json` 新規作成 | `contracts/` |
| 0-2 | `design-system.template.md` / `design-tokens.template.json` / `ui-patterns.template.md`（§2 D6 の普遍的 UX 規約をデフォルト値込みで同梱）新規作成 | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/` |
| 0-3 | PLUGIN-CONTRACTS.md に producer（sdd-bootstrap）/ consumer（sdd-implementation, sdd-quality-loop）契約を追記 | `PLUGIN-CONTRACTS.md` |

受入基準: schema が既存 6 テスト群と同じ流儀で `tests/` から検証可能。constant-parity.tests.sh が新契約定数を検知。

### Phase 1 — sdd-bootstrap: 生成フェーズ統合

| # | 変更 | 対象 |
|---|---|---|
| 1-1 | `design.template.md:26`（`## Frontend Plan`）直後に `## Design System Compliance` セクション追加（参照する design-system.md のバージョン、使用トークン群、新規コンポーネントの要否と理由） | `templates/design.template.md` |
| 1-2 | interviewer SKILL に分岐追加: Feature Type が `fullstack`/`frontend-only` のとき `design-system/` の存在を確認し、無ければ **`ds_profile` 選択インタビュー**（`smarthr` / `custom` / `none`。§2 D5 の判定条件を質問化: スタックは React か・独自ブランドが必要か・社内/公開アプリか）を実施。`custom` 時のみトークン供給源等の詳細質問に進む | `skills/sdd-bootstrap-interviewer/SKILL.md:69-112` |
| 1-2b | `ds_profile: smarthr` 選択時: AGENTS.md に `ds_profile: smarthr` を記録し、smarthr-design-system プラグインのインストール手順（`/plugin marketplace add kufu/smarthr-design-system`）を人間に提示。smarthr-ui / eslint-plugin-smarthr / eslint-config-smarthr / stylelint-config-smarthr（いずれも MIT）の導入をセットアップタスクとして tasks.md に起票 | 同上 + `templates/tasks.template.md` |
| 1-3 | `investigate-codebase` に brownfield 用インベントリ追加: ハードコード色・スペーシング・フォント指定の出現箇所を集計し design-system.md 初期化の入力にする | `skills/investigate-codebase/SKILL.md` |
| 1-4 | sdd-lite: `design-lite.md` に「トークン/既存コンポーネント使用」1 行宣言のみ追加（lite の軽さを維持） | `plugins/sdd-lite/templates/design-lite.md` |

受入基準: UI を含まない feature（`api-only`/`cli`/`library`）では生成物・質問が一切増えない。

### Phase 2 — sdd-review-loop: レビュー観点統合

| # | 変更 | 対象 |
|---|---|---|
| 2-1 | impl-reviewer-a に DESIGN-SYSTEM-CONFORMANCE 検査を追加（design.md の Design System Compliance セクションが design-system.md と矛盾しないか、新規コンポーネント追加に理由があるか） | `agents/impl-reviewer-a.md:63-154`（Feature Type 分岐に追加） |
| 2-2 | impl-reviewer-b の scope creep 検査に「規約外 UI ライブラリの無断導入」を追加 | `agents/impl-reviewer-b.md:172-177` |
| 2-3 | phase-review-checklist.md に Design System Specification セクション追加 | `references/phase-review-checklist.md:405-410` 付近 |

受入基準: review-prompt-calibration.tests.sh がレビュアー間の観点重複・欠落を検知しない。

### Phase 3 — sdd-implementation: 実装強制

| # | 変更 | 対象 |
|---|---|---|
| 3-1 | implementation-policy.md に UI 実装規則を追記: (a) スタイル値はトークン参照のみ・生値禁止、(b) 既存コンポーネント再利用優先・新規作成は design.md 記載時のみ、(c) eslint-plugin-smarthr 型の a11y 規則要点（アイコンのみボタン禁止・placeholder をラベル代替にしない・クリック可能要素はテキスト必須 等）、(d) 対象言語の lint 設定が無い場合は導入をタスク化して報告 | `skills/implement-task/references/implementation-policy.md` |
| 3-2 | implement-task の必須読み物（SKILL.md:36-41）に「UI タスク時は design-system/design-system.md」を条件付き追加 | `skills/implement-task/SKILL.md` |
| 3-3 | `ds_profile: smarthr` 時の実装規約を implementation-policy に追記: UI 実装前に smarthr-design-system プラグインの `component-guidelines`（コンポーネント選定・props）と `design-pattern-guidelines`（ページレイアウト）スキルを参照すること。プラグイン未導入を検出したら実装を進めず人間に導入を要請 | `skills/implement-task/references/implementation-policy.md` |

受入基準: 非 UI タスクのコンテキスト消費が増えない（条件付きロードのみ）。smarthr プロファイルではプラグインスキルへの参照のみで、ガイド内容を sdd-forge に複製しない。

### Phase 4 — sdd-quality-loop: 検証ゲート

| # | 変更 | 対象 |
|---|---|---|
| 4-1 | `design-system-checklist.md` 新規作成: トークン準拠(生値検出) / コンポーネント再利用 / レスポンシブ / ダークモード（トークンで定義時のみ）/ smarthr 系 design-system-guideline 4 種の言語非依存版 / **UI パターン準拠（§2 D6: プライマリアクション単一・破壊的操作の分離と確認・ダイアログの適時性・アイコンテキスト併記・フロー順配置・空/ローディング/エラー3状態の定義）** | `references/`（新規） |
| 4-2 | `accessibility-checklist.md` を WCAG 2.1 AA → 2.2 AA に更新 | `references/accessibility-checklist.md:1-48` |
| 4-3 | quality-gate の条件付きチェックリストロード（SKILL.md:69-72）に design-system-checklist を追加（UI 変更時） | `skills/quality-gate/SKILL.md` |
| 4-4 | `check-design-system.sh|ps1` 新規: ①design-tokens.json の schema 検証 ②変更差分中の生カラーコード（`#hex`/`rgb()`/`hsl()`）・マジックスペーシング値の検出（除外リスト付き grep、言語非依存）③UI タスクの design.md に Design System Compliance セクションが存在するか | `scripts/`（新規、bash 3.2 互換 + PowerShell 両対応） |
| 4-5 | verification-contract.template.json に `design-system` check を追加（UI タスクのみ required、`stack` waiver と同じ流儀で非 UI は waivable） | `templates/verification-contract.template.json` |
| 4-6 | risk-gate-matrix.md: UI 変更を含む medium 以上のタスクの required-set に `design-system` を追加 | `references/risk-gate-matrix.md:13-106` |
| 4-7 | evaluation-rubric.md: 「UI/コンポーネントライブラリ非準拠」を Major に分類 | `references/evaluation-rubric.md:15-53` |
| 4-8 | `ds_profile: smarthr` 時の決定論的ゲート: check-design-system は自前の生値 grep に加えて **eslint-plugin-smarthr の実行結果を検証チェックとして採用**（lint check に smarthr ルールが含まれることを verification-contract で確認）。言語別 AST 検査の自作を回避 | `scripts/check-design-system.sh\|ps1` + `templates/verification-contract.template.json` |

受入基準: gates.tests.sh に check-design-system の正常系/違反検出/waiver ケースを追加し全パス。既存ゲートの挙動が変わらない。

### Phase 5 — テスト・ドキュメント・オーケストレーション

| # | 変更 | 対象 |
|---|---|---|
| 5-1 | `tests/design-system-compliance.tests.sh|ps1` 新規（fixture: 準拠/違反サンプル） | `tests/` |
| 5-2 | sdd-ship の track detection に変更なし・quality-gate 委譲経由で自動適用されることを確認（契約上 sdd-ship の変更は不要の見込み） | `PLUGIN-CONTRACTS.md:39-88` 検証のみ |
| 5-3 | docs/workflow-guide.md・docs/skill-reference.md・README 特徴一覧に追記 | `docs/` |

## 5. 実施順序と工数感

依存関係: P0 → P1 → (P2 ∥ P3 ∥ P4) → P5。各 Phase は独立 PR とし、本リポジトリ自身の SDD フロー（`/sdd-bootstrap:run feature`）で仕様化してから実装することを推奨（dogfooding）。

優先度: **P0+P4-2（WCAG 2.2 更新）が最優先**（法的要件・独立して出荷可能）。次点は **smarthr プロファイルの最小実装（1-2・1-2b・3-3・4-8）** — 公式プラグイン・既存 lint を使うため自作部分が最小で、TS/React アプリに対して即座に「より良いデザインのアプリ生成」効果が出る。`custom` プロファイル一式（トークン契約・生成・検証の自作部分）はその後に段階導入する。

## 6. リスクとアンチパターン対策

| リスク | 対策 |
|---|---|
| 非 UI プロジェクトへのオーバーヘッド | 全変更を Feature Type / stack による条件付きロード・waivable check として実装(既存 `stack:` waiver と同じ流儀) |
| 生値検出の誤検知（テストコード・SVG 等） | 除外 glob + waiver 理由記述で回避可能に。検出は error でなく quality-gate の指摘として開始し、キャリブレーション後に強制化 |
| デザインシステムの形骸化 | design-system.md に「理由・避けるべき例」を必須セクション化（SmartHR/Save Medical 流）。workflow-retrospective の観点に DS 逸脱を追加 |
| lint プラグイン自作の泥沼 | 自作しない。TS/React は eslint-plugin-smarthr 等の既存プラグイン採用を第一候補として bootstrap が提案。他言語は grep ベースの決定論ゲートで下限を保証 |
| トークン変換ツールのロックイン | DTCG 標準形式のみを契約化し、Terrazzo / Style Dictionary の選択は対象アプリ側の自由とする |
| smarthr プロファイルのブランド固有性 | smarthr-ui は `createTheme()` でトークン差し替え可能（MIT）。独自ブランドが強く必要なら `custom` プロファイルへ誘導。ロゴ・イラスト等のブランド資産は流用禁止を規約に明記 |
| SmartHR プラグインとの共存・追従リスク | スキル文書を複製せずマーケットプレイス経由で併存（更新は upstream に追従）。プラグイン名・スキル名の衝突有無を Phase 1 で検証。smarthr-ui は React 専用のため、非 React スタックには `custom` プロファイルで対応 |

## 7. 未決事項（人間の判断が必要）

- **OQ-1**: `design-system/` の配置（対象アプリのリポジトリ直下 or `specs/` 隣接）。本計画は直下を仮置き。
- **OQ-2**: check-design-system 違反の初期運用を warn（指摘のみ）と error（ゲート失格）のどちらで始めるか。本計画は warn 開始 → 2 リリース後に error を推奨。
- **OQ-3**: sdd-lite トラックにも check-design-system を課すか。本計画は lite-gate では手動チェックリストのみ（スクリプト強制なし）を推奨。
- **OQ-4**: `ds_profile: smarthr` を sdd-lite のデフォルトにするか。lite の主対象（社内・部署内アプリ）は SmartHR 系ルックで十分なケースが多く、公式プラグイン併用が最も安く高品質だが、SmartHR 社外での採用実績・見た目の同質化を許容するかは利用者判断。本計画はデフォルト提案（明示確認つき）を推奨。

## 調査ソース

1. **デザインシステム 2025/2026 ベストプラクティス**（Web 調査、2026-07-03 取得）: W3C DTCG v2025.10 安定版 / Terrazzo・Style Dictionary v4 / Figma MCP・Code Connect / WCAG 2.2（ISO/IEC 40500:2025、EU 法 2026-06-28 適用）/ zeroheight 2026 Design Systems Report。
2. **eslint-plugin-smarthr v6.21.2**（kufu/tamatebako monorepo、2026-06-30 最終更新）: 56 ルールの構成と AST 強制アプローチ。
3. **Zenn: Save Medical「デザインシステム導入への取り組み」**（2025-02-25、Defuddle 抽出 2026-07-02）: Figma→JSON→言語別テーマ→GitHub Packages、radix-ui + vanilla-extract、CI で VRT、DX 重視。
4. **sdd-forge 内部構造探索**（2026-07-03）: 挿入ポイントの file:line は本文の各表に記載。
5. **kufu/smarthr-design-system・smarthr-ui・tamatebako**（GitHub API で一次確認、2026-07-03）: 公式 AI スキルプラグイン（`.claude-plugin/marketplace.json`、component-guidelines 104 件 / design-pattern-guidelines 22 件、3 層生成構造）/ smarthr-ui は MIT・React 専用・トークンは `packages/smarthr-ui/src/themes/create*.ts` / tamatebako は MIT（eslint-plugin-smarthr, eslint-config-smarthr, stylelint-config-smarthr ほか 11 パッケージ）/ smarthr-design-system は package.json で MIT 宣言（LICENSE ファイルなし）。
