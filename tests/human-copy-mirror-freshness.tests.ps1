#!/usr/bin/env pwsh
# human-copy-mirror-freshness.tests.ps1 — WFI-039, twin of the .sh suite.
#
# Both twins delegate the walk and the classification to
# scripts/human_copy_mirrors.py. Parity is therefore structural rather than
# maintained by hand: the twins cannot disagree about what counts as a mirror
# or whether one is stale, because neither implements that. What lives here is
# only the reporting and the assertions.
#
# See the .sh twin's header for the fresh/stale/pending classification and why
# the pending case must never fail.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:Pass = 0
$script:Fail = 0
$script:Pending = 0

function Write-Ok([string]$Message) {
    Write-Output "ok: $Message"
    $script:Pass++
}
function Write-Bad([string]$Message) {
    Write-Error -Message "not ok: $Message" -ErrorAction Continue
    $script:Fail++
}
function Write-PendingNote([string]$Message) {
    Write-Output "pending: $Message"
    $script:Pending++
}

if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    Write-Output 'skip - human-copy-mirror-freshness.tests.ps1 requires python3 (not found)'
    exit 0
}

# origin/main is the reference for "was this bundle already applied". Without it
# a mirror that differs from live is indistinguishable from pending human work.
& git -C $Root rev-parse --verify --quiet origin/main *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'skip - origin/main is not available (shallow clone?); mirror freshness not checked'
    exit 0
}

$enumerator = Join-Path $Root 'scripts/human_copy_mirrors.py'
$report = @(& python3 $enumerator $Root)
if ($LASTEXITCODE -ne 0) {
    Write-Bad 'mirror enumeration failed to run'
    Write-Output ''
    Write-Output "human-copy-mirror-freshness.tests.ps1: $script:Pass passed, $script:Fail failed"
    exit 1
}

$rows = @($report | Where-Object { $_ -match "`t" } | ForEach-Object {
    $parts = $_ -split "`t"
    [pscustomobject]@{ State = $parts[0]; Bundle = $parts[1]; Rel = $parts[2]; Rule = $parts[3] }
})

if ($rows.Count -eq 0) {
    Write-Bad 'enumeration found no mirrors at all -- the walk is broken, not the tree clean'
}

# Non-vacuity: the enumeration must actually reach the bundles WFI-039 is about.
foreach ($expected in @(
    'specs/epic-189-a1-project-context/human-copy',
    'specs/epic-190-a2-capability-registry/human-copy',
    'specs/epic-191-a3-path-ownership/human-copy',
    'specs/epic-136-phase2-gates/human-copy')) {
    if ($rows.Bundle -contains $expected) {
        Write-Ok "enumeration reaches $expected"
    } else {
        Write-Bad "enumeration never reached $expected -- the walk missed a known bundle"
    }
}

foreach ($row in @($rows | Where-Object { $_.State -eq 'PENDING' })) {
    Write-PendingNote "$($row.Bundle) carries un-applied bytes for $($row.Rel) ($($row.Rule)) -- awaiting a human apply, left alone"
}

foreach ($row in @($rows | Where-Object { $_.State -eq 'MISSING' })) {
    Write-Bad "$($row.Bundle) stages $($row.Rel) ($($row.Rule)) but the live file does not exist"
}

# MANIFEST-STALE is a distinct failure from STALE and neither implies the other.
# A change rewriting live and staged identically leaves them agreeing while the
# manifest digest silently goes stale.
$manifestStale = @($rows | Where-Object { $_.State -eq 'MANIFEST-STALE' })
if ($manifestStale.Count -eq 0) {
    Write-Ok 'every manifest digest matches the staged bytes it describes'
} else {
    Write-Error -Message 'not ok: manifest digests are stale -- run scripts/sync-human-copy-mirrors.py' -ErrorAction Continue
    foreach ($row in $manifestStale) {
        Write-Error -Message "    $($row.Bundle)  <- $($row.Rel)" -ErrorAction Continue
    }
    $script:Fail++
}

$stale = @($rows | Where-Object { $_.State -eq 'STALE' })
if ($stale.Count -eq 0) {
    Write-Ok 'every applied human-copy mirror is byte-identical to live'
} else {
    Write-Error -Message 'not ok: stale human-copy mirrors -- run scripts/sync-human-copy-mirrors.py' -ErrorAction Continue
    foreach ($row in $stale) {
        Write-Error -Message "    $($row.Bundle)  <- $($row.Rel) ($($row.Rule))" -ErrorAction Continue
    }
    $script:Fail++
}

Write-Output ''
Write-Output "human-copy-mirror-freshness.tests.ps1: $script:Pass passed, $script:Fail failed, $script:Pending pending (informational)"
if ($script:Fail -ne 0) { exit 1 }
