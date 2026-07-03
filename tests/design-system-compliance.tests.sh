#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-design-system.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

make_fixture() {
  # $1 = fixture dir. Creates a conforming project.
  mkdir -p "$1/design-system" "$1/src" "$1/specs/demo"
  cat > "$1/design-system/design-tokens.json" <<'EOF'
{
  "meta": {
    "schema": "design-system-contract/v1",
    "version": "0.1.0",
    "generated_by": "manual",
    "profile": "custom"
  },
  "color": { "primary": { "$type": "color", "$value": "#0f62fe" } },
  "typography": { "font-size-base": { "$type": "dimension", "$value": "16px" } },
  "spacing": { "md": { "$type": "dimension", "$value": "16px" } }
}
EOF
  printf '.button { color: var(--color-primary); }\n' > "$1/src/app.css"
  printf '# Design: demo\n\n## Design System Compliance\n\n- Design-System-Version: 0.1.0\n' > "$1/specs/demo/design.md"
}

# CDS-001 skip when no design-system/
mkdir -p "$FIX/empty"
out="$(sh "$CHECK_SH" "$FIX/empty" 2>&1)"; rc=$?
case "$out" in *"skipped: no design-system/"*) [ "$rc" -eq 0 ] && pass "CDS-001 skip without design-system" || fail "CDS-001 skip exit code" ;; *) fail "CDS-001 skip without design-system" ;; esac

# CDS-002 conforming project passes
make_fixture "$FIX/ok"
out="$(sh "$CHECK_SH" "$FIX/ok" "$FIX/ok/specs/demo/design.md" "$FIX/ok/src/app.css" 2>&1)"; rc=$?
case "$out" in *"check-design-system passed."*) [ "$rc" -eq 0 ] && pass "CDS-002 conforming project" || fail "CDS-002 exit code" ;; *) fail "CDS-002 conforming project ($out)" ;; esac

# CDS-003 raw value in changed file -> WARN, exit 0
make_fixture "$FIX/warn"
printf '.bad { color: #ff0000; }\n' > "$FIX/warn/src/bad.css"
out="$(sh "$CHECK_SH" "$FIX/warn" "$FIX/warn/specs/demo/design.md" "$FIX/warn/src/bad.css" 2>&1)"; rc=$?
case "$out" in *"check-design-system WARN"*"raw style value"*"#ff0000"*) [ "$rc" -eq 0 ] && pass "CDS-003 warn on raw value" || fail "CDS-003 warn exit code" ;; *) fail "CDS-003 warn on raw value ($out)" ;; esac

# CDS-004 enforce mode -> exit 1
out="$(SDD_DESIGN_SYSTEM_ENFORCE=error sh "$CHECK_SH" "$FIX/warn" "$FIX/warn/specs/demo/design.md" "$FIX/warn/src/bad.css" 2>&1)"; rc=$?
case "$out" in *"check-design-system FAILED"*) [ "$rc" -eq 1 ] && pass "CDS-004 enforce mode fails" || fail "CDS-004 enforce exit code" ;; *) fail "CDS-004 enforce mode fails ($out)" ;; esac

# CDS-005 invalid meta envelope -> finding
make_fixture "$FIX/badmeta"
printf '{ "meta": { "schema": "wrong/v1" }, "color": {}, "typography": {}, "spacing": {} }\n' > "$FIX/badmeta/design-system/design-tokens.json"
out="$(sh "$CHECK_SH" "$FIX/badmeta" 2>&1)"; rc=$?
case "$out" in *"meta.schema is not design-system-contract/v1"*) pass "CDS-005 invalid meta detected" ;; *) fail "CDS-005 invalid meta detected ($out)" ;; esac

# CDS-006 design.md missing compliance section -> finding
make_fixture "$FIX/nosec"
printf '# Design: demo\n' > "$FIX/nosec/specs/demo/design.md"
out="$(sh "$CHECK_SH" "$FIX/nosec" "$FIX/nosec/specs/demo/design.md" 2>&1)"; rc=$?
case "$out" in *"missing"*"Design System Compliance"*) pass "CDS-006 missing section detected" ;; *) fail "CDS-006 missing section detected ($out)" ;; esac

# CDS-007 excluded paths are not scanned
make_fixture "$FIX/excl"
printf 'color: #ff0000\n' > "$FIX/excl/design-system/design-system.md"
out="$(sh "$CHECK_SH" "$FIX/excl" "$FIX/excl/specs/demo/design.md" "design-system/design-system.md" 2>&1)"; rc=$?
case "$out" in *"check-design-system passed."*) pass "CDS-007 exclusions honored" ;; *) fail "CDS-007 exclusions honored ($out)" ;; esac

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
