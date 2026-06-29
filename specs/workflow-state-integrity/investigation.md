# Investigation: workflow-state-integrity

Source: repository audit performed on 2026-06-27 after updating local `main`
to `0369c8c`.

## Context

The review-loop prechecks reject an invalid transition while that transition is
being attempted. The repository and quality gates, however, do not revalidate
the complete persisted Spec → Impl → Task chain. This creates a gap between
transition safety and repository-state safety.

## Findings

| ID | Finding | Severity | Evidence |
|----|---------|----------|----------|
| INV-001 | A completed feature can retain `Spec-Review-Status: Pending` and `Impl-Review-Status: Pending` while `Task-Review-Status: Passed` and all tasks are `Done`. | Critical | `specs/claude-workflow-compatibility/{requirements.md,design.md,tasks.md}` |
| INV-002 | Task-review transition prechecks correctly require both predecessor statuses to be `Passed`; therefore the current invalid state was not produced through the current happy path. | High | `plugins/sdd-review-loop/scripts/task-review-precheck.sh:107-110`; PowerShell equivalent |
| INV-003 | `check-task-state` validates task lifecycle/evidence but does not validate Spec/Impl/Task review status ordering or review-contract provenance. | Critical | `plugins/sdd-quality-loop/scripts/check-task-state.{sh,ps1}` |
| INV-004 | Repository validation checks packaging, versions, required files, and script presence, but does not scan persisted workflow states. It passes the inconsistent repository. | High | `tests/validate-repository.ps1`; `.github/workflows/test.yml` |
| INV-005 | Historical specification directories use several incompatible generations: missing review headers, partially reviewed stages, and completed tasks. Silently treating them as current full-profile artifacts would either create false provenance or break every validation run. | High | `specs/{sdd-forge-refactor,cross-model-verification,risk-adaptive-layer,claude-workflow-compatibility}` |
| INV-006 | The uninstall feature merged in `277a79d` added product code and tests without a corresponding source specification record. | Medium | Git commit `277a79d`; `uninstall.{sh,ps1}`; `tests/uninstall.tests.{sh,ps1}` |
| INV-007 | POSIX and PowerShell are both supported enforcement surfaces, including CRLF input, so a one-runtime fix would recreate a parity gap. | High | `.github/workflows/test.yml`; `tests/crlf-parity.tests.sh`; existing paired gate scripts |
| INV-008 | All released plugins and both marketplaces currently use synchronized version `1.2.0`; repository validation requires synchronized release versions. | Medium | plugin manifests, marketplace files, `tests/validate-repository.ps1` |

## Root cause

Workflow integrity is enforced as local transition preconditions rather than as
a repository invariant. Once an inconsistent state is present—through an older
workflow, manual edit, merge, or incomplete migration—no global or quality-gate
check rejects it.

## Safety constraints

- Do not fabricate historical review verdicts or mark an unreviewed stage
  `Passed`.
- Do not weaken current transition prechecks, task evidence checks, or approval
  gates.
- Preserve POSIX/PowerShell behavior parity and LF/CRLF compatibility.
- Legacy classification must be explicit, bounded to known pre-v1.3.0
  artifacts, and unavailable as an implicit fallback for new directories.

