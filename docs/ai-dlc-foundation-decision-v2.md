# Multi-target AI-DLC拡張計画 改訂決定書 v2

対象: sdd-forge（https://github.com/aharada54914/sdd-forge）
基準リポジトリ状態: main @ v1.10.0-162-g3277094（v1.10.0 タグから 162 コミット先。epic-136 Phase 2 / Pillar A・B・C Phase 1 を含む）
Tracking issue: #187 / Epic A0: #188
本ファイルをもって本決定書の正本とする（外部原本からの転記後、リポジトリ内で改訂を管理する）。

## 改訂履歴と根拠

- v1: Q1〜Q16 + D の指摘への回答として作成。
- **v2（本書）**: v1 に対する 3 系統の敵対的レビュー（Claude 反証・Claude 事実照合・Codex 反証、いずれも上記リポジトリ実コードと突き合わせ）の統合結果を反映。
  - v1 の事実前提は 9/11 一致・不一致ゼロ（部分一致 2 は本書で修正済み）。
  - 骨格 11 決定は独立レビューで反証失敗（= 堅牢確認）: Q1 三軸分離 / Q2 三段Gate分割 / Q3 互換テスト三分割 / Q4 Provider Binding分離 / Q7 sdd-incident削除 / Q10 DSLコア / Q12 Registry単一正本 / Q13 Provider実状態正本 / Q16 dogfood選定 / SDD_SUDO非バイパス / 18.4 Interviewer統合。
  - 修正したのは 3 群: (a) 承認防衛の具体機構（Blocker）、(b) Q間の突合せ漏れ、(c) 単独メンテナ規模と統治機構の不釣合い。
  - 設計者裁定 3 件を反映: CLI フラグは厳格化方向のみ許可 / Promotion 語彙は延期 / 二者承認は条件付き活性化。
- 2026-07-19 v2.1: 実装レビュー指摘による修正 — platform_targets 正準化 / HMAC preimage 定義 / DSL allowlist へ local_persistence 追加 / equals・not_equals の型不一致意味論の一意化 / stale 判定の semantic output 定義

---
# 1. 総合判断

提示された16件の疑問・意見は、すべて妥当な論点である。
- Q1〜Q14：指摘または推奨案を基本的に採用
- Q15：リスク階層連動ではなく**影響範囲連動**へ変更
- Q16：最初のdogfood対象をsdd-forge自身に決定
- Dの軽微な指摘：すべて修正対象に追加

Epic Aのスキーマ確定前に解決すべき事項（v2 で更新）:
1. モードの正本と **track 選択契約の移行**（Q1）
2. Gateの実行段階と **Foundation での実装範囲**（Q2）
3. Legacy互換テストの定義（Q3）
4. liteトラックとの組合せ（Q5）
5. Conditional Facetの条件言語と**評価意味論**（Q10）
6. **承認防衛機構の再設計**（Q8: 全書込拒否 + HMAC）
7. **Staleness の束縛対象**（Q15: Registry / ownership digest）

---
# 2. Q1：モード決定変数の競合

## 判断
指摘を採用する。**ファイルの存在をモード決定変数として使用しない。**
3軸（ワークフローの厳密度 / 成果物の配置形式 / Capability Gateの強制度）を分離する。

## 正準フィールド（v2: 各軸は単一値。配列表記を廃止）

```yaml
workflow:
  spec_profile: full          # full | lite
  artifact_layout: facet-hybrid
    # lite-three-file | legacy-seven-layer | facet-hybrid | facet-native
  capability_enforcement: required   # advisory | required
```

- spec_profile → レビュー、証跡、承認の厳密度
- artifact_layout → 仕様成果物をどの構造で配置するか
- capability_enforcement → Capability固有Gateを警告または必須にするか

**（v2 追加）layout の定義**:
- `facet-hybrid`: legacy-seven-layer の全成果物を維持したまま、Facet Manifest と Facet ファイルを併存させる。既存ツール・既存レビューフローとの互換を保つ移行形態。
- `facet-native`: Facet 群が正本であり、legacy 7層の重複成果物は生成しない。facet-hybrid の運用実績を経てから昇格する将来形態。

## 正本
`project-context.yaml` が存在する場合、上記フィールドだけを正本とする。
ファイル存在チェックは互換フォールバックにのみ使う:

```text
project-context.yamlがない
    ↓ 従来互換モード
AGENTS.mdのspec_profile: lite
→ spec_profile: lite / artifact_layout: lite-three-file / （内部状態: capability機構 非活性）
それ以外
→ spec_profile: full / artifact_layout: legacy-seven-layer / （内部状態: capability機構 非活性）
```

**（v2 変更）`disabled-legacy` の再定義**: enforcement の enum 値ではなく、**「capability 評価パイプライン全体が非活性」という導出内部状態**とする。この状態では Resolver・Registry・Gate stage・Q9 の max() 演算のいずれも起動しない（max() の定義域に入らない）。Registry に `minimum_enforcement: required` があっても、Project Context を持たないプロジェクトに影響しない。

## （v2 新設）Track 選択契約の移行
現行 PLUGIN-CONTRACTS は CLI フラグ（`--full` / `--lite`）を最優先とするため、Project Context 単一正本と衝突する。裁定:

- **Project Context 存在時、CLI フラグは厳格化方向のみ許可する**（Q9 の runtime override と同じ非対称原則）。
  - Context が lite の場合: `--full` → full へ昇格して実行。`--lite` → no-op。
  - Context が full の場合: `--lite` → **エラー停止**（明示メッセージ。黙って無視しない）。`--full` → no-op。
- Project Context 不在時は現行優先順位（CLI フラグ → AGENTS marker → default）を維持する（互換フォールバック）。
- PLUGIN-CONTRACTS の track-selection 節の改訂と、全 consumer skill（ship / bootstrap-interviewer / lite 系）の移行タスクを **Epic A1 に含める**。

## Q1への最終回答
- project-context.yamlの存在 → モードを決定しない
- project-context.yaml.workflow → モードの唯一の正本（CLI フラグは厳格化方向のみ）
- project-context.yaml不在 → 旧挙動への互換フォールバック（capability 機構は非活性）

---
# 3. Q2：Task Doneと配布証跡のタイミング

## 判断
Gateを3段階に分類する: 1. Implementation Gate / 2. Artifact Gate / 3. Promotion Gate。
**（v2 追加）Foundation で実装するのは stage: implementation のみ。** artifact / promotion は Registry schema 上の enum 予約とし、実装免除を明記する（§13 の完全性テストは stage=implementation の Gate のみを対象とする）。

## 3.1 Implementation Gate
実行主体: sdd-quality-loop（lite トラックでは lite-gate） / 結果: Task Status: Done
**（v2 修正）不変条件の正確な表現: 「ゲートスキル（quality-gate または lite-gate）のみが Task を Done にできる」。** この既存不変条件を維持する。

対象は、実装時点で検証可能なものに限定する。
### 共通
- Project Contextの妥当性 / Facet Manifestの妥当性 / Capability Coverage
- componentとgit diffの整合性（check-component-coverage、§12） / 設計契約 / 単体・結合・回帰テスト
- package/buildが可能なこと / Delivery Pipelineの構造
- signing/notarization設定の存在と構造 / migrationのシミュレーション
- IaC validate／plan / retry、idempotency、compensation、replayテスト
- public API diff / observability contract / mitigation plan
- **（v2 追加・現行必須要素の取込み）**: cross-model 検証（fail-closed、waiver は第二の人間承認者名必須） / gate レポートの evaluator identity フィールド / HMAC 署名付き evidence bundle / quality-gate cycle limit
### ここで要求しないもの
実際のコード署名 / 実際のnotarization / Store審査完了 / production deployment / canary結果 / production SLO / registry公開済みartifact / Stable channelでの配信状態

## 3.2 Artifact Gate（enum 予約。実装は Foundation 外）
実行主体: sdd-delivery（**新設プラグイン。現リポジトリには存在しない**） / 前提: 関連する実装タスクがDone / 結果: Artifact Status: Verified
検査対象（Desktop / Cloud / Workflow / CLI・Library 別の項目一覧）は v1 の内容を**参考仕様**として保持するが、正式な語彙確定は sdd-delivery 実装時の ADR に委ねる。
**（v2 追加）`Artifact Status: Verified` の記録場所は Foundation では定義しない。** 実装時に provider 実状態から導出できる場合はローカル記録を持たず、導出できない場合は §10 の保護 sidecar と同じ扱い（agent 書込拒否 + HMAC）とする。エージェントが自由に書ける承認類似レコードを新設してはならない。

## 3.3 Promotion Gate（enum 予約。語彙は延期 — 設計者裁定）
結果: Delivery Status: Staging / Candidate / Production / Stable
**（v2 変更）検査項目の列挙（canary 分析 / SLO / Store 公開状態 / workflow version routing 等）は Foundation では凍結しない。** 実データゼロでの語彙凍結は schema v2 破壊の主因になるため、cloud-service Pack に実案件が付いた時点で ADR 化する。v1 の項目一覧は参考仕様として付録に残す。

## Gate定義スキーマ

```yaml
gates:
  - id: check-update-migration
    stage: implementation   # implementation | artifact | promotion（artifact/promotionは予約）
    blocking: true
```

## Q2への最終回答
署名・公証・Store公開・registry公開・canaryはquality-gateへ置かない。quality-gateでは、それらを生成・検証する設計とpipelineの正しさまでを確認する。Foundation で実装するのは Implementation Gate のみ。

---
# 4. Q3：byte-identical互換テスト

## 判断
互換テストを3種類へ分割する（レビューで堅牢確認済み）。

## 4.1 Byte-identical Test
対象: deterministic script output / exit code / stdout・stderr / templateのコピー結果 / schema validator / resolverを呼ばない旧コードパス / 生成されるディレクトリ一覧 / plugin manifest / install・uninstall結果
条件: 同じ固定fixture・同じ入力・同じ正規化済み環境

## 4.2 Structural Compatibility Test
LLM生成物は構造を比較: 必須ファイル数 / frontmatter / 必須見出し / status field / REQ・AC形式 / legacy modeではFacet参照が混入しないこと / capability関連ファイルが生成されないこと

## 4.3 Orchestration Compatibility Test
呼び出されるskillの順序 / review loopの有無 / approval checkpoint / quality gate / Done遷移 / skip・stop message をevent traceとして比較する。
**（v2 追加）ゼロから作らず、既存基盤の拡張として実装する**: loop-inventory/v1 registry・共有 loop driver・loop-consistency / loop-escalation スイート・run record（emit-run-record.sh）が既に存在する。Epic A7 はこれらへの capability イベント追加として設計する。

## 正式な互換要件
「Project Context不在時、決定論的成果物と制御フローはbyte-identicalまたはevent-identicalであり、LLM生成仕様は既存のschema・構造・必須見出しと互換であること。」

---
# 5. Q4：Provider中立性

## 判断（レビューで堅牢確認済み。変更なし）
`target_platforms`（v1 の呼称。正準フィールド名は `platform_targets`）からProvider情報を分離する。

## Project Context（Provider中立な性質だけを持たせる）

```yaml
components:
  - id: invoice-workflow
    artifact_kinds: [durable_workflow]
    runtime_classes: [managed_durable_runtime]
    platform_targets:
      - os: linux
        architecture: amd64
    characteristics:
      long_running: true
      replayable: true
      human_in_the_loop: true
    provider_binding_ids: [invoice-workflow-prod]
```

## Provider Bindings（別ファイル: sdd/provider-bindings.yaml）

```yaml
schema: sdd-provider-bindings/v1
bindings:
  - id: invoice-workflow-prod
    provider: azure
    product: durable-functions
    purpose: runtime
    state_authority:
      type: azure-runtime
      resource_ref: invoice-workflow-prod
    credentials:
      source: environment
      reference: AZURE_FEDERATED_IDENTITY
```

## 境界
- Capability Pack → Provider名を持たない
- Project Context → Provider BindingのIDだけを持つ
- Provider Bindings → Azure、AWS、Argo、MS Store等を持てる
Provider固有詳細のCapability仕様への混入を検出するレビュー規則は維持。
**（v2 注記）** credentials / state_authority の詳細語彙は §3.3 と同じく実案件時の ADR に委ね、Foundation では binding の骨格（id / provider / product / purpose / binding 参照）のみ確定する。

---
# 6. Q5：liteトラックとの関係

## 判断
現行liteの実装事実（3ファイル生成・review loop等の省略・ファイル生成前のrisk-upgrade gate・ship時の再チェック・lite-gateの独立再検証）は実コードで確認済み。この思想をCapabilityへ拡張する。

## 組合せマトリクス（v2: フォールバック2行を追加）

| spec_profile | artifact_layout | enforcement | 判定 |
|---|---|---|---|
| lite | lite-three-file | advisory | Lite許可Capabilityだけ利用可能 |
| lite | lite-three-file | required | Lite専用Gateを持つCapabilityだけ利用可能 |
| lite | lite-three-file | （非活性） | **互換フォールバック（Context不在）。capability機構は動かない** |
| full | legacy-seven-layer | （非活性） | **互換フォールバック（Context不在）。capability機構は動かない** |
| lite | legacy-seven-layer / facet-* | 任意 | 無効な組合せ |
| full | lite-three-file | 任意 | 無効な組合せ |
| full | legacy-seven-layer | advisory／required | 移行互換モード |
| full | facet-hybrid | required | 推奨モード |
| full | facet-native | required | 将来の標準モード |

## CapabilityごとのLite適格性（Registryに追加）

```yaml
lite_policy:
  eligible: false
  upgrade_reasons: [public_distribution, production_cloud_runtime, durable_workflow, external_identity, pii]
```

Lite許可例: 完全ローカルの小規模社内ツール / 内部CLI / 機密情報を扱わない単純なユーティリティ / 外部公開しない小規模UI
Fullへ強制昇格: クラウドproduction / Durable Workflow / public package registry / Store配布 / 自動アップデート / コード署名を伴うStable配布 / 外部認証 / PII / 決済 / 複数tenant / 高リスクmigration

## Lite Capability Summary
liteでは個別Facetファイルを生成せず `specs/<feature>/capability-summary.yaml` だけを生成する。

```yaml
capabilities: [desktop-local]
required_lite_checks: [build, test, installer-dry-run]
full_upgrade_required: false
```

lite-gateは、現在のplaceholder／lint／typecheck／build／testに加え、Registryで定義されたLite専用チェックだけを実行する。現行lite-gateの軽量性と独立再検証は維持する。
**（v2 追加）実装上の注意**: lite-spec SKILL.md / risk-upgrade-policy.md / check-risk-upgrade.* は epic-136 Phase 2 で**保護ファイル**（agent 書換不可、sudo 不可）になっている。Epic A6 のこれらへの変更は human-copy フロー（`specs/<feature>/human-copy/` + apply-protected-files、ADR 0011）を工程として織り込む。

---
# 7. Q6：Claude／Codex／Copilotの3環境

## 判断
Foundationから3環境同時対応を必須とする。Claude Code先行merge+legacy fallback方式は採用しない。

## 実装方針
- 廃止: 独立したcapability-interviewer / 独立したfacet-generator
- 改訂: sdd-bootstrap-interviewer に capability interview phase / deterministic resolver 呼び出し / facet generation phase を統合
- `capability-resolver` は agent skill ではなく Bash／PowerShell から呼び出せる決定論的 script とする

## （v2 変更）「各Epicの3環境タスク」と Epic A8 の役割書き分け
v1 は「各Epicに3環境タスク必須」と「A8で同一Epic内完了」が矛盾していた。裁定:
- **各 Epic** = その Epic が追加した成果物（script / skill / hook / schema）の 3 環境対応（sh+ps1、3種 plugin 設定、環境別テスト）を自 Epic の Done 条件に含む。
- **Epic A8** = 統合検証専用: cross-runtime handoff E2E / install・uninstall マトリクス / hook guard 横断テスト / path・line-ending 回帰。個別成果物の 3 環境化は A8 に持ち越さない。

## 非対応runtimeの扱い + （v2 新設）Hook 稼働ハンドシェイク
Project ContextがCapability Modeを要求している場合、`CAPABILITY_RUNTIME_UNAVAILABLE`で停止する。**legacy modeへ黙ってフォールバックしてはならない。**

**（v2 追加）** 「runtime が対応している」の判定には **hook guard が実際に装着・発火していることの検証**を含める。スキルが読めるだけでは不十分（Codex は `plugin_hooks` feature flag 必須、Copilot の subagent hook は非発火という既知の実態がある）。実装: bootstrap / gate の冒頭で、guard が必ず拒否する canary 操作（例: SDD_SUDO への書込試行に相当する無害プローブ）を発行し、**拒否されなければ hook 不在と判定して Capability Mode を停止**する。この handshake を cross-runtime handoff テスト（A8）の必須ケースにする。

---
# 8. Q7：sdd-incident

## 判断（レビューで堅牢確認済み。変更なし）
初期段階では新規プラグイン`sdd-incident`を作らない。incident-triage / incident-bundle / recovery-verification / operation-feedback は `sdd-operability` の内部 skill として実装する。
**（v2 明記）`sdd-operability` は新設プラグインである**（現リポジトリに存在しない。既存物への追加ではない）。新設自体も cloud/durable Pack に実案件が付くまで着手しない。
独立プラグイン抽出の再検討条件（5項）は v1 のとおり維持。初期のEpic構成から`sdd-incident`を削除する。

---
# 9. Q8：Project Contextの承認防衛（v2: 機構を再設計）

## 判断
YAML内の`status: Approved`だけでは不十分。Project Context自体と承認記録を分離する。
ファイル: sdd/project-context.yaml / sdd/project-context.approval.json（provider-bindings も同様）

## Approval Sidecar

```json
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:...",
  "primary_approval": {"status": "Approved", "approver": "name", "approved_at": "ISO8601"},
  "second_approval": null,
  "hmac": "…"
}
```

## （v2 変更）防衛機構: 増加検出の流用をやめる
v1 の「現行 hook guard（Approval 増加検出）を sidecar へ拡張」は **Blocker**（両系統のレビューが独立に同一攻撃を構成）: エージェントが yaml を改変し、公開 canonical 化手順で hash を再計算して `context_sha256` だけ書き換えると、承認行は増えないため 6 層すべてを通過する。無署名 sha256 は束縛（binding）であり真正性（authenticity）ではない。裁定:

1. **全書込拒否**: `*.approval.json` は tasks.md と違いエージェント編集領域と混在しないため、増加検出ではなく **PROTECTED_GATE_SUFFIXES 方式（エージェント書込の全面拒否、sudo 不可）** を適用する。変更は human-copy フロー（ADR 0011）経由のみ。
2. **外部鍵 HMAC**: リポジトリが既に持つ evidence bundle 署名（SDD_EVIDENCE_KEY）・SDD_SUDO の HMAC 前例に従い、**approval レコード全体を外部鍵 HMAC で署名**する。鍵はエージェントに読ませない（THREAT-MODEL の既存原則）。hash 照合は「本文と承認の対応」を、HMAC は「承認が人間発行であること」を担保する。
   **（v2.1 追加）HMAC preimage の定義**: preimage = approval object から `hmac` フィールドを除外し、§18.3 の canonical 化（YAML/JSON parse → NFC → JCS）を適用した UTF-8 バイト列とする。これにより署名対象が自身の署名フィールドを含む自己参照を回避する。
3. **検証機構自体の保護**: canonicalizer / hash generator / approval validator / policy weakening detector / resolver / 生成 projection を guard-invariants（PROTECTED_GATE_SUFFIXES）に追加する。これを **Epic A1 の成果物として明記**する。

## （v2 新設）防衛主張のスコープ
hook 層は間接書込（inline interpreter 等）を完全には防げない——これは現行 guard 自身が認める既知の限界であり、本計画で変わらない。よって防衛主張を THREAT-MODEL と整合する2階建てで明文化する:
- **hook 層 + deterministic validator** = エージェントの誤操作・単純な自己承認の防止（footgun guard）。
- **敵対的エージェント耐性** = 保護ファイル（全書込拒否）+ 外部鍵 HMAC + branch protection / CODEOWNERS + 人間レビューの外部境界で担保。
「3環境で防御済み」という無条件の主張はしない（§7 の hook 稼働ハンドシェイクが前提条件）。

## SDD_SUDO（レビューで堅牢確認済み。変更なし）
Project Context承認は**sudoでバイパス不可**とする。既存の never-sudo クラス（WFI / Second Approval / gate script 保護）と同型。

## （v2 変更）二者承認: 条件付き活性化（設計者裁定）
すべての変更に二者承認は要求しない。policy-weakening 変更（enforcementを弱める / Capabilityを削除 / component pathを狭める / public distributionを非対象化 / criticalityを下げる / provider allowlistを広げる / production write pathを変更 / required Gateを削除 / fullからliteへ変更）が対象である点は維持しつつ:
- **approver registry に 2 名以上の実在 identity が登録されている場合のみ**、二者承認を必須とする。
- **単独メンテナ時は「第1承認 + 24h クールダウン（遅延発効）」に緩和**する。実装は SDD_SUDO の TTL・HMAC 機構を流用（発効予定時刻を HMAC 署名し、期限前の適用を validator が拒否）。
- これにより dogfood（A9）で required→advisory の差し戻しが単独でも実行可能になり、架空の第2名義という統制の自己否定を排除する。

---
# 10. Q9：Capability Enforcementの設定

## 判断
環境変数を正本にしない。正本は `workflow.capability_enforcement`（Project Contextの承認対象）。
Registry 側は `minimum_enforcement: required` を持てる。

## Effective Enforcement

```text
effective enforcement = max(approved project policy, capability minimum, runtime override)
```

- **（v2 追加）Context 不在（互換フォールバック）時は本演算自体を行わない**（capability パイプライン非活性。§2 参照）。
- runtime override は厳格化方向だけ許可（advisory → required 可、逆は拒否または無視し警告を記録）。
- **（v2 追加）override の経路を明示**: CLI フラグまたは環境変数。緩和方向の値は入力自体を拒否し、試行を run record に記録する。厳格化専用なので経路の改竄価値は低い（緩和には使えない）。

---
# 11. Q10：Conditional Facetの条件言語

## 判断（コア設計はレビューで堅牢確認済み）
任意式・eval・JavaScript・Rego文字列は使わない。JSON／YAMLで表現する限定的なPredicate DSLを定義する。

```yaml
conditional_facets:
  - facet: data-spec
    when:
      any:
        - {scope: affected_component, field: characteristics.pii, operator: equals, value: true}
        - {scope: affected_component, field: characteristics.local_persistence, operator: equals, value: true}
```

論理演算: all / any / not（notは単項）。比較: equals / not_equals / contains / in / exists。
禁止: regex / arbitrary JSONPath / shell / JavaScript / Python / dynamic code / Provider API呼び出し / 時刻依存条件 / ネットワーク依存条件。

## （v2 新設）評価意味論
runtime 間で結果が割れないよう、以下を規範とする（A0 の DSL ADR に含める）:
- **欠落 path / null / 型不一致は「その述語は match しない」（fail-closed）**とし、WARN を Resolver Evidence に記録する。例外を投げない。
- equals / not_equals: 同型スカラー同士のみ比較。**（v2.1 明確化）型不一致・欠落 path・null のいずれの場合も、equals と not_equals のどちらも述語全体が false（match しない）+ WARN で統一する。not_equals が型不一致によって true になることはない。**
- contains: 「配列 ∋ スカラー」のみ。文字列部分一致には使えない（決定論優先）。
- in: 「スカラー ∈ 配列リテラル」のみ。
- exists: path の存在のみを判定（値が null でも存在は true）。
- all: 空リストは true / any: 空リストは false。短絡評価はせず全述語を評価し、評価結果を Evidence に記録する。
- **trigger（Capability 適用条件）も同一 DSL を用い、評価対象は affected component の性質のみとする**。別言語を導入しない（任意式の裏口を作らない）。

## Field allowlist
Schemaでallowlistされたdotted pathだけを許可: artifact_kinds / runtime_classes / characteristics.pii / characteristics.ui / characteristics.auto_update / characteristics.local_persistence / distribution_channels / data_classification
**（v2 追加）** allowlist の出所は Project Context schema 本体とする。`distribution_channels` / `data_classification` を component 直下の正式フィールドとして Project Context schema（A1）に追加する（v1 では allowlist にのみ登場し置き場所が未定義だった）。
Resolverは同じ入力に対して常に同じFacet Manifestを生成する。

---
# 12. Q11：affected_componentsの過少申告

## 判断
Project Contextへpath ownershipを追加する。

```yaml
components:
  - id: desktop-client
    paths:
      include: ["src/desktop/**", "tests/desktop/**"]
      exclude: ["src/desktop/generated/**"]
shared_paths:
  - pattern: "contracts/**"
    components: [desktop-client, sync-api]
  - pattern: "docs/**"
    classification: cross-cutting
```

## Reverse Coverage Gate
git diff path → component path resolver → affected component → facet-manifest.affected_components
Fail条件: changed pathがどのcomponentにも属さない / changed componentがmanifestにない / exclusive pathが複数componentに一致 / shared pathに関係componentが未宣言 / exclude pathのinclude扱い / Provider Adapter変更がProvider Binding未反映。
これを`check-component-coverage`としてImplementation Gateへ追加する。

## （v2 新設）git diff の比較基準
v1 では diff の入力が未定義だった。裁定:
- **baseline = 当該 feature branch と main の merge-base**。feature 単位で change set を確定する。
- gate 実行時は「baseline..worktree の全変更 + untracked ファイル」を対象とする（staged / unstaged の別で漏らさない）。
- rename は follow する（rename 前後の path 双方で ownership 判定）。submodule と symlink の実体は対象外とし、参照変更のみ判定する。
- **運用上必ず増える path（specs/** / reports/** 等）は bootstrap 時に cross-cutting の shared_paths へ確定登録**し、日常運用での unowned-path FAIL を防ぐ。

---
# 13. Q12：RegistryとPackの二重正本

## 判断（レビューで堅牢確認済み）
Capability Registryを唯一のmachine-readable正本とする。
- Registryが持つもの: Capability ID / trigger / conditions / required facets / conditional facets / review check IDs / gate IDs / gate stage / lite eligibility / minimum enforcement / delivery strategy kind
- Packが持つもの: questions.md / templates/ / review-checklist.md / guidance.md / examples/ / policy-examples/
- 廃止: capability-packs/*/gates.yaml

## （v2 修正）projection の配置と保護
- 生成先は既存慣行に合わせ **`plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`** とする（guard-invariants 生成系と同じ配置・同じ「sha256 ヘッダー + Do not edit」形式）。
- projection は**保護ファイルとして登録**し、更新は human-copy フローで適用する（先例: guard-invariants 一式）。
- **Registry は content digest（`registry_digest`）を発行**し、Facet Manifest の staleness 束縛（§16）と CI drift check に用いる。effort routing v2（contracts → 生成 agent 定義 → CI drift check）が確立済みの社内パターンであり、それに追随する。
- テストで確認: Gate ID 一意 / stage=implementation の全 Gate に実装が1つ存在（artifact/promotion は予約につき対象外） / 未登録scriptなし / PackにGate定義なし / projectionが最新 / stage欠落なし。

---
# 14. Q13：Delivery Stateの正本

## 判断（レビューで堅牢確認済み。変更なし）
外部providerのactual state → 状態の正本 / immutable evidence snapshot → 監査・再構成用。
sdd-forge内にmutableなDelivery Registryは置かない。
`/sdd-delivery:status <delivery-id>` は毎回Providerへ問い合わせ、normalized viewを計算する。観測結果は append-only snapshot（reports/delivery-observations/…）として保存できる。
DesktopのStable正本はProvider Bindingの state_authority で宣言し、未定義なら Delivery Status: UNKNOWN とし Stable へ遷移させない（fail-closed）。
**（v2 注記）** `sdd-delivery` は新設プラグインであり、Promotion 語彙（§3.3）と同時期に設計する。Foundation では着手しない。

---
# 15. Q14：promoteのGit write権限

## 判断
`/sdd-delivery:plan` → read-only / `/sdd-delivery:promote` → write-capable の二段階。
ユーザーによる promote 実行を Git write への明示指示とみなす点は維持。`sdd-ship` の「明示指示なしに push／PR を作らない」既存契約も維持。

## Production Promotion
事前に delivery-action.yaml / delivery-action.approval.json を必要とする。
**（v2 追加）リプレイ・並行実行の防止**: delivery-action.approval.json に以下を必須化する。
- action instance ID（対象 digest・対象環境を含む）
- nonce と有効期限
- **消費記録（append-only）**: 実行成功時に consumed を記録し、同一承認の再実行を拒否する
- 実行時に provider 側の compare-and-swap（version / ETag）を検証し、plan 時 snapshot と実行時状態の乖離を検出したら中止する

## （v2 変更）Git write 境界は token スコープで執行する
v1 の allowlist はクライアント側チェックのみで、hook の無い経路（素の git push 等）で素通りする。裁定:
- **(a) 必須: fine-grained PAT / GitHub App により、token 自体を対象 repo・contents:write・branch 制限にスコープする。** allowlist の執行点はスキルではなく credential 側に置く。
- (b) YAML の repository_allowlist / path_allowlist / branch_policy は「token スコープの宣言的写し」と位置づけ、一致検査を Implementation Gate に置く。
- (c) 多層防御として hook guard の shell 解析に git push 先の検査を追加する。
- 禁止事項（secret 値の保存 / allowlist 外への書込 / default branch 直接 push / plan と異なる digest / approval 不一致での PR 作成）は v1 のとおり維持。

---
# 16. Q15：Project Context更新と進行中Feature

## 判断
リスク階層ではなく、**Featureが参照したContext部分への影響**で判定する。

## Facet Manifestへ追加（v2: 束縛対象を拡大）

```yaml
context_binding:
  full_context_revision: sha256:...
  dependency_pointers:
    - /components/desktop-client/artifact_kinds
    - /workflow/capability_enforcement
  projection_sha256: sha256:...
  registry_digest: sha256:...      # v2 追加: 使用した Registry 断片の digest
  ownership_digest: sha256:...     # v2 追加: 使用した path ownership 断片の digest
resolver:
  version: 1.1.0
  rule_set_revision: sha256:...
```

**（v2 の理由）** projection が Project Context の参照部分だけを束縛すると、Registry（required facets / gates / minimum enforcement）や path ownership の変更が「fresh のまま」素通りし、古い Feature が不十分な成果物で Gate を通過する。staleness は「Resolver が実際に消費した全入力」に束縛する。

## Context・Registry・ownership 変更時（v2: 判定を統一）
**（v2.1 追加）stale 判定の比較対象**: `context_binding` ブロック自体が digest を保持するため、Facet Manifest 全体を比較対象にすると digest 更新だけで常に「出力が変わった」ことになってしまう。そこで比較対象を **semantic output**（resolved required/conditional facets・N/A 理由・gate IDs・capability set）と定義し、`context_binding` ブロックと `resolver` ブロック（メタデータ）は比較から除外する。digest 更新のみで semantic output が不変なら Stale 化せず、メタデータ（digest 含む）を更新して継続する。

- **参照部分（projection / registry / ownership のいずれの digest も）不変** → 継続可能、WARNのみ
- **いずれかが変わった** → 対象 Feature で resolver を再実行し、再計算した semantic output を旧 semantic output と比較する。**semantic output が変わる Feature のみ選択的に Stale 化**。変わらなければ metadata（digest 含む）を更新して継続。全 Feature 一律停止はしない。
- **Policy Weakening** → 全影響FeatureをBlock、Project Context再承認、Feature再resolve

これにより Q11 との矛盾（ownership 変更を Q15 は素通りさせ Q11 の Gate は FAIL させる）を解消する: ownership 変更は ownership_digest 経由で検出され、Reverse Coverage の結果が変わる Feature だけが再 resolve を要求される。

## Done済みタスク
過去のDoneは取り消さない。ただしDelivery時に現在のContextとの互換性を再確認する:
Task Done + 古いContextに基づくartifact + 現在のproduction policyと不一致 → Delivery Blocked

---
# 17. Q16：最初のdogfood

## 判断（レビューで堅牢確認済み。変更なし）
最初の実戦対象は **sdd-forge自身**。
分類: artifact_kind: developer_tooling / cli / plugin_package、distribution: GitHub Release / multi-runtime plugin installation、platform: Windows / macOS / Linux、consumers: Claude Code / Codex CLI / Copilot CLI
理由（すべて実コードで裏取り済み）: 実利用者 / 既存release workflow / Bash・PowerShell並行文化 / 3環境hook実在 / installer両対応 / 外部credential不要 / Resolver自身をResolverで開発できる。

## Pack実装順
1. developer-tooling / cli-library → sdd-forge自身でdogfood
2. desktop → WPF fixture＋実アプリ
3. cloud-service → AzureまたはAWSの小規模サービス（**この時点で Promotion 語彙・credentials 語彙を ADR 化**）
4. durable-workflow → Azure Durable FunctionsまたはAWS Step Functions

---
# 18. Dの軽微な修正

## 18.1 生成残骸
citeturn / turnXXXsearch / utm_source=chatgpt を検出する release gate を追加する。誤検出防止のため対象をドキュメントの生成残骸に限定。
**（v2 追加）** 新設ではなく、**既存の release ゲートチェーン（bump-version.sh の loop-gate 前提条件 + release.yml の required job）へのチェック追加**として実装する。

## 18.2 Resolver Version
Facet Manifest の resolver.version / rule_set_revision（§16 参照）。
ルール: patch → 出力変更なしなら再生成不要 / minor → 影響判定を実行、projectionが変わればstale / major → 再resolve必須。

## 18.3 Cross-platform Hash（v2: 仕様を確定）
raw YAML bytesを承認hashに使わない。
- **YAML は 1.2 core schema で parse する**（1.1 系の on/off/yes/no bool 化を排除）。anchor / custom tag / duplicate key は禁止（parse 時に検査して reject）。
- **canonical JSON は RFC 8785 (JCS) に準拠**する（数値表現・文字列エスケープ・key 順序を規範化）。文字列は NFC に正規化する。
- **実装は Python 単一実装 + sh / ps1 / js の薄いラッパー**（sdd-hook-guard.sh 方式の踏襲）。ランタイムごとの再実装をしない。dual-runtime での hash 一致を fixture テストで固定する。
- `.gitattributes` の eol=lf 追記は多層防御として維持（現リポジトリは既に `* text=auto eol=lf` を持つ）。

## 18.4 Interviewer統合（レビューで堅牢確認済み。変更なし）
Capability Interviewerは独立skillにせず既存`sdd-bootstrap-interviewer`へ統合。質問は既知情報を再質問しない / 適用Capabilityだけ / 1 pass最大15問 / 未解決はOpen Questions保存 / 再開可能。

---
# 19. 改訂後のFoundation Epic（v2: 順序と内容を修正）

## Epic A0：Architecture Decisions
**先頭タスク（v2 追加）: docs/adr の採番規約整備**（現状 0002/0003/0004 が各2件重複。解消してから追加する）。
ADR: workflow axesの分離 / Gate Stage Model（Foundation=implementationのみ実装） / Provider Binding分離 / **Approval Sidecar（全書込拒否 + 外部鍵HMAC + 条件付き二者承認）** / **Conditional Predicate DSL（評価意味論込み）** / **Context Projection Staleness（registry_digest / ownership_digest 束縛込み）** / Lite Capability Upgrade / **Track 選択契約の移行（CLIフラグ厳格化のみ）** / **workflow-state registry と project-context.yaml の役割分担**（feature 状態の正本 vs project 設定の正本。二重正本を作らない）

## Epic A1：Project Context
成果物: sdd/project-context.yaml / project-context.approval.json / provider-bindings.yaml / provider-bindings.approval.json
実装: schema（distribution_channels / data_classification 含む） / canonicalizer（YAML 1.2 + JCS、Python単一実装+ラッパー） / hash generator / **HMAC 署名・検証** / approval validator / policy weakening detector（条件付き二者承認・クールダウン込み） / **sidecar と検証スクリプト群の guard-invariants 登録** / **human-copy 適用フローの工程化** / hook guard拡張 / **track-selection 契約の PLUGIN-CONTRACTS 改訂と consumer 移行** / 3環境テスト（**hook 稼働ハンドシェイク含む**）

## Epic A2：Capability Registry
実装: Registry schema / structured predicate DSL（trigger 含む・意味論準拠） / Gate stage（implementation のみ実装、artifact/promotion 予約） / Lite eligibility / minimum enforcement / **registry_digest 発行** / duplicate検査 / Provider名混入検査 / **projection 生成（scripts/generated/ 配下・保護対象）**

## Epic A3：Component Path Ownership
実装: include・exclude / shared path / overlap detection / unowned path detection / **git diff 基準（merge-base + untracked + rename follow）** / reverse coverage / **ownership_digest 発行** / monorepo fixture / **specs/ 等 cross-cutting path の事前登録**

## Epic A4：Facet Manifest（v2: 旧A5と順序入替）
実装: schema / context projection hash / registry_digest・ownership_digest 束縛 / affected component / required・conditional facet / N/A理由 / stale detection / resolver version policy
（Resolver 実装より先に出力の型を確定する）

## Epic A5：Capability Resolver（v2: 旧A4）
入力: Project Context / Affected Components（**§12 の決定論的導出のみ。v1 の「Change Characteristics」は削除** — 自己申告入力を新設しない。将来必要になれば導出規則・検証Gateとセットで ADR 化） / Registry
出力: Facet Manifest / Capability Summary / Context Projection / Resolver Evidence
曖昧な場合はBlockする。

## Epic A6：Lite統合
実装: Capability-aware risk-upgrade / lite eligibility / capability-summary.yaml / lite gate checks / full upgrade / artifact生成前Block / **保護ファイル（lite-spec SKILL / risk-upgrade-policy）変更の human-copy 工程**

## Epic A7：Compatibility
byte-identical deterministic test / structural compatibility test / **orchestration event test（loop-inventory / 共有 loop driver / run record の拡張として実装。新規スイートを作らない）**

## Epic A8：3環境 統合検証（v2: 役割を変更）
cross-runtime handoff E2E / install・uninstall マトリクス（All|Codex|Claude|Copilot） / hook guard 横断テスト（**稼働ハンドシェイク含む**） / path・line-ending 回帰。
個別成果物の 3 環境化は各 Epic の Done 条件（§7）であり、A8 には持ち越さない。

## Epic A9：Dogfood
sdd-forge自身をProject Context化する。
最初は artifact_layout: legacy-seven-layer / capability_enforcement: advisory。
その後 facet-hybrid / required へ昇格。
（v2 注記: required→advisory の差し戻しは policy-weakening だが、単独メンテナ時は第1承認+クールダウンで実行可能 — §9）

---
# 20. 改訂後の実装開始条件（v2）

Epic Aへ着手できる条件:
- workflow axes と **track-selection 契約**がADRで確定
- Gate stageがschema化され、**Foundation の実装範囲（implementation のみ）が明記**されている
- Lite matrixが確定（**フォールバック2行を含む**）
- Predicate DSLが**評価意味論込みで**確定
- **Approval Sidecar方式（全書込拒否 + HMAC + 条件付き二者承認）**が確定
- **canonical 化仕様（YAML 1.2 + JCS + 単一実装）**が確定
- component path schema と **git diff 基準**が確定
- Registryが唯一のGate正本になり、**registry_digest / ownership_digest による staleness 束縛**が定義されている
- 3環境対応が各TaskのDone条件に入り、**hook 稼働ハンドシェイク**が定義されている
- Legacy互換テストが実装可能な定義になっている（**既存 loop 基盤の拡張として**）
- sdd-incident（および sdd-operability / sdd-delivery の新設）が初期scopeから削除されている
- **保護ファイル変更を伴う工程に human-copy フローが織り込まれている**

最初の実装単位は **A0〜A3**とし、Resolver本体より先に正本・承認・条件言語・path ownershipを固定する。

---
# 付録: レビューで却下された攻撃（設計の堅牢性の証跡）

- 「Task Done を production 生存確認に依存させるべき」→ offline 開発・権限のない contributor・provider 障害時に完了不能となり却下（三段分離が正当）。
- 「provider 名を capability ID に埋めるほうが単純」→ provider 置換時に Registry・gate・schema 全体の複製が必要になり却下。
- 「.gitattributes 未設定クローンで hash が壊れる」→ canonical 化が改行を正規化するため不成立。
- 「SDD_SUDO の別経路バイパス」→ 外部鍵 HMAC + TTL + repo-binding + 設定ファイル保護で不成立（実地でガードの拒否動作も確認）。
- 「最初から cloud API を dogfood すべき」→ credential・課金・provider 障害が framework 欠陥と混ざるため却下。
