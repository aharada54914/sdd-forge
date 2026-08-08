# Thin PowerShell dispatcher for canonicalize-sdd-yaml (REQ-003). Locates
# python3, else python, on PATH and invokes canonicalize-sdd-yaml.py
# unchanged. Exactly ONE behavioral implementation exists (the Python
# script beside this file). Unlike sdd-hook-guard.sh's PowerShell path
# (INV-005), which falls back to a SEPARATE, fully native PowerShell
# re-implementation of the guard's own decision logic when python3 is
# unavailable, this wrapper NEVER reimplements canonicalization natively --
# there is no native PowerShell canonicalization logic to fall back to. If
# neither python3 nor python is found, denies fail-closed with the SAME
# documented exit code every .sh/.ps1/.js wrapper uses:
# CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3). No output is produced on that
# path; the diagnostic goes to stderr only.
#
# Byte-exact passthrough note: this deliberately uses
# [System.Diagnostics.Process] with UseShellExecute=$false and NO
# stdout/stderr redirection, rather than PowerShell's `&` call operator.
# When a .ps1 script's OWN stdout is itself redirected (e.g. `pwsh -File
# ... > out.bin`, or any CI/automation invocation), `& python ...` routes
# the native command's output through PowerShell's success pipeline, which
# reconstructs it as line-based string objects and can append a trailing
# newline PowerShell itself introduced -- silently breaking byte-exactness.
# Starting the child process directly makes it inherit this process's raw
# OS-level stdout/stderr/stdin handles, which is true passthrough
# regardless of how this wrapper's own output is being consumed.
$ErrorActionPreference = "Stop"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $dir "canonicalize-sdd-yaml.py"

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}

if (-not $python) {
    [Console]::Error.WriteLine("canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH")
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
