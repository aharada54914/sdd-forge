#!/usr/bin/env bash
# Human-only application. Do not execute through an agent or bypass a hook.
set -euo pipefail
cd /Users/jrmag/sdd-forge
patch=reports/verification/adr-contract-docs-candidate-20260908.patch
check_hash() {
  local actual
  actual=$(shasum -a 256 "$2")
  actual=${actual%% *}
  if [ "$actual" != "$1" ]; then
    printf 'STOP: changed input: %s\n' "$2" >&2
    exit 1
  fi
}
check_hash ba68324881ad654f6bb0a08a8b18806cb670a3cf22ab240a2d5bc2ab3ef741b1 "$patch"
targets=(
  plugins/sdd-review-loop/templates/impl-review-contract.template.json
  plugins/sdd-review-loop/references/review-context-boundary.md
  plugins/sdd-review-loop/agents/impl-reviewer-a.md
  plugins/sdd-review-loop/agents/impl-reviewer-b.md
  plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md
)
hashes=(
  30266f405385bb8cebb41d9ff860b0d51268cb88461fe90354918f00c551430b
  f52f1dee26d9034dd07bfffb0dd310e7731b8f20a0bd843daf8feed938936a8e
  a516e1f23e53814a7e7d28cbea76986d477c505d85ada161dbf269c8a988f377
  1fc17ed207e03eba96f833e904bc7e9c0dff89d8ef4216d07b751466fa0c061c
  c211628ffadad5d9bc624e07f9ed5265a7416495316e2b76a7a83b1b9b806653
)
for i in "${!targets[@]}"; do
  check_hash "${hashes[$i]}" "${targets[$i]}"
done
git apply --check --unidiff-zero "$patch"
backup=$(mktemp -d "${TMPDIR:-/tmp}/sdd-rt004-contract.XXXXXX")
test -n "$backup" && test -d "$backup"
for file in "${targets[@]}"; do
  mkdir -p "$backup/$(dirname "$file")"
  cp -p "$file" "$backup/$file"
done
printf 'Backup: %s\n' "$backup"
git apply --unidiff-zero "$patch"
git diff --check -- "${targets[@]}"
git diff --stat -- "${targets[@]}"
shasum -a 256 "${targets[@]}"
printf '\nApplied five contract documents only. Send output to Codex.\n'
printf 'Tests, formal review, CI and merge remain pending. No commit/push/merge performed.\n'
