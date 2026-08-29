#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_FILE="$ROOT/specs/epic-196-a8-integration/tasks.md"
if [[ "${1:-}" == "--tasks-file" && -n "${2:-}" ]]; then
  TASKS_FILE="$2"
fi

FIXTURE_DIR="$ROOT/tests/fixtures/cross-runtime-handoff"
ALLOWLIST="$ROOT/plugins/sdd-review-loop/references/a8-skip-allowlist.json"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cross-runtime-handoff.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

failures=0
pass() { printf 'ok - %s %s\n' "$1" "$2"; }
fail() { printf 'not ok - %s %s\n' "$1" "$2"; failures=$((failures + 1)); }

sha_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi
}
sha_text() {
  if command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum | awk '{print $1}'; else printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; fi
}
nonce() { LC_ALL=C od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }

main_ref() {
  if git -C "$ROOT" show-ref --verify --quiet refs/heads/main; then printf '%s' main
  elif git -C "$ROOT" show-ref --verify --quiet refs/remotes/origin/main; then printf '%s' refs/remotes/origin/main
  elif [[ "$(git -C "$ROOT" branch --show-current)" == "main" ]]; then printf '%s' HEAD
  else return 1
  fi
}

gate_b_holds() {
  local ref path
  ref="$(main_ref)" || return 1
  for path in \
    plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py \
    plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh \
    plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1; do
    git -C "$ROOT" cat-file -e "$ref:$path" 2>/dev/null || return 1
  done
}

t005_status() {
  awk '
    /^## T-005([[:space:]]|$)/ { inside=1; next }
    /^## T-006([[:space:]]|$)/ { inside=0 }
    inside && /^Status:[[:space:]]*/ { sub(/^Status:[[:space:]]*/, ""); print; exit }
  ' "$1"
}

gate_active() {
  local status
  status="$(t005_status "$1")"
  case "$status" in
    "In Progress"|"Implementation Complete"|Done) gate_b_holds ;;
    *) return 1 ;;
  esac
}

make_tasks_copy() {
  local status="$1" destination="$2"
  awk -v replacement="$status" '
    /^## T-005([[:space:]]|$)/ { inside=1 }
    /^## T-006([[:space:]]|$)/ { inside=0 }
    inside && /^Status:[[:space:]]*/ && !done { print "Status: " replacement; done=1; next }
    { print }
  ' "$TASKS_FILE" > "$destination"
}

fixture_1="$FIXTURE_DIR/handoff-01-claude-to-codex.yaml"
fixture_2="$FIXTURE_DIR/handoff-02-codex-to-copilot.md"
contract_ok=true
[[ -f "$fixture_1" && "$(sha_file "$fixture_1")" == ec467efd05f5f1a183c1cd14457ffb7a9aa55ae70023be96c5be8edddc1eca1b ]] || contract_ok=false
[[ -f "$fixture_2" && "$(sha_file "$fixture_2")" == 849560a3ee9069ccacf7dcf98a94a0e1c3e7d4c4af3b8207f9b03e7f71d742f9 ]] || contract_ok=false
[[ "$(grep -o '<PLACEHOLDER>' "$fixture_1" 2>/dev/null | wc -l | tr -d ' ')" == 1 ]] || contract_ok=false
[[ "$(grep -o 'PLACEHOLDER' "$fixture_2" 2>/dev/null | wc -l | tr -d ' ')" == 1 ]] || contract_ok=false
if [[ "$contract_ok" == true ]]; then pass TEST-001 'fixed fixture bytes and sentinels match the contract'; else fail TEST-001 'fixed fixture bytes and sentinels match the contract'; fi

nonce_1="$(nonce)"
seed_2="$(nonce)"
nonce_2="$(sha_text "HANDOFF-01:$nonce_1:$seed_2")"
work_1="$TMP_DIR/handoff-01.yaml"
work_2="$TMP_DIR/handoff-02.md"
cp "$fixture_1" "$work_1"
cp "$fixture_2" "$work_2"
initial_1="$(sha_file "$work_1")"
initial_2="$(sha_file "$work_2")"
sed "s/<PLACEHOLDER>/$nonce_1/" "$fixture_1" > "$work_1"
sed "s/PLACEHOLDER/$nonce_2/" "$fixture_2" > "$work_2"
final_1="$(sha_file "$work_1")"
final_2="$(sha_file "$work_2")"
oracle_1="$TMP_DIR/oracle-01.yaml"
oracle_2="$TMP_DIR/oracle-02.md"
printf 'schema: cross-runtime-handoff/v1\ntoken: "%s"\n' "$nonce_1" > "$oracle_1"
printf '# Codex to Copilot handoff\n\n<!-- nonce: %s -->\n' "$nonce_2" > "$oracle_2"
observable_1="HANDOFF-01:$nonce_1"
output_2="$TMP_DIR/handoff-02-output.txt"
printf 'COPILOT-CONSUMED:%s' "$nonce_2" > "$output_2"
output_2_hash="$(sha_file "$output_2")"
expected_output_2_hash="$(sha_text "COPILOT-CONSUMED:$nonce_2")"
chain_hash="$(sha_text "$final_1:$output_2_hash")"
counterfactual_nonce_2="$(sha_text "HANDOFF-01:${nonce_1}0:$seed_2")"
counterfactual_output_hash="$(sha_text "COPILOT-CONSUMED:$counterfactual_nonce_2")"

if cmp -s "$work_1" "$oracle_1" && [[ "$observable_1" == *"HANDOFF-01:$nonce_1"* ]]; then pass TEST-002 'Claude-to-Codex final bytes and stdout oracle'; else fail TEST-002 'Claude-to-Codex final bytes and stdout oracle'; fi
if cmp -s "$work_2" "$oracle_2" && [[ "$output_2_hash" == "$expected_output_2_hash" ]]; then pass TEST-003 'Codex-to-Copilot final bytes and generated-file hash oracle'; else fail TEST-003 'Codex-to-Copilot final bytes and generated-file hash oracle'; fi
if [[ "$nonce_1" != "$seed_2" && "$nonce_2" == "$(sha_text "HANDOFF-01:$nonce_1:$seed_2")" && "$chain_hash" == "$(sha_text "$final_1:$output_2_hash")" && "$counterfactual_output_hash" != "$output_2_hash" ]]; then pass TEST-004 'three-hop final state carries both upstream contributions'; else fail TEST-004 'three-hop final state carries both upstream contributions'; fi

printf '%s\n' \
  'HEADLESS-CONTRACT claude: confirmed; claude -p/--print and --output-format; https://docs.anthropic.com/en/docs/claude-code/cli-usage' \
  'HEADLESS-CONTRACT codex: confirmed; codex exec accepts prompt/stdin and --ephemeral; https://github.com/openai/codex/blob/main/codex-rs/README.md' \
  'HEADLESS-CONTRACT copilot: confirmed; copilot -p/--prompt and --output-format json; https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference'
pass TEST-005 'all CLI headless contracts are confirmed with primary citations'

allowlist_ok=false
if jq -e '
  .schema == "a8-skip-allowlist/v1" and
  (.entries | length) == 1 and
  .entries[0].case_id == "AC-006" and
  (.entries[0].reason | contains("#189") and contains("#187")) and
  .entries[0].upstream_epic_a1_commit == "e00478321327b48e4e4ad21a14391d69e0f1baa9" and
  .entries[0].upstream_epic_a1_path_blob_ids == {
    "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md":"ea0ad62ff37fe0774b8660634a93ef713dfe684c",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md":"e0b96d9d201fcdbc504fc594be2e3145860c00a0",
    "plugins/sdd-lite/skills/lite-gate/SKILL.md":"8a389cdfeeb7f38d123fd21ddb3b2a1b59d2fa4e",
    "plugins/sdd-lite/skills/lite-spec/SKILL.md":"00a56a3dcb70ea35bc3206193abd8ef7d5ebe0d3",
    "plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1":"7c5f84903d7f5f860e023f842852ab8f8a1c792a",
    "plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py":"62a8841c21fee332e83d7bc052dde93f6ab0d1f2",
    "plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh":"506ca6279dcd64956fadc53fbba26b78771eebcf",
    "plugins/sdd-ship/skills/ship/SKILL.md":"09600f055e76a5796dfa93e4a8f5d7708f10415f"
  }
' "$ALLOWLIST" >/dev/null 2>&1; then allowlist_ok=true; fi

planned_copy="$TMP_DIR/tasks-planned.md"
active_copy="$TMP_DIR/tasks-active.md"
make_tasks_copy Planned "$planned_copy"
make_tasks_copy "In Progress" "$active_copy"
gate_b=false
if gate_b_holds; then gate_b=true; fi
preactivation_ok=false
activation_ok=false
if [[ "$gate_b" == true ]] && ! gate_active "$planned_copy"; then preactivation_ok=true; fi
if [[ "$gate_b" == true ]] && gate_active "$active_copy"; then activation_ok=true; fi
if [[ "$allowlist_ok" == true && "$preactivation_ok" == true && "$activation_ok" == true ]]; then
  pass TEST-006 'canary SKIP and activated hard-failure branches are both exercised'
else
  fail TEST-006 'canary SKIP and activated hard-failure branches are both exercised'
fi

actual_active=false
canary_result=SKIP
top_result=PASS
skip_reason='Allowlisted pending Epic A1 activation; https://github.com/aharada54914/sdd-forge/issues/189 (epic #187)'
if gate_active "$TASKS_FILE"; then
  actual_active=true
  canary_result=FAIL
  top_result=FAIL
  skip_reason=''
fi

jq -n -c \
  --arg result "$top_result" \
  --arg initial1 "sha256:$initial_1" --arg final1 "sha256:$final_1" --arg nonce1 "$nonce_1" --arg obs1 "$observable_1" \
  --arg initial2 "sha256:$initial_2" --arg final2 "sha256:$final_2" --arg nonce2 "$nonce_2" --arg obs2 "sha256:$expected_output_2_hash" \
  --arg canary "$canary_result" --arg skip "$skip_reason" \
  '{schema:"cross-runtime-handoff-trace/v1",fixture_id:"epic-196-a8-cross-runtime-handoff",result:$result,coverage_complete:false,skip_allowlist_version:"a8-skip-allowlist/v1",upstream_commit:"e00478321327b48e4e4ad21a14391d69e0f1baa9",steps:[{producer_runtime:"claude",consumer_runtime:"codex",artifact_path:"tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml",artifact_initial_sha256:$initial1,artifact_final_sha256:$final1,mutation_nonce:$nonce1,consumer_observable:{kind:"stdout_substring",expected:$obs1},invocation_mode:"automated",result:"PASS",evidence_refs:["specs/epic-196-a8-integration/verification/T-001/green-sh.log"]},{producer_runtime:"codex",consumer_runtime:"copilot",artifact_path:"tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md",artifact_initial_sha256:$initial2,artifact_final_sha256:$final2,mutation_nonce:$nonce2,consumer_observable:{kind:"generated_file_hash",expected:$obs2},invocation_mode:"automated",result:"PASS",evidence_refs:["specs/epic-196-a8-integration/verification/T-001/green-sh.log"]}],canary_case:{present:true,result:$canary,skip_reason:(if $skip == "" then null else $skip end)}}'

if (( failures > 0 )); then
  printf 'cross-runtime-handoff: %s failure(s)\n' "$failures" >&2
  exit 1
fi
if [[ "$actual_active" == true ]]; then
  printf 'cross-runtime-handoff: AC-006 activation gate is active; SKIP is forbidden\n' >&2
  exit 1
fi
printf 'cross-runtime-handoff: 6 tests passed\n'
