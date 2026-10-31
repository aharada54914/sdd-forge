#!/usr/bin/env bash
# Candidate only. Default is read-only --check. A human must explicitly choose
# --human-apply <identifier>; agents must not invoke that branch or use this
# script to bypass a protected-operation refusal. Adoption is not review PASS.
set -euo pipefail

mode="${1:---check}"
case "$mode" in
  --check) [[ $# -le 1 ]] || exit 2 ;;
  --human-apply) [[ $# -eq 2 && -n "$2" ]] || { printf 'Human identifier required\n' >&2; exit 2; } ;;
  *) printf 'Usage: bash %s [--check | --human-apply <identifier>]\n' "$0" >&2; exit 2 ;;
esac
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
cd "$repo_root"
patches=(
  'specs/epic-195-a7-compatibility/verification/T-010/contract-amendment-candidate-20261001.patch'
  'specs/epic-195-a7-compatibility/verification/T-010/security-contract-supplement-20261004.patch'
  'specs/epic-195-a7-compatibility/verification/T-010/file-contains-literal-candidate-20261004.patch'
)
patch_hashes=(
  'ef99dc8a5e0da14164c07da63350dbdd84b61ae7666ed1e005d5747125403cf5'
  'dc27734d6d5663098c6a5221b309b0ecf8e349075d5f641b0698c14de0301e1e'
  '1b6887a9eea1305042546a683ba1f8e4f34063e592b89c98468cfdccd3a40ca1'
)
targets=(
  'specs/epic-195-a7-compatibility/requirements.md'
  'specs/epic-195-a7-compatibility/design.md'
  'specs/epic-195-a7-compatibility/acceptance-tests.md'
  'specs/epic-195-a7-compatibility/tasks.md'
  'specs/epic-195-a7-compatibility/traceability.md'
  'specs/epic-195-a7-compatibility/security-spec.md'
  'tests/lib/skip-allowlist-evaluator.ps1'
  'tests/skip-allowlist-manifest.tests.sh'
  'tests/skip-allowlist-manifest.tests.ps1'
)
preimages=(
  '7af43a41f52d7fee4144ea603eba10cd5fe9ccf6468bcfe778afd212546f5a79'
  'ef0a43714f623e92ba7b5e2a583a53bc7dbcd4b8e2481b0df2aa96cef2fa2c96'
  'f77158ea4ad4263910439cd37ca0ed5296fc3f4e29e1d4e8c963d659ed799815'
  'fee9e7323ea2d3da9b4e30aedda5d7a80c80afa83775d41db360163fe94ce321'
  '676d2e3de2c0e311b1aa796dd4a7b21950e5ac47a030dd0fba3611617805cd31'
  '4b31d724cd326ee89b87de867e0f857cf2b7ca69d794956ebb7ce4edc6ff8d31'
  '6daae2e88a65ca7fd1b9f215f93e869215d21ee82380101cc69b5245229a1197'
  'f8a2dada6cb6db3705bef501166ff1ae9ad4d7397edf650c2db9402c17620371'
  '66a2ffe8bb7406e5b34513f8c81aacdf2bc217cdd78108c8966ec11b94d32c4c'
)
sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
require_hash() {
  local path="$1" expected="$2" actual
  [[ -f "$path" && ! -L "$path" ]] || { printf 'Missing or symlinked input: %s\n' "$path" >&2; exit 1; }
  actual="$(sha256_file "$path")"
  [[ "$actual" == "$expected" ]] || { printf 'Hash mismatch: %s\nexpected %s\nactual %s\n' "$path" "$expected" "$actual" >&2; exit 1; }
}
[[ ${#patches[@]} -eq ${#patch_hashes[@]} && ${#targets[@]} -eq ${#preimages[@]} ]] || exit 1
for i in "${!patches[@]}"; do require_hash "${patches[$i]}" "${patch_hashes[$i]}"; done
actual_targets="$(awk '/^diff --git / { src=$3; dst=$4; sub(/^a\//, "", src); sub(/^b\//, "", dst); if (src != dst) exit 2; print dst }' "${patches[@]}")"
expected_targets="$(printf '%s\n' "${targets[@]}")"
[[ "$actual_targets" == "$expected_targets" ]] || { printf 'Patch target set/order mismatch\n' >&2; exit 1; }
[[ -z "$(printf '%s\n' "${targets[@]}" | LC_ALL=C sort | uniq -d)" ]] || { printf 'Duplicate target\n' >&2; exit 1; }
for i in "${!targets[@]}"; do require_hash "${targets[$i]}" "${preimages[$i]}"; done
git apply --unidiff-zero --check "${patches[@]}"
printf 'CHECK OK: 3 hash-pinned patches; 9 unique preimages; combined applicability.\n'
printf 'Backup/readback targets:\n%s\n' "$expected_targets"
if [[ "$mode" == --check ]]; then
  printf 'Read-only check complete. No backup, target write, reservation or gate transition.\n'
  exit 0
fi

# Human adoption only. All nine targets are backed up before the single apply.
# No status reset, review reservation, test run, commit or push is performed.
backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-a7-t010-apply-20261004.XXXXXX")"
trap 'status=$?; printf "Exit: %s\nBackup: %s\n" "$status" "$backup"; if (( status != 0 )); then printf "Inspect targets against backup; no automatic restore was attempted.\n" >&2; fi' EXIT
for target in "${targets[@]}"; do
  mkdir -p "$backup/$(dirname "$target")"
  cp -p "$target" "$backup/$target"
done
# Recheck after backup immediately before any target write.
for i in "${!patches[@]}"; do require_hash "${patches[$i]}" "${patch_hashes[$i]}"; done
for i in "${!targets[@]}"; do
  require_hash "${targets[$i]}" "${preimages[$i]}"
  require_hash "$backup/${targets[$i]}" "${preimages[$i]}"
done
git apply --unidiff-zero --check "${patches[@]}"
printf 'Human adoption identifier: %s\n' "$2"
git apply --unidiff-zero "${patches[@]}"
for target in "${targets[@]}"; do
  [[ -f "$target" && ! -L "$target" ]] || exit 1
  if cmp -s "$backup/$target" "$target"; then printf 'Unchanged target: %s\n' "$target" >&2; exit 1; fi
  printf '%s  %s\n' "$(sha256_file "$target")" "$target"
done
require_hash 'specs/epic-195-a7-compatibility/security-spec.md' '6323026f1b1b867364cab929b056f55c3ef06e08f0609fe4de3c403362db25e5'
git apply --unidiff-zero --reverse --check "${patches[@]}"
printf 'Adoption readback passed. Fresh spec/design/task review, tests, current-head CI and quality gate remain pending. Historical PASS does not bind these bytes.\n'
