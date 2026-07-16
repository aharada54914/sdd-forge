[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stage = if ($env:PHASE2_HUMAN_COPY_ROOT) { $env:PHASE2_HUMAN_COPY_ROOT } else { Join-Path $root 'specs/epic-136-phase2-gates/human-copy' }
$checkSh = if ($env:CHECK_RISK_SH) { $env:CHECK_RISK_SH } else { Join-Path $stage 'plugins/sdd-lite/scripts/check-risk-upgrade.sh' }
$checkPs1 = if ($env:CHECK_RISK_PS1) { $env:CHECK_RISK_PS1 } else { Join-Path $stage 'plugins/sdd-lite/scripts/check-risk-upgrade.ps1' }
$policy = if ($env:RISK_POLICY) { $env:RISK_POLICY } else { Join-Path $stage 'plugins/sdd-lite/references/risk-upgrade-policy.md' }
$liteSkill = if ($env:LITE_SPEC_SKILL) { $env:LITE_SPEC_SKILL } else { Join-Path $stage 'plugins/sdd-lite/skills/lite-spec/SKILL.md' }
$shipSkill = if ($env:SHIP_SKILL) { $env:SHIP_SKILL } else { Join-Path $stage 'plugins/sdd-ship/skills/ship/SKILL.md' }
$bash = if ($env:BASH_EXE) { $env:BASH_EXE } else { 'bash.exe' }

$passed = 0
$failed = 0
$tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("phase2-risk-upgrade-" + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempDirectory) | Out-Null

function Add-Pass([string]$Message) {
    $script:passed += 1
    Write-Output "ok: $Message"
}

function Add-Failure([string]$Message) {
    $script:failed += 1
    Write-Output "FAIL: $Message"
}

function Convert-ToBashPath([string]$Path) {
    if ($Path -match '^[A-Za-z]:\\') {
        return (& cygpath.exe -u $Path).Trim()
    }
    return $Path
}

function Invoke-RiskChecker([string]$Kind, [string]$InputPath) {
    $outputPath = Join-Path $tempDirectory "$Kind.out"
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        if ($Kind -eq 'sh') {
            & $bash (Convert-ToBashPath $checkSh) (Convert-ToBashPath $InputPath) *> $outputPath
        } else {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -Path $InputPath *> $outputPath
        }
        $status = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output = if (Test-Path -LiteralPath $outputPath) { ([IO.File]::ReadAllText($outputPath)).Replace("`r", '').TrimEnd("`n") } else { '' }
    return [PSCustomObject]@{ Status = $status; Output = $output }
}

function Invoke-RiskCheckerWithoutPath([string]$Kind) {
    $outputPath = Join-Path $tempDirectory "$Kind.out"
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        if ($Kind -eq 'sh') {
            & $bash (Convert-ToBashPath $checkSh) *> $outputPath
        } else {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checkPs1 *> $outputPath
        }
        $status = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output = if (Test-Path -LiteralPath $outputPath) { ([IO.File]::ReadAllText($outputPath)).Replace("`r", '').TrimEnd("`n") } else { '' }
    return [PSCustomObject]@{ Status = $status; Output = $output }
}

function Assert-Case([string]$Label, [string]$Contents, [int]$ExpectedStatus, [string]$ExpectedOutput) {
    $inputPath = Join-Path $tempDirectory 'input.txt'
    [IO.File]::WriteAllText($inputPath, $Contents, [Text.UTF8Encoding]::new($false))
    $sh = Invoke-RiskChecker 'sh' $inputPath
    $ps1 = Invoke-RiskChecker 'ps1' $inputPath
    if ($sh.Status -eq $ExpectedStatus -and $ps1.Status -eq $ExpectedStatus -and $sh.Output -eq $ExpectedOutput -and $ps1.Output -eq $ExpectedOutput) {
        Add-Pass $Label
    } else {
        Add-Failure "$Label expected=[${ExpectedStatus}:$ExpectedOutput] sh=[$($sh.Status):$($sh.Output)] ps1=[$($ps1.Status):$($ps1.Output)]"
    }
}

function Assert-Unavailable([string]$Label, [string]$InputPath) {
    $expected = 'risk-upgrade: input unavailable'
    $sh = Invoke-RiskChecker 'sh' $InputPath
    $ps1 = Invoke-RiskChecker 'ps1' $InputPath
    if ($sh.Status -eq 2 -and $ps1.Status -eq 2 -and $sh.Output -eq $expected -and $ps1.Output -eq $expected) {
        Add-Pass $Label
    } else {
        Add-Failure "$Label expected=[2:$expected] sh=[$($sh.Status):$($sh.Output)] ps1=[$($ps1.Status):$($ps1.Output)]"
    }
}

function Assert-UnavailableWithoutPath() {
    $expected = 'risk-upgrade: input unavailable'
    $sh = Invoke-RiskCheckerWithoutPath 'sh'
    $ps1 = Invoke-RiskCheckerWithoutPath 'ps1'
    if ($sh.Status -eq 2 -and $ps1.Status -eq 2 -and $sh.Output -eq $expected -and $ps1.Output -eq $expected) {
        Add-Pass 'missing checker path fails closed'
    } else {
        Add-Failure "missing checker path expected=[2:$expected] sh=[$($sh.Status):$($sh.Output)] ps1=[$($ps1.Status):$($ps1.Output)]"
    }
}

function Invoke-RiskCheckerWithCygpathFailure([string]$InputPath) {
    $outputPath = Join-Path $tempDirectory 'cygpath-failure.out'
    $fakeBin = Join-Path $tempDirectory 'cygpath-failure-bin'
    $fakeCygpath = Join-Path $fakeBin 'cygpath'
    [IO.Directory]::CreateDirectory($fakeBin) | Out-Null
    [IO.File]::WriteAllText($fakeCygpath, @'
#!/usr/bin/env bash
printf '%s\n' 'synthetic cygpath failure' >&2
exit 71
'@, [Text.UTF8Encoding]::new($false))

    $bashChecker = Convert-ToBashPath $checkSh
    $bashInput = Convert-ToBashPath $InputPath
    & $bash -c 'chmod +x "$1"' -- (Convert-ToBashPath $fakeCygpath)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to make the cygpath failure fixture executable.'
    }

    $previousPath = $env:PATH
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $env:PATH = "$fakeBin;$previousPath"
        $ErrorActionPreference = 'Continue'
        & $bash $bashChecker $bashInput *> $outputPath
        $status = $LASTEXITCODE
    } finally {
        $env:PATH = $previousPath
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output = if (Test-Path -LiteralPath $outputPath) { ([IO.File]::ReadAllText($outputPath)).Replace("`r", '').TrimEnd("`n") } else { '' }
    return [PSCustomObject]@{ Status = $status; Output = $output }
}

function Assert-CygpathFailureUnavailable() {
    $inputPath = Join-Path $tempDirectory 'cygpath-failure-input.md'
    [IO.File]::WriteAllText($inputPath, 'ordinary source text', [Text.UTF8Encoding]::new($false))
    $result = Invoke-RiskCheckerWithCygpathFailure $inputPath
    $expected = 'risk-upgrade: input unavailable'
    if ($result.Status -eq 2 -and $result.Output -eq $expected) {
        Add-Pass 'shell checker converts cygpath conversion failure to unavailable input'
    } else {
        Add-Failure "shell checker cygpath failure expected=[2:$expected] actual=[$($result.Status):$($result.Output)]"
    }
}

function Assert-Contains([string]$Label, [string]$Path, [string]$Needle) {
    if ((Test-Path -LiteralPath $Path -PathType Leaf) -and ([IO.File]::ReadAllText($Path).Contains($Needle))) {
        Add-Pass $Label
    } else {
        Add-Failure "$Label missing [$Needle] in $Path"
    }
}

function Assert-Ordered([string]$Label, [string]$Path, [string]$First, [string]$Second) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $text = [IO.File]::ReadAllText($Path)
        $firstIndex = $text.IndexOf($First, [StringComparison]::Ordinal)
        $secondIndex = $text.IndexOf($Second, [StringComparison]::Ordinal)
        if ($firstIndex -ge 0 -and $secondIndex -ge 0 -and $firstIndex -lt $secondIndex) {
            Add-Pass $Label
            return
        }
    }
    Add-Failure "$Label requires [$First] before [$Second] in $Path"
}

try {
    Assert-Case 'AUTH_BOUNDARY is first and all triggers preserve matrix order' 'Authorization with an access token, MCP, third-party APIs, secret, and GitHub Actions' 10 'full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY,TOKEN_CREDENTIAL,MCP,EXTERNAL_API,SECRET,GITHUB_ACTIONS'
    Assert-Case 'authentication and authorization vocabulary forces the auth boundary' 'auth authentication authorization oauth oidc' 10 'full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY'
    Assert-Case 'token, credential, password, and private-key vocabulary forces full' 'access token credentials passwords private keys' 10 'full-required: TOKEN_CREDENTIAL; triggers=TOKEN_CREDENTIAL'
    Assert-Case 'MCP vocabulary forces full' 'MCP integration' 10 'full-required: MCP; triggers=MCP'
    Assert-Case 'external and third-party API vocabulary forces full' 'external APIs and third-party API' 10 'full-required: EXTERNAL_API; triggers=EXTERNAL_API'
    Assert-Case 'secret vocabulary forces full' 'secrets rotation' 10 'full-required: SECRET; triggers=SECRET'
    Assert-Case 'GitHub Actions vocabulary forces full' 'GitHub Actions workflow' 10 'full-required: GITHUB_ACTIONS; triggers=GITHUB_ACTIONS'
    $hyphenAndNonAscii = 'token-value design-token token' + ([string][char]0x5024)
    Assert-Case 'hyphen and non-ASCII token boundaries retain token escalation' $hyphenAndNonAscii 10 'full-required: TOKEN_CREDENTIAL; triggers=TOKEN_CREDENTIAL'
    Assert-Case 'design-token and API-design exclusions remain lite eligible' 'design tokens API design author oauthless mcpish secretion token_value' 0 'lite-eligible'
    $designTokenBoundaryVariants = 'design token/design tokens@design token"design tokens|design token' + ([string][char]0x5024)
    Assert-Case 'design-token exclusion accepts every token boundary class' $designTokenBoundaryVariants 0 'lite-eligible'
    $nonAsciiToken = ([string][char]0x65e5) + ([string][char]0x672c) + ' token' + ([string][char]0x5024)
    Assert-Case 'non-ASCII is a boundary without becoming unavailable' $nonAsciiToken 10 'full-required: TOKEN_CREDENTIAL; triggers=TOKEN_CREDENTIAL'
    $ordinaryNonAscii = ([string][char]0x65e5) + ([string][char]0x672c) + ([string][char]0x8a9e)
    Assert-Case 'ordinary valid non-ASCII text is lite eligible' $ordinaryNonAscii 0 'lite-eligible'

    $invalidUtf8 = Join-Path $tempDirectory 'invalid-utf8.txt'
    [IO.File]::WriteAllBytes($invalidUtf8, [byte[]](0x69, 0x6e, 0x76, 0x61, 0x6c, 0x69, 0x64, 0xc3, 0x28))
    Assert-Unavailable 'invalid UTF-8 fails closed' $invalidUtf8
    $nulInput = Join-Path $tempDirectory 'nul.txt'
    [IO.File]::WriteAllBytes($nulInput, [byte[]](0x76, 0x61, 0x6c, 0x69, 0x64, 0x00, 0x6e, 0x75, 0x6c))
    Assert-Unavailable 'NUL input fails closed' $nulInput
    Assert-Unavailable 'opaque URL input fails closed before a lite artifact exists' 'https://example.invalid/opaque-source'
    Assert-Unavailable 'missing ship task or requirements input fails closed' (Join-Path $tempDirectory 'missing-input.md')
    Assert-UnavailableWithoutPath
    Assert-CygpathFailureUnavailable

    Assert-Contains 'policy candidate records the ordered trigger contract' $policy 'AUTH_BOUNDARY'
    Assert-Contains 'policy candidate records the full override and unavailable-input rules' $policy 'does not invoke the scan'
    Assert-Contains 'lite-spec candidate invokes the staged checker' $liteSkill 'check-risk-upgrade.sh'
    Assert-Contains 'lite-spec candidate stops without writes on unavailable input' $liteSkill 'risk-upgrade: input unavailable'
    Assert-Ordered 'lite-spec risk gate runs before its artifact-writing process' $liteSkill '## Risk-Upgrade Gate' '## Process'
    Assert-Contains 'ship candidate keeps the --full scan bypass' $shipSkill '[sdd-ship] Track: full (--full override)'
    Assert-Contains 'ship candidate documents that --full bypasses the scan' $shipSkill '`--full` is the only scan bypass'
    Assert-Contains 'ship candidate recognizes risk-match full precedence' $shipSkill 'full-required:'
    Assert-Contains 'ship candidate stops for unavailable risk input' $shipSkill 'risk-upgrade: input unavailable'
    Assert-Contains 'ship candidate requires both the task block and requirements' $shipSkill 'inputs are mandatory'
    Assert-Contains 'ship risk-hit without full artifacts stops with a bootstrap full-track diagnostic' $shipSkill 'If either is absent, stop before task start and print `[sdd-ship] Full-track artifacts unavailable. Run /sdd-bootstrap:bootstrap for the full track.`'
    Assert-Ordered 'ship keeps the --full override before the risk scan' $shipSkill '[sdd-ship] Track: full (--full override)' 'Risk-upgrade scan'
    Assert-Ordered 'ship evaluates risk before the --lite selection branch' $shipSkill 'Risk-upgrade scan' '`--lite` flag present'
    Assert-Ordered 'ship evaluates risk before the profile selection branch' $shipSkill 'Risk-upgrade scan' 'spec_profile: lite'
    Assert-Ordered 'ship evaluates risk before the default selection branch' $shipSkill 'Risk-upgrade scan' '4. Default'
} finally {
    Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "phase2-risk-upgrade.tests.ps1: $passed passed, $failed failed"
if ($failed -ne 0) { exit 1 }
