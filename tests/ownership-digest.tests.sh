#!/usr/bin/env bash
# T-003 ownership-digest acceptance suite (AC-037..AC-041, AC-048..049).
# Drives the POSIX resolver entry point; the PowerShell twin drives the
# independent PowerShell implementation. T003_ONLY and T003_MUTATE_ASSERTION
# exist solely for the saved mutation-proof transcript.
set -u

REPO_ROOT="${T003_SOURCE_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
RESOLVER="${T003_RESOLVER:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.sh}"
CANONICALIZER="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py"
ONLY="${T003_ONLY:-}"
MUTATE="${T003_MUTATE_ASSERTION:-}"
PASS=0
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

should_run() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }
is_mutated() { [ "$MUTATE" = "$1" ]; }
ok() { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() {
  local label="$1" description="$2" result="$3"
  if [ "$result" = 1 ]; then ok "$label: $description"; else fail "$label: $description"; fi
}

resolve() {
  local config="$1" paths="$2" resolver="${3:-$RESOLVER}"
  "$resolver" --config "$config" --changed-paths-file "$paths"
}
digest_of() { printf '%s' "$1" | jq -r '.context_binding.ownership_digest // ""' | tr -d '\r'; }
rule_revision_of() { printf '%s' "$1" | jq -r '.resolver.rule_set_revision // ""' | tr -d '\r'; }
semantic_of() { printf '%s' "$1" | jq -cS 'del(.ownership_input,.context_binding,.resolver)' | tr -d '\r'; }
classification_of() { printf '%s' "$1" | jq -r --arg p "$2" '.records[] | select(.raw_path == $p) | .classification' | tr -d '\r'; }

cat >"$TMP/base.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
      exclude:
        - "src/desktop/generated/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
      exclude:
        - "src/mobile/generated/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
shared_paths:
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    components:
      - desktop
      - mobile
YAML

cat >"$TMP/owner-added.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
  - id: newcomer
    paths:
      include:
        - "src/new/**"
YAML

cat >"$TMP/owner-absent.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
YAML

cat >"$TMP/nonmatch-before.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: outside-owner
    paths:
      include:
        - "elsewhere/**"
YAML

cat >"$TMP/nonmatch-after.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: outside-owner
    paths:
      include:
        - "outside/**"
YAML

cat >"$TMP/bounded-before.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
shared_paths:
  - pattern: "contracts/**"
    components:
      - desktop
      - mobile
YAML

cat >"$TMP/bounded-after.yaml" <<'YAML'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
shared_paths:
  - pattern: "contracts/**"
    components:
      - mobile
      - legacy
YAML

printf 'src/desktop/app.py\n' >"$TMP/desktop.paths"
printf 'src/mobile/app.py\n' >"$TMP/mobile.paths"
printf 'src/new/file.py\n' >"$TMP/new.paths"
printf 'outside/file.py\n' >"$TMP/outside.paths"

base_desktop="$(resolve "$TMP/base.yaml" "$TMP/desktop.paths")"
base_mobile="$(resolve "$TMP/base.yaml" "$TMP/mobile.paths")"

if should_run TEST-037; then
  printf '%s' "$base_desktop" | jq '.ownership_input' >"$TMP/ownership-input.json"
  expected="$(python3 "$CANONICALIZER" "$TMP/ownership-input.json" --input-format json --hash-only)"
  actual="$(digest_of "$base_desktop")"
  mobile_actual="$(digest_of "$base_mobile")"
  complete="$(printf '%s' "$base_desktop" | jq -e '
    .ownership_input.components == [
      {id:"desktop",paths:{include:["src/desktop/**"],exclude:["src/desktop/generated/**"]}},
      {id:"mobile",paths:{include:["src/mobile/**"],exclude:["src/mobile/generated/**"]}},
      {id:"legacy",paths:{include:["legacy/**"],exclude:[]}}
    ] and
    .ownership_input.shared_paths == [
      {pattern:"docs/**",components:null,classification:"cross-cutting"},
      {pattern:"contracts/**",components:["desktop","mobile"],classification:null}
    ] and (.ownership_input.matcher_semantics_version | type == "string" and length > 0)' >/dev/null 2>&1; echo $?)"
  if is_mutated TEST-037; then expected='sha256:0000000000000000000000000000000000000000000000000000000000000000'; printf 'MUTATION: TEST-037 replaces the canonical full-input digest expectation\n'; fi
  result=0; [ "$complete" = 0 ] && [ -n "$actual" ] && [ "$actual" = "$expected" ] && [ "$actual" = "$mobile_actual" ] && result=1
  check TEST-037 'digest covers the complete declared ownership input and is Feature-independent' "$result"
fi

if should_run TEST-038A; then
  result="$(printf '%s' "$base_desktop" | jq -e '
    (.context_binding | keys) == ["ownership_digest"] and
    (.context_binding.ownership_digest | test("^sha256:[0-9a-f]{64}$")) and
    (.resolver.version | type == "string" and length > 0) and
    (.resolver.rule_set_revision | test("^sha256:[0-9a-f]{64}$"))' >/dev/null 2>&1; echo $?)"
  if is_mutated TEST-038A; then result=1; printf 'MUTATION: TEST-038A removes the required context binding from the observed contract\n'; fi
  [ "$result" = 0 ] && result=1 || result=0
  check TEST-038A 'context_binding and resolver metadata have the ADR-0021 shape' "$result"
fi

if should_run TEST-038B; then
  semantic="$(semantic_of "$base_desktop")"
  metadata_mutant="$(printf '%s' "$base_desktop" | jq -c '.context_binding.ownership_digest="sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" | .resolver.version="99.0.0" | .resolver.rule_set_revision="sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"')"
  mutant_semantic="$(semantic_of "$metadata_mutant")"
  if is_mutated TEST-038B; then mutant_semantic='{"mutated":true}'; printf 'MUTATION: TEST-038B leaks metadata into the semantic comparison projection\n'; fi
  result=0; [ "$semantic" = "$mutant_semantic" ] && result=1
  check TEST-038B 'context_binding, resolver metadata, and ownership_input are excluded from semantic output comparison' "$result"
fi

if should_run TEST-039; then
  before="$(resolve "$TMP/nonmatch-before.yaml" "$TMP/desktop.paths")"
  after="$(resolve "$TMP/nonmatch-after.yaml" "$TMP/desktop.paths")"
  outside_before="$(resolve "$TMP/nonmatch-before.yaml" "$TMP/outside.paths")"
  outside_after="$(resolve "$TMP/nonmatch-after.yaml" "$TMP/outside.paths")"
  before_digest="$(digest_of "$before")"; after_digest="$(digest_of "$after")"
  if is_mutated TEST-039; then after_digest="$before_digest"; printf 'MUTATION: TEST-039 substitutes the stale evaluated-only digest\n'; fi
  result=0
  [ -n "$before_digest" ] && [ "$before_digest" != "$after_digest" ] \
    && [ "$(semantic_of "$before")" = "$(semantic_of "$after")" ] \
    && [ "$(classification_of "$outside_before" outside/file.py)" = UNOWNED ] \
    && [ "$(classification_of "$outside_after" outside/file.py)" = EXCLUSIVE ] \
    && result=1
  check TEST-039 'a nonmatching-to-matching rule edit changes the digest without staling unchanged Feature semantics' "$result"
fi

matrix_case() {
  local label="$1" before_config="$2" after_config="$3" paths="$4" expected_semantic="$5" expected_digest="$6"
  should_run "$label" || return 0
  local before after b_digest a_digest semantic_changed digest_changed result=0
  before="$(resolve "$before_config" "$paths")"; after="$(resolve "$after_config" "$paths")"
  b_digest="$(digest_of "$before")"; a_digest="$(digest_of "$after")"
  if is_mutated "$label"; then a_digest="$b_digest"; printf 'MUTATION: %s collapses the after digest to the before digest\n' "$label"; fi
  semantic_changed=0; [ "$(semantic_of "$before")" != "$(semantic_of "$after")" ] && semantic_changed=1
  digest_changed=0; [ -n "$b_digest" ] && [ "$b_digest" != "$a_digest" ] && digest_changed=1
  [ "$semantic_changed" = "$expected_semantic" ] && [ "$digest_changed" = "$expected_digest" ] && result=1
  check "$label" "ownership freshness matrix semantic=$expected_semantic digest=$expected_digest" "$result"
}

matrix_case TEST-040A "$TMP/owner-absent.yaml" "$TMP/owner-added.yaml" "$TMP/new.paths" 1 1
matrix_case TEST-040B "$TMP/owner-added.yaml" "$TMP/owner-absent.yaml" "$TMP/new.paths" 1 1
matrix_case TEST-040C "$TMP/nonmatch-before.yaml" "$TMP/nonmatch-after.yaml" "$TMP/desktop.paths" 0 1
matrix_case TEST-040D "$TMP/bounded-before.yaml" "$TMP/bounded-after.yaml" "$TMP/desktop.paths" 0 1

if should_run TEST-040E; then
  d1_before="$(resolve "$TMP/nonmatch-before.yaml" "$TMP/desktop.paths")"; d1_after="$(resolve "$TMP/nonmatch-after.yaml" "$TMP/desktop.paths")"
  d2_before="$(resolve "$TMP/nonmatch-before.yaml" "$TMP/mobile.paths")"; d2_after="$(resolve "$TMP/nonmatch-after.yaml" "$TMP/mobile.paths")"
  after_digest="$(digest_of "$d1_after")"
  if is_mutated TEST-040E; then after_digest="$(digest_of "$d1_before")"; printf 'MUTATION: TEST-040E preserves one Feature digest across the disjoint edit\n'; fi
  result=0
  [ "$(semantic_of "$d1_before")" = "$(semantic_of "$d1_after")" ] \
    && [ "$(semantic_of "$d2_before")" = "$(semantic_of "$d2_after")" ] \
    && [ -n "$(digest_of "$d1_before")" ] \
    && [ "$(digest_of "$d1_before")" = "$(digest_of "$d2_before")" ] \
    && [ "$after_digest" = "$(digest_of "$d2_after")" ] \
    && [ "$(digest_of "$d1_before")" != "$after_digest" ] \
    && result=1
  check TEST-040E 'a disjoint edit invalidates all Feature digests simultaneously without semantic stale' "$result"
fi

if should_run TEST-040F; then
  mutant_dir="$TMP/matcher"
  mkdir -p "$mutant_dir"
  cp "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py" "$mutant_dir/resolve-component-paths.py"
  cp "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py" "$mutant_dir/canonicalize-sdd-yaml.py"
  cp "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.sh" "$mutant_dir/resolve-component-paths.sh"
  sed 's/MATCHER_SEMANTICS_VERSION = "1.0.0"/MATCHER_SEMANTICS_VERSION = "1.0.1"/' "$mutant_dir/resolve-component-paths.py" >"$mutant_dir/version.py"
  mv "$mutant_dir/version.py" "$mutant_dir/resolve-component-paths.py"
  chmod +x "$mutant_dir/resolve-component-paths.sh" "$mutant_dir/resolve-component-paths.py" "$mutant_dir/canonicalize-sdd-yaml.py"
  cat >"$TMP/star.yaml" <<'YAML'
components:
  - id: star
    paths:
      include:
        - "src/*"
YAML
  printf 'src/nested/file.py\n' >"$TMP/star.paths"
  original="$(resolve "$TMP/star.yaml" "$TMP/star.paths")"
  bumped="$(resolve "$TMP/star.yaml" "$TMP/star.paths" "$mutant_dir/resolve-component-paths.sh")"
  perl -0pi -e 's{\Qif seg == "**":\E}{if seg in ("**", "*"):}g' "$mutant_dir/resolve-component-paths.py"
  semantics="$(resolve "$TMP/star.yaml" "$TMP/star.paths" "$mutant_dir/resolve-component-paths.sh")"
  semantics_class="$(classification_of "$semantics" src/nested/file.py)"
  if is_mutated TEST-040F; then semantics_class="$(classification_of "$original" src/nested/file.py)"; printf 'MUTATION: TEST-040F hides the changed matcher classification\n'; fi
  result=0
  [ "$(semantic_of "$original")" = "$(semantic_of "$bumped")" ] \
    && [ "$(digest_of "$original")" != "$(digest_of "$bumped")" ] \
    && [ "$(rule_revision_of "$original")" != "$(rule_revision_of "$bumped")" ] \
    && [ "$(rule_revision_of "$bumped")" = "$(rule_revision_of "$semantics")" ] \
    && [ "$semantics_class" != "$(classification_of "$original" src/nested/file.py)" ] \
    && [ "$(digest_of "$bumped")" = "$(digest_of "$semantics")" ] \
    && [ "$(semantic_of "$bumped")" != "$(semantic_of "$semantics")" ] \
    && result=1
  check TEST-040F 'version-only bumps refresh metadata only; semantic matcher changes stale affected output' "$result"
fi

if should_run TEST-041; then
  wiring_count=0
  run_all_sh="$REPO_ROOT/tests/run-all.sh"
  run_all_ps1="$REPO_ROOT/tests/run-all.ps1"
  [ -f "$REPO_ROOT/specs/epic-191-a3-path-ownership/human-copy/tests/run-all.sh" ] && run_all_sh="$REPO_ROOT/specs/epic-191-a3-path-ownership/human-copy/tests/run-all.sh"
  [ -f "$REPO_ROOT/specs/epic-191-a3-path-ownership/human-copy/tests/run-all.ps1" ] && run_all_ps1="$REPO_ROOT/specs/epic-191-a3-path-ownership/human-copy/tests/run-all.ps1"
  grep -Fxq '  tests/ownership-digest.tests.sh' "$run_all_sh" && wiring_count=$((wiring_count + 1))
  grep -Fq "'tests/ownership-digest.tests.ps1'" "$run_all_ps1" && wiring_count=$((wiring_count + 1))
  grep -Fq 'bash ./tests/ownership-digest.tests.sh' "$REPO_ROOT/specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml" && wiring_count=$((wiring_count + 1))
  grep -Fq './tests/ownership-digest.tests.ps1' "$REPO_ROOT/specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml" && wiring_count=$((wiring_count + 1))
  grep -Fq '`tests/ownership-digest.tests.sh` / `.ps1`' "$REPO_ROOT/specs/epic-191-a3-path-ownership/design.md" && wiring_count=$((wiring_count + 1))
  if is_mutated TEST-041; then wiring_count=4; printf 'MUTATION: TEST-041 removes one required registration from the observed inventory\n'; fi
  result=0; [ "$wiring_count" = 5 ] && result=1
  check TEST-041 'both suites are wired in run-all, staged CI, and the design inventory' "$result"
fi

if should_run TEST-048; then
  unreleased="$(awk '/^## Unreleased$/{u=1;next} /^## /{u=0} u{print}' "$REPO_ROOT/CHANGELOG.md")"
  release_count=0
  printf '%s' "$unreleased" | grep -Fq 'Issue #191' && printf '%s' "$unreleased" | grep -Fq 'epic-191-a3-path-ownership T-003' && release_count=1
  if is_mutated TEST-048; then release_count=0; printf 'MUTATION: TEST-048 removes the T-003 Issue #191 Unreleased entry\n'; fi
  result=0; [ "$release_count" -ge 1 ] && result=1
  check TEST-048 'CHANGELOG has an Unreleased T-003 entry citing Issue #191' "$result"
fi

if should_run TEST-049; then
  version_files="$(git -C "$REPO_ROOT" diff --name-only -- plugins/*/plugin.json tests/validate-repository.ps1 2>/dev/null || true)"
  if is_mutated TEST-049; then version_files='plugins/sdd-quality-loop/plugin.json'; printf 'MUTATION: TEST-049 introduces an out-of-band version surface change\n'; fi
  result=0; [ -z "$version_files" ] && result=1
  check TEST-049 'no version-carrying surface is changed outside the release bump script' "$result"
fi

printf '%d passed / %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
