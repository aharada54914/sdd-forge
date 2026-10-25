# Thin PowerShell dispatcher for research-evidence-tools (Python master).
# Dispatch logic (python3 -> python -> fail-closed exit 3, byte-exact
# passthrough via [System.Diagnostics.Process]) lives in lib/py-dispatch.ps1,
# shared by every python-master wrapper.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("research-evidence-tools: RESEARCH_EVIDENCE_TOOLS_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 3
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "research-evidence-tools.py") -DiagnosticPrefix "research-evidence-tools: RESEARCH_EVIDENCE_TOOLS_RUNTIME_UNAVAILABLE" -Arguments $args
