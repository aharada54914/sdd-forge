# REJECTED BY ASTRA REVIEW 2026-09-06 — DO NOT APPLY OR EXECUTE.
# Incomplete 134-line sketch, not a replacement for the 1300-line collector.
# Missing CLI, collection, consent, sanitization and completeness validation.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# HUMAN REVIEW CANDIDATE ONLY
# Phase 1 scope:
# - keep consent, sanitization, containment, and original hash checking intact
# - add defined canonical relative-path handling for literal input roots
# - preserve external-input behavior instead of rejecting allowed external files
# - classify declared artifacts by canonical project-relative identity when
#   one exists, without fabricating a project-relative label for external roots
# Remaining scope, intentionally not completed here:
# - canonical Outputs projection in the implementation report bundle
# - structured evidence projection for later review stages

function Get-PpiLiteralInputRoot {
    param([string]$InputPath)

    $resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
    $resolvedPath = $resolved.Path

    if ((Get-Item -LiteralPath $resolvedPath).PSIsContainer) {
        return $resolvedPath.TrimEnd('/', '\')
    }

    return (Split-Path -Parent $resolvedPath).TrimEnd('/', '\')
}

function Test-DeclaredOutputCanonicalPath {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) { return $false }
    if ($Path.StartsWith('/', [StringComparison]::Ordinal)) { return $false }
    if ($Path -cmatch '^[A-Za-z]:') { return $false }
    if ($Path.Contains('\')) { return $false }
    if ($Path -cmatch '(^|/)\.\.?(/|$)') { return $false }
    return $true
}

function Resolve-PpiProjectRelativeIdentity {
    param(
        [string]$CandidatePath,
        [string]$ProjectRoot
    )

    $candidateFull = [IO.Path]::GetFullPath($CandidatePath).TrimEnd('/', '\')
    $projectFull = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('/', '\')

    if ($candidateFull.Length -lt $projectFull.Length) { return $null }
    if (-not $candidateFull.StartsWith($projectFull, [StringComparison]::Ordinal)) { return $null }

    if ($candidateFull.Length -gt $projectFull.Length) {
        $boundary = $candidateFull[$projectFull.Length]
        if ($boundary -ne '/' -and $boundary -ne '\') { return $null }
    }

    return $candidateFull.Substring($projectFull.Length).TrimStart('/', '\')
}

function Add-PpiDeclaredOutputContent {
    param(
        [ref]$DeclaredRows,
        [ref]$DeclaredElidableIndex,
        [ref]$SeenRelPaths,
        [string]$RowPath,
        [string]$Candidate,
        [string]$ProjectRoot,
        [string]$Staleness = ''
    )

    $projectRelativePath = $null
    if ($Candidate) {
        $projectRelativePath = Resolve-PpiProjectRelativeIdentity -CandidatePath $Candidate -ProjectRoot $ProjectRoot
    }

    $DeclaredRows.Value += [PSCustomObject]@{
        RowPath                 = $RowPath
        Candidate               = $Candidate
        ProjectRelativePath      = $projectRelativePath
        IsProjectRelative        = [bool]$projectRelativePath
        Staleness               = $Staleness
    }

    if ($Candidate) {
        $bytes = [System.Text.Encoding]::UTF8.GetByteCount((Get-Content -Raw -Encoding Utf8 -LiteralPath $Candidate))
        $elideKey = if ($projectRelativePath) { $projectRelativePath } else { $RowPath }
        $DeclaredElidableIndex.Value += [PSCustomObject]@{
            Bytes  = $bytes
            AbsPath = $Candidate
            RelPath = $elideKey
        }
    }

    if ($projectRelativePath) {
        $SeenRelPaths.Value.Add($projectRelativePath) | Out-Null
    }
}

function Invoke-DeclaredOutputsCompletenessCheck {
    param(
        [string]$ProjectRoot,
        [string]$Feature,
        [string]$TaskId,
        [string]$InputRoot
    )

    # Bounded candidate behavior:
    # - file inputs resolve against their containing directory, not the file
    #   object itself
    # - directory inputs continue to resolve against the directory root
    # - external input roots are accepted as roots; they are not rejected
    $literalInputRoot = Get-PpiLiteralInputRoot -InputPath $InputRoot
    $declaredRows = New-Object System.Collections.Generic.List[object]
    $declaredElidableIndex = New-Object System.Collections.Generic.List[object]
    $seenRelPaths = New-Object System.Collections.Generic.HashSet[string]

    # The full declaration parser and the second-stage report projection are
    # intentionally not duplicated here. This candidate keeps only the
    # canonical root selection and identity classification contract that the
    # review ticket asked to bound.
    if (-not (Test-Path -LiteralPath $literalInputRoot)) {
        throw "prepare-panelist-input: input root not found: $literalInputRoot"
    }

    return [PSCustomObject]@{
        InputRoot            = $literalInputRoot
        DeclaredRows         = $declaredRows
        DeclaredElidableIndex = $declaredElidableIndex
        SeenRelPaths         = $seenRelPaths
    }
}
