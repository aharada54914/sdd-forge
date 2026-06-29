#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
workflow="$repo_root/.github/workflows/test.yml"
quality_gate="$repo_root/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"

python3 - "$workflow" "$quality_gate" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
quality = Path(sys.argv[2]).read_text(encoding="utf-8")

required = (
    "Validate workflow state (PowerShell)",
    "./plugins/sdd-quality-loop/scripts/check-workflow-state.ps1",
    "Validate workflow state (POSIX)",
    "bash ./plugins/sdd-quality-loop/scripts/check-workflow-state.sh",
)
missing = [marker for marker in required if marker not in text]
if missing:
    raise SystemExit("CI workflow-state integration is missing: " + ", ".join(missing))

windows = text.index("Validate workflow state (PowerShell)")
posix = text.index("Validate workflow state (POSIX)")
repository = text.index("Validate repository")
if windows > repository or posix > repository:
    raise SystemExit("CI workflow-state checks must run before repository validation")

power_shell_block = text[windows:posix]
if "if: runner.os" in power_shell_block:
    raise SystemExit("PowerShell workflow-state validation must run on every matrix host")
if "if: runner.os != 'Windows'" not in text[posix:repository]:
    raise SystemExit("POSIX workflow-state validation must run on non-Windows hosts")

workflow_gate = quality.index("`check-workflow-state`")
task_gate = quality.index("`check-task-state`")
if workflow_gate > task_gate:
    raise SystemExit("quality-gate must run global workflow-state validation before task-state checks")
if "without `--feature`" not in quality[workflow_gate:task_gate]:
    raise SystemExit("quality-gate workflow-state validation must be repository-global")
PY

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

echo "Workflow-state CI integration tests passed."
