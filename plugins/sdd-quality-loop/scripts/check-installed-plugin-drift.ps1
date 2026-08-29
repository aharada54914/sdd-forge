[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [ValidateSet("preflight", "verify")]
    [string]$Mode = "preflight"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction Stop }
& $python.Source (Join-Path $scriptDir "check-installed-plugin-drift.py") `
    --install-root $InstallRoot --mode $Mode
exit $LASTEXITCODE
