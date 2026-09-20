#!/usr/bin/env bash
# Shared F1-F4 fixture-matrix builder for epic-195-a7-compatibility.
# Source this file from acceptance suites; it defines functions only and is
# intentionally not an independent tests/run-all.sh entry.

if [ "${_SDD_FIXTURE_MATRIX_BUILDER_SOURCED:-0}" = "1" ]; then
  return 0
fi
_SDD_FIXTURE_MATRIX_BUILDER_SOURCED=1

_FIXTURE_MATRIX_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
_FIXTURE_MATRIX_TEMP_ROOT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"

_fixture_matrix_error() {
  local message=$1
  printf 'build_fixture: %s\n' "$message" >&2
  return 2
}

_fixture_matrix_cleanup() {
  local cleanup_root=$1
  case "$cleanup_root" in
    "$_FIXTURE_MATRIX_TEMP_ROOT"/*) rm -rf -- "$cleanup_root" ;;
  esac
}

# build_fixture <project_context> <agents_marker> <capability_enforcement>
#               <valid_or_invalid> <track_flag>
#
# The selected track flag is intentionally not written into the fixture. It is
# an invocation-time input for the downstream workflow entrypoint. The returned
# stdout value is the fresh, physically normalized fixture root.
build_fixture() {
  local project_context agents_marker capability_enforcement
  local valid_or_invalid track_flag fixture_root schema_version

  if [ "$#" -ne 5 ]; then
    _fixture_matrix_error "expected 5 arguments, received $#"
    return 2
  fi

  project_context=$1
  agents_marker=$2
  capability_enforcement=$3
  valid_or_invalid=$4
  track_flag=$5

  case "$project_context" in
    absent|present) ;;
    *) _fixture_matrix_error "project_context must be absent or present"; return 2 ;;
  esac
  case "$agents_marker" in
    absent|present) ;;
    *) _fixture_matrix_error "agents_marker must be absent or present"; return 2 ;;
  esac
  case "$capability_enforcement" in
    disabled-legacy|advisory|required) ;;
    *) _fixture_matrix_error "capability_enforcement must be disabled-legacy, advisory, or required"; return 2 ;;
  esac
  case "$valid_or_invalid" in
    valid|PROJECT_CONTEXT_INVALID) ;;
    *) _fixture_matrix_error "valid_or_invalid must be valid or PROJECT_CONTEXT_INVALID"; return 2 ;;
  esac
  case "$track_flag" in
    none|--full|--lite) ;;
    *) _fixture_matrix_error "track_flag must be none, --full, or --lite"; return 2 ;;
  esac
  if [ "$project_context" = "present" ] && [ "$capability_enforcement" = "disabled-legacy" ]; then
    _fixture_matrix_error "present project context requires advisory or required enforcement"
    return 2
  fi

  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/sdd-fixture-matrix.XXXXXX")" || {
    _fixture_matrix_error "could not create a temporary directory"
    return 2
  }
  fixture_root="$(cd "$fixture_root" && pwd -P)" || {
    _fixture_matrix_error "could not physically normalize the temporary directory"
    return 2
  }

  case "$fixture_root" in
    "$_FIXTURE_MATRIX_REPO_ROOT"|"$_FIXTURE_MATRIX_REPO_ROOT"/*)
      rmdir -- "$fixture_root" 2>/dev/null || true
      _fixture_matrix_error "fixture root resolved inside the repository working tree"
      return 2
      ;;
  esac

  if [ "$agents_marker" = "present" ]; then
    if ! printf 'spec_profile: lite\n' > "$fixture_root/AGENTS.md"; then
      _fixture_matrix_cleanup "$fixture_root"
      _fixture_matrix_error "could not write AGENTS.md"
      return 2
    fi
  fi

  if [ "$project_context" = "present" ]; then
    if ! mkdir -p -- "$fixture_root/sdd"; then
      _fixture_matrix_cleanup "$fixture_root"
      _fixture_matrix_error "could not create the sdd directory"
      return 2
    fi
    schema_version="sdd-project-context/v1"
    if [ "$valid_or_invalid" = "PROJECT_CONTEXT_INVALID" ]; then
      schema_version="sdd-project-context/v0"
    fi
    if ! printf '%s\n' \
      "schema: $schema_version" \
      'workflow:' \
      '  spec_profile: full' \
      '  artifact_layout: legacy-seven-layer' \
      "  capability_enforcement: $capability_enforcement" \
      > "$fixture_root/sdd/project-context.yaml"; then
      _fixture_matrix_cleanup "$fixture_root"
      _fixture_matrix_error "could not write sdd/project-context.yaml"
      return 2
    fi
  fi

  printf '%s\n' "$fixture_root"
}
