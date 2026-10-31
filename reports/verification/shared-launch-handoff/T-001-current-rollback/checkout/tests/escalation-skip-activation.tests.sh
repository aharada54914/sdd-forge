#!/usr/bin/env bash
# Drive the real escalation suites against clean, activated, and invalid evidence.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/escalation-activation.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --no-hardlinks "$root" "$tmp/repo"
git -C "$tmp/repo" update-ref refs/remotes/origin/main "$(git -C "$root" rev-parse origin/main)"
for file in tests/loop-escalation.tests.sh tests/loop-escalation.tests.ps1 tests/lib/skip-allowlist-evaluator.sh tests/lib/skip-allowlist-evaluator.ps1; do
  cp "$root/$file" "$tmp/repo/$file"
done
manifest=tests/fixtures/skip-allowlist-manifest.json
passed=0
for runtime in bash pwsh; do
  if ! command -v "$runtime" >/dev/null 2>&1; then
    printf 'SKIP: %s unavailable for escalation activation regression\n' "$runtime"
    continue
  fi
  for mutation in clean activated invalid; do
    case "$mutation" in
      clean) cp "$root/$manifest" "$tmp/repo/$manifest" ;;
      activated)
        jq '(map(select(.assertion_id=="AC-007"))[0]) as $active |
          map(if .assertion_id=="AC-004" or .assertion_id=="AC-021" then
            .dependencies=$active.dependencies | .activation_condition=$active.activation_condition
          else . end)' "$root/$manifest" > "$tmp/repo/$manifest" ;;
      invalid)
        jq 'map(if .assertion_id=="AC-004" then
          .dependencies[0].merged_commit="0000000000000000000000000000000000000000"
          else . end)' "$root/$manifest" > "$tmp/repo/$manifest" ;;
    esac
    suite_command=(bash "$tmp/repo/tests/loop-escalation.tests.sh")
    if [[ "$runtime" == pwsh ]]; then suite_command=(pwsh -NoProfile -File "$tmp/repo/tests/loop-escalation.tests.ps1"); fi
    status=0
    "${suite_command[@]}" > "$tmp/$runtime-$mutation.log" 2>&1 || status=$?
    if [[ "$mutation" == clean ]]; then
      [[ "$status" -eq 0 ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
      grep -F 'audited 1 allowlisted line' "$tmp/$runtime-$mutation.log" >/dev/null
    else
      [[ "$status" -eq 1 ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
      grep -F 'FAIL: TEST-019.10b: emitted resolver dependency skips are no longer allowed' "$tmp/$runtime-$mutation.log" >/dev/null
    fi
    printf 'ok: %s escalation activation %s\n' "$runtime" "$mutation"
    passed=$((passed + 1))
  done
done
printf '%d escalation activation cases passed\n' "$passed"
