#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMPLATES="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates"
CORE_TEMPLATES="$ROOT/plugins/sdd-bootstrap/skills/sdd-core-spec/templates"
TRACEABILITY="$TEMPLATES/traceability.template.md"
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

assert_contains "$TRACEABILITY" 'Requirement.*Layer Spec.*Test ID' "TEST-008 Layer Spec traceability column"
trace_header=$(grep -m 1 '^| Requirement |' "$TRACEABILITY")
if [ "$trace_header" = '| Requirement | Investigation | Design | Layer Spec | Code Target | Test ID | Status |' ]; then
  pass "TEST-008 traceability retains investigation provenance"
else
  fail "TEST-008 traceability retains investigation provenance"
fi
assert_contains "$TRACEABILITY" '^## Layer Coverage$' "TEST-008 layer coverage summary"
assert_contains "$TRACEABILITY" 'ux-spec\.md#[a-z0-9-]+' "TEST-008 canonical UX anchor example"
assert_contains "$TRACEABILITY" 'frontend-spec\.md#[a-z0-9-]+' "TEST-008 canonical frontend anchor example"
assert_contains "$TRACEABILITY" 'infra-spec\.md#[a-z0-9-]+' "TEST-008 canonical infrastructure anchor example"
assert_contains "$TRACEABILITY" 'security-spec\.md#[a-z0-9-]+' "TEST-008 canonical security anchor example"
assert_contains "$TRACEABILITY" 'N/A — cross-layer only: [^|]+' "TEST-008 reasoned cross-layer example"

if ! awk -F '|' '
  /^\| Requirement / {
    for (i = 2; i < NF; i++) {
      name = $i
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "Layer Spec") layer_spec = i
    }
  }
  /^\| REQ-/ {
    rows++
    value = $layer_spec
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    if (value == "" || value == "N/A") invalid = 1
  }
  END { exit (!layer_spec || !rows || invalid) ? 1 : 0 }
' "$TRACEABILITY"; then
  fail "TEST-008 no blank or bare N/A Layer Spec examples"
else
  pass "TEST-008 no blank or bare N/A Layer Spec examples"
fi

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
if python3 "$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" "$TRACEABILITY" "$TMP_WORK/requirements.md"; then
  pass "TEST-008 shipped layer table template passes the validator"
else
  fail "TEST-008 shipped layer table template passes the validator"
fi
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
