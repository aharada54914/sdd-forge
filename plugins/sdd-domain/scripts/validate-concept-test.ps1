# Thin PowerShell dispatcher for validate-concept-test.
# One behavioral implementation lives in validate-concept-test.py beside this file.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeLib = Join-Path $dir "../runtime/lib/py-dispatch.ps1"
$siblingLib = Join-Path $dir "../../sdd-quality-loop/scripts/lib/py-dispatch.ps1"
$lib = if (Test-Path -LiteralPath $runtimeLib) { $runtimeLib } elseif (Test-Path -LiteralPath $siblingLib) { $siblingLib } else { $null }
if (-not $lib) {
    [Console]::Error.WriteLine("validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 1
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "validate-concept-test.py") -DiagnosticPrefix "validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE" -Arguments $args
