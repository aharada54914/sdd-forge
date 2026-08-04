# T-011 (epic-189-a1-project-context, REQ-009): acceptance checks for the
# ADR-0023 track-selection contract as documented in PLUGIN-CONTRACTS.md and
# in the THREE UNPROTECTED migrated consumer skills.
#
# PowerShell parity port of tests/plugin-contracts-track-selection.tests.sh.
# See that file's header for the full TEST-024/TEST-026/TEST-039/TEST-035P/
# TEST-MUT <-> AC mapping, the unprotected-half scope note, and the
# fixture-path convention (registry/sidecar fixtures deliberately avoid the
# PROTECTED-MANIFEST suffixes so an agent session can still maintain them).
#
# Deliberate implementation DIVERGENCE from the .sh twin (a variant axis, not
# duplication): the .sh suite extracts and validates the contract table with a
# PYTHON helper; this suite reimplements the extractor NATIVELY in PowerShell
# and derives its own expectations independently. A parser defect that survives
# one reading -- a mis-skipped alignment row, a cell whose backticks are only
# stripped by one implementation, a table whose closing marker is matched
# greedily -- is caught by the other. The fixture lane still drives the REAL
# generate-approval-sidecar.py / validate-approval-sidecar.py, because those
# tools ARE the production behavior under observation.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("plugin-contracts-track-selection-test-" + [Guid]::NewGuid().ToString('N'))
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
$TestKey = 't011-track-selection-test-key'

$ContractOpen = '<!-- sdd:track-selection-contract v1 -->'
$ContractClose = '<!-- /sdd:track-selection-contract -->'
$HandshakeOpen = '<!-- sdd:handshake-wiring v1 -->'
$HandshakeClose = '<!-- /sdd:handshake-wiring -->'

$DocContracts = 'PLUGIN-CONTRACTS.md'
$DocBootstrap = 'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md'
$DocInterviewer = 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
$DocLiteGate = 'plugins/sdd-lite/skills/lite-gate/SKILL.md'
$ConsumerDocs = @($DocBootstrap, $DocInterviewer, $DocLiteGate)
$AllDocs = @($DocContracts) + $ConsumerDocs

# ADR-0023 / AC-024 / AC-039, transcribed HERE in the test. Never read back out
# of a document -- a document that supplied its own expectation would make the
# comparison an echo of its own input.
$ExpectedRows = @(
    @('C1', 'physically absent', '--full, --lite, or none', 'COMPATIBILITY_FALLBACK'),
    @('C2', 'physically present, REQ-005 validation fails', '--full, --lite, or none', 'PROJECT_CONTEXT_INVALID'),
    @('C3', 'physically present and valid, spec_profile: lite', '--full', 'PROMOTE_FULL'),
    @('C4', 'physically present and valid, spec_profile: lite', '--lite', 'NO_OP_LITE'),
    @('C5', 'physically present and valid, spec_profile: full', '--lite', 'ERROR_STOP'),
    @('C6', 'physically present and valid, spec_profile: full', '--full', 'NO_OP_FULL')
)

$HandshakeTokens = @(
    'check-hook-activation-handshake',
    '--emit-challenge',
    '--verify-response',
    ('sdd/.hook-canary-' + 'sentinel'),
    'HOOK_ACTIVE',
    'CAPABILITY_RUNTIME_UNAVAILABLE'
)

$FallbackHeading = 'Compatibility fallback (no Project Context)'
$FallbackSteps = @('`--full`', '`--lite`', '`spec_profile: lite`', 'Default')
$InterviewerGates = @(
    '## Specification Review Gate',
    '## Implementation Policy Review Gate',
    '## Task Decomposition Review Gate'
)
$InterviewerGateMarker = 'resolved track'
$LegacyGatePhrases = @(
    'If `spec_profile: lite` in AGENTS.md → SKIP',
    'Check AGENTS.md spec_profile. If lite → SKIP'
)

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
    return @{ Body = $Text.Substring($start + $OpenMarker.Length, $end - $start - $OpenMarker.Length) }
}

# Native PowerShell table parser -- deliberately NOT a call into the .sh
# suite's Python helper.
function Get-ContractRows([string]$RootDir, [string]$Rel) {
    $text = Get-DocText $RootDir $Rel
    $block = Get-Block $text $ContractOpen $ContractClose
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
        if ($joined -match '^[-: ]*$') { continue }      # alignment row
        if ($cells[0].ToLower() -eq 'case') { continue }  # header row
        [void]$rows.Add($cells)
    }
    if ($rows.Count -eq 0) { return @{ Error = 'contract block contains no data rows' } }
    return @{ Rows = $rows }
}

# The conformance checker. Returns a list of finding strings shaped
# "OK|<doc>|<check>" / "BAD|<doc>|<check>|<detail>", so the mutation lane can
# assert on a SPECIFIC finding rather than on "something went wrong".
function Get-Findings([string]$RootDir) {
    $findings = New-Object System.Collections.ArrayList
    function Add-Verdict([bool]$Cond, [string]$Doc, [string]$Check, [string]$Detail) {
        if ($Cond) { [void]$findings.Add("OK|$Doc|$Check") }
        else { [void]$findings.Add("BAD|$Doc|$Check|$Detail") }
    }

    foreach ($rel in $AllDocs) {
        $parsed = Get-ContractRows $RootDir $rel
        if ($parsed.Error) {
            Add-Verdict $false $rel 'contract-block-present' $parsed.Error
            Add-Verdict $false $rel 'contract-table-exact' "not parseable: $($parsed.Error)"
            continue
        }
        Add-Verdict $true $rel 'contract-block-present' ''
        $rows = $parsed.Rows
        $detail = ''
        if ($rows.Count -ne $ExpectedRows.Count) {
            $detail = "$($rows.Count) rows, expected $($ExpectedRows.Count)"
        } else {
            for ($i = 0; $i -lt $rows.Count; $i++) {
                $got = $rows[$i]; $want = $ExpectedRows[$i]
                for ($c = 0; $c -lt 4; $c++) {
                    if ($got[$c] -cne $want[$c]) {
                        $detail = "row $($want[0]) cell $c" + ": got [$($got[$c])], expected [$($want[$c])]"
                        break
                    }
                }
                if ($detail) { break }
            }
        }
        Add-Verdict ($detail -eq '') $rel 'contract-table-exact' $detail
    }

    # The wiring is asserted in the contract document too: AC-035 binds the
    # three consumer entry points, but a normative requirement that lives only
    # in the consumers has no single place a later epic's new entry point can
    # be checked against (REQ-010's future-entry-point contract).
    foreach ($rel in $AllDocs) {
        $text = Get-DocText $RootDir $rel
        $block = Get-Block $text $HandshakeOpen $HandshakeClose
        if ($block.Error) {
            Add-Verdict $false $rel 'handshake-block-present' $block.Error
            Add-Verdict $false $rel 'handshake-tokens' "no block: $($block.Error)"
            continue
        }
        Add-Verdict $true $rel 'handshake-block-present' ''
        $missing = @($HandshakeTokens | Where-Object { -not $block.Body.Contains($_) })
        Add-Verdict ($missing.Count -eq 0) $rel 'handshake-tokens' ("missing token(s): " + ($missing -join ', '))
    }

    # PLUGIN-CONTRACTS.md only: AC-024's retitling and ordering.
    $text = Get-DocText $RootDir $DocContracts
    if ($null -eq $text) {
        Add-Verdict $false $DocContracts 'fallback-retitled' 'unreadable'
        Add-Verdict $false $DocContracts 'fallback-after-contract' 'unreadable'
        Add-Verdict $false $DocContracts 'fallback-steps' 'unreadable'
    } else {
        $headingAt = $text.IndexOf($FallbackHeading)
        $closeAt = $text.IndexOf($ContractClose)
        Add-Verdict ($headingAt -ge 0) $DocContracts 'fallback-retitled' "heading '$FallbackHeading' absent"
        Add-Verdict (($headingAt -ge 0) -and ($closeAt -ge 0) -and ($headingAt -gt $closeAt)) `
            $DocContracts 'fallback-after-contract' `
            "compatibility fallback must follow the four-case rule (heading at $headingAt, contract block ends at $closeAt)"
        if ($headingAt -ge 0) {
            $tailLen = [Math]::Min(1200, $text.Length - $headingAt)
            $tail = $text.Substring($headingAt, $tailLen)
            $missing = @($FallbackSteps | Where-Object { -not $tail.Contains($_) })
            Add-Verdict ($missing.Count -eq 0) $DocContracts 'fallback-steps' ("missing step(s): " + ($missing -join ', '))
        } else {
            Add-Verdict $false $DocContracts 'fallback-steps' 'no fallback section to inspect'
        }
    }

    # sdd-bootstrap-interviewer's three spec_profile read sites.
    $itext = Get-DocText $RootDir $DocInterviewer
    if ($null -eq $itext) {
        Add-Verdict $false $DocInterviewer 'gates-migrated' 'unreadable'
        Add-Verdict $false $DocInterviewer 'legacy-gating-removed' 'unreadable'
    } else {
        $unmigrated = New-Object System.Collections.ArrayList
        foreach ($heading in $InterviewerGates) {
            $at = $itext.IndexOf($heading)
            if ($at -lt 0) { [void]$unmigrated.Add("$heading (section absent)"); continue }
            $nxt = $itext.IndexOf("`n## ", $at + 1)
            $section = if ($nxt -gt 0) { $itext.Substring($at, $nxt - $at) } else { $itext.Substring($at) }
            if (-not $section.ToLower().Contains($InterviewerGateMarker)) { [void]$unmigrated.Add($heading) }
        }
        Add-Verdict ($unmigrated.Count -eq 0) $DocInterviewer 'gates-migrated' `
            ("gate(s) not gating on the resolved track: " + ($unmigrated -join '; '))
        $survivors = @($LegacyGatePhrases | Where-Object { $itext.Contains($_) })
        Add-Verdict ($survivors.Count -eq 0) $DocInterviewer 'legacy-gating-removed' `
            ("pre-migration phrasing survives: " + ($survivors -join '; '))
    }

    return $findings
}

# ===========================================================================
# TEST-024 / TEST-035P / TEST-039 (document half): live document conformance.
# ===========================================================================
Write-Output '--- TEST-024/TEST-035P/TEST-039: live document conformance ---'
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

# The physical-presence probe REQ-009 mandates FIRST -- a plain filesystem
# test, with no validator involvement.
function Get-ContextPresence([string]$Name) {
    if (Test-Path -LiteralPath (Join-Path $Fx "$Name/sdd/project-context.yaml")) { return 'present' }
    return 'absent'
}

# spec_profile read back OFF DISK, natively, rather than from the variable the
# fixture was built with.
function Get-DiskProfile([string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $Fx "$Name/sdd/project-context.yaml"))
    $m = [regex]::Match($text, '(?m)^\s+spec_profile:\s*(\S+)\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    return 'MISSING'
}

# The resolution THAT DOCUMENT documents, for a given case id.
function Get-DocResolution([string]$Rel, [string]$CaseId) {
    $parsed = Get-ContractRows $Root $Rel
    if ($parsed.Error) { return '' }
    foreach ($row in $parsed.Rows) { if ($row[0] -eq $CaseId) { return $row[3] } }
    return ''
}

Write-Output '--- TEST-026/TEST-039: fixture construction ---'
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

# One flipped hex character in the signature -- native, no Python helper.
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
    "TEST-026 fixture: the no-Context project's $Ctx is physically ABSENT"
Assert-Eq (Get-ContextPresence 'valid-full') 'present' `
    "TEST-026 fixture: the full-profile project's $Ctx is physically PRESENT"
Assert-Eq (Get-DiskProfile 'valid-full') 'full' `
    "TEST-039 fixture: the full-profile project's on-disk spec_profile reads 'full'"
Assert-Eq (Get-DiskProfile 'valid-lite') 'lite' `
    "TEST-039 fixture: the lite-profile project's on-disk spec_profile reads 'lite'"

Assert-Eq (Invoke-Validate 'valid-full' $Ctx 'fixtures/approval.json' $Reg) 0 `
    "TEST-039 fixture: the full-profile project's sidecar PASSES validate-approval-sidecar"
Assert-Eq (Invoke-Validate 'valid-lite' $Ctx 'fixtures/approval.json' $Reg) 0 `
    "TEST-039 fixture: the lite-profile project's sidecar PASSES validate-approval-sidecar"

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
# TEST-039: six-case matrix x four documents.
# ===========================================================================
Write-Output '--- TEST-039: six-case matrix x four documents ---'
$CaseExpectations = @(
    @('C1', 'COMPATIBILITY_FALLBACK', 'physically absent -> COMPATIBILITY_FALLBACK'),
    @('C2', 'PROJECT_CONTEXT_INVALID', 'present-but-invalid -> PROJECT_CONTEXT_INVALID'),
    @('C3', 'PROMOTE_FULL', 'lite + --full -> PROMOTE_FULL'),
    @('C4', 'NO_OP_LITE', 'lite + --lite -> NO_OP_LITE'),
    @('C5', 'ERROR_STOP', 'full + --lite -> ERROR_STOP (never a silent downgrade)'),
    @('C6', 'NO_OP_FULL', 'full + --full -> NO_OP_FULL')
)
foreach ($doc in $AllDocs) {
    foreach ($case in $CaseExpectations) {
        Assert-Eq (Get-DocResolution $doc $case[0]) $case[1] `
            "TEST-039 [$doc] $($case[0]) $($case[2])"
    }
}

Write-Output '--- TEST-026: the two routes are genuinely distinct ---'
foreach ($doc in $AllDocs) {
    $r1 = Get-DocResolution $doc 'C1'
    $r2 = Get-DocResolution $doc 'C2'
    Assert-True (($r1 -ne '') -and ($r2 -ne '') -and ($r1 -ne $r2)) `
        "TEST-026 [$doc] the absent route and the present-but-invalid route resolve DIFFERENTLY" `
        "C1=[$r1] C2=[$r2]"
}

# ===========================================================================
# TEST-MUT: detection power, as a DELTA over a pristine copy.
# ===========================================================================
Write-Output '--- TEST-MUT: mutation detection power ---'
function Copy-DocsTo([string]$Dest) {
    foreach ($d in $AllDocs) {
        $target = Join-Path $Dest $d
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $Root $d) -Destination $target -Force
    }
}

$Pristine = Join-Path $Work 'pristine'
Copy-DocsTo $Pristine
$pristineFindings = Get-Findings $Pristine
$pristineBad = @($pristineFindings | Where-Object { $_.StartsWith('BAD|') })
$PristineOk = ($pristineBad.Count -eq 0)
Assert-True $PristineOk `
    'TEST-MUT baseline: the pristine document copy CONFORMS (mutations below are measurable)' `
    "$($pristineBad.Count) finding(s)"

function Get-RowLine([string]$Text, [string]$CaseId) {
    foreach ($line in ($Text -split "`n")) {
        if ($line.Trim().StartsWith("| $CaseId ")) { return $line }
    }
    return $null
}

function Invoke-Mutation([string]$Dir, [string]$Name, [string]$Doc) {
    $path = Join-Path $Dir $Doc
    $text = [IO.File]::ReadAllText($path)
    $before = $text
    switch ($Name) {
        'c2-to-fallback' {
            $row = Get-RowLine $text 'C2'
            if ($row) { $text = $text.Replace($row, $row.Replace('PROJECT_CONTEXT_INVALID', 'COMPATIBILITY_FALLBACK')) }
        }
        'c5-silent-downgrade' {
            $row = Get-RowLine $text 'C5'
            if ($row) { $text = $text.Replace($row, $row.Replace('ERROR_STOP', 'NO_OP_LITE')) }
        }
        'drop-c2' {
            $row = Get-RowLine $text 'C2'
            if ($row) { $text = $text.Replace($row + "`n", '') }
        }
        'swap-c1-c2-state' {
            $r1 = Get-RowLine $text 'C1'
            $r2 = Get-RowLine $text 'C2'
            if ($r1 -and $r2) {
                $c1 = @($r1.Trim('|') -split '\|')
                $c2 = @($r2.Trim('|') -split '\|')
                $tmp = $c1[1]; $c1[1] = $c2[1]; $c2[1] = $tmp
                $text = $text.Replace($r1, '|' + ($c1 -join '|') + '|')
                $text = $text.Replace($r2, '|' + ($c2 -join '|') + '|')
            }
        }
        'drop-handshake' {
            $text = $text.Replace($HandshakeOpen, '<!-- handshake wiring removed -->')
        }
        'table-after-fallback' {
            $start = $text.IndexOf($ContractOpen)
            $end = $text.IndexOf($ContractClose)
            if ($start -ge 0 -and $end -ge 0) {
                $block = $text.Substring($start, $end + $ContractClose.Length - $start)
                $text = $text.Substring(0, $start) + $text.Substring($end + $ContractClose.Length) + "`n" + $block + "`n"
            }
        }
        'restore-legacy-gate' {
            $text = $text.Replace('## Specification Review Gate',
                "## Specification Review Gate`n`n1. If ``spec_profile: lite`` in AGENTS.md → SKIP.")
        }
        default { return "unknown mutation '$Name'" }
    }
    if ($text -ceq $before) { return "mutation '$Name' changed nothing in $Doc" }
    [IO.File]::WriteAllText($path, $text)
    return $null
}

$script:MutSeq = 0
function Assert-Mutation([string]$Name, [string]$Doc, [string]$FindDoc, [string]$Check, [string]$Label) {
    $dir = Join-Path $Work ("mut/" + $Name + '-' + ($Doc -replace '[/.]', '_'))
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    Copy-DocsTo $dir
    $err = Invoke-Mutation $dir $Name $Doc
    if ($err) { Test-Fail $Label "mutation could not be applied: $err"; return }
    $findings = Get-Findings $dir
    $bad = @($findings | Where-Object { $_.StartsWith('BAD|') })
    if (-not $PristineOk) {
        Test-Fail $Label 'not measurable: the pristine baseline does not conform'
    } elseif ($bad.Count -eq 0) {
        Test-Fail $Label 'mutated copy still CONFORMED -- the check has no detection power'
    } elseif (@($bad | Where-Object { $_.StartsWith("BAD|$FindDoc|$Check|") }).Count -gt 0) {
        Test-Pass $Label
    } else {
        Test-Fail $Label "rejected, but not by $FindDoc/$Check`: $($bad[0])"
    }
}

Assert-Mutation 'c2-to-fallback' $DocContracts $DocContracts 'contract-table-exact' `
    'TEST-MUT (1) routing C2 to the compatibility fallback is REJECTED (the B5 fail-open defect)'
Assert-Mutation 'c5-silent-downgrade' $DocContracts $DocContracts 'contract-table-exact' `
    'TEST-MUT (2) honoring --lite against a full profile is REJECTED (the ADR-0023 silent downgrade)'
Assert-Mutation 'drop-c2' $DocContracts $DocContracts 'contract-table-exact' `
    'TEST-MUT (3) deleting the present-but-invalid case entirely is REJECTED'
Assert-Mutation 'swap-c1-c2-state' $DocContracts $DocContracts 'contract-table-exact' `
    'TEST-MUT (4) swapping the absent and present-but-invalid preconditions is REJECTED'
Assert-Mutation 'table-after-fallback' $DocContracts $DocContracts 'fallback-after-contract' `
    'TEST-MUT (5) demoting the four-case rule below the compatibility fallback is REJECTED (AC-024 ordering)'
Assert-Mutation 'restore-legacy-gate' $DocInterviewer $DocInterviewer 'legacy-gating-removed' `
    'TEST-MUT (6) restoring a pre-migration AGENTS.md gate phrase is REJECTED'

$mutN = 6
foreach ($doc in $ConsumerDocs) {
    $mutN++
    Assert-Mutation 'c5-silent-downgrade' $doc $doc 'contract-table-exact' `
        "TEST-MUT ($mutN) the silent-downgrade defect is caught in [$doc] specifically"
}
foreach ($doc in $ConsumerDocs) {
    $mutN++
    Assert-Mutation 'drop-handshake' $doc $doc 'handshake-block-present' `
        "TEST-MUT ($mutN) removing the handshake wiring is caught in [$doc] specifically"
}

# ===========================================================================
# Self-registration (REQ-011 / design.md Test Strategy item 11).
# ===========================================================================
Write-Output '--- self-registration ---'
$runAllSh = [IO.File]::ReadAllText((Join-Path $Root 'tests/run-all.sh'))
$runAllPs1 = [IO.File]::ReadAllText((Join-Path $Root 'tests/run-all.ps1'))
Assert-True ($runAllSh.Contains('tests/plugin-contracts-track-selection.tests.sh')) `
    'self-registration: tests/plugin-contracts-track-selection.tests.sh registered in tests/run-all.sh'
Assert-True ($runAllPs1.Contains('tests/plugin-contracts-track-selection.tests.ps1')) `
    'self-registration: tests/plugin-contracts-track-selection.tests.ps1 registered in tests/run-all.ps1'
Assert-True (Test-Path -LiteralPath (Join-Path $Root 'tests/plugin-contracts-track-selection.tests.sh')) `
    'self-registration: tests/plugin-contracts-track-selection.tests.sh twin exists'

Write-Output "PASS: $script:PassCount"
Write-Output "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 }
exit 0

} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
