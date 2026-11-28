#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CORE_TEMPLATES="$ROOT/plugins/sdd-bootstrap/skills/sdd-core-spec/templates"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() {
  file=$1
  pattern=$2
  label=$3
  if grep -Eq "$pattern" "$file"; then pass "$label"; else fail "$label"; fi
}

assert_absent() {
  file=$1
  pattern=$2
  label=$3
  grep -Eq "$pattern" "$file"
  if [ "$?" -eq 1 ]; then pass "$label"; else fail "$label"; fi
}

# TEST-007 checks the Core source templates here and their installed copies below.
assert_contains "$CORE_TEMPLATES/design.md" '^## テスト方針$' "TEST-007 retains test strategy"
assert_contains "$CORE_TEMPLATES/requirements.md" '^## Open Questions' "TEST-007 retains open questions"
assert_contains "$CORE_TEMPLATES/design.md" '^## 影響範囲・リスク考慮$' "TEST-007 retains risks"
assert_absent "$CORE_TEMPLATES/design.md" '^## (Frontend|Backend) Plan$' "TEST-007 removes legacy inline plan placeholders"

# Q16 (owner decision 2026-11-28): the ten checks on the retired interviewer's
# traceability template (its Layer Spec column, provenance, coverage summary,
# canonical anchor and N/A examples, and the template passing the validator)
# retired with the template (ADR-0051 decision 2). The public validators still
# ship; Q16 below proves both reject a missing requirement, a malformed
# reference and an N/A without a reason. TEST-007 above is separate.

TMP_WORK=$(mktemp -d)
trap 'rm -rf "$TMP_WORK"' EXIT
installed="$TMP_WORK/installed"
if bash "$ROOT/install.sh" --source-directory "$ROOT" --install-root "$installed" --target FilesOnly \
    --plugins sdd-bootstrap --skip-mcp --skip-agent-install > "$TMP_WORK/install.log" 2>&1; then
  for document in requirements design tasks; do
    if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" "TEST-007-$document" "$installed"; then
      pass "TEST-007 installed Core $document.md"
    else
      fail "TEST-007 installed Core $document.md"
    fi
  done
else
  cat "$TMP_WORK/install.log" >&2
  fail "TEST-007 install Core documents"
fi

cat > "$TMP_WORK/requirements.md" <<'EOF'
# Requirements

- REQ-001
- REQ-002
- REQ-003
- REQ-004
- REQ-005
- REQ-006
EOF
# Q16: the Python and PowerShell validators accept a complete table and reject
# each defect with its own diagnostic, identically.
q16_case() {
  name=$1 expected=$2 diagnostic=$3
  shift 3
  { printf '| Requirement | Layer Spec |\n|---|---|\n'; for row in "$@"; do printf '%s\n' "$row"; done; } > "$TMP_WORK/q16-$name.md"
  python3 "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" "$TMP_WORK/q16-$name.md" "$TMP_WORK/q16-requirements.md" 2> "$TMP_WORK/q16-py.log"
  py=$?
  if [ "$py" -eq "$expected" ] && { [ -z "$diagnostic" ] || grep -F "$diagnostic" "$TMP_WORK/q16-py.log" >/dev/null; }; then
    pass "Q16 Python validator $name (exit $expected)"
  else
    fail "Q16 Python validator $name: exit $py, $(cat "$TMP_WORK/q16-py.log")"
  fi
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1" \
      -Path "$TMP_WORK/q16-$name.md" -RequirementsPath "$TMP_WORK/q16-requirements.md" > "$TMP_WORK/q16-ps.log" 2>&1
    ps=$?
    if { [ "$expected" -eq 0 ] && [ "$ps" -eq 0 ]; } || { [ "$expected" -ne 0 ] && [ "$ps" -ne 0 ] && grep -F "$diagnostic" "$TMP_WORK/q16-ps.log" >/dev/null; }; then
      pass "Q16 PowerShell validator $name"
    else
      fail "Q16 PowerShell validator $name: exit $ps, $(cat "$TMP_WORK/q16-ps.log")"
    fi
  else
    printf 'SKIP: Q16 PowerShell validator %s (pwsh unavailable)\n' "$name"
  fi
}
printf '# Requirements\n\n- REQ-001\n- REQ-002\n- REQ-003\n' > "$TMP_WORK/q16-requirements.md"
q16_case complete 0 '' '| REQ-001 | ux-spec.md#journey |' '| REQ-002 | frontend-spec.md#state; security-spec.md#authz |' \
  '| REQ-003 | N/A — cross-layer only: shared logging helper |'
q16_case missing-requirement 1 'requirements missing Layer Spec coverage: REQ-003' '| REQ-001 | ux-spec.md#journey |' \
  '| REQ-002 | infra-spec.md#deploy |'
for bad in 'api-spec.md#journey' 'ux-spec.md' 'UX-spec.md#journey' 'ux-spec.md#Journey' 'ux-spec.md#journey, infra-spec.md#deploy'; do
  q16_case "reference-$(printf '%s' "$bad" | tr -c 'a-zA-Z0-9' '-')" 1 "invalid Layer Spec for REQ-002: $bad" \
    '| REQ-001 | ux-spec.md#journey |' "| REQ-002 | $bad |" '| REQ-003 | infra-spec.md#deploy |'
done
for bad in 'N/A' 'N/A — cross-layer only:' 'n/a — cross-layer only: helper'; do
  q16_case "na-$(printf '%s' "$bad" | tr -c 'a-zA-Z0-9' '-')" 1 "invalid Layer Spec for REQ-003: $bad" \
    '| REQ-001 | ux-spec.md#journey |' '| REQ-002 | infra-spec.md#deploy |' "| REQ-003 | $bad |"
done
# Existing projects can pass layer tables directly to the public validator.
{
  printf '| Requirement | Layer Spec |\n|---|---|\n'
  for id in 001 002 003 004 005 006; do
    printf '| REQ-%s | ux-spec.md#journey |\n' "$id"
  done
} > "$TMP_WORK/traceability.md"
cat >> "$TMP_WORK/traceability.md" <<'EOF'

## Investigation Notes

| Requirement | Investigation | Notes |
|---|---|---|
| REQ-001 | INV-900 | this table must be ignored by the traceability validator |

| Notes | Requirement | Layer Spec |
|---|---|---|
| supporting data | REQ-001 | not-a-layer-anchor |
EOF
if python3 "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" "$TMP_WORK/traceability.md" "$TMP_WORK/requirements.md"; then
  pass "TEST-008 traceability validator ignores requirement-keyed side tables"
else
  fail "TEST-008 traceability validator must ignore requirement-keyed side tables"
fi

if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1" \
      -Path "$TMP_WORK/traceability.md" -RequirementsPath "$TMP_WORK/requirements.md"; then
    pass "TEST-008 PowerShell validator ignores requirement-keyed side tables"
  else
    fail "TEST-008 PowerShell validator must ignore requirement-keyed side tables"
  fi
else
  printf 'SKIP: TEST-008 PowerShell validator parity (pwsh unavailable)\n'
fi

if python3 "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" \
    "$ROOT/specs/ci-mcp/traceability.md" "$ROOT/specs/ci-mcp/requirements.md"; then
  pass "TEST-008 existing REQ-ID traceability header remains valid"
else
  fail "TEST-008 existing REQ-ID traceability header remains valid"
fi
if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1" \
      -Path "$ROOT/specs/ci-mcp/traceability.md" -RequirementsPath "$ROOT/specs/ci-mcp/requirements.md"; then
    pass "TEST-008 PowerShell existing REQ-ID traceability header remains valid"
  else
    fail "TEST-008 PowerShell existing REQ-ID traceability header remains valid"
  fi
fi

assert_header_rejection() {
  label=$1
  shift
  NO_COLOR=1 "$@" > /dev/null 2> "$TMP_WORK/header-error.log"
  status=$?
  # PowerShell prefixes the diagnostic line with a gutter below its source excerpt.
  if [ "$status" -eq 1 ] && grep -Eq '^[[:space:]]*(\|[[:space:]]*)?no requirement rows found in traceability\.md[[:space:]]*$' "$TMP_WORK/header-error.log"; then
    pass "$label"
  else
    cat "$TMP_WORK/header-error.log" >&2
    fail "$label (validator exit $status)"
  fi
}

printf '# Requirements\n\nREQ-001\n' > "$TMP_WORK/header-requirements.md"
for bad_header in 'req-id' 'REQ-id' 'Notes | REQ-ID'; do
  printf '| %s | Layer Spec |\n|---|---|\n| REQ-001 | ux-spec.md#journey |\n' "$bad_header" > "$TMP_WORK/bad-header.md"
  assert_header_rejection "TEST-008 rejects noncanonical or displaced header: $bad_header" \
    python3 "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" \
    "$TMP_WORK/bad-header.md" "$TMP_WORK/header-requirements.md"
  if command -v pwsh >/dev/null 2>&1; then
    assert_header_rejection "TEST-008 PowerShell rejects noncanonical or displaced header: $bad_header" \
      pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1" \
      -Path "$TMP_WORK/bad-header.md" -RequirementsPath "$TMP_WORK/header-requirements.md"
  fi
done

for boundary in '# Notes' '## Notes' '### Notes' '#### Notes' '##### Notes' '###### Notes'; do
  for next_layer in 'security-spec.md#access' 'invalid-anchor'; do
    expected=0
    [ "$next_layer" = 'invalid-anchor' ] && expected=1
    printf '%s\n' \
      '| Requirement | Layer Spec |' '|---|---|' \
      '| REQ-001 | ux-spec.md#journey |' "$boundary" \
      '| Requirement | Notes |' '|---|---|' \
      '| REQ-001 | supplementary prose, not a layer anchor |' \
      '### Next traceability table' \
      '| Requirement | Notes | Layer Spec |' '|---|---|---|' \
      "| REQ-001 | independent column layout | $next_layer |" \
      > "$TMP_WORK/table-boundary.md"
    python3 "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" \
      "$TMP_WORK/table-boundary.md" "$TMP_WORK/header-requirements.md" \
      > "$TMP_WORK/boundary.log" 2>&1
    actual=$?
    if [ "$actual" -eq "$expected" ] && { [ "$expected" -eq 0 ] || grep -F 'invalid Layer Spec for REQ-001: invalid-anchor' "$TMP_WORK/boundary.log" >/dev/null; }; then
      pass "TEST-008 table boundary $boundary, next layer $next_layer"
    else
      cat "$TMP_WORK/boundary.log"
      fail "TEST-008 table boundary $boundary, next layer $next_layer"
    fi
    if command -v pwsh >/dev/null 2>&1; then
      pwsh -NoProfile -File "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1" \
        -Path "$TMP_WORK/table-boundary.md" -RequirementsPath "$TMP_WORK/header-requirements.md" \
        > "$TMP_WORK/boundary.log" 2>&1
      actual=$?
      if [ "$actual" -eq "$expected" ] && { [ "$expected" -eq 0 ] || grep -F 'invalid Layer Spec for REQ-001: invalid-anchor' "$TMP_WORK/boundary.log" >/dev/null; }; then
        pass "TEST-008 PowerShell table boundary $boundary, next layer $next_layer"
      else
        cat "$TMP_WORK/boundary.log"
        fail "TEST-008 PowerShell table boundary $boundary, next layer $next_layer"
      fi
    fi
  done
done

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" traceability; then
  pass "Core traceability contract"
else
  fail "Core traceability contract"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
