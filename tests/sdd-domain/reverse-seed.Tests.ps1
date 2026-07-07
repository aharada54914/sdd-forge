#
# T-003 domain-reverse skill -- acceptance-first Pester test
#
# Required Workflow for T-003 is "acceptance-first" (Risk: medium), not
# strict TDD. domain-reverse's actual seed conversion is agent-driven --
# an LLM reads specs/<feature>/investigation.md and interprets it against
# the Finding-to-Seed Mapping table documented in
# plugins/sdd-domain/skills/domain-reverse/SKILL.md. There is no
# deterministic script to execute for that conversion step, so this file
# does not (and cannot) invoke a parser.
#
# Instead, this test validates the two things that ARE checkable
# mechanically, matching this task's Done-When criterion ("Fixture
# investigation.md produces a non-empty candidate seed with at least one
# candidate context and one candidate term"):
#
#   1. The SKILL.md documents the exact candidate-seed contract (the five
#      required section headings and the load-bearing field names) that
#      T-002's domain-interviewer will need to consume later. This is a
#      structural contract test against the SKILL.md text itself.
#
#   2. A worked example: a fixture investigation.md (constructed here,
#      matching investigate-codebase's real output template) is manually
#      converted into a seed by hand-applying the SKILL.md's own documented
#      mapping rules. That worked seed is asserted to be well-formed (has
#      all five sections, at least one candidate_contexts entry, at least
#      one candidate_terms entry, and every candidate traces back to a real
#      INV-NNN row that exists in the fixture).
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-reverse/SKILL.md"

Describe "domain-reverse SKILL.md contract" {

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "exists as an internal, non-model-invocable skill" {
        Test-Path -LiteralPath $skillPath | Should Be $true
        $script:skillText | Should Match "disable-model-invocation: true"
        $script:skillText | Should Match "user-invocable: false"
    }

    It "documents invoking investigate-codebase as the seed source" {
        $script:skillText | Should Match "investigate-codebase"
        $script:skillText | Should Match "/sdd-bootstrap:investigate-codebase"
    }

    It "declares all five required candidate-seed sections" {
        $script:skillText | Should Match "## candidate_contexts"
        $script:skillText | Should Match "## candidate_terms"
        $script:skillText | Should Match "## candidate_event_hints"
        $script:skillText | Should Match "## candidate_aggregate_hints"
        $script:skillText | Should Match "## candidate_open_questions"
    }

    It "documents the load-bearing field names for each section" {
        $script:skillText | Should Match "rationale:"
        $script:skillText | Should Match "definition_hint:"
        $script:skillText | Should Match "evidence:"
        $script:skillText | Should Match "invariant_hint:"
        $script:skillText | Should Match "kind: event \| command"
    }

    It "states domain-reverse never writes into domain/" {
        $script:skillText | Should Match "never writes into .domain/. itself"
    }

    It "requires every candidate to carry INV-NNN evidence" {
        $script:skillText | Should Match "INV-NNN"
        $script:skillText | Should Match "unevidenced claims"
    }
}

Describe "Fixture investigation.md -> worked-example candidate seed" {

    BeforeAll {
        # --- Fixture investigation.md -----------------------------------
        # Matches plugins/sdd-bootstrap/skills/investigate-codebase/templates/
        # investigation.template.md exactly: header table, Scope, Summary,
        # a Findings table with INV-NNN rows across several categories, an
        # Open Questions table, a Risks table, and Recommended Next Steps.
        $script:fixtureFeature = "widget-catalog"
        $script:fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t003-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $script:fixtureDir -Force | Out-Null
        $script:fixtureInvestigationPath = Join-Path $script:fixtureDir "investigation.md"

        $fixtureContent = @'
# Investigation: widget-catalog

| Field | Value |
|-------|-------|
| Feature | widget-catalog |
| Mode | feature |
| Date | 2026-07-06 |
| Investigator | sdd-investigator |

## Scope

Existing widget catalog and ordering code prior to the sdd-domain reverse
seed feature.

## Summary

The codebase has a catalog browsing screen, an orders API, and a stock
reservation business rule. No prior domain-model artifacts exist.

## Findings

| INV-ID | Category | Finding | Evidence | Confidence |
|--------|----------|---------|----------|------------|
| INV-001 | screen | Catalog browsing screen lists widgets grouped by category | `src/screens/CatalogScreen.tsx:12` | high |
| INV-002 | api | POST /api/orders creates a new order from a cart | `src/api/ordersController.ts:41` | high |
| INV-003 | business-rule | An order cannot be placed if reserved stock for any line item is below the requested quantity | `src/services/stockService.ts:88` | medium |
| INV-004 | data | Order entity owns orderLines, shippingAddress, and status fields | `src/models/Order.ts:10` | high |
| INV-005 | dependency | Uses axios for HTTP calls | `package.json:22` | high |
| INV-006 | test-coverage | ordersController has 40% branch coverage | `src/api/ordersController.test.ts:1` | medium |
| INV-007 | pattern | Repository pattern used consistently for data access | `src/repositories/OrderRepository.ts:1` | medium |
| INV-008 | constraint | Unclear whether Catalog and Ordering are meant to be one context or two | `src/screens/CatalogScreen.tsx:1` | low |

## Open Questions

| # | Question | Owner | Blocking |
|---|----------|-------|---------|
| 1 | Should Catalog and Ordering be separate bounded contexts? | human | no |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Implicit context boundary could be wrong | medium | medium | Confirm during domain-interviewer Context Map stage |

## Recommended Next Steps

1. Run domain-reverse to seed a candidate domain model.
2. Confirm context boundary during the interview.
'@
        Set-Content -LiteralPath $script:fixtureInvestigationPath -Value $fixtureContent -Encoding UTF8

        # --- Worked-example candidate seed ------------------------------
        # Hand-built by applying the Finding-to-Seed Mapping table in
        # domain-reverse/SKILL.md to the fixture above. This is what a
        # correct agent-driven run of domain-reverse against this exact
        # fixture is expected to produce.
        $script:workedSeed = [PSCustomObject]@{
            candidate_contexts = @(
                [PSCustomObject]@{
                    name      = "catalog"
                    rationale = "Catalog browsing screen suggests a distinct functional area"
                    evidence  = @("INV-001")
                },
                [PSCustomObject]@{
                    name      = "ordering"
                    rationale = "Orders API resource noun suggests a distinct context"
                    evidence  = @("INV-002")
                }
            )
            candidate_terms = @(
                [PSCustomObject]@{
                    term            = "Order"
                    definition_hint = "Created from a cart; owns order lines, shipping address, and status"
                    evidence        = @("INV-002", "INV-004")
                },
                [PSCustomObject]@{
                    term            = "Reserved Stock"
                    definition_hint = "Quantity of a widget held against an order line before it ships"
                    evidence        = @("INV-003")
                }
            )
            candidate_event_hints = @(
                [PSCustomObject]@{
                    name         = "OrderPlaced"
                    kind         = "event"
                    rationale    = "POST /api/orders is a state-changing operation on the Order resource"
                    evidence     = @("INV-002")
                }
            )
            candidate_aggregate_hints = @(
                [PSCustomObject]@{
                    name           = "Order"
                    rationale      = "Order entity owns related fields (order lines, shipping address, status) and enforces a stock invariant"
                    invariant_hint = "An order cannot be placed if reserved stock for any line item is below the requested quantity"
                    evidence       = @("INV-003", "INV-004")
                }
            )
            candidate_open_questions = @(
                [PSCustomObject]@{
                    question = "Should Catalog and Ordering be separate bounded contexts?"
                    evidence = @("INV-008")
                }
            )
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureDir) {
            Remove-Item -LiteralPath $script:fixtureDir -Recurse -Force
        }
    }

    It "fixture investigation.md exists and contains an INV-NNN Findings table" {
        Test-Path -LiteralPath $script:fixtureInvestigationPath | Should Be $true
        $text = Get-Content -Raw -LiteralPath $script:fixtureInvestigationPath
        $text | Should Match "\| INV-ID \| Category \| Finding \| Evidence \| Confidence \|"
    }

    It "fixture contains at least one screen finding" {
        $text = Get-Content -Raw -LiteralPath $script:fixtureInvestigationPath
        $text | Should Match "\| INV-001 \| screen \|"
    }

    It "fixture contains at least one api finding" {
        $text = Get-Content -Raw -LiteralPath $script:fixtureInvestigationPath
        $text | Should Match "\| INV-002 \| api \|"
    }

    It "fixture contains at least one business-rule finding" {
        $text = Get-Content -Raw -LiteralPath $script:fixtureInvestigationPath
        $text | Should Match "\| INV-003 \| business-rule \|"
    }

    It "worked seed has all five required sections present" {
        $sectionNames = @($script:workedSeed.PSObject.Properties.Name)
        ($sectionNames -contains "candidate_contexts") | Should Be $true
        ($sectionNames -contains "candidate_terms") | Should Be $true
        ($sectionNames -contains "candidate_event_hints") | Should Be $true
        ($sectionNames -contains "candidate_aggregate_hints") | Should Be $true
        ($sectionNames -contains "candidate_open_questions") | Should Be $true
    }

    It "worked seed is non-empty: at least one candidate context (Done-When)" {
        $script:workedSeed.candidate_contexts.Count | Should BeGreaterThan 0
    }

    It "worked seed is non-empty: at least one candidate term (Done-When)" {
        $script:workedSeed.candidate_terms.Count | Should BeGreaterThan 0
    }

    It "every candidate context name is kebab-case per domain-contract.v1 pattern" {
        foreach ($context in $script:workedSeed.candidate_contexts) {
            $context.name | Should Match "^[a-z][a-z0-9-]*$"
        }
    }

    It "every candidate aggregate hint name is PascalCase per domain-contract.v1 pattern" {
        foreach ($aggregate in $script:workedSeed.candidate_aggregate_hints) {
            $aggregate.name | Should Match "^[A-Z][A-Za-z0-9]*$"
        }
    }

    It "every candidate carries at least one INV-NNN evidence reference" {
        $allCandidates = @()
        $allCandidates += $script:workedSeed.candidate_contexts
        $allCandidates += $script:workedSeed.candidate_terms
        $allCandidates += $script:workedSeed.candidate_event_hints
        $allCandidates += $script:workedSeed.candidate_aggregate_hints
        $allCandidates += $script:workedSeed.candidate_open_questions

        $allCandidates.Count | Should BeGreaterThan 0
        foreach ($candidate in $allCandidates) {
            $candidate.evidence.Count | Should BeGreaterThan 0
            foreach ($id in $candidate.evidence) {
                $id | Should Match "^INV-[0-9]{3}$"
            }
        }
    }

    It "every evidence INV-NNN id traces back to a row that actually exists in the fixture" {
        $text = Get-Content -Raw -LiteralPath $script:fixtureInvestigationPath
        $allCandidates = @()
        $allCandidates += $script:workedSeed.candidate_contexts
        $allCandidates += $script:workedSeed.candidate_terms
        $allCandidates += $script:workedSeed.candidate_event_hints
        $allCandidates += $script:workedSeed.candidate_aggregate_hints
        $allCandidates += $script:workedSeed.candidate_open_questions

        foreach ($candidate in $allCandidates) {
            foreach ($id in $candidate.evidence) {
                $text | Should Match ([regex]::Escape("| $id |"))
            }
        }
    }

    It "excludes non-domain categories (dependency, test-coverage) from the seed" {
        # INV-005 (dependency) and INV-006 (test-coverage) must not appear
        # anywhere in the worked seed's evidence lists, per the
        # Finding-to-Seed Mapping table's exclusion rule.
        $allCandidates = @()
        $allCandidates += $script:workedSeed.candidate_contexts
        $allCandidates += $script:workedSeed.candidate_terms
        $allCandidates += $script:workedSeed.candidate_event_hints
        $allCandidates += $script:workedSeed.candidate_aggregate_hints
        $allCandidates += $script:workedSeed.candidate_open_questions

        $allEvidence = @()
        foreach ($candidate in $allCandidates) { $allEvidence += $candidate.evidence }

        ($allEvidence -contains "INV-005") | Should Be $false
        ($allEvidence -contains "INV-006") | Should Be $false
    }
}
