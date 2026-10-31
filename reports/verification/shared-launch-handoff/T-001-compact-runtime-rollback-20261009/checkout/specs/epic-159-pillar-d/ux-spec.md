# UX Specification: epic-159-pillar-d

N/A — no change: this feature is contributor-process documentation
(`docs/contributor/workflow-detail.md`, `docs/agent-capability-matrix.md`),
a new CI-only automation workflow
(`.github/workflows/model-freshness-check.yml` + its locking test suite),
and a registry data update
(`contracts/agent-model-capabilities.v2.json`), with no GUI, view, dialog,
menu item, or human interactive shell surface. The only human-observable
effects are Markdown prose a contributor reads, a GitHub Actions job's
pass/fail status on its own weekly schedule or manual dispatch, and a
GitHub issue that may be filed or commented on — all governed by the
acceptance criteria in acceptance-tests.md.

## Scope and User Journeys

- Primary user: a contributor doing plugin-improvement work involving
  model/effort routing (reads the D1 capability-refresh step); a
  maintainer who reviews a weekly-filed freshness-divergence issue or a
  "取得不能" comment (D2); a task implementer who curates current-generation
  registry data once Pillar C's C1 has landed (D3).
- Entry points: `docs/contributor/workflow-detail.md`'s WFI lifecycle
  section (read, during WFI drafting); the
  `model-freshness-check.yml`'s own `schedule:`/`workflow_dispatch:`
  triggers; `tests/model-freshness-check.tests.sh`/`.ps1` via
  `tests/run-all.sh`/`.ps1` or the GitHub Actions `test` job.
- Success outcome: a contributor drafting a `model-routing` WFI has a
  concrete checklist to follow instead of guessing; a maintainer receives
  an honest weekly signal (either a filed divergence issue or a "取得不能"
  comment) instead of silence; a registry consumer sees current-generation
  model data with its confirmation provenance recorded.
- Excluded journey: any rendered UI, navigation, or responsive layout.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: GitHub Actions job status and issue-filing outcomes are
specified by acceptance-tests.md rather than a visual component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is
introduced. The filed issue / "取得不能" comment and the extended
contributor documentation are plain Markdown/GitHub-issue text; neither
discloses secrets or credentials (Security Boundaries B1/B2).

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
