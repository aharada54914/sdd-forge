#!/usr/bin/env bash
# simulate-lite-gate-step2.sh (epic-194-a6-lite-integration, T-004 test
# fixture, REQ-003/REQ-004)
#
# Reference simulator of lite-gate/SKILL.md's new Step 2a (full_upgrade_
# required backstop) and Step 2b (Registry-sourced check execution via the
# command-discovery contract), used because the real SKILL.md is
# agent-facing prose, not executable code -- this simulator implements the
# identical documented algorithm so it can be exercised by fixtures. The
# schema-validation step is a minimal, clearly-synthetic stand-in for A4/A5's
# own validator (which does not exist in this repository yet, requirements.md
# Assumptions: no Capability Pack exists yet anywhere in this repository);
# production lite-gate calls that real validator and never reimplements it
# (Boundaries, SKILL.md).
#
# Usage (sourced, not executed): source this file, then call
#   simulate_lite_gate_step2 <summary-path-or-empty> <capability-enforcement: none|advisory|required> <repo-root>
# Sets globals: SIM_VERDICT (PASS|FAIL), SIM_REASON, SIM_RAN_CHECKS (space-
# separated list of check-ids actually "run" in this simulated pass).

set -u

_CHECK_ID_GRAMMAR='^[a-z0-9][a-z0-9-]*$'
_BASELINE_CHECKS="placeholder lint typecheck build test"

_sim_is_baseline() {
  local id="$1" b
  for b in $_BASELINE_CHECKS; do
    [ "$id" = "$b" ] && return 0
  done
  return 1
}

_sim_grammar_ok() {
  printf '%s' "$1" | grep -Eq "$_CHECK_ID_GRAMMAR"
}

# Minimal, clearly-synthetic stand-in schema check (A4's own frozen shape,
# investigation.md INV-005): schema/feature/track/capabilities/
# required_lite_checks/full_upgrade_required all present, correct types.
# NOT a reimplementation of A4/A5's real validator (which does not exist in
# this repository yet) -- production lite-gate calls that real validator.
_sim_validate_summary_schema() {
  local path="$1"
  ruby -ryaml -rjson -e '
    begin
      data = YAML.load_file(ARGV[0])
      required = %w[schema feature track capabilities required_lite_checks full_upgrade_required]
      missing = required.reject { |k| data.is_a?(Hash) && data.key?(k) }
      raise "missing: " + missing.join(",") unless missing.empty?
      raise "schema must be sdd-capability-summary/v1" unless data["schema"] == "sdd-capability-summary/v1"
      raise "track must be lite" unless data["track"] == "lite"
      raise "capabilities must be an array" unless data["capabilities"].is_a?(Array)
      raise "required_lite_checks must be an array" unless data["required_lite_checks"].is_a?(Array)
      raise "full_upgrade_required must be boolean" unless [true, false].include?(data["full_upgrade_required"])
      exit 0
    rescue => e
      warn e.message
      exit 1
    end
  ' "$path" 2>/dev/null
}

_sim_summary_field() {
  local path="$1" field="$2"
  ruby -ryaml -e '
    data = YAML.load_file(ARGV[0])
    value = data[ARGV[1]]
    if value.is_a?(Array)
      puts value.join("\n")
    else
      puts value.to_s
    end
  ' "$path" "$field" 2>/dev/null
}

# Command-discovery contract (Blocker [B7], NEW-01). Echoes "npm:<id>",
# "scripts:<id>", or "unmapped".
_sim_discover_command() {
  local id="$1" root="$2"
  if [ -f "${root}/package.json" ]; then
    if ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); exit((data["scripts"] || {}).key?(ARGV[1]) ? 0 : 1)' "${root}/package.json" "$id" 2>/dev/null; then
      echo "npm:${id}"
      return 0
    fi
  fi
  local sh_path="${root}/scripts/${id}.sh"
  local ps1_path="${root}/scripts/${id}.ps1"
  if [ -e "$sh_path" ] && [ -e "$ps1_path" ]; then
    # Regular-file-only, and canonical path must stay under scripts/.
    local scripts_canon sh_canon ps1_canon
    scripts_canon="$(cd "${root}/scripts" 2>/dev/null && pwd -P)" || { echo "unmapped"; return 0; }
    if [ -L "$sh_path" ] || [ -L "$ps1_path" ]; then echo "unmapped"; return 0; fi
    if [ ! -f "$sh_path" ] || [ ! -f "$ps1_path" ]; then echo "unmapped"; return 0; fi
    sh_canon="$(cd "$(dirname "$sh_path")" 2>/dev/null && pwd -P)/$(basename "$sh_path")"
    ps1_canon="$(cd "$(dirname "$ps1_path")" 2>/dev/null && pwd -P)/$(basename "$ps1_path")"
    # These two prefix-containment checks are currently unreachable by any
    # fixture in this suite (quality-gate NEEDS_WORK cycle 1, Minor finding):
    # id already passed the step-0 grammar (^[a-z0-9][a-z0-9-]*$, no "/" or
    # ".."), and the symlink/regular-file checks above already reject any
    # leaf-level escape, so sh_canon/ps1_canon can never actually land outside
    # scripts_canon given today's grammar. Retained anyway as defense-in-depth
    # matching SKILL.md:112's own documented containment rule (a distinct
    # rule from the symlink/regular-file rule, stated as its own bullet) --
    # if the grammar is ever relaxed to permit more characters, this is the
    # backstop that keeps command-discovery bounded to scripts/. Do not
    # remove; the symlink checks above are a different, load-bearing rule.
    case "$sh_canon" in "${scripts_canon}"/*) : ;; *) echo "unmapped"; return 0 ;; esac
    case "$ps1_canon" in "${scripts_canon}"/*) : ;; *) echo "unmapped"; return 0 ;; esac
    echo "scripts:${id}"
    return 0
  fi
  echo "unmapped"
  return 0
}

simulate_lite_gate_step2() {
  local summary_path="$1" enforcement="$2" repo_root="$3"
  SIM_VERDICT="PASS"
  SIM_REASON=""
  SIM_RAN_CHECKS=""
  local required_checks=""

  if [ "$enforcement" = "none" ]; then
    required_checks=""
  else
    if [ -z "$summary_path" ] || [ ! -f "$summary_path" ]; then
      SIM_VERDICT="FAIL"
      SIM_REASON="capability-summary.yaml missing under active capability_enforcement"
      return 0
    fi
    if ! _sim_validate_summary_schema "$summary_path"; then
      SIM_VERDICT="FAIL"
      SIM_REASON="capability-summary.yaml failed schema validation"
      return 0
    fi
    local full_upgrade
    full_upgrade="$(_sim_summary_field "$summary_path" full_upgrade_required)"
    if [ "$full_upgrade" = "true" ]; then
      SIM_VERDICT="FAIL"
      SIM_REASON="full_upgrade_required: true"
      return 0
    fi
    required_checks="$(_sim_summary_field "$summary_path" required_lite_checks)"
  fi

  local id resolved
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    if _sim_is_baseline "$id"; then
      continue
    fi
    if ! _sim_grammar_ok "$id"; then
      SIM_VERDICT="FAIL"
      SIM_REASON="${id}: check-id does not match the required ^[a-z0-9][a-z0-9-]*\$ grammar"
      return 0
    fi
    resolved="$(_sim_discover_command "$id" "$repo_root")"
    if [ "$resolved" = "unmapped" ]; then
      SIM_VERDICT="FAIL"
      SIM_REASON="${id}: required Lite check has no discoverable command"
      return 0
    fi
    SIM_RAN_CHECKS="${SIM_RAN_CHECKS} ${resolved}"
  done <<< "$required_checks"
  return 0
}
