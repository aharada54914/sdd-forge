#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
evidence="$ROOT/specs/epic-195-a7-compatibility/verification/T-004"
work="$(mktemp -d "$evidence/.status-field-mutations.XXXXXX")"
trap 'rm -rf "$work"' EXIT
passed=0
failed=0
source <(awk '/^normalize_diagnostic\(\)/ { emit=1 } /^run_pair envelope-schema / { exit } emit { print }' "$evidence/mutation-proof.sh")
runtime="${1:?sh or ps1}"
case "$runtime" in sh|ps1) ;; *) exit 2 ;; esac

for field in Status Approval; do
    target_root="$work/lite-$field"
    copy_surface "$target_root"
    corpus="$target_root/tests/fixtures/structural-fixture-corpus/f2-lite.json"
    # Historical F2 lacks both fields. Repair only the disposable control, never
    # rewrite the recorded source or claim these values were model-generated.
    update_json "$corpus" \
      '(.artifacts[] | select(.path == "tasks.md").content) += "\nStatus: Planned\nApproval: Draft\n"'
    if [[ "$field" == Status ]]; then
        if [[ "$runtime" == sh ]]; then
            (cd "$target_root" && bash tests/structural-compatibility.tests.sh) > "$work/positive.log" 2>&1
        else
            (cd "$target_root" && pwsh -NoProfile -File tests/structural-compatibility.tests.ps1) > "$work/positive.log" 2>&1
        fi
        tail -n 1 "$work/positive.log"
        printf 'POSITIVE-CONTROL: both bare fields accepted [%s]\n' "$runtime"
    fi
    before="$(shasum -a 256 "$corpus" | awk '{print $1}')"
    update_json "$corpus" --arg field "$field" \
      '(.artifacts[] | select(.path == "tasks.md").content) |= (split("\n") | map(select(startswith($field + ":") | not)) | join("\n"))'
    require_source_change "$before" "$corpus"
    run_one "lite-missing-$field" "$runtime" \
      "FAIL: lite tasks.md status field names match its shipped template" "$target_root"
done
printf 'STATUS FIELD MUTATION SUMMARY [%s]: %d killed, %d survived\n' "$runtime" "$passed" "$failed"
[[ "$failed" -eq 0 ]]
