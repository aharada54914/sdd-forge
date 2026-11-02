# エージェントのクラウド権限を絞る

Azure / AWS のクラウド資源を扱う案件で、コーディングエージェントに渡す権限を考えるための整理です。SDD Forge のフックは、クラウド API の呼び出しを止めません（[README の統制の境界](README.md#統制の境界)）。クラウド側の権限が、実質的な上限になります。

## 結論

- エージェントが使える ID（環境変数、CLI のログイン、MCP の認証情報）には、**クラウドの書込み権限を持たせない**ことを基本にします。
- 「差分の確認はできるが、デプロイはできない」という分離は、権限の絞り込みだけでは作れない場合があります（下記）。実行する場所と承認の流れで分けます（[CI の承認付きデプロイ](ci-deploy-pattern.md)）。

## Azure

| 事実 | 出典 |
|---|---|
| what-if の実行には、デプロイと同じ権限が要ります。デプロイするリソースへの書込み権限と、`Microsoft.Resources/deployments` への全操作の権限です。 | [Bicep deployment what-if operation](https://docs.azure.cn/en-us/azure-resource-manager/bicep/deploy-what-if) |
| 公式ページは、特定の組み込みロールを名指ししていません。ロールと権限は Azure の組み込みロールの一覧で確認する、という案内です。 | 同上 |

そのため、what-if を実行できる ID は、同じ範囲でデプロイもできます。エージェントに what-if だけを許す読み取り専用の ID を作る、という構成は取れません。

## AWS

| 事実 | 出典 |
|---|---|
| AWS MCP Server を経由したリクエストには、IAM の条件キー `aws:ViaAWSMCPService`（Boolean。MCP サーバー経由なら `true`）と `aws:CalledViaAWSMCP`（経由した MCP サーバーのサービスプリンシパル）が付きます。 | [How AWS MCP Server works with IAM](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/security_iam_service-with-iam.html) |
| これらのキーが示すのはリクエストの**経路**で、呼び出した主体ではありません。人間が MCP 経由で呼ぶこともあります。 | 同上（ページの趣旨を要約したものです） |
| MCP サーバー自身は、独自の IAM アクションを持ちません。ダウンストリームのサービスが、既存のポリシーで各呼び出しを認可します。プレビュー時の `aws-mcp:*` アクションは非推奨で、効果がありません。 | 同上 |

使い方の含意は次のとおりです。

- 条件キーで拒否できるのは、MCP 経由の呼び出しだけです。エージェントが AWS CLI や SDK で直接呼ぶ場合は、キーが付かないため、この拒否は効きません。
- したがって、本線はエージェントが使える**認証情報そのもの**の権限を絞ることです。条件キーは、MCP 経由の経路を追加で締める補助として使います。

## 確認できていないこと

- AWS の `cdk diff` や CloudFormation の Change Set の作成に必要な IAM 権限。この文書の作成時に、公式の記述を確認できていません。
- Azure のフェデレーション資格情報を、ブランチや環境の条件で絞る設定の詳細。
- エージェントが CLI で直接クラウドを呼べる環境で、フックを使って検出する方法。フックのガードは、Bash のデプロイ系コマンドを止めません（Python 版ガードの直接呼出しで確認済み）。

## 関連

- [CI の承認付きデプロイ](ci-deploy-pattern.md)
- [IaC の検証計画の書き方](verification-plan.md)
- [Azure](azure.md)、[AWS](aws.md)
