# No-domain regression: exercise the production gate and preserve existing bytes.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gate = Join-Path $repositoryRoot 'plugins/sdd-domain/scripts/validate-concept-test.ps1'
$bootstrap = Join-Path $repositoryRoot 'plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md'
$sync = Join-Path $repositoryRoot 'plugins/sdd-domain/skills/domain-sync/SKILL.md'
$powerShellHost = (Get-Process -Id $PID).Path

Describe 'No-domain bootstrap preserves the documented skip branch' {
    It 'delegates Concept Test and synchronization only on the domain-present branch before risk selection' {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $bootstrap
        $line = @($text -split '\r?\n' | Where-Object { $_ -cmatch '`concept-test`' })
        $line.Count | Should Be 1
        $line[0] | Should Match '`domain/`.*存在する場合のみ.*`concept-test`.*`domain-sync`.*domain-sync skipped: no domain/ directory'
        $text.IndexOf($line[0]) | Should BeLessThan $text.IndexOf('2. **タスク単位のリスク判定')
    }

    It 'domain sync records one skip line and stops at its first failed check' {
        $text = Get-Content -Raw -LiteralPath $sync
        ($text | Select-String -Pattern 'domain-sync skipped: no domain/ directory' -AllMatches).Matches.Count | Should Be 1
        $text | Should Match '(?m)^1\. .*`domain/`.*domain-sync skipped: no domain/ directory.*終了'
        $text | Should Match '最初の不一致で 1 行記録して終了'
    }
}

Describe 'Production Concept Test gate with no domain directory' {
    BeforeEach {
        $script:fixture = Join-Path ([IO.Path]::GetTempPath()) ('concept-absence-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:fixture 'specs/example') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $script:fixture 'specs/example/requirements.md'), "existing request`n")
    }
    AfterEach {
        Remove-Item -LiteralPath $script:fixture -Recurse -Force
    }

    It 'returns SKIP without modifying or creating any artifact' {
        $before = @(Get-ChildItem -LiteralPath $script:fixture -File -Recurse | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash }) -join ','
        $output = & $powerShellHost -NoProfile -File $gate --root $script:fixture --feature example
        $LASTEXITCODE | Should Be 0
        ($output -join "`n") | Should Be 'SKIP'
        $after = @(Get-ChildItem -LiteralPath $script:fixture -File -Recurse | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash }) -join ','
        $after | Should Be $before
        Test-Path -LiteralPath (Join-Path $script:fixture 'domain') | Should Be $false
    }

    It 'does not read or execute feature text on the absent-domain branch' {
        $seed = Join-Path $script:fixture 'specs/example/concept-test-seed.md'
        [IO.File]::WriteAllText($seed, '$(touch SHOULD_NOT_EXIST)')
        $before = (Get-FileHash -LiteralPath $seed).Hash
        $output = & $powerShellHost -NoProfile -File $gate --root $script:fixture --feature example
        $LASTEXITCODE | Should Be 0
        ($output -join "`n") | Should Be 'SKIP'
        (Get-FileHash -LiteralPath $seed).Hash | Should Be $before
        Test-Path -LiteralPath (Join-Path $script:fixture 'SHOULD_NOT_EXIST') | Should Be $false
    }
}
