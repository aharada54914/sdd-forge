#!/usr/bin/env bash
# Structural tests for T-001 turn-first model routing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_literal() {
  local file="$1"
  local text="$2"
  local message="$3"
  grep -Fq "$text" "$file" || fail "$message"
}

MATRIX="$ROOT/docs/agent-capability-matrix.md"
ADR="$ROOT/docs/adr/0003-turn-first-agent-routing.md"
POLICY="$ROOT/plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md"
INVESTIGATOR="$ROOT/plugins/sdd-bootstrap/agents/investigator.md"
COPILOT_INVESTIGATOR="$ROOT/plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md"
EVALUATOR="$ROOT/plugins/sdd-quality-loop/agents/evaluator.md"
REGISTRY="$ROOT/contracts/agent-model-capabilities.json"
REGISTRY_V2="$ROOT/contracts/agent-model-capabilities.v2.json"
SELECTOR_SH="$ROOT/plugins/sdd-implementation/scripts/select-agent-model.sh"
SELECTOR_PS="$ROOT/plugins/sdd-implementation/scripts/select-agent-model.ps1"
RESUME_SH="$ROOT/plugins/sdd-implementation/scripts/check-terminal-tier-resume.sh"
RESUME_PS="$ROOT/plugins/sdd-implementation/scripts/check-terminal-tier-resume.ps1"
BLOCKED_STATE_SCHEMA="$ROOT/contracts/terminal-tier-blocked-state.schema.json"
RISK_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-risk.sh"
RISK_PS="$ROOT/plugins/sdd-quality-loop/scripts/check-risk.ps1"

for file in "$MATRIX" "$ADR" "$POLICY" "$INVESTIGATOR" "$COPILOT_INVESTIGATOR" \
  "$EVALUATOR" "$REGISTRY" "$REGISTRY_V2" "$SELECTOR_SH" "$SELECTOR_PS" "$RESUME_SH" \
  "$RESUME_PS" "$BLOCKED_STATE_SCHEMA"; do
  [[ -f "$file" ]] || fail "missing required routing artifact: ${file#$ROOT/}"
done

for risk in low medium high critical; do
  assert_contains "$MATRIX" "^\\| ${risk} \\|" "matrix missing ${risk} risk row"
done
assert_literal "$MATRIX" "| low | 1 | 1 | 1 |" "low risk matrix row must be 1/1/1"
assert_literal "$MATRIX" "| medium | 2 | 1 | 1 |" "medium risk matrix row must be 2/1/1"
assert_literal "$MATRIX" "| high | 3 | 2 | 1 |" "high risk matrix row must be 3/2/1"
assert_literal "$MATRIX" "| critical | 3 | 2 | 1 |" "critical risk matrix row must be 3/2/1"

assert_literal "$MATRIX" "Expected iterations are optimized first, then the weakest sufficient tier, then token price." \
  "routing priority must put expected iterations before tier and token price"
assert_literal "$MATRIX" "estimated_cost_per_attempt_usd" "routing must use invocation-supplied cost estimate"
assert_literal "$MATRIX" "cost_estimate_timestamp" "routing must record cost estimate timestamp"
assert_literal "$MATRIX" "lexicographically smaller provider/model" "routing must define lexical final tie-break"

for failure in test lint typecheck build review-major review-critical; do
  assert_literal "$MATRIX" "\`$failure\`" "missing closed failure enum: $failure"
done
assert_literal "$MATRIX" "same classified failure occurs twice" "same failure recurrence must be required before escalation"
assert_literal "$MATRIX" "different failure classes do not accumulate" "different failure classes must not trigger escalation"
assert_literal "$MATRIX" "one-tier increase" "escalation must advance exactly one tier"
assert_literal "$MATRIX" "terminal-tier-recurrence" "strong recurrence must block with terminal-tier-recurrence"
assert_literal "$MATRIX" "check-terminal-tier-resume.sh" \
  "terminal-tier resume must use deterministic paired validation"
assert_literal "$MATRIX" "Deterministic parsing, validation, hashing, and state transitions use scripts rather than model routing." \
  "deterministic operations must be excluded from model routing"
assert_literal "$MATRIX" "model-tier-unavailable" \
  "routing must fail closed when no availability-checked model satisfies a required tier"
assert_literal "$MATRIX" "canonical tier does not change" \
  "same-tier substitution must preserve canonical tier identity"
assert_literal "$MATRIX" "high effort is the default" \
  "strong Codex routing must prefer high before xhigh"

assert_literal "$MATRIX" "| lightweight | Anthropic | Haiku |" "lightweight Anthropic mapping must be Haiku"
assert_literal "$MATRIX" "| standard | Anthropic | Sonnet |" "standard Anthropic mapping must be Sonnet"
assert_literal "$MATRIX" "| strong | Anthropic | Opus |" "strong Anthropic mapping must be Opus"
assert_literal "$MATRIX" '| lightweight | OpenAI/Codex | `gpt-5.1-codex-mini` | low |' \
  "lightweight Codex mapping must name gpt-5.1-codex-mini"
assert_literal "$MATRIX" '| standard | OpenAI/Codex | `gpt-5.1-codex` | medium |' \
  "standard Codex mapping must name gpt-5.1-codex"
assert_literal "$MATRIX" '| strong | OpenAI/Codex | `gpt-5.2-codex` (`gpt-5.1-codex-max` fallback) | high or xhigh |' \
  "strong Codex mapping must name gpt-5.2-codex and its fallback"

assert_literal "$MATRIX" '| sdd-investigator | lightweight | Anthropic Haiku | OpenAI/Codex `gpt-5.1-codex-mini`, effort low |' \
  "investigator must be lightweight/Haiku with Codex low equivalent"
assert_literal "$MATRIX" '| spec-reviewer-a/b | standard minimum | Anthropic Sonnet or stronger | OpenAI/Codex `gpt-5.1-codex`, effort medium or stronger |' \
  "spec reviewers must be at least standard/Sonnet"
assert_literal "$MATRIX" '| impl-reviewer-a/b | standard minimum | Anthropic Sonnet or stronger | OpenAI/Codex `gpt-5.1-codex`, effort medium or stronger |' \
  "implementation reviewers must be at least standard/Sonnet"
assert_literal "$MATRIX" '| task-reviewer-a/b | standard minimum | Anthropic Sonnet or stronger | OpenAI/Codex `gpt-5.1-codex`, effort medium or stronger |' \
  "task reviewers must be at least standard/Sonnet"
assert_literal "$MATRIX" '| sdd-evaluator | strong | Anthropic Opus | OpenAI/Codex `gpt-5.2-codex` (`gpt-5.1-codex-max` fallback), effort high or xhigh |' \
  "evaluator must be strong/Opus with Codex high/xhigh equivalent"

assert_contains "$INVESTIGATOR" '^model: haiku$' "Claude investigator must be downgraded to Haiku"
assert_literal "$COPILOT_INVESTIGATOR" "Model tier: lightweight" "Copilot investigator must document lightweight tier"
assert_contains "$EVALUATOR" '^model: opus$' "Claude evaluator must remain Opus"

assert_literal "$ADR" "Turn-first routing optimizes expected iteration count before token price." \
  "ADR must record turn-first routing decision"
assert_literal "$POLICY" "Apply the turn-first routing matrix before choosing an implementation model." \
  "delegation policy must require turn-first routing"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/fallback.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":false,"effort":"high"},
  {"name":"openai/gpt-5.1-codex-max","cost":"0.09","available":true,"effort":"high"}
]
JSON
cat > "$TMP/unavailable.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":false,"effort":"high"},
  {"name":"openai/gpt-5.1-codex-max","cost":"0.09","available":false,"effort":"high"}
]
JSON
cat > "$TMP/effort.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":true,"effort":"xhigh"},
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":true,"effort":"high"}
]
JSON
cat > "$TMP/xhigh-only.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":true,"effort":"xhigh"}
]
JSON
cat > "$TMP/all-tiers.json" <<'JSON'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":true,"effort":"high"}
]
JSON
printf '"not-an-array"\n' > "$TMP/scalar-candidates.json"
cat > "$TMP/boolean-cost.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":true,"available":true,"effort":"high"}
]
JSON
cat > "$TMP/exponent-cost.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":"1e2","available":true,"effort":"high"}
]
JSON
cat > "$TMP/numeric-cost.json" <<'JSON'
[
  {"name":"openai/gpt-5.2-codex","cost":1,"available":true,"effort":"high"}
]
JSON
cat > "$TMP/ordinal-registry.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v1",
  "models": [
    {"name":"provider/Z","canonical_tier":"lightweight","efforts":["low"]},
    {"name":"provider/i","canonical_tier":"lightweight","efforts":["low"]}
  ]
}
JSON
cat > "$TMP/ordinal-candidates.json" <<'JSON'
[
  {"name":"provider/i","cost":"0.01","available":true,"effort":"low"},
  {"name":"provider/Z","cost":"0.01","available":true,"effort":"low"}
]
JSON
cat > "$TMP/valid-risk.md" <<'EOF'
## T-001 Example
Risk: high
Risk Policy Version: 1
Risk Impact: material
Risk Reversibility: controlled
Risk Surface: sensitive
Risk Rationale: Trusted workflow boundary.
Required Workflow: tdd
EOF
cat > "$TMP/forged-risk.md" <<'EOF'
## T-001 Example
Risk: low
Risk Policy Version: 1
Risk Impact: material
Risk Reversibility: controlled
Risk Surface: sensitive
Risk Rationale: Incorrectly downgraded.
Required Workflow: test-after
EOF

bash "$RISK_SH" "$TMP/valid-risk.md" >/dev/null ||
  fail "shell risk precheck rejected policy-consistent structured risk"
pwsh -NoProfile -File "$RISK_PS" -TasksPath "$TMP/valid-risk.md" >/dev/null ||
  fail "PowerShell risk precheck rejected policy-consistent structured risk"
if bash "$RISK_SH" "$TMP/forged-risk.md" >/dev/null 2>&1; then
  fail "shell risk precheck accepted policy-inconsistent risk"
fi
if pwsh -NoProfile -File "$RISK_PS" -TasksPath "$TMP/forged-risk.md" >/dev/null 2>&1; then
  fail "PowerShell risk precheck accepted policy-inconsistent risk"
fi

for runtime in shell powershell; do
  if [[ "$runtime" == shell ]]; then
    run_selector() {
      bash "$SELECTOR_SH" --risk "$1" --registry "$REGISTRY" \
        --candidates-file "$2" --required-tier "$3" --json
    }
  else
    run_selector() {
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk "$1" -Registry "$REGISTRY" \
        -CandidatesFile "$2" -RequiredTier "$3" -Json
    }
  fi

  selected="$(run_selector low "$TMP/fallback.json" strong)"
  jq -e '.model == "openai/gpt-5.1-codex-max" and
    .canonical_tier == "strong" and .effort == "high"' <<<"$selected" >/dev/null ||
    fail "$runtime selector did not preserve strong tier on fallback"

  unavailable="$(run_selector low "$TMP/unavailable.json" strong)"
  [[ "$unavailable" == "BLOCKED model-tier-unavailable" ]] ||
    fail "$runtime selector did not fail closed when the tier was unavailable"

  if run_selector low "$TMP/scalar-candidates.json" strong >/dev/null 2>&1; then
    fail "$runtime selector accepted a scalar candidate document"
  fi
  for invalid_cost in boolean-cost exponent-cost numeric-cost; do
    if run_selector low "$TMP/$invalid_cost.json" strong >/dev/null 2>&1; then
      fail "$runtime selector accepted non-canonical $invalid_cost candidate cost"
    fi
  done

  if [[ "$runtime" == shell ]]; then
    ordinal="$(
      bash "$SELECTOR_SH" --risk low --registry "$TMP/ordinal-registry.json" \
        --candidates-file "$TMP/ordinal-candidates.json" --json
    )"
  else
    ordinal="$(
      SELECTOR_PS_PATH="$SELECTOR_PS" \
      ORDINAL_REGISTRY_PATH="$TMP/ordinal-registry.json" \
      ORDINAL_CANDIDATES_PATH="$TMP/ordinal-candidates.json" \
      pwsh -NoProfile -Command '
        [Threading.Thread]::CurrentThread.CurrentCulture =
          [Globalization.CultureInfo]::GetCultureInfo("sv-SE")
        & $env:SELECTOR_PS_PATH -Risk low `
          -Registry $env:ORDINAL_REGISTRY_PATH `
          -CandidatesFile $env:ORDINAL_CANDIDATES_PATH -Json
      '
    )"
  fi
  [[ "$(jq -r '.model' <<<"$ordinal")" == "provider/Z" ]] ||
    fail "$runtime selector did not use ordinal provider/model tie-breaking"

  if [[ "$runtime" == shell ]]; then
    runtime_unavailable="$(
      bash "$SELECTOR_SH" --risk low --registry "$REGISTRY" \
        --candidates-file "$TMP/all-tiers.json" \
        --deterministic-runtime-command sdd-runtime-that-does-not-exist
    )"
  else
    runtime_unavailable="$(
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk low -Registry "$REGISTRY" \
        -CandidatesFile "$TMP/all-tiers.json" \
        -DeterministicRuntimeCommand sdd-runtime-that-does-not-exist
    )"
  fi
  [[ "$runtime_unavailable" == "BLOCKED deterministic-runtime-unavailable" ]] ||
    fail "$runtime selector did not directly fail closed for an unavailable deterministic runtime"

  selected="$(run_selector low "$TMP/effort.json" strong)"
  jq -e '.model == "openai/gpt-5.2-codex" and .effort == "high" and
    .xhigh_reason == null' <<<"$selected" >/dev/null ||
    fail "$runtime selector did not prefer high effort before xhigh"

  selected="$(
    if [[ "$runtime" == shell ]]; then
      bash "$SELECTOR_SH" --risk low --registry "$REGISTRY" \
        --candidates-file "$TMP/xhigh-only.json" --required-tier strong --json \
        --xhigh-reason evaluator-contract
    else
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk low -Registry "$REGISTRY" \
        -CandidatesFile "$TMP/xhigh-only.json" -RequiredTier strong -Json \
        -XhighReason evaluator-contract
    fi
  )"
  jq -e '.canonical_tier == "strong" and .effort == "xhigh" and
    .xhigh_reason == "evaluator-contract" and
    (.available_candidates | index("openai/gpt-5.2-codex")) != null' \
    <<<"$selected" >/dev/null ||
    fail "$runtime selector did not record the availability-checked selection set"

  if [[ "$runtime" == shell ]]; then
    select_all() {
      bash "$SELECTOR_SH" --risk "$1" --registry "$REGISTRY" \
        --candidates-file "$TMP/all-tiers.json" "${@:2}" --json
    }
  else
    select_all() {
      local risk="$1"
      shift
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk "$risk" -Registry "$REGISTRY" \
        -CandidatesFile "$TMP/all-tiers.json" "$@" -Json
    }
  fi

  for risk_and_tier in "low lightweight" "medium standard" "high strong" "critical strong"; do
    read -r risk expected_tier <<<"$risk_and_tier"
    selected="$(select_all "$risk")"
    [[ "$(jq -r '.canonical_tier' <<<"$selected")" == "$expected_tier" ]] ||
      fail "$runtime selector violated turn-first matrix for $risk"
  done

  if [[ "$runtime" == shell ]]; then
    different="$(select_all medium --previous-tier standard --failure-history test,lint)"
    same="$(select_all medium --previous-tier standard --failure-history test,test --attempt-number 3)"
    one_tier="$(select_all high --previous-tier lightweight --failure-history test,test --attempt-number 4)"
    terminal="$(select_all high --previous-tier strong --failure-history review-major,review-major --attempt-number 5)"
    same_text="$(
      bash "$SELECTOR_SH" --risk medium --registry "$REGISTRY" \
        --candidates-file "$TMP/all-tiers.json" --previous-tier standard \
        --failure-history test,test --attempt-number 3
    )"
    terminal_text="$(
      bash "$SELECTOR_SH" --risk high --registry "$REGISTRY" \
        --candidates-file "$TMP/all-tiers.json" --previous-tier strong \
        --failure-history review-major,review-major --attempt-number 5
    )"
    if bash "$SELECTOR_SH" --risk medium --registry "$REGISTRY" \
      --candidates-file "$TMP/all-tiers.json" --failure-history test,unknown --json \
      >/dev/null 2>&1; then
      fail "shell selector accepted an unknown failure class"
    fi
  else
    different="$(select_all medium -PreviousTier standard -FailureHistory test,lint)"
    same="$(select_all medium -PreviousTier standard -FailureHistory test,test -AttemptNumber 3)"
    one_tier="$(select_all high -PreviousTier lightweight -FailureHistory test,test -AttemptNumber 4)"
    terminal="$(select_all high -PreviousTier strong -FailureHistory review-major,review-major -AttemptNumber 5)"
    same_text="$(
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk medium -Registry "$REGISTRY" \
        -CandidatesFile "$TMP/all-tiers.json" -PreviousTier standard \
        -FailureHistory test,test -AttemptNumber 3
    )"
    terminal_text="$(
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk high -Registry "$REGISTRY" \
        -CandidatesFile "$TMP/all-tiers.json" -PreviousTier strong \
        -FailureHistory review-major,review-major -AttemptNumber 5
    )"
    if pwsh -NoProfile -File "$SELECTOR_PS" -Risk medium -Registry "$REGISTRY" \
      -CandidatesFile "$TMP/all-tiers.json" -FailureHistory test,unknown -Json \
      >/dev/null 2>&1; then
      fail "PowerShell selector accepted an unknown failure class"
    fi
  fi
  [[ "$(jq -r '.canonical_tier' <<<"$different")" == "standard" ]] ||
    fail "$runtime selector accumulated different failure classes"
  [[ "$(jq -r '.canonical_tier' <<<"$same")" == "strong" ]] ||
    fail "$runtime selector did not advance exactly one tier after recurrence"
  jq -e '.escalation == {
    "attempt_number":3,
    "failure_class":"test",
    "next_tier":"strong",
    "prior_tier":"standard",
    "reason":"same-classified-failure-twice"
  }' <<<"$same" >/dev/null ||
    fail "$runtime selector omitted REQ-004 escalation audit fields"
  [[ "$(jq -r '.canonical_tier' <<<"$one_tier")" == "standard" ]] ||
    fail "$runtime selector skipped a tier after lightweight recurrence"
  jq -e '.status == "BLOCKED" and .reason == "terminal-tier-recurrence" and
    .escalation == {
      "attempt_number":5,
      "failure_class":"review-major",
      "next_tier":null,
      "prior_tier":"strong",
      "reason":"terminal-tier-recurrence"
    }' <<<"$terminal" >/dev/null ||
    fail "$runtime selector did not block terminal-tier recurrence"
  [[ "$same_text" == \
    "openai/gpt-5.2-codex strong prior_tier=standard next_tier=strong failure_class=test attempt_number=3 reason=same-classified-failure-twice" ]] ||
    fail "$runtime selector omitted non-JSON escalation audit fields"
  [[ "$terminal_text" == \
    "BLOCKED terminal-tier-recurrence prior_tier=strong next_tier=null failure_class=review-major attempt_number=5 reason=terminal-tier-recurrence" ]] ||
    fail "$runtime selector omitted non-JSON terminal recurrence audit fields"
done

# --- T-002: selector v2 registry support, effort-resolution priority ---
# Phase-1-scoped smoke of --effort-policy/--requested-effort/--role/--host
# (TEST-006..013, TEST-053, TEST-054); the full REQ-002/REQ-005 case list is
# T-005's own suite (tests/agent-model-routing.tests.ps1 + this file's
# extension there).

# Sanity: schema auto-detection recognizes the REAL, shipped v2 registry
# (not just the synthetic fixtures below).
real_v2="$(
  bash "$SELECTOR_SH" --risk low --registry "$REGISTRY_V2" \
    --candidates-file "$TMP/all-tiers.json" --required-tier lightweight --json
)"
jq -e '.model == "openai/gpt-5.1-codex-mini" and .effort_source == "welded"' \
  <<<"$real_v2" >/dev/null ||
  fail "shell selector did not auto-detect the real v2 registry schema"

cat > "$TMP/v2-registry.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"openai/gpt-5.1-codex-mini","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"none","codex-cli":"flag"}},
    {"name":"openai/gpt-5.1-codex","canonical_tier":"standard","supported_efforts":["medium"],"default_effort":"medium","effort_control":{"claude-code":"none","codex-cli":"flag"}},
    {"name":"openai/gpt-5.2-codex","canonical_tier":"strong","supported_efforts":["high","xhigh"],"default_effort":"high","effort_control":{"claude-code":"none","codex-cli":"flag"}},
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low","medium"],"default_effort":"low","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}},
    {"name":"anthropic/sonnet","canonical_tier":"standard","supported_efforts":["medium","high"],"default_effort":"medium","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}},
    {"name":"anthropic/opus","canonical_tier":"strong","supported_efforts":["high","xhigh"],"default_effort":"high","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {
    "sdd-evaluator": {"minimum_tier":"strong","default_effort":"high"},
    "sdd-investigator": {"minimum_tier":"lightweight","default_effort":"low"}
  }
}
JSON
cat > "$TMP/v2-partial-matrix-registry.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low","medium"],"default_effort":"low","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","critical":"high","escalation_bump":true},
  "role_defaults": {
    "sdd-investigator": {"minimum_tier":"lightweight","default_effort":"low"}
  }
}
JSON
cat > "$TMP/v2-malformed-supported-efforts.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":[],"default_effort":"low","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {}
}
JSON
cat > "$TMP/v2-malformed-effort-control.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"sometimes","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {}
}
JSON
cat > "$TMP/v2-malformed-risk-matrix.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":3,"critical":"high","escalation_bump":true},
  "role_defaults": {}
}
JSON
cat > "$TMP/v2-golden-candidates.json" <<'JSON'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":true,"effort":"high"}
]
JSON
cat > "$TMP/v2-matrix-standard-candidates.json" <<'JSON'
[
  {"name":"anthropic/sonnet","cost":"0.02","available":true},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true}
]
JSON
cat > "$TMP/v2-clamp-standard-candidate.json" <<'JSON'
[
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true}
]
JSON
cat > "$TMP/v2-escalation-strong-candidate.json" <<'JSON'
[
  {"name":"anthropic/opus","cost":"0.09","available":true}
]
JSON
cat > "$TMP/v2-role-min-tier-candidates.json" <<'JSON'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true},
  {"name":"anthropic/opus","cost":"0.09","available":true}
]
JSON
cat > "$TMP/v2-role-fallback-candidate.json" <<'JSON'
[
  {"name":"anthropic/haiku","cost":"0.01","available":true}
]
JSON
cat > "$TMP/v2-requested-override-candidate.json" <<'JSON'
[
  {"name":"anthropic/sonnet","cost":"0.02","available":true}
]
JSON
cat > "$TMP/v2-requested-clamp-candidate.json" <<'JSON'
[
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true}
]
JSON
cat > "$TMP/v2-requested-xhigh-candidate.json" <<'JSON'
[
  {"name":"anthropic/opus","cost":"0.09","available":true}
]
JSON
cat > "$TMP/v1-omit-effort-candidate.json" <<'JSON'
[
  {"name":"anthropic/haiku","cost":"0.01","available":true}
]
JSON

# TEST-006 (AC-006): v1 registry, incl. legacy positional --candidate, is
# byte-identical to the pre-feature baseline (literal strings captured
# from the pre-T-002 script, before any of this task's edits landed).
legacy_text="$(
  bash "$SELECTOR_SH" --risk low --registry "$REGISTRY" \
    --candidate anthropic/haiku:lightweight:0.01 \
    --candidate openai/gpt-5.1-codex-mini:lightweight:0.02
)"
[[ "$legacy_text" == "anthropic/haiku lightweight" ]] ||
  fail "TEST-006 legacy positional text output drifted from the pre-feature baseline"
legacy_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$REGISTRY" \
    --candidate anthropic/haiku:lightweight:0.01 \
    --candidate openai/gpt-5.1-codex-mini:lightweight:0.02 --json
)"
[[ "$legacy_json" == '{"available_candidates":["anthropic/haiku","openai/gpt-5.1-codex-mini"],"canonical_tier":"lightweight","effort":null,"escalation":null,"estimated_cost_per_attempt_usd":"0.01","model":"anthropic/haiku","xhigh_reason":null}' ]] ||
  fail "TEST-006 legacy positional JSON output drifted from the pre-feature baseline (no new keys allowed for v1)"
for runtime in shell powershell; do
  if [[ "$runtime" == shell ]]; then
    v1_golden_text="$(
      bash "$SELECTOR_SH" --risk high --registry "$REGISTRY" \
        --candidates-file "$TMP/all-tiers.json"
    )"
  else
    v1_golden_text="$(
      pwsh -NoProfile -File "$SELECTOR_PS" -Risk high -Registry "$REGISTRY" \
        -CandidatesFile "$TMP/all-tiers.json"
    )"
  fi
  [[ "$v1_golden_text" == "openai/gpt-5.2-codex strong" ]] ||
    fail "$runtime TEST-006 v1 candidates-file text output drifted from the pre-feature baseline"
done

# TEST-007 (AC-007): v2 registry, welded (default, and explicit), is
# byte-identical (TEXT-mode, which never carries the additive JSON-only
# keys) to the SAME pre-feature baseline TEST-006 just proved for v1; JSON
# mode separately proves the two new keys are present and correctly
# attributed (effort_source: "welded"), which is why the comparison
# granularity here is TEXT-mode byte-identity, not raw-JSON-string
# identity (design.md API/Contract Plan: the two new keys are additive to
# JSON output only, never to the non-JSON text format).
default_policy_text="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-golden-candidates.json"
)"
explicit_welded_text="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-golden-candidates.json" --effort-policy welded
)"
[[ "$default_policy_text" == "openai/gpt-5.2-codex strong" ]] ||
  fail "TEST-007 v2 welded (default policy) text output diverged from the v1 golden baseline"
[[ "$explicit_welded_text" == "openai/gpt-5.2-codex strong" ]] ||
  fail "TEST-007 v2 welded (explicit policy) text output diverged from the v1 golden baseline"
welded_json="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-golden-candidates.json" --json
)"
jq -e '.model == "openai/gpt-5.2-codex" and .canonical_tier == "strong" and
  .effort == "high" and .estimated_cost_per_attempt_usd == "0.03" and
  .effort_source == "welded" and .effort_control == "none" and
  .xhigh_reason == null and .escalation == null' <<<"$welded_json" >/dev/null ||
  fail "TEST-007/TEST-012 v2 welded JSON output missing correct additive keys or mutated an existing key"

# Negative canary (round-2 mutation-based self-check): mutate the golden
# fixture (make the previous winner unavailable) and confirm the TEXT-mode
# comparison actually goes red, proving TEST-007's byte-identical
# assertion above is discriminating, not vacuously true.
sed -e 's#"cost":"0.03","available":true#"cost":"0.03","available":false#' \
  "$TMP/v2-golden-candidates.json" > "$TMP/v2-golden-candidates-mutated.json"
mutated_text="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-golden-candidates-mutated.json"
)"
[[ "$mutated_text" != "$default_policy_text" ]] ||
  fail "TEST-007 negative canary: mutated golden fixture did not change output (comparison is vacuous)"
[[ "$mutated_text" == "openai/gpt-5.1-codex standard" ]] ||
  fail "TEST-007 negative canary produced an unexpected fallback winner"

# TEST-008 (AC-008): matrix policy risk-based selection picks sonnet at
# high effort (lexicographic tiebreak among equal-tier, equal-cost
# candidates once the pre-existing effort ordinal tiebreak is neutralized
# by both candidates omitting a declared effort, per design.md's
# composition of the unmodified sort key).
matrix_json="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-matrix-standard-candidates.json" \
    --effort-policy matrix --required-tier standard --json
)"
jq -e '.model == "anthropic/sonnet" and .effort == "high" and
  .effort_source == "risk-matrix"' <<<"$matrix_json" >/dev/null ||
  fail "TEST-008 matrix policy did not select sonnet at high effort"

# TEST-009 (AC-009): a matrix-selected effort outside the winning model's
# supported_efforts clamps to the nearest supported value.
clamp_json="$(
  bash "$SELECTOR_SH" --risk critical --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-clamp-standard-candidate.json" \
    --effort-policy matrix --required-tier standard --json
)"
jq -e '.model == "openai/gpt-5.1-codex" and .effort == "medium" and
  .effort_source == "risk-matrix"' <<<"$clamp_json" >/dev/null ||
  fail "TEST-009 matrix-selected effort outside supported_efforts did not clamp"

# TEST-009 (AC-009, escalation half): an escalation-bumped matrix
# selection that lands on xhigh still requires --xhigh-reason.
escalation_blocked="$(
  bash "$SELECTOR_SH" --risk critical --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-escalation-strong-candidate.json" \
    --effort-policy matrix --previous-tier standard \
    --failure-history review-major,review-major --attempt-number 3
)"
[[ "$escalation_blocked" == "BLOCKED model-tier-unavailable" ]] ||
  fail "TEST-009 escalation-bumped xhigh selection was not gated without --xhigh-reason"
escalation_json="$(
  bash "$SELECTOR_SH" --risk critical --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-escalation-strong-candidate.json" \
    --effort-policy matrix --previous-tier standard \
    --failure-history review-major,review-major --attempt-number 3 \
    --xhigh-reason escalation-bump-accepted --json
)"
jq -e '.model == "anthropic/opus" and .effort == "xhigh" and
  .effort_source == "risk-matrix" and .xhigh_reason == "escalation-bump-accepted"' \
  <<<"$escalation_json" >/dev/null ||
  fail "TEST-009 escalation-bumped xhigh selection did not succeed with --xhigh-reason"

# TEST-010 (AC-010): --requested-effort overrides the policy-selected
# effort under matrix, still clamped, still xhigh-gated.
requested_override_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-requested-override-candidate.json" \
    --effort-policy matrix --requested-effort high --json
)"
jq -e '.model == "anthropic/sonnet" and .effort == "high" and
  .effort_source == "requested"' <<<"$requested_override_json" >/dev/null ||
  fail "TEST-010 --requested-effort did not override matrix policy selection"
requested_clamp_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-requested-clamp-candidate.json" \
    --effort-policy matrix --requested-effort xhigh --json
)"
jq -e '.model == "openai/gpt-5.1-codex" and .effort == "medium" and
  .effort_source == "requested"' <<<"$requested_clamp_json" >/dev/null ||
  fail "TEST-010 --requested-effort was not clamped to supported_efforts"
requested_xhigh_blocked="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-requested-xhigh-candidate.json" \
    --effort-policy matrix --requested-effort xhigh
)"
[[ "$requested_xhigh_blocked" == "BLOCKED model-tier-unavailable" ]] ||
  fail "TEST-010 --requested-effort xhigh was not gated without --xhigh-reason"

# TEST-011 (AC-011): --role always seeds --minimum-tier (both policies);
# under matrix with a risk_effort_matrix gap, --role additionally seeds a
# role-default effort; under welded, --role's effort component is inert.
role_min_tier_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-role-min-tier-candidates.json" \
    --effort-policy matrix --role sdd-evaluator --json
)"
jq -e '.model == "anthropic/opus" and .canonical_tier == "strong" and
  .effort == "high"' <<<"$role_min_tier_json" >/dev/null ||
  fail "TEST-011 --role did not seed --minimum-tier"
role_default_json="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-partial-matrix-registry.json" \
    --candidates-file "$TMP/v2-role-fallback-candidate.json" \
    --effort-policy matrix --role sdd-investigator --json
)"
jq -e '.model == "anthropic/haiku" and .effort == "low" and
  .effort_source == "role-default"' <<<"$role_default_json" >/dev/null ||
  fail "TEST-011 --role did not seed a role-default fallback effort when risk_effort_matrix had no entry"
welded_with_role_text="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-golden-candidates.json" --role sdd-investigator
)"
[[ "$welded_with_role_text" == "$default_policy_text" ]] ||
  fail "TEST-011 --role's effort component was not inert under welded policy"

# TEST-012 (AC-012): --host resolves effort_control; effort_source
# 5-way attribution (welded/risk-matrix/role-default already proven above
# via TEST-007/TEST-008/TEST-011; requested proven via TEST-010;
# model-default proven below); every pre-existing JSON key stays present
# and correctly typed alongside the two additive keys.
model_default_json="$(
  bash "$SELECTOR_SH" --risk high --registry "$TMP/v2-partial-matrix-registry.json" \
    --candidates-file "$TMP/v2-role-fallback-candidate.json" \
    --effort-policy matrix --json
)"
jq -e '.model == "anthropic/haiku" and .effort == "low" and
  .effort_source == "model-default"' <<<"$model_default_json" >/dev/null ||
  fail "TEST-012 matrix policy did not fall back to the winning model's own default_effort"
host_codex_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-requested-clamp-candidate.json" \
    --host codex-cli --json
)"
jq -e '.effort_control == "flag"' <<<"$host_codex_json" >/dev/null ||
  fail "TEST-012 --host codex-cli did not resolve the flag effort_control"
jq -e 'has("model") and has("canonical_tier") and has("effort") and
  has("estimated_cost_per_attempt_usd") and has("available_candidates") and
  has("xhigh_reason") and has("escalation") and has("effort_source") and
  has("effort_control") and (.available_candidates | type) == "array"' \
  <<<"$host_codex_json" >/dev/null ||
  fail "TEST-012 v2 JSON output is missing a pre-existing or additive key"

# TEST-013 (AC-013): a v2 --candidates-file entry may omit effort (the
# selector fills it via policy); a v1 --candidates-file still requires
# effort and rejects its absence exactly as today.
if bash "$SELECTOR_SH" --risk low --registry "$REGISTRY" \
  --candidates-file "$TMP/v1-omit-effort-candidate.json" --json >/dev/null 2>&1; then
  fail "TEST-013 v1 --candidates-file accepted a candidate omitting effort"
fi
v2_omit_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v1-omit-effort-candidate.json" --json
)"
jq -e '.model == "anthropic/haiku" and .effort == "low" and
  .effort_source == "welded"' <<<"$v2_omit_json" >/dev/null ||
  fail "TEST-013 v2 --candidates-file did not fill an omitted effort via policy"

# TEST-053 (AC-053): --requested-effort under welded (or no policy flag)
# applies the requested value, effort_source: "requested" — provably
# outside TEST-007's golden-comparison set: none of the golden invocations
# above ever supply --requested-effort, so this case is structurally
# disjoint from that comparison, not a narrowing of it.
welded_requested_json="$(
  bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
    --candidates-file "$TMP/v2-requested-override-candidate.json" \
    --requested-effort high --json
)"
jq -e '.model == "anthropic/sonnet" and .effort == "high" and
  .effort_source == "requested"' <<<"$welded_requested_json" >/dev/null ||
  fail "TEST-053 --requested-effort under welded did not apply the requested value"

# TEST-054 (AC-054): each malformed v2 field category is rejected
# fail-closed with a MODEL_SELECTION_ERROR-class diagnostic and no
# candidate selected.
for malformed in v2-malformed-supported-efforts v2-malformed-effort-control \
  v2-malformed-risk-matrix; do
  if bash "$SELECTOR_SH" --risk low --registry "$TMP/$malformed.json" \
    --candidates-file "$TMP/v1-omit-effort-candidate.json" --json \
    >/dev/null 2>&1; then
    fail "TEST-054 $malformed did not exit non-zero"
  fi
  malformed_stderr="$(
    bash "$SELECTOR_SH" --risk low --registry "$TMP/$malformed.json" \
      --candidates-file "$TMP/v1-omit-effort-candidate.json" --json \
      2>&1 >/dev/null || true
  )"
  [[ "$malformed_stderr" == MODEL_SELECTION_ERROR:* ]] ||
    fail "TEST-054 $malformed did not emit a MODEL_SELECTION_ERROR-class diagnostic"
done

# PowerShell twin spot-check: prove the .ps1 twin implements the same v2
# schema auto-detection, matrix selection, and malformed-field rejection
# (full twin parity is T-005's own suite).
ps_matrix_json="$(
  pwsh -NoProfile -File "$SELECTOR_PS" -Risk high -Registry "$TMP/v2-registry.json" \
    -CandidatesFile "$TMP/v2-matrix-standard-candidates.json" \
    -EffortPolicy matrix -RequiredTier standard -Json
)"
jq -e '.model == "anthropic/sonnet" and .effort == "high" and
  .effort_source == "risk-matrix"' <<<"$ps_matrix_json" >/dev/null ||
  fail "PowerShell selector did not select sonnet at high effort under matrix policy"
ps_host_json="$(
  pwsh -NoProfile -File "$SELECTOR_PS" -Risk low -Registry "$TMP/v2-registry.json" \
    -CandidatesFile "$TMP/v2-requested-clamp-candidate.json" -HostName codex-cli -Json
)"
jq -e '.effort_control == "flag"' <<<"$ps_host_json" >/dev/null ||
  fail "PowerShell selector -HostName codex-cli did not resolve the flag effort_control"
ps_welded_text="$(
  pwsh -NoProfile -File "$SELECTOR_PS" -Risk high -Registry "$TMP/v2-registry.json" \
    -CandidatesFile "$TMP/v2-golden-candidates.json"
)"
[[ "$ps_welded_text" == "openai/gpt-5.2-codex strong" ]] ||
  fail "PowerShell selector v2 welded text output diverged from the v1 golden baseline"
if pwsh -NoProfile -File "$SELECTOR_PS" -Risk low -Registry "$TMP/v2-malformed-supported-efforts.json" \
  -CandidatesFile "$TMP/v1-omit-effort-candidate.json" -Json >/dev/null 2>&1; then
  fail "PowerShell selector accepted a malformed empty supported_efforts array"
fi

# PowerShell case-sensitivity hazard guard (2 layers): layer 1 is every
# comparison above using -ceq/-cne/-cin/-cnotin/-ccontains plus ordinal
# (case-sensitive) Dictionary lookups for untrusted model-name/risk-key
# strings, rather than a bare `@{}` hashtable (which PowerShell resolves
# case-INSENSITIVELY by default and would let a mis-cased value silently
# alias a correctly-cased one); layer 2 is this mis-cased negative
# fixture pair, proving the guard is live, not merely asserted by
# construction.
cat > "$TMP/v2-mis-cased-effort-control.json" <<'JSON'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"Frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {}
}
JSON
cat > "$TMP/v2-mis-cased-candidate.json" <<'JSON'
[
  {"name":"Anthropic/Haiku","cost":"0.01","available":true}
]
JSON
if pwsh -NoProfile -File "$SELECTOR_PS" -Risk low -Registry "$TMP/v2-mis-cased-effort-control.json" \
  -CandidatesFile "$TMP/v1-omit-effort-candidate.json" -Json >/dev/null 2>&1; then
  fail "PowerShell selector accepted a mis-cased effort_control value (Frontmatter, not frontmatter)"
fi
if pwsh -NoProfile -File "$SELECTOR_PS" -Risk low -Registry "$TMP/v2-registry.json" \
  -CandidatesFile "$TMP/v2-mis-cased-candidate.json" -Json >/dev/null 2>&1; then
  fail "PowerShell selector case-insensitively matched a mis-cased candidate model name (Anthropic/Haiku) against the registry's anthropic/haiku"
fi
if bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-mis-cased-effort-control.json" \
  --candidates-file "$TMP/v1-omit-effort-candidate.json" --json >/dev/null 2>&1; then
  fail "shell selector accepted a mis-cased effort_control value (Frontmatter, not frontmatter)"
fi
if bash "$SELECTOR_SH" --risk low --registry "$TMP/v2-registry.json" \
  --candidates-file "$TMP/v2-mis-cased-candidate.json" --json >/dev/null 2>&1; then
  fail "shell selector case-insensitively matched a mis-cased candidate model name (Anthropic/Haiku) against the registry's anthropic/haiku"
fi

mkdir -p "$TMP/resume-repo/diagnostics"
cat > "$TMP/resume-repo/diagnostics/T-900.md" <<'EOF'
# Diagnosis

The repeated review-major failure was caused by a stale task boundary.
EOF
cat > "$TMP/resume-repo/tasks.md" <<'EOF'
# Tasks

## T-900 Resume fixture

Approval: Approved (human reapproval)

Status: Planned

Diagnosis Reference: diagnostics/T-900.md

Terminal Reapproval: release-owner @ 2026-06-30T03:00:00Z
EOF
blocked_contract_hash="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
cat > "$TMP/resume-repo/blocked-state.json" <<EOF
{
  "schema": "terminal-tier-blocked-state/v1",
  "task_id": "T-900",
  "blocked_task_contract_sha256": "$blocked_contract_hash",
  "tier": "strong",
  "failure_class": "review-major",
  "attempt_number": 2,
  "reason": "terminal-tier-recurrence",
  "blocked_at": "2026-06-30T02:00:00Z"
}
EOF
blocked_state_hash="$(
  shasum -a 256 "$TMP/resume-repo/blocked-state.json" | awk '{print $1}'
)"
resume_tasks_hash="$(
  python3 - "$TMP/resume-repo/tasks.md" <<'PY'
import hashlib
import re
import sys
with open(sys.argv[1], encoding="utf-8", newline="") as handle:
    text = handle.read()
section = re.search(r"(?ms)^## T-900\b.*?(?=^## T-\d{3}\b|\Z)", text).group(0)
print(hashlib.sha256(section.rstrip("\r\n").encode("utf-8")).hexdigest())
PY
)"
resume_diagnosis_hash="$(
  shasum -a 256 "$TMP/resume-repo/diagnostics/T-900.md" | awk '{print $1}'
)"
cat > "$TMP/resume.json" <<EOF
{
  "schema": "terminal-tier-resume/v1",
  "task_id": "T-900",
  "blocked_state_reference": {
    "path": "blocked-state.json",
    "sha256": "$blocked_state_hash"
  },
  "blocked_task_contract_sha256": "$blocked_contract_hash",
  "revised_task_contract_sha256": "$resume_tasks_hash",
  "diagnosis_reference": {
    "path": "diagnostics/T-900.md",
    "sha256": "$resume_diagnosis_hash"
  },
  "human_reapproval": {
    "authority": "release-owner",
    "timestamp": "2026-06-30T03:00:00Z"
  }
}
EOF

bash "$RESUME_SH" --evidence "$TMP/resume.json" \
  --blocked-state "$TMP/resume-repo/blocked-state.json" \
  --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
  --expected-task T-900 >/dev/null ||
  fail "shell terminal-resume validator rejected complete human evidence"
pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume.json" \
  -BlockedState "$TMP/resume-repo/blocked-state.json" \
  -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
  -ExpectedTask T-900 >/dev/null ||
  fail "PowerShell terminal-resume validator rejected complete human evidence"

jq '.blocked_task_contract_sha256 = .revised_task_contract_sha256' \
  "$TMP/resume.json" > "$TMP/resume-unchanged.json"
for runtime in shell powershell; do
  if [[ "$runtime" == shell ]]; then
    if bash "$RESUME_SH" --evidence "$TMP/resume-unchanged.json" \
      --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
      --blocked-state "$TMP/resume-repo/blocked-state.json" \
      --expected-task T-900 >/dev/null 2>&1; then
      fail "shell terminal-resume validator accepted an unchanged task contract"
    fi
  else
    if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume-unchanged.json" \
      -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
      -BlockedState "$TMP/resume-repo/blocked-state.json" \
      -ExpectedTask T-900 >/dev/null 2>&1; then
      fail "PowerShell terminal-resume validator accepted an unchanged task contract"
    fi
  fi
done

cat >> "$TMP/resume-repo/tasks.md" <<'EOF'

## T-901 Unrelated fixture

Approval: Approved

Status: Planned
EOF
bash "$RESUME_SH" --evidence "$TMP/resume.json" \
  --blocked-state "$TMP/resume-repo/blocked-state.json" \
  --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
  --expected-task T-900 >/dev/null ||
  fail "shell terminal-resume validator bound the hash to unrelated tasks"
pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume.json" \
  -BlockedState "$TMP/resume-repo/blocked-state.json" \
  -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
  -ExpectedTask T-900 >/dev/null ||
  fail "PowerShell terminal-resume validator bound the hash to unrelated tasks"

jq '.blocked_task_contract_sha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' \
  "$TMP/resume.json" > "$TMP/resume-forged-blocked-hash.json"
for runtime in shell powershell; do
  if [[ "$runtime" == shell ]]; then
    if bash "$RESUME_SH" --evidence "$TMP/resume-forged-blocked-hash.json" \
      --blocked-state "$TMP/resume-repo/blocked-state.json" \
      --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
      --expected-task T-900 >/dev/null 2>&1; then
      fail "shell terminal-resume validator accepted a forged blocked contract hash"
    fi
  else
    if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume-forged-blocked-hash.json" \
      -BlockedState "$TMP/resume-repo/blocked-state.json" \
      -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
      -ExpectedTask T-900 >/dev/null 2>&1; then
      fail "PowerShell terminal-resume validator accepted a forged blocked contract hash"
    fi
  fi
done

jq '.human_reapproval.timestamp = "2026-06-30T03:00:00.123Z"' \
  "$TMP/resume.json" > "$TMP/resume-fractional-time.json"
for runtime in shell powershell; do
  if [[ "$runtime" == shell ]]; then
    if bash "$RESUME_SH" --evidence "$TMP/resume-fractional-time.json" \
      --blocked-state "$TMP/resume-repo/blocked-state.json" \
      --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
      --expected-task T-900 >/dev/null 2>&1; then
      fail "shell terminal-resume validator accepted a fractional-second timestamp"
    fi
  else
    if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume-fractional-time.json" \
      -BlockedState "$TMP/resume-repo/blocked-state.json" \
      -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
      -ExpectedTask T-900 >/dev/null 2>&1; then
      fail "PowerShell terminal-resume validator accepted a fractional-second timestamp"
    fi
  fi
done

mv "$TMP/resume-repo/diagnostics" "$TMP/outside-diagnostics"
ln -s "$TMP/outside-diagnostics" "$TMP/resume-repo/diagnostics"
if bash "$RESUME_SH" --evidence "$TMP/resume.json" \
  --blocked-state "$TMP/resume-repo/blocked-state.json" \
  --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
  --expected-task T-900 >/dev/null 2>&1; then
  fail "shell terminal-resume validator accepted a parent-directory symlink escape"
fi
if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume.json" \
  -BlockedState "$TMP/resume-repo/blocked-state.json" \
  -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
  -ExpectedTask T-900 >/dev/null 2>&1; then
  fail "PowerShell terminal-resume validator accepted a parent-directory symlink escape"
fi
rm "$TMP/resume-repo/diagnostics"
mv "$TMP/outside-diagnostics" "$TMP/resume-repo/diagnostics"

printf '\nTampered diagnosis.\n' >> "$TMP/resume-repo/diagnostics/T-900.md"
if bash "$RESUME_SH" --evidence "$TMP/resume.json" \
  --blocked-state "$TMP/resume-repo/blocked-state.json" \
  --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
  --expected-task T-900 >/dev/null 2>&1; then
  fail "shell terminal-resume validator accepted a forged diagnosis hash"
fi
if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume.json" \
  -BlockedState "$TMP/resume-repo/blocked-state.json" \
  -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
  -ExpectedTask T-900 >/dev/null 2>&1; then
  fail "PowerShell terminal-resume validator accepted a forged diagnosis hash"
fi

printf 'ok: turn-first model routing structure is defined\n'
