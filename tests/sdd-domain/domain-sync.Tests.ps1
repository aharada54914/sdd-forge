#
# T-007 domain-sync -- acceptance-first Pester test
#
# Required Workflow for T-007 is "acceptance-first" (Risk: medium). Like
# T-002's domain-interviewer and T-003's domain-reverse, domain-sync's actual
# injection logic is agent-driven (an LLM matches a feature's requirement
# text against domain-contract.json's contexts, composes a Bounded-Context
# field, and adds aggregate cross-references to design.md) -- there is no
# deterministic script to execute for that judgment step. Following the
# pattern established by tests/sdd-domain/artifact-set.Tests.ps1 (T-002) and
# tests/sdd-domain/reverse-seed.Tests.ps1 (T-003), this file validates:
#
#   1. Structural contract tests against domain-sync/SKILL.md: the detection
#      order (domain/ existence, Domain-Model-Status, contract validation),
#      the exact single-skip-line / single-warning-line contract, and the
#      injection contract (Bounded-Context field format, two-context
#      relation-pattern suffix, aggregate cross-references).
#   2. A worked fixture (executed for real): a fixture project with an
#      Approved domain/ model (context-map.md + domain-contract.json,
#      re-using the same widget-catalog / order-management shape as T-002's
#      fixture for consistency) produces a requirements.md whose
#      Bounded-Context: field names a context that is actually present in
#      domain-contract.json -- validated by parsing the fixture contract
#      for real and cross-checking the field value against it.
#   3. A two-context worked fixture exercising the Edge Case: two contexts
#      plus the declared relation pattern.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-sync/SKILL.md"
$bootstrapSkillPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
$schemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v1.schema.json"

# Set-StrictMode -Version Latest throws on a missing property access for a
# PSCustomObject (unlike a hashtable). Fixtures round-trip through
# ConvertTo-Json/ConvertFrom-Json into PSCustomObject, so every field read
# goes through this safe accessor. Copied from
# tests/sdd-domain/contract-schema.Tests.ps1 / artifact-set.Tests.ps1 to
# keep the same validation approach for the same schema.
function Get-PropSafe {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Test-DomainContract {
    param([Parameter(Mandatory)]$Contract)

    $errors = New-Object System.Collections.Generic.List[string]

    $schemaValue = Get-PropSafe $Contract "schema"
    if ($null -eq $schemaValue -or $schemaValue -ne "domain-contract/v1") {
        $errors.Add("schema const must equal 'domain-contract/v1'")
    }

    $meta = Get-PropSafe $Contract "meta"
    if ($null -eq $meta) {
        $errors.Add("meta is required")
    } else {
        $metaVersion = Get-PropSafe $meta "version"
        if ($null -eq $metaVersion) { $errors.Add("meta.version is required") }
        elseif ($metaVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { $errors.Add("meta.version must match semver pattern") }

        $metaStatus = Get-PropSafe $meta "status"
        if ($null -eq $metaStatus) { $errors.Add("meta.status is required") }
        elseif (@("Pending", "Reviewed", "Approved") -notcontains $metaStatus) { $errors.Add("meta.status must be one of Pending|Reviewed|Approved") }

        $metaGeneratedFrom = Get-PropSafe $meta "generated_from"
        if ($null -eq $metaGeneratedFrom) { $errors.Add("meta.generated_from is required") }
        elseif (@($metaGeneratedFrom).Count -lt 1) { $errors.Add("meta.generated_from must have at least 1 item") }
    }

    $contexts = Get-PropSafe $Contract "contexts"
    if ($null -eq $contexts) {
        $errors.Add("contexts is required")
    } else {
        $contexts = @($contexts)
        if ($contexts.Count -lt 1) { $errors.Add("contexts must have at least 1 item") }
        foreach ($context in $contexts) {
            foreach ($field in @("name", "description", "terms", "aggregates")) {
                if ($null -eq (Get-PropSafe $context $field)) { $errors.Add("contexts[].$field is required") }
            }
        }
    }

    return $errors
}

Describe "domain-sync SKILL.md contract" {

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "exists as an internal, non-model-invocable skill" {
        Test-Path -LiteralPath $skillPath | Should Be $true
        $script:skillText | Should Match "disable-model-invocation: true"
        $script:skillText | Should Match "user-invocable: false"
    }

    It "documents the three-step detection order: domain/ existence, Domain-Model-Status, contract validation" {
        $script:skillText | Should Match "Does\s*``domain/``\s*exist"
        $script:skillText | Should Match "Domain-Model-Status: Approved"
        $script:skillText | Should Match ([regex]::Escape("domain/domain-contract.json"))
        $script:skillText | Should Match ([regex]::Escape("contracts/domain-contract.v1.schema.json"))
    }

    It "documents exactly one skip line when domain/ is absent (AC-010)" {
        $script:skillText | Should Match ([regex]::Escape("domain-sync skipped: no domain/ directory"))
    }

    It "documents exactly one skip line when context-map.md is missing" {
        $script:skillText | Should Match ([regex]::Escape("domain-sync skipped: domain/context-map.md not found"))
    }

    It "documents the non-Approved-status warning per the Edge Case (warns and proceeds without injection)" {
        $script:skillText | Should Match ([regex]::Escape("domain-sync warning: Domain-Model-Status is"))
        $script:skillText | Should Match "proceeding without injection"
    }

    It "documents the corrupt/invalid contract warning per the Edge Case" {
        $script:skillText | Should Match ([regex]::Escape("domain-sync warning: domain-contract.json"))
    }

    It "documents the Bounded-Context: field injection format for a single context" {
        $script:skillText | Should Match ([regex]::Escape("Bounded-Context: <context-name>"))
    }

    It "documents the two-context Bounded-Context: field format with relation pattern (Edge Case)" {
        $script:skillText | Should Match ([regex]::Escape("Bounded-Context: <context-a>, <context-b>"))
        $script:skillText | Should Match "relation pattern"
    }

    It "documents the undeclared-relation fallback note" {
        $script:skillText | Should Match "relation: undeclared"
    }

    It "documents aggregate card cross-references injected into design.md" {
        $script:skillText | Should Match ([regex]::Escape("domain/aggregates/<name>.md"))
        $script:skillText | Should Match "aggregate.?s.\[\].card|aggregates\[\]\.card"
    }

    It "documents the never-block guarantee" {
        $script:skillText | Should Match "Never-Block Guarantee"
        $script:skillText | Should Match "never (raises|raise) an\s*error that halts"
    }

    It "documents it is never the writer of domain/ files (domain-interviewer owns that)" {
        $script:skillText | Should Match "Never write to any file under\s*``domain/``"
    }

    It "documents no-matching-context outcome (feature has no domain overlap)" {
        $script:skillText | Should Match ([regex]::Escape("domain-sync note: no matching"))
    }
}

Describe "sdd-bootstrap-interviewer SKILL.md calls domain-sync at Phase 1 start" {

    BeforeAll {
        $script:bootstrapText = Get-Content -Raw -Encoding UTF8 -LiteralPath $bootstrapSkillPath
    }

    It "references domain-sync in the Intake And Investigation section" {
        $script:bootstrapText | Should Match "domain-sync"
    }

    It "documents that absence of domain/ produces unchanged behavior (AC-010)" {
        $script:bootstrapText | Should Match "AC-010"
    }

    It "the domain-sync call happens before any Phase 1 artifact is generated" {
        # The Intake And Investigation section (where domain-sync is called)
        # must appear before the Required Outputs / Phase 1 section header
        # in the file text.
        $intakeIndex = $script:bootstrapText.IndexOf("## Intake And Investigation")
        $domainSyncIndex = $script:bootstrapText.IndexOf("domain-sync")
        $requiredOutputsIndex = $script:bootstrapText.IndexOf("## Required Outputs")

        $intakeIndex | Should Not Be -1
        $domainSyncIndex | Should Not Be -1
        $requiredOutputsIndex | Should Not Be -1
        ($domainSyncIndex -lt $requiredOutputsIndex) | Should Be $true
        ($domainSyncIndex -gt $intakeIndex) | Should Be $true
    }
}

Describe "Worked fixture: Approved domain/ model injects Bounded-Context into requirements.md" {

    BeforeAll {
        $script:fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t007-" + [Guid]::NewGuid().ToString("N"))
        $script:domainDir = Join-Path $script:fixtureDir "domain"
        $script:specsDir = Join-Path $script:fixtureDir "specs/widget-catalog"
        New-Item -ItemType Directory -Path $script:domainDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:specsDir -Force | Out-Null

        # --- Approved context-map.md ---------------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "context-map.md") -Encoding UTF8 -Value @'
# Context Map: widget-catalog

Domain-Model-Status: Approved
Stage: 4 of 7 (Context Map)
Seed-Source: free text

## Bounded Contexts

| Context | Description | Core Terms | Aggregates |
|---|---|---|---|
| order-management | Handles order lifecycle from placement to fulfillment | Order | Order |

## Context Relations

None.

## Open Questions

None.

## Unknowns

None.
'@

        # --- domain-contract.json (Approved) --------------------------------
        $script:contractFixture = @{
            schema = "domain-contract/v1"
            meta = @{
                version = "1.0.0"
                status = "Approved"
                generated_from = @(
                    "domain/context-map.md"
                )
            }
            contexts = @(
                @{
                    name = "order-management"
                    description = "Handles order lifecycle from placement to fulfillment."
                    terms = @(
                        @{
                            canonical = "Order"
                            ja = "chuumon"
                            definition = "A request from a shopper to purchase one or more widgets."
                            forbidden_synonyms = @("Purchase", "Cart")
                        }
                    )
                    aggregates = @(
                        @{
                            name = "Order"
                            root_entity = "Order"
                            invariants = @("Total must equal sum of line items")
                            transaction_boundary = "One order and its line items per transaction"
                            card = "domain/aggregates/Order.md"
                        }
                    )
                }
            )
            relations = @()
        }
        $contractJson = $script:contractFixture | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath (Join-Path $script:domainDir "domain-contract.json") -Encoding UTF8 -Value $contractJson

        # --- Worked requirements.md: what domain-sync's documented
        #     injection contract says the output MUST contain -------------
        Set-Content -LiteralPath (Join-Path $script:specsDir "requirements.md") -Encoding UTF8 -Value @'
# Requirements: widget-catalog

Spec-Review-Status: Passed
Bounded-Context: order-management

## Overview

Shoppers place orders for widgets.
'@
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureDir) {
            Remove-Item -LiteralPath $script:fixtureDir -Recurse -Force
        }
    }

    It "domain-contract.json validates against contracts/domain-contract.v1.schema.json" {
        $contractText = Get-Content -Raw -Encoding Utf8 -LiteralPath (Join-Path $script:domainDir "domain-contract.json")
        $contract = $contractText | ConvertFrom-Json
        $errors = @(Test-DomainContract -Contract $contract)
        $errors.Count | Should Be 0
    }

    It "context-map.md carries Domain-Model-Status: Approved (precondition for injection)" {
        $text = Get-Content -Raw -LiteralPath (Join-Path $script:domainDir "context-map.md")
        $text | Should Match "Domain-Model-Status: Approved"
    }

    It "requirements.md contains a Bounded-Context: field" {
        $reqText = Get-Content -Raw -LiteralPath (Join-Path $script:specsDir "requirements.md")
        $reqText | Should Match "Bounded-Context:\s*\S+"
    }

    It "the Bounded-Context: field names a context that actually exists in domain-contract.json" {
        $reqText = Get-Content -Raw -LiteralPath (Join-Path $script:specsDir "requirements.md")
        $match = [regex]::Match($reqText, "Bounded-Context:\s*([a-z][a-z0-9-]*)")
        $match.Success | Should Be $true
        $boundedContextName = $match.Groups[1].Value

        $contractText = Get-Content -Raw -Encoding Utf8 -LiteralPath (Join-Path $script:domainDir "domain-contract.json")
        $contract = $contractText | ConvertFrom-Json
        $contextNames = @(Get-PropSafe $contract "contexts" | ForEach-Object { Get-PropSafe $_ "name" })

        $contextNames -contains $boundedContextName | Should Be $true
    }

    It "the Bounded-Context: field is placed before ## Overview (metadata block convention)" {
        $reqText = Get-Content -Raw -LiteralPath (Join-Path $script:specsDir "requirements.md")
        $boundedIndex = $reqText.IndexOf("Bounded-Context:")
        $overviewIndex = $reqText.IndexOf("## Overview")
        $boundedIndex | Should Not Be -1
        $overviewIndex | Should Not Be -1
        ($boundedIndex -lt $overviewIndex) | Should Be $true
    }
}

Describe "Worked fixture: two-context feature with declared relation (Edge Case)" {

    BeforeAll {
        $script:twoCtxContract = @{
            schema = "domain-contract/v1"
            meta = @{
                version = "1.0.0"
                status = "Approved"
                generated_from = @("domain/context-map.md")
            }
            contexts = @(
                @{
                    name = "order-management"
                    description = "Handles order lifecycle."
                    terms = @()
                    aggregates = @()
                },
                @{
                    name = "billing"
                    description = "Handles invoicing."
                    terms = @()
                    aggregates = @()
                }
            )
            relations = @(
                @{
                    from = "order-management"
                    to = "billing"
                    pattern = "customer-supplier"
                    note = "Order publishes events consumed by Billing"
                }
            )
        }
    }

    It "the contract declares a relation between the two contexts" {
        # $script:twoCtxContract is a plain [hashtable] (built with @{ }
        # literals, not round-tripped through ConvertFrom-Json), so its
        # nested values are hashtables/arrays too -- index and key-access
        # directly rather than via Get-PropSafe (which targets PSCustomObject
        # .PSObject.Properties and would silently return $null here).
        $relation = $script:twoCtxContract["relations"][0]
        $relation["from"] | Should Be "order-management"
        $relation["to"] | Should Be "billing"
    }

    It "SKILL.md documents composing the two-context field as '<a>, <b> (<pattern>)'" {
        $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
        $skillText | Should Match ([regex]::Escape("(<relation-pattern>)"))
    }

    It "a worked two-context Bounded-Context field matches the documented format" {
        $relation = $script:twoCtxContract["relations"][0]
        $pattern = $relation["pattern"]
        $composed = "Bounded-Context: order-management, billing ($pattern)"
        $composed | Should Match "^Bounded-Context: order-management, billing \(customer-supplier\)$"
    }
}

Describe "sanity: schema file used by domain-sync is present and parses" {
    It "schema file exists and parses" {
        Test-Path -LiteralPath $schemaPath | Should Be $true
        { Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json } | Should Not Throw
    }
}
