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

### Issue a nonce before the actual dispatch

The ordinary handshake helper remains stateless. Its `--emit-challenge`
does not append or sign an issuance ledger. The operator-owned adapter
`plugins/sdd-quality-loop/scripts/issue-live-host-nonce.py` supplies this
missing issuance step using the registered issuer's existing Ed25519 key
through OpenSSL. This replaces the historical claim that the handshake
helper itself already writes a signed ledger. It issues only the nonce in
the caller's challenge, with the actual current UTC time; it cannot create
keys, register identities, backdate issuance, or sign completed captures.

Use the installed current scripts, a maintainer-approved public registry,
and an existing `live-host-nonce-ledger/v1` ledger. Keep the private key on
the operator's machine, outside the native host workspace and repository.
The operator must check the original pending caller challenge and intended
cell. The CLI validates signatures and consistency; it does not establish
the challenge's provenance without that operator check. OpenSSL must be
available on the operator machine. Key provisioning and custody remain
human responsibilities; fixture keys are never acceptable.

For every consumer/cell execution:

1. In the actual native session, read the full current consumer SKILL and
   invoke its ordinary `--emit-challenge`. Save its unmodified JSON and
   pause that same session before the canary tool call. A standalone
   external canary or a replacement session is not equivalent.
2. Transfer that challenge to the operator. On the operator machine run:

   ```sh
   python3 <installed-scripts>/issue-live-host-nonce.py --issue \
     --challenge <original-challenge.json> --matrix-cell <cell> \
     --nonce-ledger <private-ledger.json> --trusted-signers <approved-registry.json> \
     --issuer-key-id <registered-issuer-key-id> --private-key <operator-key-file>
   ```

   The adapter uses the aggregate's ledger lock, validates the existing
   ledger, rejects duplicate nonces, verifies its newly produced signature
   against the registered public key, and atomically appends the entry.
   Do not issue the same nonce twice or edit a failed entry into success.
   An interrupted issue that committed the ledger can be checked using the
   public verification command below; never infer success from missing output.
3. Return only the signed public ledger and approved public registry to
   the caller. Before resuming, verify against the original challenge:

   ```sh
   python3 <installed-scripts>/issue-live-host-nonce.py --verify-receipt \
     --challenge <original-challenge.json> --matrix-cell <cell> \
     --nonce-ledger <private-ledger.json> --trusted-signers <approved-registry.json>
   ```

   Continue only on exit 0 with matching nonce and cell. This path accepts
   no private key and rejects unknown, consumed, future, expired, or invalidly
   signed issuance. A printed receipt alone is not trusted input.
4. Resume the same native caller, dispatch its nonce-bearing canary, then
   run the ordinary helper verification and retain original native events.
   Dispatch must occur after actual issuance and within 24 hours. If the
   session or window is lost, restart with a fresh challenge; never infer
   a historical issuance time or modify raw events.
5. Repeat for all five consumers in all five cells. Preserve original
   installed helper/configuration bytes and native launch metadata. Build
   the five v2 records from those originals, obtain operator and independent
   reviewer signatures, and run the existing aggregate validator. Its
   successful `discharged` result consumes the 25 issued nonces atomically.

The issuer adapter and aggregate must use the same ledger, or transfer a
single authoritative copy serially; concurrent divergent copies are not
merged. Store captures and signatures privately. Public issue comments need
only sanitized results and code/CI references, never original session IDs,
local directories, or key material. The existing unsigned 25 captures are
functional evidence, not input to retrospective issuance.

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
