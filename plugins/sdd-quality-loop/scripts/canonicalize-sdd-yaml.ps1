# Thin PowerShell dispatcher for canonicalize-sdd-yaml (REQ-003). Exactly ONE
# behavioral implementation exists (the Python master beside this file); this
# wrapper never reimplements canonicalization natively (unlike
# sdd-hook-guard's INV-005 native fallback, there is nothing to fall back to).
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "canonicalize-sdd-yaml.py") -DiagnosticPrefix "canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE" -Arguments $args
