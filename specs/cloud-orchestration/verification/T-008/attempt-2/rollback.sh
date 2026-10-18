#!/usr/bin/env bash
set -euo pipefail
root=$(pwd)
scratch=/tmp/T008-release-01a1505e
fixture=$scratch/rollback
base=3017aca56ca3b96ad3cbbc8217f949bedba2d1a7
git clone --quiet --shared --no-hardlinks "$root" "$fixture"
git -C "$fixture" checkout --quiet --detach "$base"
cp "$root/docs/review-tickets/RT-20261018-900.yml" "$fixture/docs/review-tickets/"
ln -s "$root/mcp/sdd-forge-mcp/node_modules" "$fixture/mcp/sdd-forge-mcp/node_modules"
cp -a "$root/mcp/sdd-forge-mcp/dist-test" "$fixture/mcp/sdd-forge-mcp/"
checker=$root/specs/cloud-orchestration/verification/T-008/attempt-2/check-repair.mjs
mapfile -t paths < <(node -e 'const fs=require("fs"); console.log(Object.keys(JSON.parse(fs.readFileSync(process.argv[1]))).join("\n"))' "$root/specs/cloud-orchestration/verification/T-008/attempt-2/before-hashes.json")
for phase in candidate restored reapplied; do
  echo "PHASE=$phase base=$base"
  for path in "${paths[@]}"; do
    source=$root/$path
    if [[ $phase == restored ]]; then source=$scratch/initial/$path; fi
    cp "$source" "$fixture/$path"
    sha256sum "$fixture/$path"
  done
  expected=0; [[ $phase == restored ]] && expected=1
  set +e
  node "$checker" "$fixture" "$scratch/initial"
  actual=$?
  set -e
  echo "scoped acceptance exit=$actual expected=$expected"
  [[ $actual == "$expected" ]]
  set +e
  (cd "$fixture/mcp/sdd-forge-mcp" && node --test dist-test/tests/parsers-state/review-ticket.test.js)
  actual=$?
  set -e
  echo "existing MCP tickets exit=$actual expected=$expected"
  [[ $actual == "$expected" ]]
done
