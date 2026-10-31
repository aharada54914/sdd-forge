# Design: A1 RT002 bounded repair

Impl-Review-Status: Passed
Feature Type: bugfix

Authorized amendment (2026-09-28, limited extra1): exact two-envelope contract adopted for formal re-review. Existing review/status/approval lines remain historical, not a PASS of these changed bytes. No implementation, execution proof, task-attempt reset or correction-budget reset. Governing dated precedence: [amendment addendum](verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md).

## Technical Summary

Reuse the current verifier and its original Bash/PowerShell suites. Revalidate only the RT002 three-file delta. Do not introduce a second verifier, alternative execution path or new approval framework. The recovery contract's patch/body bytes remain normative; the candidate requirements and dated addendum propose only `B(N)` or `P+B(N)` as the complete raw strings.

## Architecture

Challenge emitter → caller's one native tool dispatch → trusted collector's unmodified record → shared JSON loader → schema-selected response verifier → existing result formatter. Cleanup uses the same loader but its own unchanged predicate. Actual guard denial is never rerouted. This is the existing flow (`plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:218-285,413-514`).

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| check-hook-activation-handshake.py | Challenge, typed exact-response verification and cleanup result | Python stdlib json/re/secrets | Existing |
| Original .sh/.ps1 wrappers and suites | Cross-shell invocation and explicit success/refusal assertions | Bash / PowerShell | Existing; only suites in repair source scope |
| Installed host / trusted collector | Actual enforcement and unchanged response capture | Existing native tools | Existing, not simulated live proof |

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | No visual journey change; existing CLI statuses retained | [UX](ux-spec.md#scope-and-user-journeys) | Maintainer | N/A — no change |
| Frontend | No UI/client component | [Frontend](frontend-spec.md#technology-stack) | Maintainer | N/A — no change |
| Infrastructure | Original paths, native Windows and permitted installed application | [Infrastructure](infra-spec.md#deployment-topology) | Maintainer | Planned |
| Security | Exact operation/nonce binding, fail closed and evidence limitations | [Security](security-spec.md#trust-boundaries) | Independent reviewer | Planned |

## Design System Compliance

N/A — ds_profile: none

No design-system directory was present at preparation; re-check before review. No visual artifacts or upload needed.

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC | Verification |
|---|---|---|---|---|---|
| requirements.md | security-spec.md | Exact acceptance and refusal categories | REQ-001, REQ-002, REQ-003 | AC-001–AC-004 | TEST-001–TEST-080, TEST-090–TEST-097 |
| security-spec.md | infra-spec.md | Native capture is separate from fixture result | REQ-005 | AC-006 | TEST-089 |
| requirements.md | infra-spec.md | Original-path parity and latest-head CI | REQ-004, REQ-005 | AC-005, AC-006 | TEST-081–TEST-088 |

## ADR Change Log

No new architecture decision. Carry forward the explicitly approved `reports/verification/hook-recovery-entry-contract-20260909.md` as historical authority, with only wrapper presence proposed for supersession in the dated candidate addendum; no new adapter registry, persistence or guard architecture. Existing ADR inputs required by the review contract are still included by the ordinary precheck, not silently omitted.

## Data Plan

Data Entities: challenge object, response record, verification result and cleanup result. No new database or replay state.

Existing Data Affected: no historical record is rewritten. A versioned response is distinct from no-schema legacy evidence.

Migration Strategy: additive response selector; legacy records retain runtime predicates except intentional duplicate-member rejection in the shared loader. Installed artifacts are verified by hash after permitted application. No auto-migration of old captures into the new schema.

## API / Contract Plan

Preserve the current CLI surface and result schemas. `schema` present selects only the versioned adapter; unknown/null/wrong-type schemas reject before runtime predicates. Its exact five-key set, both Codex runtime values, nonce syntax/equality, boolean false and one of the two complete raw envelopes `B(N)` or `P+B(N)` are all required. `_unique_json_members` handles duplicates before either mode; cleanup must not select the response adapter. Existing implementation sites: verifier `262-285,381-450,453-514`.

AC-002 maps selector, structure, type and runtime failures to exit 64, nonce failures to 62, executed true to 63, malformed/duplicate response JSON to 61, and missing legacy plugin flags to 65; every refusal emits `CAPABILITY_RUNTIME_UNAVAILABLE`. AC-003 binds both nonce locations to the challenge and compares the complete decoded UTF-8 template without trimming, normalization or newline conversion; prefix/suffix, quoting, target/tool operation, guard-message and line-ending mutations reject. One exact `P` before bare `B(N)` is the sole prefix exception; malformed/repeated wrappers reject.

The minimal proposed shared-predicate change is to remove only the literal `Script error:\n` from `HOST_DENIAL_PREFIX` and prepend `r"(?:Script error:\n)?"` to the fully escaped body/patch pattern. Replace only the existing `<nonce>` slot with `([0-9a-f]{32})`; use `re.fullmatch` over the whole raw string, then retain `match.group(1)` equality against expected nonce. The wrapper group is noncapturing. Preserve loader → selector → exact key/runtime → nonce → executed → raw type/fullmatch → echoed nonce comparison and all existing refusal codes. The current mandatory prefix/fullmatch and shared call path are at `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:158-165,381-423,433-445,575-593`; this is a proposal, not a claim the code changed.

## Test Strategy

Map AC-001–AC-006 to TEST-001–TEST-097 in acceptance-tests.md. Reuse full original suites; add direct assertions for schema-agnostic cleanup and complete unchanged Claude/Copilot templates. These are observed coverage gaps, not proven runtime defects. Any discovered production mismatch requires a committed focused failing regression before repair. Report old code as acceptance-first, historical RED unknown. Before new high-risk implementation, record each persisted field, its counterpart and failing mismatch test in the implementation report (WFI-001); security-spec.md defines the pairs.

Unit-level branch coverage is exercised through the existing CLI, rather than a second private-function test framework: TEST-061–TEST-073 isolate malformed JSON, UTF-8 and shared-loader rejection; TEST-002–TEST-043 isolate selector, field/type, runtime and nonce predicates; TEST-074–TEST-080 isolate cleanup outcomes and schema independence. Each fixture changes the named input and asserts the corresponding exit/result, so the same observable unit contract is checked by both original shell suites. This replaces separate direct-function unit tests without changing the integration-labelled acceptance rows. The existing suites invoke the real wrapper/verifier (`tests/check-hook-activation-handshake.tests.sh:77-83,260-285,336-389,653-824`); TEST-084/TEST-085 additionally require complete unchanged legacy templates rather than partial marker matches.

Add separate both-shell TEST-090 bare and TEST-091 wrapped positive assertions and TEST-092–TEST-097 exact malformed-wrapper assertions. The acceptance matrix expands existing response negatives over both envelopes; legacy/no-schema and cleanup contracts remain independent. Unknown host/tool/nonce, wrong/missing types, duplicate members and added leading/trailing bytes must remain refusals. No regex/runpy execution result exists for this candidate: the previous check was refused by PreToolUse; no alternate executor/path retry is permitted.

At this fixture/branch layer, the native tool/collector is substituted only by fixed caller JSON response and cleanup records; neither the shared loader nor verifier is mocked. Combined full-suite runs establish cross-shell integration and non-mutation, not live host activation. TEST-089 uses a fresh actual installed-host dispatch and unmodified capture, with no substitute CLI/collector, and remains a separate required proof.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| Record → verdict | Exact validation; collector trust explicitly limited | Local diagnostics | Forged/stale/malformed acceptance |
| Candidate → installed host | Existing protection and human application, actual fresh dispatch | Local candidate hash/response | Bypass or stale installed artifact |

Detailed controls: [Security specification](security-spec.md#trust-boundaries).

## Deployment / CI Plan

Repair-only independent reviews under recovery item 4; no ordinary activation bypass. New task approval, permitted protected application, fresh installed activation, original-path regressions, independent quality gate and latest-head required CI precede safe integration. Native Windows is not inferred from macOS PowerShell. Keep parent and eventual child tickets open until their stated exit evidence is met. See [Infrastructure](infra-spec.md#deployment-topology).

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| REQ-001/002 exact meaning | Existing full-match adapter; no normalization or invented plugin flags |
| REQ-003/004 compatibility | Shared duplicate rejection only; separate cleanup; exact template assertions |
| REQ-005 provenance | New feature inputs; no old state/verdict rewrite; live proof separate |

## Assumptions

Review the actual three-file delta against current main and current hashes before implementation/review; refresh shared guard membership and installed path/hash immediately before live dispatch. Accept only the two candidate requirements envelopes after authorized application and formal re-review; any other changed host envelope remains unavailable pending investigation. Recovery-contract authority does not waive any other review prerequisite.

## Open Questions

None requiring a new design decision. Native Windows, installed activation and formal review are pending evidence, not assumed outcomes.

## Risks

Fail-open verdicts are high risk. Strict formatting may refuse a new host version; that is preferable to false activation. Plain-file exact matching does not authenticate a forged collector, prove plugin origin or implement replay persistence. Full A1/A8 completion is outside this bounded repair.
