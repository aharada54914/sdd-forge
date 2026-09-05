[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Manifest,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [switch]$Reserve
)

$ErrorActionPreference = 'Stop'

function Fail-ReviewContext {
    param([string]$Category, [string]$Message)
    [Console]::Error.WriteLine("REVIEW_CONTEXT_${Category}: $Message")
    exit 1
}

function Test-ExactKeys {
    param([hashtable]$Value, [string[]]$Expected)
    if ($null -eq $Value) { return $false }
    $actual = @($Value.Keys | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    return (($actual -join "`n") -ceq ($wanted -join "`n"))
}

function Test-CanonicalPath {
    param([string]$Path)
    return (
        $Path -is [string] -and
        $Path -cmatch '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$' -and
        $Path -cnotmatch '(^|/)\.\.?(/|$)' -and
        $Path -cnotmatch '^[A-Za-z]:' -and
        -not $Path.Contains('\')
    )
}

function Test-CanonicalScratchRoot {
    param([string]$Path)
    return ($Path -is [string] -and
        ($Path -cmatch '^/([^/]+/)*[^/]+$' -or $Path -cmatch '^[A-Za-z]:/([^/]+/)*[^/]+$') -and
        $Path -cnotmatch '(^|/)\.\.?(/|$)' -and -not $Path.Contains('\') -and
        -not $Path.EndsWith('/'))
}

function Test-ScratchRootsOverlap {
    param([string]$Left, [string]$Right)
    $comparison = if ($Left -cmatch '^[A-Za-z]:/' -and $Right -cmatch '^[A-Za-z]:/') {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }
    return ($Left.Equals($Right, $comparison) -or
        $Left.StartsWith("$Right/", $comparison) -or
        $Right.StartsWith("$Left/", $comparison))
}

function Test-JsonInteger {
    param([object]$Value)
    if ($Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]) {
        return $true
    }
    if ($Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return [Math]::Truncate([decimal]$Value) -eq [decimal]$Value
    }
    return $false
}

function Get-Sha256Text {
    param([string]$Value)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([Convert]::ToHexString($hasher.ComputeHash($bytes))).ToLowerInvariant()
    }
    finally {
        $hasher.Dispose()
    }
}

# WFI-025: the STATUS-NORMALIZED task-plan digest -- byte-for-byte the same
# recipe as check-workflow-state.ps1 Get-NormalizedHash for the task stage
# (canonical form 1). The one scoped exception to the raw hash-equality rule
# in the manifest-entry loop is defined over exactly the fields this
# normalization rewrites.
function Get-TasksNormalizedHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    $text = [regex]::Replace($text, "(?m)^Task-Review-Status:[^\r\n]*(\r?)$", 'Task-Review-Status: Pending$1')
    $text = [regex]::Replace($text, "(?m)^Approval:[^\r\n]*(\r?)$", 'Approval: Draft$1')
    $text = [regex]::Replace($text, "(?m)^Status:[^\r\n]*(\r?)$", 'Status: Planned$1')
    $text = [regex]::Replace($text, "(?m)^Second Approval:[^\r\n]*\r?\n?", '')
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Test-AuthorizedPath {
    param(
        [string]$Stage,
        [string]$Role,
        [string]$Feature,
        [string]$Path,
        [string]$Sha256,
        [Collections.Generic.HashSet[string]]$EvaluatorOutputs,
        [string]$ImplementationReportPath,
        [Collections.Generic.HashSet[string]]$GateReportOutputs
    )
    $escapedFeature = [Regex]::Escape($Feature)
    switch ("${Stage}:${Role}") {
        { $_ -in @('spec:spec-reviewer-a', 'spec:spec-reviewer-b') } {
            if ($Path -cmatch "^specs/$escapedFeature/(requirements|acceptance-tests|investigation)\.md$" -or
                $Path -ceq 'plugins/sdd-review-loop/references/spec-review-calibration.md' -or
                $Path -cmatch "^reports/spec-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$") {
                return $true
            }
            return ($Role -ceq 'spec-reviewer-b' -and
                $Path -cmatch "^reports/spec-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$")
        }
        { $_ -in @('impl:impl-reviewer-a', 'impl:impl-reviewer-b') } {
            # Issue #143: impl-review-precheck requires impl-reviewer-a to carry
            # the PREVIOUS round's integrated-summary.json when round > 1, so the
            # summary must be authorized for both reviewer roles. Without this,
            # reviewer-a's required input is rejected as role-unlisted and
            # impl-review can never pass at round > 1. The precheck contract still
            # pins reviewer-a to the exact previous round (defense-in-depth).
            if ($Path -cmatch "^specs/$escapedFeature/(requirements|acceptance-tests|design|investigation|ux-spec|frontend-spec|infra-spec|security-spec)\.md$" -or
                $Path -ceq 'plugins/sdd-review-loop/references/reviewer-calibration.md' -or
                $Path -cmatch "^reports/impl-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$") {
                return $true
            }
            return ($Path -cmatch "^reports/impl-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$")
        }
        { $_ -in @('task:task-reviewer-a', 'task:task-reviewer-b') } {
            if ($Path -cmatch "^specs/$escapedFeature/(requirements|acceptance-tests|design|tasks|traceability|ux-spec|frontend-spec|infra-spec|security-spec)\.md$" -or
                $Path -ceq 'plugins/sdd-review-loop/references/reviewer-calibration.md' -or
                $Path -cmatch "^reports/task-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$") {
                return $true
            }
            if ($Role -ceq 'task-reviewer-a') {
                return $Path -cmatch "^reports/task-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/dependency-graph\.json$"
            }
            return (
                $Path -cmatch '^plugins/sdd-quality-loop/references/(risk-gate-matrix|risk-classification-policy)\.md$' -or
                $Path -cmatch "^reports/task-review/$escapedFeature/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$"
            )
        }
        'quality:sdd-evaluator' {
            if ($Path -cmatch "^specs/$escapedFeature/(requirements|acceptance-tests|design|tasks|traceability|baseline-behavior|ux-spec|frontend-spec|infra-spec|security-spec)\.(md|json)$" -or
                $Path -ceq 'plugins/sdd-quality-loop/references/quality-gate-calibration.md' -or
                $Path -ceq $ImplementationReportPath -or
                $EvaluatorOutputs.Contains("$Path`n$Sha256")) {
                return $true
            }
            # WFI-036 second channel. $GateReportOutputs is empty unless the
            # manifest named a gate report AND that document's own SHA-256
            # already matched the pinned value, so an unnamed or stale report
            # authorizes nothing. A gate report never authorizes another gate
            # report: handing an evaluator a prior verdict would defeat the
            # fresh-context requirement it is launched under.
            if ($Path -cmatch '^reports/quality-gate/') {
                return $false
            }
            return $GateReportOutputs.Contains("$Path`n$Sha256")
        }
        { $_ -in @('domain:domain-reviewer-a', 'domain:domain-reviewer-b') } {
            if ($Path -cmatch '^domain/(domain-story|event-storming|ubiquitous-language|context-map|message-flow|c4-container)\.md$' -or
                $Path -cmatch '^domain/aggregates/[^/]+\.md$' -or
                $Path -ceq 'domain/domain-contract.json' -or
                $Path -ceq 'plugins/sdd-domain/references/domain-review-calibration.md' -or
                $Path -cmatch '^reports/domain-review/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$') {
                return $true
            }
            return ($Role -ceq 'domain-reviewer-b' -and
                $Path -cmatch '^reports/domain-review/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$')
        }
        default { return $false }
    }
}

try {
    if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf) -or
        $null -ne (Get-Item -LiteralPath $Manifest -Force).LinkType) {
        Fail-ReviewContext 'MANIFEST' 'manifest is missing or is not a regular file'
    }
    if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
        Fail-ReviewContext 'PATH' 'repository root is missing'
    }
    $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepositoryRoot).Path)
    $rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    try {
        $document = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    }
    catch {
        Fail-ReviewContext 'JSON' 'manifest is not valid JSON'
    }

    $baseTopKeys = @(
        'schema', 'stage', 'role', 'feature', 'run_id', 'host_session_id',
        'read_only', 'input_mode', 'fallback_mode', 'identity_ledger_path',
        'identity_ledger_sha256', 'previous_record_sha256', 'sequence',
        'allowed_input_manifest'
    )
    # WFI-036: gate_report_declaration is optional and quality-only. Any other
    # stage carrying it fails the exact-key comparison below.
    $topKeys = @($baseTopKeys)
    if ($document.stage -ceq 'quality') {
        $topKeys = @($baseTopKeys) + @('task_id')
        if ($document.ContainsKey('gate_report_declaration')) {
            $topKeys = @($topKeys) + @('gate_report_declaration')
        }
        if ($document.ContainsKey('scratch_root')) {
            $topKeys = @($topKeys) + @('scratch_root')
        }
    }
    if (-not (Test-ExactKeys $document $topKeys) -or
        $document.schema -cne 'review-context-invocation/v2' -or
        $document.input_mode -cne 'file-manifest' -or
        $document.fallback_mode -cne 'none' -or
        $document.read_only -isnot [bool] -or -not $document.read_only -or
        $document.feature -isnot [string] -or $document.feature -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
        $document.identity_ledger_path -cne 'reports/review-context/identity-ledger.json' -or
        $document.identity_ledger_sha256 -isnot [string] -or $document.identity_ledger_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        $document.previous_record_sha256 -isnot [string] -or $document.previous_record_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        -not (Test-JsonInteger $document.sequence) -or
        [decimal]$document.sequence -lt 2 -or
        $document.allowed_input_manifest -isnot [array] -or
        $document.allowed_input_manifest.Count -eq 0) {
        Fail-ReviewContext 'CONTRACT' 'required fields, file-manifest input, read-only mode, or no-fallback contract is invalid'
    }
    if ($document.stage -ceq 'quality' -and
        ($document.task_id -isnot [string] -or $document.task_id -cnotmatch '^T-[0-9]{3}$')) {
        Fail-ReviewContext 'CONTRACT' 'quality invocation requires a canonical task ID'
    }
    if ($document.ContainsKey('scratch_root') -and -not (Test-CanonicalScratchRoot $document.scratch_root)) {
        Fail-ReviewContext 'CONTRACT' 'scratch_root must be a canonical absolute path'
    }
    $gateReportDeclarationPath = ''
    $gateReportDeclarationSha256 = ''
    if ($document.ContainsKey('gate_report_declaration')) {
        $gateReportDeclaration = $document.gate_report_declaration
        if ($gateReportDeclaration -isnot [hashtable] -or
            -not (Test-ExactKeys $gateReportDeclaration @('path', 'sha256')) -or
            $gateReportDeclaration.path -isnot [string] -or
            $gateReportDeclaration.path.Length -eq 0 -or
            $gateReportDeclaration.sha256 -isnot [string] -or
            $gateReportDeclaration.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            Fail-ReviewContext 'CONTRACT' 'gate-report declaration must carry exactly one path and its lowercase SHA-256'
        }
        $gateReportDeclarationPath = $gateReportDeclaration.path
        $gateReportDeclarationSha256 = $gateReportDeclaration.sha256
    }

    $validPairs = @(
        'spec:spec-reviewer-a', 'spec:spec-reviewer-b',
        'impl:impl-reviewer-a', 'impl:impl-reviewer-b',
        'task:task-reviewer-a', 'task:task-reviewer-b',
        'quality:sdd-evaluator',
        'domain:domain-reviewer-a', 'domain:domain-reviewer-b'
    )
    if ("$($document.stage):$($document.role)" -cnotin $validPairs) {
        Fail-ReviewContext 'CONTRACT' 'stage and role are not an authorized invocation pair'
    }
    foreach ($identity in @($document.run_id, $document.host_session_id)) {
        if ($identity -isnot [string] -or $identity -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$') {
            Fail-ReviewContext 'IDENTITY' 'run and host-session IDs must be nonblank canonical identifiers'
        }
    }

    $ledger = Join-Path $root 'reports/review-context/identity-ledger.json'
    $ledgerComponent = $root
    foreach ($component in @('reports', 'review-context', 'identity-ledger.json')) {
        $ledgerComponent = Join-Path $ledgerComponent $component
        if (Test-Path -LiteralPath $ledgerComponent) {
            if ($null -ne (Get-Item -LiteralPath $ledgerComponent -Force).LinkType) {
                Fail-ReviewContext 'IDENTITY' 'canonical identity ledger traverses a symbolic link'
            }
        }
    }
    if (-not (Test-Path -LiteralPath $ledger -PathType Leaf) -or
        $null -ne (Get-Item -LiteralPath $ledger -Force).LinkType) {
        Fail-ReviewContext 'IDENTITY' 'canonical identity ledger is missing or is not a regular file'
    }
    # NOTE: identity_ledger_sha256 is only meaningful for a reservation (the
    # ledger state a reservation is validated against, before it appends). It
    # is NOT checked here unconditionally -- see the reservation/verification
    # branch below, which is the only place this comparison is enforced.
    $actualLedgerHash = (Get-FileHash -LiteralPath $ledger -Algorithm SHA256).Hash.ToLowerInvariant()
    try {
        $ledgerDocument = Get-Content -LiteralPath $ledger -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    }
    catch {
        Fail-ReviewContext 'IDENTITY' 'canonical identity ledger is invalid JSON'
    }
    if (-not (Test-ExactKeys $ledgerDocument @('schema', 'records')) -or
        $ledgerDocument.schema -cne 'review-identity-ledger/v1') {
        Fail-ReviewContext 'IDENTITY' 'canonical identity ledger contract is invalid'
    }
    if ($ledgerDocument.records -isnot [array]) {
        Fail-ReviewContext 'IDENTITY' 'canonical identity ledger records must be an array'
    }
    $records = @($ledgerDocument.records)
    if ($records.Count -eq 0) {
        Fail-ReviewContext 'IDENTITY' 'canonical identity ledger must contain prior host identity'
    }
    $runs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $sessions = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $expectedSequence = 1L
    $expectedPrevious = ''
    $recordKeys = @(
        'sequence', 'stage', 'role', 'run_id', 'host_session_id',
        'previous_record_sha256', 'record_sha256'
    )
    foreach ($record in $records) {
        if ($record -isnot [hashtable] -or -not (Test-ExactKeys $record $recordKeys) -or
            -not (Test-JsonInteger $record.sequence) -or
            [decimal]$record.sequence -ne $expectedSequence -or
            $record.stage -isnot [string] -or $record.stage -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or
            $record.role -isnot [string] -or $record.role -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or
            $record.run_id -isnot [string] -or $record.run_id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or
            $record.host_session_id -isnot [string] -or $record.host_session_id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or
            $record.previous_record_sha256 -cne $expectedPrevious -or
            $record.record_sha256 -isnot [string] -or $record.record_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            -not $runs.Add($record.run_id) -or -not $sessions.Add($record.host_session_id)) {
            Fail-ReviewContext 'IDENTITY' 'canonical identity ledger chain is invalid'
        }
        $canonical = "$($record.sequence)|$($record.stage)|$($record.role)|$($record.run_id)|$($record.host_session_id)|$($record.previous_record_sha256)"
        if ((Get-Sha256Text $canonical) -cne $record.record_sha256) {
            Fail-ReviewContext 'IDENTITY' 'canonical identity ledger record hash is invalid'
        }
        $expectedPrevious = $record.record_sha256
        $expectedSequence++
    }
    # A manifest describes either an identity not yet in the ledger (a
    # reservation) or an identity whose record is already persisted (a
    # verification of a prior reservation -- possibly with later records now
    # chained on top of it, e.g. a branch merge/re-chain). The ledger itself
    # disambiguates which case this is: an identity is "reserved" once some
    # record's run_id AND host_session_id both match the manifest's. That,
    # not the -Reserve switch, decides which checks below apply.
    $persistedMatch = $records | Where-Object {
        $_.run_id -ceq $document.run_id -and $_.host_session_id -ceq $document.host_session_id
    } | Select-Object -First 1

    if ($null -ne $persistedMatch) {
        # Verification of an already-reserved identity. The persisted record
        # is authoritative and must match the manifest exactly on every
        # identity field; its own record_sha256 was already proven to
        # recompute correctly by the whole-ledger chain walk above, which
        # runs unconditionally. The tip position and identity_ledger_sha256
        # are NOT re-checked here: both are meaningless once later records
        # may have landed on top of this one.
        if ($Reserve) {
            Fail-ReviewContext 'IDENTITY' 'run and host-session identity are already persisted in the canonical identity ledger; an identity cannot be reserved twice'
        }
        if ([decimal]$persistedMatch.sequence -ne [decimal]$document.sequence) {
            Fail-ReviewContext 'IDENTITY' 'invocation sequence does not match the persisted identity-ledger record'
        }
        if ($persistedMatch.stage -cne $document.stage) {
            Fail-ReviewContext 'IDENTITY' 'invocation stage does not match the persisted identity-ledger record'
        }
        if ($persistedMatch.role -cne $document.role) {
            Fail-ReviewContext 'IDENTITY' 'invocation role does not match the persisted identity-ledger record'
        }
        if ($persistedMatch.previous_record_sha256 -cne $document.previous_record_sha256) {
            Fail-ReviewContext 'IDENTITY' 'invocation previous-record hash does not match the persisted identity-ledger record'
        }
        # WFI-037: the uniqueness the REVIEW_CONTEXT_OK line asserts must be
        # proven in this branch too, not inherited from the reserve path.
        $persistedCount = @($records | Where-Object {
            $_.run_id -ceq $document.run_id -and $_.host_session_id -ceq $document.host_session_id
        }).Count
        if ($persistedCount -ne 1) {
            Fail-ReviewContext 'IDENTITY' 'run and host-session identity appears more than once in the canonical identity ledger'
        }
        # Tip position is meaningless for a persisted verification (see
        # above), so the emitted chain fact says so explicitly.
        $preAppendTipSequence = '-'
    }
    else {
        # A partial match -- one of the two identity fields already persisted
        # under a DIFFERENT value for the other -- means two different
        # launches are colliding on one identity. That is never valid, in
        # either mode, so it fails loudly here rather than silently falling
        # into reservation mode.
        if ($records | Where-Object { $_.run_id -ceq $document.run_id -and $_.host_session_id -cne $document.host_session_id }) {
            Fail-ReviewContext 'IDENTITY' 'run ID matches a persisted identity-ledger record but host-session ID does not: two launches are colliding on one identity'
        }
        if ($records | Where-Object { $_.host_session_id -ceq $document.host_session_id -and $_.run_id -cne $document.run_id }) {
            Fail-ReviewContext 'IDENTITY' 'host-session ID matches a persisted identity-ledger record but run ID does not: two launches are colliding on one identity'
        }

        # Reservation of a new identity: today's behaviour, unchanged.
        if ($actualLedgerHash -cne $document.identity_ledger_sha256) {
            Fail-ReviewContext 'IDENTITY' 'canonical identity ledger hash is stale or mismatched'
        }
        if ([decimal]$document.sequence -ne $expectedSequence -or
            $document.previous_record_sha256 -cne $expectedPrevious) {
            Fail-ReviewContext 'IDENTITY' 'invocation does not extend the canonical identity ledger'
        }
        # WFI-037: the record extends the pre-append tip, proven just above.
        $preAppendTipSequence = [string]($expectedSequence - 1)
    }

    $inputs = @($document.allowed_input_manifest)
    $implementationReportPath = ''
    $evaluatorOutputs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $gateReportOutputs = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ("$($document.stage):$($document.role)" -ceq 'quality:sdd-evaluator') {
        $escapedFeature = [Regex]::Escape($document.feature)
        $implementationReports = @($inputs | Where-Object {
            $_ -is [hashtable] -and
            $_.path -is [string] -and
            $_.path -ceq "reports/implementation/$($document.feature)/$($document.task_id).md"
        })
        if ($implementationReports.Count -ne 1) {
            Fail-ReviewContext 'PATH' 'sdd-evaluator requires the current task implementation report'
        }
        $implementationReportPath = $implementationReports[0].path
        $implementationReport = Join-Path $root $implementationReportPath
        if (-not (Test-Path -LiteralPath $implementationReport -PathType Leaf)) {
            Fail-ReviewContext 'PATH' 'sdd-evaluator task implementation report is missing'
        }
        $implementationReportLines = @(Get-Content -LiteralPath $implementationReport -Encoding UTF8)
        if ($implementationReportLines.Count -eq 0 -or
            $implementationReportLines[0] -cne "# Implementation Report: $($document.task_id)" -or
            $implementationReportLines -cnotcontains "- Task ID: $($document.task_id)") {
            Fail-ReviewContext 'PATH' 'sdd-evaluator implementation report identity does not match task ID'
        }
        if ($document.ContainsKey('scratch_root')) {
            $scratchRootLines = @($implementationReportLines | Where-Object { $_ -cmatch '^- \*\*Scratch Root\*\*: .+$' })
            if ($scratchRootLines.Count -ne 1) {
                Fail-ReviewContext 'PATH' 'sdd-evaluator requires exactly one implementation Scratch Root when scratch_root is declared'
            }
            $implementationScratchRoot = $scratchRootLines[0].Substring('- **Scratch Root**: '.Length)
            if (-not (Test-CanonicalScratchRoot $implementationScratchRoot)) {
                Fail-ReviewContext 'PATH' 'implementation Scratch Root is not a canonical absolute path'
            }
            if (Test-ScratchRootsOverlap $document.scratch_root $implementationScratchRoot) {
                Fail-ReviewContext 'PATH' 'evaluator scratch root overlaps the implementation scratch root'
            }
        }
        $inOutputs = $false
        foreach ($line in $implementationReportLines) {
            if ($line -cmatch '^## Outputs\s*$') {
                $inOutputs = $true
                continue
            }
            if ($inOutputs -and $line -cmatch '^##\s') {
                break
            }
            if ($inOutputs -and
                $line -cmatch '^\| `(?<path>[^`]+)` \| `(?<sha>[0-9a-f]{64})` \|$') {
                [void]$evaluatorOutputs.Add("$($Matches.path)`n$($Matches.sha)")
            }
        }
        # WFI-017 ratified a second serialization for the implementation
        # report's own declaration -- the legacy '## Output Paths And Hashes'
        # bullet section, retained so previously committed bullet-only and
        # dual-form v2 reports remain valid (validate-implementation-report.sh
        # :113-119). That acceptance landed on the report contract and never on
        # this authorization boundary, so a report the repository considers
        # valid could declare artifacts this validator could not read.
        #
        # The pattern below mirrors that script's own output_pattern (:167-170)
        # byte for byte; nothing is invented here. Only the serialization
        # differs -- the pair is still matched by exact equality and the live
        # file is still re-hashed afterwards -- so this admits no artifact the
        # table form would not have admitted. Scanned in its own pass because
        # the loop above stops at the next '## ' heading and the two sections
        # may appear in either order, or the legacy one alone.
        #
        # Scoped to the implementation report on purpose: the gate report's
        # post-fix channel (WFI-036) defines its own table form and gains no
        # legacy grammar.
        $inLegacyOutputs = $false
        foreach ($line in $implementationReportLines) {
            if ($line -cmatch '^## Output Paths And Hashes\s*$') {
                $inLegacyOutputs = $true
                continue
            }
            if ($inLegacyOutputs -and $line -cmatch '^##\s') {
                break
            }
            if ($inLegacyOutputs -and
                $line -cmatch '^- \*\*Path\*\*: `(?<path>[^`]+)`; \*\*SHA-256\*\*: `(?<sha>[0-9a-f]{64})`\s*$') {
                [void]$evaluatorOutputs.Add("$($Matches.path)`n$($Matches.sha)")
            }
        }
        # WFI-036. The named gate report is a declaration source, not a manifest
        # input. It is verified in full here -- canonical path, confined to the
        # gate's own report namespace, no symlink component, regular file, and
        # byte-exact SHA-256 against the pinned value -- before a single table
        # row is read from it.
        if ($gateReportDeclarationPath -cne '') {
            if (-not (Test-CanonicalPath $gateReportDeclarationPath)) {
                Fail-ReviewContext 'PATH' "sdd-evaluator gate-report declaration is not a canonical repository-relative path: $gateReportDeclarationPath"
            }
            if ($gateReportDeclarationPath -cnotmatch '^reports/quality-gate/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*\.md$') {
                Fail-ReviewContext 'PATH' "sdd-evaluator gate-report declaration is not a quality-gate report: $gateReportDeclarationPath"
            }
            $gateReportComponent = $root
            foreach ($component in $gateReportDeclarationPath.Split('/')) {
                $gateReportComponent = Join-Path $gateReportComponent $component
                if (Test-Path -LiteralPath $gateReportComponent) {
                    if ($null -ne (Get-Item -LiteralPath $gateReportComponent -Force).LinkType) {
                        Fail-ReviewContext 'PATH' "sdd-evaluator gate-report declaration traverses a symbolic link: $gateReportDeclarationPath"
                    }
                }
            }
            $gateReport = Join-Path $root $gateReportDeclarationPath
            if (-not (Test-Path -LiteralPath $gateReport -PathType Leaf)) {
                Fail-ReviewContext 'PATH' "sdd-evaluator gate-report declaration is missing or is not a regular file: $gateReportDeclarationPath"
            }
            $gateReportHash = (Get-FileHash -LiteralPath $gateReport -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($gateReportHash -cne $gateReportDeclarationSha256) {
                Fail-ReviewContext 'HASH' "sdd-evaluator gate-report declaration hash mismatch: $gateReportDeclarationPath"
            }
            $inPostFix = $false
            foreach ($line in @(Get-Content -LiteralPath $gateReport -Encoding UTF8)) {
                if ($line -cmatch '^## Post-Fix Artifacts\s*$') {
                    $inPostFix = $true
                    continue
                }
                if ($inPostFix -and $line -cmatch '^##\s') {
                    break
                }
                if ($inPostFix -and
                    $line -cmatch '^\| `(?<path>[^`]+)` \| `(?<sha>[0-9a-f]{64})` \|$') {
                    [void]$gateReportOutputs.Add("$($Matches.path)`n$($Matches.sha)")
                }
            }
        }
    }
    # Located before the manifest-entry loop: the WFI-025 task-plan exception
    # inside the loop cross-checks the round's precheck record. The precheck
    # entry's own raw-hash verification still runs in the loop, so a tampered
    # precheck cannot buy a reservation -- any mismatch fails the whole run.
    $wfi025PrecheckEntry = $inputs | Where-Object {
        $_ -is [hashtable] -and $_.path -is [string] -and
        $_.path -cmatch '^reports/(spec|impl|task)-review/[^/]+/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$'
    } | Select-Object -First 1
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($input in $inputs) {
        if ($input -isnot [hashtable] -or -not (Test-ExactKeys $input @('path', 'sha256')) -or
            -not (Test-CanonicalPath $input.path) -or -not $paths.Add($input.path)) {
            Fail-ReviewContext 'PATH' "$($document.role) contains a duplicate or non-canonical path"
        }
        if ($input.sha256 -isnot [string] -or $input.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            Fail-ReviewContext 'HASH' "$($document.role) contains an invalid SHA-256: $($input.path)"
        }
        if ($input.path -cmatch '^reports/(spec|impl|task)-review/.*/reviewer-[^/]*\.json$' -or
            $input.path -cmatch '(^|/)reviewer-[ab]\.json$' -or
            -not (Test-AuthorizedPath $document.stage $document.role $document.feature $input.path $input.sha256 $evaluatorOutputs $implementationReportPath $gateReportOutputs)) {
            Fail-ReviewContext 'PATH' "$($document.role) contains a real but role-unlisted path: $($input.path)"
        }
        $candidate = [IO.Path]::GetFullPath((Join-Path $root $input.path))
        if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::Ordinal)) {
            Fail-ReviewContext 'PATH' "$($document.role) input escapes the repository root: $($input.path)"
        }
        $current = $root
        foreach ($component in $input.path.Split('/')) {
            $current = Join-Path $current $component
            if (Test-Path -LiteralPath $current) {
                if ($null -ne (Get-Item -LiteralPath $current -Force).LinkType) {
                    Fail-ReviewContext 'PATH' "$($document.role) input traverses a symbolic link: $($input.path)"
                }
            }
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            Fail-ReviewContext 'PATH' "$($document.role) contains a missing or non-regular input: $($input.path)"
        }
        $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne $input.sha256) {
            # WFI-025: the ONE scoped exception to the raw-equality rule. A
            # task-stage manifest may declare the task plan's normalized
            # digest, but only when the same round's precheck declares
            # tasks_sha256_form: normalized AND pinned exactly this digest
            # AND the live file still normalizes to it -- the entry keeps
            # binding every byte outside the lifecycle fields. Every other
            # entry keeps the strict raw requirement.
            $wfi025Applies = $false
            if ($document.stage -ceq 'task' -and $input.path -ceq "specs/$($document.feature)/tasks.md" -and
                $null -ne $wfi025PrecheckEntry) {
                $wfi025PrecheckPath = Join-Path $repositoryRoot $wfi025PrecheckEntry.path
                if (Test-Path -LiteralPath $wfi025PrecheckPath -PathType Leaf) {
                    $wfi025Precheck = Get-Content -LiteralPath $wfi025PrecheckPath -Raw | ConvertFrom-Json
                    $wfi025Form = 'raw'
                    if ($null -ne $wfi025Precheck.PSObject.Properties['tasks_sha256_form']) {
                        $wfi025Form = [string]$wfi025Precheck.tasks_sha256_form
                    }
                    if ($wfi025Form -cne 'normalized') {
                        Fail-ReviewContext 'HASH' "$($document.role) hash mismatch: $($input.path)"
                    }
                    $wfi025Pinned = ''
                    if ($null -ne $wfi025Precheck.PSObject.Properties['tasks_sha256']) {
                        $wfi025Pinned = [string]$wfi025Precheck.tasks_sha256
                    }
                    if ($input.sha256 -cne $wfi025Pinned) {
                        Fail-ReviewContext 'HASH' "$($document.role) hash mismatch: $($input.path) (a normalized task-plan digest must be the one this round's precheck recorded)"
                    }
                    if ((Get-TasksNormalizedHash $candidate) -cne $input.sha256) {
                        Fail-ReviewContext 'HASH' "$($document.role) hash mismatch: $($input.path) (the live task plan does not normalize to the declared digest)"
                    }
                    $wfi025Applies = $true
                }
            }
            if (-not $wfi025Applies) {
                Fail-ReviewContext 'HASH' "$($document.role) hash mismatch: $($input.path)"
            }
        }
    }

    # Round consistency. A manifest freezes hashes at reservation time; the round's
    # precheck-result.json froze them when the round opened. If the two disagree, a
    # reviewed document changed between the precheck and this reservation, so the
    # round's two reviewers would be judging different text. Precheck replay is
    # forbidden, so refuse the reservation now rather than a round later.
    $precheckEntry = $inputs | Where-Object {
        $_.path -cmatch '^reports/(spec|impl|task)-review/[^/]+/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$'
    } | Select-Object -First 1
    if ($null -ne $precheckEntry) {
        $precheckPath = Join-Path $repositoryRoot $precheckEntry.path
        if (Test-Path -LiteralPath $precheckPath -PathType Leaf) {
            $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json
            $pinned = [ordered]@{}
            $simple = [ordered]@{
                'requirements.md'     = 'requirements_sha256'
                'acceptance-tests.md' = 'acceptance_sha256'
                'design.md'           = 'design_sha256'
                'tasks.md'            = 'tasks_sha256'
                'traceability.json'   = 'traceability_sha256'
            }
            foreach ($docName in $simple.Keys) {
                $value = $precheck.PSObject.Properties[$simple[$docName]]
                if ($null -ne $value -and $value.Value -is [string] -and
                    $value.Value -cmatch '^[0-9a-f]{64}$') {
                    $pinned["specs/$($document.feature)/$docName"] = $value.Value
                }
            }
            $layer = $precheck.PSObject.Properties['layer_sha256']
            if ($null -ne $layer -and $null -ne $layer.Value) {
                foreach ($entry in $layer.Value.PSObject.Properties) {
                    if ($entry.Value -is [string] -and $entry.Value -cmatch '^[0-9a-f]{64}$') {
                        $pinned["specs/$($document.feature)/$($entry.Name)"] = $entry.Value
                    }
                }
            }
            foreach ($pinnedPath in $pinned.Keys) {
                $manifestEntry = $inputs | Where-Object { $_.path -ceq $pinnedPath } | Select-Object -First 1
                if ($null -eq $manifestEntry) { continue }
                if ($manifestEntry.sha256 -cne $pinned[$pinnedPath]) {
                    Fail-ReviewContext 'ROUND' "manifest freezes $pinnedPath at a hash this round's precheck did not pin: the document changed mid-round"
                }
            }
        }
    }

    $recordText = "$($document.sequence)|$($document.stage)|$($document.role)|$($document.run_id)|$($document.host_session_id)|$($document.previous_record_sha256)"
    $recordHash = Get-Sha256Text $recordText
    if ($Reserve) {
        $lockPath = "$ledger.lock"
        $lockStream = $null
        $lockAcquired = $false
        $temporary = Join-Path (Split-Path -Parent $ledger) (".identity-ledger.{0}.tmp" -f [Guid]::NewGuid().ToString('N'))
        try {
            try {
                $lockStream = [IO.File]::Open(
                    $lockPath,
                    [IO.FileMode]::CreateNew,
                    [IO.FileAccess]::Write,
                    [IO.FileShare]::None
                )
                $lockAcquired = $true
            }
            catch {
                Fail-ReviewContext 'IDENTITY' 'canonical identity ledger reservation is already in progress'
            }
            $currentLedgerHash = (Get-FileHash -LiteralPath $ledger -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($currentLedgerHash -cne $document.identity_ledger_sha256) {
                Fail-ReviewContext 'IDENTITY' 'canonical identity ledger changed before reservation'
            }
            $ledgerDocument.records = @($ledgerDocument.records) + @([ordered]@{
                sequence = [long]$document.sequence
                stage = $document.stage
                role = $document.role
                run_id = $document.run_id
                host_session_id = $document.host_session_id
                previous_record_sha256 = $document.previous_record_sha256
                record_sha256 = $recordHash
            })
            $json = $ledgerDocument | ConvertTo-Json -Depth 20
            [IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $temporary -Destination $ledger -Force
        }
        finally {
            if ($null -ne $lockStream) {
                $lockStream.Dispose()
            }
            if ($lockAcquired -and (Test-Path -LiteralPath $lockPath)) {
                Remove-Item -LiteralPath $lockPath -Force
            }
            if (Test-Path -LiteralPath $temporary) {
                Remove-Item -LiteralPath $temporary -Force
            }
        }
    }
    # WFI-037: the OK line carries the chain facts a launched role needs to
    # verify its own identity WITHOUT reading the ledger (which no role's
    # manifest may authorize): the reserved record's sequence, the
    # previous-record hash the record chains from, the pre-append tip
    # sequence ('-' when verifying an already-persisted identity, where tip
    # position is meaningless), and the uniqueness assertion for the
    # run/session ids -- every one proven by a fail-closed check above
    # before this line prints.
    $previousForLine = if ([string]::IsNullOrEmpty([string]$document.previous_record_sha256)) { '-' } else { [string]$document.previous_record_sha256 }
    [Console]::Out.WriteLine("REVIEW_CONTEXT_OK $recordHash sequence=$($document.sequence) previous_record_sha256=$previousForLine pre_append_tip_sequence=$preAppendTipSequence identity_unique=yes")
    exit 0
}
catch {
    Fail-ReviewContext 'IO' $_.Exception.Message
}
