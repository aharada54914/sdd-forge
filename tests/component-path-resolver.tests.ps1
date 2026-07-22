# tests/component-path-resolver.tests.ps1 - PowerShell twin of
# tests/component-path-resolver.tests.sh (epic-191-a3-path-ownership T-001).
# See the bash twin for the full TEST-NNN / AC-NNN mapping and rationale.
# This twin drives resolve-component-paths.ps1 directly (the real product
# wrapper on this runtime — not a re-implementation/port), against the same
# static fixture tree at tests/fixtures/component-path-ownership/.
#
# resolve-component-paths.ps1 is always invoked here as a genuine SUBPROCESS
# (spawning the real pwsh executable via -File, mirroring tests/run-all.ps1's
# own `$powerShell = (Get-Process -Id $PID).Path` convention) rather than
# in-process via the `&` call operator. This is deliberate, not
# stylistic: the product script sets `$ErrorActionPreference = "Stop"` and
# reports diagnostics via `Write-Error` (so a real, separate-process
# invocation's stderr is capturable the same way any CLI tool's stderr is);
# calling it in-process instead would let that Stop-preference terminating
# error propagate through the `&` call boundary and abort this test script
# itself — confirmed while developing this suite (TEST-006 first RED
# attempt). A real subprocess sidesteps that whole class of PowerShell
# stream/scope semantics and matches how every real caller (the .sh
# dispatcher, `pwsh -File`) actually invokes this script.
#
# TEST-011.3 is DELIBERATELY, PERMANENTLY red on this suite too, until Epic
# A1 ships contracts/project-context.template.yaml — see the bash twin's
# header comment and tasks.md's T-001 Blockers note. Never silence it.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1"
$fixtures = Join-Path $repoRoot "tests/fixtures/component-path-ownership"
$powerShell = (Get-Process -Id $PID).Path

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

function Invoke-ResolverRaw {
    # Spawns a real pwsh subprocess; combines stdout+stderr into Output,
    # exactly as a shell caller's `2>&1` would for any external command.
    # PowerShell 7's ConciseView error formatter wraps a Write-Error
    # message across "Line | ..." gutter continuation lines on its own
    # heuristic — NOT controlled by Out-String -Width — so a caller's
    # `-match` phrase check could otherwise land right on a wrap point.
    # Collapsing every whitespace run (including newlines) to a single
    # space sidesteps this without affecting JSON parsing (JSON treats any
    # whitespace run between tokens as equivalent) or diagnostic substring
    # matching.
    param([string[]]$CliArgs)
    $out = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPs1 @CliArgs 2>&1 | Out-String -Width 4096
    $flattened = $out -replace '\s+', ' '
    # ConciseView also inserts a literal " | " gutter marker at each wrapped
    # continuation line (e.g. "...an empty | paths.include list" for a
    # message that read "...an empty paths.include list" on one logical
    # line) — strip that formatting artifact too, then re-collapse any
    # doubled spaces its removal leaves behind.
    $flattened = ($flattened -replace ' \| ', ' ') -replace '\s+', ' '
    return @{ Output = $flattened; ExitCode = $LASTEXITCODE }
}

function Invoke-ResolveFixture {
    param([string]$ConfigPath, [string]$PathsFile)
    if (Test-Path -LiteralPath $PathsFile) {
        return Invoke-ResolverRaw -CliArgs @("-Config", $ConfigPath, "-ChangedPathsFile", $PathsFile)
    }
    return Invoke-ResolverRaw -CliArgs @("-Config", $ConfigPath)
}

function Get-Classification {
    param([string]$Json, [string]$RawPath)
    $obj = $Json | ConvertFrom-Json
    $rec = $obj.records | Where-Object { $_.raw_path -eq $RawPath }
    if ($null -eq $rec) { return $null }
    return $rec.classification
}

# ============================================================================
# TEST-001 (AC-001): ** crosses "/" boundaries
# ============================================================================
Write-Output "=== TEST-001: ** crosses / boundaries ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-001-doublestar/config.yaml") (Join-Path $fixtures "test-001-doublestar/changed-paths.txt")
if ((Get-Classification $r.Output "src/desktop/file.ts") -eq "EXCLUSIVE") { Ok "TEST-001.1: direct child match" } else { Fail "TEST-001.1: expected EXCLUSIVE" }
if ((Get-Classification $r.Output "src/desktop/sub/deep/file.ts") -eq "EXCLUSIVE") { Ok "TEST-001.2: nested match crosses /" } else { Fail "TEST-001.2: expected EXCLUSIVE" }

# ============================================================================
# TEST-002 (AC-002): bare * confined to one segment
# ============================================================================
Write-Output "=== TEST-002: bare * confined to one path segment ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-002-singlestar/config.yaml") (Join-Path $fixtures "test-002-singlestar/changed-paths.txt")
if ((Get-Classification $r.Output "src/file.ts") -eq "EXCLUSIVE") { Ok "TEST-002.1: src/*.ts matches src/file.ts" } else { Fail "TEST-002.1: expected EXCLUSIVE" }
if ((Get-Classification $r.Output "src/sub/file.ts") -eq "UNOWNED") { Ok "TEST-002.2: src/*.ts does not cross /" } else { Fail "TEST-002.2: expected UNOWNED" }

# ============================================================================
# TEST-003 (AC-003): backslash normalization
# ============================================================================
Write-Output "=== TEST-003: backslash pattern normalization ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-003-backslash/config.yaml") (Join-Path $fixtures "test-003-backslash/changed-paths.txt")
if ((Get-Classification $r.Output "src/desktop/file.ts") -eq "EXCLUSIVE") { Ok "TEST-003.1: backslash pattern normalizes to slash form" } else { Fail "TEST-003.1: expected EXCLUSIVE" }

# ============================================================================
# TEST-004 (AC-004): NFC-normalized matching
# ============================================================================
Write-Output "=== TEST-004: NFC-normalized matching ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-004-nfc-match/config.yaml") (Join-Path $fixtures "test-004-nfc-match/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records.Count -eq 1 -and $obj.records[0].classification -eq "EXCLUSIVE") {
    Ok "TEST-004.1: NFD-encoded raw path matches NFC-encoded pattern"
} else {
    Fail "TEST-004.1: expected exactly 1 EXCLUSIVE record"
}

# ============================================================================
# TEST-005 (AC-005): case-sensitive matching
# ============================================================================
Write-Output "=== TEST-005: case-sensitive matching ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-005-case-sensitive/config.yaml") (Join-Path $fixtures "test-005-case-sensitive/changed-paths.txt")
if ((Get-Classification $r.Output "Src/file.ts") -eq "EXCLUSIVE") { Ok "TEST-005.1: Src/** matches Src/file.ts" } else { Fail "TEST-005.1: expected EXCLUSIVE" }
if ((Get-Classification $r.Output "src/file.ts") -eq "UNOWNED") { Ok "TEST-005.2: Src/** does not match src/file.ts (case differs)" } else { Fail "TEST-005.2: expected UNOWNED" }

# ============================================================================
# TEST-006 (AC-006): unsupported metacharacter rejected fail-closed
# ============================================================================
Write-Output "=== TEST-006: unsupported metacharacter rejected fail-closed ==="
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-006-unsupported-metachar/config.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "unsupported glob metacharacter") {
    Ok "TEST-006.1: '[abc]' pattern rejected fail-closed at load time"
} else {
    Fail "TEST-006.1: expected non-zero exit + diagnostic, got exit=$($r.ExitCode) out=$($r.Output)"
}

# ============================================================================
# TEST-007 (AC-007): ** zero-segment case
# ============================================================================
Write-Output "=== TEST-007: ** zero-segment case ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-007-zero-segment/config.yaml") (Join-Path $fixtures "test-007-zero-segment/changed-paths.txt")
if ((Get-Classification $r.Output "a/b") -eq "EXCLUSIVE") { Ok "TEST-007.1: a/**/b matches literal a/b" } else { Fail "TEST-007.1: expected EXCLUSIVE" }
if ((Get-Classification $r.Output "a/x/b") -eq "EXCLUSIVE") { Ok "TEST-007.2: a/**/b matches a/x/b" } else { Fail "TEST-007.2: expected EXCLUSIVE" }
if ((Get-Classification $r.Output "a/c") -eq "UNOWNED") { Ok "TEST-007.3: a/**/b does not match unrelated a/c" } else { Fail "TEST-007.3: expected UNOWNED" }

# ============================================================================
# TEST-008 (AC-008): empty-set clauses
# ============================================================================
Write-Output "=== TEST-008: empty-set clauses ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-008-empty-sets/config.yaml") (Join-Path $fixtures "test-008-empty-sets/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records.Count -eq 0) { Ok "TEST-008.1: empty changed-paths diff resolves vacuously" } else { Fail "TEST-008.1: expected 0 records" }

$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-008-empty-include/config.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "empty paths.include") {
    Ok "TEST-008.2: component with empty include list is a config-load-time error"
} else {
    Fail "TEST-008.2: expected non-zero exit + empty-include diagnostic, got exit=$($r.ExitCode) out=$($r.Output)"
}

# ============================================================================
# TEST-009 (AC-009): shared_paths zero-match this resolve
# ============================================================================
Write-Output "=== TEST-009: shared_paths zero-match this resolve ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-009-shared-zero-match/config.yaml") (Join-Path $fixtures "test-009-shared-zero-match/changed-paths.txt")
if ((Get-Classification $r.Output "a/file.ts") -eq "EXCLUSIVE") { Ok "TEST-009.1: a zero-match shared_paths entry does not disturb ordinary classification" } else { Fail "TEST-009.1: expected EXCLUSIVE" }

# ============================================================================
# TEST-010 (AC-010): NFC collision, raw identity, stable sort
# ============================================================================
Write-Output "=== TEST-010: NFC collision, raw identity, stable sort ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-010-nfc-collision/config.yaml") (Join-Path $fixtures "test-010-nfc-collision/changed-paths.txt")
if ($r.ExitCode -ne 0 -and $r.Output -match "NFC-normalization collision") {
    Ok "TEST-010.1: two distinct raw paths differing only in NFC/NFD form are rejected fail-closed"
} else {
    Fail "TEST-010.1: expected non-zero exit + collision diagnostic, got exit=$($r.ExitCode) out=$($r.Output)"
}

$r = Invoke-ResolveFixture (Join-Path $fixtures "test-004-nfc-match/config.yaml") (Join-Path $fixtures "test-004-nfc-match/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
$rawBytes = [System.Text.Encoding]::UTF8.GetBytes($obj.records[0].raw_path)
$fileBytes = [System.IO.File]::ReadAllBytes((Join-Path $fixtures "test-004-nfc-match/changed-paths.txt"))
# The fixture file is exactly one line + a trailing "\n"; strip that one
# trailing byte before comparing (the resolver's raw_path field carries no
# trailing newline of its own).
$fileBytesNoTrailingNewline = $fileBytes[0..($fileBytes.Length - 2)]
if ([System.Linq.Enumerable]::SequenceEqual([byte[]]$rawBytes, [byte[]]$fileBytesNoTrailingNewline)) {
    Ok "TEST-010.2: output raw_path preserves the original NFD byte sequence exactly"
} else {
    Fail "TEST-010.2: raw_path bytes diverged from the source fixture's original bytes"
}

$r = Invoke-ResolveFixture (Join-Path $fixtures "test-010b-stable-sort/config.yaml") (Join-Path $fixtures "test-010b-stable-sort/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
$order = ($obj.records | ForEach-Object { $_.raw_path }) -join ","
if ($order -eq "a/x.ts,a/y.ts,b/z.ts") { Ok "TEST-010.3: stable ordinal sort over raw path bytes" } else { Fail "TEST-010.3: expected 'a/x.ts,a/y.ts,b/z.ts', got '$order'" }

# ============================================================================
# TEST-011 (AC-011): A1 schema conformance
# ============================================================================
Write-Output "=== TEST-011: A1 schema-conformance fixture ==="
$r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", (Join-Path $fixtures "nonexistent-schema.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match '"conformant": false') {
    Ok "TEST-011.1: fail-closed non-zero when the artifact is absent"
} else {
    Fail "TEST-011.1: expected non-zero + conformant:false for an absent schema artifact"
}

$conformantDir = Join-Path ([IO.Path]::GetTempPath()) ("rcp-schema-conformant." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $conformantDir | Out-Null
try {
    $schemaPath = Join-Path $conformantDir "schema.yaml"
    @"
components:
  - name: example
    paths:
      include:
        - "example/**"
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    components:
      - example
"@ | Set-Content -LiteralPath $schemaPath -Encoding utf8 -NoNewline
    $r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", $schemaPath)
    if ($r.ExitCode -eq 0 -and $r.Output -match '"conformant": true') {
        Ok "TEST-011.2: exit 0 + conformant:true for a well-formed schema artifact"
    } else {
        Fail "TEST-011.2: expected exit 0 + conformant:true, got exit=$($r.ExitCode) out=$($r.Output)"
    }
} finally {
    Remove-Item -Recurse -Force -LiteralPath $conformantDir -ErrorAction SilentlyContinue
}

# TEST-011.3 — DELIBERATE, DOCUMENTED, PERMANENT RED until Epic A1 lands
# contracts/project-context.template.yaml. See the bash twin's header.
$r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance")
if ($r.ExitCode -eq 0) {
    Ok "TEST-011.3: contracts/project-context.template.yaml now conforms (Epic A1 has landed)"
} else {
    Fail "TEST-011.3 [EXPECTED - Epic A1 has not landed contracts/project-context.template.yaml yet]: $($r.Output)"
}

# ============================================================================
# TEST-012 (AC-012): EXCLUSIVE classification
# ============================================================================
Write-Output "=== TEST-012: EXCLUSIVE classification ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-012-exclusive/config.yaml") (Join-Path $fixtures "test-012-exclusive/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records[0].classification -eq "EXCLUSIVE") { Ok "TEST-012.1: single-component match classifies EXCLUSIVE" } else { Fail "TEST-012.1: expected EXCLUSIVE" }
if ($obj.records[0].owning_components[0] -eq "c1") { Ok "TEST-012.2: EXCLUSIVE record names the owning component" } else { Fail "TEST-012.2: expected owning_components == [c1]" }

# ============================================================================
# TEST-013/TEST-014 (AC-013/AC-014): exclude invariant + EXCLUDED_MATCH
# ============================================================================
Write-Output "=== TEST-013/014: exclude invariant + EXCLUDED_MATCH evidence ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-013-014-exclude-invariant/config.yaml") (Join-Path $fixtures "test-013-014-exclude-invariant/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records[0].classification -eq "UNOWNED") { Ok "TEST-013.1: Fail-5 invariant — exclude wins over include within the same component" } else { Fail "TEST-013.1: expected UNOWNED" }
$evComp = $obj.records[0].evidence.excluded_match[0].component
$evPattern = $obj.records[0].evidence.excluded_match[0].patterns[0]
if ($evComp -eq "c1" -and $evPattern -eq "src/c1/generated/**") {
    Ok "TEST-014.1: UNOWNED record carries EXCLUDED_MATCH evidence"
} else {
    Fail "TEST-014.1: expected excluded_match [c1, src/c1/generated/**], got [$evComp, $evPattern]"
}

# ============================================================================
# TEST-015 (AC-015): UNOWNED (Fail-1), ordinary case
# ============================================================================
Write-Output "=== TEST-015: UNOWNED (Fail-1), ordinary case ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-015-unowned/config.yaml") (Join-Path $fixtures "test-015-unowned/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records[0].classification -eq "UNOWNED") { Ok "TEST-015.1: no component match classifies UNOWNED" } else { Fail "TEST-015.1: expected UNOWNED" }
if ($null -eq $obj.records[0].evidence.excluded_match) { Ok "TEST-015.2: ordinary UNOWNED carries no EXCLUDED_MATCH evidence" } else { Fail "TEST-015.2: expected excluded_match == null" }

# ============================================================================
# TEST-016 (AC-016): OVERLAP (Fail-3)
# ============================================================================
Write-Output "=== TEST-016: OVERLAP (Fail-3) ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-016-overlap/config.yaml") (Join-Path $fixtures "test-016-overlap/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records[0].classification -eq "OVERLAP") { Ok "TEST-016.1: two-component match classifies OVERLAP" } else { Fail "TEST-016.1: expected OVERLAP" }
$owners = ($obj.records[0].owning_components | Sort-Object) -join ","
if ($owners -eq "c1,c2") { Ok "TEST-016.2: OVERLAP names every residual owner" } else { Fail "TEST-016.2: expected c1,c2, got $owners" }

# ============================================================================
# TEST-017 (AC-017): shared_paths exemption
# ============================================================================
Write-Output "=== TEST-017: shared_paths exemption ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-017-shared-exempt/config.yaml") (Join-Path $fixtures "test-017-shared-exempt/changed-paths.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.records[0].classification -eq "SHARED_CROSS_CUTTING") { Ok "TEST-017.1: shared_paths match exempts from OVERLAP" } else { Fail "TEST-017.1: expected SHARED_CROSS_CUTTING" }

# ============================================================================
# TEST-018 (AC-018): shared_paths shape fail-closed
# ============================================================================
Write-Output "=== TEST-018: shared_paths shape fail-closed ==="
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-018-shared-shape-error/config-both.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "never both or neither") { Ok "TEST-018.1: both components+classification rejected" } else { Fail "TEST-018.1: expected shape diagnostic, got exit=$($r.ExitCode) out=$($r.Output)" }
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-018-shared-shape-error/config-neither.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "never both or neither") { Ok "TEST-018.2: neither components nor classification rejected" } else { Fail "TEST-018.2: expected shape diagnostic, got exit=$($r.ExitCode) out=$($r.Output)" }

# ============================================================================
# TEST-042/043/044 (AC-042/043/044, REQ-006, T-005): cross-epic
# cross-cutting seed inventory. TEST-042/044 read Epic A1's REAL template
# directly and are DELIBERATELY, PERMANENTLY red while it is absent — same
# documented pattern as TEST-011.3. See the bash twin's header comment for
# the full rationale.
# ============================================================================
# Shared inventory-conformance check, factored out so it can be proven
# against BOTH the real A1 template (TEST-042) and a deliberately wrong
# local fixture (TEST-042-negative, the acceptance-first RED evidence this
# task's Required Workflow calls for).
function Test-InventoryConformance {
    param([string]$TemplatePath)
    $text = Get-Content -Raw -LiteralPath $TemplatePath
    $expectedEntries = @("specs/**", "reports/**", "docs/**", ".github/**", "tests/fixtures/**", "CHANGELOG.md")
    $missing = $expectedEntries | Where-Object { $text -notmatch [regex]::Escape($_) }
    if ($text -match [regex]::Escape("contracts/**")) { return $false }
    if ($missing.Count -gt 0) { return $false }
    return $true
}

Write-Output "=== TEST-042: cross-epic inventory conformance (A1 template) ==="
$a1Template = Join-Path $repoRoot "contracts/project-context.template.yaml"
if (-not (Test-Path -LiteralPath $a1Template)) {
    Fail "TEST-042 [EXPECTED - Epic A1 has not landed contracts/project-context.template.yaml yet]: artifact absent at $a1Template"
} elseif (Test-InventoryConformance $a1Template) {
    Ok "TEST-042: A1's landed template's cross-cutting shared_paths entries match the six-entry canonical set exactly, contracts/** absent"
} else {
    Fail "TEST-042: A1's landed template diverges from the six-entry canonical cross-cutting set"
}

Write-Output "=== TEST-042-negative: inventory-conformance check catches a deliberately wrong seed set (acceptance-first RED evidence) ==="
$wrongSeedFile = Join-Path ([IO.Path]::GetTempPath()) ("rcp-wrong-seed." + [Guid]::NewGuid().ToString("N") + ".yaml")
@"
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    classification: cross-cutting
"@ | Set-Content -LiteralPath $wrongSeedFile -Encoding utf8 -NoNewline
try {
    if (Test-InventoryConformance $wrongSeedFile) {
        Fail "TEST-042-negative: a deliberately wrong seed set should have been rejected, but the check reported conformant"
    } else {
        Ok "TEST-042-negative: the inventory-conformance check correctly rejects a deliberately wrong seed set — proves the check is not vacuously always-passing"
    }
} finally {
    Remove-Item -Force -LiteralPath $wrongSeedFile -ErrorAction SilentlyContinue
}

Write-Output "=== TEST-043: no-op proof for the six-entry cross-cutting set ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "test-043-cross-cutting-no-op/config.yaml") (Join-Path $fixtures "test-043-cross-cutting-no-op/changed-paths.txt")
$dayOnePaths = @("specs/some-feature/requirements.md", "reports/quality-gate/2026-01-01.md", "docs/architecture/overview.md", ".github/workflows/example.yml", "tests/fixtures/some-fixture.json", "CHANGELOG.md")
$allCrossCutting = $true
foreach ($p in $dayOnePaths) {
    $cls = Get-Classification $r.Output $p
    if ($cls -ne "SHARED_CROSS_CUTTING") {
        $allCrossCutting = $false
        Fail "TEST-043: expected SHARED_CROSS_CUTTING for $p, got $cls"
    }
}
if ($allCrossCutting) { Ok "TEST-043: a diff confined to the six-entry cross-cutting set, with zero declared component owners, never triggers Fail-1/UNOWNED" }

Write-Output "=== TEST-044: day-one cross-epic integration proof (A1 template) ==="
if (-not (Test-Path -LiteralPath $a1Template)) {
    Fail "TEST-044 [EXPECTED - Epic A1 has not landed contracts/project-context.template.yaml yet]: artifact absent at $a1Template, day-one integration cannot be proven against it"
} else {
    $dayOneFile = Join-Path ([IO.Path]::GetTempPath()) ("rcp-dayone." + [Guid]::NewGuid().ToString("N") + ".txt")
    "specs/epic-example/requirements.md`nreports/quality-gate/2026-01-01.md`n" | Set-Content -LiteralPath $dayOneFile -Encoding utf8 -NoNewline
    try {
        $r = Invoke-ResolverRaw -CliArgs @("-Config", $a1Template, "-ChangedPathsFile", $dayOneFile)
        if ($r.ExitCode -eq 0 -and (Get-Classification $r.Output "specs/epic-example/requirements.md") -ne "UNOWNED" -and (Get-Classification $r.Output "reports/quality-gate/2026-01-01.md") -ne "UNOWNED") {
            Ok "TEST-044: a project-context.yaml shaped like A1's own landed template does not trip Fail-1 on an ordinary day-one specs/**/reports/** change"
        } else {
            Fail "TEST-044: day-one integration against A1's landed template failed (exit=$($r.ExitCode))"
        }
    } finally {
        Remove-Item -Force -LiteralPath $dayOneFile -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# TEST-045 (AC-045): fixture-tree base shape + suite/CI registration
# ============================================================================
Write-Output "=== TEST-045: fixture-tree base shape + suite/CI registration ==="
$r = Invoke-ResolveFixture (Join-Path $fixtures "base-tree/config.yaml") (Join-Path $fixtures "base-tree/changed-paths.txt")
if ((Get-Classification $r.Output "src/shared-ui/button.ts") -eq "OVERLAP") { Ok "TEST-045.1: base fixture has >=2 overlapping components" } else { Fail "TEST-045.1: expected OVERLAP" }
if ((Get-Classification $r.Output "src/desktop/generated/x.ts") -eq "UNOWNED") { Ok "TEST-045.2: base fixture has a nested excluded subtree" } else { Fail "TEST-045.2: expected UNOWNED" }
if ((Get-Classification $r.Output "contracts/schema.json") -eq "SHARED_BOUNDED") { Ok "TEST-045.3: base fixture has a bounded shared_paths entry" } else { Fail "TEST-045.3: expected SHARED_BOUNDED" }

$runAllSh = Join-Path $repoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
if ((Select-String -LiteralPath $runAllSh -Pattern "component-path-resolver" -Quiet) -and (Select-String -LiteralPath $runAllPs1 -Pattern "component-path-resolver" -Quiet)) {
    Ok "TEST-045.4: component-path-resolver self-registers in run-all.sh and .ps1"
} else {
    Fail "TEST-045.4: component-path-resolver missing from run-all.sh/.ps1 registration"
}

$manifest = Join-Path $repoRoot "specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256"
if ((Test-Path -LiteralPath $manifest) -and (Select-String -LiteralPath $manifest -Pattern "\.github/workflows/test\.yml" -Quiet)) {
    Ok "TEST-045.5: staged .github/workflows/test.yml candidate has a MANIFEST.sha256 entry"
} else {
    Fail "TEST-045.5: expected a .github/workflows/test.yml entry in $manifest"
}

# ============================================================================
# Summary
# ============================================================================
Write-Output ""
Write-Output "component-path-resolver.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
