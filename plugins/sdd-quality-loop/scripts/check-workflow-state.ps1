# Validate the repository-wide SDD workflow state. Keep rule IDs in parity with Bash.
$ErrorActionPreference = "Stop"

# WFI-021: diagnostics accumulate across independent features instead of
# exiting at the first one. Inside a feature's validation scope
# Stop-WorkflowState throws a sentinel the per-feature loop catches (so the
# short-circuit WITHIN a feature is retained); outside feature scope it
# still exits immediately. The run exits non-zero at the end if any fired.
$script:WorkflowStateFailed = 0
$script:FeatureScopeActive = $false
$script:WorkflowStateFeatureAbort = "workflow-state-feature-abort"
function Write-WorkflowStateDiagnostic([string]$Feature, [string]$Rule, [string]$Message) {
    [Console]::Error.WriteLine("workflow-state: ${Feature}: ${Rule}: ${Message}")
}
function Stop-WorkflowState([string]$Feature, [string]$Rule, [string]$Message) {
    Write-WorkflowStateDiagnostic $Feature $Rule $Message
    if ($script:FeatureScopeActive) { throw $script:WorkflowStateFeatureAbort }
    exit 1
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
# plugins/ reference docs (risk-gate-matrix.md, reviewer-calibration.md, etc.)
# evolve normally over time, but historical review evidence under reports/
# records the sha256 that was current when that evidence was produced. A
# later, legitimate edit to a reference doc must not retroactively fail every
# past feature's provenance. When a manifest-recorded hash for a plugins/
# path does not match the live working-tree file, fall back to resolving the
# file's content as of the commit that INTRODUCED the specific evidence file
# being validated (the review contract JSON itself is immutable, committed
# historical fact) and accept the match only if it is identical. The pin
# stands in for "when this review happened" -- a moment that does not move
# when the record is later amended for an unrelated reason, so this resolves
# --diff-filter=A (the commit that added the path), not the commit that most
# recently touched it: a subsequent, unrelated edit to the same contract
# (e.g. a provenance re-bind) must not retroactively shift the pin forward
# past reference-doc evolution that happened in between, which would falsely
# invalidate a hash that was valid when the review actually ran.
# This keeps tamper detection intact: a forged hash that matches no
# legitimate point-in-time content still fails.
function Get-PluginsPinCommit([string]$EvidenceFile) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    & git -C $ScriptRoot rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) { return $null }
    $prefix = $RepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $EvidenceFile.StartsWith($prefix, [StringComparison]::Ordinal)) { return $null }
    $relative = $EvidenceFile.Substring($prefix.Length).Replace("\", "/")
    # A path added, deleted, and re-added yields more than one
    # --diff-filter=A commit (captured here as an array); a path that has
    # never been committed (working-tree only) yields none ($null/empty).
    # Both are an indeterminate introducing commit. Since this is a
    # provenance check, failing closed on an indeterminate pin is safer than
    # guessing which addition -- or accepting a convenient one -- is
    # authoritative.
    $result = & git -C $ScriptRoot log --diff-filter=A --format='%H' -- $relative 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $result) { return $null }
    if ($result -is [array]) { return $null }
    return [string]$result
}
function Get-PluginsHashAtPin([string]$Pin, [string]$PluginsRelative) {
    if (-not $Pin) { return $null }
    & git -C $ScriptRoot merge-base --is-ancestor $Pin HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    # Redirect the blob straight to a temp file and hash the file so the
    # comparison is byte-exact -- capturing external-command stdout through
    # the PowerShell pipeline splits it into lines and can alter encoding or
    # trailing newlines, which would corrupt the sha256.
    $tempFile = [IO.Path]::GetTempFileName()
    try {
        & git -C $ScriptRoot show "${Pin}:${PluginsRelative}" > $tempFile 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash.ToLowerInvariant()
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}
# Returns $true when $ScriptRoot has any git history to consult at all (git
# binary present and it is a work tree). Checked independently of
# Get-PluginsPinCommit's own return value, because that function also
# returns $null for reasons that are NOT "no history exists" (e.g. an
# evidence path outside $RepoRoot, or a path with no commits) -- only the
# true absence of git history should relax Test-PluginsHashMatches below.
function Test-PluginsGitHistoryAvailable() {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    & git -C $ScriptRoot rev-parse --is-inside-work-tree *> $null
    return $LASTEXITCODE -eq 0
}
# Returns $true if $PluginsFile's content matches $Expected either right
# now, or as of the commit that produced $EvidenceFile (the review contract
# JSON whose recorded manifest hash is being validated). A release artifact
# (e.g. the tarball repository-release-validation.tests.sh builds) carries no
# .git directory, so there is no history there to reconcile a
# manifest-recorded hash against: the comparison is not evaluable rather than
# failed, and is accepted for this plugins/* shared-reference class only.
# The same assertion is still fully enforced by every git-bearing run of this
# script (in place, in CI checkouts, in this repo's own fixtures) -- that is
# where a stale or forged hash is actually checkable, and a mismatch the pin
# cannot justify still fails there.
function Test-PluginsHashMatches([string]$PluginsFile, [string]$Expected, [string]$EvidenceFile) {
    if (-not (Test-Path -LiteralPath $PluginsFile -PathType Leaf) -or
        (Get-Item -LiteralPath $PluginsFile -Force).LinkType) { return $false }
    if ((Get-Sha256 $PluginsFile) -eq $Expected) { return $true }
    if (-not (Test-PluginsGitHistoryAvailable)) { return $true }
    $prefix = $RepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $PluginsFile.StartsWith($prefix, [StringComparison]::Ordinal)) { return $false }
    $pluginsRelative = $PluginsFile.Substring($prefix.Length).Replace("\", "/")
    $pin = Get-PluginsPinCommit $EvidenceFile
    if (-not $pin) { return $false }
    $historical = Get-PluginsHashAtPin $pin $pluginsRelative
    if (-not $historical) { return $false }
    return $historical -eq $Expected
}

# The amendment re-review lane (spec-review's own "## Amendment Re-Review
# Context" section, extended to impl/task in reviewer-calibration.md)
# creates a structural oscillation none of the tolerances above cover: each
# downstream stage's OWN recovery legitimately appends to the SAME
# specs/<feature>/investigation.md section that an UPSTREAM stage's
# reviewer manifest already pinned (investigation.md is an allowed input
# for all three stages -- see Test-ManifestPaths' unconditional allowance).
# That re-stales the upstream pin with a change whose entire content is the
# record of the very recovery the lane exists to permit -- not a change to
# anything reviewed. Unlike Stop-WorkflowStateOrTolerate below, this must
# work STANDALONE (no --opening): the oscillation bites precisely when no
# stage is currently being opened. Scoping this to one named section is
# what makes a standalone, unconditional tolerance safe: the section is the
# lane's own declared channel, its conformance is judged by every reviewer
# who reads investigation.md as part of that stage's normal review, and the
# checks below guarantee nothing outside that section -- and no mutation of
# an already-reviewed line inside it -- can ride through this path. See the
# Bash twin (check-workflow-state.sh) for the full reasoning; kept in
# parity here, not duplicated verbatim in every comment.
#
# Assumes LF-only line endings, consistent with this repo's markdown files
# and with every other line array this script builds; a CRLF
# investigation.md is out of scope for this reconciliation (unlike the
# tasks.md/CRLF handling elsewhere in this file, which predates it).
#
# Mirrors amendment_section_bounds in the Bash twin: returns @(start, end)
# (0-based, inclusive -- PowerShell array convention, unlike the Bash
# twin's 1-based line numbers) for the FIRST line reading exactly
# "## Amendment Re-Review Context" in $Lines, or $null if absent.
function Get-AmendmentSectionBounds([string[]]$Lines) {
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -ceq "## Amendment Re-Review Context") { $start = $i; break }
    }
    if ($start -lt 0) { return $null }
    $end = $Lines.Count - 1
    for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -clike "## *") { $end = $i - 1; break }
    }
    return @($start, $end)
}
# Case-sensitive, ordered, exact array equality -- used everywhere below
# instead of Compare-Object so a length mismatch and a content mismatch are
# both a plain $false, with no SideIndicator bookkeeping to misread.
function Test-LineArraysEqual([string[]]$A, [string[]]$B) {
    if ($A.Count -ne $B.Count) { return $false }
    for ($i = 0; $i -lt $A.Count; $i++) {
        if ($A[$i] -cne $B[$i]) { return $false }
    }
    return $true
}
# Mirrors investigation_growth_only_change in the Bash twin exactly --
# verifies the ONLY difference between $PinnedLines and $LiveLines is pure,
# contiguous growth confined to the "## Amendment Re-Review Context"
# section as computed on $LiveLines. See the Bash function's own comments
# for the full (1)-(4) reasoning (prefix identity, growth-only /
# no-mutation section body, EOF-only creation, suffix identity); this is
# the same logic in 0-based form.
function Test-InvestigationGrowthOnlyChange([string[]]$PinnedLines, [string[]]$LiveLines) {
    $liveBounds = Get-AmendmentSectionBounds $LiveLines
    if ($null -eq $liveBounds) { return $false }
    $liveStart = $liveBounds[0]
    $liveEnd = $liveBounds[1]
    $liveTotal = $LiveLines.Count
    $pinnedTotal = $PinnedLines.Count

    $pinnedBounds = Get-AmendmentSectionBounds $PinnedLines
    if ($null -ne $pinnedBounds) {
        $pinnedStart = $pinnedBounds[0]
        $pinnedEnd = $pinnedBounds[1]
        # Sanity check, made explicit rather than left implicit in the
        # prefix comparison: the section must start at the same absolute
        # line in both files.
        if ($pinnedStart -ne $liveStart) { return $false }
        if ($liveStart -gt 0) {
            if (-not (Test-LineArraysEqual $PinnedLines[0..($liveStart - 1)] $LiveLines[0..($liveStart - 1)])) {
                return $false
            }
        }
    } else {
        # No fixed offset to compare against: the heading's live position is
        # unconstrained beyond "strictly after all of pinned's own content"
        # (a conventional blank-line separator before a brand-new heading
        # is itself new content, with nothing pinned to compare it
        # against), so the prefix check here compares ALL of pinned against
        # live's own first $pinnedTotal lines, not a window sized by
        # $liveStart.
        if ($liveStart -lt $pinnedTotal) { return $false }
        if ($pinnedTotal -gt 0) {
            if (-not (Test-LineArraysEqual $PinnedLines[0..($pinnedTotal - 1)] $LiveLines[0..($pinnedTotal - 1)])) {
                return $false
            }
        }
        # Created-at-EOF requirement, literal: the section must reach the
        # live file's own last line -- a brand-new section spliced ahead of
        # pre-existing trailing content is rejected even though it would
        # still pass a bare prefix/suffix-identity check.
        if ($liveEnd -ne ($liveTotal - 1)) { return $false }
    }

    if ($null -ne $pinnedBounds) {
        $pinnedStart = $pinnedBounds[0]
        $pinnedEnd = $pinnedBounds[1]
        $pinnedSectionLen = $pinnedEnd - $pinnedStart + 1
        $liveSectionLen = $liveEnd - $liveStart + 1
        if ($liveSectionLen -lt $pinnedSectionLen) { return $false }
        $pinnedSection = $PinnedLines[$pinnedStart..$pinnedEnd]
        $liveSectionHead = $LiveLines[$liveStart..($liveStart + $pinnedSectionLen - 1)]
        if (-not (Test-LineArraysEqual $pinnedSection $liveSectionHead)) { return $false }

        $pinnedAfter = $pinnedTotal - 1 - $pinnedEnd
        $liveAfter = $liveTotal - 1 - $liveEnd
        if ($pinnedAfter -gt 0 -or $liveAfter -gt 0) {
            if ($pinnedAfter -ne $liveAfter) { return $false }
            if ($pinnedAfter -gt 0) {
                $pinnedSuffix = $PinnedLines[($pinnedEnd + 1)..($pinnedTotal - 1)]
                $liveSuffix = $LiveLines[($liveEnd + 1)..($liveTotal - 1)]
                if (-not (Test-LineArraysEqual $pinnedSuffix $liveSuffix)) { return $false }
            }
        }
    }
    return $true
}
# Mirrors resolve_verified_investigation_pin in the Bash twin: resolves the
# pinned bytes of specs/<feature>/investigation.md at $Contract's
# introducing commit (Get-PluginsPinCommit/Get-PluginsHashAtPin -- the SAME
# machinery plugins/ reference docs use, reused rather than duplicated) and
# writes them to $OutFile. Returns $true only after independently
# re-verifying the written bytes' own sha256 equals $Expected -- a forged
# pin, an ambiguous introducing commit, or an unreconstructable history all
# fail here with nothing written that the caller could diff against.
function Resolve-VerifiedInvestigationPin([string]$Contract, [string]$Expected, [string]$Relative, [string]$OutFile) {
    $pin = Get-PluginsPinCommit $Contract
    if (-not $pin) { return $false }
    $historical = Get-PluginsHashAtPin $pin $Relative
    if ($historical -ne $Expected) { return $false }
    & git -C $ScriptRoot show "${pin}:${Relative}" > $OutFile 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    return (Get-Sha256 $OutFile) -eq $Expected
}
# Mirrors investigation_amendment_reconciles in the Bash twin: the
# top-level entry point, applied uniformly to every stage (spec/impl/task)
# since investigation.md is an allowed input for all three and the
# oscillation is structurally identical regardless of which stage's pin
# went stale.
function Test-InvestigationAmendmentReconciles([string]$ManifestFile, [string]$Expected, [string]$Contract) {
    $prefix = $RepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $ManifestFile.StartsWith($prefix, [StringComparison]::Ordinal)) { return $false }
    $relative = $ManifestFile.Substring($prefix.Length).Replace("\", "/")
    # WFI-024's no-history rule, extended to this reconciliation: without
    # git history the pinned generation's bytes are unreconstructable, so
    # the growth-only property is not evaluable -- accepted, not evaluated,
    # matching Test-PluginsHashMatches in a history-less tree.
    if (-not (Test-PluginsGitHistoryAvailable)) { return $true }
    $tempFile = [IO.Path]::GetTempFileName()
    try {
        if (-not (Resolve-VerifiedInvestigationPin $Contract $Expected $relative $tempFile)) { return $false }
        $pinnedLines = @(Get-Content -LiteralPath $tempFile)
        $liveLines = @(Get-Content -LiteralPath $ManifestFile)
        return Test-InvestigationGrowthOnlyChange $pinnedLines $liveLines
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}
# Visible notice, not a silent pass: names the file, both hashes, and that
# the delta is confined to amendment-record growth.
function Write-InvestigationAmendmentNotice([string]$Feature, [string]$Stage, [string]$Suffix, [string]$Recorded, [string]$Current) {
    [Console]::Error.WriteLine(
        "workflow-state: ${Feature}: stage-provenance-tolerated: ${Suffix} (${Stage} stage) recorded ${Recorded}, now ${Current} (amendment-record growth only)")
}

function Get-NormalizedHash([string]$Path, [string]$Stage) {
    $text = [IO.File]::ReadAllText($Path)
    switch ($Stage) {
        "spec" {
            $text = [regex]::Replace(
                $text, "(?m)^Spec-Review-Status:[^\r\n]*(\r?)$", 'Spec-Review-Status: Pending$1')
        }
        "impl" {
            $text = [regex]::Replace(
                $text, "(?m)^Impl-Review-Status:[^\r\n]*(\r?)$", 'Impl-Review-Status: Pending$1')
        }
        "task" {
            $text = [regex]::Replace(
                $text, "(?m)^Task-Review-Status:[^\r\n]*(\r?)$", 'Task-Review-Status: Pending$1')
            $text = [regex]::Replace(
                $text, "(?m)^Approval:[^\r\n]*(\r?)$", 'Approval: Draft$1')
            $text = [regex]::Replace(
                $text, "(?m)^Status:[^\r\n]*(\r?)$", 'Status: Planned$1')
                $text = [regex]::Replace(
                    $text, "(?m)^Second Approval:[^\r\n]*\r?\n?", '')
        }
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    # PS5.1-safe (no [Convert]::ToHexString, .NET 5+ only).
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-RereviewNormalizedHash([string]$Path, [string]$Status) {
    $text = [IO.File]::ReadAllText($Path)
    $text = [regex]::Replace($text, "(?m)^Task-Review-Status:[^\r\n]*(\r?)$", 'Task-Review-Status: Passed$1')
    $text = [regex]::Replace($text, "(?m)^Approval:[^\r\n]*(\r?)$", 'Approval: Approved$1')
    $text = [regex]::Replace($text, "(?m)^Status:[^\r\n]*(\r?)$", "Status: ${Status}`$1")
    $text = [regex]::Replace($text, "(?m)^Second Approval:[^\r\n]*\r?\n?", '')
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
# Twin of traceability_normalized_hash() in check-workflow-state.sh. Rewrites
# only each REQ row's final delivery-status cell, and only over the closed
# lifecycle vocabulary; every other byte still participates in the digest.
# [^\S\r\n] is horizontal whitespace only, so the explicit (\r?)$ keeps CRLF
# input byte-identical -- matching the convention of the functions above.
function Get-TraceabilityNormalizedHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    $text = [regex]::Replace(
        $text,
        '(?m)^(\|[^\S\r\n]*REQ-.*\|)([^\S\r\n]*)(Planned|In Progress|Implementation Complete|Done|Blocked)([^\S\r\n]*\|[^\S\r\n]*)(\r?)$',
        '${1}${2}Planned${4}${5}')
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Test-TraceabilityHash([string]$Candidate, [string]$Raw, [string]$Normalized) {
    if ([string]::IsNullOrEmpty($Candidate)) { return $false }
    return ($Candidate -eq $Raw -or $Candidate -eq $Normalized)
}
function Get-Header([string]$Path, [string]$Header) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $match = [regex]::Match([IO.File]::ReadAllText($Path), "(?m)^$([regex]::Escape($Header)):\s*(\S+)")
    if ($match.Success) { return $match.Groups[1].Value.TrimEnd("`r") }
    return ""
}
function Test-ManifestPathRooted([string]$Path) {
    return [IO.Path]::IsPathRooted($Path) -or $Path -match "^[A-Za-z]:[\\/]"
}
function Get-RepositoryRelativePath(
    [string]$Path, [string]$RepositoryRoot, [string]$RecordedRoot = ""
) {
    $normalizedPath = $Path.Replace("\", "/")
    $normalizedRoot = $RepositoryRoot.Replace("\", "/").TrimEnd("/")
    $roots = @($normalizedRoot)
    if ($normalizedRoot.StartsWith("/private/var/")) {
        $roots += "/var/" + $normalizedRoot.Substring("/private/var/".Length)
    } elseif ($normalizedRoot.StartsWith("/var/")) {
        $roots += "/private/var/" + $normalizedRoot.Substring("/var/".Length)
    }
    if (-not (Test-ManifestPathRooted $Path)) { return $normalizedPath }
    foreach ($root in $roots) {
        if ($normalizedPath.StartsWith("$root/", [StringComparison]::OrdinalIgnoreCase)) {
            return $normalizedPath.Substring($root.Length + 1)
        }
    }
    if ($RecordedRoot) {
        $normalizedRecordedRoot = $RecordedRoot.Replace("\", "/").TrimEnd("/")
        if ($normalizedPath.StartsWith("$normalizedRecordedRoot/", [StringComparison]::Ordinal)) {
            return $normalizedPath.Substring($normalizedRecordedRoot.Length + 1)
        }
    }
    return $null
}
function Get-CandidateRootsForPath([string]$NormalizedPath) {
    # One recorded manifest path's candidate repository roots: split on the
    # repository's structural top-level directories, counting a split only
    # when the suffix it produces matches a canonical manifest shape (the
    # rationale is documented in Get-RecordedRepositoryRoot, whose per-path
    # inner derivation this extracts). Returned with the comma operator so
    # PowerShell hands back the HashSet itself instead of unrolling it.
    $candidateRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($marker in @("/specs/", "/reports/", "/plugins/")) {
        $index = $NormalizedPath.IndexOf($marker, [StringComparison]::Ordinal)
        while ($index -ge 0) {
            $suffix = $NormalizedPath.Substring($index + 1)
            if ($suffix -cmatch '^specs/[a-z0-9][a-z0-9-]*/[^/]+$' -or
                $suffix -cmatch '^reports/(spec|impl|task)-review/[a-z0-9][a-z0-9-]*/attempt-[1-9][0-9]*/round-[1-9][0-9]*/[^/]+$' -or
                $suffix -cmatch '^plugins/[a-z0-9][a-z0-9-]*/references/[^/]+$') {
                [void]$candidateRoots.Add($NormalizedPath.Substring(0, $index))
            }
            $index = $NormalizedPath.IndexOf($marker, $index + 1, [StringComparison]::Ordinal)
        }
    }
    return ,$candidateRoots
}
function Get-RecordedRepositoryRoot($Contract, [string]$RepositoryRoot) {
    $normalizedRoot = $RepositoryRoot.Replace("\", "/").TrimEnd("/")
    $currentRoots = @($normalizedRoot)
    if ($normalizedRoot.StartsWith("/private/var/")) {
        $currentRoots += "/var/" + $normalizedRoot.Substring("/private/var/".Length)
    } elseif ($normalizedRoot.StartsWith("/var/")) {
        $currentRoots += "/private/var/" + $normalizedRoot.Substring("/var/".Length)
    }
    # Recorded manifest paths are absolute paths from the clone that produced
    # the review evidence, whose directory name has no relation to this
    # checkout's (worktrees, CI fixtures, and renamed clones are all legal).
    # Split them on the repository's own structural top-level directories
    # instead: every canonical manifest path is repo-relative under specs/,
    # reports/, or plugins/. A split candidate only counts when the suffix it
    # produces matches one of the canonical manifest shapes, so a feature
    # slug that happens to be named "specs", "reports", or "plugins" cannot
    # be mistaken for the repository root; a path with no unambiguous split
    # is invalid. A wrong split cannot weaken tamper detection - the derived
    # relative path must still match the canonical allowlist, its recorded
    # sha256 must match the live file, and every manifest entry must agree
    # on a single recorded root.
    $recordedRoots = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal)
    foreach ($reviewer in @($Contract.reviewers)) {
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $rawPath = [string]$item.path
            if (-not (Test-ManifestPathRooted $rawPath)) { continue }
            $normalizedPath = $rawPath.Replace("\", "/")
            $isCurrent = $false
            foreach ($root in $currentRoots) {
                if ($normalizedPath.StartsWith("$root/", [StringComparison]::OrdinalIgnoreCase)) {
                    $isCurrent = $true
                    break
                }
            }
            if ($isCurrent) { continue }
            $candidateRoots = Get-CandidateRootsForPath $normalizedPath
            if ($candidateRoots.Count -ne 1) {
                return [pscustomobject]@{ Valid=$false; Root="" }
            }
            [void]$recordedRoots.Add(@($candidateRoots)[0])
            if ($recordedRoots.Count -gt 1) {
                return [pscustomobject]@{ Valid=$false; Root="" }
            }
        }
    }
    $root = if ($recordedRoots.Count) { @($recordedRoots)[0] } else { "" }
    return [pscustomobject]@{ Valid=$true; Root=$root }
}
function Test-ManifestHash(
    $Contract, [string]$Suffix, [string]$Expected, [string]$RepositoryRoot
) {
    $recorded = Get-RecordedRepositoryRoot $Contract $RepositoryRoot
    if (-not $recorded.Valid) { return $false }
    $target = $Suffix.TrimStart("/")
    foreach ($reviewer in @($Contract.reviewers)) {
        $found = $false
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $path = Get-RepositoryRelativePath ([string]$item.path) $RepositoryRoot $recorded.Root
            if ($null -ne $path -and $path -ceq $target -and
                [string]$item.sha256 -eq $Expected) {
                $found = $true
                break
            }
        }
        if (-not $found) { return $false }
    }
    return @($Contract.reviewers).Count -gt 0
}
# Like Test-ManifestHash, but for a live file: accepts a manifest entry that
# matches either the file's current hash or (for plugins/ reference docs
# only) its content as of the commit that produced $Contract. This tolerates
# legitimate later edits to plugins/ reference docs without weakening the
# check for any other input.
function Test-ManifestHashForFile(
    $Contract, [string]$Suffix, [string]$FilePath, [string]$RepositoryRoot, [string]$EvidenceFile
) {
    $current = Get-Sha256 $FilePath
    if (Test-ManifestHash $Contract $Suffix $current $RepositoryRoot) { return $true }
    $trimmed = $Suffix.TrimStart("/")
    if ($trimmed -notlike "plugins/*") { return $false }
    # Same "not evaluable, not failed" rule Test-PluginsHashMatches already
    # applies: a fixture root with no git history at all (e.g. a release
    # artifact, or WFI-024's reference-doc-forged-no-git fixture) has
    # nothing to reconcile a stale plugins/ manifest hash against, so this
    # must be accepted rather than rejected. Without this check, any live
    # drift of a plugins/ reference doc this function guards
    # (spec-review-calibration.md, reviewer-calibration.md) fails closed
    # under no-git even though the identical drift on risk-gate-matrix.md is
    # correctly tolerated by Test-PluginsHashMatches -- the two functions
    # must agree on this class.
    if (-not (Test-PluginsGitHistoryAvailable)) { return $true }
    $pin = Get-PluginsPinCommit $EvidenceFile
    if (-not $pin) { return $false }
    $historical = Get-PluginsHashAtPin $pin $trimmed
    if (-not $historical) { return $false }
    return Test-ManifestHash $Contract $Suffix $historical $RepositoryRoot
}
# Reuses Get-RepositoryRelativePath -- the SAME resolution Test-ManifestHash
# uses, not a substring probe -- to answer a narrower question than
# Test-ManifestHash: ignoring sha256 entirely, was $Suffix ever recorded in
# this manifest at all, and if so, at what hash(es)? Returns every distinct
# recorded sha256 for the path. An empty result means no reviewer declared
# this path -- a genuine provenance gap. Exactly one result means every
# entry for this path agrees on a single hash, which is what lets a caller
# tell "the manifest already knows this input, just at stale bytes" apart
# from "the manifest never knew this input at all." More than one result
# (reviewers disagree with each other about this path) is deliberately left
# for the caller to treat as inconclusive -- that is not simple staleness.
function Get-ManifestRecordedHashesForPath($Contract, [string]$Suffix, [string]$RepositoryRoot) {
    # NOT ,@(...): the caller already wraps this call in @(...) to guard
    # against PowerShell's single-element-array unwrap on return (the same
    # class of bug as elsewhere in this codebase); double-guarding with a
    # leading comma HERE as well produces a worse bug in the opposite
    # direction -- a genuinely EMPTY result becomes a 1-element array
    # containing an empty array, so $hashes.Count reads as 1 (not 0) and
    # $hashes[0] is an array object, not $null. A plain @(...) return,
    # left for the caller's own @(...) to reconstruct, is correct for 0, 1,
    # and N elements alike (verified directly against PS7's actual
    # behavior, not assumed from the comma-operator convention used
    # elsewhere in this file for different call shapes).
    $recorded = Get-RecordedRepositoryRoot $Contract $RepositoryRoot
    if (-not $recorded.Valid) { return @() }
    $target = $Suffix.TrimStart("/")
    $hashes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($reviewer in @($Contract.reviewers)) {
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $path = Get-RepositoryRelativePath ([string]$item.path) $RepositoryRoot $recorded.Root
            if ($null -ne $path -and $path -ceq $target) {
                [void]$hashes.Add([string]$item.sha256)
            }
        }
    }
    return @($hashes)
}
# A reviewed document's recorded hash legitimately takes either of two forms.
# An ordinary review runs while the stage's status field still reads `Pending`
# (impl-review-precheck enforces that), so the reviewers record the raw bytes
# and the post-review flip to `Passed` is absorbed by Get-NormalizedHash. A
# re-review of an already-passed feature (--provenance-rereview) necessarily
# runs while the field already reads `Passed` -- that mode refuses to start
# otherwise -- so the reviewers record the raw bytes of THAT state, which no
# normalization can reproduce. Accepting either form does not weaken
# provenance: both prove the reviewers read the document's current body, and
# an edit to the body still matches neither.
function Test-ReviewedHash([string]$FilePath, [string]$Stage, [string]$Candidate) {
    if ([string]::IsNullOrEmpty($Candidate)) { return $false }
    if ($Candidate -eq (Get-NormalizedHash $FilePath $Stage)) { return $true }
    if ($Candidate -eq (Get-Sha256 $FilePath)) { return $true }
    if ($Stage -eq "task") {
        # A task-stage re-review binds the raw bytes of an executable state;
        # the quality gate's later Done flips are lifecycle transitions, not
        # body edits, and are absorbed by the two re-review canonical forms
        # (mirrors the bash twin's rereview_normalized_hash).
        if ($Candidate -eq (Get-RereviewNormalizedHash $FilePath "Implementation Complete")) { return $true }
        if ($Candidate -eq (Get-RereviewNormalizedHash $FilePath "Done")) { return $true }
    }
    return $false
}
function Test-ManifestReviewedHash(
    $Contract, [string]$Suffix, [string]$FilePath, [string]$Stage, [string]$RepositoryRoot
) {
    if (Test-ManifestHash $Contract $Suffix (Get-NormalizedHash $FilePath $Stage) $RepositoryRoot) { return $true }
    if (Test-ManifestHash $Contract $Suffix (Get-Sha256 $FilePath) $RepositoryRoot) { return $true }
    if ($Stage -eq "task") {
        if (Test-ManifestHash $Contract $Suffix (Get-RereviewNormalizedHash $FilePath "Implementation Complete") $RepositoryRoot) { return $true }
        if (Test-ManifestHash $Contract $Suffix (Get-RereviewNormalizedHash $FilePath "Done") $RepositoryRoot) { return $true }
    }
    return $false
}
function Test-AllowedLayerSupersetPath(
    [string]$Path, [string]$Feature, [string]$Stage, [string]$RepositoryRoot, [string]$RecordedRoot
) {
    # Scoped to impl-review only (issue #71): impl reviewers may have
    # legitimately reviewed the four layer specs even when the round
    # contract predates recording them. Spec/task stages must still
    # match the contract exactly.
    if ($Stage -ne "impl") { return $false }
    $relative = Get-RepositoryRelativePath $Path $RepositoryRoot $RecordedRoot
    if ($null -eq $relative) { return $false }
    return $relative -in @(
        "specs/$Feature/ux-spec.md", "specs/$Feature/frontend-spec.md",
        "specs/$Feature/infra-spec.md", "specs/$Feature/security-spec.md"
    )
}
function Test-ManifestSuperset(
    $ReviewerManifest, $ContractManifest, [string]$Feature, [string]$Stage,
    [string]$RepositoryRoot, [string]$RecordedRoot
) {
    $contractKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in @($ContractManifest)) {
        [void]$contractKeys.Add("$([string]$item.path)`t$([string]$item.sha256)")
    }
    $reviewerKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in @($ReviewerManifest)) {
        [void]$reviewerKeys.Add("$([string]$item.path)`t$([string]$item.sha256)")
    }
    # The contract must never record an entry the reviewer manifest lacks.
    foreach ($key in $contractKeys) {
        if (-not $reviewerKeys.Contains($key)) { return $false }
    }
    # The reviewer manifest may only exceed the contract with the four
    # implementation layer specs; any other extra entry is a fail.
    foreach ($item in @($ReviewerManifest)) {
        $key = "$([string]$item.path)`t$([string]$item.sha256)"
        if (-not $contractKeys.Contains($key)) {
            if (-not (Test-AllowedLayerSupersetPath ([string]$item.path) $Feature $Stage $RepositoryRoot $RecordedRoot)) {
                return $false
            }
        }
    }
    return $true
}
function Test-ManifestPaths(
    $Contract, [string]$Feature, [string]$Stage, [int]$Attempt, [int]$Round,
    [string]$RepositoryRoot
) {
    $recorded = Get-RecordedRepositoryRoot $Contract $RepositoryRoot
    if (-not $recorded.Valid) { return $false }
    $attemptRoot = "reports/$Stage-review/$Feature/attempt-$Attempt"
    $roundRoot = "$attemptRoot/round-$Round"
    foreach ($reviewer in @($Contract.reviewers)) {
        $role = [string]$reviewer.role
        $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($path in @(
            "specs/$Feature/requirements.md",
            "specs/$Feature/acceptance-tests.md",
            "specs/$Feature/investigation.md",
            "$roundRoot/precheck-result.json"
        )) { [void]$allowed.Add($path) }
        if ($Stage -eq "spec") {
            [void]$allowed.Add("plugins/sdd-review-loop/references/spec-review-calibration.md")
        } else {
            [void]$allowed.Add("plugins/sdd-review-loop/references/reviewer-calibration.md")
        }
        if ($Stage -eq "impl") {
            foreach ($path in @(
                "specs/$Feature/design.md", "specs/$Feature/ux-spec.md",
                "specs/$Feature/frontend-spec.md", "specs/$Feature/infra-spec.md",
                "specs/$Feature/security-spec.md"
            )) { [void]$allowed.Add($path) }
        }
        if ($Stage -eq "task") {
            foreach ($path in @(
                "specs/$Feature/tasks.md", "specs/$Feature/traceability.md",
                "specs/$Feature/design.md",
                "specs/$Feature/ux-spec.md", "specs/$Feature/frontend-spec.md",
                "specs/$Feature/infra-spec.md", "specs/$Feature/security-spec.md"
            )) { [void]$allowed.Add($path) }
        }
        if ($role -eq "$Stage-reviewer-b") { [void]$allowed.Add("$roundRoot/integrated-summary.json") }
        if ($Stage -eq "impl" -and $role -eq "impl-reviewer-a" -and $Round -gt 1) {
            [void]$allowed.Add("$attemptRoot/round-$($Round - 1)/integrated-summary.json")
        }
        if ($Stage -eq "task" -and $role -eq "task-reviewer-a") {
            [void]$allowed.Add("$roundRoot/dependency-graph.json")
        }
        if ($Stage -eq "task" -and $role -eq "task-reviewer-b") {
            [void]$allowed.Add("plugins/sdd-quality-loop/references/risk-gate-matrix.md")
            [void]$allowed.Add("plugins/sdd-quality-loop/references/risk-classification-policy.md")
        }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $path = Get-RepositoryRelativePath ([string]$item.path) $RepositoryRoot $recorded.Root
            if ($null -eq $path) { return $false }
            if ($path -match "(^|/)\.\.?(/|$)" -or -not $allowed.Contains($path) -or
                -not $seen.Add($path)) { return $false }
        }
    }
    return $true
}

$ScriptRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
$Registry = Join-Path $ScriptRoot "specs/workflow-state-registry.json"
$FeatureFilter = ""
$script:OpeningStage = ""
$script:OpeningAttempt = 0
$script:OpeningRound = 0
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ([string]$args[$i]) {
        "--feature" {
            if (++$i -ge $args.Count) { Stop-WorkflowState "repository" "cli-usage" "--feature requires a value" }
            $FeatureFilter = [string]$args[$i]
        }
        "--registry" {
            if (++$i -ge $args.Count) { Stop-WorkflowState "repository" "cli-usage" "--registry requires a value" }
            $Registry = [string]$args[$i]
        }
        "--opening" {
            if (++$i -ge $args.Count) { Stop-WorkflowState "repository" "cli-usage" "--opening requires a value" }
            $openingValue = [string]$args[$i]
            if ($openingValue -notmatch "^(spec|impl|task):([1-9][0-9]*):([1-9][0-9]*)$") {
                Stop-WorkflowState "repository" "cli-usage" "--opening must be stage:attempt:round"
            }
            $script:OpeningStage = $Matches[1]
            $script:OpeningAttempt = [int]$Matches[2]
            $script:OpeningRound = [int]$Matches[3]
        }
        default { Stop-WorkflowState "repository" "cli-usage" "unknown argument: $($args[$i])" }
    }
}
if ($FeatureFilter -and $FeatureFilter -notmatch "^[a-z0-9][a-z0-9-]*$") {
    Stop-WorkflowState $FeatureFilter "cli-usage" "invalid feature slug"
}
# --opening names the single round a review-loop precheck is about to open;
# it only ever makes sense pinned to the one feature it belongs to, never as
# a blanket exemption swept across the whole registry.
if ($script:OpeningStage -and -not $FeatureFilter) {
    Stop-WorkflowState "repository" "cli-usage" "--opening requires --feature"
}
if (-not (Test-Path -LiteralPath $Registry -PathType Leaf) -or
    (Get-Item -LiteralPath $Registry -Force).LinkType) {
    Stop-WorkflowState "repository" "registry-unreadable" "registry is missing, linked, or unreadable"
}
try { $RegistryText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Registry).Path) }
catch { Stop-WorkflowState "repository" "registry-unreadable" "registry is missing, linked, or unreadable" }
try { $RegistryData = $RegistryText | ConvertFrom-Json }
catch { Stop-WorkflowState "repository" "registry-malformed" "registry is not valid JSON" }
if ($RegistryData.schema_version -ne 1 -or -not @($RegistryData.entries).Count) {
    Stop-WorkflowState "repository" "registry-malformed" "registry shape or version is invalid"
}
foreach ($entry in @($RegistryData.entries)) {
    if ([string]$entry.feature -notmatch "^[a-z0-9][a-z0-9-]*$" -or
        [string]$entry.profile -notin @("full", "lite", "legacy")) {
        Stop-WorkflowState "repository" "registry-malformed" "registry shape or version is invalid"
    }
}
function Test-JsonValueEqual($Left, $Right) {
    if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left) -and ($null -eq $Right) }
    $leftIsObject = $Left -is [Management.Automation.PSCustomObject]
    $rightIsObject = $Right -is [Management.Automation.PSCustomObject]
    if ($leftIsObject -or $rightIsObject) {
        if (-not ($leftIsObject -and $rightIsObject)) { return $false }
        $leftNames = @($Left.PSObject.Properties.Name | Sort-Object)
        $rightNames = @($Right.PSObject.Properties.Name | Sort-Object)
        if (($leftNames -join "`t") -cne ($rightNames -join "`t")) { return $false }
        foreach ($name in $leftNames) {
            if (-not (Test-JsonValueEqual $Left.$name $Right.$name)) { return $false }
        }
        return $true
    }
    $leftIsArray = $Left -is [array]
    $rightIsArray = $Right -is [array]
    if ($leftIsArray -or $rightIsArray) {
        if (-not ($leftIsArray -and $rightIsArray) -or $Left.Count -ne $Right.Count) { return $false }
        for ($i = 0; $i -lt $Left.Count; $i++) {
            if (-not (Test-JsonValueEqual $Left[$i] $Right[$i])) { return $false }
        }
        return $true
    }
    return $Left -ceq $Right
}
# PS5.1-safe (no Test-Json, unavailable before PowerShell 6.1): mirrors the
# hand-rolled structural check in the bash twin (check-workflow-state.sh)
# rather than general JSON Schema validation, so both stay in parity and
# neither depends on a cmdlet this repo's Windows hosts don't have.
function Test-RegistrySchema($RegistryData, [string]$SchemaPath) {
    try { $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json }
    catch { return $false }
    $topKeys = @($RegistryData.PSObject.Properties.Name | Sort-Object)
    if (($topKeys -join "`t") -cne (@("entries", "migration_baseline_commit", "schema_version") -join "`t")) {
        return $false
    }
    if (-not (Test-JsonValueEqual $RegistryData.schema_version $schema.properties.schema_version.const) -or
        -not (Test-JsonValueEqual $RegistryData.migration_baseline_commit $schema.properties.migration_baseline_commit.const)) {
        return $false
    }
    # The jq twin requires .entries to be a JSON array; @() coercion alone
    # would let a scalar entries object pass as a one-item list.
    if ($RegistryData.entries -isnot [array]) { return $false }
    $entries = @($RegistryData.entries)
    if ($entries.Count -eq 0) { return $false }
    $legacyConsts = @($schema.definitions.legacyEntry.oneOf | ForEach-Object { $_.const })
    foreach ($entry in $entries) {
        $entryProfile = [string]$entry.profile
        if ($entryProfile -eq "full" -or $entryProfile -eq "lite") {
            $entryKeys = @($entry.PSObject.Properties.Name | Sort-Object)
            if (($entryKeys -join "`t") -cne (@("feature", "profile") -join "`t")) { return $false }
        } else {
            $matched = $false
            foreach ($candidate in $legacyConsts) {
                if (Test-JsonValueEqual $entry $candidate) { $matched = $true; break }
            }
            if (-not $matched) { return $false }
        }
    }
    return $true
}

$Schema = Join-Path $ScriptRoot "contracts/workflow-state-registry.schema.json"
if (-not (Test-Path -LiteralPath $Schema -PathType Leaf)) {
    Stop-WorkflowState "repository" "registry-schema" "registry schema is unavailable"
}
if (-not (Test-RegistrySchema $RegistryData $Schema)) {
    Stop-WorkflowState "repository" "registry-schema" "registry entry violates the bounded schema"
}

$SpecsRoot = (Resolve-Path (Split-Path -Parent $Registry)).Path
$RepoRoot = (Resolve-Path (Join-Path $SpecsRoot "..")).Path
$duplicate = @($RegistryData.entries | Group-Object feature | Where-Object Count -gt 1 | Select-Object -First 1)
if ($duplicate) { Stop-WorkflowState $duplicate[0].Name "registry-duplicate" "feature is registered more than once" }
$declared = @{}
$script:RegistryFailedFeatures = @{}
foreach ($entry in @($RegistryData.entries)) {
    $feature = [string]$entry.feature
    $declared[$feature] = $true
    $script:FeatureScopeActive = $true
    try {
        $candidate = Join-Path $SpecsRoot $feature
        if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
            Stop-WorkflowState $feature "registry-dangling-entry" "registered specification directory is missing"
        }
        $item = Get-Item -LiteralPath $candidate -Force
        if ($item.LinkType) {
            $target = [string]$item.Target
            if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $item.Parent.FullName $target }
            $resolved = [IO.Path]::GetFullPath($target)
        } else {
            $resolved = (Resolve-Path -LiteralPath $candidate).Path
        }
        $prefix = $SpecsRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not ($resolved + [IO.Path]::DirectorySeparatorChar).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-WorkflowState $feature "registry-path-escape" "registered directory escapes specs root"
        }
        if ($item.LinkType) {
            Stop-WorkflowState $feature "registry-linked-entry" "registered specification directory must not be linked"
        }
    } catch {
        if ([string]$_.Exception.Message -ne $script:WorkflowStateFeatureAbort) { throw }
        $script:WorkflowStateFailed++
        $script:RegistryFailedFeatures[$feature] = $true
    } finally {
        $script:FeatureScopeActive = $false
    }
}
foreach ($directory in @(Get-ChildItem -LiteralPath $SpecsRoot -Directory -Force)) {
    if (-not $declared.ContainsKey($directory.Name)) {
        Write-WorkflowStateDiagnostic $directory.Name "registry-unregistered-directory" "specification directory is not registered"
        $script:WorkflowStateFailed++
    }
}
if ($FeatureFilter -and -not $declared.ContainsKey($FeatureFilter)) {
    Stop-WorkflowState $FeatureFilter "registry-unknown-feature" "feature is not registered"
}

# A BLOCKED or NEEDS_WORK verdict is the terminal state of one review pass,
# not necessarily of the stage: a caller can re-open review after it (a
# fresh attempt, or another round of the same attempt), and it is that later
# pass -- not the one it superseded -- whose outcome the stage should be
# judged on while it is still running.
#
# A tree-only signal cannot express this: the gate that must pass before a
# new round is created runs BEFORE that round's own directory exists (this
# is precisely what impl-review-precheck.sh's own replay guard requires --
# "round destination already exists" is fatal), so nothing on disk can ever
# prove a round is "open" at the one moment this check needs to know it. An
# earlier version of this fix looked for a precheck-result.json in a later
# round directory; that file cannot exist yet either, for the same reason,
# so the exemption could never fire for the caller it exists for.
#
# The distinction that actually matters is who is asking, not what the tree
# looks like right now (same conflation as before, resolved one level up).
# A review-loop precheck opening round (attempt, round) knows those numbers
# as its own CLI arguments -- ATTEMPT and ROUND -- before it ever reaches
# this gate, and it is asking "may I start?", not "did this conclude?". It
# says so explicitly via -Opening stage:attempt:round. A standalone
# invocation (CI, task-state-check, anything auditing the feature's health)
# never passes -Opening and gets none of this exemption: the latest verdict
# governs for it exactly as before, unconditionally.
#
# -Opening is not "a flag anyone can pass to wave away a BLOCKED verdict",
# because it does not assert "trust me, this stage is fine" -- it names one
# specific (attempt, round) pair, and this function independently checks
# that pair against the tree's own recorded history before granting
# anything. The ONLY value it will ever accept is the single true next slot
# after the latest recorded verdict: either the next round of the SAME
# attempt (BestRound + 1) or round 1 of a BRAND NEW attempt
# (BestAttempt + 1). A caller cannot use it to skip past an intervening
# verdict, resurrect an arbitrarily old BLOCKED attempt, or manufacture a
# history that was never reviewed -- it can only ever confirm that trying
# again, right here, right now, is the structurally legitimate next step,
# which is true for any BLOCKED or NEEDS_WORK stage by the review loop's
# own design. It grants no power beyond what the tree already permits; it
# only lets the one caller who is about to exercise that permission prove
# which pair of numbers it refers to before the evidence for it exists.
function Test-StageIsBeingOpened([string]$Stage, [string]$Feature, [int]$BestAttempt, [int]$BestRound) {
    if (-not $script:OpeningStage -or $script:OpeningStage -ne $Stage -or $FeatureFilter -ne $Feature) {
        return $false
    }
    if (($script:OpeningAttempt -eq $BestAttempt -and $script:OpeningRound -eq ($BestRound + 1)) -or
        ($script:OpeningAttempt -eq ($BestAttempt + 1) -and $script:OpeningRound -eq 1)) {
        # Recorded as a side effect (not just a boolean return) so the
        # downstream-staleness tolerance below can be granted independently
        # of whether THIS stage's own PASS check happens to need the
        # exemption -- see the call site right after $latest is computed.
        $script:OpeningVerifiedStage = $Stage
        return $true
    }
    return $false
}
# Walk order for the three review stages, spec first. Used only to decide
# which stages are "downstream" of the one -Opening names: opening impl
# must still require spec to be fully sound (upstream, untouched), while
# task -- reviewed after impl and liable to have pinned impl's own inputs
# (e.g. design.md) -- is where the recovery -Opening exists for shows up
# as staleness, not corruption.
function Get-StageOrder([string]$Stage) {
    switch ($Stage) {
        "spec" { return 1 }
        "impl" { return 2 }
        "task" { return 3 }
    }
}
# Empty unless a -Opening slot has been independently verified (via
# Test-StageIsBeingOpened) as the structurally-next one for the stage it
# names. Never set for a standalone invocation (no -Opening), and never set
# for a slot that fails that verification.
$script:OpeningVerifiedStage = ""
# True only when $Stage is strictly downstream (in walk order) of the
# verified -Opening stage. False when -Opening was not passed or did not
# verify, false for the opened stage itself (it keeps its own pre-existing
# exemption above, not this one), and false for any upstream stage.
function Test-StageDownstreamOfOpening([string]$Stage) {
    if (-not $script:OpeningVerifiedStage) { return $false }
    return (Get-StageOrder $Stage) -gt (Get-StageOrder $script:OpeningVerifiedStage)
}
# Like Stop-WorkflowState(), but tolerated -- returns instead of throwing/
# exiting -- when the stage under validation is strictly downstream of a
# verified -Opening slot. Reserved for diagnostics that mean "the pinned
# bytes moved": the expected, recoverable state of a downstream stage whose
# own reviewed input (e.g. design.md, a layer spec) was legitimately
# amended as part of the very recovery -Opening exists to permit. Every
# call site below is commented with why that specific diagnostic qualifies.
function Stop-WorkflowStateOrTolerate([string]$Feature, [string]$Stage, [string]$Rule, [string]$Message) {
    if (Test-StageDownstreamOfOpening $Stage) { return }
    Stop-WorkflowState $Feature $Rule $Message
}
# Test-ManifestHash's "no (path, hash) pair matches" failure conflates two
# different provenance states: the path was never declared (a genuine gap)
# and the path was declared but the review ran before the file's current
# amendment (staleness wearing the same diagnostic). Both produce the
# identical $false, so every "reviewer manifests omit ..." / "contract
# hashes are stale" diagnostic built on it inherited that ambiguity. This
# resolves it, narrowly: only when downstream of a verified -Opening slot
# (never standalone, never upstream -- same discipline as
# Stop-WorkflowStateOrTolerate above), ask Get-ManifestRecordedHashesForPath
# whether the path was recorded at all. Exactly one recorded hash,
# different from the expected (current) one, is unambiguous staleness --
# the manifest already knew this input, just at pre-amendment bytes -- and
# is tolerated with a notice naming the path and both hashes, so the
# recovery is visible rather than silently waved through. Zero recorded
# hashes (the path never appeared) or more than one distinct recorded hash
# (reviewers disagree about this path, which is not simple staleness) leave
# the original diagnostic firing exactly as before.
function Write-TolerantOmitNotice([string]$Feature, [string]$Suffix, [string]$Recorded, [string]$Expected) {
    [Console]::Error.WriteLine(
        "workflow-state: ${Feature}: stage-provenance-tolerated: $($Suffix.TrimStart('/')) recorded $Recorded, now $Expected")
}
# $Checks: array of @{ Ok=[bool]; Suffix=[string]; Expected=[string] }, one
# entry per path the failing check covers. A check that aggregates several
# paths (e.g. calibration doc + precheck-result.json, or requirements.md +
# acceptance-tests.md) must still fail with its ORIGINAL diagnostic if even
# ONE of its paths is a genuine omission, regardless of whether the others
# are merely stale -- so every not-ok entry must independently explain as
# staleness for the whole check to be tolerated.
function Stop-WorkflowStateOrTolerateOmit(
    [string]$Feature, [string]$Stage, [string]$Rule, [string]$Message,
    $Contract, [string]$RepositoryRoot, [array]$Checks
) {
    $allExplained = $true
    foreach ($check in $Checks) {
        if ($check.Ok) { continue }
        $explained = $false
        if (Test-StageDownstreamOfOpening $Stage) {
            $hashes = @(Get-ManifestRecordedHashesForPath $Contract $check.Suffix $RepositoryRoot)
            if ($hashes.Count -eq 1 -and $hashes[0] -ne $check.Expected) {
                Write-TolerantOmitNotice $Feature $check.Suffix $hashes[0] $check.Expected
                $explained = $true
            }
        }
        if (-not $explained) { $allExplained = $false }
    }
    if ($allExplained) { return }
    Stop-WorkflowState $Feature $Rule $Message
}
# Validate raw JSON before ConvertFrom-Json can erase repeated members.
# Input must be decoded from the SAME safe byte snapshot the caller hashes.
function Assert-AdrJsonMembers([string]$Text) {
    $tokens = [regex]::new('\G(?:"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null|[{}\[\]:,])')
    $space = [regex]::new('\G[ \t\r\n]*')
    # Explicit frames avoid a new recursion-depth limit; keys belong to one
    # object instance, not a global path map (array siblings may repeat keys).
    $frames = [Collections.Generic.List[object]]::new()
    $frames.Add([pscustomobject]@{ Kind='root'; Phase='value'; Keys=$null })
    $offset = 0
    while ($offset -lt $Text.Length) {
        $offset += $space.Match($Text, $offset).Length
        if ($offset -eq $Text.Length) { break }
        $match = $tokens.Match($Text, $offset)
        if (-not $match.Success) { throw 'ADR JSON has an invalid token' }
        $token = $match.Value
        $offset += $match.Length
        $frame = $frames[$frames.Count - 1]
        if ($frame.Phase -ceq 'colon') {
            if ($token -cne ':') { throw 'ADR JSON member has no colon' }
            $frame.Phase = 'value'
            continue
        }
        if ($frame.Phase -ceq 'comma-or-end') {
            $closing = if ($frame.Kind -ceq 'object') { '}' } else { ']' }
            if ($token -ceq $closing) {
                $frames.RemoveAt($frames.Count - 1)
                continue
            }
            if ($token -cne ',') { throw 'ADR JSON missing separator' }
            $frame.Phase = if ($frame.Kind -ceq 'object') { 'key' } else { 'value' }
            continue
        }
        if ($frame.Phase -ceq 'key-or-end' -and $token -ceq '}') {
            $frames.RemoveAt($frames.Count - 1)
            continue
        }
        if ($frame.Phase -ceq 'value-or-end' -and $token -ceq ']') {
            $frames.RemoveAt($frames.Count - 1)
            continue
        }
        if ($frame.Phase -ceq 'key' -or $frame.Phase -ceq 'key-or-end') {
            if (-not $token.StartsWith('"', [StringComparison]::Ordinal)) {
                throw 'ADR JSON object key is not a string'
            }
            # Parse one isolated string, never a whole object with duplicate
            # keys. Array wrapping preserves the empty string in PS5.1.
            $decoded = @(ConvertFrom-Json -InputObject ('[' + $token + ']') -ErrorAction Stop)
            if ($decoded.Count -ne 1 -or $decoded[0] -isnot [string]) {
                throw 'ADR JSON key decoding failed'
            }
            if (-not $frame.Keys.Add($decoded[0])) { throw 'ADR JSON duplicate decoded member' }
            $frame.Phase = 'colon'
            continue
        }
        if ($frame.Phase -cne 'value' -and $frame.Phase -cne 'value-or-end') {
            throw 'ADR JSON has trailing content'
        }
        # Consume this value at its parent before descending into a container.
        # A comma requires a value/key, so trailing commas cannot close it.
        $frame.Phase = if ($frame.Kind -ceq 'root') { 'done' } else { 'comma-or-end' }
        if ($token -ceq '{') {
            $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $frames.Add([pscustomobject]@{ Kind='object'; Phase='key-or-end'; Keys=$keys })
        } elseif ($token -ceq '[') {
            $frames.Add([pscustomobject]@{ Kind='array'; Phase='value-or-end'; Keys=$null })
        } elseif ($token -ceq '}' -or $token -ceq ']' -or $token -ceq ':' -or $token -ceq ',') {
            throw 'ADR JSON value missing or container mismatched'
        }
    }
    if ($frames.Count -ne 1 -or $frames[0].Phase -cne 'done') {
        throw 'ADR JSON is empty or incomplete'
    }
}
# Caller must first validate every path component; this reader alone does
# not prevent symlink races. Never reopen the path to compute this digest.
function Read-AdrJsonSnapshot([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $decoder = [Text.UTF8Encoding]::new($false, $true)
    $text = $decoder.GetString($bytes)
    # Permit a leading UTF-8 BOM without excluding its bytes from the hash.
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xfeff) {
        $text = $text.Substring(1)
    }
    Assert-AdrJsonMembers $text
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
    return [pscustomobject]@{ Path=$Path; Sha256=$digest; Text=$text }
}
# ADR history core binding. Does not read current ADR bytes or grant admission.
# The full history caller must also validate identities, manifests and summaries.
function Get-AdrHistoryCoreBinding($Contract, $Precheck) {
    function Get-ExactAdrField($Object, [string]$Name) {
        if ($Object -isnot [pscustomobject]) { throw 'ADR record must be an object' }
        $properties = @($Object.PSObject.Properties | Where-Object {
            [string]::Equals($_.Name, $Name, [StringComparison]::Ordinal)
        })
        if ($properties.Count -ne 1) { throw "ADR field missing: $Name" }
        # Preserve JSON [] and singleton arrays in Windows PowerShell 5.1.
        return ,($properties[0].Value)
    }
    function Test-AdrDigest($Value) {
        return ($Value -is [string] -and $Value -cmatch '\A[0-9a-f]{64}\z')
    }
    function Get-AdrCanonicalEntries($Entries) {
        if ($Entries -isnot [array]) { throw 'ADR entries must be an array' }
        $serialized = [Collections.Generic.List[string]]::new()
        $previous = $null
        foreach ($entry in $Entries) {
            if ($entry -isnot [pscustomobject] -or
                @($entry.PSObject.Properties).Count -ne 2) { throw 'ADR entry shape invalid' }
            $path = Get-ExactAdrField $entry 'path'
            $hash = Get-ExactAdrField $entry 'sha256'
            if ($path -isnot [string] -or
                $path -cnotmatch '\Adocs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md\z' -or
                -not (Test-AdrDigest $hash)) { throw 'ADR entry path or hash invalid' }
            if ($null -ne $previous -and
                [StringComparer]::Ordinal.Compare($previous, $path) -ge 0) {
                throw 'ADR entries must be sorted and unique'
            }
            $previous = $path
            # Both values are restricted ASCII without JSON escape characters.
            $serialized.Add('{"path":"' + $path + '","sha256":"' + $hash + '"}')
        }
        return '[' + [string]::Join(',', $serialized.ToArray()) + ']'
    }
    function Get-AdrCanonicalLayers($Layers) {
        if ($Layers -isnot [pscustomobject]) { throw 'ADR layers must be an object' }
        $properties = @($Layers.PSObject.Properties)
        if ($properties.Count -eq 0) { return '{}' }
        if ($properties.Count -ne 4) { throw 'ADR layer key count invalid' }
        $parts = [Collections.Generic.List[string]]::new()
        # ASCII key order matches jq -cS, independently of locale.
        foreach ($name in @('frontend-spec.md','infra-spec.md','security-spec.md','ux-spec.md')) {
            $hash = Get-ExactAdrField $Layers $name
            if (-not (Test-AdrDigest $hash)) { throw 'ADR layer hash invalid' }
            $parts.Add('"' + $name + '":"' + $hash + '"')
        }
        return '{' + [string]::Join(',', $parts.ToArray()) + '}'
    }
    if ($Contract -isnot [pscustomobject] -or
        ($null -ne $Precheck -and $Precheck -isnot [pscustomobject])) {
        throw 'ADR history records must be objects'
    }
    $contractPresent = @($Contract.PSObject.Properties.Name) -ccontains 'adr_inputs'
    $precheckPresent = $null -ne $Precheck -and
        @($Precheck.PSObject.Properties.Name) -ccontains 'adr_inputs'
    if ($contractPresent -ne $precheckPresent) { throw 'one-sided ADR extension' }
    if (-not $contractPresent) {
        # The caller still rejects ADR-like paths in every legacy manifest.
        return [pscustomobject]@{ Extended=$false; EntriesJson='[]' }
    }
    $entries = Get-AdrCanonicalEntries (Get-ExactAdrField $Precheck 'adr_inputs')
    if ((Get-AdrCanonicalEntries (Get-ExactAdrField $Contract 'adr_inputs')) -cne $entries) {
        throw 'ADR saved sets disagree'
    }
    $pins = [Collections.Generic.List[string]]::new()
    foreach ($name in @('design_sha256','requirements_sha256','acceptance_sha256')) {
        $pin = Get-ExactAdrField $Precheck $name
        $other = Get-ExactAdrField $Contract $name
        if (-not (Test-AdrDigest $pin) -or -not (Test-AdrDigest $other) -or $pin -cne $other) {
            throw 'ADR core pins disagree'
        }
        $pins.Add($pin)
    }
    # Extended records explicitly bind an empty or complete layer map.
    $layerJson = @(
        (Get-AdrCanonicalLayers (Get-ExactAdrField $Precheck 'layer_sha256')),
        (Get-AdrCanonicalLayers (Get-ExactAdrField $Contract 'layer_sha256')))
    if ($layerJson[0] -cne $layerJson[1]) { throw 'ADR saved layer pins disagree' }
    $material = [string]::Join(':', $pins.ToArray())
    if ($layerJson[0] -cne '{}') { $material += ':' + $layerJson[0] }
    $material += ':adr_inputs/v1:' + $entries
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = [BitConverter]::ToString($hasher.ComputeHash(
            [Text.Encoding]::ASCII.GetBytes($material))).Replace('-', '').ToLowerInvariant()
    } finally { $hasher.Dispose() }
    $recordedDigest = Get-ExactAdrField $Precheck 'input_sha256'
    if (-not (Test-AdrDigest $recordedDigest) -or $recordedDigest -cne $digest) {
        throw 'ADR saved input digest mismatch'
    }
    return [pscustomobject]@{ Extended=$true; EntriesJson=$entries }
}
# Called for each of the four ADR-extended saved manifests. Snapshot hashes and
# canonical core/ADR validation are prerequisites owned by the history caller.
function Get-AdrHistoryManifest($Manifest, [string]$Role, $Precheck,
    [string]$Feature, [int]$Attempt, [int]$Round, [string]$RepositoryRoot,
    [string]$RecordedRoot, [string]$PrecheckHash, [string]$SummaryHash,
    [string]$PreviousSummaryHash) {
    if ($Role -cnotin @('impl-reviewer-a','impl-reviewer-b') -or
        $Manifest -isnot [array]) { throw 'ADR manifest role or array invalid' }
    $roundRoot = "reports/impl-review/$Feature/attempt-$Attempt/round-$Round"
    $pcPath = "$roundRoot/precheck-result.json"
    $designPath = "specs/$Feature/design.md"
    $summaryPath = "$roundRoot/integrated-summary.json"
    $previousPath = "reports/impl-review/$Feature/attempt-$Attempt/round-$($Round-1)/integrated-summary.json"
    $calibration = 'plugins/sdd-review-loop/references/reviewer-calibration.md'
    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in @('requirements.md','acceptance-tests.md','investigation.md',
        'design.md','ux-spec.md','frontend-spec.md','infra-spec.md','security-spec.md')) {
        [void]$allowed.Add("specs/$Feature/$name")
    }
    [void]$allowed.Add($calibration)
    [void]$allowed.Add($pcPath)
    if ($Role -ceq 'impl-reviewer-b') { [void]$allowed.Add($summaryPath) }
    if ($Role -ceq 'impl-reviewer-a' -and $Round -gt 1) { [void]$allowed.Add($previousPath) }
    $adrs = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $Precheck.adr_inputs) { $adrs.Add($entry.path, $entry.sha256) }
    $normalized = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $raw = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $Manifest) {
        if ($entry -isnot [pscustomobject] -or
            @($entry.PSObject.Properties.Name) -cnotcontains 'path' -or
            @($entry.PSObject.Properties.Name) -cnotcontains 'sha256' -or
            $entry.path -isnot [string] -or $entry.path.Length -eq 0 -or
            $entry.sha256 -isnot [string] -or $entry.sha256 -cnotmatch '\A[0-9a-f]{64}\z') {
            throw 'ADR manifest entry invalid'
        }
        $relative = Get-RepositoryRelativePath $entry.path $RepositoryRoot $RecordedRoot
        if ($null -eq $relative -or $relative -cmatch '(^|/)[.]{1,2}(/|$)' -or
            $normalized.ContainsKey($relative)) { throw 'ADR manifest path invalid or duplicated' }
        # Detect all ADR-like aliases before relocation; only raw canonical
        # declarations may use this branch. Case-insensitive detection rejects
        # mis-cased aliases rather than granting them authority.
        if ($entry.path.Replace('\','/') -imatch '(^|/)docs/adr/') {
            if (-not $adrs.ContainsKey($entry.path) -or $adrs[$entry.path] -cne $entry.sha256) {
                throw 'ADR manifest member is undeclared or differs from precheck'
            }
        } elseif (-not $allowed.Contains($relative)) { throw 'ADR manifest violates role isolation' }
        $normalized.Add($relative, $entry.sha256)
        $raw.Add($entry.path, $entry.sha256)
    }
    # Precheck/design must have exact raw canonical entries, not relocated aliases.
    if (-not $raw.ContainsKey($pcPath) -or $raw[$pcPath] -cne $PrecheckHash -or
        -not $raw.ContainsKey($designPath) -or $raw[$designPath] -cne $Precheck.design_sha256) {
        throw 'ADR manifest precheck or design pin invalid'
    }
    $required = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $required.Add("specs/$Feature/requirements.md", $Precheck.requirements_sha256)
    $required.Add("specs/$Feature/acceptance-tests.md", $Precheck.acceptance_sha256)
    foreach ($pin in $Precheck.layer_sha256.PSObject.Properties) {
        $required.Add("specs/$Feature/$($pin.Name)", $pin.Value)
    }
    if ($Role -ceq 'impl-reviewer-b') { $required.Add($summaryPath, $SummaryHash) }
    if ($Role -ceq 'impl-reviewer-a' -and $Round -gt 1) {
        $required.Add($previousPath, $PreviousSummaryHash)
    }
    foreach ($pin in $required.GetEnumerator()) {
        if ($pin.Value -cnotmatch '\A[0-9a-f]{64}\z' -or
            -not $normalized.ContainsKey($pin.Key) -or $normalized[$pin.Key] -cne $pin.Value) {
            throw 'ADR manifest required pin missing or inconsistent'
        }
    }
    if (-not $normalized.ContainsKey($calibration)) { throw 'ADR manifest calibration missing' }
    foreach ($pin in $adrs.GetEnumerator()) {
        if (-not $raw.ContainsKey($pin.Key) -or $raw[$pin.Key] -cne $pin.Value) {
            throw 'ADR manifest omits declared input'
        }
    }
    return [pscustomobject]@{ Raw=$raw; Normalized=$normalized }
}
function Test-AdrHistoryManifestSuperset($Actual, $Bound, [string]$Feature) {
    foreach ($entry in $Bound.Raw.GetEnumerator()) {
        if (-not $Actual.Raw.ContainsKey($entry.Key) -or
            $Actual.Raw[$entry.Key] -cne $entry.Value) { return $false }
    }
    $layers = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in @('ux-spec.md','frontend-spec.md','infra-spec.md','security-spec.md')) {
        [void]$layers.Add("specs/$Feature/$name")
    }
    foreach ($entry in $Actual.Normalized.GetEnumerator()) {
        if (-not $Bound.Normalized.ContainsKey($entry.Key) -and
            -not $layers.Contains($entry.Key)) { return $false }
    }
    return $true
}
# Called only for ADR-extended records, before opening freshness tolerance.
# Full history binding validates manifest structure and pins separately.
function Test-AdrSharedLayerAgreement($Contract, $ReviewerA, $ReviewerB,
    [string]$Feature, [string]$RepositoryRoot) {
    $recorded = Get-RecordedRepositoryRoot $Contract $RepositoryRoot
    if (-not $recorded.Valid) { return $false }
    # Ordinal keys: PowerShell's default hashtable is case-insensitive.
    $hashes = [Collections.Generic.Dictionary[string,string]]::new(
        [StringComparer]::Ordinal)
    $owners = @($Contract.reviewers) + @($ReviewerA, $ReviewerB)
    foreach ($owner in $owners) {
        foreach ($item in @($owner.allowed_input_manifest)) {
            if ($null -eq $item -or $item.path -isnot [string]) { return $false }
            $relative = Get-RepositoryRelativePath $item.path $RepositoryRoot $recorded.Root
            if ($null -eq $relative) { return $false }
            $isLayer = $false
            foreach ($name in @('ux-spec.md','frontend-spec.md','infra-spec.md','security-spec.md')) {
                if ([string]::Equals($relative, "specs/$Feature/$name", [StringComparison]::Ordinal)) {
                    $isLayer = $true
                    break
                }
            }
            if (-not $isLayer) { continue }
            if ($item.sha256 -isnot [string] -or $item.sha256 -cnotmatch '^[0-9a-f]{64}$') {
                return $false
            }
            if ($hashes.ContainsKey($relative) -and $hashes[$relative] -cne $item.sha256) {
                return $false
            }
            $hashes[$relative] = $item.sha256
        }
    }
    return $true
}
# Saved output checks only; the caller must validate safe JSON snapshots,
# precheck/core pins, four manifests, summaries and current-stage freshness.
function Test-AdrHistoryOutputs($Contract, $ReviewerA, $ReviewerB, $Verdict,
    [string]$Feature, [int]$Attempt, [int]$Round) {
    function Field($Object, [string]$Name) {
        if ($Object -isnot [pscustomobject]) { throw 'ADR output is not an object' }
        $exactProperties = @($Object.PSObject.Properties | Where-Object {
            [string]::Equals($_.Name, $Name, [StringComparison]::Ordinal)
        })
        if ($exactProperties.Count -ne 1) { throw "ADR output field missing: $Name" }
        return ,($exactProperties[0].Value)
    }
    function TextEquals($Actual, [string]$Expected) {
        return ($Actual -is [string] -and
            [string]::Equals($Actual, $Expected, [StringComparison]::Ordinal))
    }
    function Nonempty($Value) {
        return ($Value -is [string] -and $Value.Length -gt 0)
    }
    function CountEquals($Value, [long]$Expected) {
        # JSON numeric values only; never coerce strings, bools or null.
        if ($Value -isnot [int] -and $Value -isnot [long] -and
            $Value -isnot [double] -and $Value -isnot [decimal]) { return $false }
        return ($Value -ge 0 -and $Value -eq $Expected)
    }
    function CheckIdentity($Object, [string]$Schema) {
        if (-not (TextEquals (Field $Object 'schema') $Schema) -or
            -not (TextEquals (Field $Object 'feature') $Feature) -or
            -not (TextEquals (Field $Object 'stage') 'impl') -or
            -not (CountEquals (Field $Object 'attempt') $Attempt) -or
            -not (CountEquals (Field $Object 'round') $Round) -or
            -not (Nonempty (Field $Object 'run_id'))) { throw 'ADR output identity invalid' }
    }
    CheckIdentity $Contract 'impl-review-contract/v1'
    CheckIdentity $Verdict 'integrated-verdict/v1'
    if (-not (TextEquals (Field $Verdict 'run_id') (Field $Contract 'run_id'))) {
        throw 'ADR integrated run ID mismatch'
    }
    $bound = Field $Contract 'reviewers'
    if ($bound -isnot [array] -or $bound.Count -ne 2) { throw 'ADR reviewer pair invalid' }
    $roles = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $runs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $sessions = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($reviewer in $bound) {
        $role = Field $reviewer 'role'
        $run = Field $reviewer 'run_id'
        $session = Field $reviewer 'host_session_id'
        if ((-not (TextEquals $role 'impl-reviewer-a') -and
             -not (TextEquals $role 'impl-reviewer-b')) -or
            -not (Nonempty $run) -or -not (Nonempty $session)) {
            throw 'ADR reviewer reservation identity invalid'
        }
        if ($roles.ContainsKey($role) -or -not $runs.Add($run) -or
            -not $sessions.Add($session)) { throw 'ADR reviewer identities must be distinct' }
        $roles.Add($role, $reviewer)
    }
    $totals = @{ Critical=0L; Major=0L; Minor=0L }
    $results = [Collections.Generic.List[object]]::new()
    foreach ($pair in @(
        [pscustomobject]@{ Output=$ReviewerA; Role='impl-reviewer-a' },
        [pscustomobject]@{ Output=$ReviewerB; Role='impl-reviewer-b' })) {
        $output = $pair.Output
        $role = $pair.Role
        $reservation = $roles[$role]
        if (-not (TextEquals (Field $output 'schema') ($role + '/v1')) -or
            -not (TextEquals (Field $output 'stage') 'impl') -or
            -not (TextEquals (Field $output 'role') $role) -or
            -not (TextEquals (Field $output 'run_id') (Field $reservation 'run_id')) -or
            -not (TextEquals (Field $output 'host_session_id') (Field $reservation 'host_session_id'))) {
            throw 'ADR reviewer output identity mismatch'
        }
        $checks = Field $output 'checks'
        if ($checks -isnot [array] -or $checks.Count -eq 0) { throw 'ADR reviewer checks invalid' }
        # Fixed ADR-extension v1 profile; ordinal and positional comparison.
        $expectedIds = if (TextEquals $role 'impl-reviewer-a') {
            @('ARCH-COVERAGE','NO-CIRCULAR-DEPS','DATA-COVERAGE','API-COVERAGE',
              'SECURITY-COVERAGE','FRONTEND-BACKEND-CONSISTENCY','TEST-STRATEGY-COVERAGE',
              'NO-UNDEFINED-COMPONENT','ADR-PRESENT','DESIGN-SYSTEM-CONFORMANCE','DOMAIN-CONFORMANCE')
        } else {
            @('DECISION-JUSTIFIED','OPEN-QUESTIONS-RESOLVABLE','ASSUMPTIONS-VALID',
              'NO-REQ-CONTRADICTION','PERF-ADDRESSED','DEPLOYMENT-CONCRETE','MIGRATION-PLANNED',
              'INTEGRATION-IDENTIFIED','DESIGN-WITHIN-SCOPE','VERIFICATION-PATH-CONCRETE','DOMAIN-CONFORMANCE')
        }
        if ($checks.Count -ne $expectedIds.Count) { throw 'ADR required check count mismatch' }
        for ($index = 0; $index -lt $expectedIds.Count; $index++) {
            if (-not (TextEquals (Field $checks[$index] 'id') $expectedIds[$index])) {
                throw 'ADR required check sequence mismatch'
            }
        }
        $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $counts = @{ PASS=0L; FAIL=0L; SKIP=0L }
        $critical = 0L
        foreach ($check in $checks) {
            $id = Field $check 'id'
            $result = Field $check 'result'
            if (-not (Nonempty $id) -or -not $ids.Add($id)) { throw 'ADR duplicate or empty check ID' }
            if (-not (TextEquals $result 'PASS') -and -not (TextEquals $result 'FAIL') -and
                -not (TextEquals $result 'SKIP')) { throw 'ADR check result invalid' }
            $counts[$result]++
            if (TextEquals $result 'FAIL') {
                $severity = Field $check 'severity'
                if (-not (TextEquals $severity 'Critical') -and
                    -not (TextEquals $severity 'Major') -and
                    -not (TextEquals $severity 'Minor')) { throw 'ADR check severity invalid' }
                $totals[$severity]++
                if (TextEquals $severity 'Critical') { $critical++ }
            }
        }
        $expected = if ($critical -gt 0) { 'BLOCKED' }
            elseif ($counts.FAIL -gt 0) { 'NEEDS_WORK' } else { 'PASS' }
        if (-not (TextEquals (Field $output 'verdict') $expected)) { throw 'ADR reviewer verdict mismatch' }
        $results.Add([pscustomobject]@{ Ids=$ids; Counts=$counts; Verdict=$expected })
    }
    $expectedIntegrated = if ($totals.Critical -gt 0) { 'BLOCKED' }
        elseif ($totals.Major -gt 0 -or ($totals.Minor -gt 0 -and $Round -lt 3)) { 'NEEDS_WORK' }
        elseif ($totals.Minor -gt 0) { 'PASS-with-warnings' } else { 'PASS' }
    foreach ($record in @($Contract, $Verdict)) {
        if (-not (TextEquals (Field $record 'verdict') $expectedIntegrated) -or
            -not (TextEquals (Field $record 'reviewer_a_verdict') $results[0].Verdict) -or
            -not (TextEquals (Field $record 'reviewer_b_verdict') $results[1].Verdict)) {
            throw 'ADR integrated reviewer verdict mismatch'
        }
        foreach ($severity in @('Critical','Major','Minor')) {
            $name = 'findings_' + $severity.ToLowerInvariant()
            if (-not (CountEquals (Field $record $name) $totals[$severity])) {
                throw 'ADR aggregate findings disagree with actual reviewer checks'
            }
        }
    }
    # The caller compares A's exact ID set and counters with current summary.
    return $results[0]
}
# Current summary binds A's actual checks; prior summary is shape-only.
# Caller supplies safe parsed snapshots and pins their raw hashes in manifests.
function Test-AdrHistorySummary($Summary, [int]$Attempt, [int]$Round, $ReviewerResult) {
    if ($Summary -isnot [pscustomobject]) { throw 'ADR summary must be an object' }
    $fields = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($property in $Summary.PSObject.Properties) {
        if ($fields.ContainsKey($property.Name)) { throw 'ADR duplicate summary field' }
        $fields.Add($property.Name, $property.Value)
    }
    $expectedKeys = @('attempt','generated_at','reviewer_a_check_ids',
        'reviewer_a_fail_count','reviewer_a_pass_count','reviewer_a_skip_count','round','schema')
    if ($fields.Count -ne $expectedKeys.Count) { throw 'ADR summary key count invalid' }
    foreach ($key in $expectedKeys) {
        if (-not $fields.ContainsKey($key)) { throw 'ADR summary field missing or mis-cased' }
    }
    function IsNumber($Value) {
        return ($Value -is [int] -or $Value -is [long] -or
            $Value -is [double] -or $Value -is [decimal])
    }
    # This value comes only from validated JSON via ConvertFrom-Json.
    # Some PowerShell versions turn nonempty timestamp strings into dates;
    # JSON objects/arrays/numbers cannot produce these CLR date types here.
    # Do not cast other values: the raw JSON contract remains nonempty string.
    $generatedAt = $fields['generated_at']
    $generatedAtIsString = ($generatedAt -is [string] -and $generatedAt.Length -gt 0) -or
        $generatedAt -is [datetime] -or $generatedAt -is [datetimeoffset]
    if ($fields['schema'] -isnot [string] -or
        -not [string]::Equals($fields['schema'], 'integrated-summary/v1', [StringComparison]::Ordinal) -or
        -not (IsNumber $fields['attempt']) -or $fields['attempt'] -ne $Attempt -or
        -not (IsNumber $fields['round']) -or $fields['round'] -ne $Round -or
        -not $generatedAtIsString) {
        throw 'ADR summary identity invalid'
    }
    $checkIds = $fields['reviewer_a_check_ids']
    if ($checkIds -isnot [array] -or $checkIds.Count -eq 0) { throw 'ADR summary IDs invalid' }
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($id in $checkIds) {
        if ($id -isnot [string] -or $id.Length -eq 0 -or -not $ids.Add($id)) {
            throw 'ADR summary IDs must be nonempty and unique'
        }
    }
    $counts = [Collections.Generic.Dictionary[string,long]]::new([StringComparer]::Ordinal)
    $sum = 0L
    foreach ($result in @('PASS','FAIL','SKIP')) {
        $value = $fields['reviewer_a_' + $result.ToLowerInvariant() + '_count']
        # Bound before integer conversion; rejects NaN, infinity and fractions.
        if (-not (IsNumber $value) -or -not ($value -ge 0 -and $value -le $ids.Count) -or
            $value % 1 -ne 0) { throw 'ADR summary counter invalid' }
        $counts.Add($result, [long]$value)
        $sum += [long]$value
    }
    if ($sum -ne $ids.Count) { throw 'ADR summary total does not equal its ID count' }
    if ($null -ne $ReviewerResult) {
        # This result must come from Test-AdrHistoryOutputs, never caller JSON.
        if (-not $ids.SetEquals($ReviewerResult.Ids)) { throw 'ADR summary IDs disagree with actual reviewer A' }
        foreach ($result in @('PASS','FAIL','SKIP')) {
            if ($counts[$result] -ne $ReviewerResult.Counts[$result]) {
                throw 'ADR summary counters disagree with actual reviewer A'
            }
        }
    }
}
# Compose saved-state checks from immutable text/hash pairs. The file-system
# caller must create these with Read-AdrJsonSnapshot after safe-path checks,
# then recheck current evidence stability; no current ADR bytes are read here.
function Get-AdrHistoryBinding([Collections.IDictionary]$Snapshots,
    [string]$Feature, [int]$Attempt, [int]$Round, [string]$RepositoryRoot) {
    function Read-SavedAdrObject([string]$Name, [bool]$Optional = $false) {
        if (-not $Snapshots.ContainsKey($Name)) {
            if ($Optional) { return $null }
            throw "ADR saved snapshot missing: $Name"
        }
        $snapshot = $Snapshots[$Name]
        if ($snapshot.Text -isnot [string] -or $snapshot.Sha256 -isnot [string] -or
            $snapshot.Sha256 -cnotmatch '\A[0-9a-f]{64}\z') {
            throw 'ADR snapshot text or digest invalid'
        }
        # PowerShell can unwrap singleton arrays during conversion. Check the
        # raw root first; the member checker already enforces the JSON grammar.
        Assert-AdrJsonMembers $snapshot.Text
        if (-not $snapshot.Text.TrimStart([char[]]" `t`r`n").StartsWith('{', [StringComparison]::Ordinal)) {
            throw 'ADR saved evidence root must be an object'
        }
        return ConvertFrom-Json -InputObject $snapshot.Text -ErrorAction Stop
    }
    $contract = Read-SavedAdrObject 'impl-review-contract.json'
    $precheck = Read-SavedAdrObject 'precheck-result.json' $true
    $reviewerA = Read-SavedAdrObject 'reviewer-a.json'
    $reviewerB = Read-SavedAdrObject 'reviewer-b.json'
    $verdict = Read-SavedAdrObject 'integrated-verdict.json'
    $summary = Read-SavedAdrObject 'integrated-summary.json'
    $core = Get-AdrHistoryCoreBinding $contract $precheck
    if (-not $core.Extended) {
        # Legacy absence is not permission to read ADRs, including aliases.
        foreach ($owner in (@($contract.reviewers) + @($reviewerA, $reviewerB))) {
            foreach ($entry in @($owner.allowed_input_manifest)) {
                if ($entry.path -isnot [string] -or
                    $entry.path.Replace('\','/') -imatch '(^|/)docs/adr/') {
                    throw 'ADR input has no binding extension'
                }
            }
        }
    } else {
        foreach ($name in @('schema','feature','attempt','round')) {
            if (@($precheck.PSObject.Properties.Name) -cnotcontains $name) {
                throw 'ADR precheck identity field missing'
            }
        }
        if ($precheck.schema -isnot [string] -or $precheck.schema -cne 'impl-review-precheck/v1' -or
            $precheck.feature -isnot [string] -or $precheck.feature -cne $Feature) {
            throw 'ADR precheck identity mismatch'
        }
        foreach ($pair in @(@('attempt',$Attempt), @('round',$Round))) {
            $value = $precheck.($pair[0])
            if (($value -isnot [int] -and $value -isnot [long] -and
                 $value -isnot [double] -and $value -isnot [decimal]) -or $value -ne $pair[1]) {
                throw 'ADR precheck attempt or round mismatch'
            }
        }
        $aResult = Test-AdrHistoryOutputs $contract $reviewerA $reviewerB $verdict $Feature $Attempt $Round
        Test-AdrHistorySummary $summary $Attempt $Round $aResult
        $previousHash = ''
        if ($Round -gt 1) {
            $previous = Read-SavedAdrObject 'previous-integrated-summary.json'
            Test-AdrHistorySummary $previous $Attempt ($Round - 1) $null
            $previousHash = $Snapshots['previous-integrated-summary.json'].Sha256
        }
        $recorded = Get-RecordedRepositoryRoot $contract $RepositoryRoot
        if (-not $recorded.Valid) { throw 'ADR recorded root is ambiguous' }
        foreach ($role in @('impl-reviewer-a','impl-reviewer-b')) {
            $reservation = @($contract.reviewers | Where-Object { $_.role -ceq $role })[0]
            $output = if ($role -ceq 'impl-reviewer-a') { $reviewerA } else { $reviewerB }
            $bound = Get-AdrHistoryManifest $reservation.allowed_input_manifest $role $precheck `
                $Feature $Attempt $Round $RepositoryRoot $recorded.Root `
                $Snapshots['precheck-result.json'].Sha256 $Snapshots['integrated-summary.json'].Sha256 $previousHash
            $actual = Get-AdrHistoryManifest $output.allowed_input_manifest $role $precheck `
                $Feature $Attempt $Round $RepositoryRoot $recorded.Root `
                $Snapshots['precheck-result.json'].Sha256 $Snapshots['integrated-summary.json'].Sha256 $previousHash
            if (-not (Test-AdrHistoryManifestSuperset $actual $bound $Feature)) {
                throw 'ADR actual reviewer manifest diverges from reservation'
            }
        }
        if (-not (Test-AdrSharedLayerAgreement $contract $reviewerA $reviewerB $Feature $RepositoryRoot)) {
            throw 'ADR shared layer pins disagree'
        }
    }
    return [pscustomobject]@{
        Extended=$core.Extended; EntriesJson=$core.EntriesJson
        Contract=$contract; Precheck=$precheck; ReviewerA=$reviewerA
        ReviewerB=$reviewerB; Verdict=$verdict; Summary=$summary
    }
}
# Root is the caller's trusted repository root; do not resolve an evidence
# alias before examining each case-exact child and rejecting reparse points.
function Get-AdrSafeEvidencePath([string]$Relative, [string]$RepositoryRoot,
    [bool]$AllowMissingLeaf = $false) {
    if ($Relative -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._/-]*\z' -or
        $Relative.EndsWith('/') -or $Relative.Contains('//')) {
        throw 'ADR evidence relative path invalid'
    }
    $current = Get-Item -LiteralPath $RepositoryRoot -Force -ErrorAction Stop
    $components = $Relative.Split('/')
    for ($index = 0; $index -lt $components.Count; $index++) {
        $component = $components[$index]
        if ($component -ceq '.' -or $component -ceq '..' -or
            -not $current.PSIsContainer -or
            ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'ADR evidence parent is unsafe'
        }
        $siblings = @(Get-ChildItem -LiteralPath $current.FullName -Force -ErrorAction Stop)
        $children = @($siblings |
            Where-Object { [string]::Equals($_.Name, $component, [StringComparison]::Ordinal) })
        if ($children.Count -eq 0 -and $AllowMissingLeaf -and $index -eq ($components.Count - 1)) {
            # Missing means no directory entry, not an unresolved link target.
            # A case variant is malformed evidence, even on case-sensitive hosts.
            $aliases = @($siblings | Where-Object {
                [string]::Equals($_.Name, $component, [StringComparison]::OrdinalIgnoreCase)
            })
            if ($aliases.Count -ne 0) { throw 'ADR evidence leaf has wrong case' }
            return $null
        }
        if ($children.Count -ne 1) { throw 'ADR evidence component missing or wrong case' }
        $current = $children[0]
        if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'ADR evidence reparse point rejected'
        }
    }
    if ($current.PSIsContainer -or $current -isnot [IO.FileInfo]) {
        throw 'ADR evidence is not a regular file'
    }
    return $current.FullName
}
# Same restricted byte grammar as admission and the Bash declaration consumer.
function Get-AdrCurrentDeclaredPaths([string]$DesignPath) {
    # Preserve each byte, including a BOM; only ASCII declarations are recognized.
    $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($DesignPath))
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    function Get-AdrRunWidth([string]$Line, [int]$Start, [char]$Delimiter) {
        $width = 0
        while (($Start + $width) -lt $Line.Length -and $Line[$Start + $width] -ceq $Delimiter) { $width++ }
        return $width
    }
    function Test-AdrRunEscaped([string]$Line, [int]$Start) {
        $slashes = 0
        while ($Start -gt 0 -and $Line[$Start - 1] -ceq [char]92) { $slashes++; $Start-- }
        return (($slashes % 2) -ne 0)
    }
    $fence = [char]0
    $fenceWidth = 0
    foreach ($rawLine in $text.Split([char]10)) {
        $line = $rawLine
        if ($line.Length -gt 0 -and $line[$line.Length - 1] -ceq [char]13) {
            $line = $line.Substring(0, $line.Length - 1)
        }
        $indent = 0
        while ($indent -lt $line.Length -and $line[$indent] -ceq [char]32) { $indent++ }
        $rest = $line.Substring($indent)
        $first = [char]0
        if ($rest.Length -gt 0) { $first = $rest[0] }
        if ($fence -cne [char]0) {
            if ($indent -le 3 -and $first -ceq $fence) {
                $width = Get-AdrRunWidth $rest 0 $fence
                if ($width -ge $fenceWidth -and $rest.Substring($width) -cmatch '^[ \t]*$') {
                    $fence = [char]0
                }
            }
            continue
        }
        if ($indent -ge 4 -or $first -ceq [char]9) { continue }
        if ($first -ceq [char]96 -or $first -ceq [char]126) {
            $width = Get-AdrRunWidth $rest 0 $first
            if ($width -ge 3) { $fence = $first; $fenceWidth = $width; continue }
        }
        $i = 0
        while ($i -lt $line.Length) {
            if ($line[$i] -cne [char]96) { $i++; continue }
            $width = Get-AdrRunWidth $line $i ([char]96)
            if (Test-AdrRunEscaped $line $i) { $i += $width; continue }
            $j = $i + $width
            $closed = $false
            while ($j -lt $line.Length) {
                if ($line[$j] -cne [char]96) { $j++; continue }
                $closeWidth = Get-AdrRunWidth $line $j ([char]96)
                if ($closeWidth -eq $width -and -not (Test-AdrRunEscaped $line $j)) {
                    $closed = $true
                    break
                }
                $j += $closeWidth
            }
            if (-not $closed) { break }
            $value = $line.Substring($i + $width, $j - $i - $width)
            if ($width -eq 1 -and $value -cmatch '\Adocs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md\z') {
                [void]$paths.Add($value)
            }
            $i = $j + $width
        }
    }
    [string[]]$result = @($paths)
    [Array]::Sort($result, [StringComparer]::Ordinal)
    return $result
}
function Test-AdrCurrentDeclarations($Binding, [string]$Feature, [string]$RepositoryRoot) {
    if (-not $Binding.Extended) { return }
    $relative = "specs/$Feature/design.md"
    $safe = Get-AdrSafeEvidencePath $relative $RepositoryRoot
    $before = Get-Sha256 $safe
    $actual = @(Get-AdrCurrentDeclaredPaths $safe)
    $recorded = @(ConvertFrom-Json -InputObject $Binding.EntriesJson -ErrorAction Stop)
    if ($actual.Count -ne $recorded.Count) { throw 'ADR current design declarations differ from saved bindings' }
    for ($index = 0; $index -lt $actual.Count; $index++) {
        if ($actual[$index] -cne $recorded[$index].path) {
            throw 'ADR current design declarations differ from saved bindings'
        }
    }
    $safe = Get-AdrSafeEvidencePath $relative $RepositoryRoot
    if ((Get-Sha256 $safe) -cne $before) { throw 'ADR current design changed during declaration verification' }
}
function Read-AdrHistoryEvidence([string]$Feature, [int]$Attempt, [int]$Round,
    [string]$RepositoryRoot) {
    $relative = "reports/impl-review/$Feature/attempt-$Attempt/round-$Round"
    $snapshots = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $paths = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($name in @('impl-review-contract.json','precheck-result.json',
        'reviewer-a.json','reviewer-b.json','integrated-verdict.json','integrated-summary.json')) {
        $path = "$relative/$name"
        # Legacy evidence may predate persisted prechecks. Pairing still fails
        # if the contract has the ADR extension but its precheck is absent.
        $safe = Get-AdrSafeEvidencePath $path $RepositoryRoot ($name -ceq 'precheck-result.json')
        if ($null -eq $safe) { continue }
        $snapshots.Add($name, (Read-AdrJsonSnapshot $safe))
        $paths.Add($name, $path)
    }
    $pc = $null
    if ($snapshots.ContainsKey('precheck-result.json')) {
        $pc = ConvertFrom-Json -InputObject $snapshots['precheck-result.json'].Text -ErrorAction Stop
    }
    $contract = ConvertFrom-Json -InputObject $snapshots['impl-review-contract.json'].Text -ErrorAction Stop
    $core = Get-AdrHistoryCoreBinding $contract $pc
    if ($Round -gt 1) {
        $previousPath = "reports/impl-review/$Feature/attempt-$Attempt/round-$($Round-1)/integrated-summary.json"
        $needsPrevious = $core.Extended
        $recorded = Get-RecordedRepositoryRoot $contract $RepositoryRoot
        if (-not $recorded.Valid) { throw 'ADR recorded repository root is invalid' }
        foreach ($reviewer in @($contract.reviewers)) {
            foreach ($item in @($reviewer.allowed_input_manifest)) {
                $normalized = Get-RepositoryRelativePath ([string]$item.path) $RepositoryRoot $recorded.Root
                if ($normalized -ceq $previousPath) { $needsPrevious = $true }
            }
        }
        if ($needsPrevious) {
            $safe = Get-AdrSafeEvidencePath $previousPath $RepositoryRoot
            $snapshots.Add('previous-integrated-summary.json', (Read-AdrJsonSnapshot $safe))
            $paths.Add('previous-integrated-summary.json', $previousPath)
        }
    }
    $binding = Get-AdrHistoryBinding $snapshots $Feature $Attempt $Round $RepositoryRoot
    # Validate/hash the paths again, but return the original verified objects.
    # This detects persistent replacement; it is not an atomic no-follow open.
    foreach ($name in $snapshots.Keys) {
        $safe = Get-AdrSafeEvidencePath $paths[$name] $RepositoryRoot
        $after = Read-AdrJsonSnapshot $safe
        if ($after.Sha256 -cne $snapshots[$name].Sha256) {
            throw 'ADR evidence changed during validation'
        }
    }
    if (-not $snapshots.ContainsKey('precheck-result.json')) {
        $appeared = Get-AdrSafeEvidencePath "$relative/precheck-result.json" $RepositoryRoot $true
        if ($null -ne $appeared) {
            throw 'ADR precheck appeared during validation'
        }
    }
    # Preserve exact path identity: previous and current summaries share a basename.
    $evidenceHashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($name in $snapshots.Keys) {
        $evidenceHashes.Add($paths[$name], $snapshots[$name].Sha256)
    }
    $binding | Add-Member -MemberType NoteProperty -Name EvidenceHashes -Value $evidenceHashes
    return $binding
}
function Test-PassedStage([string]$Feature, [string]$Stage, [string]$FeatureDir) {
    $root = Join-Path $RepoRoot "reports/$Stage-review/$Feature"
    if (-not (Test-Path -LiteralPath $root -PathType Container) -or (Get-Item $root -Force).LinkType) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage PASS has no review report root"
    }
    $candidates = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter integrated-verdict.json -Recurse -Force)) {
        if ($file.LinkType -or -not (Test-Path -LiteralPath $file.FullName -PathType Leaf)) {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage verdict evidence is linked or unreadable"
        }
        # PS5.1-safe (no [IO.Path]::GetRelativePath, .NET Core only): the file
        # comes from Get-ChildItem -Recurse under $root, so its normalized
        # full name always carries $root as a literal prefix.
        $rootPrefix = $root.Replace("\", "/").TrimEnd("/") + "/"
        $fullName = $file.FullName.Replace("\", "/")
        if (-not $fullName.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage verdict has a noncanonical path"
        }
        $relative = $fullName.Substring($rootPrefix.Length)
        if ($relative -notmatch "^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/integrated-verdict\.json$") {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage verdict has a noncanonical path"
        }
        $candidates += [pscustomobject]@{ File=$file; Attempt=[int]$Matches[1]; Round=[int]$Matches[2] }
    }
    $latest = $candidates | Sort-Object Attempt, Round -Descending | Select-Object -First 1
    # Verify -Opening's slot for THIS stage now, unconditionally -- not only
    # when this stage's own verdict later turns out to need excusing. A
    # re-review opened after an already-valid PASS (--provenance-rereview)
    # never reaches the failure branch below, but downstream tolerance must
    # still be available in that case: the flag names the slot, not "this
    # stage is currently broken".
    $bestAttemptForOpening = if ($latest) { $latest.Attempt } else { 0 }
    $bestRoundForOpening = if ($latest) { $latest.Round } else { 0 }
    [void](Test-StageIsBeingOpened $Stage $Feature $bestAttemptForOpening $bestRoundForOpening)
    if (-not $latest) { Stop-WorkflowState $Feature "stage-provenance" "$Stage PASS has no integrated verdict" }
    $contractPath = Join-Path $latest.File.DirectoryName "$Stage-review-contract.json"
    if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf) -or (Get-Item $contractPath -Force).LinkType) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage PASS has no readable review contract"
    }
    try {
        if ($Stage -ceq 'impl') {
            $adrHistory = Read-AdrHistoryEvidence $Feature $latest.Attempt $latest.Round $RepoRoot
            $verdict = $adrHistory.Verdict
            $contract = $adrHistory.Contract
        } else {
            $verdict = Get-Content -LiteralPath $latest.File.FullName -Raw | ConvertFrom-Json
            $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        }
    } catch {
        # Identify the failed validation boundary without exposing evidence or exception text.
        if ($Stage -ceq 'impl') {
            Stop-WorkflowState $Feature "stage-provenance" "ADR impl review evidence validation failed"
        }
        Stop-WorkflowState $Feature "stage-provenance" "$Stage review evidence is malformed"
    }
    $reviewerAPath = Join-Path $latest.File.DirectoryName "reviewer-a.json"
    $reviewerBPath = Join-Path $latest.File.DirectoryName "reviewer-b.json"
    $summaryPath = Join-Path $latest.File.DirectoryName "integrated-summary.json"
    foreach ($evidencePath in @($reviewerAPath, $reviewerBPath, $summaryPath)) {
        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf) -or
            (Get-Item -LiteralPath $evidencePath -Force).LinkType) {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer evidence is missing, linked, or unreadable"
        }
    }
    try {
        if ($Stage -ceq 'impl') {
            $reviewerA = $adrHistory.ReviewerA
            $reviewerB = $adrHistory.ReviewerB
            $summary = $adrHistory.Summary
        } else {
            $reviewerA = Get-Content -LiteralPath $reviewerAPath -Raw | ConvertFrom-Json
            $reviewerB = Get-Content -LiteralPath $reviewerBPath -Raw | ConvertFrom-Json
            $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        }
    } catch { Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer evidence is malformed" }
    $identityOk = [string]$verdict.feature -eq $Feature -and [string]$verdict.stage -eq $Stage -and
        [int]$verdict.attempt -eq $latest.Attempt -and [int]$verdict.round -eq $latest.Round -and
        ([string]$verdict.verdict -eq "PASS" -or
         ($Stage -ne "spec" -and [string]$verdict.verdict -eq "PASS-with-warnings"))
    if ($Stage -eq "spec") {
        $identityOk = $identityOk -and [string]$verdict.schema -eq "spec-review-integrated-verdict/v1" -and
            $verdict.reviewer_a_run_id -and $verdict.reviewer_b_run_id -and
            $verdict.reviewer_a_host_session_id -and $verdict.reviewer_b_host_session_id -and
            $verdict.reviewer_a_run_id -ne $verdict.reviewer_b_run_id -and
            $verdict.reviewer_a_host_session_id -ne $verdict.reviewer_b_host_session_id
    } else {
        $identityOk = $identityOk -and [string]$verdict.schema -eq "integrated-verdict/v1" -and
            -not [string]::IsNullOrWhiteSpace([string]$verdict.run_id) -and
            [string]$verdict.reviewer_a_verdict -in @("PASS", "NEEDS_WORK") -and
            [string]$verdict.reviewer_b_verdict -in @("PASS", "NEEDS_WORK") -and
            [int]$verdict.findings_critical -eq 0 -and [int]$verdict.findings_major -eq 0
    }
    if (-not $identityOk) {
        if (Test-StageIsBeingOpened $Stage $Feature $latest.Attempt $latest.Round) { return }
        Stop-WorkflowState $Feature "stage-provenance" "$Stage integrated verdict is not a valid PASS"
    }
    $roles = @($contract.reviewers | ForEach-Object { [string]$_.role } | Sort-Object)
    $runs = @($contract.reviewers | ForEach-Object { [string]$_.run_id } | Sort-Object -Unique)
    $hosts = @($contract.reviewers | ForEach-Object { [string]$_.host_session_id } | Sort-Object -Unique)
    $contractOk = [string]$contract.schema -eq "$Stage-review-contract/v1" -and
        [string]$contract.feature -eq $Feature -and [string]$contract.stage -eq $Stage -and
        [int]$contract.attempt -eq $latest.Attempt -and [int]$contract.round -eq $latest.Round -and
        ([string]$contract.verdict -eq "PASS" -or
         ($Stage -ne "spec" -and [string]$contract.verdict -eq "PASS-with-warnings")) -and
        -not [string]::IsNullOrWhiteSpace([string]$contract.run_id) -and
        ($Stage -eq "spec" -or (
            [string]$contract.reviewer_a_verdict -in @("PASS", "NEEDS_WORK") -and
            [string]$contract.reviewer_b_verdict -in @("PASS", "NEEDS_WORK") -and
            [int]$contract.findings_critical -eq 0 -and [int]$contract.findings_major -eq 0)) -and
        ($roles -join ",") -eq "$Stage-reviewer-a,$Stage-reviewer-b" -and
        $runs.Count -eq 2 -and $hosts.Count -eq 2 -and -not ($runs -contains "") -and -not ($hosts -contains "")
    if (-not $contractOk) { Stop-WorkflowState $Feature "stage-provenance" "$Stage review contract identity is invalid" }
    # Extended impl manifests were strictly validated by Get-AdrHistoryBinding.
    # This runs after the existing own-stage opening return. A declaration-set
    # change is an authorization failure, not tolerated downstream staleness.
    if ($Stage -ceq 'impl') {
        try { Test-AdrCurrentDeclarations $adrHistory $Feature $RepoRoot }
        catch { Stop-WorkflowState $Feature "stage-provenance" "ADR current design declaration validation failed" }
    }
    if (-not ($Stage -ceq 'impl' -and $adrHistory.Extended) -and
        -not (Test-ManifestPaths $contract $Feature $Stage $latest.Attempt $latest.Round $RepoRoot)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest paths are not canonical"
    }
    $recorded = Get-RecordedRepositoryRoot $contract $RepoRoot
    if (-not $recorded.Valid) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest paths are not canonical"
    }
    $statusNeutral = @(
        "specs/$Feature/requirements.md",
        "specs/$Feature/design.md",
        "specs/$Feature/tasks.md",
        "specs/$Feature/traceability.md",
        "specs/$Feature/acceptance-tests.md"
    )
    foreach ($reviewer in @($contract.reviewers)) {
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $manifestPath = [string]$item.path
            $manifestRelative = Get-RepositoryRelativePath $manifestPath $RepoRoot $recorded.Root
            if ($null -eq $manifestRelative) {
                Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest path escapes repository"
            }
            $manifestFile = Join-Path $RepoRoot $manifestRelative
            if ($Stage -ceq 'impl' -and $adrHistory.EvidenceHashes.ContainsKey($manifestRelative)) {
                if ($adrHistory.EvidenceHashes[$manifestRelative] -cne [string]$item.sha256) {
                    Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "$Stage reviewer manifest input hash is stale"
                }
                # All consumers use the generation already parsed and verified above.
                continue
            }
            if ($Stage -ceq 'impl' -and $manifestRelative.StartsWith('docs/adr/', [StringComparison]::Ordinal)) {
                try {
                    $safe = Get-AdrSafeEvidencePath $manifestRelative $RepoRoot
                    $adrHash = Get-Sha256 $safe
                    $safe = Get-AdrSafeEvidencePath $manifestRelative $RepoRoot
                    if ($adrHash -cne [string]$item.sha256 -or (Get-Sha256 $safe) -cne $adrHash) {
                        throw 'ADR content differs from its binding or changed during consumption'
                    }
                    # Detect persistent parent/leaf replacement after the second read.
                    # This is not an atomic no-follow open or a defense against ABA races.
                    [void](Get-AdrSafeEvidencePath $manifestRelative $RepoRoot)
                } catch { Stop-WorkflowState $Feature "stage-provenance" "ADR current input path or hash is invalid" }
                continue
            }
            if ($statusNeutral -contains $manifestRelative) { continue }
            if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf) -or
                (Get-Item -LiteralPath $manifestFile -Force).LinkType) {
                Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest input is missing or unreadable"
            }
            # Tolerated downstream: for each entry the manifest already
            # recorded, this asks "does the live file still match what was
            # pinned" -- an unambiguous freshness check with no existence
            # question folded in (an entry that was never recorded is never
            # visited by this loop at all, so a missing declaration can't
            # hide behind this tolerance).
            if ($manifestRelative -like "plugins/*") {
                if (-not (Test-PluginsHashMatches $manifestFile ([string]$item.sha256) $contractPath)) {
                    Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "$Stage reviewer manifest input hash is stale"
                }
            } elseif ($manifestRelative -eq "specs/$Feature/investigation.md") {
                # Tolerated STANDALONE (no --opening needed): the amendment
                # re-review lane's own oscillation, where a downstream
                # stage's recovery grows this file's
                # "## Amendment Re-Review Context" section after an
                # upstream stage already pinned it. Tried first; falls
                # through to the ordinary --opening-based tolerance (and,
                # if that does not apply either, the original diagnostic)
                # when the live change is not pure, section-confined growth
                # over independently-verified historical bytes.
                $currentHash = Get-Sha256 $manifestFile
                if ($currentHash -ne [string]$item.sha256) {
                    if (Test-InvestigationAmendmentReconciles $manifestFile ([string]$item.sha256) $contractPath) {
                        Write-InvestigationAmendmentNotice $Feature $Stage $manifestRelative ([string]$item.sha256) $currentHash
                    } else {
                        Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "$Stage reviewer manifest input hash is stale"
                    }
                }
            } elseif ((Get-Sha256 $manifestFile) -ne [string]$item.sha256) {
                Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "$Stage reviewer manifest input hash is stale"
            }
        }
    }
    if ($Stage -eq "spec") {
        $map = @{}; foreach ($r in $contract.reviewers) { $map[[string]$r.role] = $r }
        $linked = $map["spec-reviewer-a"].run_id -eq $verdict.reviewer_a_run_id -and
            $map["spec-reviewer-b"].run_id -eq $verdict.reviewer_b_run_id -and
            $map["spec-reviewer-a"].host_session_id -eq $verdict.reviewer_a_host_session_id -and
            $map["spec-reviewer-b"].host_session_id -eq $verdict.reviewer_b_host_session_id
    } else { $linked = [string]$contract.run_id -eq [string]$verdict.run_id }
    if (-not $linked) { Stop-WorkflowState $Feature "stage-provenance" "$Stage contract and verdict contradict each other" }

    $reviewerMap = @{}
    foreach ($entry in @($contract.reviewers)) { $reviewerMap[[string]$entry.role] = $entry }
    if ($Stage -eq "task") {
        $reviewerIdentityOk =
            [string]$reviewerA.schema -eq "task-reviewer-a/v1" -and
            [string]$reviewerA.stage -eq "task-review" -and [string]$reviewerA.role -eq "reviewer-a" -and
            [string]$reviewerB.schema -eq "task-reviewer-b/v1" -and
            [string]$reviewerB.stage -eq "task" -and [string]$reviewerB.role -eq "task-reviewer-b" -and
            [string]$reviewerA.feature -eq $Feature -and [string]$reviewerB.feature -eq $Feature -and
            [int]$reviewerA.attempt -eq $latest.Attempt -and [int]$reviewerB.attempt -eq $latest.Attempt -and
            [int]$reviewerA.round -eq $latest.Round -and [int]$reviewerB.round -eq $latest.Round
        $manifestA = @($reviewerA.manifest)
        $manifestB = @($reviewerB.manifest.allowed_inputs)
        $resultProperty = "status"
    } else {
        $reviewerIdentityOk =
            [string]$reviewerA.schema -eq "$Stage-reviewer-a/v1" -and
            [string]$reviewerA.stage -eq $Stage -and [string]$reviewerA.role -eq "$Stage-reviewer-a" -and
            [string]$reviewerB.schema -eq "$Stage-reviewer-b/v1" -and
            [string]$reviewerB.stage -eq $Stage -and [string]$reviewerB.role -eq "$Stage-reviewer-b"
        $manifestA = @($reviewerA.allowed_input_manifest)
        $manifestB = @($reviewerB.allowed_input_manifest)
        $resultProperty = "result"
    }
    $contractA = $reviewerMap["$Stage-reviewer-a"]
    $contractB = $reviewerMap["$Stage-reviewer-b"]
    $reviewerIdentityOk = $reviewerIdentityOk -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerA.run_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerA.host_session_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerB.run_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerB.host_session_id) -and
        [string]$reviewerA.run_id -eq [string]$contractA.run_id -and
        [string]$reviewerA.host_session_id -eq [string]$contractA.host_session_id -and
        [string]$reviewerB.run_id -eq [string]$contractB.run_id -and
        [string]$reviewerB.host_session_id -eq [string]$contractB.host_session_id
    $reviewerIdentityOk = $reviewerIdentityOk -and
        (Test-ManifestSuperset $manifestA $contractA.allowed_input_manifest $Feature $Stage $RepoRoot $recorded.Root) -and
        (Test-ManifestSuperset $manifestB $contractB.allowed_input_manifest $Feature $Stage $RepoRoot $recorded.Root)
    $failedA = @($reviewerA.checks | Where-Object { [string]$_.$resultProperty -eq "FAIL" })
    $reviewerBResultProperty = if ($Stage -eq "task") { "result" } else { $resultProperty }
    $failedB = @($reviewerB.checks | Where-Object {
        [string]$_.$reviewerBResultProperty -eq "FAIL"
    })
    if ($Stage -eq "task") {
        $findingsA = @($reviewerA.findings)
        $findingsB = @($reviewerB.findings)
        $reviewerIdentityOk = $reviewerIdentityOk -and
            $failedA.Count -eq $findingsA.Count -and $failedB.Count -eq $findingsB.Count
        # WFI-030 item 7, twin of the jq clause in check-workflow-state.sh.
        # The precheck for this round is read here rather than reused from the
        # stage-provenance block, which parses it in a later scope.
        $frozenFlagged = @()
        $roundPrecheck = Join-Path $latest.File.DirectoryName "precheck-result.json"
        if (Test-Path -LiteralPath $roundPrecheck -PathType Leaf) {
            $precheckRound = Get-Content -LiteralPath $roundPrecheck -Raw | ConvertFrom-Json
            $frozenProperty = $precheckRound.psobject.Properties['frozen_artifact_done_when']
            if ($null -ne $frozenProperty -and $null -ne $frozenProperty.Value) {
                $frozenFlagged = @($frozenProperty.Value)
            }
        }
        if ($frozenFlagged.Count -gt 0) {
            $observedDoneWhen = @($reviewerA.checks |
                Where-Object { [string]$_.id -eq "OBSERVABLE-DONE" } |
                ForEach-Object { [string]$_.finding }) -join " "
            foreach ($flaggedItem in $frozenFlagged) {
                if (-not $observedDoneWhen.Contains([string]$flaggedItem.task)) {
                    $reviewerIdentityOk = $false
                }
            }
        }
    } else {
        $findingsA = $failedA
        $findingsB = $failedB
    }
    $expectedVerdictA = if (@($findingsA | Where-Object severity -eq "Critical").Count) {
        "BLOCKED"
    } elseif ($findingsA.Count) { "NEEDS_WORK" } else { "PASS" }
    $expectedVerdictB = if (@($findingsB | Where-Object severity -eq "Critical").Count) {
        "BLOCKED"
    } elseif ($findingsB.Count) { "NEEDS_WORK" } else { "PASS" }
    $reviewerIdentityOk = $reviewerIdentityOk -and
        [string]$reviewerA.verdict -eq $expectedVerdictA -and
        [string]$reviewerB.verdict -eq $expectedVerdictB
    $summaryIds = if ($Stage -eq "spec") {
        @($summary.reviewer_a_checks | ForEach-Object { [string]$_.id } | Sort-Object)
    } else { @($summary.reviewer_a_check_ids | ForEach-Object { [string]$_ } | Sort-Object) }
    $reviewerAIds = @($reviewerA.checks | ForEach-Object { [string]$_.id } | Sort-Object)
    $summaryOk = [string]$summary.schema -eq "integrated-summary/v1" -and
        [int]$summary.attempt -eq $latest.Attempt -and [int]$summary.round -eq $latest.Round -and
        (($summaryIds -join "`n") -ceq ($reviewerAIds -join "`n")) -and
        [int]$summary.reviewer_a_fail_count -eq $failedA.Count -and
        [int]$summary.reviewer_a_pass_count -eq
            @($reviewerA.checks | Where-Object { [string]$_.$resultProperty -eq "PASS" }).Count -and
        [int]$summary.reviewer_a_skip_count -eq
            @($reviewerA.checks | Where-Object { [string]$_.$resultProperty -eq "SKIP" }).Count
    $allFindings = @($findingsA) + @($findingsB)
    $criticalCount = @($allFindings | Where-Object severity -eq "Critical").Count
    $majorCount = @($allFindings | Where-Object severity -eq "Major").Count
    $minorCount = @($allFindings | Where-Object severity -eq "Minor").Count
    $severityCount = $criticalCount + $majorCount + $minorCount
    $finalEvidenceOk = $severityCount -eq $allFindings.Count -and
        $criticalCount -eq 0 -and $majorCount -eq 0 -and
        ($minorCount -eq 0 -or $latest.Round -eq 3)
    if ($Stage -eq "spec") {
        $finalEvidenceOk = $finalEvidenceOk -and
            [string]$contract.verdict -eq "PASS" -and [string]$verdict.verdict -eq "PASS" -and
            [int]$contract.warningCount -eq $minorCount -and
            [int]$verdict.warningCount -eq $minorCount -and
            [int]$verdict.finding_counts.critical -eq $criticalCount -and
            [int]$verdict.finding_counts.major -eq $majorCount -and
            [int]$verdict.finding_counts.minor -eq $minorCount
    } else {
        $expectedFinalVerdict = if ($minorCount) { "PASS-with-warnings" } else { "PASS" }
        $finalEvidenceOk = $finalEvidenceOk -and
            [string]$contract.verdict -eq $expectedFinalVerdict -and
            [string]$verdict.verdict -eq $expectedFinalVerdict -and
            [int]$contract.findings_critical -eq $criticalCount -and
            [int]$contract.findings_major -eq $majorCount -and
            [int]$contract.findings_minor -eq $minorCount -and
            [int]$verdict.findings_critical -eq $criticalCount -and
            [int]$verdict.findings_major -eq $majorCount -and
            [int]$verdict.findings_minor -eq $minorCount -and
            [string]$contract.reviewer_a_verdict -eq [string]$reviewerA.verdict -and
            [string]$contract.reviewer_b_verdict -eq [string]$reviewerB.verdict -and
            [string]$verdict.reviewer_a_verdict -eq [string]$reviewerA.verdict -and
            [string]$verdict.reviewer_b_verdict -eq [string]$reviewerB.verdict
    }
    if (-not $reviewerIdentityOk -or -not $summaryOk -or -not $finalEvidenceOk) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer outputs or integrated summary contradict the final PASS"
    }

    $requirements = Join-Path $FeatureDir "requirements.md"
    $acceptance = Join-Path $FeatureDir "acceptance-tests.md"
    if (-not (Test-Path $requirements -PathType Leaf) -or -not (Test-Path $acceptance -PathType Leaf)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage canonical inputs are missing"
    }
    if ($Stage -eq "spec") { $reqHash = Get-NormalizedHash $requirements "spec" }
    else { $reqHash = Get-Sha256 $requirements }
    # Tolerated downstream: direct comparison of the contract's own
    # top-level field against a freshly computed live-file hash --
    # unambiguous freshness, no manifest-array existence question involved.
    if ([string]$contract.requirements_sha256 -ne $reqHash -or
        [string]$contract.acceptance_sha256 -ne (Get-Sha256 $acceptance)) {
        Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "$Stage top-level contract hashes are stale"
    }
    # Test-ManifestHash's ambiguity, disambiguated per path: if EVERY
    # not-matching path is explainable as "recorded, just at a stale hash"
    # (downstream of a verified -Opening slot only), tolerate; a single
    # genuinely undeclared path among them still fails the whole check.
    $acceptanceHash = Get-Sha256 $acceptance
    Stop-WorkflowStateOrTolerateOmit $Feature $Stage "stage-provenance" "$Stage contract hashes are stale" `
        $contract $RepoRoot @(
            @{ Ok = (Test-ManifestHash $contract "/specs/$Feature/requirements.md" $reqHash $RepoRoot);
               Suffix = "/specs/$Feature/requirements.md"; Expected = $reqHash },
            @{ Ok = (Test-ManifestHash $contract "/specs/$Feature/acceptance-tests.md" $acceptanceHash $RepoRoot);
               Suffix = "/specs/$Feature/acceptance-tests.md"; Expected = $acceptanceHash }
        )
    $calibrationRelative = if ($Stage -eq "spec") {
        "plugins/sdd-review-loop/references/spec-review-calibration.md"
    } else {
        "plugins/sdd-review-loop/references/reviewer-calibration.md"
    }
    $calibration = Join-Path $RepoRoot $calibrationRelative
    $precheckRelative = "reports/$Stage-review/$Feature/attempt-$($latest.Attempt)/round-$($latest.Round)/precheck-result.json"
    $precheck = Join-Path $RepoRoot $precheckRelative
    if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or
        (Get-Item -LiteralPath $calibration -Force).LinkType -or
        -not (Test-Path -LiteralPath $precheck -PathType Leaf) -or
        (Get-Item -LiteralPath $precheck -Force).LinkType) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage required review inputs are missing"
    }
    if ($Stage -ceq 'impl') {
        if ($null -eq $adrHistory.Precheck -or -not $adrHistory.EvidenceHashes.ContainsKey($precheckRelative)) {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage required review inputs are missing"
        }
        $precheckData = $adrHistory.Precheck
        $precheckHash = $adrHistory.EvidenceHashes[$precheckRelative]
    } else {
        $precheckData = Get-Content -LiteralPath $precheck -Raw | ConvertFrom-Json
    }
    # Same per-path disambiguation. The calibration doc's own plugins/
    # historical-pin fallback (Test-ManifestHashForFile) is tried FIRST and
    # is unrelated to this recovery; only if that ALSO fails does the
    # omit-vs-stale query run, comparing against the calibration doc's
    # current live hash like every other check here.
    $calibrationHash = Get-Sha256 $calibration
    if ($Stage -cne 'impl') {
        $precheckHash = Get-Sha256 $precheck
    }
    Stop-WorkflowStateOrTolerateOmit $Feature $Stage "stage-provenance" "$Stage reviewer manifests omit required inputs" `
        $contract $RepoRoot @(
            @{ Ok = (Test-ManifestHashForFile $contract "/$calibrationRelative" $calibration $RepoRoot $contractPath);
               Suffix = "/$calibrationRelative"; Expected = $calibrationHash },
            @{ Ok = (Test-ManifestHash $contract "/$precheckRelative" $precheckHash $RepoRoot);
               Suffix = "/$precheckRelative"; Expected = $precheckHash }
        )
    if ($Stage -eq "impl") {
        $design = Join-Path $FeatureDir "design.md"
        # Tolerated downstream: Test-ManifestReviewedHash tries every
        # canonical hash form design.md's own reviewed state can
        # legitimately take (raw, lifecycle-normalized, re-review). Unlike
        # the plain Test-ManifestHash "omit" checks below, this represents
        # the document's own provenance-hash pin, not an array-membership
        # existence question -- the same role "task plan hash is stale"
        # plays for tasks.md, which the deadlock this fix resolves depends
        # on tolerating.
        if (-not (Test-ManifestReviewedHash $contract "/specs/$Feature/design.md" $design "impl" $RepoRoot)) {
            Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "implementation design hash is stale"
        }
        # Tolerated downstream: direct top-level field vs live-hash comparison.
        if (-not (Test-ReviewedHash $design "impl" ([string]$contract.design_sha256))) {
            Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "implementation top-level design hash is stale"
        }
        $layerManifestProperty = $precheckData.psobject.Properties['layer_sha256']
        $layerProperties = if ($null -eq $layerManifestProperty -or $null -eq $layerManifestProperty.Value) {
            @()
        } else {
            @($layerManifestProperty.Value.psobject.Properties)
        }
        if ($layerProperties.Count -gt 0) {
            $expectedLayers = @("ux-spec.md", "frontend-spec.md", "infra-spec.md", "security-spec.md")
            if ($layerProperties.Count -ne $expectedLayers.Count -or
                @($expectedLayers | Where-Object { $_ -notin $layerProperties.Name }).Count -gt 0) {
                Stop-WorkflowState $Feature "stage-provenance" "implementation layer precheck manifest is incomplete"
            }
            # The omit-vs-stale disambiguation runs once across all four
            # layers (an aggregate check, like calibration+precheck and
            # req/accept above): one genuinely undeclared layer must still
            # fail the whole check even if the other three are merely stale.
            $layerOmitChecks = @()
            foreach ($layer in $expectedLayers) {
                $layerPath = Join-Path $FeatureDir $layer
                if (-not (Test-Path -LiteralPath $layerPath -PathType Leaf) -or
                    (Get-Item -LiteralPath $layerPath -Force).LinkType) {
                    Stop-WorkflowState $Feature "stage-provenance" "implementation layer input is missing or linked"
                }
                $layerHash = Get-Sha256 $layerPath
                # Tolerated downstream: direct precheck/contract field vs
                # live-hash comparison.
                if ([string]$precheckData.layer_sha256.$layer -ne $layerHash -or
                    [string]$contract.layer_sha256.$layer -ne $layerHash) {
                    Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "implementation layer hash is stale"
                }
                $layerOmitChecks += @{
                    Ok = (Test-ManifestHash $contract "/specs/$Feature/$layer" $layerHash $RepoRoot)
                    Suffix = "/specs/$Feature/$layer"; Expected = $layerHash
                }
            }
            Stop-WorkflowStateOrTolerateOmit $Feature $Stage "stage-provenance" `
                "implementation reviewer manifests omit layer inputs" $contract $RepoRoot $layerOmitChecks
        }
    } elseif ($Stage -eq "task") {
        $tasks = Join-Path $FeatureDir "tasks.md"
        # Tolerated downstream: same class as the design.md pin above -- the
        # document's own provenance-hash pin, tried across every canonical
        # form. This is the literal diagnostic the epic-196 deadlock names.
        if (-not (Test-ManifestReviewedHash $contract "/specs/$Feature/tasks.md" $tasks "task" $RepoRoot)) {
            Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "task plan hash is stale"
        }
        # Tolerated downstream: direct top-level field vs live-hash comparison.
        if (-not (Test-ReviewedHash $tasks "task" ([string]$contract.tasks_sha256))) {
            Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "task top-level plan hash is stale"
        }
        $layerManifestProperty = $precheckData.psobject.Properties['layer_sha256']
        $layerProperties = if ($null -eq $layerManifestProperty -or $null -eq $layerManifestProperty.Value) { @() } else { @($layerManifestProperty.Value.psobject.Properties) }
        if ($layerProperties.Count -gt 0) {
            $traceability = Join-Path $FeatureDir "traceability.md"
            if (-not (Test-Path -LiteralPath $traceability -PathType Leaf) -or (Get-Item -LiteralPath $traceability -Force).LinkType) {
                Stop-WorkflowState $Feature "stage-provenance" "task traceability input is missing or linked"
            }
            $traceabilityHash = Get-Sha256 $traceability
            $traceabilityNormalized = Get-TraceabilityNormalizedHash $traceability
            # Tolerated downstream: direct precheck/contract field vs
            # live-hash (raw or normalized) comparison.
            if (-not (Test-TraceabilityHash ([string]$precheckData.traceability_sha256) $traceabilityHash $traceabilityNormalized) -or
                -not (Test-TraceabilityHash ([string]$contract.traceability_sha256) $traceabilityHash $traceabilityNormalized)) {
                Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "task traceability hash is stale"
            }
            $taskDesign = Join-Path $FeatureDir "design.md"
            $taskDesignHash = Get-Sha256 $taskDesign
            # Tolerated downstream: direct precheck/contract field vs
            # live-hash comparison -- this is design.md's staleness
            # surfacing on the task side of the epic-196 deadlock (design.md
            # is impl's own reviewed input, task's contract separately pins
            # its hash too).
            if ([string]$precheckData.design_sha256 -ne (Get-Sha256 $taskDesign) -or [string]$contract.design_sha256 -ne $taskDesignHash) {
                Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "task design hash is stale"
            }
            # Test-ManifestHash's ambiguity, disambiguated: this is the
            # literal epic-196 residual gate ("task reviewer manifests omit
            # design") -- design.md's manifest entry recorded at the
            # pre-amendment hash reads identically to design.md never
            # having been declared at all, unless this second query tells
            # them apart.
            Stop-WorkflowStateOrTolerateOmit $Feature $Stage "stage-provenance" `
                "task reviewer manifests omit design" $contract $RepoRoot @(
                    @{ Ok = (Test-ManifestHash $contract "/specs/$Feature/design.md" $taskDesignHash $RepoRoot);
                       Suffix = "/specs/$Feature/design.md"; Expected = $taskDesignHash }
                )
            # Traceability accepts either the raw or the lifecycle-normalized
            # form as "ok"; within the not-ok branch the recorded hash (if
            # singular) is therefore guaranteed to differ from both, so
            # comparing it against the raw form alone is sufficient for the
            # notice.
            $traceabilityManifestOk = (Test-ManifestHash $contract "/specs/$Feature/traceability.md" $traceabilityHash $RepoRoot) -or
                (Test-ManifestHash $contract "/specs/$Feature/traceability.md" $traceabilityNormalized $RepoRoot)
            Stop-WorkflowStateOrTolerateOmit $Feature $Stage "stage-provenance" `
                "task reviewer manifests omit traceability" $contract $RepoRoot @(
                    @{ Ok = $traceabilityManifestOk;
                       Suffix = "/specs/$Feature/traceability.md"; Expected = $traceabilityHash }
                )
            $expectedLayers = @("ux-spec.md", "frontend-spec.md", "infra-spec.md", "security-spec.md")
            if ($layerProperties.Count -ne $expectedLayers.Count -or @($expectedLayers | Where-Object { $_ -notin $layerProperties.Name }).Count -gt 0) {
                Stop-WorkflowState $Feature "stage-provenance" "task layer precheck manifest is incomplete"
            }
            # Aggregate, same as the impl-stage layer loop above: one
            # genuinely undeclared layer must still fail the whole check
            # even if the other three are merely stale.
            $layerOmitChecks = @()
            foreach ($layer in $expectedLayers) {
                $layerPath = Join-Path $FeatureDir $layer
                if (-not (Test-Path -LiteralPath $layerPath -PathType Leaf) -or (Get-Item -LiteralPath $layerPath -Force).LinkType) {
                    Stop-WorkflowState $Feature "stage-provenance" "task layer input is missing or linked"
                }
                $layerHash = Get-Sha256 $layerPath
                # Tolerated downstream: direct precheck/contract field vs
                # live-hash comparison.
                if ([string]$precheckData.layer_sha256.$layer -ne $layerHash -or [string]$contract.layer_sha256.$layer -ne $layerHash) {
                    Stop-WorkflowStateOrTolerate $Feature $Stage "stage-provenance" "task layer hash is stale"
                }
                $layerOmitChecks += @{
                    Ok = (Test-ManifestHash $contract "/specs/$Feature/$layer" $layerHash $RepoRoot)
                    Suffix = "/specs/$Feature/$layer"; Expected = $layerHash
                }
            }
            Stop-WorkflowStateOrTolerateOmit $Feature $Stage "stage-provenance" `
                "task reviewer manifests omit layer inputs" $contract $RepoRoot $layerOmitChecks
        }
    }
}

# The exact legacy schema const controls which task can reopen.
function Test-LegacyTaskOverrides([string]$Feature, [string]$Tasks, $Entry) {
    $item = Get-Item -LiteralPath $Tasks -ErrorAction SilentlyContinue
    if (-not $item -or $item.PSIsContainer -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Stop-WorkflowState $Feature "legacy-state" "task plan is missing, linked, or unreadable"
    }
    $records = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $current = $null
    foreach ($line in [IO.File]::ReadAllLines($Tasks)) {
        if ($line -cmatch '^[ \t]*##([^#]|$)') {
            $current = $null
            if ($line -cmatch '^## (T-[0-9]{3})(?:[ \t]|$)') {
                $id = $Matches[1]
                if (-not $seen.Add($id)) {
                    Stop-WorkflowState $Feature "legacy-state" "duplicate task identity"
                }
                $current = [pscustomobject]@{ Id = $id; Approvals = 0; Statuses = 0; Approval = ''; Status = '' }
                $records.Add($current)
            }
            continue
        }
        if ($line -cmatch '^Approval:') {
            if ($null -eq $current) { Stop-WorkflowState $Feature "legacy-state" "orphan approval" }
            $current.Approvals++
            $current.Approval = (($line -creplace '^Approval:[ \t]*', '') -creplace '[ \t]+\(.*$', '').TrimEnd([char[]]" `t")
        }
        if ($line -cmatch '^Status:') {
            if ($null -eq $current) { Stop-WorkflowState $Feature "legacy-state" "orphan status" }
            $current.Statuses++
            $current.Status = ($line -creplace '^Status:[ \t]*', '').TrimEnd([char[]]" `t")
        }
    }
    if (-not $seen.Contains('T-002')) { Stop-WorkflowState $Feature "legacy-state" "reopening task is absent" }
    foreach ($record in $records) {
        if ($record.Approvals -ne 1 -or $record.Statuses -ne 1 -or
            $record.Approval.Contains("`t") -or $record.Status.Contains("`t")) {
            Stop-WorkflowState $Feature "legacy-state" "task lifecycle fields are malformed"
        }
        if ($record.Approval -cne 'Approved') {
            Stop-WorkflowState $Feature "legacy-state" "reopening contract requires Approved tasks"
        }
        $allowed = @($Entry.legacy.allowed_task_statuses)
        if ($record.Id -ceq 'T-002') { $allowed = @($Entry.legacy.task_status_overrides.'T-002') }
        if ($allowed -cnotcontains $record.Status) {
            Stop-WorkflowState $Feature "legacy-state" "task lifecycle is broader than the migration record"
        }
    }
}

function Test-Legacy([string]$Feature, [string]$Directory, $Entry) {
    $stages = @(
        @("spec", "requirements.md", "Spec-Review-Status", "spec_status"),
        @("impl", "design.md", "Impl-Review-Status", "impl_status"),
        @("task", "tasks.md", "Task-Review-Status", "task_status")
    )
    foreach ($stage in $stages) {
        $value = Get-Header (Join-Path $Directory $stage[1]) $stage[2]
        if (-not $value) {
            if (@($Entry.legacy.allowed_missing_stages) -notcontains $stage[0]) {
                Stop-WorkflowState $Feature "legacy-state" "missing $($stage[0]) status is not declared"
            }
        } else {
            $allowed = @($Entry.legacy.allowed_noncanonical_statuses.($stage[3]))
            if ($allowed -notcontains $value) {
                Stop-WorkflowState $Feature "legacy-state" "$($stage[0]) status is broader than the migration record"
            }
        }
    }
    $tasks = Join-Path $Directory "tasks.md"
    if (@($Entry.legacy.PSObject.Properties.Name) -ccontains 'task_status_overrides') {
        Test-LegacyTaskOverrides $Feature $tasks $Entry
        return
    }
    if (Test-Path $tasks -PathType Leaf) {
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($tasks), "(?m)^Approval:\s*([^\r\n(]+)")) {
            if (@($Entry.legacy.allowed_task_approvals) -notcontains $match.Groups[1].Value.Trim()) {
                Stop-WorkflowState $Feature "legacy-state" "task approval is broader than the migration record"
            }
        }
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($tasks), "(?m)^Status:\s*([^\r\n]+)")) {
            if (@($Entry.legacy.allowed_task_statuses) -notcontains $match.Groups[1].Value.Trim()) {
                Stop-WorkflowState $Feature "legacy-state" "task lifecycle is broader than the migration record"
            }
        }
    }
}

foreach ($entry in @($RegistryData.entries)) {
    $feature = [string]$entry.feature
    if ($FeatureFilter -and $feature -ne $FeatureFilter) { continue }
    if ($script:RegistryFailedFeatures.ContainsKey($feature)) { continue }
    $script:FeatureScopeActive = $true
    try {
    $profile = [string]$entry.profile
    $directory = Join-Path $SpecsRoot $feature
    if ($profile -eq "lite") { continue }
    if ($profile -eq "legacy") { Test-Legacy $feature $directory $entry; continue }
    foreach ($required in @("requirements.md", "design.md", "acceptance-tests.md")) {
        $path = Join-Path $directory $required
        if (-not (Test-Path $path -PathType Leaf) -or (Get-Item $path -Force).LinkType) {
            Stop-WorkflowState $feature "stage-input" "$required is missing, linked, or unreadable"
        }
    }
    $spec = Get-Header (Join-Path $directory "requirements.md") "Spec-Review-Status"
    $impl = Get-Header (Join-Path $directory "design.md") "Impl-Review-Status"
    $tasks = Join-Path $directory "tasks.md"
    $taskItem = Get-Item -LiteralPath $tasks -Force -ErrorAction SilentlyContinue
    if ($taskItem -and ($taskItem.LinkType -or -not (Test-Path -LiteralPath $tasks -PathType Leaf))) {
        Stop-WorkflowState $feature "stage-input" "tasks.md is linked or unreadable"
    }
    $task = Get-Header $tasks "Task-Review-Status"
    if ($taskItem -and -not $task) { Stop-WorkflowState $feature "stage-status" "tasks.md has no Task-Review-Status" }
    if ($spec -notin @("Pending", "Passed")) { Stop-WorkflowState $feature "stage-status" "Spec status is missing or invalid" }
    if ($impl -notin @("Pending", "Passed")) { Stop-WorkflowState $feature "stage-status" "Impl status is missing or invalid" }
    if ($task -and $task -notin @("Pending", "Passed")) { Stop-WorkflowState $feature "stage-status" "Task status is invalid" }
    if ($impl -eq "Passed" -and $spec -ne "Passed") { Stop-WorkflowState $feature "stage-order" "Impl Passed requires Spec Passed" }
    if ($task -eq "Passed" -and ($spec -ne "Passed" -or $impl -ne "Passed")) {
        Stop-WorkflowState $feature "stage-order" "Task Passed requires Spec and Impl Passed"
    }
    if ((Test-Path $tasks -PathType Leaf) -and ($spec -ne "Passed" -or $impl -ne "Passed")) {
        Stop-WorkflowState $feature "task-lifecycle" "tasks.md requires Spec and Impl Passed"
    }
    if (Test-Path $tasks -PathType Leaf) {
        $taskText = [IO.File]::ReadAllText($tasks)
        $approvals = @([regex]::Matches($taskText, "(?m)^Approval:\s*([^\r\n]+)") |
            ForEach-Object { $_.Groups[1].Value.Trim() })
        $statuses = @([regex]::Matches($taskText, "(?m)^Status:\s*([^\r\n]+)") |
            ForEach-Object { $_.Groups[1].Value.Trim() })
        foreach ($approval in $approvals) {
            if ($approval -ne "Draft" -and $approval -notmatch "^Approved(?:\s+\([^)]*\))?$") {
                Stop-WorkflowState $feature "task-lifecycle" "task approval is invalid"
            }
        }
        foreach ($status in $statuses) {
            if ($status -notin @("Planned", "In Progress", "Blocked", "Implementation Complete", "Done")) {
                Stop-WorkflowState $feature "task-lifecycle" "task status is invalid"
            }
        }
        if ($approvals.Count -eq 0 -or $approvals.Count -ne $statuses.Count) {
            Stop-WorkflowState $feature "task-lifecycle" "task lifecycle fields are incomplete"
        }
        if ($task -eq "Pending") {
            foreach ($match in [regex]::Matches($taskText, "(?m)^Approval:\s*([^\r\n]+)")) {
                if ($match.Groups[1].Value.Trim() -ne "Draft") {
                    Stop-WorkflowState $feature "task-lifecycle" "pending task review permits only Draft approvals"
                }
            }
            foreach ($match in [regex]::Matches($taskText, "(?m)^Status:\s*([^\r\n]+)")) {
                if ($match.Groups[1].Value.Trim() -ne "Planned") {
                    Stop-WorkflowState $feature "task-lifecycle" "pending task review permits only Planned statuses"
                }
            }
        }
        if (($taskText -match "(?m)^Approval:\s*Approved" -or
             $taskText -match "(?m)^Status:\s*(In Progress|Blocked|Implementation Complete|Done)") -and
            ($spec -ne "Passed" -or $impl -ne "Passed" -or $task -ne "Passed")) {
            Stop-WorkflowState $feature "task-lifecycle" "executable task state requires all reviews Passed"
        }
    }
    if ($spec -eq "Passed") { Test-PassedStage $feature "spec" $directory }
    if ($impl -eq "Passed") { Test-PassedStage $feature "impl" $directory }
    if ($task -eq "Passed") { Test-PassedStage $feature "task" $directory }
    } catch {
        if ([string]$_.Exception.Message -ne $script:WorkflowStateFeatureAbort) { throw }
        $script:WorkflowStateFailed++
    } finally {
        $script:FeatureScopeActive = $false
    }
}

if ($script:WorkflowStateFailed -gt 0) { exit 1 }
Write-Output "workflow-state: ok"
exit 0
