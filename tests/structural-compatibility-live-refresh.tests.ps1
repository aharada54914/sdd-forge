param(
    [Parameter(Mandatory = $true)][ValidateSet('F1','F2','F3','F4')][string]$State,
    [string]$Fixture,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$Corpus = Join-Path $Root 'tests/fixtures/structural-fixture-corpus'
$Canon = Join-Path $Root 'tests/lib/markdown-ast-canonicalizer.ps1'
$TargetName = @{ F1='f1-full.json'; F2='f2-lite.json'; F3='f3-advisory.json'; F4='f4-required.json' }[$State]
$Track = if ($State -ceq 'F2') { 'lite' } else { 'full' }
if (-not $Fixture -and -not $DryRun) {
    if ([string]::IsNullOrEmpty($env:SDD_LIVE_MODEL_CMD)) { throw 'SDD_LIVE_MODEL_CMD is required' }
    $Prompt = "Generate the complete structural-fixture-corpus/v1 JSON envelope for $State. Return JSON only; do not use markdown fences."
    $Fixture = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N') + '.json')
    try {
        $Output = $Prompt | & $env:SDD_LIVE_MODEL_CMD
        if ($LASTEXITCODE -ne 0) { throw "live model command exited $LASTEXITCODE" }
        [IO.File]::WriteAllText($Fixture, ($Output -join "`n"), [Text.UTF8Encoding]::new($false))
    }
    catch { throw "live model command failed: $_" }
}
if (-not (Test-Path -LiteralPath $Fixture -PathType Leaf)) { throw 'fixture input does not exist' }
$Entry = Get-Content -LiteralPath $Fixture -Raw | ConvertFrom-Json
if ($Entry.schema -cne 'structural-fixture-corpus/v1' -or $Entry.fixture_state -cne $State -or
    [string]::IsNullOrEmpty($Entry.recorded_at_model) -or $Entry.recorded_at_commit -cnotmatch '^[0-9a-f]{40}$' -or
    $Entry.refresh_procedure -cne 'tests/structural-compatibility-live-refresh.tests.sh' -or $null -eq $Entry.artifacts) { throw 'invalid corpus envelope' }
foreach ($Artifact in $Entry.artifacts) { if ([string]::IsNullOrEmpty($Artifact.path) -or $null -eq $Artifact.content) { throw 'invalid corpus artifact' } }
$Paths = @($Entry.artifacts | ForEach-Object path)
if ($Paths.Count -eq 0 -or (@($Paths | Select-Object -Unique).Count -ne $Paths.Count)) { throw 'empty or duplicate corpus artifact paths' }
$Skill = Join-Path $Root 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
if ($Track -ceq 'lite') { $Skill = Join-Path $Root 'plugins/sdd-lite/skills/lite-spec/SKILL.md' }
$Lines = Get-Content -LiteralPath $Skill
$Expected = [Collections.Generic.List[string]]::new()
$InOutputs = $false
foreach ($Line in $Lines) {
    if ($Track -ceq 'full') {
        if ($Line -ceq '## Required Outputs') { $InOutputs = $true; continue }
        if ($InOutputs -and $Line -cmatch '^Phase 2 outputs') { break }
        if ($InOutputs -and $Line -cmatch '^- `specs/<feature>/([^`]+\.md)`$') { $Expected.Add($Matches[1]) }
    } else {
        if ($Line -cmatch '次の3ファイルを `specs/<feature>/` に生成') { $InOutputs = $true; continue }
        if ($InOutputs -and $Line -cmatch '^4\.') { break }
        if ($InOutputs -and $Line -cmatch '- `([^`]+\.md)`') { $Expected.Add($Matches[1]) }
    }
}
$Actual = @($Entry.artifacts | ForEach-Object path)
[Array]::Sort([string[]]$Expected, [StringComparer]::Ordinal)
[Array]::Sort([string[]]$Actual, [StringComparer]::Ordinal)
if (($Expected -join "`n") -cne ($Actual -join "`n")) { throw 'required output paths/count differ' }
$Temp = Join-Path ([IO.Path]::GetTempPath()) ('live-refresh-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Temp | Out-Null
try {
    foreach ($Path in $Expected) {
        $Artifact = $Entry.artifacts | Where-Object { $_.path -ceq $Path }
        $LivePath = Join-Path $Temp 'live.md'; $AstPath = Join-Path $Temp 'live.ast'
        [IO.File]::WriteAllText($LivePath, [string]$Artifact.content, [Text.UTF8Encoding]::new($false))
        $HostPath = (Get-Process -Id $PID).Path
        $CanonOutput = & $HostPath -NoProfile -File $Canon $LivePath
        if ($LASTEXITCODE -ne 0) { throw "invalid markdown structure: $Path" }
        [IO.File]::WriteAllText($AstPath, ($CanonOutput -join "`n"), [Text.UTF8Encoding]::new($false))
        if ($Track -ceq 'full') { $Template = Join-Path $Root "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/$($Path.Substring(0,$Path.Length-3)).template.md" }
        else {
            $Name = switch -CaseSensitive ($Path) { requirements.md {'requirements-lite.md'} design.md {'design-lite.md'} tasks.md {'tasks-lite.md'} default { throw "unknown lite path: $Path" } }
            $Template = Join-Path $Root "plugins/sdd-lite/templates/$Name"
        }
        $TemplateOutput = & $HostPath -NoProfile -File $Canon $Template
        if ($LASTEXITCODE -ne 0) { throw "invalid reference template: $Path" }
        $TemplateAst = Join-Path $Temp 'template.ast'
        [IO.File]::WriteAllText($TemplateAst, ($TemplateOutput -join "`n"), [Text.UTF8Encoding]::new($false))
        if ((Get-Content -LiteralPath $AstPath -Raw) -cne (Get-Content -LiteralPath $TemplateAst -Raw)) { throw "structural mismatch: $Path" }
    }
    if ($DryRun) {
        Write-Output 'PASS: fixture validates; dry-run left corpus unchanged'
        if ($env:SDD_LIVE_REFRESH_SELF_CHECK -ceq '1') { exit 0 }
        $Before = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Corpus $TargetName)).Hash
        $Entry.artifacts[0].content = "---`nbroken frontmatter"
        $Bad = Join-Path $Temp 'rejected.json'
        $Entry | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Bad -Encoding utf8
        $RefreshScript = Join-Path $PSScriptRoot 'structural-compatibility-live-refresh.tests.ps1'
        $env:SDD_LIVE_REFRESH_SELF_CHECK = '1'
        try { & $HostPath -NoProfile -File $RefreshScript -State $State -Fixture $Bad -DryRun *> $null; $RejectedCode = $LASTEXITCODE }
        finally { Remove-Item Env:SDD_LIVE_REFRESH_SELF_CHECK -ErrorAction SilentlyContinue }
        if ($RejectedCode -eq 0 -or $Before -cne (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Corpus $TargetName)).Hash) { throw 'malformed fixture accepted or corpus changed' }
        Write-Output 'PASS: malformed fixture rejected without corpus modification'
        exit 0
    }
    $Entry.recorded_at_model = if ($env:SDD_LIVE_MODEL_NAME) { $env:SDD_LIVE_MODEL_NAME } else { $env:SDD_LIVE_MODEL_CMD }
    $Entry.recorded_at_commit = (& git -C $Root rev-parse HEAD).Trim()
    $Destination = Join-Path $Corpus $TargetName
    $NewJson = Join-Path $Corpus ('.' + $TargetName + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($NewJson, ($Entry | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($NewJson, $Destination, $true)
    Write-Output "PASS: refreshed $State corpus entry"
}
finally { Remove-Item -LiteralPath $Temp -Recurse -Force; if ($Fixture -and $Fixture.EndsWith('.json') -and -not $PSBoundParameters.ContainsKey('Fixture')) { Remove-Item -LiteralPath $Fixture -Force -ErrorAction SilentlyContinue } }
