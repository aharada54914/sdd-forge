# Collection layer: prepare sanitized panelist input bundle with consent gate.
# Usage:
#   prepare-panelist-input.ps1 --task T-NNN --feature <f> --input <path|dir>
#                              [--tasks-file specs/<f>/tasks.md]
#                              [--out <path>]
#                              [--spec-root <dir>]
#                              [--project-root <dir>]
#                              [--effort <low|medium|high|xhigh>]
#
# Security (design.md §6):
#   * Fail-closed consent gate: exits non-zero without writing output unless
#     tasks.md contains "Cross-Model: enabled" for the task, OR a valid
#     SDD_SUDO token is present (see sudo-mode-policy.md).
#   * Sanitization: strips .env values, API keys/tokens, absolute paths, and
#     private/RFC-1918 URLs before writing the bundle.
#   * input_digest: sha256 of the sanitized bundle, printed to stdout.
#   * Key isolation: SDD_EVIDENCE_KEY / sudo key are never included in output.
#
# Exit codes: 0=success  1=consent denied / input error  2=tool error (bad args)
#
# --effort (epic-159-pillar-c T-006, REQ-006/AC-036): optional pass-through.
# This script prepares ONE shared sanitized bundle consumed by every panelist
# vendor -- it never invokes a vendor CLI itself -- so a selector-derived
# effort value is threaded through by being echoed on a second stdout line
# ("effort=<e>", after the existing digest line), for the caller to lift
# into `run-panelist-gpt --effort <e>` in its own next step. Omitted
# entirely preserves today's exact single-line stdout output (Breaking API:
# no).
#
# Simplification note (HMAC): Full HMAC-SHA256 verification of SDD_SUDO requires
# the key from ~/.sdd/sudo-key or SDD_SUDO_KEY env var. We perform complete
# HMAC verification when the key is resolvable. When SDD_SUDO_SKIP_SIG=1 is set
# (test scaffolding only), signature check is skipped.
param()
$ErrorActionPreference = "Stop"

# ── Parse GNU-style --flag value arguments ───────────────────────────────────
$TaskId      = ""
$Feature     = ""
$InputPath   = ""
$TasksFile   = ""
$OutPath     = ""
$SpecRoot    = "specs"
$ProjectRoot = ""
$Effort      = ""

$argIdx = 0
$passedArgs = $args
while ($argIdx -lt $passedArgs.Count) {
    switch ($passedArgs[$argIdx]) {
        "--task"         { $TaskId      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--feature"      { $Feature     = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--input"        { $InputPath   = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--tasks-file"   { $TasksFile   = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--out"          { $OutPath     = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--spec-root"    { $SpecRoot    = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--project-root" { $ProjectRoot = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--effort"       { $Effort      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        default {
            [Console]::Error.WriteLine("prepare-panelist-input: unknown argument: $($passedArgs[$argIdx])")
            exit 2
        }
    }
}

# ── Validate required arguments ──────────────────────────────────────────────

if (-not $TaskId) {
    [Console]::Error.WriteLine("prepare-panelist-input: --task is required")
    exit 2
}
if (-not $Feature) {
    [Console]::Error.WriteLine("prepare-panelist-input: --feature is required")
    exit 2
}
if (-not $InputPath) {
    [Console]::Error.WriteLine("prepare-panelist-input: --input is required")
    exit 2
}

# Resolve project root
if (-not $ProjectRoot) {
    $dir = (Get-Location).Path
    while ($dir -and $dir -ne (Split-Path $dir -Parent)) {
        if ((Test-Path (Join-Path $dir "AGENTS.md")) -or (Test-Path (Join-Path $dir ".git"))) {
            $ProjectRoot = $dir
            break
        }
        $dir = Split-Path $dir -Parent
    }
    if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }
}

# Default tasks file
if (-not $TasksFile) {
    $TasksFile = Join-Path $SpecRoot (Join-Path $Feature "tasks.md")
}

# Default output path
if (-not $OutPath) {
    $OutPath = Join-Path $SpecRoot (Join-Path $Feature (Join-Path "verification" "$TaskId.panelist-input.txt"))
}

# ── Consent gate (fail-closed) ───────────────────────────────────────────────

$ConsentKind = ""

# Check (a): tasks.md has "Cross-Model: enabled" in the task section
if (Test-Path $TasksFile) {
    $inSection = $false
    foreach ($line in (Get-Content -Encoding Utf8 $TasksFile)) {
        $line = $line.TrimEnd("`r")
        if ($line -match "^## $([regex]::Escape($TaskId))(\s|$)") {
            $inSection = $true
        } elseif ($line -match "^## " -and $inSection) {
            break
        } elseif ($inSection -and $line -eq "Cross-Model: enabled") {
            $ConsentKind = "human-flag"
            break
        }
    }
}

# Check (b): SDD_SUDO token
if (-not $ConsentKind) {
    $sudoFile = Join-Path $ProjectRoot "SDD_SUDO"
    if ((Test-Path -LiteralPath $sudoFile) -and (-not (Get-Item -LiteralPath $sudoFile).LinkType)) {
        $fields = @{}
        foreach ($line in (Get-Content -Encoding Utf8 $sudoFile)) {
            $line = $line.TrimEnd("`r")
            if ($line -match "^([a-z\-]+): (.+)$") {
                $fields[$Matches[1]] = $Matches[2].Trim()
            }
        }

        $requiredFields = @("issuer","nonce","repo","issued-epoch","expires-epoch","sig")
        $allPresent = ($requiredFields | Where-Object { -not $fields[$_] }).Count -eq 0

        if ($allPresent) {
            # Nonce: >= 32 hex chars
            $nonceOk = $fields["nonce"] -match '^[0-9a-fA-F]{32,}$'

            # Time window
            $now     = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $issued  = [long]$fields["issued-epoch"]
            $expires = [long]$fields["expires-epoch"]
            $maxTtl  = 86400
            $timeOk  = ($issued -le $now) -and ($now -lt $expires) -and (($expires - $issued) -le $maxTtl)

            # Repo binding: repo field equals realpath of directory containing SDD_SUDO
            $expectedRepo = (Resolve-Path (Split-Path -Parent $sudoFile)).Path
            $repoOk = ($fields["repo"] -eq $expectedRepo)

            # HMAC signature verification
            $sigOk = $false
            $skipSig = ($env:SDD_SUDO_SKIP_SIG -eq "1")

            if ($skipSig) {
                $sigOk = $true
            } else {
                # Resolve key
                $keyBytes = $null
                if ($env:SDD_SUDO_KEY) {
                    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($env:SDD_SUDO_KEY)
                } elseif ($env:SDD_SUDO_KEY_FILE -and (Test-Path $env:SDD_SUDO_KEY_FILE)) {
                    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes(
                        (Get-Content -Raw $env:SDD_SUDO_KEY_FILE).TrimEnd())
                } else {
                    $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
                    $keyFile = Join-Path $homeDir ".sdd/sudo-key"
                    if (Test-Path $keyFile) {
                        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes(
                            (Get-Content -Raw $keyFile).TrimEnd())
                    }
                }

                if ($keyBytes) {
                    $canonical = "$($fields['issuer'])`n$($fields['nonce'])`n$($fields['repo'])`n$($fields['issued-epoch'])`n$($fields['expires-epoch'])"
                    $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
                    $msgBytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
                    $computed = ($hmac.ComputeHash($msgBytes) | ForEach-Object { $_.ToString("x2") }) -join ""
                    # String-compare (PowerShell doesn't have constant-time compare; noted in policy)
                    $sigOk = ($computed -eq $fields["sig"].ToLower())
                }
                # No key resolvable → token inactive (fail-closed)
            }

            if ($nonceOk -and $timeOk -and $repoOk -and $sigOk) {
                $ConsentKind = "sudo"
            }
        }
    }
}

if (-not $ConsentKind) {
    [Console]::Error.WriteLine(
        "prepare-panelist-input: consent denied for $TaskId — no Cross-Model: enabled flag in $TasksFile and no valid SDD_SUDO token")
    exit 1
}

# ── Collect input content ────────────────────────────────────────────────────
# -Recurse -File (native re-implementation, never a shell-out to the .sh
# twin) so subdirectories of --input are visited too (REQ-003/AC-013);
# sorted for determinism.

if (-not (Test-Path $InputPath)) {
    [Console]::Error.WriteLine("prepare-panelist-input: input not found: $InputPath")
    exit 1
}

if ((Get-Item $InputPath).PSIsContainer) {
    $rawLines = @()
    foreach ($f in (Get-ChildItem $InputPath -File -Recurse | Sort-Object FullName)) {
        $rawLines += Get-Content -Raw -Encoding Utf8 $f.FullName
    }
    $rawContent = $rawLines -join "`n"
} else {
    $rawContent = Get-Content -Raw -Encoding Utf8 $InputPath
}

# ── Declared-outputs completeness check (REQ-003/AC-014..017/AC-032) ────────
# Security Boundary B1 (security-spec.md): verifies every path the
# implementation report's own "## Outputs" table declares is present in the
# bundle's --input root with a matching SHA-256, BEFORE sanitization/digest
# computation ever runs — a completeness gap means no digest line can ever
# print (a structural property: the sanitize/write/print code below is
# simply never reached on a gap, not a conditional guard around it).
#
# Native re-implementation of the same "## Outputs" heading + "| `path` |
# `hash` |" row shape validate-review-context-set.sh:63-74's
# evaluator_output_is_declared already establishes, applied in the OPPOSITE
# direction: instead of checking one caller-supplied path against the
# table, this iterates every row and containment-checks each declared path
# against the bundle's OWN --input root FIRST — reusing that same site's
# path_is_authorized containment discipline — a path that would resolve
# outside is a gap, NEVER read (never opened, never hashed), before
# existence/hash is verified for paths that pass containment.
#
# Convention, not a new flag (Breaking API: no — CLI flags are unchanged):
# the implementation report path is derived from --task/--feature/
# --project-root as reports/implementation/<feature>/<task_id>.md, the same
# convention validate-review-context-set.sh:267-282 already uses to locate
# an sdd-evaluator's implementation report. If no report exists at that
# conventional path, there is no declared-outputs table to check against —
# the completeness check is a no-op (preserves BL-007/BL-008/BL-009 for
# every caller that predates this convention, e.g. this script's own
# existing test fixtures).

function Test-DeclaredOutputCanonicalPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    if ($Path.StartsWith("/")) { return $false }
    if ($Path -match "^[A-Za-z]:") { return $false }
    if ($Path.Contains("\")) { return $false }
    if ($Path -match "(^|/)\.\.?(/|$)") { return $false }
    return $true
}

function Invoke-DeclaredOutputsCompletenessCheck {
    param([string]$ProjectRoot, [string]$Feature, [string]$TaskId, [string]$InputRoot)

    $implReportPath = Join-Path $ProjectRoot (Join-Path "reports" (Join-Path "implementation" (Join-Path $Feature "$TaskId.md")))
    if (-not (Test-Path -LiteralPath $implReportPath)) { return }

    $gaps = New-Object System.Collections.Generic.List[string]
    $inOutputs = $false
    foreach ($rawLine in (Get-Content -Encoding Utf8 $implReportPath)) {
        $line = $rawLine.TrimEnd("`r")
        if ($line -eq "## Outputs") { $inOutputs = $true; continue }
        if ($line -match "^## ") {
            if ($inOutputs) { break }
            continue
        }
        if (-not $inOutputs) { continue }

        $m = [regex]::Match($line, '^\| `([^`]*)` \| `([^`]*)` \|\s*$')
        if (-not $m.Success) { continue }
        $rowPath = $m.Groups[1].Value
        $rowHash = $m.Groups[2].Value.ToLower()
        if ([string]::IsNullOrEmpty($rowPath)) { continue }

        if (-not (Test-DeclaredOutputCanonicalPath $rowPath)) {
            $gaps.Add("declared output resolves outside input root: $rowPath")
            continue
        }

        # Component-walk containment: no symbolic link anywhere between the
        # bundle root and the candidate may be followed (mirrors
        # validate-review-context-set.sh's own symlink-component-walk).
        $current = $InputRoot.TrimEnd('/', '\')
        $outsideRoot = $false
        foreach ($component in ($rowPath -split '/')) {
            $current = "$current/$component"
            $item = Get-Item -LiteralPath $current -ErrorAction SilentlyContinue
            if ($item -and $item.LinkType) { $outsideRoot = $true }
        }
        if ($outsideRoot) {
            $gaps.Add("declared output resolves outside input root: $rowPath")
            continue
        }

        $candidate = Join-Path $InputRoot $rowPath
        $candidateItem = Get-Item -LiteralPath $candidate -ErrorAction SilentlyContinue
        if ($candidateItem -and (-not $candidateItem.PSIsContainer) -and (-not $candidateItem.LinkType)) {
            $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLower()
            if ($actualHash -ne $rowHash) {
                $gaps.Add("declared output hash mismatch: $rowPath")
            }
        } else {
            $gaps.Add("declared output missing from bundle: $rowPath")
        }
    }

    if ($gaps.Count -gt 0) {
        foreach ($g in $gaps) {
            [Console]::Error.WriteLine("prepare-panelist-input: $g")
        }
        exit 1
    }
}

Invoke-DeclaredOutputsCompletenessCheck -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId -InputRoot $InputPath

# ── Sanitize content ─────────────────────────────────────────────────────────
# Secret patterns (reusing check-ph patterns + common key detection):
#  1. Credential assignment lines (KEY=value)
#  2. AWS Access Key IDs (AKIA...)
#  3. GitHub/GitLab PATs (ghp_, ghs_, gho_, glpat-)
#  4. sk-prefixed tokens (OpenAI etc.)
#  5. Long random secrets on KEY= lines (catch-all)
#  6. Absolute Unix paths (/home, /Users, /root, /var, /etc, /usr, /opt, /tmp)
#  7. Windows absolute paths (C:\...)
#  8. Private/RFC-1918 IP URLs
#  9. Internal/corp hostnames in URLs

$REDACTED      = "[REDACTED]"
$PATH_REDACTED = "[PATH_REDACTED]"
$URL_REDACTED  = "[URL_REDACTED]"

$text = $rawContent

# 1. Credential assignment lines
$text = [regex]::Replace($text,
    '(?im)^[^\n=]*(?:api[_-]?key|secret[_-]?(?:access[_-]?)?key|access[_-]?key(?:[_-]?id)?|auth[_-]?token|bearer|password|passwd|credential|private[_-]?(?:key|token)|token)[^\n=]*=[^\n]+',
    { param($m)
        $lhs = ($m.Value -split '=')[0]
        "$lhs=$REDACTED"
    })

# 2. AWS Access Key IDs
$text = [regex]::Replace($text, 'AKIA[0-9A-Z]{16}', $REDACTED)

# 3. GitHub/GitLab PATs
$text = [regex]::Replace($text, '(?:ghp_|ghs_|gho_|glpat-)[A-Za-z0-9_\-]{20,}', $REDACTED)

# 4. sk- prefixed tokens
$text = [regex]::Replace($text, 'sk-[A-Za-z0-9_\-]{20,}', $REDACTED)

# 5. Long random secrets on KEY= lines (catch-all >= 32 chars)
$text = [regex]::Replace($text,
    '(?im)((?:key|token|secret|password|passwd|credential)[^\n=]*=\s*)[A-Za-z0-9+/=]{32,}',
    { param($m) "$($m.Groups[1].Value)$REDACTED" })

# 6. Absolute Unix paths
$text = [regex]::Replace($text,
    '/(?:home|root|Users|var|etc|usr|opt|tmp|private)/[^\s\''"\)\]]*',
    $PATH_REDACTED)

# 7. Windows absolute paths
$text = [regex]::Replace($text,
    '[A-Za-z]:\\[^\s\''"\)\]]*',
    $PATH_REDACTED)

# 8. Private/RFC-1918 IP URLs
$text = [regex]::Replace($text,
    'https?://(?:192\.168\.\d{1,3}|10\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.\d{1,3})(?::\d+)?[^\s\''"\)\]]*',
    $URL_REDACTED)

# 9. Internal/corp hostnames in URLs
$text = [regex]::Replace($text,
    'https?://[^\s\''"\)\]]*(?:internal|corp|intranet|private)[^\s\''"\)\]]*',
    $URL_REDACTED)

# ── Compute input_digest (sha256 of sanitized content) ───────────────────────

$sha256    = [System.Security.Cryptography.SHA256]::Create()
$msgBytes  = [System.Text.Encoding]::UTF8.GetBytes($text)
$hashBytes = $sha256.ComputeHash($msgBytes)
$inputDigest = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""

# ── Write output bundle ──────────────────────────────────────────────────────

$outDir = Split-Path -Parent $OutPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$bundle = @"
# Panelist Input Bundle
# task_id: $TaskId
# feature: $Feature
# input_digest: $inputDigest
# consent: $ConsentKind
# WARNING: This file is sanitized for external LLM review.
#          Do not include secrets, absolute paths, or private URLs.

$text
"@

Set-Content -Encoding Utf8 -Path $OutPath -Value $bundle -NoNewline
Add-Content -Encoding Utf8 -Path $OutPath -Value ""

# ── Emit digest (and threaded effort, if supplied) to stdout ────────────────
# AC-036: --effort is threaded through verbatim on a second stdout line, so
# the caller can lift it into `run-panelist-gpt --effort <e>` in its own
# next step. Omitted entirely preserves today's exact single-line output.

Write-Host $inputDigest
if ($Effort) {
    Write-Host "effort=$Effort"
}
exit 0
