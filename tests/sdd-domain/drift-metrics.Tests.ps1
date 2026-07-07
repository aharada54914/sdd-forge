#
# T-009 workflow-retrospective domain-drift metrics -- test-after Pester test
#
# Required Workflow for T-009 is "test-after" (Risk: low). Like T-007's
# domain-sync, workflow-retrospective's metric roll-up is agent-driven --
# there is no invocable script that performs the aggregation. Following the
# established pattern (tests/sdd-domain/domain-sync.Tests.ps1), this suite:
#
#   1. Runs structural contract tests against workflow-retrospective/
#      SKILL.md and retrospective-report.template.md: confirms the
#      domain-drift aggregation rule and the Domain Drift Metrics report
#      section are documented, and that the classification rule matches the
#      exact finding-message shapes check-domain-conformance.{sh,ps1} (T-008)
#      can actually produce.
#   2. Implements the documented classification/counting rule as a real
#      PowerShell function (Get-DomainDriftCounts) that mirrors the SKILL.md
#      rule text exactly, then runs it for real against real, on-disk
#      constructed quality-gate report fixtures (multiple
#      reports/quality-gate/*.md-shaped files under a per-run temp
#      directory) containing recorded check-domain-conformance WARN/FAILED
#      blocks -- proving nonzero term-deviation and boundary-violation
#      counts are produced, per T-009's Done-When criterion.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md"
$templatePath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/templates/retrospective-report.template.md"
$checkScriptPath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-domain-conformance.sh"

# --- Real implementation of the documented classification/counting rule ---
# This mirrors, line for line, the "Domain-drift metrics (when domain/
# exists)" rule added to workflow-retrospective/SKILL.md: locate every
# check-domain-conformance WARN/FAILED block in a quality-gate report's
# text, collect its "- <finding text>" lines, and classify each line into
# term-deviation or boundary-violation using the fixed set of messages the
# script can produce (see check-domain-conformance.sh/.ps1).
function Get-DomainDriftCounts {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ReportPaths
    )

    $termDeviationCount = 0
    $boundaryViolationCount = 0
    $unclassifiedCount = 0

    foreach ($reportPath in $ReportPaths) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath
        # Match a WARN or FAILED block header, then capture the indented
        # "- ..." finding lines that follow it up to the next blank line or
        # end of block.
        $blockMatches = [regex]::Matches(
            $text,
            '(?m)^check-domain-conformance (?:WARN|FAILED) \(\d+ finding\(s\)\):\r?\n((?:^ - .*\r?\n?)+)'
        )
        foreach ($block in $blockMatches) {
            $lines = $block.Groups[1].Value -split "\r?\n" | Where-Object { $_ -match '^\s*-\s' }
            foreach ($line in $lines) {
                $findingText = ($line -replace '^\s*-\s*', '').Trim()
                if ($findingText -match "unrecognized term '") {
                    $termDeviationCount++
                } elseif ($findingText -match "aggregate reference '.*' not found in domain-contract\.json aggregates") {
                    $termDeviationCount++
                } elseif ($findingText -match "aggregate reference '.*' has no domain/aggregates/.*\.md card") {
                    $termDeviationCount++
                } elseif ($findingText -match "Bounded-Context '.*' not found in domain-contract\.json") {
                    $boundaryViolationCount++
                } elseif ($findingText -match "Bounded-Context lists two contexts .* with no declared relation in context map") {
                    $boundaryViolationCount++
                } else {
                    $unclassifiedCount++
                }
            }
        }
    }

    return @{
        TermDeviationCount = $termDeviationCount
        BoundaryViolationCount = $boundaryViolationCount
        UnclassifiedCount = $unclassifiedCount
        CombinedCount = $termDeviationCount + $boundaryViolationCount
    }
}

Describe "workflow-retrospective SKILL.md documents domain-drift metric aggregation" {

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "SKILL.md exists and is unchanged as an internal, non-model-invocable skill" {
        Test-Path -LiteralPath $skillPath | Should Be $true
        $script:skillText | Should Match "disable-model-invocation: true"
        $script:skillText | Should Match "user-invocable: false"
    }

    It "documents the domain-drift metrics subsection gated on domain/ existing" {
        $script:skillText | Should Match "Domain-drift metrics"
        $script:skillText | Should Match ([regex]::Escape("project carries a") + "\s*``domain/``\s*" + [regex]::Escape("directory"))
    }

    It "documents sourcing only from already-recorded check-domain-conformance findings (no new evidence-collection path)" {
        $script:skillText | Should Match ([regex]::Escape("check-domain-conformance"))
        $script:skillText | Should Match "Do not re-run"
        $script:skillText | Should Match "not a new evidence-collection path"
    }

    It "documents Term-Deviation Count and Boundary-Violation Count as named metrics" {
        $script:skillText | Should Match ([regex]::Escape("Term-Deviation Count"))
        $script:skillText | Should Match ([regex]::Escape("Boundary-Violation Count"))
    }

    It "documents the exact classification rule matching check-domain-conformance's real finding messages" {
        $script:skillText | Should Match "unrecognized term"
        $script:skillText | Should Match ([regex]::Escape("aggregate reference '...' not found in domain-contract.json"))
        $script:skillText | Should Match ([regex]::Escape("Bounded-Context '...' not"))
        $script:skillText | Should Match "no declared relation in context map"
    }

    It "documents omitting the section entirely when domain/ is absent (does not emit a zero-filled table)" {
        $script:skillText | Should Match "skip this subsection entirely"
        $script:skillText | Should Match "do not emit a zero-filled table"
    }

    It "does not disturb the existing Deterministic artifact rules section (still present, still numbered 1-5)" {
        $script:skillText | Should Match ([regex]::Escape("1. **Implementation attempts.**"))
        $script:skillText | Should Match ([regex]::Escape("5. **Invalid or ambiguous evidence.**"))
    }

    It "the domain-drift subsection is placed after dataset quality indicators and before the review-gate metric derivation" {
        $datasetQualityIndex = $script:skillText.IndexOf("Also derive dataset quality indicators")
        $domainDriftIndex = $script:skillText.IndexOf("Domain-drift metrics")
        $reviewGateIndex = $script:skillText.IndexOf("For spec-review, task-review, and impl-review metrics")

        $datasetQualityIndex | Should Not Be -1
        $domainDriftIndex | Should Not Be -1
        $reviewGateIndex | Should Not Be -1
        ($domainDriftIndex -gt $datasetQualityIndex) | Should Be $true
        ($domainDriftIndex -lt $reviewGateIndex) | Should Be $true
    }
}

Describe "retrospective-report.template.md documents the Domain Drift Metrics section" {

    BeforeAll {
        $script:templateText = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
    }

    It "template exists" {
        Test-Path -LiteralPath $templatePath | Should Be $true
    }

    It "contains a Domain Drift Metrics section gated on domain/ existing" {
        $script:templateText | Should Match ([regex]::Escape("## Domain Drift Metrics"))
        $script:templateText | Should Match ([regex]::Escape("Include this section only when domain/ exists"))
    }

    It "the Domain Drift Metrics table carries Term-Deviation Count and Boundary-Violation Count rows" {
        $script:templateText | Should Match ([regex]::Escape("Term-Deviation Count"))
        $script:templateText | Should Match ([regex]::Escape("Boundary-Violation Count"))
        $script:templateText | Should Match ([regex]::Escape("{{term_deviation_count}}"))
        $script:templateText | Should Match ([regex]::Escape("{{boundary_violation_count}}"))
    }

    It "the Domain Drift Metrics section is placed after Metrics and before Friction Patterns (additive insertion point)" {
        $metricsIndex = $script:templateText.IndexOf("## Metrics")
        $domainDriftIndex = $script:templateText.IndexOf("## Domain Drift Metrics")
        $frictionIndex = $script:templateText.IndexOf("## Friction Patterns")

        $metricsIndex | Should Not Be -1
        $domainDriftIndex | Should Not Be -1
        $frictionIndex | Should Not Be -1
        ($domainDriftIndex -gt $metricsIndex) | Should Be $true
        ($domainDriftIndex -lt $frictionIndex) | Should Be $true
    }

    It "does not disturb the existing Metrics table header (still the same 8 columns)" {
        $script:templateText | Should Match ([regex]::Escape("| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |"))
    }
}

Describe "check-domain-conformance script (T-008) finding messages are read-only referenced correctly" {
    It "the five drift finding message shapes classified by the SKILL.md rule are the exact literal strings the script emits" {
        Test-Path -LiteralPath $checkScriptPath | Should Be $true
        $scriptText = Get-Content -Raw -Encoding UTF8 -LiteralPath $checkScriptPath

        # Term-deviation shapes
        $scriptText | Should Match ([regex]::Escape("unrecognized term '"))
        $scriptText | Should Match ([regex]::Escape("not found in domain-contract.json aggregates"))
        $scriptText | Should Match ([regex]::Escape("has no domain/aggregates/"))

        # Boundary-violation shapes
        $scriptText | Should Match ([regex]::Escape("Bounded-Context '"))
        $scriptText | Should Match ([regex]::Escape("no declared relation in context map"))
    }
}

Describe "Worked fixture: nonzero term-deviation and boundary-violation counts across multiple quality-gate reports" {

    BeforeAll {
        $script:tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t009-" + [Guid]::NewGuid().ToString("N"))
        $script:qgDir = Join-Path $script:tmpRoot "reports/quality-gate"
        New-Item -ItemType Directory -Path $script:qgDir -Force | Out-Null

        # --- Fixture quality-gate report 1: two term-deviation findings ---
        # (unrecognized term + unrecognized aggregate reference), matching
        # the real check-domain-conformance.sh/.ps1 WARN output shape.
        Set-Content -LiteralPath (Join-Path $script:qgDir "T-101.md") -Encoding UTF8 -Value @'
# Quality Gate -- T-101

Task ID: T-101
Feature: widget-catalog
Risk: medium
Required Workflow: acceptance-first

VERDICT: PASS
Critical: 0
Major: 0
Minor: 2

## Gates run

check-domain-conformance WARN (2 finding(s)):
 - requirements.md:12: unrecognized term 'Purchase' (not a canonical term in domain-contract.json)
 - design.md: aggregate reference 'Cart' not found in domain-contract.json aggregates

Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DOMAIN_ENFORCE=error to enforce.

## Decision

T-101 passes with two recorded domain-conformance warnings for later drift tracking.
'@

        # --- Fixture quality-gate report 2: one boundary-violation
        #     (unrecognized Bounded-Context) + one term-deviation
        #     (missing aggregate card) finding. ---
        Set-Content -LiteralPath (Join-Path $script:qgDir "T-102.md") -Encoding UTF8 -Value @'
# Quality Gate -- T-102

Task ID: T-102
Feature: widget-catalog
Risk: low
Required Workflow: test-after

VERDICT: PASS
Critical: 0
Major: 0
Minor: 2

## Gates run

check-domain-conformance WARN (2 finding(s)):
 - requirements.md: Bounded-Context 'shipping-fulfillment' not found in domain-contract.json
 - design.md: aggregate reference 'Invoice' has no domain/aggregates/Invoice.md card

## Decision

T-102 passes with two recorded domain-conformance warnings.
'@

        # --- Fixture quality-gate report 3: undeclared two-context
        #     relation boundary-violation finding, recorded under
        #     SDD_DOMAIN_ENFORCE=error (FAILED block, not WARN) to prove the
        #     rule counts both block headers. ---
        Set-Content -LiteralPath (Join-Path $script:qgDir "T-103.md") -Encoding UTF8 -Value @'
# Quality Gate -- T-103

Task ID: T-103
Feature: widget-catalog
Risk: medium
Required Workflow: acceptance-first

VERDICT: BLOCKED
Critical: 0
Major: 1
Minor: 0

## Gates run

check-domain-conformance FAILED (1 finding(s)):
 - requirements.md: Bounded-Context lists two contexts ('order-management', 'billing') with no declared relation in context map

SDD_DOMAIN_ENFORCE=error was set for this run; the finding above escalated to a gate failure.

## Decision

T-103 is Blocked pending a declared context-map relation.
'@

        # --- Fixture quality-gate report 4: a clean pass with zero
        #     check-domain-conformance findings, to prove a report with no
        #     WARN/FAILED block contributes nothing to either count. ---
        Set-Content -LiteralPath (Join-Path $script:qgDir "T-104.md") -Encoding UTF8 -Value @'
# Quality Gate -- T-104

Task ID: T-104
Feature: widget-catalog
Risk: low
Required Workflow: test-after

VERDICT: PASS
Critical: 0
Major: 0
Minor: 0

## Gates run

check-domain-conformance passed.

## Decision

T-104 passes cleanly with no domain-conformance findings.
'@

        # --- Fixture quality-gate report 5: a non-drift input-error line
        #     ("requirements.md not found: ...") must not be counted in
        #     either bucket. ---
        Set-Content -LiteralPath (Join-Path $script:qgDir "T-105.md") -Encoding UTF8 -Value @'
# Quality Gate -- T-105

Task ID: T-105
Feature: widget-catalog
Risk: low
Required Workflow: test-after

VERDICT: PASS
Critical: 0
Major: 0
Minor: 1

## Gates run

check-domain-conformance WARN (1 finding(s)):
 - requirements.md not found: specs/widget-catalog/requirements.md

## Decision

T-105 passes; the missing-file note is an input error, not a drift finding.
'@
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:tmpRoot) {
            Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force
        }
    }

    It "Get-DomainDriftCounts produces nonzero Term-Deviation Count and Boundary-Violation Count across the retained reports" {
        $reportPaths = @(
            (Join-Path $script:qgDir "T-101.md"),
            (Join-Path $script:qgDir "T-102.md"),
            (Join-Path $script:qgDir "T-103.md"),
            (Join-Path $script:qgDir "T-104.md"),
            (Join-Path $script:qgDir "T-105.md")
        )

        $counts = Get-DomainDriftCounts -ReportPaths $reportPaths

        # Term deviations: T-101 (unrecognized term + aggregate-not-found) = 2,
        # T-102 (aggregate-no-card) = 1. Total = 3.
        $counts.TermDeviationCount | Should Be 3

        # Boundary violations: T-102 (unrecognized Bounded-Context) = 1,
        # T-103 (undeclared two-context relation, FAILED block) = 1. Total = 2.
        $counts.BoundaryViolationCount | Should Be 2

        # T-105's "requirements.md not found: ..." line is a real
        # WARN-block finding line but matches neither drift pattern --
        # it must land in Unclassified, not silently vanish or be
        # miscounted into either drift bucket.
        $counts.UnclassifiedCount | Should Be 1

        $counts.CombinedCount | Should Be 5

        ($counts.TermDeviationCount -gt 0) | Should Be $true
        ($counts.BoundaryViolationCount -gt 0) | Should Be $true
    }

    It "a report with no check-domain-conformance WARN/FAILED block (clean pass) contributes zero to both counts" {
        $counts = Get-DomainDriftCounts -ReportPaths @((Join-Path $script:qgDir "T-104.md"))
        $counts.TermDeviationCount | Should Be 0
        $counts.BoundaryViolationCount | Should Be 0
        $counts.CombinedCount | Should Be 0
    }

    It "an empty report set produces all-zero counts (no domain/ scenario)" {
        $counts = Get-DomainDriftCounts -ReportPaths @()
        $counts.TermDeviationCount | Should Be 0
        $counts.BoundaryViolationCount | Should Be 0
        $counts.CombinedCount | Should Be 0
    }

    It "classifying only the T-103 FAILED block (SDD_DOMAIN_ENFORCE=error) still counts as a boundary violation" {
        $counts = Get-DomainDriftCounts -ReportPaths @((Join-Path $script:qgDir "T-103.md"))
        $counts.BoundaryViolationCount | Should Be 1
        $counts.TermDeviationCount | Should Be 0
    }
}
