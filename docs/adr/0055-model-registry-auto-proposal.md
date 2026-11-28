# ADR-0055: モデル表を契約から生成し、公式ページに基づく更新案を週次で自動起票する

- **Status:** Accepted
- **Decision:** 2026-11-28、リポジトリ所有者がティアとモデルの対応表、役割ごとの下限、表の生成、系列による分類、および自動マージなしの週次更新案 PR を承認した（PR #976 の作業中の承認「この決定と案で進めてよい」）。
- **Date:** 2026-11-28
- **Extends:** [ADR-0038 (Role policy with live model availability and immutable run selection)](0038-current-model-role-policy.md)、[ADR-0050 (Session model preferences without weakening launch admission)](0050-session-model-preferences.md)
- **Numbering Re-Verification (WFI-013):** 起票時（2026-11-28）に `origin/main`（`4876b04e`）の `docs/adr/` に `0055` がないこと、オープン PR 2件（#976 と #989）の変更ファイルにも `0055` がないことを確認した。マージ直前にもう一度確認する。

## 1. Context

- モデルの対応表が `docs/agent-capability-matrix.md` や `agent-delegation-policy.md` などに手書きで重複していた。登録（`contracts/agent-model-capabilities.v2.json`）や方針（`contracts/model-policy.v1.json`）と食い違い、退役したモデルや存在しない組み合わせが残っていた。
- 既存の `model-freshness-check.yml` が見るのは Anthropic と OpenAI だけで、乖離を検知しても issue を作るだけだった。そのため、表を最新にする作業は毎回人が手でしていた。
- 2026-11 時点のマルチエージェント開発の知見を採った。強いモデルが判断を担い、探索などの下位作業は安いモデルに任せる。ただし、モデルの段階を増やす前に「最も強いモデルを低い effort で使う」場合を測る。

## 2. Decision

1. **唯一の情報源は契約に置く。** 登録・方針・系列規則（`contracts/model-families.v1.json`）を唯一の情報源とする。文書の表は `scripts/render-model-routing-docs.py` で生成し、`--check` で差分を検出して失敗させる（`tests/agent-model-routing.tests.sh`）。
2. **役割の下限は固定せず、検査で守る。** エージェント定義は呼び出し元のモデルを引き継ぐ（`model: inherit`）。下限は登録の `role_defaults` に置き、`sdd-gate` が評価者の実際のモデルを記録して `model-tier.py check --role sdd-evaluator` で照合する。下限は次のとおり。
   - 評価者（evaluator）: 全ホストで `strong`。
   - investigator: `lightweight`、effort は `low`。
   - レビュアー: `standard`、effort は `medium`。
3. **ティアは系列で判定する。** `model-families.v1.json` の系列規則でモデル ID からティアを判定する。既知の系列の新しい版は、登録を書き換えなくても分類できる。どの系列にも合わない ID は `unclassified` とし、どの下限も満たさない。
4. **公式ページから更新案を週次で自動起票する。** `.github/workflows/model-registry-update.yml` が週次と手動で `scripts/update-model-registry.py --fetch --write` を実行する。取得するのは Anthropic、OpenAI、Google の公式モデルページ。変更があれば、検証（生成表の `--check`、系列・更新・方針・ルーティングの各テスト）を通してから更新案の PR を開く。
   - **追加するもの:** 登録済みの系列のうち、登録済みの同系列より新しい版だけを追加する。
     - 効力（effort）は同系列の最新の登録から写す。
     - `lifecycle` は `current`、`adoption` は `[]` とする。そのため一覧と下限の照合には出るが、採用の根拠を記録するまでは自動では選ばれない。
     - 方針の選好順では、同じベンダーで同じティアのモデルの前に入れる。
   - **報告だけにとどめるもの:** 次の場合は何も変更しない。
     - 新しい系列。
     - 古い版。
     - メジャー版の2世代以上の飛び越し。
     - 公式ページに見当たらない現行モデル（`lifecycle` は自動で変えない）。
     - 取得できなかったベンダー。
   - **取得したページは信頼しない入力として扱う。**
     - モデル ID はコード表記の中からだけ読む。コード表記とは、HTML の `<code>`、Markdown のバッククォート、Markdoc の「Model code **id**」の3つ。見出し・アンカー・URL のスラッグは読まない（スラッグは版番号の点を落とすため、`gemini-25-...` のような偽の ID になる）。
     - 読んだ ID は、ベンダーごとの固定パターンに合うものだけを使う。日付付きのスナップショット ID は対象外。
     - それ以外のページの文章は、契約・文書・PR 本文のいずれにも入れない。
   - **自動マージはしない。** 未マージの更新案 PR がある間は、新しい更新案を作らない。
5. **権限を分ける。** 新しいワークフローだけに `contents: write` と `pull-requests: write` を与える。`model-freshness-check.yml` は従来どおり issue 起票だけを行い、`pull-requests` 権限を持たない（TEST-005 の固定はそのまま）。PR の作成には、登録されていれば既存の fine-grained PAT（`SDD_SESSION_PR_TOKEN`）を使う。未登録なら既定トークンで作り、CI が起動していないことを PR 本文に明記する。

## 3. Consequences

- 表の更新に手作業が要らなくなる。人が判断するのは、更新案 PR のマージと、モデルを採用する根拠（`adoption`）の記録だけになる。
- 新しい系列や命名規則の変更は自動では取り込まれず、`unclassified` として報告される。系列規則を更新するのは人である。
- ベンダーがページの構成を変えると、取得できる ID が減ることがある。その場合は、`not_seen` の報告から人が気づく。誤った ID を追加するよりも、追加しないほうを選ぶ。

## 4. Alternatives Considered

- **エージェント定義にモデルを固定する案:** ホストごとに名前が異なり、新しい版が出るたびに定義の編集が必要になるため採らなかった。
- **公式ページの内容で登録を直接上書きして自動マージする案:** 取得したページは信頼できない入力であり、所有者の判断を経ずに契約を変えることになるため採らなかった。
- **鮮度チェックのワークフローに PR 作成を足す案:** 鮮度チェックが権限を持たないことは、TEST-005 で固定した設計上の決定である。そのため、権限を持つワークフローは別に分けた。
