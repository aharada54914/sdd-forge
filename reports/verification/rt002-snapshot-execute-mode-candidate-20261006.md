# RT002: snapshotの実行権限消失と共有修正候補

作成日: 2026-10-06 JST
種別: 読取専用調査と未適用の修正案。実装証跡・品質ゲート判定ではない。
対象checkout: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`
調査時HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`

## 結論

共有snapshot builderのBash版・PowerShell版は、Unixで入力ファイルを一律0444にする。RT002のBashテストはsnapshot内のshell wrapperを直接起動するため、この生成方針と両立しない。最小候補は、共有builder 2本と既存の対向テスト2本を修正し、通常ファイルの出力modeを `0444 | (検証済みsource mode & 0111)` とすること。ディレクトリ0555とWindowsの既存ACL処理は維持する。

これはRT002固有callerを別の実行方法へ変更する提案ではない。共有入力・実行境界の変更なので、既存RT002の限定適用範囲から切り離したhigh-risk修正として承認と検証が必要である。今回、ソース・installed baseline・snapshotは変更せず、テストも実行していない。

前回準備で生成したsnapshotのmode不整合を、今回callerと共有契約まで追跡した。既存のTASK_INPUT_OKはpathと内容SHAの検証結果であり、実行権限の保持を証明しない。

## 調査範囲と状態

一次資料はこのcheckoutのbuilder、caller、対向テスト、manifest schema、validator、関連仕様である。`rg`で `prepare-task-snapshot` の参照を探索し、該当ファイルを行番号付きで確認した。Git内部と生成snapshotの複製を除外した。scratch内はsnapshotとJSONを除き、handoffの参照も確認した。外部のinstalled checkoutや動的に組み立てられる未検出callerまで網羅したという主張ではない。

既存のtracked変更12件と未追跡の準備成果物は保持した。tracked変更は `.github/workflows/test.yml`、`AGENTS.md`、quality-loopのvalidator 2本とquality-gateスキル、review-loopのboundary参照、workflow-state-registry、およびtestsの5ファイルである。本提案でそれらを上書きしない。

今回の調査はfresh implementation起動ではない。新しい実装identity、reservation、費用実績は発行していない。以前のUSD 10.00は明示された暫定計画見積のままであり、vendor価格・計測usage・請求額・支出承認ではない。

## callerの追跡結果

以下の行番号は調査時checkoutに対するもの。パスはcheckout相対。

| 種別 | callerと根拠 | 意味 |
|---|---|---|
| 運用手順 | `plugins/sdd-implementation/skills/implement-tasks/SKILL.md:130-144`（builder:133、validator:134） | 共通builder対を起動する正式な手順 |
| 上位手順 | `plugins/sdd-ship/skills/ship/SKILL.md:270-275` | full経路からimplement-tasksへ委譲。別のbuilder実装ではない |
| Bash直接caller | `tests/task-context-isolation.tests.sh:7,109,242,260,270` | 正常生成、symlink拒否、親symlink拒否、公開競合。299はソース検査で起動ではない |
| PowerShell直接caller | `tests/task-context-isolation.tests.ps1:6,89,246,273,294` | 同じbuilder対の対向検証。294は子PowerShell経由の公開競合 |
| Bash suite登録 | `tests/suite-inventory.posix:33`、`tests/run-all.sh:9-25,39` | inventoryからsuiteをbashで起動 |
| CIへの接続 | `.github/workflows/test.yml:84`、`tests/run-ci-unwired.sh:6,120-131,144` | inventoryをshard選択しsuiteを起動。今回CI実行はしていない |
| PowerShell suite登録 | `tests/run-all.ps1:14,128` | PowerShell実体からsuiteを `-File` で起動。登録と今回の実行証跡は別 |

その他の一致は仕様内サンプル、過去の実装報告・manifest・handoff、rollback hash registry、guard inventory/generated mirrorであり、この探索では追加の実行callerは確認しなかった。

RT002側で実行bitを必要とする地点は `tests/check-hook-activation-handshake.tests.sh:81` の `"$HH_SH" "$@"`。固定対象は同53行の `plugins/sdd-implementation/scripts/check-hook-activation-handshake.sh` で、最初のhelper呼出しは131行にある。source modeは0755、既存準備snapshot内の対応ファイルは0444と確認した。したがってUnixでの直接起動失敗は静的に説明できる。ただし今回Permission deniedやexit 126を再実行で観測したわけではない。

外側のsuiteをbashで起動しても、81行の内側の直接起動は変わらない。PowerShell対向suiteは同名 `.ps1:85-90` で現在のPowerShell実体に `-File $HhPs1` を渡す既存経路なので同じexecute bitは要求しないが、それだけでBash側の受入条件を満たすわけではない。wrapper内部のPython dispatch（`.sh:18-20`、`lib/py-dispatch.sh:27-30`）より前に問題が生じる。

## 原因と現在の契約

`plugins/sdd-implementation/scripts/prepare-task-snapshot.sh:82` は全通常ファイルを0444にする。同204行の `open(target,"xb")` はsource modeをコピーしない。したがって最終chmodを単に「コピー先modeからwrite bitを除去」に替えても、既に失われたexecute bitを復元できない。source検証は同205-222行にあるが、変更検出の比較項目にmodeは含まれていない。seal後の確認（95-105行）はwrite bit不在を確認する。

PowerShell版も `prepare-task-snapshot.ps1:74` でUnixファイルをUserRead/GroupRead/OtherReadのみとし、source modeを伝播しない。同155-187行のcopy/hash/更新検出にもmode照合はない。Windows分岐36-71行はReadOnly属性とACL denyを使う別実装であり、Unix modeと同一視しない。

| 契約 | 現在の根拠と修正への制約 |
|---|---|
| immutable snapshot | `specs/agent-cost-context-isolation/requirements.md:94-103`（REQ-007）、`design.md:94-105`、`security-spec.md:3-8`。nofollow、変更検出、hash確認、atomic公開、read-onlyを要求。正確な0444を要求する記述は確認しなかった |
| manifest v1 | `contracts/task-input-manifest.schema.json:75-90`。入力はpathとsha256のみ、additionalProperties:false。mode項目を無断追加できない |
| validator | `validate-task-input-manifest.sh:121-155,253-276`、`.ps1:178-200`。path・通常ファイル・SHAを検査するが、execute保持やmodeの一致は検証しない |
| 既存受入 | `specs/agent-cost-context-isolation/acceptance-tests.md:33-40`（TEST-003）。manifest・cost・hash・path・symlink・mutationの対向ケース。execute保持ケースはない |
| 既存task | 同 `tasks.md:139-198` のT-003はApproved / Implementation Complete / high。今回その状態や凍結仕様を変更する権限はない |
| 保護範囲 | `plugins/sdd-quality-loop/references/guard-invariants.json:59` にBash builder登録。PowerShell版の同じ明示登録は確認していないが、対向修正も共有境界のhigh-risk変更として扱う |

## 最小の共有修正候補（未適用）

対象コードは次の4ファイルに限定する。wrapper、RT002のテストcaller、manifest validator/schema、installed baselineを便乗変更しない。

1. `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh`
2. `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1`
3. `tests/task-context-isolation.tests.sh`
4. `tests/task-context-isolation.tests.ps1`

Unix通常ファイルごとの処理は以下とする。

- nofollowと既存identity検査を維持し、コピー元の検証済みfile identityに結び付いたmodeを採取する。Bashは既存fstatを利用する。PowerShellは対応runtimeで使用できるhandle由来mode APIを実装前に確認する。安全に採取できなければfail closedとし、別executorへ切り替えない。
- コピー前、open後、コピー後、最終path確認でmode変化も拒否する。既存のsource-changed分類であるTASK_INPUT_HASHを使い、公開しない。mode変化の途中復帰まで完全に検出できるといった保証は加えない。
- 採取したexecute maskをコピー先ごとに保持し、公開前に `0444 | (source_mode & 0111)` を設定する。write bitとsetuid/setgid/stickyは付与しない。拡張子やshebangからexecute bitを推測しない。
- 公開前に期待modeそのものを照合する。ディレクトリ0555、内容SHA照合、fsync、atomic no-replace公開、失敗時の所有temp cleanupは維持する。
- Windows既存分岐は変更せず、Unixの権限保持をWindowsの実行制御保証と称さない。

例: source0755→0555、0750→0554、0700→0544、0644/0600→0444。execute bitが一つでもある場合に一律0555へ昇格させる案は、元にない実行権限を与えるため採用しない。既存の全read bit付与はこの限定修正では維持する。

### 必要な契約合意

非凍結の承認記録に、REQ-007 / designのsnapshot生成節 / security-spec / TEST-003 / implement-tasks手順へのaddendumとして、上記mode式、source mode変更時の拒否、公開前mode確認、Windows非変更、下記テストを規定する。凍結済み仕様やtask状態を今回書き換えない。正式に仕様を再bindする必要がある場合は別の承認済み手続で行う。

この最小案は「builderがコピー時のsource execute maskを保持する」契約であり、manifest v1のschema変更は不要。ただし内容SHAにはmodeが含まれないため、公開後のexecute-bit-only改変を既存validatorが検知するとは主張できない。同一ユーザーに対するchmod可能性までread-only modeが完全な隔離を提供するわけでもない。

独立した再検証でmode provenanceも束縛する要件を採用するなら、v1への項目追加ではなく、versioned schema、paired validators/builders、caller・fixture移行を含む別の拡張承認が必要。この拡張は今回の最小候補に含めない。この境界を承認時に明記する。

## 実装承認後に必要な検証（全て今回未実施）

| ケース | 具体的な期待値 |
|---|---|
| source execute保持 | Unix対向suiteで0755/0750/0700/0777をコピーし、対応する正確なmaskとwrite/special bit不在を確認 |
| 非実行入力 | 0644/0600、shebang付き非実行 `.sh` が0444のまま。直接起動失敗と副作用なしを確認。interpreterでの再実行を代替成功にしない |
| 拡張子に依存しない | 実行可能な拡張子なし/`.txt` fixtureのexecute maskを保持 |
| 直接起動 | executable fixtureをsnapshotから直接argv起動し、宣言済み出力先への期待出力のみを確認 |
| 特殊bit | source setuid/setgid/stickyを保持しない。fixtureの設定可否と環境制約は別記し、未実行をPASS扱いしない |
| mode-only source変更 | 内容を変えずcopy中にmode変更した場合TASK_INPUT_HASH、final snapshot不在。決定的な同期fixtureを用い、sleep競争にしない |
| 既存不変条件 | source bytes/modeを変更しない。非特権identityでsnapshotへのwrite/create/deleteが拒否される。symlink、置換、hash不一致、escape、公開競合、cleanupの既存負例を維持 |
| runtime parity | Unix Bash/PowerShellの期待modeが同じ。native Windowsの既存属性/ACL/write/delete検証を維持し、Unix専用caseとの適用範囲を明記 |
| RT002の復帰 | 受入済みbuilder/baselineの下で新manifest・新snapshotを作り、元のRT002 Bash/PowerShell suiteを変更せず必要条件で実行。旧snapshotをchmodしない |

既存publication barrierはseal後（Bash227-228、PowerShell189-190）なので、copy中mode変更の証明には使えない。実装時には既存harnessで安全な同期を組めるか確認し、不可能なら必要最小限のtest-only copy同期を別途レビューする。新しい汎用frameworkは導入しない。

## 次の承認単位と未完了点

共有builder対を一つの修正ownerへ割り当て、4コードファイルと非凍結契約addendum、対向検証を一つのbounded high-risk repairとして承認する。適用前には保護対象・現HEAD/dirty・baselineのversion/hashを再確認する。source modeという証拠項目、契約側のmode式、failing mismatch testをpreflightへ対応付ける。保護適用は既存の正規経路だけを使う。

その後の順序は、負例を含むTDD、正規適用/readback、独立review、必要な品質ゲート、exact-final-head CI、明示承認されたbaseline採用、RT002の新規実装準備である。これらの完了は本調査から推定しない。新準備では実際のfresh session/model/providerと許可された出力先を使う。今回のcompaction済み調査contextをfresh implementation identityに見立てない。

未完了: 修正承認、実装、modeの安全なPowerShell採取方法のruntime確認、決定的なmode-race fixture設計、全てのproduct test、独立review、品質ゲート、CI、baseline採用、RT002再検証。本ファイルの保存以外に変更は加えていない。

文書確認: natural-japaneseのlintを1回試行したが、既存Python環境にsudachipyがなく起動失敗した。依存の追加はせず、結論・根拠・提案・未実施の区別を手動確認した。これはproduct testの実行ではない。
