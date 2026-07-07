$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# T-001: locks contracts/domain-contract.v1.schema.json as a tested, final
# schema. PS5.1-safe: ConvertFrom-Json only, no Test-Json (PS6+ only, not
# available on Windows PowerShell 5.1 in this environment). This repository's
# existing schema-validation tests (see tests/design-system-contract.tests.ps1)
# use a hand-rolled set of structural assertions rather than a generic JSON
# Schema engine or an external validation package; this file replicates that
# same approach for the domain-contract schema instead of introducing a new
# dependency.

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$schemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v1.schema.json"

$validPattern = @(
    "partnership",
    "shared-kernel",
    "customer-supplier",
    "conformist",
    "anticorruption-layer",
    "open-host-service",
    "published-language",
    "separate-ways"
)

# Set-StrictMode -Version Latest throws on a missing property access for a
# PSCustomObject (unlike a hashtable, which returns $null for a missing key).
# Fixtures round-trip through ConvertTo-Json/ConvertFrom-Json into
# PSCustomObject, and the corrupt fixtures deliberately omit fields to
# exercise the "required" checks below, so every field read must go through
# this safe accessor instead of dot-notation.
function Get-PropSafe {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

# Minimal structural validator for the domain-contract/v1 shape. Mirrors the
# required/enum/pattern rules declared in contracts/domain-contract.v1.schema.json
# without a generic JSON Schema engine, matching this repo's existing pattern.
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
            $contextName = Get-PropSafe $context "name"
            if ($null -ne $contextName -and $contextName -notmatch '^[a-z][a-z0-9-]*$') {
                $errors.Add("contexts[].name must be kebab-case")
            }
            foreach ($term in @(Get-PropSafe $context "terms")) {
                foreach ($field in @("canonical", "definition")) {
                    if ($null -eq (Get-PropSafe $term $field)) { $errors.Add("contexts[].terms[].$field is required") }
                }
            }
            foreach ($aggregate in @(Get-PropSafe $context "aggregates")) {
                foreach ($field in @("name", "root_entity", "invariants", "transaction_boundary", "card")) {
                    if ($null -eq (Get-PropSafe $aggregate $field)) { $errors.Add("contexts[].aggregates[].$field is required") }
                }
            }
        }
    }

    $relations = Get-PropSafe $Contract "relations"
    if ($null -ne $relations) {
        foreach ($relation in @($relations)) {
            foreach ($field in @("from", "to", "pattern")) {
                if ($null -eq (Get-PropSafe $relation $field)) { $errors.Add("relations[].$field is required") }
            }
            $relationPattern = Get-PropSafe $relation "pattern"
            if ($null -ne $relationPattern -and $validPattern -notcontains $relationPattern) {
                $errors.Add("relations[].pattern must be a recognized contextRelation pattern")
            }
        }
    }

    return $errors
}

# Builds a minimal, schema-conformant domain-contract fixture as a hashtable
# (converted to/from JSON in each test to exercise the same code path a real
# generated domain/domain-contract.json would go through).
function New-ValidDomainContractFixture {
    return @{
        schema = "domain-contract/v1"
        meta = @{
            version = "0.1.0"
            status = "Pending"
            generated_from = @("domain/domain-story.md", "domain/context-map.md")
        }
        contexts = @(
            @{
                name = "order-management"
                description = "Handles order lifecycle from placement to fulfillment."
                terms = @(
                    @{
                        canonical = "Order"
                        ja = "chuumon"
                        definition = "A request from a customer to purchase one or more items."
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

Describe "domain-contract.v1.schema.json" {

    It "the schema file itself parses as valid JSON" {
        { Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json } | Should Not Throw
    }

    It "declares the domain-contract/v1 schema const" {
        $schema = Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json
        $schema.properties.schema.const | Should Be "domain-contract/v1"
    }

    It "declares the full contextRelation pattern enum" {
        $schema = Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json
        $declaredPatterns = @($schema.definitions.contextRelation.properties.pattern.enum)
        foreach ($pattern in $validPattern) {
            ($declaredPatterns -contains $pattern) | Should Be $true
        }
    }

    Context "valid fixture" {
        It "passes schema validation with zero errors" {
            $fixture = New-ValidDomainContractFixture
            $contract = $fixture | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            $errors = @(Test-DomainContract -Contract $contract)
            $errors.Count | Should Be 0
        }
    }

    Context "corrupt fixture: missing required field (meta)" {
        It "is rejected for missing meta" {
            $fixture = New-ValidDomainContractFixture
            $fixture.Remove("meta")
            $contract = $fixture | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            $errors = @(Test-DomainContract -Contract $contract)
            $errors.Count | Should BeGreaterThan 0
            ($errors -join "; ") | Should Match "meta is required"
        }
    }

    Context "corrupt fixture: wrong schema const value" {
        It "is rejected for schema = domain-contract/v2" {
            $fixture = New-ValidDomainContractFixture
            $fixture.schema = "domain-contract/v2"
            $contract = $fixture | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            $errors = @(Test-DomainContract -Contract $contract)
            $errors.Count | Should BeGreaterThan 0
            ($errors -join "; ") | Should Match "schema const must equal"
        }
    }

    Context "corrupt fixture: invalid pattern enum value" {
        It "is rejected for an unrecognized contextRelation pattern" {
            $fixture = New-ValidDomainContractFixture
            $fixture.relations[0].pattern = "not-a-real-pattern"
            $contract = $fixture | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            $errors = @(Test-DomainContract -Contract $contract)
            $errors.Count | Should BeGreaterThan 0
            ($errors -join "; ") | Should Match "recognized contextRelation pattern"
        }
    }

    Context "corrupt fixture: missing required aggregate field" {
        It "is rejected when an aggregate is missing invariants" {
            $fixture = New-ValidDomainContractFixture
            $fixture.contexts[0].aggregates[0].Remove("invariants")
            $contract = $fixture | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            $errors = @(Test-DomainContract -Contract $contract)
            $errors.Count | Should BeGreaterThan 0
            ($errors -join "; ") | Should Match "invariants is required"
        }
    }
}
