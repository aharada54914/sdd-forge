#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
shell_output="$(cd "$ROOT" && bash tests/workflow-state-registry.tests.sh)"
ps_output="$(cd "$ROOT" && pwsh -NoProfile -File tests/workflow-state-registry.tests.ps1)"
[[ "$shell_output" == ok:* ]] || { printf 'not ok: Shell registry suite failed\n' >&2; exit 1; }
[[ "$ps_output" == ok:* ]] || { printf 'not ok: PowerShell registry suite failed\n' >&2; exit 1; }

for fixture in duplicate dangling unregistered symlink; do
  shell_diagnostic="$(bash "$ROOT/tests/workflow-state-registry.tests.sh" --coverage-fixture "$fixture" 2>&1 || true)"
  ps_diagnostic="$(pwsh -NoProfile -File "$ROOT/tests/workflow-state-registry.tests.ps1" -CoverageFixture "$fixture" 2>&1 || true)"
  shell_rule="$(printf '%s\n' "$shell_diagnostic" | rg -o 'registry-(duplicate|dangling-entry|unregistered-directory|path-escape)' | head -1)"
  ps_rule="$(printf '%s\n' "$ps_diagnostic" | rg -o 'registry-(duplicate|dangling-entry|unregistered-directory|path-escape)' | head -1)"
  [[ -n "$shell_rule" && "$shell_rule" == "$ps_rule" ]] ||
    { printf 'not ok: rule-ID parity mismatch for %s\n' "$fixture" >&2; exit 1; }
done

printf 'ok: workflow-state registry validation has per-fixture Shell/PowerShell parity\n'
