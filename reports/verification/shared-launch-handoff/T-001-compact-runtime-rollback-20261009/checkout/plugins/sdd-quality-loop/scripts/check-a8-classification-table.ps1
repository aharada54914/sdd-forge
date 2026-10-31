[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Design
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction Stop }
& $python.Source (Join-Path $scriptDir "check-a8-classification-table.py") $Design
exit $LASTEXITCODE
