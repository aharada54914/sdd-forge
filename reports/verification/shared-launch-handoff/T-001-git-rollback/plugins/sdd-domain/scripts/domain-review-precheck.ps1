# Usage: domain-review-precheck.ps1 -Attempt <n> -Round <n> [-EditSummary <text>] [-Reset]
# Full-parity PowerShell port of domain-review-precheck.sh (Issue #147,
# epic-159-pillar-a2 T-003). Validates a domain-review transition before any
# reviewer receives input or evidence is written. The orchestrating skill
# owns reviewer invocation and status mutation; this script owns
# deterministic preconditions, provenance, and AC-014 post-approval drift
# detection (specs/sdd-domain/requirements.md:120 -- not this feature's
# AC-014). tests/lib/loop-driver.ps1 invokes this script positionally
# (attempt round [--edit-summary=<text>]), so -EditSummary also accepts the
# raw --edit-summary=<text> token and strips the prefix itself, mirroring
# domain-review-precheck.sh's own argv parsing loop.

param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Attempt,
  [Parameter(Mandatory = $true, Position = 1)][string]$Round,
  [Parameter(Position = 2)][string]$EditSummary = '',
  [switch]$Reset
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  [Console]::Error.WriteLine("ERROR: domain-review-precheck: $Message")
  exit 1
}

function Test-OrdinalEqual([object]$Left, [object]$Right) {
  return [string]::Equals([string]$Left, [string]$Right, [StringComparison]::Ordinal)
}

function Get-Sha256File([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-Sha256Text([string]$Text) {
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))
  ).ToLower()
}

function Test-IsSymlink([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if ($null -eq $item) { return $false }
  return [bool]$item.LinkType
}

function Test-RealDirectory([string]$Path) {
  return (Test-Path -LiteralPath $Path -PathType Container) -and -not (Test-IsSymlink $Path)
}

function Get-CanonicalDir([string]$Path) {
  return (Resolve-Path -LiteralPath $Path).Path
}

# --- Argument normalization (mirrors domain-review-precheck.sh's argv loop) -
if ($EditSummary -cmatch '^--edit-summary=(.*)$') { $EditSummary = $Matches[1] }
if (Test-OrdinalEqual $EditSummary '--reset') { $EditSummary = ''; $Reset = $true }

if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
$attemptInt = [int64]$Attempt
$roundInt = [int64]$Round
if ($roundInt -gt 3) { Fail 'round must be between 1 and 3' }
if (-not ([string]::IsNullOrEmpty($EditSummary)) -and $roundInt -le 1) { Fail '--edit-summary is valid only after round 1' }
if ($roundInt -gt 1) {
  if ([string]::IsNullOrEmpty(($EditSummary -replace '\s', ''))) { Fail 'rounds 2 and 3 require a non-empty --edit-summary' }
}
if ($Reset) {
  if (-not ($attemptInt -gt 1 -and $roundInt -eq 1)) { Fail '--reset starts only attempt N+1 round 1' }
} else {
  if (-not ($attemptInt -eq 1 -or $roundInt -gt 1)) { Fail 'a new attempt requires --reset' }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$domainDir = Join-Path $root 'domain'
$reportsRoot = Join-Path $root 'reports'
$reportsBase = Join-Path $reportsRoot 'domain-review'
$contextMap = Join-Path $domainDir 'context-map.md'
$calibration = Join-Path $root 'plugins/sdd-domain/references/domain-review-calibration.md'
$domainContract = Join-Path $domainDir 'domain-contract.json'
$reportDir = Join-Path $reportsBase (Join-Path "attempt-$attemptInt" "round-$roundInt")
$fingerprintPath = Join-Path $reportsBase 'last-approved-fingerprint.json'

function Get-RelativeToRoot([string]$Path) {
  $rel = $Path
  if ($rel.StartsWith($root, [StringComparison]::Ordinal)) {
    $rel = $rel.Substring($root.Length).TrimStart('\', '/')
  }
  return $rel.Replace('\', '/')
}

# Canonical domain/ artifact set (the sdd-domain feature's own AC-002 seven
# Markdown paths plus the machine-readable contract). Aggregates are
# variadic (one per aggregate); every *.md file directly under
# domain/aggregates/ is included.
$canonicalPaths = @(
  (Join-Path $domainDir 'domain-story.md'),
  (Join-Path $domainDir 'event-storming.md'),
  (Join-Path $domainDir 'ubiquitous-language.md'),
  $contextMap,
  (Join-Path $domainDir 'message-flow.md'),
  (Join-Path $domainDir 'c4-container.md'),
  $domainContract
)

if (-not (Test-RealDirectory $root)) { Fail 'repository root must be a real directory' }
if (-not (Test-RealDirectory $domainDir)) { Fail 'domain/ directory must exist and not be a symlink' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $domainDir) $domainDir)) { Fail 'domain/ directory escapes repository' }
foreach ($p in $canonicalPaths) {
  if (-not (Test-Path -LiteralPath $p -PathType Leaf) -or (Test-IsSymlink $p)) {
    Fail "missing canonical domain/ artifact: $(Get-RelativeToRoot $p)"
  }
}
$aggregatesDir = Join-Path $domainDir 'aggregates'
if (-not (Test-Path -LiteralPath $aggregatesDir -PathType Container) -or (Test-IsSymlink $aggregatesDir)) {
  Fail 'domain/aggregates/ must exist and not be a symlink'
}
$aggregateFiles = @(Get-ChildItem -LiteralPath $aggregatesDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -cmatch '\.md$' })
if ($aggregateFiles.Count -lt 1) { Fail 'domain/aggregates/ must contain at least one aggregate card' }
$aggregateFilePaths = @()
foreach ($f in $aggregateFiles) {
  if (Test-IsSymlink $f.FullName) { Fail "aggregate card is not a regular non-symlink file: $(Get-RelativeToRoot $f.FullName)" }
  $aggregateFilePaths += $f.FullName
}
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Test-IsSymlink $calibration)) {
  Fail 'domain review calibration reference must be a regular non-symlink file'
}
if (-not (Test-RealDirectory $reportsRoot)) { Fail 'reports root must be a real directory' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportsRoot) $reportsRoot)) { Fail 'reports root escapes repository' }
if (Test-Path -LiteralPath $reportsBase) {
  if (-not (Test-Path -LiteralPath $reportsBase -PathType Container) -or (Test-IsSymlink $reportsBase)) { Fail 'domain-review report base must not be a symlink' }
  if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportsBase) $reportsBase)) { Fail 'domain-review report base escapes reports root' }
}

$statusMatch = Select-String -LiteralPath $contextMap -Pattern '^Domain-Model-Status:\s*(.*)$' -CaseSensitive | Select-Object -First 1
$status = if ($statusMatch) { ($statusMatch.Matches[0].Groups[1].Value -replace '\s', '') } else { '' }
if ($status -cnotmatch '^(Pending|Reviewed|Approved)$') { Fail 'context-map.md must declare a recognized Domain-Model-Status' }

# --- Normalized-hash helper (mirrors spec-review-precheck.sh's pattern of
# substituting the mutable status field before hashing, applied here to
# Domain-Model-Status instead of Spec-Review-Status). ---
function Get-NormalizedHash([string]$Path) {
  if (Test-OrdinalEqual $Path $contextMap) {
    $content = [IO.File]::ReadAllText($Path)
    $normalized = [Text.RegularExpressions.Regex]::Replace(
      $content,
      '(?m)^Domain-Model-Status:[^\r\n]*(\r?)$',
      'Domain-Model-Status: NORMALIZED$1'
    )
    return (Get-Sha256Text $normalized)
  }
  return (Get-Sha256File $Path)
}

# --- AC-014 drift detection -------------------------------------------------
# This is a distinct precondition from the T-006 hook guard: the guard only
# rejects an agent-authored write of Approved; this step detects domain/
# content that changed after a human already approved it, and halts until
# the human resets the status field back to Pending.
#
# The hard-stop applies only while Domain-Model-Status is still Approved:
# once a human has reset the field (to Pending, or the loop has moved it to
# Reviewed), the model is no longer approved, the sanctioned re-review path
# is exactly what should run, and the stale fingerprint is removed so the
# next human Approval records a fresh one.
if ((Test-Path -LiteralPath $fingerprintPath -PathType Leaf) -and -not (Test-IsSymlink $fingerprintPath) -and -not (Test-OrdinalEqual $status 'Approved')) {
  Remove-Item -LiteralPath $fingerprintPath -Force
  [Console]::Error.WriteLine("domain-review-precheck: stale last-approved fingerprint cleared (Domain-Model-Status is $status, not Approved) -- re-review proceeds; the next human Approval records a fresh fingerprint")
}
if ((Test-Path -LiteralPath $fingerprintPath -PathType Leaf) -and -not (Test-IsSymlink $fingerprintPath)) {
  $fingerprint = $null
  try {
    $fingerprint = Get-Content -LiteralPath $fingerprintPath -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Fail 'last-approved-fingerprint.json is malformed'
  }
  $propNames = @($fingerprint.PSObject.Properties.Name | Sort-Object)
  $isValidFingerprint = ($propNames.Count -eq 2) -and (Test-OrdinalEqual $propNames[0] 'files') -and (Test-OrdinalEqual $propNames[1] 'schema') -and
    (Test-OrdinalEqual $fingerprint.schema 'domain-review-approved-fingerprint/v1') -and ($fingerprint.files -is [PSCustomObject])
  if (-not $isValidFingerprint) { Fail 'last-approved-fingerprint.json is malformed' }
  $driftPaths = [Collections.Generic.List[string]]::new()
  $allCurrentPaths = @($canonicalPaths) + @($aggregateFilePaths)
  foreach ($prop in $fingerprint.files.PSObject.Properties) {
    $relPath = $prop.Name
    $recordedHash = [string]$prop.Value
    $absPath = Join-Path $root $relPath
    if (-not (Test-Path -LiteralPath $absPath -PathType Leaf)) {
      $driftPaths.Add("$relPath (removed)")
      continue
    }
    $currentHash = Get-NormalizedHash $absPath
    if (-not (Test-OrdinalEqual $currentHash $recordedHash)) { $driftPaths.Add($relPath) }
  }
  foreach ($p in $allCurrentPaths) {
    $rel = Get-RelativeToRoot $p
    $hasEntry = $false
    foreach ($prop in $fingerprint.files.PSObject.Properties) {
      if (Test-OrdinalEqual $prop.Name $rel) { $hasEntry = $true; break }
    }
    if (-not $hasEntry) { $driftPaths.Add("$rel (added)") }
  }
  if ($driftPaths.Count -gt 0) {
    Fail "domain/ drift detected since last Domain-Model-Status: Approved (AC-014). Changed paths: $($driftPaths -join ','). A human must reset Domain-Model-Status back to Pending in domain/context-map.md before re-review can proceed."
  }
}

if ((Test-OrdinalEqual $status 'Approved') -and -not (Test-Path -LiteralPath $fingerprintPath -PathType Leaf)) {
  # First observation of an Approved model: record its fingerprint now, so a
  # future invocation can detect drift relative to this moment. This is the
  # only place this script writes the fingerprint file; a reviewed-but-not-
  # yet-approved model never reaches this branch.
  New-Item -ItemType Directory -Path $reportsBase -Force | Out-Null
  $filesMap = [ordered]@{}
  foreach ($p in (@($canonicalPaths) + @($aggregateFilePaths))) {
    $filesMap[(Get-RelativeToRoot $p)] = Get-NormalizedHash $p
  }
  $fingerprintObj = [ordered]@{ schema = 'domain-review-approved-fingerprint/v1'; files = $filesMap }
  $tmpFp = "$fingerprintPath.tmp.$PID"
  $fingerprintObj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $tmpFp -Encoding utf8NoBOM
  Move-Item -LiteralPath $tmpFp -Destination $fingerprintPath -Force
}

if (Test-OrdinalEqual $status 'Approved') {
  Fail 'Domain-Model-Status is Approved; domain-review-loop does not re-review an approved model unless domain/ drift was just detected above. If domain/ was intentionally changed, a human must reset Domain-Model-Status to Pending first.'
}

if ($Reset) {
  if (-not (Test-OrdinalEqual $status 'Pending')) { Fail 'context-map.md must declare a resettable Domain-Model-Status (Pending)' }
} else {
  if (-not (Test-OrdinalEqual $status 'Pending')) { Fail 'context-map.md must declare Domain-Model-Status: Pending' }
}
if (Test-IsSymlink $reportsBase) { Fail 'report base must not be a symlink' }
if (Test-Path -LiteralPath $reportDir) { Fail 'round destination already exists (replay is forbidden)' }

# --- Compute the composite input hash over the full canonical domain/ set --
$inputParts = @()
foreach ($p in (@($canonicalPaths) + @($aggregateFilePaths))) {
  $inputParts += (Get-NormalizedHash $p)
}
$inputSha = Get-Sha256Text ($inputParts -join ':')
$calibrationSha = Get-Sha256File $calibration

if ($roundInt -gt 1) {
  $priorDir = Join-Path $reportsBase (Join-Path "attempt-$attemptInt" "round-$($roundInt - 1)")
  $priorPrecheck = Join-Path $priorDir 'precheck-result.json'
  if (-not (Test-Path -LiteralPath $priorPrecheck -PathType Leaf)) { Fail 'prior round precheck result is required' }
  $priorData = Get-Content -LiteralPath $priorPrecheck -Raw | ConvertFrom-Json
  $priorInputSha = [string]$priorData.input_sha256
  if (Test-OrdinalEqual $inputSha $priorInputSha) { Fail 'reviewed domain/ artifacts are unchanged from the prior round' }
}

if ($Reset) {
  $previousAttempt = Join-Path $reportsBase "attempt-$($attemptInt - 1)"
  if (-not (Test-Path -LiteralPath $previousAttempt -PathType Container) -or (Test-IsSymlink $previousAttempt)) { Fail 'previous attempt is required before reset' }
  $roundDirs = @(Get-ChildItem -LiteralPath $previousAttempt -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -cmatch '^round-[1-3]$' })
  $previousRoundNumbers = @($roundDirs | ForEach-Object { [int]($_.Name -creplace '^round-', '') } | Sort-Object)
  if ($previousRoundNumbers.Count -eq 0) { Fail 'previous attempt has no terminal round' }
  $previousRound = $previousRoundNumbers[-1]
  $previousDir = Join-Path $previousAttempt "round-$previousRound"
  $previousContractPath = Join-Path $previousDir 'domain-review-contract.json'
  $previousVerdict = $null
  if (Test-Path -LiteralPath $previousContractPath -PathType Leaf) {
    try { $previousVerdict = (Get-Content -LiteralPath $previousContractPath -Raw | ConvertFrom-Json).verdict } catch { $previousVerdict = $null }
  }
  if (-not (Test-OrdinalEqual $previousVerdict 'PASS') -and -not (Test-OrdinalEqual $previousVerdict 'BLOCKED')) { Fail 'reset requires a terminal PASS or BLOCKED contract' }
}

New-Item -ItemType Directory -Path $reportsBase -Force | Out-Null
if ((Test-IsSymlink $reportsBase) -or -not (Test-OrdinalEqual (Get-CanonicalDir $reportsBase) $reportsBase)) { Fail 'domain-review report base escapes reports root' }
$lockDir = Join-Path $reportsBase '.domain-review.lock'
try {
  New-Item -ItemType Directory -Path $lockDir -ErrorAction Stop | Out-Null
} catch {
  Fail 'another domain review transition holds the lock'
}
if (Test-Path -LiteralPath $reportDir) {
  Remove-Item -LiteralPath $lockDir -Recurse -Force -ErrorAction SilentlyContinue
  Fail 'round destination already exists (replay is forbidden)'
}
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$generatedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$result = [ordered]@{
  schema = 'domain-review-precheck/v1'
  stage = 'domain'
  attempt = $attemptInt
  round = $roundInt
  domain_model_status_field = $status
  calibration_sha256 = $calibrationSha
  input_sha256 = $inputSha
  edit_summary = $EditSummary
  reset = [bool]$Reset
  generated_at = $generatedAt
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reportDir 'precheck-result.json') -Encoding utf8NoBOM
Remove-Item -LiteralPath $lockDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "domain-review-precheck: complete. Output written to $reportDir/"
