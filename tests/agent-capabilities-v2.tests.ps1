# Suite: agent-capabilities-v2 (T-001, #149) -- REQ-001 / AC-001..AC-005.
# PowerShell twin of tests/agent-capabilities-v2.tests.sh, equivalent
# coverage. Locks the shape of contracts/agent-model-capabilities.v2.json
# (schema `agent-model-capabilities/v2`) and the two-directional v1<->v2
# parity invariant against the FROZEN v1 file
# (contracts/agent-model-capabilities.json), never opened for write.
#
# Case-sensitivity (two layers, mirroring the operator- and cmdlet-level
# discipline this repository's other .ps1 twins apply):
#   1. Operator level: every string comparison below uses the `-ceq`/`-cne`
#      case-sensitive operators (schema strings, effort tokens, and model
#      names are case-sensitive contract values -- "Medium" must not match
#      "medium").
#   2. Cmdlet level: `Select-String -CaseSensitive` is used for the
#      PLUGIN-CONTRACTS.md / run-all.ps1 / MANIFEST.sha256 text greps.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$v1Path = Join-Path $repoRoot "contracts/agent-model-capabilities.json"
$v2Path = Join-Path $repoRoot "contracts/agent-model-capabilities.v2.json"
$pluginContracts = Join-Path $repoRoot "PLUGIN-CONTRACTS.md"
$runAllSh = Join-Path $repoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$stagedTestYml = Join-Path $repoRoot "specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml"
$manifest = Join-Path $repoRoot "specs/epic-159-pillar-c/human-copy/MANIFEST.sha256"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "not ok: $Name"; $script:failCount++ }

if (-not (Test-Path -LiteralPath $v1Path)) {
    Write-Output "not ok: v1 registry missing at $v1Path"
    exit 1
}
$v1ShaBefore = (Get-FileHash -LiteralPath $v1Path -Algorithm SHA256).Hash

if (-not (Test-Path -LiteralPath $v2Path)) {
    Fail "TEST-001: contracts/agent-model-capabilities.v2.json does not exist"
    Write-Output ""
    Write-Output "agent-capabilities-v2.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
    exit 1
}

$validEffortControl = @("flag", "frontmatter", "none")

function Test-SchemaShape {
    param([Parameter(Mandatory)][string]$Path)
    $data = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $errors = @()

    if (-not ($data.schema -ceq "agent-model-capabilities/v2")) {
        $errors += "schema must be 'agent-model-capabilities/v2', got '$($data.schema)'"
    }

    $models = @($data.models)
    if ($models.Count -eq 0) {
        $errors += "models must be a non-empty array"
    }

    foreach ($m in $models) {
        $name = $m.name
        $supported = @($m.supported_efforts)
        if ($supported.Count -eq 0) {
            $errors += "$($name): supported_efforts must be a non-empty array"
        }
        $defaultEffort = $m.default_effort
        $isMember = $false
        foreach ($e in $supported) { if ($e -ceq $defaultEffort) { $isMember = $true } }
        if (-not $isMember) {
            $errors += "$($name): default_effort '$defaultEffort' must be a member of supported_efforts"
        }
        $control = $m.effort_control
        if ($null -eq $control) {
            $errors += "$($name): effort_control must be an object"
        } else {
            foreach ($host_ in @("claude-code", "codex-cli")) {
                $value = $control.$host_
                $validMatch = $false
                foreach ($v in $validEffortControl) { if ($v -ceq $value) { $validMatch = $true } }
                if (-not $validMatch) {
                    $errors += "$($name): effort_control.$host_ = '$value' must be one of flag/frontmatter/none"
                }
            }
        }
    }
    return $errors
}

function Test-RiskMatrix {
    param([Parameter(Mandatory)][string]$Path)
    $data = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $errors = @()
    $matrix = $data.risk_effort_matrix
    if ($null -eq $matrix) {
        return @("risk_effort_matrix must be an object")
    }

    $expected = [ordered]@{ low = "low"; medium = "medium"; high = "high"; critical = "high" }
    foreach ($risk in $expected.Keys) {
        $actual = $matrix.$risk
        if (-not ($actual -ceq $expected[$risk])) {
            $errors += "risk_effort_matrix.$risk must be '$($expected[$risk])', got '$actual'"
        }
    }
    if ($matrix.escalation_bump -ne $true) {
        $errors += "risk_effort_matrix.escalation_bump must be true, got '$($matrix.escalation_bump)'"
    }
    foreach ($risk in @("low", "medium", "high", "critical")) {
        if ($matrix.$risk -ceq "xhigh") {
            $errors += "risk_effort_matrix.$risk must never map directly to xhigh"
        }
    }
    return $errors
}

function Test-RoleDefaults {
    param([Parameter(Mandatory)][string]$Path)
    $data = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $errors = @()
    $roleDefaults = $data.role_defaults
    if ($null -eq $roleDefaults) {
        return @("role_defaults must be an object")
    }

    $requiredRoles = @("spec-reviewer", "impl-reviewer", "task-reviewer", "sdd-evaluator", "sdd-investigator")
    foreach ($role in $requiredRoles) {
        $entry = $roleDefaults.$role
        if ($null -eq $entry) {
            $errors += "role_defaults.$role must be an object"
            continue
        }
        if ([string]::IsNullOrEmpty($entry.minimum_tier)) {
            $errors += "role_defaults.$role.minimum_tier must be present"
        }
        if ([string]::IsNullOrEmpty($entry.default_effort)) {
            $errors += "role_defaults.$role.default_effort must be present"
        }
    }
    return $errors
}

function Test-Parity {
    param([Parameter(Mandatory)][string]$V1Path, [Parameter(Mandatory)][string]$V2Path)
    $v1 = Get-Content -Raw -LiteralPath $V1Path | ConvertFrom-Json
    $v2 = Get-Content -Raw -LiteralPath $V2Path | ConvertFrom-Json
    $errors = @()

    $v2ByName = @{}
    foreach ($m in @($v2.models)) { $v2ByName[[string]$m.name] = $m }

    foreach ($m in @($v1.models)) {
        $name = [string]$m.name
        $tier = $m.canonical_tier
        $v1Efforts = @($m.efforts)
        if (-not $v2ByName.ContainsKey($name)) {
            $errors += "v1 model '$name' is missing from v2"
            continue
        }
        $v2Model = $v2ByName[$name]
        if (-not ($v2Model.canonical_tier -ceq $tier)) {
            $errors += "$($name): canonical_tier mismatch v1='$tier' v2='$($v2Model.canonical_tier)'"
        }
        $v2Supported = @($v2Model.supported_efforts)
        foreach ($effort in $v1Efforts) {
            $found = $false
            foreach ($se in $v2Supported) { if ($se -ceq $effort) { $found = $true } }
            if (-not $found) {
                $errors += "$($name): v1 effort '$effort' not present in v2 supported_efforts"
            }
        }
    }
    return $errors
}

# --- TEST-001 (AC-001) ------------------------------------------------------
$errs = Test-SchemaShape -Path $v2Path
if ($errs.Count -eq 0) {
    Ok "TEST-001: v2 schema field + per-model supported_efforts/default_effort/effort_control shape"
} else {
    Fail "TEST-001: v2 schema shape violated -- $($errs -join '; ')"
}

# --- TEST-002 (AC-002) ------------------------------------------------------
$errs = Test-RiskMatrix -Path $v2Path
if ($errs.Count -eq 0) {
    Ok "TEST-002: risk_effort_matrix exact mapping, escalation_bump true, no direct xhigh"
} else {
    Fail "TEST-002: risk_effort_matrix violated -- $($errs -join '; ')"
}

# --- TEST-003 (AC-003) ------------------------------------------------------
$errs = Test-RoleDefaults -Path $v2Path
if ($errs.Count -eq 0) {
    Ok "TEST-003: role_defaults present for all five roles with minimum_tier + default_effort"
} else {
    Fail "TEST-003: role_defaults violated -- $($errs -join '; ')"
}

# --- TEST-004 (AC-004): parity lock ----------------------------------------
$errs = Test-Parity -V1Path $v1Path -V2Path $v2Path
if ($errs.Count -eq 0) {
    Ok "TEST-004: two-directional v1<->v2 parity (model names, canonical_tier, efforts subset)"
} else {
    Fail "TEST-004: parity violated -- $($errs -join '; ')"
}

# Mutation-based negative self-check: strip a v1-required effort from a
# scratch copy of v2 and confirm Test-Parity now reports a violation. The
# tracked v2 file is never touched.
$work = Join-Path ([IO.Path]::GetTempPath()) ("agent-capabilities-v2-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    $mutated = Join-Path $work "mutated-v2.json"
    $data = Get-Content -Raw -LiteralPath $v2Path | ConvertFrom-Json
    foreach ($m in @($data.models)) {
        if ($m.name -ceq "anthropic/sonnet") {
            $remaining = @($m.supported_efforts | Where-Object { -not ($_ -ceq "medium") })
            if ($remaining.Count -eq 0) { $remaining = @("low") }
            $m.supported_efforts = $remaining
            if ($m.default_effort -ceq "medium") { $m.default_effort = $remaining[0] }
        }
    }
    ($data | ConvertTo-Json -Depth 10) | Set-Content -Encoding Utf8 -LiteralPath $mutated

    $negErrs = Test-Parity -V1Path $v1Path -V2Path $mutated
    if ($negErrs.Count -gt 0) {
        Ok "TEST-004 (negative self-check): a mutated v2 copy missing a v1-required effort correctly turns the parity assertion red"
    } else {
        Fail "TEST-004 (negative self-check): removing anthropic/sonnet's v1-required 'medium' effort from a mutated v2 copy did NOT turn the parity assertion red"
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# --- TEST-005 (AC-005): PLUGIN-CONTRACTS.md documents the v2 schema -------
if ((Test-Path -LiteralPath $pluginContracts) -and
    (Select-String -LiteralPath $pluginContracts -Pattern "agent-model-capabilities/v2" -CaseSensitive -SimpleMatch -Quiet)) {
    Ok "TEST-005: PLUGIN-CONTRACTS.md documents the agent-model-capabilities/v2 schema"
} else {
    Fail "TEST-005: PLUGIN-CONTRACTS.md does not document the agent-model-capabilities/v2 schema"
}

# --- Self-registration (mirrors tests/second-approval-mask.tests.sh's
# established pattern; case-sensitive basename match) ----------------------
if ((Test-Path -LiteralPath $runAllSh) -and
    (Select-String -LiteralPath $runAllSh -Pattern "agent-capabilities-v2\.tests\.sh" -CaseSensitive -Quiet)) {
    Ok "self-registration: agent-capabilities-v2.tests.sh registered in tests/run-all.sh"
} else {
    Fail "self-registration: agent-capabilities-v2.tests.sh NOT registered in tests/run-all.sh"
}
if ((Test-Path -LiteralPath $runAllPs1) -and
    (Select-String -LiteralPath $runAllPs1 -Pattern "agent-capabilities-v2\.tests\.ps1" -CaseSensitive -Quiet)) {
    Ok "self-registration: agent-capabilities-v2.tests.ps1 registered in tests/run-all.ps1"
} else {
    Fail "self-registration: agent-capabilities-v2.tests.ps1 NOT registered in tests/run-all.ps1"
}

# --- Protected-file human-copy staging: .github/workflows/test.yml --------
if ((Test-Path -LiteralPath $stagedTestYml) -and (Test-Path -LiteralPath $manifest)) {
    $stagedSha = (Get-FileHash -LiteralPath $stagedTestYml -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestMatch = Select-String -LiteralPath $manifest -Pattern "$stagedSha  \.github/workflows/test\.yml" -CaseSensitive -Quiet
    if ($manifestMatch) {
        Ok "human-copy: staged .github/workflows/test.yml candidate matches its MANIFEST.sha256 entry"
    } else {
        Fail "human-copy: staged .github/workflows/test.yml candidate SHA-256 does not match MANIFEST.sha256"
    }
} else {
    Fail "human-copy: staged .github/workflows/test.yml candidate or MANIFEST.sha256 is missing"
}

# --- v1 frozen: SHA-256 unchanged before/after this suite's own run -------
$v1ShaAfter = (Get-FileHash -LiteralPath $v1Path -Algorithm SHA256).Hash
if ($v1ShaBefore -ceq $v1ShaAfter) {
    Ok "AC-004: v1 registry SHA-256 unchanged before/after this suite's run ($v1ShaAfter)"
} else {
    Fail "AC-004: v1 registry SHA-256 CHANGED during this suite's run (before=$v1ShaBefore after=$v1ShaAfter)"
}

Write-Output ""
Write-Output "agent-capabilities-v2.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
