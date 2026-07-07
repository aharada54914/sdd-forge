#
# T-002 domain-interviewer templates -- English-only conformance (AC-013)
#
# Verifies all seven domain-interviewer templates are English (AC-013:
# "Templates are English") by scanning for non-ASCII literal characters
# (this repository's own PS1-hygiene convention treats non-ASCII presence
# as the practical signal of non-English filler text; see the Global
# Constraints in specs/sdd-domain/tasks.md and the em-dash/arrow
# code-point-construction pattern in tests/design-system-contract.tests.ps1).
#
# Only one narrow, intentional exception exists: ubiquitous-language.template.md's
# JA column header and any Japanese example text are expected to be ASCII
# placeholders too (e.g. "chuumon" instead of literal kanji) per this same
# PS1-hygiene rule -- the JA *column* is English-template infrastructure
# (a labeled slot for a future human-supplied translation), not itself a
# non-English content requirement on the template file. This mirrors T-001's
# documented deviation (contract-schema.Tests.ps1 fixture uses "chuumon" in
# its "ja" field for the identical reason).
#
# This also asserts the specific structural requirement from AC-013 /
# tasks.md T-002 scope: ubiquitous-language.template.md carries a
# canonical-term column, a JA translation column, and a forbidden-synonyms
# column.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$templatesDir = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-interviewer/templates"

$templateNames = @(
    "domain-story.template.md",
    "event-storming.template.md",
    "ubiquitous-language.template.md",
    "context-map.template.md",
    "aggregate.template.md",
    "message-flow.template.md",
    "c4-container.template.md"
)

# A character is "ASCII" for this check when its code point is <= 0x7E
# (0x00-0x7E covers the printable ASCII range plus common control chars
# such as \r and \n). Anything above that is flagged as a potential
# non-English literal (accented Latin, CJK, full-width punctuation, etc).
function Get-NonAsciiChars {
    param([string]$Text)

    $found = New-Object System.Collections.Generic.List[string]
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $chars = $Text.ToCharArray()
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $codePoint = [int][char]$chars[$i]
        if ($codePoint -gt 0x7E) {
            $hex = "U+{0:X4}" -f $codePoint
            if ($seen.Add($hex)) {
                $found.Add($hex)
            }
        }
    }
    return @($found)
}

Describe "domain-interviewer templates are English (AC-013)" {

    foreach ($templateName in $templateNames) {
        $templatePath = Join-Path $templatesDir $templateName

        Context "Template: $templateName" {

            It "exists" {
                Test-Path -LiteralPath $templatePath | Should Be $true
            }

            It "contains no non-ASCII literal characters" {
                $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
                $nonAscii = @(Get-NonAsciiChars -Text $text)
                ($nonAscii.Count) | Should Be 0
            }

            It "uses the {{placeholder}} convention for at least one field" {
                $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
                $text | Should Match "\{\{[a-z_0-9]+\}\}"
            }

            It "declares which of the seven stages it belongs to" {
                $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
                $text | Should Match "Stage: \d of 7"
            }

            It "carries an Open Questions section" {
                $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
                $text | Should Match "## Open Questions"
            }

            It "carries an Unknowns section that instructs never inventing an answer" {
                $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
                $text | Should Match "## Unknowns"
                $text | Should Match "[Nn]ever invent"
            }
        }
    }
}

Describe "ubiquitous-language.template.md structural requirements (AC-013)" {

    BeforeAll {
        $script:ulPath = Join-Path $templatesDir "ubiquitous-language.template.md"
        $script:ulText = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:ulPath
    }

    It "carries a canonical-term column" {
        $script:ulText | Should Match "Canonical Term"
    }

    It "carries a JA translation column" {
        $script:ulText | Should Match "\| JA \|"
    }

    It "carries a forbidden-synonyms column" {
        $script:ulText | Should Match "Forbidden Synonyms"
    }

    It "the Terms table header declares canonical, JA, and forbidden-synonyms columns together in one row" {
        $script:ulText | Should Match "\| Canonical Term \(EN\) \| JA \| Definition \| Forbidden Synonyms \| Context \|"
    }

    It "documents that the canonical column, not the JA column, is what domain-contract.json stores" {
        # AC-013 / design.md: templates are English; the JA column is a
        # translation aid, never the canonical value written to the contract.
        $script:ulText | Should Match "never becomes the canonical term"
    }
}

Describe "context-map.template.md carries the Domain-Model-Status field (AC-007)" {

    BeforeAll {
        $script:cmPath = Join-Path $templatesDir "context-map.template.md"
        $script:cmText = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:cmPath
    }

    It "declares Domain-Model-Status with an initial value of Pending" {
        $script:cmText | Should Match "Domain-Model-Status: Pending"
    }

    It "documents the full Pending|Reviewed|Approved value set" {
        $script:cmText | Should Match "Pending"
        $script:cmText | Should Match "Reviewed"
        $script:cmText | Should Match "Approved"
    }

    It "documents that only a human may set Approved" {
        $script:cmText | Should Match "[Oo]nly a human may set .Approved."
    }
}

Describe "aggregate.template.md covers the Data Plan axes (design.md)" {

    BeforeAll {
        $script:aggPath = Join-Path $templatesDir "aggregate.template.md"
        $script:aggText = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:aggPath
    }

    It "covers root entity" {
        $script:aggText | Should Match "## Root Entity"
    }

    It "covers invariants" {
        $script:aggText | Should Match "## Invariants"
    }

    It "covers transaction boundary" {
        $script:aggText | Should Match "## Transaction Boundary"
    }

    It "covers lifecycle" {
        $script:aggText | Should Match "## Lifecycle"
    }

    It "documents the PascalCase naming pattern and card path consistent with the schema" {
        $script:aggText | Should Match ([regex]::Escape("^[A-Z][A-Za-z0-9]*$"))
        $script:aggText | Should Match ([regex]::Escape("domain/aggregates/<name>.md"))
    }
}

Describe "c4-container.template.md is domain-interviewer's own adapted copy" {

    BeforeAll {
        $script:c4Path = Join-Path $templatesDir "c4-container.template.md"
        $script:c4Text = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:c4Path
    }

    It "exists under domain-interviewer's own templates directory, not sdd-bootstrap's" {
        $script:c4Path | Should Match ([regex]::Escape("plugins/sdd-domain/skills/domain-interviewer/templates/c4-container.template.md").Replace('/', '[/\\]'))
    }

    It "retains the generic C4Container mermaid structure it was adapted from" {
        $script:c4Text | Should Match "C4Container"
        $script:c4Text | Should Match "\{\{system_name\}\}|\{\{domain_name\}\}"
    }

    It "adds domain-interviewer-specific traceability back to the Context Map stage" {
        $script:c4Text | Should Match "Context-to-Container Mapping"
    }
}
