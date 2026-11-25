# 設計　Codex の版別プラグインから Concept Test を実行する

## 方針

ホストが既に選んだプラグインの実ディレクトリに、その版で必要な Concept Test 実装とスキーマを同梱する。利用者が指定する `--root` は利用者の機能・ドメイン証拠の読取元であり、製品コードを探す場所には使わない。domain と quality は別々に導入・更新できる。検証の振る舞いはひとつの正本から配る。公式 marketplace の各 source 自体を完成したパッケージにする。根拠は `.agents/plugins/marketplace.json:47–51,73–77`、`.claude-plugin/marketplace.json:40–41,58–59`、`PLUGIN-CONTRACTS.md:349–356,389–391`。

## 変更対象と責務

| 対象 | N14で必要な変更・保持する責務 |
|---|---|
| `plugins/sdd-domain/skills/concept-test/SKILL.md` | 内部委譲を受けた自身のスキル実体の位置から、同版の検証器・スキーマを特定する。通常検証には実行可能な実パスを渡す。Non-FITS だけは、利用者のシェルごとに引用した実パス・プロジェクト・featureと `--confirm` を本人へ提示する。公開bootstrapからの代表例で、実際に選んだ検証器・schemaと本人に表示したコマンド原文を収集する。区別の明示確認とNon-FITSの最終選択は別の操作として扱う。開発checkoutや決め打ちの版番号を必要としない。現行の入口は同ファイル14,19–21行と `plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md:25`。 |
| `plugins/sdd-domain/scripts/validate-concept-test.{sh,ps1,py}` と `validate-domain-contract.{sh,ps1}` | 既存のラッパー名・引数・出力・決定ロジックは維持。自プラグインの `scripts/lib/` のdispatch、同じ `scripts/` のPython依存・ネイティブ検証器、自分の `contracts/` を読む。既存の兄弟参照は `validate-concept-test.sh:8`、`.ps1:6`、`.py:15–38,88–90,134–154`。 |
| `plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs`、`scripts/review-conditional-inputs.py` | quality 内の同版ラッパーをOS別に child process で選ぶ。ライブゲートの `--require-v2`、既存の対象選定と `checks.conceptTest` を維持。条件付きread APIは自プラグイン内のPython実装に元の `observe` を渡す。現在の呼出しは `run-sdd-gate.mjs:501–556,630–631` と `review-conditional-inputs.py:144–185,220–230,263–270`。 |
| domain・quality の `scripts/`、`scripts/lib/`、`contracts/` と配布同期・検査 | domain が所有する2ラッパー・判定本体・2ネイティブ検証器、quality が所有する条件付き入力・署名sidecar・canonicalizer・両dispatch・PowerShell引数処理、ルート `contracts/` の6スキーマを配布対象一覧へ対応付ける。既存正本を使える側はその場で使い、他方には同じバイトを生成する。重複コピーを人手で保守しない。 |
| `plugins/sdd-review-loop/scripts/launch-impl-review.py` | 固定レビューの既存inventoryを保持し、N14に関して実際に読む配布元の実体を絶対パスとSHA-256で拘束する。対象プロジェクトPと配布元Rの分担は下記。既存処理は20–73,89–104,469–492,540–573行。 |

版別資材に含むスキーマは `domain-contract.v2.schema.json`、`concept-test.v1.schema.json`、`concept-test.v2.schema.json`、`concept-test-decision.v1.schema.json`、`approval-sidecar.schema.json`、`approver-registry.schema.json`。この一覧はConcept Test用である。共用sidecarのその他の呼出元とスキーマの探索順序はその呼出しの既存動作を維持する。sidecar の schema 読取と HMAC 検証の位置は `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:637–641,680,708,793,943–954`。一般schemaエンジンの適用外であるため、認可検証を汎用schema検査に置換しない（`docs/adr/0048-shared-schema-runtime.md:62–65`）。

### 配布資材の選択と検査

公式source内へ同期した正本／複製の対応表と期待ダイジェストを生成し、版は各パッケージの既存manifestに対応付ける。公開前は両sourceから正本と同じバイトが得られることをオフラインの読み取り検査で確認する。差分がある場合は対象パスを出して非0で終了する。版番号を更新するときは対応する資材も同時に確認する。現行の版連動は `scripts/bump-version.sh:47–66`、同梱物の差分検出例は `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py:88–110`。固定17ファイルの実行可能性は旧候補で実測済みだが、配布済み全経路の試験ではない。独立審査時と実装時にmanifestのsource・版、読まれる依存、保護範囲を実際の候補で再確認する。

実行時の基点は実行中ファイルの実パス。必要な資材が自身の版・想定パス・期待バイトに合うことを、該当する検証／読込を行う前に確認する。選択した公式source内で不整合があれば、読めない資材の診断を返す。別版キャッシュの列挙、環境変数での版指定、利用側checkoutへの探索はしない。開発checkoutで従来のルート `contracts/` を使う経路が必要な場合は、実行中スクリプトの実パス由来で当該プラグインの正本を含む製品checkoutそのものと確認できた場合だけに限定する。配布source内の不整合を checkout fallback で回避しない。既存のスクリプト相対解決の設計は `docs/adr/0029-registry-discovery-contract.md:53–96`。この照合は、信頼された配布物の内部整合性を確認するものであり、プラグイン自体と期待値の両方を置換できる同一権限者の本人認証には使わない。

### 固定レビューで区別する二つのルート

対象プロジェクトP（`--root`）から作業木または指定revisionの機能・モデル・判断のバイトを既存の `observe` で読む。配布元Rは起動したランチャー自身の実パスと選択版から決まる。従来の `runtime_files(root,...)` はPを基点に列挙する一方、条件読取のimportは `transport.plugin_file(...)` が選んだRにある。`plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py:43–55`、`plugins/sdd-review-loop/scripts/launch-impl-review.py:20–73,89–104`。

固定レビューは従来Pで要求していたinventoryとその前提を保つ。N14で利用する条件読取モジュール、その実行依存・schema・選択に用いる一覧／manifestは、読み込む側と同じ解決結果を使い、Rでの実パス・ダイジェストを既存の `dependencies.json` に含める。初回に対象の同版性・配布整合を確かめてから該当資材を読み、予約前にも固定した物理ファイルの同一性とバイトを検査する。Pや他版に同じ名前・同じバイトがあっても、Rの実体の拘束を代用できない。P側の従来の固定条件と新たに拘束するRの資材をともに満たす場合に限り既存手続へ進む。Rでの変更・欠落は既存の予約・審査より前で止める。従来の照合・予約順は `plugins/sdd-review-loop/scripts/launch-impl-review.py:469–492,540–573`。空の製品構成の利用者Pで旧保護ランチャーを新規提供する要件はない。

## データ・インターフェース契約

- プロジェクトの `specs/<feature>/concept-test.{json,md}`、明示列挙された `domain/` の入力、当該featureのseedと判断記録は、これまでどおり選択した利用者ルート／リビジョンから読む。別プロジェクトの同名featureを受理しない。v2の `--confirm` だけが本人のTTY判断を `concept-test.decision.json` に発行し、確認中の変更を検査する。読み取りとゲートはこの記録を作成・更新しない。`plugins/sdd-domain/scripts/validate-concept-test.py:55–131,184–248`。
- 旧署名履歴は同じregistry・署名・canonicalizer・内容ハッシュの照合を通す。旧 decision packet は従来の平坦な正式製品配置に限って互換試験を行う。起動時のquality読込は `plugins/sdd-bootstrap/scripts/decision-packet.py:15`。その `evidence(root, feature)` の既定値 `allow_local=False` によりsigned-only。固定入力を使う既存呼出元は `evidence(root, feature, observe, allow_local=True)` を使用し、パスと内容の取得を同じコールバックに閉じる。軽量ゲートは読み取り専用の `--require-v2` を用いる。署名の自動付与、v1一括再審査や履歴変換は不要。`plugins/sdd-domain/scripts/validate-concept-test.py:131–181`、`plugins/sdd-bootstrap/scripts/decision-packet.py:512–528`、`plugins/sdd-quality-loop/scripts/review-conditional-inputs.py:220–229`。
- 対象v2のゲート出力は `CONTINUE`、`DEFER`、`REJECT`、`BLOCK`。確認が非通過なら後続の指定コマンドを実行しない。対象外は `NOT_APPLICABLE`。歴史だけに残ったv2に関する `PLUGIN-CONTRACTS.md:386–388` の文言には基点の実動と差がある。N14では現行ゲートの作業木・index判定を用い、履歴の再走査を追加しない。`plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs:501–556,630–631`。

## 採らなかった設計（Alternatives Rejected）

| 候補案 | 不採用理由 | 再検討条件 |
|---|---|---|
| 隣接プラグインを探索して最新の版を選ぶ | Codexが選んだ版と異なる判断ロジック・schemaが混ざる | ホストが有効な依存の実体と不変な版を渡す共通APIを正式提供する場合 |
| installerだけで共有ルートを組み立てる | 公式marketplaceからの直接追加や版別キャッシュには共有レイアウトを保証できない | 公式配布方式で共有レイアウト自体を保証する場合 |
| 全呼出元をlive CLIへ置き換える | 固定commitの入力を読むAPIと旧署名必須の既定を失う | 同等の固定入力・署名契約を別途設計して承認を受ける場合 |

## 影響範囲とロールバック

高リスクの対象は実行資材の由来と既存の証拠拘束。自己完結には固定資材の重複という配布コストを伴う。正本との自動照合、旧署名と固定入力の独立試験、正式な保護変更手順を用いる。DB、クラウド権限、ネットワーク、UI、利用者データの移行は不要。ロールバックは当該コード・生成物・一覧をひとまとまりで直前版に戻し、既存v1/v2証跡をそのまま保持する。旧版に戻すとN14の版別導入障害は再発するため、旧版を正常な復旧先と称さず、配布前検収と導入元の正常対照を使う。

## テスト方針

AC-001、AC-002は一時HOMEの実Codexが返した登録先とFITSの実行を結ぶ。AC-003、AC-004、AC-005は両配布ラッパー、合成TTY、公開Node CLIで検証し、v1には既存試験用の合成鍵のみ使用する。AC-006はquality内の条件付き読取の4段階、別rootと固定inventory、宣言から予約前再照合までの実行資材拘束を検査する。AC-007は通常のsource、二つの版、同版資材欠落・不一致を制御したfixture、AC-008はDDDなしとGit indexの対照を使う。既存の根拠は `tests/concept-test.tests.py:184,239,334,371,419`、`tests/fixed-review-launch.tests.py:770–804` と `tests/concept-review-continuity.tests.py:159–209`。AC-001は実Codexの対話を少なくとも1つのネイティブ環境で採取する。未回答の区別と、区別確認済みNon-FITSでコマンドを表示する場合を分ける。別パスのP/R、同じバイトのモジュールを使い、実ロード先と予約前に照合する `dependencies.json` のキーを比較する。正常対照では従来の前提を満たす。R側のみの変更・欠落、従来の固定対象であるP側のみの変更・欠落は個別に検査する。AC-008のPython不在は正常v2とDDDなしの2条件を用意する。macOS・Linux・Windowsネイティブは各々の実行環境・実施項目・終了値を記録し、環境がなければ未実行と記載する。Windowsの実Nodeで `process.platform=win32` の `pwsh -NoProfile -File`、Unix系の実Nodeで `sh` と選択版ラッパー・結果を観測する（`plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs:549–556`）。macOS上のPowerShell直呼びや合成端末はWindowsネイティブの実施件数に含めない。

## Spec Amendments

2026-11-23　第1回独立審査により、実ホストの対話、配布元と対象プロジェクトの拘束、旧packetの配置、環境別の検収手順を明確にした。
