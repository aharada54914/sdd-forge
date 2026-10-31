# AC-016 minimal contract candidate — not adopted

Superseded proposal (2026-10-06): see
`a8-ac016-minimal-amendment-20261006.md`. The per-consumer raw-file pairs and
duplicate-path rejection below exceeded the recorded requirement and are
withdrawn. This file and its prototype are retained as proposal history, not
an approved contract or implementation requirement.

Owner: A8 checkout; HEAD observed `495c88d67af44530687ecea3ce9fb0a90a336539`.
Scope: attempt-9/round-2 reviewer B Major DESIGN-WITHIN-SCOPE. Existing dirty
changes are retained. High risk: signed evidence schema and acceptance binding.
No production edit, reservation, approval, task state, or historical verdict change.

## Corrected finding and reuse

The earlier continuation note's statement that no reusable inventory exists is
superseded: `plugins/sdd-review-loop/references/a8-skip-allowlist.json` already
records `upstream_epic_a1_commit` and `upstream_epic_a1_path_blob_ids` for AC-016.
`tests/fixtures/live-host-proof/run_cases.py` defines T008_A1_COMMIT and
T008_CONSUMER_PATHS and checks all five source blobs in its TEST-016 path.
That check additionally looks for AC-016 in notes; it does not check five actual
consumer observations per semantic cell. Source availability is not execution.

## Proposed normative amendment

Use `live-host-verification-record/v2` with one additional required field,
`consumer_inventory`. Reuse the existing unsigned-record JCS and two Ed25519
signatures. No additional signer, nonce ledger, gate, or parallel report.

For an executed PASS record, consumer_inventory has exactly:

- `upstream_epic_a1_commit`: the immutable accepted A1 package commit.
- `upstream_epic_a1_path_blob_ids`: the existing exact five source-path/blob map.
- `observations`: exactly five entries with unique consumer names: sdd-ship,
  sdd-bootstrap, sdd-bootstrap-interviewer, lite-spec, lite-gate.

Each observation has exactly consumer, raw_tool_request_ref,
raw_tool_request_sha256, raw_tool_result_ref, raw_tool_result_sha256. Names map to
the already-defined five source paths, not caller-controlled paths. Runtime,
semantic cell, session, nonce, CLI/configuration and human identities are
inherited from the containing record. Request/result captures must identify the
particular consumer invocation in that session, with the corresponding host
event. Native bytes remain unmodified; no generated wrapper substitutes for
native capture. Both humans inspect this binding before signing. The existing
safe proof-path and digest rules apply to every reference. A single sampled
request/result pair cannot serve multiple consumers; observations with duplicate
request or result capture paths are rejected.

The active cells require the configured consumer outcome; disabled/subagent
unavailable cells require each consumer's invocation and expected unavailability,
not a claim that its guarded operation succeeded. A record without actual
consumer observations cannot discharge AC-016. Historical v1 and draft SKIP
records remain historical and cannot satisfy the v2 completeness check. SKIP
uses null inventory and retains the existing upstream-SKIP conditions; it is
pending, never an AC-016 completion. The existing post-A1 rule still rejects SKIP.
FAIL also cannot discharge AC-016; diagnostic partial evidence is not completeness.

Validation must compare source commit/path/blob identities against the accepted
A1 source inventory and actual Git objects, not merely against a map declared in
the same record. The current accepted source is c0aaf3a639f4cb4798b16acd115f0b05db44493f;
reverify all five blobs at adoption/review. A later accepted A1 package requires
explicit inventory revision, never implicit main drift.

## Callers and required adoption changes

- `validate-live-host-proof.py`: exact RECORD_KEYS and v1 check need explicit v2
  handling, nested completeness/path/digest checks before discharge/consumption.
  Existing validate_signatures already signs every added key without a new API.
- `.sh` and `.ps1` wrappers: same CLI and validator, no new arguments.
- `tests/fixtures/live-host-proof/run_cases.py`: Fixture record generators,
  record_target/sign_record (already generic), schema/negative cases and TEST-016.
- `tests/validate-live-host-proof.tests.sh` and `.ps1`, POSIX inventory and
  `tests/run-all.ps1`: existing registrations retained; execute both wrappers.
- Five committed `tests/hook-activation-live-proof/*.json` records: preserve old
  bytes as history; do not relabel old signatures or manufacture observations.
- requirements AC-015/AC-026, design live-proof schema/AC-016 mapping, ADR-0028
  v1 scope and tasks T-008 references: explicit version-transition addendum and
  normal provenance re-review. Design-only amendment would leave contradictions.
  No frozen source is edited by this candidate.

## Preflight and candidate-only verification

Persisted fields: schema ↔ explicit v2 version (old-v1 rejection);
source commit/map ↔ accepted A1 Git objects (wrong commit/path/blob rejection);
consumer membership ↔ requirements AC-016 five names (missing/duplicate/unknown);
capture ref/digest ↔ actual native bytes (missing/outside/stale digest rejection);
cell/session ↔ outer record and native capture (formal implementation must retain
existing cell/session checks and add human-attested consumer binding);
inventory bytes ↔ both existing signatures (post-sign mutation rejection).

`a8-ac016-inventory-prototype-20261006.py` is a disposable contract experiment,
not the production validator. It uses existing deterministic synthetic signing
fixtures and existing signature/path/hash helpers. Its green results establish
only structural completeness, source identity, raw-byte references and signature
binding. They do not prove native consumer invocation, full v2 validator parity,
fresh real human signatures, review PASS, CI, or deployment.

Next: complete author-time AC-016/version identifier sweep, admit the exact
amendment through the normal design/requirements transition, then implement the
approved validator/test delta with production red→green and fresh live evidence.
No review identity may be reserved until the parent coordinates the next round.
