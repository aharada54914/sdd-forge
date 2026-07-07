#
# T-008 check-domain-conformance -- acceptance-first Pester test
#
# Required Workflow for T-008 is "acceptance-first" (Risk: medium).
# check-domain-conformance is a deterministic scripted gate (unlike T-002's
# domain-interviewer or T-007's domain-sync, which are agent-driven), so
# this suite executes the real script (plugins/sdd-quality-loop/scripts/
# check-domain-conformance.ps1) against real, on-disk constructed fixtures --
# never a simulation of the script's behavior.
#
# Per specs/sdd-domain/tasks.md T-008 Done-When, this suite proves:
#   1. conformant fixture -> 0 findings, exit 0
#   2. deviant-term fixture (unrecognized Bounded-Context) -> warn finding, exit 0
#   3. deviant-term fixture with SDD_DOMAIN_ENFORCE=error -> exit 1
#   4. two-context fixture with a declared relation -> pass
#   5. two-context fixture with an undeclared relation -> warn
#   6. no domain/ -> skip, exit 0
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$checkPs1 = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-domain-conformance.ps1"
$skillPath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"

function New-DomainFixture {
    param(
        [Parameter(Mandatory)][string]$FixtureRoot,
        [string[]]$ContextNames = @("order-management"),
        [array]$Relations = @(),
        [switch]$WithAggregateCard
    )

    $domainDir = Join-Path $FixtureRoot "domain"
    $aggDir = Join-Path $domainDir "aggregates"
    $specsDir = Join-Path $FixtureRoot "specs/demo"
    New-Item -ItemType Directory -Path $aggDir -Force | Out-Null
    New-Item -ItemType Directory -Path $specsDir -Force | Out-Null

    $contexts = @()
    foreach ($name in $ContextNames) {
        $aggregates = @()
        if ($WithAggregateCard -and $name -eq $ContextNames[0]) {
            $aggregates = @(
                @{
                    name = "Order"
                    root_entity = "Order"
                    invariants = @("Total must be positive")
                    transaction_boundary = "one order per transaction"
                    card = "domain/aggregates/Order.md"
                }
            )
        }
        $contexts += @{
            name = $name
            description = "Fixture context $name."
            terms = @(
                @{ canonical = "Order"; definition = "A customer purchase request." }
            )
            aggregates = $aggregates
        }
    }

    $contract = @{
        schema = "domain-contract/v1"
        meta = @{
            version = "1.0.0"
            status = "Approved"
            generated_from = @("domain/context-map.md")
        }
        contexts = $contexts
        relations = $Relations
    }
    $contractJson = $contract | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath (Join-Path $domainDir "domain-contract.json") -Encoding UTF8 -Value $contractJson

    if ($WithAggregateCard) {
        Set-Content -LiteralPath (Join-Path $aggDir "Order.md") -Encoding UTF8 -Value "# Order`n`nAggregate card."
    }

    return @{
        FixtureRoot = $FixtureRoot
        SpecsDir = $specsDir
    }
}

function Invoke-CheckDomainConformance {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [string]$RequirementsMd = "",
        [string]$DesignMd = "",
        [switch]$Enforce
    )
    $envBackup = $env:SDD_DOMAIN_ENFORCE
    # Local-scope only: an external process's stderr, redirected via 2>&1,
    # is wrapped as an ErrorRecord: under the file-level
    # $ErrorActionPreference = "Stop" that becomes a terminating error and
    # aborts this function before $LASTEXITCODE can be read (bad-invocation
    # fixtures deliberately write to stderr via Write-Error). Relax to
    # Continue for the scope of the external call only.
    $ErrorActionPreference = "Continue"
    try {
        if ($Enforce) { $env:SDD_DOMAIN_ENFORCE = "error" } else { Remove-Item Env:SDD_DOMAIN_ENFORCE -ErrorAction SilentlyContinue }
        $argList = @("-ProjectRoot", $ProjectRoot)
        if ($RequirementsMd -ne "") { $argList += @("-RequirementsMd", $RequirementsMd) }
        if ($DesignMd -ne "") { $argList += @("-DesignMd", $DesignMd) }
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checkPs1 @argList 2>&1 | Out-String
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
    } finally {
        if ($null -ne $envBackup) { $env:SDD_DOMAIN_ENFORCE = $envBackup } else { Remove-Item Env:SDD_DOMAIN_ENFORCE -ErrorAction SilentlyContinue }
    }
}

Describe "check-domain-conformance script exists and matches check-design-system conventions" {
    It "both script twins exist" {
        Test-Path -LiteralPath $checkPs1 | Should Be $true
        $shPath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-domain-conformance.sh"
        Test-Path -LiteralPath $shPath | Should Be $true
    }

    It "quality-gate SKILL.md registers check-domain-conformance immediately after check-design-system" {
        $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
        $designSystemIndex = $skillText.IndexOf("check-design-system")
        $domainConformanceIndex = $skillText.IndexOf("check-domain-conformance")
        $workflowStateIndex = $skillText.IndexOf("check-workflow-state")

        $designSystemIndex | Should Not Be -1
        $domainConformanceIndex | Should Not Be -1
        $workflowStateIndex | Should Not Be -1
        ($domainConformanceIndex -gt $designSystemIndex) | Should Be $true
        ($domainConformanceIndex -lt $workflowStateIndex) | Should Be $true
    }
}

Describe "TEST-009 / TEST-015: check-domain-conformance real script execution against fixtures" {

    BeforeAll {
        $script:tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t008-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $script:tmpRoot -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:tmpRoot) {
            Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force
        }
    }

    Context "Scenario 1: conformant fixture -> 0 findings, exit 0" {
        BeforeAll {
            $script:root = Join-Path $script:tmpRoot "conformant"
            $fixture = New-DomainFixture -FixtureRoot $script:root -ContextNames @("order-management") -WithAggregateCard
            Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: demo

Spec-Review-Status: Passed
Bounded-Context: order-management

## Overview

Test feature.
'@
            Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "design.md") -Encoding UTF8 -Value @'
# Design: demo

References [Order](../../domain/aggregates/Order.md) for invariants.
'@
        }

        It "exits 0 with no findings" {
            $result = Invoke-CheckDomainConformance -ProjectRoot $script:root `
                -RequirementsMd (Join-Path $script:root "specs/demo/requirements.md") `
                -DesignMd (Join-Path $script:root "specs/demo/design.md")
            $result.ExitCode | Should Be 0
            $result.Output | Should Match "check-domain-conformance passed\."
        }
    }

    Context "Scenario 2: deviant-term fixture -> warn finding, exit 0" {
        BeforeAll {
            $script:root = Join-Path $script:tmpRoot "deviant"
            $fixture = New-DomainFixture -FixtureRoot $script:root -ContextNames @("order-management")
            Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: demo

Spec-Review-Status: Passed
Bounded-Context: nonexistent-context

## Overview

Test feature.
'@
        }

        It "exits 0 and reports a WARN finding naming the unrecognized context" {
            $result = Invoke-CheckDomainConformance -ProjectRoot $script:root `
                -RequirementsMd (Join-Path $script:root "specs/demo/requirements.md")
            $result.ExitCode | Should Be 0
            $result.Output | Should Match "check-domain-conformance WARN"
            $result.Output | Should Match "nonexistent-context"
        }
    }

    Context "Scenario 3: deviant-term fixture with SDD_DOMAIN_ENFORCE=error -> exit 1" {
        BeforeAll {
            $script:root = Join-Path $script:tmpRoot "deviant-enforce"
            $fixture = New-DomainFixture -FixtureRoot $script:root -ContextNames @("order-management")
            Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: demo

Spec-Review-Status: Passed
Bounded-Context: nonexistent-context

## Overview

Test feature.
'@
        }

        It "exits 1 and reports FAILED when SDD_DOMAIN_ENFORCE=error" {
            $result = Invoke-CheckDomainConformance -ProjectRoot $script:root `
                -RequirementsMd (Join-Path $script:root "specs/demo/requirements.md") -Enforce
            $result.ExitCode | Should Be 1
            $result.Output | Should Match "check-domain-conformance FAILED"
            $result.Output | Should Match "nonexistent-context"
        }
    }

    Context "Scenario 4: two-context fixture with a declared relation -> pass" {
        BeforeAll {
            $script:root = Join-Path $script:tmpRoot "twoctx-declared"
            $fixture = New-DomainFixture -FixtureRoot $script:root -ContextNames @("order-management", "billing") -Relations @(
                @{ from = "order-management"; to = "billing"; pattern = "customer-supplier" }
            )
            Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: demo

Spec-Review-Status: Passed
Bounded-Context: order-management, billing

## Overview

Test feature spanning two contexts.
'@
        }

        It "exits 0 with no findings when the relation is declared (AC-015)" {
            $result = Invoke-CheckDomainConformance -ProjectRoot $script:root `
                -RequirementsMd (Join-Path $script:root "specs/demo/requirements.md")
            $result.ExitCode | Should Be 0
            $result.Output | Should Match "check-domain-conformance passed\."
        }
    }

    Context "Scenario 5: two-context fixture with an undeclared relation -> warn" {
        BeforeAll {
            $script:root = Join-Path $script:tmpRoot "twoctx-undeclared"
            $fixture = New-DomainFixture -FixtureRoot $script:root -ContextNames @("order-management", "billing") -Relations @()
            Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: demo

Spec-Review-Status: Passed
Bounded-Context: order-management, billing

## Overview

Test feature spanning two contexts.
'@
        }

        It "exits 0 but reports a WARN finding when no relation is declared (AC-015)" {
            $result = Invoke-CheckDomainConformance -ProjectRoot $script:root `
                -RequirementsMd (Join-Path $script:root "specs/demo/requirements.md")
            $result.ExitCode | Should Be 0
            $result.Output | Should Match "check-domain-conformance WARN"
            $result.Output | Should Match "no declared relation"
        }
    }

    Context "Scenario 6: no domain/ -> skip, exit 0" {
        BeforeAll {
            $script:root = Join-Path $script:tmpRoot "no-domain"
            New-Item -ItemType Directory -Path (Join-Path $script:root "specs/demo") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:root "specs/demo/requirements.md") -Encoding UTF8 -Value "# Requirements: demo`n`nBounded-Context: order-management`n"
        }

        It "exits 0 with exactly one skip line when domain/ is absent" {
            (Test-Path -LiteralPath (Join-Path $script:root "domain")) | Should Be $false
            $result = Invoke-CheckDomainConformance -ProjectRoot $script:root `
                -RequirementsMd (Join-Path $script:root "specs/demo/requirements.md")
            $result.ExitCode | Should Be 0
            $result.Output | Should Match "check-domain-conformance skipped: no domain/ directory\."
        }
    }

    Context "Bad invocation" {
        It "exits 1 when the project root does not exist" {
            $badRoot = Join-Path $script:tmpRoot "does-not-exist-at-all"
            $result = Invoke-CheckDomainConformance -ProjectRoot $badRoot
            $result.ExitCode | Should Be 1
        }
    }
}

Describe "check-domain-conformance.sh (bash twin) parity via WSL/Git-Bash if available" {
    BeforeAll {
        $script:bashPath = (Get-Command "bash.exe" -ErrorAction SilentlyContinue)
        if ($null -eq $script:bashPath) { $script:bashPath = (Get-Command "sh.exe" -ErrorAction SilentlyContinue) }
        $script:root = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t008-sh-" + [Guid]::NewGuid().ToString("N"))
        $fixture = New-DomainFixture -FixtureRoot $script:root -ContextNames @("order-management") -WithAggregateCard
        Set-Content -LiteralPath (Join-Path $fixture.SpecsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: demo

Spec-Review-Status: Passed
Bounded-Context: order-management

## Overview

Test feature.
'@
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:root) { Remove-Item -LiteralPath $script:root -Recurse -Force }
    }

    It "the bash twin passes the conformant fixture when a bash/sh interpreter is available" {
        if ($null -eq $script:bashPath) {
            Write-Host "skipping bash-twin parity check: no bash.exe/sh.exe found on PATH"
            return
        }
        $shScript = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-domain-conformance.sh"
        $reqMd = Join-Path $script:root "specs/demo/requirements.md"
        $output = & $script:bashPath.Source $shScript $script:root $reqMd 2>&1 | Out-String
        $LASTEXITCODE | Should Be 0
        $output | Should Match "check-domain-conformance passed\."
    }
}
