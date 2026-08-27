# Shared python-master dispatcher, dot-sourced by every thin PowerShell
# wrapper whose ONLY job is to run the Python implementation beside it.
# Twin of lib/py-dispatch.sh; the INV-008 family (check-contract,
# check-component-coverage, resolve-component-paths) has native PowerShell
# twins and deliberately does not use this.
#
# Byte-exact passthrough (the canonicalize-sdd-yaml.ps1 rationale, adopted
# for every wrapper): the child is started via [System.Diagnostics.Process]
# with UseShellExecute=$false and NO stdout/stderr/stdin redirection, so it
# inherits this process's raw OS-level handles. PowerShell's `&` call
# operator would route native output through the success pipeline, which
# reconstructs it as line-based string objects and can append a trailing
# newline PowerShell itself introduced when the wrapper's own stdout is
# redirected (e.g. `pwsh -File ... > out.bin`) -- silently breaking
# byte-exactness. That measured failure mode is why `&` is not used here.
#
# Contract (matches the sh twin):
#   - locate python3, else python, on PATH and run the master unchanged;
#   - when neither exists, deny fail-closed: one stderr line
#     "<DiagnosticPrefix>: no python3 or python interpreter found on PATH"
#     and exit 3 (runtime absence stays distinguishable from the master's
#     own validation failures).
#
# Usage from a wrapper (dot-source, then dispatch):
#   . (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'lib/py-dispatch.ps1')
#   Invoke-SddPyDispatch -Master $scriptPath -DiagnosticPrefix 'tool: TOKEN' -Arguments $args
function Invoke-SddPyDispatch {
    param(
        [Parameter(Mandatory = $true)][string]$Master,
        [Parameter(Mandatory = $true)][string]$DiagnosticPrefix,
        [object[]]$Arguments = @()
    )

    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command python -ErrorAction SilentlyContinue
    }
    if (-not $python) {
        [Console]::Error.WriteLine("${DiagnosticPrefix}: no python3 or python interpreter found on PATH")
        exit 3
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $python.Source
    $psi.ArgumentList.Add($Master)
    foreach ($a in $Arguments) { $psi.ArgumentList.Add([string]$a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    $psi.RedirectStandardInput = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    exit $proc.ExitCode
}
