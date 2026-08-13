$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = if ($env:STRUCTURAL_COMPAT_REPO_ROOT) { $env:STRUCTURAL_COMPAT_REPO_ROOT } else { Split-Path -Parent $ScriptDir }
$Canon = Join-Path $RepoRoot 'tests/lib/markdown-ast-canonicalizer.ps1'
$Corpus = Join-Path $RepoRoot 'tests/fixtures/structural-fixture-corpus'
$BootstrapSkill = Join-Path $RepoRoot 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
$LiteSkill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-spec/SKILL.md'
$Design = Join-Path $RepoRoot 'specs/epic-195-a7-compatibility/design.md'
$Acceptance = Join-Path $RepoRoot 'specs/epic-195-a7-compatibility/acceptance-tests.md'
$script:Passed = 0
$script:Failed = 0

function Pass([string]$Label) { Write-Output "PASS: $Label"; $script:Passed++ }
function Fail([string]$Label) { Write-Error "FAIL: $Label" -ErrorAction Continue; $script:Failed++ }
function Assert-True([string]$Label, [bool]$Condition) { if ($Condition) { Pass $Label } else { Fail $Label } }

$Required = @(
    $Canon, $BootstrapSkill, $LiteSkill, $Design, $Acceptance,
    (Join-Path $Corpus 'f1-full.json'), (Join-Path $Corpus 'f2-lite.json'),
    (Join-Path $Corpus 'f3-advisory.json'), (Join-Path $Corpus 'f4-required.json')
)
$Missing = $false
foreach ($Path in $Required) {
    if (-not (Test-Path -LiteralPath $Path)) { Fail "required shipped product surface exists: $Path"; $Missing = $true }
}
if ($Missing) { Write-Output "$($script:Passed) passed, $($script:Failed) failed"; exit 1 }

function Get-FullPaths([string]$Source = $BootstrapSkill) {
    $InOutputs = $false
    foreach ($Line in Get-Content -LiteralPath $Source) {
        if ($Line -ceq '## Required Outputs') { $InOutputs = $true; continue }
        if ($InOutputs -and $Line -cmatch '^Phase 2 outputs') { break }
        if ($InOutputs -and $Line -cmatch '^- `specs/<feature>/([^`]+\.md)`$') { $Matches[1] }
    }
}
function Get-LitePaths {
    $InOutputs = $false
    foreach ($Line in Get-Content -LiteralPath $LiteSkill) {
        if ($Line -cmatch '次の3ファイルを `specs/<feature>/` に生成') { $InOutputs = $true; continue }
        if ($InOutputs -and $Line -cmatch '^4\.') { break }
        if ($InOutputs -and $Line -cmatch '- `([^`]+\.md)`') { $Matches[1] }
    }
}
function Get-Template([string]$Track, [string]$Path) {
    if ($Track -ceq 'full') {
        return Join-Path $RepoRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/$($Path.Substring(0, $Path.Length - 3)).template.md"
    }
    $Name = switch -CaseSensitive ($Path) { 'requirements.md' { 'requirements-lite.md' }; 'design.md' { 'design-lite.md' }; 'tasks.md' { 'tasks-lite.md' }; default { throw "unknown lite path: $Path" } }
    Join-Path $RepoRoot "plugins/sdd-lite/templates/$Name"
}

$DesignText = Get-Content -LiteralPath $Design -Raw
$Schema = [regex]::Match($DesignText, '\{schema: "([^"]+)"', [Text.RegularExpressions.RegexOptions]::CultureInvariant).Groups[1].Value
$TasksText = Get-Content -LiteralPath (Join-Path $RepoRoot 'specs/epic-195-a7-compatibility/tasks.md') -Raw
$T012 = $TasksText.Substring($TasksText.IndexOf('## T-012 '))
$Refresh = [regex]::Match($T012, '`([^`]*structural-compatibility-live-refresh\.tests\.sh)`', [Text.RegularExpressions.RegexOptions]::CultureInvariant).Groups[1].Value

function Read-Corpus([string]$Name) { Get-Content -LiteralPath (Join-Path $Corpus $Name) -Raw | ConvertFrom-Json }
function Valid-Envelope($Value, [string]$State) {
    if ($Value.schema -cne $Schema -or $Value.fixture_state -cne $State -or [string]::IsNullOrEmpty($Value.recorded_at_model) -or
        $Value.recorded_at_commit -cnotmatch '^[0-9a-f]{40}$' -or $Value.refresh_procedure -cne $Refresh -or $null -eq $Value.artifacts) { return $false }
    foreach ($Artifact in $Value.artifacts) { if ([string]::IsNullOrEmpty($Artifact.path) -or $null -eq $Artifact.content) { return $false } }
    return $true
}
$F1 = Read-Corpus 'f1-full.json'; $F2 = Read-Corpus 'f2-lite.json'; $F3 = Read-Corpus 'f3-advisory.json'; $F4 = Read-Corpus 'f4-required.json'
Assert-True 'F1 corpus envelope matches the shipped schema' (Valid-Envelope $F1 'F1')
Assert-True 'F2 corpus envelope matches the shipped schema' (Valid-Envelope $F2 'F2')
Assert-True 'F3 corpus envelope matches the shipped schema' (Valid-Envelope $F3 'F3')
Assert-True 'F4 corpus envelope matches the shipped schema' (Valid-Envelope $F4 'F4')

$OperatorMiscase = $F1 | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$OperatorState = [string]$F1.fixture_state
$OperatorMiscase.fixture_state = $OperatorState.ToLowerInvariant()
Assert-True 'operator layer rejects a mis-cased shipped state' (-not (Valid-Envelope $OperatorMiscase $OperatorState))

$LanguageMiscase = Join-Path ([IO.Path]::GetTempPath()) ("structural-anchor-miscase-" + [guid]::NewGuid().ToString('N') + '.md')
try {
    (Get-Content -LiteralPath $BootstrapSkill -Raw).Replace('## Required Outputs', '## required outputs') | Set-Content -LiteralPath $LanguageMiscase -NoNewline
    Assert-True 'language matching layer rejects a mis-cased shipped anchor' (@(Get-FullPaths $LanguageMiscase).Count -eq 0)
}
finally { Remove-Item -LiteralPath $LanguageMiscase -Force }

$ExpectedAnchor = [regex]::Match($DesignText, 'recorded anchor-window fingerprint[\s\S]*?sha256:\s*([0-9a-f]{64})', [Text.RegularExpressions.RegexOptions]::CultureInvariant).Groups[1].Value
$Lines = Get-Content -LiteralPath $BootstrapSkill
$Start = [array]::IndexOf($Lines, '## Required Outputs')
$End = $Start
while ($End -lt $Lines.Count -and $Lines[$End] -cnotmatch 'create-only rule\.') { $End++ }
$AnchorText = (($Lines[$Start..$End] -join "`n"))
$Hash = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($AnchorText))
$ActualAnchor = [Convert]::ToHexString($Hash).ToLowerInvariant()
Assert-True 'fingerprinted Required Outputs injection anchor is unchanged' ($ActualAnchor -ceq $ExpectedAnchor)

$Temp = Join-Path ([IO.Path]::GetTempPath()) ("structural-compat-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Temp | Out-Null
try {
    function Invoke-CanonText([string]$Text, [string]$Name) {
        $Path = Join-Path $Temp $Name
        [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
        (& $Canon $Path | Out-String).Trim()
    }
    function Status-Fields([string]$Text) {
        [regex]::Matches($Text, '(?m)^([A-Za-z][A-Za-z0-9 -]*(?:Status|Approval)):\s.*$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -CaseSensitive -Unique
    }
    function Validate-Track([string]$Track, $Entry) {
        $Expected = if ($Track -ceq 'full') { @(Get-FullPaths) } else { @(Get-LitePaths) }
        $Actual = @($Entry.artifacts | ForEach-Object path)
        [Array]::Sort($Expected, [StringComparer]::Ordinal)
        [Array]::Sort($Actual, [StringComparer]::Ordinal)
        Assert-True "$Track artifact paths and exact count derive from its shipped output surface" (($Expected -join "`n") -ceq ($Actual -join "`n"))
        foreach ($Path in $Expected) {
            $Template = Get-Template $Track $Path
            if (-not (Test-Path -LiteralPath $Template)) { Fail "$Track shipped template exists for $Path"; continue }
            $TemplateText = Get-Content -LiteralPath $Template -Raw
            $Artifact = $Entry.artifacts | Where-Object { $_.path -ceq $Path }
            if ($null -eq $Artifact) { Fail "$Track corpus contains $Path"; continue }
            $ExpectedAst = (& $Canon $Template | Out-String).Trim()
            $ActualAst = Invoke-CanonText $Artifact.content ("corpus-" + $Path.Replace('/', '_'))
            Assert-True "$Track $Path frontmatter and ordered headings match its shipped template" ($ExpectedAst -ceq $ActualAst)
            Assert-True "$Track $Path status field names match its shipped template" (((Status-Fields $TemplateText) -join "`n") -ceq ((Status-Fields $Artifact.content) -join "`n"))
        }
        $All = ($Entry.artifacts | ForEach-Object content) -join "`n"
        $Ids = [regex]::Matches($All, '(REQ|AC)-[A-Za-z0-9-]+', [Text.RegularExpressions.RegexOptions]::CultureInvariant) | ForEach-Object Value
        Assert-True "$Track generated identifiers retain the shipped three-digit grammar" ($Ids.Count -gt 0 -and @($Ids | Where-Object { $_ -cnotmatch '^(REQ|AC)-[0-9]{3}$' }).Count -eq 0)
        $ReservedA = 'Fac' + 'et'; $ReservedB = 'capab' + 'ility'
        $HasReservedReference = $All.Contains($ReservedA, [StringComparison]::OrdinalIgnoreCase) -or $All.Contains($ReservedB, [StringComparison]::OrdinalIgnoreCase) -or
            @($Entry.artifacts.path | Where-Object { $_.Contains($ReservedA, [StringComparison]::OrdinalIgnoreCase) -or $_.Contains($ReservedB, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        Assert-True "$Track output contains no reserved artifact or reference vocabulary" (-not $HasReservedReference)
    }
    Validate-Track 'full' $F1
    Validate-Track 'lite' $F2
    $ReorderedPaths = @($F1.artifacts.path)
    [Array]::Reverse($ReorderedPaths)
    $ExpectedReorderedPaths = @(Get-FullPaths)
    [Array]::Sort($ReorderedPaths, [StringComparer]::Ordinal)
    [Array]::Sort($ExpectedReorderedPaths, [StringComparer]::Ordinal)
    Assert-True 'corpus artifact array order is comparison-irrelevant' (($ExpectedReorderedPaths -join "`n") -ceq ($ReorderedPaths -join "`n"))

    $BadFront = Join-Path $Temp 'bad-frontmatter.md'; [IO.File]::WriteAllText($BadFront, "---`ntitle: broken`n")
    & pwsh -NoProfile -File $Canon $BadFront *> $null
    Assert-True 'malformed frontmatter is a hard failure' ($LASTEXITCODE -ne 0)
    $BadHeading = Join-Path $Temp 'bad-heading.md'; [IO.File]::WriteAllText($BadHeading, '####### Broken heading grammar')
    & pwsh -NoProfile -File $Canon $BadHeading *> $null
    Assert-True 'unrecognized heading grammar is a hard failure' ($LASTEXITCODE -ne 0)

    $NormA = Invoke-CanonText "---`nzeta:  one`nalpha: two`n---`n# Heading   text `n" 'norm-a.md'
    $NormB = Invoke-CanonText "---`r`nalpha: two`r`nzeta: one `r`n---`r`n# Heading text`r`n" 'norm-b.md'
    Assert-True 'frontmatter order and permitted whitespace/line endings normalize' ($NormA -ceq $NormB)
    $ValueChange = Invoke-CanonText "---`nalpha: changed`nzeta: one`n---`n# Heading text`n" 'value-change.md'
    Assert-True 'frontmatter values remain comparison-significant' ($NormA -cne $ValueChange)
    $HeadingA = Invoke-CanonText "# First`n## Second`n" 'heading-a.md'
    $HeadingB = Invoke-CanonText "## Second`n# First`n" 'heading-b.md'
    Assert-True 'heading level and document order remain comparison-significant' ($HeadingA -cne $HeadingB)

    foreach ($Pair in @(@('F4', $F4), @('F3', $F3))) {
        $Fixture = $Pair[0]; $Entry = $Pair[1]
        $Row = Get-Content -LiteralPath $Acceptance | Where-Object { $_.Contains("($Fixture", [StringComparison]::Ordinal) }
        $Ac = (($Row -csplit '\|')[1]).Trim()
        $ExpectedDependencies = @([regex]::Matches($Row, 'Epic A[0-9]+', [Text.RegularExpressions.RegexOptions]::CultureInvariant) | ForEach-Object Value | Sort-Object -CaseSensitive -Unique)
        $ActualDependencies = @($Entry.skip.dependencies | Sort-Object -CaseSensitive -Unique)
        $ValidSkip = $Entry.skip.name -ceq $Fixture -and $Entry.skip.acceptance_criterion -ceq $Ac -and
            -not [string]::IsNullOrEmpty($Entry.skip.reason) -and (($ExpectedDependencies -join "`n") -ceq ($ActualDependencies -join "`n"))
        if ($ValidSkip) { Write-Output "SKIP: $Fixture/$Ac ($($ActualDependencies -join '+')): $($Entry.skip.reason)" } else { Fail "$Fixture named skip metadata matches its acceptance dependency" }
    }
    $TaskSkipSpan = [regex]::Match($TasksText, 'F5/F6 structural-identity assertions are named `SKIP`s[\s\S]*?until they merge', [Text.RegularExpressions.RegexOptions]::CultureInvariant).Value
    $CompoundRow = Get-Content -LiteralPath $Acceptance | Where-Object { $_.Contains('F5 advisory / F6 required', [StringComparison]::Ordinal) }
    $CompoundAc = (($CompoundRow -csplit '\|')[1]).Trim()
    $AcceptanceDependencies = @([regex]::Matches($CompoundRow, 'A[0-9]+', [Text.RegularExpressions.RegexOptions]::CultureInvariant) | ForEach-Object Value | Sort-Object -CaseSensitive -Unique)
    $TaskDependencies = @([regex]::Matches($TaskSkipSpan, 'A[0-9]+', [Text.RegularExpressions.RegexOptions]::CultureInvariant) | ForEach-Object Value | Sort-Object -CaseSensitive -Unique)
    foreach ($Fixture in @('F5', 'F6')) {
        if ($AcceptanceDependencies.Count -gt 1 -and (($AcceptanceDependencies -join "`n") -ceq ($TaskDependencies -join "`n"))) {
            Write-Output "SKIP: $Fixture/$CompoundAc ($($AcceptanceDependencies -join '+')): compound dependency not merged"
        } else { Fail "$Fixture compound named skip matches task and acceptance dependencies" }
    }
    $Runner = Get-Content -LiteralPath (Join-Path $RepoRoot 'tests/run-all.ps1')
    Assert-True 'PowerShell aggregate runner registers this shipped suite' ($Runner -ccontains '    "tests/structural-compatibility.tests.ps1"')
}
finally { Remove-Item -LiteralPath $Temp -Recurse -Force }

Write-Output "$($script:Passed) passed, $($script:Failed) failed"
if ($script:Failed -ne 0) { exit 1 }
