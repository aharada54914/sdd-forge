# 敵対的レビュー: 「概念設計が、その後のコードの命運を左右する」と sdd-forge 適用計画

**Date**: 2026-08-16
**Reviewer**: Claude (single-context adversarial pass; 反証優先・file:line 根拠・却下所見保持の鉄則は `skills/adversarial-review/SKILL.md` に準拠)
**対象資料**:

1. Zenn 記事「概念設計が、その後のコードの命運を左右する」(takeshi-teshima, 2026-08-14 公開)。PDF 添付版（スキャン画像、CamScanner 透かしあり）を 200dpi でレンダリングし OCR で全文復元。軽微な OCR ノイズはあるが主張の判定には影響しない。
2. ChatGPT 共有リンク (`chatgpt.com/s/t_6a81…`) — **本セッションの egress ポリシーで chatgpt.com がブロックされており取得不能**（Wayback 経由も不可）。計画の原案と推定されるが未読。

**本書の構成**: 原案が読めないため、(A) 記事本体の主張の敵対的レビュー、(B) sdd-forge 実装状況との事実照合、(C) 両者から再構成した修正後計画、の三部とする。原案テキストが提供され次第、§C との差分照合を行う（§D 未解決事項）。

---

## A. 記事の主張の敵対的レビュー

判定は SUPPORT（支持）/ PARTIAL（条件付き支持）/ REJECT（不支持）。反証に失敗した主張のみ計画の根拠に採用する。

| ID | 主張（要約） | 判定 |
|---|---|---|
| C-1 | 概念の切り分けが正しいと、未来の仕様が「実装済み」になっていることがある | PARTIAL |
| C-2 | 概念を正しく分けると、バグの存在余地がそもそも消える | PARTIAL |
| C-3 | 「概念テスト」= 新機能を既存概念の言葉で言い直し、自然さを見る手法は実装前に破綻を検出できる | SUPPORT（advisory 限定） |
| C-4 | 関係者・部署ごとの見え方の違いは概念境界の強い手掛かり | SUPPORT |
| C-5 | 命名にはいくらでも時間を投じてよい | PARTIAL |
| C-6 | 概念設計は KISS/YAGNI と矛盾しない | SUPPORT（逆側ガード欠落） |

### C-1: 「未来の仕様が実装済みになる」 — PARTIAL

反証: 分割発送の例が無変更で成立したのは、Fulfillment が偶々 `quantity` を持っていたからである。同じ Order/Fulfillment モデルでも、隣接領域外の仕様（例: 明細ごとのギフト包装、配送先の分割指定）は救えない。効果が及ぶのは「同じメンタルモデルの近傍から出てくる仕様」に限られ、記事自身も後段でそう限定している（「人が思いつく仕様は…メンタルモデルの範囲内で自然なものになる」）。また「コードを全く変える必要がない」は過大表現で、正確にはドメインモデル層が無変更なのであり、UI・集計・通知は当然変わる。

判定: 方向としては支持。ただし**保証ではなく傾向**。計画文書に効果の約束として書いてはならない。

### C-2: 「バグの存在余地が消える」 — PARTIAL

反証: 概念分離は誤用バグ（0 円 Order の混入）を消すが、代わりに**エンティティ間不変条件の管理コスト**を新設する。記事自身の例に暗黙の不変条件が潜んでいる: Order #42 (quantity 1) に Fulfillment #101 (failed) + #102 (shipped) がぶら下がる時点で、「有効な Fulfillment の数量合計 ≤ Order の数量」という failed 除外付きの制約が生まれているが、記事はこれを一度も明示しない。分離はバグを消すと同時に、バグの居場所を「単一レコード内の意味の混濁」から「レコード間の整合性」へ移す。この移動が純利得になるのは、不変条件が明示され検証される場合のみである。

判定: 支持するが、「分離には不変条件の明示が随伴しなければならない」を計画側の必須条件とする。これは sdd-domain の reviewer B（不変条件の検証可能性・トランザクション境界）が既に担う領分と一致する（`plugins/sdd-domain/references/domain-review-calibration.md:12-15`）。

### C-3: 概念テスト — SUPPORT（advisory 限定）

反証試行: 「自然さ」の判定は主観であり、二人のレビュアーが自然/不自然で対立したときの裁定手続きを記事は与えない。よって**単独の blocking ゲートには不適**。一方、コスト面の反証は失敗した: 概念テストはコードを書く前に文章だけで実行でき、実装者以外（プロダクトデザイナー）にも実行可能という記事の指摘は妥当で、observation として運用する限り誤検出のコストは低い。

判定: 採用。ただし blocking ではなく advisory/observation として。Major 所見化しない。

### C-4: 関係者視点の違い = 概念境界のヒント — SUPPORT

反証試行: 「組織境界をそのままクラス境界にする」という Conway の罠に落ちる読み方が可能だが、記事自身が明示的に否定している。sdd-domain の bounded context / context map の設計思想と完全に一致しており、新規性は「発見のための質問」としての言語化にある。反証失敗。

### C-5: 「命名にいくらでも時間を投じてよい」 — PARTIAL

反証: 非有界の命名議論は bikeshedding 化する既知の失敗モードがあり、本リポジトリのレビューループが最大 3 ラウンドで打ち切る設計（ADR 0015）と正面衝突する。「命名は概念境界を詰める行為である」という中核は支持するが、「いくらでも」は不支持。時間制約（既存ラウンド上限）の内側で扱う。

### C-6: KISS/YAGNI との整合 — SUPPORT（逆側ガード欠落）

反証試行: 「現実を無理なく表現する概念はそもそも余剰ではない」という論理は攻略できなかった。ただし記事は**分けるべきでない場合**の判定基準を示さない。C-4 の裏返し（関係者・語彙・変更タイミングの差という証拠が無いのに分割するのは premature decomposition）を計画側で補う必要がある。

### 記事のスコープ限界（所見、判定対象外）

単一事例・EC 題材であり、(a) 分散システムで Order/Fulfillment を別サービスに置いた場合の結果整合性コスト、(b) 稼働中システムへ概念分割を後付けする際のデータ移行コストに言及がない。sdd-forge 適用は新規モデリング文脈（upstream lane）が主のため計画への影響は小さいが、W-3 のガイド文書には限界として記載する。

---

## B. sdd-forge 実装状況との事実照合

| ID | 事実 | 根拠 |
|---|---|---|
| F-1 | 記事の処方の大半（ユビキタス言語・禁止同義語・却下候補の記録・コンテキスト境界・集約の不変条件レビュー）は **sdd-domain として実装済み** | ADR 0015; `plugins/sdd-domain/skills/domain-model/SKILL.md:131-139`（7 stage 表）; `plugins/sdd-domain/skills/domain-interviewer/templates/ubiquitous-language.template.md:15-37`（Forbidden Synonyms / Term Relationships / Rejected Candidate Terms） |
| F-2 | 記事の「概念テスト」に相当する明示ステップは**未実装**。`DOMAIN-CONFORMANCE` は `domain/` が存在し `Domain-Model-Status: Approved` の場合のみ発火し、`domain/` 不在の feature 単独運用では概念妥当性を見る観点が存在しない | `plugins/sdd-review-loop/agents/spec-reviewer-a.md:87-98`; 同 `:124` および `spec-reviewer-b.md:123` の check ID 一覧に概念系観点なし |
| F-3 | sdd-domain はフルパイプライン（7 stage + 2 レビュアー + cross-model + 人間承認）の**重量級オプトイン**。記事の実践は文章ベースの軽量なもので、中間の軽量な概念チェック手段が無い | ADR 0015（opt-in、`domain/` 不在で挙動不変）; `docs/superpowers/specs/2026-07-03-sdd-domain-plugin-design.md`（グレースフルデグラデーション） |
| F-4 | 保護ファイル制約: impl/task reviewer agents・`ship`/`lite-spec` SKILL は hook-guard 保護で human-copy フロー（ADR 0011）必須。**spec-reviewer-a/b.md と sdd-domain 配下は保護リスト外**（2026-08-16 時点、`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` の対象一覧で確認） | 同生成物の保護パス一覧 |
| F-5 | 本リポジトリ自身の変更は AGENTS.md の 3 段階 SDD ワークフロー（spec → review gates → 承認済み task）を経る必要がある。本書は計画であり、直接のスキル編集はここでは行わない | `AGENTS.md` Required Workflow |

---

## C. 修正後計画

前提: ChatGPT 原案は不達のため、本計画は記事とリポジトリ事実から独立に再構成し、§A の判定を反映した。「概念設計を sdd-forge に取り込む」目的に対する最小構成である。

### 採用する工程（実施順）

**W-1（小、推奨）: domain-interviewer Stage 3 への 2 ヒューリスティクス追記**
記事の発見的手法 2 点 — (a) 関係者視点プローブ（別の主体が・別の理由で・別のタイミングに変更するものは別概念を疑う）、(b) 「それしかない」命名探索（名前が確定しないのは概念レベルの矛盾のシグナル）— を `domain-interviewer` の Stage 3 質問プロトコルへ追記する。テンプレートは既に禁止同義語・却下候補を持つため（F-1）、追加するのは**質問の仕方**のみ。保護外ファイル（F-4）。
Done 条件: 追記が `domain-review-loop` の既存チェック（reviewer A の ubiquitous-language uniqueness）と重複しないこと。C-5 判定に従い、命名探索に独自のラウンド・時間枠を新設しないこと。

**W-2（小〜中、推奨）: spec-review への advisory 概念観点の追加**
`domain/` の有無に依存しない軽量観点（仮称 `CONCEPT-EXPRESSIBILITY`、observation/SKIP 可）を spec レビューに追加する。内容: 「新機能が requirements/design の既存語彙で不自然な責務の押し付けなく言い直せるか。言い直せない場合、名前のない概念が隠れていないか」。C-3 判定に従い **blocking にしない**（Major 化しない）。C-2 判定に従い、概念の分割を提案する場合は随伴する不変条件の明示を要求する。
Done 条件: 既存 check ID 群（spec-reviewer-a.md:124 / spec-reviewer-b.md:123 の各 7 観点）と直交すること、`domain/` 有無の両ケースでのテスト、`DOMAIN-CONFORMANCE` との責務境界（advisory は語彙の自然さ、CONFORMANCE は承認済み契約への準拠）の明文化。
留意: spec-reviewer-a/b.md は保護外（F-4）だが、`contracts/rollback-*.json` が同ファイルを参照するため契約更新の要否を実装 spec で先に調査する。

**W-3（小、任意）: 実践ガイド文書**
`docs/workflow-guide.md` または USERGUIDE に「概念テスト」の節を追加し、記事の要点をリポジトリ語彙（domain lane / spec lane の使い分け、W-2 観点の使い方）で再構成する。C-1 判定に従い効果は傾向として記述し、保証として書かない。§A 末尾のスコープ限界（分散整合性・後付け移行コスト）も併記する。

各工程は AGENTS.md のワークフロー（issue 起票 → spec 化 → レビューゲート）を経由する。本書はその入力資料である。

### 却下した代替案（理由付きで保持）

| 代替案 | 却下理由 |
|---|---|
| 概念設計の新プラグイン / 新レーン新設 | F-1 の通り sdd-domain と重複。ADR 0015 が独立プラグイン案（B 案）を「review-loop/guard/contract 基盤の重複」を理由に却下済みで、同型の判断が適用される |
| 概念テストの blocking ゲート化 | C-3: 「自然さ」の主観判定に裁定手続きが無く、争議所見を量産する。fail-closed 思想は決定論的判定にのみ適用すべき |
| domain レーンの必須化・デフォルト化 | グレースフルデグラデーション方針（`domain/` 不在で既存ワークフロー完全不変、ADR 0015）に反する。CRUD 中心案件・lite トラックへの強制は C-6 の逆側ガード（証拠なき分割の強制）そのもの |
| 記事の Order/Fulfillment 例をそのままテンプレート化 | 単一事例・EC 特化であり、テンプレート化すると事例をドメイン普遍と誤読させる。ガイド文書（W-3）での参照に留める |

---

## D. 未解決事項

1. **ChatGPT 原案との照合**: 共有リンク本文が提供され次第、本計画（§C）との差分を取り、原案固有の項目を §A の判定基準で追加レビューする。
2. W-2 の check ID 追加が `contracts/`（rollback contract、agent-model-capabilities）へ与える影響の調査。実装 spec の investigation 項目とする。
