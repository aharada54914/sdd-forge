#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BASE="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer"
INTERVIEWER="$BASE/SKILL.md"
RUN="$ROOT/plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
BANK="$BASE/references/interview-question-bank.md"
GUIDE="$BASE/references/claude-design-workflow.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() {
  file=$1
  pattern=$2
  label=$3
  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then pass "$label"; else fail "$label"; fi
}

categories='Product and Scope
Users, Roles, and UX
Data and Contracts
Workflow and Acceptance
Frontend Architecture
Backend, API, and Testing
Infrastructure and Operations
Security and Compliance'

printf '%s\n' "$categories" | while IFS= read -r category; do
  [ -n "$category" ] || continue
  if grep -Fqx "## $category" "$BANK"; then
    printf 'PASS: TEST-006 category %s\n' "$category"
  else
    printf 'FAIL: TEST-006 category %s\n' "$category"
  fi
done > "${TMPDIR:-/tmp}/sdd-bank-categories-$$"

while IFS= read -r result; do
  case "$result" in
    PASS:*) pass "${result#PASS: }" ;;
    FAIL:*) fail "${result#FAIL: }" ;;
  esac
done < "${TMPDIR:-/tmp}/sdd-bank-categories-$$"
rm -f "${TMPDIR:-/tmp}/sdd-bank-categories-$$"

bank_contract=$(awk '
  /^## / {
    if (section != "") {
      if (jp < 1 || en < 3) bad = 1
    }
    section = substr($0, 4)
    if (section == "Layer Coverage Checklist") exit bad ? 1 : 0
    jp = 0
    en = 0
    next
  }
  section != "" && /^- EN:/ { en++; next }
  section != "" && /^- / && $0 !~ /^[ -~]*$/ { jp++ }
  END {
    if (section != "" && (jp < 1 || en < 3)) bad = 1
    exit bad ? 1 : 0
  }
' "$BANK" 2>/dev/null; printf '%s' "$?")
if [ "$bank_contract" -eq 0 ]; then
  pass "TEST-006 every category has Japanese and three English probes"
else
  fail "TEST-006 every category has Japanese and three English probes"
fi
assert_contains "$BANK" '^## Layer Coverage Checklist$' "TEST-006 layer coverage checklist"

for output in requirements.md acceptance-tests.md design.md ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
  assert_contains "$INTERVIEWER" "specs/<feature>/$output" "TEST-009 declares Phase 1 output $output"
done
assert_contains "$INTERVIEWER" 'layer-local unknown|Layer-local unknown' "TEST-009 records layer-local unknowns"
assert_contains "$INTERVIEWER" 'MUST NOT overwrite|must not overwrite' "TEST-009 existing-layer-files create-only rule"
assert_contains "$INTERVIEWER" 'preserv(e|ed).*SHA-256|SHA-256.*preserv' "TEST-009 existing-layer-files preserved hashes"
assert_contains "$INTERVIEWER" 'N/A — no change: <reason>' "TEST-017 bugfix-unaffected-layers reasoned N/A"
assert_contains "$INTERVIEWER" 'security impact.*always|always.*security impact' "TEST-017 security assessment always required"
assert_contains "$INTERVIEWER" 'No mockup provided — optional visualization skipped' "TEST-018 no-mockup clean skip"
assert_contains "$RUN" 'ux-spec\.md.*frontend-spec\.md.*infra-spec\.md.*security-spec\.md' "TEST-009 run skill knows layer outputs"
assert_contains "$RUN" 'LITE.*zero layer outputs|zero layer outputs.*LITE' "TEST-009 LITE produces zero layer outputs"

if [ -f "$GUIDE" ] && [ "$(wc -l < "$GUIDE" | tr -d ' ')" -lt 200 ]; then
  pass "TEST-010 Claude Design guide is under 200 lines"
else
  fail "TEST-010 Claude Design guide is under 200 lines"
fi
assert_contains "$GUIDE" 'Mermaid.*primary|primary.*Mermaid' "TEST-010 Mermaid is primary"
assert_contains "$GUIDE" 'does not.*Figma API|no direct Figma API' "TEST-010 unsupported integration limits"
if [ -f "$GUIDE" ] && [ "$(grep -Ec '^### Prompt [123]$' "$GUIDE")" -eq 3 ]; then
  pass "TEST-010 three copy-ready prompts"
else
  fail "TEST-010 three copy-ready prompts"
fi

assert_contains "$INTERVIEWER" 'ds_profile' "TEST-019 ds_profile question present"
assert_contains "$INTERVIEWER" 'skip design-system integration entirely' "TEST-019 none profile skips integration"
assert_contains "$INTERVIEWER" 'ds_profile: <value>' "TEST-019 ds_profile recorded in ux-spec"

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
