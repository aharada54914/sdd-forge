# 敵対的レビュー: Concept Design Layer 追加計画（ChatGPT 原案）

**Date**: 2026-08-16
**Reviewer**: Claude (反証優先・file:line 根拠・却下所見保持。`skills/adversarial-review/SKILL.md` の鉄則を文書レビューに転用)
**対象**: ユーザー提供の ChatGPT 原案「Concept Design Layer を sdd-domain に追加するリファクタリング計画」（§1〜30、Epic A〜H、CD-001〜032、AC-C01〜C15）
**前提資料**: Zenn 記事の敵対的レビューは `reports/notes/concept-design-article-adversarial-review.md`（以下「記事レビュー」）。本書はその §D-1（原案照合）を解消するもの。

---

## 総評

**方向は支持する。** 原案の中核 — Concept を Context / Aggregate と同格の一級モデル要素にする、Term ≠ Concept の分離、Concept Distinction Matrix、投機的概念の自動追加禁止、v1/v2 スキーマ共存によるオプトイン移行 — はいずれも反証に失敗した（§4）。記事レビューで特定した本リポジトリの実ギャップ（F-2: 概念妥当性を見る観点の不在、F-3: 軽量な概念チェック手段の不在)を正面から埋める設計である。

ただし実コードとの突き合わせで **Critical 2 件、Major 6 件、Minor 3 件**の所見が出た。最大の問題は、(1) 自己申告した最重要機能（Feature Concept Test）が実装順の 5 番目に置かれる価値順序の逆転と単一 feature への一枚岩化、(2) 既存 v1 `domain/` 資産のステージ再番号付けに対する移行設計の欠落、(3) LLM 意味判定への直接の fail-closed 接続、である。§3 に修正後計画を示す。

---

## §1 事実照合（原案の前提 vs 実コード）

原案が依拠する現状認識を実コードと照合した。**ほぼ正確**である。

| 原案の前提 | 判定 | 根拠 |
|---|---|---|
| v1 契約は contexts[]/terms[]/aggregates[]/relations[] 構造で、概念境界（責務・must-not-own・区別理由）は表現不能 | 正確 | `contracts/domain-contract.v1.schema.json:36-137`（`additionalProperties: false` のため v2 は別スキーマが必須、という含意も正しい） |
| 現行 7 ステージは C4 Container を canonical stage に含む | 正確 | `plugins/sdd-domain/skills/domain-model/SKILL.md:131-139`; `domain-interviewer/SKILL.md:117` |
| domain-sync は Never-Block・semantic matching・Bounded-Context/canonical term/aggregate 参照の注入 | 正確 | `plugins/sdd-domain/skills/domain-sync/SKILL.md:85-95`（LLM 判定明記）, `:171-180`（Never-Block Guarantee） |
| Reviewer A は境界/relation/event coverage/term uniqueness/aggregate ownership、B は invariant/transaction boundary/god aggregate/anemic model 等 | 正確 | `plugins/sdd-domain/agents/domain-reviewer-a.md:68-99`, `domain-reviewer-b.md:69-100` |
| Reverse mode は candidate contexts/terms/event hints/aggregate hints/open questions を抽出 | 正確 | `plugins/sdd-domain/skills/domain-reverse/SKILL.md:79-94`（全 candidate に INV-NNN + file:line 必須） |
| 域内 C4 テンプレは bootstrap の generic テンプレ由来 | 正確 | `domain-interviewer/SKILL.md:238` が bootstrap テンプレを明示参照 |
| check-domain-conformance は決定論的（grep ベース）で warn、`SDD_DOMAIN_ENFORCE=error` で昇格 | 正確 | `plugins/sdd-quality-loop/scripts/check-domain-conformance.sh:2,46,133-138` |
| 変更対象 `tests/sdd-domain/*` | 正確 | 11 の Pester スイートが存在（artifact-set / contract-schema / update-mode / domain-review-loop / domain-sync / reverse-seed / absence-regression / cross-model-gate / drift-metrics / template-language / check-domain-conformance） |

事実誤認と呼べるものは見つからなかった。以下の所見はすべて「前提は正しいが、そこから導いた計画の構造に問題がある」類である。

---

## §2 所見

### P-1（Critical）: 価値順序の逆転と単一 feature への一枚岩化

原案 §28 の実装順は Contract v2 → テンプレ → Interviewer → Reviewer → **Concept Test（5 番目）** → bootstrap 統合 → … であり、§28 自身が「ユーザー価値として一番重要なのは 5〜6」「Concept Test が完成して初めて Concept Design Layer 完成」と認めている。最重要成果物が、最も破壊半径の大きい改修（8 ステージ再構成・レビュアー再編）の**後ろ**に置かれている。8 ステージ化は Concept Test の前提条件ではない: Concept Test が必要とするのは v2 契約の concepts[]（responsibilities / must_not_own / distinguished_from）だけであり、初期の concepts[] は移行期には人間の手書き＋軽量確認で成立する（原案自身の思想 — same/different は常に人間決定 — とも整合する）。

また CD-001〜032（32 タスク）を単一 feature `specs/sdd-domain-concept-design/` に載せる推奨（§30）は、本リポジトリのタスクサイズ運用（`reports/notes/epic-189-a1-decision-7-task-size-resolution.md` に裁定実績）と衝突し、task-review-loop を一度に通せる規模ではない。

**修正**: エピック親 issue + 複数 feature へ分割し、Concept Test を 2 番目の feature に前倒しする（§3 の Phase 構成）。

### P-2（Critical）: 既存 v1 `domain/` 資産のステージ移行設計が欠落

原案 §17 の互換表は**契約とゲート挙動**（v1 → legacy sync / v2 → concept-test）のみを扱い、**アーティファクトセットとステージ番号**の互換を扱っていない。実装上の衝突点:

- `domain-model` update mode の前提条件は「7 つの canonical stage artifact が全て存在すること」(`plugins/sdd-domain/skills/domain-model/SKILL.md:117-122`)。既存 v1 プロジェクトには concept-model.md が存在せず、8 ステージ表に切り替えた瞬間、v1 資産は update mode を通れなくなる。
- ステージ表は 2 つの SKILL に重複定義され「変更時は両方を同期」と明記 (`domain-model/SKILL.md:141-143`)。さらに各テンプレートはヘッダに番号を焼き込んでいる（`domain-story.template.md:3` の `Stage: 1 of 7`、`ubiquitous-language.template.md:3` の `Stage: 3 of 7`）。再番号付けは既存アーティファクトのヘッダと不整合を起こし、update mode の byte-identical 検証（`domain-model/SKILL.md:149-152, 182-187`）と衝突する。

**修正**: (a) ステージ表をアーティファクトセットの宣言バージョン（domain-contract の schema 値）で引く versioned stage table にする。(b) `domain-model upgrade` モード（新設）を移行経路として定義する: 既存 7 artifact は保持したまま concept 抽出インタビューだけを走らせて concept-model.md をバックフィルし、status を Pending に戻して再レビューに送る。v1 のまま留まるプロジェクトは旧 7 ステージ表で update mode が従来通り動く。これを AC に追加する（§3 AC-C16）。

### P-3（Major）: LLM 意味判定への直接 fail-closed 接続

原案 §18・CD-020 は「v2 では非 FIT を BLOCK」とする。しかし concept-test の 4 判定は LLM の意味判定であり（原案 §11 自身が Layer 2 は完全決定論不可と認める）、同一入力で判定が揺れる非決定論的ゲートになる。本リポジトリの fail-closed は決定論的検査に適用され、LLM 判定は人間へフェイルする設計である（cross-model の `requires_human_decision`、ADR 0015; domain-sync の Never-Block; 記事レビュー C-3 の裁定手続き問題と同型）。

**修正**: ゲートの機械条件を決定論的な**記録の存在**に置き換える:

```
BLOCK 条件（決定論的）:
  - specs/<feature>/concept-test.json が存在しない
  - 非 FITS 判定に対する人間の decision 記録が無い
通過条件:
  - FITS_EXISTING_CONCEPTS、または
  - 非 FITS + 人間 decision（proceed / defer-to-domain-update / rejected）が記録済み
```

LLM の生判定そのものでは決して BLOCK しない。人間は「例外として進む」を選べ、その選択は concept-test.json に監査可能な形で残る。§18 の governed 姿勢は維持され、ゲートは決定論に戻る。

### P-4（Major）: レビュー契約・precheck の破壊半径が計画に不在（WFI-027 の教訓）

domain reviewer A/B は固定 allowed-input manifest（`domain-reviewer-a.md:20-38`）と固定順序の check ID 配列（`:124-125`）を持つ厳格な出力契約であり、`domain-review-precheck.{sh,ps1}`・identity ledger・`tests/sdd-domain/` の 11 スイートがこれに依存する。concept artifact を manifest に追加する CD-013 は、**issue #288 / WFI-027 で今まさに顕在化した failure と同型**を踏む: 既存契約が知らないファイルクラスを precheck が生きた filesystem と照合すると、新 artifact 追加以前に完了した v1 ドメインレビューの契約が恒久的に invalid になる。

**修正**: WFI-027 の裁定を初日から適用する — 監査は**記録（契約が宣言した入力）**に対して行い、concept artifact の完備性要求は**予約時**（新規レビュー開始時）にのみ、かつ v2 アーティファクトセットに対してのみ課す。feature 側の `specs/<feature>/concept-test.{md,json}` も同じ扱いで `validate-review-context-set` に登録する（spec/impl レビュー契約に対する #288 の再発防止）。

### P-5（Major）: Reviewer A のチェック肥大と「自然さ」判定の Major 化

原案 §12 は Reviewer A に新規 8 check を追加し（既存 6 と合わせ実質 11 以上）、§21 は "poor semantic naming" を Major に置く。チェックリスト肥大は generic-checklist 化と severity inflation を招く（`skills/adversarial-review/SKILL.md:73-79` が自認する失敗モード）。また命名・責務の「自然さ」を blocking にすることは、記事レビュー C-3/C-5 の裁定（主観判定に裁定手続きが無い; advisory 限定）に反する。

**修正**: 新規チェックを 4 つに統合し、severity を根拠の客観性で分ける:

| 新 check ID | 統合元 | Severity | 根拠の性質 |
|---|---|---|---|
| `CONCEPT-DISTINCTION-JUSTIFIED` | IDENTITY-CLARITY + DISTINCTION-JUSTIFIED + EVIDENCE-TRACEABILITY | Major | 記録照合（definition/essence/distinguished_from/evidence の欠落・宙吊り参照） |
| `MULTI-ROLE-CONCEPT` | MULTI-ROLE + RESPONSIBILITY-NATURALNESS の客観部分 | Major | 記録照合（同一 responsibility が複数 concept に出現 / must_not_own と responsibilities の矛盾） |
| `STAKEHOLDER-PERSPECTIVE-COVERAGE` | 同名 | Minor | 助言（欠落の指摘であり、内容の当否は人間） |
| `NAME-SEMANTIC-FIT` | NAME-SEMANTIC-FIT + NATURALNESS の主観部分 | Minor | 助言 |

既存チェックの A↔B 再配置（event/message trace を B へ移す等）は、両契約と precheck・テストを同時に壊す割に必要性の証拠が無い churn であり **Phase 1 では却下**、Phase 3 で運用実績を見て再検討する。

### P-6（Major）: Layer 2「LLM concept reviewer」を quality-gate に置くのは思想違反

原案 §11 は conformance を Layer 1（決定論）+ Layer 2（LLM）に分け、Layer 2 を check-domain-conformance 側へ足す。しかし quality-gate の conformance は「grep-only の決定論的検査」として意図的に設計されている（`check-domain-conformance.sh:46` のコメントが design-system 検査との整合を明記）。LLM 判定を quality-gate に注入すると、Done 判定の再現性が壊れる。

**修正**: Layer 2 は既存の LLM レビューゲートに載せる — (a) feature 入口の concept-test（原案 §9、そのまま）、(b) spec-review の既存 `DOMAIN-CONFORMANCE` 観点の v2 拡張（responsibility / must_not_own 照合を追加。`plugins/sdd-review-loop/agents/spec-reviewer-a.md:87-98` は保護外ファイルで変更コスト小）。quality-gate への追加は決定論的な分（concept-test.json の存在と decision 完備性 — P-3 のゲート条件）に限定する。

### P-7（Major・設計決定要）: concepts[] のコンテキスト所属が曖昧

原案 §16 の v2 概略はトップレベル `concepts[]` + `contexts[].concept_ids[]` で、1 概念の複数コンテキスト共有を許す。だが記事の核心例は「営業の言う Order と倉庫の見る Order は**別概念**」であり、グローバル概念の多重参照はスキーマレベルで「一概念二役」を再導入しかねない。また terms[] と concepts[] の連結が未定義（Term ≠ Concept と言いながら、term がどの concept の名前なのかを表現する場が無い）。

**修正**: design.md の明示的決定事項とする。推奨: concept は **単一コンテキスト所属**（コンテキスト間の「同じに見えるもの」は `distinguished_from` ないし context relation で表現）、`term.concept_id` を v2 で追加（v1 由来の term は省略可として移行猶予）。受け入れテスト: 「同名別概念が 2 コンテキストに存在するモデルを表現でき、かつ MULTI-ROLE-CONCEPT が誤検出しない」fixture を必須にする。

### P-8（Minor）: UPSTREAM_CONCEPT_ISSUE の再オープン回数が非有界

原案 §13/Epic E の下流→上流再オープンは支持するが、domain-review-loop の 3 ラウンド上限の**外側**に新しいループを作るため、上限が無いと循環し得る。

**修正**: 再オープンは 1 レビュー attempt につき 1 回まで。同一 concept への 2 度目の UPSTREAM_CONCEPT_ISSUE は `requires_human_decision` に落とす（cross-model 不能時の既存規約と同型）。再オープン記録（発見ゲート・根拠・対象 concept）を必須にする。

### P-9（Major）: ステージ内部の自己矛盾と成果物の命名衝突

原案内部に 2 つの構造矛盾がある:

1. **Stage 3 の成果物が Stage 4 の仕事を先取りしている**: §4 の concept-model.md テンプレは `Canonical Name: Order` を含むが、命名は §3 の表で Stage 4（UL）の主目的である。後段ステージが前段アーティファクトを書き換える構図は、interviewer の create-only checkpointing 契約（「どのステージのアーティファクトも、後のステージ開始後には書かれない」`domain-interviewer/SKILL.md:130-144`）に違反する。
2. **`domain/concept-tests.md`（§7、ドメイン恒常資産）と `specs/<feature>/concept-test.md`（§9、feature 単位）がほぼ同名**で、役割は全く異なる。運用上の誤読・誤配置を誘発する。

**修正**: (1) Concept 発見・境界・命名・ストレス検証を**単一の Concept Model ステージ**に統合し、成果物も `domain/concept-model.md` 1 つにする（Distinction Matrix と Stress Scenarios はその節）。UL ステージは concept を入力に、term 表（JA 対訳・forbidden synonyms・term↔concept 連結）を作る現行役割に集中する。副次効果として、C4 分離後の総ステージ数は 8 ではなく **7 のまま**になり、churn の説明も簡潔になる。(2) ドメイン側の名称から "test" を外し（concept-model.md 内の Stress Scenarios 節）、"concept-test" は feature 単位の産物だけを指す語に予約する。

### P-10（Minor）: lite トラックとの関係が未定義

v2 governed と sdd-lite（3 ファイル軽量トラック）の関係が無言。silent gap は「網羅した」と誤読される。

**修正**: Phase 1〜2 では lite を明示的にスコープ外と宣言する（v2 project で lite を使う場合 concept-test は任意）。将来の統合は sdd-lite の risk-upgrade 機構への接続として別途設計（`lite-spec/SKILL.md` は hook-guard 保護ファイルのため human-copy フロー ADR 0011 が必要になる点も先に明記しておく）。

### P-11（Minor）: 新スキル追加の運用面が変更対象リストに不在

原案 §29 は concept-test/SKILL.md 追加を挙げるが、スキル追加には三重マニフェスト（.claude-plugin / .codex-plugin / .plugin）、marketplace 登録、validate-repository の期待スキル数・可視性契約の更新、release surface テストが伴う（ADR 0015 の Consequences と issue #137 T-001 の前例）。cross-model bundle の v2 対応（CD-014）はパネルコスト増も伴う。

**修正**: 変更対象に上記を追加。コスト増は domain gate PASS 1 回あたりで見積もり、design.md に記載する。

---

## §3 修正後計画

原案の CD 番号を保持したまま、フェーズ分割・順序・内容を修正する。各 Phase = 1 feature（`specs/` 配下に独立の requirements/design/tasks を持ち、AGENTS.md の 3 段階ワークフローを通す）。

### Phase 0 — Concept Contract Foundation（feature: `sdd-domain-concept-contract`）

- CD-001 v2 スキーマ（P-7 の設計決定を含む: concept の単一コンテキスト所属、`term.concept_id`、`distinguished_from` の宙吊り参照拒否、Concept ID 一意）
- CD-002 v1/v2 loader 互換層（domain-sync / conformance / interviewer が共用）
- CD-003 契約検証テスト + **Fixture 先行整備**（原案 Epic H の A/B を前倒し: Purchase-Fulfillment、Book-Bookshelf。fixture を先に書くことでスキーマと後続レビュアーの TDD 基盤にする）

### Phase 1 — Feature Concept Test（feature: `sdd-domain-concept-test`）★最優先の価値

- CD-016 concept-test.v1.schema.json（4 判定 + **human decision 記録**フィールド。P-3）
- CD-015/017 concept-test skill と generator（specs/<feature>/concept-test.{md,json}）
- CD-018 bootstrap intake 接続（domain-sync の前段。skill-to-skill 呼び出しを bootstrap-interviewer SKILL.md に文書化）
- CD-019 domain-sync predecessor 化（v2 契約検出時のみ。v1 は legacy 経路で無変更）
- CD-020' ゲートは P-3 の決定論条件（記録と decision の存在）で実装。LLM 判定での直接 BLOCK は実装しない
- `validate-review-context-set` への新ファイルクラス登録（P-4。#288 の再発防止）
- 移行期の concepts[] は人間の手書き + 対話的確認で作成可能とする（dogfood: sdd-forge 自身または fixture プロジェクトで E2E）

### Phase 2 — Concept Authoring（feature: `sdd-domain-concept-authoring`）

- CD-004 concept-model.template.md（Concepts + Distinction Matrix + Stress Scenarios を単一アーティファクトに統合。P-9。CD-005 は本タスクへ吸収）
- CD-006' interviewer のステージ挿入を **versioned stage table** で実装（P-2。v1 資産は旧表で従来動作）
- **CD-006b（新設）`domain-model upgrade` モード**: v1 → v2 アーティファクトセット移行（concept バックフィル面接 → status Pending → 再レビュー）
- CD-007/008 Distinction interview アルゴリズム（Q1〜Q6 マトリクス。same/different/undecided は人間確認必須）と命名・責務 interview
- CD-009 Stress scenario generator（normal/partial/multiple/retry/failure/cancellation/correction/historical。判定 4 分類。仮想シナリオのみを根拠とする concept 自動追加の禁止 = 原案 §8 の hard rule をそのまま採用）

### Phase 3 — Domain Review v2（feature: `sdd-domain-concept-review`）

- CD-010' Reviewer A に P-5 の 4 check を追加（既存 check の A↔B 再配置は行わない）
- CD-012 calibration reference 拡張（記録照合 = Major / 自然さ = Minor の線引きを明文化）
- CD-013' review input manifest への concept artifact 追加を **audit-against-the-record** 方式で（P-4）
- CD-014 cross-model bundle v2 対応（コスト見積を design.md に記載）
- CD-021〜024 UPSTREAM_CONCEPT_ISSUE（P-8 の回数上限・記録必須付き）と Feature Concept Test → domain-model update handoff
- spec-review `DOMAIN-CONFORMANCE` の v2 拡張（P-6。quality-gate への LLM 注入はしない）

### Phase 4 — Reverse & C4 Separation（feature: `sdd-domain-concept-reverse-c4`）

- CD-025〜028 reverse mode の concept 対応（candidate_concepts / multi-role smell / responsibility conflict evidence。全 candidate に INV-NNN + file:line — 既存規約 `domain-reverse/SKILL.md:94` を踏襲）
- CD-029〜032 C4 の 2 段階分離（Release A: deprecated 化・canonical/review 必須から除外、Release B: bootstrap architecture へ移管）— 原案 §15 をそのまま採用

### Acceptance Criteria の修正

AC-C01〜C15 は維持した上で:

- **AC-C12'**（修正）: v2 project の BLOCK は「concept-test 記録の不存在、または非 FITS 判定への human decision 不記録」に対して発火する（LLM 判定そのものでは発火しない）
- **AC-C16**（追加）: v1 アーティファクトセットは移行完了まで旧ステージ表で update mode を従来通り通過でき、`domain-model upgrade` で v2 セットへ移行できる
- **AC-C17**（追加）: concept artifact 追加以前に終端した v1 ドメインレビュー契約は追加後も valid のまま（audit-against-the-record）

### 原案から却下した項目（理由付き保持）

| 原案項目 | 却下理由 |
|---|---|
| §28 の実装順（Concept Test を 5 番目） | P-1。価値最優先の Phase 1 へ前倒し |
| §12 の既存チェック A↔B 再配置 | P-5。必要性の証拠なき契約 churn。Phase 3 以降に実績を見て再検討 |
| §18/CD-020 の「非 FIT を BLOCK」 | P-3。決定論条件（decision 記録）に置換 |
| §11 の quality-gate への LLM concept reviewer | P-6。spec-review 拡張と concept-test に載せ替え |
| §3 の 8 ステージ表（Concept Model / UL / Stress Test の 3 ステージ分割） | P-9。単一 Concept Model ステージに統合（C4 分離後は計 7 ステージ） |
| §7 の `domain/concept-tests.md` | P-9。concept-model.md の Stress Scenarios 節に統合し、"concept-test" の名は feature 単位産物に予約 |
| §30 の単一 feature `specs/sdd-domain-concept-design/` | P-1。エピック親 issue + Phase 0〜4 の 5 feature に分割 |

---

## §4 反証に失敗した点（堅牢確認）

以下は攻撃を試みたが崩れず、原案のまま採用する:

- **Concept の一級要素化**（§2）: 記事レビュー F-2/F-3 のギャップを埋める唯一の構造的解であり、terms[] への属性追加では distinguished_from / must_not_own の相互参照を表現できない（v1 スキーマの term 定義 `contracts/domain-contract.v1.schema.json:68-88` に拡張余地が無いことを確認）
- **Term ≠ Concept 分離**（§2）: UL テンプレの既存資産（forbidden synonyms / rejected candidates）を毀損せず上に積める
- **Concept Distinction Matrix Q1〜Q6**（§5): 記事の発見的手法の忠実な操作化。AI は提案のみ・人間確認必須の分業は ADR 0015 の思想と一致
- **投機的概念の自動追加禁止**（§8）: 記事レビュー C-6 の逆側ガードそのもの
- **v1/v2 共存 + v2 移行をオプトインの明示的同意にする**（§16-17）: グレースフルデグラデーション方針と整合
- **2 レビュアー体制の維持**（§12 冒頭）: 3 体化しない判断は正しい
- **Reverse mode の concept smell 提示（自動分割なし）**（§14）: 既存の evidence 必須規約に整合
- **C4 の 2 段階分離**（§15）: 即時削除しない判断・bootstrap への移管先も実コード（`domain-interviewer/SKILL.md:238`）と整合

---

## Decision record（2026-08-16, human / repository owner）

**P-2 は撤回**: owner 回答「v1 資産はないから移行設計は不要」。v1 の `domain/` アーティファクトセット・v1 契約インスタンスは存在しないため、`domain-model upgrade` モード（CD-006b）・versioned stage table・AC-C16 / AC-C17 は計画から削除する。v1/v2 スキーマファイルの共存（§3 Phase 0）は維持し、consumer の v2 切替は各 Phase で一括に行う（二重バージョンローダーは作らない）。P-4 のうち v1 ドメインレビュー契約への audit-against-the-record 適用も同じ理由で不要になるが、`specs/<feature>/concept-test.{md,json}` の `validate-review-context-set` 登録（#288 再発防止）は将来の feature に対する措置として維持する。

同日、親トラッキング issue #290 を起票し、Phase 0 を `specs/sdd-domain-concept-contract/` としてスペック化着手。

## §5 残課題

1. Phase 0 着手時に、本書と原案を入力として親 issue（エピック）を起票し、Phase 1 feature から `sdd-bootstrap:bootstrap` でスペック化する。
2. P-7 の concept コンテキスト所属は Phase 0 design.md の明示的決定事項（本書の推奨は単一所属だが、最終判断は人間）。
3. cross-model パネルコスト増（CD-014）の実測は Phase 3 の dogfood で取得し、閾値超過時の縮退（panel 縮小 or concept artifact の projection 化）を design.md の open question とする。
