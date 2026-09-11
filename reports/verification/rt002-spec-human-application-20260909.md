# RT002: human-only specification application

Scope: only the two canonical A1 specification files in the reviewed
`rt002-spec-amendment-candidate-20260909.patch`. This is not permission to
apply the production handshake patch, change a review verdict, publish an
installed plugin, commit, push, or merge. Stop other writers to these two
files before starting. The existing publisher provides its documented
anchored transaction behavior; this wrapper is not a stronger concurrency
or hostile-filesystem guarantee.

Candidate advisory: `rt002-spec-amendment-advisory-round2-20260909.md`.
The specification amendment remains pending formal review. No historical
review evidence or task status is changed by these commands. Applying the
amendment invalidates the old binding for current bytes intentionally; the
original spec precheck must subsequently perform the sanctioned new attempt.
Do not run ordinary implementation or integration between these steps.

Preparation evidence: original target/publisher hashes were checked; the
patch passes `git apply --check --recount`. Candidate hashes below were
computed in memory from the two unique insertion hunks, without publishing
or executing candidate code. Human execution below independently verifies
the materialized bytes against those hashes before publication.

The command block is for a human terminal only. It has not been applied by
the agent. It deliberately uses no `rg`, and quotes the heredoc delimiter so
zsh history expansion cannot interpret its body.

```bash
rtk proxy bash <<'BASH'
set -euo pipefail
umask 077
repo=/Users/jrmag/sdd-forge
patch_rel=reports/verification/rt002-spec-amendment-candidate-20260909.patch
publisher_rel=plugins/sdd-quality-loop/scripts/apply-human-copy.sh
req=specs/epic-189-a1-project-context/requirements.md
ac=specs/epic-189-a1-project-context/acceptance-tests.md

stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
check_hash() {
  local file=$1 expected=$2 actual output
  [ -f "$file" ] && [ ! -L "$file" ] || stop "not a regular non-symlink file: $file"
  output=$(rtk proxy shasum -a 256 "$file") || stop "hash failed: $file"
  actual=${output%% *}
  [ "$actual" = "$expected" ] || stop "hash mismatch: $file"
}
check_relative_chain() {
  local relative=$1 segment cursor=$repo
  local -a segments
  IFS=/ read -r -a segments <<< "$relative"
  for segment in "${segments[@]}"; do
    cursor=$cursor/$segment
    [ ! -L "$cursor" ] || stop "symlink in path: $cursor"
  done
}
check_no_prior_transaction() {
  local item
  [ ! -L "$repo/sdd" ] && [ ! -L "$repo/sdd/.staging" ] || stop 'symlink in publisher staging root'
  if [ -e "$repo/sdd/.staging" ]; then
    [ -d "$repo/sdd/.staging" ] || stop 'publisher staging root is not a directory'
    shopt -s nullglob dotglob
    for item in "$repo/sdd/.staging/"*; do
      stop "existing publisher staging entry requires inspection: $item"
    done
    shopt -u nullglob dotglob
  fi
}
check_inputs() {
  local relative
  for relative in "$req" "$ac" "$patch_rel" "$publisher_rel"; do
    check_relative_chain "$relative"
  done
  check_hash "$repo/$req" 78e7f94a0a7d1029ca1b8e03e23faecb050d454af588e57e7ff48cbc887f8c37
  check_hash "$repo/$ac" e0b6ae1d5a2d2d2daaa9435dcc3814ce1ba8a215703b110e36b3f9bdfc7d2b7d
  check_hash "$repo/$patch_rel" 0df91892144c5af1f6e1c93e2dd27f0bcf702ddafb03d362f8873aca671c85a4
  check_hash "$repo/$publisher_rel" 93029c02bac7ef5390638cd0a2bcde77803bf07c780baa3d6080ca3caa2db800
  check_no_prior_transaction
}

cd "$repo"
[ "$(pwd -P)" = "$repo" ] || stop 'repository path is not the expected physical path'
[ "$(rtk proxy git rev-parse --show-toplevel)" = "$repo" ] || stop 'wrong repository root'
check_inputs
rtk proxy git apply --check --recount "$repo/$patch_rel"

scratch=$(rtk proxy mktemp -d /tmp/sdd-rt002-spec.XXXXXX) || stop 'temporary directory allocation failed'
[ -d "$scratch" ] && [ ! -L "$scratch" ] || stop 'invalid temporary directory'
printf 'バックアップ・作業先: %s\n' "$scratch"
stage=$scratch/stage
rtk proxy mkdir -p "$stage/specs/epic-189-a1-project-context" "$scratch/backup"
rtk proxy cp -p "$repo/$req" "$scratch/backup/requirements.md"
rtk proxy cp -p "$repo/$ac" "$scratch/backup/acceptance-tests.md"
rtk proxy cp -p "$repo/$req" "$stage/$req"
rtk proxy cp -p "$repo/$ac" "$stage/$ac"
rtk proxy cp "$repo/$patch_rel" "$scratch/amendment.patch"
check_hash "$scratch/amendment.patch" 0df91892144c5af1f6e1c93e2dd27f0bcf702ddafb03d362f8873aca671c85a4
check_hash "$scratch/backup/requirements.md" 78e7f94a0a7d1029ca1b8e03e23faecb050d454af588e57e7ff48cbc887f8c37
check_hash "$scratch/backup/acceptance-tests.md" e0b6ae1d5a2d2d2daaa9435dcc3814ce1ba8a215703b110e36b3f9bdfc7d2b7d
rtk proxy git -C "$stage" init --quiet
rtk proxy git -C "$stage" apply --check --recount "$scratch/amendment.patch"
rtk proxy git -C "$stage" apply --recount "$scratch/amendment.patch"
check_hash "$stage/$req" 7b5376201fe17681c906c7d5531141d29af5c0c6c2a6cf9dcfd7317802325334
check_hash "$stage/$ac" 079567e6ef2ec31c96c77d4e635f1097e06ae74757bb668dd56050620d90f11a
printf '%s  %s\n' \
  7b5376201fe17681c906c7d5531141d29af5c0c6c2a6cf9dcfd7317802325334 "$req" \
  079567e6ef2ec31c96c77d4e635f1097e06ae74757bb668dd56050620d90f11a "$ac" \
  > "$scratch/MANIFEST.sha256"

# Recheck all original inputs immediately before the existing anchored publisher.
# Never replace this call with cp/git apply against the live specifications.
check_inputs
if rtk proxy sh "$repo/$publisher_rel" --staging-dir "$stage" --manifest "$scratch/MANIFEST.sha256" \
    > "$scratch/publisher.stdout" 2> "$scratch/publisher.stderr"; then
  publish_rc=0
else
  publish_rc=$?
fi
rtk proxy cat "$scratch/publisher.stdout" "$scratch/publisher.stderr"
[ "$publish_rc" -eq 0 ] || stop "publisher failed ($publish_rc); preserve staging, journal and backups; do not retry blindly"
check_hash "$repo/$req" 7b5376201fe17681c906c7d5531141d29af5c0c6c2a6cf9dcfd7317802325334
check_hash "$repo/$ac" 079567e6ef2ec31c96c77d4e635f1097e06ae74757bb668dd56050620d90f11a
rtk proxy git diff --check -- "$req" "$ac"
rtk proxy git diff --stat -- "$req" "$ac"
printf '\n仕様2ファイルの適用のみ完了。正式レビュー・実装・テストは未完了です。\n'
printf 'commit/push/merge、レビュー状態の変更はせず、この出力と作業先を Codex に送ってください。\n'
BASH
```

On any failure, preserve the printed scratch directory and any publisher
journal. Do not delete a journal, replace the publisher, or run a plain-copy
rollback. A completed publication has an additional external backup above;
any rollback must itself use the authorized anchored path after inspecting
the actual transaction state.
