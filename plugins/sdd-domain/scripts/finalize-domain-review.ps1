# Self-contained PowerShell dispatcher for finalize-domain-review (ADR-0055: py-dispatch.ps1 retired).
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$master = Join-Path $dir "finalize-domain-review.py"
if (-not (Test-Path -LiteralPath $master -PathType Leaf)) {
    [Console]::Error.WriteLine("finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: finalize-domain-review.py unavailable beside this script")
    [Console]::Error.WriteLine("finalize-domain-review: operation=finalize-domain-review cause=missing-python-master")
    exit 3
}

# Make the currently executing PowerShell host available to the shared validator.
$hostDirectory = Split-Path -Parent (Get-Process -Id $PID).Path
$env:PATH = if ($env:PATH) { $hostDirectory + [IO.Path]::PathSeparator + $env:PATH } else { $hostDirectory }

$py = Get-Command "python3" -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command "python" -ErrorAction SilentlyContinue }
if (-not $py) {
    [Console]::Error.WriteLine("finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH")
    exit 3
}

& $py.Source $master --runtime powershell @args
exit $LASTEXITCODE
