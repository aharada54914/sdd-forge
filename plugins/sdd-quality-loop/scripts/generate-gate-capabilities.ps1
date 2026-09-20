# Thin PowerShell dispatcher for generate-gate-capabilities (Python master;
# INV-014).
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("generate-gate-capabilities: GENERATE_GATE_CAPABILITIES_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "generate-gate-capabilities.py") -DiagnosticPrefix "generate-gate-capabilities: GENERATE_GATE_CAPABILITIES_RUNTIME_UNAVAILABLE" -Arguments $args
