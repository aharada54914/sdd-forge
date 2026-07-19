# UX Specification: epic-159-pillar-c

N/A — no change: this feature is a contract-schema migration, CLI-flag
additions to existing shell/PowerShell scripts, a new agent-definition
generation script, and run-record schema fields. It has no GUI, view,
dialog, menu item, or human interactive shell surface. The only
human-observable effects are: CLI exit codes and JSON output from
`select-agent-model`/`render-agent-frontmatter`/`emit-run-record`; suite
pass/fail output; CI job status; and, for the four R-10 protected reviewer
`.md` targets specifically, a human maintainer manually running one `cp`
command per file when `render-agent-frontmatter --check` reports drift —
all governed by the acceptance criteria in acceptance-tests.md.

## Scope and User Journeys

- Primary user: maintainer or CI runner invoking the registry/selector/
  renderer/run-record scripts, either directly or via `tests/run-all.sh`/
  `.ps1` and the GitHub Actions run.
- Entry points: `select-agent-model.sh`/`.ps1` (CLI flags), `render-agent-frontmatter.sh`/`.ps1`
  (including its `--check` mode), `emit-run-record.sh`/`.ps1`,
  `run-panelist-gpt.sh`/`.ps1`, and — indirectly, through the quality-gate
  skill's Codex-host startup instructions — the `sdd-evaluator`/
  `sdd-investigator` launch path.
- Secondary, explicitly human journey: a maintainer running
  `cp specs/epic-159-pillar-c/human-copy/<basename>
  plugins/sdd-review-loop/agents/<basename>` after `render-agent-frontmatter
  --check` reports drift on one of the four protected reviewer files, then
  verifying the copied file's SHA-256 against the manifest — a terminal
  copy-and-verify action, not an interactive UI flow.
- Success outcome: a v2 registry expresses tier/effort independently
  without changing v1 or `welded`-mode behavior; agent definitions on both
  hosts stay drift-free against the registry; run records carry an honest
  effort-application signal; Codex hosts actually apply the selected
  effort; Claude Code hosts record an explicit, non-silent degradation.
- Excluded journey: any rendered UI, navigation, or responsive layout.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: CLI exit codes, JSON field values, and CI job status are
specified by acceptance-tests.md rather than a visual component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is introduced.
Diagnostics (`MODEL_SELECTION_ERROR:`, drift-check output,
`effort_degraded_reason` values) stay concise, name the failing
component/field, and never disclose secrets.

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
