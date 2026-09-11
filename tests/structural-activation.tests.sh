#!/usr/bin/env bash
# Exercise the real suites with isolated corpus mutations, not a mock auditor.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/structural-activation.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --no-hardlinks "$root" "$tmp/repo"
git -C "$tmp/repo" update-ref refs/remotes/origin/main "$(git -C "$root" rev-parse origin/main)"
for file in tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1; do
  cp "$root/$file" "$tmp/repo/$file"
done
corpus=tests/fixtures/structural-fixture-corpus/f4-required.json
passed=0
for runtime in bash pwsh; do
  if ! command -v "$runtime" >/dev/null 2>&1; then
    printf 'SKIP: %s unavailable for structural activation regression\n' "$runtime"
    continue
  fi
  for mutation in clean content path; do
    case "$mutation" in
      clean) cp "$root/$corpus" "$tmp/repo/$corpus" ;;
      content) jq --arg token "Fac"'et' '.artifacts[0].content += ("\n" + $token)' "$root/$corpus" > "$tmp/repo/$corpus" ;;
      path) jq --arg token "Fac"'et' '.artifacts[0].path = ($token + ".md")' "$root/$corpus" > "$tmp/repo/$corpus" ;;
    esac
    suite_command=(bash "$tmp/repo/tests/structural-compatibility.tests.sh")
    if [[ "$runtime" == pwsh ]]; then suite_command=(pwsh -NoProfile -File "$tmp/repo/tests/structural-compatibility.tests.ps1"); fi
    status=0
    "${suite_command[@]}" > "$tmp/$runtime-$mutation.log" 2>&1 || status=$?
    grep -F 'AC-007 active: checking recorded F4 full-track artifacts' "$tmp/$runtime-$mutation.log" >/dev/null
    if [[ "$mutation" == clean ]]; then
      [[ "$status" -eq 0 ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
    else
      [[ "$status" -eq 1 ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
      grep -F 'FAIL: full output contains no reserved artifact or reference vocabulary' "$tmp/$runtime-$mutation.log" >/dev/null
    fi
    printf 'ok: %s F4 activation %s\n' "$runtime" "$mutation"
    passed=$((passed + 1))
  done
done
printf '%d structural activation cases passed\n' "$passed"
