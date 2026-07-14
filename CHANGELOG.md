# Changelog

## Unreleased

### 追加

- **ループインベントリと登録強制スイート (Issue #141, epic-159-pillar-a T-001)**:
  `tests/loops/loop-inventory.json`(schema `loop-inventory/v1`)を、8つの
  レビュー/ゲートループ(spec-review / impl-review / task-review /
  domain-review / quality-gate / terminal-tier / wfi-audit /
  hitl-diagnosis)の唯一の機械可読レジストリとして追加。新スイート
  `tests/loop-inventory.tests.sh` / `.ps1` が、リポジトリから実際のループ面
  (`plugins/**/scripts/*-review-precheck.sh`、
  `validate-review-context-set.sh` の stage:role 認可ペア)を導出して
  インベントリと双方向に突合し、cap_source:script なエントリの数値上限を
  driver ソースへ grep 照合し(terminal-tier は cap_kind:state として除外)、
  skill-instruction 強制のループ(wfi-audit / hitl-diagnosis)が偽陽性を
  出さないことを確認し、`tests/run-all.sh` / `tests/run-all.ps1` /
  `.github/workflows/test.yml` への自スイート登録を強制する。各チェックは
  mktemp コピーに対する negative self-check を伴い、300秒の実行時間予算
  (`LOOP_SUITE_BUDGET_SECONDS`)を自己計測・自己 FAIL する。実装時の grep
  実測により、impl-review / task-review の round<=3 上限は precheck
  スクリプトではなく SKILL.md 文面でのみ強制されると判明したため、両ループ
  も `cap_source: skill-instruction` として登録(ADR-0010 参照、詳細は
  `reports/implementation/epic-159-pillar-a/T-001.md`)。
  `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md`(Status Proposed)
  にこの発見を反映。

### セキュリティ修正

- **prepare-panelist-input.sh の HMAC 検証における任意コード実行 (Issue #108)**:
  SDD_SUDO トークンのフィールド(issuer / nonce / repo / issued-epoch /
  expires-epoch / sig / 署名鍵)を未クオートの `python3 - <<PYEOF` ヒアドキュメントへ
  直接展開していたため、`"""` を含むフィールドで HMAC 比較の前に任意の Python が
  実行できた。クオート済みヒアドキュメント(`<<'PYEOF'`)＋ `os.environ` 経由の
  受け渡しに変更し、データとコードを分離。実 HMAC 正常系・改竄検知・敵対的
  フィールド無害化(コード実行なし)の回帰テストを追加し、これまで CI 未接続だった
  `tests/prepare-panelist.tests.sh` を run-all.sh と CI の Bash/PowerShell ステップに接続。
  .ps1 ツインは .NET HMAC を直接使用しており本脆弱性の影響なし。

### 修正

- **impl-review が round > 1 で構造的に不通過だった問題 (Issue #143)**:
  impl-review-precheck は round > 1 で impl-reviewer-a のマニフェストに前ラウンドの
  `integrated-summary.json` を要求するが、validate-review-context-set は同ファイルを
  reviewer-b にのみ許可していたため、reviewer-a の必須入力が role-unlisted として
  拒否され impl-review が round 1 以降に進めなかった。両ツイン(.sh/.ps1)で
  impl-reviewer-a にも許可(precheck 契約が前ラウンドに固定するため多層防御は維持)。
  review-agent-isolation に回帰テストを追加。
- **check-task-state.ps1 のタスク ID 部分一致 (Issue #111)**: `Select-String` の
  部分一致で `T-001` が `T-0010` のレポートにも一致していたのを単語境界一致に修正
  (`.sh` ツインは `grep -rlw` で既に正しかった)。
- **レビュー前チェックの jq 欠如時フェイルファスト (Issue #120)**:
  impl / task-review-precheck.sh に `command -v jq` の存在確認を追加し、パイプライン
  途中の不明瞭な失敗ではなく明確なエラーで停止(spec-review-precheck.sh /
  review-contract-validate.sh には既存)。
- **check-placeholders の grep 実エラー握り潰し (Issue #127)**: grep の終了コードを
  区別し(0=一致 / 1=不一致 / >=2=致命的エラー)、品質ゲートでのフェイルオープンを
  解消。.sh / .ps1 双方を fail-closed に統一。

### ドキュメント

- **プラグイン数・スキル数の陳腐化修正 (Issue #115)**: skill-reference.md を
  「7 プラグイン / 26 スキル」に更新(sdd-domain を反映)、sdd-domain-plugin-design.md の
  「スキル数 21→27」を「21→26」に訂正。

## v1.10.0 (2026-07-09)

### evidence deep-verify — 6番目の read-only evidence ツール(Issue #68 / Phase 5)

- `sdd-forge-mcp` に `evidence_deep_verify` を追加(PR #106): evidence bundle の
  深層再検証を MCP 経由で提供します。per-artifact SHA-256 再計算と 6 値ステータス
  分類(match / mismatch / missing / too-large / path-denied /
  invalid-recorded-sha、全読取 path-guard 経由・throw なし)、正準 artifacts
  ダイジェストと spec_revision の host スクリプト逐語一致(ADR-0009)、
  git_commit の 40-hex 形状検証(git 不起動、ancestry は host-deferred、
  ADR-0008)、contract/report クロスバインド検証、署名の echo-only 境界
  (`verified: false` 固定・署名鍵非読取)。契約 v1 に evidenceDeepVerifyData を
  加算(後方互換)。host スクリプトとの判定一致ゴールデン(4 fixture 双方向)と
  決定論・スモーク検証付き。全 8 タスクが独立 evaluator / light gate を
  first-pass 8/8 で通過。

### 修正

- `emit-run-record` の gate_reports / review_tickets 集計を対象 feature に
  スコープ(PR #103): タスク ID(T-NNN)は feature ごとに再利用されるため、
  素の `Task: T-NNN` 一致では全 feature の実行が合算されていた。レポート自身の
  `Feature:` 行 / チケットの `feature:` 行での絞り込みに変更し、feature slug の
  正規表現エスケープと CRLF 耐性(severity 行)も追加。sh/ps1 パリティ回帰
  テスト同梱。
- DS-010 契約テストの ordered-checks 終端を DOMAIN-CONFORMANCE 追加後の実装に
  整合(PR #100)。

### 追加

- スタンドアロン `adversarial-review` スキル(PR #102、plugins/ 外・可視性契約
  非干渉): 2 レビュアーのブラインド並列レビュー → 相互批評 → 統合 →
  fresh-context 修正検証のプロトコル。

### ワークフロー改善(WFI-006 / WFI-007)

- WFI-006(Issue #104): 実装レポートの散文陳腐化(4機能連続の friction)への
  対応 — 実装レポートテンプレートに Snapshot Notice 欄を追加し、quality-gate
  に「散文とゲート実測の乖離はゲートレポートに現時点値を記録する(凍結レポート
  本文は改変しない)」手順を追記。
- WFI-007(Issue #105): プラグイン文書 7 箇所の実装レポートパス記載を正準形式
  `reports/implementation/<feature>/<task-id>.md` に統一(evaluator 起動境界の
  要求パターンとの乖離解消。lite トラックは grep ベース探索のため対象外と判定)。

### WFI-004 プラグイン側フォローアップ(Issue #86)

- task-review-precheck に `--provenance-rereview` / `-ProvenanceRereview`
  モードを追加: 実装後の provenance 再レビュー(新 attempt でのエビデンス
  再バインド)時に、事前の persisted task-review PASS 実績を必須とした上で
  canonical workflow-state 検証の失敗のみを許容する(他の precheck 検証は
  従来どおり)。従来は「エビデンスが陳腐化しているから再レビューが必要」な
  状況で precheck 自体が構造的に通過不能だった。
- ADR-0007 を追加: controlled re-binding は「provenance 再レビュー(新
  attempt)」で行い、バリデータ(check-workflow-state)には選択的再バインド
  機構を追加しない決定を記録。
- task レビュアーロールファイル(task-reviewer-a/b)と task-review-loop
  SKILL.md の修正パッチを
  `docs/workflow-improvements/issue-86-protected-gate-files.patch` として同梱
  (enforcement-chain 保護ファイルのためエージェントは直接編集不可 —
  人間が `git apply` で適用する): バリデータ正準の出力スキーマへの整合
  (stage/role 文字列、manifest フィールド、checks[].status vs result、
  findings 配列)、INITIAL-STATE への実装後 provenance 再レビュー条項
  (lifecycle validity 評価)、full プロファイルのレイヤーマニフェスト要件の
  明記、OBSERVABLE-DONE への凍結アーティファクト誘導ガイダンス、SKILL.md への
  「Post-Implementation Provenance Re-Review」手順の新設。

### コンテキスト最適化（トークン削減）

- `investigate-codebase` が `specs/<feature>/codemap.md`（トークン節約型の
  アーキテクチャマップ）を常時生成するようになりました。新テンプレート
  `templates/codemap.template.md` を追加。`sdd-bootstrap-interviewer` と
  `implement-task` は codemap が存在する場合それを先に読み、リポジトリの
  再探索を codemap がカバーしない範囲に限定します（下流エージェントの
  重複探索によるトークン消費を削減）。
- `bootstrap` / `ship` オーケストレータにコンテキスト圧縮（compaction）
  ガイダンスを追加。全状態がディスクに永続化されるフェーズ境界・タスク
  境界でのみ圧縮を行い、インタビュー中・タスク実装中・品質ゲート実行中の
  圧縮を避けます。

## v1.9.0 (2026-07-06)

### DDD アップストリームレーン（sdd-domain、7番目のプラグイン）

- 新プラグイン `sdd-domain` を追加（`sdd-bootstrap` / `sdd-implementation` /
  `sdd-quality-loop` / `sdd-lite` / `sdd-review-loop` / `sdd-ship` に続く
  7番目）。Phase 1 のさらに前段で、公開スキル `/sdd-domain:domain-model`
  （`new` / `update` / `reverse` の3モード）が七段階インタビュー
  （Domain Story → Event Storming → Ubiquitous Language → Context Map →
  Domain Model (aggregates) → Domain Message Flow → C4 Container）を実施し、
  人間承認済みの `domain/` 配下のドメインモデルと `domain-contract.json` を
  生成します。可視性契約は公開スキル5→6（新規は `domain-model` のみ）で
  維持され、内部スキル `domain-interviewer` / `domain-reverse` /
  `domain-review-loop` / `domain-sync` はすべて `user-invocable: false`
  です。
- **独立レビュー**: `domain-review-loop` が `domain-reviewer-a`（戦略:
  コンテキスト境界・関係パターン・イベント網羅性・用語の一意性）と
  `domain-reviewer-b`（戦術: 不変条件の検証可能性・トランザクション境界の
  現実性・god-aggregate/anemic-model リスク）による最大3ラウンドの独立
  レビューを実施し、承認後は cross-model-verify のスクリプトを人間権限
  （`SDD_SUDO`）下で直接呼び出してクロスモデル検証まで行います。承認後の
  `domain/` ドリフトはレビュー前提条件チェックが検知し、人間によるステータス
  リセットを要求します。
- **下流同期**: 承認済みモデルが存在する場合、`domain-sync` が
  `sdd-bootstrap-interviewer` の Phase 1 出力に正準コンテキストと用語を注入
  し（`requirements.md` に `Bounded-Context:` フィールドを追加）、
  `spec-reviewer-a/b` / `impl-reviewer-a/b` に DOMAIN-CONFORMANCE 観点を追加
  します。決定論ゲート `check-domain-conformance.(sh|ps1)` は
  `requirements.md`/`design.md` を `domain-contract.json` と照合し、未知の
  用語・未宣言の `Bounded-Context:`・未登録の集約参照を warn で報告します
  （`SDD_DOMAIN_ENFORCE=error` で昇格）。`workflow-retrospective` はこれらの
  warn 所見から用語逸脱数・境界違反数を集計します。
- **絶対的な不可侵**: `domain/` が存在しないプロジェクトでは全フック・
  同期・ゲートがスキップされ、1行のスキップ記録のみを残して既存ワークフロー
  はバイト同一の成果物を生成します（AC-010）。
- `tests/validate-repository.ps1` の期待値を更新（プラグイン数 6→7、
  スキル数 21→26、公開スキル5→6）。

### local-env-mcp — ローカル環境情報 MCP サーバー(新規)

- 読み取り専用の環境情報 MCP サーバー `mcp/local-env-mcp` を新設
  (`get_os_info` / `get_toolchain_versions` / `list_available_clis` の3ツール)。
  実行機能なしの設計: execFile 限定(shell なし)・コンパイル時固定 14 CLI
  allowlist・2秒タイムアウト・8KiB 出力上限・並列上限4・TTL 60秒キャッシュ・
  秘匿情報 redaction(canary 検査で非漏えいを実証)。契約は
  `contracts/local-env-mcp-tools.v1.schema.json`。esbuild 単一バンドルを
  dist コミットし、CI に 3 OS マトリクス + dist-parity ジョブを追加。
- installer 統合: `install.sh` / `install.ps1` が local-env-mcp を
  デフォルト同梱(`--mcp <list>` 選択・`--skip-mcp`・Node >= 20 ゲート)。
  Cursor(`~/.cursor/mcp.json` の `mcpServers`)/ VS Code(ユーザー
  プロファイル `mcp.json` の `servers`、OS 別パス)への自動登録
  (idempotent upsert・破損 JSON フェイルセーフ・`SDD_CURSOR_DIR` /
  `SDD_VSCODE_USER_DIR` オーバーライド)。`uninstall.sh` / `uninstall.ps1`
  は installer 管理エントリのみ削除し、ユーザーエントリを保全。
- ドキュメント: README / USERGUIDE に概要・3ツール・セキュリティ境界
  (実行機能なし)・Cursor / VS Code の自動/手動登録手順を追加。
- 全 10 タスクが full プロファイルの品質ゲート(独立 evaluator +
  evidence bundle)を PASS。TDD red/green 証跡・identity ledger 連鎖・
  requirement traceability(12 links)を完備。

### ワークフロー機構の修正と自己改善(WFI)

- AGENTS.md に「Post-review artifact freeze」「Post-implementation
  provenance re-review」の2規則を追加(WFI-004、人間承認済み)。実装後の
  full プロファイル `check-workflow-state` が恒常的に green 化
  (exit 1 → 0)。レビューゲートのプラグイン側ロール定義との不一致は
  https://github.com/aharada54914/sdd-forge/issues/86 で追跡。
- sdd-quality-loop / sdd-review-loop のゲート修正(issue #62 / #71 対応):
  保護対象ゲートファイルを標的とする書込のみ拒否、impl-review manifest の
  bounded superset 許容、任意チェックアウトからの spec 契約受理、weekly
  self-improvement の fail-fast 化(#74)。
- WFI-001(高リスクタスク preflight)・WFI-002(手動 precheck 逸脱記録)・
  WFI-003(レポート識別フィールド)・WFI-004 の4件が retrospective で
  Verified となり、retention-checklist に再発検知条件を登録。

## v1.8.0 (2026-07-03)


### デザイン駆動高速イテレーションレーン

- 内部スキル `design-sync-loop`（sdd-bootstrap）を新設。仕様段階で
  claude.ai/design（DesignSync ツール）からデザインシステムを参照し、
  使い捨て HTML モックアップを生成、都度人間承認のうえ Push して
  ブラウザ確認ループを回す。ツールがない環境では従来の手動手順
  （claude-design-workflow.md）にフォールバック。
- 内部スキル `visual-verify-loop`（sdd-implementation）を新設。UI タスクの
  実装後に Claude Preview MCP（Web）/ wpf-visual-verify（WPF）で
  「起動→スクリーンショット→デザイン照合→修正」を最大5回イテレーションし、
  最終スクリーンショットを `reports/visual-evidence/<task-id>/` に証跡保存。
  非ブロッキングで、合否判定は quality-gate と人間レビューのまま。
- sdd-bootstrap-interviewer / lite-spec / implement-task に上記への
  ルーティングを追加。公開スキルは5つのまま（可視性契約は不変）。

### 統一デザインシステム統合（design-system 契約）

- プロジェクトレベルの `design-system/` 契約を新設: W3C DTCG 準拠の
  design-tokens.json（`contracts/design-system.contract.v1.schema.json` で
  メタ検証）、design-system.md（3層構造・WCAG 2.2 AA）、ui-patterns.md
  （言語非依存の普遍的 UX 規約6カテゴリ）。テンプレート3点を同梱し、
  PLUGIN-CONTRACTS.md に producer/consumer 契約を定義。
- interviewer に `ds_profile`（custom / none）選択を追加。custom では
  design-sync-loop v2 が design-system/ を保証（ui-ux-pro-max シード生成・
  Figma DTCG エクスポート取込・D6 テンプレートインタビューの3経路）し、
  トークン駆動モックアップを生成。investigate-codebase に brownfield 用
  Design Inventory を追加。
- レビュー統合: impl-reviewer-a に DESIGN-SYSTEM-CONFORMANCE 検査を追加
  （impl-review-loop は20チェック化）、impl-reviewer-b の DESIGN-WITHIN-SCOPE
  に規約外 UI ライブラリ検出を追加。
- 実装強制: implementation-policy に UI 実装規則（トークン参照のみ・
  再利用優先・a11y 要点・lint 未整備のタスク化）、implement-task の
  条件付き必須読み物、visual-verify-loop の照合基準に design-system を追加。
- 検証ゲート: design-system-checklist.md 新設、accessibility-checklist を
  WCAG 2.2 AA に更新、決定論ゲート `check-design-system.(sh|ps1)` を warn
  モードで導入（`SDD_DESIGN_SYSTEM_ENFORCE=error` で昇格、導入2リリース後に
  error 化予定）。verification-contract に `design-system` チェック、
  risk-gate-matrix に条件付きコントロール行を追加。
- 全変更は条件付きロード / waivable check として実装し、非 UI プロジェクト・
  `ds_profile: none` へのオーバーヘッドはゼロ。

## v1.7.0 (2026-07-02)

### スラッシュメニューの2コマンド化とエントリコマンドのリネーム

- **破壊的変更**: エントリスキルをリネーム。`/sdd-bootstrap:run` → `/sdd-bootstrap:bootstrap`、
  `/sdd-ship:run` → `/sdd-ship:ship`。両スキルが `name: run` を共有していたため、
  ホスト UI（Claude Code / Codex）で選択後の表示がどちらも `run` になり
  区別できなかった問題を解消。
- 内部オーケストレーション用の14スキルに `user-invocable: false` を追加し、
  スラッシュコマンドメニューから非表示化。ユーザーに見えるコマンドは
  `bootstrap` / `ship` / `sdd-sudo` / `fix-by-review-ticket` / `diagnose` の5つのみ。
  `disable-model-invocation: true` は全スキルで維持（モデルの自動起動禁止は不変）。
  再開機能は影響なし（エントリコマンドがタスク状態から再開点を自動検出する）。
- `tests/validate-repository.ps1` にスキル可視性契約の検証を追加
  （公開5スキル以外は `user-invocable: false` 必須）。

### 自己改善フロー（WFI）の効果測定基盤

（提案の全文: `docs/contributor/self-improvement-measurement-proposal.md`）

- **ランレコード（Phase A）**: `emit-run-record.sh` / `.ps1` を新設。retrospective 実行時に
  `reports/runs/RUN-<timestamp>-<feature>.json` を決定論的に生成し、モデルID・
  プラグインバージョン・適用中 WFI 一覧・カウントベース指標を記録する。
  以後の WFI 効果の帰属分析はこのレコードを一次ソースとする。
- **WFI 検証の拘束力強化（Phase B）**: WFI テンプレートに `Target-Metric` /
  `Expected-Direction` / `Horizon` / `Rollback-Plan` と2軸分類
  （`Category`（スコープ軸: 既存2 + `human-process` / `measurement`）、
  `Mechanism`（instructions / memory / tools / architecture / model-routing）、
  `Meta-Change` フラグ）を追加。retrospective は Applied WFI の Horizon を毎回
  機械チェックし、期限内未達なら Rejected + ロールバック提案を出す。
  測定系（grader・閾値・retrospective ロジック）を触る WFI は Meta-Change
  厳格監査レーンへ（wfi-auditor-b に anti-Goodhart チェックを追加）。
- **Retention チェック（Phase C）**: `docs/workflow-improvements/retention-checklist.md`
  を新設し、Verified 済み WFI が直した失敗モードの再発を retrospective が毎回検知。
  再発時は WFI を新状態 `Regressed` に落とし、再起票を提案する。
- **golden タスクの足場（Phase D、スキャフォールド）**: `tests/golden/` に fixture
  形式と pairwise 検証手順の README を追加（fixture 本体は実失敗事例から今後蓄積）。
- `scripts/bump-version.sh` を新設し、リリース面（マニフェスト18 + marketplace 2 +
  README + バリデータ + リリーステスト）のバージョン同期を1コマンド化。

## v1.6.0 (2026-07-02)

### バグ修正トラックと P0 ハードニング

- `diagnose` スキルを新設。ハードなバグ・リグレッション・フレーキーテスト・性能退行に対し、
  再現→計装→根本原因→最小修正の5フェーズ診断規律（HITLループ）を回し、
  `reports/diagnosis/<id>.md` として出力する。フル SDD の3レビューループを通す前段として、
  軽量トラック（lite-spec → 単一承認 → implement-task → lite-gate）への入口を兼ねる。
  `task-reviewer-b` の `BUGFIX-DIAGNOSTIC-PATH` チェックが要求する証跡を供給する。
  `docs/workflow-guide.md` に「バグ修正トラック（diagnose）」節を追加。
- `wfi-audit-cycle` の監査ループに試行上限を設け、変化なし（NO-CHANGE）が続く場合は
  自動的に停止するよう修正し、監査サイクルの無限ループ化を防止。
- `sdd-ship` の品質ゲートに、ディスクベースの試行回数上限を導入し、修正・再検証サイクルが
  際限なく繰り返されることを防止。
- `implement-tasks` を独立タスクの並列ディスパッチに対応させ、依存関係のないタスク群を
  同時実装できるよう変更。
- workflow-state: 1.5.0 リリースコミットで provenance が乖離した3 feature
  （`agent-cost-context-isolation`、`bootstrap-interviewer-enhancement`、
  `workflow-state-integrity`）を、機能は維持したまま bounded legacy プロファイルへ移行。
- CI: provenance テストのため full history fetch (`fetch-depth: 0`) を追加し、
  installer テストの一時ディレクトリ cleanup を best-effort 化してテストの flake を修正。
- 全リリース面（プラグインマニフェスト、marketplace、README、リポジトリ検証スクリプト）を
  1.6.0 に同期。

## v1.5.0 (2026-06-30)

### Agent cost and context iteration metrics

- workflow-retrospective now records task attempts, review rounds,
  quality-gate runs, and model escalations so iteration cost can be measured
  independently from token price.
- All Claude, Codex, and Copilot plugin manifests, marketplaces, README, and
  repository release surfaces identify release `1.5.0`.
- Added a rollback contract for restoring the release surfaces to the pinned
  `1.4.0` baseline after hash validation.

## v1.4.0 (2026-06-29)

### Bootstrap interviewer のレイヤー仕様対応

- FULL プロファイルで UX、frontend、infrastructure、security の4レイヤー
  artifact を生成し、`design.md` と `traceability.md` から正規アンカーで索引化。
- 選択した feature directory だけを対象に、不足 artifact や空テンプレートを
  Bash / PowerShell で fail-closed 検証する構造チェックを追加。
- implementation review と task review の入力を、core spec、design、
  traceability、4レイヤー仕様の hash に拘束し、差し替えや profile downgrade
  による回避を拒否。
- Draft から Approved への人手または有効な署名付き sudo の承認境界と、
  既存 LITE / legacy profile の互換性を維持。

## v1.3.0 (2026-06-29)

### ワークフロー状態の整合性強化

- リポジトリ全体の SDD 状態を fail-closed で検証する Bash / PowerShell
  チェッカーを追加し、CI、品質ゲート、仕様・実装・タスクの各レビュー前処理へ統合。
- pre-v1.3.0 の履歴だけを対象に、固定 cutoff、理由、所有者、許容欠落項目を
  明示した bounded legacy migration を導入。
- predecessor review の遷移判定を修正し、レポートパス衝突時も feature と
  evidence bundle に結び付いた品質レポートだけを採用。
- 既存の公開コマンド、インストール／アンインストール動作、プラグイン構成は維持。

## v1.2.0 (2026-06-25)

### 修正: エントリーポイントコマンドがスラッシュメニューに表示されない問題

`sdd-bootstrap` / `sdd-ship` プラグインのエントリースキル名がプラグイン名と一致していたため、Claude Code のプラグインスキル名前空間と衝突し（[claude-code#22063](https://github.com/anthropics/claude-code/issues/22063)）、`/sdd-bootstrap` と `/sdd-ship` が `/` メニューに表示されず、フル入力しても `Unknown command` となっていた。

- エントリースキルの `name` をそれぞれ `run` にリネーム（スキルフォルダも `skills/run/` へ移動）。
- ユーザー向けコマンドは **`/sdd-bootstrap:run`** と **`/sdd-ship:run`** になった（プラグイン名前空間が衝突しなくなり、メニューに表示され実行可能）。
- 内部ヘルパー（`/sdd-bootstrap:sdd-adopt` など）、プラグイン名、`marketplace.json` の `source` パスは変更なし。
- 全ドキュメント・Codex `defaultPrompt`・テストの参照を新コマンド名に更新。

## v1.0.0 (2026-06-21)

### バージョニング方針の変更

v0.15.x から v1.0.0 へのメジャーバンプ。全プラグインのバージョンを `1.0.0` に統一。

`/sdd-bootstrap` + `/sdd-ship` の2コマンドワークフローが確立し、ユーザー向けの公開インターフェースが安定したため、メジャーバージョン 1 に昇格する。

### v0.14.x からの移行

- **移行注意**: `impl-review-loop` と `task-review-loop` は `sdd-review-loop` に移設されたため、旧 namespace（`/sdd-impl-review:*`、`/sdd-task-review:*`）は使用できない。その他の旧スキル（`implement-task`、`quality-gate` 等）は引き続き動作する。
- ユーザーが直接使うコマンドは `/sdd-bootstrap` と `/sdd-ship` の2つ。内部スキルは `sdd-ship` 経由で自動実行される。
- `v0.14.0` タグが旧パラダイム（15スキル時代）の最終状態として参照可能。

---

## v0.15.1 (2026-06-21)

### 変更

- **`sdd-review-loop` プラグイン新設（内部リファクタリング）**: `sdd-impl-review` と `sdd-task-review` の2プラグインを `plugins/sdd-review-loop/` に統合。`impl-review-loop` と `task-review-loop` の各スキル・エージェント・スクリプト・テンプレートを移植し、`plugins/sdd-bootstrap/skills/sdd-bootstrap/SKILL.md` および `sdd-bootstrap-interviewer/SKILL.md` の呼び出しパスを更新。旧プラグインディレクトリは完全削除（`$forbiddenPaths` で再作成を防止）。
- **フックガード強化（Python Check 2e）**: `sdd-hook-guard.py` に `impl_review_status_passed_increases` チェック（Check 2e）を追加。JS の `implReviewStatusPassedIncreases` との動作パリティを確立。`PROTECTED_GATE_SUFFIXES` に `sdd-review-loop` の6パスを追加。
- **内部 SKILL.md に Caller ヘッダー追加**: `implement-task`、`implement-tasks`、`quality-gate` の3スキルの frontmatter 直後に「このスキルは sdd-ship から呼ばれる」旨の caller-context ヘッダーを追加。直接呼び出し抑止のためのドキュメント整備。
- **ドキュメント再構成**: `docs/skill-reference.md`（1374→576行）と `docs/workflow-guide.md`（998→297行）をスリム化し、内部詳細を `docs/contributor/` 配下に分離。`wfi-category-guide.md` の forbidden terms に `sdd-review-loop` を追加。
- **テストスイート強化**: `tests/guard-parity.tests.sh` に Scenarios 19/20/21（impl-review-status ガードのパリティ検証）を追加。`tests/validate-repository.ps1` の `$expectedSkills` を 15→17 件に修正（sdd-bootstrap と sdd-ship の既存バグ修正）および `$forbiddenPaths` に旧プラグインパスを追加。

### v0.15.0 からの移行

- 破壊的変更なし。`impl-review-loop` と `task-review-loop` はプラグインが変わるだけで機能は同一。
- 既存レポートパス（`reports/impl-review/`、`reports/task-review/`）は変更なし。
- 旧パス（`/sdd-impl-review:impl-review-loop`、`/sdd-task-review:task-review-loop`）は削除済み。新パス `/sdd-review-loop:impl-review-loop` / `/sdd-review-loop:task-review-loop` を使用。

## v0.15.0 (2026-06-20)

### 追加

- **`sdd-ship` プラグイン（実装・品質保証フェーズのオーケストレーター）**: 新しいトップレベル公開コマンド。承認済みタスクを `implement-tasks` → `quality-gate`（または `lite-gate`）→ `workflow-retrospective` の順に処理し、全タスクを Done に導く薄いオーケストレーター。
  - **2コマンドワークフロー確立**: ユーザーが直接呼び出すのは `/sdd-bootstrap` と `/sdd-ship` の2つのみ。内部スキル（`implement-task`、`quality-gate` 等）は引き続き動作し、後方互換性を完全に維持。
  - **自動トラック検出**: `--full` → `--lite` → `spec_profile: lite`（AGENTS.md）→ デフォルト FULL の優先順でトラックを自動検出。`[sdd-ship] Track: ...` メッセージを常に先頭に出力。
  - **ゼロ引数起動**: 引数なしで実行すると AGENTS.md の `## Active Spec Directories` を走査し、承認済みタスクが1フィーチャーのみなら自動選択。
  - **`--verify` フラグ**: `Cross-Model: enabled` を持つタスクのみ `cross-model-verify` を実行。対象タスクがない場合は警告を出力して通常ゲートへ。lite トラックでは無視。
  - **`--retro` フラグ**: 全タスク Done 後に `workflow-retrospective` を強制実行。
  - **サイクル上限**: 同一タスクで `quality-gate` を3回実行しても Done に到達しない場合は人間調査を促して停止。
  - **セキュリティ境界**: `sdd-sudo` の呼び出し禁止、`Approval: Approved` の自己設定禁止、フックファイルの変更禁止。
  - ファイル: `plugins/sdd-ship/skills/sdd-ship/SKILL.md`、`plugins/sdd-ship/.claude-plugin/plugin.json`、`plugins/sdd-ship/.codex-plugin/plugin.json`、`plugins/sdd-ship/.plugin/plugin.json`

- **`sdd-bootstrap` トップレベルルーター**: `plugins/sdd-bootstrap/skills/sdd-bootstrap/SKILL.md` を新規作成し、全モード（feature/bugfix/refactor/project/adopt/investigate）のルーティングと `--lite`/`--feature`/`--reset` フラグを一元管理するエントリーポイントを追加。ハンドオフは常に `/sdd-ship` を次ステップとして案内。

### 変更

- **`install.sh` / `install.ps1` デフォルト変更**: デフォルトプラグインセットを `sdd-bootstrap,sdd-ship` に変更。`sdd-ship` を選択すると全依存プラグインが自動展開される。`VALID_PLUGINS` に `sdd-ship` を追加。`REQUIRED_PATHS` に sdd-ship の3ファイルを追加。
- **marketplace 更新**: `.claude-plugin/marketplace.json` と `.agents/plugins/marketplace.json` に `sdd-ship` エントリを追加。`sdd-implementation` と `sdd-lite` の description に `[internal]` プレフィックスを付与（UX 整理; 機能削除なし）。
- **フックガード更新**: `sdd-hook-guard.js` と `sdd-hook-guard.py` の `PROTECTED_GATE_SUFFIXES` に `plugins/sdd-ship/skills/sdd-ship/SKILL.md` を追加（R-10 保護）。
- **ドキュメント更新**: README.md にクイックスタート（2コマンド）セクションを追加。`docs/workflow-guide.md` に2コマンドクイックリファレンス表を追加。`docs/skill-reference.md` に sdd-ship と sdd-bootstrap のエントリを追加し、スキル数を16に更新。

### v0.14.0 からの移行

- 当時の公開内部スキルは直接呼び出し可能だった。後続リリースの明示的な移行（`sdd-review-loop` への namespace 移設など）はこの保証の対象外。
- 既存の `sdd-bootstrap,sdd-implementation,sdd-quality-loop,sdd-lite` でのインストールは引き続き動作する。新インストールは `sdd-bootstrap,sdd-ship` のみで全依存が自動展開される。
- `spec_profile: lite` を持つ既存プロジェクトは `/sdd-ship` が自動的に lite トラックを検出する。

## v0.14.0 (2026-06-19)

### 追加

- **`impl-review-loop` スキル（実装方針レビューループ）**: `sdd-impl-review` プラグインを新設し、design.md に対して 2 体の独立したブラインドレビュアー（A: 構造健全性、B: 実装可能性/リスク）による最大 3 ラウンドのレビューを実施する。
  - **Phase 1/2 分割**: `sdd-bootstrap-interviewer` を Phase 1（requirements.md + design.md + acceptance-tests.md）と Phase 2（tasks.md + traceability.md）に分割。`impl-review-loop` で `Impl-Review-Status: Passed` が設定されるまで Phase 2 はブロック。
  - **PASS-with-warnings**: ラウンド 3 終了時に Minor 指摘のみ残存の場合は `Passed` として設定し、`## Implementation Warnings` セクションに記録。
  - **BLOCKED + --reset**: ラウンド 3 終了時に Major/Critical 残存の場合は BLOCKED。`--reset` で attempt-M+1 からやり直し。
  - **ブラインドレビュー**: reviewer-b は `disallowedPaths` で reviewer-a.json を読めない。オーケストレーターが `integrated-summary.json`（件数 + ID のみ）を橋渡し。
  - **legacy_design 互換モード**: 新テンプレートフィールド未設定の既存仕様書は `[LEGACY COMPAT]` Minor 通知のみで失敗しない。
  - ファイル: `plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md`、`agents/impl-reviewer-a.md`、`agents/impl-reviewer-b.md`、`scripts/impl-review-precheck.sh`、`templates/impl-review-contract.template.json`

- **`task-review-loop` スキル（タスク分解レビューループ）**: `sdd-task-review` プラグインを新設し、tasks.md に対して 2 体の独立したブラインドレビュアー（A: 構造カバレッジ、B: 品質/リスク）による最大 3 ラウンドのレビューを実施する。
  - **Reviewer-A の 14 チェック**: PREREQ-AC-IDS、BLOCKERS-FORMAT、REQ-COVERAGE、AC-COVERAGE、ORPHAN-TASK、ORPHAN-TEST、INITIAL-STATE、RISK-WORKFLOW-FORMAT、NO-DUPLICATE-AC、DEPENDENCY-COMPLETE（A.10）、DEPENDENCY-CYCLE（A.11）、SINGLE-CONCERN、OBSERVABLE-DONE、TRACEABILITY-SYNC
  - **Reviewer-B の 8 チェック**: RISK-APPROPRIATE、HIGH-CRITICAL-EVIDENCE、TASK-SIZE、EDGE-CASE-COVERAGE、TEST-TYPE-MATCH、ROLLBACK-PLAN、SCOPE-DISJOINT、DEPENDENCY-OVERLAP
  - **DEPENDENCY-COMPLETE → DEPENDENCY-CYCLE 順序保証**: A.10 (DEPENDENCY-COMPLETE) が A.11 (DEPENDENCY-CYCLE) より先に実行されることをスキルで保証。
  - **Blockers 正準形式検証**: `precheck.sh` がカンマ区切り T-NNN 形式を検証し、range 記法（`T-NNN..T-MMM`）を Major で棄却。
  - ファイル: `plugins/sdd-task-review/skills/task-review-loop/SKILL.md`、`agents/task-reviewer-a.md`、`agents/task-reviewer-b.md`、`scripts/task-review-precheck.sh`、`templates/task-review-contract.template.json`

- **`sdd-bootstrap-interviewer` にレビューゲート追加**: Phase 1 → 仕様レビュー → 実装方針レビュー → Phase 2 → タスク分解レビュー → 承認ゲートの5段階フローに変更。
  - LITE プロファイル（`spec_profile: lite`）は全ゲートをスキップ。
  - acceptance-tests.md 不在の場合は LITE-SKIP が自動発動。

### 変更

- **`sdd-hook-guard.js` ガード拡充**: 新規レビュアーエージェントファイル 6 点を R-10 保護リストに追加。`Impl-Review-Status: Passed` を有効な `integrated-verdict.json`（PASS|PASS-with-warnings）なしに書き込む操作をブロック。
- **`workflow-retrospective`**: `reports/task-review/`・`reports/impl-review/` をスキャン対象に追加。新メトリクス: `task_review_rounds_per_feature`、`impl_review_rounds_per_feature`、`impl_review_blocked_rate`、`impl_review_legacy_design_rate`。
- **design.md テンプレート拡張**: `Impl-Review-Status: Pending`・`Feature Type`・`## Components`・`## Architecture Decision Records`・`## Security Boundaries`・`## Constraint Compliance`・`## Open Questions`（Blocks Implementation / Resolution Path 形式）を追加。
- **tasks.md テンプレート拡張**: `Task-Review-Status: Pending` ヘッダー・タスク単位の `Planned Files`・`Data Migration`・`Breaking API` フィールドを追加。
- **requirements.md テンプレート拡張**: `## Security Boundaries` セクションを追加。

### v0.13.0 からの移行

- 破壊的変更なし。既存の design.md / tasks.md に新フィールドが無い場合は `[LEGACY COMPAT]` Minor 通知のみで自動通過。
- `impl-review-loop` と `task-review-loop` は新規フィーチャーからの適用を推奨。既存フィーチャーへの後付け適用も可能（`Impl-Review-Status: Pending` を design.md ヘッダーに追記するだけ）。
- プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.13.0 (2026-06-19)

### セキュリティ強化

- **`sudo_active()` TOCTOU 防止**: `O_NOFOLLOW` + `O_NONBLOCK`（FIFO ブロッキング攻撃対策）+ `fstat`（シンボリックリンク置換競合防止）を py/js 双方に追加。Windows では `O_NOFOLLOW` が存在しない場合に `lstatSync` / `os.lstat` でシンボリックリンクを拒否するフォールバックも追加。
- **パストラバーサル防止**: `_is_protected_gate_file` / `isProtectedGateFile` に `os.path.normpath` / `path.posix.normalize` を適用し、`../` を含むパスによる R-10 保護回避を閉じる。
- **heredoc リダイレクト保護**: `cat > protected_file << EOF` 形式のコマンドが R-10 保護ファイルを上書きできた問題を修正。
- **R-10 保護リスト拡充**: `tests/constant-parity.tests.sh` を py/js の保護対象に追加。
- **プラグイン JSON 相対パス修正**: シェルコマンドスキャンで相対パス形式のプラグイン JSON を正しく検出。

### 修正

- **`validate_path.py` 空白バイパス修正**: 空白のみのパス文字列がチェックを通過していた問題を修正（`strip()` を空チェック前に適用）。
- **`check-contract.py` JSON 型安全**: `checks` が非リストの場合・リスト内に非 dict 要素がある場合を明示的に失敗。`evidence` / `waiver_reason` フィールドに `_str_field()` ヘルパーで型安全な抽出を適用。

### テスト改善

- **`guard-parity.tests.sh`**: `parity_check` に期待 exit code パラメータを追加し、両ランタイムが一致しているだけでなく期待値通りであることも検証。
- **`constant-parity.tests.sh`**: `RISK_TIERS` の検証をティア名の比較から `tier:id` ペア（31 エントリ）の完全比較に強化。
- **`gates.tests.sh`**: R-04 テストを tmpdir コピー方式に変更し、テスト失敗時にスクリプトが消えない安全な実装に修正。

### v0.12.0 からの移行

- 破壊的変更なし。既存の tasks.md / contract / evidence ファイルへの変更不要。
- プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.12.0 (2026-06-18)

### 追加

- **`implement-tasks` スキル（バッチ実装）**: `sdd-implementation` プラグインに新スキルを追加。承認済みタスクを依存関係順に連続実行し、全タスクが `Implementation Complete` になった時点で `quality-gate` を自動起動する。
  - **依存関係フィルタ**: 各タスクの `### Blockers` セクションを解析し、参照先タスク (`T-NNN` パターン) が未完了の場合はスキップして後回しにする
  - **自動 quality-gate 移行**: 全 `Approval: Approved` タスクが `Implementation Complete` になった時点で quality-gate を自動起動する
  - **ループ再開対応**: Blocked 発生時はバッチを停止し、再実行時に最初の選択可能タスクから自動再開する
  - **sudo 対応**: 有効な `SDD_SUDO` があれば per-task 承認チェックを自動通過（Block-and-Stop 決定は sudo でもバイパスしない）
  - ファイル: `plugins/sdd-implementation/skills/implement-tasks/SKILL.md`

### 変更

- **`sdd-implementation` プラグインを v0.12.0 に更新**: description・capabilities・`defaultPrompt` を `implement-tasks` を含む形に更新（`.plugin/plugin.json` / `.claude-plugin/plugin.json` / `.codex-plugin/plugin.json`）
- **`docs/skill-reference.md` 更新**: スキル早見表に `implement-tasks` 行を追加（12スキルに）。既存行の「後段スキル」を `implement-tasks` 対応に更新。`implement-tasks` の詳細セクションを追加
- **`docs/workflow-guide.md` 更新**: §3.1 正常系フローの「実装」行に `implement-tasks` を追記。Mermaid 状態遷移図のラベルを更新。§4.7 セッション再開例に `implement-tasks` を追加

### v0.11.0 からの移行

- 破壊的変更なし。`implement-task` は従来通り動作する。
- 新スキル `implement-tasks` は追加のインストール不要（スキルディレクトリへの配置のみ）。
- 既存の tasks.md / reports / specs ファイルへの変更不要。

## v0.11.0 (2026-06-15)

### 追加

- **sdd-lite プラグイン（軽量・中量トラック）**: 社内・部署内アプリ向けの4ステップフロー（lite-spec → 単一承認 → implement-task → lite-gate → Done）。evidence-bundle / ADR 必須 / cross-model / critical を省略し、既存プラグインとの加算的昇格に対応。
  - スキル: `lite-spec`（軽量仕様生成）、`lite-gate`（軽量品質ゲート）
  - スクリプト: `check-task-state-lite.{sh,ps1}`（Done を evidence-bundle 非依存にした lite 状態ゲート）
  - テンプレート: `requirements-lite.md` / `design-lite.md` / `tasks-lite.md` / `quality-report-lite.md`
  - リファレンス: `lite-flow-policy.md`（lite 規約・昇格手順）

### 変更

- **install / marketplace が4プラグイン構成に**: `install.sh` / `install.ps1` および `.claude-plugin/marketplace.json` / `.agents/plugins/marketplace.json` に `sdd-lite` を追加。既定インストールで `sdd-bootstrap` + `sdd-implementation` + `sdd-quality-loop` + `sdd-lite` の4プラグインが同時導入される。

## v0.10.0

リスク適応ゲート (risk-adaptive-layer, PR #16) と クロスモデル検証 (cross-model-verification, PR #20) を追加したセキュリティ・品質強化リリース。CI グリーン (Windows / macOS / Linux)。

### 新機能・強化

**リスク階層 (`low / medium / high / critical`) とゲートマトリクス**: タスクに `Risk:` + `Risk Rationale:` フィールドを追加。階層が上がるほど必須ゲートセットが拡大し、下位階層の必須セットを完全包含する (非ダウングレード superset 則)。`Risk:` フィールドが無いタスク/contract はレガシーモードで動作し、階層強制を一切行わない (後方互換)。正準対応表: `plugins/sdd-quality-loop/references/risk-gate-matrix.md`。

**新ゲート `check-risk.{sh,ps1}`**: タスクの `Risk:` 階層と `Risk Rationale:` フィールドを検証。`high`/`critical` タスクが `Required Workflow: tdd` を宣言していない場合にフェイルクローズ。

**新ゲート `check-traceability.{sh,ps1}`**: REQ→AC→TEST→証跡のトレーサビリティチェーンを決定論的に検証。`high`/`critical` は require-evidence モードで証跡ファイルの実在も検査。

**リスク対応 `check-contract.{sh,ps1}` 拡張**: Pass 4 でタスク階層の必須チェックセット superset を強制。Pass 5 で `required_workflow: tdd` の Red→Green 証跡 (`red_evidence` / `green_evidence`) を検証。`stack` 記述子 (`code` / `shell` / `docs` / `spec`) に対応し、非コードスタックでは compile 系チェック (`lint` / `typecheck` / `build`) を理由付き (`waiver_reason` 非空) で waive 可能。テスト/トレーサビリティ系チェックは全スタックで必須のまま。

**Evidence bundle プロベナンス** (`generate-evidence-bundle.{sh,ps1}`): `risk`・`required_workflow`・`spec_revision`・`build_env`・`builder`・`review_verdict` フィールドを bundle に出力。`check-evidence-bundle.{sh,ps1}` が `high`/`critical` でこれらフィールドを必須検証。

**HMAC-SHA256 署名 (critical bundle)**: 鍵は外部 (`SDD_EVIDENCE_KEY` 環境変数 / `SDD_EVIDENCE_KEY_FILE` / `~/.sdd/evidence-key`) からのみ解決。`critical` タスクのバンドルは dirty ツリーでの生成をハードフェイル。

**二者承認 (critical タスク)**: `check-task-state` が `Approval:` + 別名義の `Second Approval:` を要求。sudo でもバイパス不可。`sdd-hook-guard` でも同様に強制。

**ガバナンスのコード化**: `.github/rulesets/main.json` (GitHub Rulesets API 形式)、ルート `CODEOWNERS`、`scripts/apply-branch-protection.sh`、`.github/workflows/test.yml` に `merge_group:` トリガーと `required-checks` ジョブを追加。

**新規ドキュメント**: `docs/THREAT-MODEL.md`（脅威モデル）・`docs/agent-capability-matrix.md`（エージェント能力マトリクス）を追加。

**クロスモデル検証 (cross-model-verification, PR #20)**: 単一の独立 evaluator (`sdd-evaluator`) に加え、複数ベンダーの LLM パネリスト (Claude + GPT/Gemini) に同一の検証を**盲目・並列**で投げ、独立 verdict を集約して単一ベンダー盲点を補強する層を追加。

- **新スキル `cross-model-verify`**: 収集層（`prepare-panelist-input` で consent＋サニタイズ → `detect-panel` / `run-panelist-{gpt,gemini}` で盲目並列実行 → verdict JSON 収集）。`disable-model-invocation: true`（ユーザー明示起動）。
- **新ゲート `check-cross-model.{sh,ps1}`**: 決定論的 consensus 判定（多様性: distinct vendor ≥2 かつ 非Anthropic ≥1 / 全 verdict PASS かつ Critical なし / evaluator 乖離 → `requires_human_decision`）。exit 0/1/2。
- **`check-contract` Pass 6**: contract の `cross_model` ディスクリプタ (`required` / `waived` / `legacy`) を検証。`signature`/`two-person approval` と同じ条件付き制御で、機械形 `RISK_TIERS` には非追加（matrix↔encoding パリティと後方互換を維持）。critical=必須(waiver可)/high=opt-in。
- **新パネリストエージェント**: `sdd-panelist-gpt`・`sdd-panelist-gemini`（read-only、`.codex/agents/sdd-panelist-*.toml` ＋ `plugins/sdd-quality-loop/agents/panelist-*.md`）。Claude パネリストは Agent ツール経由。
- **2層分離**: 収集層は外部 API・opt-in・**CI では実行しない**（コストと外部送信防止）。ゲート層のみ CI で fixture 検証。`SDD_EVIDENCE_KEY` 等はパネリストに渡さない。
- **新ポリシー**: `plugins/sdd-quality-loop/references/cross-model-verification-policy.md`。

### v0.9.0 からの移行

- **既存タスク/contract への影響なし**: `Risk:` フィールドが無い contract はレガシーモードで通過。新フィールドの追加は任意 (opt-in)。
- **`stack` 記述子**: 非コードリポジトリで compile 系チェックを waive する場合のみ、contract に `"stack": "docs"` 等を追加。
- **critical タスクを使う場合**: 証拠鍵 (`~/.sdd/evidence-key`) の生成と `Second Approval:` の人間記入が必要。
- 破壊的なファイル配置変更なし。プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.9.0

監査の残課題（C-04 / H-02 / H-04 / C-06 / H-06 / H-05）に対応したセキュリティ強化リリース。

### 新機能・強化

**署名付き sudo capability token (C-04)**: `SDD_SUDO` を偽造耐性のある署名トークン化。`issuer` / `nonce` (≥32 hex) / `repo`（プロジェクトルートの正規絶対パス）束縛 + HMAC-SHA256 署名 (`sig`) を追加。署名鍵はリポジトリ作業ツリーの**外**（`SDD_SUDO_KEY` / `SDD_SUDO_KEY_FILE` / `<HOME>/.sdd/sudo-key`）に置く。`sudo_active()` は py/js/ps1 共通で、非シンボリックリンク・必須フィールド・nonce 形式・`issued<=now<expires`・TTL≤24h・repo 一致・鍵で再計算した HMAC 一致をすべて満たす場合のみ有効化し、いずれか欠落で**フェイルクローズ**（承認ゲート維持＝バイパスは決して起きない）。偽造・コミット済み・他リポジトリからのコピー・リプレイを拒否。残存リスク（鍵を読めるエージェントは署名可）は `sudo-mode-policy.md` に明記。`/sdd-sudo` スキルが鍵生成（0600）と署名を行う。

**evidence の runner 生成・git SHA 束縛 (H-02)**: `generate-evidence-bundle.{sh,ps1}` を新設。証拠の SHA-256・`git_commit`(HEAD)・`git_generated_dirty` を自動算出してバンドルを生成（エージェントによる手書きを排除）。`check-evidence-bundle` は `git_commit` を必須化し、リポジトリ履歴に存在し HEAD の祖先（または HEAD）であることを検証（git 不在・検証不能はフェイルクローズ）。digest 束縛（成果物 SHA-256 一致）と併せ、捏造・古い・他コミット由来の証拠を拒否。

**Actions の SHA pin・release 署名・SBOM (H-04 / C-06)**: `test.yml` / `self-improvement.yml` の全 Action を commit SHA に pin（`# vX.Y.Z` コメント付き）。`.github/dependabot.yml` で pin を定期更新。`release.yml` を新設し、Release publish 時に再現可能ソース tarball・CycloneDX SBOM・`SHA256SUMS`・sigstore ベースの build-provenance attestation（keyless）を生成・添付。SBOM は `.github/scripts/generate-sbom.py`（stdlib のみ）が workflow の pin 済み Action から自動生成。

**installer の排他 lock (H-06)**: 同一インストール先への並行 install による stage→backup→swap 競合を防止。`install.sh` は atomic な `mkdir` lock ディレクトリ（macOS でも動くよう flock 非依存）、`install.ps1` はインストール先のハッシュで識別する名前付き Mutex。タイムアウト（`SDD_INSTALL_LOCK_TIMEOUT`、既定 120s）と stale 回収（`SDD_INSTALL_LOCK_STALE` / 死んだ pid）を備え、全 exit 経路で解放。タイムアウト時は install 先に触れずフェイルクローズ。

**outcome ベースの eval suite (H-05)**: `tests/eval.tests.sh` を新設。実際のゲート群（check-contract / check-placeholders / check-evidence-bundle / check-task-state / sdd-hook-guard）を good/completion-faking の 8 シナリオに対して実行し、Done 可否という**結末**を検証。CI (`test.yml`) に組み込み。

### 修正

- 承認ガードの穴を解消: Write content モードが `## T-NNN` セクション単位でしか比較せず、ヘッダ無しの `Approval: Approved` や新規 tasks.md がすり抜けていた問題を、ファイル全体の承認数の純増でも deny するよう py/js/ps1 で統一（per-task swap 検知は維持）。あわせて sudo テストの `issued-epoch` 欠落と、PowerShell の親ディレクトリ走査がルートで終端できず例外になる不具合を修正。

### WFI 承認の決定論的ガードを追加

- `docs/workflow-improvements/WFI-*.md` への `Status: Approved` のエージェント書き込みをフックガードが拒否（py / js / ps1 全ランタイム）。WFI 承認は **sudo でも解除されません**（タスク承認ガードと異なる点）。
- WFI テンプレートの Status を決定論的に検出可能なインライン `Status: <値>` 形式へ変更。
- `tests/guards.tests.sh` と `tests/hooks.tests.ps1` に WFI ガードのテストを追加。

### sudoモードの適用範囲を明確化（文書のみ・挙動変更なし）

- sudo が自動通過するのは **承認ゲートのみ** であることを明文化：tasks.md のタスク承認、quality-gate の定型サインオフ、`refactor`/`bugfix` の baseline 差分 `accepted` 承認。
- sudo が **通さない判断・統治** を第2の明示例外（brownfield と並ぶ）として明文化：`requires_human_decision: true` チケット、アーキテクチャ/認証/認可/breaking-API/セキュリティ決定、WFI 承認。AGENT_STOP・決定論的ゲートは従来どおり常時有効。
- `workflow-retrospective` と `fix-by-review-ticket` に `Sudo Mode` 節を追加し、quality-gate / implement-task / interviewer の `Sudo Mode` 節を承認と判断を区別する記述に更新。
- `/sdd-sudo` スキルに「How to Turn It On (Quick Start)」を追加し、入り方を明確化。
- 注: v0.7.0 で「アーキテクチャ review 承認も自動通過」と記載していたが、アーキテクチャ決定は承認ではなく判断のため sudo では通さない、と整理（ガードのコード挙動は不変）。

### v0.8.0 からの移行

- **sudo モードは鍵が必要に**: `/sdd-sudo` を再実行して鍵（`<HOME>/.sdd/sudo-key`）を生成し直してください。署名の無い・古い `SDD_SUDO` は無効（フェイルクローズ）として扱われます。CI 等で鍵を共有する場合は `SDD_SUDO_KEY` を設定。
- **evidence bundle は runner 生成必須**: `git_commit` フィールドが必須になりました。`generate-evidence-bundle.{sh,ps1}` で生成してください（手書きの sha256 / git_commit は不可）。
- **GitHub Actions は SHA pin**: タグ更新で自動追従しなくなります。更新は Dependabot（または手動で SHA + コメント更新）で行ってください。
- 破壊的なファイル配置変更はなし。プラグイン再インストール（ワンライナー再実行）で移行完了。
## v0.8.0

### 変更内容

- private repo 前提の remote install に対応。`install.sh` / `install.ps1` は `gh auth token` を使って GitHub API の archive を取得。
- `SourceDirectory` の既存テストを維持しつつ、認証済み remote path の mock テストを追加。
- README / troubleshooting を private 前提に更新。
- フックガードを fail-closed に変更し、agent role の更新・削除・shell 書き込みを拒否。
- `Done` 判定に SHA-256 付き evidence bundle を必須化。

### v0.7.0 からの移行

- `Done` タスクには `specs/<feature>/verification/<task-id>.evidence.json` が必要です。
- evidence bundle は quality report、verification contract、passing evidence の SHA-256 を記録します。
- malformed hook payload、guard runtime 不在、Copilot guard 不在は拒否されます。

## v0.7.0

### 新機能

**sudoモード**: 人間による明示的な `/sdd-sudo` 呼び出しで、人間承認ゲート（tasks.md の `Approval: Approved`、アーキテクチャ review 承認、quality-gate 判定）を期限付きで自動通過。AGENT_STOP kill switch と決定論的スクリプト（contract 検証、placeholder 検出、task-state 検証）は常に有効。audit trail には `(sudo <ISO8601>)` 記号で記録。使用は `/sdd-sudo [duration]`、`/sdd-sudo status`、`/sdd-sudo off`。詳細は `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md` と `sudo-mode-policy.md` を参照。

**リポジトリ改名**: `sdd-plugins-windows-installer` から `sdd-forge` へ改名（自動リダイレクト）。

**週次セルフ改善ワークフロー**: `.github/workflows/self-improvement.yml` を新設。毎週月曜 09:00 JST に `anthropics/claude-code-action@v1` がリポジトリを監査し、Issue 起票と小さな改善 PR の作成までを自動実行する（人間はレビューとマージのみ）。実行指示は `.github/self-improvement-prompt.md` に置き、プロンプト自体も改善対象。認証は `claude setup-token` で発行した `CLAUDE_CODE_OAUTH_TOKEN` シークレット（Pro/Max サブスクリプション枠を消費、API 従量課金なし）。workflow-retrospective (WFI) ループとの競合は調停プロトコル（不可侵領域・台帳照合・WFI provenance・単一飛行・優先順位）で防止 — docs/workflow-guide.md「週次セルフ改善ルーチンとの境界と優先順位」参照。

### v0.6.2 からの移行

| v0.6.2 | v0.7.0 |
|---|---|
| sudoモードなし | **sudoモード追加**: 人間 `/sdd-sudo` 呼び出しで approval gate 自動通過。AGENT_STOP と決定論的ゲートは常に有効 |
| リポジトリ名 `sdd-plugins-windows-installer` | **改名**: `sdd-forge` へ移行（GitHub 自動リダイレクト対応） |
| 改善は人手起点のみ | **週次セルフ改善ワークフロー追加**: GitHub Actions が毎週監査 → Issue → 改善 PR を自動作成（要 `CLAUDE_CODE_OAUTH_TOKEN` シークレット） |

**破壊的変更**: なし。プラグインの再インストール（ワンライナー再実行)のみで移行完了。

## v0.6.2

### 変更内容

Codexエージェントロールファイルの検証・ガード・診断を追加。

## v0.6.1

### 変更内容

ハーネス監査に基づく信頼性修正リリース。機能追加はありません。

**強制レイヤの穴を修正**: Claude Code 用フックの承認ガードに `apply_patch` マッチャーを追加 (Codex 用設定との不一致でバイパス可能だった)。Copilot 用フックが `pwsh` のみの環境でフェイルオープンしていた問題を修正 (`pwsh` 優先 + `powershell.exe` フォールバック)。

**ガード4ランタイム (js/py/sh/ps1) の挙動統一**: `tasks.md` パス判定を全ランタイムで大文字小文字非区別に統一。Python ガードのキルスイッチ判定を stdin 読み込みより前に移動し、TTY ハングを防止。キルスイッチ単体スクリプトが `CLAUDE_PROJECT_DIR` とカレントディレクトリの両方を確認するよう統一。旧世代の `guard-task-approval.{sh,ps1}` (キルスイッチ/apply_patch 非対応) を削除。

**インストーラ修正**: `install.sh` がインストール先に `.codex/.codex/` 等の入れ子ディレクトリを作成するバグを修正。失敗時ロールバックを堅牢化 (Windows のファイルロックでも復元を試行)。エラー伝播を明示化。

**テスト/CI強化**: Linux (ubuntu-latest) を CI マトリクスに追加。`.gitattributes` で EOL を固定。Python ガード・キルスイッチ・MultiEdit ペイロード・インストーラ再実行冪等性・Copilot 登録の直接テストを追加。CI 失敗時のログアーティファクト保存を追加。

## v0.6.0

### 新機能

**brownfield導入サポート (`sdd-adopt`)**: プロジェクト開始後に SDD を採用する「brownfield導入」シナリオ向けスキル。`AGENTS.md` / `CLAUDE.md` / `docs/adr/` / `docs/review-tickets/` / `reports/` をスキャフォールドし、`specs/<feature>/adr/` などの旧配置 ADR を `docs/adr/` へ移行する。ホスト (GitHub / GitLab) に合わせたテンプレートを選択。

**構造プリフライトチェック (`check-sdd-structure`)**: `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` / `.ps1` が必須ファイル・ディレクトリの有無を検査し `missing:` / `advisory:` / `drift:` / `host:` 行で報告。不足時は exit 1。`sdd-bootstrap-interviewer` が feature / bugfix / refactor モード開始時に自動実行し、不足があれば `sdd-adopt` の実行を促して停止する。

**implement-task / quality-gate の明示的前提条件**: `AGENTS.md` が存在しない場合、両スキルがガイダンス付きで停止し `sdd-adopt` の実行を促す。

### v0.5.0 からの移行

| v0.5.0 | v0.6.0 |
|---|---|
| brownfield導入の公式サポートなし | **`sdd-adopt` スキル追加**: `AGENTS.md`/`CLAUDE.md`/`docs/adr/`/`docs/review-tickets/`/`reports/` をスキャフォールド。ホスト (GitHub/GitLab) に合わせたテンプレートを選択。旧配置 ADR (`specs/<feature>/adr/`) を `docs/adr/` へ移行 |
| 構造チェックなし | **`check-sdd-structure.sh` / `.ps1` 追加**: 必須構造の有無を `missing:`/`advisory:`/`drift:`/`host:` 行で報告。不足時は exit 1 |
| interviewer がそのままインタビューを開始 | **プリフライト必須化**: feature / bugfix / refactor モードで `check-sdd-structure` を自動実行。不足があれば `sdd-adopt` を促して停止 |
| implement-task / quality-gate は AGENTS.md 不在でも継続 | **明示的前提条件**: `AGENTS.md` 不在時にガイダンス付きで停止し `sdd-adopt` を促す |
| ADR 配置が曖昧 | **ADR 正規配置を `docs/adr/` に統一** |

## v0.5.0

### 新機能

**macOS/Linuxインストーラ追加**: `install.sh` により `curl | bash` ワンライナーで macOS 13+ および Linux へ導入可能。フラグは PowerShell 版と対称 (`--target`, `--plugins`, `--install-root` 等)。

**Claude CodeフックのNode.js exec form化**: `hooks/claude-hooks.json` が `sh` 経由のシェル形式ではなく `node` コマンドの exec form を使用。Git Bash 不要の Windowsネイティブ対応を実現。

**CIをWindows+macOSマトリクスに拡張**: `.github/workflows/test.yml` が `windows-latest` と `macos-latest` の両方でテスト実行。`hooks.tests.ps1` を CI に追加。

**PS 5.1のTLS 1.2強制**: PowerShell 5.1 環境で `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定し、ダウンロード失敗を防止。

**check-task-state.shのmktemp化**: 競合状態を排除するため一時ファイルに `mktemp` を使用。

### v0.4.0 からの移行

| v0.4.0 | v0.5.0 |
|---|---|
| Windowsのみインストーラー (`install.ps1`) | **クロスプラットフォーム対応**: `install.sh` により macOS 13+ / Linux へ `curl \| bash` で導入可能 |
| Claude Codeフックが `sh` 経由のシェル形式 (Git Bash必須) | **Node.js exec form化**: `hooks/claude-hooks.json` が `node` コマンドの exec form を使用。Git Bash 不要 |
| CI は windows-latest のみ | **マトリクスCI**: `windows-latest` と `macos-latest` の両方で実行。`hooks.tests.ps1` を CI に追加 |
| PS 5.1でダウンロード失敗する場合あり | **TLS 1.2強制**: `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定 |
| `check-task-state.sh` が固定パス一時ファイル | **mktemp化**: 競合状態を排除 |

## v0.4.0

### 新機能

**Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント (`sdd-investigator` / `sdd-evaluator`)、`hooks/copilot-hooks.json` (preToolUse、stdout `permissionDecision` フォーマット)。`-Target Copilot` でインストール。

**Codex hooks/agents対応**: `hooks/hooks.json` に `command_windows` フィールドを追加し Windows Codex 環境をサポート。`apply_patch` ペイロードを処理する。`.codex/agents/` TOML エージェントをインストーラーが `~/.codex/agents/` へコピー。

**統一ガード `sdd-hook-guard`**: kill-switch とタスク承認チェックを1スクリプトに統合し、Claude Code / Codex / Copilot の3ランタイムで共通動作。

**check-contract / check-task-state 強化**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化。

**CIテンプレートのフェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーにより未設定のまま CI が通過しない。

### v0.3.0 からの移行

| v0.3.0 | v0.4.0 |
|---|---|
| Claude Code のみ対応 | **Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント、`hooks/copilot-hooks.json` (preToolUse、既知の不具合: サブエージェント内) |
| Codex hookなし / エージェントなし | **Codex hooks/agents対応**: `command_windows` フィールド追加、`apply_patch` ペイロード処理、`.codex/agents/` TOML エージェント、インストーラーが `~/.codex/agents/` へコピー |
| 個別の kill-switch / guard スクリプト | **統一ガード `sdd-hook-guard`**: 3ランタイム共通、kill-switch + タスク承認チェックを統合 |
| check-contract / check-task-state 基本版 | **強化版スクリプト**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化、ベースライン必須セット保護 |
| CIテンプレートがコマンドなしで通過 | **フェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーで未設定のまま通過しない |

## v0.3.0

### 新機能 (参考)

**調査フェーズ (investigate-codebase)**: `sdd-investigator` エージェントが読み取り専用でコードを解析し、`INV-xxx` 知見と `BL-xxx` 基線動作を生成する。

**refactorモード**: `sdd-bootstrap-interviewer` に追加。`baseline-behavior.md` が必須前提となり、受入条件を BL 同値として表現する。

**決定論的検証ゲート**: Default-FAIL 契約 (`verification-contract.json`)、`check-contract` / `check-placeholders` / `check-task-state` スクリプト (.sh / .ps1) により、エージェント自己申告に依存しない機械検証を実施する。

**独立 Evaluator**: `sdd-evaluator` サブエージェント (Claude Code) または新規セッション (Codex) が実装文脈を持たない状態で批判レビューを行う。

**Claude Code フック強制層**: `PreToolUse` フックがキルスイッチ (AGENT_STOP) と自己承認の強制ブロックを行う (現在は `hooks/claude-hooks.json` + `kill-switch.js` / `sdd-hook-guard.js` の Node.js exec form に移行済み)。

**ワークフローレトロスペクティブ**: `workflow-retrospective` スキルがリワーク指標を計測し、WFI (Workflow Improvement) 提案を人間承認ループで適用する。

### v0.2.0 からの移行

| v0.2.0 | v0.3.0 |
|---|---|
| bootstrap は3モード (project/feature/bugfix) | 4モード (+ `refactor`) |
| 調査フェーズなし | `investigate-codebase` (Stage 0) が追加 |
| `quality-gate` はエージェント自己申告を許容 | Default-FAIL 検証契約 + 決定論的スクリプトゲート |
| 独立レビューは任意 | `sdd-evaluator` サブエージェント (または新規セッション) が必須 |
| フックなし | `hooks/hooks.json` が承認ガード / AGENT_STOP を強制 |
| レトロスペクティブなし | `workflow-retrospective` + WFI ループが追加 |
