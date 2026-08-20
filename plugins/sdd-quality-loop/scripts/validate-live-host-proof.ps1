[CmdletBinding()]
param(
    [Alias('records-dir')]
    [string]$RecordsDir,
    [Alias('nonce-ledger')]
    [string]$NonceLedger,
    [Alias('expected-digest-manifest')]
    [string]$ExpectedDigestManifest,
    [Alias('trusted-signers')]
    [string]$TrustedSigners,
    [Alias('skip-allowlist')]
    [string]$SkipAllowlist
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $python) {
    [Console]::Error.WriteLine('ERR_SCHEMA_INVALID: Python runtime unavailable')
    exit 3
}

$scriptPath = Join-Path $PSScriptRoot 'validate-live-host-proof.py'
$arguments = @($scriptPath)
if ($RecordsDir) { $arguments += @('--records-dir', $RecordsDir) }
if ($NonceLedger) { $arguments += @('--nonce-ledger', $NonceLedger) }
if ($ExpectedDigestManifest) { $arguments += @('--expected-digest-manifest', $ExpectedDigestManifest) }
if ($TrustedSigners) { $arguments += @('--trusted-signers', $TrustedSigners) }
if ($SkipAllowlist) { $arguments += @('--skip-allowlist', $SkipAllowlist) }

& $python.Source @arguments
exit $LASTEXITCODE
