#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
evidence="$ROOT/specs/epic-195-a7-compatibility/verification/T-004"
work="$(mktemp -d "$evidence/.activation-mutations.XXXXXX")"
trap 'rm -rf "$work"' EXIT
passed=0
failed=0
# Reuse the historical driver definitions without executing its obsolete
# activation assumptions or creating any Git commit objects.
source <(awk '/^normalize_diagnostic\(\)/ { emit=1 } /^run_pair envelope-schema / { exit } emit { print }' "$evidence/mutation-proof.sh")
runtime="${1:?sh or ps1}"
case "$runtime" in sh|ps1) ;; *) exit 2 ;; esac

for mutation in paths heading status malformed; do
  target_root="$work/f3-$mutation"
  copy_surface "$target_root"
  corpus="$target_root/tests/fixtures/structural-fixture-corpus/f3-advisory.json"
  case "$mutation" in
    paths)
      update_json "$corpus" '.artifacts[0].path = "missing-required-output.md"'
      expected='FAIL: full artifact paths and exact count derive from its shipped output surface' ;;
    heading)
      update_json "$corpus" '(.artifacts[] | select(.path == "requirements.md").content) |= "# Mutated heading\n" + .'
      expected='FAIL: full requirements.md frontmatter and ordered headings match its shipped template' ;;
    status)
      update_json "$corpus" '(.artifacts[] | select(.path == "requirements.md").content) += "\nBuild Status: Mutated\n"'
      expected='FAIL: full requirements.md status field names match its shipped template' ;;
    malformed)
      update_json "$corpus" '(.artifacts[] | select(.path == "requirements.md").content) = "####### Broken\n"'
      expected='FAIL: full requirements.md canonicalizes without parse fallback' ;;
  esac
  run_one "f3-$mutation" "$runtime" "$expected" "$target_root"
done
target_root="$work/coherent-malformed"
copy_surface "$target_root"
mutate_case corpus-and-template-bad-heading "$target_root"
run_one corpus-and-template-bad-heading "$runtime" 'FAIL: full requirements.md canonicalizes without parse fallback' "$target_root"
printf 'ACTIVATION MUTATION SUMMARY [%s]: %d killed, %d survived\n' "$runtime" "$passed" "$failed"
[[ "$failed" -eq 0 ]]
