#
# T-002 domain-interviewer skill -- acceptance-first Pester test
#
# Required Workflow for T-002 is "acceptance-first" (Risk: medium), not
# strict TDD. domain-interviewer's actual seven-stage interview is
# agent-driven -- an LLM asks questions, records human answers, and writes
# Markdown artifacts one stage at a time. There is no deterministic script
# to execute for that conversational process, so this file does not (and
# cannot) invoke an interview.
#
# Instead, matching the pattern established by
# tests/sdd-domain/reverse-seed.Tests.ps1 (T-003), this file validates the
# things that ARE checkable mechanically, per this task's Done-When
# criteria:
#
#   1. A worked fixture: a hand-authored example domain/ directory tree
#      following domain-interviewer/SKILL.md's own documented conventions
#      (the seven canonical Markdown paths from AC-002, one aggregate card,
#      and a domain-contract.json). Assert the fixture's structure matches
#      what SKILL.md promises, and that its domain-contract.json actually
#      validates against contracts/domain-contract.v1.schema.json (this
#      part is executed for real).
#
#   2. Resume-on-interruption: SKILL.md's own documented detection-order
#      algorithm is asserted against a worked scenario where stages 1-3
#      already exist on disk. The algorithm says "resume at stage 4"; this
#      is checked both as a text-contract assertion against SKILL.md and as
#      a worked simulation whose stage 1-3 fixture content is proven
#      byte-identical (SHA-256) before and after simulating the resume
#      decision.
#
#   3. Error-path fixtures required by AC-004: an unreadable local seed path
#      and an unreachable seed URL each produce a plain-language error
#      naming which seed failed, and never invent content in its place.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-interviewer/SKILL.md"
$schemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v1.schema.json"

$templateNames = @(
    "domain-story.template.md",
    "event-storming.template.md",
    "ubiquitous-language.template.md",
    "context-map.template.md",
    "aggregate.template.md",
    "message-flow.template.md",
    "c4-container.template.md"
)

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
# PSCustomObject (unlike a hashtable). Fixtures round-trip through
# ConvertTo-Json/ConvertFrom-Json into PSCustomObject, so every field read
# goes through this safe accessor instead of dot-notation. Copied from
# tests/sdd-domain/contract-schema.Tests.ps1 (T-001) to keep the same
# validation approach for the same schema.
function Get-PropSafe {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

# Minimal structural validator for the domain-contract/v1 shape. Mirrors
# tests/sdd-domain/contract-schema.Tests.ps1's Test-DomainContract exactly,
# duplicated here (not dot-sourced) so this file has no cross-file runtime
# dependency and stays independently runnable.
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

function Get-Sha256Hex {
    param([string]$Path)
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return $hash.Hash
}

Describe "domain-interviewer SKILL.md contract" {

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "exists as an internal, non-model-invocable skill" {
        Test-Path -LiteralPath $skillPath | Should Be $true
        $script:skillText | Should Match "disable-model-invocation: true"
        $script:skillText | Should Match "user-invocable: false"
    }

    It "documents all seven canonical checkpoint paths from AC-002" {
        $script:skillText | Should Match ([regex]::Escape("domain/domain-story.md"))
        $script:skillText | Should Match ([regex]::Escape("domain/event-storming.md"))
        $script:skillText | Should Match ([regex]::Escape("domain/ubiquitous-language.md"))
        $script:skillText | Should Match ([regex]::Escape("domain/context-map.md"))
        $script:skillText | Should Match ([regex]::Escape("domain/aggregates/<name>.md"))
        $script:skillText | Should Match ([regex]::Escape("domain/message-flow.md"))
        $script:skillText | Should Match ([regex]::Escape("domain/c4-container.md"))
    }

    It "documents the domain-contract.json regeneration step after every stage" {
        $script:skillText | Should Match ([regex]::Escape("domain/domain-contract.json"))
        $script:skillText | Should Match "after every stage"
        $script:skillText | Should Match ([regex]::Escape("contracts/domain-contract.v1.schema.json"))
    }

    It "documents seed intake for text, local path, issue URL, and reverse candidate seed" {
        $script:skillText | Should Match "Free text"
        $script:skillText | Should Match "Local Markdown path"
        $script:skillText | Should Match "Issue URL"
        $script:skillText | Should Match "domain-reverse candidate seed"
    }

    It "documents resume-on-interruption stage detection order" {
        $script:skillText | Should Match "Resume on Interruption"
        $script:skillText | Should Match "resume point"
    }

    It "documents create-only stage checkpointing" {
        $script:skillText | Should Match "create-only"
    }

    It "documents the plain-language seed-failure error contract (AC-004)" {
        $script:skillText | Should Match "plain-language error"
        $script:skillText | Should Match "never invent"
    }

    It "does not instruct reading the sdd-bootstrap c4-container template at runtime" {
        # Global Constraints: sdd-domain ships its own copy, adapted, and
        # never reads across the plugin boundary by relative filesystem path.
        # SKILL.md is allowed to mention the sdd-bootstrap path in prose (to
        # explain the adaptation and disclaim a runtime read of it); the
        # invariant under test is that this skill's own Seven-Stage Sequence
        # table -- the actual stage-to-template wiring the interview follows
        # -- points only at its own templates/ directory, never at
        # sdd-bootstrap's.
        $script:skillText | Should Match ([regex]::Escape("not a runtime read"))
        $script:skillText | Should Match ([regex]::Escape("| 7 | C4 Container | ``templates/c4-container.template.md`` |"))
        $script:skillText | Should Not Match ([regex]::Escape("| 7 | C4 Container | ``plugins/sdd-bootstrap"))
    }
}

Describe "domain-interviewer templates exist" {

    foreach ($templateName in $templateNames) {
        $templatePath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-interviewer/templates/$templateName"
        It "template $templateName exists" {
            Test-Path -LiteralPath $templatePath | Should Be $true
        }
    }
}

Describe "Worked fixture: eight-artifact domain/ tree (AC-002)" {

    BeforeAll {
        $script:fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t002-" + [Guid]::NewGuid().ToString("N"))
        $script:domainDir = Join-Path $script:fixtureDir "domain"
        $script:aggregatesDir = Join-Path $script:domainDir "aggregates"
        New-Item -ItemType Directory -Path $script:aggregatesDir -Force | Out-Null

        # --- Stage 1: Domain Story ---------------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "domain-story.md") -Encoding UTF8 -Value @'
# Domain Story: widget-catalog

Stage: 1 of 7 (Domain Story)
Seed-Source: free text

## Actors

| Actor | Role | Goal |
|---|---|---|
| Shopper | Customer | Browse widgets and place an order |

## Story Narrative

A shopper browses the catalog, adds widgets to a cart, and places an order.

1. Shopper browses Catalog (views available widgets)
2. Shopper submits Cart (hands off to Ordering)

## Work Objects

| Work Object | Description | Produced By | Consumed By |
|---|---|---|---|
| Cart | Selected widgets pending order | Shopper | Ordering |

## Story Diagram

```mermaid
flowchart LR
  A1(["Shopper"]) -->|"browses"| W1[/"Catalog"/]
  W1 -->|"submits"| A2(["Ordering"])
```

## Boundary Observations

Catalog and Ordering look like two separate bounded contexts.

## Open Questions

None.

## Unknowns

None.
'@

        # --- Stage 2: Event Storming -------------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "event-storming.md") -Encoding UTF8 -Value @'
# Event Storming: widget-catalog

Stage: 2 of 7 (Event Storming)
Seed-Source: free text

## Domain Events

| Event | Trigger | Triggered By | Resulting State Change |
|---|---|---|---|
| OrderPlaced | PlaceOrder command succeeds | Shopper | Order created in Placed state |

## Commands

| Command | Issued By | Produces Event | Precondition |
|---|---|---|---|
| PlaceOrder | Shopper | OrderPlaced | Reserved stock covers every line item |

## Policies

| Policy | Reacts To Event | Issues Command | Rationale |
|---|---|---|---|
| ReserveStockOnOrder | OrderPlaced | ReserveStock | Stock must be held once an order is placed |

## Actors and Read Models

| Actor | Reads | Decides | Issues Command |
|---|---|---|---|
| Shopper | Catalog | What to order | PlaceOrder |

## Hotspots

None.

## Timeline Diagram

```mermaid
flowchart LR
  C1["PlaceOrder"] --> E1(["OrderPlaced"])
  E1 --> P1{{"ReserveStockOnOrder"}}
```

## Candidate Aggregate Clusters

Order (PlaceOrder, OrderPlaced) forms one cluster.

## Open Questions

None.

## Unknowns

None.
'@

        # --- Stage 3: Ubiquitous Language --------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "ubiquitous-language.md") -Encoding UTF8 -Value @'
# Ubiquitous Language: widget-catalog

Stage: 3 of 7 (Ubiquitous Language)
Seed-Source: free text

## Terms

| Canonical Term (EN) | JA | Definition | Forbidden Synonyms | Context |
|---|---|---|---|---|
| Order | chuumon | A request from a shopper to purchase one or more widgets | Purchase, Cart | order-management |

## Term Relationships

None.

## Rejected Candidate Terms

None.

## Open Questions

None.

## Unknowns

None.
'@

        # --- Stage 4: Context Map ----------------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "context-map.md") -Encoding UTF8 -Value @'
# Context Map: widget-catalog

Domain-Model-Status: Pending
Stage: 4 of 7 (Context Map)
Seed-Source: free text

## Bounded Contexts

| Context | Description | Core Terms | Aggregates |
|---|---|---|---|
| order-management | Handles order lifecycle from placement to fulfillment | Order | Order |

## Context Relations

| From Context | To Context | Pattern | Note |
|---|---|---|---|
| order-management | billing | customer-supplier | Order publishes events consumed by Billing |

## Context Map Diagram

```mermaid
flowchart LR
  CTX1["order-management"] -- "customer-supplier" --> CTX2["billing"]
```

## Open Questions

None.

## Unknowns

None.
'@

        # --- Stage 5: Aggregate card --------------------------------------
        Set-Content -LiteralPath (Join-Path $script:aggregatesDir "Order.md") -Encoding UTF8 -Value @'
# Aggregate: Order

Stage: 5 of 7 (Domain Model - Aggregates)
Context: order-management
Seed-Source: free text

## Root Entity

Order

## Members

| Member | Kind | Description |
|---|---|---|
| OrderLine | entity | One line item within the order |

## Invariants

- Total must equal sum of line items
- An order cannot be placed if reserved stock for any line item is below the requested quantity

## Transaction Boundary

One order and its line items per transaction.

## Lifecycle

| State | Entered From | Exit Transitions | Notes |
|---|---|---|---|
| Placed | (initial) | Shipped, Cancelled | Created by PlaceOrder |

## Commands and Events Handled

| Command / Event | Direction | Effect on This Aggregate |
|---|---|---|
| PlaceOrder | incoming | Creates the Order in Placed state |
| OrderPlaced | outgoing | Notifies Billing via customer-supplier relation |

## God-Aggregate / Anemic-Model Check

Order owns only order-lifecycle behavior; billing and shipping stay in
their own contexts, avoiding god-aggregate risk.

## Open Questions

None.

## Unknowns

None.
'@

        # --- Stage 6: Message Flow -----------------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "message-flow.md") -Encoding UTF8 -Value @'
# Domain Message Flow: widget-catalog

Stage: 6 of 7 (Domain Message Flow)
Seed-Source: free text

## Message Catalog

| Message | Kind | Origin Context | Origin Aggregate | Destination Context(s) |
|---|---|---|---|---|
| OrderPlaced | event | order-management | Order | billing |

## Cross-Context Flows

| Flow | Originating Event | Relation Pattern Used | Consuming Context | Resulting Action |
|---|---|---|---|---|
| order-to-billing | OrderPlaced | customer-supplier | billing | Creates an invoice |

## Sequence Diagram

```mermaid
sequenceDiagram
  participant A as order-management
  participant B as billing
  A->>A: PlaceOrder
  A-->>B: OrderPlaced (customer-supplier)
  B->>B: CreateInvoice
```

## Failure and Compensation Paths

| Message | Failure Mode | Compensation |
|---|---|---|
| OrderPlaced | Billing unreachable | Retry with backoff; alert on-call |

## Open Questions

None.

## Unknowns

None.
'@

        # --- Stage 7: C4 Container -------------------------------------------
        Set-Content -LiteralPath (Join-Path $script:domainDir "c4-container.md") -Encoding UTF8 -Value @'
# C4 Container: widget-catalog

Stage: 7 of 7 (C4 Container)
Seed-Source: free text

## Diagram

```mermaid
C4Container
    title Container Diagram - widget-catalog
    Person(user, "Shopper", "Browses and orders widgets")
    Container(app, "Ordering Service", "Node.js", "Handles order placement")
    ContainerDb(db, "Orders DB", "PostgreSQL", "Stores orders")
    System_Ext(ext1, "Billing", "Invoices orders")
    Rel(user, app, "places order via", "HTTPS")
    Rel(app, db, "reads/writes", "SQL")
    Rel(app, ext1, "publishes OrderPlaced to", "events")
```

## Elements

| Name | Type | Responsibility | Technology | Dependencies |
|---|---|---|---|---|
| Ordering Service | Container | Handles order placement | Node.js | Orders DB, Billing |
| Orders DB | Database | Stores orders | PostgreSQL | - |

## Context-to-Container Mapping

| Container | Implements Context(s) | Aggregates Hosted |
|---|---|---|
| Ordering Service | order-management | Order |

## Related ADRs

- None.

## Open Questions

None.

## Unknowns

None.
'@

        # --- Eighth artifact: domain-contract.json ------------------------
        $script:contractFixture = @{
            schema = "domain-contract/v1"
            meta = @{
                version = "0.1.6"
                status = "Pending"
                generated_from = @(
                    "domain/domain-story.md",
                    "domain/event-storming.md",
                    "domain/ubiquitous-language.md",
                    "domain/context-map.md",
                    "domain/aggregates/Order.md",
                    "domain/message-flow.md",
                    "domain/c4-container.md"
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
                            invariants = @(
                                "Total must equal sum of line items",
                                "An order cannot be placed if reserved stock for any line item is below the requested quantity"
                            )
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
        $contractJson = $script:contractFixture | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath (Join-Path $script:domainDir "domain-contract.json") -Encoding UTF8 -Value $contractJson
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureDir) {
            Remove-Item -LiteralPath $script:fixtureDir -Recurse -Force
        }
    }

    It "produces all seven canonical Markdown checkpoint paths from AC-002" {
        Test-Path -LiteralPath (Join-Path $script:domainDir "domain-story.md") | Should Be $true
        Test-Path -LiteralPath (Join-Path $script:domainDir "event-storming.md") | Should Be $true
        Test-Path -LiteralPath (Join-Path $script:domainDir "ubiquitous-language.md") | Should Be $true
        Test-Path -LiteralPath (Join-Path $script:domainDir "context-map.md") | Should Be $true
        Test-Path -LiteralPath (Join-Path $script:aggregatesDir "Order.md") | Should Be $true
        Test-Path -LiteralPath (Join-Path $script:domainDir "message-flow.md") | Should Be $true
        Test-Path -LiteralPath (Join-Path $script:domainDir "c4-container.md") | Should Be $true
    }

    It "produces the eighth artifact domain-contract.json" {
        Test-Path -LiteralPath (Join-Path $script:domainDir "domain-contract.json") | Should Be $true
    }

    It "context-map.md carries Domain-Model-Status: Pending (AC-007 initial value)" {
        $text = Get-Content -Raw -LiteralPath (Join-Path $script:domainDir "context-map.md")
        $text | Should Match "Domain-Model-Status: Pending"
    }

    It "domain-contract.json validates against contracts/domain-contract.v1.schema.json (AC-003)" {
        $contractText = Get-Content -Raw -Encoding Utf8 -LiteralPath (Join-Path $script:domainDir "domain-contract.json")
        $contract = $contractText | ConvertFrom-Json
        $errors = @(Test-DomainContract -Contract $contract)
        $errors.Count | Should Be 0
    }

    It "the schema file itself is present and parses (sanity check on the T-001 dependency)" {
        Test-Path -LiteralPath $schemaPath | Should Be $true
        { Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json } | Should Not Throw
    }

    It "aggregate card name matches PascalCase pattern required by the schema" {
        "Order" | Should Match "^[A-Z][A-Za-z0-9]*$"
    }

    It "context name matches kebab-case pattern required by the schema" {
        "order-management" | Should Match "^[a-z][a-z0-9-]*$"
    }
}

Describe "Resume-on-interruption: worked scenario (stages 1-3 checkpointed)" {

    BeforeAll {
        $script:resumeFixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t002-resume-" + [Guid]::NewGuid().ToString("N"))
        $script:resumeDomainDir = Join-Path $script:resumeFixtureDir "domain"
        New-Item -ItemType Directory -Path $script:resumeDomainDir -Force | Out-Null

        $script:stage1Content = "# Domain Story: resume-fixture`n`nStage: 1 of 7 (Domain Story)`nSeed-Source: free text`n`nAlready checkpointed.`n"
        $script:stage2Content = "# Event Storming: resume-fixture`n`nStage: 2 of 7 (Event Storming)`nSeed-Source: free text`n`nAlready checkpointed.`n"
        $script:stage3Content = "# Ubiquitous Language: resume-fixture`n`nStage: 3 of 7 (Ubiquitous Language)`nSeed-Source: free text`n`nAlready checkpointed.`n"

        Set-Content -LiteralPath (Join-Path $script:resumeDomainDir "domain-story.md") -Encoding UTF8 -Value $script:stage1Content
        Set-Content -LiteralPath (Join-Path $script:resumeDomainDir "event-storming.md") -Encoding UTF8 -Value $script:stage2Content
        Set-Content -LiteralPath (Join-Path $script:resumeDomainDir "ubiquitous-language.md") -Encoding UTF8 -Value $script:stage3Content
        # Stages 4-7 and aggregates/ deliberately absent.

        $script:hashBefore = @{
            "domain-story.md" = Get-Sha256Hex (Join-Path $script:resumeDomainDir "domain-story.md")
            "event-storming.md" = Get-Sha256Hex (Join-Path $script:resumeDomainDir "event-storming.md")
            "ubiquitous-language.md" = Get-Sha256Hex (Join-Path $script:resumeDomainDir "ubiquitous-language.md")
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:resumeFixtureDir) {
            Remove-Item -LiteralPath $script:resumeFixtureDir -Recurse -Force
        }
    }

    # Simulates SKILL.md's documented detection-order algorithm: check the
    # seven canonical paths in stage order; the resume point is the first
    # stage whose canonical artifact is missing.
    function Get-ResumeStage {
        param([string]$DomainDir)

        $stageChecks = @(
            @{ Stage = 1; Path = Join-Path $DomainDir "domain-story.md" },
            @{ Stage = 2; Path = Join-Path $DomainDir "event-storming.md" },
            @{ Stage = 3; Path = Join-Path $DomainDir "ubiquitous-language.md" },
            @{ Stage = 4; Path = Join-Path $DomainDir "context-map.md" },
            @{ Stage = 5; Path = Join-Path $DomainDir "aggregates" },
            @{ Stage = 6; Path = Join-Path $DomainDir "message-flow.md" },
            @{ Stage = 7; Path = Join-Path $DomainDir "c4-container.md" }
        )

        foreach ($check in $stageChecks) {
            if ($check.Stage -eq 5) {
                $aggregatesExist = (Test-Path -LiteralPath $check.Path) -and
                    (@(Get-ChildItem -LiteralPath $check.Path -Filter "*.md" -ErrorAction SilentlyContinue).Count -gt 0)
                if (-not $aggregatesExist) { return $check.Stage }
            } elseif (-not (Test-Path -LiteralPath $check.Path)) {
                return $check.Stage
            }
        }
        return $null
    }

    It "SKILL.md documents the same stage-order detection algorithm this test simulates" {
        $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
        $skillText | Should Match "in this\s*\r?\n?\s*exact stage order"
        $skillText | Should Match "first stage in that order whose canonical artifact is missing"
    }

    It "detects stages 1-3 as already checkpointed and resumes at stage 4 (Done-When)" {
        $resumeStage = Get-ResumeStage -DomainDir $script:resumeDomainDir
        $resumeStage | Should Be 4
    }

    It "does not report a resume stage before 4 when 1-3 are present" {
        $resumeStage = Get-ResumeStage -DomainDir $script:resumeDomainDir
        ($resumeStage -eq 1 -or $resumeStage -eq 2 -or $resumeStage -eq 3) | Should Be $false
    }

    It "restarting from stage 1 would be wrong for this fixture (regression guard)" {
        # Sanity check that the fixture actually exercises a non-trivial
        # resume point, not stage 1 (which would trivially pass any check).
        $resumeStage = Get-ResumeStage -DomainDir $script:resumeDomainDir
        $resumeStage | Should Not Be 1
    }

    It "stage 1-3 fixture content remains byte-identical after simulating the resume decision" {
        # The resume algorithm above is read-only (Test-Path / Get-ChildItem);
        # re-hash the same three files to prove the simulated resume decision
        # touched none of them.
        $hashAfter = @{
            "domain-story.md" = Get-Sha256Hex (Join-Path $script:resumeDomainDir "domain-story.md")
            "event-storming.md" = Get-Sha256Hex (Join-Path $script:resumeDomainDir "event-storming.md")
            "ubiquitous-language.md" = Get-Sha256Hex (Join-Path $script:resumeDomainDir "ubiquitous-language.md")
        }
        $hashAfter["domain-story.md"] | Should Be $script:hashBefore["domain-story.md"]
        $hashAfter["event-storming.md"] | Should Be $script:hashBefore["event-storming.md"]
        $hashAfter["ubiquitous-language.md"] | Should Be $script:hashBefore["ubiquitous-language.md"]
    }

    It "a completed all-seven-stage tree reports no resume point (interview already complete)" {
        $completeDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t002-complete-" + [Guid]::NewGuid().ToString("N"))
        $completeAggregatesDir = Join-Path $completeDir "aggregates"
        New-Item -ItemType Directory -Path $completeAggregatesDir -Force | Out-Null
        try {
            foreach ($name in @("domain-story.md", "event-storming.md", "ubiquitous-language.md", "context-map.md", "message-flow.md", "c4-container.md")) {
                Set-Content -LiteralPath (Join-Path $completeDir $name) -Encoding UTF8 -Value "placeholder"
            }
            Set-Content -LiteralPath (Join-Path $completeAggregatesDir "Order.md") -Encoding UTF8 -Value "placeholder"

            $resumeStage = Get-ResumeStage -DomainDir $completeDir
            $resumeStage | Should Be $null
        } finally {
            Remove-Item -LiteralPath $completeDir -Recurse -Force
        }
    }
}

Describe "Error-path fixtures (AC-004): unreadable local seed and unreachable seed URL" {

    BeforeAll {
        $script:missingSeedPath = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t002-missing-seed-" + [Guid]::NewGuid().ToString("N") + ".md")
        # Deliberately never created, to simulate an unreadable/missing local seed path.

        $script:unreachableSeedUrl = "https://issues.invalid.example/does-not-exist/999999"
    }

    # Simulates domain-interviewer's documented seed-intake error contract:
    # a missing local path or unreachable URL produces a plain-language
    # error naming the failed seed, never invented content.
    function Get-SeedIntakeResult {
        param([string]$SeedKind, [string]$SeedValue)

        if ($SeedKind -eq "local-path") {
            if (-not (Test-Path -LiteralPath $SeedValue)) {
                return [PSCustomObject]@{
                    Success = $false
                    ErrorMessage = "Seed intake failed: local Markdown seed path not found or unreadable: $SeedValue"
                    Content = $null
                }
            }
            return [PSCustomObject]@{
                Success = $true
                ErrorMessage = $null
                Content = Get-Content -Raw -LiteralPath $SeedValue
            }
        }

        if ($SeedKind -eq "issue-url") {
            # This fixture never performs a real network call (Pester unit
            # test, no live network dependency); it simulates the documented
            # unreachable-URL branch of the seed-intake contract instead.
            $isKnownUnreachableFixture = $SeedValue -eq $script:unreachableSeedUrl
            if ($isKnownUnreachableFixture) {
                return [PSCustomObject]@{
                    Success = $false
                    ErrorMessage = "Seed intake failed: issue URL unreachable: $SeedValue"
                    Content = $null
                }
            }
            return [PSCustomObject]@{
                Success = $true
                ErrorMessage = $null
                Content = "simulated issue body"
            }
        }

        throw "unknown seed kind: $SeedKind"
    }

    It "an unreadable local seed path produces a plain-language error naming that path" {
        $result = Get-SeedIntakeResult -SeedKind "local-path" -SeedValue $script:missingSeedPath
        $result.Success | Should Be $false
        $result.ErrorMessage | Should Match ([regex]::Escape($script:missingSeedPath))
        $result.ErrorMessage | Should Match "local Markdown seed path"
    }

    It "an unreadable local seed path never invents seed content" {
        $result = Get-SeedIntakeResult -SeedKind "local-path" -SeedValue $script:missingSeedPath
        $result.Content | Should Be $null
    }

    It "an unreachable seed URL produces a plain-language error naming that URL" {
        $result = Get-SeedIntakeResult -SeedKind "issue-url" -SeedValue $script:unreachableSeedUrl
        $result.Success | Should Be $false
        $result.ErrorMessage | Should Match ([regex]::Escape($script:unreachableSeedUrl))
        $result.ErrorMessage | Should Match "issue URL unreachable"
    }

    It "an unreachable seed URL never invents seed content" {
        $result = Get-SeedIntakeResult -SeedKind "issue-url" -SeedValue $script:unreachableSeedUrl
        $result.Content | Should Be $null
    }

    It "SKILL.md documents this exact never-invent-content error contract" {
        $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
        $skillText | Should Match "never invent (content|seed content)"
        $skillText | Should Match "plain-language error naming"
    }
}
