#!/usr/bin/env bash
# Validate the repository-wide SDD workflow state. Diagnostics are API-stable.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
REGISTRY="$SCRIPT_ROOT/specs/workflow-state-registry.json"
FEATURE_FILTER=""
OPENING_STAGE=""
OPENING_ATTEMPT=""
OPENING_ROUND=""

diagnostic_line() {
  printf 'workflow-state: %s: %s: %s\n' "$1" "$2" "$3" >&2
}
diagnostic() {
  diagnostic_line "$@"
  exit 1
}
# Fail closed when no SHA-256 tool exists: with the bare else-shasum shape a
# host with neither tool captures an empty digest and empty == empty passes.
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || {
  diagnostic_line "neither sha256sum nor shasum is available"
  exit 1
}
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else diagnostic "neither sha256sum nor shasum is available"; fi
}
sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else diagnostic "neither sha256sum nor shasum is available"; fi
}
# plugins/ reference docs (risk-gate-matrix.md, reviewer-calibration.md, etc.)
# evolve normally over time, but historical review evidence under reports/
# records the sha256 that was current when that evidence was produced. A
# later, legitimate edit to a reference doc must not retroactively fail every
# past feature's provenance. When a manifest-recorded hash for a plugins/
# path does not match the live working-tree file, fall back to resolving the
# file's content as of the commit that INTRODUCED the specific evidence file
# being validated (the review contract JSON itself is immutable, committed
# historical fact) and accept the match only if it is identical. The pin
# stands in for "when this review happened" -- a moment that does not move
# when the record is later amended for an unrelated reason, so this resolves
# --diff-filter=A (the commit that added the path), not the commit that most
# recently touched it: a subsequent, unrelated edit to the same contract
# (e.g. a provenance re-bind) must not retroactively shift the pin forward
# past reference-doc evolution that happened in between, which would falsely
# invalidate a hash that was valid when the review actually ran.
# This keeps tamper detection intact: a forged hash that matches no
# legitimate point-in-time content still fails.
plugins_pin_commit() {
  local evidence_file="$1" relative pins
  command -v git >/dev/null 2>&1 || return 1
  git -C "$SCRIPT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  case "$evidence_file" in
    "$REPO_ROOT"/*) relative="${evidence_file#"$REPO_ROOT/"}" ;;
    *) return 1 ;;
  esac
  # A path added, deleted, and re-added yields more than one --diff-filter=A
  # commit; a path that has never been committed (working-tree only) yields
  # none. Both are an indeterminate introducing commit. Since this is a
  # provenance check, failing closed on an indeterminate pin is safer than
  # guessing which addition -- or accepting a convenient one -- is
  # authoritative.
  pins="$(git -C "$SCRIPT_ROOT" log --diff-filter=A --format='%H' -- "$relative" 2>/dev/null)" || return 1
  [[ -n "$pins" ]] || return 1
  [[ "$pins" != *$'\n'* ]] || return 1
  printf '%s\n' "$pins"
}
plugins_hash_at_pin() {
  local pin="$1" plugins_relative="$2" hash
  [[ -n "$pin" ]] || return 1
  git -C "$SCRIPT_ROOT" merge-base --is-ancestor "$pin" HEAD 2>/dev/null || return 1
  hash="$(git -C "$SCRIPT_ROOT" show "$pin:$plugins_relative" 2>/dev/null | sha256_stream)" || return 1
  [[ -n "$hash" ]] || return 1
  printf '%s\n' "$hash"
}
# Returns success when SCRIPT_ROOT has any git history to consult at all
# (git binary present and it is a work tree). Checked independently of
# plugins_pin_commit's own exit status, because that function also fails for
# reasons that are NOT "no history exists" (e.g. an evidence path outside
# REPO_ROOT, or a path with no commits) -- only the true absence of git
# history should relax plugins_hash_matches below.
plugins_git_history_available() {
  command -v git >/dev/null 2>&1 || return 1
  git -C "$SCRIPT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}
# Returns success if $plugins_file's content matches $expected either right
# now, or as of the commit that produced $evidence_file (the review contract
# JSON whose recorded manifest hash is being validated). A release artifact
# (e.g. the tarball repository-release-validation.tests.sh builds) carries no
# .git directory, so there is no history there to reconcile a
# manifest-recorded hash against: the comparison is not evaluable rather than
# failed, and is accepted for this plugins/* shared-reference class only.
# The same assertion is still fully enforced by every git-bearing run of this
# script (in place, in CI checkouts, in this file's own fixtures) -- that is
# where a stale or forged hash is actually checkable, and a mismatch the pin
# cannot justify still fails there.
plugins_hash_matches() {
  local plugins_file="$1" expected="$2" evidence_file="$3" plugins_relative pin historical
  [[ -f "$plugins_file" && ! -L "$plugins_file" ]] || return 1
  [[ "$(sha256_file "$plugins_file")" == "$expected" ]] && return 0
  plugins_git_history_available || return 0
  case "$plugins_file" in
    "$REPO_ROOT"/*) plugins_relative="${plugins_file#"$REPO_ROOT/"}" ;;
    *) return 1 ;;
  esac
  pin="$(plugins_pin_commit "$evidence_file")" || return 1
  historical="$(plugins_hash_at_pin "$pin" "$plugins_relative")" || return 1
  [[ "$historical" == "$expected" ]]
}

# The amendment re-review lane (spec-review's `## Amendment Re-Review
# Context` section, extended to impl/task in reviewer-calibration.md)
# creates a structural oscillation none of the tolerances above cover: each
# downstream stage's OWN recovery legitimately appends to the SAME
# specs/<feature>/investigation.md section that an UPSTREAM stage's
# reviewer manifest already pinned (investigation.md is an allowed input
# for all three stages -- see the unconditional `allowed()` clause above).
# That re-stales the upstream pin with a change whose entire content is the
# record of the very recovery the lane exists to permit -- not a change to
# anything reviewed. Unlike the --opening tolerance above, this must work
# STANDALONE: the oscillation bites precisely when no stage is currently
# being opened (a later stage's recovery already landed and closed; an
# earlier stage's pin is what went stale). Scoping this to one named
# section is what makes a standalone, unconditional tolerance safe: the
# section is the lane's own declared channel, its conformance is judged by
# every reviewer who reads investigation.md as part of that stage's normal
# review (the calibration docs define the evidence bar), and the checks
# below guarantee nothing outside that section -- and no mutation of an
# already-reviewed line inside it -- can ride through this path even if a
# byte anywhere else changed.
#
# Prints "START END" (1-indexed, inclusive) for the FIRST line reading
# exactly "## Amendment Re-Review Context" in $1: START is that heading's
# own line, END is the line before the next line starting with "## " after
# it, or the file's last line if none follows (the section runs to EOF).
# Prints nothing and fails if the heading is not present at all. Assumes
# the file ends with a trailing newline, consistent with every other
# line-oriented check in this script.
amendment_section_bounds() {
  local file="$1" start end total
  start="$(grep -n '^## Amendment Re-Review Context$' "$file" | head -1 | cut -d: -f1)"
  [[ -n "$start" ]] || return 1
  total="$(wc -l < "$file" | tr -d ' ')"
  end="$(awk -v s="$start" 'NR>s && /^## /{print NR-1; exit}' "$file")"
  [[ -n "$end" ]] || end="$total"
  printf '%s %s\n' "$start" "$end"
}
# Verifies the pinned bytes ($1, already-verified content -- see the only
# caller) differ from live bytes ($2) in a shape that is PURE, CONTIGUOUS
# GROWTH confined to the `## Amendment Re-Review Context` section as
# computed on the LIVE file. Checked directly via line ranges rather than
# parsing a diff(1) hunk format (which differs subtly between GNU and BSD
# diff and would need cross-platform parsing on both twins for no benefit
# here -- the required shape is narrow enough to verify directly):
#   (1) every line before the section must be byte-identical between
#       pinned and live -- nothing outside the section may change at all.
#   (2) if the section existed in the pinned version, its lines must be an
#       EXACT PREFIX of the live section's lines. Growth (more lines
#       appended after) is fine; fewer lines, or ANY changed line within
#       the shared prefix, is not -- a mutated already-reviewed entry line
#       is rewriting reviewed history, not recording new history, so it is
#       deliberately NOT tolerated even though it is still "inside" the
#       section window. Tolerating it would let a downstream recovery
#       silently rewrite an upstream-pinned entry under cover of this
#       path; refusing it means the only thing this reconciliation can
#       ever waive through is strictly additive.
#   (3) if the section did NOT exist in the pinned version, it may ONLY be
#       a pure, contiguous creation whose live-side boundary reaches the
#       live file's own LAST line -- i.e. "created at EOF" literally, not
#       merely "inserted somewhere that happens to satisfy (1) and the
#       trailing-content check below". A brand-new section spliced into
#       the middle of the file, ahead of pre-existing trailing content,
#       is rejected even though such a splice would still pass a bare
#       prefix/suffix-identity check. The heading may land a line or two
#       after pinned's own last line (e.g. a conventional blank-line
#       separator before a new `## ` heading) -- that gap is itself brand
#       new content with nothing pinned to compare it against, so it is
#       swept into the same tolerance as the section rather than forced
#       to equal a fixed offset from pinned's length.
#   (4) every line after the section (present only when the section is
#       not the file's last -- e.g. an unrelated later "## " section
#       exists) must be byte-identical too -- growth is licensed strictly
#       inside the section, nowhere else.
investigation_growth_only_change() {
  local pinned="$1" live="$2"
  local live_bounds live_start live_end live_total pinned_total prefix_len
  live_bounds="$(amendment_section_bounds "$live")" || return 1
  read -r live_start live_end <<<"$live_bounds"
  live_total="$(wc -l < "$live" | tr -d ' ')"
  pinned_total="$(wc -l < "$pinned" | tr -d ' ')"

  local pinned_bounds="" pinned_start="" pinned_end=""
  if pinned_bounds="$(amendment_section_bounds "$pinned")"; then
    read -r pinned_start pinned_end <<<"$pinned_bounds"
    # Sanity check, made explicit rather than left implicit in (1) below:
    # the section must start at the same absolute line in both files.
    [[ "$pinned_start" == "$live_start" ]] || return 1
    prefix_len=$((live_start - 1))
    if ((prefix_len > 0)); then
      cmp -s <(head -n "$prefix_len" "$pinned") <(head -n "$prefix_len" "$live") || return 1
    fi
  else
    # No fixed offset to compare against: the heading's live position is
    # unconstrained beyond "strictly after all of pinned's own content"
    # (see comment (3) above), so the prefix check here compares ALL of
    # pinned against live's own first pinned_total lines, not a window
    # sized by live_start.
    ((live_start > pinned_total)) || return 1
    if ((pinned_total > 0)); then
      cmp -s <(head -n "$pinned_total" "$pinned") <(head -n "$pinned_total" "$live") || return 1
    fi
    [[ "$live_end" -eq "$live_total" ]] || return 1
  fi

  if [[ -n "$pinned_start" ]]; then
    local pinned_section_len=$((pinned_end - pinned_start + 1))
    local live_section_len=$((live_end - live_start + 1))
    ((live_section_len >= pinned_section_len)) || return 1
    cmp -s \
      <(sed -n "${pinned_start},${pinned_end}p" "$pinned") \
      <(sed -n "${live_start},$((live_start + pinned_section_len - 1))p" "$live") || return 1

    local pinned_after=$((pinned_total - pinned_end))
    local live_after=$((live_total - live_end))
    if ((pinned_after > 0 || live_after > 0)); then
      ((pinned_after == live_after)) || return 1
      cmp -s \
        <(tail -n "+$((pinned_end + 1))" "$pinned") \
        <(tail -n "+$((live_end + 1))" "$live") || return 1
    fi
  fi
  return 0
}
# Resolves the pinned bytes of specs/<feature>/investigation.md at the
# CONTRACT's introducing commit (--diff-filter=A -- the SAME machinery
# plugins_pin_commit/plugins_hash_at_pin already use for plugins/
# reference docs, reused rather than duplicated: the contract JSON whose
# manifest entry is being checked is itself immutable, committed
# historical fact, so its introducing commit stands for "when this review
# ran" exactly as it does there) and writes them to $4. Returns success
# ONLY after independently re-verifying that the written bytes' own sha256
# equals $2 -- a forged pin, an ambiguous introducing commit, or a
# contract whose commit predates reconstructable history all fail here,
# with nothing written that the caller could diff against, so the
# reconciliation below can never proceed from an unverified base.
resolve_verified_investigation_pin() {
  local contract="$1" expected="$2" relative="$3" out_file="$4" pin
  pin="$(plugins_pin_commit "$contract")" || return 1
  [[ "$(plugins_hash_at_pin "$pin" "$relative")" == "$expected" ]] || return 1
  git -C "$SCRIPT_ROOT" show "$pin:$relative" > "$out_file" 2>/dev/null || return 1
  [[ "$(sha256_file "$out_file")" == "$expected" ]]
}
# Top-level entry point for the amendment-oscillation tolerance: returns
# success only when $2 (the manifest's recorded sha256 for
# specs/<feature>/investigation.md) resolves to independently-verified
# historical bytes (see resolve_verified_investigation_pin) whose ONLY
# difference from $1 (the live file) is pure growth confined to the
# `## Amendment Re-Review Context` section (see
# investigation_growth_only_change). Applies uniformly to every stage
# (spec/impl/task): investigation.md is an allowed input for all three,
# the oscillation is structurally identical regardless of which stage's
# pin went stale, and the same calibration-governed section is what makes
# it safe for all three alike.
investigation_amendment_reconciles() {
  local manifest_file="$1" expected="$2" contract="$3" relative tmp_pinned result
  case "$manifest_file" in
    "$REPO_ROOT"/*) relative="${manifest_file#"$REPO_ROOT/"}" ;;
    *) return 1 ;;
  esac
  tmp_pinned="$(mktemp)" || return 1
  if resolve_verified_investigation_pin "$contract" "$expected" "$relative" "$tmp_pinned"; then
    investigation_growth_only_change "$tmp_pinned" "$manifest_file"
    result=$?
  else
    result=1
  fi
  rm -f "$tmp_pinned"
  return "$result"
}
# Visible notice, not a silent pass: names the file, both hashes, and that
# the delta is confined to amendment-record growth, so the recovery is
# observable in the run's output rather than waved through unremarked.
print_investigation_amendment_notice() {
  local feature="$1" stage="$2" suffix="$3" recorded="$4" current="$5"
  printf 'workflow-state: %s: stage-provenance-tolerated: %s (%s stage) recorded %s, now %s (amendment-record growth only)\n' \
    "$feature" "${suffix#/}" "$stage" "$recorded" "$current" >&2
}

while (($#)); do
  case "$1" in
    --feature)
      (($# >= 2)) || diagnostic repository cli-usage "--feature requires a value"
      FEATURE_FILTER="$2"; shift 2 ;;
    --registry)
      (($# >= 2)) || diagnostic repository cli-usage "--registry requires a value"
      REGISTRY="$2"; shift 2 ;;
    --opening)
      (($# >= 2)) || diagnostic repository cli-usage "--opening requires a value"
      [[ "$2" =~ ^(spec|impl|task):([1-9][0-9]*):([1-9][0-9]*)$ ]] ||
        diagnostic repository cli-usage "--opening must be stage:attempt:round"
      OPENING_STAGE="${BASH_REMATCH[1]}"
      OPENING_ATTEMPT="${BASH_REMATCH[2]}"
      OPENING_ROUND="${BASH_REMATCH[3]}"
      shift 2 ;;
    *) diagnostic repository cli-usage "unknown argument: $1" ;;
  esac
done
[[ -z "$FEATURE_FILTER" || "$FEATURE_FILTER" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
  diagnostic "$FEATURE_FILTER" cli-usage "invalid feature slug"
# --opening names the single round a review-loop precheck is about to open; it
# only ever makes sense pinned to the one feature it belongs to, never as a
# blanket exemption swept across the whole registry.
[[ -z "$OPENING_STAGE" || -n "$FEATURE_FILTER" ]] ||
  diagnostic repository cli-usage "--opening requires --feature"
[[ -f "$REGISTRY" && ! -L "$REGISTRY" && -r "$REGISTRY" ]] ||
  diagnostic repository registry-unreadable "registry is missing, linked, or unreadable"
jq -e . "$REGISTRY" >/dev/null 2>&1 ||
  diagnostic repository registry-malformed "registry is not valid JSON"
jq -e '
  .schema_version == 1 and
  (.entries | type == "array" and length > 0) and
  all(.entries[];
    (.feature | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
    (.profile == "full" or .profile == "lite" or .profile == "legacy"))
' "$REGISTRY" >/dev/null 2>&1 ||
  diagnostic repository registry-malformed "registry shape or version is invalid"
SCHEMA="$SCRIPT_ROOT/contracts/workflow-state-registry.schema.json"
[[ -f "$SCHEMA" ]] || diagnostic repository registry-schema "registry schema is unavailable"
jq -e --slurpfile schema "$SCHEMA" '
  (keys | sort) == ["entries","migration_baseline_commit","schema_version"] and
  .schema_version == $schema[0].properties.schema_version.const and
  .migration_baseline_commit == $schema[0].properties.migration_baseline_commit.const and
  (.entries | type == "array" and length > 0) and
  all(.entries[];
    if .profile == "full" or .profile == "lite" then
      (keys | sort) == ["feature","profile"]
    else
      . as $entry |
      any($schema[0].definitions.legacyEntry.oneOf[]; .const == $entry)
    end)
' "$REGISTRY" >/dev/null 2>&1 ||
  diagnostic repository registry-schema "registry entry violates the bounded schema"

SPECS_ROOT="$(cd "$(dirname "$REGISTRY")" && pwd -P)"
REPO_ROOT="$(cd "$SPECS_ROOT/.." && pwd -P)"
REPO_ROOT_ALIAS="$REPO_ROOT"
case "$REPO_ROOT" in
  /private/var/*) REPO_ROOT_ALIAS="/var/${REPO_ROOT#/private/var/}" ;;
  /var/*) REPO_ROOT_ALIAS="/private/var/${REPO_ROOT#/var/}" ;;
esac

duplicate="$(jq -r '[.entries[].feature] | group_by(.)[] | select(length > 1) | .[0]' "$REGISTRY" | head -1)"
[[ -z "$duplicate" ]] || diagnostic "$duplicate" registry-duplicate "feature is registered more than once"
# WFI-021: diagnostics accumulate across independent features instead of
# exiting at the first one. Each feature's checks run in a subshell so
# diagnostic()'s exit ends only that feature's iteration (the short-circuit
# WITHIN a feature is retained); the run exits non-zero at the end if any
# feature fired. A feature that fails these registry checks is excluded from
# the later per-feature validation loop, so no check is evaluated against
# state an earlier check already rejected.
workflow_state_failed=0
registry_failed_features=""
while IFS= read -r feature; do
  set +e
  (
    set -euo pipefail
    candidate="$SPECS_ROOT/$feature"
    [[ -e "$candidate" || -L "$candidate" ]] ||
      diagnostic "$feature" registry-dangling-entry "registered specification directory is missing"
    resolved="$(cd "$candidate" 2>/dev/null && pwd -P)" ||
      diagnostic "$feature" registry-unreadable-path "registered directory cannot be resolved"
    case "$resolved/" in "$SPECS_ROOT/"*) ;; *)
      diagnostic "$feature" registry-path-escape "registered directory escapes specs root" ;;
    esac
    [[ ! -L "$candidate" ]] ||
      diagnostic "$feature" registry-linked-entry "registered specification directory must not be linked"
  )
  entry_status=$?
  set -e
  if [[ "$entry_status" -ne 0 ]]; then
    workflow_state_failed=$((workflow_state_failed + 1))
    registry_failed_features="${registry_failed_features}${feature}"$'\n'
  fi
done < <(jq -r '.entries[].feature' "$REGISTRY")
for candidate in "$SPECS_ROOT"/*; do
  [[ -d "$candidate" || -L "$candidate" ]] || continue
  feature="$(basename "$candidate")"
  jq -e --arg feature "$feature" 'any(.entries[]; .feature == $feature)' "$REGISTRY" >/dev/null || {
    diagnostic_line "$feature" registry-unregistered-directory "specification directory is not registered"
    workflow_state_failed=$((workflow_state_failed + 1))
  }
done
if [[ -n "$FEATURE_FILTER" ]]; then
  jq -e --arg feature "$FEATURE_FILTER" 'any(.entries[]; .feature == $feature)' "$REGISTRY" >/dev/null ||
    diagnostic "$FEATURE_FILTER" registry-unknown-feature "feature is not registered"
fi

header_value() {
  local file="$1" header="$2"
  sed -n "s/^${header}:[[:space:]]*\\([^[:space:]\r]*\\).*/\\1/p" "$file" | head -1
}
normalized_hash() {
  local file="$1" stage="$2"
  local cr=""
  case "$stage" in
    spec)
      LC_ALL=C grep -q $'^Spec-Review-Status:.*\r$' "$file" && cr=$'\r'
      sed "s/^Spec-Review-Status:[[:space:]]*.*/Spec-Review-Status: Pending${cr}/" "$file" | sha256_stream ;;
    impl)
      LC_ALL=C grep -q $'^Impl-Review-Status:.*\r$' "$file" && cr=$'\r'
      sed "s/^Impl-Review-Status:[[:space:]]*.*/Impl-Review-Status: Pending${cr}/" "$file" | sha256_stream ;;
    task)
      LC_ALL=C grep -q $'^Task-Review-Status:.*\r$' "$file" && cr=$'\r'
      sed \
        -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending${cr}/" \
        -e "s/^Approval:[[:space:]]*.*/Approval: Draft${cr}/" \
        -e "s/^Status:[[:space:]]*.*/Status: Planned${cr}/" \
        -e "/^Second Approval:/d" "$file" | sha256_stream ;;
  esac
}
# A reviewed document's recorded hash legitimately takes either of two forms.
# An ordinary review runs while the stage's status field still reads `Pending`
# (impl-review-precheck.sh enforces that), so the reviewers record the raw
# bytes and the post-review flip to `Passed` is absorbed by normalized_hash().
# A re-review of an already-passed feature (--provenance-rereview) necessarily
# runs while the field already reads `Passed` -- that mode refuses to start
# otherwise -- so the reviewers record the raw bytes of THAT state, which no
# normalization can reproduce. Accepting either form does not weaken
# provenance: both prove the reviewers read the document's current body, and
# an edit to the body still matches neither.
# A task-stage re-review binds the raw bytes of an executable state (statuses
# uniformly `Implementation Complete` or `Done` with approvals granted). The
# quality gate's own later `Done` flips are lifecycle transitions, not body
# edits, so they must be absorbable the same way the ordinary flow's
# `Planned -> ...` flips are absorbed by normalized_hash(). These two extra
# canonical forms rewrite ONLY the lifecycle fields to each uniform
# re-review-legal state; a body edit still matches none of the four forms.
rereview_normalized_hash() {
  local file="$1" status="$2"
  local cr=""
  LC_ALL=C grep -q $'^Task-Review-Status:.*\r$' "$file" && cr=$'\r'
  sed \
    -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Passed${cr}/" \
    -e "s/^Approval:[[:space:]]*.*/Approval: Approved${cr}/" \
    -e "s/^Status:[[:space:]]*.*/Status: ${status}${cr}/" \
    -e "/^Second Approval:/d" "$file" | sha256_stream
}
reviewed_hash_accepted() {
  local file="$1" stage="$2" candidate="$3"
  [[ -n "$candidate" ]] || return 1
  [[ "$candidate" == "$(normalized_hash "$file" "$stage")" ]] && return 0
  [[ "$candidate" == "$(sha256_file "$file")" ]] && return 0
  if [[ "$stage" == task ]]; then
    [[ "$candidate" == "$(rereview_normalized_hash "$file" "Implementation Complete")" ]] && return 0
    [[ "$candidate" == "$(rereview_normalized_hash "$file" "Done")" ]] && return 0
  fi
  return 1
}
manifest_has_reviewed_hash() {
  local contract="$1" suffix="$2" file="$3" stage="$4" recorded_root="$5"
  manifest_has_hash "$contract" "$suffix" "$(normalized_hash "$file" "$stage")" "$recorded_root" && return 0
  manifest_has_hash "$contract" "$suffix" "$(sha256_file "$file")" "$recorded_root" && return 0
  if [[ "$stage" == task ]]; then
    manifest_has_hash "$contract" "$suffix" "$(rereview_normalized_hash "$file" "Implementation Complete")" "$recorded_root" && return 0
    manifest_has_hash "$contract" "$suffix" "$(rereview_normalized_hash "$file" "Done")" "$recorded_root" && return 0
  fi
  return 1
}
# The traceability matrix is the only task-stage input besides the task plan
# that carries a field the workflow is designed to advance: each requirement
# row's final cell records that requirement's delivery status. Binding the
# whole file froze that column too -- no full-profile feature has ever moved a
# row off the authoring-time default. This rewrites ONLY that one cell, and
# only when it already holds a value from the closed lifecycle vocabulary the
# state registry pins, so every other byte of every row -- code targets, test
# IDs, evidence paths -- still participates in the digest, and a body edit
# matches neither form. An out-of-vocabulary value is a body edit, not a
# lifecycle transition, and stays bound.
# The recorded digest is taken at authoring time, when every cell already holds
# the default, so the recorded raw digest and this normalized digest coincide
# there; that is why no producing-side field is needed.
# The trailing [[:space:]]* absorbs a CR, so CRLF input round-trips without a
# literal \r escape (BSD sed has none).
traceability_normalized_hash() {
  local file="$1"
  LC_ALL=C sed -E \
    -e 's/^(\|[[:space:]]*REQ-.*\|)([[:space:]]*)(Planned|In Progress|Implementation Complete|Done|Blocked)([[:space:]]*\|[[:space:]]*)$/\1\2Planned\4/' \
    "$file" | sha256_stream
}
traceability_hash_accepted() {
  local candidate="$1" raw="$2" normalized="$3"
  [[ -n "$candidate" ]] || return 1
  [[ "$candidate" == "$raw" || "$candidate" == "$normalized" ]]
}
manifest_has_hash() {
  local contract="$1" suffix="$2" expected="$3" recorded_root="$4"
  jq -e --arg suffix "$suffix" --arg expected "$expected" \
    --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg recorded "${recorded_root:+$recorded_root/}" '
    def relative_path:
      gsub("\\\\"; "/") |
      if startswith($repo) then .[($repo|length):]
      elif startswith($alias) then .[($alias|length):]
      elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
      elif test("^(/|[A-Za-z]:/)") then null
      else . end;
    ($suffix | ltrimstr("/")) as $target |
    all(.reviewers[]?;
      any(.allowed_input_manifest[]?;
        (.path | type == "string" and relative_path == $target) and .sha256 == $expected))
  ' "$contract" >/dev/null
}
# Like manifest_has_hash, but for a live file: accepts a manifest entry that
# matches either the file's current hash or (for plugins/ reference docs
# only) its content as of the commit that produced $contract. This tolerates
# legitimate later edits to plugins/ reference docs without weakening the
# check for any other input.
manifest_has_hash_for_file() {
  local contract="$1" suffix="$2" file="$3" recorded_root="$4" current pin plugins_relative historical
  current="$(sha256_file "$file")"
  manifest_has_hash "$contract" "$suffix" "$current" "$recorded_root" && return 0
  case "${suffix#/}" in
    plugins/*) ;;
    *) return 1 ;;
  esac
  # Same "not evaluable, not failed" rule plugins_hash_matches already
  # applies: a fixture root with no git history at all (e.g. a release
  # artifact, or WFI-024's reference-doc-forged-no-git fixture) has nothing
  # to reconcile a stale plugins/ manifest hash against, so this must be
  # accepted rather than rejected. Without this check, any live drift of a
  # plugins/ reference doc this function guards (spec-review-calibration.md,
  # reviewer-calibration.md) fails closed under no-git even though the
  # identical drift on risk-gate-matrix.md is correctly tolerated by
  # plugins_hash_matches -- the two functions must agree on this class.
  plugins_git_history_available || return 0
  pin="$(plugins_pin_commit "$contract")" || return 1
  plugins_relative="${suffix#/}"
  historical="$(plugins_hash_at_pin "$pin" "$plugins_relative")" || return 1
  manifest_has_hash "$contract" "$suffix" "$historical" "$recorded_root"
}
# Reuses the EXACT relative_path resolution manifest_has_hash uses (not a
# substring probe -- an annotated/prefix-confused path must resolve the
# same way here as it does everywhere else this manifest is read) to answer
# a narrower question than manifest_has_hash: ignoring sha256 entirely, was
# $suffix ever recorded in this manifest at all, and if so, at what
# hash(es)? Prints one distinct recorded sha256 per line. Zero lines means
# no reviewer declared this path -- a genuine provenance gap. Exactly one
# line means every entry for this path agrees on a single hash, which is
# what lets a caller tell "the manifest already knows this input, just at
# stale bytes" apart from "the manifest never knew this input at all."
# More than one line (reviewers disagree with each other about this path)
# is deliberately left for the caller to treat as inconclusive -- that is
# not simple staleness and must not be waved through by this function.
manifest_recorded_hashes_for_path() {
  local contract="$1" suffix="$2" recorded_root="$3"
  jq -r --arg suffix "$suffix" \
    --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg recorded "${recorded_root:+$recorded_root/}" '
    def relative_path:
      gsub("\\\\"; "/") |
      if startswith($repo) then .[($repo|length):]
      elif startswith($alias) then .[($alias|length):]
      elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
      elif test("^(/|[A-Za-z]:/)") then null
      else . end;
    ($suffix | ltrimstr("/")) as $target |
    [.reviewers[]?.allowed_input_manifest[]? |
      select(.path | type == "string" and relative_path == $target) |
      .sha256] | unique[]
  ' "$contract"
}
# Recorded manifest paths are absolute paths from the clone that produced the
# review evidence, whose directory name has no relation to this checkout's
# (worktrees, CI fixtures, and renamed clones are all legal). Split them on
# the repository's own structural top-level directories instead: every
# canonical manifest path is repo-relative under specs/, reports/, or
# plugins/. A split candidate only counts when the suffix it produces
# matches one of the canonical manifest shapes, so a feature slug that
# happens to be named "specs", "reports", or "plugins" cannot be mistaken
# for the repository root; a path with no unambiguous split is invalid. A
# wrong split cannot weaken tamper detection - the derived relative path
# must still match the canonical allowlist, its recorded sha256 must match
# the live file, and every manifest entry must agree on a single recorded
# root.
recorded_repo_root() {
  local contract="$1"
  jq -r --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" '
    def normalized: gsub("\\\\"; "/");
    def rooted: test("^(/|[A-Za-z]:/)");
    def canonical_suffix:
      test("^specs/[a-z0-9][a-z0-9-]*/[^/]+$") or
      test("^reports/(spec|impl|task)-review/[a-z0-9][a-z0-9-]*/attempt-[1-9][0-9]*/round-[1-9][0-9]*/[^/]+$") or
      test("^plugins/[a-z0-9][a-z0-9-]*/references/[^/]+$");
    [.reviewers[].allowed_input_manifest[].path |
      normalized |
      select(rooted and (startswith($repo) or startswith($alias) | not)) |
      . as $path |
      ([(($path | indices("/specs/")), ($path | indices("/reports/")), ($path | indices("/plugins/")))[] |
         . as $i | select($path[$i + 1:] | canonical_suffix) | $path[0:$i]]
        | unique) as $candidates |
      if ($candidates | length) == 1 then $candidates[0]
      else null
      end] as $roots |
    if any($roots[]; . == null) or ($roots | map(select(. != null)) | unique | length) > 1
    then "__INVALID__"
    else ($roots | map(select(. != null)) | unique | .[0] // "")
    end
  ' "$contract"
}
# A BLOCKED or NEEDS_WORK verdict is the terminal state of one review pass,
# not necessarily of the stage: a caller can re-open review after it (a
# fresh attempt, or another round of the same attempt), and it is that later
# pass -- not the one it superseded -- whose outcome the stage should be
# judged on while it is still running.
#
# A tree-only signal cannot express this: the gate that must pass before a
# new round is created runs BEFORE that round's own directory exists (this
# is precisely what impl-review-precheck.sh's own replay guard requires --
# "round destination already exists" is fatal), so nothing on disk can ever
# prove a round is "open" at the one moment this check needs to know it. An
# earlier version of this fix looked for a precheck-result.json in a later
# round directory; that file cannot exist yet either, for the same reason,
# so the exemption could never fire for the caller it exists for.
#
# The distinction that actually matters is who is asking, not what the tree
# looks like right now (same conflation as before, resolved one level up).
# A review-loop precheck opening round (attempt, round) knows those numbers
# as its own CLI arguments -- ATTEMPT and ROUND -- before it ever reaches
# this gate, and it is asking "may I start?", not "did this conclude?". It
# says so explicitly via --opening stage:attempt:round. A standalone
# invocation (CI, task-state-check, anything auditing the feature's health)
# never passes --opening and gets none of this exemption: the latest
# verdict governs for it exactly as before, unconditionally.
#
# --opening is not "a flag anyone can pass to wave away a BLOCKED verdict",
# because it does not assert "trust me, this stage is fine" -- it names one
# specific (attempt, round) pair, and this function independently checks
# that pair against the tree's own recorded history before granting
# anything. The ONLY value it will ever accept is the single true next slot
# after the latest recorded verdict: either the next round of the SAME
# attempt (best_round + 1) or round 1 of a BRAND NEW attempt
# (best_attempt + 1). A caller cannot use it to skip past an intervening
# verdict, resurrect an arbitrarily old BLOCKED attempt, or manufacture a
# history that was never reviewed -- it can only ever confirm that trying
# again, right here, right now, is the structurally legitimate next step,
# which is true for any BLOCKED or NEEDS_WORK stage by the review loop's
# own design. It grants no power beyond what the tree already permits; it
# only lets the one caller who is about to exercise that permission prove
# which pair of numbers it refers to before the evidence for it exists.
stage_is_being_opened() {
  local stage="$1" feature="$2" best_attempt="$3" best_round="$4"
  [[ -n "$OPENING_STAGE" && "$OPENING_STAGE" == "$stage" && "$FEATURE_FILTER" == "$feature" ]] ||
    return 1
  if ((OPENING_ATTEMPT == best_attempt && OPENING_ROUND == best_round + 1)) ||
     ((OPENING_ATTEMPT == best_attempt + 1 && OPENING_ROUND == 1)); then
    # Recorded as a side effect (not just a boolean return) so the
    # downstream-staleness tolerance below can be granted independently of
    # whether THIS stage's own PASS check happens to need the exemption --
    # see the call site right after best_attempt/best_round are computed.
    OPENING_VERIFIED_STAGE="$stage"
    return 0
  fi
  return 1
}
# Walk order for the three review stages, spec first. Used only to decide
# which stages are "downstream" of the one --opening names: opening impl
# must still require spec to be fully sound (upstream, untouched), while
# task -- reviewed after impl and liable to have pinned impl's own inputs
# (e.g. design.md) -- is where the recovery --opening exists for shows up
# as staleness, not corruption.
stage_order() {
  case "$1" in
    spec) printf '1\n' ;;
    impl) printf '2\n' ;;
    task) printf '3\n' ;;
  esac
}
# Empty unless a --opening slot has been independently verified (via
# stage_is_being_opened) as the structurally-next one for the stage it
# names. Never set for a standalone invocation (no --opening), and never
# set for a slot that fails that verification.
OPENING_VERIFIED_STAGE=""
# True only when $1 is strictly downstream (in walk order) of the verified
# --opening stage. False when --opening was not passed or did not verify,
# false for the opened stage itself (it keeps its own pre-existing
# exemption above, not this one), and false for any upstream stage.
stage_downstream_of_opening() {
  local stage="$1"
  [[ -n "$OPENING_VERIFIED_STAGE" ]] || return 1
  (( $(stage_order "$stage") > $(stage_order "$OPENING_VERIFIED_STAGE") ))
}
# Like diagnostic(), but tolerated -- returns success instead of exiting --
# when the stage under validation is strictly downstream of a verified
# --opening slot. Reserved for diagnostics that mean "the pinned bytes
# moved": the expected, recoverable state of a downstream stage whose own
# reviewed input (e.g. design.md, a layer spec) was legitimately amended as
# part of the very recovery --opening exists to permit. Every call site
# below is commented with why that specific diagnostic qualifies.
diagnostic_or_tolerate() {
  local feature="$1" stage="$2" category="$3" message="$4"
  stage_downstream_of_opening "$stage" && return 0
  diagnostic "$feature" "$category" "$message"
}
# manifest_has_hash's "no (path, hash) pair matches" failure conflates two
# different provenance states: the path was never declared (a genuine gap)
# and the path was declared but the review ran before the file's current
# amendment (staleness wearing the same diagnostic). Both produce the
# identical boolean false, so every "reviewer manifests omit ..." /
# "contract hashes are stale" diagnostic built on it inherited that
# ambiguity. This resolves it, narrowly: only when downstream of a verified
# --opening slot (never standalone, never upstream -- same discipline as
# diagnostic_or_tolerate above), ask manifest_recorded_hashes_for_path
# whether the path was recorded at all. Exactly one recorded hash,
# different from the expected (current) one, is unambiguous staleness --
# the manifest already knew this input, just at pre-amendment bytes -- and
# is tolerated with a notice naming the path and both hashes, so the
# recovery is visible rather than silently waved through. Zero recorded
# hashes (the path never appeared) or more than one distinct recorded hash
# (reviewers disagree about this path, which is not simple staleness)
# leave the original diagnostic firing exactly as before.
print_tolerated_omit_notice() {
  local feature="$1" suffix="$2" recorded="$3" expected="$4"
  printf 'workflow-state: %s: stage-provenance-tolerated: %s recorded %s, now %s\n' \
    "$feature" "${suffix#/}" "$recorded" "$expected" >&2
}
# $1=feature $2=stage $3=category $4=message $5=contract $6=recorded_root,
# followed by any number of (ok, suffix, expected) triples -- one per path
# the failing check covers. A check that aggregates several paths (e.g.
# calibration doc + precheck-result.json, or requirements.md +
# acceptance-tests.md) must still fail with its ORIGINAL diagnostic if even
# ONE of its paths is a genuine omission, regardless of whether the others
# are merely stale -- so every not-ok triple must independently explain as
# staleness for the whole check to be tolerated.
diagnostic_or_tolerate_omit() {
  local feature="$1" stage="$2" category="$3" message="$4" contract="$5" recorded_root="$6"
  shift 6
  local all_explained=1 ok suffix expected hashes count explained
  while (($#)); do
    ok="$1"; suffix="$2"; expected="$3"; shift 3
    ((ok)) && continue
    explained=0
    if stage_downstream_of_opening "$stage"; then
      hashes="$(manifest_recorded_hashes_for_path "$contract" "$suffix" "$recorded_root")"
      count=0
      [[ -z "$hashes" ]] || count="$(printf '%s\n' "$hashes" | grep -c .)"
      if [[ "$count" -eq 1 && "$hashes" != "$expected" ]]; then
        print_tolerated_omit_notice "$feature" "$suffix" "$hashes" "$expected"
        explained=1
      fi
    fi
    ((explained)) || all_explained=0
  done
  ((all_explained)) && return 0
  diagnostic "$feature" "$category" "$message"
}
validate_passed_stage() {
  local feature="$1" stage="$2" feature_dir="$3"
  local root="$REPO_ROOT/reports/${stage}-review/$feature"
  [[ -d "$root" && ! -L "$root" ]] ||
    diagnostic "$feature" stage-provenance "$stage PASS has no review report root"
  local best="" best_attempt=0 best_round=0 candidate relative attempt round
  while IFS= read -r candidate; do
    [[ ! -L "$candidate" && -f "$candidate" ]] ||
      diagnostic "$feature" stage-provenance "$stage verdict evidence is linked or unreadable"
    relative="${candidate#"$root/"}"
    [[ "$relative" =~ ^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/integrated-verdict\.json$ ]] ||
      diagnostic "$feature" stage-provenance "$stage verdict has a noncanonical path"
    attempt="${BASH_REMATCH[1]}"; round="${BASH_REMATCH[2]}"
    if ((attempt > best_attempt || (attempt == best_attempt && round > best_round))); then
      best="$candidate"; best_attempt="$attempt"; best_round="$round"
    fi
  done < <(find "$root" -name integrated-verdict.json -print)
  # Verify --opening's slot for THIS stage now, unconditionally -- not only
  # when this stage's own verdict later turns out to need excusing. A
  # re-review opened after an already-valid PASS (--provenance-rereview)
  # never reaches the failure branch below, but downstream tolerance must
  # still be available in that case: the flag names the slot, not "this
  # stage is currently broken".
  stage_is_being_opened "$stage" "$feature" "$best_attempt" "$best_round" || true
  [[ -n "$best" ]] || diagnostic "$feature" stage-provenance "$stage PASS has no integrated verdict"
  local contract="$(dirname "$best")/${stage}-review-contract.json"
  local round_dir="$(dirname "$best")"
  local reviewer_a="$round_dir/reviewer-a.json"
  local reviewer_b="$round_dir/reviewer-b.json"
  local summary="$round_dir/integrated-summary.json"
  [[ -f "$contract" && ! -L "$contract" && -r "$contract" ]] ||
    diagnostic "$feature" stage-provenance "$stage PASS has no readable review contract"
  for candidate in "$reviewer_a" "$reviewer_b" "$summary"; do
    [[ -f "$candidate" && ! -L "$candidate" && -r "$candidate" ]] ||
      diagnostic "$feature" stage-provenance "$stage reviewer evidence is missing, linked, or unreadable"
    jq -e . "$candidate" >/dev/null 2>&1 ||
      diagnostic "$feature" stage-provenance "$stage reviewer evidence is malformed"
  done
  if ! jq -e --arg feature "$feature" --arg stage "$stage" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    .feature == $feature and .stage == $stage and .attempt == $attempt and
    .round == $round and
    (.verdict == "PASS" or ($stage != "spec" and .verdict == "PASS-with-warnings")) and
    (if $stage == "spec" then
      .schema == "spec-review-integrated-verdict/v1" and
      ([.reviewer_a_run_id,.reviewer_b_run_id,.reviewer_a_host_session_id,.reviewer_b_host_session_id]
       | all(type == "string" and length > 0)) and
      .reviewer_a_run_id != .reviewer_b_run_id and
      .reviewer_a_host_session_id != .reviewer_b_host_session_id
     else
      .schema == "integrated-verdict/v1" and
      (.run_id | type == "string" and length > 0) and
      (.reviewer_a_verdict == "PASS" or .reviewer_a_verdict == "NEEDS_WORK") and
      (.reviewer_b_verdict == "PASS" or .reviewer_b_verdict == "NEEDS_WORK") and
      .findings_critical == 0 and .findings_major == 0 and
      (.findings_minor | type == "number" and . >= 0)
     end)
  ' "$best" >/dev/null 2>&1; then
    stage_is_being_opened "$stage" "$feature" "$best_attempt" "$best_round" && return 0
    diagnostic "$feature" stage-provenance "$stage integrated verdict is not a valid PASS"
  fi
  jq -e --arg feature "$feature" --arg stage "$stage" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    .schema == ($stage + "-review-contract/v1") and .feature == $feature and
    .stage == $stage and .attempt == $attempt and .round == $round and
    (.verdict == "PASS" or ($stage != "spec" and .verdict == "PASS-with-warnings")) and
    (.run_id | type == "string" and length > 0) and
    ($stage == "spec" or
      ((.reviewer_a_verdict == "PASS" or .reviewer_a_verdict == "NEEDS_WORK") and
       (.reviewer_b_verdict == "PASS" or .reviewer_b_verdict == "NEEDS_WORK") and
       .findings_critical == 0 and .findings_major == 0 and
       (.findings_minor | type == "number" and . >= 0))) and
    ([.reviewers[]?.role] | sort) == [($stage+"-reviewer-a"),($stage+"-reviewer-b")] and
    ([.reviewers[]?.run_id] | all(type == "string" and length > 0) and (unique|length)==2) and
    ([.reviewers[]?.host_session_id] | all(type == "string" and length > 0) and (unique|length)==2)
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage review contract identity is invalid"
  local recorded_root
  recorded_root="$(recorded_repo_root "$contract")"
  [[ "$recorded_root" != "__INVALID__" ]] ||
    diagnostic "$feature" stage-provenance "$stage reviewer manifest paths are not canonical"
  jq -e --arg feature "$feature" --arg stage "$stage" \
    --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg recorded "${recorded_root:+$recorded_root/}" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    def relative_path:
      gsub("\\\\"; "/") |
      if startswith($repo) then .[($repo|length):]
      elif startswith($alias) then .[($alias|length):]
      elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
      elif test("^(/|[A-Za-z]:/)") then null
      else . end;
    def allowed($role; $path):
      ("reports/" + $stage + "-review/" + $feature + "/attempt-" + ($attempt|tostring)) as $attempt_root |
      ($attempt_root + "/round-" + ($round|tostring)) as $round_root |
      ($path == ("specs/" + $feature + "/requirements.md")) or
      ($path == ("specs/" + $feature + "/acceptance-tests.md")) or
      ($path == ("specs/" + $feature + "/investigation.md")) or
      ($stage == "impl" and
        ($path == ("specs/" + $feature + "/design.md") or
         $path == ("specs/" + $feature + "/ux-spec.md") or
         $path == ("specs/" + $feature + "/frontend-spec.md") or
         $path == ("specs/" + $feature + "/infra-spec.md") or
         $path == ("specs/" + $feature + "/security-spec.md"))) or
      ($stage == "task" and
        ($path == ("specs/" + $feature + "/tasks.md") or
         $path == ("specs/" + $feature + "/design.md") or
         $path == ("specs/" + $feature + "/traceability.md") or
         $path == ("specs/" + $feature + "/ux-spec.md") or
         $path == ("specs/" + $feature + "/frontend-spec.md") or
         $path == ("specs/" + $feature + "/infra-spec.md") or
         $path == ("specs/" + $feature + "/security-spec.md"))) or
      ($path == (if $stage == "spec" then
                   "plugins/sdd-review-loop/references/spec-review-calibration.md"
                 else "plugins/sdd-review-loop/references/reviewer-calibration.md" end)) or
      ($path == ($round_root + "/precheck-result.json")) or
      ($role == ($stage + "-reviewer-b") and $path == ($round_root + "/integrated-summary.json")) or
      ($stage == "impl" and $role == "impl-reviewer-a" and $round > 1 and
       $path == ($attempt_root + "/round-" + (($round-1)|tostring) + "/integrated-summary.json")) or
      ($stage == "task" and $role == "task-reviewer-a" and
       $path == ($round_root + "/dependency-graph.json")) or
      ($stage == "task" and $role == "task-reviewer-b" and
       ($path == "plugins/sdd-quality-loop/references/risk-gate-matrix.md" or
        $path == "plugins/sdd-quality-loop/references/risk-classification-policy.md"));
    all(.reviewers[];
      .role as $role |
      ([.allowed_input_manifest[].path | relative_path] as $paths |
       ($paths | all(. != null and (test("(^|/)\\.\\.?(/|$)")|not))) and
       ($paths | length) == ($paths | unique | length) and
       all($paths[]; allowed($role; .))))
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage reviewer manifest paths are not canonical"
  while IFS=$'\t' read -r manifest_path manifest_hash; do
    manifest_path="${manifest_path//\\//}"
    if [[ -n "$recorded_root" && "$manifest_path" == "$recorded_root/"* ]]; then
      manifest_relative="${manifest_path#"$recorded_root/"}"
      manifest_file="$REPO_ROOT/$manifest_relative"
    else
      case "$manifest_path" in
        "$REPO_ROOT"/*) manifest_file="$manifest_path"; manifest_relative="${manifest_path#"$REPO_ROOT/"}" ;;
        "$REPO_ROOT_ALIAS"/*)
          manifest_relative="${manifest_path#"$REPO_ROOT_ALIAS/"}"
          manifest_file="$REPO_ROOT/$manifest_relative" ;;
        /*|[A-Za-z]:/*) diagnostic "$feature" stage-provenance "$stage reviewer manifest path escapes repository" ;;
        *) manifest_file="$REPO_ROOT/$manifest_path"; manifest_relative="$manifest_path" ;;
      esac
    fi
    case "$manifest_relative" in
      "specs/$feature/requirements.md"|"specs/$feature/design.md"|"specs/$feature/tasks.md"|"specs/$feature/traceability.md"|"specs/$feature/acceptance-tests.md") continue ;;
    esac
    [[ -f "$manifest_file" && ! -L "$manifest_file" && -r "$manifest_file" ]] ||
      diagnostic "$feature" stage-provenance "$stage reviewer manifest input is missing or unreadable"
    case "$manifest_relative" in
      # Tolerated downstream: for each entry the manifest already recorded,
      # this asks "does the live file still match what was pinned" -- an
      # unambiguous freshness check with no existence question folded in
      # (an entry that was never recorded is never visited by this loop at
      # all, so a missing declaration can't hide behind this tolerance).
      plugins/*)
        plugins_hash_matches "$manifest_file" "$manifest_hash" "$contract" ||
          diagnostic_or_tolerate "$feature" "$stage" stage-provenance "$stage reviewer manifest input hash is stale" ;;
      # Tolerated STANDALONE (no --opening needed): the amendment
      # re-review lane's own oscillation, where a downstream stage's
      # recovery grows this file's `## Amendment Re-Review Context`
      # section after an upstream stage already pinned it. Tried first;
      # falls through to the ordinary --opening-based tolerance (and, if
      # that does not apply either, the original diagnostic) when the
      # live change is not pure, section-confined growth over
      # independently-verified historical bytes.
      "specs/$feature/investigation.md")
        current_hash="$(sha256_file "$manifest_file")"
        if [[ "$current_hash" != "$manifest_hash" ]]; then
          if investigation_amendment_reconciles "$manifest_file" "$manifest_hash" "$contract"; then
            print_investigation_amendment_notice "$feature" "$stage" "$manifest_relative" "$manifest_hash" "$current_hash"
          else
            diagnostic_or_tolerate "$feature" "$stage" stage-provenance "$stage reviewer manifest input hash is stale"
          fi
        fi ;;
      *)
        [[ "$(sha256_file "$manifest_file")" == "$manifest_hash" ]] ||
          diagnostic_or_tolerate "$feature" "$stage" stage-provenance "$stage reviewer manifest input hash is stale" ;;
    esac
  done < <(jq -r '.reviewers[].allowed_input_manifest[] | .path + "\t" + .sha256' "$contract")
  jq -e --slurpfile verdict "$best" --arg stage "$stage" '
    .attempt == $verdict[0].attempt and .round == $verdict[0].round and
    .verdict == $verdict[0].verdict and
    (if $stage == "spec" then
      (.reviewers|map({key:.role,value:{run_id:.run_id,host:.host_session_id}})|from_entries) as $r |
      $r["spec-reviewer-a"].run_id == $verdict[0].reviewer_a_run_id and
      $r["spec-reviewer-b"].run_id == $verdict[0].reviewer_b_run_id and
      $r["spec-reviewer-a"].host == $verdict[0].reviewer_a_host_session_id and
      $r["spec-reviewer-b"].host == $verdict[0].reviewer_b_host_session_id
     else .run_id == $verdict[0].run_id end)
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage contract and verdict contradict each other"

  # WFI-030 item 7: the round's precheck carries frozen_artifact_done_when, and
  # reviewer-a must adjudicate every entry by name. A round recorded before the
  # detector existed has no such file field; pointing --slurpfile at /dev/null
  # yields an empty array, so $precheck[0] is null and `// []` below treats it
  # as nothing to adjudicate rather than as a violation.
  local round_precheck="$round_dir/precheck-result.json"
  [[ -f "$round_precheck" ]] || round_precheck=/dev/null

  jq -e --slurpfile contract "$contract" --slurpfile verdict "$best" \
    --slurpfile reviewer_b "$reviewer_b" --slurpfile summary "$summary" --arg stage "$stage" \
    --slurpfile precheck "$round_precheck" \
    --arg feature "$feature" --arg repo "$REPO_ROOT/" --arg alias "$REPO_ROOT_ALIAS/" \
    --arg recorded "${recorded_root:+$recorded_root/}" \
    --argjson attempt "$best_attempt" --argjson round "$best_round" '
    def normalized_manifest:
      map({path: .path, sha256: .sha256}) | sort_by(.path);
    def manifest_relative_path:
      gsub("\\\\"; "/") |
      if startswith($repo) then .[($repo|length):]
      elif startswith($alias) then .[($alias|length):]
      elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
      elif test("^(/|[A-Za-z]:/)") then null
      else . end;
    def is_allowed_layer_superset_path:
      # Scoped to impl-review only (issue #71): impl reviewers may have
      # legitimately reviewed the four layer specs even when the round
      # contract predates recording them. Spec/task stages must still
      # match the contract exactly.
      $stage == "impl" and
      manifest_relative_path as $rel |
      ($rel != null) and
      ($rel == ("specs/" + $feature + "/ux-spec.md") or
       $rel == ("specs/" + $feature + "/frontend-spec.md") or
       $rel == ("specs/" + $feature + "/infra-spec.md") or
       $rel == ("specs/" + $feature + "/security-spec.md"));
    def manifest_superset_ok($reviewer_manifest; $contract_manifest):
      ($contract_manifest | normalized_manifest) as $contract_norm |
      ($reviewer_manifest | normalized_manifest) as $reviewer_norm |
      # Every contract entry must be present in the reviewer manifest
      # (path+sha256 pair) -- the contract must never be a superset.
      (($contract_norm - $reviewer_norm) | length) == 0 and
      # Reviewer manifest may only exceed the contract with the four
      # implementation layer specs; any other extra entry is a fail.
      (($reviewer_norm - $contract_norm) | all(.path | is_allowed_layer_superset_path));
    def reviewer_contract($role):
      $contract[0].reviewers[] | select(.role == $role);
    def check_result:
      if $stage == "task" then .status else .result end;
    def failures($reviewer):
      if $stage == "task" then [$reviewer.findings[]?]
      else [$reviewer.checks[]? | select(.result == "FAIL")] end;
    def expected_reviewer_verdict($reviewer):
      failures($reviewer) as $f |
      if any($f[]?; .severity == "Critical") then "BLOCKED"
      elif ($f | length) > 0 then "NEEDS_WORK"
      else "PASS" end;
    . as $a |
    $reviewer_b[0] as $b |
    (if $stage == "task" then
       ($a.schema == "task-reviewer-a/v1" and $a.stage == "task-review" and
        $a.role == "reviewer-a" and $b.schema == "task-reviewer-b/v1" and
        $b.stage == "task" and $b.role == "task-reviewer-b" and
        $a.feature == $contract[0].feature and $b.feature == $contract[0].feature and
        $a.attempt == $attempt and $b.attempt == $attempt and
        $a.round == $round and $b.round == $round)
     else
       ($a.schema == ($stage + "-reviewer-a/v1") and $a.stage == $stage and
        $a.role == ($stage + "-reviewer-a") and
        $b.schema == ($stage + "-reviewer-b/v1") and $b.stage == $stage and
        $b.role == ($stage + "-reviewer-b"))
     end) and
    ([$a.run_id,$a.host_session_id,$b.run_id,$b.host_session_id]
      | all(type == "string" and length > 0)) and
    $a.run_id == reviewer_contract($stage + "-reviewer-a").run_id and
    $a.host_session_id == reviewer_contract($stage + "-reviewer-a").host_session_id and
    $b.run_id == reviewer_contract($stage + "-reviewer-b").run_id and
    $b.host_session_id == reviewer_contract($stage + "-reviewer-b").host_session_id and
    manifest_superset_ok(
      (if $stage == "task" then $a.manifest else $a.allowed_input_manifest end);
      reviewer_contract($stage + "-reviewer-a").allowed_input_manifest) and
    manifest_superset_ok(
      (if $stage == "task" then $b.manifest.allowed_inputs else $b.allowed_input_manifest end);
      reviewer_contract($stage + "-reviewer-b").allowed_input_manifest) and
    $a.verdict == expected_reviewer_verdict($a) and
    $b.verdict == expected_reviewer_verdict($b) and
    (failures($a) + failures($b) |
      all(.severity == "Critical" or .severity == "Major" or .severity == "Minor")) and
    (if $stage == "task" then
       ([$a.checks[] | select(.status == "FAIL")] | length) == ($a.findings | length) and
       ([$b.checks[] | select(.result == "FAIL")] | length) == ($b.findings | length) and
       # WFI-030 item 7: every Done When item the precheck flagged as naming a
       # review-frozen artifact must be adjudicated by task ID in the
       # OBSERVABLE-DONE finding of reviewer-a. This does not judge the
       # adjudication -- the detector is deliberately permissive and the reviewer
       # decides -- it only requires that the decision was recorded against each
       # flagged task. (No apostrophes here: the jq program is single-quoted.)
       (([$a.checks[]? | select(.id == "OBSERVABLE-DONE") | (.finding // "")]
          | join(" ")) as $observed |
        all(($precheck[0].frozen_artifact_done_when // [])[];
            . as $flagged | $observed | contains($flagged.task)))
     else true end) and
    ($summary[0].schema == "integrated-summary/v1" and
     $summary[0].attempt == $attempt and $summary[0].round == $round) and
    ([$a.checks[] | .id] | sort) ==
      ((if $stage == "spec" then [$summary[0].reviewer_a_checks[] | .id]
        else $summary[0].reviewer_a_check_ids end) | sort) and
    ([$a.checks[] | select(check_result == "FAIL")] | length) ==
      $summary[0].reviewer_a_fail_count and
    ([$a.checks[] | select(check_result == "PASS")] | length) ==
      $summary[0].reviewer_a_pass_count and
    ([$a.checks[] | select(check_result == "SKIP")] | length) ==
      $summary[0].reviewer_a_skip_count and
    ((failures($a) + failures($b)) as $findings |
     {critical: ([$findings[] | select(.severity == "Critical")] | length),
      major: ([$findings[] | select(.severity == "Major")] | length),
      minor: ([$findings[] | select(.severity == "Minor")] | length)} as $counts |
     ($counts.critical == 0 and $counts.major == 0 and
      ($counts.minor == 0 or $round == 3)) and
     (if $stage == "spec" then
        $contract[0].verdict == "PASS" and
        $contract[0].warningCount == $counts.minor and
        $verdict[0].verdict == "PASS" and
        $verdict[0].warningCount == $counts.minor and
        $verdict[0].finding_counts == $counts
      else
        ($counts.minor == 0 and $contract[0].verdict == "PASS" and
         $verdict[0].verdict == "PASS" or
         $counts.minor > 0 and $contract[0].verdict == "PASS-with-warnings" and
         $verdict[0].verdict == "PASS-with-warnings") and
        $contract[0].findings_critical == $counts.critical and
        $contract[0].findings_major == $counts.major and
        $contract[0].findings_minor == $counts.minor and
        $verdict[0].findings_critical == $counts.critical and
        $verdict[0].findings_major == $counts.major and
        $verdict[0].findings_minor == $counts.minor and
        $contract[0].reviewer_a_verdict == $a.verdict and
        $contract[0].reviewer_b_verdict == $b.verdict and
        $verdict[0].reviewer_a_verdict == $a.verdict and
        $verdict[0].reviewer_b_verdict == $b.verdict
      end))
  ' "$reviewer_a" >/dev/null 2>&1 ||
    diagnostic "$feature" stage-provenance "$stage reviewer outputs or integrated summary contradict the final PASS"

  local req="$feature_dir/requirements.md" accept="$feature_dir/acceptance-tests.md"
  local req_hash accept_hash
  [[ -f "$req" && -f "$accept" && ! -L "$req" && ! -L "$accept" ]] ||
    diagnostic "$feature" stage-provenance "$stage canonical inputs are missing"
  accept_hash="$(sha256_file "$accept")"
  if [[ "$stage" == spec ]]; then req_hash="$(normalized_hash "$req" spec)"
  else req_hash="$(sha256_file "$req")"; fi
  # Tolerated downstream: direct comparison of the contract's own top-level
  # field against a freshly computed live-file hash -- unambiguous
  # freshness, no manifest-array existence question involved.
  jq -e --arg stage "$stage" --arg req "$req_hash" --arg accept "$accept_hash" '
    .requirements_sha256 == $req and .acceptance_sha256 == $accept
  ' "$contract" >/dev/null 2>&1 ||
    diagnostic_or_tolerate "$feature" "$stage" stage-provenance "$stage top-level contract hashes are stale"
  # manifest_has_hash's ambiguity, disambiguated per path: if EVERY
  # not-matching path is explainable as "recorded, just at a stale hash"
  # (downstream of a verified --opening slot only), tolerate; a single
  # genuinely undeclared path among them still fails the whole check.
  local req_manifest_ok accept_manifest_ok
  req_manifest_ok=0
  manifest_has_hash "$contract" "/specs/$feature/requirements.md" "$req_hash" "$recorded_root" && req_manifest_ok=1
  accept_manifest_ok=0
  manifest_has_hash "$contract" "/specs/$feature/acceptance-tests.md" "$accept_hash" "$recorded_root" && accept_manifest_ok=1
  diagnostic_or_tolerate_omit "$feature" "$stage" stage-provenance \
    "$stage contract hashes are stale" "$contract" "$recorded_root" \
    "$req_manifest_ok" "/specs/$feature/requirements.md" "$req_hash" \
    "$accept_manifest_ok" "/specs/$feature/acceptance-tests.md" "$accept_hash"
  local calibration precheck
  if [[ "$stage" == spec ]]; then
    calibration="$REPO_ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md"
  else
    calibration="$REPO_ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md"
  fi
  precheck="$root/attempt-$best_attempt/round-$best_round/precheck-result.json"
  [[ -f "$calibration" && ! -L "$calibration" && -f "$precheck" && ! -L "$precheck" ]] ||
    diagnostic "$feature" stage-provenance "$stage required review inputs are missing"
  # Same per-path disambiguation. The calibration doc's own plugins/
  # historical-pin fallback (manifest_has_hash_for_file) is tried FIRST and
  # is unrelated to this recovery; only if that ALSO fails does the
  # omit-vs-stale query run, comparing against the calibration doc's
  # current live hash like every other check here.
  local calibration_hash precheck_hash calibration_manifest_ok precheck_manifest_ok
  calibration_hash="$(sha256_file "$calibration")"
  calibration_manifest_ok=0
  manifest_has_hash_for_file "$contract" "/${calibration#"$REPO_ROOT/"}" "$calibration" "$recorded_root" &&
    calibration_manifest_ok=1
  precheck_hash="$(sha256_file "$precheck")"
  precheck_manifest_ok=0
  manifest_has_hash "$contract" "/${precheck#"$REPO_ROOT/"}" "$precheck_hash" "$recorded_root" &&
    precheck_manifest_ok=1
  diagnostic_or_tolerate_omit "$feature" "$stage" stage-provenance \
    "$stage reviewer manifests omit required inputs" "$contract" "$recorded_root" \
    "$calibration_manifest_ok" "/${calibration#"$REPO_ROOT/"}" "$calibration_hash" \
    "$precheck_manifest_ok" "/${precheck#"$REPO_ROOT/"}" "$precheck_hash"
  if [[ "$stage" == impl ]]; then
    local design="$feature_dir/design.md"
    [[ -f "$design" && ! -L "$design" ]] ||
      diagnostic "$feature" stage-provenance "implementation design is missing"
    # Tolerated downstream: manifest_has_reviewed_hash tries every
    # canonical hash form design.md's own reviewed state can legitimately
    # take (raw, lifecycle-normalized, re-review). Unlike the plain
    # manifest_has_hash "omit" checks below, this represents the
    # document's own provenance-hash pin, not an array-membership existence
    # question -- the same role "task plan hash is stale" plays for
    # tasks.md, which the deadlock this fix resolves depends on tolerating.
    manifest_has_reviewed_hash "$contract" "/specs/$feature/design.md" "$design" impl "$recorded_root" ||
      diagnostic_or_tolerate "$feature" "$stage" stage-provenance "implementation design hash is stale"
    # Tolerated downstream: direct top-level field vs live-hash comparison.
    reviewed_hash_accepted "$design" impl "$(jq -r '.design_sha256 // empty' "$contract")" ||
      diagnostic_or_tolerate "$feature" "$stage" stage-provenance "implementation top-level design hash is stale"
    if [[ "$(jq -r '(.layer_sha256 // {}) | length' "$precheck")" -gt 0 ]]; then
      jq -e '(.layer_sha256 | keys) == ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"]' "$precheck" >/dev/null ||
        diagnostic "$feature" stage-provenance "implementation layer precheck manifest is incomplete"
      # The omit-vs-stale disambiguation runs once across all four layers
      # (an aggregate check, like calibration+precheck and req/accept
      # above): one genuinely undeclared layer must still fail the whole
      # check even if the other three are merely stale.
      local layer_omit_triples=()
      for layer in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
        layer_path="$feature_dir/$layer"
        [[ -f "$layer_path" && ! -L "$layer_path" ]] ||
          diagnostic "$feature" stage-provenance "implementation layer input is missing or linked"
        layer_hash="$(sha256_file "$layer_path")"
        # Tolerated downstream: direct precheck/contract field vs live-hash
        # comparison.
        [[ "$(jq -r --arg layer "$layer" '.layer_sha256[$layer] // empty' "$precheck")" == "$layer_hash" &&
           "$(jq -r --arg layer "$layer" '.layer_sha256[$layer] // empty' "$contract")" == "$layer_hash" ]] ||
          diagnostic_or_tolerate "$feature" "$stage" stage-provenance "implementation layer hash is stale"
        local layer_manifest_ok
        layer_manifest_ok=0
        manifest_has_hash "$contract" "/specs/$feature/$layer" "$layer_hash" "$recorded_root" && layer_manifest_ok=1
        layer_omit_triples+=("$layer_manifest_ok" "/specs/$feature/$layer" "$layer_hash")
      done
      diagnostic_or_tolerate_omit "$feature" "$stage" stage-provenance \
        "implementation reviewer manifests omit layer inputs" "$contract" "$recorded_root" \
        "${layer_omit_triples[@]}"
    fi
  elif [[ "$stage" == task ]]; then
    local tasks="$feature_dir/tasks.md" traceability="$feature_dir/traceability.md"
    [[ -f "$tasks" && ! -L "$tasks" ]] ||
      diagnostic "$feature" stage-provenance "task plan is missing"
    # Tolerated downstream: same class as the design.md pin above -- the
    # document's own provenance-hash pin, tried across every canonical form.
    # This is the literal diagnostic the epic-196 deadlock names.
    manifest_has_reviewed_hash "$contract" "/specs/$feature/tasks.md" "$tasks" task "$recorded_root" ||
      diagnostic_or_tolerate "$feature" "$stage" stage-provenance "task plan hash is stale"
    # Tolerated downstream: direct top-level field vs live-hash comparison.
    reviewed_hash_accepted "$tasks" task "$(jq -r '.tasks_sha256 // empty' "$contract")" ||
      diagnostic_or_tolerate "$feature" "$stage" stage-provenance "task top-level plan hash is stale"
    if [[ "$(jq -r '(.layer_sha256 // {}) | length' "$precheck")" -gt 0 ]]; then
      [[ -f "$traceability" && ! -L "$traceability" ]] ||
        diagnostic "$feature" stage-provenance "task traceability input is missing or linked"
      local traceability_hash traceability_normalized
      traceability_hash="$(sha256_file "$traceability")"
      traceability_normalized="$(traceability_normalized_hash "$traceability")"
      # Tolerated downstream: direct precheck/contract field vs live-hash
      # (raw or normalized) comparison.
      if ! traceability_hash_accepted "$(jq -r '.traceability_sha256 // empty' "$precheck")" \
             "$traceability_hash" "$traceability_normalized" ||
         ! traceability_hash_accepted "$(jq -r '.traceability_sha256 // empty' "$contract")" \
             "$traceability_hash" "$traceability_normalized"; then
        diagnostic_or_tolerate "$feature" "$stage" stage-provenance "task traceability hash is stale"
      fi
      local task_design_hash
      task_design_hash="$(sha256_file "$feature_dir/design.md")"
      # Tolerated downstream: direct precheck/contract field vs live-hash
      # comparison -- this is design.md's staleness surfacing on the task
      # side of the epic-196 deadlock (design.md is impl's own reviewed
      # input, task's contract separately pins its hash too).
      [[ "$(jq -r '.design_sha256 // empty' "$precheck")" == "$task_design_hash" &&
         "$(jq -r '.design_sha256 // empty' "$contract")" == "$task_design_hash" ]] ||
        diagnostic_or_tolerate "$feature" "$stage" stage-provenance "task design hash is stale"
      # manifest_has_hash's ambiguity, disambiguated: this is the literal
      # epic-196 residual gate ("task reviewer manifests omit design") --
      # design.md's manifest entry recorded at the pre-amendment hash reads
      # identically to design.md never having been declared at all, unless
      # this second query tells them apart.
      local design_manifest_ok
      design_manifest_ok=0
      manifest_has_hash "$contract" "/specs/$feature/design.md" "$task_design_hash" "$recorded_root" &&
        design_manifest_ok=1
      diagnostic_or_tolerate_omit "$feature" "$stage" stage-provenance \
        "task reviewer manifests omit design" "$contract" "$recorded_root" \
        "$design_manifest_ok" "/specs/$feature/design.md" "$task_design_hash"
      # Traceability accepts either the raw or the lifecycle-normalized
      # form as "ok"; within the not-ok branch the recorded hash (if
      # singular) is therefore guaranteed to differ from both, so comparing
      # it against the raw form alone is sufficient for the notice.
      local traceability_manifest_ok
      traceability_manifest_ok=0
      { manifest_has_hash "$contract" "/specs/$feature/traceability.md" "$traceability_hash" "$recorded_root" ||
        manifest_has_hash "$contract" "/specs/$feature/traceability.md" "$traceability_normalized" "$recorded_root"; } &&
        traceability_manifest_ok=1
      diagnostic_or_tolerate_omit "$feature" "$stage" stage-provenance \
        "task reviewer manifests omit traceability" "$contract" "$recorded_root" \
        "$traceability_manifest_ok" "/specs/$feature/traceability.md" "$traceability_hash"
      jq -e '(.layer_sha256 | keys) == ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"]' "$precheck" >/dev/null ||
        diagnostic "$feature" stage-provenance "task layer precheck manifest is incomplete"
      # Aggregate, same as the impl-stage layer loop above: one genuinely
      # undeclared layer must still fail the whole check even if the other
      # three are merely stale.
      local layer_omit_triples=()
      for layer in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
        layer_path="$feature_dir/$layer"
        [[ -f "$layer_path" && ! -L "$layer_path" ]] ||
          diagnostic "$feature" stage-provenance "task layer input is missing or linked"
        layer_hash="$(sha256_file "$layer_path")"
        # Tolerated downstream: direct precheck/contract field vs live-hash
        # comparison.
        [[ "$(jq -r --arg layer "$layer" '.layer_sha256[$layer] // empty' "$precheck")" == "$layer_hash" &&
           "$(jq -r --arg layer "$layer" '.layer_sha256[$layer] // empty' "$contract")" == "$layer_hash" ]] ||
          diagnostic_or_tolerate "$feature" "$stage" stage-provenance "task layer hash is stale"
        local layer_manifest_ok
        layer_manifest_ok=0
        manifest_has_hash "$contract" "/specs/$feature/$layer" "$layer_hash" "$recorded_root" && layer_manifest_ok=1
        layer_omit_triples+=("$layer_manifest_ok" "/specs/$feature/$layer" "$layer_hash")
      done
      diagnostic_or_tolerate_omit "$feature" "$stage" stage-provenance \
        "task reviewer manifests omit layer inputs" "$contract" "$recorded_root" \
        "${layer_omit_triples[@]}"
    fi
  fi
}

validate_legacy() {
  local feature="$1" dir="$2" entry="$3" stage file header key value
  for stage in spec impl task; do
    case "$stage" in
      spec) file="$dir/requirements.md"; header="Spec-Review-Status"; key="spec_status" ;;
      impl) file="$dir/design.md"; header="Impl-Review-Status"; key="impl_status" ;;
      task) file="$dir/tasks.md"; header="Task-Review-Status"; key="task_status" ;;
    esac
    value=""; [[ -f "$file" ]] && value="$(header_value "$file" "$header")"
    if [[ -z "$value" ]]; then
      jq -e --arg stage "$stage" '.legacy.allowed_missing_stages | index($stage) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "missing $stage status is not declared"
    else
      jq -e --arg key "$key" --arg value "$value" \
        '.legacy.allowed_noncanonical_statuses[$key] | index($value) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "$stage status is broader than the migration record"
    fi
  done
  if [[ -f "$dir/tasks.md" ]]; then
    while IFS= read -r value; do
      value="${value#Approval: }"; value="${value%% (*}"
      jq -e --arg value "$value" '.legacy.allowed_task_approvals | index($value) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "task approval is broader than the migration record"
    done < <(sed -n 's/^\(Approval:[[:space:]]*.*\r\{0,1\}\)$/\1/p' "$dir/tasks.md" | tr -d '\r')
    while IFS= read -r value; do
      value="${value#Status: }"
      jq -e --arg value "$value" '.legacy.allowed_task_statuses | index($value) != null' <<<"$entry" >/dev/null ||
        diagnostic "$feature" legacy-state "task lifecycle is broader than the migration record"
    done < <(sed -n 's/^\(Status:[[:space:]]*.*\r\{0,1\}\)$/\1/p' "$dir/tasks.md" | tr -d '\r')
  fi
}

while IFS= read -r entry; do
  feature="$(jq -r '.feature' <<<"$entry")"
  [[ -z "$FEATURE_FILTER" || "$feature" == "$FEATURE_FILTER" ]] || continue
  case $'\n'"$registry_failed_features" in
    *$'\n'"$feature"$'\n'*) continue ;;
  esac
  set +e
  (
  set -euo pipefail
  profile="$(jq -r '.profile' <<<"$entry")"
  dir="$SPECS_ROOT/$feature"
  [[ "$profile" == lite ]] && exit 0
  if [[ "$profile" == legacy ]]; then validate_legacy "$feature" "$dir" "$entry"; exit 0; fi
  for required in requirements.md design.md acceptance-tests.md; do
    [[ -f "$dir/$required" && ! -L "$dir/$required" && -r "$dir/$required" ]] ||
      diagnostic "$feature" stage-input "$required is missing, linked, or unreadable"
  done
  spec="$(header_value "$dir/requirements.md" Spec-Review-Status)"
  impl="$(header_value "$dir/design.md" Impl-Review-Status)"
  tasks="$dir/tasks.md"; task=""
  if [[ -e "$tasks" || -L "$tasks" ]]; then
    [[ -f "$tasks" && ! -L "$tasks" && -r "$tasks" ]] ||
      diagnostic "$feature" stage-input "tasks.md is linked or unreadable"
  fi
  [[ -f "$tasks" ]] && task="$(header_value "$tasks" Task-Review-Status)"
  [[ ! -f "$tasks" || -n "$task" ]] ||
    diagnostic "$feature" stage-status "tasks.md has no Task-Review-Status"
  [[ "$spec" == Pending || "$spec" == Passed ]] ||
    diagnostic "$feature" stage-status "Spec status is missing or invalid"
  [[ "$impl" == Pending || "$impl" == Passed ]] ||
    diagnostic "$feature" stage-status "Impl status is missing or invalid"
  [[ -z "$task" || "$task" == Pending || "$task" == Passed ]] ||
    diagnostic "$feature" stage-status "Task status is invalid"
  [[ "$impl" != Passed || "$spec" == Passed ]] ||
    diagnostic "$feature" stage-order "Impl Passed requires Spec Passed"
  [[ "$task" != Passed || ( "$spec" == Passed && "$impl" == Passed ) ]] ||
    diagnostic "$feature" stage-order "Task Passed requires Spec and Impl Passed"
  [[ ! -f "$tasks" || ( "$spec" == Passed && "$impl" == Passed ) ]] ||
    diagnostic "$feature" task-lifecycle "tasks.md requires Spec and Impl Passed"
  if [[ -f "$tasks" ]]; then
    approval_count=0; status_count=0
    while IFS= read -r value; do
      approval_count=$((approval_count + 1))
      case "$value" in
        Draft|Approved|"Approved ("*")") ;;
        *) diagnostic "$feature" task-lifecycle "task approval is invalid" ;;
      esac
    done < <(sed -n 's/^Approval:[[:space:]]*//p' "$tasks" | tr -d '\r')
    while IFS= read -r value; do
      status_count=$((status_count + 1))
      [[ "$value" == Planned || "$value" == "In Progress" || "$value" == Blocked ||
         "$value" == "Implementation Complete" || "$value" == Done ]] ||
        diagnostic "$feature" task-lifecycle "task status is invalid"
    done < <(sed -n 's/^Status:[[:space:]]*//p' "$tasks" | tr -d '\r')
    [[ "$approval_count" -gt 0 && "$approval_count" -eq "$status_count" ]] ||
      diagnostic "$feature" task-lifecycle "task lifecycle fields are incomplete"
  fi
  if [[ "$task" == Pending ]]; then
    while IFS= read -r value; do
      [[ "$value" == Draft ]] ||
        diagnostic "$feature" task-lifecycle "pending task review permits only Draft approvals"
    done < <(sed -n 's/^Approval:[[:space:]]*//p' "$tasks" | tr -d '\r')
    while IFS= read -r value; do
      [[ "$value" == Planned ]] ||
        diagnostic "$feature" task-lifecycle "pending task review permits only Planned statuses"
    done < <(sed -n 's/^Status:[[:space:]]*//p' "$tasks" | tr -d '\r')
  fi
  if [[ -f "$tasks" ]] && grep -Eq '^Status:[[:space:]]*(In Progress|Blocked|Implementation Complete|Done)|^Approval:[[:space:]]*Approved' "$tasks"; then
    [[ "$spec" == Passed && "$impl" == Passed && "$task" == Passed ]] ||
      diagnostic "$feature" task-lifecycle "executable task state requires all reviews Passed"
  fi
  [[ "$spec" != Passed ]] || validate_passed_stage "$feature" spec "$dir"
  [[ "$impl" != Passed ]] || validate_passed_stage "$feature" impl "$dir"
  [[ "$task" != Passed ]] || validate_passed_stage "$feature" task "$dir"
  )
  feature_status=$?
  set -e
  [[ "$feature_status" -eq 0 ]] || workflow_state_failed=$((workflow_state_failed + 1))
done < <(jq -c '.entries[]' "$REGISTRY")

[[ "$workflow_state_failed" -eq 0 ]] || exit 1
printf 'workflow-state: ok\n'
