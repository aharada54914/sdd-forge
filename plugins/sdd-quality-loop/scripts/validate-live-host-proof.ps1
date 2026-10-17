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

$scriptPath = Join-Path $PSScriptRoot 'validate-live-host-proof.py'
$arguments = @()
if ($RecordsDir) { $arguments += @('--records-dir', $RecordsDir) }
if ($NonceLedger) { $arguments += @('--nonce-ledger', $NonceLedger) }
if ($ExpectedDigestManifest) { $arguments += @('--expected-digest-manifest', $ExpectedDigestManifest) }
if ($TrustedSigners) { $arguments += @('--trusted-signers', $TrustedSigners) }
if ($SkipAllowlist) { $arguments += @('--skip-allowlist', $SkipAllowlist) }

. (Join-Path $PSScriptRoot 'lib/py-dispatch.ps1')
Invoke-SddPyDispatch `
    -Master $scriptPath `
    -DiagnosticPrefix 'validate-live-host-proof: ERR_SCHEMA_INVALID' `
    -Arguments $arguments
