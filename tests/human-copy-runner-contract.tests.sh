#!/usr/bin/env bash
# human-copy-runner-contract.tests.sh (epic-194-a6-lite-integration, T-001)
#
# POSIX twin of tests/human-copy-runner-contract.tests.ps1. The runner
# under test, specs/epic-194-a6-lite-integration/human-copy/
# apply-protected-files.ps1, is PowerShell-native only (Planned Files,
# tasks.md T-001 -- there is no .sh runner twin), so this suite drives the
# real PowerShell suite via `pwsh` rather than reimplementing the fixture
# logic a second time in bash: a duplicate bash-native reimplementation of
# the same four-point contract would exercise a DIFFERENT artifact than
# the one this feature actually ships, which is worse coverage, not
# better. This mirrors the existing repository convention of
# `tests/run-all.sh` itself invoking `tests/guard-r10-port.tests.ps1` via
# `pwsh` for a PowerShell-only surface.
#
# CI-resilience (Global Constraints): fails closed (not silently "SKIP")
# when pwsh is absent, since the runner this suite exists to test has no
# other execution path on this host; no possibly-empty array is expanded
# under `set -u`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SUITE="${REPO_ROOT}/tests/human-copy-runner-contract.tests.ps1"
RUNNER="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FATAL: pwsh is required to run human-copy-runner-contract.tests.sh (the runner under test is PowerShell-native only, tasks.md T-001 Planned Files)" >&2
  exit 2
fi

if [ ! -f "${RUNNER}" ]; then
  echo "FATAL: runner script not found: ${RUNNER}" >&2
  exit 2
fi

echo "==> pwsh ${SUITE}"
pwsh -NoProfile -ExecutionPolicy Bypass -File "${SUITE}"
