#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BASH_RUNNER="$ROOT/scripts/rollback-1.5.0.sh"
PS_RUNNER="$ROOT/scripts/rollback-1.5.0.ps1"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/rollback-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

for command in git jq shasum pwsh; do
  command -v "$command" >/dev/null 2>&1 || fail "missing runtime: $command"
done
for file in "$BASH_RUNNER" "$PS_RUNNER"; do
  [[ -f "$file" ]] || fail "missing rollback runner: $file"
done

source_repo="$TMP/source"
mkdir -p "$source_repo"
git -C "$source_repo" init -q
git -C "$source_repo" config user.name rollback-test
git -C "$source_repo" config user.email rollback-test@example.invalid
printf 'baseline-present\n' > "$source_repo/present.txt"
printf 'baseline-restored\n' > "$source_repo/baseline-only.txt"
git -C "$source_repo" add .
git -C "$source_repo" commit -qm baseline
baseline="$(git -C "$source_repo" rev-parse HEAD)"

printf 'release-present\n' > "$source_repo/present.txt"
rm "$source_repo/baseline-only.txt"
printf 'release-only\n' > "$source_repo/release-only.txt"
git -C "$source_repo" add -A
git -C "$source_repo" commit -qm release
reviewed="$(git -C "$source_repo" rev-parse HEAD)"

git_hash() {
  git -C "$source_repo" show "$1:$2" | shasum -a 256 | awk '{print $1}'
}

contract="$TMP/rollback.json"
jq -n \
  --arg baseline "$baseline" \
  --arg reviewed "$reviewed" \
  --arg baseline_only "$(git_hash "$baseline" baseline-only.txt)" \
  --arg present_baseline "$(git_hash "$baseline" present.txt)" \
  --arg present_release "$(git_hash "$reviewed" present.txt)" \
  --arg release_only "$(git_hash "$reviewed" release-only.txt)" '{
    schema: "rollback-1.5.0/v1",
    baseline_commit: $baseline,
    reviewed_release_commit: $reviewed,
    files: [
      {path:"baseline-only.txt", baseline_sha256:$baseline_only, new_sha256:null},
      {path:"present.txt", baseline_sha256:$present_baseline, new_sha256:$present_release},
      {path:"release-only.txt", baseline_sha256:null, new_sha256:$release_only}
    ]
  }' > "$contract"

pass_validator="$TMP/pass-validator.sh"
fail_validator="$TMP/fail-validator.sh"
printf '#!/usr/bin/env bash\nset -eu\ngrep -qx baseline-present present.txt\ngrep -qx baseline-restored baseline-only.txt\ntest ! -e release-only.txt\n' > "$pass_validator"
printf '#!/usr/bin/env bash\nexit 23\n' > "$fail_validator"
chmod +x "$pass_validator" "$fail_validator"

clone_fixture() {
  local name="$1"
  git clone -q "$source_repo" "$TMP/$name"
  printf '%s\n' "$TMP/$name"
}

snapshot() {
  local repo="$1"
  (
    cd "$repo"
    for path in baseline-only.txt present.txt release-only.txt; do
      if [[ -f "$path" ]]; then
        printf 'present %s %s\n' "$path" "$(shasum -a 256 "$path" | awk '{print $1}')"
      else
        printf 'absent %s\n' "$path"
      fi
    done
  )
}

run_case() {
  local runtime="$1" repo="$2" validator="$3"
  shift 3
  if [[ "$runtime" == "bash" ]]; then
    bash "$BASH_RUNNER" --repo-root "$repo" --contract "$contract" \
      --validator "$validator" "$@"
  else
    local ps_args=(-RepoRoot "$repo" -Contract "$contract" -Validator "$validator")
    if (($#)); then
      [[ "$1" == "--inject-apply-failure-after" ]] || fail "unknown test argument"
      ps_args+=(-InjectApplyFailureAfter "$2")
    fi
    pwsh -NoProfile -File "$PS_RUNNER" "${ps_args[@]}"
  fi
}

for runtime in bash powershell; do
  repo="$(clone_fixture "$runtime-success")"
  run_case "$runtime" "$repo" "$pass_validator" >/dev/null
  [[ "$(cat "$repo/present.txt")" == "baseline-present" &&
     "$(cat "$repo/baseline-only.txt")" == "baseline-restored" &&
     ! -e "$repo/release-only.txt" ]] ||
    fail "$runtime success did not apply the complete baseline inventory"

  repo="$(clone_fixture "$runtime-tamper")"
  printf 'tampered\n' > "$repo/present.txt"
  git -C "$repo" add present.txt
  git -C "$repo" commit -qm tamper
  set +e
  output="$(run_case "$runtime" "$repo" "$pass_validator" 2>&1)"
  status=$?
  set -e
  [[ $status -ne 0 && "$output" == *"ROLLBACK_HASH"* ]] ||
    fail "$runtime did not reject current-file tampering"

  repo="$(clone_fixture "$runtime-dirty")"
  printf 'dirty\n' >> "$repo/present.txt"
  set +e
  output="$(run_case "$runtime" "$repo" "$pass_validator" 2>&1)"
  status=$?
  set -e
  [[ $status -ne 0 && "$output" == *"ROLLBACK_DIRTY"* ]] ||
    fail "$runtime did not reject a dirty worktree"

  repo="$(clone_fixture "$runtime-validator-failure")"
  before="$(snapshot "$repo")"
  set +e
  output="$(run_case "$runtime" "$repo" "$fail_validator" 2>&1)"
  status=$?
  set -e
  after="$(snapshot "$repo")"
  [[ $status -ne 0 && "$output" == *"ROLLBACK_VALIDATION"* && "$before" == "$after" ]] ||
    fail "$runtime validator failure changed the original tree"

  repo="$(clone_fixture "$runtime-partial-failure")"
  before="$(snapshot "$repo")"
  set +e
  output="$(run_case "$runtime" "$repo" "$pass_validator" \
    --inject-apply-failure-after 1 2>&1)"
  status=$?
  set -e
  after="$(snapshot "$repo")"
  [[ $status -ne 0 && "$output" == *"ROLLBACK_APPLY"* && "$before" == "$after" &&
     ! -e "$repo/baseline-only.txt" && -f "$repo/present.txt" &&
     -f "$repo/release-only.txt" ]] ||
    fail "$runtime partial apply did not restore original absent/present files byte-for-byte"

  tampered_contract="$TMP/$runtime-contract-tamper.json"
  jq '.unexpected = true' "$contract" > "$tampered_contract"
  repo="$(clone_fixture "$runtime-contract-tamper")"
  set +e
  if [[ "$runtime" == "bash" ]]; then
    output="$(bash "$BASH_RUNNER" --repo-root "$repo" --contract "$tampered_contract" \
      --validator "$pass_validator" 2>&1)"
  else
    output="$(pwsh -NoProfile -File "$PS_RUNNER" -RepoRoot "$repo" \
      -Contract "$tampered_contract" -Validator "$pass_validator" 2>&1)"
  fi
  status=$?
  set -e
  [[ $status -ne 0 && "$output" == *"ROLLBACK_CONTRACT"* ]] ||
    fail "$runtime did not fail closed on an unknown contract property"
done

canonical="$ROOT/contracts/rollback-1.5.0.json"
[[ -f "$canonical" && ! -L "$canonical" ]] ||
  fail "missing canonical rollback contract"
jq -e '
  . as $root |
  (keys | sort) == ["baseline_commit","files","reviewed_release_commit","schema"] and
  .schema == "rollback-1.5.0/v1" and
  .baseline_commit == "7df7318e73c688a85bbe29a8e7e326b41eeae4e2" and
  .reviewed_release_commit == "8af2b1fcfc77b7f4eb377dd53c6d5a30be68a5d7" and
  (.files | length > 0) and
  ([$root.files[].path] == ([$root.files[].path] | sort)) and
  ([$root.files[].path] | length == ([$root.files[].path] | unique | length)) and
  all(.files[];
    (keys | sort) == ["baseline_sha256","new_sha256","path"] and
    (.baseline_sha256 == null or
      (.baseline_sha256 | test("^[a-f0-9]{64}$"))) and
    (.new_sha256 == null or (.new_sha256 | test("^[a-f0-9]{64}$"))))
' "$canonical" >/dev/null || fail "canonical rollback contract is not closed and pinned"

# TEST-006: materialize the reviewed T-007 tree plus the six post-review T-008
# outputs, then run the real pinned inventory and a 1.4.0 release validator.
canonical_release="$TMP/canonical-release"
git clone -q "$ROOT" "$canonical_release"
for path in \
  contracts/rollback-1.5.0.json \
  scripts/rollback-1.5.0.sh scripts/rollback-1.5.0.ps1 \
  tests/rollback-1.5.0.tests.sh tests/rollback-1.5.0.tests.ps1 \
  tests/run-all.sh tests/run-all.ps1; do
  mkdir -p "$canonical_release/$(dirname "$path")"
  cp "$ROOT/$path" "$canonical_release/$path"
done
git -C "$canonical_release" add .
git -C "$canonical_release" -c user.name=rollback-test \
  -c user.email=rollback-test@example.invalid commit -qm t008-release
baseline_release_validator="$TMP/baseline-release-validator.sh"
cat > "$baseline_release_validator" <<'VALIDATOR'
#!/usr/bin/env bash
set -euo pipefail
grep -q '^## v1\.4\.0' CHANGELOG.md
for manifest in plugins/*/.claude-plugin/plugin.json \
  plugins/*/.codex-plugin/plugin.json plugins/*/.plugin/plugin.json; do
  [[ "$(jq -r '.version' "$manifest")" == "1.4.0" ]]
done
VALIDATOR
chmod +x "$baseline_release_validator"
bash "$BASH_RUNNER" --repo-root "$canonical_release" \
  --contract "$canonical_release/contracts/rollback-1.5.0.json" \
  --validator "$baseline_release_validator" >/dev/null

while IFS=$'\t' read -r path baseline_hash; do
  if [[ "$baseline_hash" == "__ABSENT__" ]]; then
    [[ ! -e "$canonical_release/$path" ]] ||
      fail "canonical rollback did not remove baseline-absent path: $path"
  else
    [[ -f "$canonical_release/$path" &&
       "$(shasum -a 256 "$canonical_release/$path" | awk '{print $1}')" == "$baseline_hash" ]] ||
      fail "canonical rollback baseline hash mismatch: $path"
  fi
done < <(jq -r '.files[] | [.path, (.baseline_sha256 // "__ABSENT__")] | @tsv' "$canonical")

printf 'ok: rollback contract and paired transactions pass success, tamper, dirty, validator, and partial-apply cases\n'
