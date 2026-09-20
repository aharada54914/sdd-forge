# Thin PowerShell dispatcher for detect-policy-weakening (REQ-006); the
# Python master beside this file is the only behavioral implementation.
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("detect-policy-weakening: DETECT_POLICY_WEAKENING_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "detect-policy-weakening.py") -DiagnosticPrefix "detect-policy-weakening: DETECT_POLICY_WEAKENING_RUNTIME_UNAVAILABLE" -Arguments $args
