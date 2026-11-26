# T-010　既存契約、Shadow の実測と廃止候補

初回の実行対象は PR #976 の head `cc5872c29`。Actions のマージコミット `124c57a18` と同じ Git ツリーである。実行は 2026-11-25 UTC。測定値と実行レシートはこのディレクトリの JSON に収録した。

## AC-013 の互換性

v2.1.3 の配布例を一時プロジェクトの `sdd/guardrails.yaml` にそのまま設置し、同じデータを旧版と PR head の CLI に渡した。設定の SHA-256 は実行前後とも `79d3cca3689f58c681467e1ab90e4b1e5f276ec8014c6b1ce69cf2e2a3b98557`。8通りの終了コードと対象の診断または JSON フィールドが両版で一致した。生の各測定値は [既存 CLI の照合](stock-exit-codes.json) にある。

| 公開 CLI の条件 | 旧版 | PR head |
|---|---:|---:|
| task-lock の初回 acquire / 別 owner による競合 / 所有者の release | 0 / 1 / 0 | 0 / 1 / 0 |
| sdd-soft-guard の AGENT_STOP | 2 | 2 |
| 旧署名付き Concept Test の defer / reject | 2 / 3 | 2 / 3 |
| finalize-domain-review の dispatch helper 不在（sh / pwsh） | 3 / 3 | 3 / 3 |

`mcp/sdd-forge-mcp` の hosted `npm test` は同じツリーで73件成功、失敗0件。v2.1.3 設定での stdio 起動による4ツール列挙とインストール時の既定 OFF の検査は T-009 の記録から追跡できる。[MCP ジョブ](https://github.com/aharada54914/sdd-forge/actions/runs/45719350065/job/139573450999) · [T-009 の旧設定による比較](../../T-009/main-integration/compatibility.json)

## SELF-AC-005 の実測

同じクリーンな PR head、同じローカルホスト、同じカタログ・スイートに対し、追加処理なしと、実際の PR 差分の AST＋組み込み依存チェック付きの壁時計時間を3組で比較した。実行順は各組で交互。全6実行でカタログの個別スイートが成功し、追加処理も毎回成功した。差は +2.356、+1.691、+1.737秒で、今回のローカル経路では上限 +15秒以内。外部 SAST と TLC は hosted ジョブで測定した。[6レシートとコマンド](paired-local.json)

hosted 比較は両方とも GitHub Actions の `pull_request` イベント。PR #980 のツリーは #976 の base と一致する。両 PR の Test と Guardrails に対し、**実行された**最初のジョブ開始から最後のジョブ完了までを計測した。待ち行列の時間とスキップしたジョブを除く。差分・runner・キャッシュは異なるため、単一対の観測値にはそれらの変動も含まれる。[元の Test](https://github.com/aharada54914/sdd-forge/actions/runs/45702351630) · [比較先の Test](https://github.com/aharada54914/sdd-forge/actions/runs/45719350065)

| 計測範囲 | #980 | #976 | 差 |
|---|---:|---:|---:|
| PR の両ワークフロー全体 | 612秒 | 645秒 | +33秒 |
| Guardrails ジョブ単体 | 24秒 | 149秒 | +125秒 |

PR 全体では +120秒以内。Guardrails 単独の増分は上限を5秒超える。同ジョブは実 TLC と SAST を実行した。直近3回の両 scanner のアーティファクトには Gitleaks/Semgrep の所見が各0件で、SAST の誤検知率の分母は0件。AST の独立した実差分の判定は T-004 にある。strict 昇格の実績はない。[元の Guardrails](https://github.com/aharada54914/sdd-forge/actions/runs/45702351606) · [比較先の Guardrails](https://github.com/aharada54914/sdd-forge/actions/runs/45719350191) · [ジョブ時刻と scanner 出力](hosted-comparison.json)

## プロファイルとカテゴリ2

実プロファイル195件から指定した5スイートを、候補では標準の `--suite ... --receipt`、v2.1.3 では同じファイルの直接実行で比較した。定数と CRLF の検査は両版で0、P0 文書とワークフロー文書は両版で1、図のリンク検査は旧版1から候補0に改善した。後者はスイートの結果であり、旧 CLI 公開契約の変更を示さない。[個別レシート](local-suite-comparison.json)

対象 SHA の全195件を完走したレシートは未取得。旧版は全カタログ検証の参照先欠落で計画エラー（終了2）。欠落77件中、local-posix に含まれるものは42件。過去の部分実行の原因とハッシュは既存報告に記録されている。現行の通常 CI は別のスイート選択で完走した。全件選択には実サブプロセスへのコード注入試験（`tests/cross-model.tests.sh:1194`、`tests/task-state-grammar-parity.tests.sh:215`）と、実サンドボックス境界の試験（`tests/research-acquire.tests.py:762`）が含まれる。今回の実行は上記の個別スイートと通常 CI の記録収集まで。[過去の全件調査](../2026-11-26-local-profile.md)

カタログ348件には同一 stem の `.tests.sh` / `.tests.ps1` が85組あり、名前が `-parity.tests.sh` のものは14、`-parity.tests.ps1` は6。定数などの契約照合も含まれるので、ファイル名や Windows ジョブの成功だけでは後継 ESM への同値集約を証明できない。承認台帳の記載は0件で、今回の廃止は0件。[棚卸し](parity-inventory.json) · [Windows を含むテスト実行](https://github.com/aharada54914/sdd-forge/actions/runs/45719350065)

## 過去の195件と現在のツリーの照合

過去2回の対象は重複せず、同一プロファイル195件のうち82成功、113失敗だった。失敗113件の判定を、重複しない一次根拠で集計した。現行での失敗再現、ツリー上で確認した失敗条件、未判定を区別した。PR base は `2db182ad2`、修正前 head は `cc5872c29`、旧版は `484cbe7ae`。各スイートの追加原因、ログ行番号、比較対象SHAは[個別の照合結果](historical-failure-triage.json)にある。

| 一次根拠 | スイート数 | 判定 |
|---|---:|---|
| 同じ終了1・同じ診断をbase/headで再現 | 7 | 文書・旧プラグイン・CLIインストール契約など、PR以前から失敗 |
| registry 検査をbase/headで再現 | 2 | baseで既に1ディレクトリ欠落。PRでさらに2件増加。修正後の実レシートは下記 |
| 下流テストのログに同じregistry診断 | 7 | 修正前headのディレクトリ差と一致。個々のスイート全体の修正後判定は未取得 |
| 既存テストがワークフローで要求するスイート名が旧版/base/headすべてで欠落 | 6 | 各スイートにある実際の文字列検査と3版の `.github/workflows/test.yml` を照合 |
| 過去の診断が読み込んだパスが旧版/base/headの全ツリーで欠落 | 39 | 旧プラグイン、テンプレート等。ほかの一次根拠との重複を含めると44スイート・41パス |
| 過去のworkflow未コミット判定がクリーンな両checkoutで解消 | 3 | `git diff --quiet HEAD -- .github/workflows/test.yml` は両版0。重複を含めると4スイート。各スイート全体は未判定 |
| ドキュメント図検査がheadで成功 | 1 | baseは1、headは0 |
| 過去ログでAjv依存不足 | 1 | 今回の環境での同スイートは未判定 |
| 現行との因果関係が未判定 | 47 | 既存ログで失敗。現行での成功・失敗数には含めない |
| 合計 | 113 | |

base/headで直接再実行した12スイートは上表の10件と、元々成功した定数、CRLFの2件。各版で成功した通常CIログから、同一プロファイルの9本をコマンド行で特定した。9本は過去の成功82件に含まれる。合成データや実行コマンドが見当たらないスイートをCIの実行件数に加えていない。[12本の両版比較](paired-triage.json)・[baseのジョブ](https://github.com/aharada54914/sdd-forge/actions/runs/45702351630)・[headのジョブ](https://github.com/aharada54914/sdd-forge/actions/runs/45719350065)

`f4b7cc0` で、既存の `lite` プロファイルに `v2-lightweight-guardrails`、`verification-first-factory`、`self-verification` を登録した。tracked `AGENTS.md` は3件を列挙し、ADR-0051/0054はv2のSDD Coreによる検証を定める。`self-verification` はモデル・設定を収め、仕様は親featureが管理する。旧validatorの `lite` は登録・パスを検証し、Full三段レビューを適用しない既存契約である。ShellとPowerShellのregistry検査、両者のparity、各featureを両シェルで検査した計9件が成功した。[修正後の9件と2件のカタログ実レシート](registry-repair.json)・[旧validatorのプロファイル定義](../../../../workflow-state-integrity/design.md#lite-profile)

この修正でregistry欠落は解消した。旧プラグイン配下の欠落を確認したスイートには、各スイートが現在も保護すべき公開契約とv2での後継実装を特定する作業が残る。全195件を完走した同一SHAのレシートは得られていない。

## 統合版での追加6対

旧113失敗の「現行結果未確認」47本のうち6本を、統合版 `c9c5d24b2` のクリーンなカタログ単独実行とPR base `2db182ad2` の直接実行で照合した。6本ともスイートソースが同じで、終了1と先頭診断が一致した。残る現行結果未確認は41本。対象は `review-prompt-calibration`、`loop-inventory`、`model-selector-package`、`design-system-compliance`、`design-sync-policy`、`turn-first-workflow`。統合版は各スイートの前後ともクリーン。同一SHA・全195本のレシートは未取得。[診断とカタログレシート](additional-clean-pairs.json)

## カタログと既存契約の変更履歴（統合版 `123cebf69`）

3版の `tests/verification-catalog.json` と `git ls-tree -r <rev>` を突き合わせた。3版とも `verification-catalog/v1` を使用する。旧版の計画エラーは `tests/verification.py:44` の全カタログ検証で最初の欠落パスに達した時点で発生する。[カタログ SHA-256・除外パス・スイート blob の比較](catalog-lineage.json)

| Git ツリー | カタログ登録 / 欠落 | local-posix 登録 / 欠落 | 実在する選択数 |
|---|---:|---:|---:|
| 配布版 v2.1.3 | 424 / 77 | 237 / 42 | 195 |
| PR base `2db182ad2` | 425 / 77 | 237 / 42 | 195 |
| 統合版 `123cebf69` | 348 / 0 | 195 / 0 | 195 |

この195件は3版で順序まで一致する。baseと統合版の195件の `runtime`、引数、CI名など登録行全体も一致する。スイート本体の Git blob が一致したのはbase比較で194件、配布版比較で187件。baseから変わった1件は形式検証の `project-skill-formal.tests.py` で、TLCの終了値や予約の勝者を検査するアサーションを追加した。`tests/verification.py` 自体のbaseとの差分は `--receipt` 単独指定時に実行する経路で、個別の合否の集計は両版とも一つでも `failed` があれば終了1。`--list` と `--plan` は選択のみを実行する。ソースが同じ場合も、依存ファイルや環境によって終了値は変わる。[実行・集計](../../../../../tests/verification.py#L177)

### 全件レシート取得後に残る判断

| 実測・静的根拠 | 契約の所有者が選ぶ変更と検証 |
|---|---|
| 44スイートの依存欠落41パス。40パスは配布前に削除された。`e2110862f` が17件（Full/Lite、旧ガード、3段階レビュー）、`0da63039a` が15件（旧テンプレート・スキル）、`03a3f4573` が5件（旧reviewer等）、`220f60afd` が2件（旧workflow・fixture）、`8e7c693b5` が1件（重複hook）。残り1件 `.github/scripts/check-model-freshness.ps1` の削除履歴は見つからなかった。 | ADR-0051に沿って、廃止した機能だけを検査する箇所と、後継Coreでも保証する箇所をスイート内で切り分ける。後者は現役CLI・公開契約に対応づけ、同じ失敗を検知するアサーションを移す。旧機能そのものを再導入する場合は別の製品変更として仕様・ADRの承認を要する。41パスを一括再作成する根拠はない。 |
| 6スイートが自身の名前を `.github/workflows/test.yml` に要求する。この6本は現行カタログの `ci_jobs` に旧ジョブ名を持ち、プロフィールでは `local-posix` だけに所属する。`test.yml` はカタログランナーを起動せず、該当の6文字列を含まない。 | `.github/` の所有者が各契約を実行する現役ジョブと予算を決める。現役ジョブが同じ検査を間接起動する場合は実ログと同じ失敗モードを確認して登録アサーションを更新する。未配線の現役契約には個別にCI配線を追加する。カタログの `ci_jobs` の値だけでは実行実績にならない。 |
| base と `c9c5d24b2` の clean 比較6件は全て同じ失敗。`model-selector-package` は bash/pwsh で登録済み capability を選べず、`design-system-compliance` は jq 不在を模した場合に期待する診断が空だった（`tests/design-system-compliance.tests.sh:114`）。他4本は旧reviewer・loop登録・Full/Liteの呼び出し・実装エージェント起動指示。 | モデル選択のパッケージfixtureと製品入力、jq不在時の `check-design-system.sh` の終了値・診断を各担当で照合する。前2件には現役製品とfixtureのどちらを改めるべきかの調査が残る。文書・登録の4件は現在のCoreの対応要件に照合する。6件を同じ廃止カテゴリには入れられない。 |
| 残る41本の過去失敗は現行結果が未判定。汚れたスナップショットの182＋13件と通常CIの結果にはSHA・選択範囲の差がある。 | 対象SHA・全195件の正規レシートの `results[]` と個別診断を照合する。スイートを減らす、失敗を任意扱いする、過去レシートを連結する変更はこの判定を満たさない。 |

[41パスごとの削除コミットと6件の登録行](catalog-lineage.json)・[6対の実行結果](additional-clean-pairs.json)・[v2の統合方針](../../../../../docs/adr/0051-lightweight-guardrails-and-sdd-core.md)・[所有者](../../../../../CODEOWNERS)

T-010 が扱う廃止はカテゴリ2。base～統合版で変更した本番 `.sh/.ps1` は `validate-review-context-set.sh` のみで、同じ `.ps1` は既存実装のまま。20本の `*-parity.tests.{sh,ps1}` には、Python/PowerShellの定数、BashのCRLF処理、Pythonを共有するパス解決、Shell/PowerShellのregistry実装など14系統の異なる比較が入る。registry比較は実際にこのPRの登録欠落を検知した。個別の本番ESMへの統合、旧版と後継のWindows実行結果、各失敗モードの負例100%検知、承認済み blob を揃えた候補は今回0件。E2E・3-AI・goldenを保持し、スイート廃止は0件のままとした。旧Full/Liteの廃止（カテゴリ1）をT-010のカテゴリ2として処理するには対象範囲が異なる。[14系統・20本の対象名](parity-inventory.json)・[承認要件](../../../requirements.md)

## 11月26日、現役スイートの修復

`3519cb1d5` で jq 非搭載を模した fixture は8件、モデル選択の package は9件が成功した。後者では Bash・PowerShell 両方の製品を修正した。上記の本番シェル変更1件は旧比較点の集計である。現役349スイートのうち local-posix の選択は195本。ownership-digest は13件のうち登録検査1件が失敗した。

macOSの一時ディレクトリの祖先 `/var` がシンボリックリンクで、通常ファイルの検査がテストの準備段階で失敗していた。実ファイルのパスを使ってfixtureを作ると、修正 `d24368af6` のクリーンなツリーで research-consumers 17件、research-evidence 21件が成功した。子のシンボリックリンクを拒否する検査を含む。[個別実行のレシート](active-suite-repair.json)

所有者はv2に残る保証の個別移植と、証拠に基づく廃止候補の個別判断を承認した。全195件を同一SHAで完走したレシートと各廃止の承認は引き続き別途必要となる。

### Design Sync の現行呼び出し

v2 の bootstrap から呼ばれる design-sync-loop に、外部データの読み込みと送信を別々に判定する同梱 CLI `resolve-design-sync.py` を接続した。旧 Full/Lite の2入口を検査していた1メソッドを現行の bootstrap → loop → 実ファイルの配線に移植した。実CLIを含む design-sync-policy は14/14成功。旧 standing-consent スイートの手動フォールバック参照を両言語で配布先に修正した結果、TEST-046～050は両方とも成功した。Bashは修正前16件成功・39件失敗。PowerShellは欠落パスから TEST-049 で例外。パス修正直後の両言語は19件成功・36件失敗で、旧 Loop の文書構造と DS-29 ベースライン等の評価が残る。
