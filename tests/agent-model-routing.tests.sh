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
SELECTOR_SH="$ROOT/plugins/sdd-implementation/scripts/select-agent-model.sh"
SELECTOR_PS="$ROOT/plugins/sdd-implementation/scripts/select-agent-model.ps1"
RESUME_SH="$ROOT/plugins/sdd-implementation/scripts/check-terminal-tier-resume.sh"
RESUME_PS="$ROOT/plugins/sdd-implementation/scripts/check-terminal-tier-resume.ps1"
RISK_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-risk.sh"
RISK_PS="$ROOT/plugins/sdd-quality-loop/scripts/check-risk.ps1"

for file in "$MATRIX" "$ADR" "$POLICY" "$INVESTIGATOR" "$COPILOT_INVESTIGATOR" \
  "$EVALUATOR" "$REGISTRY" "$SELECTOR_SH" "$SELECTOR_PS" "$RESUME_SH" \
  "$RESUME_PS"; do
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
    same="$(select_all medium --previous-tier standard --failure-history test,test)"
    terminal="$(select_all high --previous-tier strong --failure-history review-major,review-major)"
    if bash "$SELECTOR_SH" --risk medium --registry "$REGISTRY" \
      --candidates-file "$TMP/all-tiers.json" --failure-history test,unknown --json \
      >/dev/null 2>&1; then
      fail "shell selector accepted an unknown failure class"
    fi
  else
    different="$(select_all medium -PreviousTier standard -FailureHistory test,lint)"
    same="$(select_all medium -PreviousTier standard -FailureHistory test,test)"
    terminal="$(select_all high -PreviousTier strong -FailureHistory review-major,review-major)"
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
  [[ "$terminal" == "BLOCKED terminal-tier-recurrence" ]] ||
    fail "$runtime selector did not block terminal-tier recurrence"
done

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
resume_tasks_hash="$(shasum -a 256 "$TMP/resume-repo/tasks.md" | awk '{print $1}')"
resume_diagnosis_hash="$(
  shasum -a 256 "$TMP/resume-repo/diagnostics/T-900.md" | awk '{print $1}'
)"
cat > "$TMP/resume.json" <<EOF
{
  "schema": "terminal-tier-resume/v1",
  "task_id": "T-900",
  "blocked_task_contract_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
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
  --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
  --expected-task T-900 >/dev/null ||
  fail "shell terminal-resume validator rejected complete human evidence"
pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume.json" \
  -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
  -ExpectedTask T-900 >/dev/null ||
  fail "PowerShell terminal-resume validator rejected complete human evidence"

jq '.blocked_task_contract_sha256 = .revised_task_contract_sha256' \
  "$TMP/resume.json" > "$TMP/resume-unchanged.json"
for runtime in shell powershell; do
  if [[ "$runtime" == shell ]]; then
    if bash "$RESUME_SH" --evidence "$TMP/resume-unchanged.json" \
      --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
      --expected-task T-900 >/dev/null 2>&1; then
      fail "shell terminal-resume validator accepted an unchanged task contract"
    fi
  else
    if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume-unchanged.json" \
      -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
      -ExpectedTask T-900 >/dev/null 2>&1; then
      fail "PowerShell terminal-resume validator accepted an unchanged task contract"
    fi
  fi
done

printf '\nTampered diagnosis.\n' >> "$TMP/resume-repo/diagnostics/T-900.md"
if bash "$RESUME_SH" --evidence "$TMP/resume.json" \
  --tasks "$TMP/resume-repo/tasks.md" --repo-root "$TMP/resume-repo" \
  --expected-task T-900 >/dev/null 2>&1; then
  fail "shell terminal-resume validator accepted a forged diagnosis hash"
fi
if pwsh -NoProfile -File "$RESUME_PS" -Evidence "$TMP/resume.json" \
  -Tasks "$TMP/resume-repo/tasks.md" -RepoRoot "$TMP/resume-repo" \
  -ExpectedTask T-900 >/dev/null 2>&1; then
  fail "PowerShell terminal-resume validator accepted a forged diagnosis hash"
fi

printf 'ok: turn-first model routing structure is defined\n'
