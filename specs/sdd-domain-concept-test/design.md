# Design: sdd-domain-concept-test

Impl-Review-Status: Passed
Status: Draft — no review or implementation approval

## Architecture

既存bootstrap intake → Concept Test proposal/human confirmation → feature証跡 → 既存domain-sync。v2契約検査はPhase0のvalidate-domain-contract twinsを再利用する。Concept Testはdomain/を読むだけで、更新は後続authoring運用へ返す。

現在syncはv1を読む (`plugins/sdd-domain/skills/domain-sync/SKILL.md:60-63`)。対象consumerをv2へ一括切替する範囲はPhase0 DD-2 (`specs/sdd-domain-concept-contract/design.md:25`) と整合させ、旧v1資産移行機能は作らない。

## Data Plan

新契約`contracts/concept-test.v1.schema.json`とfeature側md/jsonを必要とする。必須内容はfeature、4提案分類、根拠、確認済みsame/different/undecided、全読取入力path+sha256。非FITSにはdecisionと署名付きapproval sidecarを必須とする。md/json判断差、入力不足・hash変化を拒否する。既存signed approvalのcontent/hash/HMAC/registry標準検証を再利用し、concept-test型登録とfeature内path対応を追加する。現enum/mappingは2型限定 (`contracts/approval-sidecar.schema.json:8`; `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:152-163`)。標準検証 (`同:909-922`) を使い、content/registry未照合のprovenance-only (`同:925-931`) で代替しない。共有登録はreview時と実装前に再確認する。新暗号方式なし、署名生成はHuman/CI-only (`plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py:579-585`)。

## Deterministic Gate

AC-015は既存signed approval標準検証に対応付ける。TEST-030〜034のsidecar不存在、署名改ざん、鍵不存在、未登録承認者、decision文字列のみの各入力を個別にBLOCKとし、skipやprovenance-onlyで代替しない。BLOCK時はdomain-syncと後続生成を呼び出さない。

domain-sync前にJSON不存在・構造不正・非FITSのdecision欠如・署名不正・未登録承認者・入力hash差・md/json判断差を決定論で検査する。LLM意味判断はgate verdictを直接決めない。quality-gateへのLLM追加を禁ずる既存計画P-6 (`reports/notes/concept-design-layer-plan-adversarial-review.md:94-98`) を守る。証跡妥当性と実行結果を分離し、FITS/proceedは続行、deferは保留、rejectedは停止。保留/停止ではdomain-syncも後続生成も呼ばない。入力変更時は再提案・再人間承認が必要。

## Review Context and Release

sh/ps1の許可集合、対応precheck/input manifest、公開manifestを一貫して更新する。現行入力集合の根拠は`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:254-285`。実装直前に両twinと全callerを再確認する。既存frozenレビュー証跡を新入力集合へretrofitしない。

## Test Strategy

acceptance-tests.mdのfixtureで4提案、3decision、domain不在、破損入力、manifest完全性を検査する。Phase0契約suiteを回帰検証する。sh/ps1両twinのcase sensitivityは独立したoperator/cmdlet sweepとmis-cased negative fixtureを必要とする。

単体検証の対象は、新しいConcept Test契約検査のJSON構造・列挙値・md/json一致・入力path/hash一致、および証跡検証結果から続行/保留/停止を選ぶ処理とする。下流のdomain-syncと後続生成だけを呼出順・回数を記録するspyに置換し、不正/保留/停止で各0回、続行でdomain-sync→生成の順となることを検証する。標準approval検証はモックせず、隔離した一時鍵・登録済みテスト承認者を使った実署名・content/hash/HMAC/registry検証を統合検証し、TEST-030〜034の拒否を実際の検証器で確認する。鍵・registry・署名検証結果を固定値で代替しない。TEST-035〜078の入力差替え・md/json差・manifest欠落検証と既存Phase0回帰も保持する。

## Open Questions

OQ-001/002はrequirements.mdの2026-09-28 owner決定で解決済み。同文書Governing Amendmentsが保存済みlayerの旧未解決spanより優先する。後続レビューは同じmd/json/sidecarと全入力path+hashを予約manifestに束縛し再検証する。shared ADR番号は実作成時に確認する。2026-09-28のspec-review attempt-1 round-2は独立A/BともPASS、保存済みcontractと通常workflow-state検証によりSpec-Review-StatusをPassedへ正規化した。requirements.md Preflightの「レビュー未実施」はintake時点の記録であり、現在の仕様レビュー状態は同文書statusとround-2 contractを優先する。設計レビュー未実施、tasks/traceability未生成。
