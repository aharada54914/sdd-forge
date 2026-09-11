#!/usr/bin/env bash
# Human-operated application only. Do not invoke from an agent tool.
set -euo pipefail
cd /Users/jrmag/sdd-forge
source_file=plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
candidate=reports/verification/hook-host-contract-human-20260909.patch
command -v pwsh >/dev/null
shasum -a 256 -c <<'HASHES'
d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064  plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
2a322bf83a765a161382bf51b15dc290c62ce8bb0671ef4e41754c4f5547ab63  reports/verification/hook-host-contract-human-20260909.patch
HASHES
git apply --check --recount "$candidate"
backup_dir=$(mktemp -d /tmp/sdd-rt002-production.XXXXXX)
printf 'Backup and logs: %s\n' "$backup_dir"
cp "$source_file" "$backup_dir/check-hook-activation-handshake.py"
git apply --recount "$candidate"
git diff --check -- "$source_file"
shasum -a 256 "$source_file"
failed=0
sh tests/check-hook-activation-handshake.tests.sh 2>&1 | tee "$backup_dir/bash.log" || failed=1
pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1 2>&1 | tee "$backup_dir/pwsh.log" || failed=1
printf '\nFailed flag: %s. Send output to Codex. No commit/push/merge performed.\n' "$failed"
printf 'Fixture tests do not prove live host activation.\n'
exit "$failed"
