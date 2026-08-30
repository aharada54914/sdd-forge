param(
    [ValidateSet('all', 'dependency-present', 'unknown-skip', 'fingerprint-drift', 'clean', 'primitives', 'manifest-contract')]
    [string]$Case = 'all'
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Evaluator = if ($env:T010_EVALUATOR_UNDER_TEST) { $env:T010_EVALUATOR_UNDER_TEST } else { Join-Path $Root 'tests/lib/skip-allowlist-evaluator.ps1' }
$ShippedManifest = Join-Path $Root 'tests/fixtures/skip-allowlist-manifest.json'
$Work = Join-Path ([System.IO.Path]::GetTempPath()) ("skip-allowlist-{0}" -f [guid]::NewGuid().ToString('N'))
$SkipPrefix = 'SK' + 'IP:'
$script:Pass = 0
$script:Fail = 0
$script:FixtureSeq = 0
New-Item -ItemType Directory -Path $Work | Out-Null

function Pass([string]$Message) { Write-Output "PASS: $Message"; $script:Pass++ }
function Fail([string]$Message) { [Console]::Error.WriteLine("FAIL: $Message"); $script:Fail++ }
function Invoke-Git([string]$Repo, [string[]]$Arguments) {
    & git -C $Repo @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($Arguments -join ' ')" }
}
function Invoke-Evaluator([string[]]$Arguments) {
    if ($env:T010_PERMISSIVE_EVALUATOR -eq '1') { return 0 }
    & pwsh -NoLogo -NoProfile -File $Evaluator @Arguments
    return $LASTEXITCODE
}
function Get-Sha256Text([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

function New-Fixture([string]$State) {
    $script:FixtureSeq++
    $fixtureRoot = Join-Path $Work "$State-$($script:FixtureSeq)"
    $repo = Join-Path $fixtureRoot 'repo'
    $manifest = Join-Path $fixtureRoot 'manifest.json'
    $output = Join-Path $fixtureRoot 'output.log'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    Invoke-Git $repo @('init', '-q', '-b', 'main')
    Invoke-Git $repo @('config', 'user.name', 'T-010 fixture')
    Invoke-Git $repo @('config', 'user.email', 't010-fixture@example.invalid')
    Set-Content -LiteralPath (Join-Path $repo 'README.md') -Value 'base' -Encoding utf8NoBOM
    Invoke-Git $repo @('add', 'README.md')
    Invoke-Git $repo @('commit', '-q', '-m', 'base')
    Invoke-Git $repo @('switch', '-q', '-c', 'feature/epic-999-fixture')
    $specDir = Join-Path $repo 'specs/epic-999-fixture'
    New-Item -ItemType Directory -Path $specDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $specDir 'requirements.md'), "---`nSpec-Review-Status: Passed`n---`n`ncontract-v1`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $specDir 'design.md'), "---`nImpl-Review-Status: Passed`n---`n", [Text.UTF8Encoding]::new($false))
    Invoke-Git $repo @('add', 'specs/epic-999-fixture/requirements.md', 'specs/epic-999-fixture/design.md')
    Invoke-Git $repo @('commit', '-q', '-m', 'fixture epic terminal')
    $fixtureManifest = @(
        [ordered]@{
            assertion_id = 'AC-900'
            dependencies = @([ordered]@{
                epic = 'A9'; issue = 999
                fingerprints = @([ordered]@{
                    source = 'specs/epic-999-fixture/requirements.md'; line_range = '5-5'; algorithm = 'sha256'
                    normalization = "lf-normalized, utf-8, lines joined by a single \n, no trailing newline"
                    digest = "sha256:$(Get-Sha256Text 'contract-v1')"; quote = 'contract-v1'
                })
            })
            activation_condition = 'merged(A9)'
        }
    )
    [IO.File]::WriteAllText($manifest, ($fixtureManifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    if ($State -ne 'unmerged') {
        Invoke-Git $repo @('switch', '-q', 'main')
        Invoke-Git $repo @('merge', '-q', '--no-ff', 'feature/epic-999-fixture', '-m', 'merge fixture epic')
    }
    if ($State -eq 'merged-fingerprint-mismatch') {
        [IO.File]::WriteAllText((Join-Path $specDir 'requirements.md'), "---`nSpec-Review-Status: Passed`n---`n`ncontract-v2`n", [Text.UTF8Encoding]::new($false))
        Invoke-Git $repo @('add', 'specs/epic-999-fixture/requirements.md')
        Invoke-Git $repo @('commit', '-q', '-m', 'drift fixture contract')
    }
    return @{ Repo = $repo; Manifest = $manifest; Output = $output }
}

function Assert-HardFail([string]$Label, [hashtable]$Fixture) {
    $rc = Invoke-Evaluator @('audit', $Fixture.Manifest, $Fixture.Output, $Fixture.Repo, 'main')
    if ($rc -eq 0) { Fail $Label } else { Pass $Label }
}
function Test-DependencyPresent {
    $fixture = New-Fixture 'merged-fingerprint-match'
    [IO.File]::WriteAllText($fixture.Output, "$SkipPrefix TEST-FIXTURE/AC-900: dependency should activate`n", [Text.UTF8Encoding]::new($false))
    Assert-HardFail 'AC-035a dependency-present output is a hard failure' $fixture
}
function Test-UnknownSkip {
    $fixture = New-Fixture 'unmerged'
    [IO.File]::WriteAllText($fixture.Output, "$SkipPrefix TEST-FIXTURE/AC-999: no manifest entry`n", [Text.UTF8Encoding]::new($false))
    Assert-HardFail 'AC-035b unrecognized output is a hard failure' $fixture
}
function Test-FingerprintDrift {
    $fixture = New-Fixture 'merged-fingerprint-mismatch'
    [IO.File]::WriteAllText($fixture.Output, "$SkipPrefix TEST-FIXTURE/AC-900: merged contract drifted`n", [Text.UTF8Encoding]::new($false))
    Assert-HardFail 'AC-035c merged fingerprint drift is a hard failure' $fixture
}
function Test-Clean {
    $fixture = New-Fixture 'unmerged'
    [IO.File]::WriteAllText($fixture.Output, "PASS: ordinary assertion ran`n$SkipPrefix TEST-FIXTURE/AC-900: dependency is not merged`n", [Text.UTF8Encoding]::new($false))
    $captured = & pwsh -NoLogo -NoProfile -File $Evaluator audit $fixture.Manifest $fixture.Output $fixture.Repo main 2>&1
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and ($captured -join "`n") -like '*audited 1 allowlisted line*') { Pass 'clean fixture audits one real allowlisted line without failing vacuously' }
    else { Fail "clean fixture is accepted with a non-vacuous audit ($($captured -join '; '))" }
}
function Test-Primitives {
    $fixture = New-Fixture 'unmerged'
    if ((Invoke-Evaluator @('merged', $fixture.Manifest, 'AC-900', 'A9', $fixture.Repo, 'main')) -ne 0) { Pass 'merged(A9) is false before branch ancestry reaches main' } else { Fail 'merged(A9) is false before branch ancestry reaches main' }
    if ((Invoke-Evaluator @('fingerprint-match', $fixture.Manifest, 'AC-900', '0', $fixture.Repo, 'main')) -eq 0) { Pass 'fingerprint_match(0) matches the unmerged epic current HEAD' } else { Fail 'fingerprint_match(0) matches the unmerged epic current HEAD' }
    $fixture = New-Fixture 'merged-fingerprint-match'
    if ((Invoke-Evaluator @('merged', $fixture.Manifest, 'AC-900', 'A9', $fixture.Repo, 'main')) -eq 0 -and (Invoke-Evaluator @('fingerprint-match', $fixture.Manifest, 'AC-900', '0', $fixture.Repo, 'main')) -eq 0) { Pass 'merged fingerprint-match fixture makes both primitives true' } else { Fail 'merged fingerprint-match fixture makes both primitives true' }
    $fixture = New-Fixture 'merged-fingerprint-mismatch'
    if ((Invoke-Evaluator @('merged', $fixture.Manifest, 'AC-900', 'A9', $fixture.Repo, 'main')) -eq 0 -and (Invoke-Evaluator @('fingerprint-match', $fixture.Manifest, 'AC-900', '0', $fixture.Repo, 'main')) -ne 0) { Pass 'merged fingerprint-mismatch fixture keeps merged true and fingerprint_match false' } else { Fail 'merged fingerprint-mismatch fixture keeps merged true and fingerprint_match false' }
    $fixture = New-Fixture 'unmerged'
    $document = @(Get-Content -Raw -LiteralPath $fixture.Manifest | ConvertFrom-Json)
    $document[0].activation_condition = 'merged(A9) OR fingerprint_match(0)'
    $conditionManifest = Join-Path $Work 'condition.json'
    [IO.File]::WriteAllText($conditionManifest, ($document | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    if ((Invoke-Evaluator @('condition', $conditionManifest, 'AC-900', $fixture.Repo, 'main')) -eq 0) { Pass 'OR accepts one true primitive' } else { Fail 'OR accepts one true primitive' }
    $document[0].activation_condition = 'merged(A9) AND fingerprint_match(0)'
    [IO.File]::WriteAllText($conditionManifest, ($document | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    if ((Invoke-Evaluator @('condition', $conditionManifest, 'AC-900', $fixture.Repo, 'main')) -ne 0) { Pass 'AND rejects one false primitive' } else { Fail 'AND rejects one false primitive' }
}
function Test-ManifestContract {
    if (-not (Test-Path -LiteralPath $ShippedManifest)) { Fail 'AC-034 shipped manifest exists'; return }
    $manifest = @(Get-Content -Raw -LiteralPath $ShippedManifest | ConvertFrom-Json)
    $expectedIds = @('AC-004', 'AC-007', 'AC-021', 'AC-042', 'AC-043')
    $expectedDigests = @(
        'sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff',
        'sha256:b84bd60bfba1bc9741bb76096d0502a461343c6867efcaa4bc57986b02d11157',
        'sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a',
        'sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff',
        'sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a',
        'sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a',
        'sha256:185d9e88b4ef19fd86d4993dabc6446f5e1b2e5dc9a84b3bacbb81f823f25134'
    )
    $actualIds = @($manifest | ForEach-Object assertion_id)
    $actualDigests = @($manifest | ForEach-Object { $_.dependencies | ForEach-Object { $_.fingerprints | ForEach-Object digest } })
    $validShape = $manifest.Count -eq 5 -and (@(Compare-Object $expectedIds $actualIds).Count -eq 0) -and (@(Compare-Object $expectedDigests $actualDigests).Count -eq 0)
    if (-not $validShape) { Fail 'AC-034 manifest contains exactly the five fixed entries and fingerprint values'; return }
    Pass 'AC-034 manifest contains exactly the five fixed entries and fingerprint values'
    $suiteFiles = @('loop-consistency.tests.sh', 'loop-escalation.tests.sh', 'compatibility-byte-identical.tests.sh', 'structural-compatibility.tests.sh')
    $source = ($suiteFiles | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $Root "tests/$_") }) -join "`n"
    foreach ($assertion in $expectedIds) {
        if ($source -notmatch "skip_allowlist_line[^`n]*$assertion") { Fail "AC-016 $assertion output is not sourced through skip_allowlist_line"; return }
    }
    Pass 'AC-016 all five fixed SKIP assertions read from the manifest helper'
}

try {
    switch ($Case) {
        'dependency-present' { Test-DependencyPresent }
        'unknown-skip' { Test-UnknownSkip }
        'fingerprint-drift' { Test-FingerprintDrift }
        'clean' { Test-Clean }
        'primitives' { Test-Primitives }
        'manifest-contract' { Test-ManifestContract }
        'all' { Test-ManifestContract; Test-Primitives; Test-DependencyPresent; Test-UnknownSkip; Test-FingerprintDrift; Test-Clean }
    }
    Write-Output "$script:Pass passed, $script:Fail failed"
    if ($script:Fail -ne 0) { exit 1 }
}
finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
