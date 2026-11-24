#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN_CHECK="$ROOT/plugins/sdd-bootstrap/scripts/check-sdd-structure.sh"
ROOT_CHECK="$ROOT/scripts/check-sdd-structure.sh"
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/sdd-feature-check.XXXXXX")
PASS=0
FAIL=0

trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

make_repository() {
  repo=$1
  mkdir -p "$repo/specs" "$repo/reports/implementation" \
    "$repo/reports/quality-gate" "$repo/docs/adr" \
    "$repo/docs/review-tickets" "$repo/contracts" \
    "$repo/docs/architecture"
  : > "$repo/AGENTS.md"
  : > "$repo/CLAUDE.md"
}

# SDD Core v2 requires exactly these three files per selected feature; the
# retired layer specs below stay optional and must not be demanded (#859).
CORE_FILES="requirements.md design.md tasks.md"
LEGACY_FILES="ux-spec.md frontend-spec.md infra-spec.md security-spec.md acceptance-tests.md traceability.md"

make_feature() {
  repo=$1
  feature=$2
  mkdir -p "$repo/specs/$feature"
  for name in $CORE_FILES $LEGACY_FILES; do
    : > "$repo/specs/$feature/$name"
  done
}

assert_success_output() {
  expected=$1
  label=$2
  shift 2
  actual=$("$@" 2>&1)
  status=$?
  if [ "$status" -eq 0 ] && [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (exit=$status output=$actual)"
  fi
}

assert_failure_output() {
  expected=$1
  label=$2
  shift 2
  actual=$("$@" 2>&1)
  status=$?
  if [ "$status" -eq 1 ] && [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (exit=$status output=$actual)"
  fi
}

REPO="$FIXTURE/repo"
make_repository "$REPO"
mkdir -p "$REPO/specs/legacy-lite"
: > "$REPO/specs/legacy-lite/requirements.md"

BASELINE='host: local
check-sdd-structure: OK'
assert_success_output "$BASELINE" "TEST-011 plugin repository-only output is unchanged" \
  sh "$PLUGIN_CHECK" "$REPO"
assert_success_output "$BASELINE" "TEST-011 root repository-only output is unchanged" \
  sh "$ROOT_CHECK" "$REPO"
assert_success_output "$BASELINE" "TEST-013 LITE/legacy specs are not implicitly validated" \
  sh "$PLUGIN_CHECK" "$REPO"

make_feature "$REPO" "complete-feature"
assert_success_output "$BASELINE" "TEST-012 plugin accepts complete Core v2 feature" \
  sh "$PLUGIN_CHECK" "$REPO" "complete-feature"
assert_success_output "$BASELINE" "TEST-012 root checker accepts complete Core v2 feature" \
  sh "$ROOT_CHECK" "$REPO" "complete-feature"

mkdir -p "$REPO/specs/core-only"
for name in $CORE_FILES; do : > "$REPO/specs/core-only/$name"; done
assert_success_output "$BASELINE" "TEST-012 plugin does not demand retired layer specs" \
  sh "$PLUGIN_CHECK" "$REPO" "core-only"
assert_success_output "$BASELINE" "TEST-012 root checker does not demand retired layer specs" \
  sh "$ROOT_CHECK" "$REPO" "core-only"

for name in $CORE_FILES; do
  rm "$REPO/specs/complete-feature/$name"
  expected="missing: specs/complete-feature/$name
host: local
check-sdd-structure: FAIL (1 missing)"
  assert_failure_output "$expected" "TEST-012 missing $name has one stable diagnostic" \
    sh "$PLUGIN_CHECK" "$REPO" "complete-feature"
  : > "$REPO/specs/complete-feature/$name"
done

for invalid in "" "/tmp/outside" "../outside" "Uppercase" "under_score"; do
  assert_failure_output "invalid feature: $invalid" \
    "TEST-019 invalid selector '$invalid' fails before path access" \
    sh "$PLUGIN_CHECK" "$REPO" "$invalid"
done

OUTSIDE="$FIXTURE/specs/outside-feature"
make_feature "$FIXTURE" "outside-feature"
ln -s "$OUTSIDE" "$REPO/specs/linked-feature"
assert_failure_output "invalid feature: linked-feature" \
  "TEST-019 plugin rejects a feature-directory symlink before traversal" \
  sh "$PLUGIN_CHECK" "$REPO" "linked-feature"
assert_failure_output "invalid feature: linked-feature" \
  "TEST-019 root checker rejects a feature-directory symlink before traversal" \
  sh "$ROOT_CHECK" "$REPO" "linked-feature"

make_feature "$REPO" "linked-file"
rm "$REPO/specs/linked-file/design.md"
ln -s "$OUTSIDE/design.md" "$REPO/specs/linked-file/design.md"
assert_failure_output "invalid feature: linked-file" \
  "TEST-019 plugin rejects a feature-file symlink before traversal" \
  sh "$PLUGIN_CHECK" "$REPO" "linked-file"

ROLLBACK="$FIXTURE/rollback"
mkdir -p "$ROLLBACK/baseline" "$ROLLBACK/working"
for relative in \
  plugins/sdd-bootstrap/scripts/check-sdd-structure.sh \
  plugins/sdd-bootstrap/scripts/check-sdd-structure.ps1 \
  scripts/check-sdd-structure.sh; do
  mkdir -p "$ROLLBACK/baseline/$(dirname "$relative")" \
    "$ROLLBACK/working/$(dirname "$relative")"
  cp "$ROOT/$relative" "$ROLLBACK/baseline/$relative"
  cp "$ROOT/$relative" "$ROLLBACK/working/$relative"
done
baseline_hashes=$((cd "$ROLLBACK/baseline" && find . -type f -exec shasum -a 256 {} \;) | sort)
printf '\n# rollback mutation\n' >> \
  "$ROLLBACK/working/plugins/sdd-bootstrap/scripts/check-sdd-structure.sh"
for relative in \
  plugins/sdd-bootstrap/scripts/check-sdd-structure.sh \
  plugins/sdd-bootstrap/scripts/check-sdd-structure.ps1 \
  scripts/check-sdd-structure.sh; do
  cp "$ROLLBACK/baseline/$relative" "$ROLLBACK/working/$relative"
done
restored_hashes=$((cd "$ROLLBACK/working" && find . -type f -exec shasum -a 256 {} \;) | sort)
if [ "$baseline_hashes" = "$restored_hashes" ]; then
  pass "TEST-013 rollback restores baseline checker hashes"
else
  fail "TEST-013 rollback restores baseline checker hashes"
fi
assert_success_output "$BASELINE" "TEST-013 rolled-back plugin checker retains repository-only behavior" \
  sh "$ROLLBACK/working/plugins/sdd-bootstrap/scripts/check-sdd-structure.sh" "$REPO"
assert_success_output "$BASELINE" "TEST-013 rolled-back root checker retains repository-only behavior" \
  sh "$ROLLBACK/working/scripts/check-sdd-structure.sh" "$REPO"

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
