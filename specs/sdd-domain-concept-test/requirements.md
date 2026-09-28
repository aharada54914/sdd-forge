# Requirements: sdd-domain-concept-test

Spec-Review-Status: Passed
Source: GitHub issue #290, Phase 1
Status: Draft — owner decisions recorded; no review or implementation approval

## Overview

Feature単位のConcept Testをdomain-sync前段へ追加し、概念の責務境界を人間が判断できる証跡として残す。Phase 0のv2契約・validatorを再利用する。Phase 2〜4のauthoring、reviewer再編、reverse、C4移管は対象外。

## Approved Scope and Requirements

- REQ-001: v2 concepts[]とfeatureの要求を読み、`FITS_EXISTING_CONCEPTS` / `NEW_CONCEPT_CANDIDATE` / `RESPONSIBILITY_CONFLICT` / `REQUIRES_HUMAN_DECISION`の提案を`specs/<feature>/concept-test.{md,json}`に記録する。TermとConceptを混同しない。
- REQ-002: same/different/undecidedは人間が決定する。未来の仮想シナリオだけからConceptを自動追加しない。domain/は変更しない。
- REQ-003: v2 full profileのゲートは記録不存在または非FITSへの人間decision未記録をBLOCKとする。LLM判定単独ではBLOCKしない。既存計画のdecision値は`proceed` / `defer-to-domain-update` / `rejected`。
- REQ-004: bootstrap intakeからdomain-sync前段で呼ぶ。domain/不在の従来生成を保持し、lite統合は範囲外。v2 consumer切替はこのPhaseの対象consumerで一括実施し、二重version loaderやupgrade modeを作らない。
- REQ-005: concept-test.md/jsonをreview-contextの入力クラスへ登録し、予約時の完全入力と記録に基づく監査を保証する。
- REQ-006: skill公開に必要な三重manifestとrelease surfaceを既存パターンに従って更新する。

## Existing Behavior Evidence

- bootstrapは現在domain-syncを先に呼ぶ: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:33-42`。
- syncはv1 schemaを読む: `plugins/sdd-domain/skills/domain-sync/SKILL.md:60-63`。
- concept-test入力クラスは現行許可集合にない: `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:254-285`。実装直前にsh/ps1両方の集合を再確認する。
- Phase0決定は単一context所属、二重loaderなし、v2専用validator: `specs/sdd-domain-concept-contract/design.md:24-30`。
- decision三値と機械ゲートの根拠: `reports/notes/concept-design-layer-plan-adversarial-review.md:60-71`。同文書`:214-216`のowner決定が旧移行案に優先する。

## Open Questions

- OQ-001 (resolved, human / repository owner, 2026-09-28): 既存signed human approvalを再利用して本人証跡を検証する。decision文字列だけでは認めず、新暗号方式・鍵管理を作らない。
- OQ-002 (resolved, human / repository owner, 2026-09-28): `proceed`のみ続行、`defer-to-domain-update`は保留、`rejected`は停止。domain-sync前に評価し、後続レビューは同じ証跡を束縛する。
- OQ-003 (non-blocking, resolved observation): 現入力にはlocal mockup/visual referenceなし。非GUI skillの任意視覚資料として `No mockup provided — optional visualization skipped` を記録する。

## Preflight

Base: 96c040a6cf7644981f94956e0878092d0ac85c04
Hook handshake: own canary cd7c492a3f117bd7855fcc69f3e6676d, installed host-denial adapter HOOK_ACTIVE (exit 0)
Structure: check-sdd-structure OK; advisory CLAUDE.md
Track: full (project-context physically absent; compatibility fallback)
Domain sync: domain-sync skipped: no domain/ directory

上記Preflightは既存intake時の観測であり、今回のfresh handshake実行証拠ではない。レビュー未実施。tasks生成・実装承認は既存レビュー順序に従う。

## Governing Amendments (2026-09-28)

REQ-003の「decision記録ありならゲート通過」は証跡妥当性の意味であり、生成許可ではない。人間承認は署名、登録承認者、content hashを検証する。署名対象はfeature、提案分類、根拠、same/different/undecided、decisionおよび全読取入力のpath+sha256。入力不存在・hash変化、md/json不整合、sidecar不存在、不正署名、未登録承認者、鍵不存在はBLOCK。FITSはdecision不要だが確認済みsame/different/undecidedと入力hashを含む有効証跡が必要。

REQ-004の具体的結果: FITSは有効証跡で続行、非FITSは有効な署名付きproceedのみ続行。deferは保留、rejectedは停止し、いずれもdomain-syncと後続生成を呼ばない。後続レビューは入口と同一md/json/approval sidecarと全読取入力をmanifestへ収録しhashを再確認する。入力変更時は再提案・再人間承認まで停止する。

現sidecar enumとvalidator mappingはproject-context/provider-bindings限定 (`contracts/approval-sidecar.schema.json:8`; `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:152-163`)。concept-test契約登録とfeature内path対応を実装対象に含め、標準検証content/hash/HMAC/registry照合を再利用する (`同:909-922`)。provenance-onlyはcontent/registry照合しない (`同:925-931`) ため本人証跡に代用しない。共有登録はspec/design review時と実装直前に再確認する。署名生成はHuman/CI-only境界を維持 (`plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py:579-585`)。

既存layerはbootstrap create-only規則でbyte保存する。次の旧未解決記述には本節とOQ-001/002を優先する: frontend-spec.md State and Testing / Open Questionsの本人確認委譲・owner待ち、infra-spec.md Open Questionsのゲート時点block、security-spec.md STRIDE表Spoofing行 / Authorization / Open Questionsの本人証跡未解決・後続fail-open条件待ち、ux-spec.md Component States / Open Questionsの後続処理待ち。現在の未解決事項ではなく、negative testsはacceptance-tests.md AC-015以降で具体化する。
