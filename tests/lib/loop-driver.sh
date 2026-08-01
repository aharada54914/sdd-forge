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

# _loop_set_status_field <file> <field> <value> — flips a canonical status
# header field (e.g. "Spec-Review-Status") in place, mirroring the same
# human/skill action the real workflow takes after a genuine terminal PASS
# (A3 / Issue #143: impl/task-review preconditions read these fields as
# plain text, independent of the review evidence chain itself).
_loop_set_status_field() {
  local file="$1" field="$2" value="$3" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/loop-status-field.XXXXXX")" || return 1
  sed "s/^${field}:[[:space:]]*.*/${field}: ${value}/" "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file"
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
  jq -r --arg id "$id" '.loops[] | select(.id == $id) | .driver_scripts[0] // empty' "$LOOP_INVENTORY_PATH" | tr -d '\r'
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

- REQ-001: loop-driver ${profile} fixture for feature ${feature} (A2 / Issue #142; A3 / Issue #143).
EOF
  cat > "${LOOP_FIXTURE_ROOT}/specs/${feature}/acceptance-tests.md" <<'EOF'
# Acceptance tests

| AC-ID | Requirement | Status |
|---|---|---|
| AC-001 | REQ-001 | Planned |
EOF

  # impl/task-review full-profile inputs (A3 / Issue #143): impl-review-precheck.sh
  # and task-review-precheck.sh both run under the fixture's unconditional
  # "full" workflow-state-registry profile (see the registry write below), so
  # both require design.md and the four layer specs to exist regardless of
  # which stage a given fixture ends up driving. These are synthesized here
  # (once, per fixture) rather than lazily per stage because their presence
  # is harmless to stages that never read them (spec-review-precheck.sh does
  # not touch design.md or the layer files). tasks.md/traceability.md are
  # deliberately NOT created here -- see _loop_task_fixture_prepare: a
  # tasks.md file existing at all makes check-workflow-state.sh require BOTH
  # Spec-Review-Status and Impl-Review-Status to already read Passed
  # (task-lifecycle gate), which would break a fixture mid-drive of the impl
  # leg itself, so tasks.md is synthesized lazily by the task-leg driver only
  # after both upstream statuses are genuinely Passed.
  cat > "${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md" <<EOF
# Design

Impl-Review-Status: Pending

## Components

- loop-driver ${profile} fixture component for feature ${feature} (A3 / Issue #143).

Feature Type: internal-tooling

Data Entities: none

Existing Data Affected: none

## Security Boundaries

- none (synthetic loop-driver fixture; no real security surface).
EOF
  cat > "${LOOP_FIXTURE_ROOT}/specs/${feature}/traceability.md" <<'EOF'
# Traceability

| REQ-ID | Description | Layer Spec |
|---|---|---|
| REQ-001 | loop-driver fixture requirement | ux-spec.md#req-001 |
EOF
  local layer_name
  for layer_name in ux frontend infra security; do
    cat > "${LOOP_FIXTURE_ROOT}/specs/${feature}/${layer_name}-spec.md" <<EOF
# ${layer_name} spec

<a id="req-001"></a>
## req-001

Synthetic ${layer_name} layer content for loop-driver fixture REQ-001.
EOF
  done

  _loop_fixture_init_domain || return 1

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
    plugins/sdd-domain/scripts/domain-review-precheck.sh \
    plugins/sdd-quality-loop/scripts/check-workflow-state.sh \
    plugins/sdd-review-loop/scripts/validate-layer-traceability.py
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
    plugins/sdd-domain/references/domain-review-calibration.md \
    contracts/workflow-state-registry.schema.json
  do
    src="${SDD_LOOP_REPO_ROOT}/${rel}"
    [[ -f "$src" ]] || continue
    mkdir -p "${LOOP_FIXTURE_ROOT}/$(dirname "$rel")" || return 1
    cp "$src" "${LOOP_FIXTURE_ROOT}/${rel}" || return 1
  done
  return 0
}

# _loop_fixture_init_domain — synthesizes the canonical domain/ tree
# (domain-review-precheck.sh's fixed, repo-root-relative input set; A3 /
# Issue #143) once per fixture, unconditionally, since domain-review is not
# feature-scoped and driving it never depends on which other stage(s) a
# given fixture also drives.
_loop_fixture_init_domain() {
  local domain_dir="${LOOP_FIXTURE_ROOT}/domain" name
  mkdir -p "${domain_dir}/aggregates" || return 1
  cat > "${domain_dir}/context-map.md" <<'EOF'
# Context map

Domain-Model-Status: Pending

## Contexts

- loop-driver-fixture-context: synthetic bounded context for the loop-driver domain fixture.
EOF
  for name in domain-story event-storming ubiquitous-language message-flow c4-container; do
    cat > "${domain_dir}/${name}.md" <<EOF
# ${name}

Synthetic ${name} content for the loop-driver domain fixture (A3 / Issue #143).
EOF
  done
  jq -n '{schema: "domain-contract/v1", contexts: ["loop-driver-fixture-context"]}' \
    > "${domain_dir}/domain-contract.json" || return 1
  cat > "${domain_dir}/aggregates/loop-driver-fixture.md" <<'EOF'
# loop-driver-fixture aggregate

Synthetic aggregate card for the loop-driver domain fixture.
EOF
  return 0
}

# _loop_task_fixture_prepare <feature> — lazily synthesizes tasks.md, called
# by _loop_drive_task_round immediately before the first task round it
# drives. Deferred (not part of loop_fixture_init) because tasks.md merely
# existing forces check-workflow-state.sh's task-lifecycle gate to require
# both Spec-Review-Status and Impl-Review-Status to already read Passed
# (see loop_fixture_init's comment); the caller is responsible for having
# already driven and flipped those two stages to Passed first.
#
# Two tasks (T-002 Blockers: T-001) rather than one: task-review-precheck.sh
# builds graph_edges_to by parsing every Blockers field, and a single task
# with "Blockers: None" never appends to that array. Under bash 3.2 (macOS
# CI's default /bin/bash) `"${graph_edges_to[@]}"` on a declared-but-never-
# appended-to array is an unbound-variable error with `set -u`, even though
# bash 4.4+ treats it as an empty expansion. Keeping a real (non-cyclic)
# dependency edge in the fixture keeps that array non-empty on every bash
# version without branching on host OS.
_loop_task_fixture_prepare() {
  local feature="$1"
  local tasks_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/tasks.md"
  [[ -f "$tasks_path" ]] && return 0
  cat > "$tasks_path" <<'EOF'
# Tasks

Task-Review-Status: Pending

## T-001 loop-driver fixture task

Approval: Draft

Status: Planned

Risk: low

Risk Rationale: synthetic loop-driver fixture task; no real change surface.

Blockers: None

## T-002 loop-driver fixture dependent task

Approval: Draft

Status: Planned

Risk: low

Risk Rationale: synthetic loop-driver fixture task; no real change surface.

Blockers: T-001
EOF
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
  jq -r '(.records | length) + 1' "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json" | tr -d '\r'
}
_loop_previous_hash() {
  jq -r '.records[-1].record_sha256' "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json" | tr -d '\r'
}

# _loop_review_context_call <stage> <role> <feature> <manifest-json-array> [reserve|check]
# Runs the REAL validate-review-context-set.sh against $LOOP_FIXTURE_ROOT
# (passed as repository-root data, not a symlink target). Mode "reserve"
# (default) extends the fixture's identity-ledger chain; mode "check" omits
# --reserve so the call is read-only and never advances the ledger -- safe
# to re-run any number of times (security-spec.md B1/B2).
_loop_review_context_call() {
  local stage="$1" role="$2" feature="$3" manifest_entries="$4" mode="${5:-reserve}"
  local validator="${SDD_LOOP_REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
  [[ -f "$validator" ]] || { echo "_loop_review_context_call: validator missing: ${validator}" >&2; return 1; }
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
  if [[ "$mode" == check ]]; then
    "$validator" "$manifest_path" "${LOOP_FIXTURE_ROOT}" >/dev/null
  else
    "$validator" "$manifest_path" "${LOOP_FIXTURE_ROOT}" --reserve >/dev/null
  fi
  rc=$?
  rm -f "$manifest_path"
  return $rc
}

# ---------------------------------------------------------------------------
# Runtime capability probe for validator-driving checks
# ---------------------------------------------------------------------------

# _loop_genesis_formula_valid <ledger> — suite-side recomputation of the
# genesis record hash via the canonical INV-006 formula
# (validate-review-context-set.sh:245), using this library's own CRLF-safe
# jq reads. Returns 0 when the stored record_sha256 matches the formula.
_loop_genesis_formula_valid() {
  local ledger="$1" seq stage role run session previous stored computed
  [[ -f "$ledger" ]] || return 1
  seq="$(jq -r '.records[0].sequence' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  stage="$(jq -r '.records[0].stage' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  role="$(jq -r '.records[0].role' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  run="$(jq -r '.records[0].run_id' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  session="$(jq -r '.records[0].host_session_id' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  previous="$(jq -r '.records[0].previous_record_sha256' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  stored="$(jq -r '.records[0].record_sha256' "$ledger" 2>/dev/null | tr -d '\r')" || return 1
  computed="$(printf '%s' "${seq}|${stage}|${role}|${run}|${session}|${previous}" | _loop_sha256_text)"
  [[ -n "$stored" && "$computed" == "$stored" ]]
}

# loop_validator_capability_probe — pure runtime behavior probe (REQ-005: no
# uname/OS branching anywhere). Immediately after loop_fixture_init, asks the
# REAL validate-review-context-set.sh to check-validate (read-only, never
# --reserve, so the fixture ledger is not advanced) a minimal spec-reviewer-a
# manifest against the fixture's genesis identity ledger.
#
# Returns 0 (capability ok) when the validator accepts the call. Returns 1
# (capability degraded) ONLY when BOTH hold: the validator rejected the call
# with a REVIEW_CONTEXT_IDENTITY error, AND this library's own canonical
# INV-006 formula recomputation validates the very same genesis record. That
# conjunction is the signature of the upstream Windows CRLF defect in
# validate-review-context-set.sh's record-hash recomputation (its
# while-IFS=tab-read loop consumes `jq -r ... | @tsv` output whose trailing
# CR lands in the final record_sha256 field, so a byte-exact hash comparison
# fails on a canonically valid ledger; tracked as issue #179). Every other
# failure mode returns 0 so genuine regressions still fail loudly in the
# gated checks themselves.
#
# The verdict is cached in LOOP_VALIDATOR_CAPABILITY (ok|degraded): a suite
# probes the real validator at most once, and later gate points may call
# this function again cheaply as a plain condition.
LOOP_VALIDATOR_SKIP_REASON="real validator rejects a canonically-valid genesis ledger on this runtime (upstream Windows CRLF defect in validate-review-context-set.sh record-hash recomputation; issue #179)"
loop_validator_capability_probe() {
  if [[ -n "${LOOP_VALIDATOR_CAPABILITY:-}" ]]; then
    [[ "$LOOP_VALIDATOR_CAPABILITY" == ok ]]
    return
  fi
  local feature="${LOOP_FIXTURE_FEATURE:?loop_validator_capability_probe requires LOOP_FIXTURE_FEATURE (set by loop_fixture_init)}"
  local ledger="${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json"
  local entries probe_out probe_rc
  entries="$(_loop_manifest_array \
    "specs/${feature}/requirements.md" \
    "specs/${feature}/acceptance-tests.md")" || {
    # Could not even compose the probe manifest: not the upstream validator
    # defect; report ok so the real checks run and surface the actual error.
    LOOP_VALIDATOR_CAPABILITY=ok
    return 0
  }
  if probe_out="$(_loop_review_context_call spec spec-reviewer-a "$feature" "$entries" check 2>&1)"; then
    probe_rc=0
  else
    probe_rc=$?
  fi
  if [[ "$probe_rc" -eq 0 ]]; then
    LOOP_VALIDATOR_CAPABILITY=ok
    return 0
  fi
  if [[ "$probe_out" == *REVIEW_CONTEXT_IDENTITY* ]] && _loop_genesis_formula_valid "$ledger"; then
    LOOP_VALIDATOR_CAPABILITY=degraded
    return 1
  fi
  LOOP_VALIDATOR_CAPABILITY=ok
  return 0
}

# loop_validator_skip <check-id> — emits the canonical named SKIP line for a
# validator-driving check suppressed by loop_validator_capability_probe.
loop_validator_skip() {
  printf 'SKIP: %s: %s\n' "$1" "$LOOP_VALIDATOR_SKIP_REASON"
}

# Second runtime capability probe (behavior-only, no OS branching), same
# design as loop_validator_capability_probe: the impl/task legs additionally
# exercise impl-review-precheck.sh's canonical workflow-state validation,
# which has its own upstream Windows CRLF consumption defect (issue #203)
# that only became reachable once issue #179's validator fix let those legs
# run. Probes the fixture's own checker once, read-only; cached globally
# because the defect is runtime-level, not fixture-level.
LOOP_WORKFLOW_STATE_SKIP_REASON="canonical workflow-state validation rejects the fixture's registered, on-disk specification directory on this runtime (upstream Windows CRLF defect in check-workflow-state.sh jq -r consumption; issue #203)"
loop_workflow_state_capability_probe() {
  if [[ -n "${LOOP_WORKFLOW_STATE_CAPABILITY:-}" ]]; then
    [[ "$LOOP_WORKFLOW_STATE_CAPABILITY" == ok ]]
    return
  fi
  local root="${LOOP_FIXTURE_ROOT:?loop_workflow_state_capability_probe requires LOOP_FIXTURE_ROOT (set by loop_fixture_init)}"
  local checker="${root}/plugins/sdd-quality-loop/scripts/check-workflow-state.sh"
  local probe_out probe_rc
  if [[ ! -f "$checker" ]]; then
    # No fixture copy to probe: not the upstream defect; report ok so the
    # real checks run and surface the actual error.
    LOOP_WORKFLOW_STATE_CAPABILITY=ok
    return 0
  fi
  if probe_out="$(bash "$checker" --feature "${LOOP_FIXTURE_FEATURE:-}" 2>&1)"; then
    probe_rc=0
  else
    probe_rc=$?
  fi
  if [[ "$probe_rc" -eq 0 ]]; then
    LOOP_WORKFLOW_STATE_CAPABILITY=ok
    return 0
  fi
  if [[ "$probe_out" == *registry-dangling-entry* ]]; then
    # The fixture registry is canonically valid by construction (every
    # registered directory exists on disk), so a dangling-entry diagnostic
    # here can only be the upstream CRLF consumption defect.
    LOOP_WORKFLOW_STATE_CAPABILITY=degraded
    return 1
  fi
  LOOP_WORKFLOW_STATE_CAPABILITY=ok
  return 0
}

# loop_workflow_state_skip <check-id> — canonical named SKIP line for a check
# suppressed by loop_workflow_state_capability_probe.
loop_workflow_state_skip() {
  printf 'SKIP: %s: %s\n' "$1" "$LOOP_WORKFLOW_STATE_SKIP_REASON"
}

# loop_impl_chain_skip <check-id> — SKIP for checks that need BOTH the real
# validator and canonical workflow-state validation; names whichever
# capability degraded.
loop_impl_chain_skip() {
  if [[ "${LOOP_VALIDATOR_CAPABILITY:-}" == degraded ]]; then
    loop_validator_skip "$1"
  else
    loop_workflow_state_skip "$1"
  fi
}

# _loop_reserve_review_context <stage> <role> <feature> <manifest-json-array>
# Unchanged public contract from A2/#142: always reserves (extends the
# identity-ledger chain).
_loop_reserve_review_context() {
  _loop_review_context_call "$1" "$2" "$3" "$4" reserve
}

# ---------------------------------------------------------------------------
# assert_bidirectional_invariant <stage> <role> <feature> <manifest-json-array>
# ---------------------------------------------------------------------------
# A3 / Issue #143, AC-010: re-validates (READ-ONLY, no --reserve) the exact
# manifest a downstream gate composed as its round requirement against the
# REAL validate-review-context-set.sh cross_gate script -- the same script
# drive_review_round already called with --reserve to actually advance the
# round, so a successful drive already proves the invariant once; this
# function makes the assertion explicit and independently re-checkable
# (including by the negative self-check below) without mutating the ledger.
# Returns 0 iff every input the downstream gate's manifest requires is an
# input the upstream gate (cross_gates) authorizes.
assert_bidirectional_invariant() {
  _loop_review_context_call "$1" "$2" "$3" "$4" check
}

# ---------------------------------------------------------------------------
# assert_prior_round_complete <stage> <round-dir>
# ---------------------------------------------------------------------------
_loop_required_round_files() {
  case "$1" in
    spec) printf '%s\n' precheck-result.json integrated-summary.json reviewer-a.json reviewer-b.json integrated-verdict.json spec-review-contract.json ;;
    impl) printf '%s\n' precheck-result.json integrated-summary.json reviewer-a.json reviewer-b.json integrated-verdict.json impl-review-contract.json ;;
    task) printf '%s\n' precheck-result.json dependency-graph.json integrated-summary.json reviewer-a.json reviewer-b.json integrated-verdict.json task-review-contract.json ;;
    domain) printf '%s\n' precheck-result.json integrated-summary.json reviewer-a.json reviewer-b.json integrated-verdict.json domain-review-contract.json ;;
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
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
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
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
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

# =============================================================================
# A3 / Issue #143 stage dispatch extension: impl/task/domain review rounds.
# Orchestrator scope adjudication (recorded in tasks.md T-003 and this task's
# implementation report Specification Differences): T-002's Out of Scope note
# assigned "driving impl/task/domain loops" to T-003/T-004, and T-003's own
# Goal cannot be achieved without extending drive_review_round's dispatcher,
# so this addition is in scope for T-003. It is a REVIEW-STAGE dispatch
# extension only -- the escalation chain (quality-gate/terminal-tier) stays
# T-004 scope and is not touched here. The existing "spec" stage function,
# the public function contract, and T-002's smoke suite are unmodified.
# =============================================================================

# ---------------------------------------------------------------------------
# impl-review round emission
# ---------------------------------------------------------------------------
_loop_impl_layer_names() { printf '%s\n' ux-spec frontend-spec infra-spec security-spec; }

_loop_impl_layer_sha_json() {
  local feature="$1" name path json='{}'
  for name in $(_loop_impl_layer_names); do
    path="${LOOP_FIXTURE_ROOT}/specs/${feature}/${name}.md"
    json="$(jq -c --arg k "${name}.md" --arg v "$(_loop_sha256 "$path")" '. + {($k): $v}' <<<"$json")"
  done
  printf '%s' "$json"
}

_loop_emit_impl_round_a() {
  local round_dir="$1" severity="$2"
  local round a_verdict a_result a_fails a_passes check_severity feature
  feature="$LOOP_FIXTURE_FEATURE"
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
  case "$severity" in
    none)     a_verdict="PASS";        a_result="PASS"; a_fails=0; a_passes=6; check_severity="Minor" ;;
    Critical) a_verdict="BLOCKED";     a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Critical" ;;
    Major)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Major" ;;
    Minor)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Minor" ;;
    *) echo "_loop_emit_impl_round_a: unknown severity: ${severity}" >&2; return 1 ;;
  esac

  jq -n --argjson attempt 1 --argjson round "$round" \
    --argjson fail_count "$a_fails" --argjson pass_count "$a_passes" '
    ["INPUT-COMPLETENESS","DESIGN-ALIGNMENT","LAYER-COVERAGE","RISK-SURFACE","IMPLEMENTABILITY","SCOPE-BOUNDARY"] as $ids |
    {schema:"integrated-summary/v1",attempt:$attempt,round:$round,
     reviewer_a_check_ids:$ids,
     reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}' \
    > "${round_dir}/integrated-summary.json" || return 1

  local requirements_path acceptance_path design_path precheck_path calibration_path
  local requirements_sha acceptance_sha design_sha precheck_sha calibration_sha layer_sha
  requirements_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md"
  acceptance_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/acceptance-tests.md"
  design_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md"
  precheck_path="${round_dir}/precheck-result.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-review-loop/references/reviewer-calibration.md"
  requirements_sha="$(_loop_sha256 "$requirements_path")"
  acceptance_sha="$(_loop_sha256 "$acceptance_path")"
  design_sha="$(_loop_sha256 "$design_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"
  layer_sha="$(_loop_impl_layer_sha_json "$feature")"

  local manifest_json name lname lpath lsha
  manifest_json="$(jq -n --arg requirements "$requirements_path" --arg requirements_sha "$requirements_sha" \
    --arg acceptance "$acceptance_path" --arg acceptance_sha "$acceptance_sha" \
    --arg design "$design_path" --arg design_sha "$design_sha" \
    --arg precheck "$precheck_path" --arg precheck_sha "$precheck_sha" \
    --arg calibration "$calibration_path" --arg calibration_sha "$calibration_sha" '
    [{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},
     {path:$design,sha256:$design_sha},{path:$precheck,sha256:$precheck_sha},
     {path:$calibration,sha256:$calibration_sha}]')"
  for name in $(_loop_impl_layer_names); do
    lpath="${LOOP_FIXTURE_ROOT}/specs/${feature}/${name}.md"
    lsha="$(_loop_sha256 "$lpath")"
    manifest_json="$(jq -c --arg p "$lpath" --arg s "$lsha" '. + [{path:$p,sha256:$s}]' <<<"$manifest_json")"
  done
  # INV-012/2d8c6a5 fix regression lock: round>1 carries the PREVIOUS round's
  # integrated-summary.json on impl-reviewer-a's own manifest (the exact
  # entry the pre-fix validator rejected -- see the RED differential).
  if [[ "$round" -gt 1 ]]; then
    local prior_summary="${LOOP_FIXTURE_ROOT}/reports/impl-review/${feature}/attempt-1/round-$((round - 1))/integrated-summary.json"
    manifest_json="$(jq -c --arg p "$prior_summary" --arg s "$(_loop_sha256 "$prior_summary")" '. + [{path:$p,sha256:$s}]' <<<"$manifest_json")"
  fi

  jq -n --arg verdict "$a_verdict" --argjson manifest "$manifest_json" \
    --arg result "$a_result" --arg severity "$check_severity" '
    ["INPUT-COMPLETENESS","DESIGN-ALIGNMENT","LAYER-COVERAGE","RISK-SURFACE","IMPLEMENTABILITY","SCOPE-BOUNDARY"] as $ids |
    {schema:"impl-reviewer-a/v1",stage:"impl",role:"impl-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",
     allowed_input_manifest:$manifest, verdict:$verdict,
     checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}' \
    > "${round_dir}/reviewer-a.json" || return 1

  return 0
}

_loop_emit_impl_round_b_contract() {
  local round_dir="$1" verdict="$2" severity="$3"
  local round critical major minor feature
  feature="$LOOP_FIXTURE_FEATURE"
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
  case "$severity" in
    none)     critical=0; major=0; minor=0 ;;
    Critical) critical=1; major=0; minor=0 ;;
    Major)    critical=0; major=1; minor=0 ;;
    Minor)    critical=0; major=0; minor=1 ;;
    *) echo "_loop_emit_impl_round_b_contract: unknown severity: ${severity}" >&2; return 1 ;;
  esac
  local a_verdict
  if [[ "$critical" -gt 0 ]]; then a_verdict=BLOCKED
  elif [[ "$((major + minor))" -gt 0 ]]; then a_verdict=NEEDS_WORK
  else a_verdict=PASS; fi

  local requirements_path acceptance_path design_path precheck_path calibration_path summary_path
  local requirements_sha acceptance_sha design_sha precheck_sha calibration_sha summary_sha layer_sha
  requirements_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md"
  acceptance_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/acceptance-tests.md"
  design_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md"
  precheck_path="${round_dir}/precheck-result.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-review-loop/references/reviewer-calibration.md"
  summary_path="${round_dir}/integrated-summary.json"
  requirements_sha="$(_loop_sha256 "$requirements_path")"
  acceptance_sha="$(_loop_sha256 "$acceptance_path")"
  design_sha="$(_loop_sha256 "$design_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"
  summary_sha="$(_loop_sha256 "$summary_path")"
  layer_sha="$(_loop_impl_layer_sha_json "$feature")"

  jq -n --arg feature "$feature" --arg verdict "$verdict" --argjson round "$round" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" \
    --arg a_verdict "$a_verdict" '
    {schema:"integrated-verdict/v1",stage:"impl",feature:$feature,attempt:1,round:$round,
     run_id:"fixture-orchestrator",verdict:$verdict,
     reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",
     findings_critical:$critical,findings_major:$major,findings_minor:$minor}' \
    > "${round_dir}/integrated-verdict.json" || return 1

  local manifest_b_json name lpath lsha
  manifest_b_json="$(jq -n --arg requirements "$requirements_path" --arg requirements_sha "$requirements_sha" \
    --arg acceptance "$acceptance_path" --arg acceptance_sha "$acceptance_sha" \
    --arg design "$design_path" --arg design_sha "$design_sha" \
    --arg precheck "$precheck_path" --arg precheck_sha "$precheck_sha" \
    --arg calibration "$calibration_path" --arg calibration_sha "$calibration_sha" \
    --arg summary "$summary_path" --arg summary_sha "$summary_sha" '
    [{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},
     {path:$design,sha256:$design_sha},{path:$precheck,sha256:$precheck_sha},
     {path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}]')"
  for name in $(_loop_impl_layer_names); do
    lpath="${LOOP_FIXTURE_ROOT}/specs/${feature}/${name}.md"
    lsha="$(_loop_sha256 "$lpath")"
    manifest_b_json="$(jq -c --arg p "$lpath" --arg s "$lsha" '. + [{path:$p,sha256:$s}]' <<<"$manifest_b_json")"
  done
  jq -n --arg result PASS --arg severity Minor '
    ["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids |
    {schema:"impl-reviewer-b/v1",stage:"impl",role:"impl-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",
     allowed_input_manifest:'"$manifest_b_json"',verdict:"PASS",
     checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}' \
    > "${round_dir}/reviewer-b.json" || return 1

  local manifest_a_json
  manifest_a_json="$(jq -r '.allowed_input_manifest' "${round_dir}/reviewer-a.json" | tr -d '\r')"
  jq -n --arg feature "$feature" --arg verdict "$verdict" --argjson round "$round" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" \
    --arg a_verdict "$a_verdict" --arg requirements_sha256 "$requirements_sha" --arg acceptance_sha256 "$acceptance_sha" \
    --arg design_sha256 "$design_sha" --argjson layer_sha256 "$layer_sha" \
    --argjson manifest_a "$manifest_a_json" --argjson manifest_b "$manifest_b_json" '
    {schema:"impl-review-contract/v1",stage:"impl",feature:$feature,attempt:1,round:$round,
     run_id:"fixture-orchestrator",verdict:$verdict,
     reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",
     findings_critical:$critical,findings_major:$major,findings_minor:$minor,
     requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,
     design_sha256:$design_sha256,layer_sha256:$layer_sha256,
     reviewers:[
       {role:"impl-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest_a},
       {role:"impl-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest_b}
     ]}' \
    > "${round_dir}/impl-review-contract.json" || return 1

  return 0
}

_loop_impl_manifest_a() {
  local round_dir="$1" round="$2" feature="$3" round_rel name
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  local rels=(
    "specs/${feature}/requirements.md"
    "specs/${feature}/acceptance-tests.md"
    "specs/${feature}/design.md"
    "plugins/sdd-review-loop/references/reviewer-calibration.md"
    "${round_rel}/precheck-result.json"
  )
  for name in $(_loop_impl_layer_names); do rels+=("specs/${feature}/${name}.md"); done
  if [[ "$round" -gt 1 ]]; then
    rels+=("reports/impl-review/${feature}/attempt-1/round-$((round - 1))/integrated-summary.json")
  fi
  _loop_manifest_array "${rels[@]}"
}
_loop_impl_manifest_b() {
  local round_dir="$1" feature="$2" round_rel name
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  local rels=(
    "specs/${feature}/requirements.md"
    "specs/${feature}/acceptance-tests.md"
    "specs/${feature}/design.md"
    "plugins/sdd-review-loop/references/reviewer-calibration.md"
    "${round_rel}/precheck-result.json"
    "${round_rel}/integrated-summary.json"
  )
  for name in $(_loop_impl_layer_names); do rels+=("specs/${feature}/${name}.md"); done
  _loop_manifest_array "${rels[@]}"
}

# loop_prepare_impl_prereqs <feature> — drives spec rounds 1->3 to a genuine
# PASS on <feature> (reusing _loop_drive_spec_round unmodified) and flips
# Spec-Review-Status to Passed, so impl-review-precheck.sh's own
# unconditional precondition (require_persisted_pass + the literal
# "Spec-Review-Status: Passed" field check) is satisfied by real, on-disk
# evidence -- never a hand-written shortcut.
loop_prepare_impl_prereqs() {
  local feature="$1"
  _loop_drive_spec_round 1 1 NEEDS_WORK Major || return 1
  _loop_drive_spec_round 1 2 NEEDS_WORK Major || return 1
  _loop_drive_spec_round 1 3 PASS Minor || return 1
  _loop_set_status_field "${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md" "Spec-Review-Status" "Passed" || return 1
  return 0
}

# loop_prepare_task_prereqs <feature> — additionally drives impl rounds 1->3
# to a genuine PASS and flips Impl-Review-Status to Passed (after
# loop_prepare_impl_prereqs), then lazily synthesizes tasks.md, satisfying
# task-review-precheck.sh's own unconditional preconditions (both status
# fields plus require_persisted_pass for both spec and impl -- OQ-5 subject).
loop_prepare_task_prereqs() {
  local feature="$1"
  loop_prepare_impl_prereqs "$feature" || return 1
  drive_review_round impl 1 1 NEEDS_WORK Major || return 1
  drive_review_round impl 1 2 NEEDS_WORK Major || return 1
  drive_review_round impl 1 3 PASS none || return 1
  _loop_set_status_field "${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md" "Impl-Review-Status" "Passed" || return 1
  _loop_task_fixture_prepare "$feature" || return 1
  return 0
}

_loop_drive_impl_round() {
  local attempt="$1" round="$2" verdict="$3" severity="$4"
  local feature script_rel script design precheck_args
  feature="${LOOP_FIXTURE_FEATURE:?_loop_drive_impl_round requires LOOP_FIXTURE_FEATURE (set by loop_fixture_init)}"
  script_rel="$(_loop_driver_script impl)" || return 1
  [[ -n "$script_rel" ]] || { echo "drive_review_round: impl-review driver script not registered in the inventory" >&2; return 1; }
  script="${LOOP_FIXTURE_ROOT}/${script_rel}"
  [[ -f "$script" ]] || { echo "drive_review_round: precheck script missing at ${script}" >&2; return 1; }

  design="${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md"
  precheck_args=("$feature" "$attempt" "$round")
  if [[ "$round" -gt 1 ]]; then
    local prior_dir="${LOOP_FIXTURE_ROOT}/reports/impl-review/${feature}/attempt-${attempt}/round-$((round - 1))"
    assert_prior_round_complete impl "$prior_dir" || {
      echo "drive_review_round: round-$((round - 1)) output set is incomplete on disk; refusing to start round ${round}" >&2
      return 1
    }
    printf '\n<!-- loop-driver round %s edit -->\n' "$round" >> "$design"
  fi

  ( cd "${LOOP_FIXTURE_ROOT}" && bash "$script" "${precheck_args[@]}" ) >/dev/null || return 1

  local round_dir="${LOOP_FIXTURE_ROOT}/reports/impl-review/${feature}/attempt-${attempt}/round-${round}"
  [[ -f "${round_dir}/precheck-result.json" ]] || {
    echo "drive_review_round: precheck-result.json missing after a successful precheck run" >&2
    return 1
  }

  local manifest_a manifest_b
  manifest_a="$(_loop_impl_manifest_a "$round_dir" "$round" "$feature")" || return 1
  _loop_reserve_review_context impl impl-reviewer-a "$feature" "$manifest_a" || return 1
  _loop_emit_impl_round_a "$round_dir" "$severity" || return 1

  manifest_b="$(_loop_impl_manifest_b "$round_dir" "$feature")" || return 1
  _loop_reserve_review_context impl impl-reviewer-b "$feature" "$manifest_b" || return 1
  _loop_emit_impl_round_b_contract "$round_dir" "$verdict" "$severity" || return 1

  return 0
}

# ---------------------------------------------------------------------------
# task-review round emission
# ---------------------------------------------------------------------------
_loop_emit_task_round_a() {
  local round_dir="$1" severity="$2"
  local round a_verdict a_result a_fails a_passes check_severity feature
  feature="$LOOP_FIXTURE_FEATURE"
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
  case "$severity" in
    none)     a_verdict="PASS";        a_result="PASS"; a_fails=0; a_passes=6; check_severity="Minor" ;;
    Critical) a_verdict="BLOCKED";     a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Critical" ;;
    Major)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Major" ;;
    Minor)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Minor" ;;
    *) echo "_loop_emit_task_round_a: unknown severity: ${severity}" >&2; return 1 ;;
  esac

  jq -n --argjson attempt 1 --argjson round "$round" \
    --argjson fail_count "$a_fails" --argjson pass_count "$a_passes" '
    ["DEPENDENCY-GRAPH-VALID","TASK-AC-TRACE","RISK-WORKFLOW-MATCH","SCOPE-DISJOINT","ROLLBACK-PLANNED","SIZE-APPROPRIATE"] as $ids |
    {schema:"integrated-summary/v1",attempt:$attempt,round:$round,
     reviewer_a_check_ids:$ids,
     reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}' \
    > "${round_dir}/integrated-summary.json" || return 1

  local tasks_path requirements_path acceptance_path design_path precheck_path dep_path calibration_path
  local tasks_sha requirements_sha acceptance_sha design_sha precheck_sha dep_sha calibration_sha
  tasks_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/tasks.md"
  requirements_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md"
  acceptance_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/acceptance-tests.md"
  design_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md"
  precheck_path="${round_dir}/precheck-result.json"
  dep_path="${round_dir}/dependency-graph.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-review-loop/references/reviewer-calibration.md"
  tasks_sha="$(_loop_sha256 "$tasks_path")"
  requirements_sha="$(_loop_sha256 "$requirements_path")"
  acceptance_sha="$(_loop_sha256 "$acceptance_path")"
  design_sha="$(_loop_sha256 "$design_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  dep_sha="$(_loop_sha256 "$dep_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"

  jq -n --arg verdict "$a_verdict" --arg result "$a_result" --arg severity "$check_severity" \
    --arg tasks "$tasks_path" --arg tasks_sha "$tasks_sha" \
    --arg requirements "$requirements_path" --arg requirements_sha "$requirements_sha" \
    --arg acceptance "$acceptance_path" --arg acceptance_sha "$acceptance_sha" \
    --arg design "$design_path" --arg design_sha "$design_sha" \
    --arg precheck "$precheck_path" --arg precheck_sha "$precheck_sha" \
    --arg dep "$dep_path" --arg dep_sha "$dep_sha" \
    --arg calibration "$calibration_path" --arg calibration_sha "$calibration_sha" '
    ["DEPENDENCY-GRAPH-VALID","TASK-AC-TRACE","RISK-WORKFLOW-MATCH","SCOPE-DISJOINT","ROLLBACK-PLANNED","SIZE-APPROPRIATE"] as $ids |
    {schema:"task-reviewer-a/v1",stage:"task",role:"task-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",
     allowed_input_manifest:[
       {path:$tasks,sha256:$tasks_sha},{path:$requirements,sha256:$requirements_sha},
       {path:$acceptance,sha256:$acceptance_sha},{path:$design,sha256:$design_sha},
       {path:$precheck,sha256:$precheck_sha},{path:$dep,sha256:$dep_sha},
       {path:$calibration,sha256:$calibration_sha}
     ],
     verdict:$verdict,
     checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}' \
    > "${round_dir}/reviewer-a.json" || return 1

  return 0
}

_loop_emit_task_round_b_contract() {
  local round_dir="$1" verdict="$2" severity="$3"
  local round critical major minor feature
  feature="$LOOP_FIXTURE_FEATURE"
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
  case "$severity" in
    none)     critical=0; major=0; minor=0 ;;
    Critical) critical=1; major=0; minor=0 ;;
    Major)    critical=0; major=1; minor=0 ;;
    Minor)    critical=0; major=0; minor=1 ;;
    *) echo "_loop_emit_task_round_b_contract: unknown severity: ${severity}" >&2; return 1 ;;
  esac
  local a_verdict
  if [[ "$critical" -gt 0 ]]; then a_verdict=BLOCKED
  elif [[ "$((major + minor))" -gt 0 ]]; then a_verdict=NEEDS_WORK
  else a_verdict=PASS; fi

  local tasks_path requirements_path acceptance_path design_path precheck_path dep_path calibration_path summary_path
  local tasks_sha requirements_sha acceptance_sha design_sha precheck_sha dep_sha calibration_sha summary_sha
  tasks_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/tasks.md"
  requirements_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/requirements.md"
  acceptance_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/acceptance-tests.md"
  design_path="${LOOP_FIXTURE_ROOT}/specs/${feature}/design.md"
  precheck_path="${round_dir}/precheck-result.json"
  dep_path="${round_dir}/dependency-graph.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-review-loop/references/reviewer-calibration.md"
  summary_path="${round_dir}/integrated-summary.json"
  tasks_sha="$(_loop_sha256 "$tasks_path")"
  requirements_sha="$(_loop_sha256 "$requirements_path")"
  acceptance_sha="$(_loop_sha256 "$acceptance_path")"
  design_sha="$(_loop_sha256 "$design_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  dep_sha="$(_loop_sha256 "$dep_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"
  summary_sha="$(_loop_sha256 "$summary_path")"

  jq -n --arg feature "$feature" --arg verdict "$verdict" --argjson round "$round" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" \
    --arg a_verdict "$a_verdict" '
    {schema:"integrated-verdict/v1",stage:"task",feature:$feature,attempt:1,round:$round,
     run_id:"fixture-orchestrator",verdict:$verdict,
     reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",
     findings_critical:$critical,findings_major:$major,findings_minor:$minor}' \
    > "${round_dir}/integrated-verdict.json" || return 1

  jq -n --arg tasks "$tasks_path" --arg tasks_sha "$tasks_sha" \
    --arg requirements "$requirements_path" --arg requirements_sha "$requirements_sha" \
    --arg acceptance "$acceptance_path" --arg acceptance_sha "$acceptance_sha" \
    --arg design "$design_path" --arg design_sha "$design_sha" \
    --arg precheck "$precheck_path" --arg precheck_sha "$precheck_sha" \
    --arg calibration "$calibration_path" --arg calibration_sha "$calibration_sha" \
    --arg summary "$summary_path" --arg summary_sha "$summary_sha" '
    ["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids |
    {schema:"task-reviewer-b/v1",stage:"task",role:"task-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",
     allowed_input_manifest:[
       {path:$tasks,sha256:$tasks_sha},{path:$requirements,sha256:$requirements_sha},
       {path:$acceptance,sha256:$acceptance_sha},{path:$design,sha256:$design_sha},
       {path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},
       {path:$summary,sha256:$summary_sha}
     ],
     verdict:"PASS",
     checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}' \
    > "${round_dir}/reviewer-b.json" || return 1

  local manifest_a_json manifest_b_json
  manifest_a_json="$(jq -r '.allowed_input_manifest' "${round_dir}/reviewer-a.json" | tr -d '\r')"
  manifest_b_json="$(jq -r '.allowed_input_manifest' "${round_dir}/reviewer-b.json" | tr -d '\r')"
  jq -n --arg feature "$feature" --arg verdict "$verdict" --argjson round "$round" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" \
    --arg a_verdict "$a_verdict" --arg tasks_sha256 "$tasks_sha" \
    --arg requirements_sha256 "$requirements_sha" --arg acceptance_sha256 "$acceptance_sha" \
    --argjson manifest_a "$manifest_a_json" --argjson manifest_b "$manifest_b_json" '
    {schema:"task-review-contract/v1",stage:"task",feature:$feature,attempt:1,round:$round,
     run_id:"fixture-orchestrator",verdict:$verdict,
     reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",
     findings_critical:$critical,findings_major:$major,findings_minor:$minor,
     tasks_sha256:$tasks_sha256,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,
     reviewers:[
       {role:"task-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest_a},
       {role:"task-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest_b}
     ]}' \
    > "${round_dir}/task-review-contract.json" || return 1

  return 0
}

_loop_task_manifest_a() {
  local round_dir="$1" feature="$2" round_rel
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  _loop_manifest_array \
    "specs/${feature}/tasks.md" "specs/${feature}/requirements.md" "specs/${feature}/acceptance-tests.md" \
    "specs/${feature}/design.md" "plugins/sdd-review-loop/references/reviewer-calibration.md" \
    "${round_rel}/precheck-result.json" "${round_rel}/dependency-graph.json"
}
_loop_task_manifest_b() {
  local round_dir="$1" feature="$2" round_rel
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  _loop_manifest_array \
    "specs/${feature}/tasks.md" "specs/${feature}/requirements.md" "specs/${feature}/acceptance-tests.md" \
    "specs/${feature}/design.md" "plugins/sdd-review-loop/references/reviewer-calibration.md" \
    "${round_rel}/precheck-result.json" "${round_rel}/integrated-summary.json"
}

_loop_drive_task_round() {
  local attempt="$1" round="$2" verdict="$3" severity="$4"
  local feature script_rel script tasks precheck_args
  feature="${LOOP_FIXTURE_FEATURE:?_loop_drive_task_round requires LOOP_FIXTURE_FEATURE (set by loop_fixture_init)}"
  script_rel="$(_loop_driver_script task)" || return 1
  [[ -n "$script_rel" ]] || { echo "drive_review_round: task-review driver script not registered in the inventory" >&2; return 1; }
  script="${LOOP_FIXTURE_ROOT}/${script_rel}"
  [[ -f "$script" ]] || { echo "drive_review_round: precheck script missing at ${script}" >&2; return 1; }

  tasks="${LOOP_FIXTURE_ROOT}/specs/${feature}/tasks.md"
  [[ -f "$tasks" ]] || { echo "drive_review_round: tasks.md missing; call loop_prepare_task_prereqs first" >&2; return 1; }
  precheck_args=("$feature" "$attempt" "$round")
  if [[ "$round" -gt 1 ]]; then
    local prior_dir="${LOOP_FIXTURE_ROOT}/reports/task-review/${feature}/attempt-${attempt}/round-$((round - 1))"
    assert_prior_round_complete task "$prior_dir" || {
      echo "drive_review_round: round-$((round - 1)) output set is incomplete on disk; refusing to start round ${round}" >&2
      return 1
    }
    printf '\n<!-- loop-driver round %s edit -->\n' "$round" >> "$tasks"
  fi

  ( cd "${LOOP_FIXTURE_ROOT}" && bash "$script" "${precheck_args[@]}" ) >/dev/null || return 1

  local round_dir="${LOOP_FIXTURE_ROOT}/reports/task-review/${feature}/attempt-${attempt}/round-${round}"
  [[ -f "${round_dir}/precheck-result.json" ]] || {
    echo "drive_review_round: precheck-result.json missing after a successful precheck run" >&2
    return 1
  }

  local manifest_a manifest_b
  manifest_a="$(_loop_task_manifest_a "$round_dir" "$feature")" || return 1
  _loop_reserve_review_context task task-reviewer-a "$feature" "$manifest_a" || return 1
  _loop_emit_task_round_a "$round_dir" "$severity" || return 1

  manifest_b="$(_loop_task_manifest_b "$round_dir" "$feature")" || return 1
  _loop_reserve_review_context task task-reviewer-b "$feature" "$manifest_b" || return 1
  _loop_emit_task_round_b_contract "$round_dir" "$verdict" "$severity" || return 1

  return 0
}

# ---------------------------------------------------------------------------
# domain-review round emission (not feature-scoped; operates on the
# fixture's single domain/ tree synthesized by _loop_fixture_init_domain)
# ---------------------------------------------------------------------------
_loop_emit_domain_round_a() {
  local round_dir="$1" severity="$2"
  local round a_verdict a_result a_fails a_passes check_severity
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
  case "$severity" in
    none)     a_verdict="PASS";        a_result="PASS"; a_fails=0; a_passes=6; check_severity="Minor" ;;
    Critical) a_verdict="BLOCKED";     a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Critical" ;;
    Major)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Major" ;;
    Minor)    a_verdict="NEEDS_WORK";  a_result="FAIL"; a_fails=1; a_passes=5; check_severity="Minor" ;;
    *) echo "_loop_emit_domain_round_a: unknown severity: ${severity}" >&2; return 1 ;;
  esac

  jq -n --argjson attempt 1 --argjson round "$round" \
    --argjson fail_count "$a_fails" --argjson pass_count "$a_passes" '
    ["MODEL-CONSISTENCY","UBIQUITOUS-LANGUAGE","CONTEXT-BOUNDARY","AGGREGATE-INTEGRITY","EVENT-COVERAGE","C4-ALIGNMENT"] as $ids |
    {schema:"integrated-summary/v1",attempt:$attempt,round:$round,
     reviewer_a_check_ids:$ids,
     reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}' \
    > "${round_dir}/integrated-summary.json" || return 1

  local context_path precheck_path calibration_path
  local context_sha precheck_sha calibration_sha
  context_path="${LOOP_FIXTURE_ROOT}/domain/context-map.md"
  precheck_path="${round_dir}/precheck-result.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-domain/references/domain-review-calibration.md"
  context_sha="$(_loop_sha256 "$context_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"

  jq -n --arg verdict "$a_verdict" --arg result "$a_result" --arg severity "$check_severity" \
    --arg context "$context_path" --arg context_sha "$context_sha" \
    --arg precheck "$precheck_path" --arg precheck_sha "$precheck_sha" \
    --arg calibration "$calibration_path" --arg calibration_sha "$calibration_sha" '
    ["MODEL-CONSISTENCY","UBIQUITOUS-LANGUAGE","CONTEXT-BOUNDARY","AGGREGATE-INTEGRITY","EVENT-COVERAGE","C4-ALIGNMENT"] as $ids |
    {schema:"domain-reviewer-a/v1",stage:"domain",role:"domain-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",
     allowed_input_manifest:[
       {path:$context,sha256:$context_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}
     ],
     verdict:$verdict,
     checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}' \
    > "${round_dir}/reviewer-a.json" || return 1

  return 0
}

_loop_emit_domain_round_b_contract() {
  local round_dir="$1" verdict="$2" severity="$3"
  local round critical major minor
  round="$(jq -r .round "${round_dir}/precheck-result.json" | tr -d '\r')" || return 1
  case "$severity" in
    none)     critical=0; major=0; minor=0 ;;
    Critical) critical=1; major=0; minor=0 ;;
    Major)    critical=0; major=1; minor=0 ;;
    Minor)    critical=0; major=0; minor=1 ;;
    *) echo "_loop_emit_domain_round_b_contract: unknown severity: ${severity}" >&2; return 1 ;;
  esac
  local a_verdict
  if [[ "$critical" -gt 0 ]]; then a_verdict=BLOCKED
  elif [[ "$((major + minor))" -gt 0 ]]; then a_verdict=NEEDS_WORK
  else a_verdict=PASS; fi

  local context_path precheck_path calibration_path summary_path
  local context_sha precheck_sha calibration_sha summary_sha
  context_path="${LOOP_FIXTURE_ROOT}/domain/context-map.md"
  precheck_path="${round_dir}/precheck-result.json"
  calibration_path="${LOOP_FIXTURE_ROOT}/plugins/sdd-domain/references/domain-review-calibration.md"
  summary_path="${round_dir}/integrated-summary.json"
  context_sha="$(_loop_sha256 "$context_path")"
  precheck_sha="$(_loop_sha256 "$precheck_path")"
  calibration_sha="$(_loop_sha256 "$calibration_path")"
  summary_sha="$(_loop_sha256 "$summary_path")"

  jq -n --arg verdict "$verdict" --argjson round "$round" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" \
    --arg a_verdict "$a_verdict" '
    {schema:"integrated-verdict/v1",stage:"domain",attempt:1,round:$round,
     run_id:"fixture-orchestrator",verdict:$verdict,
     reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",
     findings_critical:$critical,findings_major:$major,findings_minor:$minor}' \
    > "${round_dir}/integrated-verdict.json" || return 1

  jq -n --arg context "$context_path" --arg context_sha "$context_sha" \
    --arg precheck "$precheck_path" --arg precheck_sha "$precheck_sha" \
    --arg calibration "$calibration_path" --arg calibration_sha "$calibration_sha" \
    --arg summary "$summary_path" --arg summary_sha "$summary_sha" '
    ["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids |
    {schema:"domain-reviewer-b/v1",stage:"domain",role:"domain-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",
     allowed_input_manifest:[
       {path:$context,sha256:$context_sha},{path:$precheck,sha256:$precheck_sha},
       {path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}
     ],
     verdict:"PASS",
     checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}' \
    > "${round_dir}/reviewer-b.json" || return 1

  local manifest_a_json manifest_b_json
  manifest_a_json="$(jq -r '.allowed_input_manifest' "${round_dir}/reviewer-a.json" | tr -d '\r')"
  manifest_b_json="$(jq -r '.allowed_input_manifest' "${round_dir}/reviewer-b.json" | tr -d '\r')"
  jq -n --arg verdict "$verdict" --argjson round "$round" \
    --argjson critical "$critical" --argjson major "$major" --argjson minor "$minor" \
    --arg a_verdict "$a_verdict" \
    --argjson manifest_a "$manifest_a_json" --argjson manifest_b "$manifest_b_json" '
    {schema:"domain-review-contract/v1",stage:"domain",attempt:1,round:$round,
     run_id:"fixture-orchestrator",verdict:$verdict,
     reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",
     findings_critical:$critical,findings_major:$major,findings_minor:$minor,
     reviewers:[
       {role:"domain-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest_a},
       {role:"domain-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest_b}
     ]}' \
    > "${round_dir}/domain-review-contract.json" || return 1

  return 0
}

_loop_domain_manifest_a() {
  local round_dir="$1" round_rel
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  _loop_manifest_array \
    "domain/context-map.md" "plugins/sdd-domain/references/domain-review-calibration.md" \
    "${round_rel}/precheck-result.json"
}
_loop_domain_manifest_b() {
  local round_dir="$1" round_rel
  round_rel="${round_dir#"${LOOP_FIXTURE_ROOT}"/}"
  _loop_manifest_array \
    "domain/context-map.md" "plugins/sdd-domain/references/domain-review-calibration.md" \
    "${round_rel}/precheck-result.json" "${round_rel}/integrated-summary.json"
}

_loop_drive_domain_round() {
  local attempt="$1" round="$2" verdict="$3" severity="$4"
  local script_rel script story_md precheck_args
  script_rel="$(_loop_driver_script domain)" || return 1
  [[ -n "$script_rel" ]] || { echo "drive_review_round: domain-review driver script not registered in the inventory" >&2; return 1; }
  script="${LOOP_FIXTURE_ROOT}/${script_rel}"
  [[ -f "$script" ]] || { echo "drive_review_round: precheck script missing at ${script}" >&2; return 1; }

  story_md="${LOOP_FIXTURE_ROOT}/domain/domain-story.md"
  precheck_args=("$attempt" "$round")
  if [[ "$round" -gt 1 ]]; then
    local prior_dir="${LOOP_FIXTURE_ROOT}/reports/domain-review/attempt-${attempt}/round-$((round - 1))"
    assert_prior_round_complete domain "$prior_dir" || {
      echo "drive_review_round: round-$((round - 1)) output set is incomplete on disk; refusing to start round ${round}" >&2
      return 1
    }
    printf '\n<!-- loop-driver round %s edit -->\n' "$round" >> "$story_md"
    precheck_args+=("--edit-summary=round-${round}-edit")
  fi

  ( cd "${LOOP_FIXTURE_ROOT}" && bash "$script" "${precheck_args[@]}" ) >/dev/null || return 1

  local round_dir="${LOOP_FIXTURE_ROOT}/reports/domain-review/attempt-${attempt}/round-${round}"
  [[ -f "${round_dir}/precheck-result.json" ]] || {
    echo "drive_review_round: precheck-result.json missing after a successful precheck run" >&2
    return 1
  }

  local manifest_a manifest_b
  manifest_a="$(_loop_domain_manifest_a "$round_dir")" || return 1
  _loop_reserve_review_context domain domain-reviewer-a "loop-driver-domain" "$manifest_a" || return 1
  _loop_emit_domain_round_a "$round_dir" "$severity" || return 1

  manifest_b="$(_loop_domain_manifest_b "$round_dir")" || return 1
  _loop_reserve_review_context domain domain-reviewer-b "loop-driver-domain" "$manifest_b" || return 1
  _loop_emit_domain_round_b_contract "$round_dir" "$verdict" "$severity" || return 1

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
    impl) _loop_drive_impl_round "$attempt" "$round" "$verdict" "$severity" ;;
    task) _loop_drive_task_round "$attempt" "$round" "$verdict" "$severity" ;;
    domain) _loop_drive_domain_round "$attempt" "$round" "$verdict" "$severity" ;;
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
    schema="$(jq -r '.schema? // empty' "$f" 2>/dev/null | tr -d '\r')" || return 1
    [[ -n "$schema" ]] || return 1
    found="$(printf '%s' "$known_json" | jq -r --arg s "$schema" 'index($s) != null' | tr -d '\r')"
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
  expected="$(jq -r --arg id "$loop_id" '.loops[] | select(.id == $id) | .terminal.state // empty' "$LOOP_INVENTORY_PATH" | tr -d '\r')" || return 1
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
