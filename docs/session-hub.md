# 質問窓口と離席実行

## 構成と保証範囲

既存の6ビュー画面と読み取り専用MCPは維持する。Sitesの同じWorkerに
`/hub` と専用 `/api/hub` を追加する。初期状態は未設定・無効であり、既存の
監視用publisherトークンは窓口の操作権限にならない。窓口の回答は質問への回答であり、
正本のApproval、Status、証跡、マージ許可を書き換えない。

1つのプロジェクトの質問を複数セッションから登録できる。窓口を担当する親セッションは
同じSite ID／Artifact URLを使い続ける。セッション別に画面を作る必要はない。
窓口の会話が止まっても、質問・回答は保存先に残る。別プロジェクトの集約は未対応。

| 配置 | 保存先 | 実行寿命 |
| --- | --- | --- |
| Sites | 既存R2の独立した `hub.json`。ETag条件付き書き込み | Siteと独立した許可済みワーカーが必要 |
| ローカル | 専用ディレクトリの `hub.json`。単一ライター・一時ファイル同期後の置換 | ローカルプロセス／OSが動いている間 |
| Claude Artifact | 実際に接続したリモートコネクタの保存基盤 | Artifact自体にはワーカーを置かない |

## ローカル起動

Node 24以降、POSIXで検証済み。ローカル窓口とHTTP APIはNode標準ライブラリだけで動く。
Storybookは開発時だけ別途依存する。既存観測デーモンを自動起動・変更しない。

```sh
node plugins/sdd-ship/session-hub/local.mjs
```

標準入力へ1つのJSONを渡してEOFを送る。認証情報は引数・履歴・ファイルに保存しない。
以下は値の形を示す例であり、そのまま実行する秘密値ではない。

```json
{"directory":"/private/runtime/hub","project":"my-project","ownerToken":"<暗号学的乱数32バイトのhex64文字>","port":0}
```

stdoutに返る `url` の `/hub` を開き、同じownerTokenで接続する。トークンはブラウザーの
HttpOnly・SameSite=Strict cookieに交換し、入力欄を空にする。ローカル専用HTTP cookieのため
外部へ公開しない。サーバーは127.0.0.1と実際のHostだけを受け付ける。
再起動でcookieは失効し、ログインをやり直す。SIGINT/SIGTERMで停止する。

同じ保存ディレクトリを2プロセスで開かない。異常終了時の `hub.lock` は自動で奪わない。
元のプロセスが停止済みと確認してからlockだけを削除する。保存JSONが壊れた場合は
空データに置換せず停止／エラーにする。保存先はGitや共有Webディレクトリの外へ置く。

## セッション登録・質問・回答配送

`cli.mjs` は標準入力のJSONから接続情報と操作を読む。引数にトークンを渡さない。
操作を省略すると読取だけを行う。stdoutには公開状態だけを返し、トークンは返さない。

```sh
node plugins/sdd-ship/session-hub/cli.mjs
```

共通入力は `{url,project,token,action,input}`。
Sitesへの機械接続には既存の正規service credentialを `serviceToken` として追加する。
これは `OAI-Sites-Authorization` で同じSiteだけへ送り、リダイレクトを拒否する。
service accessは窓口の操作権限とは別で、両方必要。資格情報がない場合は未接続として扱う。

1. ownerTokenで `action:"register"`, `input:{id,label}`, 別に生成した `sessionToken` を渡す。
   セッショントークンは各セッションへ保護された経路で渡す。保存するのはSHA-256だけ。
2. セッションのtokenで `action:"ask"` を送る。
   `input:{id,sessionId,title,expiresAt,options:[{id,label},...]}`。
   `expiresAt` はUTC epochミリ秒で、現在から30日以内。選択肢は2〜8個。
3. 所有者が窓口で選択すると `answered` になる。画面は「受領待ち」と表示する。
4. 元のセッションが `GET /api/hub` で自分宛ての回答を取得し、適用する前に
   保存済みのrequestIdと照合する。セッション内でもrequestIdで重複適用を防ぐ。
5. 適用後に `action:"receive", input:{id,requestId}` を送り `received` にする。

全操作は `{project,expectedRevision,action,input}` のJSONを
`POST /api/hub/command` へ送る。CLIは先に最新revisionを取得する。
競合409では状態を読み直して判断し、回答の自動上書きはしない。
同じ回答requestIdの再受領は冪等。選択肢や回答先の変更は拒否する。
登録済みセッションは自分の質問・作業だけを読める。他セッションの操作は拒否する。
登録を更新するとトークンをローテーションできる。実行中のローテーションは避ける。

**現実装の配送はpull＋受領確認。** 任意の既存ChatGPT／Claudeセッションへのpushや
会話の自動再開は実装済みとしない。セッションはCLI／正規コネクタを利用して参加する必要がある。
ネイティブ送信APIを実証できた場合も、この質問ID・requestId・受領契約に接続する。

## SitesとArtifacts

既存 `status-site/build.mjs` が窓口も同梱する。既存Site IDと私有アクセスを保持して更新する。
R2 `BUCKET` に加え、ランタイムで以下を設定する。秘密値はSitesのsecretsへ置く。

- `SDD_HUB_PROJECT`: 固定プロジェクトID。英数字・`_`・`-`、80文字以内。
- `SDD_HUB_OWNER_ID`: 操作を許可する、Sitesが認証したSite内ユーザーID。
- `SDD_HUB_OWNER_TOKEN`: CLI／機械操作向けの別の乱数hex64文字。publisherとは共有しない。

未設定なら `/hub` は503。閲覧権限だけのユーザーは403。Cookie利用のPOSTは同一Origin必須。
既存6ビュー画面は窓口読取が成功した場合だけリンクを表示する。

Artifact用の自己完結HTMLは次で生成する。

```sh
node plugins/sdd-ship/session-hub/artifact.mjs > /tmp/sdd-session-hub.html
```

`window.sddHubRead(): Promise<PublicState>` と
`window.sddHubAction(command): Promise<PublicState>` はSDD独自のアダプター名であり、
ベンダーAPI名ではない。親ホストで実在する宣言済みリモートコネクタへ結び付ける。
読取・操作権限とネイティブの同意フローをそれぞれ確認する。HTMLにトークンを埋め込まない。
アダプターがなければ画面は未接続と表示する。ローカルstdio MCPだけでは接続成立としない。
この環境でネイティブClaude発行／Sites本番接続は未検証。

## 実部品の比較

`components.mjs` の `choiceButton` を窓口とStorybookが共用する。
選択肢の `preview:{storyId:"hub-choice--variants",version:"1",variant:"primary"}`
または `secondary` で実部品を表示できる。未知の部品・版・variantは拒否する。
外部URLや任意HTMLを選択肢へ埋め込まない。新たな部品は共通実装と受入variantを追加し、
Storybook・窓口・テストを同時更新する。任意プロジェクトの部品を自動読込する機能ではない。

```sh
cd plugins/sdd-ship/session-hub
npm ci --ignore-scripts
npm run storybook
npm run build-storybook
```

## 離席モード

窓口で作業のセッションとローカル許可コマンドIDを指定し、実行を許可して追加する。
離席モードは初期無効。同時実行上限は全体で1件。
ワーカーは空きメモリとCPU数で正規化したload averageを確認し、条件が満たされなければ待つ。
これらは着手判定であり、実行中のCPU／メモリを強制制限するcgroupではない。

```sh
node plugins/sdd-ship/session-hub/runner.mjs
```

標準入力の設定例。`token` は実行セッションのもの。許可リストはローカルで管理する。

```json
{"url":"http://127.0.0.1:12345","project":"my-project","token":"<session token>","sessionId":"worker","minFreeMb":512,"maxLoad":0.7,"commands":{"verify":{"argv":["/absolute/path/to/node","/project/check.mjs"],"cwd":"/project","timeoutMs":300000}}}
```

shellを使わず、絶対パスのargvを実行する。子プロセスにはPATH/LANGだけを渡し、
ワーカーの接続設定は渡さない。ただし同一OSユーザーのファイル読み取りを隔離する
サンドボックスではない。許可コマンド自体を信頼できる環境で使う。
許可リストにない作業は待機する。現在のワーカーはPOSIXプロセスグループでのみ動作する。

無効化は新規着手を止める。個別停止は1秒周期で確認しプロセスグループを停止する。
通信障害でも子を停止する。失敗・タイムアウトは自動再実行しない。
クラッシュ時は期限後に「結果不明」と表示するが、ロックを自動解放しない。
ワーカー／子プロセスが止まったことを確認後、ownerが
`resolve:{id,workerStopped:true}` を送る。再実行する場合は副作用を確認して新しい作業IDで登録する。
起動の常駐化・OS停止中の実行・自動マージ／公開は設定しない。
最大500セッション・500質問・500作業、保存状態1MiB。上限到達は明示エラーで返し、
未解決データを自動削除しない。長期運用のアーカイブ／保持ポリシーは今後の拡張点。

## マージ前検証

`scripts/merge-readiness.py` は既存 `tests/verification-ci.py` の実集約器を使う。
信頼されたCI収集ディレクトリ（`collection.json`、実ジョブ・証跡）と計画が必要。
GitHub APIで同じPRの最新head/baseとmergeabilityを処理前後に確認する。
証跡不足、必須チェック失敗・実行中、コミット更新、draft、状態不明は通過しない。

```sh
python3 scripts/merge-readiness.py --root . --repository OWNER/REPO --pr 123 \
  --run-id 456 --plan /trusted/plan.json --evidence-dir /trusted/observations
```

exit 0は取得時点のready、1はblocked、2は判定不能。GitHub認証は既存のghに委譲する。
出力をownerの `verification` 操作のinputにして窓口へ表示できる。
窓口へ取り込む結果はowner提供のサマリーであり、サーバー自身によるGitHub証明ではない。
60秒経過後は再確認が必要と表示する。マージ直前には必ず再実行し、GitHubの必須チェックと
rulesetを適用する。ブランチ保護設定の変更や自動マージは行わない。

再現可能な検証手順は [.agents/skills/verify-session-hub](../.agents/skills/verify-session-hub/SKILL.md)。
