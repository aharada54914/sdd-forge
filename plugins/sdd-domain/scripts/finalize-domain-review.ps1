# Thin PowerShell dispatcher for finalize-domain-review (REQ-004); the
# Python master beside this file is the only behavioral implementation.
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "../../sdd-quality-loop/scripts/lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("finalize-domain-review: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

# Make the currently executing PowerShell host available to the shared validator.
$hostDirectory = Split-Path -Parent (Get-Process -Id $PID).Path
$env:PATH = $hostDirectory + [IO.Path]::PathSeparator + $env:PATH

Invoke-SddPyDispatch -Master (Join-Path $dir "finalize-domain-review.py") -DiagnosticPrefix "finalize-domain-review: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE" -Arguments (@("--runtime", "powershell") + $args)
