# T-008 (epic-193-a5): PowerShell twin for validate-resolver-evidence -- the
# twelve-value check-id matrix (AC-021), the Registry/affected-component
# provenance-binding locks (AC-050/AC-051), and the reader-side
# publication-journal fail-closed lock (AC-054).
$ErrorActionPreference = 'Stop'
# Runtime marker (recurring cross-model panel Minor, every round): a leading
# capture line naming the invoking runtime so sh/ps1 captures of this
# suite's own output stop being byte-identical -- the PowerShell lane
# becomes self-evidencing (proof pwsh genuinely ran it, not a duplicated sh
# capture pasted under a different filename).
Write-Output '# runner: pwsh'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) { $Python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $Python) {
  Write-Output 'FAIL: no python3/python interpreter available'
  exit 1
}
& $Python.Source (Join-Path $Root 'tests/validate-resolver-evidence-check.py') --launcher ps1
exit $LASTEXITCODE
