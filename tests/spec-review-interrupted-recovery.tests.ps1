# The shared fixture table drives native PowerShell predicates and identity verifier.
# Python is test orchestration only; the tested implementation remains PowerShell.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'spec-review-interrupted-recovery.tests.sh'))
$start = $source.IndexOf("import copy,", [StringComparison]::Ordinal)
$end = $source.LastIndexOf("`nPY", [StringComparison]::Ordinal)
if ($start -lt 0 -or $end -le $start) { throw 'Shared fixture runner is missing' }
$python = $source.Substring($start, $end - $start)
$env:SDD_TEST_PWSH = (Get-Process -Id $PID).Path
$python | & python3 - $root powershell
exit $LASTEXITCODE
