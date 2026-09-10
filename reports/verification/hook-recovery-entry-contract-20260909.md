# RT-20260909-002: authorized recovery-entry contract

Date: 2026-09-09
State: proposed implementation contract, human scope authorized; not reviewed PASS.
Owner: epic-189-a1-project-context T-008 repair.

## Authority and supersession

The user explicitly authorized changing the Codex activation criterion to
actual SDD guard denial of this operation, and a recovery-only review route.
This supersedes the plugin-origin prerequisite in A1 requirements.md REQ-010
(lines 993–999) and design.md's Codex signature discussion only for the new
versioned adapter. Historical bytes, reviews, task Done and runtime evidence
remain unchanged; this addendum is not retroactive proof of their currentness.
Legacy plugin-flag evidence remains accepted under its existing predicates.
Claude and Copilot predicates remain unchanged. A8 live cross-runtime proof
is not established by this amendment or fixture verification.

## Recovery entry (temporary and narrowly scoped)

1. This entry admits independent review of RT-20260909-002's contract,
   candidate implementation, rejection regressions and human-application
   helper, plus the repair-specific provenance reviews in item 4 ONLY.
   It does not admit unrelated spec work, task implementation,
   quality-gate completion, integration, or an ordinary bootstrap invocation.
2. The unavailable handshake and raw prior denial are disclosed as historical
   observations, not represented as a passing precheck. All filesystem/tool
   enforcement remains live. A denied operation is not rerouted through an
   alternative executor, renamed executable or installed cache modification.
3. Review inputs must include the ticket, this amendment, the earlier repair
   report, original source and both wrappers/tests, exact candidate diff and
   a path/SHA-256 input manifest. Record reviewer identity and actual review
   outcome separately from every formal SDD gate. An independent reviewer
   must not author the candidate; ordinary advisory scrutiny never sets Done.
4. Before activation, propagate the authorized meaning through a scoped new
   specification/design/task provenance review as required by the project.
   This entry authorizes conducting those repair-specific reviews despite
   the unavailable handshake; all their other prechecks, identity reservations,
   input hashes, schema validation, independence and cycle limits remain
   mandatory. No manually asserted PASS or use of issue #61 fallback is
   authorized. If another required precheck fails, record it and stop that gate.
5. Production application remains through the human when protected. Original
   path suites, both wrappers and all existing cleanup/stale-start checks are
   mandatory. The diagnostic-only patch does not meet this exit condition.
6. Exit only after a NEW emitted challenge, ONE actual native host dispatch,
   unmodified raw response and original installed-path verifier produce
   HOOK_ACTIVE under the reviewed adapter. Record source hashes and results.
   Fixture GREEN alone is insufficient. If installation/version differs from
   the tested original, human application and verification must cover that
   actual path before it is used. No automatic cache editing.
7. On successful exit, retire this repair-specific admission in a dated
   addendum and resume ordinary entry. It is not a reusable bypass flag.

## New Codex evidence adapter

Schema selector: `schema: "sdd-codex-host-denial/v1"`. Required and ONLY keys:
`schema`, `runtime`, `nonce`, `executed`, `raw_result`. Runtime must be exactly
`codex-cli`; executed must be the boolean false; nonce must be exactly 32
lowercase hex digits and match both the expected challenge nonce and the
nonce inside the echoed patch. Raw result must be a string.

The exact Add File operation uses `sdd/.hook-canary-sentinel` and one content
line `sdd-hook-challenge:<nonce>`. Verify the ENTIRE documented host denial
envelope and echoed patch, not a substring. Permit no optional terminal
newline initially: exact string equality is the contract. An actual new host
response that differs is unavailable and must be investigated, not normalized
into acceptance. The historical empty-line canary cannot pass this adapter.

Normative byte templates: decode each JSON string below as UTF-8 text and
replace the single literal `<nonce>` with the challenge nonce. No other
substitution, whitespace trimming, Unicode normalization or line-ending
conversion is allowed. Both decoded strings have NO terminal newline.
The emitted `tool_call_template.codex-cli.tool_input.patch` must be the first
string with the SAME generated nonce as the challenge's top-level nonce.
Claude/Copilot emitted templates remain unchanged. A fresh live result is
still mandatory; this template is derived from the historical host response,
not itself an observation of the new operation.

Emitted patch:

```json
"*** Begin Patch\n*** Add File: sdd/.hook-canary-sentinel\n+sdd-hook-challenge:<nonce>\n*** End Patch"
```

Accepted `raw_result`:

```json
"Script error:\nCommand blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。\n[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.. Command: *** Begin Patch\n*** Add File: sdd/.hook-canary-sentinel\n+sdd-hook-challenge:<nonce>\n*** End Patch"
```

Select schema before runtime-adapter evaluation. An explicit unknown/null/
wrong-type schema rejects without legacy fallback. Any duplicate JSON member
rejects (including nested objects). No-schema legacy records use their
existing runtime predicates, with accurate missing-flag diagnostics. New
schema records containing either plugin flag, even true, reject as extra keys;
thus explicit false cannot be ignored. Other-runtime records cannot use this
schema. No inferred or synthesized host fields.

Adapter selection applies ONLY to `--verify-response`. Its CLI runtime and
recorded runtime must both be exactly `codex-cli` for the new schema. New
adapter structural/signature errors use existing UNRECOGNIZED_RESULT (64),
nonce mismatches use STALE_CHALLENGE_REJECTED (62), and boolean executed true
uses WRITE_EXECUTED (63); all must emit CAPABILITY_RUNTIME_UNAVAILABLE.
Malformed or duplicate-member response JSON uses RECORDED_RESULT_UNREADABLE
(61). Schema selection must not fall through to another runtime even if
that runtime's legacy success fields are present.

Cleanup keeps its valid legacy fields, nonce syntax and all outcomes; the
new response adapter is never used to confirm cleanup. Duplicate-member
rejection intentionally tightens the shared loader for BOTH modes. Cleanup
duplicates use CLEANUP_RESULT_UNREADABLE (71) and must never emit
SENTINEL_CLEANUP_CONFIRMED. Otherwise this repair does not add a cleanup
schema selector or alter cleanup acceptance predicates.

## Trust boundary and required regression branches

The trusted collector is the current agent session recording its own tool
response. Exact matching binds recorded content; it is NOT a cryptographic
host attestation. A fully forged caller-authored transcript is not detectable
by a plain-file verifier. A matching recorded nonce alone also does not prove
single use; the session must consume one new challenge once and never reuse
old transcripts. Do not claim a persistent replay ledger or plugin provenance.

Before implementation, original-path RED cases must individually cover:
valid new adapter; legacy three-runtime success; missing/null/string/true
executed; outer and inner nonce mismatches; malformed nonce; unknown schema;
wrong runtime; each missing key; each extra/contradictory plugin flag; duplicate
members; non-string raw result; altered guard message; prefixed/quoted/suffixed/
truncated responses; another target; extra operation; old empty-line patch;
terminal newline differences. Each negative asserts nonzero and no HOOK_ACTIVE.
Retain all existing cleanup, stale-start and non-mutation checks. Run both
original wrappers, not a copied executable. These fixtures are not live proof.

Explicit matrix expansion: schema null, boolean, numeric, array and object;
executed numeric 0 and 1; arbitrary extra keys; CLI-versus-recorded runtime
mismatches for each non-Codex runtime; duplicate schema/runtime/nonce/executed/
raw_result individually and nested duplicates. Duplicate executed true/false
must be tested in BOTH orders for response and cleanup. Legacy three-runtime
positive cases remain GREEN during the new-adapter RED stage. Verify emitted
patch exact bytes and equality of its embedded nonce with the challenge nonce,
and reject CRLF substitution and leading/trailing newlines separately.

The repair's persisted-field preflight pairs schema/runtime with adapter
selection, nonce with generated and echoed nonce, executed with nonexecution,
raw_result with the exact operation/envelope, and result status with the
authorized guard-denial meaning. Each pair requires its mismatch test above.
