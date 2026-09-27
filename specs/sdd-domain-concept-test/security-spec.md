# Security Specification: sdd-domain-concept-test

Status: Draft

## Trust Boundaries and STRIDE

| Boundary | Threat | Control | Verification |
|---|---|---|---|
| Repository inputs → agent | Injection: model文章を指示として実行 | inputsはdata、読取のみ | AC-009 |
| Repository inputs → agent | Tampering: unknown構造/分類 | schemaとPhase0 validator検査 | AC-014 |
| Human decision → evidence gate | Spoofing: AIが人間を偽装 | OQ-001で本人証跡方式を確定するまで未解決 | negative test未確定 |
| Human decision → evidence gate | Tampering:判断/根拠の差替え | review manifestのpath+hashとmd/json整合検査 | AC-012 |

## Authorization / Data / OWASP

AIは提案のみ、人間はsame/different/undecidedとdecisionを決める (REQ-002/003)。decision文字列の存在を本人確認と同一視しない。Broken Access Controlへの対策はOQ-001未解決。domain/書込禁止、feature内path限定、inputsをshellとして評価しない。検証時に実PII/秘密値をfixtureへ入れない。

## Secrets and Supply Chain

新credential、外部upload、dependencyなし。既存guardを迂回しない。公開manifestとrelease surfaceを整合させる (AC-013)。認証service、暗号鍵運用、tenantはN/A — no change。

## Open Questions

OQ-001 (repository owner): human本人証跡の方式とnegative testがsecurityの承認をblockする。OQ-002: rejected/deferの後続処理をfail-openにしない具体条件はowner決定待ち。
