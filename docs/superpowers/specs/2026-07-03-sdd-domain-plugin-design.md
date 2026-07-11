# sdd-domain（DDD 上流工程プラグイン）設計書

- 日付: 2026-07-03
- ステータス: 承認済み（ブレインストーミング完了）
- 対象バージョン: v1.9.0 候補
- 次ステップ: `/sdd-bootstrap:bootstrap` によるドッグフーディング（本書は bootstrap Phase 1 インタビューの入力資料）

## 目的

複雑なビジネスロジックを扱う大規模システム向けに、sdd-forge の Phase 1（仕様化）のさらに上流として DDD（ドメイン駆動設計）の戦略的・戦術的設計レーンを追加する。feature 単位の spec 生成に先立ち、ドメインモデル（ユビキタス言語・境界づけられたコンテキスト・集約設計）をプロジェクトレベルの承認済み成果物として確立し、下流の requirements.md / design.md がそれに準拠することを機械的に検証可能にする。

## 背景と現状ギャップ

- bootstrap は feature 単位のインタビューから requirements.md を生成するが、「その feature がどのコンテキストに属し、どの用語で語られるべきか」というドメインモデルの入力が存在しない。上流はユーザーの頭の中だけにある。
- 複数 feature にまたがる開発では、用語の不統一・集約境界の暗黙化・コンテキスト間整合性の欠如が spec ごとに蓄積する。Entity / Value Object / Aggregate の可変性・識別・ライフサイクルの判断が design.md 内で毎回再発明される。
- 先行事例調査（2026-07-03）: marketplace には単発の DDD スキル（Advanced Event Storming、DDD Architect、ruvnet v3-ddd-architecture 等）が存在するが、SDD フレームワークの契約・独立レビュー・トレーサビリティに統合されたものは確認できなかった。cc-sdd（gotalab）の boundary-first discipline が最接近だが明示的 DDD ではない。
- ecc（affaan-m/everything-claude-code）にも DDD 専用の上流スキルは確認できず。参考実装として読む価値はあるが、実行時依存はしない。

## 決定事項（要件）

| 論点 | 決定 |
|---|---|
| 実現方式 | A案: sdd-forge の7番目のプラグイン `plugins/sdd-domain` として追加。review-contract スキーマ・hook guards・validate-repository・WFI 基盤を直接再利用 |
| スコープ | 戦略的設計（event storming / context map / ユビキタス言語）＋戦術的設計（集約設計カード）まで。言語別コード生成テンプレートは非スコープ |
| 位置づけ | オプトインの上流レーン。CRUD 中心・lite トラックの案件では通らない。domain/ が存在しない場合、既存ワークフローは一切変化しない（グレースフルデグラデーション） |
| 公開スキル | `domain-model` の1つのみ追加（公開 5→6）。他は全て `user-invocable: false` + `disable-model-invocation: true` の内部スキル。可視性契約は validate-repository.ps1 の期待リスト更新で維持 |
| フロー方向 | 単方向フロー維持: domain → spec → design → tasks → 実装。下流からの学びは WFI / diagnose 経由でのみ上流に還流 |
| ゲート強度 | check-domain-conformance は warn で導入し、design-system と同じ「2リリース後に error 昇格（人間編集必要）」の運用 |

## アーキテクチャ

```
/sdd-domain:domain-model（新設・公開・オプトイン）
   event-storming-interviewer → context-mapper → aggregate-designer
   → domain-review-loop（reviewer-a/b 2体 × 最大3ラウンド）
   → 人間承認（Domain-Model-Status: Approved、hook guard 保護）
        │
        ▼
/sdd-bootstrap:bootstrap feature …（既存 Phase 1）
   domain/ 存在時に domain-sync が起動:
   ・requirements.md に Bounded-Context: フィールド付与
   ・用語は ubiquitous-language.md 準拠を強制
   ・design.md の集約設計は domain/aggregates/ カードを参照
   → spec/impl/task review-loop に DOMAIN-CONFORMANCE 観点追加
        │
        ▼
/sdd-ship:ship（既存）
   quality-gate に check-domain-conformance（warn）
        │
        ▼
workflow-retrospective（既存）
   ドメインモデルと実装の乖離（domain drift）を WFI として検出
   → diagnose で境界違反発見時は domain-model 更新レーンへ還流
```

## 成果物（`domain/` — design-system/ と同格のプロジェクトレベル資産）

| 成果物 | 内容 |
|---|---|
| `domain/ubiquitous-language.md` | 用語集。コンテキストごとの定義・禁止同義語・英日対訳 |
| `domain/context-map.md` | 境界づけられたコンテキスト一覧と関係パターン（Partnership / Shared Kernel / ACL / OHS / Conformist / Customer-Supplier） |
| `domain/event-storming.md` | ドメインイベント → コマンド → ポリシー → 集約候補の時系列マップ |
| `domain/aggregates/<name>.md` | 集約設計カード。軸: 可変性・識別（ID/値比較）・ライフサイクル・不変条件・トランザクション境界・所属コンテキスト |
| `domain/domain-contract.json` | 機械可読契約（`domain-contract/v1`）。コンテキスト名・集約名・正規用語を下流ゲートが参照。design-system.contract.v1 と同型の meta envelope 方式 |

## コンポーネント

### 新規プラグイン `plugins/sdd-domain`

| スキル | 可視性 | 役割 |
|---|---|---|
| `domain-model` | 公開 | エントリポイント。新規作成/更新モードのルーティング、成果物一式のオーケストレーション |
| `event-storming-interviewer` | 内部 | Brandolini 方式のインタビュー: ドメインイベント抽出 → コマンド → アクター → ポリシー → ホットスポット |
| `context-mapper` | 内部 | イベントクラスタから bounded context 候補を提示し、関係パターンをインタビューで確定 |
| `aggregate-designer` | 内部 | コンテキストごとに集約カードを生成。不変条件・トランザクション境界を確認 |
| `domain-review-loop` | 内部 | sdd-review-loop パターン流用。2体独立レビュー × 最大3ラウンド |
| `domain-sync` | 内部 | bootstrap 実行時に domain/ を Phase 1 成果物へ注入・整合検証 |

### 新規サブエージェント

- `domain-reviewer-a`（戦略的整合性）: コンテキスト境界の妥当性、関係パターンの整合、イベント網羅性、用語の一意性
- `domain-reviewer-b`（戦術的実装可能性・リスク）: 集約の不変条件の検証可能性、トランザクション境界の現実性、巨大集約・貧血モデルのリスク検出

いずれも read-only、fresh context、classified findings 返却（既存 reviewer 契約と同形式）。

### 新規スクリプトゲート

- `check-domain-conformance`: design.md / requirements.md が domain-contract.json の正規用語・コンテキスト割当・集約参照に準拠しているか検証。導入時 warn、`SDD_DOMAIN_ENFORCE=error` で昇格可、2リリース後にデフォルト error 化（人間編集必要）

## 既存ファイルへの変更

| ファイル | 変更内容 |
|---|---|
| sdd-bootstrap-interviewer SKILL.md | Phase 1 冒頭に domain/ 検出 → domain-sync ルーティングを追加（なければ現行動作） |
| spec/impl review-loop の reviewer 指示 | domain/ 存在時のみ DOMAIN-CONFORMANCE 観点を追加 |
| quality-gate SKILL.md / scripted gates | check-domain-conformance を warn で追加 |
| workflow-retrospective SKILL.md | domain drift メトリクス（用語逸脱数・境界違反数）を集計対象に追加 |
| tests/validate-repository.ps1 | プラグイン数 6→7、スキル数 21→26、公開スキル 5→6 の期待値更新 |
| PLUGIN-CONTRACTS.md / README.md / docs/workflow-guide.md | 上流レーンの文書化 |
| contracts/ | `domain-contract.v1.schema.json` 追加 |

## 設計パターンの出典（流用元）

- superpowers: HARD-GATE タグ、チェックリスト方式、dot digraph プロセス定義、reviewer プロンプトテンプレート（placeholder 埋め込み）、モデル選択ガイドライン（cheap/standard/capable）— パターン流用のみ、ランタイム依存なし
- sdd-forge 既存: review-contract v1、2体×3ラウンド独立レビュー、hook guard による承認行保護、warn→error 2リリース昇格ルール、WFI 還流

## エラー処理・異常系

- domain/ なし: 全フック・ゲートはスキップし、判定結果のみ記録（非ブロッキング）
- domain-contract.json 破損/スキーマ不一致: bootstrap は警告を出して domain-sync をスキップ（spec 生成は止めない）
- レビュー3ラウンド不通過: BLOCKED として人間へエスカレーション（既存 review-loop と同じ terminal-tier-blocked-state 形式）
- 承認済みドメインモデルの変更: Domain-Model-Status を Pending に戻し再レビュー必須（hook guard で Approved 行の無断増加を拒否）

## テスト戦略

- validate-repository.ps1 の期待値テスト（プラグイン/スキル数・可視性契約）
- domain-contract.v1.schema.json のスキーマ検証テスト（正常系・破損系）
- check-domain-conformance の fixture テスト（準拠 design.md / 用語逸脱 design.md）
- domain/ 不在時の全ワークフロー無影響確認（回帰）

## 非スコープ（YAGNI）

- 言語別実装テンプレート（Repository / Domain Service のコード生成）
- CQRS / Event Sourcing の実装支援
- 既存コードベースからのドメインモデル逆生成（将来 investigate-codebase 拡張で検討）
- lite トラックへの DDD 統合
