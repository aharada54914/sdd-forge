#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# Inspect executable steps, their host conditions and order in the required job.
node - "$repo_root" <<'JS'
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = process.argv[2];
const yaml = require(path.join(root, 'mcp/sdd-forge-mcp/node_modules/js-yaml'));
const workflow = yaml.load(fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8'));
const job = workflow.jobs['v2-guardrails'];
assert.deepEqual(job.strategy.matrix.os.toSorted(), ['macos-latest', 'ubuntu-latest', 'windows-latest']);
assert.ok(workflow.jobs['required-checks'].needs.includes('v2-guardrails'));
const steps = job.steps;
const indexOf = command => {
  const index = steps.findIndex(step => step.run?.split('\n').map(line => line.trim()).includes(command));
  assert.ok(index >= 0, 'missing executable step: ' + command);
  return index;
};
const ps = indexOf('./plugins/sdd-quality-loop/scripts/check-workflow-state.ps1');
const sh = indexOf('bash ./plugins/sdd-quality-loop/scripts/check-workflow-state.sh');
assert.equal(steps[ps].shell, 'pwsh');
assert.equal(steps[ps].if, undefined);
assert.equal(steps[sh].shell, 'bash');
assert.equal(steps[sh].if, "runner.os != 'Windows'");
assert.ok(!steps[ps]['continue-on-error'] && !steps[sh]['continue-on-error']);
for (const validation of ['bash scripts/check-sdd-structure.sh', './tests/structure-check-feature-mode.tests.ps1']) {
  assert.ok(Math.max(ps, sh) < indexOf(validation), 'global state checks precede structure validation');
}
JS

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/specs"
cat >"$fixture/specs/workflow-state-registry.json" <<'JSON'
{
  "schema_version": 1,
  "migration_baseline_commit": "0369c8c96de2eb3179868d1949d66644488f65aa",
  "entries": [
    {
      "feature": "missing-feature",
      "profile": "full"
    }
  ]
}
JSON

registry="$fixture/specs/workflow-state-registry.json"
set +e
bash_output="$(bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --registry "$registry" 2>&1)"
bash_status=$?
pwsh_output="$(pwsh -NoProfile -File "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" --registry "$registry" 2>&1)"
pwsh_status=$?
set -e

if [[ $bash_status -eq 0 || $pwsh_status -eq 0 ]]; then
  echo "CI workflow-state command accepted invalid persisted state" >&2
  exit 1
fi
if [[ "$bash_output" != *"registry-dangling"* || "$pwsh_output" != *"registry-dangling"* ]]; then
  echo "CI workflow-state commands did not fail through the canonical rule" >&2
  printf 'bash: %s\npwsh: %s\n' "$bash_output" "$pwsh_output" >&2
  exit 1
fi

python3 "$repo_root/tests/lib/core-lifecycle-checks.py" workflow
echo "Workflow-state CI integration tests passed."
