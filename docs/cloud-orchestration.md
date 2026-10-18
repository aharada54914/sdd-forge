# マルチターゲット基盤と Azure / AWS 対応

## 現在利用できる基盤

#423 は検証義務を対象ごとに選択する基盤です。Resolver、Facet Manifest、
保護された Registry と selected-plan の証跡評価を組み合わせます。
selected-plan は実装段階の検証結果であり、クラウド実行の結果ではありません。
IaC/cloud を含むターゲット例のテストは合成フィクスチャで、実クラウドへの
デプロイや監視・正常性確認の証拠にはなりません。

既存の code/shell/docs/spec の必須チェックは残ります。Full トラックでは
requirements、acceptance-tests、design、ux-spec、frontend-spec、infra-spec、
security-spec の7文書を保持し、UI 非該当等は別途理由を記載します。

## #423 の現在の検証方法

リポジトリのルートで実行します。

```bash
python3 -B tests/sdd-domain-multitarget-foundation.tests.py
python3 -B tests/sdd-domain-multitarget-T-003.tests.py
python3 -B tests/sdd-domain-multitarget-T-004.tests.py
```

foundation スイートは、現在の消費箇所インベントリ、元の T-001 の分類検査、
T-002 の契約境界検査を実行します。必須7文書の参照は `Required Outputs` の
節に結び付け、行挿入によるずれを許容しつつ、節や要件の消失・曖昧な重複・
別の節への移動を検出します。POSIX / PowerShell のローカル一括実行と
ネイティブプラットフォーム CI に登録しています。

過去の `consumer-inventory.json` は当時のソース位置を記録した証跡として保存しています。
その歴史的スナップショット用のスクリプトを現在のソースに直接当てた結果を、
最新検証の代わりにしないでください。現在の検証には上記 foundation スイートを使います。
歴史的なタスク状態を変更せずに、今回の検証を新しい証跡へ保存します。

## Azure / AWS 拡張の状態

クラウド実行アダプターは現在、設計・実装作業中です。ここでは未提供のコマンドを
実行可能な機能として案内していません。[要件](../specs/cloud-orchestration/requirements.md)と
[設計](../specs/cloud-orchestration/design.md)で進捗・契約を確認できます。

初期対象は Azure compute/Bicep と AWS CDK/CloudFormation です。
構想では、各デプロイ単位の実行経路と IaC 所有者を1つに限定し、準備時の書き込みと
適用時の書き込みを分けて承認します。既存の Terraform/SAM/azd 等は所有権を検出し、
未対応経路では停止します。自動 import や破壊的なクロスクラウド rollback は行いません。

Azure の what-if は固定された実行計画ではないため、適用直前の再確認が必要です。
AWS は承認した Change Set の ARN・テンプレート・アセットを固定します。
タイムアウト時は元の操作 ID を照会し、無条件で再適用しません。
デプロイ完了後にはネットワーク、権限、監視、ワークロード正常性等を実際に確認する設計です。

## 実クラウド検証の前提

サンドボックスの対象アカウント/サブスクリプション、リージョン、管理範囲、
CI の保護環境と OIDC、許可されたイメージ、正常性検査、バックアップ方針、
予算、証跡の保管場所・保存期間を管理者が設定する必要があります。
開発の承認、JSON の `approved: true`、ローカルの環境変数だけではクラウド操作を承認できません。
クリーンアップも対象と破壊範囲を明示した別の承認対象です。

## リリースの確認

リリースタグは、検証されたコミットを特定するものです。タグの存在、GitHub Release
アセットの公開、実クラウドでの検証完了は、それぞれ別に確認してください。
バージョン更新と CI の条件は[リリース手順](contributor/release-runbook.md)を参照してください。
