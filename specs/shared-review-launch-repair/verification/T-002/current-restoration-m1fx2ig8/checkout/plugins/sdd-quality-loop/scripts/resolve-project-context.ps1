# Thin PowerShell dispatcher; the Python master is the sole implementation.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) {
    [Console]::Error.WriteLine('capability-resolver: runtime-unavailable: no python3 or python interpreter found')
    exit 3
}
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $python.Source
$psi.ArgumentList.Add((Join-Path $dir 'resolve-project-context.py'))
foreach ($argument in $args) { $psi.ArgumentList.Add($argument) }
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $false
$psi.RedirectStandardError = $false
$psi.RedirectStandardInput = $false
$process = [System.Diagnostics.Process]::Start($psi)
$process.WaitForExit()
exit $process.ExitCode
