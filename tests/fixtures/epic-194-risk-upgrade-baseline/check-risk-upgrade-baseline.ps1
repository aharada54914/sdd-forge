[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [AllowEmptyString()]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

function Write-InputUnavailable {
    [Console]::Out.WriteLine('risk-upgrade: input unavailable')
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

$triggers = @($rules | Where-Object { Test-BoundedMatch $normalized $_.Expression } | ForEach-Object { $_.Id })
if ($triggers.Count -eq 0) {
    [Console]::Out.WriteLine('lite-eligible')
    exit 0
}

[Console]::Out.WriteLine(('full-required: {0}; triggers={1}' -f $triggers[0], ($triggers -join ',')))
exit 10
