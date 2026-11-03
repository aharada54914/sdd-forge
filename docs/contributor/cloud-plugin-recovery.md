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
旧系統にあるモデル選択ポリシーとCI再構成全体は移植せず、クラウド検証を現行CIへ接続します。
現行の入力検証、リテラルパス、Bash 3.2／PowerShell互換性の修正を保持します。

テストが参照していた旧 `specs/cloud-orchestration/verification/` の必要な入力だけを、
原文バイトのまま [tests/fixtures/cloud-orchestration](../../tests/fixtures/cloud-orchestration/README.md)
へ移しました。旧レビュー・承認・実行成功の記録を、新しい成功証跡として作り直してはいません。
同梱する上流資料のライセンス・NOTICEと固定ハッシュも保持します。

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
| クラウド契約 | 34テスト成功 |
| クラウド実行境界（合成transport） | 87テスト成功 |
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
