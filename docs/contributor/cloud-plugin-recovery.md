# Azure／AWSプラグインの復旧記録

v1.20.0に含まれていた `sdd-azure-cloud` と `sdd-aws-cloud` を、現行コードへ復旧します。
旧版の実装を含む履歴がmainに取り込まれず、v1.21.0以降では両プラグインが欠落していました。

## 出自と復旧範囲

| 対象 | コミット |
|---|---|
| 復旧元のv1.20.0 | [`96afb59f`](https://github.com/aharada54914/sdd-forge/commit/96afb59fcceab422024d5f2d1abc1b478d7058cf) |
| 旧版とmainの共通祖先 | [`fcb8275a`](https://github.com/aharada54914/sdd-forge/commit/fcb8275a42061b8132ea88a36e69b02f4487be71) |
| 今回の復旧前main | [`006c0840`](https://github.com/aharada54914/sdd-forge/commit/006c0840693b821f6cab7627e4779445b49e74a0) |

復旧対象は、両プラグイン、共有の契約・認可・検証処理、導入と更新・解除、
明示的なbootstrapの委譲、保護対象、CIテンプレート、関連テストと利用文書です。
このクラウド復旧の時点ではモデル選択ポリシーとCI再構成全体を移植せず、
クラウド検証を現行CIへ接続しました。後続の復旧範囲と互換条件は下記を参照してください。
現行の入力検証、リテラルパス、Bash 3.2／PowerShell互換性の修正を保持します。

テストが参照していた旧 `specs/cloud-orchestration/verification/` の必要な入力だけを、
原文バイトのまま [tests/fixtures/cloud-orchestration](../../tests/fixtures/cloud-orchestration/README.md)
へ移しました。旧レビュー・承認・実行成功の記録を、新しい成功証跡として作り直してはいません。
同梱する上流資料のライセンス・NOTICEと固定ハッシュも保持します。

## 後続のモデル選択ポリシー復旧

v1.20.0のモデル選択ポリシー、managed entry、契約、ADR 0038、16スキルの
`Managed allocation boundary` と関連する起動手順を現行コードへ復旧します。
調査、診断、単一・一括実装、レビュー、監査、外部パネリストの呼び出しが対象です。
入力検証、リテラルパス、固定入力、クラウドの権限境界など、復旧後に加わった修正は保持します。

旧版との差は、managedを明示的に選ぶ点です。通常の呼び出しには既存のlegacy経路を残します。

| 呼び出し | managedを選ぶ入力 | 入力がない場合 |
|---|---|---|
| `select-agent-model` | `--policy-input`／`-PolicyInput` | 従来の候補・tier選択 |
| `render-agent-frontmatter` | `--model-controls`、ハッシュ、run/session、managed-targetの引数群 | 従来のfrontmatter／参照コメント |
| GPT/Gemini runner | controls、ハッシュ、run/sessionの引数群 | 従来の同意付きrunner |
| managed entry | `prepare`、`claude-entry`、`claude-batch-definition`の明示呼び出し | 自動では起動しない |
| 週次self-improvement | 既存の `SDD_SELF_IMPROVEMENT_REQUEST` repository variable | 従来のAction設定 |

managed用引数の一部だけを渡しても、legacyへ戻りません。不完全・不整合な入力は拒否します。
managedを選んだ処理では、子の役割・host・run/session・workloadごとに有効なselectionと
controlsの対応が必要です。親の認可や成功だけで新しい子を認可せず、選択・検証・起動が
失敗した場合もlegacyや別hostへ自動退避しません。必要なbindingがなければ、作業や予約の前に停止します。

controlsは選択結果と実行コードのハッシュを結びます。今回追加したPowerShell共通ヘルパーも
検証対象です。旧実行コード用のcontrolsは復旧後の起動へ転用せず、現在の可用性観測と
採用条件を検証して再生成してください。過去の記録を上書きする手順ではありません。

復旧した採用記録は当時の記録です。現在のモデル可用性、実際に応答したbackendのID、
未採用候補の利用許可、実運用の成功を新たに示すものではありません。
`actual_id: null`／`proof: unverified`は設定の証拠として区別し、実モデルの証明にしません。
Windowsへの導入成功とmanaged runtimeの実行対応も別です。POSIXの安全なファイル操作を
必要とする経路は、未対応環境での拒否を保持します。
Windowsでpolicy selectorを使う場合、その内部の選択再演にはPowerShell 7 (`pwsh`) が
必要です。Windows PowerShell 5.1の入口検証と、再演エンジンの実行環境は区別します。

復旧時の独立監査では、呼び出し側のpolicyだけでcandidateをcurrentへ変更し、任意の採用記録を
付けても起動できる欠落を、記録用CLIで再現しました。共有policy全体をインストール済みの
trusted policyと構造比較するよう修正しています。lifecycle、採用記録、鮮度制限、役割の優先順を
呼び出し側で書き換えて権限を増やすことはできません。CLI、環境変数、project設定による
モデル・policy選択は、従来の優先順位と許可範囲内で引き続き使えます。本番のClaude候補を
採用済みへ変更してはいません。正方向のテストだけが、隔離したtrusted fixtureに合成の採用条件を設定します。

拒否時の成果物も確認しました。終了コード2・成功stdoutなしで残るselectionやcontrolsは、
診断用の入力記録です。出力ディレクトリ名は再利用できませんが、run/session/attemptの
全体予約やモデル作業の成功を意味しません。Action準備で残る`validation.json`も設定検証の
receiptであり、SDK wrapperや実行結果ではありません。Codexの失敗時にも実行成功のvalidationは
発行されません。捕捉や拒否の調査に使う記録は一律に削除しない方針です。

役割・tier・起動時の設定の違いは [モデルとエージェントの対応表](../agent-capability-matrix.md#managed-model-policy)
を参照してください。旧版の全新規割当への強制を戻すのではなく、明示選択されたmanaged処理の
境界を維持する互換変更です。承認、レビューの独立性、外部送信の同意は変更しません。

## 実行と承認の境界

- 導入は明示指定です。既定の `sdd-bootstrap,sdd-ship` は変えません。
- ローカルの `route`／`plan`／`validate` と、保護されたCIの `prepare`／`apply` は別の権限境界です。
  タスク承認、環境変数、保存済みreceiptからクラウドへの書込み権限は発生しません。
- 実行コードと上流・ツールの固定情報を保護し、要求・成果物のハッシュと実行先を検証します。
  不明な所有者、入力の変更、足りない前提条件は拒否します。
- Windowsへの導入成功は、Windowsパスでのクラウド実行対応を意味しません。
  Provider実行には、文書化されたPOSIXファイル操作と固定ツールが必要です。

実クラウドの受入 `TEST-003`／`TEST-005`／`TEST-009` は引き続き **BLOCKED** です。
今回の復旧やローカル・CIテストを、実デプロイの成功や本番対応の証明にはしません。
操作・復旧手順は [クラウド実行ガイド](../cloud-orchestration.md) を参照してください。

## Contextの所有範囲

署名済みの現行Contextは、7プラグインとMCP・installerの計9コンポーネントのまま保持します。
署名、承認済みの写し、歴史候補は変更していません。

復旧した2プラグインを含む11コンポーネントの候補は、
[project-context-restored-cloud.yaml](../../specs/epic-197-a9-dogfood/candidate/project-context-restored-cloud.yaml)
です。共有テンプレートは、この2プラグインだけに所有を限定しています。
候補の検証成功は、署名・承認・有効化ではありません。

現行の署名済みContextを使った実CLI検証では、両Providerのパスと `templates/cloud/` のパスが
`UNOWNED` となり、`check-component-coverage` は `Fail-1: triggered=true` を報告しました。
`advisory` のため終了コードは0です。このCI成功を、復旧部分の所有が承認・有効化された証拠として扱いません。

## 確認済みのローカル検証

復旧作業中に確認した結果です。最終コミットのCI結果とは区別します。

| 検証 | 結果 |
|---|---|
| クラウド契約 | 34件実行: 33成功、Windows専用1件skip |
| クラウド実行境界（合成transport） | 87件実行: 86成功、Windows専用1件skip |
| ガードの言語間整合性 | 478項目成功 |
| A9の候補・所有・昇格境界 | 35テスト成功 |
| 署名済みContextによる復旧パスの実CLI分類 | 上記の `UNOWNED`／advisoryを確認 |

最終コミットのCI結果は[PR #708のチェック](https://github.com/aharada54914/sdd-forge/pull/708/checks)で確認できます。
公開後の配布物と検証結果は、v1.22.1のReleaseに記録します。

## 追加のローカル検証

- Cloud verification: 109件成功。保存済み証跡だけでは認可・成功にせず、freshな収集と契約を検査した。
- 固定Bicep 0.48.1／Node 24.19.0／CDK 2.1145.0を実行したrouting: 96件成功、skipなし。実際のcompile／synthと、誤pin・asset・出力の拒否を確認した。
- インストール既存回帰: Bash 63件、PowerShellの全シナリオ成功。解除: Bash 25件、PowerShellの全シナリオ成功。cloud固有の導入・更新・cache・破損時保持・symlink拒否も検証した。
- Gitに保存した復旧snapshotでの導入matrix: Bash 20件／PowerShell 21件成功。All／Codex／Claude／Copilotで再導入の同一性と全9件の解除・残骸なしを確認した。
- Foundation: 55件成功。共有MCP GET処理への現行アダプターと、GET・delegate改変の拒否を検査した。
- applied mirrorだけを同期。PENDING／frozen関連59ファイルは変更せず、mirror freshnessとPhase 2のBash／PowerShell回帰が成功した。

fixtureの各ファイルは`tests/fixtures/cloud-orchestration/source-manifest.json`に出自とSHAを記録し、元タグのバイト列との一致を確認した。これらの結果は実クラウド受入を意味しない。

## AWSのプライベートCIDR判定

復旧時の独立レビューで、AWSの観測処理がサンプルの`10.0.0.0/16`だけを受け入れ、
コンパイル時に対応する他のRFC1918 CIDRを拒否する不整合を確認しました。
観測でも既存のCIDR検査を共有し、3つのRFC1918範囲へ整合します。
ポート・プロトコル・公開IP・受信規則・リソースID等の既存検査は維持します。

CIDRのQuery/XML回帰で、旧実装の誤拒否と例外を再現してから修正を確認しました。
許容CIDR、公開・IPv6・不正形式・範囲跨ぎ・混在規則と、既存のポート・ID制約を検査しています。
全112件のスイートが成功し、PATH未設定で省略されたPowerShell経路は指定runtimeで個別に成功しました。
追加修正の独立レビューと、59対象の静的検査（指摘0件）も完了しています。
