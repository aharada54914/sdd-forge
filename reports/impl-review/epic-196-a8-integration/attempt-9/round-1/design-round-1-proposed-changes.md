# Implementation Policy Review Report: epic-196-a8-integration — Round 1 / Attempt 9

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Feature | epic-196-a8-integration |
| Round | 1 of 3 |
| Attempt | 9 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 1 |
| Major Findings | 5 |
| Minor Findings | 0 |
| Generated | 2026-10-05T07:41:26Z |

## Reviewer-A Findings (Structural Soundness)

- **DATA-COVERAGE (Major)**: TYPE-D: Data Planの必須項目はdesign.md:256-282にあるが、二つの契約矛盾がある。(1) :540-546はPASS/FAIL時にnotes以外の全値を非nullとし違反をERR_SCHEMA_INVALIDにする一方、:480/:565はskip_reasonをnull必須、:465/:583-587は非Codexのfeature-configをnull必須とする。文字どおり実装すると正当なPASS記録まで拒否され、例外を推測する必要がある。(2) :912-913/:931-933はrepo側だけの対象をadded、installed側だけをremovedとするが、MCP領域の:948-952は同じ欠落・余剰を逆に分類する。欠落MCPブロックの差分種別とnull/hash条件が両立せず、AC-022の厳密な差分判定が実装ごとに分かれる。ともに検証の不一致を招くMajor。

- **TEST-STRATEGY-COVERAGE (Major)**: TYPE-D: design.md:1082-1194は統合・受入検証と具体的な実行先を計画しているが、AC-001の厳密な検証オラクルが未確定。requirements.md:279-287はPhase 2/3前に正確な初期bytesと最終bytes/hashを裁量なく定義するよう要求する。一方design.md:339-340は一つのフィールド/commentを含む将来のfixed stubのみを示し、テンプレート全体・encoding・改行を確定していない。:1086のfixed initial bytesという検証主張を再現できず、実装者が異なるテンプレートを選んでも各自のhash検証が通る。AC-001の予定証拠が一意にならないためMajor。二つの貢献を検証する:342-348の独立nonce変異チェック自体はADR-0035:21-33と一致する。

- **ADR-PRESENT (Major)**: TYPE-D: admitted ADR-0035を全文読み、:21-33/:45-49の二つのnonceを結ぶ判定とdesign.md:340-348の一致を新たに確認した。ただしdesign.md:247-252は新規Ed25519/JCS/Trusted-Signer Registry判断の対応ADRとしてADR-0028を指定し、security-spec.md:125/:176-182もその決定記録を前提とする。design.md:248-249のpathは改行をまたぐため宣言文法に適合せず、precheck-result.json:13とinvocationのADR集合は0035のみである。署名方式の対応ADRはhash-boundな審査証拠として未提供であり、ADR-PRESENTを満たせない。ファイル不在とは判定せず、境界外の読取りも行っていない。新規暗号・信頼登録方式の判断を検証できない証拠不足としてMajor。

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION (Critical)**: TYPE-D: requirements.md:144-146 の『新しい CI topology を提案しない』制約に対し、design.md の必須 Constraint Compliance 節:1656-1676 は CI resilience と B1/B2 のみを扱い、この制約の適合記載または参照を欠く。方針自体は Global Constraints:1575-1578 にあるが、指定された節で要求制約を照合する契約が成立しない。本チェックは同節の未対応制約を明示的に Critical と定めており、進行を阻害する。

- **INTEGRATION-IDENTIFIED (Major)**: TYPE-H: design.md の External Integrations:1613-1621 は Claude/Codex/Copilot CLI と gh-authenticated GitHub access を挙げるが、対応契約・version と unavailable 時の処理を示さない。特に Claude MCP 検証は:439-445 で claude mcp list の output/exit contract を oracle とするだけで、支持する契約とコマンド失敗時の扱いが未規定。OQ-001:1508-1519 の session/headless 確認の延期は、この MCP 検証契約の欠落を解決しない。REQ-002 の present/absent 判定が CLI error と未登録をどう区別するか実装者に委ねられるため、検証不一致を招く Major。

- **VERIFICATION-PATH-CONCRETE (Major)**: TYPE-H: security-spec.md:94-95 は operator_key_id／reviewer_key_id に対応する登録 role の一致を要求する。しかし design.md:561-566,701-715 の validator 規則は key 存在・identity・signature・key collision の照合のみで、operator/reviewer の登録 role を照合する規則を欠く。issuer だけは:634-645 に明示的な role 検査がある。Test Strategy:1160-1185 と security-spec.md:203-208 にも、署名自体は有効な issuer-role key または逆 role の key を operator/reviewer に使った場合の拒否経路がない。domain separation は署名 payload を区別しても登録 role の権限を検査しないため、設計どおりの実装がレイヤ仕様の役割制限を満たさない可能性がある。役割不一致の拒否規則・診断・負例を設計に結合する必要がある Major。

## Proposed Changes

1. DATA-COVERAGE: replace the blanket non-null rule with field-specific conditions. PASS/FAIL requires skip_reason=null; non-Codex feature-config remains null by its existing rule. Align MCP diff direction with the general rule: repository-only=added; installed-only=removed. Retain existing hash/null rejection conditions.
2. TEST-STRATEGY-COVERAGE: specify complete initial and final stub bytes, UTF-8 without BOM, and exactly one LF on every OS. Bind the final content to both independent nonce contributions, with exact digest computation. The current driver uses LF explicitly; do not substitute platform-native CRLF.
3. ADR-PRESENT: declare docs/adr/0028-live-host-proof-ed25519-signing.md on one uninterrupted line using the existing declaration grammar. Round 2 must derive and hash-bind it through the precheck and both reviewer manifests; do not retrofit round 1.
4. NO-REQ-CONTRADICTION: add the requirement forbidding new CI topology to Constraint Compliance with its requirement location and existing Global Constraints reference. Preserve all existing mandatory checks.
5. INTEGRATION-IDENTIFIED: define supported CLI command/output contracts, record actual versions, and separate command/authentication/unavailable failures from successful absent-registration results. Do not infer absence from a failed command. Keep unresolved live contracts explicitly blocking the affected acceptance proof.
6. VERIFICATION-PATH-CONCRETE: explicitly check registered operator/reviewer roles in addition to signatures and identity; define rejection and negative cases for valid signatures made with issuer-role keys or reversed operator/reviewer roles.

## Next Steps

Preserve both original reviewer JSON files, consumed reservations and this BLOCKED result. The existing Passed header is historical provenance, not approval of these admitted bytes.

Apply the scoped design correction as one reviewed batch, then run a fresh round-2 precheck with the edit summary and independently reserved reviewers. Neither current source behavior, native host activation, CI nor merge is established by this design review.

Evidence check before integration: all 23 reviewer-manifest input hashes matched; the two host session identities were distinct. Reviewer B's saved JSON matched its completed app-server response. No task status, approval or source implementation was changed.
