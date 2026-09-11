# UX Specification: epic-196-a8-integration

N/A — no change: this feature has no UX surface. Design.md's Feature Type
header fixes this package as "test-infrastructure specification (Phase
1 — no code)" and its own Layer Specifications section records "UX: N/A
— no GUI, view, dialog, menu item, or human interactive shell surface.
The only human-observable effects are suite pass/fail output, live-host-
session diagnostics, and CI job status." This document restates that
determination in the review harness's canonical layer-file shape; it
introduces no UX judgment beyond what design.md already fixes.

Every deliverable this Phase 1 package specifies is a *design* for a
future implementation task: a cross-runtime handoff fixture and driver
(REQ-001), an install/uninstall matrix driver (REQ-002), an extended
hook-guard regression suite plus a live-host proof record set and its
aggregate validator (REQ-003), a path/line-ending regression fixture
(REQ-004), an installed-cache drift checker (REQ-005), a classification
table and manual-session record schema (REQ-006), and two process-
integrity checks (REQ-007) — design.md's own Components table names all
of them. None of these is an interactive surface — every one is either a
JSON data artifact or a Bash/PowerShell/Python CLI script whose only
observable output is stdout text, a committed JSON record, and an exit
code, consumed by a test suite, a human operator following a fixed
record format, or a CI job — never by a human operating a UI.

The nearest UX-adjacent surface is the diagnostic/verdict text a human
reads at a terminal, in CI logs, or in a committed
`live-host-verification-record/v1` file: suite `PASS`/`FAIL`/`SKIP`
lines, `validate-live-host-proof`'s own `discharged`/`pending`/named
error-code output (design.md API / Contract Plan), and the
`install-uninstall-matrix-result/v1`/`installed-plugin-drift-report/v1`/
`path-lineending-fixture-result/v1` structured records a Phase 2/3
implementer or CI consumes programmatically. This is CLI/test-runner
output and committed data, not an interactive UI, and its exact shape is
fixed by design.md's Data Plan and API / Contract Plan, not this
document's scope to restate.

One narrow surface carries a human-authored, not merely human-read,
component: the `live-host-verification-record/v1` manual-session record
(REQ-006, design.md Data Plan) an operator and an independent reviewer
fill by hand when no automated capture path exists for a given runtime
(Automated / Manual Classification Table, design.md). This is a
structured JSON record an operator fills into a committed file — never a
form, dialog, wizard, or any other rendered interactive surface this
package designs; the fields it requires (nonce, session start/end,
operator/reviewer identity and key IDs, raw capture references, verdict,
two Ed25519 signatures) are fixed by design.md's own schema, and the
"how a human obtains and enters those values" is a Phase 2/3 operational
procedure this Phase 1 package does not design a UI for.

- Target views / navigation / component states / interaction sequence /
  responsive behavior / design tokens / accessibility: N/A — no change
  (no UI exists for this feature to specify).

## Wireframe Attachments

None — manual visual refinement skipped (no UI to mock up).

## Open Questions

- None.
