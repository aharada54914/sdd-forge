#!/bin/sh
# POSIX dispatcher for the unified SDD PreToolUse guard.
# It delegates decisions to the Python or PowerShell guard beside this script.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

emit="exit"
prev=""
for arg in "$@"; do
  if [ "$prev" = "--emit" ]; then emit="$arg"; fi
  case "$arg" in --emit=*) emit="${arg#--emit=}" ;; esac
  prev="$arg"
done
[ "$emit" = "copilot" ] || emit="exit"

deny_unavailable() {
  if [ "$emit" = "copilot" ]; then
    printf '%s' '{"permissionDecision":"deny","permissionDecisionReason":"sdd-hook-guard: generated invariants unavailable; guard denied."}'
    exit 0
  fi
  echo 'sdd-hook-guard: generated invariants unavailable; guard denied.' >&2
  exit 2
}

# The dispatcher imports no guard-decision constants. It validates only the
# generated schema/provenance module before selecting a native guard runtime.
if ! . "$dir/generated/guard-invariants.generated.sh"; then deny_unavailable; fi
if [ "${GUARD_INVARIANTS_SCHEMA_VERSION:-}" != "1" ] || \
   ! printf '%s' "${GUARD_INVARIANTS_SOURCE_SHA256:-}" | grep -Eq '^[0-9a-f]{64}$'; then
  deny_unavailable
fi

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

deny_unavailable
