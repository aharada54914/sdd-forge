# Thin PowerShell dispatcher for finalize-domain-review (REQ-004); the
# Python master beside this file is the only behavioral implementation.
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "../../sdd-quality-loop/scripts/lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    [Console]::Error.WriteLine("finalize-domain-review: operation=finalize-domain-review cause=missing-dispatch-helper (../../sdd-quality-loop/scripts/lib/py-dispatch.ps1 unavailable)")
    exit 3
}
. $lib

# Make the currently executing PowerShell host available to the shared validator.
$hostDirectory = Split-Path -Parent (Get-Process -Id $PID).Path
$env:PATH = if ($env:PATH) { $hostDirectory + [IO.Path]::PathSeparator + $env:PATH } else { $hostDirectory }

Invoke-SddPyDispatch -Master (Join-Path $dir "finalize-domain-review.py") -DiagnosticPrefix "finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE" -Arguments (@("--runtime", "powershell") + $args)
