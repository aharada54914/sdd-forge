$ErrorActionPreference = "Stop"
$repositoryRoot = "/workspace/sdd-forge"
$readmeLines = Get-Content -Encoding Utf8 (Join-Path $repositoryRoot "README.md")
$readmeCurrentRelease = $readmeLines |
    Where-Object { $_ -match "^v\d+\.\d+\.\d+(?:\s|$)" } |
    Select-Object -First 1
if ($null -eq $readmeCurrentRelease -or $readmeCurrentRelease -notmatch "^v1\.19\.0(?:\s|$)") {
    throw "README.md current release must be v1.19.0."
}

$changelog = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "CHANGELOG.md")
$currentReleaseHeadings = [regex]::Matches($changelog, "(?m)^## v1\.19\.0(?:\s|$)")
if ($currentReleaseHeadings.Count -ne 1) {
    throw "CHANGELOG.md must contain exactly one v1.19.0 release heading."
}

Write-Output "PASS: existing README and CHANGELOG release assertions (documentation slice only)"
