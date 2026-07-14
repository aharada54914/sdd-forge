#!/usr/bin/env bash
# tests/lib/loop-driver.sh — shared source-style loop driver
# (A2 / Issue #142 / epic-159-pillar-a REQ-002).
#
# Sourced by tests/loop-driver.tests.sh (this task's smoke suite) and, per
# design.md Dependency Order, intended for reuse by the future
# tests/loop-consistency.tests.sh (T-003) and tests/loop-escalation.tests.sh
# (T-004). Defines functions only — never executed directly. Follows the
# ok()/fail() + mktemp/trap conventions of tests/spec-review-loop.tests.sh
# (INV-009); the calling suite owns its own ok()/fail() counters, this
# library only exposes boolean-returning assertions and driver functions.
#
# Public functions:
#   loop_fixture_init <greenfield|brownfield> <feature>
#   drive_review_round <stage> <attempt> <round> <verdict> [<severity>]
#   assert_prior_round_complete <stage> <round-dir>
#   assert_artifacts_schema <dir>
#   assert_terminal <loop-id> <observed-state> [<exit-code>]
#   assert_runtime_budget <start-epoch> [<budget-seconds>]
#
# Environment:
#   SDD_LOOP_REPO_ROOT  — checkout whose REAL gate scripts are driven
#                         (default: this library file's own repo root).
#                         Overriding it is the RED-differential hook
#                         (design.md Test Strategy item 2; T-003 scope).
#   LOOP_INVENTORY_PATH — loop-inventory/v1 JSON path (default:
#                         $SDD_LOOP_REPO_ROOT/tests/loops/loop-inventory.json)
#   LOOP_FIXTURE_SEED   — brownfield seed directory (loop_fixture_init
#                         brownfield only)
#
# Fixture isolation (security-spec.md B1/B2): all fixture state lives under
# $LOOP_FIXTURE_ROOT (mktemp -d, exported by loop_fixture_init), asserted
# outside the repository working tree. spec-review-precheck.sh and
# review-contract-validate.sh compute their own repository root from their
# own invocation path (dirname "$0"/../../..), so the REAL, unmodified
# scripts are exposed inside the fixture through a symlink skeleton (leaf
# script files only — never copied, never edited) that redirects that
# self-computed root to $LOOP_FIXTURE_ROOT. validate-review-context-set.sh
# instead takes repository-root as an explicit CLI argument, so it is
# invoked directly from $SDD_LOOP_REPO_ROOT with $LOOP_FIXTURE_ROOT passed as
# data — no symlink needed for that script. Reference docs the prechecks
# read (e.g. spec-review-calibration.md) are REJECTED by those scripts when
# the path itself is a symlink (spec-review-precheck.sh:63), so those are
# snapshotted with cp (never modified) into the fixture at init time.
#
# Scope note (tasks.md T-002 Out of Scope): drive_review_round fully
# implements and is proven only for stage "spec"; impl/task/domain are
# explicitly refused with a clear error rather than shipping unverified
# behavior (driving those loops is T-003/#143 scope). See this task's
# implementation report for the forward-compatibility risk this leaves for
# T-003, which cannot edit this file per its own Planned Files list.

if [[ -n "${_LOOP_DRIVER_SOURCED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_LOOP_DRIVER_SOURCED=1

LOOP_SUITE_BUDGET_SECONDS="${LOOP_SUITE_BUDGET_SECONDS:-300}"

_loop_driver_lib="${BASH_SOURCE[0]}"
SDD_LOOP_REPO_ROOT="${SDD_LOOP_REPO_ROOT:-$(cd "$(dirname "${_loop_driver_lib}")/../.." && pwd -P)}"
LOOP_INVENTORY_PATH="${LOOP_INVENTORY_PATH:-${SDD_LOOP_REPO_ROOT}/tests/loops/loop-inventory.json}"

_loop_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
_loop_sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}';
  else shasum -a 256 | awk '{print $1}'; fi
}

_loop_id_for_stage() {
  case "$1" in
    spec) echo spec-review ;;
    impl) echo impl-review ;;
    task) echo task-review ;;
    domain) echo domain-review ;;
    *) return 1 ;;
  esac
}

# _loop_driver_script <stage> — resolves driver_scripts[0] (repo-relative)
# for <stage> from the committed loop-inventory/v1 registry (T-001).
_loop_driver_script() {
  local stage="$1" id
  id="$(_loop_id_for_stage "$stage")" || return 1
  jq -r --arg id "$id" '.loops[] | select(.id == $id) | .driver_scripts[0] // empty' "$LOOP_INVENTORY_PATH"
}

# ---------------------------------------------------------------------------
# loop_fixture_init <greenfield|brownfield> <feature>
# ---------------------------------------------------------------------------
loop_fixture_init() {
  local profile="$1" feature="$2"
  case "$profile" in
    greenfield|brownfield) ;;
    *) echo "loop_fixture_init: unknown profile: ${profile} (want greenfield|brownfield)" >&2; return 1 ;;
  esac
  [[ "$feature" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
    echo "loop_fixture_init: invalid feature slug: ${feature}" >&2
    return 1
  }

  LOOP_FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/loop-fixture.XXXXXX")" || return 1
  # Physical-path normalization: spec-review-precheck.sh resolves its own
  # repo_root via `pwd -P` (symlinks resolved), and on macOS $TMPDIR is
  # itself a symlink (/var/folders/... -> /private/var/folders/...). Without
  # this, the fixture-relative path strings this library writes into
  # reviewer/contract JSON would never match what the precheck script's own
  # symlink-resolved repo_root computes, breaking every downstream lookup.
  LOOP_FIXTURE_ROOT="$(cd "${LOOP_FIXTURE_ROOT}" && pwd -P)" || return 1
  case "${LOOP_FIXTURE_ROOT}" in
    "${SDD_LOOP_REPO_ROOT}"|"${SDD_LOOP_REPO_ROOT}"/*)
      echo "loop_fixture_init: fixture root resolved inside the repository working tree" >&2
      return 1
      ;;
  esac

  if [[ "$profile" == brownfield ]]; then
    [[ -n "${LOOP_FIXTURE_SEED:-}" && -d "${LOOP_FIXTURE_SEED}" ]] || {
      echo "loop_fixture_init: brownfield profile requires LOOP_FIXTURE_SEED to name an existing directory" >&2
      return 1
    }
    cp -R "${LOOP_FIXTURE_SEED}/." "${LOOP_FIXTURE_ROOT}/" || return 1
  fi

  _loop_fixture_link_scripts || return 1
  _loop_fixture_copy_references || return 1

  mkdir -p "${LOOP_FIXTURE_ROOT}/specs/${feature}"
  cat > "${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md" <<EOF
# Requirements

Spec-Review-Status: Pending

## Goals

- loop-driver ${profile} fixture for feature ${feature} (A2 / Issue #142).
EOF
  cat > "${LOOP_FIXTURE_ROOT}/specs/${feature}/acceptance-tests.md" <<'EOF'
# Acceptance tests

| AC-ID | Requirement | Status |
|---|---|---|
| AC-001 | REQ-001 | Planned |
EOF

  mkdir -p "${LOOP_FIXTURE_ROOT}/reports"

  jq -n --arg feature "$feature" '
    {schema_version: 1,
     migration_baseline_commit: "0369c8c96de2eb3179868d1949d66644488f65aa",
     entries: [{feature: $feature, profile: "full"}]}' \
    > "${LOOP_FIXTURE_ROOT}/specs/workflow-state-registry.json" || return 1

  mkdir -p "${LOOP_FIXTURE_ROOT}/reports/review-context"
  local genesis_hash
  genesis_hash="$(printf '%s' "1|genesis|loop-driver-fixture|fixture-genesis-run|fixture-genesis-session|" | _loop_sha256_text)"
  jq -n --arg hash "$genesis_hash" '
    {schema: "review-identity-ledger/v1",
     records: [{sequence: 1, stage: "genesis", role: "loop-driver-fixture",
       run_id: "fixture-genesis-run", host_session_id: "fixture-genesis-session",
       previous_record_sha256: "", record_sha256: $hash}]}' \
    > "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json" || return 1

  LOOP_FIXTURE_FEATURE="$feature"
  export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE
  return 0
}

# Real gate scripts driven read-only: exposed via leaf-file symlinks only
# (containing directories are real, so each script's own dirname-based
# repo_root resolves to $LOOP_FIXTURE_ROOT — see file header). Never copies
# or edits the real script content.
_loop_fixture_link_scripts() {
  local rel src
  for rel in \
    plugins/sdd-review-loop/scripts/spec-review-precheck.sh \
    plugins/sdd-review-loop/scripts/review-contract-validate.sh \
    plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
    plugins/sdd-review-loop/scripts/task-review-precheck.sh \
    plugins/sdd-domain/scripts/domain-review-precheck.sh
  do
    src="${SDD_LOOP_REPO_ROOT}/${rel}"
    [[ -f "$src" ]] || continue
    mkdir -p "${LOOP_FIXTURE_ROOT}/$(dirname "$rel")" || return 1
    ln -s "$src" "${LOOP_FIXTURE_ROOT}/${rel}" || return 1
  done
  return 0
}

# Reference docs the prechecks read for their calibration hash. These MUST
# be real (non-symlink) files: spec-review-precheck.sh:63 explicitly rejects
# a symlinked calibration path. Snapshotting with cp does not modify the
# real file and is refreshed on every fixture build, so there is no drift
# risk versus reading the real file directly.
_loop_fixture_copy_references() {
  local rel src
  for rel in \
    plugins/sdd-review-loop/references/spec-review-calibration.md \
    plugins/sdd-review-loop/references/reviewer-calibration.md \
    plugins/sdd-domain/references/domain-review-calibration.md
  do
    src="${SDD_LOOP_REPO_ROOT}/${rel}"
    [[ -f "$src" ]] || continue
    mkdir -p "${LOOP_FIXTURE_ROOT}/$(dirname "$rel")" || return 1
    cp "$src" "${LOOP_FIXTURE_ROOT}/${rel}" || return 1
  done
  return 0
}

# ---------------------------------------------------------------------------
# Manifest helpers (validate-review-context-set.sh's allowed_input_manifest)
# ---------------------------------------------------------------------------

# _loop_manifest_entry <repo-relative-path-under-LOOP_FIXTURE_ROOT>
# Asserts the file exists on disk (never a hand-typed hash) and emits
# {path, sha256}.
_loop_manifest_entry() {
  local rel="$1" abs="${LOOP_FIXTURE_ROOT}/$1"
  [[ -f "$abs" && ! -L "$abs" ]] || {
    echo "_loop_manifest_entry: missing or symlinked artifact: ${rel}" >&2
    return 1
  }
  jq -n --arg path "$rel" --arg sha256 "$(_loop_sha256 "$abs")" '{path: $path, sha256: $sha256}'
}

_loop_manifest_array() {
  local rel entry entries=()
  for rel in "$@"; do
    entry="$(_loop_manifest_entry "$rel")" || return 1
    entries+=("$entry")
  done
  printf '%s\n' "${entries[@]}" | jq -sc '.'
}

_loop_next_sequence() {
  jq -r '(.records | length) + 1' "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json"
}
_loop_previous_hash() {
  jq -r '.records[-1].record_sha256' "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json"
}

# _loop_reserve_review_context <stage> <role> <feature> <manifest-json-array>
# Runs the REAL validate-review-context-set.sh --reserve against
# $LOOP_FIXTURE_ROOT (passed as repository-root data, not a symlink target),
# extending the fixture's identity-ledger chain.
_loop_reserve_review_context() {
  local stage="$1" role="$2" feature="$3" manifest_entries="$4"
  local validator="${SDD_LOOP_REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
  [[ -f "$validator" ]] || { echo "_loop_reserve_review_context: validator missing: ${validator}" >&2; return 1; }
  local ledger="${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json"
  local ledger_sha sequence previous run_id session manifest_path rc
  ledger_sha="$(_loop_sha256 "$ledger")"
  sequence="$(_loop_next_sequence)"
  previous="$(_loop_previous_hash)"
  run_id="fixture-${role}-${feature}-seq${sequence}"
  session="fixture-session-${role}-seq${sequence}"
  manifest_path="$(mktemp "${TMPDIR:-/tmp}/loop-manifest.XXXXXX.json")"
  jq -n --arg schema "review-context-invocation/v2" --arg stage "$stage" --arg role "$role" \
    --arg feature "$feature" --arg run_id "$run_id" --arg session "$session" \
    --argjson sequence "$sequence" --arg previous "$previous" \
    --arg ledger_path "reports/review-context/identity-ledger.json" --arg ledger_sha "$ledger_sha" \
    --argjson manifest "$manifest_entries" '
    {schema: $schema, stage: $stage, role: $role, feature: $feature, run_id: $run_id,
     host_session_id: $session, sequence: $sequence, previous_record_sha256: $previous,
     identity_ledger_path: $ledger_path, identity_ledger_sha256: $ledger_sha,
     input_mode: "file-manifest", fallback_mode: "none", read_only: true,
     allowed_input_manifest: $manifest}' > "$manifest_path" || { rm -f "$manifest_path"; return 1; }
  "$validator" "$manifest_path" "${LOOP_FIXTURE_ROOT}" --reserve >/dev/null
  rc=$?
  rm -f "$manifest_path"
  return $rc
}

# ---------------------------------------------------------------------------
# assert_prior_round_complete <stage> <round-dir>
# ---------------------------------------------------------------------------
_loop_required_round_files() {
  case "$1" in
    spec) printf '%s\n' precheck-result.json integrated-summary.json reviewer-a.json reviewer-b.json integrated-verdict.json spec-review-contract.json ;;
    *) return 1 ;;
  esac
}

assert_prior_round_complete() {
  local stage="$1" dir="$2" name
  [[ -d "$dir" ]] || return 1
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ -f "${dir}/${name}" ]] || return 1
  done < <(_loop_required_round_files "$stage") || return 1
  return 0
}

# ---------------------------------------------------------------------------
# Spec-review round emission (write_contract() port from
# tests/spec-review-loop.tests.sh:39-99, INV-008) — writes reviewer-a/b
# outputs, the integrated verdict, and the round contract from the fixture's
# actual on-disk requirements/acceptance/precheck/calibration content.
# ---------------------------------------------------------------------------
_loop_emit_spec_round_a() {
  local round_dir="$1" severity="$2"
  local round a_verdict a_result a_fails a_passes check_severity warning
  round="$(jq -r .round "${round_dir}/precheck-result.json")" || return 1
  case "$severity" in
    none)     a_verdict="PASS";        a_result="PASS"; a_fails=0; a_passes=6; check_severity="Minor" ;;
    Critical) a_verdict="BLOCKED";     a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Critical" ;;
    Major)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Major" ;;
    Minor)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Minor" ;;
    *) echo "_loop_emit_spec_round_a: unknown severity: ${severity}" >&2; return 1 ;;
  esac
  warning=0
  [[ "$round" == 3 && "$severity" == Minor ]] && warning=1

  jq -n --argjson attempt 1 --argjson round "$round" --arg result "$a_result" --arg severity "$check_severity" \
    --argjson fail_count "$a_fails" --argjson pass_count "$a_passes" '
    ["REQ-TESTABILITY","GOAL-AC-TRACE","AC-OBSERVABLE","SCOPE-BOUNDARY","CONSTRAINTS-EXPLICIT","RISK-VALIDATION-SURFACE"] as $ids |
    {schema:"integrated-summary/v1",attempt:$attempt,round:$round,
     reviewer_a_checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end)})),
     reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}' \
    > "${round_dir}/integrated-summary.json" || return 1

  local requirements_path acceptance_path precheck_path calibration_path
  local requirements_sha acceptance_sha precheck_sha calibration_sha
  requirements_path="${LOOP_FIXTURE_ROOT}/specs/${LOOP_FIXTURE_FEATURE}/requirements.md"
  acceptance_path="${LOOP_FIXTURE_ROOT}/specs/${LOOP_FIXTURE_FEATURE}/acceptance-tests.md"
  precheck_path="${round_dir}/precheck-result.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-review-loop/references/spec-review-calibration.md"
  requirements_sha="$(_loop_sha256 "$requirements_path")"
  acceptance_sha="$(_loop_sha256 "$acceptance_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"

  jq -n --arg result "$a_result" --arg severity "$check_severity" --arg verdict "$a_verdict" \
    --arg requirements "$requirements_path" --arg acceptance "$acceptance_path" --arg precheck "$precheck_path" --arg calibration "$calibration_path" \
    --arg requirements_sha "$requirements_sha" --arg acceptance_sha "$acceptance_sha" --arg precheck_sha "$precheck_sha" --arg calibration_sha "$calibration_sha" '
    ["REQ-TESTABILITY","GOAL-AC-TRACE","AC-OBSERVABLE","SCOPE-BOUNDARY","CONSTRAINTS-EXPLICIT","RISK-VALIDATION-SURFACE"] as $ids |
    {schema:"spec-reviewer-a/v1",stage:"spec",role:"spec-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",
     allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}],
     verdict:$verdict,
     checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}' \
    > "${round_dir}/reviewer-a.json" || return 1

  return 0
}

_loop_emit_spec_round_b_contract() {
  local round_dir="$1" verdict="$2" severity="$3"
  local round warning critical major minor
  round="$(jq -r .round "${round_dir}/precheck-result.json")" || return 1
  warning=0
  [[ "$round" == 3 && "$severity" == Minor ]] && warning=1
  case "$severity" in
    none)     critical=0; major=0; minor=0 ;;
    Critical) critical=1; major=0; minor=0 ;;
    Major)    critical=0; major=1; minor=0 ;;
    Minor)    critical=0; major=0; minor=1 ;;
    *) echo "_loop_emit_spec_round_b_contract: unknown severity: ${severity}" >&2; return 1 ;;
  esac

  local requirements_path acceptance_path precheck_path calibration_path summary_path
  local requirements_sha acceptance_sha precheck_sha calibration_sha summary_sha
  requirements_path="${LOOP_FIXTURE_ROOT}/specs/${LOOP_FIXTURE_FEATURE}/requirements.md"
  acceptance_path="${LOOP_FIXTURE_ROOT}/specs/${LOOP_FIXTURE_FEATURE}/acceptance-tests.md"
  precheck_path="${round_dir}/precheck-result.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-review-loop/references/spec-review-calibration.md"
  summary_path="${round_dir}/integrated-summary.json"
  requirements_sha="$(_loop_sha256 "$requirements_path")"
  acceptance_sha="$(_loop_sha256 "$acceptance_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"
  summary_sha="$(_loop_sha256 "$summary_path")"

  jq -n --arg feature "$LOOP_FIXTURE_FEATURE" --arg verdict "$verdict" --argjson round "$round" --argjson warning "$warning" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" '
    {schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:$round,
     reviewer_a_run_id:"fixture-a",reviewer_b_run_id:"fixture-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",
     finding_counts:{critical:$critical,major:$major,minor:$minor},verdict:$verdict,warningCount:$warning}' \
    > "${round_dir}/integrated-verdict.json" || return 1

  jq -n --arg requirements "$requirements_path" --arg acceptance "$acceptance_path" --arg precheck "$precheck_path" --arg summary "$summary_path" \
    --arg calibration "$calibration_path" --arg requirements_sha "$requirements_sha" --arg acceptance_sha "$acceptance_sha" \
    --arg precheck_sha "$precheck_sha" --arg summary_sha "$summary_sha" --arg calibration_sha "$calibration_sha" '
    ["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids |
    {schema:"spec-reviewer-b/v1",stage:"spec",role:"spec-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",
     allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}],
     verdict:"PASS",
     checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}' \
    > "${round_dir}/reviewer-b.json" || return 1

  jq -n --arg feature "$LOOP_FIXTURE_FEATURE" --arg verdict "$verdict" \
    --arg requirements_sha256 "$requirements_sha" --arg acceptance_sha256 "$acceptance_sha" \
    --argjson round "$round" --argjson warning "$warning" \
    --arg requirements "$requirements_path" --arg acceptance "$acceptance_path" --arg precheck "$precheck_path" --arg summary "$summary_path" --arg calibration "$calibration_path" \
    --arg precheck_sha "$precheck_sha" --arg summary_sha "$summary_sha" --arg calibration_sha "$calibration_sha" '
    {schema:"spec-review-contract/v1",stage:"spec",feature:$feature,attempt:1,round:$round,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,reviewers:[
      {role:"spec-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[
        {path:$requirements,sha256:$requirements_sha256},{path:$acceptance,sha256:$acceptance_sha256},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}
      ]},
      {role:"spec-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[
        {path:$requirements,sha256:$requirements_sha256},{path:$acceptance,sha256:$acceptance_sha256},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}
      ]}
    ],run_id:"fixture-orchestrator",verdict:$verdict,warningCount:$warning}' \
    > "${round_dir}/spec-review-contract.json" || return 1

  return 0
}

_loop_spec_manifest_a() {
  local round_dir="$1" round_rel
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  _loop_manifest_array \
    "specs/${LOOP_FIXTURE_FEATURE}/requirements.md" \
    "specs/${LOOP_FIXTURE_FEATURE}/acceptance-tests.md" \
    "plugins/sdd-review-loop/references/spec-review-calibration.md" \
    "${round_rel}/precheck-result.json"
}
_loop_spec_manifest_b() {
  local round_dir="$1" round_rel
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  _loop_manifest_array \
    "specs/${LOOP_FIXTURE_FEATURE}/requirements.md" \
    "specs/${LOOP_FIXTURE_FEATURE}/acceptance-tests.md" \
    "plugins/sdd-review-loop/references/spec-review-calibration.md" \
    "${round_rel}/precheck-result.json" \
    "${round_rel}/integrated-summary.json"
}

_loop_drive_spec_round() {
  local attempt="$1" round="$2" verdict="$3" severity="$4"
  local feature script_rel script requirements precheck_args
  feature="${LOOP_FIXTURE_FEATURE:?_loop_drive_spec_round requires LOOP_FIXTURE_FEATURE (set by loop_fixture_init)}"
  script_rel="$(_loop_driver_script spec)" || return 1
  [[ -n "$script_rel" ]] || { echo "drive_review_round: spec-review driver script not registered in the inventory" >&2; return 1; }
  script="${LOOP_FIXTURE_ROOT}/${script_rel}"
  [[ -f "$script" ]] || { echo "drive_review_round: precheck script missing at ${script}" >&2; return 1; }

  requirements="${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md"
  precheck_args=("$feature" "$attempt" "$round")
  if [[ "$round" -gt 1 ]]; then
    local prior_dir="${LOOP_FIXTURE_ROOT}/reports/spec-review/${feature}/attempt-${attempt}/round-$((round - 1))"
    assert_prior_round_complete spec "$prior_dir" || {
      echo "drive_review_round: round-$((round - 1)) output set is incomplete on disk; refusing to start round ${round}" >&2
      return 1
    }
    printf '\n<!-- loop-driver round %s edit -->\n' "$round" >> "$requirements"
    precheck_args+=("--edit-summary=round-${round}-edit")
  fi

  ( cd "${LOOP_FIXTURE_ROOT}" && bash "$script" "${precheck_args[@]}" ) >/dev/null || return 1

  local round_dir="${LOOP_FIXTURE_ROOT}/reports/spec-review/${feature}/attempt-${attempt}/round-${round}"
  [[ -f "${round_dir}/precheck-result.json" ]] || {
    echo "drive_review_round: precheck-result.json missing after a successful precheck run" >&2
    return 1
  }

  local manifest_a manifest_b
  manifest_a="$(_loop_spec_manifest_a "$round_dir")" || return 1
  _loop_reserve_review_context spec spec-reviewer-a "$feature" "$manifest_a" || return 1
  _loop_emit_spec_round_a "$round_dir" "$severity" || return 1

  manifest_b="$(_loop_spec_manifest_b "$round_dir")" || return 1
  _loop_reserve_review_context spec spec-reviewer-b "$feature" "$manifest_b" || return 1
  _loop_emit_spec_round_b_contract "$round_dir" "$verdict" "$severity" || return 1

  return 0
}

# ---------------------------------------------------------------------------
# drive_review_round <stage> <attempt> <round> <verdict> [<severity>]
# ---------------------------------------------------------------------------
drive_review_round() {
  local stage="$1" attempt="$2" round="$3" verdict="$4" severity="${5:-}"
  if [[ -z "$severity" ]]; then
    case "$verdict" in
      PASS) severity=none ;;
      NEEDS_WORK) severity=Major ;;
      BLOCKED) severity=Critical ;;
      *) echo "drive_review_round: cannot default severity for verdict '${verdict}'; pass it explicitly" >&2; return 1 ;;
    esac
  fi
  case "$stage" in
    spec) _loop_drive_spec_round "$attempt" "$round" "$verdict" "$severity" ;;
    impl|task|domain)
      echo "drive_review_round: stage '${stage}' is not implemented by A2/#142 (spec-review only; driving impl/task/domain is A3/#143 scope — see specs/epic-159-pillar-a/tasks.md T-002 Out of Scope and this task's implementation report)" >&2
      return 1
      ;;
    *)
      echo "drive_review_round: unknown stage: ${stage}" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# assert_artifacts_schema <dir>
# ---------------------------------------------------------------------------
assert_artifacts_schema() {
  local dir="$1" f schema known_json found any=0
  [[ -d "$dir" ]] || return 1
  known_json="$(jq -c '[.loops[].artifact_schemas[]] | unique' "$LOOP_INVENTORY_PATH")" || return 1
  for f in "$dir"/*.json; do
    [[ -f "$f" ]] || continue
    any=1
    schema="$(jq -r '.schema? // empty' "$f" 2>/dev/null)" || return 1
    [[ -n "$schema" ]] || return 1
    found="$(printf '%s' "$known_json" | jq -r --arg s "$schema" 'index($s) != null')"
    [[ "$found" == "true" ]] || return 1
  done
  [[ "$any" -eq 1 ]] || return 1
  return 0
}

# ---------------------------------------------------------------------------
# assert_terminal <loop-id> <observed-state> [<exit-code>]
# ---------------------------------------------------------------------------
assert_terminal() {
  local loop_id="$1" observed="$2" exit_code="${3:-0}" expected
  [[ "$exit_code" -eq 0 ]] || return 1
  expected="$(jq -r --arg id "$loop_id" '.loops[] | select(.id == $id) | .terminal.state // empty' "$LOOP_INVENTORY_PATH")" || return 1
  [[ -n "$expected" ]] || return 1
  [[ "$expected" == "$observed" ]]
}

# ---------------------------------------------------------------------------
# assert_runtime_budget <start-epoch> [<budget-seconds>]
# ---------------------------------------------------------------------------
assert_runtime_budget() {
  local start="$1" budget="${2:-$LOOP_SUITE_BUDGET_SECONDS}" now elapsed
  now=$(date +%s)
  elapsed=$(( now - start ))
  [[ "$elapsed" -le "$budget" ]]
}
