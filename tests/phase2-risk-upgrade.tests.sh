#!/usr/bin/env bash
# TEST-007 through TEST-009: deterministic risk-policy parity and workflow conformance.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
STAGE="${PHASE2_HUMAN_COPY_ROOT:-$ROOT/specs/epic-136-phase2-gates/human-copy}"
CHECK_SH="${CHECK_RISK_SH:-$STAGE/plugins/sdd-lite/scripts/check-risk-upgrade.sh}"
CHECK_PS1="${CHECK_RISK_PS1:-$STAGE/plugins/sdd-lite/scripts/check-risk-upgrade.ps1}"
POLICY="${RISK_POLICY:-$STAGE/plugins/sdd-lite/references/risk-upgrade-policy.md}"
LITE_SKILL="${LITE_SPEC_SKILL:-$STAGE/plugins/sdd-lite/skills/lite-spec/SKILL.md}"
SHIP_SKILL="${SHIP_SKILL:-$STAGE/plugins/sdd-ship/skills/ship/SKILL.md}"
POWERSHELL="${POWERSHELL_EXE:-powershell.exe}"

passed=0
failed=0
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/phase2-risk-upgrade.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

pass() {
  printf 'ok: %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failed=$((failed + 1))
}

run_checker() {
  local checker_kind="$1"
  local input_path="$2"
  local output_file="$temp_dir/${checker_kind}.out"
  local status

  set +e
  if [[ "$checker_kind" == 'sh' ]]; then
    bash "$CHECK_SH" "$input_path" >"$output_file" 2>&1
  else
    local windows_checker windows_input
    windows_checker="$(cygpath -w "$CHECK_PS1")"
    windows_input="$input_path"
    if [[ -e "$input_path" ]]; then
      windows_input="$(cygpath -w "$input_path")"
    fi
    "$POWERSHELL" -NoProfile -ExecutionPolicy Bypass -File "$windows_checker" -Path "$windows_input" >"$output_file" 2>&1
  fi
  status=$?
  set -e
  CHECKER_OUTPUT="$(tr -d '\r' <"$output_file")"
  CHECKER_STATUS="$status"
}

run_checker_without_path() {
  local checker_kind="$1"
  local output_file="$temp_dir/${checker_kind}.out"
  local status

  set +e
  if [[ "$checker_kind" == 'sh' ]]; then
    bash "$CHECK_SH" >"$output_file" 2>&1
  else
    local windows_checker
    windows_checker="$(cygpath -w "$CHECK_PS1")"
    "$POWERSHELL" -NoProfile -ExecutionPolicy Bypass -File "$windows_checker" >"$output_file" 2>&1
  fi
  status=$?
  set -e
  CHECKER_OUTPUT="$(tr -d '\r' <"$output_file")"
  CHECKER_STATUS="$status"
}

assert_case() {
  local label="$1"
  local contents="$2"
  local expected_status="$3"
  local expected_output="$4"
  local input_path="$temp_dir/input.txt"

  printf '%s' "$contents" >"$input_path"
  run_checker sh "$input_path"
  local sh_status="$CHECKER_STATUS"
  local sh_output="$CHECKER_OUTPUT"
  run_checker ps1 "$input_path"
  local ps_status="$CHECKER_STATUS"
  local ps_output="$CHECKER_OUTPUT"

  if [[ "$sh_status" == "$expected_status" && "$ps_status" == "$expected_status" && "$sh_output" == "$expected_output" && "$ps_output" == "$expected_output" ]]; then
    pass "$label"
  else
    fail "$label expected=[$expected_status:$expected_output] sh=[$sh_status:$sh_output] ps1=[$ps_status:$ps_output]"
  fi
}

assert_unavailable_case() {
  local label="$1"
  local input_path="$2"
  local expected_output='risk-upgrade: input unavailable'

  run_checker sh "$input_path"
  local sh_status="$CHECKER_STATUS"
  local sh_output="$CHECKER_OUTPUT"
  run_checker ps1 "$input_path"
  local ps_status="$CHECKER_STATUS"
  local ps_output="$CHECKER_OUTPUT"

  if [[ "$sh_status" == '2' && "$ps_status" == '2' && "$sh_output" == "$expected_output" && "$ps_output" == "$expected_output" ]]; then
    pass "$label"
  else
    fail "$label expected=[2:$expected_output] sh=[$sh_status:$sh_output] ps1=[$ps_status:$ps_output]"
  fi
}

assert_unavailable_without_path() {
  local expected_output='risk-upgrade: input unavailable'

  run_checker_without_path sh
  local sh_status="$CHECKER_STATUS"
  local sh_output="$CHECKER_OUTPUT"
  run_checker_without_path ps1
  local ps_status="$CHECKER_STATUS"
  local ps_output="$CHECKER_OUTPUT"

  if [[ "$sh_status" == '2' && "$ps_status" == '2' && "$sh_output" == "$expected_output" && "$ps_output" == "$expected_output" ]]; then
    pass 'missing checker path fails closed'
  else
    fail "missing checker path expected=[2:$expected_output] sh=[$sh_status:$sh_output] ps1=[$ps_status:$ps_output]"
  fi
}

assert_cygpath_failure_unavailable() {
  local fake_bin="$temp_dir/cygpath-failure-bin"
  local input_path="$temp_dir/cygpath-failure-input.md"
  local output_file="$temp_dir/cygpath-failure.out"
  local expected_output='risk-upgrade: input unavailable'
  local status

  mkdir -p "$fake_bin"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "synthetic cygpath failure" >&2' 'exit 71' >"$fake_bin/cygpath"
  chmod +x "$fake_bin/cygpath"
  printf '%s' 'ordinary source text' >"$input_path"

  set +e
  PATH="$fake_bin:$PATH" bash "$CHECK_SH" "$input_path" >"$output_file" 2>&1
  status=$?
  set -e

  local output
  output="$(tr -d '\r' <"$output_file")"
  if [[ "$status" == '2' && "$output" == "$expected_output" ]]; then
    pass 'shell checker converts cygpath conversion failure to unavailable input'
  else
    fail "shell checker cygpath failure expected=[2:$expected_output] actual=[$status:$output]"
  fi
}

assert_file_contains() {
  local label="$1"
  local file_path="$2"
  local expected="$3"
  if [[ -f "$file_path" ]] && grep -Fq -- "$expected" "$file_path"; then
    pass "$label"
  else
    fail "$label missing [$expected] in $file_path"
  fi
}

assert_order() {
  local label="$1"
  local file_path="$2"
  local first="$3"
  local second="$4"
  if [[ -f "$file_path" ]]; then
    local first_line second_line
    first_line="$(grep -n -F -- "$first" "$file_path" | head -n 1 | cut -d: -f1 || true)"
    second_line="$(grep -n -F -- "$second" "$file_path" | head -n 1 | cut -d: -f1 || true)"
    if [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]]; then
      pass "$label"
      return
    fi
  fi
  fail "$label requires [$first] before [$second] in $file_path"
}

assert_case 'AUTH_BOUNDARY is first and all triggers preserve matrix order' \
  'Authorization with an access token, MCP, third-party APIs, secret, and GitHub Actions' \
  10 'full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY,TOKEN_CREDENTIAL,MCP,EXTERNAL_API,SECRET,GITHUB_ACTIONS'
assert_case 'authentication and authorization vocabulary forces the auth boundary' \
  'auth authentication authorization oauth oidc' \
  10 'full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY'
assert_case 'token, credential, password, and private-key vocabulary forces full' \
  'access token credentials passwords private keys' \
  10 'full-required: TOKEN_CREDENTIAL; triggers=TOKEN_CREDENTIAL'
assert_case 'MCP vocabulary forces full' \
  'MCP integration' \
  10 'full-required: MCP; triggers=MCP'
assert_case 'external and third-party API vocabulary forces full' \
  'external APIs and third-party API' \
  10 'full-required: EXTERNAL_API; triggers=EXTERNAL_API'
assert_case 'secret vocabulary forces full' \
  'secrets rotation' \
  10 'full-required: SECRET; triggers=SECRET'
assert_case 'GitHub Actions vocabulary forces full' \
  'GitHub Actions workflow' \
  10 'full-required: GITHUB_ACTIONS; triggers=GITHUB_ACTIONS'
assert_case 'hyphen and non-ASCII token boundaries retain token escalation' \
  'token-value design-token token値' \
  10 'full-required: TOKEN_CREDENTIAL; triggers=TOKEN_CREDENTIAL'
assert_case 'design-token and API-design exclusions remain lite eligible' \
  'design tokens API design author oauthless mcpish secretion token_value' \
  0 'lite-eligible'
assert_case 'design-token exclusion accepts every token boundary class' \
  'design token/design tokens@design token"design tokens|design token蛟､' \
  0 'lite-eligible'
assert_case 'non-ASCII is a boundary without becoming unavailable' \
  '日本語 token値' \
  10 'full-required: TOKEN_CREDENTIAL; triggers=TOKEN_CREDENTIAL'
assert_case 'ordinary valid non-ASCII text is lite eligible' \
  '日本語だけの通常の説明' \
  0 'lite-eligible'

printf 'invalid\303\050' >"$temp_dir/invalid-utf8.txt"
assert_unavailable_case 'invalid UTF-8 fails closed' "$temp_dir/invalid-utf8.txt"
printf 'valid\000nul' >"$temp_dir/nul.txt"
assert_unavailable_case 'NUL input fails closed' "$temp_dir/nul.txt"
assert_unavailable_case 'opaque URL input fails closed before a lite artifact exists' 'https://example.invalid/opaque-source'
assert_unavailable_case 'missing ship task or requirements input fails closed' "$temp_dir/missing-input.md"
assert_unavailable_without_path
assert_cygpath_failure_unavailable

assert_file_contains 'policy candidate records the ordered trigger contract' "$POLICY" 'AUTH_BOUNDARY'
assert_file_contains 'policy candidate records the full override and unavailable-input rules' "$POLICY" 'does not invoke the scan'
assert_file_contains 'lite-spec candidate invokes the staged checker' "$LITE_SKILL" 'check-risk-upgrade.sh'
assert_file_contains 'lite-spec candidate stops without writes on unavailable input' "$LITE_SKILL" 'risk-upgrade: input unavailable'
assert_order 'lite-spec risk gate runs before its artifact-writing process' "$LITE_SKILL" '## Risk-Upgrade Gate' '## Process'
assert_file_contains 'ship candidate keeps the --full scan bypass' "$SHIP_SKILL" '[sdd-ship] Track: full (--full override)'
assert_file_contains 'ship candidate documents that --full bypasses the scan' "$SHIP_SKILL" '`--full` is the only scan bypass'
assert_file_contains 'ship candidate recognizes risk-match full precedence' "$SHIP_SKILL" 'full-required:'
assert_file_contains 'ship candidate stops for unavailable risk input' "$SHIP_SKILL" 'risk-upgrade: input unavailable'
assert_file_contains 'ship candidate requires both the task block and requirements' "$SHIP_SKILL" 'inputs are mandatory'
assert_file_contains 'ship risk-hit without full artifacts stops with a bootstrap full-track diagnostic' "$SHIP_SKILL" 'If either is absent, stop before task start and print `[sdd-ship] Full-track artifacts unavailable. Run /sdd-bootstrap:bootstrap for the full track.`'
assert_order 'ship keeps the --full override before the risk scan' "$SHIP_SKILL" '[sdd-ship] Track: full (--full override)' 'Risk-upgrade scan'
assert_order 'ship evaluates risk before the --lite selection branch' "$SHIP_SKILL" 'Risk-upgrade scan' '`--lite` flag present'
assert_order 'ship evaluates risk before the profile selection branch' "$SHIP_SKILL" 'Risk-upgrade scan' 'spec_profile: lite'
assert_order 'ship evaluates risk before the default selection branch' "$SHIP_SKILL" 'Risk-upgrade scan' '4. Default'

printf 'phase2-risk-upgrade.tests.sh: %d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
