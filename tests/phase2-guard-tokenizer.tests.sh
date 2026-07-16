#!/usr/bin/env bash
# TEST-001 / TEST-002 staging-integrity companion. The candidate manifest holds
# hashes of staged source bytes keyed by the exact live target path; it never
# authorizes a direct agent write to the protected target. T-005 expands this
# shared manifest to the complete reviewed inventory, so this task asserts its
# own three required entries while validating every listed staged binding.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
stage="${T001_HUMAN_COPY_ROOT:-$root/specs/epic-136-phase2-gates/human-copy}"
manifest="$stage/MANIFEST.sha256"
pass=0
fail=0

ok() { echo "ok: $*"; pass=$((pass + 1)); }
bad() { echo "FAIL: $*"; fail=$((fail + 1)); }

expected_targets=(
  "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"
  "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js"
  "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1"
)

declare -A expected=()
declare -A seen=()
for target in "${expected_targets[@]}"; do expected["$target"]=1; done

if [[ ! -f "$manifest" || -L "$manifest" ]]; then
  bad "missing regular staged manifest: $manifest"
else
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ ! "$line" =~ ^([0-9a-f]{64})\ \ (.+)$ ]]; then
      bad "invalid manifest line: $line"
      continue
    fi
    digest="${BASH_REMATCH[1]}"
    target="${BASH_REMATCH[2]}"
    if [[ -n "${seen[$target]+x}" ]]; then
      bad "duplicate target: $target"
      continue
    fi
    source="$stage/$target"
    if [[ ! -f "$source" || -L "$source" ]]; then
      bad "missing regular staged candidate: $target"
      continue
    fi
    actual="$(sha256sum "$source" | awk '{print $1}')"
    if [[ "$actual" == "$digest" ]]; then
      ok "candidate hash binds exact target: $target"
      seen["$target"]=1
    else
      bad "candidate hash mismatch: $target"
    fi
  done < "$manifest"
fi

for target in "${expected_targets[@]}"; do
  [[ -n "${seen[$target]+x}" ]] || bad "manifest omits expected target: $target"
done

if command -v powershell.exe >/dev/null 2>&1; then
  if powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$root/tests/phase2-guard-tokenizer.tests.ps1")"; then
    ok "cross-runtime tokenizer corpus passed"
  else
    bad "cross-runtime tokenizer corpus failed"
  fi
else
  bad "powershell.exe is required for the cross-runtime corpus"
fi

echo "phase2-guard-tokenizer.tests.sh: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
