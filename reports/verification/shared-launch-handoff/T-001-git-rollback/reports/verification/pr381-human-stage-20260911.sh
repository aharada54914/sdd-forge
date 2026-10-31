#!/usr/bin/env bash
# Human terminal only. Stage the inspected PR381 checkpoint; do not commit/push.
set -euo pipefail
cd /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
[[ "$(rtk proxy git rev-parse HEAD)" == 39dbaabc814d43a8cafc461c141e89e930bcaf89 ]] || { echo 'STOP: HEAD changed'; exit 1; }
[[ "$(rtk proxy git branch --show-current)" == codex/wip-pr381-20260911 ]] || { echo 'STOP: branch changed'; exit 1; }
rtk proxy git diff --cached --quiet || { echo 'STOP: existing staged changes'; exit 1; }
rtk proxy git diff --check
rtk proxy git add -- \
  .github/workflows/test.yml \
  specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml \
  specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 \
  tests/design-sync-standing-consent.tests.ps1 \
  tests/deterministic-lane-selfcheck.tests.sh \
  tests/required-checks-posix.tests.py \
  reports/verification/pr381-consent-registration-regression.ps1 \
  reports/verification/pr381-required-checks-posix-20260911.md \
  reports/verification/pr381-main-conflict-resolution-20260911.md \
  reports/verification/pr381-ci-human-batch-20260911.sh \
  reports/verification/pr381-current-lane-20260911.patch \
  reports/verification/pr381-required-checks-posix-20260911.patch \
  reports/verification/pr381-human-stage-20260911.sh
rtk proxy git diff --cached --check
rtk proxy git diff --cached --stat
printf '\nStaging only complete. Send output to Codex. No commit/push/merge performed.\n'
