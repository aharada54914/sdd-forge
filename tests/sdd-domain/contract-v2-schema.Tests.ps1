$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# T-001 (Issue #290, sdd-domain-concept-contract Phase 0): adds
# contracts/domain-contract.v2.schema.json (concepts[] as a first-class,
# additive model element) and installs the v1 byte-identity drift lock.
# PS5.1-safe: ConvertFrom-Json only, no Test-Json (PS6+ only, not available
# on Windows PowerShell 5.1). Follows the same hand-rolled structural-
# assertion approach as tests/sdd-domain/contract-schema.Tests.ps1 (v1)
# rather than a generic JSON Schema engine (INV-005 house pattern).
#
# This file grows across T-001..T-005: T-001 authors TEST-001 (schema shape,
# AC-001) and TEST-002 (v1 drift lock, AC-002) only. T-002 through T-005 each
# append their own Describe blocks (TEST-003..TEST-026) to this same file
# without editing what T-001 wrote here.

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$v2SchemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v2.schema.json"
$v1SchemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v1.schema.json"

# TEST-002 drift lock (AC-002, REQ-007): SHA-256 of
# contracts/domain-contract.v1.schema.json measured at this feature's start
# (T-001, 2026-08-18: `shasum -a 256 contracts/domain-contract.v1.schema.json`).
# REQ-007 requires v1 stay byte-identical for the whole feature; any change to
# this recorded value is a regression in v1, not an update to this constant.
$v1BaselineSha256 = "0ab46b74c1e2561431b42b76106698339e79cd64ce0513b02aec5527b8b73841"

# Safe property accessor: Set-StrictMode -Version Latest throws on a missing
# property access for a PSCustomObject (unlike a hashtable, which returns
# $null for a missing key). Every field read below goes through this
# accessor instead of dot-notation so a missing/renamed key fails the
# relevant assertion instead of throwing.
function Get-PropSafe {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

Describe "domain-contract.v2.schema.json shape (TEST-001, AC-001)" {

    It "the v2 schema file exists" {
        Test-Path $v2SchemaPath | Should Be $true
    }

    It "parses as valid JSON" {
        { Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json } | Should Not Throw
    }

    Context "once parsed" {

        It "declares draft-07" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $draftValue = Get-PropSafe $contract '$schema'
            $draftValue | Should Be "http://json-schema.org/draft-07/schema#"
        }

        It "declares the domain-contract/v2 schema const" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $contract.properties.schema.const | Should Be "domain-contract/v2"
        }

        It "declares root required schema/meta/contexts/concepts, exactly those four" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $required = @($contract.required)
            foreach ($key in @("schema", "meta", "contexts", "concepts")) {
                ($required -contains $key) | Should Be $true
            }
            $required.Count | Should Be 4
        }

        It "declares a v1-shaped meta definition (version/status/generated_from)" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $meta = $contract.properties.meta
            $metaRequired = @($meta.required)
            foreach ($key in @("version", "status", "generated_from")) {
                ($metaRequired -contains $key) | Should Be $true
            }
            $metaRequired.Count | Should Be 3

            $meta.properties.version.pattern | Should Be '^[0-9]+\.[0-9]+\.[0-9]+$'

            $statusEnum = @($meta.properties.status.enum)
            $statusEnum.Count | Should Be 3
            foreach ($value in @("Pending", "Reviewed", "Approved")) {
                ($statusEnum -contains $value) | Should Be $true
            }

            $meta.properties.generated_from.type | Should Be "array"
            $meta.properties.generated_from.minItems | Should Be 1
            $meta.properties.generated_from.items.type | Should Be "string"
        }

        It "declares concepts as a required top-level array with minItems 1" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $contract.properties.concepts.type | Should Be "array"
            $contract.properties.concepts.minItems | Should Be 1
            (Get-PropSafe $contract.properties.concepts.items '$ref') | Should Be "#/definitions/concept"
        }

        It "duplicates the v1 boundedContext/term/aggregate/contextRelation definitions in-file (DD-3) and adds a concept definition" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            foreach ($def in @("boundedContext", "term", "aggregate", "contextRelation", "concept")) {
                (Get-PropSafe $contract.definitions $def) | Should Not Be $null
            }
        }

        It "does not `$ref` the v1 schema file (DD-3: definitions are duplicated, not cross-referenced)" {
            # Scoped to an actual JSON Schema $ref pointing at the v1 file, not
            # to prose mentioning v1's filename for documentation purposes --
            # DD-3 prohibits the cross-file reference, not the mention.
            $raw = Get-Content -Raw -Encoding Utf8 $v2SchemaPath
            $raw | Should Not Match '"\$ref"\s*:\s*"[^"]*domain-contract\.v1\.schema\.json[^"]*"'
        }

        It "declares contexts[].terms[].concept_id as optional with the concept-id pattern (REQ-003)" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $termDef = $contract.definitions.term
            $termRequired = @($termDef.required)
            ($termRequired -contains "concept_id") | Should Be $false
            $termDef.properties.concept_id.pattern | Should Be '^CONCEPT-[A-Z][A-Z0-9-]*$'
        }
    }
}

Describe "domain-contract.v1.schema.json byte-identity drift lock (TEST-002, AC-002, REQ-007)" {

    It "the v1 schema file still exists" {
        Test-Path $v1SchemaPath | Should Be $true
    }

    It "v1 schema file SHA-256 equals the recorded feature-start baseline" {
        $actualHash = (Get-FileHash -Path $v1SchemaPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $actualHash | Should Be $v1BaselineSha256
    }
}
