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
# TEST-011 is fail-closed: both the JSON Schema contract and canonical YAML
# template must exist and agree with the parser contract.
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
    $rec = $obj.records | Where-Object { $_.raw_path -ceq $RawPath }
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
$questionConfig = Join-Path ([IO.Path]::GetTempPath()) ("rcp-question." + [Guid]::NewGuid().ToString("N") + ".yaml")
@'
components:
  - id: c1
    paths:
      include:
        - "src/?.ts"
'@ | Set-Content -LiteralPath $questionConfig -Encoding utf8 -NoNewline
try {
    $r = Invoke-ResolverRaw -CliArgs @("-Config", $questionConfig)
    if ($r.ExitCode -ne 0 -and $r.Output -match "unsupported glob metacharacter") {
        Ok "TEST-006.2: '?' pattern rejected fail-closed at load time"
    } else {
        Fail "TEST-006.2: expected non-zero exit + diagnostic, got exit=$($r.ExitCode) out=$($r.Output)"
    }
} finally {
    Remove-Item -Force -LiteralPath $questionConfig -ErrorAction SilentlyContinue
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
if ($order -ceq "A/upper.ts,a/lower.ts,z/last.ts,é/nonascii.ts") { Ok "TEST-010.3: stable ordinal sort over raw UTF-8 path bytes" } else { Fail "TEST-010.3: expected raw UTF-8 byte order A,a,z,é, got '$order'" }

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
schema: sdd-project-context/v1
components: []
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    components:
      - example
"@ | Set-Content -LiteralPath $schemaPath -Encoding utf8 -NoNewline
    $schemaContractPath = Join-Path $conformantDir "schema.json"
    @'
{
  "properties": {
    "schema": {"const": "sdd-project-context/v1"},
    "components": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "paths"],
        "properties": {
          "id": {"type": "string"},
          "paths": {"type": "object", "properties": {
            "include": {"type": "array", "items": {"type": "string"}},
            "exclude": {"type": "array", "items": {"type": "string"}}
          }}
        }
      }
    },
    "shared_paths": {"type": "array", "items": {
      "type": "object",
      "required": ["pattern"],
      "oneOf": [
        {"required": ["components"], "properties": {"components": {"type": "array", "items": {"type": "string"}}}},
        {"required": ["classification"], "properties": {"classification": {"const": "cross-cutting"}}}
      ]
    }}
  }
}
'@ | Set-Content -LiteralPath $schemaContractPath -Encoding utf8 -NoNewline
    $r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", $schemaPath, "-SchemaContract", $schemaContractPath)
    if ($r.ExitCode -eq 0 -and $r.Output -match '"conformant": true') {
        Ok "TEST-011.2: exact schema version/types and canonical components: [] report conformant:true"
    } else {
        Fail "TEST-011.2: expected exact version/types plus components: [] to conform, got exit=$($r.ExitCode) out=$($r.Output)"
    }

    $wrongVersionPath = Join-Path $conformantDir "wrong-version.yaml"
    ((Get-Content -Raw -LiteralPath $schemaPath) -replace 'sdd-project-context/v1', 'sdd-project-context/v2') |
        Set-Content -LiteralPath $wrongVersionPath -Encoding utf8 -NoNewline
    $r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", $wrongVersionPath, "-SchemaContract", $schemaContractPath)
    if ($r.ExitCode -ne 0 -and $r.Output -match '"conformant": false') {
        Ok "TEST-011.2a: wrong project-context schema version is rejected fail-closed"
    } else {
        Fail "TEST-011.2a: wrong project-context schema version was not rejected"
    }

    $wrongTypesPath = Join-Path $conformantDir "wrong-types.json"
    ((Get-Content -Raw -LiteralPath $schemaContractPath) -replace '"type": "string"', '"type": "number"') |
        Set-Content -LiteralPath $wrongTypesPath -Encoding utf8 -NoNewline
    $r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", $schemaPath, "-SchemaContract", $wrongTypesPath)
    if ($r.ExitCode -ne 0 -and $r.Output -match '"conformant": false') {
        Ok "TEST-011.2b: divergent project-context field types are rejected fail-closed"
    } else {
        Fail "TEST-011.2b: divergent project-context field types were not rejected"
    }

    $wrongFieldNamePath = Join-Path $conformantDir "wrong-field-name.json"
    ((Get-Content -Raw -LiteralPath $schemaContractPath) -replace '"id":', '"ID":') |
        Set-Content -LiteralPath $wrongFieldNamePath -Encoding utf8 -NoNewline
    $r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", $schemaPath, "-SchemaContract", $wrongFieldNamePath)
    if ($r.ExitCode -ne 0 -and $r.Output -match '"conformant": false') {
        Ok "TEST-011.2c: mis-cased schema-contract field name is rejected fail-closed"
    } else {
        Fail "TEST-011.2c: mis-cased schema-contract field name was not rejected"
    }
} finally {
    Remove-Item -Recurse -Force -LiteralPath $conformantDir -ErrorAction SilentlyContinue
}

# TEST-011.3 — Epic A1 has LANDED, so this is now an ordinary green
# assertion on the real contract. See the bash twin's header.
$r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance")
if ($r.ExitCode -eq 0) {
    Ok "TEST-011.3: contracts/project-context.template.yaml conforms against A1's landed contract"
} else {
    Fail "TEST-011.3: A1's landed template no longer conforms: $($r.Output)"
}

# TEST-011.4 (AC-011) — instance validation against A1's real JSON Schema.
$r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance")
if ($r.ExitCode -eq 0 -and $r.Output -match 'validates against contracts/project-context\.schema\.json') {
    Ok "TEST-011.4: A1's template is validated as an instance against contracts/project-context.schema.json"
} else {
    Fail "TEST-011.4: schema-conformance did not perform instance validation against A1's JSON Schema: $($r.Output)"
}

# TEST-011.5 (AC-011) — negative control: an instance violating A1's schema
# (the pre-A1 'name' key, invalid under "additionalProperties": false) is
# rejected fail-closed.
$instanceViolation = Join-Path ([System.IO.Path]::GetTempPath()) ("a3-instance-" + [guid]::NewGuid().ToString() + ".yaml")
@(
    'schema: sdd-project-context/v1'
    'workflow:'
    '  spec_profile: full'
    '  artifact_layout: legacy-seven-layer'
    '  capability_enforcement: advisory'
    'components:'
    '  - name: legacy-keyed-component'
    '    paths:'
    '      include:'
    '        - "src/c1/**"'
    'shared_paths:'
    '  - pattern: "specs/**"'
    '    classification: cross-cutting'
) -join "`n" | Set-Content -LiteralPath $instanceViolation -Encoding utf8
try {
    $r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", $instanceViolation)
    if ($r.ExitCode -ne 0 -and $r.Output -match "missing required field 'id'") {
        Ok "TEST-011.5: an instance violating A1's schema (legacy 'name' key) is rejected fail-closed"
    } else {
        Fail "TEST-011.5: a schema-violating instance was not rejected: $($r.Output)"
    }
} finally {
    Remove-Item -Force -LiteralPath $instanceViolation -ErrorAction SilentlyContinue
}

# TEST-011.6 (AC-011) — fail-closed-on-absence is still live.
$r = Invoke-ResolverRaw -CliArgs @("-CheckSchemaConformance", "-Schema", (Join-Path $repoRoot "contracts/does-not-exist.template.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match '"conformant": false') {
    Ok "TEST-011.6: an absent schema artifact still FAILS closed (never a skip)"
} else {
    Fail "TEST-011.6: absent schema artifact did not fail closed: $($r.Output)"
}

$legacyConfig = Join-Path ([System.IO.Path]::GetTempPath()) ("component-path-legacy-" + [guid]::NewGuid().ToString() + ".yaml")
$legacyKey = "na" + "me"
@(
    'schema: sdd-project-context/v1'
    'components:'
    "  - ${legacyKey}: legacy-component"
    '    paths:'
    '      include:'
    '        - "src/**"'
    'shared_paths: []'
) -join "`n" | Set-Content -LiteralPath $legacyConfig -Encoding utf8
$r = Invoke-ResolverRaw -CliArgs @("-Config", $legacyConfig)
Remove-Item -Force -LiteralPath $legacyConfig -ErrorAction SilentlyContinue
if ($r.ExitCode -ne 0 -and $r.Output -match "legacy 'name' is not supported") {
    Ok "TEST-011.7: ordinary resolve rejects the pre-A1 legacy name field"
} else {
    Fail "TEST-011.7: ordinary resolve accepted legacy name, exit=$($r.ExitCode) out=$($r.Output)"
}

$r = Invoke-ResolveFixture (Join-Path $fixtures "test-012-exclusive/config.yaml") (Join-Path $fixtures "test-012-exclusive/changed-paths.txt")
$ownershipComponent = ($r.Output | ConvertFrom-Json).ownership_input.components[0]
$ownershipKeys = @($ownershipComponent.PSObject.Properties.Name)
$legacyOwnershipKey = "na" + "me"
if ($ownershipKeys -ccontains "id" -and $ownershipKeys -cnotcontains $legacyOwnershipKey) {
    Ok "TEST-011.8: ownership_input preserves canonical component id"
} else {
    Fail "TEST-011.8: ownership_input rewrote canonical component id: $($r.Output)"
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
$evPattern = $obj.records[0].evidence.excluded_match[0].pattern
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
if ((Get-Classification $r.Output "contracts/zero.json") -ceq "SHARED_CROSS_CUTTING") { Ok "TEST-017.1: shared_paths precedence applies with zero matching component includes" } else { Fail "TEST-017.1: expected SHARED_CROSS_CUTTING with zero owners" }
if ((Get-Classification $r.Output "contracts/one/schema.json") -ceq "SHARED_CROSS_CUTTING") { Ok "TEST-017.2: shared_paths precedence applies with one matching component include" } else { Fail "TEST-017.2: expected SHARED_CROSS_CUTTING with one owner" }
if ((Get-Classification $r.Output "contracts/two/schema.json") -ceq "SHARED_CROSS_CUTTING") { Ok "TEST-017.3: shared_paths precedence applies with two matching component includes" } else { Fail "TEST-017.3: expected SHARED_CROSS_CUTTING with two owners" }

# ============================================================================
# TEST-018 (AC-018): shared_paths shape fail-closed
# ============================================================================
Write-Output "=== TEST-018: shared_paths shape fail-closed ==="
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-018-shared-shape-error/config-both.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "never both or neither") { Ok "TEST-018.1: both components+classification rejected" } else { Fail "TEST-018.1: expected shape diagnostic, got exit=$($r.ExitCode) out=$($r.Output)" }
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-018-shared-shape-error/config-neither.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "never both or neither") { Ok "TEST-018.2: neither components nor classification rejected" } else { Fail "TEST-018.2: expected shape diagnostic, got exit=$($r.ExitCode) out=$($r.Output)" }
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-018-shared-shape-error/config-miscased-classification.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "unsupported classification") { Ok "TEST-018.3: mis-cased Cross-Cutting literal is rejected fail-closed" } else { Fail "TEST-018.3: expected exact-case classification rejection, got exit=$($r.ExitCode) out=$($r.Output)" }
$r = Invoke-ResolverRaw -CliArgs @("-Config", (Join-Path $fixtures "test-018-shared-shape-error/config-miscased-components.yaml"))
if ($r.ExitCode -ne 0 -and $r.Output -match "config.components must be a list") { Ok "TEST-018.4: mis-cased Components field is rejected fail-closed" } else { Fail "TEST-018.4: expected exact-case field-name rejection, got exit=$($r.ExitCode) out=$($r.Output)" }

# ============================================================================
# TEST-042/043/044 (AC-042/043/044, REQ-006, T-005): cross-epic
# cross-cutting seed inventory. TEST-042/044 read Epic A1's REAL template
# directly; now that A1 has landed they are green, while an absent or divergent
# artifact remains fail-closed. See the bash twin's header comment for the full
# rationale.
# ============================================================================
# Shared inventory-conformance check, factored out so it can be proven
# against BOTH the real A1 template (TEST-042) and deliberately wrong local
# fixtures (TEST-042-negative, the acceptance-first RED evidence this
# task's Required Workflow calls for).
#
# T-005 quality-gate finding (Major, reports/quality-gate/epic-191-a3-path-ownership/T-005.md):
# the prior version did a fixed-string/regex-escaped substring match, which
# caught a missing entry and the one specific extra `contracts/**` case,
# but did not reject an ARBITRARY extra cross-cutting entry ("no more") or
# a canonical entry wrongly classified as bounded instead of cross-cutting
# ("no differently classified") — both of which AC-042 explicitly requires
# this fixture to fail on. Remedied by parsing the actual shared_paths
# entry structure (a small, purpose-built parser scoped to exactly this
# shape — not resolve-component-paths.ps1's own generic YAML parser,
# since dot-sourcing that script would also execute its CLI dispatch/exit
# logic in this process) and asserting SET EQUALITY between the
# template's cross-cutting patterns and the canonical six.
function Test-InventoryConformance {
    param([string]$TemplatePath)
    $CANONICAL = @("specs/**", "reports/**", "docs/**", ".github/**", "tests/fixtures/**", "CHANGELOG.md")
    $lines = Get-Content -LiteralPath $TemplatePath
    $entries = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $lines) {
        if ($line -match '^\s*-\s*pattern:\s*(.+)$') {
            if ($null -ne $current) { $entries.Add($current) }
            $patternValue = $matches[1].Trim().Trim('"').Trim("'")
            $current = [ordered]@{ Pattern = $patternValue; Classification = $null; HasComponents = $false }
        } elseif ($null -ne $current -and $line -match '^\s*classification:\s*(.+)$') {
            $current.Classification = $matches[1].Trim().Trim('"').Trim("'")
        } elseif ($null -ne $current -and $line -match '^\s*components:\s*$') {
            $current.HasComponents = $true
        }
    }
    if ($null -ne $current) { $entries.Add($current) }

    $misclassified = [System.Collections.Generic.List[string]]::new()
    $crossCuttingSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($e in $entries) {
        $isCanonical = $CANONICAL -contains $e.Pattern
        if ($isCanonical -and ($e.Classification -ne "cross-cutting" -or $e.HasComponents)) {
            $misclassified.Add($e.Pattern)
        }
        if ($e.Classification -eq "cross-cutting") {
            [void]$crossCuttingSet.Add($e.Pattern)
        }
    }
    if ($misclassified.Count -gt 0) {
        return @{ Conformant = $false; Reason = "canonical entries wrongly classified as bounded: $($misclassified -join ',')" }
    }
    $canonicalSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$CANONICAL, [System.StringComparer]::Ordinal)
    if (-not $crossCuttingSet.SetEquals($canonicalSet)) {
        $missing = $CANONICAL | Where-Object { -not $crossCuttingSet.Contains($_) }
        $extra = $crossCuttingSet | Where-Object { $CANONICAL -notcontains $_ }
        return @{ Conformant = $false; Reason = "cross-cutting set mismatch: missing=$($missing -join ',') extra=$($extra -join ',')" }
    }
    return @{ Conformant = $true; Reason = "conformant" }
}

Write-Output "=== TEST-042: cross-epic inventory conformance (A1 template) ==="
$a1Template = Join-Path $repoRoot "contracts/project-context.template.yaml"
if (-not (Test-Path -LiteralPath $a1Template)) {
    Fail "TEST-042: A1's canonical template has LANDED and is a tracked repository artifact; its absence at $a1Template is now a regression, not an expected pre-A1 state"
} else {
    $r042 = Test-InventoryConformance $a1Template
    if ($r042.Conformant) {
        Ok "TEST-042: A1's landed template's cross-cutting shared_paths entries match the six-entry canonical set exactly, contracts/** absent, none misclassified"
    } else {
        Fail "TEST-042: A1's landed template diverges from the six-entry canonical cross-cutting set: $($r042.Reason)"
    }
}

Write-Output "=== TEST-042-negative: inventory-conformance check catches deliberately wrong seed sets (acceptance-first RED evidence) ==="
$wrongSeedFile1 = Join-Path ([IO.Path]::GetTempPath()) ("rcp-wrong-seed1." + [Guid]::NewGuid().ToString("N") + ".yaml")
@"
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    classification: cross-cutting
"@ | Set-Content -LiteralPath $wrongSeedFile1 -Encoding utf8 -NoNewline
try {
    if ((Test-InventoryConformance $wrongSeedFile1).Conformant) {
        Fail "TEST-042-negative.1: missing entries + wrongly-included contracts/** should have been rejected, but the check reported conformant"
    } else {
        Ok "TEST-042-negative.1: the check correctly rejects missing entries + wrongly-included contracts/**"
    }
} finally {
    Remove-Item -Force -LiteralPath $wrongSeedFile1 -ErrorAction SilentlyContinue
}

# Sub-case the QG finding specifically named: an ARBITRARY 7th extra
# cross-cutting entry, with all six canonical entries otherwise present
# and correctly classified — a pure "no more" violation the old
# substring-match check would have missed entirely.
$wrongSeedFile2 = Join-Path ([IO.Path]::GetTempPath()) ("rcp-wrong-seed2." + [Guid]::NewGuid().ToString("N") + ".yaml")
@"
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "reports/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: ".github/**"
    classification: cross-cutting
  - pattern: "tests/fixtures/**"
    classification: cross-cutting
  - pattern: "CHANGELOG.md"
    classification: cross-cutting
  - pattern: "vendor/**"
    classification: cross-cutting
"@ | Set-Content -LiteralPath $wrongSeedFile2 -Encoding utf8 -NoNewline
try {
    if ((Test-InventoryConformance $wrongSeedFile2).Conformant) {
        Fail "TEST-042-negative.2: all six canonical entries PLUS one arbitrary extra (vendor/**) should have been rejected, but the check reported conformant"
    } else {
        Ok "TEST-042-negative.2: the check correctly rejects an arbitrary extra cross-cutting entry even when all six canonical entries are present and correctly classified ('no more')"
    }
} finally {
    Remove-Item -Force -LiteralPath $wrongSeedFile2 -ErrorAction SilentlyContinue
}

# Sub-case the QG finding specifically named: a canonical pattern present
# but wrongly classified as BOUNDED (components: [...]) instead of
# cross-cutting — a pure "no differently classified" violation.
$wrongSeedFile3 = Join-Path ([IO.Path]::GetTempPath()) ("rcp-wrong-seed3." + [Guid]::NewGuid().ToString("N") + ".yaml")
@"
shared_paths:
  - pattern: "specs/**"
    components:
      - some-component
  - pattern: "reports/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: ".github/**"
    classification: cross-cutting
  - pattern: "tests/fixtures/**"
    classification: cross-cutting
  - pattern: "CHANGELOG.md"
    classification: cross-cutting
"@ | Set-Content -LiteralPath $wrongSeedFile3 -Encoding utf8 -NoNewline
try {
    if ((Test-InventoryConformance $wrongSeedFile3).Conformant) {
        Fail "TEST-042-negative.3: specs/** declared bounded (components:) instead of cross-cutting should have been rejected, but the check reported conformant"
    } else {
        Ok "TEST-042-negative.3: the check correctly rejects a canonical entry wrongly classified as bounded instead of cross-cutting ('no differently classified')"
    }
} finally {
    Remove-Item -Force -LiteralPath $wrongSeedFile3 -ErrorAction SilentlyContinue
}

Write-Output "=== TEST-043: no-op proof for the six-entry cross-cutting set ==="
# TEST-043.0 — AC-043 is about a diff "with zero components declared to own
# them". Assert the fixture's actual precondition so the pass message and
# the fixture agree (see the bash twin's comment).
$noOpConfig = Join-Path $fixtures "test-043-cross-cutting-no-op/config.yaml"
if ((Get-Content -Raw -LiteralPath $noOpConfig -Encoding utf8) -match '(?m)^components:[ \t]*\[\][ \t]*$') {
    Ok "TEST-043.0: the no-op fixture really does declare zero component owners (components: [])"
} else {
    Fail "TEST-043.0: fixture claims zero declared component owners but does not declare 'components: []'"
}
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
    Fail "TEST-044: A1's canonical template has LANDED and is a tracked repository artifact; its absence at $a1Template is now a regression, not an expected pre-A1 state"
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

$draftDir = Join-Path $repoRoot "reports/implementation/epic-191-a3-path-ownership/drafts"
$draftFile = Join-Path $draftDir "component-path-resolver-ci-steps.yml"
$manifest = Join-Path $draftDir "MANIFEST.sha256"
$expectedDigest = if (Test-Path -LiteralPath $manifest) { ((Get-Content -LiteralPath $manifest -Raw) -split '\s+')[0] } else { "" }
$actualDigest = if (Test-Path -LiteralPath $draftFile) { (Get-FileHash -Algorithm SHA256 -LiteralPath $draftFile).Hash.ToLowerInvariant() } else { "" }
if ($expectedDigest -cne "" -and $actualDigest -ceq $expectedDigest) {
    Ok "TEST-045.5: non-protected CI-step draft has a verified MANIFEST.sha256 entry"
} else {
    Fail "TEST-045.5: expected a hash-verified CI-step draft in $draftDir"
}

& git -C $repoRoot diff --quiet -- .github/workflows/test.yml
if ($LASTEXITCODE -eq 0) {
    Ok "TEST-045.6: live .github/workflows/test.yml remains byte-unchanged"
} else {
    Fail "TEST-045.6: live .github/workflows/test.yml has working-tree changes"
}

# TEST-045.7 — this suite's fixture corpus is keyed on Epic A1's canonical
# 'id', not this epic's pre-A1 'name'. See the bash twin's comment.
$legacyNamed = @(
    Get-ChildItem -Recurse -File -LiteralPath $fixtures |
        Where-Object { (Get-Content -Raw -LiteralPath $_.FullName -Encoding utf8) -match '(?m)^[ \t]*-[ \t]*name:' } |
        ForEach-Object { $_.FullName }
)
if ($legacyNamed.Count -eq 0) {
    Ok "TEST-045.7: every component-path-ownership fixture uses A1's canonical 'id' key"
} else {
    Fail "TEST-045.7: fixtures still use the pre-A1 'name' key: $($legacyNamed -join ' ')"
}

# ============================================================================
# Summary
# ============================================================================
Write-Output ""
Write-Output "component-path-resolver.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
