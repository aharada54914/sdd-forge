# UX Specification: quality-loop-fixes

N/A — no change: this feature is 4 independent script/skill-prose
bugfixes (`check-quality-gate-cycle-limit.{sh,ps1}`,
`emit-run-record.{sh,ps1}`, `prepare-panelist-input.{sh,ps1}`,
`cross-model-verify/SKILL.md`, `validate-review-context-set.sh`, plus the
protected `ship/SKILL.md` and `.github/workflows/test.yml` human-copy
edits), with no GUI, view, dialog, menu item, or human interactive shell
surface of its own. The only human-observable effects are: the `ship`
skill's cycle-limit gate no longer falsely escalating across features
(Stream 1); a run record's `gate_reports.blocked` count matching what a
human actually sees in each report's `VERDICT:` line (Stream 2); a
panelist-input bundle that either succeeds with a complete evidence set
or fails closed with a legible gap list before any panelist is invoked
(Stream 3); and a Windows Git Bash user's review-context-gated command no
longer failing on a canonically valid identity ledger (Stream 4) — all
governed by the acceptance criteria in acceptance-tests.md.

## Scope and User Journeys

- Primary user: any human or agent session invoking `/sdd-ship:ship`
  (Stream 1); anyone reading a run record's gate-report metrics
  (Stream 2); anyone running `cross-model-verify` to collect blind
  panelist verdicts (Stream 3); anyone on Windows Git Bash invoking a
  review-context-gated reviewer/evaluator/loop-driver step (Stream 4).
- Entry points: `check-quality-gate-cycle-limit.{sh,ps1}` (CLI, now
  2-required-arg); `emit-run-record.{sh,ps1}` (CLI, unchanged
  invocation shape); `prepare-panelist-input.{sh,ps1}` (CLI, unchanged
  invocation shape) and `cross-model-verify/SKILL.md` (skill prose, read
  by an agent session); `validate-review-context-set.sh` (CLI, unchanged
  invocation shape).
- Success outcome: each of the 4 fix streams' target audience
  (requirements.md Target Users) sees the corrected, evidence-matching
  behavior instead of the documented defect (BL-101..BL-105).
- Excluded journey: any rendered UI, navigation, or responsive layout.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: script exit codes/stdout contracts and skill-prose
content are specified by acceptance-tests.md rather than a visual
component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is
introduced. All human-observable output (CLI stdout/stderr, skill prose,
gap lists) is plain text; none discloses secrets or credentials
(Security Boundaries B1/B2, security-spec.md).

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
