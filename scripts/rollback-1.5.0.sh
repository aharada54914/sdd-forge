#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_SCHEMA="rollback-1.5.0/v1"

contract="contracts/rollback-1.5.0.json"
repo_root="."
validator=""
inject_after=0

fail() {
  printf '%s: %s\n' "$1" "$2" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --contract) (($# >= 2)) || fail ROLLBACK_USAGE "--contract requires a value"; contract="$2"; shift 2 ;;
    --repo-root) (($# >= 2)) || fail ROLLBACK_USAGE "--repo-root requires a value"; repo_root="$2"; shift 2 ;;
    --validator) (($# >= 2)) || fail ROLLBACK_USAGE "--validator requires a value"; validator="$2"; shift 2 ;;
    --inject-apply-failure-after)
      (($# >= 2)) || fail ROLLBACK_USAGE "--inject-apply-failure-after requires a value"
      inject_after="$2"
      [[ "$inject_after" =~ ^[1-9][0-9]*$ ]] ||
        fail ROLLBACK_USAGE "--inject-apply-failure-after must be a positive integer"
      shift 2
      ;;
    *) fail ROLLBACK_USAGE "unknown argument: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || fail ROLLBACK_RUNTIME "git is required"
command -v jq >/dev/null 2>&1 || fail ROLLBACK_RUNTIME "jq is required"
command -v shasum >/dev/null 2>&1 || fail ROLLBACK_RUNTIME "shasum is required"

repo_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" ||
  fail ROLLBACK_PATH "repository root is not accessible"
git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  fail ROLLBACK_PATH "repository root is not a Git worktree"
[[ "$(git -C "$repo_root" rev-parse --show-toplevel)" == "$repo_root" ]] ||
  fail ROLLBACK_PATH "repository root must be the Git worktree root"

if [[ "$contract" != /* ]]; then
  contract="$repo_root/$contract"
fi
[[ -f "$contract" && ! -L "$contract" ]] ||
  fail ROLLBACK_CONTRACT "contract must be a regular non-symlink file"

[[ -z "$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)" ]] ||
  fail ROLLBACK_DIRTY "repository must be clean"

contract_ok="$(
  jq -er \
    --arg schema "$EXPECTED_SCHEMA" \
    '
      (keys | sort) == ["baseline_commit","files","reviewed_release_commit","schema"] and
      .schema == $schema and
      (.baseline_commit | type == "string" and test("^[a-f0-9]{40}$")) and
      (.reviewed_release_commit | type == "string" and test("^[a-f0-9]{40}$")) and
      (.files | type == "array" and length > 0) and
      (all(.files[];
        type == "object" and
        (keys | sort) == ["baseline_sha256","new_sha256","path"] and
        (.path | type == "string" and
          test("^[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$") and
          (contains("//") | not) and
          . != "." and . != ".." and
          (startswith("../") | not) and
          (contains("/../") | not) and
          (contains("/./") | not)) and
        (.baseline_sha256 == null or
          (.baseline_sha256 | type == "string" and test("^[a-f0-9]{64}$"))) and
        (.new_sha256 == null or
          (.new_sha256 | type == "string" and test("^[a-f0-9]{64}$"))) and
        (.baseline_sha256 != null or .new_sha256 != null))) and
      ([.files[].path] == ([.files[].path] | sort)) and
      ([.files[].path] | length == (unique | length))
    ' "$contract" 2>/dev/null
)" || fail ROLLBACK_CONTRACT "invalid or non-closed contract"
[[ "$contract_ok" == "true" ]] || fail ROLLBACK_CONTRACT "invalid contract"

baseline="$(jq -r '.baseline_commit' "$contract")"
reviewed="$(jq -r '.reviewed_release_commit' "$contract")"
git -C "$repo_root" cat-file -e "${baseline}^{commit}" 2>/dev/null ||
  fail ROLLBACK_CONTRACT "baseline commit is unavailable"
git -C "$repo_root" cat-file -e "${reviewed}^{commit}" 2>/dev/null ||
  fail ROLLBACK_CONTRACT "reviewed release commit is unavailable"

validate_relative_path() {
  local path="$1" cursor="$repo_root"
  IFS='/' read -r -a parts <<< "$path"
  local part
  for part in "${parts[@]}"; do
    cursor="$cursor/$part"
    [[ ! -L "$cursor" ]] || fail ROLLBACK_PATH "symlink is forbidden: $path"
  done
}

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

verify_commit_entry() {
  local commit="$1" path="$2" expected="$3" label="$4" object_type actual
  if [[ "$expected" == "__ABSENT__" ]]; then
    git -C "$repo_root" cat-file -e "$commit:$path" 2>/dev/null &&
      fail ROLLBACK_HASH "$label expected absent: $path"
    return 0
  fi
  object_type="$(git -C "$repo_root" cat-file -t "$commit:$path" 2>/dev/null)" ||
    fail ROLLBACK_HASH "$label file missing: $path"
  [[ "$object_type" == "blob" ]] || fail ROLLBACK_PATH "$label path is not a file: $path"
  actual="$(git -C "$repo_root" show "$commit:$path" | shasum -a 256 | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] ||
    fail ROLLBACK_HASH "$label hash mismatch: $path"
}

# These are the only inventory members produced after the reviewed T-007
# commit. The contract itself is intentionally excluded because embedding its
# own SHA-256 would be mathematically self-referential.
is_t008_output() {
  case "$1" in
    scripts/rollback-1.5.0.sh|scripts/rollback-1.5.0.ps1|\
    tests/rollback-1.5.0.tests.sh|tests/rollback-1.5.0.tests.ps1|\
    tests/run-all.sh|tests/run-all.ps1) return 0 ;;
    *) return 1 ;;
  esac
}

# Verify containment, every current state, every baseline object, and every
# reviewed-release object that existed at the reviewed T-007 commit.
while IFS=$'\t' read -r path baseline_hash new_hash; do
  validate_relative_path "$path"
  verify_commit_entry "$baseline" "$path" "$baseline_hash" baseline

  if git -C "$repo_root" cat-file -e "$reviewed:$path" 2>/dev/null &&
     ! is_t008_output "$path"; then
    verify_commit_entry "$reviewed" "$path" "$new_hash" reviewed
  fi

  current="$repo_root/$path"
  if [[ "$new_hash" == "__ABSENT__" ]]; then
    [[ ! -e "$current" && ! -L "$current" ]] ||
      fail ROLLBACK_HASH "current path expected absent: $path"
  else
    [[ -f "$current" && ! -L "$current" ]] ||
      fail ROLLBACK_PATH "current file is missing, non-regular, or a symlink: $path"
    [[ "$(hash_file "$current")" == "$new_hash" ]] ||
      fail ROLLBACK_HASH "current hash mismatch: $path"
  fi
done < <(jq -r '.files[] |
  [.path, (.baseline_sha256 // "__ABSENT__"), (.new_sha256 // "__ABSENT__")] | @tsv' "$contract")

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/sdd-rollback.XXXXXX")" ||
  fail ROLLBACK_IO "cannot create transaction directory"
stage="$tmp_root/stage"
backup="$tmp_root/backup"
backup_state="$tmp_root/backup-state.tsv"
mkdir -p "$stage" "$backup"
worktree_added=0

cleanup() {
  if ((worktree_added)); then
    git -C "$repo_root" worktree remove --force "$stage" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_root"
}
trap cleanup EXIT

git -C "$repo_root" worktree add --quiet --detach "$stage" "$baseline" ||
  fail ROLLBACK_STAGE "cannot create isolated baseline worktree"
worktree_added=1

# Stage and verify the complete baseline inventory before validation.
while IFS=$'\t' read -r path baseline_hash; do
  validate_relative_path "$path"
  staged="$stage/$path"
  if [[ "$baseline_hash" == "__ABSENT__" ]]; then
    [[ ! -e "$staged" && ! -L "$staged" ]] ||
      fail ROLLBACK_HASH "staged baseline expected absent: $path"
  else
    [[ -f "$staged" && ! -L "$staged" ]] ||
      fail ROLLBACK_PATH "staged baseline file is invalid: $path"
    [[ "$(hash_file "$staged")" == "$baseline_hash" ]] ||
      fail ROLLBACK_HASH "staged baseline hash mismatch: $path"
  fi
done < <(jq -r '.files[] | [.path, (.baseline_sha256 // "__ABSENT__")] | @tsv' "$contract")

set +e
if [[ -n "$validator" ]]; then
  validator_path="$validator"
  [[ "$validator_path" == /* ]] || validator_path="$repo_root/$validator_path"
  [[ -f "$validator_path" && ! -L "$validator_path" ]] ||
    fail ROLLBACK_VALIDATION "validator must be a regular non-symlink file"
  (cd "$stage" && bash "$validator_path")
  validator_status=$?
else
  command -v pwsh >/dev/null 2>&1 || fail ROLLBACK_RUNTIME "pwsh is required"
  (cd "$stage" && pwsh -NoProfile -File tests/validate-repository.ps1)
  validator_status=$?
fi
set -e
((validator_status == 0)) ||
  fail ROLLBACK_VALIDATION "isolated baseline validation failed"

# Retain a byte-for-byte verified backup and an explicit present/absent map.
: > "$backup_state"
while IFS= read -r path; do
  validate_relative_path "$path"
  source="$repo_root/$path"
  if [[ -f "$source" && ! -L "$source" ]]; then
    target="$backup/$path"
    mkdir -p "$(dirname "$target")"
    cp -p "$source" "$target"
    [[ "$(hash_file "$target")" == "$(hash_file "$source")" ]] ||
      fail ROLLBACK_BACKUP "backup verification failed: $path"
    printf 'present\t%s\t%s\n' "$path" "$(hash_file "$target")" >> "$backup_state"
  elif [[ ! -e "$source" && ! -L "$source" ]]; then
    printf 'absent\t%s\t-\n' "$path" >> "$backup_state"
  else
    fail ROLLBACK_PATH "cannot back up non-regular path: $path"
  fi
done < <(jq -r '.files[].path' "$contract")

restore_original() {
  local state path expected target saved
  while IFS=$'\t' read -r state path expected; do
    target="$repo_root/$path"
    if [[ "$state" == "absent" ]]; then
      rm -f "$target" || return 1
    else
      saved="$backup/$path"
      mkdir -p "$(dirname "$target")" || return 1
      cp -p "$saved" "$target" || return 1
      [[ "$(hash_file "$target")" == "$expected" ]] || return 1
    fi
  done < "$backup_state"
}

apply_count=0
apply_failed=0
while IFS=$'\t' read -r path baseline_hash; do
  target="$repo_root/$path"
  if [[ "$baseline_hash" == "__ABSENT__" ]]; then
    rm -f "$target" || apply_failed=1
  else
    mkdir -p "$(dirname "$target")" || apply_failed=1
    ((apply_failed)) || cp -p "$stage/$path" "$target" || apply_failed=1
  fi
  ((apply_count += 1))
  if ((inject_after > 0 && apply_count == inject_after)); then
    apply_failed=1
  fi
  ((apply_failed == 0)) || break
done < <(jq -r '.files[] | [.path, (.baseline_sha256 // "__ABSENT__")] | @tsv' "$contract")

if ((apply_failed)); then
  restore_original ||
    fail ROLLBACK_RESTORE "apply failed and original tree could not be restored"
  fail ROLLBACK_APPLY "apply failed; original tree restored byte-for-byte"
fi

# Verify that every inventory path reached its baseline state.
while IFS=$'\t' read -r path baseline_hash; do
  target="$repo_root/$path"
  if [[ "$baseline_hash" == "__ABSENT__" ]]; then
    [[ ! -e "$target" && ! -L "$target" ]] ||
      fail ROLLBACK_APPLY "post-apply path should be absent: $path"
  else
    [[ -f "$target" && ! -L "$target" &&
       "$(hash_file "$target")" == "$baseline_hash" ]] ||
      fail ROLLBACK_APPLY "post-apply hash mismatch: $path"
  fi
done < <(jq -r '.files[] | [.path, (.baseline_sha256 // "__ABSENT__")] | @tsv' "$contract")

printf 'ROLLBACK_OK: 1.5.0 -> 1.4.0 complete\n'
