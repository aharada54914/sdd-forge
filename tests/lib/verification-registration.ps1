# Query the executable inventory; a failed listing must never look registered.
param([Parameter(Mandatory)][string]$Runner)
$ErrorActionPreference = 'Stop'
$listed = if ($Runner.EndsWith('.sh')) { @(& bash $Runner --list) } else { @(& $Runner -List) }
if ($LASTEXITCODE -ne 0) { throw "Verification inventory query failed: $LASTEXITCODE" }
$listed -join "`n"
