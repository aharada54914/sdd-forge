param([string]$CaseHome,[string]$CachePath)
$ErrorActionPreference = 'Stop'
$info = [System.Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh'))
$info.UseShellExecute = $false
$info.Environment['HOME'] = $CaseHome
$info.Environment['XDG_DATA_HOME'] = (Join-Path $CaseHome '.local/share')
if ($CachePath) { $info.Environment['XDG_CACHE_HOME'] = $CachePath } else { $info.Environment.Remove('XDG_CACHE_HOME') | Out-Null }
foreach ($item in @('-NoProfile','-NonInteractive','-Command','Get-Command Get-FileHash | Out-Null')) { $info.ArgumentList.Add($item) }
$child = [System.Diagnostics.Process]::Start($info)
$child.WaitForExit()
exit $child.ExitCode
