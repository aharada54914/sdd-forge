#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
SH_SUITE="$ROOT/tests/structural-compatibility.tests.sh"
PS_SUITE="$ROOT/tests/structural-compatibility.tests.ps1"
work="$(mktemp -d "${TMPDIR:-/tmp}/t004-mutations.XXXXXX")"
trap 'rm -rf "$work"' EXIT
passed=0
failed=0

copy_surface() {
  local destination="$1" relative
  mkdir -p "$destination/tests/lib" "$destination/tests/fixtures" \
    "$destination/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer" \
    "$destination/plugins/sdd-lite/skills" "$destination/plugins/sdd-lite" \
    "$destination/specs/epic-195-a7-compatibility"
  for relative in \
    tests/run-all.sh tests/run-all.ps1 \
    tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 \
    tests/lib/markdown-ast-canonicalizer.sh tests/lib/markdown-ast-canonicalizer.ps1 \
    plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md \
    plugins/sdd-lite/skills/lite-spec/SKILL.md \
    specs/epic-195-a7-compatibility/design.md \
    specs/epic-195-a7-compatibility/acceptance-tests.md \
    specs/epic-195-a7-compatibility/tasks.md; do
    mkdir -p "$destination/$(dirname "$relative")"
    cp "$ROOT/$relative" "$destination/$relative"
  done
  cp -R "$ROOT/tests/fixtures/structural-fixture-corpus" "$destination/tests/fixtures/"
  cp -R "$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates" \
    "$destination/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/"
  cp -R "$ROOT/plugins/sdd-lite/templates" "$destination/plugins/sdd-lite/"
}

update_json() {
  local target="$1"; shift
  jq "$@" "$target" > "$target.next"
  mv "$target.next" "$target"
}

require_source_change() {
  local before="$1" target="$2" after
  after="$(shasum -a 256 "$target" | awk '{print $1}')"
  [[ "$before" != "$after" ]] || { printf 'MUTATION DRIVER ERROR: source did not change: %s\n' "$target" >&2; exit 2; }
}

mutate_case() {
  local id="$1" target_root="$2"
  local corpus="$target_root/tests/fixtures/structural-fixture-corpus"
  local blocked_one blocked_two before
  blocked_one='Fac'; blocked_one+='et'
  blocked_two='capab'; blocked_two+='ility'
  case "$id" in
    envelope-schema) update_json "$corpus/f1-full.json" '.schema += "/mutated"' ;;
    envelope-state) update_json "$corpus/f1-full.json" '.fixture_state = "mutated"' ;;
    envelope-model) update_json "$corpus/f1-full.json" 'del(.recorded_at_model)' ;;
    envelope-commit) update_json "$corpus/f1-full.json" '.recorded_at_commit = "not-an-object-id"' ;;
    envelope-refresh) update_json "$corpus/f1-full.json" '.refresh_procedure += ".mutated"' ;;
    envelope-path) update_json "$corpus/f1-full.json" '.artifacts[0].path = ""' ;;
    envelope-content) update_json "$corpus/f1-full.json" '.artifacts[0].content = null' ;;
    envelope-f2) update_json "$corpus/f2-lite.json" '.fixture_state = "mutated"' ;;
    envelope-f3) update_json "$corpus/f3-advisory.json" '.fixture_state = "mutated"' ;;
    envelope-f4) update_json "$corpus/f4-required.json" '.fixture_state = "mutated"' ;;
    operator-case-sensitivity)
      before="$(shasum -a 256 "$target_root/tests/structural-compatibility.tests.sh" | awk '{print $1}')"
      perl -0pi -e 's/\.fixture_state == \$state/\(.fixture_state | ascii_downcase\) == \(\$state | ascii_downcase\)/' "$target_root/tests/structural-compatibility.tests.sh"
      perl -0pi -e 's/\$Value\.fixture_state -cne \$State/\$Value.fixture_state -ne \$State/' "$target_root/tests/structural-compatibility.tests.ps1"
      require_source_change "$before" "$target_root/tests/structural-compatibility.tests.sh"
      ;;
    language-case-sensitivity)
      before="$(shasum -a 256 "$target_root/tests/structural-compatibility.tests.sh" | awk '{print $1}')"
      perl -0pi -e 's~\/\^## Required Outputs\$\/~tolower(\$0) == tolower("## Required Outputs")~' "$target_root/tests/structural-compatibility.tests.sh"
      perl -0pi -e "s/\$Line -ceq '## Required Outputs'/\$Line -eq '## Required Outputs'/" "$target_root/tests/structural-compatibility.tests.ps1"
      require_source_change "$before" "$target_root/tests/structural-compatibility.tests.sh"
      ;;
    anchor) perl -0pi -e 's/## Required Outputs/## Required Outputs\n<!-- mutation -->/' "$target_root/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md" ;;
    full-paths) update_json "$corpus/f1-full.json" '.artifacts[0].path = "missing-required-output.md"' ;;
    lite-paths) update_json "$corpus/f2-lite.json" '.artifacts[0].path = "missing-required-output.md"' ;;
    full-heading-*)
      local artifact="${id#full-heading-}.md"
      update_json "$corpus/f1-full.json" --arg artifact "$artifact" '(.artifacts[] | select(.path == $artifact).content) |= "# Mutated heading\n" + .'
      ;;
    lite-heading-*)
      local artifact="${id#lite-heading-}.md"
      update_json "$corpus/f2-lite.json" --arg artifact "$artifact" '(.artifacts[] | select(.path == $artifact).content) |= "# Mutated heading\n" + .'
      ;;
    full-status-*)
      local artifact="${id#full-status-}.md"
      update_json "$corpus/f1-full.json" --arg artifact "$artifact" '(.artifacts[] | select(.path == $artifact).content) += "\nBuild Status: Mutated\n"'
      ;;
    lite-status-*)
      local artifact="${id#lite-status-}.md"
      update_json "$corpus/f2-lite.json" --arg artifact "$artifact" '(.artifacts[] | select(.path == $artifact).content) += "\nBuild Status: Mutated\n"'
      ;;
    full-id) update_json "$corpus/f1-full.json" '(.artifacts[0].content) |= sub("REQ-001"; "REQ-01")' ;;
    lite-id) update_json "$corpus/f2-lite.json" '(.artifacts[0].content) |= sub("AC-001"; "AC-01")' ;;
    full-reference) update_json "$corpus/f1-full.json" --arg word "$blocked_two" '.artifacts[0].content += "\n" + $word + " reference\n"' ;;
    lite-reference) update_json "$corpus/f2-lite.json" --arg word "$blocked_one" '.artifacts[0].content += "\n" + $word + " reference\n"' ;;
    full-artifact-leak) update_json "$corpus/f1-full.json" --arg word "$blocked_one" '.artifacts[0].path = ($word | ascii_downcase) + ".md"' ;;
    lite-artifact-leak) update_json "$corpus/f2-lite.json" --arg word "$blocked_two" '.artifacts[0].path = ($word | ascii_downcase) + ".md"' ;;
    corpus-bad-frontmatter) update_json "$corpus/f1-full.json" '.artifacts[0].content = "---\ntitle: broken\n"' ;;
    corpus-bad-heading) update_json "$corpus/f1-full.json" '.artifacts[0].content = "####### Broken\n"' ;;
    parser-frontmatter-lenient)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/if \(!failed && saw_frontmatter/if (0 && !failed && saw_frontmatter/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e 's/if \(\$SawFrontmatter -and/if (\$false -and/' "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    parser-heading-lenient)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/level > 6/0/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e 's/ -or \$Heading\.Groups\[1\]\.Value\.Length -gt 6//' "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    normalize-key-order)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/LC_ALL=C sort -o "\$work\/frontmatter\.tsv" "\$work\/frontmatter\.tsv"/: # key-sort mutation/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e 's/    \[Array\]::Sort\(\$Keys, \[StringComparer\]::Ordinal\)/    \$Keys = @(\$Keys)/' "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    normalize-horizontal-space)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/gsub\(\/\[ \\t\]\+\/, " ", value\)/gsub(\/__never__\/, " ", value)/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e "s/'\[ \\\\t\]\+'/'__never__'/" "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    normalize-line-endings)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/sub\(\/\\r\$\/, "", line\)/sub(\/__never__\$\/, "", line)/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e 's/-creplace "\\r\\n\?", "`n"/-creplace "__never__", "`n"/' "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    frontmatter-value-significance)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/value=normalized\(value\)/value=""/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e 's/\$Frontmatter\.Add\(\$Key, \(Normalize-HorizontalWhitespace \$Entry\.Groups\[2\]\.Value\)\)/\$Frontmatter.Add(\$Key, "")/' "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    heading-order-significance)
      before="$(shasum -a 256 "$target_root/tests/lib/markdown-ast-canonicalizer.sh" | awk '{print $1}')"
      perl -0pi -e 's/print level "\\t" text >> headings/print 1 "\\t" "constant" >> headings/' "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      perl -0pi -e 's/level = \$Heading\.Groups\[1\]\.Value\.Length; text = \$HeadingText/level = 1; text = "constant"/' "$target_root/tests/lib/markdown-ast-canonicalizer.ps1"
      require_source_change "$before" "$target_root/tests/lib/markdown-ast-canonicalizer.sh"
      ;;
    artifact-order-normalization)
      before="$(shasum -a 256 "$target_root/tests/structural-compatibility.tests.sh" | awk '{print $1}')"
      perl -0pi -e 's/jq -r '\''\.artifacts\[\]\.path'\'' "\$tmp\/f1-reordered\.json" \| LC_ALL=C sort/jq -r '\''.artifacts[].path'\'' "\$tmp\/f1-reordered.json"/' "$target_root/tests/structural-compatibility.tests.sh"
      perl -0pi -e 's/    \[Array\]::Sort\(\$ReorderedPaths, \[StringComparer\]::Ordinal\)\n//' "$target_root/tests/structural-compatibility.tests.ps1"
      require_source_change "$before" "$target_root/tests/structural-compatibility.tests.sh"
      ;;
    f3-skip) update_json "$corpus/f3-advisory.json" '.skip.dependencies = []' ;;
    f4-skip) update_json "$corpus/f4-required.json" '.skip.dependencies = []' ;;
    compound-without-a1) perl -pi -e 'if (/^\| AC-043 /) { s/\bA1\b/A9/g }' "$target_root/specs/epic-195-a7-compatibility/acceptance-tests.md" ;;
    compound-without-a6) perl -pi -e 'if (/^\| AC-043 /) { s/\bA6\b/A9/g }' "$target_root/specs/epic-195-a7-compatibility/acceptance-tests.md" ;;
    runner-sh) perl -0pi -e 's/^  tests\/structural-compatibility\.tests\.sh\n//m' "$target_root/tests/run-all.sh" ;;
    runner-ps1) perl -0pi -e 's/^    "tests\/structural-compatibility\.tests\.ps1"\n//m' "$target_root/tests/run-all.ps1" ;;
    *) printf 'unknown mutation: %s\n' "$id" >&2; exit 2 ;;
  esac
}

run_one() {
  local id="$1" runtime="$2" expected="$3" target_root="$4" output normalized_output rc suite
  set +e
  if [[ "$runtime" == sh ]]; then
    suite="$target_root/tests/structural-compatibility.tests.sh"
    output="$(STRUCTURAL_COMPAT_REPO_ROOT="$target_root" bash "$suite" 2>&1)"
    rc=$?
  else
    suite="$target_root/tests/structural-compatibility.tests.ps1"
    output="$(STRUCTURAL_COMPAT_REPO_ROOT="$target_root" pwsh -NoProfile -File "$suite" 2>&1)"
    rc=$?
  fi
  set -e
  normalized_output="$(tr '\n' ' ' <<<"$output" | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/ | / /g')"
  if [[ "$rc" -ne 0 ]] && grep -F "$expected" <<<"$normalized_output" >/dev/null; then
    printf 'MUTATION-KILLED: %s [%s] exit=%d evidence=%s\n' "$id" "$runtime" "$rc" "$expected"
    passed=$((passed + 1))
  else
    printf 'MUTATION-SURVIVED: %s [%s] exit=%d expected=%s\n%s\n' "$id" "$runtime" "$rc" "$expected" "$output" >&2
    failed=$((failed + 1))
  fi
}

run_pair() {
  local id="$1" expected="$2"
  local target_root="$work/$id"
  copy_surface "$target_root"
  mutate_case "$id" "$target_root"
  run_one "$id" sh "$expected" "$target_root"
  run_one "$id" ps1 "$expected" "$target_root"
}

run_pair envelope-schema 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-state 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-model 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-commit 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-refresh 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-path 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-content 'FAIL: F1 corpus envelope matches the shipped schema'
run_pair envelope-f2 'FAIL: F2 corpus envelope matches the shipped schema'
run_pair envelope-f3 'FAIL: F3 corpus envelope matches the shipped schema'
run_pair envelope-f4 'FAIL: F4 corpus envelope matches the shipped schema'
run_pair operator-case-sensitivity 'FAIL: operator layer rejects a mis-cased shipped state'
run_pair language-case-sensitivity 'FAIL: language matching layer rejects a mis-cased shipped anchor'
run_pair anchor 'FAIL: fingerprinted Required Outputs injection anchor is unchanged'
run_pair full-paths 'FAIL: full artifact paths and exact count derive from its shipped output surface'
run_pair lite-paths 'FAIL: lite artifact paths and exact count derive from its shipped output surface'

for artifact in requirements acceptance-tests design ux-spec frontend-spec infra-spec security-spec; do
  run_pair "full-heading-$artifact" "FAIL: full $artifact.md frontmatter and ordered headings match its shipped template"
  run_pair "full-status-$artifact" "FAIL: full $artifact.md status field names match its shipped template"
done
for artifact in requirements design tasks; do
  run_pair "lite-heading-$artifact" "FAIL: lite $artifact.md frontmatter and ordered headings match its shipped template"
  run_pair "lite-status-$artifact" "FAIL: lite $artifact.md status field names match its shipped template"
done

run_pair full-id 'FAIL: full generated identifiers retain the shipped three-digit grammar'
run_pair lite-id 'FAIL: lite generated identifiers retain the shipped three-digit grammar'
run_pair full-reference 'FAIL: full output contains no '
run_pair lite-reference 'FAIL: lite output contains no '
run_pair full-artifact-leak 'FAIL: full output contains no '
run_pair lite-artifact-leak 'FAIL: lite output contains no '
run_pair corpus-bad-frontmatter 'markdown AST parse failure:'
run_pair corpus-bad-heading 'markdown AST parse failure:'
run_pair parser-frontmatter-lenient 'FAIL: malformed frontmatter is a hard failure'
run_pair parser-heading-lenient 'FAIL: unrecognized heading grammar is a hard failure'
run_pair normalize-key-order 'FAIL: frontmatter order and permitted whitespace/line endings normalize'
run_pair normalize-horizontal-space 'FAIL: frontmatter order and permitted whitespace/line endings normalize'
run_pair normalize-line-endings 'FAIL: frontmatter order and permitted whitespace/line endings normalize'
run_pair frontmatter-value-significance 'FAIL: frontmatter values remain comparison-significant'
run_pair heading-order-significance 'FAIL: heading level and document order remain comparison-significant'
run_pair artifact-order-normalization 'FAIL: corpus artifact array order is comparison-irrelevant'
run_pair f3-skip 'FAIL: F3 named skip metadata matches its acceptance dependency'
run_pair f4-skip 'FAIL: F4 named skip metadata matches its acceptance dependency'
run_pair compound-without-a1 'FAIL: F5 compound named skip matches task and acceptance dependencies'
run_pair compound-without-a6 'FAIL: F6 compound named skip matches task and acceptance dependencies'

runner_root="$work/runner-sh"
copy_surface "$runner_root"; mutate_case runner-sh "$runner_root"
run_one runner-sh sh 'FAIL: Bash aggregate runner registers this shipped suite' "$runner_root"
runner_root="$work/runner-ps1"
copy_surface "$runner_root"; mutate_case runner-ps1 "$runner_root"
run_one runner-ps1 ps1 'FAIL: PowerShell aggregate runner registers this shipped suite' "$runner_root"

empty_root="$work/empty-product-root"
mkdir -p "$empty_root/tests"
cp "$SH_SUITE" "$empty_root/tests/structural-compatibility.tests.sh"
cp "$PS_SUITE" "$empty_root/tests/structural-compatibility.tests.ps1"
run_one empty-product-root sh 'FAIL: required shipped product surface exists:' "$empty_root"
run_one empty-product-root ps1 'FAIL: required shipped product surface exists:' "$empty_root"

printf '%s\n' 'RESTORE-GREEN: Bash'
bash "$SH_SUITE"
printf '%s\n' 'RESTORE-GREEN: PowerShell'
pwsh -NoProfile -File "$PS_SUITE"
printf 'MUTATION SUMMARY: %d killed, %d survived\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
