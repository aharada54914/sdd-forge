$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PromoteToken = 'promote-golden-baseline' + '.sh'
$CandidateToken = '--write-' + 'candidate'
$Workflow = if ([string]::IsNullOrEmpty($env:GOLDEN_WORKFLOW_UNDER_TEST)) { Join-Path $Root '.github/workflows/test.yml' } else { $env:GOLDEN_WORKFLOW_UNDER_TEST }
$Promote = if ([string]::IsNullOrEmpty($env:GOLDEN_PROMOTE_UNDER_TEST)) { Join-Path $Root ('tests/promote-golden-baseline' + '.ps1') } else { $env:GOLDEN_PROMOTE_UNDER_TEST }
$BaselineRoot = Join-Path $Root 'specs/epic-195-a7-compatibility/verification/golden-baseline'
$Canonical = Join-Path $BaselineRoot 'canonical'
$Passed = 0
$Failed = 0
$Work = Join-Path ([System.IO.Path]::GetTempPath()) ("golden-ci-guard-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work | Out-Null

function Add-Pass([string]$Message) { $script:Passed++; Write-Output "ok: $Message" }
function Add-Fail([string]$Message) { $script:Failed++; Write-Output "FAIL: $Message" }

function Get-TreeHash([string]$Path) {
    $Program = @'
import hashlib
import sys
from pathlib import Path
root = Path(sys.argv[1])
digest = hashlib.sha256()
if root.is_dir():
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode("utf-8") + b"\0" + path.read_bytes() + b"\0")
print(digest.hexdigest())
'@
    return ($Program | & python3 - $Path)
}

function Test-WorkflowSafe([string]$Path) {
    if (-not [IO.File]::Exists($Path)) { return $false }
    $Text = [IO.File]::ReadAllText($Path)
    return $Text.IndexOf($PromoteToken, [StringComparison]::Ordinal) -lt 0 -and
        $Text.IndexOf($CandidateToken, [StringComparison]::Ordinal) -lt 0
}

function Invoke-PromoteProcess {
    param(
        [AllowNull()][string]$CiValue,
        [string[]]$Arguments
    )
    # The production script writes through Console.Error, which bypasses
    # PowerShell's redirectable error stream. A child process captures the
    # actual OS stderr bytes and exit status without changing that script.
    $Info = [Diagnostics.ProcessStartInfo]::new()
    $Info.FileName = (Get-Process -Id $PID).Path
    $Info.UseShellExecute = $false
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Info.ArgumentList.Add('-NoProfile')
    $Info.ArgumentList.Add('-File')
    $Info.ArgumentList.Add($Promote)
    foreach ($Argument in $Arguments) { $Info.ArgumentList.Add($Argument) }
    if ($null -eq $CiValue) { [void]$Info.Environment.Remove('CI') } else { $Info.Environment['CI'] = $CiValue }
    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $Info
    [void]$Process.Start()
    $Stdout = $Process.StandardOutput.ReadToEnd()
    $Stderr = $Process.StandardError.ReadToEnd()
    $Process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $Process.ExitCode; Stdout = $Stdout.TrimEnd(); Stderr = $Stderr.TrimEnd() }
}

try {
    $WorkflowCasePasses = Test-WorkflowSafe $Workflow
    foreach ($Token in @($PromoteToken, $CandidateToken)) {
        $Fixture = Join-Path $Work ("workflow-" + [guid]::NewGuid().ToString('N') + '.yml')
        [IO.File]::WriteAllText($Fixture, "run: $Token`n")
        if (Test-WorkflowSafe $Fixture) { $WorkflowCasePasses = $false }
    }
    $Miscased = Join-Path $Work 'workflow-miscased.yml'
    [IO.File]::WriteAllText($Miscased, "run: $($PromoteToken.ToUpperInvariant()) $($CandidateToken.ToUpperInvariant())`n")
    if (-not (Test-WorkflowSafe $Miscased)) { $WorkflowCasePasses = $false }
    if ($WorkflowCasePasses) { Add-Pass 'AC-040 rejects both exact mutation-capable workflow references' } else { Add-Fail 'AC-040 workflow scan must reject either exact forbidden reference and accept mis-cased text' }

    $BaselineBefore = Get-TreeHash $BaselineRoot
    $CiCandidate = Join-Path $Work 'must-not-be-read'
    $CiResult = Invoke-PromoteProcess -CiValue 'false' -Arguments @($CiCandidate, '--approved-by', 'test-human')
    $BaselineAfter = Get-TreeHash $BaselineRoot
    $ExpectedCi = 'promote-golden-baseline: promotion is forbidden when CI is non-empty'
    if ($CiResult.ExitCode -ne 0 -and $CiResult.Stdout -ceq '' -and $CiResult.Stderr -ceq $ExpectedCi -and $BaselineAfter -ceq $BaselineBefore -and -not (Test-Path -LiteralPath $CiCandidate)) {
        Add-Pass 'AC-041 refuses non-empty CI before candidate or canonical file I/O'
    } else {
        Add-Fail "AC-041 CI refusal mismatch (status=$($CiResult.ExitCode) candidate_exists=$(Test-Path -LiteralPath $CiCandidate))"
    }

    $ApprovalCandidate = Join-Path $Work 'must-not-be-written'
    $CanonicalBefore = Get-TreeHash $Canonical
    $ApprovalResult = Invoke-PromoteProcess -CiValue $null -Arguments @($ApprovalCandidate)
    $EmptyApprovalResult = Invoke-PromoteProcess -CiValue $null -Arguments @($ApprovalCandidate, '--approved-by', '')
    $CanonicalAfter = Get-TreeHash $Canonical
    $ExpectedUsage = 'Usage: promote-golden-baseline.ps1 <candidate-path> --approved-by <human-identifier>'
    if ($ApprovalResult.ExitCode -ne 0 -and $ApprovalResult.Stdout -ceq '' -and $ApprovalResult.Stderr -ceq $ExpectedUsage -and
        $EmptyApprovalResult.ExitCode -ne 0 -and $EmptyApprovalResult.Stdout -ceq '' -and $EmptyApprovalResult.Stderr -ceq $ExpectedUsage -and
        $CanonicalAfter -ceq $CanonicalBefore -and -not (Test-Path -LiteralPath $ApprovalCandidate)) {
        Add-Pass 'AC-041 refuses omitted or empty approval without canonical write'
    } else {
        Add-Fail "AC-041 approval refusal mismatch (omitted_status=$($ApprovalResult.ExitCode) empty_status=$($EmptyApprovalResult.ExitCode) candidate_exists=$(Test-Path -LiteralPath $ApprovalCandidate))"
    }

    Write-Output "$Passed passed, $Failed failed"
    if ($Passed -ne 3 -or $Failed -ne 0) { exit 1 }
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
