#!/usr/bin/env pwsh
# Thin wrapper: dispatch to the single Python implementation
# (validate-context-projection.py). No runtime-specific logic lives here.
# Diagnostic determinism contract: the underlying python3 process writes
# LF-only bytes directly (validate-context-projection.py reconfigures stdout
# to newline="\n"); this wrapper streams that subprocess output through
# unmodified -- it never re-emits it via Write-Output/Write-Host, which
# would risk PowerShell's default CRLF `NewLine` leaking in.
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $ScriptDir "validate-context-projection.py"

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $python) {
    [Console]::Error.Write("context-projection: python-not-found: no python3 or python on PATH`n")
    exit 1
}

& $python.Path $Target @args
exit $LASTEXITCODE
