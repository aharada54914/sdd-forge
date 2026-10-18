# The catalog owns registration; each PowerShell suite gets a fresh native host.
[CmdletBinding()]
param([switch]$List, [string]$Receipt)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Verification requires python3 or python.' }
$arguments = @((Join-Path $PSScriptRoot 'verification.py'), '--profile', 'local-powershell', '--powershell', (Get-Process -Id $PID).Path)
if ($List) { $arguments += '--list' } else { $arguments += '--run' }
if ($Receipt) { $arguments += @('--receipt', $Receipt) }
& $python.Source @arguments
exit $LASTEXITCODE
