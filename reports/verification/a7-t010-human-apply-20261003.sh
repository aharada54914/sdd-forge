#!/usr/bin/env bash
# Human-only, single-run application of the two T-010 candidates.
# Human must choose to run this; agents must not use it to route around a
# protected-operation refusal.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
cd "$repo_root"

spec_patch='specs/epic-195-a7-compatibility/verification/T-010/contract-amendment-candidate-20261001.patch'
code_patch='specs/epic-195-a7-compatibility/verification/T-010/file-contains-literal-candidate-20261003.patch'
targets=(
  'specs/epic-195-a7-compatibility/requirements.md'
  'specs/epic-195-a7-compatibility/design.md'
  'specs/epic-195-a7-compatibility/acceptance-tests.md'
  'specs/epic-195-a7-compatibility/tasks.md'
  'specs/epic-195-a7-compatibility/traceability.md'
  'tests/lib/skip-allowlist-evaluator.ps1'
  'tests/skip-allowlist-manifest.tests.sh'
  'tests/skip-allowlist-manifest.tests.ps1'
)

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
require_hash() {
  local path="$1" expected="$2" actual
  [[ -f "$path" && ! -L "$path" ]] || { printf 'Missing or symlinked preimage: %s\n' "$path" >&2; exit 1; }
  actual="$(sha256_file "$path")"
  [[ "$actual" == "$expected" ]] || { printf 'Preimage hash mismatch: %s\nexpected %s\nactual   %s\n' "$path" "$expected" "$actual" >&2; exit 1; }
}

# Reject an altered candidate, any duplicate/unexpected target, or reordered
# patch input before creating a backup or writing a target.
require_hash "$spec_patch" 'ef99dc8a5e0da14164c07da63350dbdd84b61ae7666ed1e005d5747125403cf5'
require_hash "$code_patch" '912cd0a56e0cda524620f9415f1f6676f5248d763322971086b1873ca66b0171'
actual_targets="$(awk '/^diff --git / { src=$3; dst=$4; sub(/^a\//, "", src); sub(/^b\//, "", dst); if (src != dst) exit 2; print dst }' "$spec_patch" "$code_patch")"
expected_targets="$(printf '%s\n' "${targets[@]}")"
[[ "$actual_targets" == "$expected_targets" ]] || { printf 'Candidate target set, order, or uniqueness mismatch\n' >&2; exit 1; }
for duplicate in $(printf '%s\n' "${targets[@]}" | LC_ALL=C sort | uniq -d); do
  printf 'Duplicate target: %s\n' "$duplicate" >&2
  exit 1
done

require_hash "${targets[0]}" '7af43a41f52d7fee4144ea603eba10cd5fe9ccf6468bcfe778afd212546f5a79'
require_hash "${targets[1]}" 'ef0a43714f623e92ba7b5e2a583a53bc7dbcd4b8e2481b0df2aa96cef2fa2c96'
require_hash "${targets[2]}" 'f77158ea4ad4263910439cd37ca0ed5296fc3f4e29e1d4e8c963d659ed799815'
require_hash "${targets[3]}" 'fee9e7323ea2d3da9b4e30aedda5d7a80c80afa83775d41db360163fe94ce321'
require_hash "${targets[4]}" '676d2e3de2c0e311b1aa796dd4a7b21950e5ac47a030dd0fba3611617805cd31'
require_hash "${targets[5]}" '6daae2e88a65ca7fd1b9f215f93e869215d21ee82380101cc69b5245229a1197'
require_hash "${targets[6]}" 'f8a2dada6cb6db3705bef501166ff1ae9ad4d7397edf650c2db9402c17620371'
require_hash "${targets[7]}" '66a2ffe8bb7406e5b34513f8c81aacdf2bc217cdd78108c8966ec11b94d32c4c'

patch --dry-run -F 0 -p1 -i "$spec_patch"
patch --dry-run -F 0 -p1 -i "$code_patch"

backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-a7-t010-apply.XXXXXX")"
trap 'status=$?; printf "Exit: %s\nBackup: %s\n" "$status" "$backup"; if (( status != 0 )); then printf "Application incomplete; inspect targets against the backup. No automatic restore was attempted.\n" >&2; fi' EXIT
for target in "${targets[@]}"; do
  mkdir -p "$backup/$(dirname "$target")"
  cp -p "$target" "$backup/$target"
done
printf 'Preimages backed up. Applying frozen-spec amendment first, then evaluator/test patch.\n'
patch -t -F 0 -p1 -i "$spec_patch"
patch -t -F 0 -p1 -i "$code_patch"

# Read back all outputs: every target changed and each patch can be reversed
# without changing files. This is not test/CI/review/quality-gate evidence.
for target in "${targets[@]}"; do
  if cmp -s "$backup/$target" "$target"; then
    printf 'Target did not change: %s\n' "$target" >&2
    exit 1
  fi
  printf '%s  %s\n' "$(sha256_file "$target")" "$target"
done
patch --dry-run -R -F 0 -p1 -i "$code_patch"
patch --dry-run -R -F 0 -p1 -i "$spec_patch"
printf 'Patch readback passed. Tests, CI, independent review and quality gate remain pending.\n'
