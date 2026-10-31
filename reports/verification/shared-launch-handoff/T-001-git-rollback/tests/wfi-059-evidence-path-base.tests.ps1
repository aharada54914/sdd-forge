# WFI-059 designed-red regression: this suite MUST fail until the staged
# protected-script patch is applied, then pass unchanged.
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CheckPs1 = if ($env:WFI_059_CHECK_PS1) { $env:WFI_059_CHECK_PS1 } else { Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/check-contract.ps1' }
$PpiPs1 = if ($env:WFI_059_PPI_PS1) { $env:WFI_059_PPI_PS1 } else { Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1' }
$Work = Join-Path ([IO.Path]::GetTempPath()) ("wfi-059-" + [guid]::NewGuid().ToString('N'))
$Pass = 0
$Fail = 0

function Ok([string]$Message) { Write-Host "ok: $Message"; $script:Pass++ }
function Fail([string]$Message) { Write-Host "FAIL: $Message"; $script:Fail++ }

function Write-Contract([string]$Evidence) {
    $checks = @('lint', 'typecheck', 'unit-tests', 'build', 'placeholder-scan', 'task-state-check') | ForEach-Object {
        [ordered]@{ id = $_; required = $true; passes = $true; evidence = $Evidence; waiver_reason = '' }
    }
    [ordered]@{ task_id = 'T-001'; feature = 'wfi-059'; checks = $checks } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:Contract -Encoding utf8
}

function Invoke-Check([string]$Base) {
    $text = & pwsh -NoProfile -File $CheckPs1 $script:Contract $Base 2>&1 | Out-String
    $script:CheckExit = $LASTEXITCODE
    $script:CheckOutput = $text
}

function Invoke-Prepare {
    # The preparer parses POSIX-style "--task" flags in BOTH runtimes; it has no
    # PowerShell param block. The earlier "-TaskId/-Feature/-InputDir/..." form
    # never reached any code under test -- it exited 2 with
    # "unknown argument: -TaskId", which the assertions below then reported as
    # an annotation failure.
    #
    # --spec-root is deliberately omitted: it is joined against --project-root,
    # so an ABSOLUTE path resolves to nothing and the preparer emits a bundle
    # containing only its own header (input_digest e3b0c442..., the sha256 of
    # the empty string), making every content assertion vacuous.
    $text = & pwsh -NoProfile -File $PpiPs1 --task T-001 --feature wfi-059 --input $script:InputDir --tasks-file $script:Tasks --project-root $script:Root --out $script:Bundle 2>&1 | Out-String
    $script:PrepareExit = $LASTEXITCODE
    $script:PrepareOutput = $text
}

try {
    $Root = Join-Path $Work 'project'
    $Specs = Join-Path $Root 'specs'
    $Spec = Join-Path $Specs 'wfi-059'
    $Verification = Join-Path $Spec 'verification'
    $InputDir = Join-Path $Root 'input'
    $Tasks = Join-Path $Root 'tasks.md'
    $Contract = Join-Path $Verification 'T-001.contract.json'
    $Bundle = Join-Path $Root 'bundle.txt'
    New-Item -ItemType Directory -Force -Path $Verification, $InputDir | Out-Null
    git -C $Root init -q
    git -C $Root config user.email wfi-059@example.invalid
    git -C $Root config user.name WFI-059
    "# Tasks`n`n## T-001 Fixture`n`nStatus: Planned`nRisk: low`nCross-Model: enabled`n" | Set-Content -LiteralPath $Tasks -Encoding utf8
    '# Clean input' | Set-Content -LiteralPath (Join-Path $InputDir 'context.md') -Encoding utf8
    'WFI-059-EVIDENCE-CONTENT' | Set-Content -LiteralPath (Join-Path $Verification 'evidence.log') -Encoding utf8
    git -C $Root add tasks.md input/context.md specs/wfi-059/verification/evidence.log
    git -C $Root commit -q -m fixture

    Write-Contract 'verification/evidence.log'
    Invoke-Check $Spec
    if ($CheckExit -ne 0 -and $CheckOutput.Contains("project-root-relative base: $Root")) {
        Ok 'spec-relative evidence is rejected with the canonical project-root base'
    } else {
        Fail "spec-relative evidence must be rejected from project root; exit=$CheckExit output=$CheckOutput"
    }
    Invoke-Prepare
    # The annotation names the join as "<project-root>/<path>", NOT as an
    # absolute path. Measured: the bundle sanitizer redacts every /home, /root,
    # /Users, /var, /etc, /usr, /opt, /tmp and /private path before a bundle
    # reaches a vendor, so an absolute form always arrives as "no file exists
    # at [PATH_REDACTED]" -- strictly less diagnosable than the "there" it
    # replaces. The placeholder survives sanitization and still carries both
    # halves of the defect: the relative path the contract wrote, and the base
    # it was joined against. Owner-approved wording change, 2026-09-04;
    # recorded in WFI-059.
    $Attempted = '<project-root>/verification/evidence.log'
    $Marker = "[contract names this evidence path but no file exists at $Attempted]"
    if ($PrepareExit -eq 0 -and (Get-Content -LiteralPath $Bundle -Raw).Contains($Marker)) {
        Ok 'missing-evidence annotation names the attempted project-root join'
    } else {
        Fail "annotation must name $Attempted; exit=$PrepareExit output=$PrepareOutput"
    }

    Write-Contract 'specs/wfi-059/verification/evidence.log'
    Invoke-Check $Root
    if ($CheckExit -eq 0) { Ok 'canonical project-root-relative contract passes' } else { Fail "canonical contract must pass; output=$CheckOutput" }
    Invoke-Prepare
    if ($PrepareExit -eq 0 -and (Get-Content -LiteralPath $Bundle -Raw).Contains('WFI-059-EVIDENCE-CONTENT')) {
        Ok 'canonical evidence content reaches the bundle'
    } else {
        Fail "canonical evidence must reach bundle; exit=$PrepareExit output=$PrepareOutput"
    }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
}

Write-Host "$Pass passed, $Fail failed"
if ($Fail -ne 0) { exit 1 }
