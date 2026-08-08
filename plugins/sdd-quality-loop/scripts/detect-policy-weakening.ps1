# Thin PowerShell dispatcher for detect-policy-weakening (REQ-006). Locates
# python3, else python, on PATH and invokes detect-policy-weakening.py
# unchanged. Exactly ONE behavioral implementation exists (the Python
# script beside this file); this wrapper never reimplements
# classification/verdict logic natively. If neither python3 nor python is
# found, denies fail-closed with the SAME documented exit code the sibling
# canonicalize-sdd-yaml.sh/.ps1 / generate-approval-sidecar.sh/.ps1
# wrappers use for this condition (exit 3). No output is produced on that
# path; the diagnostic goes to stderr only.
#
# Byte-exact passthrough note: this deliberately uses
# [System.Diagnostics.Process] with UseShellExecute=$false and NO
# stdout/stderr redirection, rather than PowerShell's `&` call operator,
# mirroring canonicalize-sdd-yaml.ps1's/generate-approval-sidecar.ps1's own
# rationale (avoids PowerShell's success-pipeline reconstruction of a
# native command's raw output).
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $dir "detect-policy-weakening.py"

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}

if (-not $python) {
    [Console]::Error.WriteLine("detect-policy-weakening: DETECT_POLICY_WEAKENING_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH")
    exit 3
}

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $python.Source
$psi.ArgumentList.Add($scriptPath)
foreach ($a in $args) { $psi.ArgumentList.Add($a) }
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $false
$psi.RedirectStandardError = $false
$psi.RedirectStandardInput = $false

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit()
exit $proc.ExitCode
