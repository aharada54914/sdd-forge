#!/usr/bin/env bash
# Authenticate the selected Git inputs once; reports remain in the live checkout.
fixed_input_init() {
  fixed_source_map=''
  [[ -n "${fixed_input_record:-}${fixed_input_snapshot:-}" ]] || return 0
  [[ "$1" == true && -n "${fixed_input_record:-}" && -n "${fixed_input_snapshot:-}" ]] ||
    fail 'fixed inputs require --verify-inputs and both fixed input options'
  fixed_source_map=$(python3 "$repo_root/plugins/sdd-review-loop/scripts/fixed-review-inputs.py" source-map \
    --repo "$repo_root" --record "$fixed_input_record" --snapshot "$fixed_input_snapshot") ||
    fail 'fixed Git input verification failed'
}

fixed_input_path() {
  local relative="${1#"$repo_root/"}"
  if [[ -z "$fixed_source_map" || "$relative" == reports/* ]]; then
    printf '%s\n' "$1"
  else
    jq -er --arg p "$relative" '.sources[$p] // error("required source absent from fixed inventory: " + $p)' \
      <<< "$fixed_source_map" || fail "required source absent from fixed inventory: $relative"
  fi
}

fixed_input_options() {
  fixed_input_record='' fixed_input_snapshot=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fixed-input-record|--fixed-input-snapshot)
        [[ $# -ge 2 && -n "$2" ]] || fail "missing value: $1"
        if [[ "$1" == --fixed-input-record ]]; then fixed_input_record=$2; else fixed_input_snapshot=$2; fi
        shift 2 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
  local verify=false
  [[ "$MODE" == --verify-inputs ]] && verify=true
  fixed_input_init "$verify"
}
