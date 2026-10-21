#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
workflow="$repo_root/.github/workflows/test.yml"
quality_gate="$repo_root/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"

python3 - "$workflow" "$quality_gate" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
quality = Path(sys.argv[2]).read_text(encoding="utf-8")

PLAN = "needs.ci-plan.outputs.run_test == 'true'"
STEPS = {
    # name: (exact `if`, shell, exact `run`)
    "[deterministic] Validate workflow state (PowerShell)": (
        PLAN,
        "pwsh",
        "./plugins/sdd-quality-loop/scripts/check-workflow-state.ps1",
    ),
    "[deterministic] Validate workflow state (POSIX)": (
        PLAN + " && runner.os != 'Windows'",
        "bash",
        "bash ./plugins/sdd-quality-loop/scripts/check-workflow-state.sh",
    ),
}
POWERSHELL, POSIX = STEPS
REPOSITORY = "[deterministic] Validate repository"
STEP_RE = re.compile(r"^(\s*)- name:\s*(.*?)\s*$")


def unquote(value):
    return value[1:-1] if len(value) > 1 and value[0] == value[-1] and value[0] in "'\"" else value


def parse_steps(workflow):
    """Return [(name, {key: value})] for every `- name:` step, in file order."""
    steps, current, indent = [], None, 0
    for line in workflow.splitlines():
        match = STEP_RE.match(line)
        if match:
            indent = len(match.group(1))
            current = (unquote(match.group(2)), {})
            steps.append(current)
        elif current is not None:
            key = re.match(r"^(\s*)(if|shell|run):\s*(.*?)\s*$", line)
            if key and len(key.group(1)) == indent + 2:
                current[1].setdefault(key.group(2), key.group(3))
    return steps


def validate(workflow):
    """Return the first violation as a string, or None when the workflow is valid."""
    steps = parse_steps(workflow)
    names = [name for name, _ in steps]
    for name, (want_if, want_shell, want_run) in STEPS.items():
        if names.count(name) != 1:
            return f"CI workflow-state integration needs exactly one step: {name}"
        fields = dict(steps)[name]
        if fields.get("if") != want_if:
            return f"{name}: condition must be exactly `{want_if}`, found `{fields.get('if')}`"
        if fields.get("shell") != want_shell:
            return f"{name}: shell must be {want_shell}"
        if fields.get("run") != want_run:
            return f"{name}: command must be exactly `{want_run}`"
    repository = names.index(REPOSITORY) if REPOSITORY in names else None
    if repository is None:
        return "CI workflow is missing repository validation"
    if not names.index(POWERSHELL) < names.index(POSIX) < repository:
        return "CI workflow-state checks must run (PowerShell, then POSIX) before repository validation"
    return None


violation = validate(text)
if violation:
    raise SystemExit(violation)


def with_condition(workflow, name, condition):
    lines, inside = workflow.splitlines(), False
    for index, line in enumerate(lines):
        match = STEP_RE.match(line)
        if match:
            inside = unquote(match.group(2)) == name
        elif inside and re.match(r"^\s*if:", line):
            lines[index] = line[: line.index("if:")] + "if: " + condition
    return "\n".join(lines) + "\n"


negative_controls = {
    "POSIX restricted to Windows only": (POSIX, PLAN + " && runner.os == 'Windows'"),
    "POSIX OS rule removed": (POSIX, PLAN),
    "POSIX OS rule widened by disjunction": (POSIX, PLAN + " && runner.os == 'Windows' || runner.os != 'Windows'"),
    "POSIX plan output renamed": (POSIX, "needs.ci-plan.outputs.run_posix_regression == 'true' && runner.os != 'Windows'"),
    "POSIX plan value flipped": (POSIX, "needs.ci-plan.outputs.run_test == 'false' && runner.os != 'Windows'"),
    "PowerShell restricted to Windows": (POWERSHELL, PLAN + " && runner.os == 'Windows'"),
    "PowerShell restricted to non-Windows": (POWERSHELL, PLAN + " && runner.os != 'Windows'"),
    "PowerShell plan output renamed": (POWERSHELL, "needs.ci-plan.outputs.run_posix_regression == 'true'"),
    "PowerShell plan value flipped": (POWERSHELL, "needs.ci-plan.outputs.run_test == 'false'"),
    "PowerShell condition removed": (POWERSHELL, "true"),
}
for label, (name, condition) in negative_controls.items():
    if validate(with_condition(text, name, condition)) is None:
        raise SystemExit(f"workflow-state predicate validator accepted invalid workflow: {label}")

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
