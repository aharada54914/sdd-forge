# Deterministic gate: cross-model consensus verification
# Usage: check-cross-model.ps1 --task T-NNN --feature <f> [--evaluator PASS|NEEDS_WORK]
#        [--expect-digest <64-hex>] [--spec-root <dir>]
#
# Reads all T-NNN.panelist-*.verdict.json under <spec-root>/<feature>/verification/
# Applies consensus policy (design.md §3), writes aggregate JSON, exits 0/1/2.
#
# Exit codes: 0=pass  1=fail  2=tool error (bad args / malformed verdict / no verdicts)
param(
    [string]$Task         = "",
    [string]$Feature      = "",
    [string]$Evaluator    = "",
    [string]$ExpectDigest = "",
    [string]$SpecRoot     = "specs"
)
$ErrorActionPreference = "Stop"

# Parse GNU-style --flag value arguments not covered by param() above
# (param() handles --Task but not --task due to case on some PS versions)
$argIdx = 0
$passedArgs = $args
while ($argIdx -lt $passedArgs.Count) {
    switch ($passedArgs[$argIdx]) {
        "--task"          { $Task         = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--feature"       { $Feature      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--evaluator"     { $Evaluator    = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--expect-digest" { $ExpectDigest = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--spec-root"     { $SpecRoot     = $passedArgs[$argIdx+1]; $argIdx += 2 }
        default           { [Console]::Error.WriteLine("check-cross-model: unknown argument: $($passedArgs[$argIdx])"); exit 2 }
    }
}

if (-not $Task -or -not $Feature) {
    [Console]::Error.WriteLine("check-cross-model: --task and --feature are required")
    exit 2
}

$verdictDir    = Join-Path $SpecRoot (Join-Path $Feature "verification")
$aggregatePath = Join-Path $verdictDir "$Task.cross-model.json"

# ── helpers ────────────────────────────────────────────────────────────────

function Write-Aggregate {
    param(
        [array]  $Panelists,
        [int]    $VendorsDistinct,
        [int]    $NonAnthropicCount,
        [bool]   $AllPass,
        [bool]   $AnyCritical,
        $EvaluatorVerdict,
        [bool]   $Divergence,
        [bool]   $RequiresHuman,
        [string] $Result
    )

    $agg = [ordered]@{
        schema                 = "cross-model-aggregate/v1"
        task_id                = $Task
        feature                = $Feature
        panelists              = $Panelists
        vendors_distinct       = $VendorsDistinct
        non_anthropic_count    = $NonAnthropicCount
        all_pass               = $AllPass
        any_critical           = $AnyCritical
        evaluator_verdict      = $EvaluatorVerdict
        divergence             = $Divergence
        requires_human_decision = $RequiresHuman
        result                 = $Result
    }

    $dir = Split-Path -Parent $aggregatePath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $agg | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 $aggregatePath
}

# ── Step 0: discover verdict files ─────────────────────────────────────────

$prefix = "$Task.panelist-"
$suffix = ".verdict.json"

if (-not (Test-Path -LiteralPath $verdictDir)) {
    [Console]::Error.WriteLine("check-cross-model: verdict dir not found: $verdictDir")
    exit 2
}

$verdictFiles = @(Get-ChildItem -Path $verdictDir -Filter "*.verdict.json" |
    Where-Object { $_.Name.StartsWith($prefix) -and $_.Name.EndsWith($suffix) } |
    Sort-Object Name)

if ($verdictFiles.Count -eq 0) {
    [Console]::Error.WriteLine("check-cross-model: no verdict files found matching ${prefix}*${suffix} in $verdictDir")
    exit 2
}

# ── Step 1: parse + schema-validate each verdict ───────────────────────────

$HEX64 = '^[0-9a-fA-F]{64}$'
$verdicts = @()

foreach ($vfile in $verdictFiles) {
    try {
        $v = Get-Content -Raw -Encoding Utf8 $vfile.FullName | ConvertFrom-Json
    } catch {
        [Console]::Error.WriteLine("check-cross-model: failed to parse $($vfile.Name): $_")
        exit 2
    }

    # blind must be exactly $true (boolean)
    if ($v.blind -ne $true) {
        [Console]::Error.WriteLine("check-cross-model: $($vfile.Name): blind must be true (got $($v.blind))")
        exit 2
    }

    # input_digest must be 64-hex
    $digest = [string]($v.input_digest)
    if (-not ($digest -match $HEX64)) {
        [Console]::Error.WriteLine("check-cross-model: $($vfile.Name): input_digest must be 64-hex (got '$digest')")
        exit 2
    }

    # vendor must be non-empty string
    $vendor = [string]($v.vendor)
    if (-not $vendor) {
        [Console]::Error.WriteLine("check-cross-model: $($vfile.Name): vendor must be non-empty string")
        exit 2
    }

    # consent.kind must be present
    $consent = $v.consent
    if ($null -eq $consent -or -not $consent.PSObject.Properties['kind'] -or -not $consent.kind) {
        [Console]::Error.WriteLine("check-cross-model: $($vfile.Name): consent.kind is required")
        exit 2
    }

    $verdicts += $v
}

# ── Step 2: compute vendor diversity metrics ────────────────────────────────

$allVendors      = $verdicts | ForEach-Object { [string]$_.vendor }
$distinctVendors = $allVendors | ForEach-Object { $_.ToLower() } | Sort-Object -Unique
$vendorsDistinct  = $distinctVendors.Count
$nonAnthropicCount = ($distinctVendors | Where-Object { $_ -ne "anthropic" }).Count

$panelists = @(
    $verdicts | ForEach-Object {
        @{ vendor = [string]$_.vendor; model = [string]$_.model; verdict = [string]$_.verdict }
    }
)

# ── Step 3: diversity check ─────────────────────────────────────────────────

if ($vendorsDistinct -lt 2 -or $nonAnthropicCount -lt 1) {
    Write-Aggregate -Panelists $panelists -VendorsDistinct $vendorsDistinct `
        -NonAnthropicCount $nonAnthropicCount -AllPass $false -AnyCritical $false `
        -EvaluatorVerdict $null -Divergence $false -RequiresHuman $false -Result "FAIL"
    [Console]::Error.WriteLine("check-cross-model: diversity check failed: vendors_distinct=$vendorsDistinct non_anthropic_count=$nonAnthropicCount (need >=2 distinct and >=1 non-anthropic)")
    exit 1
}

# ── Step 4: consent check ───────────────────────────────────────────────────
# Validated per-verdict in Step 1. All verdicts carry consent.kind.

# ── Step 5: digest check (if --expect-digest) ───────────────────────────────

if ($ExpectDigest) {
    $mismatches = @(
        $verdicts | Where-Object {
            ([string]$_.input_digest).ToLower() -ne $ExpectDigest.ToLower()
        } | ForEach-Object { [string]$_.vendor }
    )
    if ($mismatches.Count -gt 0) {
        Write-Aggregate -Panelists $panelists -VendorsDistinct $vendorsDistinct `
            -NonAnthropicCount $nonAnthropicCount -AllPass $false -AnyCritical $false `
            -EvaluatorVerdict $null -Divergence $false -RequiresHuman $false -Result "FAIL"
        [Console]::Error.WriteLine("check-cross-model: input_digest mismatch for vendors: $($mismatches -join ', ')")
        exit 1
    }
}

# ── Step 6: consensus check ─────────────────────────────────────────────────

$allPass = ($verdicts | Where-Object { [string]$_.verdict -ne "PASS" }).Count -eq 0
$anyCritical = ($verdicts | ForEach-Object {
    $v = $_
    if ($v.findings) {
        $v.findings | Where-Object { [string]$_.severity -eq "Critical" }
    }
} | Measure-Object).Count -gt 0

if (-not $allPass -or $anyCritical) {
    Write-Aggregate -Panelists $panelists -VendorsDistinct $vendorsDistinct `
        -NonAnthropicCount $nonAnthropicCount -AllPass $allPass -AnyCritical $anyCritical `
        -EvaluatorVerdict $null -Divergence $false -RequiresHuman $false -Result "FAIL"
    $reasons = @()
    if (-not $allPass) { $reasons += "not all verdicts are PASS" }
    if ($anyCritical)  { $reasons += "Critical finding(s) present" }
    [Console]::Error.WriteLine("check-cross-model: consensus FAIL: $($reasons -join '; ')")
    exit 1
}

# ── Step 7: evaluator divergence check ─────────────────────────────────────

if ($Evaluator) {
    $panelConsensus = "PASS"  # we passed step 6
    if ($Evaluator -ne $panelConsensus) {
        Write-Aggregate -Panelists $panelists -VendorsDistinct $vendorsDistinct `
            -NonAnthropicCount $nonAnthropicCount -AllPass $true -AnyCritical $false `
            -EvaluatorVerdict $Evaluator -Divergence $true -RequiresHuman $true -Result "NEEDS_HUMAN"
        [Console]::Error.WriteLine("check-cross-model: evaluator=$Evaluator diverges from panel consensus=$panelConsensus; requires human decision")
        exit 1
    }
}

# ── Step 8: all checks passed → PASS ───────────────────────────────────────

$evalOut = if ($Evaluator) { $Evaluator } else { $null }
Write-Aggregate -Panelists $panelists -VendorsDistinct $vendorsDistinct `
    -NonAnthropicCount $nonAnthropicCount -AllPass $true -AnyCritical $false `
    -EvaluatorVerdict $evalOut -Divergence $false -RequiresHuman $false -Result "PASS"
Write-Host "check-cross-model: consensus PASS for $Task ($($verdicts.Count) panelists, $vendorsDistinct distinct vendors)"
exit 0
