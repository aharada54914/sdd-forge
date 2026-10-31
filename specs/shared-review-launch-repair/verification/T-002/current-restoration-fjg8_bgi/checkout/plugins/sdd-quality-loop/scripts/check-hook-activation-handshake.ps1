# Thin PowerShell dispatcher for check-hook-activation-handshake; the Python
# master beside this file is the only behavioral implementation.
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("check-hook-activation-handshake: CHECK_HOOK_ACTIVATION_HANDSHAKE_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "check-hook-activation-handshake.py") -DiagnosticPrefix "check-hook-activation-handshake: CHECK_HOOK_ACTIVATION_HANDSHAKE_RUNTIME_UNAVAILABLE" -Arguments $args
