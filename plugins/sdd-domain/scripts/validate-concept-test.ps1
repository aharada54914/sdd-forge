# Thin PowerShell dispatcher for validate-concept-test.
# One behavioral implementation lives in validate-concept-test.py beside this file.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = Join-Path $dir "../../sdd-quality-loop/scripts/lib/py-dispatch.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    [Console]::Error.WriteLine("validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script")
    exit 1
}
. $lib

Invoke-SddPyDispatch -Master (Join-Path $dir "validate-concept-test.py") -DiagnosticPrefix "validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE" -Arguments $args
