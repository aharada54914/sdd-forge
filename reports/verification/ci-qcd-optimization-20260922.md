# Cross-platform CI QCD optimization candidate (2026-09-22; superseded patch noted 2026-09-23)

## Scope

The original candidate kept one repository and all existing Windows, macOS, and Ubuntu
platform-sensitive jobs. The workflow in this worktree already contains the
publisher-suite parallel step, so the old patch is stale. The current candidate
is limited to removing macOS from the platform-neutral `loops-routing` matrix:

1. `loops-routing` runs on Windows and Ubuntu. Those suites are explicitly
   file/manifest-only and do not use OS-specific behavior, git history, or a
   CLI. Windows covers native PowerShell plus Git Bash; Ubuntu covers native
   Bash plus PowerShell. macOS remains covered by `test`, `version-gates`,
   installer, MCP, and hook-enforcement jobs.
2. `apply-human-copy` Bash and PowerShell suites are already run concurrently
   by the current workflow at lines 646-666; this candidate does not alter them.

No assertion, fixture, required job, or platform-specific test is removed.
The `loops-routing` job ID and check name remain unchanged, and the required
checks job continues to depend on it. The three-leg matrix becomes two legs,
reducing the lane's 22 Bash/PowerShell executions from 66 to 44 per workflow run.

## Platform evidence

| Workflow surface | Current evidence | Why it stays / changes |
|---|---|---|
| `loops-routing` | `.github/workflows/test.yml:390-402` describes file/manifest suites and current 3-OS matrix | Remove macOS leg only; Windows covers native PowerShell and Git Bash, Ubuntu covers native Bash and PowerShell |
| Main `test` | `.github/workflows/test.yml:64-69` runs Windows, macOS, Ubuntu | Keep: broad cross-platform behavior and git-history-dependent suites |
| `installers` | `.github/workflows/test.yml:292-317` has explicit Windows lanes plus macOS/Ubuntu lanes | Keep: real filesystem install and platform-specific installer paths |
| `version-gates` | `.github/workflows/test.yml:518-520` labels POSIX Bash/PowerShell twins; corresponding Windows jobs at 1062-1150 | Keep: OS/runtime matrix coverage |
| Publisher / hook checks | `.github/workflows/test.yml:646-673` has macOS/Linux condition and POSIX suites | Keep: POSIX-specific behavior |
| MCP and CLI hook enforcement | jobs at `.github/workflows/test.yml:1155-1347` | Keep: specialized required lanes |
| Required-check aggregation | `.github/workflows/test.yml:1348-1351` includes `loops-routing` in `needs` | Preserve job ID/name and dependency |

Coverage check: `tests/ci-qcd-candidate.tests.sh` asserts the proposed two-OS
matrix, unchanged `loops-routing` identity, presence of the other OS-specific
jobs, and an elapsed-time control for the parallel-execution model.

## Evidence

- Original, stale candidate patch: `reports/verification/ci-qcd-optimization-20260922.patch` (includes publisher parallelization already present in this workflow)
- Current candidate patch: `reports/verification/ci-loops-routing-macos-removal-20260923.patch`
- Original patch SHA-256: `36d8ff073ef8985196cb8645dba72ce3d5eb8442581aadc40d05cf087309f969`
- Current candidate patch SHA-256: `6c2799cb720a07baa2c4c9b9559e25ee638748009db68bac2f5294e9e02e7cc4`
- Candidate elapsed-time control: PASS (local run: 268 ms for two concurrent 250 ms tasks; serial baseline 500 ms)
- Candidate timing control: PASS; the post-edit assertions have not yet been rerun.
- Current workflow job identity/OS evidence inspected; required-check dependency remains `loops-routing`.
- Automatic pre-tool gate rejected the `git apply --check` / candidate-test invocation because its command matched the deterministic-gate protection for critical test files. Patch applicability and full test execution remain unverified.

Full GitHub Actions timing and live runner coverage remain pending. The
workflow is protected and remains unchanged; the candidate is a patch artifact.

## Best-practice basis

- GitHub Actions supports matrix jobs and explicit concurrency controls; keep
  only matrix dimensions that add coverage:
  <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax>
- Reuse dependency caches only when the dependency manifest is present and
  keyed to that manifest:
  <https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching>
- Reusable workflows centralize cross-platform policy while leaving
  OS-specific jobs explicit:
  <https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows>
- `actions/setup-python` documents dependency-file keyed caching and pinned
  interpreter versions:
  <https://github.com/actions/setup-python/blob/main/README.md>

## Stop condition

Further reduction would require removing a platform-specific lane or merging
tests with different fixtures, which would reduce confidence. After the
candidate is human-applied and one full CI run confirms timing and coverage,
optimization should stop unless measured regressions identify a new bottleneck.
