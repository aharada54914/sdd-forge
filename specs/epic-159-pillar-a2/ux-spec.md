# UX Specification: epic-159-pillar-a2

N/A — no change: this feature is test infrastructure (a new terminal-behavior
suite, a canonical fixture seed plus its lock suite, and two PowerShell
precheck script ports) with no GUI, view, dialog, menu item, or human
interactive shell surface. The only human-observable effects are suite
pass/fail output, named SKIP-with-reason degradation lines (and, for T-003/
T-004, those SKIP lines disappearing from two already-existing suites), and
CI job status — all governed by the acceptance criteria in
acceptance-tests.md.

## Scope and User Journeys

- Primary user: maintainer or CI runner executing the loop harness suites.
- Entry points: `tests/hitl-wfi-terminal.tests.sh`/`.ps1`,
  `tests/check-placeholders-brownfield.tests.sh`/`.ps1`, via
  `tests/run-all.sh`/`.ps1` or the GitHub Actions run; the two new
  `plugins/**/scripts/*-review-precheck.ps1` files are invoked indirectly,
  through the existing `tests/loop-driver.tests.ps1` and
  `tests/loop-consistency.tests.ps1` entry points.
- Success outcome: HITL and WFI-audit terminal caps are demonstrably
  verified; the brownfield fixture profile has a canonical seed and a
  locked `check-placeholders` behavior contract; the pwsh lane's spec-review
  and domain-review named SKIPs disappear.
- Excluded journey: any rendered UI, navigation, or responsive layout.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: CLI exit codes, ok/FAIL counters, and CI job status are
specified by acceptance-tests.md rather than a visual component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is introduced.
Diagnostics stay concise, name the failing loop/leg, and never disclose
secrets.

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
