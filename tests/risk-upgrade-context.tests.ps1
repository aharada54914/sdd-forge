$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$engine = (Get-Process -Id $PID).Path
& python3 (Join-Path $root 'tests/risk-upgrade-context-cases.py') --powershell $engine
exit $LASTEXITCODE
