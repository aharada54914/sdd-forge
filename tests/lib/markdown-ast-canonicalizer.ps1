param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = 'Stop'
try {
    $Node = Get-Command node -ErrorAction Stop
    & $Node.Source (Join-Path $PSScriptRoot 'markdown-ast-canonicalizer.mjs') $Path
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("markdown AST parse failure: $($_.Exception.Message)")
    exit 2
}
