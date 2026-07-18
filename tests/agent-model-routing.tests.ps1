# Suite: agent-model-routing -- PowerShell twin of
# tests/agent-model-routing.tests.sh (T-001/T-002/T-005, epic-159-pillar-c).
# Closes the pre-existing twin gap requirements.md's Problems section
# documents (T-005, Issue #154, REQ-005, AC-027..AC-034) and ports the full
# REQ-002/REQ-005 v2 routing case matrix (TEST-006..013, TEST-027..034,
# TEST-053, TEST-054) 1:1 from the extended `.sh`, plus the pre-existing
# T-001 routing-doc/ADR/policy assertions and the terminal-tier-resume
# validator cases the `.sh` file already carried.
#
# Only the PowerShell-native half of each dual-runtime `.sh` case is
# ported here (this suite must run standalone on Windows CI lanes where
# `bash`/`jq` are not guaranteed available) -- the `.sh` file itself
# remains the bash-native half.
#
# Case-sensitivity (two layers, mirroring select-agent-model.ps1's own
# established T-002/T-003 discipline):
#   1. Operator level: every registry/candidate/effort string comparison
#      below uses -ceq/-cne/-cin/-cnotin/-ccontains, never a bare -eq/-in
#      (which PowerShell resolves case-INSENSITIVELY for strings).
#   2. Fixture level: an explicit mis-cased negative fixture pair (a
#      capitalized `effort_control` value, a capitalized candidate model
#      name) proves the guard is live, not merely asserted by construction
#      (case-sensitivity guard section, below).
# `$Host` is PowerShell's own reserved automatic variable (the host
# program), so every local variable naming the selector's --host concept
# below is named with a `HostName`-shaped identifier, matching
# select-agent-model.ps1's own -HostName parameter (T-002 lesson).
# Error output from expected-failure invocations is captured via
# try/catch into a plain-text $_.Exception.Message comparison, never
# relying on pwsh's default ConciseView error formatting (T-003 lesson:
# that formatting can fracture a substring match across lines).
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Fail([string]$Message) {
    [Console]::Error.WriteLine("not ok: $Message")
    exit 1
}

$Matrix = Join-Path $root 'docs/agent-capability-matrix.md'
$Adr = Join-Path $root 'docs/adr/0003-turn-first-agent-routing.md'
$Policy = Join-Path $root 'plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md'
$Investigator = Join-Path $root 'plugins/sdd-bootstrap/agents/investigator.md'
$CopilotInvestigator = Join-Path $root 'plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md'
$Evaluator = Join-Path $root 'plugins/sdd-quality-loop/agents/evaluator.md'
$Registry = Join-Path $root 'contracts/agent-model-capabilities.json'
$RegistryV2 = Join-Path $root 'contracts/agent-model-capabilities.v2.json'
$SelectorPs = Join-Path $root 'plugins/sdd-implementation/scripts/select-agent-model.ps1'
$ResumePs = Join-Path $root 'plugins/sdd-implementation/scripts/check-terminal-tier-resume.ps1'
$BlockedStateSchema = Join-Path $root 'contracts/terminal-tier-blocked-state.schema.json'
$RiskPs = Join-Path $root 'plugins/sdd-quality-loop/scripts/check-risk.ps1'
$RunAllSh = Join-Path $root 'tests/run-all.sh'
$RunAllPs1 = Join-Path $root 'tests/run-all.ps1'

foreach ($file in @($Matrix, $Adr, $Policy, $Investigator, $CopilotInvestigator, $Evaluator,
        $Registry, $RegistryV2, $SelectorPs, $ResumePs, $BlockedStateSchema, $RiskPs)) {
    if (-not (Test-Path -LiteralPath $file)) {
        Fail "missing required routing artifact: $file"
    }
}

function Assert-Contains([string]$Path, [string]$Pattern, [string]$Message) {
    if (-not (Select-String -LiteralPath $Path -Pattern $Pattern -CaseSensitive -Quiet)) {
        Fail $Message
    }
}
function Assert-Literal([string]$Path, [string]$Text, [string]$Message) {
    if (-not (Select-String -LiteralPath $Path -Pattern $Text -SimpleMatch -CaseSensitive -Quiet)) {
        Fail $Message
    }
}

# Portable SHA-256 (mirrors tests/agent-capabilities-v2.tests.ps1's Get-FileHash
# convention). TEST-027 part (b): the LIVE .github/workflows/test.yml SHA-256
# captured BEFORE this suite does anything, compared again at the very end --
# this suite never opens the real, R-10 protected path for write.
$LiveTestYml = Join-Path $root '.github/workflows/test.yml'
$liveTestYmlShaBefore = (Get-FileHash -LiteralPath $LiveTestYml -Algorithm SHA256).Hash

foreach ($risk in @('low', 'medium', 'high', 'critical')) {
    Assert-Contains $Matrix "^\| $risk \|" "matrix missing $risk risk row"
}
Assert-Literal $Matrix '| low | 1 | 1 | 1 |' 'low risk matrix row must be 1/1/1'
Assert-Literal $Matrix '| medium | 2 | 1 | 1 |' 'medium risk matrix row must be 2/1/1'
Assert-Literal $Matrix '| high | 3 | 2 | 1 |' 'high risk matrix row must be 3/2/1'
Assert-Literal $Matrix '| critical | 3 | 2 | 1 |' 'critical risk matrix row must be 3/2/1'

Assert-Literal $Matrix 'Expected iterations are optimized first, then the weakest sufficient tier, then token price.' `
    'routing priority must put expected iterations before tier and token price'
Assert-Literal $Matrix 'estimated_cost_per_attempt_usd' 'routing must use invocation-supplied cost estimate'
Assert-Literal $Matrix 'cost_estimate_timestamp' 'routing must record cost estimate timestamp'
Assert-Literal $Matrix 'lexicographically smaller provider/model' 'routing must define lexical final tie-break'

foreach ($failure in @('test', 'lint', 'typecheck', 'build', 'review-major', 'review-critical')) {
    Assert-Literal $Matrix "``$failure``" "missing closed failure enum: $failure"
}
Assert-Literal $Matrix 'same classified failure occurs twice' 'same failure recurrence must be required before escalation'
Assert-Literal $Matrix 'different failure classes do not accumulate' 'different failure classes must not trigger escalation'
Assert-Literal $Matrix 'one-tier increase' 'escalation must advance exactly one tier'
Assert-Literal $Matrix 'terminal-tier-recurrence' 'strong recurrence must block with terminal-tier-recurrence'
Assert-Literal $Matrix 'check-terminal-tier-resume.sh' `
    'terminal-tier resume must use deterministic paired validation'
Assert-Literal $Matrix 'Deterministic parsing, validation, hashing, and state transitions use scripts rather than model routing.' `
    'deterministic operations must be excluded from model routing'
Assert-Literal $Matrix 'model-tier-unavailable' `
    'routing must fail closed when no availability-checked model satisfies a required tier'
Assert-Literal $Matrix 'canonical tier does not change' `
    'same-tier substitution must preserve canonical tier identity'
Assert-Literal $Matrix 'high effort is the default' `
    'strong Codex routing must prefer high before xhigh'

Assert-Literal $Matrix '| lightweight | Anthropic | Haiku |' 'lightweight Anthropic mapping must be Haiku'
Assert-Literal $Matrix '| standard | Anthropic | Sonnet |' 'standard Anthropic mapping must be Sonnet'
Assert-Literal $Matrix '| strong | Anthropic | Opus |' 'strong Anthropic mapping must be Opus'
Assert-Literal $Matrix '| lightweight | OpenAI/Codex | `gpt-5.1-codex-mini` | low |' `
    'lightweight Codex mapping must name gpt-5.1-codex-mini'
Assert-Literal $Matrix '| standard | OpenAI/Codex | `gpt-5.1-codex` | medium |' `
    'standard Codex mapping must name gpt-5.1-codex'
Assert-Literal $Matrix '| strong | OpenAI/Codex | `gpt-5.2-codex` (`gpt-5.1-codex-max` fallback) | high or xhigh |' `
    'strong Codex mapping must name gpt-5.2-codex and its fallback'

Assert-Literal $Matrix '| sdd-investigator | lightweight | Anthropic Haiku | OpenAI/Codex `gpt-5.1-codex-mini`, effort low |' `
    'investigator must be lightweight/Haiku with Codex low equivalent'
Assert-Literal $Matrix '| spec-reviewer-a/b | standard minimum | Anthropic Sonnet or stronger | OpenAI/Codex `gpt-5.1-codex`, effort medium or stronger |' `
    'spec reviewers must be at least standard/Sonnet'
Assert-Literal $Matrix '| impl-reviewer-a/b | standard minimum | Anthropic Sonnet or stronger | OpenAI/Codex `gpt-5.1-codex`, effort medium or stronger |' `
    'implementation reviewers must be at least standard/Sonnet'
Assert-Literal $Matrix '| task-reviewer-a/b | standard minimum | Anthropic Sonnet or stronger | OpenAI/Codex `gpt-5.1-codex`, effort medium or stronger |' `
    'task reviewers must be at least standard/Sonnet'
Assert-Literal $Matrix '| sdd-evaluator | strong | Anthropic Opus | OpenAI/Codex `gpt-5.2-codex` (`gpt-5.1-codex-max` fallback), effort high or xhigh |' `
    'evaluator must be strong/Opus with Codex high/xhigh equivalent'

Assert-Contains $Investigator '^model: haiku$' 'Claude investigator must be downgraded to Haiku'
Assert-Literal $CopilotInvestigator 'Model tier: lightweight' 'Copilot investigator must document lightweight tier'
Assert-Contains $Evaluator '^model: opus$' 'Claude evaluator must remain Opus'

Assert-Literal $Adr 'Turn-first routing optimizes expected iteration count before token price.' `
    'ADR must record turn-first routing decision'
Assert-Literal $Policy 'Apply the turn-first routing matrix before choosing an implementation model.' `
    'delegation policy must require turn-first routing'

# CI-resilience: mktemp root normalized (Resolve-Path) immediately after
# creation, mirroring `pwd -P` on the bash side.
$tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$tmp = (Resolve-Path $tmp).Path
try {

    $fallbackPath = Join-Path $tmp 'fallback.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":false,"effort":"high"},
  {"name":"openai/gpt-5.1-codex-max","cost":"0.09","available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $fallbackPath

    $unavailablePath = Join-Path $tmp 'unavailable.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":false,"effort":"high"},
  {"name":"openai/gpt-5.1-codex-max","cost":"0.09","available":false,"effort":"high"}
]
'@ | Set-Content -LiteralPath $unavailablePath

    $effortPath = Join-Path $tmp 'effort.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":true,"effort":"xhigh"},
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $effortPath

    $xhighOnlyPath = Join-Path $tmp 'xhigh-only.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":"0.08","available":true,"effort":"xhigh"}
]
'@ | Set-Content -LiteralPath $xhighOnlyPath

    $allTiersPath = Join-Path $tmp 'all-tiers.json'
    @'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $allTiersPath

    $scalarCandidatesPath = Join-Path $tmp 'scalar-candidates.json'
    '"not-an-array"' | Set-Content -LiteralPath $scalarCandidatesPath

    $booleanCostPath = Join-Path $tmp 'boolean-cost.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":true,"available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $booleanCostPath

    $exponentCostPath = Join-Path $tmp 'exponent-cost.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":"1e2","available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $exponentCostPath

    $numericCostPath = Join-Path $tmp 'numeric-cost.json'
    @'
[
  {"name":"openai/gpt-5.2-codex","cost":1,"available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $numericCostPath

    $ordinalRegistryPath = Join-Path $tmp 'ordinal-registry.json'
    @'
{
  "schema": "agent-model-capabilities/v1",
  "models": [
    {"name":"provider/Z","canonical_tier":"lightweight","efforts":["low"]},
    {"name":"provider/i","canonical_tier":"lightweight","efforts":["low"]}
  ]
}
'@ | Set-Content -LiteralPath $ordinalRegistryPath

    $ordinalCandidatesPath = Join-Path $tmp 'ordinal-candidates.json'
    @'
[
  {"name":"provider/i","cost":"0.01","available":true,"effort":"low"},
  {"name":"provider/Z","cost":"0.01","available":true,"effort":"low"}
]
'@ | Set-Content -LiteralPath $ordinalCandidatesPath

    $validRiskPath = Join-Path $tmp 'valid-risk.md'
    @'
## T-001 Example
Risk: high
Risk Policy Version: 1
Risk Impact: material
Risk Reversibility: controlled
Risk Surface: sensitive
Risk Rationale: Trusted workflow boundary.
Required Workflow: tdd
'@ | Set-Content -LiteralPath $validRiskPath

    $forgedRiskPath = Join-Path $tmp 'forged-risk.md'
    @'
## T-001 Example
Risk: low
Risk Policy Version: 1
Risk Impact: material
Risk Reversibility: controlled
Risk Surface: sensitive
Risk Rationale: Incorrectly downgraded.
Required Workflow: test-after
'@ | Set-Content -LiteralPath $forgedRiskPath

    & $RiskPs -TasksPath $validRiskPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Fail 'PowerShell risk precheck rejected policy-consistent structured risk'
    }
    & $RiskPs -TasksPath $forgedRiskPath | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Fail 'PowerShell risk precheck accepted policy-inconsistent risk'
    }

    # --- T-002/T-005: turn-first matrix + escalation/effort case matrix
    # (PowerShell-native half only) ------------------------------------

    $fallbackJson = & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $fallbackPath -RequiredTier strong -Json | ConvertFrom-Json
    if (-not ($fallbackJson.model -ceq 'openai/gpt-5.1-codex-max' -and
            $fallbackJson.canonical_tier -ceq 'strong' -and $fallbackJson.effort -ceq 'high')) {
        Fail 'PowerShell selector did not preserve strong tier on fallback'
    }

    $unavailableText = & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $unavailablePath -RequiredTier strong
    if ($unavailableText -cne 'BLOCKED model-tier-unavailable') {
        Fail 'PowerShell selector did not fail closed when the tier was unavailable'
    }

    try {
        & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $scalarCandidatesPath -RequiredTier strong -Json | Out-Null
        Fail 'PowerShell selector accepted a scalar candidate document'
    } catch { }

    foreach ($invalidCostPath in @($booleanCostPath, $exponentCostPath, $numericCostPath)) {
        try {
            & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $invalidCostPath -RequiredTier strong -Json | Out-Null
            Fail "PowerShell selector accepted non-canonical candidate cost ($invalidCostPath)"
        } catch { }
    }

    # Culture-hazard guard: force a non-ordinal culture (Swedish collation
    # differs from ordinal byte comparison) on THIS thread before calling
    # the in-process selector, proving its "lexicographically smaller
    # provider/model" tie-break stays ordinal/culture-invariant
    # (select-agent-model.ps1's own [StringComparer]::Ordinal.Compare use)
    # even under a hostile thread culture -- a PowerShell-only regression
    # class with no bash-side equivalent.
    $originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('sv-SE')
        $ordinalJson = & $SelectorPs -Risk low -Registry $ordinalRegistryPath -CandidatesFile $ordinalCandidatesPath -Json | ConvertFrom-Json
    } finally {
        [Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
    }
    if ($ordinalJson.model -cne 'provider/Z') {
        Fail 'PowerShell selector did not use ordinal provider/model tie-breaking'
    }

    $runtimeUnavailable = & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $allTiersPath `
        -DeterministicRuntimeCommand 'sdd-runtime-that-does-not-exist'
    if ($runtimeUnavailable -cne 'BLOCKED deterministic-runtime-unavailable') {
        Fail 'PowerShell selector did not directly fail closed for an unavailable deterministic runtime'
    }

    $effortSelectedJson = & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $effortPath -RequiredTier strong -Json | ConvertFrom-Json
    if (-not ($effortSelectedJson.model -ceq 'openai/gpt-5.2-codex' -and $effortSelectedJson.effort -ceq 'high' -and
            $null -eq $effortSelectedJson.xhigh_reason)) {
        Fail 'PowerShell selector did not prefer high effort before xhigh'
    }

    $xhighJson = & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $xhighOnlyPath -RequiredTier strong -Json `
        -XhighReason 'evaluator-contract' | ConvertFrom-Json
    if (-not ($xhighJson.canonical_tier -ceq 'strong' -and $xhighJson.effort -ceq 'xhigh' -and
            $xhighJson.xhigh_reason -ceq 'evaluator-contract' -and
            (@($xhighJson.available_candidates) -ccontains 'openai/gpt-5.2-codex'))) {
        Fail 'PowerShell selector did not record the availability-checked selection set'
    }

    foreach ($riskAndTier in @('low lightweight', 'medium standard', 'high strong', 'critical strong')) {
        $parts = $riskAndTier.Split(' ')
        $riskValue = $parts[0]
        $expectedTier = $parts[1]
        $selectedJson = & $SelectorPs -Risk $riskValue -Registry $Registry -CandidatesFile $allTiersPath -Json | ConvertFrom-Json
        if ($selectedJson.canonical_tier -cne $expectedTier) {
            Fail "PowerShell selector violated turn-first matrix for $riskValue"
        }
    }

    $differentJson = & $SelectorPs -Risk medium -Registry $Registry -CandidatesFile $allTiersPath `
        -PreviousTier standard -FailureHistory 'test,lint' -Json | ConvertFrom-Json
    $sameJson = & $SelectorPs -Risk medium -Registry $Registry -CandidatesFile $allTiersPath `
        -PreviousTier standard -FailureHistory 'test,test' -AttemptNumber 3 -Json | ConvertFrom-Json
    $oneTierJson = & $SelectorPs -Risk high -Registry $Registry -CandidatesFile $allTiersPath `
        -PreviousTier lightweight -FailureHistory 'test,test' -AttemptNumber 4 -Json | ConvertFrom-Json
    $terminalJson = & $SelectorPs -Risk high -Registry $Registry -CandidatesFile $allTiersPath `
        -PreviousTier strong -FailureHistory 'review-major,review-major' -AttemptNumber 5 -Json | ConvertFrom-Json
    $sameText = & $SelectorPs -Risk medium -Registry $Registry -CandidatesFile $allTiersPath `
        -PreviousTier standard -FailureHistory 'test,test' -AttemptNumber 3
    $terminalText = & $SelectorPs -Risk high -Registry $Registry -CandidatesFile $allTiersPath `
        -PreviousTier strong -FailureHistory 'review-major,review-major' -AttemptNumber 5
    try {
        & $SelectorPs -Risk medium -Registry $Registry -CandidatesFile $allTiersPath `
            -FailureHistory 'test,unknown' -Json | Out-Null
        Fail 'PowerShell selector accepted an unknown failure class'
    } catch { }

    if ($differentJson.canonical_tier -cne 'standard') {
        Fail 'PowerShell selector accumulated different failure classes'
    }
    if ($sameJson.canonical_tier -cne 'strong') {
        Fail 'PowerShell selector did not advance exactly one tier after recurrence'
    }
    if (-not ($sameJson.escalation.attempt_number -eq 3 -and $sameJson.escalation.failure_class -ceq 'test' -and
            $sameJson.escalation.next_tier -ceq 'strong' -and $sameJson.escalation.prior_tier -ceq 'standard' -and
            $sameJson.escalation.reason -ceq 'same-classified-failure-twice')) {
        Fail 'PowerShell selector omitted REQ-004 escalation audit fields'
    }
    if ($oneTierJson.canonical_tier -cne 'standard') {
        Fail 'PowerShell selector skipped a tier after lightweight recurrence'
    }
    if (-not ($terminalJson.status -ceq 'BLOCKED' -and $terminalJson.reason -ceq 'terminal-tier-recurrence' -and
            $null -eq $terminalJson.escalation.next_tier -and $terminalJson.escalation.prior_tier -ceq 'strong' -and
            $terminalJson.escalation.failure_class -ceq 'review-major' -and $terminalJson.escalation.attempt_number -eq 5)) {
        Fail 'PowerShell selector did not block terminal-tier recurrence'
    }
    $expectedSameText = 'openai/gpt-5.2-codex strong prior_tier=standard next_tier=strong failure_class=test attempt_number=3 reason=same-classified-failure-twice'
    if ($sameText -cne $expectedSameText) {
        Fail 'PowerShell selector omitted non-JSON escalation audit fields'
    }
    $expectedTerminalText = 'BLOCKED terminal-tier-recurrence prior_tier=strong next_tier=null failure_class=review-major attempt_number=5 reason=terminal-tier-recurrence'
    if ($terminalText -cne $expectedTerminalText) {
        Fail 'PowerShell selector omitted non-JSON terminal recurrence audit fields'
    }

    # --- T-002: selector v2 registry support, effort-resolution priority
    # (TEST-006..013, TEST-053, TEST-054) --------------------------------

    $realV2Json = & $SelectorPs -Risk low -Registry $RegistryV2 -CandidatesFile $allTiersPath -RequiredTier lightweight -Json | ConvertFrom-Json
    if (-not ($realV2Json.model -ceq 'openai/gpt-5.1-codex-mini' -and $realV2Json.effort_source -ceq 'welded')) {
        Fail 'PowerShell selector did not auto-detect the real v2 registry schema'
    }

    $v2RegistryPath = Join-Path $tmp 'v2-registry.json'
    @'
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
'@ | Set-Content -LiteralPath $v2RegistryPath

    $v2PartialMatrixRegistryPath = Join-Path $tmp 'v2-partial-matrix-registry.json'
    @'
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
'@ | Set-Content -LiteralPath $v2PartialMatrixRegistryPath

    $v2MalformedSupportedEffortsPath = Join-Path $tmp 'v2-malformed-supported-efforts.json'
    @'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":[],"default_effort":"low","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {}
}
'@ | Set-Content -LiteralPath $v2MalformedSupportedEffortsPath

    $v2MalformedEffortControlPath = Join-Path $tmp 'v2-malformed-effort-control.json'
    @'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"sometimes","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {}
}
'@ | Set-Content -LiteralPath $v2MalformedEffortControlPath

    $v2MalformedRiskMatrixPath = Join-Path $tmp 'v2-malformed-risk-matrix.json'
    @'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":3,"critical":"high","escalation_bump":true},
  "role_defaults": {}
}
'@ | Set-Content -LiteralPath $v2MalformedRiskMatrixPath

    $v2GoldenCandidatesPath = Join-Path $tmp 'v2-golden-candidates.json'
    @'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":true,"effort":"high"}
]
'@ | Set-Content -LiteralPath $v2GoldenCandidatesPath

    $v2GoldenCandidatesMutatedPath = Join-Path $tmp 'v2-golden-candidates-mutated.json'
    @'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":false,"effort":"high"}
]
'@ | Set-Content -LiteralPath $v2GoldenCandidatesMutatedPath

    $v2MatrixStandardCandidatesPath = Join-Path $tmp 'v2-matrix-standard-candidates.json'
    @'
[
  {"name":"anthropic/sonnet","cost":"0.02","available":true},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true}
]
'@ | Set-Content -LiteralPath $v2MatrixStandardCandidatesPath

    $v2ClampStandardCandidatePath = Join-Path $tmp 'v2-clamp-standard-candidate.json'
    @'
[
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true}
]
'@ | Set-Content -LiteralPath $v2ClampStandardCandidatePath

    $v2EscalationStrongCandidatePath = Join-Path $tmp 'v2-escalation-strong-candidate.json'
    @'
[
  {"name":"anthropic/opus","cost":"0.09","available":true}
]
'@ | Set-Content -LiteralPath $v2EscalationStrongCandidatePath

    $v2RoleMinTierCandidatesPath = Join-Path $tmp 'v2-role-min-tier-candidates.json'
    @'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true},
  {"name":"anthropic/opus","cost":"0.09","available":true}
]
'@ | Set-Content -LiteralPath $v2RoleMinTierCandidatesPath

    $v2RoleFallbackCandidatePath = Join-Path $tmp 'v2-role-fallback-candidate.json'
    @'
[
  {"name":"anthropic/haiku","cost":"0.01","available":true}
]
'@ | Set-Content -LiteralPath $v2RoleFallbackCandidatePath

    $v2RequestedOverrideCandidatePath = Join-Path $tmp 'v2-requested-override-candidate.json'
    @'
[
  {"name":"anthropic/sonnet","cost":"0.02","available":true}
]
'@ | Set-Content -LiteralPath $v2RequestedOverrideCandidatePath

    $v2RequestedClampCandidatePath = Join-Path $tmp 'v2-requested-clamp-candidate.json'
    @'
[
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true}
]
'@ | Set-Content -LiteralPath $v2RequestedClampCandidatePath

    $v2RequestedXhighCandidatePath = Join-Path $tmp 'v2-requested-xhigh-candidate.json'
    @'
[
  {"name":"anthropic/opus","cost":"0.09","available":true}
]
'@ | Set-Content -LiteralPath $v2RequestedXhighCandidatePath

    $v1OmitEffortCandidatePath = Join-Path $tmp 'v1-omit-effort-candidate.json'
    @'
[
  {"name":"anthropic/haiku","cost":"0.01","available":true}
]
'@ | Set-Content -LiteralPath $v1OmitEffortCandidatePath

    # TEST-006 (AC-006): v1 registry, incl. legacy positional -Candidate, is
    # byte-identical to the pre-feature baseline.
    $legacyText = & $SelectorPs -Risk low -Registry $Registry `
        -Candidate @('anthropic/haiku:lightweight:0.01', 'openai/gpt-5.1-codex-mini:lightweight:0.02')
    if ($legacyText -cne 'anthropic/haiku lightweight') {
        Fail 'TEST-006 legacy positional text output drifted from the pre-feature baseline'
    }
    $legacyJson = & $SelectorPs -Risk low -Registry $Registry `
        -Candidate @('anthropic/haiku:lightweight:0.01', 'openai/gpt-5.1-codex-mini:lightweight:0.02') -Json | ConvertFrom-Json
    if (-not ($legacyJson.model -ceq 'anthropic/haiku' -and $legacyJson.canonical_tier -ceq 'lightweight' -and
            $null -eq $legacyJson.effort -and $null -eq $legacyJson.escalation -and
            $legacyJson.estimated_cost_per_attempt_usd -ceq '0.01' -and $null -eq $legacyJson.xhigh_reason -and
            (@($legacyJson.available_candidates) -join ',') -ceq 'anthropic/haiku,openai/gpt-5.1-codex-mini' -and
            ($legacyJson.PSObject.Properties.Name -cnotcontains 'effort_source') -and
            ($legacyJson.PSObject.Properties.Name -cnotcontains 'effort_control'))) {
        Fail 'TEST-006 legacy positional JSON output drifted from the pre-feature baseline (no new keys allowed for v1)'
    }
    $v1GoldenText = & $SelectorPs -Risk high -Registry $Registry -CandidatesFile $allTiersPath
    if ($v1GoldenText -cne 'openai/gpt-5.2-codex strong') {
        Fail 'PowerShell TEST-006 v1 candidates-file text output drifted from the pre-feature baseline'
    }

    # TEST-007/TEST-028 (AC-007/AC-028): v2 registry, welded (default and
    # explicit), is byte-identical (TEXT-mode) to the SAME pre-feature
    # baseline TEST-006 just proved for v1; JSON mode separately proves the
    # two new keys are present and correctly attributed.
    $defaultPolicyText = & $SelectorPs -Risk high -Registry $v2RegistryPath -CandidatesFile $v2GoldenCandidatesPath
    $explicitWeldedText = & $SelectorPs -Risk high -Registry $v2RegistryPath -CandidatesFile $v2GoldenCandidatesPath -EffortPolicy welded
    if ($defaultPolicyText -cne 'openai/gpt-5.2-codex strong') {
        Fail 'TEST-007/TEST-028 v2 welded (default policy) text output diverged from the v1 golden baseline'
    }
    if ($explicitWeldedText -cne 'openai/gpt-5.2-codex strong') {
        Fail 'TEST-007/TEST-028 v2 welded (explicit policy) text output diverged from the v1 golden baseline'
    }
    $weldedJson = & $SelectorPs -Risk high -Registry $v2RegistryPath -CandidatesFile $v2GoldenCandidatesPath -Json | ConvertFrom-Json
    if (-not ($weldedJson.model -ceq 'openai/gpt-5.2-codex' -and $weldedJson.canonical_tier -ceq 'strong' -and
            $weldedJson.effort -ceq 'high' -and $weldedJson.estimated_cost_per_attempt_usd -ceq '0.03' -and
            $weldedJson.effort_source -ceq 'welded' -and $weldedJson.effort_control -ceq 'none' -and
            $null -eq $weldedJson.xhigh_reason -and $null -eq $weldedJson.escalation)) {
        Fail 'TEST-007/TEST-012 v2 welded JSON output missing correct additive keys or mutated an existing key'
    }

    # Negative canary (mutation-based self-check): the previous winner is
    # unavailable in the mutated fixture -- confirm the TEXT-mode
    # comparison actually goes red, proving the byte-identical assertion
    # above is discriminating, not vacuously true.
    $mutatedText = & $SelectorPs -Risk high -Registry $v2RegistryPath -CandidatesFile $v2GoldenCandidatesMutatedPath
    if ($mutatedText -ceq $defaultPolicyText) {
        Fail 'TEST-007/TEST-028 negative canary: mutated golden fixture did not change output (comparison is vacuous)'
    }
    if ($mutatedText -cne 'openai/gpt-5.1-codex standard') {
        Fail 'TEST-007/TEST-028 negative canary produced an unexpected fallback winner'
    }

    # TEST-008/TEST-029 (AC-008/AC-029): matrix policy risk-based selection
    # picks sonnet at high effort.
    $matrixJson = & $SelectorPs -Risk high -Registry $v2RegistryPath -CandidatesFile $v2MatrixStandardCandidatesPath `
        -EffortPolicy matrix -RequiredTier standard -Json | ConvertFrom-Json
    if (-not ($matrixJson.model -ceq 'anthropic/sonnet' -and $matrixJson.effort -ceq 'high' -and
            $matrixJson.effort_source -ceq 'risk-matrix')) {
        Fail 'TEST-008/TEST-029 matrix policy did not select sonnet at high effort'
    }

    # TEST-009/TEST-030 (AC-009/AC-030): a matrix-selected effort outside
    # the winning model's supported_efforts clamps to the nearest supported
    # value.
    $clampJson = & $SelectorPs -Risk critical -Registry $v2RegistryPath -CandidatesFile $v2ClampStandardCandidatePath `
        -EffortPolicy matrix -RequiredTier standard -Json | ConvertFrom-Json
    if (-not ($clampJson.model -ceq 'openai/gpt-5.1-codex' -and $clampJson.effort -ceq 'medium' -and
            $clampJson.effort_source -ceq 'risk-matrix')) {
        Fail 'TEST-009/TEST-030 matrix-selected effort outside supported_efforts did not clamp'
    }

    # TEST-009/TEST-031 (AC-009/AC-031, escalation half): an
    # escalation-bumped matrix selection that lands on xhigh still requires
    # -XhighReason.
    $escalationBlocked = & $SelectorPs -Risk critical -Registry $v2RegistryPath -CandidatesFile $v2EscalationStrongCandidatePath `
        -EffortPolicy matrix -PreviousTier standard -FailureHistory 'review-major,review-major' -AttemptNumber 3
    if ($escalationBlocked -cne 'BLOCKED model-tier-unavailable') {
        Fail 'TEST-009/TEST-031 escalation-bumped xhigh selection was not gated without -XhighReason'
    }
    $escalationJson = & $SelectorPs -Risk critical -Registry $v2RegistryPath -CandidatesFile $v2EscalationStrongCandidatePath `
        -EffortPolicy matrix -PreviousTier standard -FailureHistory 'review-major,review-major' -AttemptNumber 3 `
        -XhighReason 'escalation-bump-accepted' -Json | ConvertFrom-Json
    if (-not ($escalationJson.model -ceq 'anthropic/opus' -and $escalationJson.effort -ceq 'xhigh' -and
            $escalationJson.effort_source -ceq 'risk-matrix' -and
            $escalationJson.xhigh_reason -ceq 'escalation-bump-accepted')) {
        Fail 'TEST-009/TEST-031 escalation-bumped xhigh selection did not succeed with -XhighReason'
    }

    # TEST-010 (AC-010): -RequestedEffort overrides the policy-selected
    # effort under matrix, still clamped, still xhigh-gated.
    $requestedOverrideJson = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2RequestedOverrideCandidatePath `
        -EffortPolicy matrix -RequestedEffort high -Json | ConvertFrom-Json
    if (-not ($requestedOverrideJson.model -ceq 'anthropic/sonnet' -and $requestedOverrideJson.effort -ceq 'high' -and
            $requestedOverrideJson.effort_source -ceq 'requested')) {
        Fail 'TEST-010 -RequestedEffort did not override matrix policy selection'
    }
    $requestedClampJson = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2RequestedClampCandidatePath `
        -EffortPolicy matrix -RequestedEffort xhigh -Json | ConvertFrom-Json
    if (-not ($requestedClampJson.model -ceq 'openai/gpt-5.1-codex' -and $requestedClampJson.effort -ceq 'medium' -and
            $requestedClampJson.effort_source -ceq 'requested')) {
        Fail 'TEST-010 -RequestedEffort was not clamped to supported_efforts'
    }
    $requestedXhighBlocked = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2RequestedXhighCandidatePath `
        -EffortPolicy matrix -RequestedEffort xhigh
    if ($requestedXhighBlocked -cne 'BLOCKED model-tier-unavailable') {
        Fail 'TEST-010 -RequestedEffort xhigh was not gated without -XhighReason'
    }

    # TEST-011/TEST-033 (AC-011/AC-033): -Role always seeds -MinimumTier
    # (both policies); under matrix with a risk_effort_matrix gap, -Role
    # additionally seeds a role-default effort; under welded, -Role's
    # effort component is inert.
    $roleMinTierJson = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2RoleMinTierCandidatesPath `
        -EffortPolicy matrix -Role sdd-evaluator -Json | ConvertFrom-Json
    if (-not ($roleMinTierJson.model -ceq 'anthropic/opus' -and $roleMinTierJson.canonical_tier -ceq 'strong' -and
            $roleMinTierJson.effort -ceq 'high')) {
        Fail 'TEST-011/TEST-033 -Role did not seed -MinimumTier'
    }
    $roleDefaultJson = & $SelectorPs -Risk high -Registry $v2PartialMatrixRegistryPath -CandidatesFile $v2RoleFallbackCandidatePath `
        -EffortPolicy matrix -Role sdd-investigator -Json | ConvertFrom-Json
    if (-not ($roleDefaultJson.model -ceq 'anthropic/haiku' -and $roleDefaultJson.effort -ceq 'low' -and
            $roleDefaultJson.effort_source -ceq 'role-default')) {
        Fail 'TEST-011 -Role did not seed a role-default fallback effort when risk_effort_matrix had no entry'
    }
    $weldedWithRoleText = & $SelectorPs -Risk high -Registry $v2RegistryPath -CandidatesFile $v2GoldenCandidatesPath -Role sdd-investigator
    if ($weldedWithRoleText -cne $defaultPolicyText) {
        Fail "TEST-011 -Role's effort component was not inert under welded policy"
    }

    # TEST-012 (AC-012): -HostName resolves effort_control; effort_source
    # 5-way attribution; every pre-existing JSON key stays present and
    # correctly typed alongside the two additive keys.
    $modelDefaultJson = & $SelectorPs -Risk high -Registry $v2PartialMatrixRegistryPath -CandidatesFile $v2RoleFallbackCandidatePath `
        -EffortPolicy matrix -Json | ConvertFrom-Json
    if (-not ($modelDefaultJson.model -ceq 'anthropic/haiku' -and $modelDefaultJson.effort -ceq 'low' -and
            $modelDefaultJson.effort_source -ceq 'model-default')) {
        Fail "TEST-012 matrix policy did not fall back to the winning model's own default_effort"
    }
    $hostCodexJson = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2RequestedClampCandidatePath `
        -HostName codex-cli -Json | ConvertFrom-Json
    if ($hostCodexJson.effort_control -cne 'flag') {
        Fail 'TEST-012 -HostName codex-cli did not resolve the flag effort_control'
    }
    $expectedKeys = @('model', 'canonical_tier', 'effort', 'estimated_cost_per_attempt_usd',
        'available_candidates', 'xhigh_reason', 'escalation', 'effort_source', 'effort_control')
    $actualKeys = @($hostCodexJson.PSObject.Properties.Name)
    foreach ($key in $expectedKeys) {
        if ($actualKeys -cnotcontains $key) {
            Fail "TEST-012 v2 JSON output is missing key: $key"
        }
    }
    if (@($hostCodexJson.available_candidates) -isnot [Array]) {
        Fail 'TEST-012 v2 JSON output available_candidates is not an array'
    }

    # TEST-013 (AC-013): a v2 -CandidatesFile entry may omit effort (the
    # selector fills it via policy); a v1 -CandidatesFile still requires
    # effort and rejects its absence exactly as today.
    try {
        & $SelectorPs -Risk low -Registry $Registry -CandidatesFile $v1OmitEffortCandidatePath -Json | Out-Null
        Fail 'TEST-013 v1 -CandidatesFile accepted a candidate omitting effort'
    } catch { }
    $v2OmitJson = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v1OmitEffortCandidatePath -Json | ConvertFrom-Json
    if (-not ($v2OmitJson.model -ceq 'anthropic/haiku' -and $v2OmitJson.effort -ceq 'low' -and
            $v2OmitJson.effort_source -ceq 'welded')) {
        Fail 'TEST-013 v2 -CandidatesFile did not fill an omitted effort via policy'
    }

    # TEST-053 (AC-053): -RequestedEffort under welded (or no policy flag)
    # applies the requested value, effort_source: "requested" -- provably
    # outside TEST-007/TEST-028's golden-comparison set: none of the golden
    # invocations above ever supply -RequestedEffort.
    $weldedRequestedJson = & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2RequestedOverrideCandidatePath `
        -RequestedEffort high -Json | ConvertFrom-Json
    if (-not ($weldedRequestedJson.model -ceq 'anthropic/sonnet' -and $weldedRequestedJson.effort -ceq 'high' -and
            $weldedRequestedJson.effort_source -ceq 'requested')) {
        Fail 'TEST-053 -RequestedEffort under welded did not apply the requested value'
    }

    # TEST-054 (AC-054): each malformed v2 field category is rejected
    # fail-closed with a MODEL_SELECTION_ERROR-class diagnostic and no
    # candidate selected.
    foreach ($malformedPath in @($v2MalformedSupportedEffortsPath, $v2MalformedEffortControlPath, $v2MalformedRiskMatrixPath)) {
        $threw = $false
        $message = ''
        try {
            & $SelectorPs -Risk low -Registry $malformedPath -CandidatesFile $v1OmitEffortCandidatePath -Json | Out-Null
        } catch {
            $threw = $true
            $message = $_.Exception.Message
        }
        if (-not $threw) {
            Fail "TEST-054 $malformedPath did not throw"
        }
        if ($message -cnotmatch '^MODEL_SELECTION_ERROR:') {
            Fail "TEST-054 $malformedPath did not emit a MODEL_SELECTION_ERROR-class diagnostic (got: $message)"
        }
    }

    # PowerShell case-sensitivity hazard guard (2 layers): layer 1 is every
    # comparison above using -ceq/-cne/-ccontains plus ordinal
    # (case-sensitive) Dictionary lookups inside select-agent-model.ps1
    # itself for untrusted model-name/risk-key strings, rather than a bare
    # `@{}` hashtable (which PowerShell resolves case-INSENSITIVELY by
    # default and would let a mis-cased value silently alias a
    # correctly-cased one); layer 2 is this mis-cased negative fixture
    # pair, proving the guard is live, not merely asserted by construction.
    $v2MisCasedEffortControlPath = Join-Path $tmp 'v2-mis-cased-effort-control.json'
    @'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {"name":"anthropic/haiku","canonical_tier":"lightweight","supported_efforts":["low"],"default_effort":"low","effort_control":{"claude-code":"Frontmatter","codex-cli":"none"}}
  ],
  "risk_effort_matrix": {"low":"low","medium":"medium","high":"high","critical":"high","escalation_bump":true},
  "role_defaults": {}
}
'@ | Set-Content -LiteralPath $v2MisCasedEffortControlPath

    $v2MisCasedCandidatePath = Join-Path $tmp 'v2-mis-cased-candidate.json'
    @'
[
  {"name":"Anthropic/Haiku","cost":"0.01","available":true}
]
'@ | Set-Content -LiteralPath $v2MisCasedCandidatePath

    try {
        & $SelectorPs -Risk low -Registry $v2MisCasedEffortControlPath -CandidatesFile $v1OmitEffortCandidatePath -Json | Out-Null
        Fail 'PowerShell selector accepted a mis-cased effort_control value (Frontmatter, not frontmatter)'
    } catch { }
    try {
        & $SelectorPs -Risk low -Registry $v2RegistryPath -CandidatesFile $v2MisCasedCandidatePath -Json | Out-Null
        Fail "PowerShell selector case-insensitively matched a mis-cased candidate model name (Anthropic/Haiku) against the registry's anthropic/haiku"
    } catch { }

    # --- T-005 (#154): REQ-005 case (h), not already covered above -------
    # TEST-034 (AC-034): v1<->v2 projection invariant -- the SAME candidate
    # set and risk/tier input, run against the REAL v1 registry and the
    # REAL v2 registry (welded, the Phase-1 default), select the identical
    # winning model and canonical_tier, with effort_source correctly
    # attributed "welded" (shares fixtures with
    # tests/agent-capabilities-v2.tests.ps1's TEST-004 registry-content
    # parity lock; this is the same invariant re-asserted at the
    # select-agent-model.ps1 OUTPUT level).
    foreach ($riskAndTier in @('low lightweight', 'medium standard', 'high strong')) {
        $parts = $riskAndTier.Split(' ')
        $projRisk = $parts[0]
        $projTier = $parts[1]
        $v1Projection = & $SelectorPs -Risk $projRisk -Registry $Registry -CandidatesFile $allTiersPath -RequiredTier $projTier -Json | ConvertFrom-Json
        $v2Projection = & $SelectorPs -Risk $projRisk -Registry $RegistryV2 -CandidatesFile $allTiersPath -RequiredTier $projTier -Json | ConvertFrom-Json
        if (-not ($v1Projection.model -ceq $v2Projection.model -and
                $v1Projection.canonical_tier -ceq $v2Projection.canonical_tier -and
                $v2Projection.effort_source -ceq 'welded')) {
            Fail "TEST-034 v1<->v2 projection diverged for risk=$projRisk tier=$projTier (v1=$($v1Projection.model)/$($v1Projection.canonical_tier) v2=$($v2Projection.model)/$($v2Projection.canonical_tier))"
        }
    }

    # --- Terminal-tier resume validator (T-001 fixture, ported unedited) --
    $resumeRepoRoot = Join-Path $tmp 'resume-repo'
    New-Item -ItemType Directory -Path (Join-Path $resumeRepoRoot 'diagnostics') -Force | Out-Null
    $diagnosisPath = Join-Path $resumeRepoRoot 'diagnostics/T-900.md'
    @'
# Diagnosis

The repeated review-major failure was caused by a stale task boundary.
'@ | Set-Content -LiteralPath $diagnosisPath

    $tasksPath = Join-Path $resumeRepoRoot 'tasks.md'
    @'
# Tasks

## T-900 Resume fixture

Approval: Approved (human reapproval)

Status: Planned

Diagnosis Reference: diagnostics/T-900.md

Terminal Reapproval: release-owner @ 2026-06-30T03:00:00Z
'@ | Set-Content -LiteralPath $tasksPath

    $blockedContractHash = 'a' * 64
    $blockedStatePath = Join-Path $resumeRepoRoot 'blocked-state.json'
    @"
{
  "schema": "terminal-tier-blocked-state/v1",
  "task_id": "T-900",
  "blocked_task_contract_sha256": "$blockedContractHash",
  "tier": "strong",
  "failure_class": "review-major",
  "attempt_number": 2,
  "reason": "terminal-tier-recurrence",
  "blocked_at": "2026-06-30T02:00:00Z"
}
"@ | Set-Content -LiteralPath $blockedStatePath

    $blockedStateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $blockedStatePath).Hash.ToLowerInvariant()

    # Section-hash algorithm mirrors check-terminal-tier-resume.ps1's own
    # validation logic exactly (the SAME regex, TrimEnd, and UTF8-no-BOM
    # SHA256 computation), since that script IS the authority this fixture
    # must satisfy.
    $tasksText = Get-Content -Raw -LiteralPath $tasksPath
    $sectionMatch = [regex]::Match($tasksText, '(?ms)^## T-900\b.*?(?=^## T-[0-9]{3}\b|\z)')
    if (-not $sectionMatch.Success) { Fail 'resume fixture: T-900 section not found in tasks.md' }
    $sectionContract = $sectionMatch.Value.TrimEnd([char[]]"`r`n")
    $resumeTasksHash = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.UTF8Encoding]::new($false).GetBytes($sectionContract))).ToLowerInvariant()
    $resumeDiagnosisHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $diagnosisPath).Hash.ToLowerInvariant()

    $resumePath = Join-Path $tmp 'resume.json'
    @"
{
  "schema": "terminal-tier-resume/v1",
  "task_id": "T-900",
  "blocked_state_reference": {
    "path": "blocked-state.json",
    "sha256": "$blockedStateHash"
  },
  "blocked_task_contract_sha256": "$blockedContractHash",
  "revised_task_contract_sha256": "$resumeTasksHash",
  "diagnosis_reference": {
    "path": "diagnostics/T-900.md",
    "sha256": "$resumeDiagnosisHash"
  },
  "human_reapproval": {
    "authority": "release-owner",
    "timestamp": "2026-06-30T03:00:00Z"
  }
}
"@ | Set-Content -LiteralPath $resumePath

    $resumeJsonObject = Get-Content -Raw -LiteralPath $resumePath | ConvertFrom-Json

    try {
        & $ResumePs -Evidence $resumePath -BlockedState $blockedStatePath -Tasks $tasksPath `
            -RepoRoot $resumeRepoRoot -ExpectedTask T-900 | Out-Null
    } catch {
        Fail "PowerShell terminal-resume validator rejected complete human evidence: $($_.Exception.Message)"
    }

    $resumeUnchangedPath = Join-Path $tmp 'resume-unchanged.json'
    $resumeUnchanged = $resumeJsonObject | Select-Object *
    $resumeUnchanged.blocked_task_contract_sha256 = $resumeUnchanged.revised_task_contract_sha256
    ($resumeUnchanged | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $resumeUnchangedPath
    try {
        & $ResumePs -Evidence $resumeUnchangedPath -Tasks $tasksPath -RepoRoot $resumeRepoRoot `
            -BlockedState $blockedStatePath -ExpectedTask T-900 | Out-Null
        Fail 'PowerShell terminal-resume validator accepted an unchanged task contract'
    } catch { }

    Add-Content -LiteralPath $tasksPath -Value @'


## T-901 Unrelated fixture

Approval: Approved

Status: Planned
'@
    try {
        & $ResumePs -Evidence $resumePath -BlockedState $blockedStatePath -Tasks $tasksPath `
            -RepoRoot $resumeRepoRoot -ExpectedTask T-900 | Out-Null
    } catch {
        Fail "PowerShell terminal-resume validator bound the hash to unrelated tasks: $($_.Exception.Message)"
    }

    $resumeForgedBlockedHashPath = Join-Path $tmp 'resume-forged-blocked-hash.json'
    $resumeForgedBlockedHash = $resumeJsonObject | Select-Object *
    $resumeForgedBlockedHash.blocked_task_contract_sha256 = 'f' * 64
    ($resumeForgedBlockedHash | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $resumeForgedBlockedHashPath
    try {
        & $ResumePs -Evidence $resumeForgedBlockedHashPath -BlockedState $blockedStatePath -Tasks $tasksPath `
            -RepoRoot $resumeRepoRoot -ExpectedTask T-900 | Out-Null
        Fail 'PowerShell terminal-resume validator accepted a forged blocked contract hash'
    } catch { }

    $resumeFractionalTimePath = Join-Path $tmp 'resume-fractional-time.json'
    $resumeFractionalTime = $resumeJsonObject | Select-Object *
    $resumeFractionalTime.human_reapproval = [pscustomobject]@{
        authority = $resumeFractionalTime.human_reapproval.authority
        timestamp = '2026-06-30T03:00:00.123Z'
    }
    ($resumeFractionalTime | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $resumeFractionalTimePath
    try {
        & $ResumePs -Evidence $resumeFractionalTimePath -BlockedState $blockedStatePath -Tasks $tasksPath `
            -RepoRoot $resumeRepoRoot -ExpectedTask T-900 | Out-Null
        Fail 'PowerShell terminal-resume validator accepted a fractional-second timestamp'
    } catch { }

    # Parent-directory symlink escape (graceful degradation: some Windows
    # CI runners deny unprivileged symlink creation -- skip this specific
    # negative-path leg rather than failing the whole suite, mirroring
    # tests/phase2-guard-invariants.tests.ps1's Try-NewFixtureSymbolicLink
    # convention).
    function Try-NewFixtureSymbolicLink([string]$Path, [string]$Target) {
        try {
            New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
            return $true
        } catch { return $false }
    }
    $diagnosticsDir = Join-Path $resumeRepoRoot 'diagnostics'
    $outsideDiagnosticsDir = Join-Path $tmp 'outside-diagnostics'
    Move-Item -LiteralPath $diagnosticsDir -Destination $outsideDiagnosticsDir
    if (Try-NewFixtureSymbolicLink $diagnosticsDir $outsideDiagnosticsDir) {
        try {
            & $ResumePs -Evidence $resumePath -BlockedState $blockedStatePath -Tasks $tasksPath `
                -RepoRoot $resumeRepoRoot -ExpectedTask T-900 | Out-Null
            Fail 'PowerShell terminal-resume validator accepted a parent-directory symlink escape'
        } catch { }
        Remove-Item -LiteralPath $diagnosticsDir -Force
    } else {
        Write-Output 'SKIP: parent-directory symlink escape leg (unprivileged symlink creation denied on this host)'
    }
    Move-Item -LiteralPath $outsideDiagnosticsDir -Destination $diagnosticsDir

    Add-Content -LiteralPath $diagnosisPath -Value "`nTampered diagnosis.`n"
    try {
        & $ResumePs -Evidence $resumePath -BlockedState $blockedStatePath -Tasks $tasksPath `
            -RepoRoot $resumeRepoRoot -ExpectedTask T-900 | Out-Null
        Fail 'PowerShell terminal-resume validator accepted a forged diagnosis hash'
    } catch { }

    # --- TEST-027 (AC-027): twin existence + self-registration + staged
    # .github/workflows/test.yml candidate/manifest consistency + live-file
    # byte-identity during this suite's own run (three-part protected-file
    # registration proof). Part (c) -- the post-human-copy self-registration
    # grep against the now-updated LIVE file -- can only hold true after a
    # human applies the staged candidate via cp; it is recorded as a
    # report note in reports/implementation/epic-159-pillar-c/T-005.md, not
    # asserted here (this suite never writes .github/workflows/test.yml).
    if (-not (Test-Path -LiteralPath $PSCommandPath)) {
        Fail 'TEST-027 tests/agent-model-routing.tests.ps1 twin does not exist'
    }
    if (-not (Select-String -LiteralPath $RunAllSh -Pattern 'tests/agent-model-routing\.tests\.sh' -CaseSensitive -Quiet)) {
        Fail 'TEST-027 tests/agent-model-routing.tests.sh not registered in tests/run-all.sh'
    }
    if (-not (Select-String -LiteralPath $RunAllPs1 -Pattern 'tests/agent-model-routing\.tests\.ps1' -CaseSensitive -Quiet)) {
        Fail 'TEST-027 tests/agent-model-routing.tests.ps1 not registered in tests/run-all.ps1'
    }

    $stagedTestYml = Join-Path $root 'specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml'
    $manifest = Join-Path $root 'specs/epic-159-pillar-c/human-copy/MANIFEST.sha256'
    if ((Test-Path -LiteralPath $stagedTestYml) -and (Test-Path -LiteralPath $manifest)) {
        $stagedSha = (Get-FileHash -LiteralPath $stagedTestYml -Algorithm SHA256).Hash.ToLowerInvariant()
        if (-not (Select-String -LiteralPath $manifest -Pattern "$stagedSha  \.github/workflows/test\.yml" -CaseSensitive -Quiet)) {
            Fail 'TEST-027(a) staged test.yml candidate SHA-256 does not match MANIFEST.sha256'
        }
        if (-not (Select-String -LiteralPath $stagedTestYml -Pattern 'agent-model-routing\.tests\.sh' -CaseSensitive -Quiet)) {
            Fail 'TEST-027(a) staged test.yml candidate does not register agent-model-routing.tests.sh'
        }
        if (-not (Select-String -LiteralPath $stagedTestYml -Pattern 'agent-model-routing\.tests\.ps1' -CaseSensitive -Quiet)) {
            Fail 'TEST-027(a) staged test.yml candidate does not register agent-model-routing.tests.ps1'
        }
    } else {
        Fail 'TEST-027(a) staged test.yml candidate or MANIFEST.sha256 is missing'
    }

    $liveTestYmlShaAfter = (Get-FileHash -LiteralPath $LiveTestYml -Algorithm SHA256).Hash
    if ($liveTestYmlShaAfter -cne $liveTestYmlShaBefore) {
        Fail "TEST-027(b) live .github/workflows/test.yml SHA-256 CHANGED during this suite's own run (before=$liveTestYmlShaBefore after=$liveTestYmlShaAfter)"
    }

} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'ok: turn-first model routing structure is defined (PowerShell twin)'
