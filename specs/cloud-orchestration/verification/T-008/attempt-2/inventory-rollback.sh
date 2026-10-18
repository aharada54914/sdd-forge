#!/usr/bin/env bash
set -euo pipefail
root=$(pwd)
scratch=/tmp/T008-release-01a1505e
fixture=$scratch/rollback-inventory
export PATH=/workspace/.tools/sdd-forge-dev/bin:$PATH
git clone --quiet --shared --no-hardlinks "$root" "$fixture"
git -C "$fixture" checkout --quiet --detach 3017aca56ca3b96ad3cbbc8217f949bedba2d1a7
paths=(tests/agent-model-routing.tests.sh scripts/validate-a9-candidate.py tests/a9-dogfood.tests.py specs/epic-197-a9-dogfood/candidate/project-context.yaml)
for phase in candidate restored reapplied; do
  echo "PHASE=$phase"
  for path in "${paths[@]}"; do
    source=$root/$path
    if [[ $phase == restored ]]; then
      prefix=supplemental
      [[ $path == tests/host-review-preflight.tests.py ]] && prefix=host-supplement
      source=$scratch/$prefix/$path
    fi
    cp "$source" "$fixture/$path"
    sha256sum "$fixture/$path"
  done
  expected=0; [[ $phase == restored ]] && expected=1
  for suite in routing a9; do
    set +e
    (
      cd "$fixture"
      case $suite in
        routing) bash tests/agent-model-routing.tests.sh ;;
        a9) python3 -B tests/a9-dogfood.tests.py CandidatePackTests.test_candidate_has_complete_nonoverlapping_tracked_ownership CandidatePackTests.test_candidate_contract_rejects_inventory_classification_and_ownership_drift ;;
        host) python3 -B tests/host-review-preflight.tests.py ProtectedEntrypointTests.test_012d_unrelated_membership_unchanged ;;
      esac
    )
    actual=$?
    set -e
    echo "$suite exit=$actual expected=$expected"
    [[ $actual == "$expected" ]]
  done
done
