$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Checker = Join-Path $Root "plugins/sdd-bootstrap/scripts/check-sdd-structure.ps1"
$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-feature-check-" + [guid]::NewGuid())
$Pass = 0
$Fail = 0

function Record-Pass([string]$Label) {
    $script:Pass++
    Write-Host "PASS: $Label"
}

function Record-Fail([string]$Label) {
    $script:Fail++
    Write-Host "FAIL: $Label"
}

function Invoke-Checker {
    param([string[]]$Arguments)
    $output = & pwsh -NoProfile -File $Checker @Arguments 2>&1
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = (($output | ForEach-Object { "$_" }) -join "`n")
    }
}

function Assert-Result {
    param(
        [int]$ExitCode,
        [string]$Output,
        [string]$Label,
        [string[]]$Arguments
    )
    $result = Invoke-Checker -Arguments $Arguments
    if ($result.ExitCode -eq $ExitCode -and $result.Output -eq $Output) {
        Record-Pass $Label
    } else {
        Record-Fail "$Label (exit=$($result.ExitCode) output=$($result.Output))"
    }
}

try {
    $Repo = Join-Path $Fixture "repo"
    $directories = @(
        "specs", "reports/implementation", "reports/quality-gate", "docs/adr",
        "docs/review-tickets", "contracts", "docs/architecture", "specs/legacy-lite"
    )
    foreach ($directory in $directories) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Repo $directory) | Out-Null
    }
    New-Item -ItemType File -Force -Path (Join-Path $Repo "AGENTS.md") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $Repo "CLAUDE.md") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $Repo "specs/legacy-lite/requirements.md") | Out-Null

    $baseline = "host: local`ncheck-sdd-structure: OK"
    Assert-Result 0 $baseline "TEST-011 PowerShell repository-only output is unchanged" @("-Root", $Repo)
    Assert-Result 0 $baseline "TEST-013 PowerShell does not implicitly validate LITE/legacy specs" @("-Root", $Repo)

    $feature = "complete-feature"
    $featureDir = Join-Path $Repo "specs/$feature"
    New-Item -ItemType Directory -Force -Path $featureDir | Out-Null
    $files = @(
        "requirements.md", "design.md", "ux-spec.md", "frontend-spec.md",
        "infra-spec.md", "security-spec.md", "acceptance-tests.md", "tasks.md",
        "traceability.md"
    )
    foreach ($name in $files) {
        New-Item -ItemType File -Force -Path (Join-Path $featureDir $name) | Out-Null
    }

    Assert-Result 0 $baseline "TEST-012 PowerShell accepts complete nine-file feature" @("-Root", $Repo, "-Feature", $feature)

    foreach ($name in $files) {
        Remove-Item -LiteralPath (Join-Path $featureDir $name)
        $expected = "missing: specs/$feature/$name`nhost: local`ncheck-sdd-structure: FAIL (1 missing)"
        Assert-Result 1 $expected "TEST-012 PowerShell missing $name has one stable diagnostic" @("-Root", $Repo, "-Feature", $feature)
        New-Item -ItemType File -Force -Path (Join-Path $featureDir $name) | Out-Null
    }

    foreach ($invalid in @("", "/tmp/outside", "../outside", "Uppercase", "under_score")) {
        Assert-Result 1 "invalid feature: $invalid" "TEST-019 PowerShell invalid selector '$invalid' fails closed" @("-Root", $Repo, "-Feature", $invalid)
    }

    $outside = Join-Path $Fixture "outside-feature"
    New-Item -ItemType Directory -Force -Path $outside | Out-Null
    foreach ($name in $files) {
        New-Item -ItemType File -Force -Path (Join-Path $outside $name) | Out-Null
    }
    New-Item -ItemType SymbolicLink -Path (Join-Path $Repo "specs/linked-feature") -Target $outside | Out-Null
    Assert-Result 1 "invalid feature: linked-feature" "TEST-019 PowerShell rejects a feature-directory symlink before traversal" @("-Root", $Repo, "-Feature", "linked-feature")

    $linkedFile = Join-Path $Repo "specs/linked-file"
    New-Item -ItemType Directory -Force -Path $linkedFile | Out-Null
    foreach ($name in $files) {
        New-Item -ItemType File -Force -Path (Join-Path $linkedFile $name) | Out-Null
    }
    Remove-Item -LiteralPath (Join-Path $linkedFile "ux-spec.md")
    New-Item -ItemType SymbolicLink -Path (Join-Path $linkedFile "ux-spec.md") -Target (Join-Path $outside "ux-spec.md") | Out-Null
    Assert-Result 1 "invalid feature: linked-file" "TEST-019 PowerShell rejects a feature-file symlink before traversal" @("-Root", $Repo, "-Feature", "linked-file")
} finally {
    Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS: $Pass"
Write-Host "FAIL: $Fail"
if ($Fail -ne 0) { exit 1 }
exit 0
