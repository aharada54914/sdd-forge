#!/usr/bin/env pwsh
# Thin wrapper: dispatch to the single Python implementation
# (compare-facet-manifest-staleness.py). No runtime-specific logic lives
# here.
# Diagnostic determinism contract: the underlying python3 process writes
# LF-only bytes directly on BOTH channels (compare-facet-manifest-
# staleness.py reconfigures both sys.stdout and sys.stderr to
# newline="\n"); this wrapper streams that subprocess's stdout/stderr
# through unmodified -- it never re-emits either channel via
# Write-Output/Write-Host, which would risk PowerShell's default CRLF
# `NewLine` leaking in, and it never merges the two channels together (the
# verdict channel, stdout exit 0/1/2, and the diagnostic channel, stderr
# exit 3, stay fully separated end to end).
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $ScriptDir "compare-facet-manifest-staleness.py"

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $python) {
    [Console]::Error.Write("facet-manifest-staleness: python-not-found: no python3 or python on PATH`n")
    exit 3
}

& $python.Path $Target @args
exit $LASTEXITCODE
