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

function Test-AuthorizedPath {
    param(
        [string]$Stage,
        [string]$Role,
        [string]$Feature,
        [string]$Path,
        [string]$Sha256,
        [Collections.Generic.HashSet[string]]$EvaluatorOutputs,
        [string]$ImplementationReportPath
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
            return (
                $Path -cmatch "^specs/$escapedFeature/(requirements|acceptance-tests|design|tasks|traceability|baseline-behavior|ux-spec|frontend-spec|infra-spec|security-spec)\.(md|json)$" -or
                $Path -ceq 'plugins/sdd-quality-loop/references/quality-gate-calibration.md' -or
                $Path -ceq $ImplementationReportPath -or
                $EvaluatorOutputs.Contains("$Path`n$Sha256")
            )
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
    $topKeys = if ($document.stage -ceq 'quality') {
        @($baseTopKeys) + @('task_id')
    }
    else {
        @($baseTopKeys)
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
    $actualLedgerHash = (Get-FileHash -LiteralPath $ledger -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualLedgerHash -cne $document.identity_ledger_sha256) {
        Fail-ReviewContext 'IDENTITY' 'canonical identity ledger hash is stale or mismatched'
    }
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
    if ([decimal]$document.sequence -ne $expectedSequence -or
        $document.previous_record_sha256 -cne $expectedPrevious) {
        Fail-ReviewContext 'IDENTITY' 'invocation does not extend the canonical identity ledger'
    }
    if ($runs.Contains($document.run_id) -or $sessions.Contains($document.host_session_id)) {
        Fail-ReviewContext 'IDENTITY' 'run or host-session identity was already persisted'
    }

    $inputs = @($document.allowed_input_manifest)
    $implementationReportPath = ''
    $evaluatorOutputs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
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
    }
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
            -not (Test-AuthorizedPath $document.stage $document.role $document.feature $input.path $input.sha256 $evaluatorOutputs $implementationReportPath)) {
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
            Fail-ReviewContext 'HASH' "$($document.role) hash mismatch: $($input.path)"
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
    [Console]::Out.WriteLine("REVIEW_CONTEXT_OK $recordHash")
    exit 0
}
catch {
    Fail-ReviewContext 'IO' $_.Exception.Message
}
