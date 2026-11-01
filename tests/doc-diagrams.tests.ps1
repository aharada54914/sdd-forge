# Documentation links, Mermaid diagrams and pinned anchors (see doc-diagrams.tests.py).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { Write-Error 'python3 or python is required'; exit 1 }
& $python.Source (Join-Path $root 'tests/doc-diagrams.tests.py') @args
exit $LASTEXITCODE
