#!/usr/bin/env bash
# Diagnostic launcher only. Raw host output is not an AC-004/AC-021 verdict.
# Usage: bash live-host-spy-candidate.sh F1|F3|F4|positive SCRATCH_REPO OUTPUT_DIR
set -euo pipefail

if [[ "$(basename "$0")" == resolve-project-context.sh ]]; then
  : "${A7_SPY_LOG:?A7_SPY_LOG is required}"
  : "${A7_REAL_DISPATCHER:?A7_REAL_DISPATCHER is required}"
  printf '%s\n' "$*" >> "$A7_SPY_LOG"
  exec "$A7_REAL_DISPATCHER" "$@"
fi

if [[ $# -ne 3 ]]; then
  printf 'usage: %s F1|F3|F4|positive SCRATCH_REPO OUTPUT_DIR\n' "$0" >&2
  exit 2
fi
case_name=$1
case "$case_name" in F1|F3|F4|positive) ;; *) printf 'invalid case\n' >&2; exit 2 ;; esac
scratch=$(cd "$2" && pwd -P)
out_dir=$(cd "$3" && pwd -P)
repo_root=$(cd "$(dirname "$0")/../../../.." && pwd -P)
case "$scratch" in "$repo_root"|"$repo_root"/*) printf 'scratch must be outside owner checkout\n' >&2; exit 2 ;; esac
case "$out_dir" in "$repo_root"|"$repo_root"/*) printf 'output must be outside owner checkout\n' >&2; exit 2 ;; esac
for artifact in "$out_dir/$case_name.structure.log" "$out_dir/$case_name.invocations.log" \
  "$out_dir/$case_name.claude-stream.jsonl" "$out_dir/$case_name.receipt.txt"; do
  [[ ! -e "$artifact" ]] || { printf 'output artifact exists; use a fresh output directory\n' >&2; exit 2; }
done
[[ -f "$scratch/AGENTS.md" && -f "$scratch/scripts/check-sdd-structure.sh" ]] || {
  printf 'scratch is not an SDD repository\n' >&2; exit 2;
}
[[ -d "$scratch/.git" || -f "$scratch/.git" ]] || {
  printf 'scratch lacks git identity\n' >&2; exit 2;
}
context="$scratch/sdd/project-context.yaml"
case "$case_name" in
  F1) [[ ! -e "$context" ]] || { printf 'F1 requires absent Context\n' >&2; exit 2; } ;;
  F3|F4) [[ -f "$context" ]] && rtk proxy rg -q 'schema: sdd-project-context/v0' "$context" || {
    printf '%s requires an invalid-v0 Context fixture\n' "$case_name" >&2; exit 2;
  } ;;
  positive) [[ -f "$context" ]] && rtk proxy rg -q 'schema: sdd-project-context/v1' "$context" || {
    printf 'positive requires a valid-v1 Context fixture\n' >&2; exit 2;
  } ;;
esac

rtk proxy bash "$scratch/scripts/check-sdd-structure.sh" > "$out_dir/$case_name.structure.log" 2>&1 || {
  printf 'scratch structure preflight failed; see recorded log\n' >&2; exit 3;
}
spy_dir=$(mktemp -d "${TMPDIR:-/tmp}/a7-host-spy.XXXXXX")
trap 'rm -f -- "$spy_dir/resolve-project-context.sh"; rmdir -- "$spy_dir"' EXIT
ln -s "$repo_root/specs/epic-195-a7-compatibility/verification/T-008/live-host-spy-candidate.sh" "$spy_dir/resolve-project-context.sh"
spy_log="$out_dir/$case_name.invocations.log"
raw_log="$out_dir/$case_name.claude-stream.jsonl"
real_dispatcher="$scratch/plugins/sdd-quality-loop/scripts/resolve-project-context.sh"
[[ -f "$real_dispatcher" && -x "$real_dispatcher" ]] || {
  printf 'real resolver dispatcher unavailable in isolated repository\n' >&2; exit 3;
}
: > "$spy_log"
prompt="/sdd-bootstrap:bootstrap feature --feature a7-spy-$case_name Synthetic, isolated capability-boundary regression probe. The user request is to verify the real host's Resolver invocation boundary. Each prerequisite command is for structure or hook-activation verification; state that purpose before invoking Bash. Do not use external issue text. Stop at the first required human answer; do not proceed into review gates."
set +e
(cd "$scratch" && PATH="$spy_dir:$PATH" A7_SPY_LOG="$spy_log" A7_REAL_DISPATCHER="$real_dispatcher" \
  rtk proxy claude --model sonnet \
  --plugin-dir "$scratch/plugins/sdd-bootstrap" \
  --plugin-dir "$scratch/plugins/sdd-quality-loop" \
  --print --verbose --output-format stream-json -p "$prompt") > "$raw_log" 2>&1
host_rc=$?
set -e
spy_count="$(wc -l < "$spy_log" | tr -d ' ')"
interception=not_observed
if [[ "$case_name" == positive && "$spy_count" -eq 1 ]] &&
  grep -Eq -- '(^|[[:space:]])--config([=[:space:]]|$)' "$spy_log" &&
  grep -Eq -- '(^|[[:space:]])--target-rev([=[:space:]]|$)' "$spy_log" &&
  grep -Eq -- '(^|[[:space:]])--feature([=[:space:]]|$)' "$spy_log"; then
  interception=path_spy_observed_once
fi
printf 'case=%s\nhost_exit=%s\nverdict=UNVERIFIED\ninterception=%s\nspy_invocations=%s\nraw=%s\n' \
  "$case_name" "$host_rc" "$interception" "$spy_count" "$raw_log" \
  > "$out_dir/$case_name.receipt.txt"
printf 'UNVERIFIED: inspect interception, hook activation, actual branch reached, tool trace, and host permission result in %s\n' "$raw_log"
exit 3
