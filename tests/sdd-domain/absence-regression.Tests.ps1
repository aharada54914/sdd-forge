#
# T-007 absence-regression -- AC-010 absent-domain regression guard
#
# AC-010: "With no domain/ directory, all sdd-domain hooks, sync steps, and
# gates are skipped, recording a single skip line; existing workflows
# produce byte-identical artifacts."
#
# The bootstrap skill is an instruction document, not an executable program.
# Its absent-domain contract is checked below, while both executable domain
# conformance gates are run against real temporary input files. The tests do
# not infer runtime behavior from the shape of a historical Git diff.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSkillRelativePath = "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
$bootstrapSkillPath = Join-Path $repositoryRoot $bootstrapSkillRelativePath
$domainSyncSkillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-sync/SKILL.md"
$shellGatePath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-domain-conformance.sh"
$powerShellGatePath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-domain-conformance.ps1"

Describe "AC-010: domain-sync single-skip-line contract (documented, cross-checked against the bootstrap edit)" {

    BeforeAll {
        $script:bootstrapText = Get-Content -Raw -Encoding UTF8 -LiteralPath $bootstrapSkillPath
        $script:domainSyncText = Get-Content -Raw -Encoding UTF8 -LiteralPath $domainSyncSkillPath
    }

    It "the inserted bootstrap step documents proceeding exactly as if domain/ were absent on skip/warning" {
        $script:bootstrapText | Should Match "proceed exactly as if\s*``domain/``\s*were absent"
    }

    It "the inserted bootstrap step explicitly claims no other change to Phase 1 flow" {
        $script:bootstrapText | Should Match "no other change to this flow"
    }

    It "the inserted bootstrap step cites AC-010 directly" {
        $script:bootstrapText | Should Match "AC-010"
    }

    It "domain-sync documents exactly one skip line for the absent-domain/ case" {
        ($script:domainSyncText | Select-String -Pattern "domain-sync skipped: no domain/ directory" -AllMatches).Matches.Count | Should Be 1
    }

    It "domain-sync's detection logic runs its checks in order and stops at the first failing check (no double-skip)" {
        $script:domainSyncText | Should Match "The first\s*check that fails ends the run"
    }
}

Describe "AC-010: executable domain gates preserve absent-domain inputs" {

    BeforeAll {
        $script:shellCommand = Get-Command sh -ErrorAction SilentlyContinue
        if ($null -eq $script:shellCommand) {
            $script:shellCommand = Get-Command bash -ErrorAction SilentlyContinue
        }
        $script:powerShellCommand = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }
        $script:fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t007-absence-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $script:fixtureDir -Force | Out-Null
        $script:requirementsPath = Join-Path $script:fixtureDir "requirements.md"
        $script:designPath = Join-Path $script:fixtureDir "design.md"
        [IO.File]::WriteAllText($script:requirementsPath, "# Requirements`nBounded-Context: absent-context`n")
        [IO.File]::WriteAllText($script:designPath, "# Design`n[Missing](domain/aggregates/Missing.md)`n")
        $script:requirementsHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $script:requirementsPath).Hash
        $script:designHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $script:designPath).Hash
        $script:expectedFiles = @($script:requirementsPath, $script:designPath | Sort-Object)
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureDir) {
            Remove-Item -LiteralPath $script:fixtureDir -Recurse -Force
        }
    }

    It "the fixture project genuinely has no domain/ directory" {
        Test-Path -LiteralPath (Join-Path $script:fixtureDir "domain") | Should Be $false
    }

    It "the shell gate emits one skip line, exits zero, and preserves artifact bytes" {
        if ($null -eq $script:shellCommand) {
            Set-TestInconclusive "shell gate not executable: neither sh nor bash is available"
        }
        $output = @(& $script:shellCommand.Source $shellGatePath $script:fixtureDir $script:requirementsPath $script:designPath 2>&1)
        $LASTEXITCODE | Should Be 0
        $output.Count | Should Be 1
        $output[0] | Should Be "check-domain-conformance skipped: no domain/ directory."
        (Get-FileHash -Algorithm SHA256 -LiteralPath $script:requirementsPath).Hash | Should Be $script:requirementsHash
        (Get-FileHash -Algorithm SHA256 -LiteralPath $script:designPath).Hash | Should Be $script:designHash
        @(Get-ChildItem -LiteralPath $script:fixtureDir -Recurse -File -Force | ForEach-Object FullName | Sort-Object) | Should Be $script:expectedFiles
    }

    It "the PowerShell gate emits one skip line, exits zero, and preserves artifact bytes" {
        $output = @(& $script:powerShellCommand -NoProfile -File $powerShellGatePath -ProjectRoot $script:fixtureDir -RequirementsMd $script:requirementsPath -DesignMd $script:designPath 2>&1)
        $LASTEXITCODE | Should Be 0
        $output.Count | Should Be 1
        $output[0] | Should Be "check-domain-conformance skipped: no domain/ directory."
        (Get-FileHash -Algorithm SHA256 -LiteralPath $script:requirementsPath).Hash | Should Be $script:requirementsHash
        (Get-FileHash -Algorithm SHA256 -LiteralPath $script:designPath).Hash | Should Be $script:designHash
        @(Get-ChildItem -LiteralPath $script:fixtureDir -Recurse -File -Force | ForEach-Object FullName | Sort-Object) | Should Be $script:expectedFiles
    }

    It "rejects a hidden unexpected artifact in the output inventory" {
        $hiddenPath = Join-Path $script:fixtureDir ".unexpected-artifact"
        try {
            [IO.File]::WriteAllText($hiddenPath, "unexpected")
            if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
                [IO.File]::SetAttributes($hiddenPath, [IO.FileAttributes]::Hidden)
            }
            @(Get-ChildItem -LiteralPath $script:fixtureDir -Recurse -File -Force |
                ForEach-Object FullName) | Should Contain $hiddenPath
            {
                @(Get-ChildItem -LiteralPath $script:fixtureDir -Recurse -File -Force |
                    ForEach-Object FullName | Sort-Object) | Should Be $script:expectedFiles
            } | Should Throw
        } finally {
            Remove-Item -LiteralPath $hiddenPath -Force -ErrorAction SilentlyContinue
        }
    }
}
