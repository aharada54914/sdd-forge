# README consumer audit — accepted B6/M6 inputs, activation pending

現在の受入結果: 最終 B6 と M6 の実収集・集約を完了した。末尾の「B6/M6 の実受入結果」を参照。途中の候補・未受入という記述は、その時点の履歴として残す。これだけで選択実行の有効化や速度改善を完了したとは扱わない。

対象: `/workspace/scratch/release-parity-ci-wiring` と、モデル復旧が進行中の `/workspace/scratch/release-parity-models`。この調査ではリポジトリを編集せず、GitHubの設定・PR・実行状態も変更していない。最終baseline Bが未確定なのでsource digest、rule digest、activation packetは作成していない。

## 判断

現在の `readme-contract` は、実行job groupを `cli-hook-enforcement` 以外すべて保持する。READMEの実内容・配置・配布物を消費する既知の経路は保持側にある。CLI hook jobの現在のテスト入力・読み込み経路を追った範囲では、root `README.md` からの依存はないため、この1 jobの省略候補には根拠がある。

ただし、これはactivationを承認する証拠一式ではない。最終Bのfull CI、READMEのみを変える実mutationの検出、current consumer packetの検証、同じtested revisionでのselected/full比較が必要。今回のLinux syscall観測をWindows/macOSの実行証拠やhosted CI mutation証拠として代用しない。

`tests/verification-impact.py` 冒頭の古い `README_SUITES` は5本だけの計測用hypothesisであり、このconsumer一覧の代用にはならない。doc-diagrams、component-path-ownership、installer/current-byte captureなどを列挙していない。今回のcategoryがこの5本だけに狭められると安全性の根拠が失われる。

## Categoryとworkflowの対応

- `tests/verification-catalog.json` の `impact.categories[0]`: `paths=["README.md"]`, `prefixes=[]`, `suites=[]`, `active=false`, `evidence=null`。
- 保持group: `a9-advisory`, `a9-advisory-inputs`, `ci-mcp-tests`, `ci-plan`, `cloud-native`, `coding-standards`, `installers`, `interrupted-recovery`, `local-env-mcp-tests`, `loops-routing`, `mcp-tests`, `posix-regression`, `posix-unwired-sharded`, `test`, `test-windows-heavy`, `version-gates`, `version-gates-windows-bump`, `version-gates-windows-lanes`, `windows-powershell`。
- `.github/workflows/test.yml` のjobsと比較した差は `cli-hook-enforcement` と `required-checks`。後者は `if: always()` の収集・検証jobで、categoryで省略する実行groupではない。全jobの実結果と元planを読み、aggregateを実施する。
- `cli-hook-enforcement` は3 OSのmatrix。`needs: [ci-plan]` と `if: needs.ci-plan.outputs.run_cli_hook_enforcement == 'true'` で制御される。
- categoryの非suite宣言は同jobの `Install Claude Code CLI` だけを `setup` と宣言している。Codex/Copilotのbest-effort setupはworkflowに引き続き存在する。任意の別job/setupを省略してよいという宣言ではない。

## Root READMEを実際に消費する経路

| 経路 | 読むもの・副作用・判定 | 保持される実行先 |
|---|---|---|
| `tests/validate-repository.ps1:53` | root READMEを読み、最初のrelease行がvalidatorの現版と一致することを検証する。`.sh`は同PS validatorへexecする。 | `test` の直接step |
| `tests/repository-release-validation.tests.sh:25` | 現在のrepositoryをfixtureへコピーし、READMEを保存、valid-treeを検証、release行を誤値へ変更して両validatorの失敗を確認する。 | `test` |
| `scripts/bump-version.sh:74` → `tests/bump-version-gate.tests.{sh,ps1}` | README release行を書き換え、manifest/marketplace/validator/release-testと同時更新する。正方向fixtureでは変更後READMEを実読する。CHANGELOG見出しとloop prerequisitesの確認を先に行う。 | `version-gates`, `version-gates-windows-bump` |
| `tests/component-path-ownership-parity.tests.{sh,ps1}` | READMEをrelease surfaces集合へ含め、README版とshipped versionを比較する。 | `version-gates` |
| `tests/workflow-documentation.tests.sh:6` | README内のspec/impl/task review各名称と独立レビューの説明を読む。 | `ci-posix-fallback` → `posix-unwired-sharded` |
| `tests/design-system-contract.tests.{sh,ps1}` | READMEに `design-system/` の公開説明が存在することを読む。 | `posix-regression` |
| `tests/doc-diagrams.tests.py:58,104` + `.sh`/`.ps1` wrappers | README全文をMarkdown link/Mermaid検査対象にする。相対リンク先の存在も検査し、冒頭5行にrelease行があることを検証する。 | shell版は `ci-posix-fallback` → `posix-unwired-sharded`; PS版はlocal profileにも登録 |
| `install-payload.txt:36` → `install.sh` / `install.ps1` | root READMEを配布payloadとして明示許可。local tracked-fileの現在bytes、archiveのbytesを採用する。READMEの意味を解析しなくても、そのbytesがインストール成果物になる。 | `installers`, `windows-powershell`, `cloud-native` およびcaptureを行う保持job |
| `tests/lib/install-payload-check.py:226` | root filesをfixtureへコピーしREADMEへ未commit追記する。source/installed/archiveのpayload manifestを比較するためroot READMEのbytesと名前を消費する。 | `tests/install.tests.sh` / `.ps1` → `installers`; Windows ZIP 3ケースは `windows-powershell` |
| `tests/install.tests.{sh,ps1}`, `tests/installer-idempotency.tests.ps1` | git archive/current overlayから実source fixtureを作り実installerを実行する。PSにはliteral-path先のREADME存在確認もある。 | `installers` |
| `tests/install-cloud.tests.py:90` | READMEをcloud installer fixtureへ明示コピーしてGit追跡し、実installer経路を検証する。 | `cloud-native` |
| `tests/lib/current-byte-capture.py:indexed_source/capture` | `git ls-files -z`からREADMEを含む現bytesを読み、isolated product/installerを実行して配布manifestと比較する。モデル統合側では `files_only_payload()` が復旧済み許可リストと比較する。 | `tests/current-byte-capture.tests.py` → `posix-regression`/`test-windows-heavy`; `tests/compatibility-byte-identical.tests.sh` → fallback; `.ps1` → `test-windows-heavy` |
| `tests/spec-review-loop.tests.sh:429` | root READMEへのsymlinkを仕様入力として作る負例。通常のREADME内容契約ではないが、root READMEのパスをfixture依存として使用するため保持する。 | `test` |

上記のcopy/archive経路はREADMEの内容をassertするテストとは区別した。bytesを配布・snapshotする以上はconsumer inventoryに含める。current-byte captureの生成物（installed manifest、template/manifest比較、generated directory listing）にもこの経路が到達する。

## READMEに言及するがroot READMEの内容を消費しないもの

- `resolve-project-context-*-check.py`, `tests/skip-allowlist-manifest.tests.*`, `tests/coding-standards.tests.py`: disposable fixture内に別のREADMEを生成する。root READMEを読むのではない。
- `tests/project-skill-lifecycle.tests.py`: fixtureの `features/README.md`。
- `tests/guard-parity.tests.sh`, `guard-r10-port.tests.ps1`, `guard-negative-corpus.tests.sh`, `guard-cwd-bypass.tests.sh`, `self-improvement-guard.tests.sh`, `python-input-boundaries.tests.py`: READMEというpath/command文字列を入力し、guardを評価する。root READMEの文面の検査ではない。より広いguard suiteは保持側に残る。
- `tests/sdd-domain-multitarget-foundation.tests.py:151`: `section` と `line_start` の混在を拒否するfixture。`resolve_inventory()` は混在をファイル読取り前に拒否するので、このケースのREADME文字列はroot文面依存ではない。
- capability/generate-gate suitesとguard実装内の `docs/ci-staging/README.md` 等: 別READMEの説明・診断文字列。root READMEの読取りではない。
- `.github/self-improvement*-prompt.md`: 人/agentの調査対象としてREADMEに言及する。`test.yml` の省略候補CLI hook jobから実行されるプロンプトではない。

## CLI hook jobの依存trace

1. jobはcheckout、`npm install -g ... @anthropic-ai/claude-code` と `claude --version`、best-effortなCodex/Copilot導入、`tests/cli-hook-enforcement.ps1` を実行する。READMEを解析するstepやREADMEを渡す引数はない。
2. suiteは一時ディレクトリに `tasks.md` とsynthetic Codex configを生成し、`Edit` payload（Draft→Approvedとsrc.jsのbenign edit）を投入する。CLIsは `Get-Command` による存在確認であり、モデル/agentにREADMEやrepository contextを渡さない。
3. guard invocationは固定: JS/node、PS/pwsh、POSIXのSH→Python（fallback PSあり）。config drift確認はquality-loopの3 hooks JSONを実読する。
4. guarded file inputsは一時tasks/src.js、承認設定 `SDD_SUDO`/鍵探索、実装横のgenerated invariants。テストのEdit経路からgit diffや全repository contentを取り込む経路は確認されなかった。guardにあるREADME言及は別のci-stagingドキュメントへのコメント。
5. generated guard valuesは `references/guard-invariants.json` とgeneratorから作られる。generator `main()` はそのJSONだけをcanonical inputにし、root READMEは生成入力に入らない。
6. model worktreeとの比較では、guard本体・CLI suite・hook configsは同bytes。generatorとgenerated invariant群はmanaged関連4pathの保護対象追加がある。これはREADME入力追加ではない。ただし最終Bではこれらの現bytesを必ずproofへ束縛し直す。

実観測: wiring worktreeとmodel worktreeのそれぞれで `strace -f -e trace=file` を付けて実suiteを実行し、両方とも **15 passed / 0 failed**。root README（大文字/小文字とも）へのfile syscallは0件。子プロセスを含むtraceにはguard実装、generated module群、3 hooks JSON、一時tasks/config、SDD_SUDO探索が現れる。Nodeのpackage.json探索もあり、README探索はない。

保存した観測（いずれもbaseline未確定の補助資料）:

- `/workspace/scratch/cli-hook-readme-run.log`
- `/workspace/scratch/cli-hook-readme-files.log`
- `/workspace/scratch/cli-hook-models-run.log`
- `/workspace/scratch/cli-hook-models-files.log`

このローカル観測ではhosted jobのnpm/gh setup自体は再実行していない。setup省略の正式な扱いは既存planner/activation validatorと実hosted full/mutation/selected観測で確定する。

## Model統合とreleaseの注意

- models worktreeの新suiteは observation/identity/policy/platform が `test`/`test-windows-heavy`、launch/installedが `posix-regression`。全てcategory保持group内。
- `tests/model-policy-installed.tests.py` のpackageは明示runtime closureを実installerで配置する。root READMEという名前を直接扱わず、これを理由にモデルsuite自体をREADME選択から落とす必要もない（group全保持）。
- wiring worktreeだけにはモデルsuite登録と最新current-byte payload処理が未統合。両者とWindows修正が入った最終Bでinventory/queryとmutationをやり直す必要がある。
- root READMEのrelease行、`tests/validate-repository.ps1` のexpected versions/regex、`tests/repository-release-validation.tests.sh` のliteral version、両marketplace、plugin manifest、CHANGELOGは同じrelease契約。version bumpはREADME-only変更ではなく複数path変更なので、このcategoryを適用しない。
- READMEのみを誤release値へ変えるMはvalidator/release-validationで失敗するはずだが、予想やこのソース調査は実hosted mutationの代用ではない。

## 最終Bでhash対象にするsource path一覧

README.md自身は変更入力であり、以下はconsumer実装・登録・依存の候補一覧。activation packetのconsumer.suites/groupsはcategory定義と完全一致させる。source一覧の各pathをBから取得し、その保存bytesをhashする。現在値のhashはまだ作成しない。

```text
.github/workflows/test.yml
tests/verification-catalog.json
tests/verification.py
tests/verification-impact.py
tests/verification-workflow.py
tests/verification-ci.py
tests/run-ci-unwired.sh
tests/run-all.sh
tests/run-all.ps1
tests/validate-repository.ps1
tests/validate-repository.sh
tests/repository-release-validation.tests.sh
scripts/bump-version.sh
tests/bump-version-gate.tests.sh
tests/bump-version-gate.tests.ps1
tests/component-path-ownership-parity.tests.sh
tests/component-path-ownership-parity.tests.ps1
tests/workflow-documentation.tests.sh
tests/design-system-contract.tests.sh
tests/design-system-contract.tests.ps1
tests/doc-diagrams.tests.py
tests/doc-diagrams.tests.sh
tests/doc-diagrams.tests.ps1
tests/spec-review-loop.tests.sh
install-payload.txt
install.sh
install.ps1
tests/install.tests.sh
tests/install.tests.ps1
tests/lib/install-payload-check.py
tests/installer-idempotency.tests.ps1
tests/install-cloud.tests.py
tests/windows-powershell.tests.ps1
tests/lib/current-byte-capture.py
tests/current-byte-capture.tests.py
tests/compatibility-byte-identical.tests.sh
tests/compatibility-byte-identical.tests.ps1
tests/cli-hook-enforcement.ps1
plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh
plugins/sdd-quality-loop/scripts/generate-guard-invariants.py
plugins/sdd-quality-loop/references/guard-invariants.json
plugins/sdd-quality-loop/scripts/generated/guard_invariants.py
plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js
plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1
plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh
plugins/sdd-quality-loop/hooks/claude-hooks.json
plugins/sdd-quality-loop/hooks/hooks.json
plugins/sdd-quality-loop/hooks/copilot-hooks.json
tests/model-policy-installed.tests.py
```


## 最終候補スナップショットの追記（2026-11-04）

今回読み取り確認した固定コミットは **`979878638d9f8f1c8decf992627f718c9c79c78b`**。stage 4の実際のtested mergeで、source head `8eb8e555` とGit treeが同一であることを確認した。これは最終候補Bのソース監査であり、まだ受入済みbaselineという意味ではない。実run `41836235053` のfull PASSとcollector/aggregateの `PASS / verified` がそろうまでBとして受け入れない。実行結果の代作やactivation packet生成は行っていない。

上の準備時点の「wiring側にモデルsuite登録・最新current-byte payload処理が未統合」という記述は、当時の調査履歴として保持する。この固定コミットでは解消済みであり、現在の欠落ではない。

- `readme-contract` は引き続き `paths=["README.md"]`、空のprefixes/suites、`active=false`、`evidence=null`。上記19 groupを保持し、workloadの省略候補は `cli-hook-enforcement` のみ。`required-checks` は収集・検証側として残る。CLI jobは3 OS matrixとci-planの明示条件を持ち、setup宣言の範囲も以前の説明と一致する。
- モデル6 suite（observation、identity、policy、launch-platform、launch、installed）がcatalog/profileに統合済み。前4本は `test` / `test-windows-heavy`、後2本は `posix-regression` に属し、すべて保持group内。
- `tests/lib/current-byte-capture.py` はGit追跡bytesを読む `indexed_source()` とmanifestを独立解釈する `files_only_payload()` を備え、READMEの配布bytesを検査する。`install-payload.txt` はroot READMEを明示収録する。モデル復旧のpackage/installed検証も統合済み。
- READMEのrelease/version（PS validatorの先頭release行チェック）、release-validation、bump/ownership-parity、workflow/design-system説明、doc-diagrams、installer/local/archive/Windows ZIP、cloud installer、current-byte capture、spec-review symlink負例を固定Git blobsで再確認した。今回、新しいroot README consumerやCLI jobへの依存追加は見つからなかった。source inventoryは**52件のまま**で、すべてこのコミットのregular Git blobとして存在する。

### CLI省略候補の現在の静的trace

過去のstrace記録には対象全ファイルを束縛する保存hash一覧がないため、今回のBと過去実測対象がbyte-identicalとは主張しない。全suiteやstraceを再実行せず、固定Bで次の経路を読み直した。

1. workflowはCLIを導入・存在確認し、`tests/cli-hook-enforcement.ps1` を起動する。READMEを引数として渡したり内容を読むstepはない。
2. suiteは一時 `tasks.md`、一時 `src.js`、synthetic configに対するEdit payloadを作り、JS/PS/SH guardを直接呼ぶ。CLI自体は `Get-Command` で存在を確認する。3 hooks JSONを読むconfig drift検査も同じ範囲。
3. SHは横のgenerated moduleを読み、PythonまたはPowerShellへ同じpayloadを渡す。native guardは横のgenerated invariants、一時payloadの対象ファイル、SDD_SUDO/鍵経路を扱う。このEdit経路でroot READMEや全repository contentsを取得する経路は見つからなかった。guardのREADME言及は `docs/ci-staging/README.md` の説明コメント。
4. generatorのcanonical入力は `references/guard-invariants.json`。READMEは生成入力ではない。今回の静的調査をhosted CLI実動作やWindows/macOS syscall観測とは扱わない。

確認した代表bytesのSHA-256:

| 固定Bのsource | SHA-256 |
| --- | --- |
| `tests/cli-hook-enforcement.ps1` | `91b4b5db08e87db8aeb0e01c6d2f9fbac86f5cda22c22f9bc100f7afb65eec3b` |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `3de96f9ca3d80986bc3e2f24b91796f1a0e29fa0fb0324cba6d055fe280f3d03` |
| `tests/lib/current-byte-capture.py` | `88ca540e883f507abf6cfeec5557b51eae26a1f7ca1b06e7ea5bcaffbbaa0dde` |

52件の順序は上のtext一覧どおり。各B blobの `{path, sha256}` を配列にし、Python `json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()` でUTF-8化した一覧のSHA-256は `c63fe74d01f3d4052aadbf2118b88237d02142e7a115c683c6f746efcaaeafc2`。これはソース監査の束縛であり、CI成功・mutation検出の証拠ではない。

準備済みM **`da9d9daa2c559edb338f22abec013efeb35ac1a7`** はこのBとのdiffがREADMEだけで、先頭release token `v1.23.0` → `v0.0.0` の1箇所以外は同じbytesであることを確認した。hosted mutationは未受入であり、実runの完全な失敗検出・証跡検証を待つ。Bのworkflow/catalog/consumer/execution定義に変更が入れば、この追記とsource digestを新Bで更新し直す。

## B2への更新（2026-11-04）— 旧Bは未受入のまま失効

前節の候補B `979878638d9f8f1c8decf992627f718c9c79c78b` は、実CIでA2の保存済みworkflow候補が `ci-plan` を欠落させる回帰を検出したため、**baselineとして受け入れず失効**した。対応する旧M `da9d9daa2c559edb338f22abec013efeb35ac1a7` も現行の比較対象に使わない。旧runや旧静的確認をB2の成功証拠へ読み替えない。

現在の候補は **B2 `b0e7dd84929a747c56def8c17bd5a9b548829c76`**、実stage 4 tested merge。source head `a3489fed` とGit treeが同一であることをローカルGitで確認した。実runは `41844335263`（rootが確認した計画はfull 476 obligations / 0 omissions）。この追記の時点で**hosted結果待ち、未受入**であり、完全なfull PASSとcollector/aggregate `PASS / verified` が必要。

旧B→B2の全ソース差分は次の4ファイルだけだった。

- `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate`
- `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/MANIFEST.sha256.candidate`
- `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/README.md`
- `tests/lib/a2-workflow-evolution.py`

これはcurrent apply candidateの同期、対応manifest/provenance、およびplanner依存・条件とcollector弱化を拒否する検証の修正。歴史archive/pinは不変である。これらはroot READMEを読み取る新しい経路を追加していない。A2検証は保持側のversion/capability jobsで実行される。

監査済み**52 sourceすべてを旧BとB2のGit blobで比較し、変更0件**を確認した。この集合にはlive workflow、CLI suite、4 guard、generator、canonical invariants、generated modules、3 hooks configsを含む。したがって前節の固定ソース静的traceはB2でも同じbytesに適用でき、今回の更新のためにfull suiteやstraceを重複実行する必要はない。過去のstrace自体をB2のhosted実行証拠として扱わない。

B2のcategoryもREADMEのみ、19保持group、空のsuites/prefixes、`active=false` / `evidence=null` のまま。source inventoryは52件を維持する。前節と同じ順序・JSON encodingで算出した一覧SHA-256は引き続き **`c63fe74d01f3d4052aadbf2118b88237d02142e7a115c683c6f746efcaaeafc2`**。ただしB2用consumer packetの `baseline_revision` は必ずB2を使い、旧Bの参照を転記しない。

新しい比較候補 **M2 `f2791476dbb9ef7290c9f8908cb9f70d94ffda57`** はB2を祖先に持ち、B2との変更がREADMEだけで、先頭release tokenの `v1.23.0` → `v0.0.0` 以外はbyte-identicalであることをローカルGitから確認した。履歴の通常mergeによる再利用であり、旧Mの実行結果を使い回さない。rootでの局所的な期待失敗確認は、実M2 runの検出結果の代用ではない。実B2/M2結果がそろうまでproof生成・catalog変更・activationは行わない。


## B3への更新（2026-11-04）— metadata fixtureの修正後

現在の固定候補は **B3 `7fd1385a8e120ef36ef8b575996fff4f2ee422f8`**、実stage 4 tested merge、run **`41848390750`**。前候補B2 `b0e7dd84929a747c56def8c17bd5a9b548829c76` と対応M2を現行の受入・比較対象として扱わず、新しい実行結果に束縛し直す。今回の追記はソース監査であり、B3のfull PASSや `PASS / verified` を宣言するものではない。実際のcollect/aggregate結果の確認後にのみ受入を確定する。

B2→B3の実Git差分は **`tests/emit-run-record-feature-scope.tests.sh` 1件だけ**。修正 `eb504bf0` はmetadataのv1/v2ケースに別feature名を与え、出力が各1件で期待schemaであることを確認する。従来の同feature・timestamp付きファイルのglob先頭選択による混同を解消している。emit-run-recordの製品実装やworkflow/catalogは変更していない。

このテストは独立した一時ディレクトリにtasks・gate reports・review tickets等を生成し、対象emitterを呼ぶ。今回変更したmetadataケースも一時tasksとrun recordを扱い、root READMEを読む経路を増やしていない。catalog上のこのBash suiteは `ci-posix-fallback` とlocal profileに登録され、fallbackの実行は保持側 `posix-unwired-sharded` に属する。旧失敗を無視したのではなく、修正後のB3全実行で再確認する。

既存の**52 sourceの全Git blobsをB2とB3で比較し、変更0件**。CLI suite・guard・generator・generated invariants・3 hooks configs・live workflowを含むため、前節の静的依存traceとcategoryの保持範囲はB3でも同一bytesである。source inventoryは52件のまま、一覧SHA-256も **`c63fe74d01f3d4052aadbf2118b88237d02142e7a115c683c6f746efcaaeafc2`** を維持する。B3のためにfull suiteやstraceは重複実行していない。過去straceの全入力hashが保存されていないという制約はそのままであり、それをB3のhosted証拠とは扱わない。

B3用パケットでは `baseline_revision` を必ずB3へ更新し、対応する実mutation commit/runを別途確認する。旧B/B2のplan/resultや旧M/M2の結果を差し替え・再利用してB3成功やmutation成功を作らない。この追記ではproof生成・catalog変更・activationは行っていない。


## B4への更新（2026-11-04）— Intel macOSと安定チェック名

現在の固定候補は **B4 `e16d5e53da0cde946f5cba98f11757b12fdad50d`**、実tested merge、run **`41864101017`**。B3 `7fd1385a8e120ef36ef8b575996fff4f2ee422f8` と旧M3の実行・証跡はB4の受入・比較に流用しない。B3は新しいrunner/workflow定義に置き換えられた旧候補であり、この監査で成功したbaselineとは扱わない。**B4も実CI全件とcollect/aggregateの確認が終わるまでは未受入**。GitHub Actions障害中はJobs APIと成果物の更新時刻が一致しない場合があるため、待機表示だけでもartifactの存在だけでも成功を確定しない。

B3→B4の全差分はIntel prerequisiteを統合した10ファイル。既存52 sourceのうちbytesが変わったのは次の3件だけだった。

- `.github/workflows/test.yml`
- `tests/verification-impact.py`
- `tests/verification-workflow.py`

- live workflowは標準 `macos-26-intel` を指定し、main testの40分制限を維持する。ブランチ保護が要求する表示名 `test (macos-latest)` は `matrix.check` で維持する一方、`matrix.os`、`runs-on`、計画と実行のrunner labelにはIntelを記録する。testのreceipt名も `matrix.check` と対応する。表示名はARM64実行を意味しない。
- planner/workflowの明示runner集合にIntelを追加し、既存 `macos-latest` は保持する。未知runnerの拒否も維持。対応schemaとlive期待値、両label/未知labelの回帰検証、公開検証説明を更新している。
- unsigned A2 current candidateとmanifest/provenanceは統合後workflowへ同期。歴史archive/pinは不変。`ci-plan`、`required-checks`、A9両jobの定義はB3と同一で、今回の差分にroot READMEを読む新しい経路はない。

統合レビューではrunner変更・安定表示名・receipt名の意図した差分だけを正規化するとworkflow AST全体がB3と一致すること、全476 obligationsとnative macOS144項目のstep/suite/receipt要件が残ることを確認済み。新しいラベルでの実行結果を以前のARM候補から作らず、Intel macOS 26の実行とARM64未確認を区別する。

CLI jobの入力経路は変更されていない。workflow上のrunner選択は変わるが、**CLI suite、4 guard、generator、canonical invariants、generated modules、3 hooks configsの14 sourceはB3とbyte-identical**。root READMEを読む経路の追加はなく、52 sourceのpath集合を維持する。live category/catalog自体もB3と同一（READMEのみ、19保持group、空のsuites/prefixes、inactive/evidenceなし）。

B4のregular Git blobsから同じ順序・JSON encodingで算出した52-source一覧SHA-256は **`e89891bc8295a663e529e8bdcbde2faa526ae8b16683dff7818e7e818c6861f6`**。以前の `c63fe74d…` は旧候補にだけ対応するため、B4 packetへ転記しない。各consumer sourceのhashもB4 blobから作り直す。

この追記はread-only静的確認であり、新たなstraceやnative実行は行っていない。過去straceの全入力hashがない制約は維持し、過去観測をB4のhosted実行証拠へ昇格しない。B4用の実mutation commit/runと完全な比較結果がそろうまで、proof生成・catalog変更・activationは行わない。


## B5への更新（2026-11-04）— 実測に基づくIntelの実行時間枠

固定候補は **B5 `6852656019e50e62738d920261989a4bb2921e2d`**、実tested merge、run **`41875299187`**。元plan ZIPのAPI digestと取得bytesを照合し、full/shared-change、476 obligations・省略0件を確認した。B4と対応M4は時間枠変更前の未採用実行として保持する。**B5も全件実行とcollect/aggregateの確認前であり、未受入**である。

B4→B5の全差分は6ファイル。live workflowとunsigned A2 candidate・manifest・説明、検証の公開説明、復旧進捗文書である。live workflowの変更は、test/installers/version-gates/cloud-nativeの4ジョブについてIntelの場合だけtimeoutを90分にするもの。旧runでは検査が進行する途中の30分・40分の時間切れを観測した。全476実行義務とmacOS144項目、コマンド・条件・receipt要件・必須チェック名を保持し、他OSと軽いジョブの時間枠も変更していない。候補の同期はunsigned currentだけで、歴史archiveを変更していない。

既存52 sourceを全件Git blobで比較し、変更は **`.github/workflows/test.yml` の1件だけ**だった。実行コマンドや入力経路の変更はなく、新たなREADME consumerは追加されていない。CLI suite、guard、generator、generated invariants、hooksの静的traceはB4と同じbytesを対象とする。catalogも同一で、READMEのみ・19保持group・inactive/evidenceなしを維持する。

同じ順序・JSON encodingで算出したB5の52-source一覧SHA-256は **`36063d3351b34743e6ea483fd8166cfc6346fe904f2c901870a378c8c6d8bdf6`**。packetの各source hashとbaselineはB5から生成し、旧候補のdigestや成功を流用しない。この更新はソース差分の確認であり、過去straceをB5の実動作証拠とは扱わない。新しい実M5のREADMEのみの変更・失敗検出と、B5のfull成功を別々に確認してから受入を判断する。


## B6への更新（2026-11-04）— Git保守と起動待ちのfixture修正

固定候補は **B6 `aa7ba8d3b59399f0c69a6cfa59c3d35a65b1414a`**、実tested merge、run **`41886656823`**。元plan ZIPとAPI digestを照合し、full/shared-change、476 obligations・省略0件を確認した。B5/M5には実macOSでA9の一時Git削除エラーがあり、別の実CIではslow-start fixtureが期限を5ms超えた。検証コードを修正するため、旧実行は未採用のまま保存し、B6の成功に読み替えない。**B6も全件結果とcollect/aggregateがそろうまでは未受入**である。

B5→B6の変更は2ファイルのみ。

- `tests/a9-advisory-evidence.tests.py`: fixtureのcommit前に既存installer fixtureと同じrepo-local設定を適用し、Gitの背景保守を止める。実Git traceでcommit後もrepackが書き込むことを確認し、修正後の未起動を検証した。負例の拒否判定と厳密cleanupは維持する。
- `tests/cross-model.tests.sh`: 固定3秒のsupervisor待機を、改変していない実deadline receiptからの絶対待機へ変更する。未公開・空receiptの待機を10秒に限定し、不正内容・他のI/Oエラーは拒否する。500ms出力、期限前完了、実child終了、expiry後の再確認などの既存assertionを維持し、旧相対待機の負例も失敗することを確認した。

両方は保持group側のfixtureであり、製品のGit設定・時計・期限判定や新しいREADME consumerを追加していない。既存**52 sourceの全Git blobsはB5と同一**で、workflow/catalog、CLI省略候補の入力経路も同一である。一覧SHA-256は **`36063d3351b34743e6ea483fd8166cfc6346fe904f2c901870a378c8c6d8bdf6`** を維持するが、consumer packetのbaselineと実行証拠は必ずB6へ束縛し直す。新しいM6のREADMEだけの変更と実検出結果を確認するまでactivationは行わない。


## B6/M6 の実受入結果（2026-11-04）

最終 B6 は **`aa7ba8d3b59399f0c69a6cfa59c3d35a65b1414a`**。実 Actions run [41886656823](https://github.com/aharada54914/sdd-forge/actions/runs/41886656823) の attempt 2 が全52ジョブ成功し、元の計画と未改変の collector/aggregate により **PASS / verified、476義務すべてPASS** を確認した。元の計画は epoch 1 のまま、実行元は attempt 1 の442義務と、再実行した macOS 本体の attempt 2 の34義務である。再実行していない成功ジョブを attempt 2 の新規実行として数えていない。

初回は macOS 本体が90分の上限に達し、集約は442 PASS・34 FAILだった。この失敗記録と元のAPI応答を保持した。該当ジョブの個別ログも全体ログZIP内の記録も取得できず、根本原因は特定していない。同じソースで1回だけ行った失敗ジョブの診断再実行では、停止表示だった panelist-input Bash step が28秒、macOS 本体が50分35秒で成功した。初回成功や原因解決の証明とは扱わない。

比較対象 M6 は **`59046067a2b51a2e38cf42c748c2dc2b0f98689b`**。B6を祖先に持ち、差分はREADME冒頭のrelease tokenを `v1.23.0` から `v0.0.0` に変える1箇所だけ。実 run [41887468670](https://github.com/aharada54914/sdd-forge/actions/runs/41887468670) は取消なしで全52ジョブが終了し、Windows・Ubuntu・Intel macOSの直接validatorが誤版を拒否した。元の計画と実収集結果による集約は **FAIL / execution-failed、293 PASS・182 FAIL・1 EXPECTED_SKIP**。hosted集約とローカルの正規集約はbytesまで一致した。182 FAILはREADME不整合に起因する失敗またはその後の未実行として分類され、別原因の失敗は確認されなかった。既存のmacOS bump suiteにはBSD sedによる名前付きSKIPがあり、full計画を全内部ケースの実行成功とは表現しない。

B6/M6の固定Gitオブジェクトはそれぞれ `archive/ci-selection-v1.23.0-baseline` と `archive/ci-selection-v1.23.0-mutation` の注釈付きタグで保持した。B6の52-source一覧と前節の静的依存確認は変更なし。実パケットはこのB6/M6の元plan/resultから生成し、実際のCコミットで再検証する。README選択実行と同じtested revisionのfull比較、実測とリリース確認は別の後続作業であり、この受入記録で完了とはしない。
