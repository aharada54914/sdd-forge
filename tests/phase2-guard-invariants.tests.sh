#!/usr/bin/env bash
# TEST-010 / TEST-011: deterministic native guard-invariant generation.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
stage="$root/specs/epic-136-phase2-gates/human-copy"
source_loop="$stage/plugins/sdd-quality-loop"
generator="$source_loop/scripts/generate-guard-invariants.py"
outputs=(guard_invariants.py guard-invariants.generated.js guard-invariants.generated.ps1 guard-invariants.generated.sh)
pass=0
fail=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

ok() { printf 'ok: %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$*"; fail=$((fail + 1)); }
copy_tree() { cp -R "$source_loop" "$1"; }
native_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
run_generator() {
  local tree="$1"
  shift
  python3 "$(native_path "$tree/scripts/generate-guard-invariants.py")" "$@"
}
check_fails() {
  if run_generator "$1" --check >/dev/null 2>&1; then return 1; fi
  return 0
}

if ! command -v python3 >/dev/null 2>&1; then
  printf 'FAIL: python3 is required\n'
  exit 1
fi

[[ -f "$generator" ]] && ok 'staged stdlib generator exists' || bad 'staged stdlib generator exists'
for output in "${outputs[@]}"; do
  [[ -f "$source_loop/scripts/generated/$output" ]] && ok "committed native output exists: $output" || bad "committed native output exists: $output"
done

if run_generator "$source_loop" --check; then ok '--check accepts committed outputs'; else bad '--check accepts committed outputs'; fi

# TEST-013: the reviewed human-copy manifest is an exact ordered binding from
# the fixed Phase 2 inventory to the staged source bytes.
phase2_targets=(
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js'
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1'
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh'
  'plugins/sdd-quality-loop/scripts/check-contract.ps1'
  'plugins/sdd-lite/references/risk-upgrade-policy.md'
  'plugins/sdd-lite/scripts/check-risk-upgrade.sh'
  'plugins/sdd-lite/scripts/check-risk-upgrade.ps1'
  'plugins/sdd-lite/skills/lite-spec/SKILL.md'
  'plugins/sdd-ship/skills/ship/SKILL.md'
  'plugins/sdd-quality-loop/references/guard-invariants.json'
  'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'
  'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py'
  'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js'
  'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1'
  'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh'
  '.github/workflows/test.yml'
  'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
)
manifest="$stage/MANIFEST.sha256"
manifest_ok=1
candidate_ok=1
if [[ ! -f "$manifest" ]]; then
  manifest_ok=0
else
  mapfile -t manifest_lines < <(sed 's/\r$//' "$manifest")
  [[ ${#manifest_lines[@]} -eq ${#phase2_targets[@]} ]] || manifest_ok=0
fi
for index in "${!phase2_targets[@]}"; do
  target="${phase2_targets[$index]}"
  candidate="$stage/$target"
  if [[ ! -f "$candidate" ]]; then
    candidate_ok=0
    manifest_ok=0
    continue
  fi
  if [[ -f "$manifest" ]]; then
    expected="$(sha256sum "$candidate" | awk '{print $1}')  $target"
    [[ "${manifest_lines[$index]:-}" == "$expected" ]] || manifest_ok=0
  fi
done
[[ "$candidate_ok" == 1 ]] && ok 'TEST-013 staged batch contains each exact protected candidate' || bad 'TEST-013 staged batch contains each exact protected candidate'
[[ "$manifest_ok" == 1 ]] && ok 'TEST-013 final manifest has exact ordered lowercase staged hashes' || bad 'TEST-013 final manifest has exact ordered lowercase staged hashes'

ci="$stage/.github/workflows/test.yml"
if [[ -f "$ci" ]]; then
  checkout_line="$(grep -Fn 'uses: actions/checkout' "$ci" | head -n 1 | cut -d: -f1 || true)"
  validation_line="$(grep -Fn 'Install recorded Claude Code CLI' "$ci" | head -n 1 | cut -d: -f1 || true)"
  guard_line="$(grep -Fn 'Test hook guards' "$ci" | head -n 1 | cut -d: -f1 || true)"
  windows_generator_line="$(grep -Fn 'Verify generated guard invariants (Windows)' "$ci" | head -n 1 | cut -d: -f1 || true)"
  posix_generator_line="$(grep -Fn 'Verify generated guard invariants (POSIX)' "$ci" | head -n 1 | cut -d: -f1 || true)"
  if [[ -n "$checkout_line" && -n "$validation_line" && -n "$guard_line" && -n "$windows_generator_line" && -n "$posix_generator_line" && "$windows_generator_line" -gt "$checkout_line" && "$posix_generator_line" -gt "$checkout_line" && "$windows_generator_line" -lt "$validation_line" && "$posix_generator_line" -lt "$validation_line" && "$windows_generator_line" -lt "$guard_line" && "$posix_generator_line" -lt "$guard_line" ]] \
    && grep -A 5 -F 'Verify generated guard invariants (Windows)' "$ci" | grep -Fq "if: runner.os == 'Windows'" \
    && grep -A 5 -F 'Verify generated guard invariants (Windows)' "$ci" | grep -Fq 'run: python ./plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check' \
    && grep -A 5 -F 'Verify generated guard invariants (POSIX)' "$ci" | grep -Fq "if: runner.os != 'Windows'" \
    && grep -A 5 -F 'Verify generated guard invariants (POSIX)' "$ci" | grep -Fq 'run: python3 ./plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check' \
    && grep -A 5 -F 'Test Phase 2 guard invariants (pwsh)' "$ci" | grep -Fq "if: runner.os == 'Windows'" \
    && grep -A 5 -F 'Test Phase 2 guard invariants (bash)' "$ci" | grep -Fq "if: runner.os != 'Windows'"; then
    ok 'TEST-011 staged CI uses platform-native generator and invariant suites before validation and guards'
  else
    bad 'TEST-011 staged CI uses platform-native generator and invariant suites before validation and guards'
  fi
else
  bad 'TEST-011 staged CI uses platform-native generator and invariant suites before validation and guards'
fi

copy_tree "$work/one"
copy_tree "$work/two"
run_generator "$work/one"
run_generator "$work/two"
same=1
for output in "${outputs[@]}"; do
  one="$(sha256sum "$work/one/scripts/generated/$output" | awk '{print $1}')"
  two="$(sha256sum "$work/two/scripts/generated/$output" | awk '{print $1}')"
  [[ "$one" == "$two" ]] || same=0
done
[[ "$same" == 1 ]] && ok 'two independent write-mode renders are byte-identical' || bad 'two independent write-mode renders are byte-identical'

stale="$work/one/scripts/generated/guard_invariants.py"
printf '# stale\n' > "$stale"
before="$(sha256sum "$stale" | awk '{print $1}')"
if check_fails "$work/one"; then
  after="$(sha256sum "$stale" | awk '{print $1}')"
  [[ "$before" == "$after" ]] && ok '--check rejects stale output without writing' || bad '--check must not mutate stale output'
else
  bad '--check rejects stale output'
fi

rm -f "$work/one/scripts/generated/guard-invariants.generated.js"
if check_fails "$work/one"; then ok '--check rejects missing output'; else bad '--check rejects missing output'; fi

for kind in type version; do
  copy_tree "$work/$kind"
  canonical="$work/$kind/references/guard-invariants.json"
  if [[ "$kind" == type ]]; then
    python3 - "$(native_path "$canonical")" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding='utf-8'))
d['shell']['write_arg_cmds'] = 'tee'
open(p, 'w', encoding='utf-8', newline='\n').write(json.dumps(d, indent=2) + '\n')
PY
  else
    python3 - "$(native_path "$canonical")" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding='utf-8'))
d['schema_version'] = 2
open(p, 'w', encoding='utf-8', newline='\n').write(json.dumps(d, indent=2) + '\n')
PY
  fi
  if check_fails "$work/$kind"; then ok "--check rejects invalid $kind schema"; else bad "--check rejects invalid $kind schema"; fi
done

copy_tree "$work/malformed"
printf '{ malformed\n' > "$work/malformed/references/guard-invariants.json"
if check_fails "$work/malformed"; then ok '--check rejects malformed canonical JSON'; else bad '--check rejects malformed canonical JSON'; fi

copy_tree "$work/io-error"
io_canonical="$work/io-error/references/guard-invariants.json"
mv "$io_canonical" "$io_canonical.backing"
mkdir "$io_canonical"
if check_fails "$work/io-error"; then ok '--check rejects canonical read I/O errors'; else bad '--check rejects canonical read I/O errors'; fi

# TEST-012: staged guard candidates must use fixed generated-module loaders.
scripts="$source_loop/scripts"
assert_contains() {
  local path="$1" needle="$2" label="$3"
  if [[ -f "$path" ]] && grep -Fq "$needle" "$path"; then ok "$label"; else bad "$label"; fi
}
assert_not_contains() {
  local path="$1" needle="$2" label="$3"
  if [[ -f "$path" ]] && ! grep -Fq "$needle" "$path"; then ok "$label"; else bad "$label"; fi
}
assert_contains "$scripts/sdd-hook-guard.py" 'spec_from_file_location' 'Python uses explicit fixed module loading'
assert_contains "$scripts/sdd-hook-guard.py" 'guard_invariants.py' 'Python loader targets its generated module'
assert_contains "$scripts/sdd-hook-guard.js" 'guard-invariants.generated.js' 'Node loader targets its generated module'
assert_contains "$scripts/sdd-hook-guard.js" 'path.join(__dirname, "generated"' 'Node loader is script-directory based'
assert_contains "$scripts/sdd-hook-guard.ps1" 'guard-invariants.generated.ps1' 'PowerShell loader targets its generated module'
assert_contains "$scripts/sdd-hook-guard.ps1" '$PSScriptRoot' 'PowerShell loader is script-directory based'
assert_contains "$scripts/sdd-hook-guard.sh" 'guard-invariants.generated.sh' 'dispatcher sources schema/provenance module'
for guard in sdd-hook-guard.py sdd-hook-guard.js sdd-hook-guard.ps1 sdd-hook-guard.sh; do
  assert_not_contains "$scripts/$guard" 'guard-invariants.json' "$guard does not parse canonical JSON at runtime"
done

payload='{"tool_name":"bash","tool_input":{"command":"cat plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'
cwd="$work/alternate-cwd"
mkdir -p "$cwd/shadow"
printf 'raise SystemExit(99)\n' > "$cwd/shadow/guard_invariants.py"
if (cd "$cwd" && PAYLOAD="$payload" PYTHONPATH="$(native_path "$cwd/shadow")" python3 "$(native_path "$scripts/sdd-hook-guard.py")" --emit exit >/dev/null 2>&1); then
  ok 'Python ignores CWD/PYTHONPATH shadow and preserves read-only decision'
else
  bad 'Python ignores CWD/PYTHONPATH shadow and preserves read-only decision'
fi
if command -v node >/dev/null 2>&1 && (cd "$cwd" && PAYLOAD="$payload" NODE_PATH="$(native_path "$cwd/shadow")" node "$(native_path "$scripts/sdd-hook-guard.js")" --emit exit >/dev/null 2>&1); then
  ok 'Node ignores CWD/NODE_PATH shadow and preserves read-only decision'
else
  bad 'Node ignores CWD/NODE_PATH shadow and preserves read-only decision'
fi

# TEST-012 dynamic fail-closed checks run only from copied trees. They prove
# the fixed module is neither optional nor allowed to carry an ignored export.
for runtime in python node; do
  fixture="$work/loader-$runtime-missing"
  copy_tree "$fixture"
  if [[ "$runtime" == python ]]; then
    rm -f "$fixture/scripts/generated/guard_invariants.py"
    if (cd "$cwd" && PAYLOAD="$payload" python3 "$(native_path "$fixture/scripts/sdd-hook-guard.py")" --emit exit >/dev/null 2>&1); then
      bad 'Python denies a missing fixed generated module'
    else
      ok 'Python denies a missing fixed generated module'
    fi
  else
    if ! command -v node >/dev/null 2>&1; then
      bad 'Node is required for fixed-module failure checks'
    else
      rm -f "$fixture/scripts/generated/guard-invariants.generated.js"
      if (cd "$cwd" && PAYLOAD="$payload" node "$(native_path "$fixture/scripts/sdd-hook-guard.js")" --emit exit >/dev/null 2>&1); then
        bad 'Node denies a missing fixed generated module'
      else
        ok 'Node denies a missing fixed generated module'
      fi
    fi
  fi
done

fixture="$work/loader-python-poisoned"
copy_tree "$fixture"
printf 'UNCONSUMED_V1_EXPORT = 1\n' > "$fixture/scripts/generated/guard_invariants.py"
if (cd "$cwd" && PAYLOAD="$payload" python3 "$(native_path "$fixture/scripts/sdd-hook-guard.py")" --emit exit >/dev/null 2>&1); then
  bad 'Python denies an unconsumed fixed-module export'
else
  ok 'Python denies an unconsumed fixed-module export'
fi

fixture="$work/loader-node-poisoned"
copy_tree "$fixture"
printf 'module.exports = { UNCONSUMED_V1_EXPORT: 1 };\n' > "$fixture/scripts/generated/guard-invariants.generated.js"
if command -v node >/dev/null 2>&1 && (cd "$cwd" && PAYLOAD="$payload" node "$(native_path "$fixture/scripts/sdd-hook-guard.js")" --emit exit >/dev/null 2>&1); then
  bad 'Node denies an unconsumed fixed-module export'
else
  ok 'Node denies an unconsumed fixed-module export'
fi

echo "phase2-guard-invariants.tests.sh: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
