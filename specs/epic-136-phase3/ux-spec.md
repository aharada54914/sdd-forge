# UX Specification: epic-136-phase3

**Stream C status.** ADR-0010 reached `Status: Accepted` (commit `67015a5`,
2026-07-22), discharging Stream C's Blocker, and Stream C landed in this
feature (T-004 authored `tests/workflow-scenarios/` and
`workflow-scenarios.tests.sh`). requirements.md and design.md carry the
authoritative record; this document is reconciled to it.

N/A — no change: this feature is 4 new-test-suite/CI-lane additions
(`tests/guard-dispatch-fallback.tests.sh`,
`tests/guard-negative-corpus.tests.sh`, `tests/workflow-scenarios/`, and
the `.github/workflows/test.yml` job-graph restructuring), with no GUI, view,
dialog, menu item, or human interactive shell surface of its own. The only
human-observable effects are: a maintainer running Codex CLI or GitHub
Copilot CLI on a `python3`-absent macOS/Linux host can trust
`sdd-hook-guard.sh`'s `.ps1` fallback branch has actually been exercised by
a test (Stream A); a maintainer reviewing a guard-touching PR sees a
regression of the `cd&&rm` bypass, the triple-quote injection shape, or a
task-id substring-collision defect caught across all 4 guard-runtime
surfaces and both Claude/Codex `tool_name` shapes, not a narrower subset
(Stream B); a CI maintainer sees `test.yml`'s deterministic steps carrying
a visible `[deterministic]` name prefix in the GitHub Actions UI, without
any step being dropped from `required-checks`' gate (Stream D); and a
maintainer creating a new `tests/workflow-scenarios/` scenario finds it
already speaking the same `greenfield`/`brownfield` vocabulary the loop
harness uses (Stream C) — all governed by the acceptance criteria in
acceptance-tests.md.

## Scope and User Journeys

- Primary user: maintainers and CI reviewers running the full test suite
  locally (`bash tests/run-all.sh`) or observing the GitHub Actions job
  list for a PR (Streams A, B, D); epic-159 Pillar A loop-harness authors
  who author `tests/workflow-scenarios/` fixtures against the shape Stream
  C landed.
- Entry points: `tests/guard-dispatch-fallback.tests.sh` (CLI, `bash
  tests/guard-dispatch-fallback.tests.sh`); `tests/guard-negative-corpus.tests.sh`
  (CLI, same convention); the GitHub Actions job list rendered for any PR
  (Stream D's `[deterministic]`-prefixed step names).
- Success outcome: each stream's target audience
  (requirements.md Target Users) sees the new coverage exist and pass, or
  fail with a legible, per-combination diagnostic naming exactly which
  runtime/tool_name/branch combination regressed (acceptance-tests.md).
- Excluded journey: any rendered UI, navigation, or responsive layout.
  Stream C's downstream user journey — an epic-159 Pillar A author's
  workflow for consuming `tests/workflow-scenarios/` — remains out of scope
  for THIS feature's UX surface: Stream C delivers the harness and its
  fixtures, not a workflow built on top of them.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: script exit codes/stdout contracts and the GitHub Actions
job list's step-name presentation are specified by acceptance-tests.md and
design.md's API/Contract Plan rather than a visual component.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is
introduced. All human-observable output (CLI stdout/stderr, GitHub Actions
step names, cross-runtime parity failure messages) is plain text; none
discloses secrets or credentials (Security Boundaries B1/B2/B3,
security-spec.md).

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
