# T-012 (epic-189-a1-project-context, REQ-009 / REQ-010): acceptance checks
# for the ADR-0023 migration of the TWO PROTECTED track-selection consumers
# (sdd-ship/ship, sdd-lite/lite-spec) and the close-out of consumer wiring.
#
# PowerShell parity port of tests/ship-track-selection-migration.tests.sh.
# See that file's header for the full TEST-025/TEST-026/TEST-035/TEST-039/
# TEST-CGS/TEST-PRESERVE/TEST-PUB/TEST-MUT <-> AC mapping, the
# protected-file/staging note, and the fixture-path convention.
#
# Deliberate implementation DIVERGENCE from the .sh twin (a variant axis, not
# duplication), continuing T-011's established discipline: the .sh suite
# extracts and classifies the contract, capability-gate and preservation
# properties with a PYTHON helper; this suite reimplements every extractor
# NATIVELY in PowerShell and derives its own expectations independently. A
# parser defect that survives one reading -- a mis-skipped alignment row, a
# cell whose backticks are stripped by only one implementation, a greedily
# matched closing marker, a flag cell split on the wrong separator -- is
# caught by the other. The fixture lane still drives the REAL
# generate-approval-sidecar.py / validate-approval-sidecar.py, because those
# tools ARE the production behavior under observation.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("ship-track-selection-migration-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

try {

$script:PassCount = 0
$script:FailCount = 0
function Test-Pass([string]$Label) { $script:PassCount++; Write-Output "PASS: $Label" }
function Test-Fail([string]$Label, [string]$Detail = '') { $script:FailCount++; Write-Output "FAIL: ${Label}: $Detail" }
function Assert-True([bool]$Condition, [string]$Label, [string]$Detail = '') {
    if ($Condition) { Test-Pass $Label } else { Test-Fail $Label $Detail }
}
function Assert-Eq($Actual, $Expected, [string]$Label) {
    if ($Actual -eq $Expected) { Test-Pass $Label } else { Test-Fail $Label "expected [$Expected], got [$Actual]" }
}
function Assert-Ne($A, $B, [string]$Label) {
    if (($A -ne '') -and ($B -ne '') -and ($A -ne $B)) { Test-Pass $Label }
    else { Test-Fail $Label "both sides resolved to [$A] / [$B]; they must differ and be non-empty" }
}

$Python = $null
foreach ($candidate in @('python3', 'python')) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found) { $Python = $found.Source; break }
}
if (-not $Python) {
    Write-Output 'FAIL: no python3/python interpreter available'
    exit 1
}
$env:PYTHONDONTWRITEBYTECODE = '1'

$GenPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py'
$ValPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py'
$TestKey = 't012-ship-track-selection-test-key'

$ContractOpen = '<!-- sdd:track-selection-contract v1 -->'
$ContractClose = '<!-- /sdd:track-selection-contract -->'
$HandshakeOpen = '<!-- sdd:handshake-wiring v1 -->'
$HandshakeClose = '<!-- /sdd:handshake-wiring -->'
$GateOpen = '<!-- sdd:capability-gate-scope v1 -->'
$GateClose = '<!-- /sdd:capability-gate-scope -->'

$Stage = 'specs/epic-189-a1-project-context/human-copy'
$DocShip = "$Stage/plugins/sdd-ship/skills/ship/SKILL.md"
$DocBootstrap = 'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md'
$DocInterviewer = 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
$DocLiteSpec = "$Stage/plugins/sdd-lite/skills/lite-spec/SKILL.md"
$DocLiteGate = 'plugins/sdd-lite/skills/lite-gate/SKILL.md'
# AC-039's own listed consumer order.
$ConsumerDocs = @($DocShip, $DocBootstrap, $DocInterviewer, $DocLiteSpec, $DocLiteGate)
$StagedDocs = @($DocShip, $DocLiteSpec)

$LiveShip = 'plugins/sdd-ship/skills/ship/SKILL.md'
$LiveLiteSpec = 'plugins/sdd-lite/skills/lite-spec/SKILL.md'

# ADR-0023 / AC-024 / AC-039, transcribed HERE in the test. Never read back
# out of a document -- a document that supplied its own expectation would make
# every comparison an echo of its own input.
$ExpectedRows = @(
    @('C1', 'physically absent', '--full, --lite, or none', 'COMPATIBILITY_FALLBACK'),
    @('C2', 'physically present, REQ-005 validation fails', '--full, --lite, or none', 'PROJECT_CONTEXT_INVALID'),
    @('C3', 'physically present and valid, spec_profile: lite', '--full', 'PROMOTE_FULL'),
    @('C4', 'physically present and valid, spec_profile: lite', '--lite', 'NO_OP_LITE'),
    @('C5', 'physically present and valid, spec_profile: full', '--lite', 'ERROR_STOP'),
    @('C6', 'physically present and valid, spec_profile: full', '--full', 'NO_OP_FULL')
)

# The settled REQ-010 scope ruling, as a 2x2 over (Project Context state) x
# (handshake outcome). G2 is the ADR-0023 stop (design.md:1112); G4 is
# ADR-0016's disabled-legacy, "a normal, expected condition for a project with
# no Project Context, not an error" (requirements.md:1821-1827), "never
# conflated with disabled-legacy" (design.md:1734).
$ExpectedGateRows = @(
    @('G1', 'physically present and valid', 'HOOK_ACTIVE', 'CAPABILITY_MODE'),
    @('G2', 'physically present and valid', 'not HOOK_ACTIVE', 'CAPABILITY_RUNTIME_UNAVAILABLE'),
    @('G3', 'physically absent', 'HOOK_ACTIVE', 'DISABLED_LEGACY'),
    @('G4', 'physically absent', 'not HOOK_ACTIVE', 'DISABLED_LEGACY')
)

$StopResolutions = @('ERROR_STOP', 'PROJECT_CONTEXT_INVALID')
$ContinueResolutions = @('COMPATIBILITY_FALLBACK', 'PROMOTE_FULL', 'NO_OP_LITE', 'NO_OP_FULL')

$HandshakeTokens = @(
    'check-hook-activation-handshake',
    '--emit-challenge',
    '--verify-response',
    ('sdd/.hook-canary-' + 'sentinel'),
    'HOOK_ACTIVE',
    'CAPABILITY_RUNTIME_UNAVAILABLE'
)

# Pre-existing normative content the migration must NOT silently drop.
$Preserved = @{
    $DocShip = @(
        'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
        'check-quality-gate-cycle-limit.sh',
        'Cross-Model-Waiver:',
        'Escalate-Human',
        '[sdd-ship] Track: full (--full override)',
        '[sdd-ship] Track: lite (--lite override)',
        '[sdd-ship] Track: lite (spec_profile: lite in AGENTS.md)',
        '[sdd-ship] Track: full (no lite profile detected)',
        'full-required: <primary-id>; triggers=<ordered-ids>',
        'risk-upgrade: input unavailable'
    )
    $DocLiteSpec = @(
        'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
        'lite-eligible',
        'full-required: ...',
        'risk-upgrade: input unavailable',
        'templates/requirements-lite.md',
        'Status: Planned'
    )
}

# The four OBSERVABLE fixture states, mapped to the precondition cell each one
# selects. The fixture establishes the state; the document supplies the
# resolution.
$StateCells = @{
    'absent'  = 'physically absent'
    'invalid' = 'physically present, REQ-005 validation fails'
    'lite'    = 'physically present and valid, spec_profile: lite'
    'full'    = 'physically present and valid, spec_profile: full'
}

function Get-NormalizedCell([string]$Text) {
    return ([regex]::Replace($Text.Replace('`', '').Trim(), '\s+', ' '))
}

function Get-DocText([string]$RootDir, [string]$Rel) {
    $path = Join-Path $RootDir $Rel
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return [IO.File]::ReadAllText($path)
}

# Native PowerShell block slicer -- the .sh twin's Python counterpart.
function Get-Block([string]$Text, [string]$OpenMarker, [string]$CloseMarker) {
    if ($null -eq $Text) { return @{ Error = 'document unreadable' } }
    $start = $Text.IndexOf($OpenMarker)
    if ($start -lt 0) { return @{ Error = "opening marker $OpenMarker absent" } }
    $end = $Text.IndexOf($CloseMarker, $start)
    if ($end -lt 0) { return @{ Error = "closing marker $CloseMarker absent" } }
    if ($Text.IndexOf($OpenMarker, $start + 1) -ge 0) {
        return @{ Error = "opening marker $OpenMarker appears more than once" }
    }
    return @{
        Body  = $Text.Substring($start + $OpenMarker.Length, $end - $start - $OpenMarker.Length)
        Start = $start
    }
}

# Native PowerShell table parser -- deliberately NOT a call into the .sh
# suite's Python helper.
function Get-BlockRows([string]$RootDir, [string]$Rel, [string]$OpenMarker, [string]$CloseMarker, [string]$HeaderWord) {
    $text = Get-DocText $RootDir $Rel
    $block = Get-Block $text $OpenMarker $CloseMarker
    if ($block.Error) { return @{ Error = $block.Error } }
    $rows = New-Object System.Collections.ArrayList
    foreach ($rawLine in ($block.Body -split "`n")) {
        $line = $rawLine.Trim()
        if (-not $line.StartsWith('|')) { continue }
        $cells = @($line.Trim('|') -split '\|' | ForEach-Object { Get-NormalizedCell $_ })
        if ($cells.Count -ne 4) {
            return @{ Error = "table row has $($cells.Count) cells, expected 4: $line" }
        }
        $joined = -join $cells
        if ($joined -match '^[-: ]*$') { continue }                    # alignment row
        if ($cells[0].ToLower() -eq $HeaderWord) { continue }           # header row
        [void]$rows.Add($cells)
    }
    if ($rows.Count -eq 0) { return @{ Error = 'block contains no data rows' } }
    return @{ Rows = $rows }
}

function Get-ContractRows([string]$RootDir, [string]$Rel) {
    return Get-BlockRows $RootDir $Rel $ContractOpen $ContractClose 'case'
}
function Get-GateRows([string]$RootDir, [string]$Rel) {
    return Get-BlockRows $RootDir $Rel $GateOpen $GateClose 'gate'
}

function Get-RowDiffDetail($Rows, $Expected) {
    if ($Rows.Count -ne $Expected.Count) {
        return "$($Rows.Count) rows, expected $($Expected.Count)"
    }
    for ($i = 0; $i -lt $Rows.Count; $i++) {
        $got = $Rows[$i]; $want = $Expected[$i]
        for ($c = 0; $c -lt 4; $c++) {
            if ($got[$c] -cne $want[$c]) {
                return "row $($want[0]) cell $c" + ": got [$($got[$c])], expected [$($want[$c])]"
            }
        }
    }
    return ''
}

# The conformance checker. Returns finding strings shaped "OK|<doc>|<check>" /
# "BAD|<doc>|<check>|<detail>", so the mutation lane can assert on a SPECIFIC
# finding rather than on "something went wrong".
function Get-Findings([string]$RootDir) {
    $findings = New-Object System.Collections.ArrayList
    function Add-Verdict([bool]$Cond, [string]$Doc, [string]$Check, [string]$Detail) {
        if ($Cond) { [void]$findings.Add("OK|$Doc|$Check") }
        else { [void]$findings.Add("BAD|$Doc|$Check|$Detail") }
    }

    foreach ($rel in $ConsumerDocs) {
        $parsed = Get-ContractRows $RootDir $rel
        if ($parsed.Error) {
            Add-Verdict $false $rel 'contract-block-present' $parsed.Error
            Add-Verdict $false $rel 'contract-table-exact' "not parseable: $($parsed.Error)"
        } else {
            Add-Verdict $true $rel 'contract-block-present' ''
            $detail = Get-RowDiffDetail $parsed.Rows $ExpectedRows
            Add-Verdict ($detail -eq '') $rel 'contract-table-exact' $detail
        }

        # AC-035: exactly one handshake block, every protocol token, and the
        # block positioned BEFORE the track-selection contract it gates.
        $text = Get-DocText $RootDir $rel
        $block = Get-Block $text $HandshakeOpen $HandshakeClose
        if ($block.Error) {
            Add-Verdict $false $rel 'handshake-block-present' $block.Error
            Add-Verdict $false $rel 'handshake-tokens' "no block: $($block.Error)"
            Add-Verdict $false $rel 'handshake-before-contract' "no block: $($block.Error)"
        } else {
            Add-Verdict $true $rel 'handshake-block-present' ''
            $missing = @($HandshakeTokens | Where-Object { -not $block.Body.Contains($_) })
            Add-Verdict ($missing.Count -eq 0) $rel 'handshake-tokens' ("missing token(s): " + ($missing -join ', '))
            $contractAt = $text.IndexOf($ContractOpen)
            Add-Verdict (($contractAt -ge 0) -and ($block.Start -lt $contractAt)) $rel 'handshake-before-contract' `
                ("the handshake must run at the START of the entry point, before the track-selection contract " +
                 "(handshake at $($block.Start), contract at $contractAt)")
        }
    }

    foreach ($rel in $StagedDocs) {
        $parsedGate = Get-GateRows $RootDir $rel
        if ($parsedGate.Error) {
            Add-Verdict $false $rel 'gate-scope-block-present' $parsedGate.Error
            Add-Verdict $false $rel 'gate-scope-table-exact' "not parseable: $($parsedGate.Error)"
        } else {
            Add-Verdict $true $rel 'gate-scope-block-present' ''
            $detail = Get-RowDiffDetail $parsedGate.Rows $ExpectedGateRows
            Add-Verdict ($detail -eq '') $rel 'gate-scope-table-exact' $detail
        }

        $text = Get-DocText $RootDir $rel
        if ($null -eq $text) {
            Add-Verdict $false $rel 'content-preserved' 'unreadable'
        } else {
            $missingAnchors = @($Preserved[$rel] | Where-Object { -not $text.Contains($_) })
            Add-Verdict ($missingAnchors.Count -eq 0) $rel 'content-preserved' `
                ("migration dropped pre-existing normative content: " + ($missingAnchors -join '; '))
        }
    }

    return $findings
}

# All extractors take a ROOT, so the mutation lane below drives the very same
# routing functions the matrix assertions use.
function Get-DocResolutionAt([string]$RootDir, [string]$Rel, [string]$CaseId) {
    $parsed = Get-ContractRows $RootDir $Rel
    if ($parsed.Error) { return '' }
    foreach ($row in $parsed.Rows) { if ($row[0] -eq $CaseId) { return $row[3] } }
    return ''
}
function Get-DocResolution([string]$Rel, [string]$CaseId) { return Get-DocResolutionAt $Root $Rel $CaseId }

function Get-GateResolutionAt([string]$RootDir, [string]$Rel, [string]$GateId) {
    $parsed = Get-GateRows $RootDir $Rel
    if ($parsed.Error) { return '' }
    foreach ($row in $parsed.Rows) { if ($row[0] -eq $GateId) { return $row[3] } }
    return ''
}
function Get-GateResolution([string]$Rel, [string]$GateId) { return Get-GateResolutionAt $Root $Rel $GateId }

# The case id / resolution / disposition THAT DOCUMENT gives for an OBSERVED
# fixture state. Native flag-cell splitting, deliberately independent of the
# .sh twin's Python implementation.
function Get-FixtureResolution([string]$Rel, [string]$State, [string]$Flag) {
    $parsed = Get-ContractRows $Root $Rel
    if ($parsed.Error) { return @{ Case = ''; Resolution = ''; Kind = '' } }
    $wantState = $StateCells[$State]
    if (-not $wantState) { return @{ Case = ''; Resolution = ''; Kind = '' } }
    foreach ($row in $parsed.Rows) {
        if ($row[1] -cne $wantState) { continue }
        $flags = @($row[2].Replace(' or ', ',') -split ',' | ForEach-Object { $_.Trim() })
        if (($flags -notcontains $Flag) -and ($flags -notcontains 'none')) { continue }
        $kind = 'UNCLASSIFIED'
        if ($StopResolutions -contains $row[3]) { $kind = 'stop' }
        elseif ($ContinueResolutions -contains $row[3]) { $kind = 'continue' }
        return @{ Case = $row[0]; Resolution = $row[3]; Kind = $kind }
    }
    return @{ Case = ''; Resolution = ''; Kind = '' }
}

# ===========================================================================
# Document conformance against the live tree.
# ===========================================================================
Write-Output '--- TEST-035/TEST-039/TEST-CGS/TEST-PRESERVE: document conformance ---'
$liveFindings = Get-Findings $Root
foreach ($finding in $liveFindings) {
    $parts = $finding -split '\|', 4
    if ($parts[0] -eq 'OK') { Test-Pass "$($parts[1]): $($parts[2])" }
    else { Test-Fail "$($parts[1]): $($parts[2])" $parts[3] }
}

# ===========================================================================
# Fixture projects: real on-disk state, signed by the REAL generator and
# judged by the REAL validator.
# ===========================================================================
$Fx = Join-Path $Work 'fx'

function New-FixtureProject([string]$Name, [string]$Profile) {
    $d = Join-Path $Fx $Name
    New-Item -ItemType Directory -Path (Join-Path $d 'sdd') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $d 'fixtures') -Force | Out-Null
    $ctx = Join-Path $d 'sdd/project-context.yaml'
    if ($Profile -eq 'NO-CONTEXT') {
        # sdd/project-context.yaml deliberately never created.
    } elseif ($Profile -eq 'OMIT-PROFILE') {
        @(
            'schema: sdd-project-context/v1'
            'workflow:'
            '  artifact_layout: lite-three-file'
            '  capability_enforcement: required'
        ) -join "`n" | Set-Content -LiteralPath $ctx -NoNewline -Encoding utf8
        Add-Content -LiteralPath $ctx -Value '' -Encoding utf8
    } else {
        @(
            'schema: sdd-project-context/v1'
            'workflow:'
            "  spec_profile: $Profile"
            '  artifact_layout: lite-three-file'
            '  capability_enforcement: required'
        ) -join "`n" | Set-Content -LiteralPath $ctx -NoNewline -Encoding utf8
        Add-Content -LiteralPath $ctx -Value '' -Encoding utf8
    }
    @(
        'schema: sdd-approver-registry/v1'
        'approvers:'
        '  - id: alice'
        '    name: Alice Example'
        '  - id: bob'
        '    name: Bob Example'
    ) -join "`n" | Set-Content -LiteralPath (Join-Path $d 'fixtures/approver-registry.fixture.yaml') -Encoding utf8
    @(
        'schema: sdd-approver-registry/v1'
        'approvers:'
        '  - id: bob'
        '    name: Bob Example'
    ) -join "`n" | Set-Content -LiteralPath (Join-Path $d 'fixtures/registry-without-alice.yaml') -Encoding utf8
}

function Invoke-Sign([string]$Name, [string[]]$Extra = @()) {
    $d = Join-Path $Fx $Name
    $prev = Get-Location
    Set-Location -LiteralPath $d
    try {
        $env:SDD_CONTEXT_KEY = $TestKey
        $genArgs = @(
            $GenPy,
            '--schema', 'sdd-project-context-approval/v1',
            '--content', 'sdd/project-context.yaml',
            '--approver', 'alice', '--status', 'Approved',
            '--live-sidecar', 'fixtures/no-such-live-sidecar.json'
        ) + $Extra
        & $Python @genArgs *> (Join-Path $Work 'gen.log')
    } finally { Set-Location -LiteralPath $prev }
    $cand = Get-ChildItem -Path (Join-Path $d 'sdd/.staging') -Recurse -Filter 'project-context.approval.json' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { Copy-Item -LiteralPath $cand.FullName -Destination (Join-Path $d 'fixtures/approval.json') -Force }
}

function Invoke-Validate([string]$Name, [string]$ContentRel, [string]$SidecarRel, [string]$RegistryRel) {
    $d = Join-Path $Fx $Name
    $prev = Get-Location
    Set-Location -LiteralPath $d
    try {
        $env:SDD_CONTEXT_KEY = $TestKey
        & $Python $ValPy --content $ContentRel --sidecar $SidecarRel --approver-registry $RegistryRel *> (Join-Path $Work 'val.log')
        return $LASTEXITCODE
    } finally { Set-Location -LiteralPath $prev }
}

function Get-ContextPresence([string]$Name) {
    if (Test-Path -LiteralPath (Join-Path $Fx "$Name/sdd/project-context.yaml")) { return 'present' }
    return 'absent'
}

function Get-DiskProfile([string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $Fx "$Name/sdd/project-context.yaml"))
    $m = [regex]::Match($text, '(?m)^\s+spec_profile:\s*(\S+)\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    return 'MISSING'
}

Write-Output '--- TEST-025/TEST-026: fixture construction ---'
New-FixtureProject 'ctx-absent' 'NO-CONTEXT'
New-FixtureProject 'valid-full' 'full'
New-FixtureProject 'valid-lite' 'lite'
New-FixtureProject 'bad-schema' 'OMIT-PROFILE'
New-FixtureProject 'not-yet-effective' 'full'

Invoke-Sign 'valid-full'
Invoke-Sign 'valid-lite'
Invoke-Sign 'bad-schema'
$futureAt = (Get-Date).ToUniversalTime().AddDays(3).ToString('yyyy-MM-ddTHH:mm:ssZ')
Invoke-Sign 'not-yet-effective' @('--effective-at', $futureAt)

Copy-Item -LiteralPath (Join-Path $Fx 'valid-lite/sdd/project-context.yaml') `
    -Destination (Join-Path $Fx 'valid-full/fixtures/other-content.yaml') -Force

$goodSidecar = Join-Path $Fx 'valid-full/fixtures/approval.json'
$badMacSidecar = Join-Path $Fx 'valid-full/fixtures/approval-badmac.json'
if (Test-Path -LiteralPath $goodSidecar) {
    $obj = Get-Content -LiteralPath $goodSidecar -Raw | ConvertFrom-Json
    $mac = [string]$obj.hmac
    $obj.hmac = (@{ $true = '1'; $false = '0' }[$mac[0] -eq '0']) + $mac.Substring(1)
    $obj | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badMacSidecar -Encoding utf8
}

$Reg = 'fixtures/approver-registry.fixture.yaml'
$Ctx = 'sdd/project-context.yaml'

Assert-Eq (Get-ContextPresence 'ctx-absent') 'absent' `
    "fixture: the no-Context project's $Ctx is physically ABSENT"
Assert-Eq (Get-ContextPresence 'valid-full') 'present' `
    "fixture: the full-profile project's $Ctx is physically PRESENT"
Assert-Eq (Get-DiskProfile 'valid-full') 'full' `
    "fixture: the full-profile project's on-disk spec_profile reads 'full'"
Assert-Eq (Get-DiskProfile 'valid-lite') 'lite' `
    "fixture: the lite-profile project's on-disk spec_profile reads 'lite'"
Assert-Eq (Invoke-Validate 'valid-full' $Ctx 'fixtures/approval.json' $Reg) 0 `
    "fixture: the full-profile project's sidecar PASSES validate-approval-sidecar"
Assert-Eq (Invoke-Validate 'valid-lite' $Ctx 'fixtures/approval.json' $Reg) 0 `
    "fixture: the lite-profile project's sidecar PASSES validate-approval-sidecar"

Write-Output '--- TEST-026: six independent present-but-invalid reasons ---'
Assert-Eq (Invoke-Validate 'valid-full' $Ctx 'fixtures/nonexistent.json' $Reg) 37 `
    'TEST-026 (1) missing sidecar file rejected (SIDECAR_UNREADABLE)'
Assert-Eq (Invoke-Validate 'bad-schema' $Ctx 'fixtures/approval.json' $Reg) 32 `
    'TEST-026 (2) content-schema violation rejected (CONTENT_SCHEMA_VIOLATION)'
Assert-Eq (Invoke-Validate 'valid-full' 'fixtures/other-content.yaml' 'fixtures/approval.json' $Reg) 39 `
    'TEST-026 (3) hash mismatch rejected (HASH_MISMATCH)'
Assert-Eq (Invoke-Validate 'valid-full' $Ctx 'fixtures/approval-badmac.json' $Reg) 40 `
    'TEST-026 (4) HMAC mismatch rejected (HMAC_MISMATCH)'
Assert-Eq (Invoke-Validate 'valid-full' $Ctx 'fixtures/approval.json' 'fixtures/registry-without-alice.yaml') 41 `
    'TEST-026 (5) unregistered approver rejected (UNREGISTERED_APPROVER)'
Assert-Eq (Invoke-Validate 'not-yet-effective' $Ctx 'fixtures/approval.json' $Reg) 42 `
    'TEST-026 (6) not-yet-effective effective_at rejected (EFFECTIVE_AT_NOT_YET_REACHED)'

foreach ($p in @('valid-full', 'bad-schema', 'not-yet-effective')) {
    Assert-Eq (Get-ContextPresence $p) 'present' `
        "TEST-026: the '$p' invalid fixture is physically PRESENT (never absent)"
}

# ===========================================================================
# TEST-039 (AC-039): six cases x five consumers = 30 routing assertions.
# ===========================================================================
Write-Output '--- TEST-039: six-case matrix x five consumers (30 assertions) ---'
$CaseExpectations = @(
    @('C1', 'COMPATIBILITY_FALLBACK', 'physically absent -> COMPATIBILITY_FALLBACK'),
    @('C2', 'PROJECT_CONTEXT_INVALID', 'present-but-invalid -> PROJECT_CONTEXT_INVALID'),
    @('C3', 'PROMOTE_FULL', 'lite + --full -> PROMOTE_FULL'),
    @('C4', 'NO_OP_LITE', 'lite + --lite -> NO_OP_LITE'),
    @('C5', 'ERROR_STOP', 'full + --lite -> ERROR_STOP (never a silent downgrade)'),
    @('C6', 'NO_OP_FULL', 'full + --full -> NO_OP_FULL')
)
foreach ($doc in $ConsumerDocs) {
    foreach ($case in $CaseExpectations) {
        Assert-Eq (Get-DocResolution $doc $case[0]) $case[1] `
            "TEST-039 [$doc] $($case[0]) $($case[2])"
    }
}

Write-Output '--- TEST-026: absent and present-but-invalid resolve DIFFERENTLY ---'
foreach ($doc in $ConsumerDocs) {
    Assert-Ne (Get-DocResolution $doc 'C1') (Get-DocResolution $doc 'C2') `
        "TEST-026 [$doc] the absent route and the present-but-invalid route resolve DIFFERENTLY"
}

# ===========================================================================
# TEST-025 (AC-025): sdd-ship's own behavior lock.
# ===========================================================================
Write-Output '--- TEST-025: sdd-ship error-stop and promotion behavior lock ---'
$fullLite = Get-FixtureResolution $DocShip 'full' '--lite'
$liteFull = Get-FixtureResolution $DocShip 'lite' '--full'
$invalidAny = Get-FixtureResolution $DocShip 'invalid' '--lite'
$absentAny = Get-FixtureResolution $DocShip 'absent' '--lite'
Assert-Eq $fullLite.Case 'C5' `
    'TEST-025 the observed spec_profile: full + valid sidecar + --lite fixture selects case C5'
Assert-Eq $fullLite.Resolution 'ERROR_STOP' `
    'TEST-025 sdd-ship resolves that fixture to ERROR_STOP'
Assert-Eq $fullLite.Kind 'stop' `
    'TEST-025 ERROR_STOP is classified as a STOP (execution stops; --lite never downgrades)'
Assert-Eq $liteFull.Case 'C3' `
    'TEST-025 the observed spec_profile: lite + valid sidecar + --full fixture selects case C3'
Assert-Eq $liteFull.Resolution 'PROMOTE_FULL' `
    'TEST-025 sdd-ship resolves that fixture to PROMOTE_FULL'
Assert-Eq $liteFull.Kind 'continue' `
    'TEST-025 PROMOTE_FULL is classified as a CONTINUE (promotes, no error)'
Assert-Ne $fullLite.Kind $liteFull.Kind `
    'TEST-025 the error-stop case and the promotion case have OPPOSITE stop/continue dispositions'
Assert-Eq $invalidAny.Kind 'stop' `
    'TEST-025 the present-but-invalid fixture is a STOP, not a fallback continue'
Assert-Eq $absentAny.Kind 'continue' `
    'TEST-025 the physically-absent fixture CONTINUES on the compatibility fallback'

# ===========================================================================
# TEST-CGS: the settled REQ-010 scope ruling, asserted in BOTH directions.
# ===========================================================================
Write-Output '--- TEST-CGS: capability-gate scope, both directions ---'
foreach ($doc in $StagedDocs) {
    $g1 = Get-GateResolution $doc 'G1'
    $g2 = Get-GateResolution $doc 'G2'
    $g3 = Get-GateResolution $doc 'G3'
    $g4 = Get-GateResolution $doc 'G4'
    Assert-Ne $g2 $g4 `
        "TEST-CGS [$doc] a valid Context's non-HOOK_ACTIVE outcome DIFFERS from an absent Context's (never conflated with disabled-legacy)"
    Assert-Eq $g3 $g4 `
        "TEST-CGS [$doc] the handshake outcome does NOT change an absent-Context project's resolution (legacy -> legacy is not a downgrade)"
    Assert-Ne $g1 $g2 `
        "TEST-CGS [$doc] the handshake outcome DOES change a valid-Context project's resolution (Capability Mode is genuinely stopped)"
    Assert-Eq $g2 'CAPABILITY_RUNTIME_UNAVAILABLE' `
        "TEST-CGS [$doc] a valid Context + non-HOOK_ACTIVE stops with CAPABILITY_RUNTIME_UNAVAILABLE"
    # The non-empty requirement is load-bearing: without it a document with no
    # capability-gate table at all would satisfy "G4 is not the runtime error"
    # vacuously, which is the exact class of assertion-that-echoes-nothing this
    # feature has already been bitten by. Caught by the TDD Red capture, where
    # the staged candidates do not yet exist.
    Assert-True (($g4 -ne '') -and ($g4 -ne 'CAPABILITY_RUNTIME_UNAVAILABLE')) `
        "TEST-CGS [$doc] an absent Context + non-HOOK_ACTIVE is NOT CAPABILITY_RUNTIME_UNAVAILABLE (disabled-legacy is a normal condition)" `
        "G4 resolved to [$g4]"
    Assert-Eq (Get-DocResolution $doc 'C1') 'COMPATIBILITY_FALLBACK' `
        "TEST-CGS [$doc] the same absent-Context project continues on the compatibility fallback"
}

# ===========================================================================
# TEST-PUB: publication state of the two protected consumers.
# ===========================================================================
Write-Output '--- TEST-PUB: staged/live publication state ---'
function Get-PublicationState([string]$LiveRel, [string]$StagedRel) {
    $livePath = Join-Path $Root $LiveRel
    $stagedPath = Join-Path $Root $StagedRel
    if (-not (Test-Path -LiteralPath $livePath)) { return 'missing-live' }
    if (-not (Test-Path -LiteralPath $stagedPath)) { return 'missing-staged' }
    $liveBytes = [IO.File]::ReadAllBytes($livePath)
    $stagedBytes = [IO.File]::ReadAllBytes($stagedPath)
    $same = ($liveBytes.Length -eq $stagedBytes.Length)
    if ($same) {
        for ($i = 0; $i -lt $liveBytes.Length; $i++) {
            if ($liveBytes[$i] -ne $stagedBytes[$i]) { $same = $false; break }
        }
    }
    if ($same) { return 'published' }
    $liveText = [IO.File]::ReadAllText($livePath)
    if ($liveText.Contains('sdd:track-selection-contract v1')) { return 'drift' }
    return 'unpublished'
}
foreach ($pair in @(@($LiveShip, $DocShip), @($LiveLiteSpec, $DocLiteSpec))) {
    $state = Get-PublicationState $pair[0] $pair[1]
    Write-Output "--- publication state [$($pair[0])]: $state"
    Assert-True (($state -eq 'published') -or ($state -eq 'unpublished')) `
        "TEST-PUB [$($pair[0])] publication state is a valid terminal state ($state)" `
        "got $state"
    Assert-True ($state -ne 'drift') `
        "TEST-PUB [$($pair[0])] no staged/live drift" `
        'a published live file must be byte-identical to its staged candidate'
}

# ===========================================================================
# TEST-MUT: detection power. Every assertion is a DELTA over a pristine copy,
# and each mutation additionally re-runs the ROUTING extractors against the
# mutated root, so this lane covers Get-DocResolutionAt/Get-GateResolutionAt
# -- not merely the conformance checker -- with no external harness required.
# ===========================================================================
Write-Output '--- TEST-MUT: mutation detection power ---'
# A source document that does not exist is COPIED AS ABSENT, never allowed to
# abort the run: with $ErrorActionPreference = 'Stop' a bare Copy-Item would
# throw and the suite would exit with no tally at all, which is precisely the
# state a TDD Red capture has to be able to measure.
function Copy-DocSet([string]$DestRoot) {
    foreach ($doc in $ConsumerDocs) {
        $src = Join-Path $Root $doc
        $dest = Join-Path $DestRoot $doc
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dest -Force }
    }
}

$Pristine = Join-Path $Work 'pristine'
Copy-DocSet $Pristine
$pristineFindings = Get-Findings $Pristine
$pristineBad = @($pristineFindings | Where-Object { $_.StartsWith('BAD|') })
$PristineOk = ($pristineBad.Count -eq 0)
Assert-True $PristineOk `
    'TEST-MUT baseline: the pristine document copy CONFORMS (mutations below are measurable)' `
    "$($pristineBad.Count) finding(s)"

function Invoke-Mutation([string]$RootDir, [string]$Name, [string]$Doc) {
    $path = Join-Path $RootDir $Doc
    $text = [IO.File]::ReadAllText($path)
    $before = $text
    $rowOf = {
        param($rowId)
        foreach ($line in ($text -split "`n")) {
            if ($line.Trim().StartsWith("| $rowId ")) { return $line }
        }
        return $null
    }
    switch ($Name) {
        'c2-to-fallback' {
            $row = & $rowOf 'C2'
            if ($row) { $text = $text.Replace($row, $row.Replace('PROJECT_CONTEXT_INVALID', 'COMPATIBILITY_FALLBACK')) }
        }
        'c5-silent-downgrade' {
            $row = & $rowOf 'C5'
            if ($row) { $text = $text.Replace($row, $row.Replace('ERROR_STOP', 'NO_OP_LITE')) }
        }
        'g2-degrade-to-legacy' {
            $row = & $rowOf 'G2'
            if ($row) { $text = $text.Replace($row, $row.Replace('CAPABILITY_RUNTIME_UNAVAILABLE', 'DISABLED_LEGACY')) }
        }
        'g4-conflate-disabled-legacy' {
            $row = & $rowOf 'G4'
            if ($row) { $text = $text.Replace($row, $row.Replace('DISABLED_LEGACY', 'CAPABILITY_RUNTIME_UNAVAILABLE')) }
        }
        'drop-gate-scope' {
            $text = $text.Replace($GateOpen, '<!-- capability gate scope removed -->')
        }
        'drop-handshake' {
            $text = $text.Replace($HandshakeOpen, '<!-- handshake wiring removed -->')
        }
        'handshake-after-contract' {
            $start = $text.IndexOf($HandshakeOpen)
            $end = $text.IndexOf($HandshakeClose)
            if (($start -ge 0) -and ($end -ge 0)) {
                $block = $text.Substring($start, $end + $HandshakeClose.Length - $start)
                $rest = $text.Substring(0, $start) + $text.Substring($end + $HandshakeClose.Length)
                $text = $rest + "`n" + $block + "`n"
            }
        }
        'drop-risk-upgrade' {
            $text = $text.Replace('plugins/sdd-lite/scripts/check-risk-upgrade.sh', 'plugins/sdd-lite/scripts/REMOVED.sh')
        }
        default { return "unknown mutation $Name" }
    }
    if ($text -ceq $before) { return "mutation $Name changed nothing in $Doc" }
    [IO.File]::WriteAllText($path, $text)
    return ''
}

function Assert-Mutation([string]$Name, [string]$Doc, [string]$Check, [string]$Mode, [string]$RowId, [string]$PristineValue, [string]$Label) {
    $mutDir = Join-Path $Work ("mut/" + $Name + "-" + ($Doc -replace '[/.]', '_'))
    if (Test-Path -LiteralPath $mutDir) { Remove-Item -LiteralPath $mutDir -Recurse -Force }
    Copy-DocSet $mutDir
    if (-not (Test-Path -LiteralPath (Join-Path $mutDir $Doc))) {
        Test-Fail $Label "mutation could not be applied: $Doc does not exist"
        return
    }
    $err = Invoke-Mutation $mutDir $Name $Doc
    if ($err) { Test-Fail $Label "mutation could not be applied: $err"; return }

    $findings = Get-Findings $mutDir
    $bad = @($findings | Where-Object { $_.StartsWith('BAD|') })
    if (-not $PristineOk) { Test-Fail $Label 'not measurable: the pristine baseline does not conform'; return }
    if ($bad.Count -eq 0) { Test-Fail $Label 'mutated copy still CONFORMED -- the check has no detection power'; return }
    $wanted = @($bad | Where-Object { $_.StartsWith("BAD|$Doc|$Check|") })
    if ($wanted.Count -eq 0) { Test-Fail $Label "rejected, but not by $Doc/$Check`: $($bad[0])"; return }
    if ($Mode -eq 'none') { Test-Pass $Label; return }

    if ($Mode -eq 'gate') { $got = Get-GateResolutionAt $mutDir $Doc $RowId }
    else { $got = Get-DocResolutionAt $mutDir $Doc $RowId }
    if ($got -ceq $PristineValue) {
        Test-Fail $Label "the routing extractor still reported [$PristineValue] for $RowId on the MUTATED copy -- it is not reading the document"
    } else {
        Test-Pass $Label
    }
}

foreach ($doc in $ConsumerDocs) {
    Assert-Mutation 'c5-silent-downgrade' $doc 'contract-table-exact' 'table' 'C5' 'ERROR_STOP' `
        "TEST-MUT the ADR-0023 silent downgrade (full + --lite honored) is caught in [$doc] specifically"
}
foreach ($doc in $ConsumerDocs) {
    Assert-Mutation 'c2-to-fallback' $doc 'contract-table-exact' 'table' 'C2' 'PROJECT_CONTEXT_INVALID' `
        "TEST-MUT the B5 fail-open (present-but-invalid granted the fallback) is caught in [$doc] specifically"
}
foreach ($doc in $ConsumerDocs) {
    Assert-Mutation 'drop-handshake' $doc 'handshake-block-present' 'none' '' '' `
        "TEST-MUT removing the REQ-010 handshake wiring is caught in [$doc] specifically"
}
foreach ($doc in $StagedDocs) {
    Assert-Mutation 'g2-degrade-to-legacy' $doc 'gate-scope-table-exact' 'gate' 'G2' 'CAPABILITY_RUNTIME_UNAVAILABLE' `
        "TEST-MUT a valid Project Context DEGRADING to legacy on a non-HOOK_ACTIVE handshake is REJECTED in [$doc]"
    Assert-Mutation 'g4-conflate-disabled-legacy' $doc 'gate-scope-table-exact' 'gate' 'G4' 'DISABLED_LEGACY' `
        "TEST-MUT reporting an entirely-legacy project as CAPABILITY_RUNTIME_UNAVAILABLE is REJECTED in [$doc]"
    Assert-Mutation 'drop-gate-scope' $doc 'gate-scope-block-present' 'none' '' '' `
        "TEST-MUT deleting the capability-gate scope block is REJECTED in [$doc]"
    Assert-Mutation 'drop-risk-upgrade' $doc 'content-preserved' 'none' '' '' `
        "TEST-MUT silently dropping pre-existing risk-upgrade content is REJECTED in [$doc]"
}
Assert-Mutation 'handshake-after-contract' $DocShip 'handshake-before-contract' 'none' '' '' `
    'TEST-MUT moving the handshake AFTER track resolution is REJECTED (AC-035 entry-point ordering)'

# ===========================================================================
# Self-registration (REQ-011 / design.md Test Strategy item 11).
# ===========================================================================
Write-Output '--- self-registration ---'
$runAllSh = [IO.File]::ReadAllText((Join-Path $Root 'tests/run-all.sh'))
$runAllPs1 = [IO.File]::ReadAllText((Join-Path $Root 'tests/run-all.ps1'))
Assert-True ($runAllSh.Contains('tests/ship-track-selection-migration.tests.sh')) `
    'self-registration: tests/ship-track-selection-migration.tests.sh registered in tests/run-all.sh'
Assert-True ($runAllPs1.Contains('tests/ship-track-selection-migration.tests.ps1')) `
    'self-registration: tests/ship-track-selection-migration.tests.ps1 registered in tests/run-all.ps1'
Assert-True (Test-Path -LiteralPath (Join-Path $Root 'tests/ship-track-selection-migration.tests.sh')) `
    'self-registration: tests/ship-track-selection-migration.tests.sh twin exists'

Write-Output "PASS: $($script:PassCount)"
Write-Output "FAIL: $($script:FailCount)"
if ($script:FailCount -gt 0) { exit 1 }
exit 0

} finally {
    Set-Location -LiteralPath $Root
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}
