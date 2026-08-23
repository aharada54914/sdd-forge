# WFI-041 installer idempotency — CI registration handoff

Status: Pending human application

Base commit: `e16a126aad74409453138396bd428d4129f08cec`

Protected target: `.github/workflows/test.yml`

Patch: `docs/ci-staging/wfi-041-installer-idempotency-ci.patch`

SHA-256: `21d99d3fbc25e9e944bd874179f0e7b14de4b303316890157ba3429ac7cfa3ca`

The repository's deterministic guard prohibits agents from modifying the active
workflow directly. This was not assumed — the edit was attempted on 2026-08-23
and refused:

```
SDD deterministic gate: agents must not modify gate scripts, hook
configuration, or critical test files. These are part of the enforcement
chain and cannot be bypassed by sudo.
```

No workaround was attempted. WFI-040 closed most of the gaps that used to let
an agent reach a protected path through an unrecognised write verb; going
looking for a surviving one would defeat the control this repository just
finished tightening.

A human must verify the base commit and digest, then apply the staged patch
from the repository root:

```bash
shasum -a 256 docs/ci-staging/wfi-041-installer-idempotency-ci.patch
git apply --check docs/ci-staging/wfi-041-installer-idempotency-ci.patch
git apply docs/ci-staging/wfi-041-installer-idempotency-ci.patch
```

## What it registers

Two new steps in the `installers` job, for the paired suite WFI-041 added:

| Step | Runs on | Suite |
|---|---|---|
| `Test installer idempotency (pwsh; WFI-041)` | all three OSes | `tests/installer-idempotency.tests.ps1` |
| appended to `Test POSIX installer` | macOS, Ubuntu | `tests/installer-idempotency.tests.sh` |

The placement mirrors how `install.tests.{sh,ps1}` are already registered: the
pwsh twin as its own step across the full matrix, the sh twin inside the
existing `runner.os != 'Windows'` block so its log is teed alongside the other
POSIX installer logs and picked up by the existing failure-artifact upload.

Five inserted lines, none removed (`git apply --numstat` reports `5 0`).

## Why the suites are not fully covered until this lands

Both suites are already registered in `tests/run-all.{sh,ps1}`, so a developer
running the full local sweep executes them today, and so does CI's separate
`run-all` job. The `installers` job does not go through `run-all` — it lists
each suite explicitly — so until this patch is applied, the WFI-041 suites
never run in the job that owns the installer.

## What breaks if it is not applied

Nothing fails. That is the hazard: the suites pass locally and in `run-all`,
which reads as full coverage. A future change to `install.sh` or `install.ps1`
reviewed against the `installers` job alone would show green without ever
running the idempotency, upgrade-path, or rollback-phase cases.
