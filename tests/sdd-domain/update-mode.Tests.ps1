$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# T-004: domain-model update-mode algorithm (AC-016).
#
# Proves, via a worked fixture:
#   1. Editing stage N (here N=4, Context Map) and re-running update leaves
#      stages 1..N-1 (Domain Story, Event Storming, Ubiquitous Language)
#      byte-identical -- content hashes captured before and after are equal.
#   2. Stages N..7 (Context Map, Aggregates, Message Flow, C4 Container) are
#      re-run in confirmation mode -- each is re-written (timestamps/confirm
#      markers change) even where content is otherwise unchanged.
#   3. Domain-Model-Status is reset to Pending in the fixture's
#      context-map.md, regardless of its prior value.
#
# This test simulates domain-model SKILL.md's documented Update Algorithm
# with a PowerShell fixture harness (the skill itself is agent-driven prose,
# not executable code) -- the harness function below implements exactly the
# steps documented in plugins/sdd-domain/skills/domain-model/SKILL.md's
# "Update Algorithm" section, so a change to that algorithm's real behavior
# should be reflected here too.
#
# Pester 3.4.0 / Windows PowerShell 5.1 only on this host: uses
# `Describe`/`It`/`BeforeAll`/`AfterAll`, `-contains` for collection
# membership, `Invoke-Pester -Script <path>` legacy invocation. No
# non-ASCII literals.

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-domain-update-mode-" + [guid]::NewGuid())

$stageFiles = @{
    1 = "domain-story.md"
    2 = "event-storming.md"
    3 = "ubiquitous-language.md"
    4 = "context-map.md"
    6 = "message-flow.md"
    7 = "c4-container.md"
}
# Stage 5 (aggregates) lives under domain/aggregates/<name>.md -- handled
# separately below since it is a directory of one-or-more files, not a
# single canonical path like the other six stages.

function New-FixtureDomainTree {
    param([string]$Root, [string]$InitialStatus = "Approved")

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root "aggregates") -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $Root "domain-story.md") -Value @(
        "# Domain Story: fixture",
        "Stage: 1 of 7 (Domain Story)",
        "",
        "The fixture actor places an order."
    )

    Set-Content -LiteralPath (Join-Path $Root "event-storming.md") -Value @(
        "# Event Storming: fixture",
        "Stage: 2 of 7 (Event Storming)",
        "",
        "OrderPlaced (event)"
    )

    Set-Content -LiteralPath (Join-Path $Root "ubiquitous-language.md") -Value @(
        "# Ubiquitous Language: fixture",
        "Stage: 3 of 7 (Ubiquitous Language)",
        "",
        "| Canonical Term | JA | Forbidden Synonyms |",
        "|---|---|---|",
        "| Order | chuumon | Purchase |"
    )

    Set-Content -LiteralPath (Join-Path $Root "context-map.md") -Value @(
        "# Context Map: fixture",
        "Domain-Model-Status: $InitialStatus",
        "Stage: 4 of 7 (Context Map)",
        "",
        "| Context | Description | Core Terms | Aggregates |",
        "|---|---|---|---|",
        "| ordering | Order fixture context | Order | Order |"
    )

    Set-Content -LiteralPath (Join-Path $Root "aggregates/Order.md") -Value @(
        "# Aggregate: Order",
        "Stage: 5 of 7 (Domain Model)",
        "",
        "Root entity: Order"
    )

    Set-Content -LiteralPath (Join-Path $Root "message-flow.md") -Value @(
        "# Message Flow: fixture",
        "Stage: 6 of 7 (Domain Message Flow)",
        "",
        "OrderPlaced -> ConfirmOrder"
    )

    Set-Content -LiteralPath (Join-Path $Root "c4-container.md") -Value @(
        "# C4 Container: fixture",
        "Stage: 7 of 7 (C4 Container)",
        "",
        "Container: Ordering Service"
    )

    Set-Content -LiteralPath (Join-Path $Root "domain-contract.json") -Value (
        '{"schema":"domain-contract/v1","meta":{"status":"' + $InitialStatus + '","version":"0.1.0"},"contexts":[]}'
    )
}

function Get-FileHashHex {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# Simulates domain-model SKILL.md's documented "Update Algorithm" section
# for a given edited stage N. Confirmation mode is simulated by re-writing
# each downstream stage file with an appended confirmation marker (standing
# in for the human's confirm-or-revise pass) -- upstream stages are never
# touched.
function Invoke-SimulatedUpdateMode {
    param([string]$DomainRoot, [int]$EditedStage)

    $orderedStages = 1..7

    # Step 1: snapshot upstream stages 1..N-1 before touching anything.
    $upstreamStages = $orderedStages | Where-Object { $_ -lt $EditedStage }
    $upstreamHashesBefore = @{}
    foreach ($stage in $upstreamStages) {
        if ($stage -eq 5) { continue } # aggregates handled separately, and stage 5 is never upstream of itself in this fixture's N=4 scenario
        $path = Join-Path $DomainRoot $stageFiles[$stage]
        $upstreamHashesBefore[$stage] = Get-FileHashHex -Path $path
    }

    # Steps 2-4: re-run stage N and every downstream stage N..7 in
    # confirmation mode. Confirmation mode = re-present existing content,
    # append a confirmation marker, and re-write (even when unchanged).
    $downstreamStages = $orderedStages | Where-Object { $_ -ge $EditedStage }
    foreach ($stage in $downstreamStages) {
        if ($stage -eq 5) {
            $aggregateFiles = Get-ChildItem -LiteralPath (Join-Path $DomainRoot "aggregates") -Filter "*.md"
            foreach ($aggFile in $aggregateFiles) {
                Add-Content -LiteralPath $aggFile.FullName -Value "Confirmed-In-Update: stage 5"
            }
            continue
        }
        $path = Join-Path $DomainRoot $stageFiles[$stage]
        Add-Content -LiteralPath $path -Value "Confirmed-In-Update: stage $stage"
    }

    # Step 6: regenerate domain-contract.json (simulated as a version bump).
    $contractPath = Join-Path $DomainRoot "domain-contract.json"
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $contract.meta.version = "0.1.1"
    $contract.meta.status = "Pending"
    ($contract | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $contractPath

    # Step 7: reset Domain-Model-Status to Pending in context-map.md.
    # (For this fixture, stage 4 = context-map.md, so this coincides with
    # stage 4's own confirmation-mode re-write above, matching SKILL.md's
    # documented convergence for N = 4.)
    $contextMapPath = Join-Path $DomainRoot "context-map.md"
    $contextMapLines = Get-Content -LiteralPath $contextMapPath
    $newLines = $contextMapLines | ForEach-Object {
        if ($_ -match "^Domain-Model-Status:\s*\S+") {
            "Domain-Model-Status: Pending"
        } else {
            $_
        }
    }
    Set-Content -LiteralPath $contextMapPath -Value $newLines

    # Step 5: verify upstream stages 1..N-1 remain byte-identical.
    $upstreamHashesAfter = @{}
    foreach ($stage in $upstreamStages) {
        if ($stage -eq 5) { continue }
        $path = Join-Path $DomainRoot $stageFiles[$stage]
        $upstreamHashesAfter[$stage] = Get-FileHashHex -Path $path
    }

    return @{
        UpstreamStages       = $upstreamStages
        UpstreamHashesBefore = $upstreamHashesBefore
        UpstreamHashesAfter  = $upstreamHashesAfter
        DownstreamStages     = $downstreamStages
    }
}

Describe "Fixture: editing stage 4 (Context Map) and re-running update" {

    New-FixtureDomainTree -Root $fixtureRoot -InitialStatus "Approved"

    # Capture pre-update hashes for ALL stages (including downstream) so we
    # can positively assert downstream stages DID change (were re-run),
    # not just that upstream stages did not.
    $preUpdateHashes = @{}
    foreach ($stage in 1..7) {
        if ($stage -eq 5) {
            $preUpdateHashes[5] = Get-FileHashHex -Path (Join-Path $fixtureRoot "aggregates/Order.md")
            continue
        }
        $preUpdateHashes[$stage] = Get-FileHashHex -Path (Join-Path $fixtureRoot $stageFiles[$stage])
    }
    $preUpdateStatus = (Get-Content -LiteralPath (Join-Path $fixtureRoot "context-map.md") | Where-Object { $_ -match "^Domain-Model-Status:" })

    $result = Invoke-SimulatedUpdateMode -DomainRoot $fixtureRoot -EditedStage 4

    It "pre-update fixture status is Approved (sanity check before reset)" {
        $preUpdateStatus | Should Match "Approved"
    }

    It "identifies stages 1-3 as upstream of edited stage 4" {
        ($result.UpstreamStages -join ",") | Should Be "1,2,3"
    }

    It "identifies stages 4-7 as downstream (re-run) of edited stage 4" {
        ($result.DownstreamStages -join ",") | Should Be "4,5,6,7"
    }

    foreach ($stage in @(1, 2, 3)) {
        It "stage $stage (upstream) is byte-identical before and after update" {
            $result.UpstreamHashesBefore[$stage] | Should Be $result.UpstreamHashesAfter[$stage]
        }

        It "stage $stage (upstream) hash matches the original pre-update fixture hash" {
            $preUpdateHashes[$stage] | Should Be $result.UpstreamHashesAfter[$stage]
        }
    }

    foreach ($stage in @(4, 6, 7)) {
        It "stage $stage (downstream) was re-run: content hash changed" {
            $path = Join-Path $fixtureRoot $stageFiles[$stage]
            $postHash = Get-FileHashHex -Path $path
            ($postHash -eq $preUpdateHashes[$stage]) | Should Be $false
        }

        It "stage $stage (downstream) carries the confirmation-mode marker" {
            $path = Join-Path $fixtureRoot $stageFiles[$stage]
            (Get-Content -LiteralPath $path -Raw) | Should Match "Confirmed-In-Update: stage $stage"
        }
    }

    It "stage 5 (aggregates, downstream) was re-run: content hash changed" {
        $postHash = Get-FileHashHex -Path (Join-Path $fixtureRoot "aggregates/Order.md")
        ($postHash -eq $preUpdateHashes[5]) | Should Be $false
    }

    It "stage 5 (aggregates, downstream) carries the confirmation-mode marker" {
        (Get-Content -LiteralPath (Join-Path $fixtureRoot "aggregates/Order.md") -Raw) | Should Match "Confirmed-In-Update: stage 5"
    }

    It "Domain-Model-Status is reset to Pending in context-map.md" {
        $line = Get-Content -LiteralPath (Join-Path $fixtureRoot "context-map.md") | Where-Object { $_ -match "^Domain-Model-Status:" }
        $line | Should Match "^Domain-Model-Status:\s*Pending\s*$"
    }

    It "Domain-Model-Status is no longer Approved after update" {
        $line = Get-Content -LiteralPath (Join-Path $fixtureRoot "context-map.md") | Where-Object { $_ -match "^Domain-Model-Status:" }
        ($line -match "Approved") | Should Be $false
    }

    It "domain-contract.json meta.status was also reset to Pending" {
        $contract = Get-Content -LiteralPath (Join-Path $fixtureRoot "domain-contract.json") -Raw | ConvertFrom-Json
        $contract.meta.status | Should Be "Pending"
    }

    It "domain-contract.json version was bumped (regeneration occurred)" {
        $contract = Get-Content -LiteralPath (Join-Path $fixtureRoot "domain-contract.json") -Raw | ConvertFrom-Json
        $contract.meta.version | Should Be "0.1.1"
    }
}

Describe "Fixture: update mode resets status even when prior status was Reviewed (not just Approved)" {

    $reviewedFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-domain-update-mode-reviewed-" + [guid]::NewGuid())
    New-FixtureDomainTree -Root $reviewedFixtureRoot -InitialStatus "Reviewed"

    Invoke-SimulatedUpdateMode -DomainRoot $reviewedFixtureRoot -EditedStage 4 | Out-Null

    It "status resets to Pending from a prior Reviewed state" {
        $line = Get-Content -LiteralPath (Join-Path $reviewedFixtureRoot "context-map.md") | Where-Object { $_ -match "^Domain-Model-Status:" }
        $line | Should Match "^Domain-Model-Status:\s*Pending\s*$"
    }

    Remove-Item -LiteralPath $reviewedFixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Fixture: editing stage 2 (Event Storming) leaves only stage 1 upstream" {

    $stage2FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-domain-update-mode-stage2-" + [guid]::NewGuid())
    New-FixtureDomainTree -Root $stage2FixtureRoot -InitialStatus "Approved"

    $preHashStage1 = Get-FileHashHex -Path (Join-Path $stage2FixtureRoot "domain-story.md")

    $result2 = Invoke-SimulatedUpdateMode -DomainRoot $stage2FixtureRoot -EditedStage 2

    It "only stage 1 is upstream of edited stage 2" {
        ($result2.UpstreamStages -join ",") | Should Be "1"
    }

    It "stage 1 remains byte-identical" {
        $postHashStage1 = Get-FileHashHex -Path (Join-Path $stage2FixtureRoot "domain-story.md")
        $preHashStage1 | Should Be $postHashStage1
    }

    It "status is still reset to Pending even though the edited stage (2) is not the Context Map stage" {
        $line = Get-Content -LiteralPath (Join-Path $stage2FixtureRoot "context-map.md") | Where-Object { $_ -match "^Domain-Model-Status:" }
        $line | Should Match "^Domain-Model-Status:\s*Pending\s*$"
    }

    Remove-Item -LiteralPath $stage2FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "domain-model SKILL.md documents the update algorithm this fixture simulates" {

    $skillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-model/SKILL.md"
    $skillContent = Get-Content -LiteralPath $skillPath -Raw

    It "domain-model SKILL.md exists" {
        Test-Path -LiteralPath $skillPath | Should Be $true
    }

    It "documents re-running the edited stage plus every downstream stage" {
        $skillContent | Should Match "downstream stage"
    }

    It "documents confirmation mode as re-presenting existing artifacts for approval" {
        $skillContent | Should Match "[Cc]onfirmation mode"
    }

    It "documents verifying upstream stages remain byte-identical" {
        $skillContent | Should Match "byte-identical"
    }

    It "documents resetting Domain-Model-Status to Pending" {
        $skillContent | Should Match "Domain-Model-Status.*Pending"
    }

    It "documents that only a human may set Approved, never this skill" {
        $skillContent | Should Match "never sets `Domain-Model-Status: Approved`|never set.*Approved"
    }
}

# Cleanup for the primary fixture (the other two Describe blocks clean up
# their own fixtures inline since they use separate temp roots).
Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
