#!/usr/bin/env bash
set -u
export PATH="/workspace/.tools/sdd-forge-dev/bin:$PATH"
export CLOUD_BICEP_BIN=/workspace/.tools/cloud/bicep/0.48.1/bicep
export CLOUD_CDK_ROOT=/workspace/.tools/cloud/cdk/2.1145.0
export CLOUD_NODE_BIN=/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin/node
export CLOUD_AZURE_UPSTREAM_ROOT="$PWD/specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream"
evidence=specs/cloud-orchestration/verification/T-010/attempt-2/evidence
runner="$evidence/run-scoped.py"
for group in verification execution routing contracts; do
  printf '%s COMMAND python3 -B %s tests/cloud-orchestration-%s.tests.py\n' "$(date -u +%FT%TZ)" "$runner" "$group"
  python3 -B "$runner" "tests/cloud-orchestration-$group.tests.py" > "$evidence/scoped-final-$group.log" 2>&1
  result=$?
  printf '%s EXIT %s %s\n' "$(date -u +%FT%TZ)" "$group" "$result"
  tail -6 "$evidence/scoped-final-$group.log"
done
