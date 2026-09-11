#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="${STRUCTURAL_COMPAT_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"
CANON="$REPO_ROOT/tests/lib/markdown-ast-canonicalizer.sh"
CORPUS="$REPO_ROOT/tests/fixtures/structural-fixture-corpus"
BOOTSTRAP_SKILL="$REPO_ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
LITE_SKILL="$REPO_ROOT/plugins/sdd-lite/skills/lite-spec/SKILL.md"
DESIGN="$REPO_ROOT/specs/epic-195-a7-compatibility/design.md"
ACCEPTANCE="$REPO_ROOT/specs/epic-195-a7-compatibility/acceptance-tests.md"

PASS=0
FAIL=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
assert_true() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/structural-compat.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

required=("$CANON" "$BOOTSTRAP_SKILL" "$LITE_SKILL" "$DESIGN" "$ACCEPTANCE" "$CORPUS/f1-full.json" "$CORPUS/f2-lite.json" "$CORPUS/f3-advisory.json" "$CORPUS/f4-required.json")
missing=0
for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    fail "required shipped product surface exists: ${path#$REPO_ROOT/}"
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  printf '%d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi

extract_full_paths() {
  local source="${1:-$BOOTSTRAP_SKILL}"
  awk '
    /^## Required Outputs$/ { in_outputs=1; next }
    in_outputs && /^Phase 2 outputs/ { exit }
    in_outputs && /^- `specs\/<feature>\/[^`]+\.md`$/ {
      line=$0; sub(/^- `specs\/<feature>\//, "", line); sub(/`$/, "", line); print line
    }
  ' "$source"
}

extract_lite_paths() {
  awk '
    /次の3ファイルを `specs\/<feature>\/` に生成/ { in_outputs=1; next }
    in_outputs && /^4\./ { exit }
    in_outputs && /- `[^`]+\.md`/ {
      line=$0; sub(/^.*- `/, "", line); sub(/`.*/, "", line); print line
    }
  ' "$LITE_SKILL"
}

template_for() {
  local track="$1" path="$2"
  if [[ "$track" == full ]]; then
    printf '%s/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/%s.template.md\n' "$REPO_ROOT" "${path%.md}"
  else
    case "$path" in
      requirements.md) printf '%s/plugins/sdd-lite/templates/requirements-lite.md\n' "$REPO_ROOT" ;;
      design.md) printf '%s/plugins/sdd-lite/templates/design-lite.md\n' "$REPO_ROOT" ;;
      tasks.md) printf '%s/plugins/sdd-lite/templates/tasks-lite.md\n' "$REPO_ROOT" ;;
      *) return 1 ;;
    esac
  fi
}

# First match only, extracted without a pipe. `sed -n ...p | head -1` under
# `set -o pipefail` couples this assignment's status to SIGPIPE: once sed's
# output exceeds the pipe buffer, head exits first, sed dies on SIGPIPE, the
# pipeline reports 141, and errexit kills the whole suite instead of failing an
# assertion. awk with an explicit exit takes the same first match with no pipe
# to break, and matches the PowerShell twin's first-match [regex]::Match.
schema_from_design="$(awk 'match($0, /\{schema: "[^"]*"/) { s = substr($0, RSTART + 10, RLENGTH - 11); print s; exit }' "$DESIGN")"
refresh_path="$(awk '/^## T-012 / { seen=1 } seen && /structural-compatibility-live-refresh\.tests\.sh/ { if (match($0, /`[^`]*structural-compatibility-live-refresh\.tests\.sh`/)) { line=substr($0, RSTART + 1, RLENGTH - 2); print line; exit } }' "$REPO_ROOT/specs/epic-195-a7-compatibility/tasks.md")"

validate_envelope() {
  local file="$1" state="$2"
  jq -e --arg schema "$schema_from_design" --arg state "$state" --arg refresh "$refresh_path" '
    .schema == $schema and .fixture_state == $state and
    (.recorded_at_model | type == "string" and length > 0) and
    (.recorded_at_commit | type == "string" and test("^[0-9a-f]{40}$")) and
    .refresh_procedure == $refresh and
    (.artifacts | type == "array") and
    (all(.artifacts[]; (.path | type == "string" and length > 0) and (.content | type == "string")))
  ' "$file" >/dev/null
}

assert_true "F1 corpus envelope matches the shipped schema" validate_envelope "$CORPUS/f1-full.json" F1
assert_true "F2 corpus envelope matches the shipped schema" validate_envelope "$CORPUS/f2-lite.json" F2
assert_true "F3 corpus envelope matches the shipped schema" validate_envelope "$CORPUS/f3-advisory.json" F3
assert_true "F4 corpus envelope matches the shipped schema" validate_envelope "$CORPUS/f4-required.json" F4

operator_state="$(jq -r '.fixture_state' "$CORPUS/f1-full.json")"
operator_miscase="$(printf '%s' "$operator_state" | tr '[:upper:]' '[:lower:]')"
jq --arg state "$operator_miscase" '.fixture_state = $state' "$CORPUS/f1-full.json" > "$tmp/operator-miscase.json"
if validate_envelope "$tmp/operator-miscase.json" "$operator_state"; then
  fail "operator layer rejects a mis-cased shipped state"
else
  pass "operator layer rejects a mis-cased shipped state"
fi

sed 's/^## Required Outputs$/## required outputs/' "$BOOTSTRAP_SKILL" > "$tmp/language-miscase.md"
if [[ -n "$(extract_full_paths "$tmp/language-miscase.md")" ]]; then
  fail "language matching layer rejects a mis-cased shipped anchor"
else
  pass "language matching layer rejects a mis-cased shipped anchor"
fi

# FIRST sha256 in the span, matching the PowerShell twin's lazy
# `[\s\S]*?sha256:`. The previous `.*sha256:` here was greedy and took the
# LAST one: the twins agreed only because the span currently holds exactly one
# digest, and would have silently disagreed the moment a second was recorded.
anchor_expected="$(sed -n '/recorded anchor-window fingerprint/,/this worktree/p' "$DESIGN" | tr '\n' ' ' \
  | awk '{ i = index($0, "sha256:"); if (i > 0) { rest = substr($0, i + 7); sub(/^[ \t]+/, "", rest); print substr(rest, 1, 64); exit } }')"
anchor_text="$(awk '/^## Required Outputs$/ { emit=1 } emit { print } emit && /create-only rule\./ { exit }' "$BOOTSTRAP_SKILL")"
anchor_actual="$(printf '%s' "$anchor_text" | shasum -a 256 | awk '{print $1}')"
assert_true "fingerprinted Required Outputs injection anchor is unchanged" test "$anchor_actual" = "$anchor_expected"

canonicalize_content() {
  local json="$1" path="$2" out="$3" raw="$tmp/raw.md"
  jq -er --arg path "$path" '.artifacts[] | select(.path == $path) | .content' "$json" > "$raw" || return 1
  bash "$CANON" "$raw" > "$out"
}

status_fields() {
  sed -n -E 's/^([[:alpha:]][[:alnum:] -]*(Status|Approval)):[[:space:]].*$/\1/p' "$1" | LC_ALL=C sort -u
}

validate_track() {
  local track="$1" json="$2"
  local expected="$tmp/${track}-expected" actual="$tmp/${track}-actual"
  if [[ "$track" == full ]]; then extract_full_paths > "$expected"; else extract_lite_paths > "$expected"; fi
  jq -r '.artifacts[].path' "$json" | LC_ALL=C sort > "$actual"
  LC_ALL=C sort -o "$expected" "$expected"
  assert_true "$track artifact paths and exact count derive from its shipped output surface" cmp -s "$expected" "$actual"

  local path template expected_ast actual_ast content
  while IFS= read -r path; do
    template="$(template_for "$track" "$path")" || { fail "$track template maps for $path"; continue; }
    if [[ ! -f "$template" ]]; then fail "$track shipped template exists for $path"; continue; fi
    expected_ast="$tmp/${track}-${path//\//_}.template.ast"
    actual_ast="$tmp/${track}-${path//\//_}.corpus.ast"
    if bash "$CANON" "$template" > "$expected_ast" && canonicalize_content "$json" "$path" "$actual_ast"; then
      assert_true "$track $path frontmatter and ordered headings match its shipped template" cmp -s "$expected_ast" "$actual_ast"
    else
      fail "$track $path canonicalizes without parse fallback"
    fi
    jq -er --arg path "$path" '.artifacts[] | select(.path == $path) | .content' "$json" > "$tmp/content.md" || true
    status_fields "$template" > "$tmp/template.status"
    status_fields "$tmp/content.md" > "$tmp/content.status"
    assert_true "$track $path status field names match its shipped template" cmp -s "$tmp/template.status" "$tmp/content.status"
  done < "$expected"

  jq -r '.artifacts[].content' "$json" > "$tmp/${track}.all.md"
  ids="$(grep -Eo '(REQ|AC)-[[:alnum:]-]+' "$tmp/${track}.all.md" || true)"
  if [[ -n "$ids" ]] && ! grep -Ev '^(REQ|AC)-[0-9]{3}$' <<<"$ids" >/dev/null; then
    pass "$track generated identifiers retain the shipped three-digit grammar"
  else
    fail "$track generated identifiers retain the shipped three-digit grammar"
  fi

  local reserved_a reserved_b
  reserved_a="Fac"; reserved_a+="et"
  reserved_b="capab"; reserved_b+="ility"
  if ! grep -Eiq "${reserved_a}|${reserved_b}" "$tmp/${track}.all.md" &&
     ! jq -er --arg a "$reserved_a" --arg b "$reserved_b" '[.artifacts[].path | ascii_downcase | contains($a|ascii_downcase) or contains($b)] | any' "$json" >/dev/null; then
    pass "$track output contains no reserved artifact or reference vocabulary"
  else
    fail "$track output contains no reserved artifact or reference vocabulary"
  fi
}

validate_track full "$CORPUS/f1-full.json"
validate_track lite "$CORPUS/f2-lite.json"
jq '.artifacts |= reverse' "$CORPUS/f1-full.json" > "$tmp/f1-reordered.json"
extract_full_paths | LC_ALL=C sort > "$tmp/reordered-expected"
jq -r '.artifacts[].path' "$tmp/f1-reordered.json" | LC_ALL=C sort > "$tmp/reordered-actual"
assert_true "corpus artifact array order is comparison-irrelevant" cmp -s "$tmp/reordered-expected" "$tmp/reordered-actual"

printf '%s\n' '---' 'title: broken' > "$tmp/bad-frontmatter.md"
if bash "$CANON" "$tmp/bad-frontmatter.md" >/dev/null 2>&1; then fail "malformed frontmatter is a hard failure"; else pass "malformed frontmatter is a hard failure"; fi
printf '%s\n' '####### Broken heading grammar' > "$tmp/bad-heading.md"
if bash "$CANON" "$tmp/bad-heading.md" >/dev/null 2>&1; then fail "unrecognized heading grammar is a hard failure"; else pass "unrecognized heading grammar is a hard failure"; fi

printf '%s\n' '---' 'zeta:  one' 'alpha: two' '---' '# Heading   text ' > "$tmp/norm-a.md"
printf '%s\r\n' '---' 'alpha: two' 'zeta: one ' '---' '# Heading text' > "$tmp/norm-b.md"
if bash "$CANON" "$tmp/norm-a.md" > "$tmp/norm-a.ast" && bash "$CANON" "$tmp/norm-b.md" > "$tmp/norm-b.ast"; then
  assert_true "frontmatter order and permitted whitespace/line endings normalize" cmp -s "$tmp/norm-a.ast" "$tmp/norm-b.ast"
else
  fail "frontmatter order and permitted whitespace/line endings normalize"
fi
printf '%s\n' '---' 'alpha: changed' 'zeta: one' '---' '# Heading text' > "$tmp/value-change.md"
bash "$CANON" "$tmp/value-change.md" > "$tmp/value-change.ast"
if cmp -s "$tmp/norm-a.ast" "$tmp/value-change.ast"; then fail "frontmatter values remain comparison-significant"; else pass "frontmatter values remain comparison-significant"; fi
printf '%s\n' '# First' '## Second' > "$tmp/heading-a.md"
printf '%s\n' '## Second' '# First' > "$tmp/heading-b.md"
bash "$CANON" "$tmp/heading-a.md" > "$tmp/heading-a.ast"
bash "$CANON" "$tmp/heading-b.md" > "$tmp/heading-b.ast"
if cmp -s "$tmp/heading-a.ast" "$tmp/heading-b.ast"; then fail "heading level and document order remain comparison-significant"; else pass "heading level and document order remain comparison-significant"; fi

# The named-SKIP lines below are this suite's only non-assertion output, and
# the REQ-007 allowlist audit reads them, so their rendering is part of the
# contract and must be byte-identical across both runtimes. It was not: the
# Bash side rewrote the joined dependency list's trailing "+" as a SPACE
# ("SKIP: F4/AC-007 (Epic A4 ): ...") while the PowerShell twin's -join
# produced "(Epic A4)". Nothing asserted the emitted shape, so the divergence
# was invisible to both suites. Lock it here; the .ps1 twin asserts the same.
assert_skip_line() {
  local label="$1" line="$2"
  if [[ "$line" != *" )"* && "$line" =~ ^SKIP:\ [^/[:space:]]+/[^[:space:]]+\ \([^()]+\):\ .+$ ]]; then
    pass "$label"
  else
    fail "$label (rendered: [$line])"
  fi
}

emit_recorded_skip() {
  local fixture="$1" json="$2" row ac expected_deps actual_deps line
  row="$(grep -F "(${fixture}" "$ACCEPTANCE")"
  [[ -n "$row" ]] || { fail "$fixture acceptance row exists"; return; }
  ac="$(awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}' <<<"$row")"
  expected_deps="$(grep -Eo 'Epic A[0-9]+' <<<"$row" | LC_ALL=C sort -u)"
  actual_deps="$(jq -r '.skip.dependencies[]' "$json" | LC_ALL=C sort -u)"
  if jq -e --arg fixture "$fixture" --arg ac "$ac" '.skip.name == $fixture and .skip.acceptance_criterion == $ac and (.skip.reason | type == "string" and length > 0)' "$json" >/dev/null &&
     [[ "$actual_deps" == "$expected_deps" ]]; then
    line="$(printf 'SKIP: %s/%s (%s): %s' "$fixture" "$ac" "$(tr '\n' '+' <<<"$actual_deps" | sed 's/+$//')" "$(jq -r '.skip.reason' "$json")")"
    assert_skip_line "$fixture named skip line renders in the twin-identical shape" "$line"
    printf '%s\n' "$line"
  else
    fail "$fixture named skip metadata matches its acceptance dependency"
  fi
}
emit_compound_skip() {
  local fixture="$1" acceptance_row task_span acceptance_deps task_deps ac line
  acceptance_row="$(grep -F "${fixture} " "$ACCEPTANCE" | grep -F 'F5 advisory / F6 required')"
  task_span="$(awk '/F5\/F6 structural-identity assertions are named `SKIP`s/ { emit=1 } emit { printf "%s ", $0 } emit && /until they merge/ { exit }' "$REPO_ROOT/specs/epic-195-a7-compatibility/tasks.md")"
  ac="$(awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}' <<<"$acceptance_row")"
  acceptance_deps="$(grep -Eo 'A[0-9]+' <<<"$acceptance_row" | LC_ALL=C sort -u)"
  task_deps="$(grep -Eo 'A[0-9]+' <<<"$task_span" | LC_ALL=C sort -u)"
  if [[ -n "$ac" && "$acceptance_deps" == "$task_deps" && "$(wc -l <<<"$acceptance_deps" | tr -d ' ')" -gt 1 ]]; then
    line="$(printf 'SKIP: %s/%s (%s): compound dependency not merged' "$fixture" "$ac" "$(tr '\n' '+' <<<"$acceptance_deps" | sed 's/+$//')")"
    assert_skip_line "$fixture compound skip line renders in the twin-identical shape" "$line"
    printf '%s\n' "$line"
  else
    fail "$fixture compound named skip matches task and acceptance dependencies"
  fi
}
emit_recorded_skip F4 "$CORPUS/f4-required.json"
emit_recorded_skip F3 "$CORPUS/f3-advisory.json"
emit_compound_skip F5
emit_compound_skip F6

assert_true "Bash aggregate runner registers this shipped suite" grep -Fxq '  tests/structural-compatibility.tests.sh' "$REPO_ROOT/tests/run-all.sh"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
