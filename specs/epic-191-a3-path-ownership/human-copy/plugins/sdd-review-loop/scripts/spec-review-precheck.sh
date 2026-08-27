#!/usr/bin/env bash
# Validate a specification-review transition before any reviewer receives input
# or evidence is written. The orchestrating skill owns reviewer invocation and
# status mutation; this script owns deterministic preconditions and provenance.
set -euo pipefail

usage() {
  echo "Usage: spec-review-precheck.sh <feature-slug> <attempt> <round> [--edit-summary=<text>] [--reset]" >&2
  exit 1
}

fail() { echo "ERROR: spec-review-precheck: $*" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else fail "neither sha256sum nor shasum is available"; fi
}
sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}';
  else fail "neither sha256sum nor shasum is available"; fi
}
canonical_dir() { (cd "$1" && pwd -P); }
# Lowercase only: every producer in this tree emits lowercase hex, and a
# case-insensitive class here would admit a digest its strict consumers reject.
is_sha256() { [[ "$1" =~ ^[0-9a-f]{64}$ ]]; }

[[ $# -ge 3 ]] || usage
feature="$1"; attempt="$2"; round="$3"; shift 3
edit_summary=""; reset=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --edit-summary=*) edit_summary="${1#*=}" ;;
    --reset) reset=true ;;
    *) usage ;;
  esac
  shift
done

[[ "$feature" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid feature slug"
[[ "$attempt" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$round" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ "$round" -le 3 ]] || fail "round must be between 1 and 3"
[[ -z "$edit_summary" || "$round" -gt 1 ]] || fail "--edit-summary is valid only after round 1"
if [[ "$round" -gt 1 ]]; then
  [[ -n "${edit_summary//[[:space:]]/}" ]] || fail "rounds 2 and 3 require a non-empty --edit-summary"
fi
if [[ "$reset" == true ]]; then
  [[ "$attempt" -gt 1 && "$round" -eq 1 ]] || fail "--reset starts only attempt N+1 round 1"
else
  [[ "$attempt" -eq 1 || "$round" -gt 1 ]] || fail "a new attempt requires --reset"
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
specs_root="${repo_root}/specs"
reports_root="${repo_root}/reports"
reports_base="${reports_root}/spec-review"
spec_dir="${repo_root}/specs/${feature}"
requirements="${spec_dir}/requirements.md"
acceptance="${spec_dir}/acceptance-tests.md"
calibration="${repo_root}/plugins/sdd-review-loop/references/spec-review-calibration.md"
report_root="${repo_root}/reports/spec-review/${feature}"
report_dir="${report_root}/attempt-${attempt}/round-${round}"

# Manifests record absolute paths from whatever checkout produced the evidence.
# A later run -- a git worktree, CI, a different machine -- has a different
# repository root, so comparing recorded paths against locally built ones as
# raw strings rejects valid evidence. The canonical gate already normalizes
# (check-workflow-state.sh relative_path) and so does the PowerShell side
# (Get-ManifestRelativePath, issue #61); this validator was the last one still
# comparing absolute strings, which made a prior attempt unverifiable from any
# checkout but the one that wrote it.
#
# Same semantics as the canonical gate, deliberately: strip the local root, its
# /private/var alias, or the single root the contract itself recorded, and
# reject anything still absolute afterwards. An unrelated absolute path
# therefore normalizes to null rather than to a plausible-looking suffix, so
# this does not widen what counts as a match -- it only stops the root from
# being part of the comparison.
repo_root_alias="$repo_root"
case "$repo_root" in
  /private/var/*) repo_root_alias="/var/${repo_root#/private/var/}" ;;
  /var/*) repo_root_alias="/private/var/${repo_root#/var/}" ;;
esac
relative_to_repo() { printf '%s' "${1#"$repo_root/"}"; }

jq_relative_path='
  def relative_path:
    gsub("\\\\"; "/") |
    if startswith($repo) then .[($repo|length):]
    elif startswith($alias) then .[($alias|length):]
    elif ($recorded != "" and startswith($recorded)) then .[($recorded|length):]
    elif test("^(/|[A-Za-z]:/)") then null
    else . end;'

# The recorded root is derived from the contract rather than trusted from it:
# every manifest entry must split into a root plus a suffix of a canonical
# shape, and all entries must agree on one root. A feature slug that happens
# to be named "specs" or "plugins" produces two candidate splits and is
# rejected. A wrong split cannot weaken tamper detection -- the derived
# relative path still has to match the expected manifest entry, and its
# recorded sha256 still has to match.
recorded_repo_root() {
  jq -r --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" '
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
      if ($candidates | length) == 1 then $candidates[0] else null end] as $roots |
    if any($roots[]; . == null) or ($roots | map(select(. != null)) | unique | length) > 1
    then "__INVALID__"
    else ($roots | map(select(. != null)) | unique | .[0] // "")
    end' "$1"
}

[[ -d "$specs_root" && ! -L "$specs_root" ]] || fail "specs root must be a real directory"
[[ "$(canonical_dir "$specs_root")" == "$specs_root" ]] || fail "specs root escapes repository"
[[ -d "$spec_dir" && ! -L "$spec_dir" ]] || fail "feature specification directory must not be a symlink"
[[ "$(canonical_dir "$spec_dir")" == "$spec_dir" ]] || fail "feature specification directory escapes repository"
[[ -f "$requirements" && ! -L "$requirements" ]] || fail "requirements.md must be a regular non-symlink file"
[[ -f "$acceptance" && ! -L "$acceptance" ]] || fail "acceptance-tests.md must be a regular non-symlink file"
[[ -f "$calibration" && ! -L "$calibration" ]] || fail "spec review calibration reference must be a regular non-symlink file"
[[ -d "$reports_root" && ! -L "$reports_root" ]] || fail "reports root must be a real directory"
[[ "$(canonical_dir "$reports_root")" == "$reports_root" ]] || fail "reports root escapes repository"
if [[ -e "$reports_base" ]]; then
  [[ -d "$reports_base" && ! -L "$reports_base" ]] || fail "spec-review report base must not be a symlink"
  [[ "$(canonical_dir "$reports_base")" == "$reports_base" ]] || fail "spec-review report base escapes reports root"
fi
command -v jq >/dev/null 2>&1 || fail "jq is required"
# Fail closed when no SHA-256 tool exists: with the bare else-shasum shape a
# host with neither tool captures an empty digest and empty == empty passes.
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 ||
  fail "neither sha256sum nor shasum is available"
status="$(sed -n 's/^Spec-Review-Status:[[:space:]]*//p' "$requirements" | head -n 1 | tr -d '[:space:]')"
if [[ "$reset" == true ]]; then
  [[ "$status" == "Pending" || "$status" == "Passed" ]] || fail "requirements.md must declare a resettable Spec-Review-Status"
else
  [[ "$status" == "Pending" ]] || fail "requirements.md must declare Spec-Review-Status: Pending"
fi
[[ ! -L "$report_root" ]] || fail "report root must not be a symlink"
[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"

requirements_sha="$(sha256 "$requirements")"
acceptance_sha="$(sha256 "$acceptance")"
calibration_sha="$(sha256 "$calibration")"
input_sha="$(printf '%s:%s' "$requirements_sha" "$acceptance_sha" | sha256_stream)"

validate_reviewer_output() {
  local output="$1" role="$2" manifest="$3" run_id="$4" host_session_id="$5" recorded_prefix="${6:-}"
  local actual_manifest expected_ids actual_ids
  [[ -f "$output" && ! -L "$output" ]] || return 1
  jq -e --arg schema "${role}/v1" --arg role "$role" --arg run_id "$run_id" --arg host_session_id "$host_session_id" '
    type == "object" and keys == ["allowed_input_manifest", "checks", "host_session_id", "role", "run_id", "schema", "stage", "verdict"] and
    .schema == $schema and .stage == "spec" and .role == $role and .run_id == $run_id and .host_session_id == $host_session_id and
    (.allowed_input_manifest | type == "array" and length > 0 and all(.[]; type == "object" and keys == ["path", "sha256"] and (.path | type == "string") and (.sha256 | type == "string" and test("^[0-9a-f]{64}$")))) and
    (.checks | type == "array" and length > 0 and all(.[]; type == "object" and keys == ["finding", "id", "result", "severity"] and
      (.id | type == "string" and test("\\S")) and (.result == "PASS" or .result == "FAIL" or .result == "SKIP") and
      (.severity == "Critical" or .severity == "Major" or .severity == "Minor") and (.finding | type == "string"))) and
    (.verdict == "PASS" or .verdict == "NEEDS_WORK" or .verdict == "BLOCKED")' "$output" >/dev/null || return 1
  actual_manifest="$(jq -c --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" --arg recorded "$recorded_prefix" "$jq_relative_path"'
    [.allowed_input_manifest[] | {path: (.path | relative_path), sha256}] | sort_by(.path)' "$output")"
  [[ "$actual_manifest" == "$manifest" ]] || return 1
  case "$role" in
    spec-reviewer-a)
      expected_ids="REQ-TESTABILITY,GOAL-AC-TRACE,AC-OBSERVABLE,SCOPE-BOUNDARY,CONSTRAINTS-EXPLICIT,RISK-VALIDATION-SURFACE,DOMAIN-CONFORMANCE"
      ;;
    spec-reviewer-b)
      expected_ids="AMBIGUITY,CONTRADICTION,EDGE-CASE-COVERAGE,ASSUMPTIONS-RESOLVABLE,APPROVAL-BOUNDARY,DOWNSTREAM-READINESS,DOMAIN-CONFORMANCE"
      ;;
    *)
      return 1
      ;;
  esac
  actual_ids="$(jq -r '[.checks[].id] | join(",")' "$output")"
  # Evidence is held to the role as it was defined when the evidence was
  # produced, not as it is defined today. Check ids are appended to a role's
  # list -- never inserted, reordered or renamed -- so a review that ran before
  # a check existed carries a prefix of today's list. epic-136-phase3's
  # attempt 2 is exactly that: six ids, DOMAIN-CONFORMANCE added afterwards
  # (95479bb2, d528cbed). Rejecting it would mean every feature reviewed before
  # any future check is added can never open a new attempt again.
  #
  # A prefix and nothing looser. A run that skipped a middle check, reordered
  # them, invented one, or carries more ids than the role defines does not form
  # a prefix and still fails, so this does not weaken any current-version
  # review: for those, prefix and equality coincide.
  [[ "${expected_ids}," == "${actual_ids},"* ]] || return 1
  # Verdict/finding coherence is checked, not derived. The role documents are
  # authoritative on the verdict choice (epic-191-a3 a2r1 escalation,
  # 2026-08-11): review-context-boundary.md defines BLOCKED as a launch or
  # boundary failure -- the review could not be validly conducted -- and no
  # role document states a severity-to-verdict formula. A reviewer that
  # conducted its review and recorded at least one FAIL, of any severity, has
  # earned the choice between NEEDS_WORK and BLOCKED; content severity and
  # procedural blockage are different questions. The previous rule here
  # mechanically forced FAIL/Critical to BLOCKED and rejected a persisted
  # NEEDS_WORK verbatim record, deadlocking every subsequent round and reset
  # of the same attempt chain.
  #
  # Narrowed, not removed. The two shapes that are incoherent on any reading
  # are still rejected: a declared PASS carrying any FAIL, and a declared
  # NEEDS_WORK or BLOCKED carrying none.
  jq -e 'if ([.checks[] | select(.result == "FAIL")] | length) > 0
         then .verdict == "NEEDS_WORK" or .verdict == "BLOCKED"
         else .verdict == "PASS" end' "$output" >/dev/null
}

validate_contract() {
  local contract="$1" expected_attempt="$2" expected_round="$3" expected_verdict="$4" precheck="$5"
  local round_dir summary integrated_verdict expected_a expected_b actual_a actual_b requirements_hash acceptance_hash calibration_hash investigation_hash
  local reviewer_a reviewer_b a_run a_session b_run b_session checks critical major minor expected_merged expected_warning
  local recorded_root recorded_prefix
  [[ -f "$contract" && ! -L "$contract" && -f "$precheck" && ! -L "$precheck" ]] || return 1
  recorded_root="$(recorded_repo_root "$contract")"
  [[ "$recorded_root" != "__INVALID__" ]] || return 1
  recorded_prefix="${recorded_root:+$recorded_root/}"
  jq -e --arg feature "$feature" --argjson attempt "$expected_attempt" --argjson round "$expected_round" --arg verdict "$expected_verdict" '
    type == "object" and keys == ["acceptance_sha256", "attempt", "feature", "requirements_sha256", "reviewers", "round", "run_id", "schema", "stage", "verdict", "warningCount"] and
    .schema == "spec-review-contract/v1" and .stage == "spec" and .feature == $feature and .attempt == $attempt and .round == $round and .verdict == $verdict and
    (.requirements_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and (.acceptance_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    (.run_id | type == "string" and test("\\S")) and (.warningCount | type == "number" and . >= 0) and
    (.reviewers | type == "array" and length == 2 and ([.[].role] | sort) == ["spec-reviewer-a", "spec-reviewer-b"] and
      (([.[] | .host_session_id] | all(type == "string" and test("\\S"))) and ([.[] | .host_session_id] | unique | length == 2)) and
      all(.[]; (.run_id | type == "string" and test("\\S")) and (.allowed_input_manifest | type == "array" and length > 0 and all(.[]; (.path | type == "string") and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))))))' "$contract" >/dev/null || return 1
  jq -e --arg feature "$feature" --argjson attempt "$expected_attempt" --argjson round "$expected_round" --arg requirements_sha "$(jq -r .requirements_sha256 "$contract")" --arg acceptance_sha "$(jq -r .acceptance_sha256 "$contract")" '
    .schema == "spec-review-precheck/v1" and .stage == "spec" and .feature == $feature and .attempt == $attempt and .round == $round and .requirements_sha256 == $requirements_sha and .acceptance_sha256 == $acceptance_sha and
    (.calibration_sha256 == null or (.calibration_sha256 | type == "string" and test("^[0-9a-f]{64}$")))' "$precheck" >/dev/null || return 1

  round_dir="$(dirname "$contract")"
  summary="${round_dir}/integrated-summary.json"
  [[ -f "$summary" && ! -L "$summary" ]] || return 1
  jq -e --argjson attempt "$expected_attempt" --argjson round "$expected_round" '
    type == "object" and keys == ["attempt", "generated_at", "reviewer_a_checks", "reviewer_a_fail_count", "reviewer_a_pass_count", "reviewer_a_skip_count", "round", "schema"] and
    .schema == "integrated-summary/v1" and .attempt == $attempt and .round == $round and
    (.reviewer_a_checks | type == "array" and all(.[]; type == "object" and keys == ["id", "result", "severity"] and
      (.id | type == "string" and test("\\S")) and (.result == "PASS" or .result == "FAIL" or .result == "SKIP") and
      (.severity == "Critical" or .severity == "Major" or .severity == "Minor"))) and
    (.reviewer_a_fail_count | type == "number" and . >= 0) and (.reviewer_a_pass_count | type == "number" and . >= 0) and (.reviewer_a_skip_count | type == "number" and . >= 0) and
    (.generated_at | type == "string")' "$summary" >/dev/null || return 1

  requirements_hash="$(jq -r .requirements_sha256 "$contract")"
  acceptance_hash="$(jq -r .acceptance_sha256 "$contract")"
  calibration_hash="$(jq -r --arg calibration "$calibration" --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" --arg recorded "$recorded_prefix" "$jq_relative_path"'
    ($calibration | relative_path) as $target |
    [.reviewers[].allowed_input_manifest[] | select((.path | relative_path) == $target) | .sha256] | unique | if length == 1 then .[0] else "" end' "$contract")"
  is_sha256 "$calibration_hash" || return 1
  if jq -e '.calibration_sha256 != null' "$precheck" >/dev/null; then
    [[ "$(jq -r .calibration_sha256 "$precheck")" == "$calibration_hash" ]] || return 1
  fi
  expected_a="$(jq -cn --arg requirements "$(relative_to_repo "$requirements")" --arg requirements_hash "$requirements_hash" --arg acceptance "$(relative_to_repo "$acceptance")" --arg acceptance_hash "$acceptance_hash" --arg precheck "$(relative_to_repo "$precheck")" --arg precheck_hash "$(sha256 "$precheck")" --arg calibration "$(relative_to_repo "$calibration")" --arg calibration_hash "$calibration_hash" '[{path:$requirements,sha256:$requirements_hash},{path:$acceptance,sha256:$acceptance_hash},{path:$precheck,sha256:$precheck_hash},{path:$calibration,sha256:$calibration_hash}] | sort_by(.path)')"
  # investigation.md is derived from the contract, exactly like calibration_hash
  # above -- never from the live working tree. Every other entry in this expected
  # manifest already comes from an immutable source: requirements/acceptance from
  # the contract's own top-level fields, precheck-result.json from a frozen round
  # artifact, calibration from the manifest itself. investigation.md was the lone
  # outlier, and it is the single worst file to read live: by design it is the
  # document that accumulates the amendment record ACROSS stages, so it grows
  # after a round is sealed as a matter of course. Reading it live compared
  # today's bytes against the correctly-pinned ones, mismatched, and refused
  # `--reset` with "previous terminal contract is invalid" -- permanently, since
  # nothing can un-grow the file (reproduced on epic-195). A sealed contract is
  # evidence about the past; validating it against the present is a category
  # error. The live-vs-pinned question belongs to check-workflow-state.sh, which
  # asks it deliberately and carries the amendment-record growth tolerance for
  # exactly this file.
  #
  # Same discipline as calibration: every reviewer that pinned the file must have
  # pinned the SAME bytes (`unique` must collapse to one value), and that value
  # must be a well-formed digest. A contract in which reviewer A and reviewer B
  # disagree about what they read is not a valid contract. Absent from the
  # manifest entirely means the reviewers declared they did not read it, which is
  # legal (check-workflow-state.sh's allowed() list permits investigation.md but
  # never requires it), so nothing is expected. There is no cross-check against
  # precheck-result.json here because the precheck schema records no
  # investigation_sha256 field -- unlike calibration_sha256 -- so the "if the
  # precheck records it" clause has nothing to compare against.
  investigation_hash="$(jq -r --arg investigation "${spec_dir}/investigation.md" --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" --arg recorded "$recorded_prefix" "$jq_relative_path"'
    ($investigation | relative_path) as $target |
    [.reviewers[].allowed_input_manifest[] | select((.path | relative_path) == $target) | .sha256] | unique |
    if length == 0 then "" elif length == 1 then .[0] else "__AMBIGUOUS__" end' "$contract")"
  if [[ -n "$investigation_hash" ]]; then
    is_sha256 "$investigation_hash" || return 1
    expected_a="$(jq -cn --argjson manifest "$expected_a" --arg investigation "$(relative_to_repo "${spec_dir}/investigation.md")" --arg investigation_hash "$investigation_hash" '$manifest + [{path:$investigation,sha256:$investigation_hash}] | sort_by(.path)')"
  fi
  expected_b="$(jq -cn --argjson manifest "$expected_a" --arg summary "$(relative_to_repo "$summary")" --arg summary_hash "$(sha256 "$summary")" '$manifest + [{path:$summary,sha256:$summary_hash}] | sort_by(.path)')"
  actual_a="$(jq -c --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" --arg recorded "$recorded_prefix" "$jq_relative_path"'
    [.reviewers[] | select(.role == "spec-reviewer-a") | .allowed_input_manifest[] | {path: (.path | relative_path), sha256}] | sort_by(.path)' "$contract")"
  actual_b="$(jq -c --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" --arg recorded "$recorded_prefix" "$jq_relative_path"'
    [.reviewers[] | select(.role == "spec-reviewer-b") | .allowed_input_manifest[] | {path: (.path | relative_path), sha256}] | sort_by(.path)' "$contract")"
  [[ "$actual_a" == "$expected_a" && "$actual_b" == "$expected_b" ]] || return 1

  reviewer_a="${round_dir}/reviewer-a.json"
  reviewer_b="${round_dir}/reviewer-b.json"
  a_run="$(jq -r '.reviewers[] | select(.role == "spec-reviewer-a") | .run_id' "$contract")"
  a_session="$(jq -r '.reviewers[] | select(.role == "spec-reviewer-a") | .host_session_id' "$contract")"
  b_run="$(jq -r '.reviewers[] | select(.role == "spec-reviewer-b") | .run_id' "$contract")"
  b_session="$(jq -r '.reviewers[] | select(.role == "spec-reviewer-b") | .host_session_id' "$contract")"
  validate_reviewer_output "$reviewer_a" "spec-reviewer-a" "$expected_a" "$a_run" "$a_session" "$recorded_prefix" || return 1
  validate_reviewer_output "$reviewer_b" "spec-reviewer-b" "$expected_b" "$b_run" "$b_session" "$recorded_prefix" || return 1
  [[ "$(jq -c '[.checks[] | {id, result, severity}]' "$reviewer_a")" == "$(jq -c '.reviewer_a_checks' "$summary")" ]] || return 1
  [[ "$(jq -r '.reviewer_a_fail_count' "$summary")" == "$(jq '[.checks[] | select(.result == "FAIL")] | length' "$reviewer_a")" ]] || return 1
  [[ "$(jq -r '.reviewer_a_pass_count' "$summary")" == "$(jq '[.checks[] | select(.result == "PASS")] | length' "$reviewer_a")" ]] || return 1
  [[ "$(jq -r '.reviewer_a_skip_count' "$summary")" == "$(jq '[.checks[] | select(.result == "SKIP")] | length' "$reviewer_a")" ]] || return 1

  checks="$(jq -sc '[.[].checks[]]' "$reviewer_a" "$reviewer_b")"
  critical="$(jq '[.[] | select(.result == "FAIL" and .severity == "Critical")] | length' <<<"$checks")"
  major="$(jq '[.[] | select(.result == "FAIL" and .severity == "Major")] | length' <<<"$checks")"
  minor="$(jq '[.[] | select(.result == "FAIL" and .severity == "Minor")] | length' <<<"$checks")"
  if (( critical > 0 || major > 0 )); then
    if (( expected_round == 3 )); then expected_merged="BLOCKED"; else expected_merged="NEEDS_WORK"; fi
    expected_warning=0
  elif (( minor > 0 )); then
    if (( expected_round == 3 )); then expected_merged="PASS"; expected_warning="$minor"; else expected_merged="NEEDS_WORK"; expected_warning=0; fi
  else
    expected_merged="PASS"; expected_warning=0
  fi
  [[ "$expected_merged" == "$expected_verdict" ]] || return 1
  integrated_verdict="${round_dir}/integrated-verdict.json"
  [[ -f "$integrated_verdict" && ! -L "$integrated_verdict" ]] || return 1
  jq -e --arg feature "$feature" --argjson attempt "$expected_attempt" --argjson round "$expected_round" --arg verdict "$expected_merged" --argjson warning "$expected_warning" --arg a_run "$a_run" --arg b_run "$b_run" --arg a_session "$a_session" --arg b_session "$b_session" --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" '
    type == "object" and keys == ["attempt", "feature", "finding_counts", "reviewer_a_host_session_id", "reviewer_a_run_id", "reviewer_b_host_session_id", "reviewer_b_run_id", "round", "schema", "stage", "verdict", "warningCount"] and
    .schema == "spec-review-integrated-verdict/v1" and .stage == "spec" and .feature == $feature and .attempt == $attempt and .round == $round and .verdict == $verdict and .warningCount == $warning and
    .reviewer_a_run_id == $a_run and .reviewer_b_run_id == $b_run and .reviewer_a_host_session_id == $a_session and .reviewer_b_host_session_id == $b_session and
    .finding_counts == {critical:$critical, major:$major, minor:$minor}' "$integrated_verdict" >/dev/null || return 1
  [[ "$(jq -r .verdict "$contract")" == "$expected_merged" && "$(jq -r .warningCount "$contract")" == "$expected_warning" ]]
}

if [[ "$round" -gt 1 ]]; then
  prior_dir="${report_root}/attempt-${attempt}/round-$((round - 1))"
  prior_contract="${prior_dir}/spec-review-contract.json"
  [[ -f "$prior_contract" ]] || fail "prior round contract is required"
  validate_contract "$prior_contract" "$attempt" "$((round - 1))" "NEEDS_WORK" "${prior_dir}/precheck-result.json" \
    || fail "prior round contract is malformed or does not require work"
  prior_requirements_sha="$(jq -r '.requirements_sha256' "$prior_contract")"
  prior_acceptance_sha="$(jq -r '.acceptance_sha256' "$prior_contract")"
  [[ "$requirements_sha" != "$prior_requirements_sha" || "$acceptance_sha" != "$prior_acceptance_sha" ]] \
    || fail "reviewed inputs are unchanged from the prior round"
fi

if [[ "$reset" == true ]]; then
  previous_attempt="${report_root}/attempt-$((attempt - 1))"
  [[ -d "$previous_attempt" && ! -L "$previous_attempt" ]] || fail "previous attempt is required before reset"
  previous_round="$(find "$previous_attempt" -maxdepth 1 -type d -name 'round-*' -print | sed -n 's#.*/round-\([1-3]\)$#\1#p' | sort -n | tail -1)"
  [[ -n "$previous_round" ]] || fail "previous attempt has no terminal round"
  previous_dir="${previous_attempt}/round-${previous_round}"
  previous_verdict="$(jq -r '.verdict // empty' "${previous_dir}/spec-review-contract.json" 2>/dev/null || true)"
  [[ "$previous_verdict" == "PASS" || "$previous_verdict" == "BLOCKED" ]] || fail "reset requires a terminal PASS or BLOCKED contract"
  validate_contract "${previous_dir}/spec-review-contract.json" "$((attempt - 1))" "$previous_round" "$previous_verdict" "${previous_dir}/precheck-result.json" \
    || fail "previous terminal contract is invalid"
fi

# Only after every pure validation succeeds may this script acquire a lock or
# create an evidence path. mkdir makes concurrent writers fail deterministically.
mkdir -p "$reports_base"
[[ ! -L "$reports_base" && "$(canonical_dir "$reports_base")" == "$reports_base" ]] || fail "spec-review report base escapes reports root"
mkdir -p "$report_root"
[[ ! -L "$report_root" ]] || fail "report root must not be a symlink"
[[ "$(canonical_dir "$report_root")" == "$report_root" ]] || fail "report root escapes report base"
lock_dir="${report_root}/.spec-review.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  fail "another specification review transition holds the lock"
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"
mkdir -p "$report_dir"

# Exercise the shared portable foundation against the canonical composite input
# before persisting the gate-specific precheck evidence.
foundation_contract="${report_root}/.review-contract-${attempt}-${round}-$$.json"
trap 'rm -f "$foundation_contract"; rmdir "$lock_dir" 2>/dev/null || true' EXIT
jq -n --arg feature "$feature" --argjson attempt "$attempt" --argjson round "$round" --arg input_sha256 "$input_sha" \
  '{schema:"review-contract/v1",stage:"spec",feature:$feature,attempt:$attempt,round:$round,input_sha256:$input_sha256,run_id:"spec-precheck",verdict:"PASS"}' > "$foundation_contract"
"${repo_root}/plugins/sdd-review-loop/scripts/review-contract-validate.sh" --feature "$feature" --attempt "$attempt" --round "$round" --stage spec --report-root "$report_root" --contract "$foundation_contract" >/dev/null
rm -f "$foundation_contract"

# Reset is the sole exceptional transition that restores Pending. It occurs only
# after the old evidence and the new destination have both been validated.
if [[ "$reset" == true && "$status" == "Passed" ]]; then
  reset_tmp="${requirements}.spec-review-reset.$$"
  sed 's/^Spec-Review-Status:[[:space:]]*Passed[[:space:]]*$/Spec-Review-Status: Pending/' "$requirements" > "$reset_tmp"
  mv "$reset_tmp" "$requirements"
  status="Pending"
  # Recompute the requirements/input hashes against the post-reset file: any
  # persisted precheck-result.json must record the bytes reviewers, contracts,
  # and later validate_contract calls will actually see, never the pre-mutation
  # (Passed) bytes this same invocation just rewrote.
  requirements_sha="$(sha256 "$requirements")"
  input_sha="$(printf '%s:%s' "$requirements_sha" "$acceptance_sha" | sha256_stream)"
fi

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
jq -n \
  --arg schema "spec-review-precheck/v1" --arg feature "$feature" \
  --argjson attempt "$attempt" --argjson round "$round" \
  --arg requirements_sha256 "$requirements_sha" --arg acceptance_sha256 "$acceptance_sha" --arg calibration_sha256 "$calibration_sha" --arg input_sha256 "$input_sha" \
  --arg status "$status" --arg edit_summary "$edit_summary" --arg generated_at "$generated_at" \
  --argjson reset "$reset" \
  '{schema:$schema,stage:"spec",feature:$feature,attempt:$attempt,round:$round,spec_review_status_field:$status,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,calibration_sha256:$calibration_sha256,input_sha256:$input_sha256,edit_summary:$edit_summary,reset:$reset,generated_at:$generated_at}' \
  > "${report_dir}/precheck-result.json"

echo "spec-review-precheck: complete. Output written to ${report_dir}/"
