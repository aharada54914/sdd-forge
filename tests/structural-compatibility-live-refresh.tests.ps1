param(
    [ValidateSet('F1', 'F2', 'all')][string]$Fixture = 'all',
    [string]$TargetDir,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Builder = Join-Path $RepoRoot 'tests/lib/fixture-matrix-builder.ps1'
$Canon = Join-Path $RepoRoot 'tests/lib/markdown-ast-canonicalizer.ps1'
$BootstrapSkill = Join-Path $RepoRoot 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
$LiteSkill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-spec/SKILL.md'
$Corpus = Join-Path $RepoRoot 'tests/fixtures/structural-fixture-corpus'
$Schema = 'structural-fixture-corpus/v1'
$RefreshProcedure = 'tests/structural-compatibility-live-refresh.tests.sh'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$script:SuppressRefreshFailure = $false
if ([string]::IsNullOrEmpty($TargetDir)) { $TargetDir = $Corpus }

$script:_SddFixtureMatrixBuilderSourced = $false
. $Builder

function Get-FullPaths([string]$Source = $BootstrapSkill) {
    $inOutputs = $false
    foreach ($line in Get-Content -LiteralPath $Source) {
        if ($line -ceq '## Required Outputs') { $inOutputs = $true; continue }
        if ($inOutputs -and $line -cmatch '^Phase 2 outputs') { break }
        if ($inOutputs -and $line -cmatch '^- `specs/<feature>/([^`]+\.md)`$') { $Matches[1] }
    }
}

function Get-LitePaths {
    $inOutputs = $false
    foreach ($line in Get-Content -LiteralPath $LiteSkill) {
        if ($line -cmatch '次の3ファイルを `specs/<feature>/` に生成') { $inOutputs = $true; continue }
        if ($inOutputs -and $line -cmatch '^4\.') { break }
        if ($inOutputs -and $line -cmatch '- `([^`]+\.md)`') { $Matches[1] }
    }
}

function Get-Template([string]$Track, [string]$Path) {
    if ($Track -ceq 'full') {
        return Join-Path $RepoRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/$($Path.Substring(0, $Path.Length - 3)).template.md"
    }
    $name = switch -CaseSensitive ($Path) {
        'requirements.md' { 'requirements-lite.md' }
        'design.md' { 'design-lite.md' }
        'tasks.md' { 'tasks-lite.md' }
        default { throw "unknown lite artifact: $Path" }
    }
    return Join-Path $RepoRoot "plugins/sdd-lite/templates/$name"
}

function Test-Candidate([string]$Path, [string]$State, [string]$Track) {
    $work = Join-Path ([IO.Path]::GetTempPath()) ('structural-live-validate.' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        try { $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { return $false }
        $envelopeKeys = @($value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
        $requiredEnvelopeKeys = @('artifacts','fixture_state','recorded_at_commit','recorded_at_model','refresh_procedure','schema')
        if (($envelopeKeys -join "`n") -cne ($requiredEnvelopeKeys -join "`n") -or
            $value.schema -cne $Schema -or $value.fixture_state -cne $State -or
            $value.recorded_at_model -isnot [string] -or [string]::IsNullOrEmpty($value.recorded_at_model) -or
            $value.recorded_at_commit -isnot [string] -or $value.recorded_at_commit -cnotmatch '^[0-9a-f]{40}$' -or
            $value.refresh_procedure -cne $RefreshProcedure -or $null -eq $value.artifacts) { return $false }

        $artifacts = @($value.artifacts)
        if ($artifacts.Count -eq 0) { return $false }
        foreach ($artifact in $artifacts) {
            $artifactKeys = @($artifact.PSObject.Properties.Name | Sort-Object -CaseSensitive)
            if (($artifactKeys -join "`n") -cne "content`npath" -or $artifact.path -isnot [string] -or
                [string]::IsNullOrEmpty($artifact.path) -or $artifact.content -isnot [string]) { return $false }
        }

        $expected = if ($Track -ceq 'full') { @(Get-FullPaths) } else { @(Get-LitePaths) }
        $actual = @($artifacts | ForEach-Object path)
        [Array]::Sort($expected, [StringComparer]::Ordinal)
        [Array]::Sort($actual, [StringComparer]::Ordinal)
        if (($expected -join "`n") -cne ($actual -join "`n")) { return $false }

        function Get-StatusFields([string]$Text) {
            @([regex]::Matches($Text, '(?m)^([A-Za-z][A-Za-z0-9 -]*(?:Status|Approval)):\s.*$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -CaseSensitive -Unique)
        }

        $astPairs = [Collections.Generic.List[object]]::new()
        foreach ($artifactPath in $expected) {
            $template = Get-Template $Track $artifactPath
            if (-not (Test-Path -LiteralPath $template -PathType Leaf)) { return $false }
            $artifact = @($artifacts | Where-Object { $_.path -ceq $artifactPath })
            if ($artifact.Count -ne 1) { return $false }
            $raw = Join-Path $work ($artifactPath.Replace('/','_') + '.md')
            [IO.File]::WriteAllText($raw, $artifact[0].content, $Utf8NoBom)
            $astPairs.Add([ordered]@{ expected=$template; actual=$raw })
            $templateText = [IO.File]::ReadAllText($template)
            if (((Get-StatusFields $templateText) -join "`n") -cne ((Get-StatusFields $artifact[0].content) -join "`n")) { return $false }
        }

        $astManifest = Join-Path $work 'ast-pairs.json'
        [IO.File]::WriteAllText($astManifest, ($astPairs | ConvertTo-Json -Depth 5), $Utf8NoBom)
        $astDriver = Join-Path $work 'validate-asts.ps1'
        $astDriverText = @'
param([string]$Canonicalizer, [string]$Manifest)
$ErrorActionPreference = 'Stop'
$pairs = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
foreach ($pair in @($pairs)) {
    $expected = ((& $Canonicalizer $pair.expected) | Out-String).Trim()
    $actual = ((& $Canonicalizer $pair.actual) | Out-String).Trim()
    if ($expected -cne $actual) { exit 1 }
}
exit 0
'@
        [IO.File]::WriteAllText($astDriver, $astDriverText, $Utf8NoBom)
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.ArgumentList.Add('-NoProfile')
        $startInfo.ArgumentList.Add('-File')
        $startInfo.ArgumentList.Add($astDriver)
        $startInfo.ArgumentList.Add('-Canonicalizer')
        $startInfo.ArgumentList.Add($Canon)
        $startInfo.ArgumentList.Add('-Manifest')
        $startInfo.ArgumentList.Add($astManifest)
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        [void]$process.Start()
        [void]$process.StandardOutput.ReadToEnd()
        [void]$process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { return $false }

        $allContent = ($artifacts | ForEach-Object content) -join "`n"
        $ids = @([regex]::Matches($allContent, '(REQ|AC)-[A-Za-z0-9-]+', [Text.RegularExpressions.RegexOptions]::CultureInvariant) | ForEach-Object Value)
        if ($ids.Count -eq 0 -or @($ids | Where-Object { $_ -cnotmatch '^(REQ|AC)-[0-9]{3}$' }).Count -ne 0) { return $false }
        $reservedA = 'Fac' + 'et'; $reservedB = 'capab' + 'ility'
        if ($allContent.Contains($reservedA, [StringComparison]::OrdinalIgnoreCase) -or
            $allContent.Contains($reservedB, [StringComparison]::OrdinalIgnoreCase) -or
            @($artifacts.path | Where-Object { $_.Contains($reservedA, [StringComparison]::OrdinalIgnoreCase) -or $_.Contains($reservedB, [StringComparison]::OrdinalIgnoreCase) }).Count -ne 0) { return $false }
        return $true
    }
    catch { return $false }
    finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force } }
}

function Get-FixtureParameters([string]$State) {
    if ($State -ceq 'F1') {
        return [ordered]@{ ProjectContext='absent'; AgentsMarker='absent'; Enforcement='disabled-legacy'; Validity='valid'; TrackFlag='--full'; Track='full'; File='f1-full.json' }
    }
    return [ordered]@{ ProjectContext='absent'; AgentsMarker='present'; Enforcement='disabled-legacy'; Validity='valid'; TrackFlag='--lite'; Track='lite'; File='f2-lite.json' }
}

function New-Prompt([string]$State, [string]$TrackFlag, [string]$AgentsMarker) {
    $markerKey = 'capab' + 'ility_enforcement'
    return @"
Follow the sdd-bootstrap-interviewer workflow at $BootstrapSkill for a throwaway structural recording only.
The fixture is fixture_state=$State with project_context=absent, agents_marker=$AgentsMarker, ${markerKey}=disabled-legacy, and track_flag=$TrackFlag.
Do not write files. Generate the track's required specification artifacts structurally, including the shipped required headings, status-field names, and at least REQ-001 and AC-001 where identifiers belong.
Return only compact JSON with exactly one top-level key named artifacts. Its value must be an array of objects with exactly path and content string fields. Do not use Markdown fences or explanatory prose.
"@
}

function Invoke-Refresh([string]$State, [string]$Destination) {
    $p = Get-FixtureParameters $State
    $fixtureRoot = build_fixture $p.ProjectContext $p.AgentsMarker $p.Enforcement $p.Validity $p.TrackFlag
    $work = Join-Path ([IO.Path]::GetTempPath()) ('structural-live-refresh.' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $prompt = New-Prompt $State $p.TrackFlag $p.AgentsMarker
        Push-Location $fixtureRoot
        try {
            $global:LASTEXITCODE = 0
            $responseLines = & claude '-p' $prompt '--output-format' 'json'
            $invokeExit = $LASTEXITCODE
        } finally { Pop-Location }
        if ($invokeExit -ne 0) { throw "$State live invocation failed" }
        $outer = (($responseLines | Out-String) | ConvertFrom-Json)
        if ($outer.PSObject.Properties.Name -cnotcontains 'result' -or $outer.result -isnot [string] -or [string]::IsNullOrEmpty($outer.result)) { throw "$State live response has no final result text" }
        $payload = $outer.result | ConvertFrom-Json
        $payloadKeys = @($payload.PSObject.Properties.Name)
        if ($payloadKeys.Count -ne 1 -or $payloadKeys[0] -cne 'artifacts' -or $null -eq $payload.artifacts) { throw "$State result is not the artifacts payload" }
        foreach ($artifact in @($payload.artifacts)) {
            $keys = @($artifact.PSObject.Properties.Name | Sort-Object -CaseSensitive)
            if (($keys -join "`n") -cne "content`npath" -or $artifact.path -isnot [string] -or [string]::IsNullOrEmpty($artifact.path) -or $artifact.content -isnot [string]) {
                throw "$State result has a malformed artifact"
            }
        }
        $models = [Collections.Generic.List[string]]::new()
        if ($outer.PSObject.Properties.Name -ccontains 'model' -and $outer.model -is [string] -and -not [string]::IsNullOrEmpty($outer.model)) { $models.Add($outer.model) }
        if ($outer.PSObject.Properties.Name -ccontains 'modelUsage' -and $null -ne $outer.modelUsage) {
            foreach ($name in $outer.modelUsage.PSObject.Properties.Name) { if (-not [string]::IsNullOrEmpty($name)) { $models.Add($name) } }
        }
        $model = @($models | Sort-Object -CaseSensitive -Unique) -join ','
        if ([string]::IsNullOrEmpty($model)) { throw "$State response has no recording model identity" }
        $commit = ((& git -C $RepoRoot rev-parse HEAD) | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'could not resolve repository HEAD' }
        $candidate = [ordered]@{
            schema = $Schema
            fixture_state = $State
            recorded_at_model = $model
            recorded_at_commit = $commit
            refresh_procedure = $RefreshProcedure
            artifacts = @($payload.artifacts)
        }
        $candidatePath = Join-Path $work 'candidate.json'
        [IO.File]::WriteAllText($candidatePath, (($candidate | ConvertTo-Json -Depth 30) + "`n"), $Utf8NoBom)
        if (-not (Test-Candidate $candidatePath $State $p.Track)) { throw "$State candidate failed structural validation; corpus unchanged" }
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        $target = Join-Path $Destination $p.File
        $targetTemp = Join-Path $Destination ('.' + $p.File + '.' + [Guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllText($targetTemp, (($candidate | ConvertTo-Json -Depth 30) + "`n"), $Utf8NoBom)
        Move-Item -LiteralPath $targetTemp -Destination $target -Force
        if (-not $SelfTest) { [Console]::Out.WriteLine("PASS: $State live response validated before refresh: $target") }
    }
    catch {
        if (-not $script:SuppressRefreshFailure) { [Console]::Error.WriteLine("FAIL: $($_.Exception.Message)") }
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    }
    return $true
}

function Invoke-SelfTest {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ('structural-live-self-test.' + [Guid]::NewGuid().ToString('N'))
    $stubDir = Join-Path $testRoot 'bin'
    $scratch = Join-Path $testRoot 'corpus'
    New-Item -ItemType Directory -Path $stubDir, $scratch | Out-Null
    $stub = Join-Path $stubDir 'claude'
    $stubText = @'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 4 && $1 == -p && $3 == --output-format && $4 == json ]] || exit 64
prompt=$2
state=F1; file=f1-full.json
if [[ "$prompt" == *"fixture_state=F2"* ]]; then state=F2; file=f2-lite.json; fi
printf "%s\n%s\n%s\n" "$1" "$3" "$4" > "$STRUCTURAL_REFRESH_STUB_CAPTURE"
[[ "$prompt" == *"project_context=absent"* && "$prompt" == *"disabled-legacy"* ]] || exit 65
if [[ "$state" == F1 ]]; then [[ ! -e AGENTS.md && "$prompt" == *"track_flag=--full"* ]] || exit 66; else [[ -f AGENTS.md && "$prompt" == *"track_flag=--lite"* ]] || exit 67; fi
if [[ "${STRUCTURAL_REFRESH_STUB_CASE:-valid}" == missing-result ]]; then jq -cn '{modelUsage:{"claude-test":{}}}'; exit; fi
if [[ "${STRUCTURAL_REFRESH_STUB_CASE:-valid}" == bad-payload ]]; then jq -cn '{result:"{\"not_artifacts\":[]}",modelUsage:{"claude-test":{}}}'; exit; fi
payload="$(jq -c '{artifacts:.artifacts}' "$STRUCTURAL_REFRESH_STUB_CORPUS/$file")"
if [[ "${STRUCTURAL_REFRESH_STUB_CASE:-valid}" == bad-heading ]]; then payload="$(jq -c '.artifacts[0].content += "\n## Unexpected live heading\n"' <<<"$payload")"; fi
jq -cn --arg result "$payload" '{result:$result,modelUsage:{"claude-test":{}}}'
'@
    [IO.File]::WriteAllText($stub, $stubText, $Utf8NoBom)
    & chmod '+x' $stub

    $oldPath = $env:PATH
    $oldCorpus = $env:STRUCTURAL_REFRESH_STUB_CORPUS
    $oldCapture = $env:STRUCTURAL_REFRESH_STUB_CAPTURE
    $oldCase = $env:STRUCTURAL_REFRESH_STUB_CASE
    $env:PATH = $stubDir + [IO.Path]::PathSeparator + $oldPath
    $env:STRUCTURAL_REFRESH_STUB_CORPUS = $Corpus
    $capture = Join-Path $testRoot 'argv.txt'
    $env:STRUCTURAL_REFRESH_STUB_CAPTURE = $capture
    function Pass([string]$Label) { [Console]::Out.WriteLine("PASS: $Label") }
    function Fail([string]$Label) { [Console]::Error.WriteLine("FAIL: $Label"); $script:SelfTestFailed++ }
    $script:SelfTestFailed = 0
    try {
        $script:SuppressRefreshFailure = $true
        Copy-Item -LiteralPath (Join-Path $Corpus 'f1-full.json') -Destination (Join-Path $scratch 'f1-full.json')
        $before = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $scratch 'f1-full.json')).Hash
        $env:STRUCTURAL_REFRESH_STUB_CASE = 'bad-heading'
        $ok = Invoke-Refresh F1 $scratch
        $after = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $scratch 'f1-full.json')).Hash
        if ((-not $ok) -and $after -ceq $before) { Pass 'structurally invalid live response preserves an existing target' } else { Fail 'structurally invalid live response preserves an existing target' }

        Remove-Item -LiteralPath (Join-Path $scratch 'f1-full.json') -Force
        $ok = Invoke-Refresh F1 $scratch
        if ((-not $ok) -and -not (Test-Path -LiteralPath (Join-Path $scratch 'f1-full.json'))) { Pass 'structurally invalid live response preserves an absent target' } else { Fail 'structurally invalid live response preserves an absent target' }

        Remove-Item -LiteralPath (Join-Path $scratch 'f1-full.json') -Force -ErrorAction SilentlyContinue
        $env:STRUCTURAL_REFRESH_STUB_CASE = 'missing-result'
        $ok = Invoke-Refresh F1 $scratch
        if ((-not $ok) -and -not (Test-Path -LiteralPath (Join-Path $scratch 'f1-full.json'))) { Pass 'missing final result is rejected before write' } else { Fail 'missing final result is rejected before write' }

        $env:STRUCTURAL_REFRESH_STUB_CASE = 'bad-payload'
        $ok = Invoke-Refresh F1 $scratch
        if ((-not $ok) -and -not (Test-Path -LiteralPath (Join-Path $scratch 'f1-full.json'))) { Pass 'malformed final artifact payload is rejected before write' } else { Fail 'malformed final artifact payload is rejected before write' }

        $script:SuppressRefreshFailure = $false
        $env:STRUCTURAL_REFRESH_STUB_CASE = 'valid'
        $ok = Invoke-Refresh F1 $scratch
        if ($ok -and (Test-Candidate (Join-Path $scratch 'f1-full.json') F1 full)) { Pass 'valid F1 response refreshes a scratch target' } else { Fail 'valid F1 response refreshes a scratch target' }
        $ok = Invoke-Refresh F2 $scratch
        if ($ok -and (Test-Candidate (Join-Path $scratch 'f2-lite.json') F2 lite)) { Pass 'valid F2 response refreshes a scratch target' } else { Fail 'valid F2 response refreshes a scratch target' }
        $argv = Get-Content -LiteralPath $capture
        if ($argv[0] -ceq '-p' -and $argv[1] -ceq '--output-format' -and $argv[2] -ceq 'json') { Pass 'live invocation uses the exact argument contract' } else { Fail 'live invocation uses the exact argument contract' }

        $miscasedSkill = Join-Path $testRoot 'miscased-bootstrap-skill.md'
        [IO.File]::WriteAllText($miscasedSkill, ([IO.File]::ReadAllText($BootstrapSkill).Replace('## Required Outputs', '## required outputs', [StringComparison]::Ordinal)), $Utf8NoBom)
        if (@(Get-FullPaths $miscasedSkill).Count -eq 0) { Pass 'mis-cased required-output anchor is rejected' } else { Fail 'mis-cased required-output anchor is rejected' }

        $reservedA = 'Fac' + 'et'; $reservedB = 'capab' + 'ility'
        foreach ($mutation in @('schema','state','model','commit','refresh','path','frontmatter','heading','status','identifier','reserved-a','reserved-b')) {
            $copy = Get-Content -LiteralPath (Join-Path $Corpus 'f1-full.json') -Raw | ConvertFrom-Json
            switch -CaseSensitive ($mutation) {
                'schema' { $copy.schema = 'STRUCTURAL-FIXTURE-CORPUS/v1' }
                'state' { $copy.fixture_state = 'f1' }
                'model' { $copy.recorded_at_model = '' }
                'commit' { $copy.recorded_at_commit = 'ABC' }
                'refresh' { $copy.refresh_procedure = 'tests/other.sh' }
                'path' { $copy.artifacts[0].path = 'Requirements.md' }
                'frontmatter' { $copy.artifacts[0].content = "---`ntitle: broken`n" }
                'heading' { $copy.artifacts[0].content += "`n####### Broken`n" }
                'status' { ($copy.artifacts | Where-Object path -CEQ 'design.md').content = (($copy.artifacts | Where-Object path -CEQ 'design.md').content -creplace 'Impl-Review-Status','Impl-Review-State') }
                'identifier' { $copy.artifacts[0].content = $copy.artifacts[0].content.Replace('REQ-001','REQ-01',[StringComparison]::Ordinal) }
                'reserved-a' { $copy.artifacts[0].content += "`n$reservedA`n" }
                'reserved-b' { $copy.artifacts[0].content += "`n$reservedB`n" }
            }
            $mutationPath = Join-Path $testRoot "mutation-$mutation.json"
            [IO.File]::WriteAllText($mutationPath, (($copy | ConvertTo-Json -Depth 30) + "`n"), $Utf8NoBom)
            if (Test-Candidate $mutationPath F1 full) { Fail "validator rejects $mutation mismatch" } else { Pass "validator rejects $mutation mismatch" }
        }

        $registration = @(
            (Join-Path $RepoRoot 'tests/run-all.sh'),
            (Join-Path $RepoRoot 'tests/run-all.ps1'),
            (Join-Path $RepoRoot '.github/workflows/test.yml')
        ) | ForEach-Object { Get-Content -LiteralPath $_ -Raw }
        if (-not (($registration -join "`n").Contains('structural-compatibility-live-refresh', [StringComparison]::Ordinal))) { Pass 'live refresh remains outside aggregate runners and CI' } else { Fail 'live refresh remains outside aggregate runners and CI' }
    }
    finally {
        $script:SuppressRefreshFailure = $false
        $env:PATH = $oldPath
        $env:STRUCTURAL_REFRESH_STUB_CORPUS = $oldCorpus
        $env:STRUCTURAL_REFRESH_STUB_CAPTURE = $oldCapture
        $env:STRUCTURAL_REFRESH_STUB_CASE = $oldCase
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    [Console]::Out.WriteLine("$($script:SelfTestFailed) self-tests failed")
    return ($script:SelfTestFailed -eq 0)
}

if ($SelfTest) {
    if (-not (Invoke-SelfTest)) { exit 1 }
    exit 0
}

if (@('F1','F2','all') -cnotcontains $Fixture) {
    [Console]::Error.WriteLine('Fixture must be exactly F1, F2, or all.')
    exit 2
}
$states = if ($Fixture -ceq 'all') { @('F1','F2') } else { @($Fixture) }
$success = $true
foreach ($state in $states) { if (-not (Invoke-Refresh $state $TargetDir)) { $success = $false } }
if (-not $success) { exit 1 }
