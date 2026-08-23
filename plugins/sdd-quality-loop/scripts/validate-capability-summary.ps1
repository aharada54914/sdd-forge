# Thin PowerShell dispatcher for validate-capability-summary (Python master).
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("validate-capability-summary: VALIDATE_CAPABILITY_SUMMARY_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "validate-capability-summary.py") -DiagnosticPrefix "validate-capability-summary: VALIDATE_CAPABILITY_SUMMARY_RUNTIME_UNAVAILABLE" -Arguments $args
