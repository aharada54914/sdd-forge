#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
BUILDER="$ROOT/tests/lib/fixture-matrix-builder.sh"
PASS_COUNT=0
FAIL_COUNT=0
ROOTS_FILE="$(mktemp "${TMPDIR:-/tmp}/fixture-matrix-acceptance.XXXXXX")"

cleanup() {
  while IFS= read -r fixture_root; do
    [ -n "$fixture_root" ] && rm -rf -- "$fixture_root"
  done < "$ROOTS_FILE"
  rm -f -- "$ROOTS_FILE"
}
trap cleanup EXIT

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok %d - %s\n' "$PASS_COUNT" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'not ok %d - %s\n' "$FAIL_COUNT" "$1"
}

assert_true() {
  description=$1
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

if [ ! -f "$BUILDER" ]; then
  fail "fixture matrix builder exists"
  printf 'RESULT: PASS=%d FAIL=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

# shellcheck source=../../../../tests/lib/fixture-matrix-builder.sh
. "$BUILDER"

declare -A SEEN_ROOTS=()

assert_fixture_root() {
  fixture_root=$1
  label=$2
  physical_root="$(cd "$fixture_root" 2>/dev/null && pwd -P)"
  assert_true "$label returns an existing directory" test -d "$fixture_root"
  if [ "$physical_root" = "$fixture_root" ]; then
    pass "$label returns a physically normalized root"
  else
    fail "$label returns a physically normalized root"
  fi
  case "$physical_root" in
    "$ROOT"|"$ROOT"/*) fail "$label root is outside the real repository" ;;
    *) pass "$label root is outside the real repository" ;;
  esac
  if [ -z "${SEEN_ROOTS[$physical_root]+set}" ]; then
    SEEN_ROOTS[$physical_root]=1
    pass "$label root is fresh"
  else
    fail "$label root is fresh"
  fi
}

assert_context() {
  fixture_root=$1
  enforcement=$2
  validity=$3
  label=$4
  context="$fixture_root/sdd/project-context.yaml"
  assert_true "$label writes project context" test -f "$context"
  if awk '
      NR == 1 { ok = ($1 == "schema:" && $2 ~ /^sdd-project-context\/v[01]$/) }
      NR == 2 { ok = ok && ($0 == "workflow:") }
      NR == 3 { ok = ok && ($1 == "spec_profile:" && $2 == "full") }
      NR == 4 { ok = ok && ($1 == "artifact_layout:" && $2 == "legacy-seven-layer") }
      NR == 5 { ok = ok && ($1 == "capability_enforcement:" && $2 == expected) }
      END { exit !(ok && NR == 5) }
    ' expected="$enforcement" "$context"; then
    pass "$label is syntactically valid restricted YAML"
  else
    fail "$label is syntactically valid restricted YAML"
  fi
  expected_schema="sdd-project-context/v1"
  [ "$validity" = "PROJECT_CONTEXT_INVALID" ] && expected_schema="sdd-project-context/v0"
  if [ "$(awk 'NR == 1 { print $2 }' "$context")" = "$expected_schema" ]; then
    pass "$label has the expected schema field"
  else
    fail "$label has the expected schema field"
  fi
}

assert_marker() {
  fixture_root=$1
  marker=$2
  label=$3
  agents="$fixture_root/AGENTS.md"
  if [ "$marker" = "present" ]; then
    assert_true "$label writes AGENTS marker file" test -f "$agents"
    if awk 'NF == 2 && $1 == "spec_profile:" && $2 == "lite" { found = 1 } END { exit !found }' "$agents"; then
      pass "$label writes the lite marker"
    else
      fail "$label writes the lite marker"
    fi
  else
    assert_true "$label omits AGENTS marker file" test ! -e "$agents"
  fi
}

build_and_check() {
  project_context=$1
  marker=$2
  enforcement=$3
  validity=$4
  track_flag=$5
  label=$6
  fixture_root="$(build_fixture "$project_context" "$marker" "$enforcement" "$validity" "$track_flag")"
  rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$fixture_root" ]; then
    fail "$label constructs successfully"
    return
  fi
  printf '%s\n' "$fixture_root" >> "$ROOTS_FILE"
  pass "$label constructs successfully"
  assert_fixture_root "$fixture_root" "$label"
  assert_marker "$fixture_root" "$marker" "$label"
  if [ "$project_context" = "present" ]; then
    assert_context "$fixture_root" "$enforcement" "$validity" "$label"
  else
    assert_true "$label omits project context" test ! -e "$fixture_root/sdd/project-context.yaml"
  fi
  LAST_FIXTURE_ROOT=$fixture_root
}

# F1-F4 and both invalid F3/F4 variants.
build_and_check absent absent disabled-legacy valid none "F1"
build_and_check absent present disabled-legacy valid none "F2"
build_and_check present absent advisory valid none "F3 valid"
F3_VALID_ROOT=$LAST_FIXTURE_ROOT
build_and_check present absent advisory PROJECT_CONTEXT_INVALID none "F3 invalid"
F3_INVALID_ROOT=$LAST_FIXTURE_ROOT
build_and_check present absent required valid none "F4 valid"
F4_VALID_ROOT=$LAST_FIXTURE_ROOT
build_and_check present absent required PROJECT_CONTEXT_INVALID none "F4 invalid"
F4_INVALID_ROOT=$LAST_FIXTURE_ROOT

for pair in "$F3_VALID_ROOT:$F3_INVALID_ROOT:F3" "$F4_VALID_ROOT:$F4_INVALID_ROOT:F4"; do
  valid_root=${pair%%:*}
  remainder=${pair#*:}
  invalid_root=${remainder%%:*}
  label=${pair##*:}
  if ! cmp -s <(sed -n '1p' "$valid_root/sdd/project-context.yaml") <(sed -n '1p' "$invalid_root/sdd/project-context.yaml") &&
    cmp -s <(sed -n '2,$p' "$valid_root/sdd/project-context.yaml") <(sed -n '2,$p' "$invalid_root/sdd/project-context.yaml"); then
    pass "$label invalid YAML differs from valid YAML in exactly the schema field"
  else
    fail "$label invalid YAML differs from valid YAML in exactly the schema field"
  fi
done

assert_named_validator_verdict() {
  context=$1
  expected=$2
  label=$3
  if python3 - "$ROOT" "$context" "$expected" <<'PY'
import importlib.util
import pathlib
import sys

root, context_path, expected = sys.argv[1:]
validator_path = pathlib.Path(root) / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"
spec = importlib.util.spec_from_file_location("fixture_matrix_named_validator", validator_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
info = module.CONTENT_SCHEMA_INFO["sdd-project-context-approval/v1"]
try:
    module._validate_content(context_path, info)
except module.ValidateApprovalSidecarError as exc:
    if expected == "invalid" and exc.category == "CONTENT_SCHEMA_VIOLATION":
        raise SystemExit(0)
    print(f"unexpected validator failure: {exc.category}: {exc.message}", file=sys.stderr)
    raise SystemExit(1)
if expected == "valid":
    raise SystemExit(0)
print("invalid fixture unexpectedly passed validate-approval-sidecar content validation", file=sys.stderr)
raise SystemExit(1)
PY
  then
    pass "$label has the expected validate-approval-sidecar verdict"
  else
    fail "$label has the expected validate-approval-sidecar verdict"
  fi
}

assert_named_validator_verdict "$F3_VALID_ROOT/sdd/project-context.yaml" valid "F3 valid"
assert_named_validator_verdict "$F3_INVALID_ROOT/sdd/project-context.yaml" invalid "F3 invalid"
assert_named_validator_verdict "$F4_VALID_ROOT/sdd/project-context.yaml" valid "F4 valid"
assert_named_validator_verdict "$F4_INVALID_ROOT/sdd/project-context.yaml" invalid "F4 invalid"

# Six legacy CLI cells: each track flag crossed with marker present/absent.
for track_flag in none --full --lite; do
  for marker in present absent; do
    build_and_check absent "$marker" disabled-legacy valid "$track_flag" "legacy $track_flag marker-$marker"
  done
done

for invalid_case in \
  "unknown absent disabled-legacy valid none" \
  "Present absent disabled-legacy valid none" \
  "absent unknown disabled-legacy valid none" \
  "absent absent unknown valid none" \
  "absent absent disabled-legacy unknown none" \
  "absent absent disabled-legacy valid --unknown" \
  "absent absent disabled-legacy valid --FULL" \
  "present absent disabled-legacy valid none"; do
  # Word splitting is intentional: each row is the five-argument public API.
  if build_fixture $invalid_case >/dev/null 2>&1; then
    fail "invalid argument tuple is rejected: $invalid_case"
  else
    pass "invalid argument tuple is rejected: $invalid_case"
  fi
done

under_arity_output="$(build_fixture absent absent disabled-legacy valid 2>&1)"
under_arity_status=$?
if [ "$under_arity_status" -eq 2 ] && [ "$under_arity_output" = 'build_fixture: expected 5 arguments, received 4' ]; then
  pass "a missing fifth argument reaches the explicit arity guard"
else
  fail "a missing fifth argument reaches the explicit arity guard"
fi

if build_fixture absent absent disabled-legacy valid none extra >/dev/null 2>&1; then
  fail "a sixth argument is rejected"
else
  pass "a sixth argument is rejected"
fi

grep -F 'fixture-matrix-builder' "$ROOT/tests/run-all.sh" "$ROOT/tests/run-all.ps1" >/dev/null 2>&1
registration_status=$?
case "$registration_status" in
  0) fail "sourced builder is not registered as an independent suite" ;;
  1) pass "sourced builder is not registered as an independent suite" ;;
  *) fail "sourced builder registration could not be checked (grep exit $registration_status)" ;;
esac

printf 'RESULT: PASS=%d FAIL=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
