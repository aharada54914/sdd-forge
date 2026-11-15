# Session model selection: startup gate diagnosis

Date: 2026-11-15 UTC
Feature implementation: not started; canonical feature specifications not generated.

## Observed failure

The bootstrap skill requested a fresh hook activation challenge. The actual
`apply_patch` tool wrote `sdd/.hook-canary-sentinel` successfully, and a separate
read verified its challenge content. Verification with an honest `executed: true`
record returned exit 63, `CAPABILITY_RUNTIME_UNAVAILABLE / WRITE_EXECUTED`.
The sentinel was subsequently deleted; the working tree contained no feature changes.
The user then explicitly approved treating this hook check as an exception for
this development session. This does not grant exceptions to other gates.

## Cause and limits of the finding

The verifier deliberately rejects a successful write: its contract requires a
real host-level denial as proof that the guard is active. This behavior matches
its implementation; changing the verifier to pass would erase the guarantee.

The current session operates through ChatGPT Work tools. The development
environment README explicitly distinguishes local native CLI plugin registration
from ChatGPT Work registration. The repository's quality plugin manifests bind
PreToolUse guards to native CLI hook lifecycles. Reading their source in Work does
not install those guards into Work's tool dispatch. The observed write establishes
that this attempt was not blocked. It does not establish whether a separately
launched Codex or Claude CLI has working hooks, nor whether their trust settings
are enabled. Those require a canary in each actual native host.

The contributor AGENTS workflow requires the bootstrap skill, and that skill
requires native hook attestation before bootstrap. Applying that native-runtime
precondition to this Work development session created the initial stop. The user
exception permits continuing past this specific check without claiming HOOK_ACTIVE.

## Corrective choices

- Keep normal plugin verification isolated in `verify-codex`; prove native hooks
  using that actual process, independently of Work-side source edits.
- For Work development, explicitly authorize a contributor workflow using the
  local development skills, ordinary tests and independent code review, without
  requiring native consumer-runtime attestations in the parent Work session.
- Do not change hook guards, claim native denial from model prose, fabricate
  native identities, or set missing key material to arbitrary replacement values.

## Follow-on independent blocker

Project Context approval validation then reported `NO_CONTEXT_KEY` (exit 11).
See `session-model-selection-readiness.md` for the exact check and recovery.
That gate is independent of the hook exception. No approval signature was
changed and no key value was read, printed, generated or committed.

## Verification of the diagnostic behavior

The existing Bash suites completed successfully on 2026-11-15:

- `tests/check-hook-activation-handshake.tests.sh`: 985 assertions passed,
  zero failed; its additional 12 Python tests also passed. These include the
  successful-write refusal and the separation of cleanup from activation.
- `tests/validate-approval-sidecar.tests.sh`: 50 assertions passed, zero failed,
  including the missing-key hard failure.

These are deterministic verifier tests, not live native hook attestation or
feature acceptance tests. No feature implementation has been verified.

## Resolution after implementation

The user explicitly authorized development skills, independent review and tests
for this Work session instead of the consumer SDD approval workflow. Implementation
therefore proceeded without pretending that Work's tool dispatch is the native CLI
hook lifecycle, and without inventing a Project Context signature key. The feature
was implemented and tested under that authorized route. No normal-user guard,
sidecar, approval registry, hook trust setting or future-session instruction was
changed to manufacture a passing startup check. For future Work development,
make that distinction explicit in the development entry workflow; for real plugin
use, keep native runtime and signature checks intact.
