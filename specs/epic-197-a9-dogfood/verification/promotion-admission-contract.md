# Bound Phase-2 promotion

`scripts/validate-a9-promotion.py` implements REQ-007/008 and the resolved
OQ-003 criteria. Validation is read-only by default. It does not issue approval,
create signatures, collect live-host proof, publish a release, or activate a
Context merely because the tests pass.

An operator supplies a private `promotion-decision/v1` JSON document and a
staging directory. Use `--decision <relative-record>` and
`--staging-dir <relative-stage>` from the intended project, or select that
project with `--root`. No key, evidence body, or local path is included in the
result. Evidence should remain private; the test fixtures use disposable keys
and synthetic observations and are not operational approval.

## Signed decision and current authority

The exact decision fields are `schema`, `criteria_revision`, `head_sha`,
`decided_at`, `decision`, `bindings`, `basis`, `old_tuple`, `new_tuple`,
`criteria`, `rollback`, `signer`, `signer_key_id`, and `signature`.
The revision is `OQ-003/2026-09-02`, and `decision` is `promote`.
The tuples are exactly `full`/`legacy-seven-layer`/`advisory` and
`full`/`facet-hybrid`/`required`. All four criteria
(`false_positive_triage`, `critical_major_resolution`, `three_platforms`,
`rollback_rehearsal`) must be `PASS`; each is recomputed from evidence.

The current trusted-signers registry authorizes the Ed25519 operator key.
The signer must be the candidate Context's primary HMAC approver. Using the existing Ed25519 convention, sign
`SHA256(JCS(decision without signature) || UTF8(":a9-promotion-approved"))`.
The validator accepts signatures; it has no signing operation. It also verifies
both existing Context HMAC approvals, the current approved anchor, the exact
successor epoch and predecessor digest, and approval/decision times against the
actual clock. Neither a JSON `PASS` claim nor a valid Context approval alone
approves the evidence bundle.

Each `bindings` entry is `{path, sha256}` with a canonical project-relative path
and the unprefixed SHA-256 of original bytes. Fixed entries are `context`,
`approval`, `anchor`, `approvers`, `trusted_signers`, and `registry`; they must
name the existing live policy locations. Candidate entries are
`candidate_context`, `candidate_approval`, `candidate_snapshot`, and `manifest`,
all within the supplied stage. Evidence entries are `resolver`, `facet_manifest`,
`release_cycle`, `findings`, `compatibility`, and `cross_runtime`.
`basis` binds the actual resolver `context_binding` and `resolver`, plus the
facet manifest's `affected_components`. The release cycle and decision must
identify the clean current Git HEAD. The existing release preflight rechecks
all release PRs, their exact heads/checks, Pack/Resolver evidence and ownership.
Each observed Phase-1 approval is also authenticated with the current approver
registry and existing HMAC validator.

## Findings, compatibility, and live-host evidence

`findings` is an `a9-advisory-findings/v1` inventory with `base_sha`, `head_sha`,
`observations`, and `dispositions`. There must be exactly one observation per
release PR: `{pr, head_sha, source, findings}`. Its bound original export is
`{pr, head_sha, findings}`; every finding has `id`, `kind` (`finding`,
`guard-false-positive`, or `gate-false-positive`), and `severity` (`Critical`,
`Major`, `Minor`, or `Info`). Every observed finding needs exactly one
`{pr, id, status, wfi}` disposition. Status is `open` or `resolved`;
Critical/Major must be resolved. False positives bind an actual committed
`docs/workflow-improvements/WFI-NNN.md` with matching WFI-ID, valid Status,
and Problem Evidence identifying the PR and finding. Normal findings have
`wfi: null`. The signed operator attests the original export's completeness;
this offline tool does not claim to query a hosting service for omitted events.

`compatibility` is `a9-compatibility-observations/v1` with `head_sha` and
`results`. Each result binds `platform`, `suite`, `source_sha256`, numeric
`exit_code`, and a `log` byte binding. Both existing compatibility suites must
pass on Linux, macOS, and Windows, using the suite source at the release head.
Logs must end in a nonzero pass count and zero failures, with no skipped
required coverage. These are original execution logs attested by the signed
operator, not an independently authenticated CI API response.

`cross_runtime` is `a9-cross-runtime-observation/v1` with `head_sha`, `suite`,
`source_sha256`, numeric `exit_code`, `trace`, `logs`, `output`,
`proof_records_dir`, and `proof_stdout`. `logs` maps every trace evidence ref to
its byte binding. The actual two-stage handoff must have complete coverage,
fresh distinct mutation nonces, native consumer observations, and exact final
output bytes. A complete canary also requires the existing signed A8 aggregate,
revalidated through `read_only_proof` against current trust, current consumer
bytes, and exactly consumed nonce receipts. The original trace's artifact
roster and hashes must match that validation; claimed PASS, unsigned records,
foreign/unconsumed nonces, changed source or changed trust are insufficient.
The original trace bytes remain unchanged when proof is transported:
`proof_records_dir` selects the copied proof directory; the original
`records_dir` string is only a locator, while stable artifact refs and hashes
establish identity. Host sessions must precede the signed decision. No nonce
state is written by promotion validation.

## Rehearsal and publication

`rollback` contains `root`, `receipt`, `staging_dir`, and `applied_attestation`.
It identifies the private rehearsal project and bound authorization/attestation
records consumed by the existing rollback verifier. Rehearsal trust must equal
current trust; its signed before-Context must equal this proposed Phase-2
Context. `APPLIED_VERIFIED` is required, including current rehearsal files and
signed publisher result. A proposed rollback plan or a rehearsal of another
Context does not qualify.

Success without `--apply` reports `ADMISSIBLE`. Explicit `--apply` privately
snapshots only the approved Context, approval sidecar, approved snapshot and
exact three-target manifest. It rechecks current evidence, trust, time and
live anchor immediately before invoking the existing transactional publisher.
The low-level publisher and HMAC schema are unchanged. The result is `APPLIED`
only after the receipt and all three live byte hashes match. Publisher failures
remain failures and use the existing publisher's recovery procedure.

Even `APPLIED` reports `post_promotion_feature_verified: false`. REQ-008's real
feature workflow under required enforcement remains a separate acceptance
condition, and actual release/host evidence and human authorization remain
external operational prerequisites.
