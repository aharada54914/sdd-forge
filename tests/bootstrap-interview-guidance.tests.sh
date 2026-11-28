#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BASE="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer"
INTERVIEWER="$BASE/SKILL.md"
CORE="$ROOT/plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md"
RUN="$ROOT/plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
# v1.26.0 (b193c75be2): archived SKILL.md and references/interview-question-bank.md
# from plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/.
ARCHIVE="$ROOT/tests/fixtures/bootstrap-v1.26.0"
BANK="$ARCHIVE/interview-question-bank.md"
GUIDE="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/references/claude-design-workflow.md"
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

assert_blob() {
  if [ "$(git hash-object -- "$1")" = "$2" ]; then pass "$3"; else fail "$3"; fi
}
assert_blob "$BANK" a4ecaddae9d760020ac6cf8df66ef6f1e8f24788 'v1.26.0 interview question bank provenance'
assert_blob "$ARCHIVE/interviewer.md" 631074c4deb08121d5a95ff981e00d7a8d34c450 'v1.26.0 interviewer provenance'

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

assert_contains "$ARCHIVE/interviewer.md" 'N/A — no change: <reason>' "TEST-017 bugfix-unaffected-layers reasoned N/A"
assert_contains "$ARCHIVE/interviewer.md" 'security impact.*always|always.*security impact' "TEST-017 security assessment always required"
assert_contains "$ARCHIVE/interviewer.md" 'ds_profile' "TEST-019 ds_profile question present"
assert_contains "$ARCHIVE/interviewer.md" 'skip design-system integration entirely' "TEST-019 none profile skips integration"
assert_contains "$ARCHIVE/interviewer.md" 'ds_profile: <value>' "TEST-019 ds_profile recorded in ux-spec"

for contract in TEST-006 TEST-017 TEST-019; do
  if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" "$contract"; then
    pass "$contract Core interview guidance"
  else
    fail "$contract Core interview guidance"
  fi
done

if [ "${1:-}" = '--interview-contracts' ]; then
  printf 'PASS: %s\nFAIL: %s\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]; exit $?
fi

for output in requirements.md design.md; do
  assert_contains "$CORE" "specs/<feature>/$output" "TEST-009 declares Core output $output"
done
# Q03 (owner decision 2026-11-28): the v1 Phase 1 outputs (acceptance-tests.md,
# four layer specs, layer-local unknowns, create-only layer files and the LITE
# zero-layer rule) retired with the interviewer (ADR-0051 decision 2). The
# same guarantees are now checked on the three Core documents: each is
# generated from its template, acceptance criteria live in requirements.md,
# and no retired output is declared.
CORE_TEMPLATES="$ROOT/plugins/sdd-bootstrap/skills/sdd-core-spec/templates"
for doc in requirements design tasks; do
  assert_contains "$CORE" "templates/$doc.md\` → \`specs/<feature>/$doc.md" "TEST-009 Core generates $doc.md from its template"
  [ -f "$CORE_TEMPLATES/$doc.md" ] && pass "TEST-009 template $doc.md ships" || fail "TEST-009 template $doc.md ships"
done
assert_contains "$CORE" '^3\. \*\*3 ファイル生成' "TEST-009 Core declares exactly three generated documents"
assert_contains "$CORE" 'requirements.md.*全 `REQ-NNN` に観測・テスト可能な `AC-NNN`|全 `REQ-NNN` に観測・テスト可能な `AC-NNN` を紐付け' "TEST-009 acceptance criteria are generated in requirements.md"
assert_contains "$CORE_TEMPLATES/requirements.md" '^- \*\*AC-001\*\* \(REQ-001\): Given .*When .*Then ' "TEST-009 requirements template carries Given/When/Then AC rows bound to a REQ"
assert_contains "$CORE" '`### Done When`（対応 `AC-NNN` 参照）' "TEST-009 tasks reference their AC in Done When"
assert_contains "$RUN" 'specs/<feature>/\{requirements,design,tasks\}\.md' "TEST-009 bootstrap hands off the three Core documents"
for retired in acceptance-tests.md ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
  if grep -Fq "specs/<feature>/$retired" "$CORE" "$RUN"; then
    fail "TEST-009 retired output $retired is still declared"
  else
    pass "TEST-009 retired output $retired is not declared"
  fi
done
assert_contains "$GUIDE" 'No mockup provided — optional visualization skipped' "TEST-018 no-mockup clean skip"

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

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" interview; then
  pass "Core interview contract"
else
  fail "Core interview contract"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
