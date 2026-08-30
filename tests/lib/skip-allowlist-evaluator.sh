#!/usr/bin/env bash
set -u

skip_allowlist_sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'; else sha256sum | awk '{print $1}'; fi
}

skip_allowlist_branch() {
  local repo="$1" issue="$2" ref
  ref="$(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads refs/remotes |
    awk -v issue="$issue" '$0 ~ "epic-" issue "([^0-9]|$)" || $0 ~ "epic-" issue "/" { print; exit }')"
  [[ -n "$ref" ]] || return 1
  printf '%s\n' "$ref"
}

skip_allowlist_terminal() {
  local repo="$1" ref="$2" path="$3" value
  value="$(git -C "$repo" show "$ref:$path" 2>/dev/null |
    awk '/^(Spec-Review-Status|Impl-Review-Status): / { sub(/^[^:]+: /, ""); print; exit }')"
  [[ "$value" == Passed ]]
}

skip_allowlist_merged() {
  local manifest="$1" assertion="$2" epic="$3" repo="$4" main_ref="$5" issue branch source spec_dir
  issue="$(jq -er --arg ac "$assertion" --arg epic "$epic" '.[]|select(.assertion_id==$ac)|.dependencies[]|select(.epic==$epic)|.issue' "$manifest")" || return 2
  source="$(jq -er --arg ac "$assertion" --arg epic "$epic" '.[]|select(.assertion_id==$ac)|.dependencies[]|select(.epic==$epic)|.fingerprints[0].source' "$manifest")" || return 2
  spec_dir="${source%/*}"
  branch="$(skip_allowlist_branch "$repo" "$issue")" || return 1
  git -C "$repo" merge-base --is-ancestor "$branch" "$main_ref" 2>/dev/null || return 1
  skip_allowlist_terminal "$repo" "$main_ref" "$spec_dir/requirements.md" || return 1
  skip_allowlist_terminal "$repo" "$main_ref" "$spec_dir/design.md" || return 1
}

skip_allowlist_fingerprint_match() {
  local manifest="$1" assertion="$2" index="$3" repo="$4" main_ref="$5"
  local dep epic issue branch ref count fp source range expected start end actual
  dep="$(jq -cer --arg ac "$assertion" --argjson index "$index" '.[]|select(.assertion_id==$ac)|.dependencies[$index]' "$manifest")" || return 2
  epic="$(jq -r .epic <<<"$dep")"; issue="$(jq -r .issue <<<"$dep")"
  if skip_allowlist_merged "$manifest" "$assertion" "$epic" "$repo" "$main_ref"; then ref="$main_ref"; else ref="$(skip_allowlist_branch "$repo" "$issue")" || return 1; fi
  count="$(jq '.fingerprints|length' <<<"$dep")"
  for ((fp=0; fp<count; fp++)); do
    source="$(jq -r --argjson fp "$fp" '.fingerprints[$fp].source' <<<"$dep")"
    range="$(jq -r --argjson fp "$fp" '.fingerprints[$fp].line_range' <<<"$dep")"
    expected="$(jq -r --argjson fp "$fp" '.fingerprints[$fp].digest' <<<"$dep")"
    start="${range%-*}"; end="${range#*-}"
    actual="$(git -C "$repo" show "$ref:$source" 2>/dev/null | sed 's/\r$//' | sed -n "${start},${end}p" | awk 'NR>1{printf "\n"}{printf "%s",$0}' | skip_allowlist_sha256)" || return 1
    [[ "sha256:$actual" == "$expected" ]] || return 1
  done
}

skip_allowlist_condition() {
  local manifest="$1" assertion="$2" repo="$3" main_ref="$4" condition token result=0 op=OR value
  condition="$(jq -er --arg ac "$assertion" '.[]|select(.assertion_id==$ac)|.activation_condition' "$manifest")" || return 2
  read -r -a tokens <<<"$condition"
  [[ ${#tokens[@]} -gt 0 && $((${#tokens[@]} % 2)) -eq 1 ]] || return 2
  for ((i=0; i<${#tokens[@]}; i++)); do
    token="${tokens[$i]}"
    if ((i % 2)); then [[ "$token" == AND || "$token" == OR ]] || return 2; op="$token"; continue; fi
    value=1
    if [[ "$token" =~ ^merged\((A[0-9]+)\)$ ]]; then skip_allowlist_merged "$manifest" "$assertion" "${BASH_REMATCH[1]}" "$repo" "$main_ref" && value=0
    elif [[ "$token" =~ ^fingerprint_match\(([0-9]+)\)$ ]]; then skip_allowlist_fingerprint_match "$manifest" "$assertion" "${BASH_REMATCH[1]}" "$repo" "$main_ref" && value=0
    else return 2; fi
    if ((i == 0)); then result=$value
    elif [[ "$op" == AND ]]; then ((result == 0 && value == 0)) && result=0 || result=1
    else ((result == 0 || value == 0)) && result=0 || result=1; fi
  done
  return "$result"
}

skip_allowlist_line() {
  local manifest="$1" label="$2"; shift 2
  local assertion dep_text issue_text condition_text assertion_id
  dep_text=""; issue_text=""; condition_text=""
  for assertion_id in "$@"; do
    jq -e --arg ac "$assertion_id" '.[]|select(.assertion_id==$ac)' "$manifest" >/dev/null || return 2
    dep_text+="$(jq -r --arg ac "$assertion_id" '.[]|select(.assertion_id==$ac)|.dependencies[].epic' "$manifest")"$'\n'
    issue_text+="$(jq -r --arg ac "$assertion_id" '.[]|select(.assertion_id==$ac)|.dependencies[].issue' "$manifest")"$'\n'
    condition_text+="$(jq -r --arg ac "$assertion_id" '.[]|select(.assertion_id==$ac)|.activation_condition' "$manifest")"$'\n'
  done
  dep_text="$(printf '%s' "$dep_text" | sed '/^$/d' | sort -u | paste -sd+ -)"
  issue_text="$(printf '%s' "$issue_text" | sed '/^$/d' | sort -un | sed 's/^/#/' | paste -sd+ -)"
  condition_text="$(printf '%s' "$condition_text" | sed '/^$/d' | sort -u | paste -sd';' -)"
  printf 'SKIP: %s (Epic %s): blocked by issue %s until %s\n' "$label" "${dep_text//+/+Epic }" "$issue_text" "$condition_text"
}

skip_allowlist_audit() {
  local manifest="$1" output="$2" repo="$3" main_ref="$4" marker line ids assertion dep_count index epic failures=0 count=0
  marker='SK'; marker+='IP:'
  while IFS= read -r line; do
    [[ "$line" == *"$marker"* ]] || continue
    count=$((count + 1)); ids="$(grep -Eo 'AC-[0-9]{3}' <<<"$line" | sort -u || true)"
    if [[ -z "$ids" ]]; then printf 'ERROR: unrecognized skip-shaped line: %s\n' "$line" >&2; failures=$((failures + 1)); continue; fi
    while IFS= read -r assertion; do
      if ! jq -e --arg ac "$assertion" '.[]|select(.assertion_id==$ac)' "$manifest" >/dev/null; then printf 'ERROR: unrecognized allowlist assertion %s\n' "$assertion" >&2; failures=$((failures + 1)); continue; fi
      if skip_allowlist_condition "$manifest" "$assertion" "$repo" "$main_ref"; then printf 'ERROR: %s emitted after activation condition became true\n' "$assertion" >&2; failures=$((failures + 1)); fi
      dep_count="$(jq --arg ac "$assertion" '.[]|select(.assertion_id==$ac)|.dependencies|length' "$manifest")"
      for ((index=0; index<dep_count; index++)); do
        epic="$(jq -r --arg ac "$assertion" --argjson i "$index" '.[]|select(.assertion_id==$ac)|.dependencies[$i].epic' "$manifest")"
        if skip_allowlist_merged "$manifest" "$assertion" "$epic" "$repo" "$main_ref" && ! skip_allowlist_fingerprint_match "$manifest" "$assertion" "$index" "$repo" "$main_ref"; then printf 'ERROR: %s dependency %s fingerprint drift\n' "$assertion" "$epic" >&2; failures=$((failures + 1)); fi
      done
    done <<<"$ids"
  done <"$output"
  ((failures == 0)) || return 1
  printf 'audited %d allowlisted line%s\n' "$count" "$([[ $count -eq 1 ]] || printf s)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    merged) shift; skip_allowlist_merged "$@" ;;
    fingerprint-match) shift; skip_allowlist_fingerprint_match "$@" ;;
    condition) shift; skip_allowlist_condition "$@" ;;
    audit) shift; skip_allowlist_audit "$@" ;;
    line) shift; skip_allowlist_line "$@" ;;
    *) printf 'usage: %s {merged|fingerprint-match|condition|audit|line} ...\n' "$0" >&2; exit 2 ;;
  esac
fi
