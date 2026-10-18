#!/usr/bin/env bash
set -uo pipefail
source /tmp/cloud-test-env.sh
export CLOUD_BICEP_BIN=/workspace/.tools/cloud/bicep/0.48.1/bicep
export CLOUD_CDK_ROOT=/workspace/.tools/cloud/cdk/2.1145.0
export CLOUD_NODE_BIN=/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin/node
export CLOUD_AZURE_UPSTREAM_ROOT="$PWD/specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream"
evidence=specs/cloud-orchestration/verification/T-010/dependency-expiry-fix
phase=${1:?phase required}
status=0
for group in verification execution routing contracts; do
  printf '%s COMMAND python3 -B %s/run-scoped.py tests/cloud-orchestration-%s.tests.py\n' "$(date -u +%FT%TZ)" "$evidence" "$group"
  python3 -B "$evidence/run-scoped.py" "tests/cloud-orchestration-$group.tests.py" > "$evidence/$phase-$group.log" 2>&1
  result=$?
  printf '%s EXIT %s %s\n' "$(date -u +%FT%TZ)" "$group" "$result"
  tail -6 "$evidence/$phase-$group.log"
  if [[ $result != 0 ]]; then status=1; fi
done
exit "$status"
