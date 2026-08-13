#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RESOLVER_SH="$ROOT/plugins/sdd-quality-loop/scripts/resolve-component-paths.sh"
RESOLVER_PS="$ROOT/plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1"
COVERAGE_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-component-coverage.sh"
COVERAGE_PS="$ROOT/plugins/sdd-quality-loop/scripts/check-component-coverage.ps1"
RESOLVER_FIXTURE="$ROOT/tests/fixtures/component-path-ownership/test-016-overlap"
COVERAGE_FIXTURE="$ROOT/tests/fixtures/check-component-coverage"
FEATURE_ROOT="$ROOT/specs/epic-191-a3-path-ownership"
ACCEPTANCE="$FEATURE_ROOT/acceptance-tests.md"
TRACEABILITY="$FEATURE_ROOT/traceability.md"
HUMAN_COPY="$FEATURE_ROOT/human-copy"
STAGED_WORKFLOW="$HUMAN_COPY/.github/workflows/test.yml"
MANIFEST="$HUMAN_COPY/MANIFEST.sha256"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf 'ok - %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf 'not ok - %s\n' "$1"
}

assert_equal() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (shell=[$actual], pwsh=[$expected])"
  fi
}

canonical_json() {
  jq -S -c . "$1" 2>/dev/null | tr -d '\r\n'
}

run_shell() {
  local stem="$1"
  shift
  bash "$@" >"$TMP/$stem.stdout" 2>"$TMP/$stem.stderr"
  printf '%s' "$?" >"$TMP/$stem.exit"
}

run_pwsh() {
  local stem="$1"
  shift
  pwsh -NoProfile -File "$@" >"$TMP/$stem.stdout" 2>"$TMP/$stem.stderr"
  printf '%s' "$?" >"$TMP/$stem.exit"
}

error_category() {
  local stem="$1" probe="$2" status
  status="$(<"$TMP/$stem.exit")"
  if [[ "$status" == "0" ]]; then
    printf 'accepted'
  elif rg -F -q -- "$probe" "$TMP/$stem.stderr"; then
    printf 'rejected-named-extra'
  elif [[ -s "$TMP/$stem.stderr" ]]; then
    sed -n '1{s/:.*//;p;}' "$TMP/$stem.stderr" | tr -d '\r\n'
  else
    printf 'rejected-without-category'
  fi
}

registration_audit() {
  local run_sh="$1" run_ps="$2" workflow="$3" suite sh_count ps_count ci_sh_count ci_ps_count
  shift 3
  for suite in "$@"; do
    sh_count="$(rg -F -c "tests/$suite.tests.sh" "$run_sh" 2>/dev/null || true)"
    ps_count="$(rg -F -c "tests/$suite.tests.ps1" "$run_ps" 2>/dev/null || true)"
    ci_sh_count="$(rg -F -c "tests/$suite.tests.sh" "$workflow" 2>/dev/null || true)"
    ci_ps_count="$(rg -F -c "tests/$suite.tests.ps1" "$workflow" 2>/dev/null || true)"
    if [[ "$sh_count" != "1" || "$ps_count" != "1" || "$ci_sh_count" != "1" || "$ci_ps_count" != "1" ]]; then
      return 1
    fi
  done
}

for required in "$RESOLVER_SH" "$RESOLVER_PS" "$COVERAGE_SH" "$COVERAGE_PS" \
  "$RESOLVER_FIXTURE/config.yaml" "$RESOLVER_FIXTURE/changed-paths.txt" \
  "$COVERAGE_FIXTURE/config-required.yaml" \
  "$COVERAGE_FIXTURE/facet-manifest-full.json" \
  "$COVERAGE_FIXTURE/changed-paths-clean.txt"; do
  if [[ ! -f "$required" ]]; then
    fail "TEST-050 requires shipped surface $required"
  fi
done

# TEST-050: recognized resolver argv, canonical JSON, and exit status are
# compared between the real product entry points. Expected output is derived
# only by executing those entry points; no output value is copied into here.
run_shell resolver-sh "$RESOLVER_SH" \
  --config "$RESOLVER_FIXTURE/config.yaml" \
  --changed-paths-file "$RESOLVER_FIXTURE/changed-paths.txt"
run_pwsh resolver-ps "$RESOLVER_PS" \
  -Config "$RESOLVER_FIXTURE/config.yaml" \
  -ChangedPathsFile "$RESOLVER_FIXTURE/changed-paths.txt"
resolver_sh_json="$(canonical_json "$TMP/resolver-sh.stdout")"
resolver_ps_json="$(canonical_json "$TMP/resolver-ps.stdout")"
if [[ -n "$resolver_sh_json" && -n "$resolver_ps_json" ]]; then
  pass "TEST-050 resolver outputs parse as JSON"
else
  fail "TEST-050 resolver outputs parse as JSON"
fi
assert_equal "TEST-050 resolver canonical stdout parity" "$resolver_sh_json" "$resolver_ps_json"
assert_equal "TEST-050 resolver exit parity" "$(<"$TMP/resolver-sh.exit")" "$(<"$TMP/resolver-ps.exit")"

# TEST-050: the real coverage pair is exercised with the same shipped fixture.
# Its warning strings are part of the canonical output comparison.
run_shell coverage-sh "$COVERAGE_SH" \
  --config "$COVERAGE_FIXTURE/config-required.yaml" \
  --facet-manifest "$COVERAGE_FIXTURE/facet-manifest-full.json" \
  --changed-paths-file "$COVERAGE_FIXTURE/changed-paths-clean.txt"
run_pwsh coverage-ps "$COVERAGE_PS" \
  -Config "$COVERAGE_FIXTURE/config-required.yaml" \
  -FacetManifest "$COVERAGE_FIXTURE/facet-manifest-full.json" \
  -ChangedPathsFile "$COVERAGE_FIXTURE/changed-paths-clean.txt"
coverage_sh_json="$(canonical_json "$TMP/coverage-sh.stdout")"
coverage_ps_json="$(canonical_json "$TMP/coverage-ps.stdout")"
if [[ -n "$coverage_sh_json" && -n "$coverage_ps_json" ]]; then
  pass "TEST-050 coverage outputs parse as JSON"
else
  fail "TEST-050 coverage outputs parse as JSON"
fi
assert_equal "TEST-050 coverage canonical stdout and warning parity" "$coverage_sh_json" "$coverage_ps_json"
assert_equal "TEST-050 coverage exit and LASTEXITCODE parity" "$(<"$TMP/coverage-sh.exit")" "$(<"$TMP/coverage-ps.exit")"

# Derive a unique extra argument from the shipped suite itself, feed equivalent
# argv to both real runtimes, and compare behavior. Under the amended delivery
# split the resolver cells are GREEN now; the protected live coverage twin's
# cells remain designed RED until the staged candidate is human-applied.
probe_digest="$(shasum -a 256 "$0" | awk '{print substr($1,1,12)}')"
probe="parity-probe-$probe_digest"
run_shell resolver-extra-sh "$RESOLVER_SH" \
  --config "$RESOLVER_FIXTURE/config.yaml" \
  --changed-paths-file "$RESOLVER_FIXTURE/changed-paths.txt" \
  "--$probe"
run_pwsh resolver-extra-ps "$RESOLVER_PS" \
  -Config "$RESOLVER_FIXTURE/config.yaml" \
  -ChangedPathsFile "$RESOLVER_FIXTURE/changed-paths.txt" \
  "-$probe"
assert_equal "TEST-050 resolver extra-argument exit parity" \
  "$(<"$TMP/resolver-extra-sh.exit")" "$(<"$TMP/resolver-extra-ps.exit")"
assert_equal "TEST-050 resolver extra-argument category parity" \
  "$(error_category resolver-extra-sh "$probe")" \
  "$(error_category resolver-extra-ps "$probe")"

run_shell coverage-extra-sh "$COVERAGE_SH" \
  --config "$COVERAGE_FIXTURE/config-required.yaml" \
  --facet-manifest "$COVERAGE_FIXTURE/facet-manifest-full.json" \
  --changed-paths-file "$COVERAGE_FIXTURE/changed-paths-clean.txt" \
  "--$probe"
run_pwsh coverage-extra-ps "$COVERAGE_PS" \
  -Config "$COVERAGE_FIXTURE/config-required.yaml" \
  -FacetManifest "$COVERAGE_FIXTURE/facet-manifest-full.json" \
  -ChangedPathsFile "$COVERAGE_FIXTURE/changed-paths-clean.txt" \
  "-$probe"
assert_equal "TEST-050 coverage extra-argument exit parity" \
  "$(<"$TMP/coverage-extra-sh.exit")" "$(<"$TMP/coverage-extra-ps.exit")"
assert_equal "TEST-050 coverage extra-argument category parity" \
  "$(error_category coverage-extra-sh "$probe")" \
  "$(error_category coverage-extra-ps "$probe")"

# Non-vacuity: both disposable PowerShell mutants remain correct for the
# recognized invocation but diverge on the same real extra-argument oracle.
# The first drops the automatic argument tail; the second forwards it but
# discards the child process status. Neither mutant replaces a product path.
export T006_REAL_RESOLVER="$RESOLVER_PS"
cat >"$TMP/argument-drop-mutant.ps1" <<'PWSH'
param([string]$Config, [string]$ChangedPathsFile)
& $env:T006_REAL_RESOLVER -Config $Config -ChangedPathsFile $ChangedPathsFile
exit $LASTEXITCODE
PWSH
cat >"$TMP/child-exit-mutant.ps1" <<'PWSH'
param([string]$Config, [string]$ChangedPathsFile)
& $env:T006_REAL_RESOLVER -Config $Config -ChangedPathsFile $ChangedPathsFile @args
exit 0
PWSH
run_pwsh mutant-drop-recognized "$TMP/argument-drop-mutant.ps1" \
  -Config "$RESOLVER_FIXTURE/config.yaml" \
  -ChangedPathsFile "$RESOLVER_FIXTURE/changed-paths.txt"
run_pwsh mutant-drop-extra "$TMP/argument-drop-mutant.ps1" \
  -Config "$RESOLVER_FIXTURE/config.yaml" \
  -ChangedPathsFile "$RESOLVER_FIXTURE/changed-paths.txt" "-$probe"
if [[ "$(canonical_json "$TMP/mutant-drop-recognized.stdout")" == "$resolver_sh_json" \
   && "$(<"$TMP/mutant-drop-recognized.exit")" == "$(<"$TMP/resolver-sh.exit")" \
   && ( "$(<"$TMP/mutant-drop-extra.exit")" != "$(<"$TMP/resolver-extra-sh.exit")" \
     || "$(error_category mutant-drop-extra "$probe")" != "$(error_category resolver-extra-sh "$probe")" ) ]]; then
  pass "TEST-050 disposable argument-drop mutant is detected"
else
  fail "TEST-050 disposable argument-drop mutant is detected"
fi
run_pwsh mutant-exit-recognized "$TMP/child-exit-mutant.ps1" \
  -Config "$RESOLVER_FIXTURE/config.yaml" \
  -ChangedPathsFile "$RESOLVER_FIXTURE/changed-paths.txt"
run_pwsh mutant-exit-extra "$TMP/child-exit-mutant.ps1" \
  -Config "$RESOLVER_FIXTURE/config.yaml" \
  -ChangedPathsFile "$RESOLVER_FIXTURE/changed-paths.txt" "-$probe"
if [[ "$(canonical_json "$TMP/mutant-exit-recognized.stdout")" == "$resolver_sh_json" \
   && "$(<"$TMP/mutant-exit-recognized.exit")" == "$(<"$TMP/resolver-sh.exit")" \
   && ( "$(<"$TMP/mutant-exit-extra.exit")" != "$(<"$TMP/resolver-extra-sh.exit")" \
     || "$(error_category mutant-exit-extra "$probe")" != "$(error_category resolver-extra-sh "$probe")" ) ]]; then
  pass "TEST-050 disposable child-exit mutant is detected"
else
  fail "TEST-050 disposable child-exit mutant is detected"
fi
unset T006_REAL_RESOLVER

# Suite names and acceptance inventory are read from the frozen specification,
# so the audit cannot silently retain a hand-copied list when the contract moves.
suite_bases=()
while IFS= read -r suite; do
  suite_bases+=("$suite")
done < <(rg -o 'tests/[a-z0-9-]+\.tests' "$TRACEABILITY" \
  | sed 's#tests/##;s#\.tests##' | LC_ALL=C sort -u)
if [[ "${#suite_bases[@]}" -gt 0 ]] \
  && registration_audit "$ROOT/tests/run-all.sh" "$ROOT/tests/run-all.ps1" "$STAGED_WORKFLOW" "${suite_bases[@]}"; then
  pass "TEST-047 all spec-declared suites are registered once in both runners and staged CI"
else
  fail "TEST-047 all spec-declared suites are registered once in both runners and staged CI"
fi

parity_suite="$(basename "$0" .tests.sh)"
if [[ "$(rg -F -c "tests/$parity_suite.tests.sh" "$ROOT/tests/run-all.sh" || true)" == "1" \
   && "$(rg -F -c "tests/$parity_suite.tests.ps1" "$ROOT/tests/run-all.ps1" || true)" == "1" \
   && "$(rg -F -c "tests/$parity_suite.tests.sh" "$STAGED_WORKFLOW" || true)" == "1" \
   && "$(rg -F -c "tests/$parity_suite.tests.ps1" "$STAGED_WORKFLOW" || true)" == "1" ]]; then
  pass "TEST-051 parity harness self-registration"
else
  fail "TEST-051 parity harness self-registration"
fi

manifest_output="$(cd "$HUMAN_COPY" && shasum -a 256 -c MANIFEST.sha256 2>&1)"
manifest_status=$?
if [[ "$manifest_status" == "0" ]]; then
  pass "TEST-051 staged candidates match every manifest row"
else
  fail "TEST-051 staged candidates match every manifest row ($manifest_output)"
fi

cp "$ROOT/tests/run-all.sh" "$TMP/run-all-mutant.sh"
first_suite="${suite_bases[0]:-}"
python3 - "$TMP/run-all-mutant.sh" "tests/$first_suite.tests.sh" <<'PY'
import pathlib
import sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace(sys.argv[2], '', 1))
PY
if [[ -n "$first_suite" ]] \
  && ! registration_audit "$TMP/run-all-mutant.sh" "$ROOT/tests/run-all.ps1" "$STAGED_WORKFLOW" "${suite_bases[@]}"; then
  pass "TEST-047 registration audit rejects a disposable missing-suite mutant"
else
  fail "TEST-047 registration audit rejects a disposable missing-suite mutant"
fi

ac047="$(rg '^\| AC-047 ' "$ACCEPTANCE")"
behavior_span="$(printf '%s\n' "$ac047" | sed -E 's/.*each of ([^|]+) has .*/\1/')"
behavior_audit_ok=1
green_corpus="$(find "$FEATURE_ROOT/verification" -type f -name '*GREEN*' -exec cat {} + 2>/dev/null)"
red_corpus="$(find "$FEATURE_ROOT/verification" -type f -name '*RED*' -exec cat {} + 2>/dev/null)"
suite_sources=()
for suite in "${suite_bases[@]}"; do
  suite_sources+=("$ROOT/tests/$suite.tests.sh" "$ROOT/tests/$suite.tests.ps1")
done
while IFS= read -r behavior; do
  behavior="$(printf '%s' "$behavior" | xargs)"
  [[ -n "$behavior" ]] || continue
  stem="${behavior%%-*}"
  if ! rg -i -q "(ok|Pass).*${stem}" "${suite_sources[@]}" \
    || ! rg -i -q "(fail|Fail).*${stem}" "${suite_sources[@]}" \
    || ! printf '%s' "$green_corpus" | rg -i -q "$stem" \
    || ! printf '%s' "$red_corpus" | rg -i -q "$stem"; then
    behavior_audit_ok=0
  fi
done < <(printf '%s' "$behavior_span" | tr ',/' '\n')
if [[ "$behavior_audit_ok" == "1" ]]; then
  pass "TEST-047 spec-declared behavior branches have positive and red-then-fixed evidence"
else
  fail "TEST-047 spec-declared behavior branches have positive and red-then-fixed evidence"
fi

fixture_audit_ok=1
while IFS='|' read -r _ ac _ test_id _; do
  ac="$(printf '%s' "$ac" | xargs)"
  test_id="$(printf '%s' "$test_id" | xargs | sed 's/TEST-//')"
  if [[ "$ac" =~ ^AC-00[6-9]$ ]] \
    && ! find "$ROOT/tests/fixtures/component-path-ownership" -maxdepth 1 -type d -name "test-$test_id*" | rg -q .; then
    fixture_audit_ok=0
  fi
done < "$ACCEPTANCE"
nfc_id="$(rg '^\| AC-010 ' "$ACCEPTANCE" | sed -E 's/.*\| TEST-([0-9]+) \|.*/\1/')"
if ! find "$ROOT/tests/fixtures/component-path-ownership" -maxdepth 1 -type d -name "test-$nfc_id*" | rg -q .; then
  fixture_audit_ok=0
fi
ac024="$(rg '^\| AC-024 ' "$ACCEPTANCE")"
ref_test="$(printf '%s' "$ac024" | sed -E 's/.*\| TEST-([0-9]+) \|.*/\1/')"
ref_count="$(printf '%s' "$ac024" | sed -E 's/.*\(([0-9]+) fixtures\).*/\1/')"
for ((i=1; i<=ref_count; i++)); do
  if ! rg -F -q "TEST-$ref_test.$i" "$ROOT/tests/component-path-diff-basis.tests.sh" \
    || ! rg -F -q "TEST-$ref_test.$i" "$ROOT/tests/component-path-diff-basis.tests.ps1"; then
    fixture_audit_ok=0
  fi
done
if [[ "$fixture_audit_ok" == "1" ]]; then
  pass "TEST-047 glob, NFC-collision, and reference-only fixture inventory"
else
  fail "TEST-047 glob, NFC-collision, and reference-only fixture inventory"
fi

if git diff --quiet -- .github/workflows/test.yml; then
  pass "TEST-047 live protected workflow remains byte-unchanged"
else
  fail "TEST-047 live protected workflow remains byte-unchanged"
fi

# Derive release surfaces from the repository's only sanctioned mutation path.
# The common task path proves that none changed.  The content fallback is what
# keeps this baseline valid after a real bump-version.sh replay: every surface
# must converge on the validator's newly shipped version.  This is the same
# full-tree/content-fallback shape used for shallow-history-safe assertions.
version_mutation=0
while IFS= read -r release_surface; do
  [[ -n "$release_surface" ]] || continue
  if ! git diff --quiet -- "$release_surface"; then
    version_mutation=1
  fi
done < <(find "$ROOT/plugins" -type f \( -path '*/.claude-plugin/plugin.json' -o -path '*/.codex-plugin/plugin.json' -o -path '*/.plugin/plugin.json' \) -print \
  | sed "s#^$ROOT/##"; printf '%s\n' .claude-plugin/marketplace.json .agents/plugins/marketplace.json README.md tests/validate-repository.ps1 tests/repository-release-validation.tests.sh)
release_sync=1
shipped_version="$(sed -n 's/.*"sdd-ship"[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' "$ROOT/tests/validate-repository.ps1" | head -1)"
[[ -n "$shipped_version" ]] || release_sync=0
while IFS= read -r manifest; do
  [[ "$(jq -r '.version' "$manifest" | tr -d '\r')" == "$shipped_version" ]] || release_sync=0
done < <(find "$ROOT/plugins" -type f \( -path '*/.claude-plugin/plugin.json' -o -path '*/.codex-plugin/plugin.json' -o -path '*/.plugin/plugin.json' \) -print)
for marketplace in "$ROOT/.claude-plugin/marketplace.json" "$ROOT/.agents/plugins/marketplace.json"; do
  if jq -er --arg version "$shipped_version" \
    '[.. | objects | select(has("version")) | .version] | length > 0 and all(. == $version)' \
    "$marketplace" >/dev/null; then
    :
  else
    release_sync=0
  fi
done
readme_version="$(sed -n 's/^v\([0-9][0-9.]*\).*/\1/p' "$ROOT/README.md" | head -1)"
[[ "$readme_version" == "$shipped_version" ]] || release_sync=0
rg -F -q "$shipped_version" "$ROOT/tests/repository-release-validation.tests.sh" || release_sync=0
if [[ "$version_mutation" == "0" || "$release_sync" == "1" ]]; then
  pass "TEST-049 release surfaces are untouched or synchronized by bump-version"
else
  fail "TEST-049 release surfaces are untouched or synchronized by bump-version"
fi

task_id="$(rg '^\| T-006 ' "$TRACEABILITY" | head -1 | cut -d'|' -f2 | xargs)"
issue_id="$(rg '^\| AC-048 ' "$ACCEPTANCE" | rg -o '#[0-9]+' | head -1)"
if rg -U -q "${task_id}(.|\n){0,160}${issue_id}|${issue_id}(.|\n){0,160}${task_id}" "$ROOT/CHANGELOG.md"; then
  pass "TEST-048 task changelog registration survives release-heading replay"
else
  fail "TEST-048 task changelog registration survives release-heading replay"
fi

printf '\nResults: %d passed, %d failed\n' "$passed" "$failed"
if (( failed > 0 )); then
  exit 1
fi
