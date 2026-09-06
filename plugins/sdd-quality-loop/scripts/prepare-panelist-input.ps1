# Collection layer: prepare sanitized panelist input bundle with consent gate.
# Usage:
#   prepare-panelist-input.ps1 --task T-NNN --feature <f> --input <path|dir>
#                              [--tasks-file specs/<f>/tasks.md]
#                              [--out <path>]
#                              [--spec-root <dir>]
#                              [--project-root <dir>]
#                              [--effort <low|medium|high|xhigh>]
#                              [--max-bytes <n>]
#
# --max-bytes (optional, no default -- unset means unlimited): a fail-closed
# size guard on the FINAL sanitized bundle. A vendor caller with a known
# input cap (e.g. codex exec's 1,048,576-character limit) passes its own
# threshold here. If the sanitized bundle would exceed it, this script
# prints a per-section byte breakdown to stderr, writes NO output file, and
# exits 1 -- it never truncates. A panelist who cannot tell their input was
# cut would report confident conclusions about material they never saw,
# which is worse than a failed run that says so plainly.
#
# Per-file elision (only when --max-bytes is set, and only when the whole
# bundle exceeds it): a two-tier, budget-driven cut. Tier one is the
# reviewed task's own verification/<task_id>/ evidence directory plus every
# path the task's own contract.json names in an "evidence", "red_evidence",
# or "green_evidence" field, wherever in the repo that path lives -- the
# task's own raw log/tool-output noise. Tier two -- used ONLY once every
# tier-one candidate has been through the loop below and the bundle is
# STILL over --max-bytes -- is the CURRENT worktree content of every path
# the implementation report's "## Outputs" table declares. Within each
# tier, the largest remaining candidate is cut first, to its first/last 40
# lines plus a marker stating how many bytes were elided from the middle
# and from which path -- never silently -- re-measuring the bundle after
# every single cut and stopping the moment it fits. Tier two is never
# touched while tier one could still reduce the bundle: a reviewer told to
# judge material "as it stands" should lose incidental log noise before
# losing any of the source under review, and only ever as much of either as
# the cap forces. Spec documents, the task's own contract/evidence.json,
# and the implementation report are in neither tier -- never elided, at any
# bundle size. If the bundle is still over --max-bytes after both tiers are
# exhausted, this script still fails closed exactly as above.
#
# Security (design.md §6):
#   * Fail-closed consent gate: exits non-zero without writing output unless
#     tasks.md contains "Cross-Model: enabled" for the task, OR a valid
#     SDD_SUDO token is present (see sudo-mode-policy.md).
#   * Sanitization: strips .env values, API keys/tokens, absolute paths, and
#     private/RFC-1918 URLs before writing the bundle.
#   * input_digest: sha256 of the sanitized bundle, printed to stdout.
#   * Key isolation: SDD_EVIDENCE_KEY / sudo key are never included in output.
#
# Exit codes: 0=success  1=consent denied / input error  2=tool error (bad args)
#
# --effort (epic-159-pillar-c T-006, REQ-006/AC-036): optional pass-through.
# This script prepares ONE shared sanitized bundle consumed by every panelist
# vendor -- it never invokes a vendor CLI itself -- so a selector-derived
# effort value is threaded through by being echoed on a second stdout line
# ("effort=<e>", after the existing digest line), for the caller to lift
# into `run-panelist-gpt --effort <e>` in its own next step. Omitted
# entirely preserves today's exact single-line stdout output (Breaking API:
# no).
#
# Simplification note (HMAC): Full HMAC-SHA256 verification of SDD_SUDO requires
# the key from ~/.sdd/sudo-key or SDD_SUDO_KEY env var. We perform complete
# HMAC verification when the key is resolvable. When SDD_SUDO_SKIP_SIG=1 is set
# (test scaffolding only), signature check is skipped.
param()
$ErrorActionPreference = "Stop"

# ── Parse GNU-style --flag value arguments ───────────────────────────────────
$TaskId      = ""
$Feature     = ""
$InputPath   = ""
$TasksFile   = ""
$OutPath     = ""
$SpecRoot    = "specs"
$ProjectRoot = ""
$Effort      = ""
$MaxBytes    = ""

$argIdx = 0
$passedArgs = $args
while ($argIdx -lt $passedArgs.Count) {
    switch ($passedArgs[$argIdx]) {
        "--task"         { $TaskId      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--feature"      { $Feature     = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--input"        { $InputPath   = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--tasks-file"   { $TasksFile   = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--out"          { $OutPath     = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--spec-root"    { $SpecRoot    = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--project-root" { $ProjectRoot = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--effort"       { $Effort      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--max-bytes"    { $MaxBytes    = $passedArgs[$argIdx+1]; $argIdx += 2 }
        default {
            [Console]::Error.WriteLine("prepare-panelist-input: unknown argument: $($passedArgs[$argIdx])")
            exit 2
        }
    }
}

# ── Validate required arguments ──────────────────────────────────────────────

if (-not $TaskId) {
    [Console]::Error.WriteLine("prepare-panelist-input: --task is required")
    exit 2
}
if (-not $Feature) {
    [Console]::Error.WriteLine("prepare-panelist-input: --feature is required")
    exit 2
}
if (-not $InputPath) {
    [Console]::Error.WriteLine("prepare-panelist-input: --input is required")
    exit 2
}

# Resolve project root
if (-not $ProjectRoot) {
    $dir = (Get-Location).Path
    while ($dir -and $dir -ne (Split-Path $dir -Parent)) {
        if ((Test-Path (Join-Path $dir "AGENTS.md")) -or (Test-Path (Join-Path $dir ".git"))) {
            $ProjectRoot = $dir
            break
        }
        $dir = Split-Path $dir -Parent
    }
    if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }
}

# Default tasks file
if (-not $TasksFile) {
    $TasksFile = Join-Path $SpecRoot (Join-Path $Feature "tasks.md")
}

# Default output path
if (-not $OutPath) {
    $OutPath = Join-Path $SpecRoot (Join-Path $Feature (Join-Path "verification" "$TaskId.panelist-input.txt"))
}

# ── Consent gate (fail-closed) ───────────────────────────────────────────────

$ConsentKind = ""

# Check (a): tasks.md has "Cross-Model: enabled" in the task section
if (Test-Path $TasksFile) {
    $inSection = $false
    foreach ($line in (Get-Content -Encoding Utf8 $TasksFile)) {
        $line = $line.TrimEnd("`r")
        if ($line -match "^## $([regex]::Escape($TaskId))(\s|$)") {
            $inSection = $true
        } elseif ($line -match "^## " -and $inSection) {
            break
        } elseif ($inSection -and $line -eq "Cross-Model: enabled") {
            $ConsentKind = "human-flag"
            break
        }
    }
}

# Check (b): SDD_SUDO token
if (-not $ConsentKind) {
    $sudoFile = Join-Path $ProjectRoot "SDD_SUDO"
    if ((Test-Path -LiteralPath $sudoFile) -and (-not (Get-Item -LiteralPath $sudoFile).LinkType)) {
        $fields = @{}
        foreach ($line in (Get-Content -Encoding Utf8 $sudoFile)) {
            $line = $line.TrimEnd("`r")
            if ($line -match "^([a-z\-]+): (.+)$") {
                $fields[$Matches[1]] = $Matches[2].Trim()
            }
        }

        $requiredFields = @("issuer","nonce","repo","issued-epoch","expires-epoch","sig")
        $allPresent = ($requiredFields | Where-Object { -not $fields[$_] }).Count -eq 0

        if ($allPresent) {
            # Nonce: >= 32 hex chars
            $nonceOk = $fields["nonce"] -match '^[0-9a-fA-F]{32,}$'

            # Time window
            $now     = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $issued  = [long]$fields["issued-epoch"]
            $expires = [long]$fields["expires-epoch"]
            $maxTtl  = 86400
            $timeOk  = ($issued -le $now) -and ($now -lt $expires) -and (($expires - $issued) -le $maxTtl)

            # Repo binding: repo field equals realpath of directory containing SDD_SUDO
            $expectedRepo = (Resolve-Path (Split-Path -Parent $sudoFile)).Path
            $repoOk = ($fields["repo"] -eq $expectedRepo)

            # HMAC signature verification
            $sigOk = $false
            $skipSig = ($env:SDD_SUDO_SKIP_SIG -eq "1")

            if ($skipSig) {
                $sigOk = $true
            } else {
                # Resolve key
                $keyBytes = $null
                if ($env:SDD_SUDO_KEY) {
                    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($env:SDD_SUDO_KEY)
                } elseif ($env:SDD_SUDO_KEY_FILE) {
                    # A named key file that is missing or unreadable fails
                    # CLOSED with no fallback to ~/.sdd/sudo-key — matching
                    # sdd-hook-guard.ps1's Resolve-SudoKey. The previous
                    # `-and (Test-Path ...)` elseif silently substituted the
                    # home key when the named file was absent: key
                    # substitution in a signature-verification path. Trim is
                    # the guard's exact " `t`r`n" set, not bare TrimEnd()
                    # (all Unicode whitespace).
                    try {
                        $raw = (Get-Content -Raw -Encoding Utf8 -LiteralPath $env:SDD_SUDO_KEY_FILE).TrimEnd(" `t`r`n")
                        if ($raw.Length -gt 0) {
                            $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
                        }
                    } catch { }
                } else {
                    $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
                    $keyFile = Join-Path $homeDir ".sdd/sudo-key"
                    if (Test-Path -LiteralPath $keyFile) {
                        try {
                            $raw = (Get-Content -Raw -Encoding Utf8 -LiteralPath $keyFile).TrimEnd(" `t`r`n")
                            if ($raw.Length -gt 0) {
                                $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
                            }
                        } catch { }
                    }
                }

                if ($keyBytes) {
                    $canonical = "$($fields['issuer'])`n$($fields['nonce'])`n$($fields['repo'])`n$($fields['issued-epoch'])`n$($fields['expires-epoch'])"
                    $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
                    $msgBytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
                    $computed = ($hmac.ComputeHash($msgBytes) | ForEach-Object { $_.ToString("x2") }) -join ""
                    # String-compare (PowerShell doesn't have constant-time compare; noted in policy)
                    $sigOk = ($computed -eq $fields["sig"].ToLower())
                }
                # No key resolvable → token inactive (fail-closed)
            }

            if ($nonceOk -and $timeOk -and $repoOk -and $sigOk) {
                $ConsentKind = "sudo"
            }
        }
    }
}

if (-not $ConsentKind) {
    [Console]::Error.WriteLine(
        "prepare-panelist-input: consent denied for $TaskId — no Cross-Model: enabled flag in $TasksFile and no valid SDD_SUDO token")
    exit 1
}

# ── Collect input content ────────────────────────────────────────────────────
# Task-scoped composition (replaces the earlier whole-directory -Recurse walk
# of --input). The old walk read every file under --input, which in real
# invocations was `specs/<feature>/` -- every OTHER task's evidence logs,
# quality-gate transcripts, and mutation output, all concatenated into one
# bundle. Two panelists on epic-195 independently reported this: bundles
# that were mostly unrelated-task noise while containing "zero bytes of any
# of the five files [the task] actually changed" -- the Outputs table names
# those files, but the old walk never read outside specs/. A directory walk
# is structurally the wrong shape for "what does a reviewer of ONE task
# need"; this composes that set instead of discovering it by traversal:
#   1. the feature's spec documents (fixed filenames, each only if present)
#   2. the reviewed task's own verification contract + evidence.json
#   3. the reviewed task's own verification/<task_id>/ evidence directory
#      (recursively, same panel-artifact exclusions the old walk applied)
#   3b. every path the reviewed task's own contract.json names in an
#      "evidence", "red_evidence", or "green_evidence" field, whenever that
#      path is NOT already covered by step 3 (a task's contract routinely
#      names shared evidence outside verification/<task_id>/, e.g.
#      verification/qg/shared/regression.log -- a panelist handed a check
#      asserting passes:false with no way to read what it points at cannot
#      tell whether that claim is honest, which is the same defect two
#      panelists already raised about source code, one level over). See
#      Get-PpiContractEvidencePaths.
#   4. the reviewed task's own implementation report
#   5. the CURRENT worktree content of every path the report's "## Outputs"
#      table declares -- appended below, after
#      Invoke-DeclaredOutputsCompletenessCheck resolves each row (see
#      $script:PpiDeclaredContent and Add-PpiDeclaredOutputContent). The
#      completeness check may still consult the declaration commit to
#      decide whether a row was ever true, but that historical blob is
#      never what lands in the bundle: a row whose worktree hash no longer
#      matches the declared one still contributes its worktree bytes, plus
#      an in-bundle notice that the report's declaration is stale; a row
#      absent from the worktree entirely contributes no content, only a
#      notice -- reviewing material a panelist is told to judge "as it
#      stands" must never be quietly historical.
# --input is unchanged for a literal FILE argument (still read verbatim --
# this is the shape used by secret-sanitization fixtures, and is orthogonal
# to feature/task composition). --input is retained as the completeness
# check's first-try resolution root (unchanged; see
# Invoke-DeclaredOutputsCompletenessCheck) even though real callers now get
# task-scoped content regardless of what --input points to.

if (-not (Test-Path $InputPath)) {
    [Console]::Error.WriteLine("prepare-panelist-input: input not found: $InputPath")
    exit 1
}

# Rejects any declared path that is not a plain, relative, forward-slash,
# no-`..`-segment path -- containment check BEFORE any read is attempted.
# Shared by step 3b below (contract-declared evidence) and by
# Invoke-DeclaredOutputsCompletenessCheck further down (Outputs-table
# rows) -- both need the identical containment discipline applied to a
# path taken from repo content, not from a trusted caller.
function Test-DeclaredOutputCanonicalPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    if ($Path.StartsWith("/")) { return $false }
    if ($Path -match "^[A-Za-z]:") { return $false }
    if ($Path.Contains("\")) { return $false }
    if ($Path -match "(^|/)\.\.?(/|$)") { return $false }
    return $true
}

# Resolve one declared row (an Outputs-table path, or here a contract's
# evidence/red_evidence/green_evidence path) under a single candidate root,
# applying a component-walk symlink guard -- no symbolic link anywhere
# between the candidate root and the candidate may be followed (mirrors
# validate-review-context-set.sh's own symlink-component-walk). Returns
# @{ State = "Matched"|"Escaped"|"Absent"; Candidate = ... } (Candidate is
# set only when State is "Matched").
function Resolve-DeclaredOutputRow {
    param([string]$RowPath, [string]$Root)

    $current = $Root.TrimEnd('/', '\')
    $escaped = $false
    foreach ($component in ($RowPath -split '/')) {
        $current = "$current/$component"
        $item = Get-Item -LiteralPath $current -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) { $escaped = $true }
    }
    if ($escaped) {
        return @{ State = "Escaped"; Candidate = $null }
    }

    $candidate = Join-Path $Root $RowPath
    $candidateItem = Get-Item -LiteralPath $candidate -ErrorAction SilentlyContinue
    if ($candidateItem -and (-not $candidateItem.PSIsContainer) -and (-not $candidateItem.LinkType)) {
        return @{ State = "Matched"; Candidate = $candidate }
    }
    return @{ State = "Absent"; Candidate = $null }
}

# Extract every unique, non-empty "evidence"/"red_evidence"/"green_evidence"
# value across a contract.json's "checks" array, in first-seen order.
# Self-dedups (a contract routinely repeats the same path across
# evidence/green_evidence, or across sibling checks like unit-tests and
# acceptance-tests sharing one log) so step 3b below never considers the
# same path twice from the same contract. Returns an empty array (not an
# error) on a missing/unparseable contract or an absent/non-array "checks"
# field -- contract shape is check-contract.ps1's job, not this script's;
# a task under review with no contract yet simply contributes no extra
# evidence paths here.
function Get-PpiContractEvidencePaths {
    param([string]$ContractPath)

    $result = New-Object System.Collections.Generic.List[string]
    $seen = New-Object System.Collections.Generic.HashSet[string]

    try {
        $contract = Get-Content -Raw -Encoding Utf8 -LiteralPath $ContractPath | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $result
    }

    $checks = $contract.checks
    if (-not $checks) { return $result }

    foreach ($check in @($checks)) {
        foreach ($field in @("evidence", "red_evidence", "green_evidence")) {
            $val = $check.$field
            if ($val -isnot [string]) { continue }
            $val = $val.Trim()
            if (-not $val) { continue }
            if ($seen.Add($val)) {
                $result.Add($val) | Out-Null
            }
        }
    }

    return $result
}

# Tracks project-root-relative paths already pulled in by steps 1-4 above, so
# step 5 (declared outputs) does not duplicate a file already present (e.g.
# tasks.md and CHANGELOG.md are commonly both a spec document/committed file
# AND a declared output; verification/<task_id>/*.log is commonly both the
# task's own evidence dir AND separately declared). Only meaningful for rows
# that resolve project-root-relative; rows resolved under --input have no
# comparable identity here and are never deduplicated against this set.
$script:PpiSeenRelPaths = New-Object System.Collections.Generic.HashSet[string]

# Per-file elision (Part 2, design.md §6 follow-up): a single oversized
# evidence log (e.g. a whole-repo run-all capture), or several moderate
# ones together, can push a bundle over --max-bytes even though every byte
# is legitimate evidence, not noise. Truncating silently would let a
# reviewer draw confident conclusions about material they never saw -- the
# same reasoning that made --max-bytes fail closed instead of truncating
# the whole bundle (see the file header). The fix here is the same shape
# at file granularity: keep a file's own first/last lines, and replace the
# middle with a marker stating, in plain words, how many bytes were
# removed and from which path.
#
# Budget-driven, not threshold-driven. An earlier version of this elided
# any single file over one quarter of --max-bytes, which got two things
# wrong in practice: a bundle with one file just over that fraction and
# another just under it treated two near-identical artifacts oppositely
# for no benefit when the bundle was refused anyway, and a bundle whose
# overage was spread across many moderate files (none individually over
# the fraction) got no elision help at all. This version composes the
# bundle WHOLE first and measures it. If it already fits --max-bytes,
# nothing is elided -- every such bundle is byte-for-byte what it would be
# with no elision logic in this script at all. Only when the whole bundle
# is over cap does it elide, one file at a time, LARGEST FIRST, from the
# elidable set only, recomputing the actual sanitized bundle size after
# each elision (never estimated -- eliding one file changes the total, so
# each step re-measures) until it fits or the elidable set is exhausted.
# Exhausted-and-still-over fails closed, unchanged in shape from before
# Part 2. This is also the honest answer to the degenerate case where even
# every elidable file's own head+tail+marker floor, summed with the
# content that is never elided, still exceeds --max-bytes: no amount of
# elision can fix that, so refusing to write is correct -- identical in
# spirit to failing closed when there were no elidable candidates at all.
#
# Scope, two tiers. Tier one (elidable first -- see $script:PpiElidableIndex)
# is step 3 (the reviewed task's own verification/<task_id>/ evidence
# directory) plus step 3b (contract-declared evidence found elsewhere in
# the repo) -- the task's own raw log/tool-output noise. Tier two (elidable
# only once tier one's own budget loop has run and the bundle is STILL over
# cap -- see $script:PpiDeclaredElidableIndex, built by
# Add-PpiDeclaredOutputContent/Build-PpiDeclaredContent below) is step 5,
# every declared-outputs row -- the source the report's claims are actually
# about. That ordering is the point: a reviewer told to judge review
# material "as it stands" should lose incidental log noise long before
# losing any of the source under review, and only ever as much of either as
# the cap actually forces. It took a real production bundle to justify
# cutting declared-outputs content at all -- a 263,703-byte whole-repo
# CHANGELOG.md, 25% of the bundle, for a task that appended a handful of
# lines to it -- but that file is still review material, so it is the LAST
# thing this loop will touch, not the first.
#
# Spec documents (step 1), the task's own contract/evidence.json (step 2),
# and the implementation report (step 4) are in NEITHER tier -- never
# elided, at any bundle size. A cut requirements.md or design.md cannot be
# reviewed against its own acceptance criteria, and a cut implementation
# report is the very thing under review; unlike a declared-outputs row --
# one file among several, each independently readable -- these are
# singular per-bundle documents where head/tail elision would routinely
# remove the exact criteria or Outputs table a panelist needs to judge the
# rest of the bundle by. A third tier for either was considered and
# rejected for that reason: there is no partial version of "the criteria
# this task is judged against" that stays meaningful once cut.
#
# Head/tail size stays a fixed line count (not proportional to the cap) --
# this exists purely for reviewer legibility (show a log's setup and its
# final summary), never as a byte dial; the byte-target job stays entirely
# with --max-bytes and the budget loop, in both tiers.
$script:PpiElideLines = 40

# One file's content, elided to its first/last $PpiElideLines lines plus a
# marker. Callers only invoke this for a file the budget loop below has
# already decided to elide -- it is not itself threshold-gated.
function Get-PpiElidedContent {
    param([string]$FilePath, [string]$Label)
    $raw = Get-Content -Raw -Encoding Utf8 -LiteralPath $FilePath
    $totalBytes = [System.Text.Encoding]::UTF8.GetByteCount($raw)
    $lines = Get-Content -Encoding Utf8 -LiteralPath $FilePath
    $lineCount = $lines.Count
    $n = [Math]::Min($script:PpiElideLines, $lineCount)
    $headText = ($lines[0..($n - 1)] -join "`n")
    $tailStart = $lineCount - $n
    $tailText = ($lines[$tailStart..($lineCount - 1)] -join "`n")
    $headBytes = [System.Text.Encoding]::UTF8.GetByteCount($headText)
    $tailBytes = [System.Text.Encoding]::UTF8.GetByteCount($tailText)
    $elided = $totalBytes - $headBytes - $tailBytes
    if ($elided -lt 0) { $elided = 0 }
    $marker = "[... $elided bytes elided from the middle of $Label (original size $totalBytes bytes; showing first/last $n lines) ...]"
    return "$headText`n$marker`n$tailText"
}

# Append one file's content to $rawContent (by ref, via [ref]) with a path
# header, so a reviewer (and these tests) can tell which bytes came from
# which file -- the old walk concatenated files with no such marker at
# all. -Elidable reads the file through Get-PpiElidedContent instead of
# whole; only the step-3 rebuild function below ever passes it.
function Add-PpiFileContent {
    param([ref]$RawContent, [string]$FilePath, [string]$RelPath, [switch]$Elidable)
    if ($Elidable) {
        $content = Get-PpiElidedContent -FilePath $FilePath -Label $RelPath
    } else {
        $content = Get-Content -Raw -Encoding Utf8 -LiteralPath $FilePath
    }
    $RawContent.Value += "# ---- $RelPath ----`n$content`n"
}

$rawContent = ""

if ((Get-Item $InputPath).PSIsContainer) {
    $specDir = Join-Path $ProjectRoot (Join-Path $SpecRoot $Feature)

    # 1. Spec documents (fixed order; only those that exist).
    $specDocs = @("requirements.md", "design.md", "acceptance-tests.md",
        "tasks.md", "traceability.md", "investigation.md",
        "ux-spec.md", "frontend-spec.md", "infra-spec.md", "security-spec.md")
    foreach ($doc in $specDocs) {
        $docPath = Join-Path $specDir $doc
        $docItem = Get-Item -LiteralPath $docPath -ErrorAction SilentlyContinue
        if ($docItem -and (-not $docItem.PSIsContainer) -and (-not $docItem.LinkType)) {
            $docRel = "$SpecRoot/$Feature/$doc"
            Add-PpiFileContent -RawContent ([ref]$rawContent) -FilePath $docPath -RelPath $docRel
            $script:PpiSeenRelPaths.Add($docRel) | Out-Null
        }
    }

    # 2. The reviewed task's own verification contract + evidence.json.
    $verifDir = Join-Path $specDir "verification"
    foreach ($vf in @("$TaskId.contract.json", "$TaskId.evidence.json")) {
        $vfPath = Join-Path $verifDir $vf
        $vfItem = Get-Item -LiteralPath $vfPath -ErrorAction SilentlyContinue
        if ($vfItem -and (-not $vfItem.PSIsContainer) -and (-not $vfItem.LinkType)) {
            $vfRel = "$SpecRoot/$Feature/verification/$vf"
            Add-PpiFileContent -RawContent ([ref]$rawContent) -FilePath $vfPath -RelPath $vfRel
            $script:PpiSeenRelPaths.Add($vfRel) | Out-Null
        }
    }

    # Steps 1+2 are never elided -- freeze them as the fixed prefix, then
    # reset $rawContent so step 4 (also never elided) can be assembled
    # separately. Step 3 sits BETWEEN these two in the final bundle but is
    # composed by Build-PpiStep3Content below, possibly more than once, so
    # it is never accumulated directly into $rawContent at all.
    $script:PpiContentPrefix = $rawContent
    $rawContent = ""

    # 3. The reviewed task's own verification/<task_id>/ evidence
    # directory, recursively, sorted for determinism -- same panel-
    # artifact exclusions the old whole-directory walk applied, now scoped
    # to just this task's own subdirectory instead of the whole feature.
    # This pass only INVENTORIES the elidable candidates (size, absolute
    # path, relative path -- one record per file in
    # $script:PpiElidableIndex) and marks each file seen -- seen-ness and
    # dedup against step 5 do not depend on whether a file ends up elided,
    # only on whether it is present at all. Actual content composition
    # happens in Build-PpiStep3Content, below, invoked by the budget loop
    # after $script:PpiDeclaredContent is ready.
    $taskVerifDir = Join-Path $verifDir $TaskId
    $script:PpiElidableIndex = @()
    $taskVerifItem = Get-Item -LiteralPath $taskVerifDir -ErrorAction SilentlyContinue
    if ($taskVerifItem -and $taskVerifItem.PSIsContainer -and (-not $taskVerifItem.LinkType)) {
        $panelArtifacts = @('*.panelist-input.txt', '*.verdict.json', '*.cross-model.json')
        $taskVerifFull = (Resolve-Path -LiteralPath $taskVerifDir).Path.TrimEnd('/', '\')
        foreach ($f in (Get-ChildItem -LiteralPath $taskVerifDir -File -Recurse -Exclude $panelArtifacts |
                Sort-Object FullName)) {
            $subPath = $f.FullName.Substring($taskVerifFull.Length + 1) -replace '\\', '/'
            $tfRel = "$SpecRoot/$Feature/verification/$TaskId/$subPath"
            $tfBytes = [System.Text.Encoding]::UTF8.GetByteCount((Get-Content -Raw -Encoding Utf8 -LiteralPath $f.FullName))
            $script:PpiElidableIndex += [PSCustomObject]@{ Bytes = $tfBytes; AbsPath = $f.FullName; RelPath = $tfRel }
            $script:PpiSeenRelPaths.Add($tfRel) | Out-Null
        }
    }

    # 3b. Every path the reviewed task's own contract.json names in an
    # "evidence", "red_evidence", or "green_evidence" field, when not
    # already pulled in by steps 1-3 above (see $script:PpiSeenRelPaths). A
    # contract routinely names evidence OUTSIDE verification/<task_id>/ --
    # shared regression/placeholder-scan/task-state-check logs living
    # under verification/qg/shared/, for instance -- and a panelist handed
    # a check asserting passes:false with no way to read what it points at
    # cannot tell whether that claim is honest, which is the same defect
    # already raised about source code, one level over. Found paths join
    # the SAME elidable candidate set step 3 built above (identical
    # PSCustomObject shape: Bytes, AbsPath, RelPath) so a large one is
    # subject to the identical budget-driven elision, never treated as
    # bundle-breaking on its own. A declared path that does not exist (or
    # resolves outside ProjectRoot, or through a symlink) is not silently
    # dropped -- a one-line note is appended to the bundle naming it,
    # because telling the reviewer a contract points at nothing is true
    # and useful, while hiding it reproduces exactly the "unreadable
    # claim" defect this step exists to fix.
    $contractPathForEvidence = Join-Path $verifDir "$TaskId.contract.json"
    $contractItemForEvidence = Get-Item -LiteralPath $contractPathForEvidence -ErrorAction SilentlyContinue
    if ($contractItemForEvidence -and (-not $contractItemForEvidence.PSIsContainer) -and (-not $contractItemForEvidence.LinkType)) {
        foreach ($depPath in (Get-PpiContractEvidencePaths -ContractPath $contractPathForEvidence)) {
            if ($script:PpiSeenRelPaths.Contains($depPath)) { continue }

            if (-not (Test-DeclaredOutputCanonicalPath $depPath)) {
                $rawContent += "# ---- $depPath (contract-declared evidence, not found) ----`n[contract names this evidence path but it could not be resolved safely]`n"
                $script:PpiSeenRelPaths.Add($depPath) | Out-Null
                continue
            }

            $depResult = Resolve-DeclaredOutputRow -RowPath $depPath -Root $ProjectRoot
            if ($depResult.State -eq "Matched") {
                $depBytes = [System.Text.Encoding]::UTF8.GetByteCount((Get-Content -Raw -Encoding Utf8 -LiteralPath $depResult.Candidate))
                $script:PpiElidableIndex += [PSCustomObject]@{ Bytes = $depBytes; AbsPath = $depResult.Candidate; RelPath = $depPath }
            } else {
                # WFI-059: name the join that was actually attempted, not just
                # "there". The base is the literal token <project-root>, not an
                # absolute path: the sanitize step below redacts every absolute
                # path before this bundle reaches a vendor, so an absolute form
                # would always reach the reviewer as "[PATH_REDACTED]".
                $rawContent += "# ---- $depPath (contract-declared evidence, not found) ----`n[contract names this evidence path but no file exists at <project-root>/$depPath]`n"
            }
            $script:PpiSeenRelPaths.Add($depPath) | Out-Null
        }
    }

    # 4. The reviewed task's own implementation report.
    $implReportPathForContent = Join-Path $ProjectRoot (Join-Path "reports" (Join-Path "implementation" (Join-Path $Feature "$TaskId.md")))
    $implReportItem = Get-Item -LiteralPath $implReportPathForContent -ErrorAction SilentlyContinue
    if ($implReportItem -and (-not $implReportItem.PSIsContainer) -and (-not $implReportItem.LinkType)) {
        $implReportRel = "reports/implementation/$Feature/$TaskId.md"
        Add-PpiFileContent -RawContent ([ref]$rawContent) -FilePath $implReportPathForContent -RelPath $implReportRel
        $script:PpiSeenRelPaths.Add($implReportRel) | Out-Null
    }
    $script:PpiContentSuffix = $rawContent
    $rawContent = ""
} else {
    $script:PpiContentPrefix = Get-Content -Raw -Encoding Utf8 $InputPath
    $script:PpiContentSuffix = ""
    $script:PpiElidableIndex = @()
}

# Rebuilds step 3's content from scratch given the set of relpaths ($1)
# that should be elided THIS attempt; every other elidable file is
# included whole. Called once with an empty elide-set (the "as if elision
# never existed" bundle) and, only if that is over --max-bytes, again with
# one more relpath added each time -- largest-candidate-first, decided by
# the budget loop below.
function Build-PpiStep3Content {
    param([string[]]$ElideSet)
    $content = ""
    foreach ($cand in $script:PpiElidableIndex) {
        if ($ElideSet -contains $cand.RelPath) {
            $body = Get-PpiElidedContent -FilePath $cand.AbsPath -Label $cand.RelPath
        } else {
            $body = Get-Content -Raw -Encoding Utf8 -LiteralPath $cand.AbsPath
        }
        $content += "# ---- $($cand.RelPath) ----`n$body`n"
    }
    return $content
}

# $script:PpiDeclaredRows accumulates one record per "## Outputs" row
# Invoke-DeclaredOutputsCompletenessCheck resolves (step 5 below):
# RowPath, the resolved worktree Candidate ($null when there is none),
# and Staleness ("" | "StaleHash" | "Missing"). Populated in both --input
# modes: a literal-file --input can still name a task with its own
# implementation report and Outputs table. Populated once -- it never
# depends on any elision decision, only on what
# Invoke-DeclaredOutputsCompletenessCheck resolved.
# $script:PpiDeclaredElidableIndex is the SAME PSCustomObject
# (Bytes/AbsPath/RelPath) shape $script:PpiElidableIndex uses, but only
# for rows that carry real content -- never for a "Missing" row, which has
# nothing to elide. $script:PpiDeclaredContent itself is (re)built from
# $script:PpiDeclaredRows by Build-PpiDeclaredContent below, once with an
# empty elide-set (tier two's own "as if elision never existed" version)
# and, only if tier one's own loop leaves the bundle still over cap, again
# with one more RelPath added each time -- largest tier-two candidate
# first, exactly mirroring Build-PpiStep3Content's shape for tier one.
$script:PpiDeclaredRows = New-Object System.Collections.Generic.List[object]
$script:PpiDeclaredElidableIndex = @()
$script:PpiDeclaredContent = ""

# ── Declared-outputs completeness check (REQ-003/AC-014..017/AC-032) ────────
# Security Boundary B1 (security-spec.md): verifies every path the
# implementation report's own "## Outputs" table declares is present, with
# a matching SHA-256, under the --input root OR the --project-root, BEFORE
# sanitization/digest computation ever runs — a completeness gap means no
# digest line can ever print (a structural property: the sanitize/write/
# print code below is simply never reached on a gap, not a conditional
# guard around it).
#
# Native re-implementation of the same "## Outputs" heading + "| `path` |
# `hash` |" row shape validate-review-context-set.sh:63-74's
# evaluator_output_is_declared already establishes, applied in the OPPOSITE
# direction: instead of checking one caller-supplied path against the
# table, this iterates every row and containment-checks each declared path
# against a candidate root FIRST — reusing that same site's
# path_is_authorized containment discipline — a path that would resolve
# outside the root being tried is never read (never opened, never hashed),
# before existence/hash is verified for paths that pass containment. Real
# implementation reports declare rows relative to project_root (the same
# convention generate-evidence-bundle/check-evidence-bundle use); this
# script's own pre-existing fixtures declare rows relative to InputRoot.
# Both are tried — InputRoot first (preserving today's exact behavior for
# existing callers), ProjectRoot only on a miss — and whichever root
# actually resolves a row must independently pass containment under that
# root; a row never escapes the root it resolved under.
#
# Convention, not a new flag (Breaking API: no — CLI flags are unchanged):
# the implementation report path is derived from --task/--feature/
# --project-root as reports/implementation/<feature>/<task_id>.md, the same
# convention validate-review-context-set.sh:267-282 already uses to locate
# an sdd-evaluator's implementation report. If no report exists at that
# conventional path, there is no declared-outputs table to check against —
# the completeness check is a no-op (preserves BL-007/BL-008/BL-009 for
# every caller that predates this convention, e.g. this script's own
# existing test fixtures).
#
# Declaration-commit check (staleness of shared, living files): a row that
# is absent, or hash-mismatched, under ProjectRoot after both roots have
# been tried is not necessarily a lie -- CHANGELOG.md and a feature's own
# tasks.md are declared as whole-file hashes but are shared files every
# sibling task edits after this report was written, so an accurate
# declaration goes stale the moment the next task commits. Rather than
# recording a commit in the report schema, the "declaration commit" (the
# commit that last modified the implementation report ITSELF) is derived
# with git and the row is re-checked against the tree as of that commit --
# same pattern, same rationale as check-workflow-state.ps1's
# Get-PluginsPinCommit/Get-PluginsHashAtPin for plugins/ reference docs.
# Only rows that resolved (or were validly attempted, never escaped) under
# ProjectRoot qualify: that root IS the repo root git commands run from, so
# rowPath is already a repository-relative git-show argument with no
# translation. A row that only matched under InputRoot has no such form and
# is never retried this way -- see Invoke-DeclaredOutputsCompletenessCheck.
# Every acceptance via this path prints a distinct stderr notice (never
# silent).
#
# This check decides ONE thing only: whether the row was ever true (was the
# declaration accurate as of the commit that wrote it), which keeps the
# build failing exactly as before for a row satisfiable by neither the
# worktree nor the declaration commit. It must never become a way for a
# check to quietly stop verifying content it claims to verify -- and, as of
# the fix below, it must never become a way for a REVIEW BUNDLE to carry
# historical bytes as if they were current ones either. A row accepted
# through this path is content-wise handled by Add-PpiDeclaredOutputContent
# as "StaleHash" (worktree file exists, gets served, hash mismatch is
# called out in-bundle) or "Missing" (no worktree file at all, no content
# to serve, called out in-bundle) -- never by reading the declaration-
# commit blob into the bundle.

$script:PpiDeclCommitChecked = $false
$script:PpiDeclCommit = $null

# Parse a report's ## Outputs section into the same record shape the sh twin's
# _ppi_extract_declared_output_rows emits: "ROW<TAB>path<TAB>hash" for a data
# row, "UNPARSEABLE<TAB>line" for a line that begins like one and is not.
#
# One parser, two consumers: the completeness check below and the WFI-058
# anchor scan. Keeping them on one function is the point -- an anchor computed
# from a different row set than the authorization boundary reads would drift
# silently the first time either copy of the regex was touched.
function Get-PpiDeclaredOutputRows {
    param([string[]]$Lines)

    $records = New-Object System.Collections.Generic.List[string]
    $inOutputs = $false
    foreach ($rawLine in $Lines) {
        $line = ([string]$rawLine).TrimEnd("`r")
        if ($line -eq "## Outputs") { $inOutputs = $true; continue }
        if ($line -match "^## ") {
            if ($inOutputs) { break }
            continue
        }
        if (-not $inOutputs) { continue }

        # Neither cell boundary is anchored tight against the backtick that
        # closes it: real annotated rows put the free text in either
        # position -- AFTER the hash, still inside that same cell, e.g.
        # "| `path` | `hash` (drifted -- extended by `sha1` ...) |"
        # (epic-193 T-004, caught by a panelist), or BETWEEN the path and
        # the column separator, e.g. "| `path` (added) | `hash` |"
        # (epic-195 T-005, found by running this exact fix against all
        # seven real corpus bundles, not reasoning from the shape in
        # isolation). "[^|]*" between the two captures tolerates the
        # second case; requiring a full "\|\s*$" at either boundary -- the
        # sh twin's old exact-backtick-count parser's, and this regex's own
        # first draft -- rejected one or the other for the same reason: an
        # annotation breaking a strict "nothing else in this cell"
        # assumption.
        $m = [regex]::Match($line, '^\| `([^`]*)`[^|]*\| `([^`]*)`')
        if (-not $m.Success) {
            # A line that begins like a data row ("| `") but does not fully
            # match is never silently dropped -- the header row, the `---`
            # separator row, blank lines, and stray prose never begin that
            # way, so this cannot mistake ordinary table furniture for a
            # failed parse. Nothing about this row's declared path/hash is
            # known, so there is nothing to check completeness against --
            # unlike a verified-absent row (declaration-commit fallback
            # below), NOTHING was checked here at all, which this project
            # treats as a strictly worse gap, not a milder one. Fails the
            # build exactly like every other gap kind -- never silently
            # skipped.
            if ($line -match '^\| `') {
                $records.Add("UNPARSEABLE`t" + ($line -replace "`t", " "))
            }
            continue
        }
        $records.Add("ROW`t" + $m.Groups[1].Value + "`t" + $m.Groups[2].Value)
    }
    return $records.ToArray()
}

# Fingerprint of a report's ## Outputs section, used to decide WHEN that
# section last changed. Row extraction is reused verbatim so the fingerprint
# tracks exactly the rows the authorization boundary reads -- reflowed prose
# or an edited heading elsewhere in the report does not move the anchor.
function Get-PpiOutputsFingerprint {
    param([string[]]$Lines)

    $joined = (@(Get-PpiDeclaredOutputRows -Lines $Lines) -join "`n")
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($joined)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLower()
    } finally {
        $sha.Dispose()
    }
}

# Lazily derive & cache the declaration commit. Computed at most once per
# invocation (a report with no git history, or no git binary at all, still
# only pays for one failed lookup, not one per row that needs it).
function Get-PpiDeclarationCommit {
    param([string]$ProjectRoot, [string]$Feature, [string]$TaskId)

    if ($script:PpiDeclCommitChecked) { return $script:PpiDeclCommit }
    $script:PpiDeclCommitChecked = $true
    $script:PpiDeclCommit = $null

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    & git -C $ProjectRoot rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) { return $null }

    $reportRelPath = "reports/implementation/$Feature/$TaskId.md"
    $reportAbsPath = Join-Path $ProjectRoot (Join-Path "reports" (Join-Path "implementation" (Join-Path $Feature "$TaskId.md")))

    # WFI-058: anchor to the last commit that changed the report's ## Outputs
    # SECTION, not the last commit that touched the report FILE. The two are
    # the same event only until something edits the report for an unrelated
    # reason -- a machine-readable header line, an addendum, a status word --
    # after the declared outputs have legitimately drifted. When that happens
    # the file-anchored lookup lands PAST the drift, every previously
    # tolerated row stops verifying, and bundle preparation fail-closes on a
    # tree that was fine the day before. Measured on epic-194: commit
    # 8456b861 added "- Task ID:" header lines to three reports whose Outputs
    # rows had already drifted through the owner-approved apply chain, and
    # the next bundle build refused with nine hash mismatches.
    #
    # Walk the report's own history newest-first and keep the OLDEST
    # consecutive commit whose Outputs section still equals the current one:
    # that is where this section's content was introduced, and it is the tree
    # state the declared hashes were written against.
    #
    # The historical blob is compared as PARSED ROWS, not as bytes, so the
    # encoding drift that "git show" through the PowerShell pipeline can
    # introduce cannot move the anchor. The hash comparison itself still goes
    # through the byte-exact temp-file path in
    # Test-DeclaredOutputAtDeclarationCommit below.
    $anchor = $null
    if (Test-Path -LiteralPath $reportAbsPath) {
        $currentFp = Get-PpiOutputsFingerprint -Lines (Get-Content -Encoding Utf8 -LiteralPath $reportAbsPath)
        foreach ($commit in @(& git -C $ProjectRoot log --format='%H' -- $reportRelPath 2>$null)) {
            $commitId = ([string]$commit).Trim()
            if (-not $commitId) { continue }
            $blob = @(& git -C $ProjectRoot show "${commitId}:${reportRelPath}" 2>$null)
            if ($LASTEXITCODE -ne 0) { break }
            if ((Get-PpiOutputsFingerprint -Lines $blob) -ne $currentFp) { break }
            $anchor = $commitId
        }
    }

    # No commit carries the current section (the table itself is edited but
    # uncommitted): keep the historical file anchor rather than losing the
    # fallback entirely. A wrong anchor still cannot admit anything -- the row
    # is re-hashed against that commit's tree either way.
    if (-not $anchor) {
        $fallback = & git -C $ProjectRoot log -1 --format='%H' -- $reportRelPath 2>$null
        if ($LASTEXITCODE -eq 0 -and $fallback) { $anchor = ([string]$fallback).Trim() }
    }
    if (-not $anchor) { return $null }

    $script:PpiDeclCommit = $anchor
    return $script:PpiDeclCommit
}

# Verify a declared-outputs row against the tree AS OF the declaration
# commit. Caller contract: RowPath must already be known project-root-
# relative (only called for rows resolved, or validly attempted and merely
# absent -- never escaped -- under ProjectRoot; see
# Invoke-DeclaredOutputsCompletenessCheck). Prints a distinct stderr notice
# and returns $true ONLY on a verified match -- never silently, per the
# WFI-017 regression this guards against (a strict matcher that skipped
# rows with no diagnostic and five files went missing from a manifest). Any
# other outcome (no declaration commit, path absent at that commit, content
# still mismatched) returns $false so the caller keeps the unchanged gap
# message.
function Test-DeclaredOutputAtDeclarationCommit {
    param([string]$ProjectRoot, [string]$Feature, [string]$TaskId, [string]$RowPath, [string]$RowHash)

    $commit = Get-PpiDeclarationCommit -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId
    if (-not $commit) { return $false }

    # Redirect the blob straight to a temp file and hash the file so the
    # comparison is byte-exact -- capturing external-command stdout through
    # the PowerShell pipeline can alter encoding or line endings, which
    # would corrupt the sha256 (same reasoning as check-workflow-state.ps1's
    # Get-PluginsHashAtPin).
    $tempFile = [IO.Path]::GetTempFileName()
    try {
        & git -C $ProjectRoot show "${commit}:${RowPath}" > $tempFile 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        $actualHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash.ToLower()
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
    if ($actualHash -ne $RowHash) { return $false }

    $shortCommit = $commit.Substring(0, [Math]::Min(7, $commit.Length))
    [Console]::Error.WriteLine("prepare-panelist-input: declared output verified at declaration commit ${shortCommit} (last ## Outputs change): ${RowPath} (drifted since)")
    return $true
}

# (Test-DeclaredOutputCanonicalPath and Resolve-DeclaredOutputRow now live
# earlier in this file, right after the --input existence check -- step 3b
# below, composed before this point in the script, needs them too. Both are
# used again here, unchanged, by Invoke-DeclaredOutputsCompletenessCheck
# below.)

# Record one declared-outputs row into $script:PpiDeclaredRows (and, when
# it carries real content, into $script:PpiDeclaredElidableIndex -- tier
# two's own elidable candidate set). Invoke-DeclaredOutputsCompletenessCheck
# decides only whether the row was ever true (build-gate job, unchanged);
# this function decides what a reviewer actually reads, and it reads from
# the worktree candidate whenever one exists -- NEVER the declaration-
# commit blob, which would hand a panelist code that no longer exists in
# the tree it is asked to review. This function itself no longer builds
# $script:PpiDeclaredContent -- Build-PpiDeclaredContent does, from the
# rows recorded here, so tier two's own budget loop can rebuild it more
# than once, exactly as Build-PpiStep3Content already does for tier one.
# Skips a row already pulled in by the spec-document/task-verification/
# implementation-report composition above (see $script:PpiSeenRelPaths) --
# comparison is only meaningful for project-root-relative rows
# (ProjectRelative = $true); a row that only matched under --input has no
# comparable identity in that set and is never deduplicated. -Staleness
# selects which case this call is:
#   ""          a normal match -- the declared hash was verified directly
#               against the worktree candidate. No notice needed.
#   "StaleHash" the worktree candidate exists but its hash no longer
#               matches the declared one (only the declaration-commit blob
#               matched it, via Test-DeclaredOutputAtDeclarationCommit).
#               Served content is still $Candidate -- the CURRENT worktree
#               bytes -- plus an in-bundle notice that the report's
#               declared hash for this path is stale, so the reviewer
#               knows both what the code is now and that the report
#               describing it is out of date. Both notices (stale-hash and
#               elided) can land on the same row -- see
#               Build-PpiDeclaredContent, which prints the staleness
#               header once and independently decides whether the BODY
#               that follows it is whole or elided; the two never share a
#               line, so eliding one never overwrites the other.
#   "Missing"   no worktree candidate exists at all -- the row matched only
#               at the declaration commit. There is no current content to
#               serve; falling back to the declaration-commit blob here
#               would silently hand the reviewer a file that has been
#               deleted. Instead this appends only a notice, and -- having
#               no candidate -- is never a tier-two elision candidate.
function Add-PpiDeclaredOutputContent {
    param(
        [string]$RowPath,
        [string]$Candidate,
        [bool]$ProjectRelative,
        [string]$ProjectRoot,
        [string]$Feature,
        [string]$TaskId,
        [string]$Staleness = ""
    )

    if ($ProjectRelative -and $script:PpiSeenRelPaths.Contains($RowPath)) {
        return
    }

    $script:PpiDeclaredRows.Add([PSCustomObject]@{
        RowPath   = $RowPath
        Candidate = $Candidate
        Staleness = $Staleness
    }) | Out-Null

    if ($Candidate) {
        $bytes = [System.Text.Encoding]::UTF8.GetByteCount((Get-Content -Raw -Encoding Utf8 -LiteralPath $Candidate))
        $script:PpiDeclaredElidableIndex += [PSCustomObject]@{ Bytes = $bytes; AbsPath = $Candidate; RelPath = $RowPath }
    }

    if ($ProjectRelative) { $script:PpiSeenRelPaths.Add($RowPath) | Out-Null }
}

# Rebuilds $script:PpiDeclaredContent from scratch from
# $script:PpiDeclaredRows, given the set of RelPaths ($ElideSet) that
# should be elided THIS attempt -- mirrors Build-PpiStep3Content's shape
# exactly, one tier over. A row with no worktree Candidate ("Missing") is
# never in $ElideSet (it has no $script:PpiDeclaredElidableIndex entry to
# be sorted into) and always renders its own fixed notice body. Every
# other row renders its staleness header (if any) followed by either its
# whole content or, when its RowPath is in $ElideSet,
# Get-PpiElidedContent's head/tail/marker body -- the SAME function tier
# one uses, so the marker text and byte-accounting are identical between
# tiers.
function Build-PpiDeclaredContent {
    param([string[]]$ElideSet)
    $content = ""
    foreach ($row in $script:PpiDeclaredRows) {
        switch ($row.Staleness) {
            "StaleHash" {
                $header = "# ---- $($row.RowPath) (declared output — CURRENT worktree content; implementation report's declared hash for this path is STALE, the file has changed since the report was written) ----"
            }
            "Missing" {
                $commit = Get-PpiDeclarationCommit -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId
                $header = "# ---- $($row.RowPath) (declared output — MISSING from the worktree; implementation report's declaration for this path is STALE, it matched only at declaration commit $commit, the path no longer exists in the current tree) ----"
            }
            default {
                $header = "# ---- $($row.RowPath) (declared output) ----"
            }
        }

        if (-not $row.Candidate) {
            $content += "$header`n[no current content: this declared output does not exist in the worktree]`n"
        } elseif ($ElideSet -contains $row.RowPath) {
            $body = Get-PpiElidedContent -FilePath $row.Candidate -Label $row.RowPath
            $content += "$header`n$body`n"
        } else {
            $body = Get-Content -Raw -Encoding Utf8 -LiteralPath $row.Candidate
            $content += "$header`n$body`n"
        }
    }
    return $content
}

function Invoke-DeclaredOutputsCompletenessCheck {
    param([string]$ProjectRoot, [string]$Feature, [string]$TaskId, [string]$InputRoot)

    $implReportPath = Join-Path $ProjectRoot (Join-Path "reports" (Join-Path "implementation" (Join-Path $Feature "$TaskId.md")))
    if (-not (Test-Path -LiteralPath $implReportPath)) { return }

    $gaps = New-Object System.Collections.Generic.List[string]
    foreach ($record in @(Get-PpiDeclaredOutputRows -Lines (Get-Content -Encoding Utf8 $implReportPath))) {
        $fields = $record -split "`t", 3
        if ($fields[0] -eq "UNPARSEABLE") {
            $gaps.Add("declared output row could not be parsed: " + $fields[1])
            continue
        }
        $rowPath = $fields[1]
        $rowHash = ([string]$fields[2]).ToLower()
        if ([string]::IsNullOrEmpty($rowPath)) { continue }

        if (-not (Test-DeclaredOutputCanonicalPath $rowPath)) {
            $gaps.Add("declared output resolves outside input root: $rowPath")
            continue
        }

        # Try InputRoot first (unchanged default behavior); only on a miss
        # there, retry under ProjectRoot.
        $inputResult = Resolve-DeclaredOutputRow -RowPath $rowPath -Root $InputRoot
        $escapedUnderInput = ($inputResult.State -eq "Escaped")

        $rowIsProjectRelative = $false
        if ($inputResult.State -eq "Matched") {
            $candidate = $inputResult.Candidate
        } else {
            $projectResult = Resolve-DeclaredOutputRow -RowPath $rowPath -Root $ProjectRoot

            if ($projectResult.State -eq "Matched") {
                $candidate = $projectResult.Candidate
                $rowIsProjectRelative = $true
            } elseif ($escapedUnderInput -or ($projectResult.State -eq "Escaped")) {
                $gaps.Add("declared output resolves outside input root: $rowPath")
                continue
            } else {
                # Absent under both roots. rowPath already passed the
                # canonical-path check above and did not escape under
                # ProjectRoot (only "absent" -- never attempted-and-
                # escaped), so it is a valid repository-relative path to
                # re-check against the declaration commit before giving up
                # (see Test-DeclaredOutputAtDeclarationCommit).
                if (Test-DeclaredOutputAtDeclarationCommit -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId -RowPath $rowPath -RowHash $rowHash) {
                    Add-PpiDeclaredOutputContent -RowPath $rowPath -Candidate $null -ProjectRelative $true `
                        -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId -Staleness "Missing"
                    continue
                }
                $gaps.Add("declared output missing from bundle: $rowPath")
                continue
            }
        }

        $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $rowHash) {
            if ($rowIsProjectRelative -and
                (Test-DeclaredOutputAtDeclarationCommit -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId -RowPath $rowPath -RowHash $rowHash)) {
                Add-PpiDeclaredOutputContent -RowPath $rowPath -Candidate $candidate -ProjectRelative $true `
                    -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId -Staleness "StaleHash"
                continue
            }
            $gaps.Add("declared output hash mismatch: $rowPath")
        } else {
            Add-PpiDeclaredOutputContent -RowPath $rowPath -Candidate $candidate -ProjectRelative $rowIsProjectRelative `
                -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId
        }
    }

    if ($gaps.Count -gt 0) {
        foreach ($g in $gaps) {
            [Console]::Error.WriteLine("prepare-panelist-input: $g")
        }
        exit 1
    }
}

Invoke-DeclaredOutputsCompletenessCheck -ProjectRoot $ProjectRoot -Feature $Feature -TaskId $TaskId -InputRoot $InputPath

# ── Sanitize content ─────────────────────────────────────────────────────────
# Secret patterns (reusing check-ph patterns + common key detection):
#  1. Credential assignment lines (KEY=value)
#  2. AWS Access Key IDs (AKIA...)
#  3. GitHub/GitLab PATs (ghp_, ghs_, gho_, glpat-)
#  4. sk-prefixed tokens (OpenAI etc.)
#  5. Long random secrets on KEY= lines (catch-all)
#  6. Absolute Unix paths (/home, /Users, /root, /var, /etc, /usr, /opt, /tmp)
#  7. Windows absolute paths (C:\...)
#  8. Private/RFC-1918 IP URLs
#  9. Internal/corp hostnames in URLs
#
# Wrapped as a function because the budget-driven size guard below may
# need to sanitize more than one candidate bundle (once per elision
# attempt). Sets $script:PpiSanitizedDigest / $script:PpiSanitizedContent.

$REDACTED      = "[REDACTED]"
$PATH_REDACTED = "[PATH_REDACTED]"
$URL_REDACTED  = "[URL_REDACTED]"

function Invoke-PpiSanitize {
    param([string]$Raw)
    $text = $Raw

    # 1. Credential assignment lines
    $text = [regex]::Replace($text,
        '(?im)^[^\n=]*(?:api[_-]?key|secret[_-]?(?:access[_-]?)?key|access[_-]?key(?:[_-]?id)?|auth[_-]?token|bearer|password|passwd|credential|private[_-]?(?:key|token)|token)[^\n=]*=[^\n]+',
        { param($m)
            $lhs = ($m.Value -split '=')[0]
            "$lhs=$REDACTED"
        })

    # 2. AWS Access Key IDs
    $text = [regex]::Replace($text, 'AKIA[0-9A-Z]{16}', $REDACTED)

    # 3. GitHub/GitLab PATs
    $text = [regex]::Replace($text, '(?:ghp_|ghs_|gho_|glpat-)[A-Za-z0-9_\-]{20,}', $REDACTED)

    # 4. sk- prefixed tokens
    $text = [regex]::Replace($text, 'sk-[A-Za-z0-9_\-]{20,}', $REDACTED)

    # 5. Long random secrets on KEY= lines (catch-all >= 32 chars)
    $text = [regex]::Replace($text,
        '(?im)((?:key|token|secret|password|passwd|credential)[^\n=]*=\s*)[A-Za-z0-9+/=]{32,}',
        { param($m) "$($m.Groups[1].Value)$REDACTED" })

    # 6. Absolute Unix paths
    $text = [regex]::Replace($text,
        '/(?:home|root|Users|var|etc|usr|opt|tmp|private)/[^\s\''"\)\]]*',
        $PATH_REDACTED)

    # 7. Windows absolute paths
    $text = [regex]::Replace($text,
        '[A-Za-z]:\\[^\s\''"\)\]]*',
        $PATH_REDACTED)

    # 8. Private/RFC-1918 IP URLs
    $text = [regex]::Replace($text,
        'https?://(?:192\.168\.\d{1,3}|10\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.\d{1,3})(?::\d+)?[^\s\''"\)\]]*',
        $URL_REDACTED)

    # 9. Internal/corp hostnames in URLs
    $text = [regex]::Replace($text,
        'https?://[^\s\''"\)\]]*(?:internal|corp|intranet|private)[^\s\''"\)\]]*',
        $URL_REDACTED)

    $sha256    = [System.Security.Cryptography.SHA256]::Create()
    $msgBytes  = [System.Text.Encoding]::UTF8.GetBytes($text)
    $hashBytes = $sha256.ComputeHash($msgBytes)
    $script:PpiSanitizedDigest  = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
    $script:PpiSanitizedContent = $text
}

# Builds the exact bundle bytes header + sanitized content would occupy on
# disk from the current $script:PpiSanitizedDigest/$script:PpiSanitizedContent.
function Get-PpiBundlePreview {
    return @"
# Panelist Input Bundle
# task_id: $TaskId
# feature: $Feature
# input_digest: $($script:PpiSanitizedDigest)
# consent: $ConsentKind
# WARNING: This file is sanitized for external LLM review.
#          Do not include secrets, absolute paths, or private URLs.

$($script:PpiSanitizedContent)
"@
}

# ── Size guard (fail-closed, --max-bytes only) -- two-tier budget-driven
# elision ─────────────────────────────────────────────────────────────────
# Compose the bundle whole (empty elide-sets, both tiers) and measure it --
# the exact bytes that would be written and sent to a panelist, not an
# approximation. A bundle that already fits never touches either tier's
# build function again after this first call, so it is byte-for-byte what
# it would be with no elision logic in this script at all.

$elideSet = @()
$step3Content = Build-PpiStep3Content -ElideSet $elideSet
$declaredElideSet = @()
$script:PpiDeclaredContent = Build-PpiDeclaredContent -ElideSet $declaredElideSet
Invoke-PpiSanitize -Raw "$($script:PpiContentPrefix)$step3Content$($script:PpiContentSuffix)$($script:PpiDeclaredContent)"
$bundle = Get-PpiBundlePreview
$bundleBytes = [System.Text.Encoding]::UTF8.GetByteCount($bundle)

$elidedCount = 0
$declaredElidedCount = 0
if ($MaxBytes) {
    $maxBytesInt = [long]$MaxBytes

    if ($bundleBytes -gt $maxBytesInt) {
        # Tier one: the task's own verification/<task_id>/ evidence plus
        # contract-declared evidence. Elide candidates one at a time,
        # LARGEST FIRST, recomputing the actual sanitized bundle size
        # after each (never estimated), stopping the moment it fits.
        $sortedCandidates = $script:PpiElidableIndex | Sort-Object -Property Bytes -Descending
        foreach ($cand in $sortedCandidates) {
            $elideSet += $cand.RelPath
            $elidedCount++
            $step3Content = Build-PpiStep3Content -ElideSet $elideSet
            Invoke-PpiSanitize -Raw "$($script:PpiContentPrefix)$step3Content$($script:PpiContentSuffix)$($script:PpiDeclaredContent)"
            $bundle = Get-PpiBundlePreview
            $bundleBytes = [System.Text.Encoding]::UTF8.GetByteCount($bundle)
            if ($bundleBytes -le $maxBytesInt) { break }
        }

        # Tier two: declared-outputs rows -- the source under review.
        # Reached ONLY when tier one's own loop above (every candidate
        # offered a chance to help, stopping early the moment it was
        # enough) still leaves the bundle over cap. Same largest-first,
        # re-measure-after-each, stop-the-moment-it-fits shape as tier
        # one, over $script:PpiDeclaredElidableIndex instead -- see the
        # file header and the "Scope, two tiers" comment above
        # $script:PpiElideLines for why this tier exists and why it is
        # never tried first.
        if ($bundleBytes -gt $maxBytesInt) {
            $sortedDeclaredCandidates = $script:PpiDeclaredElidableIndex | Sort-Object -Property Bytes -Descending
            foreach ($dcand in $sortedDeclaredCandidates) {
                $declaredElideSet += $dcand.RelPath
                $declaredElidedCount++
                $script:PpiDeclaredContent = Build-PpiDeclaredContent -ElideSet $declaredElideSet
                Invoke-PpiSanitize -Raw "$($script:PpiContentPrefix)$step3Content$($script:PpiContentSuffix)$($script:PpiDeclaredContent)"
                $bundle = Get-PpiBundlePreview
                $bundleBytes = [System.Text.Encoding]::UTF8.GetByteCount($bundle)
                if ($bundleBytes -le $maxBytesInt) { break }
            }
        }

        if ($bundleBytes -gt $maxBytesInt) {
            # Exhausted every elidable candidate in BOTH tiers (or there
            # were none) and the bundle is still over cap -- the
            # degenerate case where even every elidable file's own
            # head/tail/marker floor, summed with the content that is
            # never elided, still exceeds --max-bytes. No further elision
            # is possible; refusing to write is the only honest outcome,
            # identical in shape to the no-elidable-candidates case this
            # replaces.
            $rawContentBytes = [System.Text.Encoding]::UTF8.GetByteCount("$($script:PpiContentPrefix)$step3Content$($script:PpiContentSuffix)")
            $declaredContentBytes = [System.Text.Encoding]::UTF8.GetByteCount($script:PpiDeclaredContent)
            [Console]::Error.WriteLine("prepare-panelist-input: sanitized bundle exceeds --max-bytes for ${Feature}/${TaskId} even after eliding $elidedCount task-evidence file(s) and $declaredElidedCount declared-output file(s) (${bundleBytes} > ${maxBytesInt} bytes) — refusing to write a silently-truncated bundle.")
            [Console]::Error.WriteLine("  spec documents + task verification + implementation report: ${rawContentBytes} bytes")
            [Console]::Error.WriteLine("  of which declared-outputs content:                          ${declaredContentBytes} bytes")
            [Console]::Error.WriteLine("  sanitized bundle (header + content) that would have been written: ${bundleBytes} bytes")
            [Console]::Error.WriteLine("Every elidable verification-directory file and every elidable declared-output file is already cut to its head/tail; reduce input size further (e.g. split the report itself) and retry, or omit --max-bytes to bypass the guard.")
            exit 1
        }
    }
}

$inputDigest = $script:PpiSanitizedDigest

# ── Write output bundle ──────────────────────────────────────────────────────

$outDir = Split-Path -Parent $OutPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

Set-Content -Encoding Utf8 -Path $OutPath -Value $bundle -NoNewline
Add-Content -Encoding Utf8 -Path $OutPath -Value ""

# ── Emit digest (and threaded effort, if supplied) to stdout ────────────────
# AC-036: --effort is threaded through verbatim on a second stdout line, so
# the caller can lift it into `run-panelist-gpt --effort <e>` in its own
# next step. Omitted entirely preserves today's exact single-line output.

Write-Host $inputDigest
if ($Effort) {
    Write-Host "effort=$Effort"
}
exit 0
