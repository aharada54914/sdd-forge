# UX Specification: epic-159-pillar-b

N/A — no change: this feature is release-gate wiring (a new CLI-side
prerequisite inside `scripts/bump-version.sh` and a new required CI job
inside `.github/workflows/release.yml`, plus their two locking test
suites) with no GUI, view, dialog, menu item, or human interactive shell
surface. The only human-observable effects are `scripts/bump-version.sh`'s
existing terse stdout/stderr convention (an added failure diagnostic when
the loop-gate prerequisite fails), CI job pass/fail status for the new
`loop-gate` job in `release.yml`, and suite pass/fail output — all
governed by the acceptance criteria in acceptance-tests.md.

## Scope and User Journeys

- Primary user: a release operator running `scripts/bump-version.sh
  <version>` locally, or a maintainer publishing a GitHub Release /
  triggering `workflow_dispatch` on `release.yml`.
- Entry points: `scripts/bump-version.sh <version>` (CLI); the
  `release: [published]` GitHub event or a manual `workflow_dispatch` run
  (CI); `tests/bump-version-gate.tests.sh`/`.ps1` and
  `tests/release-loop-gate.tests.sh`/`.ps1` via `tests/run-all.sh`/`.ps1`
  or the GitHub Actions `test` job.
- Success outcome: a release operator or CI run whose loop suites are red
  is refused before any release surface is touched or any release artifact
  is produced; a green run proceeds exactly as it does today.
- Excluded journey: any rendered UI, navigation, or responsive layout.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: CLI exit codes and CI job status are specified by
acceptance-tests.md rather than a visual component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is
introduced. The added CLI failure diagnostic names the failing suite and
states that no release surface was modified; it never discloses secrets.

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
