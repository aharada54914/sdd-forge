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
    [Console]::Error.WriteLine("finalize-domain-review: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    [Console]::Error.WriteLine("finalize-domain-review: operation=finalize-domain-review cause=missing-dispatch-helper (../../sdd-quality-loop/scripts/lib/py-dispatch.ps1 unavailable; legacy machine token kept above for compatibility)")
    exit 3
}
. $lib

# Make the currently executing PowerShell host available to the shared validator.
$hostDirectory = Split-Path -Parent (Get-Process -Id $PID).Path
$env:PATH = if ($env:PATH) { $hostDirectory + [IO.Path]::PathSeparator + $env:PATH } else { $hostDirectory }

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $python) {
    [Console]::Error.WriteLine("finalize-domain-review: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH")
    [Console]::Error.WriteLine("finalize-domain-review: operation=finalize-domain-review cause=missing-python-runtime (python3 or python not found on PATH; legacy machine token kept above for compatibility)")
    exit 3
}

Invoke-SddPyDispatch -Master (Join-Path $dir "finalize-domain-review.py") -DiagnosticPrefix "finalize-domain-review: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE" -Arguments (@("--runtime", "powershell") + $args)
