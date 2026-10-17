# Design: Feature Concept Test

Impl-Review-Status: Pending

Bootstrap gathers the request, invokes concept-test, then invokes domain-sync
only after CONTINUE. The seed is saved verbatim before analysis. The Concept
Test skill reads domain evidence and that seed; externally supplied requirements
are included in the seed. Domain authoring is a separate workflow.

The JSON contract stores feature, proposal, rationale, distinctions, optional
decision and input hashes. Markdown carries one authoritative fenced JSON object
identical to the JSON file. This avoids a second prose parser or a second source
of truth. Inputs include the contract, its generated_from sources, and the seed;
paths must be canonical and stay inside domain/ or the feature seed. Symlinks,
missing files, duplicate entries and hash changes fail closed.

validate-concept-test.py uses the existing schema validator, standard approval
validator, and Phase 0 domain validator. Bash/PowerShell wrappers share that
implementation. Approval JSON content uses the existing canonicalizer's JSON
mode; YAML approval callers keep their existing mode. A Concept Test signature
approves an immutable decision snapshot, not a context-policy transition. The
existing generator stages the feature-local sidecar and snapshot without writing
live files. No new cryptographic algorithm or key store is introduced.

The review conditional-input resolver selects these files at the same revision
as the review. Both admission twins require the selected hashes; historical
reservations keep their bound inputs. Every review stage repeats domain semantic
validation and signed approval validation against a private snapshot of the
selected bytes, and requires a continuing decision. The approver registry is an
observed validation dependency at that same revision. Existing domain validators,
canonicalizer and approval schemas are part of the fixed runtime dependencies.
The three plugin manifests already expose
the entire skills directory, so no per-skill manifest enumeration is necessary.

The validator reports CONTINUE/SKIP (0), BLOCK (1), DEFER (2), REJECT (3).
The bootstrap skill is declarative: test the executable gate independently and
assert the documented ordering/stop contract; do not claim a simulated LLM run
is an observed end-to-end bootstrap session.

## Fresh domain review identity

The normal first domain review previously required a nonempty identity ledger
without providing a producer. A bounded initializer now reads the original
Copilot `session.start` event under its configured native state directory,
binds the event's session directory and project cwd, and publishes sequence 1
with stage `host` and role `orchestrator`. It accepts no caller-supplied IDs.
The documented `COPILOT_HOME` setting (default `.copilot` in the home directory)
and selection of the current session are trusted host configuration. This is
native metadata provenance, not cryptographic or live-process attestation.
Other hosts are not inferred from this format.

Initialization precedes the first domain precheck. Existing ledgers, prior
review/implementation artifacts, redirected paths, aliased event files and
reservation locks cause refusal. The existing cross-runtime ledger lock and
exclusive publication of a completely written file prevent overwrites and
partial records. Failure removes only this invocation's temporary state. Normal
review admission still validates the full chain and reserves each new reviewer;
initialization neither authorizes a reviewer nor fabricates review history.

## Independent native review hashing

The native child-agent interface may reveal IDs only after creation. Copilot's
CLI supports empty tool-free runtime allocation first, followed by reservation
of its actual native event/session identities and continuation into the named
reviewer. Only that empty allocation may precede reservation. No implementation,
review, evaluation or substantive input context may be reused.

Read/Grep/Glob alone could not perform the existing independent SHA-256 checks.
Domain roles now describe a conditional Bash hashing primitive, with verified
host-enforced read-only permissions required before launch. The native route
exposes view/rg/glob/bash and grants only sha256sum/printf explicitly, denies the
write tool and disallows interactive permission escalation. Built-in read-only
commands may remain available; this is not a single-command sandbox. Actual
host permission probes must cover compound commands, substitution and nested
shell/environment writes. Unknown host profiles block rather than trusting a
prompt-only read-only promise. Literal record text is hashed without a terminal
newline, input bytes remain individually verified, and output identities must
match the reservation verbatim.
