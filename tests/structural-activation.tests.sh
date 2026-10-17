#!/usr/bin/env bash
# Exercise the real suites with isolated corpus mutations, not a mock auditor.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/structural-activation.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --no-hardlinks "$root" "$tmp/repo"
git -C "$tmp/repo" update-ref refs/remotes/origin/main "$(git -C "$root" rev-parse origin/main)"
for file in tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 tests/lib/markdown-ast-canonicalizer.sh tests/lib/markdown-ast-canonicalizer.ps1 tests/lib/markdown-ast-canonicalizer.mjs tests/fixtures/structural-frontmatter-cases.json tests/fixtures/skip-allowlist-manifest.json tests/lib/structural-context-lite.py; do
  cp "$root/$file" "$tmp/repo/$file"
done
# The isolated clone needs the same locked parser used by the parent suite.
ln -s "$root/mcp/sdd-forge-mcp/node_modules" "$tmp/repo/mcp/sdd-forge-mcp/node_modules"
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
    grep -F 'AC-043 active: checking F5 Context-present Lite artifacts' "$tmp/$runtime-$mutation.log" >/dev/null
    grep -F 'AC-043 active: checking F6 Context-present Lite artifacts' "$tmp/$runtime-$mutation.log" >/dev/null
    if grep -Eq 'SKIP: F[56]/AC-043' "$tmp/$runtime-$mutation.log"; then cat "$tmp/$runtime-$mutation.log"; exit 1; fi
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
# Mutate the actual current producer, separately for each Context mode. The
# recorded F2 response stays untouched; a passing fallback cannot hide F5/F6.
producer=plugins/sdd-quality-loop/scripts/resolve-project-context.py
for runtime in sh ps1; do
  if [[ "$runtime" == ps1 ]] && ! command -v pwsh >/dev/null 2>&1; then continue; fi
  for state in F5 F6; do
    python3 - "$root/$producer" "$tmp/repo/$producer" "$state" <<'PYCODE'
import pathlib,sys
source=pathlib.Path(sys.argv[1]).read_text()
start=source.index('def _assemble_resolver_evidence(')
end=source.index('\ndef ', start+1)
section=source[start:end]
old='"state": state,'
assert section.count(old)==1
wrong='required' if sys.argv[3]=='F5' else 'advisory'
pathlib.Path(sys.argv[2]).write_text(source[:start]+section.replace(old, '"state": "'+wrong+'",')+source[end:])
PYCODE
    status=0
    python3 "$tmp/repo/tests/lib/structural-context-lite.py" --state "$state" --runtime "$runtime" --output "$tmp/$state-$runtime.json" > "$tmp/$state-$runtime-negative.log" 2>&1 || status=$?
    [[ "$status" -ne 0 && ! -f "$tmp/$state-$runtime.json" ]] || { cat "$tmp/$state-$runtime-negative.log"; exit 1; }
    grep -F 'Resolver must observe the requested advisory/required Context state' "$tmp/$state-$runtime-negative.log" >/dev/null
    printf 'ok: %s %s rejects actual producer state substitution\n' "$runtime" "$state"
    passed=$((passed + 1))
  done
done
printf '%d structural activation cases passed\n' "$passed"
