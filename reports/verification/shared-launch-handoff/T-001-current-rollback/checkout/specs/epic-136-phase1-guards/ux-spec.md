# UX Specification: epic-136-phase1-guards

N/A — no change: this batch has no GUI, view, dialog, menu item, or human
interactive shell surface. The only human-observable effects are (a) existing
CLI hook deny/allow decisions, (b) the ship skill's cycle-limit and
cross-model diagnostics, and (c) a CI workflow pass/fail. All are governed by
the acceptance criteria in acceptance-tests.md.

## Scope and User Journeys

- Primary user: maintainer running the gate suites, the ship flow, or the
  weekly CI workflow.
- Entry points: `tests/*.tests.sh` / `*.tests.ps1`, `/sdd-ship:ship`, and the
  GitHub Actions run.
- Success outcome: protected writes are denied on every runtime; critical
  tasks cannot skip cross-model verification silently; automated PRs are
  guarded.
- Excluded journey: any rendered UI, navigation, or responsive layout.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: CLI exit codes, hook decisions, and CI job status are
specified by acceptance-tests.md rather than a visual component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is introduced.
Diagnostics stay concise and never disclose secrets or token values.

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
