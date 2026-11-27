# T-010 失敗スイートの処置計画（2026-11-28 案）

対象は `5270e23f` 時点で失敗している48スイート。各スイートを単独で再実行して原因を特定した（root 実行と非 root 実行の両方）。所有者の方針（2026-11-28）は次の3点。

- 古い仕様だけに適したテストは退役してよい。
- 新しい仕様にテストがなければ用意する。
- 形式検証を合理的に使う。

本書は実装前の計画で、承認後に着手する。退役の根拠は [ADR-0051](../../../../../docs/adr/0051-lightweight-guardrails-and-sdd-core.md) の決定1〜4と、[v2 契約調査](v2-contract-inventory.md)の後継・未証明欄である。

## 分類

| 記号 | 意味 | 処置 |
|---|---|---|
| E | 実行環境だけが原因（root 実行、Pester 未導入、shallow clone、`pwsh` の配置）。製品・テストとも正しい | 非 root・全履歴・CI と同じツールで再実行する。コードは変えない |
| Q | 所有者回答 Q02〜Q16 で処置が決まっている | 回答どおりに移行する |
| R | ADR-0051 が退役させた面（Full/Lite 分割、3ループレビュー、パネル、HMAC 署名・sidecar、guard-invariants・ハンドシェイク、SDD_SUDO、v1 CI 構成）だけを検証している | 退役台帳に記録してカタログから外し、ファイルを削除する。後継テストを台帳に明記する |
| P | v1 専用ケースと v2 にも残る保証が混在している | v1 専用ケースだけ退役し、残りを v2 に移行する |
| N | v2 の保証にテストがない | 新規テストを作る |
| F | 状態遷移の保証で、形式モデルが担える | モデルと実装の対応検査を足し、個別例の旧テストを退役する |

## スイート別の処置

| スイート | 失敗の直接原因 | 分類 | 処置と後継 |
|---|---|---|---|
| design-system-compliance | root では権限エラーが起きない | E | 非 root で合格を確認済み |
| emit-run-record-feature-scope | 同上（読取エラーの再現） | E | 非 root で合格を確認済み |
| research-acquire | 同上（共有ストアの権限） | E | 非 root で合格を確認済み |
| research-discovery | 同上 | E | 非 root で合格を確認済み |
| task-context-isolation | 同上（スナップショットの書込み禁止） | E | 非 root で合格を確認済み |
| check-installed-plugin-drift | 同上 | E | 非 root で合格を確認済み |
| workflow-state | root では読めないファイルを作れない。非 root では `pwsh` を起動できない | E | `node` と `pwsh` を非 root から使える環境で再実行する |
| sdd-domain.tests.ps1 | Pester 4.10.1 が未導入 | E | CI と同じ版を導入して再実行する |
| bootstrap-interview-guidance | 旧 Phase 1 の7出力を宣言 | Q03 | 現行3文書と requirements.md の受入条件の検査へ移す |
| bootstrap-cross-layer-index | 旧レイヤー索引（TEST-008） | Q16 | 旧テンプレート専用10件を退役し、現行の要件漏れ・不正参照・理由のない N/A の拒否を検証する |
| bootstrap-layer-templates | 旧4レイヤーテンプレートが不在 | Q16 / R | Q16 の範囲。テンプレート存在検査は退役する |
| design-system-contract | Lite テンプレート・旧 interviewer | Q04 / P | 同意内容と Design-Source 記録は両シェルで検証し、Lite 参照は退役する |
| design-sync-scan | 手順番号・旧文言（TEST-031/032/035/044/045）。TEST-012 は root | Q07 / Q08 / E | 現行手順3へ移す。TEST-012 は非 root で確認する |
| design-sync-standing-consent | 旧文言29件 | Q08 / P | 3項目は旧フィールド名で記録する。残りは v2 の手順で検証できるものを移し、旧文言だけのものは退役する |
| compatibility-byte-identical | ship の互換フォールバック節、Project Context の有無の組合せ | Q09 | 6通りを現行の Risk 判定に揃える |
| resolve-project-context-caller-contract | 旧 Project Context の呼出し元 | Q09 / R | Q09 の範囲を移し、v1 の呼出し元固定は退役する |
| component-path-ownership-parity | 旧10本の CI 登録 | Q11 | 当時の workflow とローカル10本・ownership-digest 2本で検証する |
| structural-compatibility | interviewer・lite-spec の存在要求 | Q02（推定） / R | 発行前検査は現行 v2 テストへ移し、旧製品面の存在要求は退役する |
| render-agent-frontmatter | 旧4役のファイル固定 | Q15 | 配布6役と旧4役の明示指定時の挙動を検証する（下記の確認点） |
| gates | HMAC 証跡束、Lite 状態検査 | R + F | ADR-0051 決定1・2。後継は run-sdd-gate と v2-sdd-core-flow。Done の条件は GateLifecycle `DoneRequiresGatePass` |
| eval | 署名付き証跡束の生成 | R | 決定1。参照関係は check-traceability と golden-eval が後継 |
| scenario | 署名付き全工程、旧フック契約 | R | 決定1・3。後継は v2-real-flows-e2e |
| spec-review-loop | 6役の3ループ | R | 決定2（3ループ廃止）。後継は spec-check の2視点（v2-sdd-core-flow） |
| review-agent-isolation | 旧 spec-review スキル | R | 決定2 |
| review-prompt-calibration | 旧レビュー役の較正 | R | 決定2 |
| cross-model | 外部パネル（cross-model-verify） | R | 決定2。high は2視点で、外部プロバイダの多様性は v2 の要件ではない |
| run-panelist-effort | 旧パネルランナー | R | 決定2 |
| wfi-058-outputs-anchor | 旧パネル入力生成器 | R | 決定2 |
| wfi-059-evidence-path-base | 旧パネル入力生成器 | R + N1 | 決定2。現行ゲートの証拠パス解決は N1 で新規テストにする |
| risk-upgrade-context | Full/Lite トラック切替 | R | 決定2。Core の Risk 別確認は v2-sdd-core-flow が後継 |
| workflow-scenarios | 旧 interviewer スキル | R | 決定2 |
| current-byte-capture | guard-invariants 生成器 | R | 決定3（224ファイルロック不変条件の廃止） |
| generate-gate-capabilities | guard-invariants 入力 | R | 決定3。現行能力一覧の生成に価値が残る場合は P に変更する |
| deterministic-lane-selfcheck | v1 の単一ジョブ CI 構成 | R | 決定4。後継は verification-ci の経路契約 |
| gemini-environment-loops | 旧ハンドシェイク・Python guard | P | ハンドシェイクは退役する。Gemini の soft guard 配線は現行 hooks.json で検証する |
| check-component-coverage | guard-invariants、quality-gate の Process 節 | P + N2 | 旧部分は退役。Core ゲートから必須時に呼ばれ、N/A と失敗を区別するかを N2 で検証する |
| host-review-preflight | 3ループのスキル名、session-panelist | P | 3ループ・パネル部分は退役し、現行 preflight を残す |
| boundary-reference-authorization-parity | 旧レビュー役の文言 | P + N3 | 旧役は退役。現行レビュー役の権限境界の明示を N3 で検証する |
| review-context-boundary | 旧 impl-reviewer | P | 旧役名を外し、現行の境界検査を残す |
| agent-model-routing | 旧レビュー役と investigator の Haiku 要求 | P + 確認 | 旧役は退役。investigator は agent が `model: inherit`、文書が Haiku で食い違っている（下記の確認点） |
| loop-escalation | 署名付き v1 Context、承認 sidecar | P + F | 署名部分は退役。修復上限と人間へのエスカレーションは GateLifecycle の Repair/Escalate を対応検査で結ぶ |
| loop-inventory | run-all・test.yml への登録要求 | P | 登録の正本を v2 の verification catalog に移す |
| quality-loop-calibration | quality-gate スキルの較正 | P | 旧スキル部分は退役。sdd-gate の G1〜G5 の視点は v2 の記述で検証する |
| workflow-documentation | README の spec-review-loop | P | 旧3ループの文言は退役し、v2 の Core フロー記述で検証する |
| p0-hardening | v2 で書き換えたスキルの旧文言 | P + 確認 | 文言検査は退役。挙動（並列化の独立集合、ゲート上限）が v2 の要件なら挙動テストにする |
| retrospective-loop | 「Regression connection」節 | P + 確認 | 同上 |
| turn-first-workflow | 「1タスクに1つの新しい実装エージェント」の文言 | P + 確認 | 同上 |
| model-policy-installed（残り31件） | 退役した呼出し元スキル・旧記述、ManagedClaudeRoles | P / Q15 | 退役スキルと旧記述を読む約29件は退役する。2件は Q15 |

集計は E 8、Q 11、R 15、P 14 スイート。新規テストは下記の N1〜N5。

## 新規テスト（v2 の保証で、テストがないもの）

- **N1:** run-sdd-gate の証拠パス解決。起点をリポジトリにすること、別ファイルの誤読を防ぐこと、欠落を診断すること（契約調査 #6）。
- **N2:** component coverage。Core ゲートが必須時に呼び出し、N/A と失敗を区別すること（#34）。
- **N3:** 現行レビュー役（spec-check A/B と sdd-gate の評価者）が、引用の確認と台帳の無許可読取り禁止を明示していること（#19）。
- **N4:** Core ゲートが失敗・中断・再入のそれぞれで正しい run を記録すること（#3）。
- **N5:** 形式モデルと実装の対応。下記の F1 を参照。

## 形式検証の使い方

現行モデルは `specs/self-verification/formal/` の3つ。

- **TaskLock:** `SingleOwner` を保証する。
- **TaskLockMutation:** `OneWriter` を保証する。
- **GateLifecycle:** `DoneRequiresGatePass` を保証し、修復・エスカレーション・ドリフト・改ざんの各負例を持つ。

TLC は22件の検査でベースライン・負例・実装トレースの再生を確認している（v2-formal-gate）。

ただし `mapping.json` の前提「Status を Done にするのは quality-gate だけ」と、状態の集合が実装の読取りと一致することは検査されていない。そこで次の2つを足す。

- **F1（対応検査）:** v2 共有パーサ（`v2-pure-lib.mjs`）が受け付ける Approval/Status の値の集合と遷移が、GateLifecycle の状態・アクションと一致することを検査する。片方にだけ値を足すと失敗するようにする。
- **F2（トレース）:** run-sdd-gate の実行から GateLifecycle のトレースを生成し、TLC で再生する。PASS・FAIL・修復上限到達の3経路で行う。まず既存の再生検査がどこまで対象にしているかを確認し、不足分だけ足す。

F1・F2 が通れば、状態遷移を個別の例で確かめていた旧テスト（gates のタスク状態、loop-escalation の上限連鎖）は、モデルの保証で置き換えられる。例をさらに増やすのではなく、モデルと実装の対応を1か所で検査する。

## 前提となる変更（承認が必要）

1. **T-010 の合格条件の文言変更。** `tasks.md` の T-010 Verification と `approved-shadow-release.md` は「全195件成功」と書いている。退役すると件数が変わるので、文言を「退役台帳に記録したものを除く登録済み全スイート」に改める。凍結された task plan の変更なので、人間の承認を記録し、実装後の provenance 再レビューを行う（AGENTS.md WFI-004）。
2. **退役台帳。** `verification/T-010/shadow-pr976/retirement-ledger.json` に、スイート、ADR-0051 の決定番号、後継テスト、承認日を記録する。必須チェックを黙って削らないための記録とする。
3. **受入実行の環境。** 合格判定のための単一実行は、非 root ユーザー・全履歴・Pester 4.10.1・`node` と `pwsh` が使える環境で行う。それが用意できない場合は、E 分類を CI の結果で判定する。
4. **既に実装した Q05・Q10・Q12・Q14 の v1.26.0 固定。** 所有者の回答どおりなので維持する。新方針に合わせて退役へ切り替えるかは別途判断する。

## 確認点（所有者の判断が必要）

- **Q15:** 現行レンダラーは旧4役の明示指定を入力エラーで拒否し、何も書かない。「ステージ出力」は v1.26.0 でしか検証できない。案は、現行では「拒否され、元のファイルは書き換えられない」ことを検証し、ステージ出力は v1.26.0 で検証すること。
- **investigator のモデル:** agent は `model: inherit`、ルーティング表は Haiku で食い違っている。どちらを v2 の仕様とするか。
- **v2 で書き換えたスキルの旧文言（p0-hardening・retrospective-loop・turn-first-workflow）:** 文言は退役させる。挙動は v2 の要件文書と照合し、要件にあるものだけ挙動テストにする。照合結果は実施時に報告する。

## 実施順

1. 退役台帳と T-010 の文言変更を用意する（承認後）。
2. R を退役する。
3. P の v1 専用ケースを退役し、残りを移行する。
4. Q を回答どおりに移行する。
5. N1〜N4 と F1・F2 を作る。
6. 非 root 環境で全件を単一実行する。
7. 独立レビューを行う。
