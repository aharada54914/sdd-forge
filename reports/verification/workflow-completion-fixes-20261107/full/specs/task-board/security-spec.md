# Security Specification: task-board

## Trust Boundaries
| Boundary | Source → Destination | Asset | Validation | Auth | REQ | AC |
|---|---|---|---|---|---|---|
| B1 | browser → HTTP server | tasks/API | loopback, Host/Origin, JSON schema/body limit | local user; login不要 | REQ-007 | AC-010/013 |
| B2 | server → filesystem | JSON | fixed path, schema/version, atomic replace | process filesystem access | REQ-004 | AC-012 |

## STRIDE Analysis
| Boundary | Threat | STRIDE | Abuse | Mitigation | Verification |
|---|---|---|---|---|---|
| B1 | script injection | Tampering | titleにHTML | textContent、schema/type/length | TEST-009 |
| B1 | cross-site writes | Spoofing | external Origin POST | loopback bind、Host allowlist、Origin一致、JSON要求 | TEST-009 |
| B1 | oversized request | Denial of Service | huge body | 64KiB制限 | TEST-009 |
| B2 | partial writes | Tampering | 保存途中例外 | atomic replace、lock、失敗で旧state保持 | TEST-011 |
| B2 | arbitrary read | Information Disclosure | traversal静的path | static allowlist、data非公開 | TEST-009 |

## Authentication Flow
N/A — 指定通りlocal単一ユーザーで認証なし。token、TTL、refresh、MFA、IdPは作らない。外部公開しない。

## Authorization
local browserのみtask全体操作可。Hostは127.0.0.1/localhostと起動portへ限定、Originがある更新要求は同一Originのみ。unknown idは404。multi-tenantは対象外。OSの他local processからの操作はこの認証なしモデルの限界。

## Data Classification and Protection
合成ローカルタスク、個人情報投入不要。JSON plaintext、localhost HTTP、暗号化/鍵管理なし。taskは削除まで保持、削除は次のatomic saveで反映。task titleをlogしない。

## OWASP Mapping
Access control: origin/host and static allowlist → TEST-009。Injection: textContentと厳密JSON検証 → TEST-009。Cryptographic failures: public transportなし、local平文は明示仕様。Storage integrity: TEST-011。

## Secrets Management
秘密情報、認証情報、external API key不要。source/manifest/logへ秘密を入れない。

## SBOM and Supply Chain
Python標準libraryとbrowser built-insのみ、runtime lockfile不要。Python versionを検証reportへ記録。test用Playwrightのversionも記録しruntimeと分離。外部CDNなし。更新責任はlocal運用者。

## Security Tests
TEST-009: 不正JSON/型/length/Origin/Host/path/unknown idを拒否。titleを実行せず文字表示。TEST-011: broken JSON/書込失敗でも元data保持。AC-010/012。secret scanはquality deterministic gateで実行。認証/encryption/rate-limit serviceは対象外、body上限を検証する。

TEST-012 / AC-013: 実processのlisten addressが127.0.0.1のみであることと、実非loopback addressへの直接TCP接続が成立しないことを確認し証拠を保存する。loopback GET成功を併せて確認し、server未起動による偽陰性を避ける。

## Open Questions
なし。
