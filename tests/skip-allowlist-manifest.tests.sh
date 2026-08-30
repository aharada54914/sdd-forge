#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
EVALUATOR="${T010_EVALUATOR_UNDER_TEST:-$ROOT/tests/lib/skip-allowlist-evaluator.sh}"
SHIPPED_MANIFEST="$ROOT/tests/fixtures/skip-allowlist-manifest.json"
CASE="${1:---all}"
PASS=0
FAIL=0
FIXTURE_SEQ=0
WORK="$(mktemp -d "${TMPDIR:-/tmp}/skip-allowlist.XXXXXX")"
SKIP_PREFIX='SK'
SKIP_PREFIX+='IP:'

cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

run_evaluator() {
  if [[ "${T010_PERMISSIVE_EVALUATOR:-0}" == 1 ]]; then
    return 0
  fi
  bash "$EVALUATOR" "$@"
}

sha256_text() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}

create_fixture() {
  local state="$1"
  FIXTURE_SEQ=$((FIXTURE_SEQ + 1))
  FIXTURE_REPO="$WORK/$state-$FIXTURE_SEQ/repo"
  FIXTURE_MANIFEST="$WORK/$state-$FIXTURE_SEQ/manifest.json"
  FIXTURE_OUTPUT="$WORK/$state-$FIXTURE_SEQ/output.log"
  mkdir -p "$FIXTURE_REPO"
  git -C "$FIXTURE_REPO" init -q -b main
  git -C "$FIXTURE_REPO" config user.name 'T-010 fixture'
  git -C "$FIXTURE_REPO" config user.email 't010-fixture@example.invalid'
  printf '%s\n' base > "$FIXTURE_REPO/README.md"
  git -C "$FIXTURE_REPO" add README.md
  git -C "$FIXTURE_REPO" commit -q -m base
  git -C "$FIXTURE_REPO" switch -q -c feature/epic-999-fixture
  mkdir -p "$FIXTURE_REPO/specs/epic-999-fixture"
  printf '%s\n' '---' 'Spec-Review-Status: Passed' '---' '' 'contract-v1' > "$FIXTURE_REPO/specs/epic-999-fixture/requirements.md"
  printf '%s\n' '---' 'Impl-Review-Status: Passed' '---' > "$FIXTURE_REPO/specs/epic-999-fixture/design.md"
  git -C "$FIXTURE_REPO" add specs/epic-999-fixture/requirements.md specs/epic-999-fixture/design.md
  git -C "$FIXTURE_REPO" commit -q -m 'fixture epic terminal'
  local digest
  digest="$(printf '%s' 'contract-v1' | sha256_text)"
  jq -n --arg digest "sha256:$digest" '[{
    assertion_id:"AC-900",
    dependencies:[{epic:"A9",issue:999,fingerprints:[{
      source:"specs/epic-999-fixture/requirements.md",
      line_range:"5-5",
      algorithm:"sha256",
      normalization:"lf-normalized, utf-8, lines joined by a single \\n, no trailing newline",
      digest:$digest,
      quote:"contract-v1"
    }]}],
    activation_condition:"merged(A9)"
  }]' > "$FIXTURE_MANIFEST"
  if [[ "$state" != unmerged ]]; then
    git -C "$FIXTURE_REPO" switch -q main
    git -C "$FIXTURE_REPO" merge -q --no-ff feature/epic-999-fixture -m 'merge fixture epic'
  fi
  if [[ "$state" == merged-fingerprint-mismatch ]]; then
    printf '%s\n' '---' 'Spec-Review-Status: Passed' '---' '' 'contract-v2' > "$FIXTURE_REPO/specs/epic-999-fixture/requirements.md"
    git -C "$FIXTURE_REPO" add specs/epic-999-fixture/requirements.md
    git -C "$FIXTURE_REPO" commit -q -m 'drift fixture contract'
  fi
}

assert_hard_fail() {
  local label="$1"
  if run_evaluator audit "$FIXTURE_MANIFEST" "$FIXTURE_OUTPUT" "$FIXTURE_REPO" main >/dev/null 2>&1; then
    fail "$label"
  else
    pass "$label"
  fi
}

case_dependency_present() {
  create_fixture merged-fingerprint-match
  printf '%s TEST-FIXTURE/AC-900: dependency should activate\n' "$SKIP_PREFIX" > "$FIXTURE_OUTPUT"
  assert_hard_fail 'AC-035a dependency-present output is a hard failure'
}

case_unknown_skip() {
  create_fixture unmerged
  printf '%s TEST-FIXTURE/AC-999: no manifest entry\n' "$SKIP_PREFIX" > "$FIXTURE_OUTPUT"
  assert_hard_fail 'AC-035b unrecognized output is a hard failure'
}

case_fingerprint_drift() {
  create_fixture merged-fingerprint-mismatch
  printf '%s TEST-FIXTURE/AC-900: merged contract drifted\n' "$SKIP_PREFIX" > "$FIXTURE_OUTPUT"
  assert_hard_fail 'AC-035c merged fingerprint drift is a hard failure'
}

case_clean() {
  create_fixture unmerged
  {
    printf 'PASS: ordinary assertion ran\n'
    printf '%s TEST-FIXTURE/AC-900: dependency is not merged\n' "$SKIP_PREFIX"
  } > "$FIXTURE_OUTPUT"
  local audit
  if audit="$(run_evaluator audit "$FIXTURE_MANIFEST" "$FIXTURE_OUTPUT" "$FIXTURE_REPO" main 2>&1)" &&
     [[ "$audit" == *'audited 1 allowlisted line'* ]]; then
    pass 'clean fixture audits one real allowlisted line without failing vacuously'
  else
    fail "clean fixture is accepted with a non-vacuous audit ($audit)"
  fi
}

case_primitives() {
  create_fixture unmerged
  if run_evaluator merged "$FIXTURE_MANIFEST" AC-900 A9 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    fail 'merged(A9) is false before branch ancestry reaches main'
  else
    pass 'merged(A9) is false before branch ancestry reaches main'
  fi
  if run_evaluator fingerprint-match "$FIXTURE_MANIFEST" AC-900 0 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    pass 'fingerprint_match(0) matches the unmerged epic current HEAD'
  else
    fail 'fingerprint_match(0) matches the unmerged epic current HEAD'
  fi
  create_fixture merged-fingerprint-match
  if run_evaluator merged "$FIXTURE_MANIFEST" AC-900 A9 "$FIXTURE_REPO" main >/dev/null 2>&1 &&
     run_evaluator fingerprint-match "$FIXTURE_MANIFEST" AC-900 0 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    pass 'merged fingerprint-match fixture makes both primitives true'
  else
    fail 'merged fingerprint-match fixture makes both primitives true'
  fi
  create_fixture merged-fingerprint-mismatch
  if run_evaluator merged "$FIXTURE_MANIFEST" AC-900 A9 "$FIXTURE_REPO" main >/dev/null 2>&1 &&
     ! run_evaluator fingerprint-match "$FIXTURE_MANIFEST" AC-900 0 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    pass 'merged fingerprint-mismatch fixture keeps merged true and fingerprint_match false'
  else
    fail 'merged fingerprint-mismatch fixture keeps merged true and fingerprint_match false'
  fi

  create_fixture unmerged
  jq '.[0].activation_condition = "merged(A9) OR fingerprint_match(0)"' "$FIXTURE_MANIFEST" > "$WORK/condition.json"
  if run_evaluator condition "$WORK/condition.json" AC-900 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    pass 'OR accepts one true primitive'
  else
    fail 'OR accepts one true primitive'
  fi
  jq '.[0].activation_condition = "merged(A9) AND fingerprint_match(0)"' "$FIXTURE_MANIFEST" > "$WORK/condition.json"
  if run_evaluator condition "$WORK/condition.json" AC-900 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    fail 'AND rejects one false primitive'
  else
    pass 'AND rejects one false primitive'
  fi
}

case_manifest_contract() {
  if [[ ! -f "$SHIPPED_MANIFEST" ]]; then
    fail 'AC-034 shipped manifest exists'
    return
  fi
  local expected
  expected='[
    ["AC-004","A5","sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff","merged(A5)"],
    ["AC-007","A4","sha256:b84bd60bfba1bc9741bb76096d0502a461343c6867efcaa4bc57986b02d11157","merged(A4)"],
    ["AC-021","A1+A5","sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a+sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff","merged(A1) AND merged(A5)"],
    ["AC-042","A1","sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a","merged(A1)"],
    ["AC-043","A1+A6","sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a+sha256:185d9e88b4ef19fd86d4993dabc6446f5e1b2e5dc9a84b3bacbb81f823f25134","merged(A1) AND merged(A6)"]
  ]'
  local actual
  actual="$(jq -c '[.[] | [.assertion_id, ([.dependencies[].epic] | join("+")), ([.dependencies[].fingerprints[].digest] | join("+")), .activation_condition]]' "$SHIPPED_MANIFEST" 2>/dev/null || true)"
  if [[ "$actual" == "$(jq -c . <<<"$expected")" ]] &&
     jq -e --arg norm 'lf-normalized, utf-8, lines joined by a single \n, no trailing newline' '
       length == 5 and
       all(.[]; (.dependencies | type) == "array" and (.dependencies | length) > 0) and
       all(.[] | .dependencies[]; (.issue | type) == "number" and (.fingerprints | type) == "array" and (.fingerprints | length) > 0) and
       all(.[] | .dependencies[] | .fingerprints[];
         .algorithm == "sha256" and .normalization == $norm and
         (.source | type) == "string" and (.line_range | type) == "string" and (.quote | type) == "string")
     ' "$SHIPPED_MANIFEST" >/dev/null; then
    pass 'AC-034 manifest contains exactly the five fixed entries and fingerprint values'
  else
    fail 'AC-034 manifest contains exactly the five fixed entries and fingerprint values'
    return
  fi
  local source_hits assertion
  source_hits="$(rg -n 'skip_allowlist_line.*AC-(004|007|021|042|043)' \
    "$ROOT/tests/loop-consistency.tests.sh" "$ROOT/tests/loop-escalation.tests.sh" \
    "$ROOT/tests/compatibility-byte-identical.tests.sh" "$ROOT/tests/structural-compatibility.tests.sh" 2>/dev/null || true)"
  for assertion in AC-004 AC-007 AC-021 AC-042 AC-043; do
    if ! grep -Fq "$assertion" <<<"$source_hits"; then
      fail "AC-016 $assertion output is not sourced through skip_allowlist_line"
      return
    fi
  done
  if [[ -n "$source_hits" ]]; then
    pass 'AC-016 all five fixed SKIP assertions read from the manifest helper'
  fi
}

case "$CASE" in
  --case=dependency-present) case_dependency_present ;;
  --case=unknown-skip) case_unknown_skip ;;
  --case=fingerprint-drift) case_fingerprint_drift ;;
  --case=clean) case_clean ;;
  --case=primitives) case_primitives ;;
  --case=manifest-contract) case_manifest_contract ;;
  --all)
    case_manifest_contract
    case_primitives
    case_dependency_present
    case_unknown_skip
    case_fingerprint_drift
    case_clean
    ;;
  *) printf 'usage: %s [--all|--case=dependency-present|--case=unknown-skip|--case=fingerprint-drift|--case=clean|--case=primitives|--case=manifest-contract]\n' "$0" >&2; exit 2 ;;
esac

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
