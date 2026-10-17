#!/usr/bin/env bash
# Exercise real caller detection separately from rendered allowlist evidence.
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
  suite_command=(bash "$tmp/repo/tests/loop-escalation.tests.sh")
  evaluator_command=(bash "$tmp/repo/tests/lib/skip-allowlist-evaluator.sh")
  if [[ "$runtime" == pwsh ]]; then
    suite_command=(pwsh -NoProfile -File "$tmp/repo/tests/loop-escalation.tests.ps1")
    evaluator_command=(pwsh -NoProfile -File "$tmp/repo/tests/lib/skip-allowlist-evaluator.ps1")
  fi
  caller="$tmp/repo/plugins/sdd-bootstrap/scripts/escalation-activation-fixture.sh"
  for mutation in clean activated; do
    if [[ "$mutation" == activated ]]; then
      printf '%s\n' '#!/usr/bin/env bash' 'resolve-project-context.sh --config fixture.json' > "$caller"
      chmod +x "$caller"
    fi
    status=0
    "${suite_command[@]}" > "$tmp/$runtime-consumer-$mutation.log" 2>&1 || status=$?
    if [[ "$mutation" == clean ]]; then
      [[ "$status" -eq 0 ]] || { cat "$tmp/$runtime-consumer-$mutation.log"; exit 1; }
      grep -F 'TEST-019.10a (negative self-check): the spy-harness mechanism itself records a direct invocation' "$tmp/$runtime-consumer-$mutation.log" >/dev/null
      grep -F 'TEST-019.10b: resolver non-invocation assertion deferred until the live caller is wired (no stale SKIP emitted)' "$tmp/$runtime-consumer-$mutation.log" >/dev/null
    else
      [[ "$status" -eq 1 ]] || { cat "$tmp/$runtime-consumer-$mutation.log"; exit 1; }
      grep -F 'FAIL: TEST-019.10b: live resolver caller is wired but this suite still lacks a real invocation driver' "$tmp/$runtime-consumer-$mutation.log" >/dev/null
      rm "$caller"
    fi
    printf 'ok: %s escalation consumer %s\n' "$runtime" "$mutation"
    passed=$((passed + 1))
  done
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
    "${evaluator_command[@]}" line "$tmp/repo/$manifest" 'TEST-019.10b/AC-004+AC-021' AC-004 AC-021 > "$tmp/rendered.log"
    status=0
    "${evaluator_command[@]}" audit "$tmp/repo/$manifest" "$tmp/rendered.log" "$tmp/repo" origin/main > "$tmp/$runtime-$mutation.log" 2>&1 || status=$?
    if [[ "$mutation" == clean ]]; then
      [[ "$status" -eq 0 ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
      grep -F 'audited 1 allowlisted line' "$tmp/$runtime-$mutation.log" >/dev/null
    else
      if [[ "$mutation" == activated ]]; then
        [[ "$status" -eq 1 ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
        grep -F 'ERROR: AC-004 emitted after activation condition became true' "$tmp/$runtime-$mutation.log" >/dev/null
        grep -F 'ERROR: AC-021 emitted after activation condition became true' "$tmp/$runtime-$mutation.log" >/dev/null
      else
        expected_status=1
        expected_diagnostic='ERROR: AC-004 invalid activation evidence'
        if [[ "$runtime" == pwsh ]]; then
          expected_status=2
          expected_diagnostic='ERROR: integration ancestry evidence unavailable'
        fi
        [[ "$status" -eq "$expected_status" ]] || { cat "$tmp/$runtime-$mutation.log"; exit 1; }
        grep -F "$expected_diagnostic" "$tmp/$runtime-$mutation.log" >/dev/null
      fi
    fi
    printf 'ok: %s escalation allowlist audit %s\n' "$runtime" "$mutation"
    passed=$((passed + 1))
  done
done
printf '%d escalation activation cases passed\n' "$passed"
