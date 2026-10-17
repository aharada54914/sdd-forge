# Current native hook acceptance contract

This addendum describes the current implementation of AC-015, AC-016,
AC-026–028. The original approved documents and historical captures retain
what was known when they were recorded; they are not rewritten as new proof.
The current aggregate accepts `live-host-verification-record/v2` only.
This supersedes the v1 field table and fixed child-unavailability assumption
in the historical `requirements.md`, `design.md`, and `security-spec.md` for
current aggregate execution. Their approved bytes and old v1 records remain
unchanged; they are not a migration input or current successful proof.

## What the aggregate verifies

Each of the five cells must contain exactly one execution of each current
consumer: `sdd-bootstrap`, `sdd-bootstrap-interviewer`, `lite-spec`,
`lite-gate`, and `sdd-ship`. `consumer_executions` binds each consumer's
canonical source path and SHA-256, fresh nonce, native session/event IDs,
observed outcome, native evidence window, and SHA-256 references to the
original request, result, and invocation JSONL. The cell's representative
request/result must be one of those exact executions. Merely listing source
files, reading a SKILL, or running a separate canary does not satisfy AC-016.

The validator recognizes native Claude stream events, Codex persisted rollout
events, and Copilot tool events. It requires the complete source read in
original order before the same caller invokes the shipped challenge helper,
dispatches the nonce-bearing canary, and invokes the verifier. The native
verifier output must establish the declared runtime, nonce, and status.
Assistant prose is not a tool result. A redirected helper result is accepted
only when the same native caller reads that exact destination without an
intervening replacement. Unsupported command forms fail closed.

The signed inventory's evidence window equals the native timestamps: the
Codex session metadata timestamp when present, otherwise the first timed
native event, through the last timed event. The issuer's original issuance
must fall between the caller's native emit and canary dispatch. Raw events
are never supplemented with invented times or identities.

## Current host semantics

| Cell | Required observation |
| --- | --- |
| `Claude-active` | `HOOK_ACTIVE` for all five consumers |
| `Codex-enabled-active` | `HOOK_ACTIVE`, actual `--enable hooks` launch |
| `Codex-disabled-expected-unavailable` | `CAPABILITY_RUNTIME_UNAVAILABLE`, actual `--disable hooks` launch |
| `Copilot-primary-active` | `HOOK_ACTIVE`, primary caller ownership |
| `Copilot-subagent-observed` | The actual child outcome, consistently `HOOK_ACTIVE` or `CAPABILITY_RUNTIME_UNAVAILABLE` |

Current Codex uses the `hooks` feature. A removed `plugin_hooks` selector is
not evidence that enforcement was disabled. Each Codex execution and its
cell bind `hook_control_ref` and `hook_control_sha256` to the original launch
metadata (`command` argv, `root`, and measured `started` epoch seconds).
The validator requires a single current hooks selector, rejects conflicting
configuration overrides, and matches the metadata to the native session's
working directory and start. It does not manufacture an effective TOML file
for a process that was launched using CLI selectors.

A Copilot child must have matching native agent and parent-tool identities,
a real parent `task` dispatch, and ordered child-start/completion events.
Its SKILL read, emit, canary, and verify must belong to that same child.
A working current child is not relabeled as unavailable to fit an older
expectation. The deliberately disabled Codex cell remains the negative
non-firing observation.

## Authenticity and completion

Confirmed automated native captures use `invocation_mode: automated`;
manual captures use `manual`. Both require the identical issuer-signed nonce
ledger and two distinct trusted, role-separated operator/reviewer Ed25519
signatures. The entire inventory, launch metadata hashes, and raw hashes
are covered by the record signatures. Existing key identity, collision,
TTL, single-use, atomic consumption, and synthetic-substitution protections
remain in effect.

Native event structure and hashes establish consistency, not cryptographic
host attestation. The independent operator/reviewer trust boundary still
establishes origin and installed helper provenance. Recognizing a helper
basename and a supported invocation does not authenticate that executable's
bytes; operator/reviewer review must check the original installed artifacts.
The validator parses capture data and never executes embedded commands.
Unit-test keys and synthetic fixtures demonstrate
validator behavior only. Native functional captures without authoritative
issuance and signatures do not discharge the aggregate. Existing unsigned
captures must not be retroactively supplied with invented issuer times,
registry membership, or signatures.

Current real-host evaluation exercised all 25 consumer/cell combinations:
Claude five active; Codex five enabled active and five disabled unavailable;
Copilot five primary active and five child active. The validator's native
parser accepted those original captures, including actual caller execution
and host ownership. These private, unsigned captures do not constitute a
signed aggregate result. Public raw captures must not disclose personal
information, credentials, local directories, or host/session identifiers.

## Verification

The existing Bash and PowerShell live-host-proof suites exercise the v2
contract, including missing and duplicated consumers, source/hash mismatch,
native identity and role substitution, native-result/verifier contradictions,
incorrect outcomes, signed-payload
tampering, issuance after dispatch, forged evidence windows, removed or
conflicting feature selectors, false helper invocations, shuffled source
reads, redirected-result replacement, and native child ownership. Positive
cases retain manual and automated execution and exact redirected reads.
Historical unsigned v1 records remain explicit incomplete evidence.

## Handoff completion and downstream revalidation

When AC-006 is active, the live cross-runtime handoff drivers validate the
signed five-cell aggregate after both real handoffs succeed. The Bash
`--live-host-proof-dir` and PowerShell `-LiveHostProofDir` options select its
records directory; the default is the repository's live-host-proof directory.
Trusted signers, expected configuration digests, the skip allowlist, and the
verifier remain those of the current checkout. The captured five consumer
sources must match that checkout even when the proof is stored elsewhere.

Only a successful `discharged` result produces `canary_case.result: PASS`
and `coverage_complete: true`. Missing, unsigned, stale, or invalid proof
does not produce a successful trace. Fixture-only and pre-activation runs
remain incomplete coverage; manual result fields cannot replace validation.
The private trace binds the five original records, the consumed nonce ledger,
current policy/source hashes, and original validator output in
`canary_case.proof` (`cross-runtime-live-proof/v1`). These artifacts may contain
sensitive host information and must not be published as raw evidence.
Artifact references for records and the ledger are relative to the selected
records directory; current verifier, consumer, and policy references are
repository-relative. The stdout reference is relative to the trace evidence
directory. `records_dir` is an original collection locator, not an immutable
identity: transporting the original evidence preserves the relative references
and hashes, and revalidation uses the explicitly selected proof root.

Downstream promotion uses the same validator through the read-only
`read_only_proof` helper. It requires an already completed consumption receipt
for each exact record, rechecks all original signatures and evidence, and
leaves ledger bytes unchanged. It does not reset consumed nonces or turn an
unconsumed issuance into completed proof. The validator CLI still consumes
valid nonces by default.
