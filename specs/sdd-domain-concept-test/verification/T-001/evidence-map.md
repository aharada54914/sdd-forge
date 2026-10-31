# T-001 検証追補（2026-10-02）

## 2026-10-06 署名発行から標準validatorまでの実経路

`generate-approval-sidecar.py` に Concept Test の Human/CI 署名発行経路を追加し、
一時鍵・登録済み架空承認者の隔離環境で署名→既存 `apply-human-copy.sh` 公開→
標準 validator の順に通した。これは実運用の Human/CI 署名発行ではない。
validator は `--expected-feature` がない標準CLIでも JSON `feature` と
`specs/<feature>/concept-test.json` / `concept-test.approval.json` の配置を
照合する。T-003 caller は別途、稼働中 feature を同引数で渡す責務を持つ。

独立診断で検出した無指定時の配置素通り、署名preflight前後の内容変更、
通常CIへの新suite未接続を修正した。Python統合 4/4、既存validator
Bash 115/0・macOS PowerShell 114/0、既存signer Bash 69/0・PowerShell
67/0、CI配線suite 20件、`git diff --check` 終了0。全て現行ローカル
ファイルに対する実行出力であり、完全な生ログは保存していない。CI自体、
native Windows、T-003 bootstrap、正式独立実装レビュー、quality-gate、
Implementation Complete / Done は未実施・未認定のまま。

## 2026-10-06 承認済み候補の適用と現行照合

以下は新しい現行証拠であり、下の各時点の記録を履歴として保持する。承認済み
minItems テスト候補を事前ハッシュ照合とバックアップ後に適用し、両ドライバの
SHA-256 を Bash `b39767190ee83d88f17055f67f273db35535e14395e203b84533e54f83c89bc8`、
PowerShell `75dede41bdb9aeeec9fdfb5965107897ea19febf4b4eab089313d49d13f7c366`
と読み戻した。validator 自体は `5f1fe69df13bc90baac757aefa56e2e36c82a175b6db1000cee71592e22cbc74`
のまま。macOS の実行出力で Bash 115 PASS/0 FAIL、PowerShell 114 PASS/0 FAIL、
両終了コード0を確認した。新規2件は `inputs` の1件許容・0件拒否である。
完全な新規生ログは保存していないため、旧保存ログをこのハッシュの実行証拠とは扱わない。

改訂 task plan は attempt-7/round-1 で独立 reviewer A/B の canonical 出力を取得し、
それぞれ PASS（A: 14 PASS、B: 7 PASS/2 SKIP、finding 0）。統合判定 PASS、
`check-workflow-state.sh --feature sdd-domain-concept-test` 終了0・`workflow-state: ok`。
記録は `reports/task-review/sdd-domain-concept-test/attempt-7/round-1/` にあり、
これは task provenance の再束縛だけで実装 quality-gate の判定ではない。
T-001 は Approved/In Progress のまま。native Windows、現行 HEAD の CI、
独立実装レビュー・quality-gate・Done は未確認。

## 2026-10-06 実装完了と全体ゲートの順序

`implement-tasks/SKILL.md:72–79,235–258` では依存タスクの着手条件は
先行タスクの Implementation Complete または Done であり、全承認済みタスクが
そのいずれかに達するまで feature quality-gate を起動しない。
`sdd-ship/SKILL.md:269–291` も同順序である。従って T-001 は validator
側の実証と実装報告・独立実装レビューが揃えば Implementation Complete へ
進められるが、この時点では Done ではない。共有 TEST の bootstrap 側断言は
T-003 が後で実行し、T-004 が全 REQ/AC/TEST と実証済み証跡を feature-root
`traceability.json` に揃えてから品質ゲートを実行する。

これは既存のゲート契約の順序確認であり、部分的な feature-root JSON の作成や
`check-traceability` の緩和を許さない。現 checker は列挙済みリンクだけを
検査するので、T-004 の full-table expected-ID/断言照合は引き続き必要。
独立実装レビュー、T-001 の Implementation Complete 移行、全体ゲートは未実施。

## 2026-10-03 人間適用後の照合（以下の表示番号未修正記述に優先）

人間が2パッチを一括適用した後、Bash ドライバ SHA-256 は `72511d69f5407e5f186beb3b32ebb8c5a0fa47b94807f319341f04429dad43e6`、PowerShell ドライバは `a8ed8ee80504e1ff75fbe38c1f33e8a3e614b0c38906f38a88a2d6e19fa7eb09`、`tasks.md` は `fe1899d1a9f5ded503278ca4ae9e0f456798d1f7cda6a1d3147e675ba75d100a` と照合した。Done When の報告書パスは既存の feature 配下へ訂正済み。両ドライバの検査条件を変えず、FITS `TEST-037/078`、NEW `TEST-075`、CONFLICT `TEST-076`、HUMAN `TEST-077` の表示を実行結果で確認した。

macOS で `rtk proxy bash tests/validate-approval-sidecar.tests.sh` は終了0・113 PASS/0 FAIL、`rtk proxy pwsh -NoLogo -NoProfile -File tests/validate-approval-sidecar.tests.ps1` は終了0・112 PASS/0 FAIL。`rtk proxy python3 specs/sdd-domain-concept-test/verification/T-001/check-validator-rollback.py` は終了0・6 PASS/0 FAIL。これらは今回の実行出力による確認で、新しい完全ログファイルは保存していない。旧ログの表示番号は履歴として変えない。

タスク本文のハッシュ変更で旧 task-review 束縛は stale。直近 attempt-3/round-1 の PASS を前提に、attempt-4/round-1 の `--provenance-rereview` precheck は終了0で、normalized `tasks_sha256` は `4cedf3755cb0bf8068d840d866b5e22adf9df52cea1933840980338464599ec2`。独立A/Bの新予約・判定は未実施。T-001 は In Progress のままで、native Windows・CI・quality-gate・Done は未検証。

## minItems 修正後の現行証拠（以下の旧ハッシュ・生ログ状況に優先）

対象 validator SHA-256: `5f1fe69df13bc90baac757aefa56e2e36c82a175b6db1000cee71592e22cbc74`。保存済み `sidecar-bash-minitems-20261002.log` は113 PASS/0 FAIL（SHA-256 `a86ce919643e47dd7b0213f810c080294278c5f915a2beebf25eab73bc8e8b9f`）、`sidecar-pwsh-minitems-20261002.log` は112 PASS/0 FAIL（SHA-256 `c3429cb46d5abe0a22b3ae718acf8670f08efa0371b2c76ef41ee7497b9da545`）。両終了コード0、実行環境macOS。旧 `primary` ログは修正前の証拠として保持する。

AC-016 の decision 不一致は全4分類で実行済みだが、ドライバの表示番号が仕様とずれている。生ログは改変せず、`acceptance-tests.md:57–60` を正本として次の対応を記録する。両ログの行番号は共通。

| 仕様の TEST-ID | 分類 | 生ログの表示 | ログ行 |
| --- | --- | --- | --- |
| TEST-075 | NEW_CONCEPT_CANDIDATE | TEST-076 | 87 |
| TEST-076 | RESPONSIBILITY_CONFLICT | TEST-077 | 94 |
| TEST-077 | REQUIRES_HUMAN_DECISION | TEST-078 | 101 |
| TEST-078 | FITS_EXISTING_CONCEPTS | TEST-037/075 | 80 |

これは validator の拒否動作の対応表であり、テスト表示番号の修正済み宣言ではない。保護対象の両ドライバの番号修正、独立 quality-gate、CI・統合は未完了。各 AC の bootstrap 下流呼出0は T-003 の担当で、ここでは未検証のままとする。

## 以前の記録（履歴として保持）

最新追補: 主担当が両 sidecar suite を再実行し、Bash 113 PASS/0 FAIL、PowerShell 112 PASS/0 FAIL、終了コードはいずれも0。完全な出力は同ディレクトリの `sidecar-bash-primary-20261002.log` と `sidecar-pwsh-primary-20261002.log` に保存済み。以下の「生ログなし」はそれ以前の実行記録であり、この2 suite についてのみ解消した。実行環境はmacOSであり、native Windows・独立 quality-gate・CI・統合の証明ではない。

対象は現行の Concept Test 契約・署名付き証跡 validator。仕様・task plan・traceability の凍結本文は更新しない。以下の「実行観測」は `reports/implementation/sdd-domain-concept-test/T-001.md` の同日 continuation に記録された macOS 実行結果であり、この追補作成時の再実行でも、保存された完全な生ログでもない。対象 validator SHA-256: `01411086bb889967f62b33249a0f42b0399f1945ec98f7f0a25f8576fe46bcd1`。

| REQ / AC / TEST | 対応する現行ドライバの検査 | 証拠の範囲・残る差分 |
| --- | --- | --- |
| REQ-001/003; AC-001/006; TEST-001/006 | `tests/validate-approval-sidecar.tests.{sh,ps1}` の FITS 正例は、feature・proposal・rationale・relation・入力 hash を持つ JSON と固定形式 md、登録済みテスト承認者・一時鍵の署名 sidecar を実 validator に渡す。 | 証跡妥当性のみ。Concept Test の提案作成や bootstrap 続行は未検証。 |
| REQ-001/003; AC-002〜005; TEST-002〜005 | 両ドライバは非 FITS 3 種の decision 欠如、JSON 不在を拒否する。 | validator の BLOCK。bootstrap の下流呼出 0 は未検証。 |
| REQ-003; AC-007; TEST-007/015〜022 | 両ドライバは非 FITS 3 提案 × 3 decision の署名付き正例を検証する。 | `defer-to-domain-update` / `rejected` を含む証跡妥当性であり、TEST-022 の bootstrap 停止・下流呼出 0 は未検証。 |
| REQ-003; AC-014/015; TEST-014/028〜034 | 両ドライバは破損 JSON、未知 enum、sidecar 不在、HMAC 改ざん、鍵不在、未登録承認者、decision 文字列のみを拒否する。 | 実 validator の拒否検査。署名生成を人間/CI のみに限定する運用の実地証明ではない。 |
| REQ-003; AC-016; TEST-035〜037/051〜078 | 両ドライバは読取入力の変更・不在を拒否し、4 提案それぞれで md/json の feature・proposal・rationale・relation・入力 path/hash・decision の不一致を拒否する。 | md 全文比較の追加変種もある。TEST-051〜078 および TEST-075〜078 に書かれた bootstrap 下流呼出 0 は未検証。 |
| REQ-002; AC-008/009; TEST-008/009/023/024 | T-002 の人間確認・未来のみの候補・`domain/` 不変性に属する。 | T-001 ドライバの relation enum は人間確認手順の証拠にならない。未検証。 |
| REQ-004; AC-010/011/017; TEST-010/011/038〜046 | T-003 の bootstrap 呼び出し順・分岐に属する。 | 未検証。T-001 の TEST-022/035/075〜078 のうち下流呼出に関する断言もここで未検証。 |
| REQ-005/006; AC-012/013/018; TEST-012/013/025〜027/047〜050 | T-004/T-006 の review-context と公開面に属する。 | T-001 の証拠対象外。未検証。 |

実行観測: Bash sidecar 113 PASS/0 FAIL、macOS 上の PowerShell sidecar 112 PASS/0 FAIL、Phase 0 schema 正例 8 件、v2 schema の Bash/PowerShell 78 fixture parity（終了 0）。これらは各ドライバ全体の集計であり、上表の TEST-ID ごとの独立実行記録ではない。生ログ、native Windows、CI、独立レビュー/quality-gate の証拠はない。

T-001 の validator-side rollback は `check-validator-rollback.py` により6件成功・終了0。固定コミット `badbb7aa5d16114be542c33018967c58770d1a41` の実 validator を一時ディレクトリへ展開し、既存2形式の署名付き承認の成功と、unsigned・新署名形式・旧2形式経由の Concept Test の拒否を確認した。本番環境は変更していない。2026-10-02 の人間承認に基づき、bootstrap の停止・下流呼出0は T-003 の責務のまま未検証。T-001 は In Progress のまま、Done 判定は quality-gate のみが行う。

旧 attempt-2 の証拠は履歴として保持。改訂計画は `reports/task-review/sdd-domain-concept-test/attempt-3/round-1/` の独立 A/B と統合判定で PASS。今回も feature-scoped workflow-state 検査は終了0。これはタスク計画のレビューであり、実装 quality-gate の代替ではない。今回再実行した Bash 113件・PowerShell 112件はともに失敗0。CI・独立実装 quality-gate・マージは未完了。
