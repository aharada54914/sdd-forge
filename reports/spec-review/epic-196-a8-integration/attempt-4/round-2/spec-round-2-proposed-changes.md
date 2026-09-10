# A8 attempt 4 round 2 — proposed changes

Status: Proposed; NOT applied to canonical specifications; NOT a PASS.

## Scope and review provenance

Address reviewer A CONSTRAINTS-EXPLICIT (Critical), reviewer B APPROVAL-BOUNDARY (Critical), and reviewer B EDGE-CASE-COVERAGE (Major) from reports/spec-review/epic-196-a8-integration/attempt-4/round-2/. Scope: append an investigation citation correction and expand acceptance criteria into concrete planned cases. No implementation, signing key, live proof, status, CI requirement or historical review is changed.

Human editing is required by the installed sdd-bootstrap-interviewer skill, Specification Review Gate step 4: “verdict == NEEDS_WORK → present proposed changes; await human edit of requirements.md or acceptance-tests.md; re-invoke.” Existing general implementation authority is not recorded as an actual human edit. Current proposal requires human application followed by new hashes and review.

Base investigation SHA-256: dffb5e44ce29f734f5d07d6286eda469a92a8eb3a14f35f12aa0c41e36df83be.
Base acceptance SHA-256: 4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1.

## 1. Append to investigation.md; do not rewrite old declarations

### Full commit identities for earlier amendment entries

The earlier “This commit” entry (lines 630–645 before this addition) refers to commit `d9f1c42f69c4604ff7d7bbe050f8b9969e18147e`. Its changed-file set contains only `specs/epic-196-a8-integration/investigation.md`. The historical blob SHA-256 is `117aa4ee7a385fbc606e2b788dd6bdd169c0be32036e17be535d5301b65bc939`. This explicit identity supersedes the old statement that its identity must be inferred from “this commit” and its file shape; it does not replace the current investigation hash.

The subsequent joint design/investigation amendment entry (lines 691–703 before this addition) refers to commit `a01dbf5a661a2cafc6f53130e06ec3b7df07fd6a`. Its changed-file set is exactly `specs/epic-196-a8-integration/design.md` and `specs/epic-196-a8-integration/investigation.md`. Historical SHA-256: design `c69ec42ed738a1bb091453920b890459f236a60e5673527338d183e94bab78d4`; investigation `2a5912f80e7687a9e4e82d158c359cad1f8aecd6ee0f772b6a08f9985f0e2953`. This binds the existing 2026-08-29 approval to its actual commit rather than a date/file-shape inference. No additional approval or retroactive PASS is asserted.

Source verification: git show --format=fuller --stat for both full commit IDs (36e7e1); historical blob hashes computed from git show bytes (58559b). Re-verify those blobs before applying.

## 2. Acceptance index clarification

Retain TEST-001 through TEST-030 as parent AC index entries. Replace the paragraph claiming that every Planned row proves no test code exists with:

> The thirty parent TEST-001–TEST-030 entries remain the Phase-1 AC index. The subcase IDs below are concrete acceptance assertions, not additional ACs or additional classification-table entries. Planned denotes that this revised assertion has not been accepted under the current specification review; it does not assert that no historical implementation exists. Later implementation must map each subcase to executable evidence without deferring branch definition. Previously produced evidence is not automatically accepted for these revised assertions.

Retain the canonical test-path paragraph and classification-table scope, but remove its superseded assertion that concrete cases are defined only in Phase 2/3. The new rows inherit their parent check's classification; validator fixtures are synthetic tests of rejection logic, never evidence that a real host session occurred.

## 3. Concrete acceptance subcases to append

Source: requirements.md AC-026–AC-028, lines 542–593 (30526d), existing acceptance-tests.md lines 30–51 (eb5c93). Start each negative case from an independently accepted valid baseline and change only the named property. Recompute other legitimate bindings as needed to isolate the intended failure; no negative test may pass merely because setup failed. Cases below are Planned, not executed. The all-five valid case requires real evidence for actual discharge; fabricated test keys/captures remain confined to disposable validator fixtures and never enter canonical proof records.

| Test ID | AC | Requirement | Input / independent case | Concrete assertion | Status |
|---|---|---|---|---|---|
| TEST-026-MISSING-01 | AC-026 | REQ-006 | Remove only `session_date` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-02 | AC-026 | REQ-006 | Remove only `session_start` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-03 | AC-026 | REQ-006 | Remove only `session_end` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-04 | AC-026 | REQ-006 | Remove only `operator` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-05 | AC-026 | REQ-006 | Remove only `operator_key_id` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-06 | AC-026 | REQ-006 | Remove only `reviewer` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-07 | AC-026 | REQ-006 | Remove only `reviewer_key_id` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-08 | AC-026 | REQ-006 | Remove only `nonce` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-09 | AC-026 | REQ-006 | Remove only `raw_tool_request_ref` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-10 | AC-026 | REQ-006 | Remove only `raw_tool_request_sha256` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-11 | AC-026 | REQ-006 | Remove only `raw_tool_result_ref` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-12 | AC-026 | REQ-006 | Remove only `raw_tool_result_sha256` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-13 | AC-026 | REQ-006 | Remove only `host_session_id` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-14 | AC-026 | REQ-006 | Remove only `host_event_id` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-15 | AC-026 | REQ-006 | Remove only `installed_hook_config_ref` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-16 | AC-026 | REQ-006 | Remove only `installed_hook_config_digest` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-17 | AC-026 | REQ-006 | Remove only `cli_name` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-18 | AC-026 | REQ-006 | Remove only `cli_version` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-19 | AC-026 | REQ-006 | Remove only `host_os` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-20 | AC-026 | REQ-006 | Remove only `plugin_hooks_flag` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-21 | AC-026 | REQ-006 | Remove only `tool_call_evidence` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-22 | AC-026 | REQ-006 | Remove only `verdict` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-23 | AC-026 | REQ-006 | Remove only `operator_signature` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-MISSING-24 | AC-026 | REQ-006 | Remove only `reviewer_signature` from an otherwise valid non-SKIP record (use a Codex cell for its flag). | Reject the missing required field; non-zero, not discharged. | Planned |
| TEST-026-NONCE-UNKNOWN | AC-026 | REQ-006 | Use a well-formed nonce absent from the issuance ledger; leave the other validation bindings valid. | Reject the record; aggregate exits non-zero and never reports discharged. | Planned |
| TEST-026-NONCE-REUSED | AC-026 | REQ-006 | Use a nonce already consumed by a different record. | Reject nonce reuse, not the idempotent validation of the identical accepted record. | Planned |
| TEST-026-REQUEST-HASH | AC-026 | REQ-006 | Change only referenced raw request bytes without updating their recorded digest. | Reject the request-capture hash mismatch; non-zero, not discharged. | Planned |
| TEST-026-RESULT-HASH | AC-026 | REQ-006 | Change only referenced raw result bytes without updating their recorded digest. | Reject the result-capture hash mismatch; non-zero, not discharged. | Planned |
| TEST-026-CONFIG-EXPECTED | AC-026 | REQ-006 | Keep the captured installed config and its recorded digest consistent, but different from the maintainer expected-digest manifest. | Reject expected-config mismatch; non-zero, not discharged. | Planned |
| TEST-026-OPERATOR-SIGNATURE | AC-026 | REQ-006 | Corrupt only the operator signature, preserving the reviewer signature and trusted key registration. | Reject signature verification; non-zero, not discharged. | Planned |
| TEST-026-REVIEWER-SIGNATURE | AC-026 | REQ-006 | Corrupt only the reviewer signature, preserving the operator signature and trusted key registration. | Reject signature verification; non-zero, not discharged. | Planned |
| TEST-026-OPERATOR-UNTRUSTED | AC-026 | REQ-006 | Sign with an operator key not registered as trusted. | Reject untrusted operator key; non-zero, not discharged. | Planned |
| TEST-026-REVIEWER-UNTRUSTED | AC-026 | REQ-006 | Sign with a reviewer key not registered as trusted. | Reject untrusted reviewer key; non-zero, not discharged. | Planned |
| TEST-027-AUTOMATED-AS-MANUAL | AC-027 | REQ-006 | Present a manual-format record to a check classified automated. | Reject the classification mismatch, not discharged. | Planned |
| TEST-027-SYNTHETIC-AS-LIVE | AC-027 | REQ-006 | Present the known direct-invocation synthetic artifact as a manual-required live observation. | Reject the known structural substitution; an independent human reviewer also must not countersign it. No claim of universal mechanical spoof detection. | Planned |
| TEST-028-POSTMERGE-SKIP | AC-028 | REQ-003 | For each of the five named cells independently, replace only that cell with a schema-valid signed SKIP after A1 activation. | Non-zero and not discharged for each cell. | Planned |
| TEST-028-FAIL | AC-028 | REQ-003 | For each named cell independently, replace only that cell with a validly signed FAIL record. | Non-zero and not discharged for each cell. | Planned |
| TEST-028-NONCE-SESSION | AC-028 | REQ-003 | Mismatch the record nonce against the nonce in its raw session capture while retaining valid hashes/signatures for those bytes. | Non-zero for nonce/session mismatch, not discharged. | Planned |
| TEST-028-HOST-SESSION | AC-028 | REQ-003 | Mismatch the record host session ID against its raw capture session ID while retaining valid hashes/signatures. | Non-zero for host-session mismatch, not discharged. | Planned |
| TEST-028-EXPIRED | AC-028 | REQ-003 | Use a nonce/session outside the already specified validity window; control the verification clock and keep all other fields valid. | Non-zero for expiry, not discharged; do not invent or extend the design's TTL. | Planned |
| TEST-028-DUPLICATE | AC-028 | REQ-003 | Give two distinct cell records the same nonce. | Non-zero for duplicate nonce, not discharged. | Planned |
| TEST-028-VALID-FIVE | AC-028 | REQ-003 | Use valid records for all five named cells with independent nonce/hash/config/session/signature checks satisfied. | Zero and discharged. Active cells prove denial; expected-unavailable cells prove detected unavailability, not denial. | Planned |
| TEST-028-PREACTIVATION | AC-028 | REQ-003 | In an isolated historical-state fixture only, use complete schema-valid signed SKIP records with genuinely nonactivated allowlist entries. | Zero with pending, never discharged. This fixture does not turn back current A1 activation. | Planned |
| TEST-028-MISSING-1 | AC-028 | REQ-003 | Remove only the `Claude-active` record, leaving the other four valid. | Non-zero for missing cell, not discharged. | Planned |
| TEST-028-MISSING-2 | AC-028 | REQ-003 | Remove only the `Codex-enabled-active` record, leaving the other four valid. | Non-zero for missing cell, not discharged. | Planned |
| TEST-028-MISSING-3 | AC-028 | REQ-003 | Remove only the `Codex-disabled-expected-unavailable` record, leaving the other four valid. | Non-zero for missing cell, not discharged. | Planned |
| TEST-028-MISSING-4 | AC-028 | REQ-003 | Remove only the `Copilot-primary-active` record, leaving the other four valid. | Non-zero for missing cell, not discharged. | Planned |
| TEST-028-MISSING-5 | AC-028 | REQ-003 | Remove only the `Copilot-subagent-expected-unavailable` record, leaving the other four valid. | Non-zero for missing cell, not discharged. | Planned |

The per-cell loops in TEST-028-POSTMERGE-SKIP and TEST-028-FAIL must report five individually named results using the exact cell names above; failure of one cell cannot substitute for exercising another. TEST-026-CONFIG-EXPECTED also discharges the identical aggregate config-mismatch branch in AC-028; TEST-026-NONCE-REUSED covers previously consumed nonce rejection, whereas TEST-028-DUPLICATE covers duplicate current records. Signature deletion cases are individually covered by TEST-026-MISSING-23/24, and corrupted signatures/untrusted keys have separate cases. Do not count a missing-signature rejection as proof of cryptographic verification.

## 4. Rebinding and completion conditions

After the human applies the approved revision, preserve attempt 4 round 2 unchanged. Record actual authorization and final amendment commit identity plus new acceptance/investigation hashes in an append-only provenance entry; do not use “this commit” in place of a known full commit ID. A subsequent citation-only entry can bind the already-created amendment commit. Run a fresh legal round-3 precheck with an edit summary and independent reviewers; if Major/Critical remains, preserve BLOCKED and follow the reset/approval procedure. No design/task-stage PASS is inferred from a spec PASS: validate their existing hash bindings and re-review where invalidated. Only the independent quality gate may declare tasks Done.

Identifier sweep: existing acceptance index asserts one parent entry per AC, so that paragraph needs the clarification above. Requirements, design, tasks and layer specifications reference the parent AC/TEST IDs and keep their classification/ownership; do not renumber them. The sweep also exposed an existing design.md Schema Validation Rules prose inconsistency: the general “every key except notes must be non-null” conflicts with its explicit null skip_reason and non-Codex feature-config exceptions (7a65ba). This proposal does not silently resolve or change the frozen design; the existing explicit field-specific exceptions remain inputs for the next design review. All changed-input and downstream binding checks remain mandatory.

