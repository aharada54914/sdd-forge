$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# T-001 (Issue #290, sdd-domain-concept-contract Phase 0): adds
# contracts/domain-contract.v2.schema.json (concepts[] as a first-class,
# additive model element) and installs the v1 byte-identity drift lock.
# PS5.1-safe: ConvertFrom-Json only, no Test-Json (PS6+ only, not available
# on Windows PowerShell 5.1). Follows the same hand-rolled structural-
# assertion approach as tests/sdd-domain/contract-schema.Tests.ps1 (v1)
# rather than a generic JSON Schema engine (INV-005 house pattern).
#
# This file grows across T-001..T-005: T-001 authors TEST-001 (schema shape,
# AC-001) and TEST-002 (v1 drift lock, AC-002) only. T-002 through T-005 each
# append their own Describe blocks (TEST-003..TEST-026) to this same file
# without editing what T-001 wrote here.

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$v2SchemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v2.schema.json"
$v1SchemaPath = Join-Path $repositoryRoot "contracts/domain-contract.v1.schema.json"

# TEST-002 drift lock (AC-002, REQ-007): SHA-256 of
# contracts/domain-contract.v1.schema.json measured at this feature's start
# (T-001, 2026-08-18: `shasum -a 256 contracts/domain-contract.v1.schema.json`).
# REQ-007 requires v1 stay byte-identical for the whole feature; any change to
# this recorded value is a regression in v1, not an update to this constant.
$v1BaselineSha256 = "0ab46b74c1e2561431b42b76106698339e79cd64ce0513b02aec5527b8b73841"

# Safe property accessor: Set-StrictMode -Version Latest throws on a missing
# property access for a PSCustomObject (unlike a hashtable, which returns
# $null for a missing key). Every field read below goes through this
# accessor instead of dot-notation so a missing/renamed key fails the
# relevant assertion instead of throwing.
function Get-PropSafe {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

Describe "domain-contract.v2.schema.json shape (TEST-001, AC-001)" {

    It "the v2 schema file exists" {
        Test-Path $v2SchemaPath | Should Be $true
    }

    It "parses as valid JSON" {
        { Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json } | Should Not Throw
    }

    Context "once parsed" {

        It "declares draft-07" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $draftValue = Get-PropSafe $contract '$schema'
            $draftValue | Should Be "http://json-schema.org/draft-07/schema#"
        }

        It "declares the domain-contract/v2 schema const" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $contract.properties.schema.const | Should Be "domain-contract/v2"
        }

        It "declares root required schema/meta/contexts/concepts, exactly those four" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $required = @($contract.required)
            foreach ($key in @("schema", "meta", "contexts", "concepts")) {
                ($required -contains $key) | Should Be $true
            }
            $required.Count | Should Be 4
        }

        It "declares a v1-shaped meta definition (version/status/generated_from)" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $meta = $contract.properties.meta
            $metaRequired = @($meta.required)
            foreach ($key in @("version", "status", "generated_from")) {
                ($metaRequired -contains $key) | Should Be $true
            }
            $metaRequired.Count | Should Be 3

            $meta.properties.version.pattern | Should Be '^[0-9]+\.[0-9]+\.[0-9]+$'

            $statusEnum = @($meta.properties.status.enum)
            $statusEnum.Count | Should Be 3
            foreach ($value in @("Pending", "Reviewed", "Approved")) {
                ($statusEnum -contains $value) | Should Be $true
            }

            $meta.properties.generated_from.type | Should Be "array"
            $meta.properties.generated_from.minItems | Should Be 1
            $meta.properties.generated_from.items.type | Should Be "string"
        }

        It "declares concepts as a required top-level array with minItems 1" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $contract.properties.concepts.type | Should Be "array"
            $contract.properties.concepts.minItems | Should Be 1
            (Get-PropSafe $contract.properties.concepts.items '$ref') | Should Be "#/definitions/concept"
        }

        It "duplicates the v1 boundedContext/term/aggregate/contextRelation definitions in-file (DD-3) and adds a concept definition" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            foreach ($def in @("boundedContext", "term", "aggregate", "contextRelation", "concept")) {
                (Get-PropSafe $contract.definitions $def) | Should Not Be $null
            }
        }

        It "does not `$ref` the v1 schema file (DD-3: definitions are duplicated, not cross-referenced)" {
            # Scoped to an actual JSON Schema $ref pointing at the v1 file, not
            # to prose mentioning v1's filename for documentation purposes --
            # DD-3 prohibits the cross-file reference, not the mention.
            $raw = Get-Content -Raw -Encoding Utf8 $v2SchemaPath
            $raw | Should Not Match '"\$ref"\s*:\s*"[^"]*domain-contract\.v1\.schema\.json[^"]*"'
        }

        It "declares contexts[].terms[].concept_id as optional with the concept-id pattern (REQ-003)" {
            $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
            $termDef = $contract.definitions.term
            $termRequired = @($termDef.required)
            ($termRequired -contains "concept_id") | Should Be $false
            $termDef.properties.concept_id.pattern | Should Be '^CONCEPT-[A-Z][A-Z0-9-]*$'
        }
    }
}

Describe "domain-contract.v1.schema.json byte-identity drift lock (TEST-002, AC-002, REQ-007)" {

    It "the v1 schema file still exists" {
        Test-Path $v1SchemaPath | Should Be $true
    }

    It "v1 schema file SHA-256 equals the recorded feature-start baseline" {
        $actualHash = (Get-FileHash -Path $v1SchemaPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $actualHash | Should Be $v1BaselineSha256
    }
}

# ---------------------------------------------------------------------------
# T-002 (Issue #290, sdd-domain-concept-contract Phase 0): the validator twins
# plugins/sdd-domain/scripts/validate-domain-contract.{sh,ps1}, REQ-004 steps
# (a) fail-closed JSON parse and (b) `schema`-value dispatch.
#
# Fixture allocation for this task (tasks.md `## Negative Fixture Allocation`):
# AC-017 x2 (truncated JSON, >10 MiB file) and AC-012 x1 (a domain-contract/v1
# contract rejected by name). The argument / path-error checks below are the
# tasks.md `### Done When` "Argument and path errors" item, not additional
# negative fixtures from that allocation table.
#
# Fixtures are ephemeral: every one is a here-string in this file expanded into
# a per-test temporary file that the test deletes again (DD-5, INV-006). No
# permanent fixtures directory is added. All fixture vocabulary is synthetic
# (Purchase / Fulfillment domain nouns); no credential, token, personal, or
# customer-derived string appears in any of them (security-spec.md).
# ---------------------------------------------------------------------------

$validatorPs1Path = Join-Path $repositoryRoot "plugins/sdd-domain/scripts/validate-domain-contract.ps1"
$validatorShPath = Join-Path $repositoryRoot "plugins/sdd-domain/scripts/validate-domain-contract.sh"

# The validator's oversized-input threshold (REQ-004(a) / requirements.md Edge
# Cases: "a contract file exceeding 10MB"). Declared here so the oversized
# fixture can be proven to actually exceed it rather than passing vacuously.
$maxContractBytes = 10485760

# Run the .ps1 twin under the SAME PowerShell host that is running this suite:
# Windows PowerShell 5.1 on Windows, pwsh elsewhere. Resolved from the live
# process rather than hard-coded so the twin is exercised on whatever host the
# suite runs under.
$powerShellHostPath = $null
try {
    $powerShellHostPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
} catch {
    $powerShellHostPath = $null
}
if ([string]::IsNullOrEmpty($powerShellHostPath)) {
    if ($PSVersionTable.PSEdition -eq "Desktop") {
        $powerShellHostPath = Join-Path $PSHOME "powershell.exe"
    } else {
        $powerShellHostPath = Join-Path $PSHOME "pwsh"
    }
}

# The .sh twin needs both bash and python3 (DD-4). Absence is a named SKIP, the
# existing twin-check degradation convention -- never a silent pass.
$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
$python3Command = Get-Command python3 -ErrorAction SilentlyContinue
$shTwinAvailable = ($null -ne $bashCommand) -and ($null -ne $python3Command)
$shTwinSkipReason = "bash and/or python3 absent from PATH"

# Capability probe for the unreadable-path fixture: POSIX mode bits only. On a
# host without chmod (Windows) or when the test process can read a 000-mode
# file anyway (running as root), the corresponding check is a named SKIP.
$unreadableFixtureSupported = $false
$chmodCommand = Get-Command chmod -ErrorAction SilentlyContinue
if ($null -ne $chmodCommand) {
    $probePath = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t002-probe-" + [guid]::NewGuid().ToString("N"))
    try {
        [System.IO.File]::WriteAllText($probePath, "probe", (New-Object System.Text.UTF8Encoding($false)))
        & $chmodCommand.Source "000" $probePath 2>$null | Out-Null
        try {
            [void][System.IO.File]::ReadAllBytes($probePath)
            $unreadableFixtureSupported = $false
        } catch {
            $unreadableFixtureSupported = $true
        }
    } catch {
        $unreadableFixtureSupported = $false
    } finally {
        if (Test-Path -LiteralPath $probePath) {
            & $chmodCommand.Source "600" $probePath 2>$null | Out-Null
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-EphemeralContractFile {
    # Expands a fixture here-string into a fresh temp file (DD-5). ASCII-only
    # content, written without a BOM so both twins see identical bytes.
    param([string]$Content, [string]$Extension = ".json")
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t002-" + [guid]::NewGuid().ToString("N") + $Extension)
    [System.IO.File]::WriteAllText($path, $Content, (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Remove-EphemeralPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function Invoke-CapturedProcess {
    # Runs a child process capturing stdout, stderr and exit code separately.
    # Deliberately NOT Start-Process: the assertions below depend on stdout
    # being empty and on stderr being exactly one line, so both streams must be
    # captured verbatim and independently.
    param([string]$FilePath, [string]$ArgumentString)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $ArgumentString
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
    $process.Dispose()
    return New-Object PSObject -Property @{
        ExitCode = $exitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Invoke-ValidatorPs1 {
    # $ContractPath omitted entirely reproduces the missing-argument case.
    param([string]$ContractPath)
    $arguments = '-NoProfile -NonInteractive -File "{0}"' -f $validatorPs1Path
    if ($PSBoundParameters.ContainsKey("ContractPath")) {
        $arguments = '-NoProfile -NonInteractive -File "{0}" "{1}"' -f $validatorPs1Path, $ContractPath
    }
    return Invoke-CapturedProcess -FilePath $powerShellHostPath -ArgumentString $arguments
}

function Invoke-ValidatorSh {
    param([string]$ContractPath)
    $arguments = '"{0}"' -f $validatorShPath
    if ($PSBoundParameters.ContainsKey("ContractPath")) {
        $arguments = '"{0}" "{1}"' -f $validatorShPath, $ContractPath
    }
    return Invoke-CapturedProcess -FilePath $bashCommand.Source -ArgumentString $arguments
}

function Get-StdErrViolationLines {
    param($Result)
    $normalized = ($Result.StdErr -replace "`r`n", "`n") -replace "`r", "`n"
    return @($normalized -split "`n" | Where-Object { $_.Length -gt 0 })
}

function Assert-FailClosed {
    # The single shared shape every fail-closed path must satisfy (DD-7):
    # exit 1, nothing on stdout, exactly one `RULE-ID: message` line on stderr,
    # and no stack trace or raw interpreter exception anywhere in stderr.
    param($Result, [string]$ExpectedRuleId)
    $Result.ExitCode | Should Be 1
    $Result.StdOut.Length | Should Be 0
    # @() re-wraps: PowerShell unrolls a one-element array returned from a
    # function, and a bare string has no .Count under Set-StrictMode.
    $lines = @(Get-StdErrViolationLines -Result $Result)
    $lines.Count | Should Be 1
    $lines[0] | Should Match ("^" + $ExpectedRuleId + ": \S.*$")
    $Result.StdErr | Should Not Match "Traceback"
    $Result.StdErr | Should Not Match "Exception"
    $Result.StdErr | Should Not Match "CategoryInfo"
    $Result.StdErr | Should Not Match "FullyQualifiedErrorId"
    $Result.StdErr | Should Not Match "ScriptStackTrace"
    $Result.StdErr | Should Not Match "at <ScriptBlock>"
    $Result.StdErr | Should Not Match "^\s+\+ "
}

# --- Fixture bodies (here-strings, DD-5) ------------------------------------

# AC-017 (1): a contract whose body stops mid-string. Syntactically invalid.
$fixtureTruncatedJson = @'
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/domain-story.md"] },
  "contexts": [
    { "name": "order-taking", "description": "Where the purchase promise is ma
'@

# AC-012: a well-formed v1 contract handed to the v2-only validator (DD-6).
$fixtureV1Contract = @'
{
  "schema": "domain-contract/v1",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/context-map.md"] },
  "contexts": [
    {
      "name": "order-taking",
      "description": "Where a purchase promise is recorded.",
      "terms": [
        { "canonical": "Order", "definition": "A recorded purchase promise." }
      ],
      "aggregates": []
    }
  ],
  "relations": []
}
'@

function New-OversizedContractFixture {
    # AC-017 (2): a contract file larger than the validator's 10 MiB ceiling.
    # Deliberately a COMPLETE, well-formed v2 contract whose only defect is its
    # size, so the rejection cannot be attributed to any other check -- the
    # padding lives inside a legal `meta.generated_from[0]` string value.
    param([int]$TargetBytes)
    $prefix = '{"schema":"domain-contract/v2","meta":{"version":"1.0.0","status":"Pending","generated_from":["'
    $suffix = '"]},"contexts":[{"name":"order-taking","description":"Where a purchase promise is recorded.","terms":[],"aggregates":[]}],"concepts":[{"id":"CONCEPT-ORDER","name":"Order","context":"order-taking","definition":"The promise to buy, as recorded at order time.","essence":"what was promised and at what price","responsibilities":["purchase intent"],"evidence":["domain-story:activity-1"]}]}'
    $padLength = $TargetBytes - $prefix.Length - $suffix.Length
    return $prefix + ("a" * $padLength) + $suffix
}

Describe "validate-domain-contract twins exist (TEST-017/TEST-012 preconditions, REQ-004)" {

    It "the .sh twin exists" {
        Test-Path $validatorShPath | Should Be $true
    }

    It "the .ps1 twin exists" {
        Test-Path $validatorPs1Path | Should Be $true
    }
}

Describe "validate-domain-contract fail-closed input handling (TEST-017, AC-017, REQ-004(a))" {

    Context "fixture 1 of 2 -- syntactically broken JSON (truncated body)" {

        It "ps1 twin: exits 1 with one V2-PARSE line, no stdout, no stack trace" {
            $fixture = New-EphemeralContractFile -Content $fixtureTruncatedJson
            try {
                $result = Invoke-ValidatorPs1 -ContractPath $fixture
                Assert-FailClosed -Result $result -ExpectedRuleId "V2-PARSE"
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }

        It "sh twin: exits 1 with one V2-PARSE line, no stdout, no stack trace" -Skip:(-not $shTwinAvailable) {
            $fixture = New-EphemeralContractFile -Content $fixtureTruncatedJson
            try {
                $result = Invoke-ValidatorSh -ContractPath $fixture
                Assert-FailClosed -Result $result -ExpectedRuleId "V2-PARSE"
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }
    }

    Context "fixture 2 of 2 -- a file larger than the 10 MiB ceiling" {

        It "the fixture really does exceed the ceiling (non-vacuity)" {
            $fixture = New-EphemeralContractFile -Content (New-OversizedContractFixture -TargetBytes ($maxContractBytes + 1))
            try {
                (Get-Item -LiteralPath $fixture).Length | Should BeGreaterThan $maxContractBytes
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }

        It "ps1 twin: exits 1 with one V2-INPUT-TOO-LARGE line, no stdout, no stack trace" {
            $fixture = New-EphemeralContractFile -Content (New-OversizedContractFixture -TargetBytes ($maxContractBytes + 1))
            try {
                $result = Invoke-ValidatorPs1 -ContractPath $fixture
                Assert-FailClosed -Result $result -ExpectedRuleId "V2-INPUT-TOO-LARGE"
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }

        It "sh twin: exits 1 with one V2-INPUT-TOO-LARGE line, no stdout, no stack trace" -Skip:(-not $shTwinAvailable) {
            $fixture = New-EphemeralContractFile -Content (New-OversizedContractFixture -TargetBytes ($maxContractBytes + 1))
            try {
                $result = Invoke-ValidatorSh -ContractPath $fixture
                Assert-FailClosed -Result $result -ExpectedRuleId "V2-INPUT-TOO-LARGE"
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }
    }
}

Describe "validate-domain-contract argument and path errors (REQ-004(a), Edge Cases fail-closed)" {

    Context "no argument" {

        It "ps1 twin: exits 1 with one V2-USAGE line" {
            Assert-FailClosed -Result (Invoke-ValidatorPs1) -ExpectedRuleId "V2-USAGE"
        }

        It "sh twin: exits 1 with one V2-USAGE line" -Skip:(-not $shTwinAvailable) {
            Assert-FailClosed -Result (Invoke-ValidatorSh) -ExpectedRuleId "V2-USAGE"
        }
    }

    Context "a path that does not exist" {

        It "ps1 twin: exits 1 with one V2-INPUT-NOT-FOUND line" {
            $missing = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t002-absent-" + [guid]::NewGuid().ToString("N") + ".json")
            Assert-FailClosed -Result (Invoke-ValidatorPs1 -ContractPath $missing) -ExpectedRuleId "V2-INPUT-NOT-FOUND"
        }

        It "sh twin: exits 1 with one V2-INPUT-NOT-FOUND line" -Skip:(-not $shTwinAvailable) {
            $missing = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t002-absent-" + [guid]::NewGuid().ToString("N") + ".json")
            Assert-FailClosed -Result (Invoke-ValidatorSh -ContractPath $missing) -ExpectedRuleId "V2-INPUT-NOT-FOUND"
        }
    }

    Context "a path that is a directory, not a contract file" {

        It "ps1 twin: exits 1 with one V2-INPUT-NOT-FILE line" {
            $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t002-dir-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                Assert-FailClosed -Result (Invoke-ValidatorPs1 -ContractPath $dir) -ExpectedRuleId "V2-INPUT-NOT-FILE"
            } finally {
                Remove-EphemeralPath -Path $dir
            }
        }

        It "sh twin: exits 1 with one V2-INPUT-NOT-FILE line" -Skip:(-not $shTwinAvailable) {
            $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t002-dir-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                Assert-FailClosed -Result (Invoke-ValidatorSh -ContractPath $dir) -ExpectedRuleId "V2-INPUT-NOT-FILE"
            } finally {
                Remove-EphemeralPath -Path $dir
            }
        }
    }

    Context "a regular file the process may not read (POSIX mode 000)" {

        It "ps1 twin: exits 1 with one V2-INPUT-UNREADABLE line [SKIPPED when chmod is unavailable or ineffective]" -Skip:(-not $unreadableFixtureSupported) {
            $fixture = New-EphemeralContractFile -Content "{}"
            try {
                & $chmodCommand.Source "000" $fixture | Out-Null
                Assert-FailClosed -Result (Invoke-ValidatorPs1 -ContractPath $fixture) -ExpectedRuleId "V2-INPUT-UNREADABLE"
            } finally {
                & $chmodCommand.Source "600" $fixture 2>$null | Out-Null
                Remove-EphemeralPath -Path $fixture
            }
        }

        It "sh twin: exits 1 with one V2-INPUT-UNREADABLE line [SKIPPED when chmod is unavailable or ineffective]" -Skip:(-not ($unreadableFixtureSupported -and $shTwinAvailable)) {
            $fixture = New-EphemeralContractFile -Content "{}"
            try {
                & $chmodCommand.Source "000" $fixture | Out-Null
                Assert-FailClosed -Result (Invoke-ValidatorSh -ContractPath $fixture) -ExpectedRuleId "V2-INPUT-UNREADABLE"
            } finally {
                & $chmodCommand.Source "600" $fixture 2>$null | Out-Null
                Remove-EphemeralPath -Path $fixture
            }
        }
    }
}

Describe "validate-domain-contract v2 version dispatch (TEST-012, AC-012, REQ-004(b), DD-6)" {

    It "the v1 fixture really declares domain-contract/v1 (non-vacuity)" {
        $fixture = New-EphemeralContractFile -Content $fixtureV1Contract
        try {
            $parsed = Get-Content -Raw -Encoding Utf8 $fixture | ConvertFrom-Json
            $parsed.schema | Should Be "domain-contract/v1"
        } finally {
            Remove-EphemeralPath -Path $fixture
        }
    }

    It "ps1 twin: rejects a domain-contract/v1 contract with one V2-WRONG-SCHEMA line naming the v2-only constraint" {
        $fixture = New-EphemeralContractFile -Content $fixtureV1Contract
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixture
            Assert-FailClosed -Result $result -ExpectedRuleId "V2-WRONG-SCHEMA"
            $line = @(Get-StdErrViolationLines -Result $result)[0]
            $line | Should Match "domain-contract/v1"
            $line | Should Match "domain-contract/v2 only"
        } finally {
            Remove-EphemeralPath -Path $fixture
        }
    }

    It "sh twin: rejects a domain-contract/v1 contract with one V2-WRONG-SCHEMA line naming the v2-only constraint" -Skip:(-not $shTwinAvailable) {
        $fixture = New-EphemeralContractFile -Content $fixtureV1Contract
        try {
            $result = Invoke-ValidatorSh -ContractPath $fixture
            Assert-FailClosed -Result $result -ExpectedRuleId "V2-WRONG-SCHEMA"
            $line = @(Get-StdErrViolationLines -Result $result)[0]
            $line | Should Match "domain-contract/v1"
            $line | Should Match "domain-contract/v2 only"
        } finally {
            Remove-EphemeralPath -Path $fixture
        }
    }
}

# ---------------------------------------------------------------------------
# T-003 (Issue #290, sdd-domain-concept-contract Phase 0): the ordered
# structural check pass, REQ-004 step (c), in both validator twins.
#
# requirements.md `## Field Definitions` is the authority for every type,
# pattern, required flag, minItems and minLength asserted below. REQ-004(c)
# fixes the ORDER -- JSON type conformance first, then required-key presence,
# then pattern / minLength / minItems -- and a value whose type does not
# conform must be recorded and then EXCLUDED from the later checks, so that a
# mistyped field can never reach a regex or a length test and raise a raw
# interpreter exception (security-spec.md fail-closed rule).
#
# Fixture allocation for this task (tasks.md `## Negative Fixture
# Allocation`): exactly 62 negative fixtures -- AC-024 x29, AC-014 x7,
# AC-021 x7, AC-023 x8, AC-020 x4, AC-018 x3, AC-019 x3, AC-016 x1. The
# base-acceptance check and the two-violation enumeration check are the
# tasks.md `### Done When` non-vacuity and enumeration items, NOT additional
# negative fixtures from that allocation table -- the same convention T-002
# used for its argument / path-error checks.
#
# AC-021 (1) `schema` absent and AC-024 (1) `schema` not a string are the two
# fixtures whose behaviour T-002's admission dispatch already implements; they
# are authored here against that existing behaviour rather than re-checked in
# the structural pass, which would double-report them.
#
# Every fixture is ONE single-point mutation of a common, fully valid base
# contract expressed as here-string tokens and expanded into a per-test
# temporary file the test deletes again (DD-5, INV-006). No permanent fixture
# directory is added. All fixture vocabulary is synthetic Purchase /
# Fulfillment domain nouns; no credential, token, personal, or customer-derived
# string appears in any of them (security-spec.md).
# ---------------------------------------------------------------------------

# Token table for the structural fixture corpus. `%TOKEN%` placeholders are
# expanded repeatedly until the body is literal JSON. Because a token name is
# always delimited by `%` on both sides and no token value contains a bare
# `%`, no token name can be confused with another.
$structuralFixtureTokens = [ordered]@{
    ROOT                   = '{%R_SCHEMA%%R_META%%R_CONTEXTS%%R_CONCEPTS%"relations": []}'
    R_SCHEMA               = '"schema": %SCHEMA_VALUE%, '
    SCHEMA_VALUE           = '"domain-contract/v2"'
    R_META                 = '"meta": %META%, '
    META                   = '{"version": %M_VERSION%, "status": %M_STATUS%, "generated_from": %M_GENERATED_FROM%}'
    M_VERSION              = '"1.0.0"'
    M_STATUS               = '"Pending"'
    M_GENERATED_FROM       = '["domain/domain-story.md"]'
    META_NO_VERSION        = '{"status": "Pending", "generated_from": ["domain/domain-story.md"]}'
    META_NO_STATUS         = '{"version": "1.0.0", "generated_from": ["domain/domain-story.md"]}'
    META_NO_GENERATED_FROM = '{"version": "1.0.0", "status": "Pending"}'
    R_CONTEXTS             = '"contexts": %CONTEXTS%, '
    CONTEXTS               = '[{"name": "order-taking", "description": "Where a purchase promise is recorded.", "terms": [{"canonical": "Order", "definition": "A recorded purchase promise.", "concept_id": %T_CONCEPT_ID%}], "aggregates": []}]'
    CONTEXTS_PLAIN         = '[{"name": "order-taking", "description": "Where a purchase promise is recorded.", "terms": [{"canonical": "Order", "definition": "A recorded purchase promise."}], "aggregates": []}]'
    T_CONCEPT_ID           = '"CONCEPT-ORDER"'
    R_CONCEPTS             = '"concepts": %CONCEPTS%, '
    CONCEPTS               = '[%CONCEPT_MAIN%, %CONCEPT_SECOND%]'
    CONCEPT_MAIN           = '{%C_ID%%C_NAME%%C_CONTEXT%%C_DEFINITION%%C_ESSENCE%%C_RESPONSIBILITIES%%C_EVIDENCE%%C_STAKEHOLDER%%C_DISTINGUISHED%"must_not_own": %C_MUST_NOT_OWN%}'
    CONCEPT_SECOND         = '{"id": "CONCEPT-FULFILLMENT", "name": "Fulfillment", "context": "order-taking", "definition": "The unit of delivery for a recorded promise.", "essence": "what and how much is delivered", "responsibilities": ["delivery quantity"], "evidence": ["domain-story:activity-4"]}'
    C_ID                   = '"id": "CONCEPT-ORDER", '
    C_NAME                 = '"name": "Order", '
    C_CONTEXT              = '"context": "order-taking", '
    C_DEFINITION           = '"definition": "The promise to buy, as recorded at order time.", '
    C_ESSENCE              = '"essence": "what was promised and at what price", '
    C_RESPONSIBILITIES     = '"responsibilities": ["purchase intent"], '
    C_EVIDENCE             = '"evidence": ["domain-story:activity-1"], '
    C_STAKEHOLDER          = '"stakeholder_perspectives": [{"actor": "purchasing", "concern": "price and quantity"}], '
    C_DISTINGUISHED        = '"distinguished_from": [{"concept_id": "CONCEPT-FULFILLMENT", "reasons": ["different lifecycle"]}], '
    C_MUST_NOT_OWN         = '["delivery quantity"]'
}

function New-StructuralFixtureJson {
    # Expands the token table into one fixture body. `Override` replaces the
    # named tokens; every other token keeps its base value, so each fixture
    # differs from a fully valid contract at exactly one point. An unknown
    # token name, or a token left unexpanded, throws instead of silently
    # producing a fixture that does not exercise the intended check.
    param([hashtable]$Override)
    $table = @{}
    foreach ($key in $structuralFixtureTokens.Keys) {
        $table[$key] = [string]$structuralFixtureTokens[$key]
    }
    if ($null -ne $Override) {
        foreach ($key in $Override.Keys) {
            if (-not $table.ContainsKey($key)) { throw ("unknown fixture token: " + $key) }
            $table[$key] = [string]$Override[$key]
        }
    }
    $text = '%ROOT%'
    for ($pass = 0; $pass -lt 12; $pass++) {
        $changed = $false
        foreach ($key in @($table.Keys)) {
            $token = '%' + $key + '%'
            if ($text.Contains($token)) {
                $text = $text.Replace($token, $table[$key])
                $changed = $true
            }
        }
        if (-not $changed) { break }
    }
    if ($text.Contains('%')) { throw ("unexpanded fixture token remains in: " + $text) }
    return $text
}

function New-StructuralFixtureFile {
    # Ephemeral expansion of one fixture (DD-5, INV-006). The file name is hex
    # and ASCII hyphens only -- no byte in 0x00-0x1F, which is legal on POSIX
    # but illegal on Win32 and would kill the whole .ps1 side there.
    param([hashtable]$Override)
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t003-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllText($path, (New-StructuralFixtureJson -Override $Override), (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Assert-StructuralViolation {
    # The shape every structural negative fixture must satisfy (DD-7): exit 1,
    # nothing on stdout, no stack trace or raw interpreter exception anywhere
    # on stderr, exactly ONE `RULE-ID: <field path>: ...` line for the check
    # under test, and no line at all carrying any rule id the check must stay
    # textually distinguishable from. The forbidden-rule assertions are what
    # prove REQ-004(c)'s precedence (a type failure is not reported as a
    # pattern or minLength failure) and the AC-014 / AC-016 / AC-019 / AC-023
    # requirement that adjacent failure paths be told apart by their wording.
    param($Result, [string]$RuleId, [string]$FieldPath, [string[]]$ForbiddenRuleIds, [string]$LineMustMatch)
    $Result.ExitCode | Should Be 1
    $Result.StdOut.Length | Should Be 0
    $Result.StdErr | Should Not Match "Traceback"
    $Result.StdErr | Should Not Match "Exception"
    $Result.StdErr | Should Not Match "CategoryInfo"
    $Result.StdErr | Should Not Match "FullyQualifiedErrorId"
    $Result.StdErr | Should Not Match "ScriptStackTrace"
    $Result.StdErr | Should Not Match "at <ScriptBlock>"
    $Result.StdErr | Should Not Match "^\s+\+ "
    $lines = @(Get-StdErrViolationLines -Result $Result)
    # -cmatch, not -match: the rule ids and the declared patterns are
    # case-significant and PowerShell's -match is case-insensitive.
    $expectedPrefix = "^" + [regex]::Escape($RuleId + ": " + $FieldPath + ":")
    $matched = @($lines | Where-Object { $_ -cmatch $expectedPrefix })
    $matched.Count | Should Be 1
    if (-not [string]::IsNullOrEmpty($LineMustMatch)) {
        $matched[0] | Should Match $LineMustMatch
    }
    foreach ($forbidden in $ForbiddenRuleIds) {
        @($lines | Where-Object { $_ -cmatch ("^" + [regex]::Escape($forbidden) + ":") }).Count | Should Be 0
    }
}

function New-StructuralFixtureCase {
    param(
        [string]$Ac,
        [string]$Case,
        [hashtable]$Override,
        [string]$Rule,
        [string]$Field,
        [string[]]$Forbidden = @(),
        [string]$LineMustMatch = ""
    )
    return New-Object PSObject -Property @{
        Ac            = $Ac
        Case          = $Case
        Override      = $Override
        Rule          = $Rule
        Field         = $Field
        Forbidden     = $Forbidden
        LineMustMatch = $LineMustMatch
    }
}

# --- The 62 structural negative fixtures ------------------------------------
#
# AC-024 (29): one per field that declares a JSON type. (9)(10)(11) must be
# reported as type violations rather than pattern violations and (17)(18)(19)
# as type violations rather than minLength violations -- that is the direct
# proof of REQ-004(c)'s precedence rule, expressed as a forbidden rule id.
$structuralFixtures = @(
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(1) root schema is not a string" `
        -Override @{ SCHEMA_VALUE = '2' } `
        -Rule "V2-TYPE-MISMATCH" -Field "schema" -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(2) root meta is not an object" `
        -Override @{ META = '"1.0.0"' } `
        -Rule "V2-TYPE-MISMATCH" -Field "meta" -Forbidden @("V2-MISSING-KEY") `
        -LineMustMatch "expected object, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(3) root contexts is not an array" `
        -Override @{ CONTEXTS = '"order-taking"' } `
        -Rule "V2-TYPE-MISMATCH" -Field "contexts" -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(4) root concepts is not an array" `
        -Override @{ CONCEPTS = '"CONCEPT-ORDER"'; CONTEXTS = '%CONTEXTS_PLAIN%' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts" -Forbidden @("V2-EMPTY-ARRAY", "V2-MISSING-KEY") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(5) meta.version is not a string" `
        -Override @{ M_VERSION = '100' } `
        -Rule "V2-TYPE-MISMATCH" -Field "meta.version" -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(6) meta.status is not a string" `
        -Override @{ M_STATUS = 'true' } `
        -Rule "V2-TYPE-MISMATCH" -Field "meta.status" -LineMustMatch "expected string, found boolean"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(7) meta.generated_from is neither a string nor the declared array" `
        -Override @{ M_GENERATED_FROM = '7' } `
        -Rule "V2-TYPE-MISMATCH" -Field "meta.generated_from" -Forbidden @("V2-EMPTY-ARRAY") `
        -LineMustMatch "expected array, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(8) a concepts[] element is not an object" `
        -Override @{ CONCEPTS = '[%CONCEPT_MAIN%, %CONCEPT_SECOND%, 42]' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[2]" -Forbidden @("V2-MISSING-KEY") `
        -LineMustMatch "expected object, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(9) concepts[].id is not a string -- reported as a type violation, not a pattern violation" `
        -Override @{ C_ID = '"id": 42, '; CONTEXTS = '%CONTEXTS_PLAIN%' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].id" -Forbidden @("V2-PATTERN") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(10) concepts[].name is not a string -- reported as a type violation, not a pattern violation" `
        -Override @{ C_NAME = '"name": 42, ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].name" -Forbidden @("V2-PATTERN") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(11) concepts[].context is not a string -- reported as a type violation, not a pattern violation" `
        -Override @{ C_CONTEXT = '"context": 42, ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].context" -Forbidden @("V2-PATTERN") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(12) concepts[].definition is not a string" `
        -Override @{ C_DEFINITION = '"definition": 42, ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].definition" -Forbidden @("V2-EMPTY-STRING") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(13) concepts[].essence is not a string" `
        -Override @{ C_ESSENCE = '"essence": 42, ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].essence" -Forbidden @("V2-EMPTY-STRING") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(14) concepts[].responsibilities is not an array" `
        -Override @{ C_RESPONSIBILITIES = '"responsibilities": "purchase intent", ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].responsibilities" -Forbidden @("V2-EMPTY-ARRAY", "V2-EMPTY-STRING") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(15) concepts[].evidence is not an array" `
        -Override @{ C_EVIDENCE = '"evidence": "domain-story:activity-1", ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].evidence" -Forbidden @("V2-EMPTY-ARRAY", "V2-EMPTY-STRING") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(16) concepts[].must_not_own is not an array" `
        -Override @{ C_MUST_NOT_OWN = '"delivery quantity"' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].must_not_own" -Forbidden @("V2-EMPTY-ARRAY", "V2-EMPTY-STRING") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(17) a concepts[].responsibilities element is not a string -- reported as a type violation, not a minLength violation" `
        -Override @{ C_RESPONSIBILITIES = '"responsibilities": [42], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].responsibilities[0]" -Forbidden @("V2-EMPTY-STRING", "V2-EMPTY-ARRAY") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(18) a concepts[].evidence element is not a string -- reported as a type violation, not a minLength violation" `
        -Override @{ C_EVIDENCE = '"evidence": [42], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].evidence[0]" -Forbidden @("V2-EMPTY-STRING", "V2-EMPTY-ARRAY") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(19) a concepts[].must_not_own element is not a string -- reported as a type violation, not a minLength violation" `
        -Override @{ C_MUST_NOT_OWN = '[42]' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].must_not_own[0]" -Forbidden @("V2-EMPTY-STRING", "V2-EMPTY-ARRAY") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(20) concepts[].stakeholder_perspectives is not an array" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": "purchasing", ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].stakeholder_perspectives" -Forbidden @("V2-MISSING-KEY", "V2-EMPTY-STRING") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(21) a stakeholder_perspectives element is not an object" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [42], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].stakeholder_perspectives[0]" -Forbidden @("V2-MISSING-KEY", "V2-EMPTY-STRING") `
        -LineMustMatch "expected object, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(22) stakeholder_perspectives[].actor is not a string" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [{"actor": 42, "concern": "price and quantity"}], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].stakeholder_perspectives[0].actor" -Forbidden @("V2-EMPTY-STRING") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(23) stakeholder_perspectives[].concern is not a string" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [{"actor": "purchasing", "concern": 42}], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].stakeholder_perspectives[0].concern" -Forbidden @("V2-EMPTY-STRING") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(24) concepts[].distinguished_from is not an array" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": "CONCEPT-FULFILLMENT", ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].distinguished_from" -Forbidden @("V2-MISSING-KEY", "V2-EMPTY-ARRAY") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(25) a distinguished_from element is not an object" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [42], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].distinguished_from[0]" -Forbidden @("V2-MISSING-KEY", "V2-EMPTY-ARRAY") `
        -LineMustMatch "expected object, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(26) distinguished_from[].concept_id is not a string" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": 42, "reasons": ["different lifecycle"]}], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].distinguished_from[0].concept_id" -Forbidden @("V2-PATTERN") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(27) distinguished_from[].reasons is not an array" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "CONCEPT-FULFILLMENT", "reasons": "different lifecycle"}], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].distinguished_from[0].reasons" -Forbidden @("V2-EMPTY-ARRAY", "V2-EMPTY-STRING") `
        -LineMustMatch "expected array, found string"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(28) a distinguished_from[].reasons element is not a string" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "CONCEPT-FULFILLMENT", "reasons": [42]}], ' } `
        -Rule "V2-TYPE-MISMATCH" -Field "concepts[0].distinguished_from[0].reasons[0]" -Forbidden @("V2-EMPTY-STRING", "V2-EMPTY-ARRAY") `
        -LineMustMatch "expected string, found number"),
    (New-StructuralFixtureCase -Ac "AC-024" -Case "(29) contexts[].terms[].concept_id is not a string" `
        -Override @{ T_CONCEPT_ID = '42' } `
        -Rule "V2-TYPE-MISMATCH" -Field "contexts[0].terms[0].concept_id" -Forbidden @("V2-PATTERN") `
        -LineMustMatch "expected string, found number"),

    # AC-014 (7): each required concept key absent. The key-absent wording must
    # be distinguishable from the invalid-value paths (AC-018 pattern, AC-023
    # empty string), so V2-TYPE-MISMATCH must not appear.
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(1) concepts[].id is absent" `
        -Override @{ C_ID = ''; CONTEXTS = '%CONTEXTS_PLAIN%' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].id" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(2) concepts[].name is absent" `
        -Override @{ C_NAME = '' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].name" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(3) concepts[].context is absent" `
        -Override @{ C_CONTEXT = '' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].context" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(4) concepts[].definition is absent" `
        -Override @{ C_DEFINITION = '' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].definition" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(5) concepts[].essence is absent" `
        -Override @{ C_ESSENCE = '' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].essence" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(6) concepts[].responsibilities is absent" `
        -Override @{ C_RESPONSIBILITIES = '' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].responsibilities" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),
    (New-StructuralFixtureCase -Ac "AC-014" -Case "(7) concepts[].evidence is absent" `
        -Override @{ C_EVIDENCE = '' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].evidence" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),

    # AC-021 (7): each root and meta required key absent. (4) must be
    # distinguishable from AC-016's empty concepts array by its rule id.
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(1) root schema is absent" `
        -Override @{ R_SCHEMA = '' } `
        -Rule "V2-MISSING-KEY" -Field "schema" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(2) root meta is absent" `
        -Override @{ R_META = '' } `
        -Rule "V2-MISSING-KEY" -Field "meta" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(3) root contexts is absent" `
        -Override @{ R_CONTEXTS = '' } `
        -Rule "V2-MISSING-KEY" -Field "contexts" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(4) root concepts is absent -- a different path from the empty concepts array" `
        -Override @{ R_CONCEPTS = ''; CONTEXTS = '%CONTEXTS_PLAIN%' } `
        -Rule "V2-MISSING-KEY" -Field "concepts" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(5) meta.version is absent" `
        -Override @{ META = '%META_NO_VERSION%' } `
        -Rule "V2-MISSING-KEY" -Field "meta.version" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(6) meta.status is absent" `
        -Override @{ META = '%META_NO_STATUS%' } `
        -Rule "V2-MISSING-KEY" -Field "meta.status" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-021" -Case "(7) meta.generated_from is absent" `
        -Override @{ META = '%META_NO_GENERATED_FROM%' } `
        -Rule "V2-MISSING-KEY" -Field "meta.generated_from" -Forbidden @("V2-TYPE-MISMATCH")),

    # AC-023 (8): every string that declares minLength 1, as an empty string.
    # (3)(4)(5)(8) keep the array non-empty so the minItems path (AC-019)
    # cannot be what fired.
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(1) concepts[].definition is an empty string" `
        -Override @{ C_DEFINITION = '"definition": "", ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].definition" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(2) concepts[].essence is an empty string" `
        -Override @{ C_ESSENCE = '"essence": "", ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].essence" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(3) a concepts[].responsibilities element is an empty string" `
        -Override @{ C_RESPONSIBILITIES = '"responsibilities": [""], ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].responsibilities[0]" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(4) a concepts[].evidence element is an empty string" `
        -Override @{ C_EVIDENCE = '"evidence": [""], ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].evidence[0]" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(5) a concepts[].must_not_own element is an empty string" `
        -Override @{ C_MUST_NOT_OWN = '[""]' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].must_not_own[0]" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(6) stakeholder_perspectives[].actor is an empty string" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [{"actor": "", "concern": "price and quantity"}], ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].stakeholder_perspectives[0].actor" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(7) stakeholder_perspectives[].concern is an empty string" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [{"actor": "purchasing", "concern": ""}], ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].stakeholder_perspectives[0].concern" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY")),
    (New-StructuralFixtureCase -Ac "AC-023" -Case "(8) a distinguished_from[].reasons element is an empty string" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "CONCEPT-FULFILLMENT", "reasons": [""]}], ' } `
        -Rule "V2-EMPTY-STRING" -Field "concepts[0].distinguished_from[0].reasons[0]" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),

    # AC-020 (4): required fields nested INSIDE the optional object arrays. The
    # optional array is present in every case -- the acceptance case where the
    # array is absent entirely is AC-026, owned by T-005.
    (New-StructuralFixtureCase -Ac "AC-020" -Case "(1) stakeholder_perspectives[].actor is absent" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [{"concern": "price and quantity"}], ' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].stakeholder_perspectives[0].actor" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-020" -Case "(2) stakeholder_perspectives[].concern is absent" `
        -Override @{ C_STAKEHOLDER = '"stakeholder_perspectives": [{"actor": "purchasing"}], ' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].stakeholder_perspectives[0].concern" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-020" -Case "(3) distinguished_from[].concept_id is absent" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"reasons": ["different lifecycle"]}], ' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].distinguished_from[0].concept_id" -Forbidden @("V2-TYPE-MISMATCH")),
    (New-StructuralFixtureCase -Ac "AC-020" -Case "(4) distinguished_from[].reasons is absent" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "CONCEPT-FULFILLMENT"}], ' } `
        -Rule "V2-MISSING-KEY" -Field "concepts[0].distinguished_from[0].reasons" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-ARRAY")),

    # AC-018 (3): the three REQ-002 patterns. The accepting boundary cases
    # (APIOrder, order-taking-2) are AC-003, owned by T-005.
    (New-StructuralFixtureCase -Ac "AC-018" -Case "(1) concepts[].id does not match the concept-id pattern" `
        -Override @{ C_ID = '"id": "concept-order", '; CONTEXTS = '%CONTEXTS_PLAIN%' } `
        -Rule "V2-PATTERN" -Field "concepts[0].id" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-018" -Case "(2) concepts[].name does not match the PascalCase pattern" `
        -Override @{ C_NAME = '"name": "order_item", ' } `
        -Rule "V2-PATTERN" -Field "concepts[0].name" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-018" -Case "(3) concepts[].context does not match the kebab-case pattern" `
        -Override @{ C_CONTEXT = '"context": "Order-Taking", ' } `
        -Rule "V2-PATTERN" -Field "concepts[0].context" -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING")),

    # AC-019 (3): the three arrays declaring minItems 1, empty. Distinguished
    # from key absence (AC-014 / AC-020) by rule id.
    (New-StructuralFixtureCase -Ac "AC-019" -Case "(1) concepts[].responsibilities is an empty array" `
        -Override @{ C_RESPONSIBILITIES = '"responsibilities": [], ' } `
        -Rule "V2-EMPTY-ARRAY" -Field "concepts[0].responsibilities" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-019" -Case "(2) concepts[].evidence is an empty array" `
        -Override @{ C_EVIDENCE = '"evidence": [], ' } `
        -Rule "V2-EMPTY-ARRAY" -Field "concepts[0].evidence" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-EMPTY-STRING")),
    (New-StructuralFixtureCase -Ac "AC-019" -Case "(3) distinguished_from[].reasons is an empty array" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "CONCEPT-FULFILLMENT", "reasons": []}], ' } `
        -Rule "V2-EMPTY-ARRAY" -Field "concepts[0].distinguished_from[0].reasons" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-EMPTY-STRING")),

    # AC-016 (1): the concepts key is present, so root required is satisfied
    # and minItems 1 is what must fire.
    (New-StructuralFixtureCase -Ac "AC-016" -Case "(1) concepts is an empty array" `
        -Override @{ CONCEPTS = '[]'; CONTEXTS = '%CONTEXTS_PLAIN%' } `
        -Rule "V2-EMPTY-ARRAY" -Field "concepts" -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY"))
)

Describe "T-003 structural negative fixture allocation (tasks.md Negative Fixture Allocation table)" {

    It "contributes exactly 62 negative fixtures" {
        $structuralFixtures.Count | Should Be 62
    }

    It "allocates 29 fixtures to AC-024 (type mismatch)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-024" }).Count | Should Be 29
    }

    It "allocates 7 fixtures to AC-014 (concept required key absent)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-014" }).Count | Should Be 7
    }

    It "allocates 7 fixtures to AC-021 (root and meta required key absent)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-021" }).Count | Should Be 7
    }

    It "allocates 8 fixtures to AC-023 (minLength)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-023" }).Count | Should Be 8
    }

    It "allocates 4 fixtures to AC-020 (nested required inside an optional array)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-020" }).Count | Should Be 4
    }

    It "allocates 3 fixtures to AC-018 (pattern)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-018" }).Count | Should Be 3
    }

    It "allocates 3 fixtures to AC-019 (minItems)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-019" }).Count | Should Be 3
    }

    It "allocates 1 fixture to AC-016 (empty concepts array)" {
        @($structuralFixtures | Where-Object { $_.Ac -eq "AC-016" }).Count | Should Be 1
    }

    It "gives every fixture a distinct contract body (no fixture silently duplicates another)" {
        $bodies = @($structuralFixtures | ForEach-Object { New-StructuralFixtureJson -Override $_.Override })
        @($bodies | Sort-Object -Unique).Count | Should Be 62
    }

    It "keeps every fixture body well-formed JSON, so only the declared structural defect is under test" {
        foreach ($structuralCase in $structuralFixtures) {
            $body = New-StructuralFixtureJson -Override $structuralCase.Override
            { ConvertFrom-Json -InputObject $body } | Should Not Throw
        }
    }
}

Describe "validate-domain-contract structural pass -- base fixture acceptance (non-vacuity for the 62 negatives)" {

    # Not one of the 62 allocated negative fixtures and not an AC-003..AC-026
    # positive: this is the non-vacuity guard that every negative fixture
    # differs from an ACCEPTED contract at exactly one point, so a rejection
    # cannot be attributed to anything but the mutation under test.

    It "ps1 twin: accepts the unmutated base contract with exit 0 and no output at all" {
        $fixturePath = New-StructuralFixtureFile -Override @{}
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixturePath
            $result.ExitCode | Should Be 0
            $result.StdOut.Length | Should Be 0
            $result.StdErr.Length | Should Be 0
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts the unmutated base contract with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-StructuralFixtureFile -Override @{}
        try {
            $result = Invoke-ValidatorSh -ContractPath $fixturePath
            $result.ExitCode | Should Be 0
            $result.StdOut.Length | Should Be 0
            $result.StdErr.Length | Should Be 0
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}

Describe "validate-domain-contract structural check pass (TEST-014/016/018/019/020/021/023/024, REQ-004(c))" {

    foreach ($structuralCase in $structuralFixtures) {
        $caseLabel = $structuralCase.Ac + " " + $structuralCase.Case

        It ("ps1 twin -- " + $caseLabel) {
            $fixturePath = New-StructuralFixtureFile -Override $structuralCase.Override
            try {
                Assert-StructuralViolation -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath) `
                    -RuleId $structuralCase.Rule -FieldPath $structuralCase.Field `
                    -ForbiddenRuleIds $structuralCase.Forbidden -LineMustMatch $structuralCase.LineMustMatch
            } finally {
                Remove-EphemeralPath -Path $fixturePath
            }
        }

        It ("sh twin -- " + $caseLabel) -Skip:(-not $shTwinAvailable) {
            $fixturePath = New-StructuralFixtureFile -Override $structuralCase.Override
            try {
                Assert-StructuralViolation -Result (Invoke-ValidatorSh -ContractPath $fixturePath) `
                    -RuleId $structuralCase.Rule -FieldPath $structuralCase.Field `
                    -ForbiddenRuleIds $structuralCase.Forbidden -LineMustMatch $structuralCase.LineMustMatch
            } finally {
                Remove-EphemeralPath -Path $fixturePath
            }
        }
    }
}

Describe "validate-domain-contract structural pass enumerates every violation (design.md Error Handling, DD-7)" {

    # tasks.md `### Done When` enumeration item, not one of the 62 allocated
    # fixtures: two INDEPENDENT defects in one contract must produce two
    # stderr lines, proving the pass does not stop at the first violation.
    $enumerationOverride = @{ C_NAME = '"name": 42, '; C_DEFINITION = '"definition": "", ' }

    It "ps1 twin: a contract with two independent violations produces exactly two stderr lines" {
        $fixturePath = New-StructuralFixtureFile -Override $enumerationOverride
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixturePath
            $result.ExitCode | Should Be 1
            $result.StdOut.Length | Should Be 0
            $lines = @(Get-StdErrViolationLines -Result $result)
            $lines.Count | Should Be 2
            @($lines | Where-Object { $_ -cmatch "^V2-TYPE-MISMATCH: concepts\[0\]\.name:" }).Count | Should Be 1
            @($lines | Where-Object { $_ -cmatch "^V2-EMPTY-STRING: concepts\[0\]\.definition:" }).Count | Should Be 1
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: a contract with two independent violations produces exactly two stderr lines" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-StructuralFixtureFile -Override $enumerationOverride
        try {
            $result = Invoke-ValidatorSh -ContractPath $fixturePath
            $result.ExitCode | Should Be 1
            $result.StdOut.Length | Should Be 0
            $lines = @(Get-StdErrViolationLines -Result $result)
            $lines.Count | Should Be 2
            @($lines | Where-Object { $_ -cmatch "^V2-TYPE-MISMATCH: concepts\[0\]\.name:" }).Count | Should Be 1
            @($lines | Where-Object { $_ -cmatch "^V2-EMPTY-STRING: concepts\[0\]\.definition:" }).Count | Should Be 1
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}
