#!/usr/bin/env bash
# Human-only application. The agent may run --check, never --apply.
set -euo pipefail

mode="${1:---check}"
case "$mode" in --check|--apply) ;; *) printf 'Use --check or --apply\n' >&2; exit 2 ;; esac
repo=/Users/jrmag/sdd-forge
target=plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
patch=reports/verification/hook-diagnostic-human-20260909.patch
cd "$repo"
for dependency in rtk git shasum awk mktemp cp bash pwsh; do
  command -v "$dependency" >/dev/null || { printf 'Missing dependency: %s\n' "$dependency" >&2; exit 1; }
done
check_hash() {
  local actual
  actual="$(rtk proxy shasum -a 256 -- "$1" | rtk proxy awk '{print $1}')"
  [ "$actual" = "$2" ] || { printf 'Hash mismatch; nothing further applied: %s\n' "$1" >&2; exit 1; }
}
check_hash "$target" d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064
check_hash "$patch" df5e309755439ffffed54cd314b88e78ebd7f4db93f2ea8169c74a9adc772f88
check_hash tests/check-hook-activation-handshake.tests.sh ec94cc6577e4aed8b59e469b938e6c8dfb457ef35f9574448efcab258ccb6565
check_hash tests/check-hook-activation-handshake.tests.ps1 c243ffeda8fb91843c97b6df03deac9e0f4569322ecbc9d38b02a2fb87b82aaa
rtk proxy git apply --check "$patch"
if [ "$mode" = --check ]; then
  printf 'Preflight only: hashes and patch applicability verified; nothing applied.\n'
  exit 0
fi

backup="$(rtk proxy mktemp -d /tmp/sdd-hook-diagnostic.XXXXXX)" || exit 1
[ -n "$backup" ] && [ -d "$backup" ] || exit 1
printf 'Backup and logs: %s\n' "$backup"
rtk proxy cp -p -- "$target" "$backup/check-hook-activation-handshake.py.before"
check_hash "$backup/check-hook-activation-handshake.py.before" d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064
# Recheck after backup; never force application over a changed source.
check_hash "$target" d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064
rtk proxy git apply "$patch"
failed=0
if rtk proxy git diff --check -- "$target" tests/check-hook-activation-handshake.tests.sh tests/check-hook-activation-handshake.tests.ps1; then :; else failed=1; fi
if rtk proxy bash tests/check-hook-activation-handshake.tests.sh >"$backup/bash.log" 2>&1; then bash_exit=0; else bash_exit=$?; failed=1; fi
if rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1 >"$backup/pwsh.log" 2>&1; then pwsh_exit=0; else pwsh_exit=$?; failed=1; fi
rtk proxy cat "$backup/bash.log" "$backup/pwsh.log"
printf 'Bash exit: %s; PowerShell exit: %s\n' "$bash_exit" "$pwsh_exit"
rtk proxy git diff --stat -- "$target" tests/check-hook-activation-handshake.tests.sh tests/check-hook-activation-handshake.tests.ps1
rtk proxy shasum -a 256 -- "$target" tests/check-hook-activation-handshake.tests.sh tests/check-hook-activation-handshake.tests.ps1
printf 'Send this output to Codex. No commit/push/merge or installed-cache change was performed.\n'
printf 'This diagnostic-only patch does not unblock the handshake. Backup and logs: %s\n' "$backup"
exit "$failed"
