# loop-inventory.tests.ps1 - PowerShell twin of loop-inventory.tests.sh,
# byte-equivalent in coverage (T-001 / Issue #141 / epic-159-pillar-a REQ-001).
# See loop-inventory.tests.sh for the full checklist description (TEST-001,
# TEST-002, TEST-003, TEST-004, TEST-008, TEST-009, TEST-017).
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
$loopDriver = Join-Path $repoRoot "tests/lib/loop-driver.ps1"

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

function Test-CapabilityApplicabilityShape([string]$InvPath) {
    $filter = @'
(.loops | length) == 8 and
([.loops[] | select(has("capability_applicability"))] | length) == 1 and
(.loops[] | select(.id == "quality-gate") | .capability_applicability) == {
  "disabled-legacy": "not-applicable (disabled-legacy)",
  "advisory": "advisory",
  "required": "required"
}
'@
    $null = & jq -e $filter $InvPath 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-FunctionBodySha256([string]$Path, [string]$FunctionName) {
    $lines = [IO.File]::ReadAllLines($Path)
    $captured = [Collections.Generic.List[string]]::new()
    $capture = $false
    foreach ($line in $lines) {
        if (-not $capture -and $line -cmatch ("^function " + [regex]::Escape($FunctionName) + "(?:\s|\{)")) {
            $capture = $true
        }
        if ($capture) {
            $captured.Add($line)
            if ($line -eq "}") { break }
        }
    }
    if ($captured.Count -eq 0) { return "" }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($captured -join "`n") + "`n")
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -creplace '-', '').ToLowerInvariant()
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
# TEST-008 (AC-008/AC-009): capability applicability + legacy compatibility
# ---------------------------------------------------------------------------
Write-Output "=== TEST-008: quality-gate capability applicability ==="

$legacyInventory = Join-Path $work "loop-inventory.pre-epic-195.json"
& jq 'del(.loops[].capability_applicability)' $inventoryPath | Set-Content -LiteralPath $legacyInventory -Encoding utf8
if (Test-Registration $legacyInventory) {
    Ok "TEST-008.1: a pre-epic-195 copy without capability_applicability remains base-valid"
} else {
    Fail "TEST-008.1: a pre-epic-195 copy without capability_applicability is not base-valid"
}

if (Test-CapabilityApplicabilityShape $inventoryPath) {
    Ok "TEST-008.2: only quality-gate carries the exact three-state applicability mapping"
} else {
    Fail "TEST-008.2: quality-gate does not carry the exact three-state applicability mapping"
}

$badCapabilityInventory = Join-Path $work "loop-inventory.bad-capability.json"
& jq '(.loops[] | select(.id == "quality-gate") | .capability_applicability) = {
  "disabled-legacy": "disabled", "advisory": "advisory", "required": "required"
}' $inventoryPath | Set-Content -LiteralPath $badCapabilityInventory -Encoding utf8
if (Test-CapabilityApplicabilityShape $badCapabilityInventory) {
    Fail "TEST-008.3 (negative self-check): an incorrect applicability value passed validation"
} else {
    Ok "TEST-008.3 (negative self-check): an incorrect applicability value is rejected"
}

# ---------------------------------------------------------------------------
# TEST-009 (AC-009): trace API, normalization, purity, and non-regression
# ---------------------------------------------------------------------------
Write-Output "=== TEST-009: event trace API + legacy helper non-regression ==="

$expectedArtifactsSha = "0734964255324b2f23be7639f86f1175552e50d908c3556f454838e7fc7d9d7a"
$expectedTerminalSha = "4140a2eca754ff4be9abc650c7491d9bebb9a6dd9b0695eb9f736b23e6fd865d"
if ((Get-FunctionBodySha256 $loopDriver "Test-ArtifactsSchema") -eq $expectedArtifactsSha) {
    Ok "TEST-009.1: Test-ArtifactsSchema remains byte-identical"
} else {
    Fail "TEST-009.1: Test-ArtifactsSchema changed"
}
if ((Get-FunctionBodySha256 $loopDriver "Test-LoopTerminal") -eq $expectedTerminalSha) {
    Ok "TEST-009.2: Test-LoopTerminal remains byte-identical"
} else {
    Fail "TEST-009.2: Test-LoopTerminal changed"
}

$mutatedDriver = Join-Path $work "loop-driver.mutated.ps1"
$mutatedText = [IO.File]::ReadAllText($loopDriver).Replace(
    'return ($expected -eq $Observed)',
    'return ($expected -ceq $Observed)'
)
[IO.File]::WriteAllText($mutatedDriver, $mutatedText, [Text.UTF8Encoding]::new($false))
if ((Get-FunctionBodySha256 $mutatedDriver "Test-LoopTerminal") -eq $expectedTerminalSha) {
    Fail "TEST-009.3 (negative self-check): a deliberately changed legacy function was accepted"
} else {
    Ok "TEST-009.3 (negative self-check): a deliberately changed legacy function is rejected"
}

. $loopDriver
$traceApiReady = $true
foreach ($functionName in @("Write-LoopTraceEvent", "Test-CapabilityApplicability", "Test-EventTrace")) {
    if (Get-Command $functionName -CommandType Function -ErrorAction SilentlyContinue) {
        Ok "TEST-009.4: $functionName is available"
    } else {
        Fail "TEST-009.4: $functionName is unavailable"
        $traceApiReady = $false
    }
}

if ($traceApiReady) {
    $script:_LOOP_EVENT_TRACE = '[{"kind":"stale","producer":"stale","seq":99,"value":"stale"}]'
    $script:_LOOP_EVENT_SEQ = 99
    $initialized = Initialize-LoopFixture -Profile greenfield -Feature trace-reset 2>$null
    if ($initialized -and $script:_LOOP_EVENT_TRACE -eq '[]' -and $script:_LOOP_EVENT_SEQ -eq 0) {
        Ok "TEST-009.5: Initialize-LoopFixture resets the trace and sequence per fixture"
    } else {
        Fail "TEST-009.5: Initialize-LoopFixture did not reset the trace and sequence"
    }
    if ($script:LoopFixtureRoot) { Remove-Item -Recurse -Force $script:LoopFixtureRoot -ErrorAction SilentlyContinue }

    $capabilityOk = Test-CapabilityApplicability -LoopId quality-gate -FixtureState advisory -Observed advisory
    $capabilityEventOk = ($script:_LOOP_EVENT_TRACE | & jq -e '
      length == 1 and .[0].kind == "quality-gate-outcome" and
      .[0].producer == "quality-gate-outcome:capability-applicability" and
      .[0].seq == 1 and .[0].value == {"applicability":"advisory"}
    ' 2>$null)
    if ($capabilityOk -and $LASTEXITCODE -eq 0 -and $capabilityEventOk) {
        Ok "TEST-009.6: capability applicability compares exactly and emits one canonical event"
    } else {
        Fail "TEST-009.6: capability applicability comparison/event emission is incorrect"
    }
    if (Test-CapabilityApplicability -LoopId quality-gate -FixtureState unknown -Observed unknown 2>$null) {
        Fail "TEST-009.7: an unknown fixture state was accepted"
    } else {
        Ok "TEST-009.7: an unknown fixture state is rejected"
    }
    if (Test-CapabilityApplicability -LoopId quality-gate -FixtureState advisory -Observed Advisory 2>$null) {
        Fail "TEST-009.7: a mis-cased observed applicability was accepted"
    } else {
        Ok "TEST-009.7: applicability comparison is case-sensitive"
    }

    $script:_LOOP_EVENT_TRACE = '[]'
    $script:_LOOP_EVENT_SEQ = 0
    $skillPathJson = & jq -cn --arg value (($script:SddLoopRepoRoot -creplace '\\', '/') + '/plugins/sdd-review-loop/SKILL.md') '$value'
    $null = Write-LoopTraceEvent -Kind skill-order -Producer skill-order:invocation -ValueJson ([string]$skillPathJson)
    $null = Write-LoopTraceEvent -Kind review-loop-presence -Producer review-loop-presence:stage-dispatch -ValueJson '"spec"'
    $null = Write-LoopTraceEvent -Kind approval-checkpoint -Producer approval-checkpoint:reserve `
        -ValueJson '{"stage":"quality","role":"sdd-evaluator","run_id":"ignored"}'
    $null = Write-LoopTraceEvent -Kind quality-gate-outcome -Producer quality-gate-outcome:escalation `
        -ValueJson '{"next_tier":"human","wall_clock":"ignored"}'
    $null = Write-LoopTraceEvent -Kind quality-gate-outcome -Producer quality-gate-outcome:capability-applicability `
        -ValueJson '{"applicability":"required","wall_clock":"ignored"}'
    $null = Write-LoopTraceEvent -Kind skip-stop-message -Producer skip-stop-message:skip -ValueJson '"SKIP: cited upstream issue"'
    $null = Write-LoopTraceEvent -Kind skip-stop-message -Producer skip-stop-message:stop -ValueJson '"PROJECT_CONTEXT_INVALID"'
    $null = Write-LoopTraceEvent -Kind done-transition -Producer done-transition:assert-terminal -ValueJson '"Done"'
    $sequenceOk = $script:_LOOP_EVENT_TRACE | & jq -e '[.[].seq] == [1,2,3,4,5,6,7,8]' 2>$null
    if ($LASTEXITCODE -eq 0 -and $sequenceOk) {
        Ok "TEST-009.8: the collector assigns one trace-wide monotonic sequence"
    } else {
        Fail "TEST-009.8: collector sequence is not trace-wide and monotonic"
    }

    $traceBeforeBadJson = $script:_LOOP_EVENT_TRACE
    $seqBeforeBadJson = $script:_LOOP_EVENT_SEQ
    $badJsonAccepted = Write-LoopTraceEvent -Kind done-transition -Producer done-transition:assert-terminal -ValueJson '{bad-json' 2>$null
    if ($badJsonAccepted) {
        Fail "TEST-009.9: invalid event value JSON was accepted"
    } elseif ($script:_LOOP_EVENT_TRACE -eq $traceBeforeBadJson -and $script:_LOOP_EVENT_SEQ -eq $seqBeforeBadJson) {
        Ok "TEST-009.9: invalid event JSON is rejected without consuming sequence state"
    } else {
        Fail "TEST-009.9: invalid event JSON changed trace or sequence state"
    }

    $goldenTrace = Join-Path $work "golden-trace.json"
    & jq -n '[
      {kind:"skill-order", producer:"skill-order:invocation", seq:1,
        value:"plugins/sdd-review-loop/SKILL.md"},
      {kind:"review-loop-presence", producer:"review-loop-presence:stage-dispatch", seq:2, value:"spec"},
      {kind:"approval-checkpoint", producer:"approval-checkpoint:reserve", seq:3,
        value:{stage:"quality", role:"sdd-evaluator"}},
      {kind:"quality-gate-outcome", producer:"quality-gate-outcome:escalation", seq:4,
        value:{next_tier:"human"}},
      {kind:"quality-gate-outcome", producer:"quality-gate-outcome:capability-applicability", seq:5,
        value:{applicability:"required"}},
      {kind:"skip-stop-message", producer:"skip-stop-message:skip", seq:6,
        value:"SKIP: cited upstream issue"},
      {kind:"skip-stop-message", producer:"skip-stop-message:stop", seq:7,
        value:"PROJECT_CONTEXT_INVALID"},
      {kind:"done-transition", producer:"done-transition:assert-terminal", seq:8, value:"Done"}
    ]' | Set-Content -LiteralPath $goldenTrace -Encoding utf8
    $traceSnapshot = $script:_LOOP_EVENT_TRACE
    $seqSnapshot = $script:_LOOP_EVENT_SEQ
    if ((Test-EventTrace -GoldenTracePath $goldenTrace) -and
        $script:_LOOP_EVENT_TRACE -eq $traceSnapshot -and $script:_LOOP_EVENT_SEQ -eq $seqSnapshot) {
        Ok "TEST-009.10: comparator normalizes values, matches the golden trace, and is pure"
    } else {
        Fail "TEST-009.10: comparator failed normalization, identity, or purity"
    }

    foreach ($mutation in @("kind", "producer", "value", "count")) {
        $mutatedTrace = Join-Path $work "golden-trace.$mutation.json"
        switch ($mutation) {
            "kind" { & jq '.[0].kind = "review-loop-presence"' $goldenTrace | Set-Content -LiteralPath $mutatedTrace -Encoding utf8 }
            "producer" { & jq '.[4].producer = "quality-gate-outcome:escalation"' $goldenTrace | Set-Content -LiteralPath $mutatedTrace -Encoding utf8 }
            "value" { & jq '.[7].value = "Implementation Complete"' $goldenTrace | Set-Content -LiteralPath $mutatedTrace -Encoding utf8 }
            "count" { & jq 'del(.[7])' $goldenTrace | Set-Content -LiteralPath $mutatedTrace -Encoding utf8 }
        }
        if (Test-EventTrace -GoldenTracePath $mutatedTrace 2>$null) {
            Fail "TEST-009.11: $mutation mismatch was accepted"
        } else {
            Ok "TEST-009.11: $mutation mismatch is rejected"
        }
    }

    $eventTraceBody = [IO.File]::ReadAllLines($loopDriver)
    $insideEventTrace = $false
    $callsAppender = $false
    foreach ($line in $eventTraceBody) {
        if ($line -cmatch '^function Test-EventTrace(?:\s|\{)') { $insideEventTrace = $true }
        if ($insideEventTrace -and $line -cmatch 'Write-LoopTraceEvent') { $callsAppender = $true }
        if ($insideEventTrace -and $line -eq '}') { break }
    }
    if (-not $callsAppender) {
        Ok "TEST-009.12: Test-EventTrace is a pure reader and never calls the appender"
    } else {
        Fail "TEST-009.12: Test-EventTrace calls the trace appender"
    }

    $misCasedRepoRoot = ($script:SddLoopRepoRoot -creplace '\\', '/').ToUpperInvariant()
    $script:_LOOP_EVENT_TRACE = & jq -cn --arg value ($misCasedRepoRoot + '/plugins/sdd-review-loop/SKILL.md') `
        '[{kind:"skill-order", producer:"skill-order:invocation", seq:1, value:$value}]'
    $misCasedPathGolden = Join-Path $work "golden-trace.mis-cased-path.json"
    & jq -n '[{kind:"skill-order", producer:"skill-order:invocation", seq:1,
      value:"plugins/sdd-review-loop/SKILL.md"}]' | Set-Content -LiteralPath $misCasedPathGolden -Encoding utf8
    if (Test-EventTrace -GoldenTracePath $misCasedPathGolden 2>$null) {
        Fail "TEST-009.13: a mis-cased repository path was canonicalized as a match"
    } else {
        Ok "TEST-009.13: path canonicalization is case-sensitive"
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
