#!/bin/sh
# POSIX dispatcher for the unified SDD PreToolUse guard.
# Reads the hook payload from stdin once, then prefers python3 (payload passed
# via the PAYLOAD env var), falling back to PowerShell. If no runtime is
# available it fails closed and denies.
#
# Runs three checks: kill switch, approval guard (bypassed by valid SDD_SUDO flag),
# and agent-role guard. Kill switch and agent-role guard are never bypassed.
#
# Usage: sdd-hook-guard.sh --emit exit|copilot   (default: exit)

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# Capture --emit so we can choose the correct fail-open behavior.
emit="exit"
prev=""
for arg in "$@"; do
  if [ "$prev" = "--emit" ]; then emit="$arg"; fi
  case "$arg" in --emit=*) emit="${arg#--emit=}" ;; esac
  prev="$arg"
done
[ "$emit" = "copilot" ] || emit="exit"

payload="$(cat)"

if command -v python3 >/dev/null 2>&1; then
  PAYLOAD="$payload" python3 "$dir/sdd-hook-guard.py" "$@"
  exit $?
fi

for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    if [ "$emit" = "copilot" ]; then
      printf '%s' "$payload" | "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/sdd-hook-guard.ps1" -Emit copilot
    else
      printf '%s' "$payload" | "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/sdd-hook-guard.ps1" -Emit exit
    fi
    exit $?
  fi
done

# No runtime available: fail closed.
if [ "$emit" = "copilot" ]; then
  printf '%s' '{"permissionDecision":"deny","permissionDecisionReason":"sdd-hook-guard: python3 and PowerShell unavailable; guard denied."}'
  exit 0
fi
echo "sdd-hook-guard: python3 and PowerShell unavailable; guard denied." >&2
exit 2
