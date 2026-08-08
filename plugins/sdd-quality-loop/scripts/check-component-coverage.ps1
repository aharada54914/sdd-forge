# check-component-coverage.ps1 — the Reverse Coverage Gate, PowerShell
# twin (REQ-004, T-004). See check-component-coverage.py for the full
# rationale; this is a full independent PowerShell port, dot-sourcing
# resolve-component-paths.ps1 (same directory) to reuse its config
# parsing, classification, and git-diff collector rather than
# reimplementing them a second time.
param(
    [string]$Config,
    [string]$FacetManifest,
    [string]$ProviderBindings = "sdd/provider-bindings.yaml",
    [string]$ChangedPathsFile,
    [string]$SourceRev = "HEAD",
    [string]$TargetRev,
    [bool]$IncludeUntracked = $true,
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

# NOTE: a FIFTH distinct PowerShell pitfall found in this feature (after
# the null-pipeline, culture-aware -eq/-ne, case-insensitive @{}, and
# IEnumerable-output-stream-unwrapping issues documented in
# resolve-component-paths.ps1): dot-sourcing a script that has its OWN
# `param()` block, when invoked with no arguments, CLOBBERS same-named
# variables already bound in the CALLING script's scope -- dot-sourcing
# shares scope, and the dot-sourced script's param block re-declares and
# re-binds those parameter names to ITS OWN defaults (confirmed via a
# minimal repro: `param([string]$Config)` bound to a real value, followed
# by a bare `. resolve-component-paths.ps1` dot-source with no arguments,
# left $Config empty afterward -- resolve-component-paths.ps1 has its own
# same-named $Config/$ChangedPathsFile/$SourceRev/$TargetRev/
# $IncludeUntracked/$RepoRoot parameters). Captured into differently-named
# local variables immediately, before the dot-source line, and used those
# from here on instead of the directly-bound parameter variables.
$myConfig = $Config
$myFacetManifest = $FacetManifest
$myProviderBindings = $ProviderBindings
$myChangedPathsFile = $ChangedPathsFile
$mySourceRev = $SourceRev
$myTargetRev = $TargetRev
$myIncludeUntracked = $IncludeUntracked
$myRepoRoot = $RepoRoot

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "resolve-component-paths.ps1")

$SCHEMA = "check-component-coverage-verdict/v1"
$CHECK_ID = "check-component-coverage"
$EXIT_OK = 0
$EXIT_FAIL_TRIGGERED = 1
$EXIT_HARD_ERROR = 2

function Get-ProducerSha256 {
    # `producer.sha256` binds to check-component-coverage.PY specifically,
    # on BOTH runtimes -- requirements.md is explicit that check-contract's
    # producer-digest verification pass "independently recomputes ... over
    # the live, on-disk check-component-coverage.py" (singular, always the
    # Python file) regardless of which twin actually produced the evidence,
    # so both twins must emit the identical value for that single
    # cross-runtime verification check to work. (Found via a test failure:
    # this function originally hashed itself -- check-component-coverage.ps1
    # -- which correctly matches the Python twin only by coincidence when
    # the Python producer hashes ITS OWN file; the two would silently
    # diverge the moment the two files' bytes differ even slightly.)
    $pyPath = Join-Path $scriptDir "check-component-coverage.py"
    $bytes = [System.IO.File]::ReadAllBytes($pyPath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash($bytes)
    return (-join ($hash | ForEach-Object { $_.ToString("x2") }))
}

function Get-DerivedState {
    param([string]$ConfigPath)
    if ([string]::IsNullOrEmpty($ConfigPath) -or -not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        return "disabled-legacy"
    }
    try {
        $text = Get-Content -Raw -LiteralPath $ConfigPath -Encoding utf8
        $data = ConvertFrom-MinimalYaml $text
    } catch {
        return "disabled-legacy"
    }
    $workflow = $data["workflow"]
    if ($workflow -isnot [System.Collections.IDictionary]) { return "disabled-legacy" }
    $value = $workflow["capability_enforcement"]
    if ($value -eq "advisory") { return "advisory" }
    if ($value -eq "required") { return "required" }
    return "disabled-legacy"
}

function Import-FacetManifest {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{ Affected = $null; Error = "Facet Manifest not found: $Path" }
    }
    try {
        $text = Get-Content -Raw -LiteralPath $Path -Encoding utf8
    } catch {
        return @{ Affected = $null; Error = "Facet Manifest unreadable: $Path ($($_.Exception.Message))" }
    }
    try {
        $data = $text | ConvertFrom-Json -AsHashtable
    } catch {
        try {
            $data = ConvertFrom-MinimalYaml $text
        } catch {
            return @{ Affected = $null; Error = "Facet Manifest could not be parsed as JSON or YAML: $Path" }
        }
    }
    if ($data -isnot [System.Collections.IDictionary] -or -not $data.Contains("affected_components")) {
        return @{ Affected = $null; Error = "Facet Manifest at $Path has no top-level 'affected_components' key" }
    }
    return @{ Affected = @($data["affected_components"]); Error = $null }
}

function Import-ProviderBindingsFile {
    # NOTE: another instance of the IEnumerable/array output-stream
    # unwrapping pitfall (documented at length in resolve-component-paths.ps1)
    # was found and fixed here: the original code assigned `$data["bindings"]`
    # through an if/else block USED AS AN EXPRESSION, which collapsed a
    # 1-element bindings array to its bare scalar element -- and a bare
    # `return @()` for the empty case then collapsed itself to $null. Fixed
    # by using a plain (non-expression) if-statement for the array lookup
    # (confirmed safe by the same direct-assignment pattern already proven
    # in resolve-component-paths.ps1's own HashSet fix) and a leading-comma
    # `return ,@()` for every array-returning exit path.
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $text = Get-Content -Raw -LiteralPath $Path -Encoding utf8
    try {
        $data = $text | ConvertFrom-Json -AsHashtable
    } catch {
        $data = ConvertFrom-MinimalYaml $text
    }
    $bindingsRaw = $null
    if ($data -is [System.Collections.IDictionary]) {
        $bindingsRaw = $data["bindings"]
    }
    if ($bindingsRaw -isnot [System.Array]) { return , @() }
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($b in $bindingsRaw) {
        if ($b -isnot [System.Collections.IDictionary]) { continue }
        # Deliberately never reads a "credentials" key (security-spec.md).
        $joinIds = $null
        if ($b["provider_binding_ids"]) { $joinIds = $b["provider_binding_ids"] } else { $joinIds = @() }
        $out.Add(@{ ProviderBindingIds = $joinIds; AdapterPaths = $b["adapter_paths"] })
    }
    return , @($out)
}

function Test-FailConditions {
    param([object[]]$Records, [string[]]$AffectedComponents, $Bindings)
    $affectedSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$AffectedComponents, [System.StringComparer]::Ordinal)
    $warnings = [System.Collections.Generic.List[string]]::new()

    $fail1Paths = @($Records | Where-Object { $_.classification -eq "UNOWNED" } | ForEach-Object { $_.raw_path })
    $fail1 = [ordered]@{ id = "Fail-1"; triggered = ($fail1Paths.Count -gt 0); detail = [ordered]@{ unowned_paths = $fail1Paths } }

    $fail2Components = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Records) {
        if ($r.classification -eq "EXCLUSIVE") {
            foreach ($comp in $r.owning_components) {
                if (-not $affectedSet.Contains($comp) -and -not $fail2Components.Contains($comp)) { $fail2Components.Add($comp) }
            }
        }
    }
    $fail2 = [ordered]@{ id = "Fail-2"; triggered = ($fail2Components.Count -gt 0); detail = [ordered]@{ missing_exclusive_owners = @($fail2Components) } }

    $fail3Paths = @($Records | Where-Object { $_.classification -eq "OVERLAP" } | ForEach-Object { $_.raw_path })
    $fail3 = [ordered]@{ id = "Fail-3"; triggered = ($fail3Paths.Count -gt 0); detail = [ordered]@{ overlap_paths = $fail3Paths } }

    $fail4Components = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Records) {
        if ($r.classification -eq "SHARED_BOUNDED") {
            foreach ($comp in $r.owning_components) {
                if (-not $affectedSet.Contains($comp) -and -not $fail4Components.Contains($comp)) { $fail4Components.Add($comp) }
            }
        }
    }
    $fail4 = [ordered]@{ id = "Fail-4"; triggered = ($fail4Components.Count -gt 0); detail = [ordered]@{ missing_bounded_shared_owners = @($fail4Components) } }

    $fail5Paths = @($Records | Where-Object { $_.classification -eq "UNOWNED" -and $_.evidence.excluded_match } | ForEach-Object { $_.raw_path })
    $fail5 = [ordered]@{ id = "Fail-5"; triggered = ($fail5Paths.Count -gt 0); detail = [ordered]@{ excluded_match_paths = $fail5Paths } }

    if ($null -eq $Bindings) {
        $fail6 = [ordered]@{ id = "Fail-6"; triggered = $false; detail = [ordered]@{ status = "not-applicable (provider-bindings absent)" } }
        $warnings.Add("Fail-6: sdd/provider-bindings.yaml absent; recorded N/A")
    } else {
        $exclusiveByComponent = @{}
        foreach ($r in $Records) {
            if ($r.classification -eq "EXCLUSIVE") {
                foreach ($comp in $r.owning_components) {
                    if (-not $exclusiveByComponent.ContainsKey($comp)) { $exclusiveByComponent[$comp] = [System.Collections.Generic.List[string]]::new() }
                    $exclusiveByComponent[$comp].Add($r.raw_path)
                }
            }
        }
        $matches = [System.Collections.Generic.List[object]]::new()
        foreach ($binding in $Bindings) {
            if ($null -eq $binding.AdapterPaths) {
                $warnings.Add("Fail-6: a provider binding declares no adapter_paths; evaluation not possible for it")
                continue
            }
            foreach ($comp in $binding.ProviderBindingIds) {
                if (-not $exclusiveByComponent.ContainsKey($comp)) { continue }
                foreach ($path in $exclusiveByComponent[$comp]) {
                    $nfcPath = ConvertTo-Nfc $path
                    foreach ($pattern in $binding.AdapterPaths) {
                        try {
                            $normalized = Confirm-AndNormalizePattern $pattern
                        } catch {
                            continue
                        }
                        if (Test-PatternMatches -PatternNormalized $normalized -PathNfc $nfcPath) {
                            $matches.Add([ordered]@{ component = $comp; path = $path; pattern = $pattern })
                        }
                    }
                }
            }
        }
        $fail6 = [ordered]@{ id = "Fail-6"; triggered = ($matches.Count -gt 0); detail = [ordered]@{ matches = @($matches) } }
    }

    return @{ Conditions = @($fail1, $fail2, $fail3, $fail4, $fail5, $fail6); Warnings = @($warnings) }
}

# --------------------------------------------------------------------------
# CLI dispatch
# --------------------------------------------------------------------------

$state = Get-DerivedState -ConfigPath $myConfig
$producer = [ordered]@{ script = "plugins/sdd-quality-loop/scripts/check-component-coverage.py"; sha256 = (Get-ProducerSha256) }

if ($state -eq "disabled-legacy") {
    $result = [ordered]@{
        schema = $SCHEMA; check_id = $CHECK_ID; producer = $producer
        state = "not-applicable (disabled-legacy)"; manifest_status = "not-consulted"
        fail_conditions = @(); warnings = @()
    }
    Write-Output ($result | ConvertTo-Json -Depth 20)
    exit $EXIT_OK
}

$records = @()
if (-not [string]::IsNullOrEmpty($myConfig)) {
    try {
        $cfg = Import-ConfigFile -Path $myConfig
        if (-not [string]::IsNullOrEmpty($myTargetRev)) {
            $diffBasis = Get-ChangedPaths -RepoRoot $myRepoRoot -SourceRev $mySourceRev -TargetRev $myTargetRev -IncludeUntracked $myIncludeUntracked
            $rawPaths = @($diffBasis.ChangedPaths)
        } else {
            if ([string]::IsNullOrEmpty($myChangedPathsFile)) {
                $text = [Console]::In.ReadToEnd()
            } else {
                $text = Get-Content -Raw -LiteralPath $myChangedPathsFile -Encoding utf8
            }
            $normalizedText = $text -replace "`r`n", "`n" -replace "`r", "`n"
            $rawPaths = @($normalizedText -split "`n" | Where-Object { $_ -ne "" })
        }
        $classifyResult = Invoke-ClassifyPaths -Config $cfg -RawPaths $rawPaths
        $records = $classifyResult.records
    } catch {
        Write-Error ("check-component-coverage: $($_.Exception.Message)")
        exit $EXIT_HARD_ERROR
    }
}

if ([string]::IsNullOrEmpty($myFacetManifest)) {
    $result = [ordered]@{
        schema = $SCHEMA; check_id = $CHECK_ID; producer = $producer
        state = $state; manifest_status = "missing"
        error = "-FacetManifest is required in advisory/required state"
    }
    Write-Output ($result | ConvertTo-Json -Depth 20)
    exit $EXIT_HARD_ERROR
}

$manifestResult = Import-FacetManifest -Path $myFacetManifest
if ($manifestResult.Error) {
    $manifestStatus = if (-not (Test-Path -LiteralPath $myFacetManifest -PathType Leaf)) { "missing" } else { "unreadable" }
    $result = [ordered]@{
        schema = $SCHEMA; check_id = $CHECK_ID; producer = $producer
        state = $state; manifest_status = $manifestStatus; error = $manifestResult.Error
    }
    Write-Output ($result | ConvertTo-Json -Depth 20)
    exit $EXIT_HARD_ERROR
}

$bindings = Import-ProviderBindingsFile -Path $myProviderBindings
$failResult = Test-FailConditions -Records $records -AffectedComponents $manifestResult.Affected -Bindings $bindings

$result = [ordered]@{
    schema = $SCHEMA; check_id = $CHECK_ID; producer = $producer
    state = $state; manifest_status = "present"
    fail_conditions = $failResult.Conditions; warnings = $failResult.Warnings
}
Write-Output ($result | ConvertTo-Json -Depth 20)

if ($state -eq "advisory") { exit $EXIT_OK }
if ($failResult.Conditions | Where-Object { $_.triggered }) { exit $EXIT_FAIL_TRIGGERED }
exit $EXIT_OK
