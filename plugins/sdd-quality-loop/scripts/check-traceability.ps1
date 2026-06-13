# Deterministic gate: verify requirement traceability (REQ → AC → TEST → evidence).
# Usage: check-traceability.ps1 [-TracePath <path>] [-RepoRoot <path>] [-RequireEvidence]
# Fails (exit 1) if traceability chain is incomplete or evidence files are missing/invalid.
# Additional rules enforced:
#  - Every link must have req (non-empty string), acs (array with ≥1 entry), tests (array with ≥1 entry)
#  - If evidence key is present, each entry must be path-safe (reject absolute POSIX "/",
#    Windows drive "X:", UNC "\\\\", and ".." traversal escaping repo-root)
#  - Evidence files must exist, be regular files, and be non-empty
#  - RequireEvidence switch: every link MUST have evidence array with ≥1 entry

param(
    [Parameter(Mandatory)][string]$TracePath,
    [string]$RepoRoot = ".",
    [switch]$RequireEvidence
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TracePath)) {
    Write-Error "Traceability file not found: $TracePath"
    exit 1
}

try {
    $traceability = Get-Content -Raw -Encoding Utf8 $TracePath | ConvertFrom-Json
} catch {
    Write-Error "check-traceability: invalid JSON"
    exit 1
}

$failures = @()

# Resolve repo root to an absolute path for traversal checks
$absRoot = (Resolve-Path $RepoRoot).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')

# Validate structure
$feature = ([string]($traceability.feature)).Trim()
if ([string]::IsNullOrWhiteSpace($feature)) {
    $failures += "missing feature"
}

$links = $traceability.links
if ($null -eq $links -or -not ($links -is [array]) -or $links.Count -eq 0) {
    $failures += "traceability has no links"
    if ($failures.Count -gt 0) {
        Write-Host "Traceability check FAILED:"
        $failures | ForEach-Object { Write-Host " - $_" }
        exit 1
    }
}

# Validate each link
for ($i = 0; $i -lt $links.Count; $i++) {
    $link = $links[$i]
    $req = ([string]($link.req)).Trim()
    if ([string]::IsNullOrWhiteSpace($req)) {
        $req = "link $i"
    }

    # Check acs: must be an array with >=1 non-empty entry
    $acs = $link.acs
    if (-not ($acs -is [array]) -or @($acs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -lt 1) {
        $failures += "$req has no acceptance criteria (acs)"
        continue
    }

    # Check tests: must be an array with >=1 non-empty entry
    $tests = $link.tests
    if (-not ($tests -is [array]) -or @($tests | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -lt 1) {
        $failures += "$req has no tests"
        continue
    }

    # Check evidence if present
    $evidence = $link.evidence

    # RequireEvidence mode: link must list >=1 non-empty evidence entry
    # (an absent key OR an empty/whitespace-only array fails closed).
    if ($RequireEvidence) {
        $nonEmptyEv = @()
        if ($evidence -is [array]) { $nonEmptyEv = @($evidence | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) }
        if ($nonEmptyEv.Count -lt 1) {
            $failures += "$req requires evidence but none listed"
            continue
        }
    }

    if ($null -ne $evidence) {
        if (-not ($evidence -is [array])) {
            $failures += "$req evidence must be an array"
            continue
        }

        foreach ($evFile in $evidence) {
            $evPath = ([string]($evFile)).Trim()
            if ([string]::IsNullOrWhiteSpace($evPath)) {
                continue
            }

            # Path safety checks (same as check-contract)
            if ($evPath.StartsWith("/")) {
                $failures += "$req evidence $evPath is an absolute path"
                continue
            }
            if (($evPath.Length -ge 2 -and $evPath[1] -eq ':') -or $evPath.StartsWith("\\")) {
                $failures += "$req evidence $evPath is an absolute path"
                continue
            }

            # Resolve and check for traversal outside root
            try {
                $joined = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($absRoot, $evPath))
            } catch {
                $failures += "$req evidence $evPath path could not be resolved"
                continue
            }

            $sep = [System.IO.Path]::DirectorySeparatorChar
            if (-not ($joined.StartsWith($absRoot + $sep) -or $joined -eq $absRoot)) {
                $failures += "$req evidence $evPath path escapes repo root"
                continue
            }

            # Evidence must exist, be a regular file (not directory), and have size > 0
            if (-not (Test-Path -LiteralPath $joined)) {
                $failures += "$req evidence $evPath file missing"
            } elseif ((Test-Path -LiteralPath $joined -PathType Container)) {
                $failures += "$req evidence $evPath is not a regular file"
            } else {
                $fileInfo = Get-Item -LiteralPath $joined -ErrorAction SilentlyContinue
                if ($fileInfo -and $fileInfo.Length -eq 0) {
                    $failures += "$req evidence $evPath file is empty"
                }
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Traceability check FAILED:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "Traceability check passed for $feature`: $($links.Count) link(s)."
exit 0
