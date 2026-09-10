# collector-isolation-regressions.ps1
# Staging-only regression driver for the collector repair candidate.
# Do not execute the human-copy collector. Point RepositoryRoot at the live
# repo root when a human applies this file.

param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot
)

$ErrorActionPreference = "Stop"
$SpecRoot = "specs"

$ScriptUnderTest = Join-Path $RepositoryRoot "plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1"
$PowerShellHost = if ($null -ne (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    (Get-Command pwsh).Source
} else {
    Join-Path $PSHOME "powershell.exe"
}

$Pass = 0
$Fail = 0
$Skip = 0

function ok($msg)   { Write-Host "ok: $msg";   $script:Pass++ }
function fail($msg) { Write-Host "FAIL: $msg"; $script:Fail++ }
function skip($msg) { Write-Host "SKIP: $msg"; $script:Skip++ }

function Invoke-Collector {
    param([string[]]$ArgList)
    $script:CollectorExit = 0
    $script:CollectorOutput = ""
    try {
        $out = & $PowerShellHost -NoLogo -NoProfile -File $ScriptUnderTest @ArgList 2>&1
        $script:CollectorExit = $LASTEXITCODE
        $script:CollectorOutput = ($out -join "`n")
    } catch {
        $script:CollectorExit = 99
        $script:CollectorOutput = $_.ToString()
    }
}

function New-OwnedRoot {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("collector-repair." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

function Normalize-Root {
    param([string]$Path)
    return (([IO.Path]::GetFullPath($Path)) -replace '\\', '/').TrimEnd('/')
}

function Write-Tasks {
    param([string]$Path, [string]$TaskId = "T-004")
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Encoding Utf8 -Path $Path -Value @"
# Tasks

## $TaskId Collector repair

Status: Planned
Risk: high
Cross-Model: enabled
"@
}

function Write-Input {
    param([string]$Path, [string[]]$Lines)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Encoding Utf8 -Path $Path -Value ($Lines -join "`n")
}

function Write-FillerLines {
    param([string]$Path, [int]$Count, [string]$Prefix)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    $lines = 1..$Count | ForEach-Object { "{0} line {1:D4} filler filler filler filler" -f $Prefix, $_ }
    Set-Content -Encoding Utf8 -Path $Path -Value ($lines -join "`n")
}

function Write-DeclaredRowReport {
    param([string]$RepoRoot, [string]$Feature, [string]$TaskId, [string[]]$Paths, [string[]]$Hashes)
    $dir = Join-Path $RepoRoot (Join-Path "reports/implementation" $Feature)
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $bt = [char]96
    $lines = @(
        "# Implementation Report: $TaskId"
        ""
        "## Outputs"
        ""
        "| Path | SHA-256 |"
        "|---|---|"
    )
    for ($i = 0; $i -lt $Paths.Count; $i++) {
        $lines += "| $bt$($Paths[$i])$bt | $bt$($Hashes[$i])$bt |"
    }
    $lines += ""
    $lines += "## Test Evidence"
    $lines += ""
    $lines += "N/A."
    Set-Content -Encoding Utf8 -Path (Join-Path $dir "$TaskId.md") -Value $lines
}

function Write-Contract {
    param([string]$SpecDir, [string]$TaskId, [string[]]$Evidence)
    $verifDir = Join-Path $SpecDir "verification"
    New-Item -ItemType Directory -Path $verifDir -Force | Out-Null
    $contract = [ordered]@{
        task_id = $TaskId
        checks  = @([ordered]@{ id = "check-1"; evidence = $Evidence; red_evidence = @(); green_evidence = @() })
    }
    Set-Content -Encoding Utf8 -Path (Join-Path $verifDir "$TaskId.contract.json") -Value ($contract | ConvertTo-Json -Depth 10)
}

function Write-TaskVerificationFile {
    param([string]$SpecDir, [string]$TaskId, [string]$Name, [string]$Body)
    $dir = Join-Path (Join-Path $SpecDir "verification") $TaskId
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content -Encoding Utf8 -Path (Join-Path $dir $Name) -Value $Body
}

function Read-Bundle {
    param([string]$Path)
    return (Get-Content -Raw -Encoding Utf8 -LiteralPath $Path)
}

function Assert-Exit([string]$Label, [int]$Expected) {
    if ($script:CollectorExit -eq $Expected) { ok $Label } else { fail "$Label expected exit $Expected got $($script:CollectorExit)" }
}
function Assert-Has([string]$Label, [string]$Text, [string]$Needle) {
    if ($Text -match [regex]::Escape($Needle)) { ok $Label } else { fail "$Label missing [$Needle]" }
}
function Assert-Lacks([string]$Label, [string]$Text, [string]$Needle) {
    if ($Text -notmatch [regex]::Escape($Needle)) { ok $Label } else { fail "$Label unexpectedly found [$Needle]" }
}

if ((Normalize-Root $RepositoryRoot) -match '(?i)[\\/]+specs[\\/]+[^\\/]+[\\/]+human-copy(?:[\\/]|$)') {
    throw "RepositoryRoot must point at the live repo root, not the staged human-copy tree."
}

$feature = "epic-195-a7-compatibility"
$taskId = "T-004"
$ownedRoot = New-OwnedRoot
$cleanupRoot = $ownedRoot

try {
    $specRootPath = Join-Path $ownedRoot $SpecRoot
    $specDir = Join-Path $specRootPath $feature
    $outDir = Join-Path $ownedRoot "out"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $bundleSentinel = "BUNDLE" + "_SENTINEL"
    $ordinarySentinel = "ORDINARY" + "_SOURCE" + "_PRESERVED"
    $qualityGateSentinel = "QUALITY" + "_GATE" + "_PRESERVED"
    $taskTestSentinel = "TASK" + "_TEST" + "_PRESERVED"
    $externalSentinel = "EXTERNAL" + "_INDEPENDENT" + "_PRESERVED"
    $contractSentinel = "CONTRACT" + "_EVIDENCE" + "_PRESERVED"
    $headMarker = "HEAD" + "_KEEP"
    $tailMarker = "TAIL" + "_KEEP"
    $verdictName = ("run" + ".verdict" + ".json")
    $crossModelName = ("run" + ".cross-model" + ".json")

    # Case 1: positive control. Ordinary source stays in bundle; declared report/quality-gate
    # content is omitted from the bundle because it is not one of the included paths.
    Write-Tasks -Path (Join-Path $specDir "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $ownedRoot "input.txt") -Lines @("# input", $bundleSentinel)
    Set-Content -Encoding Utf8 -Path (Join-Path $specDir "requirements.md") -Value @"
# Requirements

$ordinarySentinel
"@
    New-Item -ItemType Directory -Path (Join-Path $ownedRoot "reports/quality-gate") -Force | Out-Null
    Set-Content -Encoding Utf8 -Path (Join-Path $ownedRoot "reports/quality-gate/prior.md") -Value $qualityGateSentinel
    Write-TaskVerificationFile -SpecDir $specDir -TaskId $taskId -Name "independent-test.md" -Body $taskTestSentinel
    Write-DeclaredRowReport -RepoRoot $ownedRoot -Feature $feature -TaskId $taskId -Paths @(
        "specs/$feature/requirements.md",
        "reports/quality-gate/prior.md"
    ) -Hashes @(
        (Get-FileHash -LiteralPath (Join-Path $specDir "requirements.md") -Algorithm SHA256).Hash.ToLower(),
        (Get-FileHash -LiteralPath (Join-Path $ownedRoot "reports/quality-gate/prior.md") -Algorithm SHA256).Hash.ToLower()
    )
    Write-Contract -SpecDir $specDir -TaskId $taskId -Evidence @("specs/$feature/requirements.md", "reports/quality-gate/prior.md")

    $positiveOut = Join-Path $outDir "positive.txt"
    Invoke-Collector @(
        "--task", $taskId,
        "--feature", $feature,
        "--input", (Join-Path $ownedRoot "input.txt"),
        "--tasks-file", (Join-Path $specDir "tasks.md"),
        "--spec-root", $specRootPath,
        "--project-root", $ownedRoot,
        "--out", $positiveOut
    )
    Assert-Exit "case-01 exit 0" 0
    $positiveText = Read-Bundle $positiveOut
    Assert-Has "case-01 bundle contains ordinary source" $positiveText $ordinarySentinel
    Assert-Lacks "case-01 bundle omits task verification prose" $positiveText $taskTestSentinel
    Assert-Lacks "case-01 bundle omits quality-gate prose" $positiveText $qualityGateSentinel

    # Case 2: wrong declared hash fails closed and does not write the bundle.
    $root2 = Join-Path $ownedRoot "case-02"
    $specDir2 = Join-Path $root2 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir2 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root2 "input.txt") -Lines @("# input", $bundleSentinel)
    New-Item -ItemType Directory -Path (Join-Path $root2 "reports/quality-gate") -Force | Out-Null
    Set-Content -Encoding Utf8 -Path (Join-Path $root2 "reports/quality-gate/prior.md") -Value $qualityGateSentinel
    Write-DeclaredRowReport -RepoRoot $root2 -Feature $feature -TaskId $taskId -Paths @("reports/quality-gate/prior.md") -Hashes @(("0" * 64))
    Write-Contract -SpecDir $specDir2 -TaskId $taskId -Evidence @("reports/quality-gate/prior.md")
    $out2 = Join-Path $root2 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root2 "input.txt"),"--tasks-file",(Join-Path $specDir2 "tasks.md"),"--spec-root",(Join-Path $root2 $SpecRoot),"--project-root",$root2,"--out",$out2)
    Assert-Exit "case-02 wrong hash exits 1" 1
    if (Test-Path $out2) { fail "case-02 bundle must not be written on a hash mismatch" } else { ok "case-02 bundle not written" }
    Assert-Has "case-02 mentions mismatch" $script:CollectorOutput "hash mismatch"

    # Case 3: absent declared artifact fails closed.
    $root3 = Join-Path $ownedRoot "case-03"
    $specDir3 = Join-Path $root3 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir3 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root3 "input.txt") -Lines @("# input", $bundleSentinel)
    Write-DeclaredRowReport -RepoRoot $root3 -Feature $feature -TaskId $taskId -Paths @("reports/quality-gate/missing.md") -Hashes @(("f" * 64))
    Write-Contract -SpecDir $specDir3 -TaskId $taskId -Evidence @("reports/quality-gate/missing.md")
    $out3 = Join-Path $root3 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root3 "input.txt"),"--tasks-file",(Join-Path $specDir3 "tasks.md"),"--spec-root",(Join-Path $root3 $SpecRoot),"--project-root",$root3,"--out",$out3)
    Assert-Exit "case-03 absent exits 1" 1
    if (Test-Path $out3) { fail "case-03 bundle must not be written on an absent row" } else { ok "case-03 bundle not written" }
    Assert-Has "case-03 mentions missing path" $script:CollectorOutput "missing.md"

    # Case 4: traversal rejected.
    $root4 = Join-Path $ownedRoot "case-04"
    $specDir4 = Join-Path $root4 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir4 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root4 "input.txt") -Lines @("# input", $bundleSentinel)
    Write-DeclaredRowReport -RepoRoot $root4 -Feature $feature -TaskId $taskId -Paths @("reports/quality-gate/../escape.md") -Hashes @(("f" * 64))
    Write-Contract -SpecDir $specDir4 -TaskId $taskId -Evidence @("reports/quality-gate/../escape.md")
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root4 "input.txt"),"--tasks-file",(Join-Path $specDir4 "tasks.md"),"--spec-root",(Join-Path $root4 $SpecRoot),"--project-root",$root4,"--out",(Join-Path $root4 "out.txt"))
    Assert-Exit "case-04 traversal exits 1" 1
    Assert-Has "case-04 mentions traversal" $script:CollectorOutput ".."

    # Case 5: symlink containment, only when supported.
    $root5 = Join-Path $ownedRoot "case-05"
    $specDir5 = Join-Path $root5 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir5 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root5 "input.txt") -Lines @("# input", $bundleSentinel)
    $outside5 = Join-Path $root5 "outside.txt"
    Set-Content -Encoding Utf8 -Path $outside5 -Value "outside"
    $link5 = Join-Path $root5 "reports/quality-gate/link.md"
    New-Item -ItemType Directory -Path (Split-Path $link5) -Force | Out-Null
    $symlinkOk = $true
    try {
        New-Item -ItemType SymbolicLink -Path $link5 -Target $outside5 -ErrorAction Stop | Out-Null
    } catch {
        $symlinkOk = $false
    }
    if ($symlinkOk) {
    Write-DeclaredRowReport -RepoRoot $root5 -Feature $feature -TaskId $taskId -Paths @("reports/quality-gate/link.md") -Hashes @((Get-FileHash -LiteralPath $outside5 -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir5 -TaskId $taskId -Evidence @("reports/quality-gate/link.md")
        Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root5 "input.txt"),"--tasks-file",(Join-Path $specDir5 "tasks.md"),"--spec-root",(Join-Path $root5 $SpecRoot),"--project-root",$root5,"--out",(Join-Path $root5 "out.txt"))
        Assert-Exit "case-05 symlink exits 1" 1
        Assert-Has "case-05 mentions symlink rejection" $script:CollectorOutput "symlink"
    } else {
        skip "case-05 symlink containment unsupported on this host"
    }

    # Case 6: named run.verdict.json excluded via declared route.
    $root6 = Join-Path $ownedRoot "case-06"
    $specDir6 = Join-Path $root6 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir6 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root6 "input.txt") -Lines @("# input", $bundleSentinel)
    Write-TaskVerificationFile -SpecDir $specDir6 -TaskId $taskId -Name $verdictName -Body $qualityGateSentinel
    Write-DeclaredRowReport -RepoRoot $root6 -Feature $feature -TaskId $taskId -Paths @("specs/$feature/verification/$taskId/$verdictName") -Hashes @((Get-FileHash -LiteralPath (Join-Path $specDir6 "verification/$taskId/$verdictName") -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir6 -TaskId $taskId -Evidence @("specs/$feature/verification/$taskId/$verdictName")
    $out6 = Join-Path $root6 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root6 "input.txt"),"--tasks-file",(Join-Path $specDir6 "tasks.md"),"--spec-root",(Join-Path $root6 $SpecRoot),"--project-root",$root6,"--out",$out6)
    Assert-Exit "case-06 verdict route exits 0" 0
    if (Test-Path $out6) { ok "case-06 bundle written" } else { fail "case-06 bundle missing" }
    $bundle6 = Read-Bundle $out6
    Assert-Has "case-06 bundle keeps input sentinel" $bundle6 $bundleSentinel
    Assert-Lacks "case-06 bundle excludes verdict sentinel" $bundle6 $qualityGateSentinel

    # Case 7: named run.cross-model.json excluded via declared route.
    $root7 = Join-Path $ownedRoot "case-07"
    $specDir7 = Join-Path $root7 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir7 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root7 "input.txt") -Lines @("# input", $bundleSentinel)
    Write-TaskVerificationFile -SpecDir $specDir7 -TaskId $taskId -Name $crossModelName -Body $qualityGateSentinel
    Write-DeclaredRowReport -RepoRoot $root7 -Feature $feature -TaskId $taskId -Paths @("specs/$feature/verification/$taskId/$crossModelName") -Hashes @((Get-FileHash -LiteralPath (Join-Path $specDir7 "verification/$taskId/$crossModelName") -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir7 -TaskId $taskId -Evidence @("specs/$feature/verification/$taskId/$crossModelName")
    $out7 = Join-Path $root7 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root7 "input.txt"),"--tasks-file",(Join-Path $specDir7 "tasks.md"),"--spec-root",(Join-Path $root7 $SpecRoot),"--project-root",$root7,"--out",$out7)
    Assert-Exit "case-07 cross-model route exits 0" 0
    if (Test-Path $out7) { ok "case-07 bundle written" } else { fail "case-07 bundle missing" }
    $bundle7 = Read-Bundle $out7
    Assert-Has "case-07 bundle keeps input sentinel" $bundle7 $bundleSentinel
    Assert-Lacks "case-07 bundle excludes cross-model sentinel" $bundle7 $qualityGateSentinel

    # Case 8: same-named independent-test.md outside verification is preserved.
    $root8 = Join-Path $ownedRoot "case-08"
    $specDir8 = Join-Path $root8 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir8 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root8 "input.txt") -Lines @("# input", $bundleSentinel)
    Set-Content -Encoding Utf8 -Path (Join-Path $root8 "independent-test.md") -Value $externalSentinel
    Write-DeclaredRowReport -RepoRoot $root8 -Feature $feature -TaskId $taskId -Paths @("independent-test.md") -Hashes @((Get-FileHash -LiteralPath (Join-Path $root8 "independent-test.md") -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir8 -TaskId $taskId -Evidence @("independent-test.md")
    $out8 = Join-Path $root8 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root8 "input.txt"),"--tasks-file",(Join-Path $specDir8 "tasks.md"),"--spec-root",(Join-Path $root8 $SpecRoot),"--project-root",$root8,"--out",$out8)
    Assert-Exit "case-08 external independent-test exits 0" 0
    Assert-Has "case-08 external independent-test preserved" (Read-Bundle $out8) $externalSentinel

    # Case 9: task verification independent-test.md excluded with custom relative SpecRoot.
    $root9 = Join-Path $ownedRoot "case-09"
    $specRoot9 = "custom-specs"
    $specDir9 = Join-Path $root9 (Join-Path $specRoot9 $feature)
    Write-Tasks -Path (Join-Path $specDir9 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root9 "input.txt") -Lines @("# input", $bundleSentinel)
    Write-TaskVerificationFile -SpecDir $specDir9 -TaskId $taskId -Name "independent-test.md" -Body $taskTestSentinel
    Write-DeclaredRowReport -RepoRoot $root9 -Feature $feature -TaskId $taskId -Paths @("$specRoot9/$feature/verification/$taskId/independent-test.md") -Hashes @((Get-FileHash -LiteralPath (Join-Path $specDir9 "verification/$taskId/independent-test.md") -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir9 -TaskId $taskId -Evidence @("$specRoot9/$feature/verification/$taskId/independent-test.md")
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root9 "input.txt"),"--tasks-file",(Join-Path $specDir9 "tasks.md"),"--spec-root",$specRoot9,"--project-root",$root9,"--out",(Join-Path $root9 "out.txt"))
    Assert-Exit "case-09 custom relative specroot exits 0" 0
    $bundle9 = Read-Bundle (Join-Path $root9 "out.txt")
    Assert-Has "case-09 bundle keeps input sentinel" $bundle9 $bundleSentinel
    Assert-Lacks "case-09 bundle excludes task independent-test sentinel" $bundle9 $taskTestSentinel

    # Case 10: task verification independent-test.md excluded with custom absolute SpecRoot.
    $root10 = Join-Path $ownedRoot "case-10"
    $specRoot10 = Join-Path $root10 "absolute-specs"
    $specDir10 = Join-Path $specRoot10 $feature
    Write-Tasks -Path (Join-Path $specDir10 "tasks.md") -TaskId $taskId
    Write-Input -Path (Join-Path $root10 "input.txt") -Lines @("# input", $bundleSentinel)
    Write-TaskVerificationFile -SpecDir $specDir10 -TaskId $taskId -Name "independent-test.md" -Body $taskTestSentinel
    Write-DeclaredRowReport -RepoRoot $root10 -Feature $feature -TaskId $taskId -Paths @("absolute-specs/$feature/verification/$taskId/independent-test.md") -Hashes @((Get-FileHash -LiteralPath (Join-Path $specDir10 "verification/$taskId/independent-test.md") -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir10 -TaskId $taskId -Evidence @("absolute-specs/$feature/verification/$taskId/independent-test.md")
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root10 "input.txt"),"--tasks-file",(Join-Path $specDir10 "tasks.md"),"--spec-root",$specRoot10,"--project-root",$root10,"--out",(Join-Path $root10 "out.txt"))
    Assert-Exit "case-10 custom absolute specroot exits 0" 0
    $bundle10 = Read-Bundle (Join-Path $root10 "out.txt")
    Assert-Has "case-10 bundle keeps input sentinel" $bundle10 $bundleSentinel
    Assert-Lacks "case-10 bundle excludes task independent-test sentinel" $bundle10 $taskTestSentinel

    # Case 11: contract-evidence route exclusion. The bundle should not include the
    # contract-declared shared evidence path when that evidence is outside the target row set.
    $root11 = Join-Path $ownedRoot "case-11"
    $specDir11 = Join-Path $root11 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir11 "tasks.md") -TaskId $taskId
    New-Item -ItemType Directory -Path (Join-Path $root11 "input") -Force | Out-Null
    Write-Input -Path (Join-Path $root11 "input/ordinary.txt") -Lines @($ordinarySentinel)
    New-Item -ItemType Directory -Path (Join-Path $root11 "reports/quality-gate") -Force | Out-Null
    Set-Content -Encoding Utf8 -Path (Join-Path $root11 "reports/quality-gate/prior.md") -Value $contractSentinel
    Write-DeclaredRowReport -RepoRoot $root11 -Feature $feature -TaskId $taskId -Paths @("input/ordinary.txt") -Hashes @(
        (Get-FileHash -LiteralPath (Join-Path $root11 "input/ordinary.txt") -Algorithm SHA256).Hash.ToLower()
    )
    Write-Contract -SpecDir $specDir11 -TaskId $taskId -Evidence @("reports/quality-gate/prior.md")
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root11 "input"),"--tasks-file",(Join-Path $specDir11 "tasks.md"),"--spec-root",$SpecRoot,"--project-root",$root11,"--out",(Join-Path $root11 "out.txt"))
    Assert-Exit "case-11 contract evidence exits 0" 0
    $bundle11 = Read-Bundle (Join-Path $root11 "out.txt")
    Assert-Has "case-11 ordinary input retained" $bundle11 $ordinarySentinel
    Assert-Lacks "case-11 prior quality-gate marker excluded" $bundle11 $contractSentinel

    # Case 12/13: both budget rebuild tiers must preserve the excluded head/tail of the same large file.
    $root12 = Join-Path $ownedRoot "case-12"
    $specDir12 = Join-Path $root12 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir12 "tasks.md") -TaskId $taskId
    New-Item -ItemType Directory -Path (Join-Path $root12 "empty-input") -Force | Out-Null
    Write-FillerLines -Path (Join-Path $specDir12 "verification/T-004/big.log") -Count 500 -Prefix "BIGT072"
    Write-FillerLines -Path (Join-Path $root12 "small-declared.txt") -Count 20 -Prefix "SMALLT072"
    $budgetBody12 = @($headMarker) + (1..240 | ForEach-Object { "filler line $_" }) + @($tailMarker)
    Write-TaskVerificationFile -SpecDir $specDir12 -TaskId $taskId -Name "independent-test.md" -Body ($budgetBody12 -join "`n")
    Write-DeclaredRowReport -RepoRoot $root12 -Feature $feature -TaskId $taskId -Paths @("small-declared.txt") -Hashes @((Get-FileHash -LiteralPath (Join-Path $root12 "small-declared.txt") -Algorithm SHA256).Hash.ToLower())
    Write-Contract -SpecDir $specDir12 -TaskId $taskId -Evidence @("specs/$feature/verification/T-004/big.log", "specs/$feature/verification/T-004/independent-test.md")
    $out12 = Join-Path $root12 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root12 "empty-input"),"--tasks-file",(Join-Path $specDir12 "tasks.md"),"--spec-root",$SpecRoot,"--project-root",$root12,"--max-bytes","15000","--out",$out12)
    Assert-Exit "case-12 tier-one rebuild exits 0" 0
    $bundle12 = Read-Bundle $out12
    Assert-Has "case-12 bundle contains tier-one marker" $bundle12 "BIGT072 line 0001"
    Assert-Has "case-12 bundle contains declared output" $bundle12 "SMALLT072 line 0001"
    Assert-Has "case-12 bundle keeps declared output tail" $bundle12 "SMALLT072 line 0020"
    if (([regex]::Matches($bundle12, "elided from the middle")).Count -eq 1) { ok "case-12 exactly one middle elision" } else { fail "case-12 expected exactly one middle elision" }
    Assert-Has "case-12 big.log named in elision" $bundle12 "big.log"
    Assert-Lacks "case-12 excluded head marker absent" $bundle12 $headMarker
    Assert-Lacks "case-12 excluded tail marker absent" $bundle12 $tailMarker

    $root13 = Join-Path $ownedRoot "case-13"
    $specDir13 = Join-Path $root13 (Join-Path $SpecRoot $feature)
    Write-Tasks -Path (Join-Path $specDir13 "tasks.md") -TaskId $taskId
    New-Item -ItemType Directory -Path (Join-Path $root13 "empty-input") -Force | Out-Null
    Write-FillerLines -Path (Join-Path $specDir13 "verification/T-004/tiny.log") -Count 100 -Prefix "TINYT074"
    Write-FillerLines -Path (Join-Path $root13 "big-declared.txt") -Count 500 -Prefix "BIGT074"
    New-Item -ItemType Directory -Path (Join-Path $root13 "reports/quality-gate") -Force | Out-Null
    $budgetBody13 = @($headMarker) + (1..240 | ForEach-Object { "filler line $_" }) + @($tailMarker)
    Set-Content -Encoding Utf8 -Path (Join-Path $root13 "reports/quality-gate/prior.md") -Value ($budgetBody13 -join "`n")
    Write-DeclaredRowReport -RepoRoot $root13 -Feature $feature -TaskId $taskId -Paths @("big-declared.txt", "reports/quality-gate/prior.md") -Hashes @(
        (Get-FileHash -LiteralPath (Join-Path $root13 "big-declared.txt") -Algorithm SHA256).Hash.ToLower(),
        (Get-FileHash -LiteralPath (Join-Path $root13 "reports/quality-gate/prior.md") -Algorithm SHA256).Hash.ToLower()
    )
    Write-Contract -SpecDir $specDir13 -TaskId $taskId -Evidence @("specs/$feature/verification/T-004/tiny.log", "reports/quality-gate/prior.md")
    $out13 = Join-Path $root13 "out.txt"
    Invoke-Collector @("--task",$taskId,"--feature",$feature,"--input",(Join-Path $root13 "empty-input"),"--tasks-file",(Join-Path $specDir13 "tasks.md"),"--spec-root",$SpecRoot,"--project-root",$root13,"--max-bytes","15000","--out",$out13)
    Assert-Exit "case-13 tier-two rebuild exits 0" 0
    $bundle13 = Read-Bundle $out13
    Assert-Has "case-13 bundle contains tier-two marker" $bundle13 "BIGT074 line 0001"
    Assert-Has "case-13 bundle contains tier-one marker" $bundle13 "TINYT074 line 0001"
    Assert-Lacks "case-13 middle line elided" $bundle13 "TINYT074 line 0050"
    if (([regex]::Matches($bundle13, "elided from the middle")).Count -eq 2) { ok "case-13 two middle elisions" } else { fail "case-13 expected exactly two middle elisions" }
    Assert-Has "case-13 tiny.log named in elision" $bundle13 "tiny.log"
    Assert-Has "case-13 big-declared named in elision" $bundle13 "big-declared.txt"
    Assert-Lacks "case-13 excluded head marker absent" $bundle13 $headMarker
    Assert-Lacks "case-13 excluded tail marker absent" $bundle13 $tailMarker

    Write-Host "PASS=$Pass FAIL=$Fail SKIP=$Skip"
    if ($Fail -gt 0) { exit 1 }
    exit 0
} finally {
    Remove-Item -Recurse -Force -LiteralPath $cleanupRoot -ErrorAction SilentlyContinue
}
