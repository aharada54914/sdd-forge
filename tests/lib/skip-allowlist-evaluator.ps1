param(
    [Parameter(Position = 0, Mandatory = $true)][string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest
)
$ErrorActionPreference = 'Stop'

function Read-Manifest([string]$Path) { return @(Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json) }
function Get-Entry([string]$Path, [string]$Assertion) {
    $entry = @(Read-Manifest $Path | Where-Object assertion_id -eq $Assertion)
    if ($entry.Count -ne 1) { throw "manifest assertion is not unique: $Assertion" }
    return $entry[0]
}
function Invoke-GitText([string]$Repo, [string[]]$Arguments) {
    $text = & git -C $Repo @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($Arguments -join ' ')" }
    return @($text)
}
function Find-EpicBranch([string]$Repo, [int]$Issue) {
    $refs = Invoke-GitText $Repo @('for-each-ref', '--format=%(refname:short)', 'refs/heads', 'refs/remotes')
    $branch = @($refs | Where-Object { $_ -match "epic-$Issue(?:[^0-9]|$)" } | Select-Object -First 1)
    if ($branch.Count -ne 1) { throw "feature branch for issue $Issue was not found" }
    return $branch[0]
}
function Test-Terminal([string]$Repo, [string]$Ref, [string]$Path) {
    try { $lines = Invoke-GitText $Repo @('show', "${Ref}:$Path") } catch { return $false }
    $status = @($lines | Where-Object { $_ -match '^(?:Spec-Review-Status|Impl-Review-Status): ' } | Select-Object -First 1)
    return $status.Count -eq 1 -and (($status[0] -replace '^[^:]+: ', '') -ceq 'Passed')
}
function Test-Merged([string]$Manifest, [string]$Assertion, [string]$Epic, [string]$Repo, [string]$MainRef) {
    $entry = Get-Entry $Manifest $Assertion
    $dependency = @($entry.dependencies | Where-Object epic -eq $Epic)
    if ($dependency.Count -ne 1) { throw "dependency is not unique: $Assertion/$Epic" }
    try { $branch = Find-EpicBranch $Repo ([int]$dependency[0].issue) } catch { return $false }
    & git -C $Repo merge-base --is-ancestor $branch $MainRef 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $specDir = Split-Path -Parent ([string]$dependency[0].fingerprints[0].source)
    return (Test-Terminal $Repo $MainRef "$specDir/requirements.md") -and (Test-Terminal $Repo $MainRef "$specDir/design.md")
}
function Get-Sha256([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Test-Fingerprint([string]$Manifest, [string]$Assertion, [int]$Index, [string]$Repo, [string]$MainRef) {
    $entry = Get-Entry $Manifest $Assertion
    if ($Index -lt 0 -or $Index -ge $entry.dependencies.Count) { throw "dependency index is out of range: $Index" }
    $dependency = $entry.dependencies[$Index]
    try { $branch = Find-EpicBranch $Repo ([int]$dependency.issue) } catch { return $false }
    $ref = if (Test-Merged $Manifest $Assertion ([string]$dependency.epic) $Repo $MainRef) { $MainRef } else { $branch }
    foreach ($fingerprint in $dependency.fingerprints) {
        $range = ([string]$fingerprint.line_range).Split('-')
        $allLines = Invoke-GitText $Repo @('show', "${ref}:$($fingerprint.source)")
        $selected = @($allLines[([int]$range[0] - 1)..([int]$range[1] - 1)])
        $actual = 'sha256:' + (Get-Sha256 ($selected -join "`n"))
        if ($actual -cne [string]$fingerprint.digest) { return $false }
    }
    return $true
}
function Test-Condition([string]$Manifest, [string]$Assertion, [string]$Repo, [string]$MainRef) {
    $condition = [string](Get-Entry $Manifest $Assertion).activation_condition
    $tokens = @($condition.Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    if ($tokens.Count -eq 0 -or $tokens.Count % 2 -ne 1) { throw "invalid activation condition: $condition" }
    $result = $false; $operator = 'OR'
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        if ($i % 2 -eq 1) {
            if ($tokens[$i] -cnotin @('AND', 'OR')) { throw "invalid activation operator: $($tokens[$i])" }
            $operator = $tokens[$i]; continue
        }
        if ($tokens[$i] -cmatch '^merged\((A[0-9]+)\)$') { $value = Test-Merged $Manifest $Assertion $Matches[1] $Repo $MainRef }
        elseif ($tokens[$i] -cmatch '^fingerprint_match\(([0-9]+)\)$') { $value = Test-Fingerprint $Manifest $Assertion ([int]$Matches[1]) $Repo $MainRef }
        else { throw "invalid activation primitive: $($tokens[$i])" }
        if ($i -eq 0) { $result = $value }
        elseif ($operator -ceq 'AND') { $result = $result -and $value }
        else { $result = $result -or $value }
    }
    return $result
}
function Invoke-Audit([string]$Manifest, [string]$Output, [string]$Repo, [string]$MainRef) {
    $marker = 'SK' + 'IP:'; $failures = 0; $count = 0
    foreach ($line in Get-Content -LiteralPath $Output) {
        if (-not $line.Contains($marker)) { continue }
        $count++
        $ids = @([regex]::Matches($line, 'AC-[0-9]{3}') | ForEach-Object Value | Sort-Object -Unique)
        if ($ids.Count -eq 0) { [Console]::Error.WriteLine("ERROR: unrecognized skip-shaped line: $line"); $failures++; continue }
        foreach ($assertion in $ids) {
            try { $entry = Get-Entry $Manifest $assertion } catch { [Console]::Error.WriteLine("ERROR: unrecognized allowlist assertion $assertion"); $failures++; continue }
            if (Test-Condition $Manifest $assertion $Repo $MainRef) { [Console]::Error.WriteLine("ERROR: $assertion emitted after activation condition became true"); $failures++ }
            for ($i = 0; $i -lt $entry.dependencies.Count; $i++) {
                $epic = [string]$entry.dependencies[$i].epic
                if ((Test-Merged $Manifest $assertion $epic $Repo $MainRef) -and -not (Test-Fingerprint $Manifest $assertion $i $Repo $MainRef)) {
                    [Console]::Error.WriteLine("ERROR: $assertion dependency $epic fingerprint drift"); $failures++
                }
            }
        }
    }
    if ($failures -ne 0) { return 1 }
    $suffix = if ($count -eq 1) { '' } else { 's' }
    [Console]::Out.WriteLine("audited $count allowlisted line$suffix")
    return 0
}

try {
    switch -CaseSensitive ($Command) {
        'merged' { if (Test-Merged $Rest[0] $Rest[1] $Rest[2] $Rest[3] $Rest[4]) { exit 0 } else { exit 1 } }
        'fingerprint-match' { if (Test-Fingerprint $Rest[0] $Rest[1] ([int]$Rest[2]) $Rest[3] $Rest[4]) { exit 0 } else { exit 1 } }
        'condition' { if (Test-Condition $Rest[0] $Rest[1] $Rest[2] $Rest[3]) { exit 0 } else { exit 1 } }
        'audit' { exit (Invoke-Audit $Rest[0] $Rest[1] $Rest[2] $Rest[3]) }
        default { throw 'usage: evaluator {merged|fingerprint-match|condition|audit} ...' }
    }
} catch { [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)"); exit 2 }
