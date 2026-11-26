# T-010 リリースとモデル鮮度の検証移行

基準コミットは `d24368af68ecbe157705810a51043fa212844830`。実装前に照合する証拠と、誤った結果を検出する条件を次に示す。

| 証拠 | 照合先 | 不一致を検出する条件 |
|---|---|---|
| リリースを許可したコミット | タグが解決した SHA、完了した test.yml の SHA・リポジトリ・結果 | 成功した検査が別 SHA にしかない場合、出力を渡すと失敗 |
| 発行の前提 | release の依存関係、loop-gate が実行する v2 のテスト・doctor、権限と checkout | 依存やゲートを外した構成が通ると失敗 |
| バージョン変更の結果 | bump CLI の終了コード、テストと doctor の実行、変更前後の各ファイル | テストまたは doctor の失敗後に1ファイルでも変更すると失敗 |
| モデル鮮度の通知 | 実際の CLI がローカルの gh 代替に渡す引数、fixture のカタログ・公開情報 | 取得失敗を差分扱い、未登録モデルを見逃し、既報を再作成、既知モデルで発報のいずれかで失敗 |

## 契約ごとの照合

| 旧検査 | 現在の一次根拠と、CIが検証する内容 |
|---|---|
| `release-config-lock.tests.sh` 1～5 | ADR-0051「Layer 3」の設定契約を引き続き検査する。`--release-config-only` は同じ5検査を実行する。ruleset の構造、全 CODEOWNERS 行の owner、merge group、apply スクリプトの構文、release の CI 依存を対象とする。設定ファイルの検査であり、GitHub サーバー上の適用状態は未測定。[旧検査](../../../../../tests/release-config-lock.tests.sh)・[現在の ruleset](../../../../../.github/rulesets/main.json) |
| 同 6 の署名前提 | `context-signing-environment.tests.py` の7件をローカルで実行。残存する Python の設定・イベント検証6件が成功。`test_workflow_keeps_pinned_issuer_and_secret_step_boundary` だけが `context-approval.yml` 欠落でエラー。削除コミットは `220f60afd`。ADR-0051 の Layer 2 は承認 sidecar/HMAC を Git ベースラインに置き換え、Layer 3 は PR/CI の責務を定めている。v2 の drift テストが署名鍵や signer の環境条件を実証するという対応付けはできない。[署名前提の7件](../../../../../tests/context-signing-environment.tests.py)・[ADR の決定](../../../../../docs/adr/0051-lightweight-guardrails-and-sdd-core.md) |
| `release-loop-gate.tests.sh/.ps1` TEST-007～010 | `1731c015a` で旧2ループと旧 repository validator を、v2 の10本の Node テスト、doctor、構造・installer の検査に置換。現行の実行ステップ、Ubuntu 単一ジョブ、read-only、認証情報を保持しない SHA checkout、release の必須依存を確かめ、依存を1本外した例が検査に失敗することも確認した。[現在のリリースジョブ](../../../../../.github/workflows/release.yml)・[新検査](../../../../../tests/release-readiness.tests.py) |
| 同 Bash 版の後半 | 旧検査は冒頭の失敗で後半まで進まない。後半の通常経路を独立させ、実際の release.yml の実行本文を使用。main/tag の手動受付、誤った SHA・失敗 CI・PR 実行の拒否、checkout の SHA、コミット内のファイルを使った tar と SBOM、両成果物のチェックサム、workflow と release の provenance を検証する。タグ移動時は upload 呼び出し0回。同じタグなら一時ディレクトリの gh 代替が3つのファイル名を記録する。署名・配布の外部サービス、実ホスト認証、旧 Bash 版後半の全分岐は実行対象外。[旧 Bash 版](../../../../../tests/release-loop-gate.tests.sh)・[現在のリリースジョブ](../../../../../.github/workflows/release.yml) |
| `bump-version-gate.tests.sh/.ps1` TEST-001～006 | `scripts/bump-version.sh` を一時プロジェクトで実行。10本の個別 Node テストと doctor は停止位置を選べる fixture。先頭・末尾のテストを別々に失敗させると doctor 未実行、doctor を失敗させると変更前に終了する。いずれも対象11ファイルの内容がバイト単位で同一。成功時は10本と doctor が動き、6種類のホスト manifest、両 marketplace、MCP の package・source、README がすべて更新される。配布 bundle の再ビルドはこの依存なし fixture の対象外。macOS の成功経路も実測済み。[実 CLI](../../../../../scripts/bump-version.sh)・[旧 Bash 版](../../../../../tests/bump-version-gate.tests.sh) |
| 同 Bash 版 TEST-007 | `606ad3867` で加わった2条件は両方とも現役。README の版は実際に bump と release が実行する `v2-hooks-and-ci.test.mjs` の版整合チェックにある。`managed-model-entry.py` は install.sh:1229 と install.ps1:987 の必須入力で、現行 implement-task の委譲ポリシーにも実行例がある。全 OS の release スイートにソース実在、POSIX の FilesOnly 実インストールに配布内容のバイト一致を追加した。独立した一時入力で helper 欠落と README `v0.0.0` を与えた際、各 Node 検査が該当箇所で個別に終了1となった。[配布検査と README 版整合](../../../../../tests/v2-hooks-and-ci.test.mjs)・[委譲ポリシー](../../../../../plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md) |
| `model-freshness-check.tests.sh/.ps1` TEST-005～007、009、010、016、020、#298、共有ポリシー | 月曜03:00 UTCと手動起動の Ubuntu ジョブは現役。実装は Bash。PowerShell テスト自身の冒頭に、Windows ではロジックを独立に再実装したと明記している。新しい CI 経路は本番の Bash にローカル3社 fixture と gh 代替を渡し、部分取得失敗時の通知、差分・重複排除、差分なし時の無通信、Google 候補、出典日と明示的な廃止候補、既知ポリシーと入力不変を確認する。旧 guard の対象パスと両ローカル runner の登録も確認。通知がモデルの採用・手動選択を変更することはない。選択は session-models の live discovery と確認が所有する。[週次 workflow](../../../../../.github/workflows/model-freshness-check.yml)・[実 CLI](../../../../../.github/scripts/check-model-freshness.sh)・[モデル選択の仕様](../../../../../plugins/sdd-implementation/skills/model-selection/SKILL.md) |

## 本人承認が必要な個別候補

- 署名系は `context-signing-environment.tests.py:89` の旧 workflow 固有アサーションに限って廃止候補にできる。残る6件には実装がある。外部署名を復活させる場合、発行者・保護環境・鍵の所有と運用は別途決定が必要。
- release と bump の旧2ループ名、旧 validator のコマンド名、旧 for 文の字面、旧 CI ジョブへの自己登録は、上記の v2 保証に移行した範囲で個別廃止候補。bump の README・managed entry 欠落検知は継続。旧バイパス文字列検査は任意の将来の環境変数による迂回まで検出する動作証明にはならず、今回の停止試験も指定した失敗条件に限る。
- モデル鮮度の Bash を PowerShell にポートする要件はない。旧 PowerShell テスト独自の Windows 比較と、旧スイート名そのものの CI 登録は別々に承認が必要。旧 TEST-021 と protocol の境界試験、旧リリース検査の残りには自動廃止の根拠を付けていない。
- 旧スイートと既定実行経路を保持した。新スイートを独立名でカタログに登録し、部分実行した旧スイートに CI 全体成功を付けない。

## 実測と残件

| macOS arm64 での実行 | 結果 |
|---|---|
| `python3 tests/release-readiness.tests.py` | 6テスト成功。Linux ジョブ用の全ケースをローカルで実行 |
| `bash tests/release-config-lock.tests.sh --release-config-only` | 5成功 |
| `bash tests/model-freshness-check.tests.sh --release-catalog` | 46成功 |
| `python3 tests/context-signing-environment.tests.py -v` | 6成功、1エラー（上表の旧 workflow 欠落） |
| `node --test tests/v2-hooks-and-ci.test.mjs` | 19成功、skip 0 |
| `python3 tests/verification-catalog.tests.py` | 23成功 |
| actionlint 1.7.12 で test.yml、release.yml、model-freshness-check.yml を検査 | 終了0 |
| `python3 tests/verification.py --profile local-posix --list` | 195件。新しい独立スイートは別途 CI ジョブで実行 |

製品コミット `805220bb1365f5f6c083b923afc65206e008ddcc` の前後とも clean な状態で、新スイートを単独でカタログ実行した。6テストが成功し、カタログの所要時間は3.062秒。[実行レシート](release-readiness-receipt.json)

[CI の配線](../../../../../.github/workflows/test.yml)は Ubuntu で全6件、macOS・Windows でワークステーション向け bump の1件を実行する。初回の hosted 実行は未測定。旧195スイートの同一 SHA 完走と strict 昇格は未達のため、T-010 全体の判定は FAIL。

## repository-release-validation の20件

2026年11月26日に、正常・復元の4件を現在の配布構成へ移し、版異常4件と構造異常12件で同じ不備を検出することが個別に承認された。v1.26.0（`b193c75be`）では旧入口で20件すべてが成功した。`bf3f666c5` では最初に README の固定版の検査が失敗し、版だけを直しても配布終了した sdd-lite の欠落で停止した。旧一覧の106ファイル中23ファイルが現行ツリーに存在しない。

| 対象 | 件数 | 合否の根拠 |
|---|---:|---|
| 有効な配布ツリー、全変異を戻した配布ツリー | 4 | 現在の CI とリリースの両入口が変更前と復元後に成功する |
| README の先頭版 | 2 | 現行版を変更すると両入口が版ずれを示す |
| CHANGELOG の候補版見出し | 2 | 同じ版の見出しを増やすと両入口が重複を示す |
| managed-entry、policy-engine | 2 | 委譲入口または方針処理本体を個別に削除し、配布元検査または実インストールで欠落を検出する |
| cloud-entry、cloud-marketplace | 2 | Azure の実行ファイルを削除、または marketplace の配布元を変更すると該当するクラウド検査が失敗する |
| payload-contracts | 1 | インストーラーの配布対象から contracts/ を外すと、配布必須の契約を実インストールで検出できない |
| ci-cache | 1 | キャッシュ用スクリプトを削除するとそのパスが診断に出る |
| role-reference | 1 | モデル方針の役を未登録の能力名に変えると拒否される |
| ci-plan、ci-observations、ci-result | 3 | 3スキーマを個別に削除すると対象のパスが診断に出る |
| model-schema-id、ci-result-id | 2 | 配布スキーマ内の識別子を個別に v999 にすると拒否される |

末尾の7件（ci-cache 以降）は、CI とリリースの両方で拒否する追加承認の対象。通常スイートの入口は [repository-release-validation.tests.sh](../../../../../tests/repository-release-validation.tests.sh)。CI とリリースに登録したコマンドは [test.yml](../../../../../.github/workflows/test.yml) と [release.yml](../../../../../.github/workflows/release.yml) にある。
