# クラウド開発と SDD Forge

Azure / AWS 上のシステムを SDD Forge で開発するときの、**現行機能と今後の拡張の境界**を示す入口です。クラウド専用のプラグインや検証機能は、現行の 7 プラグインに含まれていません。この文書群は、導入済みと誤認されないことを最優先にしています。

- [Azure で開発する](azure.md)
- [AWS で開発する](aws.md)

## 現在の状態

| 区分 | 内容 | 根拠 |
|---|---|---|
| **現行でできること** | 仕様化、3 段の独立レビュー、人間の承認、実装、`quality-gate` による Done 判定という共通の SDD フロー。アプリや IaC は、他のコードと同じ実装タスクとして扱えます。 | [workflow-guide.md](../workflow-guide.md) |
| 同上 | コンポーネントの特性とクラウドプロバイダーの識別を分ける方針（ADR-0018）と、その雛形のスキーマ。 | [ADR-0018](../adr/0018-provider-binding-separation.md)、`contracts/provider-bindings.schema.json`（skeleton） |
| 同上 | Lite トラックの昇格理由に `production_cloud_runtime` と `durable_workflow` が登録されています。クラウドの本番や Durable Workflow を扱う案件は Full の対象です。 | `contracts/lite-upgrade-reason-catalog.json`、[決定書 v2](../ai-dlc-foundation-decision-v2.md) |
| **設計済み・未実装** | `artifact` / `promotion` Gate（予約値のみ。実装されているのは `implementation` Gate だけ）。 | [ADR-0017](../adr/0017-gate-stage-model.md) |
| 同上 | Azure / AWS 向けの Provider Adapter、cloud-service Pack、durable-workflow Pack、新規プラグイン `sdd-operability`（新設予定で、実案件が付くまで着手しない方針）。ベンダー公式ツールキットと重なるため、見直し案を [ADR-0046](../adr/0046-vendor-agent-toolkit-coexistence.md) として提案中です（**未決**。受け入れられるまで、この行は ADR-0018 と決定書 v2 のままです）。 | [決定書 v2](../ai-dlc-foundation-decision-v2.md) の Pack 実装順 |
| 同上 | Promotion の語彙と credentials の語彙。cloud-service Pack に実案件が付いた時点で ADR 化する予定で、現時点では確定していません。 | [決定書 v2](../ai-dlc-foundation-decision-v2.md) |
| **併用（外部ツール）** | AWS と Microsoft が公式に提供するコーディングエージェント向けツールキット。製品知識やサービス操作の手段を担います。SDD Forge が同梱・実行・検証するものではありません。[下記](#ベンダー公式ツールキットとの併用)を参照してください。 | [aws.md](aws.md)、[azure.md](azure.md) |
| **参考（sdd-forge 未対応）** | Azure / AWS の各ツール（what-if、cdk diff など）の使い方。[azure.md](azure.md) と [aws.md](aws.md) に公式ドキュメントの出典つきで整理していますが、SDD Forge が自動で実行・検証するものではありません。 | 各ページの出典 |

> 実装完了とクラウドへの本番デプロイ完了は別物です。`quality-gate` が付ける `Done` は、実装時点で検証できる範囲（テスト、ビルド可否、設計との整合など）を意味します。デプロイが完了した、本番で動いている、という意味ではありません。`/sdd-ship:ship` がクラウドへ本番デプロイを実行することもありません。

## 構成: 共通の SDD とクラウド拡張

実線は現行の機能、点線は設計済みで未実装の拡張です。

```mermaid
flowchart TB
    subgraph CORE["現行の SDD 基盤"]
        A["要件・仕様・設計"]
        B["Project Context<br/>コンポーネントの特性"]
        C["実装と implementation Gate<br/>quality-gate が Done 判定"]
        D["Provider Binding<br/>プロバイダー識別（雛形スキーマ）"]
        A --> B --> C
        B --> D
    end
    V["ベンダー公式ツールキット<br/>外部ツール（併用）"]
    subgraph PLAN["設計済み・未実装"]
        E["Azure Adapter"]
        F["AWS Adapter"]
        G["artifact / promotion Gate<br/>予約値のみ"]
        H["デプロイ・運用の証跡"]
        E --> G
        F --> G
        G --> H
    end
    D -.-> E
    D -.-> F
    C -.-> G
    V -->|"製品知識・サービス操作"| C
```

Azure と AWS で別々の開発エンジンを作らず、仕様化・レビュー・変更影響分析・リスク判定は共通のまま使います。クラウド製品に固有の検証だけを、Provider Binding と Adapter の側に分ける方針です（[ADR-0018](../adr/0018-provider-binding-separation.md)）。

## ベンダー公式ツールキットとの併用

AWS と Microsoft は、コーディングエージェント向けの公式ツールキットを提供しています（[AWS](aws.md#ベンダー公式ツールキット)、[Azure](azure.md#ベンダー公式ツールキット)）。クラウド製品の知識、IaC の書き方、サービス操作はこちらの領域で、SDD Forge が重ねて作る対象ではありません。役割は次のように分かれます。

| 関心 | 担当 |
|---|---|
| クラウド製品の知識、IaC の書き方、サービス操作 | ベンダー公式ツールキット（外部ツール） |
| 仕様化、3 段の独立レビュー、人間の承認、独立検証、Done 判定 | SDD Forge |
| クラウド側の実行権限の上限 | クラウド自身の仕組み（AWS は IAM、Azure はロール割り当て） |

### 統制の境界

SDD Forge のフックは、ベンダーのツールキットが行うクラウド API 呼び出しを止めません。`claude-hooks.json` と `hooks.json` の定義から読み取れる範囲では、次のとおりです。

- キルスイッチ（`AGENT_STOP`）は全ツールが対象です。ファイルがある間は、MCP ツールを含むすべてのツール使用を止めます。
- 承認ガードと保護パスガードは、編集系とシェル系のツール（`Edit`、`Write`、`Bash` など）だけが対象です。MCP 経由のクラウド API 呼び出しは対象外です。
- Copilot CLI 向けの定義は全ツールをガードに通しますが、ガードが検査するのは承認欄や保護パスへの書込みです。クラウド API 呼び出しを止める設計ではありません。

これは定義ファイルを読んだ結果です。実機での挙動は検証していません。したがって、エージェントに与えるクラウド側の権限は、クラウド自身の仕組みで絞ってください。たとえば AWS には、エージェントによる操作を人間の操作と区別できる IAM 条件キーがあります（[aws.md](aws.md#ベンダー公式ツールキット)）。Azure では、実行する ID に必要最小限のロールを割り当てます（[azure.md](azure.md) の OIDC の項）。デプロイの承認は人間が行います。

## 証跡・デプロイ・運用確認の流れ

実線は現行の範囲、点線は設計済みで未実装の範囲です。デプロイの実行や承認の手順は、現状は SDD Forge の外にあります。

```mermaid
flowchart LR
    subgraph NOW["現行: implementation Gate"]
        A["実装タスクを完了"] --> B["quality-gate で独立検証"]
        B --> C["Done<br/>実装時点で検証できた範囲"]
    end
    subgraph LATER["設計済み・未実装"]
        D["artifact Gate<br/>成果物の署名・公開などの確認"]
        E["promotion Gate<br/>本番昇格・運用状況の確認"]
        D --> E
    end
    C -.-> D
```

運用面の確認項目（カナリア分析、SLO、公開状態など）は、決定書 v2 では参考仕様に留め、語彙を凍結していません。実案件が付いた時点で ADR にする方針です。

## 関連ドキュメント

- [ADR-0017 Gate Stage Model](../adr/0017-gate-stage-model.md)
- [ADR-0018 Provider Binding Separation](../adr/0018-provider-binding-separation.md)
- [ADR-0046 ベンダー公式ツールキットとの併用（提案中）](../adr/0046-vendor-agent-toolkit-coexistence.md)
- [AI-DLC 拡張計画の決定書 v2](../ai-dlc-foundation-decision-v2.md)
- [Issue #423](https://github.com/aharada54914/sdd-forge/issues/423)（クローズ済みの提案。Foundation の未完了項目を実装済みとは扱いません）
- [ドキュメント案内](../README.md)
