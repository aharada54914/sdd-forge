# IaC の検証計画の書き方

Azure / AWS の IaC（Bicep、CDK、CloudFormation）を SDD Forge で進めるとき、`validate` / `plan` / `what-if` の出力を、タスクの検証計画に**明示的な検査**として書くための雛形です。先に [クラウド開発と SDD Forge](README.md) で現行機能の境界を確認してください。

## なぜ明示するのか

- 検証ポリシーは「コマンドはリポジトリの設定から検出し、作り出さない」と定めています。実行可能な検証コマンドが無いタスクは `Done` にしません（[verification-policy.md](../../plugins/sdd-quality-loop/references/verification-policy.md)）。
- 品質ゲートの能力レジストリには、クラウドや IaC 向けの検査がありません。登録されているのは SDD Forge 自身のプラグイン向けの 2 件だけです。IaC の検査は、プロジェクト側が自分で定義する必要があります。
- SDD Forge はこれらのコマンドを実行せず、出力も解釈しません。実行するのは CI や人間で、SDD Forge が見るのは、タスクに紐づく検査として定義されているかどうかです。

## 検査の種類と、証明できる範囲

| 種類 | Azure | AWS | 証明できること | 証明できないこと |
|---|---|---|---|---|
| 構文・静的 | Bicep のビルドとリンター | `aws cloudformation validate-template` | テンプレートが解釈できる。 | AWS の validate-template は構文のみで、リソースのプロパティ値が正しいかは確認しません（[公式](https://docs.amazonaws.cn/en_us/AWSCloudFormation/latest/UserGuide/using-cfn-validate-template.html)）。 |
| デプロイ前の検証 | `Test-AzResourceGroupDeployment`（テンプレートとパラメーターが有効かを判定。[公式](https://learn.microsoft.com/powershell/module/az.resources/test-azresourcegroupdeployment)） | Change Set の作成と確認 | 入力が受け付けられる。 | 実際のデプロイの成功。 |
| 変更の差分（plan 相当） | `az deployment group what-if`（既存リソースを変更せず、作成・変更・削除を予測。[公式](https://learn.microsoft.com/en-us/Azure/azure-resource-manager/bicep/deploy-what-if)） | `cdk diff`（`--method auto` は、リソースを変更しない Change Set を使用）、または CloudFormation の Change Set | どのリソースが作られ、変わり、消えるか。 | 実行時の挙動、容量やクォータ、Azure Policy などの実行時の結果。 |

出典の確認範囲は [azure.md](azure.md) と [aws.md](aws.md) に書いています。上の表のうち、Azure の Bicep のビルドとリンターの挙動は、この文書の作成時に公式ページで確認できていません。使う前に Microsoft Learn で確認してください。Terraform は、この文書では出典を確認していないため扱いません。

## 検査はオンラインとオフラインに分ける

差分の確認（what-if、`cdk diff`、Change Set）にはクラウドの認証情報が要ります。ローカルや認証情報の無い環境では実行できないため、`Done` の根拠にできる検査と、デプロイ前の承認で使う検査を分けます。

| 区分 | 例 | 認証情報 | 実行する場所 |
|---|---|---|---|
| オフライン | 構文・静的な検査、単体テスト | 不要 | ローカルと CI |
| オンライン（リソースは変更しない） | what-if、`cdk diff`、Change Set の作成と確認 | 必要（下記の注意を参照） | CI（OIDC）。人間が承認した環境 |

**注意: what-if は読み取り専用の権限では実行できません。** Azure の公式ページによると、what-if には、デプロイと同じ権限（デプロイするリソースへの書込み権限と、`Microsoft.Resources/deployments` への全操作の権限）が要ります（[公式](https://docs.azure.cn/en-us/azure-resource-manager/bicep/deploy-what-if)）。つまり、what-if を実行できる ID は、同じ範囲でデプロイもできてしまいます。AWS の Change Set の作成に必要な権限は、この文書の作成時に確認できていません。

そのため、権限を絞るだけでは「差分の確認はできるが、デプロイはできない」という分離を作れない可能性があります。差分の確認とデプロイを分けるには、実行する場所と承認の流れで分けます。差分の確認は CI の専用ジョブで実行し、デプロイは別のジョブで、人間の承認を挟んで実行します。エージェント自身には、クラウドの書込み権限を持つ ID を渡しません（[README の統制の境界](README.md#統制の境界)）。

## 受け入れテストの書き方

`acceptance-tests` の表に、IaC の検査を通常のテストと同じ形で並べます。種別の列は自由記述なので、`iac-static`、`iac-plan` のように書けます。次は Azure の例です。

| 受入基準 | 要件 | Test ID | 種別 | 対象 | 状態 |
|---|---|---|---|---|---|
| AC-010 | REQ-010 | TEST-010 | iac-static | Bicep のビルドとリンターが警告 0 で通る | Planned |
| AC-011 | REQ-010 | TEST-011 | iac-plan | what-if の出力を保存し、削除と置換が 0 件、または人間の確認済みである | Planned |
| AC-012 | REQ-011 | TEST-012 | iac-plan | 変更対象が要件に書かれたリソースに限られる | Planned |

AWS では、TEST-011 の対象を `cdk diff --fail` の結果の保存と、削除と置換の確認に置き換えます。`--fail` は差分があると失敗にするオプションです（[aws.md](aws.md) の出典を参照）。

## 証跡に残すもの

- 差分の出力そのもの（機械可読な形式を推奨。Azure の what-if は `--no-pretty-print` が使えます）
- 実行時のコミットと、使ったテンプレートとパラメーターの版
- 削除と置換が含まれる場合は、人間が確認したという記録

証跡は SDD Forge の証跡バンドルの仕組みで生成します。手書きは認められていません。ただし、差分の出力の中身を SDD Forge が解釈する機能はありません。削除や置換の確認は、プロジェクトの運用ルールとして人間が行います。

## 限界

- この雛形は文書上の取り決めで、SDD Forge が差分を判定して止める機能ではありません。
- 差分の証跡を共通の形式で束ねるゲートは、実案件での検証の後に検討する、という整理です（[ADR-0046](../adr/0046-vendor-agent-toolkit-coexistence.md)、提案中で未決）。
- `Done` はデプロイの完了を意味しません。
