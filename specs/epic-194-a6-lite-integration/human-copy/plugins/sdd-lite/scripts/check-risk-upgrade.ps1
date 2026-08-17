[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [AllowEmptyString()]
    [string]$Path,

    [Parameter(Position = 1)]
    [AllowNull()]
    [string]$CapabilityReasons
)

# epic-194-a6-lite-integration T-002 (REQ-002): extended with an optional
# -CapabilityReasons <fragment-path> parameter. Omitted entirely -> byte-
# identical to the pre-T-002 script (AC-007). Supplied -> unreadable/
# malformed/shape-invalid fragment is a hard error, exit 2, no trigger
# reporting (Blocker [B3]); a valid fragment's eligible:$false entries
# contribute their own upgrade_reasons tokens, or a synthetic
# "ineligible:<id>" token when upgrade_reasons is empty/absent (Blocker
# [B4]), appended AFTER the existing keyword-derived tokens (AC-008).

$ErrorActionPreference = 'Stop'

function Write-InputUnavailable {
    [Console]::Out.WriteLine('risk-upgrade: input unavailable')
    exit 2
}

function Write-FragmentInvalid {
    [Console]::Out.WriteLine('risk-upgrade: capability-reasons fragment invalid')
    exit 2
}

function ConvertTo-AsciiLower([string]$Value) {
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Value.ToCharArray()) {
        $codePoint = [int][char]$character
        if ($codePoint -ge 65 -and $codePoint -le 90) {
            [void]$builder.Append([char]($codePoint + 32))
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString()
}

function Test-BoundedMatch([string]$Value, [string]$Expression) {
    return [regex]::IsMatch($Value, '(^|[^a-z0-9_])(?:' + $Expression + ')(?=$|[^a-z0-9_])')
}

try {
    if ($null -eq $Path -or $Path.Length -eq 0) {
        Write-InputUnavailable
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes -contains [byte]0) {
        Write-InputUnavailable
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $source = $utf8.GetString($bytes)
} catch {
    Write-InputUnavailable
}

$normalized = ConvertTo-AsciiLower $source
$normalized = $normalized.Replace("`r`n", "`n").Replace("`r", "`n")
$normalized = [regex]::Replace($normalized, '[ \t\n]+', ' ')
$normalized = [regex]::Replace(
    $normalized,
    '(^|[^a-z0-9_])design tokens?(?=$|[^a-z0-9_])',
    '$1 '
)

$rules = @(
    [PSCustomObject]@{ Id = 'AUTH_BOUNDARY'; Expression = 'auth|authentication|authorization|oauth|oidc' },
    [PSCustomObject]@{ Id = 'TOKEN_CREDENTIAL'; Expression = 'token|tokens|credential|credentials|password|passwords|private key(?:s)?' },
    [PSCustomObject]@{ Id = 'MCP'; Expression = 'mcp' },
    [PSCustomObject]@{ Id = 'EXTERNAL_API'; Expression = 'external[ -]+api(?:s)?|third[ -]+party[ -]+api(?:s)?' },
    [PSCustomObject]@{ Id = 'SECRET'; Expression = 'secret|secrets' },
    [PSCustomObject]@{ Id = 'GITHUB_ACTIONS'; Expression = 'github actions' }
)

$keywordTriggers = @($rules | Where-Object { Test-BoundedMatch $normalized $_.Expression } | ForEach-Object { $_.Id })

$capabilityTriggers = @()
if ($PSBoundParameters.ContainsKey('CapabilityReasons') -and -not [string]::IsNullOrEmpty($CapabilityReasons)) {
    try {
        if (-not (Test-Path -LiteralPath $CapabilityReasons -PathType Leaf)) { Write-FragmentInvalid }
        $fragmentBytes = [IO.File]::ReadAllBytes($CapabilityReasons)
        $fragmentUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $fragmentText = $fragmentUtf8.GetString($fragmentBytes)
        $fragment = $fragmentText | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $fragment -or $null -eq $fragment.PSObject.Properties['capabilities']) {
            Write-FragmentInvalid
        }
        $capabilities = @($fragment.capabilities)
        foreach ($entry in $capabilities) {
            if ($null -eq $entry -or $null -eq $entry.PSObject.Properties['id'] -or $null -eq $entry.PSObject.Properties['eligible']) {
                Write-FragmentInvalid
            }
        }
        foreach ($entry in $capabilities) {
            if ($entry.eligible -eq $false) {
                $reasons = @()
                if ($null -ne $entry.PSObject.Properties['upgrade_reasons'] -and $null -ne $entry.upgrade_reasons) {
                    $reasons = @($entry.upgrade_reasons)
                }
                if ($reasons.Count -gt 0) {
                    foreach ($token in $reasons) { $capabilityTriggers += [string]$token }
                } else {
                    $capabilityTriggers += ('ineligible:' + [string]$entry.id)
                }
            }
        }
    } catch {
        Write-FragmentInvalid
    }
}

$allTriggers = @($keywordTriggers + $capabilityTriggers)
if ($allTriggers.Count -eq 0) {
    [Console]::Out.WriteLine('lite-eligible')
    exit 0
}

[Console]::Out.WriteLine(('full-required: {0}; triggers={1}' -f $allTriggers[0], ($allTriggers -join ',')))
exit 10
