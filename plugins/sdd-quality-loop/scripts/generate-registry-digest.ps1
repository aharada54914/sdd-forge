# Thin raw-stdio dispatcher for generate-registry-digest.py.
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$pythonScript = Join-Path $scriptDir 'generate-registry-digest.py'
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) {
  [Console]::Error.WriteLine('generate-registry-digest: python3 (or python) is required')
  exit 3
}

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $python.Source
$startInfo.UseShellExecute = $false
$startInfo.ArgumentList.Add($pythonScript)
foreach ($argument in $args) { $startInfo.ArgumentList.Add([string]$argument) }
$process = [System.Diagnostics.Process]::Start($startInfo)
$process.WaitForExit()
exit $process.ExitCode
