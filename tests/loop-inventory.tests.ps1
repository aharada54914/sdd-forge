# loop-inventory.tests.ps1 - PowerShell twin of loop-inventory.tests.sh,
# byte-equivalent in coverage (T-001 / Issue #141 / epic-159-pillar-a REQ-001).
# See loop-inventory.tests.sh for the full checklist description (TEST-001,
# TEST-002, TEST-003, TEST-004, TEST-017).
$ErrorActionPreference = "Stop"

$startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$loopSuiteBudgetSeconds = 300

$repoRoot = Split-Path -Parent $PSScriptRoot
$inventoryPath = $env:LOOP_INVENTORY_PATH
if ([string]::IsNullOrEmpty($inventoryPath)) {
    $inventoryPath = Join-Path $repoRoot "tests/loops/loop-inventory.json"
}
$validator = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
$runAllSh = Join-Path $repoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$testYml = Join-Path $repoRoot ".github/workflows/test.yml"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqCmd) {
    Write-Output "FAIL: jq is required"
    exit 1
}

function Invoke-Jq([string]$JqArgsString, [string]$Path) {
    # Runs jq against $Path; returns $null on any failure (missing file,
    # invalid JSON, or a selector that yields nothing) instead of throwing,
    # matching the bash suite's "2>/dev/null || true" tolerance.
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $out = & jq -r $JqArgsString $Path 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("loop-inventory-tests." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
try {

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

function Get-PrecheckScripts {
    Get-ChildItem -Path (Join-Path $repoRoot "plugins") -Recurse -Filter "*-review-precheck.sh" -File |
        Where-Object { $_.DirectoryName -match "[\\/]scripts$" } |
        ForEach-Object {
            $rel = $_.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/'
            $rel
        } | Sort-Object
}

function Get-StageRolePairs {
    $line = (Select-String -LiteralPath $validator -Pattern ([regex]::Escape('quality:sdd-evaluator|domain:domain-reviewer-a')) | Select-Object -First 1).Line
    if (-not $line) { return @() }
    $line = $line -replace '\)\s*;;.*$', ''
    return ($line -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

function Get-EntryIdForStage([string]$Stage) {
    switch ($Stage) {
        "spec" { "spec-review" }
        "impl" { "impl-review" }
        "task" { "task-review" }
        "domain" { "domain-review" }
        "quality" { "quality-gate" }
        default { $null }
    }
}

function Test-Registration([string]$InvPath) {
    if (-not (Test-Path -LiteralPath $InvPath)) { return $false }
    $schemaOk = Invoke-Jq '.schema == "loop-inventory/v1"' $InvPath
    if ($schemaOk -ne "true") { return $false }
    $countOk = Invoke-Jq '(.loops | type) == "array" and (.loops | length) == 8' $InvPath
    if ($countOk -ne "true") { return $false }
    $uniqueOk = Invoke-Jq '(.loops | map(.id) | unique | length) == 8' $InvPath
    if ($uniqueOk -ne "true") { return $false }

    foreach ($scriptPath in (Get-PrecheckScripts)) {
        $registered = Invoke-Jq "[.loops[].driver_scripts[]?] | index(`"$scriptPath`") != null" $InvPath
        if ($registered -ne "true") { return $false }
    }

    foreach ($pair in (Get-StageRolePairs)) {
        $stage = $pair.Split(':')[0]
        $entryId = Get-EntryIdForStage $stage
        if (-not $entryId) { return $false }
        $mapped = Invoke-Jq "[.loops[].id] | index(`"$entryId`") != null" $InvPath
        if ($mapped -ne "true") { return $false }
    }

    $gates = Invoke-Jq '.loops[].cross_gates[]?' $InvPath
    if ($gates) {
        foreach ($gate in ($gates -split "`n")) {
            if ([string]::IsNullOrWhiteSpace($gate)) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $gate))) { return $false }
        }
    }
    return $true
}

# ---------------------------------------------------------------------------
# TEST-001 (AC-001)
# ---------------------------------------------------------------------------
Write-Output "=== TEST-001: inventory schema + registration forcing ==="

if (Test-Path -LiteralPath $inventoryPath) {
    Ok "TEST-001.0: loop-inventory.json exists at $inventoryPath"
} else {
    Fail "TEST-001.0: loop-inventory.json missing at $inventoryPath"
}

if ((Invoke-Jq '.schema == "loop-inventory/v1"' $inventoryPath) -eq "true") {
    Ok "TEST-001.1: schema field is loop-inventory/v1"
} else {
    Fail "TEST-001.1: schema field is not loop-inventory/v1"
}

if ((Invoke-Jq '(.loops | type) == "array" and (.loops | length) == 8' $inventoryPath) -eq "true") {
    Ok "TEST-001.2: inventory carries exactly eight loop entries"
} else {
    Fail "TEST-001.2: inventory does not carry exactly eight loop entries"
}

foreach ($scriptPath in (Get-PrecheckScripts)) {
    $registered = Invoke-Jq "[.loops[].driver_scripts[]?] | index(`"$scriptPath`") != null" $inventoryPath
    if ($registered -eq "true") {
        Ok "TEST-001.3: $scriptPath is registered in some entry's driver_scripts"
    } else {
        Fail "TEST-001.3: $scriptPath is NOT registered in any entry's driver_scripts"
    }
}

$pairs = Get-StageRolePairs
if ($pairs.Count -gt 0) {
    foreach ($pair in $pairs) {
        $stage = $pair.Split(':')[0]
        $entryId = Get-EntryIdForStage $stage
        $mapped = $null
        if ($entryId) { $mapped = Invoke-Jq "[.loops[].id] | index(`"$entryId`") != null" $inventoryPath }
        if ($entryId -and $mapped -eq "true") {
            Ok "TEST-001.4: stage:role pair $pair maps to inventory entry $entryId"
        } else {
            Fail "TEST-001.4: stage:role pair $pair does not map to an inventory entry"
        }
    }
} else {
    Fail "TEST-001.4: could not derive stage:role pairs from $validator"
}

$gates = Invoke-Jq '.loops[].cross_gates[]?' $inventoryPath
if ($gates) {
    foreach ($gate in ($gates -split "`n")) {
        if ([string]::IsNullOrWhiteSpace($gate)) { continue }
        if (Test-Path -LiteralPath (Join-Path $repoRoot $gate)) {
            Ok "TEST-001.5: cross_gates path exists: $gate"
        } else {
            Fail "TEST-001.5: cross_gates path does not exist: $gate"
        }
    }
}

$negMissingEntry = Join-Path $work "missing-entry.json"
if (Test-Path -LiteralPath $inventoryPath) {
    & jq 'del(.loops[0])' $inventoryPath > $negMissingEntry 2>$null
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $negMissingEntry)) {
        if (Test-Registration $negMissingEntry) {
            Fail "TEST-001.6 (negative self-check): removing a registered entry did NOT turn registration validation red"
        } else {
            Ok "TEST-001.6 (negative self-check): removing a registered entry turns registration validation red"
        }
    } else {
        Fail "TEST-001.6 (negative self-check): could not build the mutated mktemp copy"
    }
} else {
    Fail "TEST-001.6 (negative self-check): could not build the mutated mktemp copy"
}

# ---------------------------------------------------------------------------
# TEST-002 (AC-002): bidirectional numeric cap-drift lock
# ---------------------------------------------------------------------------
Write-Output "=== TEST-002: numeric cap-drift lock (cap_source:script + cap_kind:numeric) ==="

function Get-SourceCap([string]$Id) {
    switch ($Id) {
        "spec-review" {
            $p = Join-Path $repoRoot "plugins/sdd-review-loop/scripts/spec-review-precheck.sh"
            $m = Select-String -LiteralPath $p -Pattern '"\$round" -le ([0-9]+)' | Select-Object -First 1
            if ($m) { return $m.Matches[0].Groups[1].Value }
            return $null
        }
        "domain-review" {
            $p = Join-Path $repoRoot "plugins/sdd-domain/scripts/domain-review-precheck.sh"
            $m = Select-String -LiteralPath $p -Pattern '"\$round" -le ([0-9]+)' | Select-Object -First 1
            if ($m) { return $m.Matches[0].Groups[1].Value }
            return $null
        }
        "quality-gate" {
            $p = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh"
            $m = Select-String -LiteralPath $p -Pattern '"\$count" -ge ([0-9]+)' | Select-Object -First 1
            if ($m) { return $m.Matches[0].Groups[1].Value }
            return $null
        }
        default { return $null }
    }
}

function Test-CapDrift([string]$Id, [string]$InvPath) {
    $sourceVal = Get-SourceCap $Id
    $invVal = Invoke-Jq ".loops[] | select(.id == `"$Id`") | .cap.value" $InvPath
    return ($sourceVal -and $sourceVal -eq $invVal)
}

$numericIdsRaw = Invoke-Jq '.loops[] | select(.cap_source == "script" and .cap_kind == "numeric") | .id' $inventoryPath
$numericIds = @()
if ($numericIdsRaw) { $numericIds = $numericIdsRaw -split "`n" | Where-Object { $_ -ne "" } }
if ($numericIds.Count -eq 0) {
    Fail "TEST-002.0: no cap_source:script + cap_kind:numeric entries found to drift-lock"
}
foreach ($id in $numericIds) {
    if (Test-CapDrift $id $inventoryPath) {
        Ok "TEST-002.1: $id cap value greps to its driver source's limit"
    } else {
        Fail "TEST-002.1: $id cap value does NOT match its driver source's limit"
    }
}

$terminalTierState = Invoke-Jq '[.loops[] | select(.id == "terminal-tier")] | length == 1 and .[0].cap_kind == "state"' $inventoryPath
if ($terminalTierState -eq "true") {
    Ok "TEST-002.2: terminal-tier is cap_kind:state and excluded from the numeric grep"
} else {
    Fail "TEST-002.2: terminal-tier is not registered as the sole cap_kind:state entry"
}
$stateCount = Invoke-Jq '[.loops[] | select(.cap_kind == "state")] | length == 1' $inventoryPath
if ($stateCount -eq "true") {
    Ok "TEST-002.3: exactly one cap_kind:state entry exists in the inventory"
} else {
    Fail "TEST-002.3: more than one (or zero) cap_kind:state entries exist"
}

$negMutatedCap = Join-Path $work "mutated-cap.json"
if (Test-Path -LiteralPath $inventoryPath) {
    & jq '(.loops[] | select(.id == "spec-review") | .cap.value) = 999' $inventoryPath > $negMutatedCap 2>$null
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $negMutatedCap)) {
        if (Test-CapDrift "spec-review" $negMutatedCap) {
            Fail "TEST-002.4 (negative self-check): a mutated cap value did NOT turn the drift lock red"
        } else {
            Ok "TEST-002.4 (negative self-check): a mutated cap value turns the drift lock red"
        }
    } else {
        Fail "TEST-002.4 (negative self-check): could not build the mutated mktemp copy"
    }
} else {
    Fail "TEST-002.4 (negative self-check): could not build the mutated mktemp copy"
}

# ---------------------------------------------------------------------------
# TEST-003 (AC-003): skill-instruction exemption + fixture_profiles vocabulary lock
# ---------------------------------------------------------------------------
Write-Output "=== TEST-003: skill-instruction exemption + fixture_profiles vocabulary lock ==="

$skillIdsRaw = Invoke-Jq '.loops[] | select(.cap_source == "skill-instruction") | .id' $inventoryPath
$skillIds = @()
if ($skillIdsRaw) { $skillIds = $skillIdsRaw -split "`n" | Where-Object { $_ -ne "" } }
if ($skillIds.Count -eq 0) {
    Fail "TEST-003.0: no cap_source:skill-instruction entries found"
}
foreach ($id in $skillIds) {
    $noCapKind = Invoke-Jq "(.loops[] | select(.id == `"$id`") | has(`"cap_kind`")) | not" $inventoryPath
    if ($noCapKind -eq "true") {
        Ok "TEST-003.1: $id carries no cap_kind field (skill-instruction is exempt from the numeric grep)"
    } else {
        Fail "TEST-003.1: $id unexpectedly carries a cap_kind field"
    }
}

foreach ($id in @("wfi-audit", "hitl-diagnosis")) {
    $check = Invoke-Jq ".loops[] | select(.id == `"$id`") | .cap_source == `"skill-instruction`" and (.driver_scripts | length) == 0" $inventoryPath
    if ($check -eq "true") {
        Ok "TEST-003.2: $id carries cap_source:skill-instruction and driver_scripts: []"
    } else {
        Fail "TEST-003.2: $id does not carry cap_source:skill-instruction with driver_scripts: []"
    }
}

$vocabOk = Invoke-Jq '[.loops[].fixture_profiles[]?] | all(. == "greenfield" or . == "brownfield")' $inventoryPath
if ($vocabOk -eq "true") {
    Ok "TEST-003.3: every fixture_profiles value is greenfield or brownfield"
} else {
    Fail "TEST-003.3: a fixture_profiles value outside the closed vocabulary was found"
}
$nonEmptyOk = Invoke-Jq '[.loops[] | select((.fixture_profiles | length) == 0)] | length == 0' $inventoryPath
if ($nonEmptyOk -eq "true") {
    Ok "TEST-003.4: every entry declares a non-empty fixture_profiles list"
} else {
    Fail "TEST-003.4: an entry declares an empty fixture_profiles list"
}

# ---------------------------------------------------------------------------
# TEST-004 (AC-004): self-registration forcing
# ---------------------------------------------------------------------------
Write-Output "=== TEST-004: registration forcing (run-all.sh / run-all.ps1 / test.yml) ==="

$canonicalBasenames = @("loop-inventory.tests", "loop-driver.tests", "loop-consistency.tests", "loop-escalation.tests")

function Test-RegisteredSh([string]$Basename) {
    $inRunAll = (Select-String -LiteralPath $runAllSh -Pattern ([regex]::Escape("tests/$Basename.sh")) -Quiet -ErrorAction SilentlyContinue)
    $inYml = (Select-String -LiteralPath $testYml -Pattern ([regex]::Escape("$Basename.sh")) -Quiet -ErrorAction SilentlyContinue)
    return ($inRunAll -and $inYml)
}
function Test-RegisteredPs1([string]$Basename) {
    $inRunAll = (Select-String -LiteralPath $runAllPs1 -Pattern ([regex]::Escape("tests/$Basename.ps1")) -Quiet -ErrorAction SilentlyContinue)
    $inYml = (Select-String -LiteralPath $testYml -Pattern ([regex]::Escape("$Basename.ps1")) -Quiet -ErrorAction SilentlyContinue)
    return ($inRunAll -and $inYml)
}

foreach ($basename in $canonicalBasenames) {
    $shPath = Join-Path $repoRoot "tests/$basename.sh"
    $ps1Path = Join-Path $repoRoot "tests/$basename.ps1"

    if ($basename -eq "loop-inventory.tests" -or (Test-Path -LiteralPath $shPath)) {
        if (Test-RegisteredSh $basename) {
            Ok "TEST-004.1: $basename.sh is registered in run-all.sh and test.yml"
        } else {
            Fail "TEST-004.1: $basename.sh exists but is NOT registered in run-all.sh and/or test.yml"
        }
    } else {
        Write-Output "SKIP: TEST-004.1 $basename.sh not yet on disk (later Pillar-A task)"
    }

    if ($basename -eq "loop-inventory.tests" -or (Test-Path -LiteralPath $ps1Path)) {
        if (Test-RegisteredPs1 $basename) {
            Ok "TEST-004.2: $basename.ps1 is registered in run-all.ps1 and test.yml"
        } else {
            Fail "TEST-004.2: $basename.ps1 exists but is NOT registered in run-all.ps1 and/or test.yml"
        }
    } else {
        Write-Output "SKIP: TEST-004.2 $basename.ps1 not yet on disk (later Pillar-A task)"
    }
}

# ---------------------------------------------------------------------------
# TEST-017 (AC-017): runtime budget, live negative self-check
# ---------------------------------------------------------------------------
Write-Output "=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=$loopSuiteBudgetSeconds) ==="

function Test-RuntimeBudget([long]$Start, [int]$Budget) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $elapsed = $now - $Start
    return ($elapsed -le $Budget)
}

# Synthetic start time strictly in the past so this negative self-check is
# deterministic regardless of how fast the suite executes.
$syntheticPastEpoch = $startEpoch - 1
if (Test-RuntimeBudget $syntheticPastEpoch 0) {
    Fail "TEST-017.1 (negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
} else {
    Ok "TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red"
}

$elapsedSeconds = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $startEpoch
if ($elapsedSeconds -le $loopSuiteBudgetSeconds) {
    Ok "TEST-017.2: suite completed within the ${loopSuiteBudgetSeconds}s runtime budget"
} else {
    Fail "TEST-017.2: suite exceeded the ${loopSuiteBudgetSeconds}s runtime budget"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Output ""
Write-Output "loop-inventory.tests.ps1: $($script:passCount) passed, $($script:failCount) failed, ${elapsedSeconds}s elapsed"
if ($script:failCount -ne 0) { exit 1 }
exit 0

} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
