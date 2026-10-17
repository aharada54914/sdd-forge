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
