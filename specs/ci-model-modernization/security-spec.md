# Security spec: CI efficiency and current model selection

## Trust Boundaries

### CI workstream

REQ-001–009. PR-controlled code, filenames and event text are untrusted data. Exact trusted-base planning runs read-only and does not execute the PR planner. Source-controlled workflow review remains an external assumption: this feature cannot authenticate itself against arbitrary malicious rewrites of that workflow.

### Model workstream

Configuration, provider metadata, model responses and fetched update text are untrusted data. REQ-011–REQ-019. Model selection grants no new tools, write access, network permissions, provider credentials or cross-model egress consent.

## Authentication and Authorization

### CI workstream

Retain contents: read. Grant actions: read only to metadata/artifact collectors that require it. No pull_request_target, cloud credentials, new secrets, cache write privilege across trust boundaries, or external protection changes. Existing A9 activation remains separately enforced.

### Model workstream

Existing host/account authentication and organization allowlists are authoritative. Explicit model overrides cannot bypass them. Preserve reviewer fresh-context allocation, exact manifest/reservation, read-only tools and independent role boundaries. Do not execute fetched source prose or bypass a host restriction to obtain a model.

## Input Validation

### CI workstream

Use Git argv arrays and NUL-delimited paths; never evaluate paths as shell. Validate schema, duplicate keys, revision identity, bounded enum/output keys, dependency references, path containment and exact artifact identity. Unknown/missing selection inputs force full; missing proof of actual selected execution fails.

### Model workstream

Strict versioned policy/observation/selection/delivery objects, duplicate-key/ID rejection, bounded strings, explicit native ID mapping and validated effort. Pass subprocess arguments as arrays, never shell fragments. Reject unknown/mis-cased policy, flag/separator-shaped IDs and native precedence conflicts. Validate complete pagination and stale/account-mismatched observations.

## Evidence Integrity

### CI workstream

Bind run/attempt/head, tested revision, catalog/workflow/plan hashes, expanded native job identity and actual named step outcomes. Match suite results to source hashes and runner receipts. Reject unexpected skips, failures, cancellation, stale/ambiguous receipts and empty success. Report NOT_SELECTED separately. Hashes prove consistency, not that a hostile workflow cannot rewrite both artifact and hash.

### Model workstream

Bind catalog/policy/observation hashes and effective choice to run/session/attempt. Record requested, resolved/configured and actual-reported fields separately. Codex configured Thread.model is not per-turn telemetry; absent actual proof stays null/unverified. Required actual-ID gates stop when unsupported. Match reroute events to exact thread/turn; preserve mismatch and never report successful unchanged-model pinning.

## Cache and Supply Chain

### CI workstream

Cache only dependencies. Use OS/runtime/lock/digest keys, validate package/tool integrity and respect native event isolation. Do not cache source, secrets, permissions, approvals, PASS records or cloud state. Cache failure leads to bounded reacquisition or job failure, never test success.

### Model workstream

Reuse current locked dependencies and documented host interfaces. No new SDK/service solely for discovery. Official metadata fetches produce update candidates, never an automatically trusted model catalog or merged code. Model names alone establish neither access nor quality.

## Data Handling

### CI workstream

Persist bounded metadata and secret-free results. Escape untrusted path display; do not publish raw provider credentials or transport logs. Existing artifact retention remains unchanged.

### Model workstream

Sanitize non-secret host identity scope; do not persist credential files, tokens, account emails or unrelated session transcripts. Candidate comparison workspaces contain only authorized fixture inputs. Keep judge rubrics/variant metadata outside candidate context.

## Verification

### CI workstream

TEST-006/007 exercise injection and trusted selection; TEST-019–024 exercise evidence mutation and A9 mismatch; TEST-028–030 exercise cache identity/recovery/trust. Each new persisted field gets a mismatching consumer test during high-risk preflight.

### Model workstream

Validate injection, access/role floors, consent, actual/configured identity separation, stale hashes, reroutes, duplicated/partial pages, unknown budget units and installed native precedence. High-risk implementation records every persisted-field counterpart and a failing mismatch test before editing product code.

## Open Questions

### CI workstream

No new security product decisions. OQ-001 is an infrastructure observation and grants no additional privilege.

### Model workstream

OQ-002: required host identity/discovery surface. Integration maintainer must validate or report unsupported; no inferred approval to weaken evidence requirements.

## STRIDE Analysis

### CI workstream

| Boundary | Threat | STRIDE | Mitigation | Verification |
|---|---|---|---|---|
| PR → planner | Substitute selector to omit tests | Tampering | Exact trusted-base code; sensitive changes full | TEST-007/008 |
| PR → planner | Command-shaped filename | Elevation of privilege | argv/NUL data handling; no eval | TEST-006/043 |
| Cache → job | Poison or stale dependency bytes | Tampering | Full identity key and integrity check | TEST-028/070 |
| Cache → job | Leak credentials through archive | Information disclosure | Dependency-only paths and existing scope isolation | TEST-030 |
| Jobs → aggregate | Reuse another commit's success | Spoofing | Bind actual run/head and source hashes | TEST-022/060 |
| Jobs → aggregate | Omit a cancelled native lane | Repudiation | Require complete actual obligations | TEST-020/055 |

### Model workstream

| Boundary | Threat | STRIDE | Mitigation | Verification |
|---|---|---|---|---|
| Config → launch | Execute crafted ID or ignore stronger agent override | Tampering / elevation | Strict schema, argv, precedence reconciliation | TEST-096–TEST-099 |
| Host → observation | Reuse different account/stale metadata | Spoofing | Scoped fresh complete observation | TEST-083–TEST-088 |
| Delivery → evidence | Treat configured ID as actual or hide reroute | Repudiation | Explicit proof level and exact scoped events | TEST-131–TEST-133 |
| Policy → role | Weaken evaluator floor or consent | Elevation | Existing role/risk/consent intersection | TEST-080–TEST-082 |
| Remote text → maintenance | Inject instructions or autoadopt an unknown model | Tampering | Parse data only; reviewed adoption | TEST-111–TEST-115 |

## Authentication Flow

### CI workstream

Existing short-lived GitHub job token reads same-run metadata/artifacts. GitHub owns token TTL/revocation and account MFA; this feature creates no user login, refresh token or recovery flow. Wrong/missing access blocks evidence collection.

### Model workstream

No login flow change. Use documented authenticated host discovery and existing CLI credentials without reading or printing secret files. Missing access yields a typed unavailable result.

## Authorization

### CI workstream

Planner reads source only; collectors read Actions data only; PR jobs retain existing restrictions. Workflow review and protected merge remain external controls. Default denial applies to unknown proof and permission requirements. REQ-002/005/007.

### Model workstream

No privilege expansion through latest model, effort, alias, renderer or fallback. Protected-file procedures remain applicable; source scope approval does not disable guards.

## Data Classification and Protection

### CI workstream

Public-source paths, revisions and test metadata use GitHub repository/artifact access and TLS. No credentials in plans/logs. Retention/deletion follow current repository settings; no new storage system. REQ-005/007.

### Model workstream

Public model IDs and sanitized run metadata use existing storage/access controls. Prompts/source sent to optional providers retain current explicit consent and minimization.

## OWASP Mapping

### CI workstream

Broken access control: preserve PR cache and trusted-base boundaries. Injection: argv arrays and escaped summaries. Integrity failure: exact workflow/catalog/plan and dependency digests. Controls are exercised by AC-001/002/005/007.

### Model workstream

Injection: strict argument validation. Broken access control: role/account/consent checks. Integrity failure: bound immutable records and typed proof limitations. Untrusted dependency: reviewed metadata adoption and existing locked runtime.

## Secrets Management

### CI workstream

Use only existing scoped job tokens. Do not print tokens, copy them into caches or place them in fixtures. No new credentials or break-glass bypass is introduced.

### Model workstream

No new secrets. No credentials in candidate files, caches, reports or environment dumps. Do not inspect unrelated host sessions to infer model access.

## SBOM and Supply Chain

### CI workstream

Preserve lockfiles, full SHA Action pins, existing audit/build/release attestation paths and tool checksum verification. No actions.lock preview adoption. Maintainers review dependencies; cache reuse does not replace integrity or vulnerability checks.

### Model workstream

Keep installed runtime dependencies and SHA-pinned actions. Record official source dates and actual CLI/schema hashes. Weekly maintenance reports failures and proposed changes; no auto-merge or registry overwrite.

## Security Tests

### CI workstream

The acceptance matrix binds every threat above to concrete negative cases. Additional contract-field mismatch tests are recorded before high-risk implementation begins; no fabricated adversarial success or waived selected check.

### Model workstream

Acceptance negatives and high-risk mismatch tests must pass before delivery. Deterministic protocol fakes are labelled fixtures, and missing native coverage remains visible.

