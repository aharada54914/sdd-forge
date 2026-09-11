#!/usr/bin/env bash
# Human-only application of reviewed candidates; no guard or cache changes.
set -euo pipefail
cd /Users/jrmag/sdd-forge
command -v pwsh >/dev/null
command -v python3 >/dev/null
command -v jq >/dev/null
printf '%s  %s\n' \
  a57f1cee0a7e15f4a6c9ad8b4a05d1cb1e23544e69fda238557570157ceb70ed reports/verification/rt004-producer-human-20260911.sh \
  176f4c6f84f9059c6b69797e757657ddcacaf60cbcdd6062a50db8ec611640a2 reports/verification/rt004-downstream-human-20260911.sh \
  8be54ef9f564268e1e5c99609f27db3ec359537c2f48c7b6b2822ab4561d5f3c tests/impl-review-adr-inputs.tests.sh | shasum -a 256 -c -
git apply --check --unidiff-zero \
  reports/verification/adr-precheck-generation-candidate-20260909.patch \
  reports/verification/adr-precheck-powershell-generation-candidate-20260909.patch \
  reports/verification/adr-persisted-bash-candidate-20260909.patch \
  reports/verification/adr-persisted-powershell-candidate-20260909.patch
batch_logs=$(mktemp -d /tmp/sdd-rt004-batch.XXXXXX) || exit 1
printf 'Batch logs: %s\n' "$batch_logs"
# Each helper checks exact original/patch hashes and backs up before applying.
bash reports/verification/rt004-producer-human-20260911.sh 2>&1 | tee "$batch_logs/producer.log"
bash reports/verification/rt004-downstream-human-20260911.sh 2>&1 | tee "$batch_logs/downstream.log"
test_status=0
bash tests/impl-review-adr-inputs.tests.sh >"$batch_logs/regression.log" 2>&1 || test_status=$?
tail -n 60 "$batch_logs/regression.log"
printf '\nRegression exit: %s; logs: %s\n' "$test_status" "$batch_logs"
printf 'Send output to Codex. No formal PASS, commit, push or merge. Backups are retained; no automatic rollback.\n'
exit "$test_status"
