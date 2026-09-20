# Shared predecessor-verdict validation for the review-loop prechecks.
# Sourced (not executed) by impl-review-precheck.sh and
# task-review-precheck.sh — the sdd-hook-guard.sh sourcing convention.
#
# Contract with the including script (all referenced at call time):
#   functions: fail, sha256, reviewed_sha256
#   globals:   FEATURE, repo_root, CALIBRATION_MD, LAYER_FILES
#
# History: require_persisted_pass lived as a ~176-line copy in each script
# and drifted three ways (recorded in
# reports/notes/plugin-code-quality-audit-2026-08-21.md). This unified
# version is the superset: the task-stage allowlist carries the full
# layer-spec set and the layer_sha256 manifest verification (previously
# task-copy-only; dead branches for the impl caller, which validates spec
# predecessors only), and every caller now runs
# assert_contract_reviewer_agreement (previously impl-copy-only, although
# the incident it guards — a contract recording a hash neither reviewer
# read, epic-136-phase4-docs attempt 2 round 2 — applies to any persisted
# contract).
# A round's verdict belongs to the text its two reviewers actually read.
# Elsewhere the manifest checks accept either the contract's recorded hash or the
# current file hash, which is right for tolerating an untouched file but leaves a
# real gap: a contract written after a remediation edit can record a hash neither
# reviewer ever saw, and the round's verdict is then attributed to text that was
# never reviewed. That happened on epic-136-phase4-docs attempt 2 round 2, and
# surfaced only because the next round's precheck happened to refuse.
#
# Close it directly: the two reviewers must have pinned the same hash for each
# reviewed document, and the contract must record that hash and no other.
assert_contract_reviewer_agreement() {
  local contract="$1" stage="$2"
  local role_a="${stage}-reviewer-a" role_b="${stage}-reviewer-b"
  local doc doc_key hash_a hash_b hash_contract
  pinned_hash() {
    jq -r --arg role "$1" --arg path "$2" --arg repo "${repo_root}/" '
      def relative_path:
        if startswith($repo) then .[($repo | length):]
        elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
        else . end;
      [.reviewers[]? | select(.role == $role) | .allowed_input_manifest[]?
       | select((.path | relative_path) == $path) | .sha256] | first // ""
    ' "$contract"
  }
  for doc in requirements.md acceptance-tests.md design.md; do
    case "$doc" in
      requirements.md)     doc_key=requirements_sha256 ;;
      acceptance-tests.md) doc_key=acceptance_sha256 ;;
      design.md)           doc_key=design_sha256 ;;
    esac
    hash_a=$(pinned_hash "$role_a" "specs/${FEATURE}/${doc}")
    hash_b=$(pinned_hash "$role_b" "specs/${FEATURE}/${doc}")
    [[ -n "$hash_a" && -n "$hash_b" ]] || continue
    [[ "$hash_a" == "$hash_b" ]] ||
      fail "persisted ${stage} contract: reviewer-a and reviewer-b pinned different ${doc}; they did not review the same text"
    hash_contract=$(jq -r --arg k "$doc_key" '.[$k] // ""' "$contract")
    if [[ -n "$hash_contract" && "$hash_contract" != "$hash_a" ]]; then
      fail "persisted ${stage} contract records a ${doc} hash neither reviewer read; the verdict does not belong to that text"
    fi
  done
}


require_persisted_pass() {
  local root="$1" stage="$2" requirements_hash="$3" acceptance_hash="$4" design_hash="$5"
  local requirements_current_hash="$6" design_current_hash="$7" verdict="" contract contract_dir
  local stage_calibration stage_calibration_hash
  if [[ "$stage" == "spec" ]]; then
    stage_calibration="plugins/sdd-review-loop/references/spec-review-calibration.md"
  else
    stage_calibration="$CALIBRATION_MD"
  fi
  stage_calibration_hash="$(sha256 "${repo_root}/${stage_calibration}")"
  [[ -d "$root" && ! -L "$root" ]] || fail "missing ${stage} predecessor report root"
  local candidate candidate_dir relative_dir candidate_attempt candidate_round
  local latest_attempt=0 latest_round=0
  while IFS= read -r candidate; do
    candidate_dir="$(dirname "$candidate")"
    relative_dir="${candidate_dir#"${root}/"}"
    [[ "$relative_dir" =~ ^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)$ ]] ||
      fail "persisted ${stage} verdict is outside a canonical attempt/round directory"
    candidate_attempt="${BASH_REMATCH[1]}"
    candidate_round="${BASH_REMATCH[2]}"
    if (( candidate_attempt > latest_attempt ||
          (candidate_attempt == latest_attempt && candidate_round > latest_round) )); then
      latest_attempt="$candidate_attempt"
      latest_round="$candidate_round"
      verdict="$candidate"
    fi
  done < <(find "$root" -type f -name integrated-verdict.json ! -lname '*' -print)
  [[ -n "$verdict" ]] || fail "missing persisted ${stage} PASS verdict"
  contract_dir="$(dirname "$verdict")"; contract="${contract_dir}/${stage}-review-contract.json"
  [[ -f "$contract" && ! -L "$contract" ]] || fail "missing persisted ${stage} review contract"
  [[ "$contract_dir" =~ /attempt-([1-9][0-9]*)/round-([1-9][0-9]*)$ ]] ||
    fail "persisted ${stage} contract is outside a canonical attempt/round directory"
  local stored_attempt="${BASH_REMATCH[1]}" stored_round="${BASH_REMATCH[2]}"
  jq -e --arg feature "$FEATURE" --arg stage "$stage" '
    .feature == $feature and .stage == $stage and (.attempt | type == "number" and . > 0) and (.round | type == "number" and . > 0) and .verdict == "PASS" and
    (if $stage == "spec" then .schema == "spec-review-integrated-verdict/v1" and
      ([.reviewer_a_run_id, .reviewer_b_run_id, .reviewer_a_host_session_id, .reviewer_b_host_session_id] | all(type == "string" and length > 0)) and
      .reviewer_a_run_id != .reviewer_b_run_id and .reviewer_a_host_session_id != .reviewer_b_host_session_id
     else .schema == "integrated-verdict/v1" and (.run_id | type == "string" and length > 0) end)' "$verdict" >/dev/null ||
    fail "persisted ${stage} verdict is not a complete PASS contract"
  jq -e --arg feature "$FEATURE" --arg stage "$stage" --arg req "$requirements_hash" --arg req_current "$requirements_current_hash" \
    --arg accept "$acceptance_hash" --arg design "$design_hash" --arg design_current "$design_current_hash" \
    --arg repo "${repo_root}/" --arg calibration "$stage_calibration" --arg calibration_hash "$stage_calibration_hash" '
    # Contracts persisted by predecessor gates record absolute paths of the
    # checkout that generated them. Relativize against the known repository
    # anchors so evidence stays verifiable from any checkout (issue #61).
    def relative_path:
      if startswith($repo) then .[($repo | length):]
      elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
      else . end;
    def allowed_input($role; $path; $attempt; $round):
      ($stage + "-reviewer-a") as $role_a |
      ($stage + "-reviewer-b") as $role_b |
      ("reports/" + $stage + "-review/" + $feature + "/attempt-" + ($attempt | tostring)) as $attempt_root |
      ($attempt_root + "/round-" + ($round | tostring)) as $round_root |
      (($path == ("specs/" + $feature + "/requirements.md")) or
       ($path == ("specs/" + $feature + "/acceptance-tests.md")) or
       ($stage == "spec" and $path == ("specs/" + $feature + "/investigation.md")) or
       ($stage == "impl" and
        ($path == ("specs/" + $feature + "/design.md") or
         $path == ("specs/" + $feature + "/ux-spec.md") or
         $path == ("specs/" + $feature + "/frontend-spec.md") or
         $path == ("specs/" + $feature + "/infra-spec.md") or
         $path == ("specs/" + $feature + "/security-spec.md") or
         $path == ("specs/" + $feature + "/investigation.md"))) or
       ($stage == "task" and
        ($path == ("specs/" + $feature + "/tasks.md") or
         $path == ("specs/" + $feature + "/design.md") or
         $path == ("specs/" + $feature + "/traceability.md") or
         $path == ("specs/" + $feature + "/ux-spec.md") or
         $path == ("specs/" + $feature + "/frontend-spec.md") or
         $path == ("specs/" + $feature + "/infra-spec.md") or
         $path == ("specs/" + $feature + "/security-spec.md"))) or
       ($path == $calibration) or
       ($path == ($round_root + "/precheck-result.json")) or
       ($stage == "spec" and $role == $role_b and
        $path == ($round_root + "/integrated-summary.json")) or
       ($stage == "impl" and $role == $role_b and
        $path == ($round_root + "/integrated-summary.json")) or
       ($stage == "impl" and $role == $role_a and $round > 1 and
        $path == ($attempt_root + "/round-" + (($round - 1) | tostring) + "/integrated-summary.json")) or
       ($stage == "task" and $role == $role_a and
        $path == ($round_root + "/dependency-graph.json")) or
       ($stage == "task" and $role == $role_b and
        ($path == ($round_root + "/integrated-summary.json") or
         $path == "plugins/sdd-quality-loop/references/risk-gate-matrix.md" or
         $path == "plugins/sdd-quality-loop/references/risk-classification-policy.md")));
    .schema == ($stage + "-review-contract/v1") and .feature == $feature and .stage == $stage and
    (.attempt | type == "number" and . > 0) and (.round | type == "number" and . > 0) and
    (.run_id | type == "string" and length > 0) and .verdict == "PASS" and
    ([.reviewers[]? | .role] | sort) == [($stage + "-reviewer-a"), ($stage + "-reviewer-b")] and
    ([.reviewers[]? | .host_session_id] | (all(type == "string" and length > 0) and (unique | length == 2))) and
    ([.reviewers[]? | .run_id] | (all(type == "string" and length > 0) and (unique | length == 2))) and
    (.attempt as $attempt | .round as $round |
      all(.reviewers[]?;
        .role as $role |
        ([.allowed_input_manifest[]? | (.path | relative_path)] as $paths |
          ($paths | length) > 0 and ($paths | length) == ($paths | unique | length)) and
        all(.allowed_input_manifest[]?;
          .path as $raw_path |
          (($raw_path | type == "string") and
           (($raw_path | relative_path) as $path |
             (($path | startswith("/")) | not) and
             ($path | test("(^|/)\\.\\.?(/|$)") | not) and
             allowed_input($role; $path; $attempt; $round) and
             (.sha256 | type == "string") and
             (.sha256 | test("^[0-9a-f]{64}$"))))
        )
      )
    ) and
    (any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == ("specs/" + $feature + "/requirements.md") and (.sha256 == $req or .sha256 == $req_current))) and
    (any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == ("specs/" + $feature + "/acceptance-tests.md") and .sha256 == $accept)) and
    ($stage != "impl" or any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == ("specs/" + $feature + "/design.md") and (.sha256 == $design or .sha256 == $design_current))) and
    all(.reviewers[]?; any(.allowed_input_manifest[]?; (.path | relative_path) == $calibration and .sha256 == $calibration_hash))
  ' "$contract" >/dev/null || fail "persisted ${stage} contract does not match canonical current inputs"
  [[ "$(jq -r '.attempt' "$contract")" == "$stored_attempt" &&
     "$(jq -r '.round' "$contract")" == "$stored_round" ]] ||
    fail "persisted ${stage} contract attempt/round does not match its directory"

  local role_a="${stage}-reviewer-a" role_b="${stage}-reviewer-b"
  local precheck_path="reports/${stage}-review/${FEATURE}/attempt-${stored_attempt}/round-${stored_round}/precheck-result.json"
  local summary_path="reports/${stage}-review/${FEATURE}/attempt-${stored_attempt}/round-${stored_round}/integrated-summary.json"
  local investigation_path="specs/${FEATURE}/investigation.md"
  manifest_has() {
    local role="$1" path="$2" hash_one="$3" hash_two="${4:-}"
    jq -e --arg role "$role" --arg path "$path" --arg repo "${repo_root}/" \
      --arg hash_one "$hash_one" --arg hash_two "$hash_two" '
      def relative_path:
        if startswith($repo) then .[($repo | length):]
        elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
        else . end;
      any(.reviewers[]?;
        .role == $role and
        any(.allowed_input_manifest[]?;
          ((.path | relative_path) == $path) and
          (.sha256 == $hash_one or ($hash_two != "" and .sha256 == $hash_two))
        )
      )' "$contract" >/dev/null
  }
  # investigation.md's expected pin is derived from the contract under
  # validation -- never from the live working tree. Every other entry checked in
  # this loop comes from an immutable or deliberately-current source:
  # requirements/acceptance/design carry BOTH the contract's recorded hash and
  # the current one, so an untouched file and a sealed file are both accepted;
  # precheck-result.json and integrated-summary.json are frozen round artifacts
  # that nothing may append to. investigation.md was the lone outlier, pinned to
  # live bytes with no recorded-hash alternative, and it is the single worst file
  # to read live: by design it is the document that accumulates the amendment
  # record ACROSS stages, so it grows after a round is sealed as a matter of
  # course. Reading it live compared today's bytes against the correctly-pinned
  # ones and refused the downstream stage outright -- permanently, since nothing
  # can un-grow the file (epic-196: "persisted spec contract reviewer manifest is
  # missing investigation evidence", with require_persisted_pass running
  # unconditionally so --provenance-rereview granted no way past it). A sealed
  # contract is evidence about the past; validating it against the present is a
  # category error. The live-vs-pinned question belongs to
  # check-workflow-state.sh, which asks it deliberately and carries the
  # amendment-record growth tolerance for exactly this file.
  #
  # Same discipline as spec-review-precheck.sh's validate_contract: every
  # reviewer that pinned the file must have pinned the SAME bytes (`unique` must
  # collapse to one value), and that value must be a well-formed digest, so a
  # contract whose reviewer A and reviewer B disagree about what they read is
  # still refused. The per-reviewer binding below is unchanged: once any reviewer
  # pinned the file, BOTH must have. Absent from the manifest entirely means the
  # reviewers declared they did not read it, which is legal -- allowed_input()
  # above permits investigation.md for the spec and impl stages but never
  # requires it -- so nothing is expected and the file merely existing today
  # cannot invalidate a contract sealed before it was written.
  local investigation_pin
  investigation_pin="$(jq -r --arg path "$investigation_path" --arg repo "${repo_root}/" '
    def relative_path:
      if startswith($repo) then .[($repo | length):]
      elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
      else . end;
    [.reviewers[]?.allowed_input_manifest[]? | select((.path | relative_path) == $path) | .sha256] |
    unique |
    if length == 0 then "" elif length == 1 then .[0] else "__AMBIGUOUS__" end' "$contract")"
  if [[ -n "$investigation_pin" ]]; then
    [[ "$investigation_pin" =~ ^[0-9a-f]{64}$ ]] ||
      fail "persisted ${stage} contract reviewer manifest records an ambiguous or malformed investigation evidence pin"
  fi
  for role in "$role_a" "$role_b"; do
    manifest_has "$role" "specs/${FEATURE}/requirements.md" "$requirements_hash" "$requirements_current_hash" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical requirements"
    manifest_has "$role" "specs/${FEATURE}/acceptance-tests.md" "$acceptance_hash" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical acceptance tests"
    manifest_has "$role" "$stage_calibration" "$stage_calibration_hash" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical calibration"
    manifest_has "$role" "$precheck_path" "$(sha256 "${repo_root}/${precheck_path}")" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical precheck evidence"
    if [[ "$stage" == "impl" ]]; then
      manifest_has "$role" "specs/${FEATURE}/design.md" "$design_hash" "$design_current_hash" ||
        fail "persisted impl contract reviewer manifest is missing canonical design"
      if [[ "$(jq -r '(.layer_sha256 // {}) | length' "$contract")" -gt 0 ]]; then
        for layer in "${LAYER_FILES[@]}"; do
          manifest_has "$role" "specs/${FEATURE}/${layer}" "$(sha256 "${repo_root}/specs/${FEATURE}/${layer}")" ||
            fail "persisted impl contract reviewer manifest is missing canonical layer input: ${layer}"
        done
      fi
    fi
    if [[ -n "$investigation_pin" ]]; then
      manifest_has "$role" "$investigation_path" "$investigation_pin" ||
        fail "persisted ${stage} contract reviewer manifest is missing investigation evidence"
    fi
  done
  manifest_has "$role_b" "$summary_path" "$(sha256 "${repo_root}/${summary_path}")" ||
    fail "persisted ${stage} reviewer-b manifest is missing canonical integrated summary"
  if [[ "$stage" == "impl" && "$stored_round" -gt 1 ]]; then
    local previous_summary="reports/impl-review/${FEATURE}/attempt-${stored_attempt}/round-$((stored_round - 1))/integrated-summary.json"
    manifest_has "$role_a" "$previous_summary" "$(sha256 "${repo_root}/${previous_summary}")" ||
      fail "persisted impl reviewer-a manifest is missing previous-round summary"
  fi

  assert_contract_reviewer_agreement "$contract" "$stage"
  jq -e --slurpfile verdict "$verdict" --arg stage "$stage" '
    . as $contract | $verdict[0] as $verdict |
    $contract.attempt == $verdict.attempt and
    $contract.round == $verdict.round and
    $contract.verdict == $verdict.verdict and
    (if $stage == "spec" then
       ($contract.reviewers | map({key: .role, value: {run_id: .run_id, host_session_id: .host_session_id}}) | from_entries) as $reviewers |
       $reviewers["spec-reviewer-a"].run_id == $verdict.reviewer_a_run_id and
       $reviewers["spec-reviewer-b"].run_id == $verdict.reviewer_b_run_id and
       $reviewers["spec-reviewer-a"].host_session_id == $verdict.reviewer_a_host_session_id and
       $reviewers["spec-reviewer-b"].host_session_id == $verdict.reviewer_b_host_session_id
     else $contract.run_id == $verdict.run_id end)
  ' "$contract" >/dev/null || fail "persisted ${stage} verdict and contract contradict each other"
}
