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

# ---------------------------------------------------------------------------
# T-004 (Issue #290, sdd-domain-concept-contract Phase 0): the cross-reference
# integrity pass, REQ-004 steps (d) through (i), in both validator twins,
# plus the pattern check for the two reference fields that share the concept-id
# pattern (AC-022 -- left to this task by T-003).
#
# The six checks are the entire reason this validator exists rather than a
# plain JSON Schema run: draft-07 cannot express referential integrity
# (design.md DD-1, INV-003), so duplicate ids, dangling context /
# distinguished_from / term references, self-contradictory responsibility
# sets, and within-context name collisions are caught here or nowhere.
#
# Fixture allocation for this task (tasks.md `## Negative Fixture
# Allocation`): exactly 8 negative fixtures -- AC-006 x1, AC-007 x1, AC-008 x1,
# AC-009 x1, AC-010 x1, AC-011 x1, AC-022 x2. The two positive control
# contracts below (same name in two different contexts; a case- and
# whitespace-differing near-duplicate responsibility) are the tasks.md
# `### Done When` cross-context-permissiveness and exact-string-equality
# items, NOT additional negative fixtures from that allocation table -- the
# same convention T-002 used for its argument / path-error checks and T-003
# for its base-acceptance and enumeration checks.
#
# Every fixture is built from the SAME base contract token table and the same
# expander T-003 authored, so a T-004 negative and a T-003 negative are both
# single-point mutations of one accepted contract, and the base-acceptance
# check above is the non-vacuity guard for both corpora (DD-5, INV-006 --
# fixtures stay ephemeral, no permanent fixture directory is added). All
# fixture vocabulary is synthetic Purchase / Fulfillment / Book domain nouns;
# no credential, token, personal, or customer-derived string appears in any of
# them (security-spec.md).
#
# Two discriminations are load-bearing and are asserted as forbidden rule ids
# rather than merely described:
#   1. A malformed reference (AC-022) is a PATTERN violation; a well-formed
#      but unresolvable reference (AC-008 / AC-009) is a DANGLING violation.
#      Neither fixture may produce the other's rule id.
#   2. The same concept `name` in two DIFFERENT contexts is not a violation at
#      all (requirements.md Edge Cases, INV-012). Only same-name-same-context
#      is. The negative proof is here; the positive proof is T-005's AC-005.
# ---------------------------------------------------------------------------

function New-CrossReferenceFixtureFile {
    # Ephemeral expansion of one T-004 fixture through T-003's token expander
    # (DD-5, INV-006). The file name is hex and ASCII hyphens only -- no byte
    # in 0x00-0x1F, which is legal on POSIX but illegal on Win32 and would kill
    # the whole .ps1 side there.
    param([hashtable]$Override)
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t004-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllText($path, (New-StructuralFixtureJson -Override $Override), (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function New-CrossReferenceExpectation {
    param([string]$Rule, [string]$FieldPath, [string]$LineMustMatch = "")
    return New-Object PSObject -Property @{
        Rule          = $Rule
        FieldPath     = $FieldPath
        LineMustMatch = $LineMustMatch
    }
}

function New-CrossReferenceFixtureCase {
    param(
        [string]$Ac,
        [string]$Case,
        [hashtable]$Override,
        [object[]]$Expected,
        [string[]]$Forbidden = @()
    )
    return New-Object PSObject -Property @{
        Ac        = $Ac
        Case      = $Case
        Override  = $Override
        Expected  = $Expected
        Forbidden = $Forbidden
    }
}

function Assert-CrossReferenceViolations {
    # The shape every cross-reference negative fixture must satisfy (DD-7):
    # exit 1, nothing on stdout, no stack trace or raw interpreter exception
    # anywhere on stderr, and stderr carrying EXACTLY the expected violation
    # lines -- no more and no fewer. The total-line assertion is strict here
    # (unlike T-003's presence-scoped helper) because every fixture below is a
    # single-point mutation whose complete expected output is known: a stray
    # extra line would mean a cross-reference check fired on a value the
    # mutation did not touch.
    param($Result, [object[]]$Expected, [string[]]$ForbiddenRuleIds)
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
    $lines.Count | Should Be $Expected.Count
    foreach ($expectation in $Expected) {
        # -cmatch, not -match: the rule ids and the declared patterns are
        # case-significant and PowerShell's -match is case-insensitive.
        $expectedPrefix = "^" + [regex]::Escape($expectation.Rule + ": " + $expectation.FieldPath + ":")
        $matched = @($lines | Where-Object { $_ -cmatch $expectedPrefix })
        $matched.Count | Should Be 1
        if (-not [string]::IsNullOrEmpty($expectation.LineMustMatch)) {
            @($matched | Where-Object { $_ -cmatch $expectation.LineMustMatch }).Count | Should Be 1
        }
    }
    foreach ($forbidden in $ForbiddenRuleIds) {
        @($lines | Where-Object { $_ -cmatch ("^" + [regex]::Escape($forbidden) + ":") }).Count | Should Be 0
    }
}

# --- The 8 cross-reference negative fixtures --------------------------------

$crossReferenceFixtures = @(
    # AC-006 (1), REQ-004(d): a third concept re-uses the id concepts[0]
    # already declared. Its `name` is distinct so that the duplicate-id check
    # is unambiguously what fired, and every reference in the contract still
    # resolves.
    (New-CrossReferenceFixtureCase -Ac "AC-006" -Case "(1) two concepts declare the same id -- stderr names the duplicated id" `
        -Override @{ CONCEPTS = '[%CONCEPT_MAIN%, %CONCEPT_SECOND%, {"id": "CONCEPT-ORDER", "name": "Placement", "context": "order-taking", "definition": "Where a book sits on a shelf.", "essence": "where an item is placed", "responsibilities": ["shelf position"], "evidence": ["domain-story:activity-7"]}]' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-DUP-CONCEPT-ID" -FieldPath "concepts[2].id" `
                -LineMustMatch "id CONCEPT-ORDER is already declared by an earlier concept")
        ) `
        -Forbidden @("V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-PATTERN", "V2-DUP-NAME-IN-CONTEXT", "V2-DANGLING-CONTEXT", "V2-DANGLING-DISTINCTION", "V2-DANGLING-TERM")),

    # AC-007 (1), REQ-004(e): `shipping` is a well-formed kebab-case context
    # name -- so the pattern check cannot be what fires -- but no contexts[]
    # entry declares it.
    (New-CrossReferenceFixtureCase -Ac "AC-007" -Case "(1) concepts[].context names a context no contexts[] entry declares" `
        -Override @{ C_CONTEXT = '"context": "shipping", ' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-DANGLING-CONTEXT" -FieldPath "concepts[0].context" `
                -LineMustMatch "context shipping is not declared in contexts")
        ) `
        -Forbidden @("V2-PATTERN", "V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-DUP-NAME-IN-CONTEXT", "V2-DUP-CONCEPT-ID")),

    # AC-008 (1), REQ-004(f): ONE fixture carrying both sub-cases the AC names
    # -- entry [0] points at the concept's own id (requirements.md Edge Cases
    # declares a distinguished_from entry that points at its own concept
    # invalid), entry [1] points at an id no concept declares. Both are well
    # formed, so neither can be reported as
    # a pattern violation; the two messages differ so a reader can tell the
    # self-reference from the unresolvable reference.
    (New-CrossReferenceFixtureCase -Ac "AC-008" -Case "(1) distinguished_from points at the concept itself and at an undeclared id" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "CONCEPT-ORDER", "reasons": ["a concept is never distinguished from itself"]}, {"concept_id": "CONCEPT-GHOST", "reasons": ["no concept declares this id"]}], ' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-DANGLING-DISTINCTION" -FieldPath "concepts[0].distinguished_from[0].concept_id" `
                -LineMustMatch "is the concept's own id; a concept cannot be distinguished from itself"),
            (New-CrossReferenceExpectation -Rule "V2-DANGLING-DISTINCTION" -FieldPath "concepts[0].distinguished_from[1].concept_id" `
                -LineMustMatch "CONCEPT-GHOST does not resolve to any declared concept id")
        ) `
        -Forbidden @("V2-PATTERN", "V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-DANGLING-TERM", "V2-DUP-CONCEPT-ID")),

    # AC-009 (1), REQ-003 / REQ-004(g): a well-formed term reference to an id
    # no concept declares.
    (New-CrossReferenceFixtureCase -Ac "AC-009" -Case "(1) contexts[].terms[].concept_id names an id no concept declares" `
        -Override @{ T_CONCEPT_ID = '"CONCEPT-GHOST"' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-DANGLING-TERM" -FieldPath "contexts[0].terms[0].concept_id" `
                -LineMustMatch "CONCEPT-GHOST does not resolve to any declared concept id")
        ) `
        -Forbidden @("V2-PATTERN", "V2-TYPE-MISMATCH", "V2-MISSING-KEY", "V2-DANGLING-DISTINCTION", "V2-DANGLING-CONTEXT")),

    # AC-010 (1), REQ-004(h): the identical string "purchase intent" is both a
    # responsibility of concepts[0] and one of its must_not_own entries. Exact
    # string equality -- the accepted near-duplicate control below proves the
    # comparison is neither case-folded nor whitespace-normalized.
    (New-CrossReferenceFixtureCase -Ac "AC-010" -Case "(1) one concept lists the identical string in responsibilities and must_not_own" `
        -Override @{ C_MUST_NOT_OWN = '["purchase intent"]' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-SELF-CONTRADICTION" -FieldPath "concepts[0]" `
                -LineMustMatch "purchase intent appears in both responsibilities and must_not_own")
        ) `
        -Forbidden @("V2-TYPE-MISMATCH", "V2-EMPTY-STRING", "V2-EMPTY-ARRAY", "V2-MISSING-KEY", "V2-DUP-NAME-IN-CONTEXT")),

    # AC-011 (1), REQ-004(i): two concepts carrying the name `Order` in the one
    # context `order-taking`. Their ids stay distinct so the duplicate-id check
    # cannot be what fired.
    (New-CrossReferenceFixtureCase -Ac "AC-011" -Case "(1) two concepts share a name inside one context" `
        -Override @{ CONCEPT_SECOND = '{"id": "CONCEPT-FULFILLMENT", "name": "Order", "context": "order-taking", "definition": "The unit of delivery for a recorded promise.", "essence": "what and how much is delivered", "responsibilities": ["delivery quantity"], "evidence": ["domain-story:activity-4"]}' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-DUP-NAME-IN-CONTEXT" -FieldPath "concepts[1].name" `
                -LineMustMatch "name Order is already declared by another concept in context order-taking")
        ) `
        -Forbidden @("V2-DUP-CONCEPT-ID", "V2-TYPE-MISMATCH", "V2-PATTERN", "V2-MISSING-KEY", "V2-DANGLING-CONTEXT")),

    # AC-022 (1 of 2), REQ-004(c) applied to a reference field: the value is
    # malformed rather than unresolvable, so it must be reported as a PATTERN
    # violation and the dangling check must not also fire on it.
    (New-CrossReferenceFixtureCase -Ac "AC-022" -Case "(1) distinguished_from[].concept_id violates the concept-id pattern -- a pattern violation, not a dangling reference" `
        -Override @{ C_DISTINGUISHED = '"distinguished_from": [{"concept_id": "concept-order", "reasons": ["different lifecycle"]}], ' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-PATTERN" -FieldPath "concepts[0].distinguished_from[0].concept_id" `
                -LineMustMatch "value concept-order does not match")
        ) `
        -Forbidden @("V2-DANGLING-DISTINCTION", "V2-DANGLING-TERM", "V2-TYPE-MISMATCH", "V2-MISSING-KEY")),

    # AC-022 (2 of 2): the same discrimination on the other reference field.
    (New-CrossReferenceFixtureCase -Ac "AC-022" -Case "(2) contexts[].terms[].concept_id violates the concept-id pattern -- a pattern violation, not a dangling reference" `
        -Override @{ T_CONCEPT_ID = '"concept-order"' } `
        -Expected @(
            (New-CrossReferenceExpectation -Rule "V2-PATTERN" -FieldPath "contexts[0].terms[0].concept_id" `
                -LineMustMatch "value concept-order does not match")
        ) `
        -Forbidden @("V2-DANGLING-TERM", "V2-DANGLING-DISTINCTION", "V2-TYPE-MISMATCH", "V2-MISSING-KEY"))
)

# --- The two positive control contracts (tasks.md `### Done When`) -----------

# Cross-context permissiveness: the SAME concept name in two DIFFERENT
# contexts must not be reported by the AC-011 duplicate-name check
# (requirements.md Edge Cases, INV-012). This is the negative proof -- that
# the check does not fire; T-005's AC-005 owns the positive capability proof.
$crossContextSameNameOverride = @{
    CONTEXTS       = '[{"name": "order-taking", "description": "Where a purchase promise is recorded.", "terms": [{"canonical": "Order", "definition": "A recorded purchase promise.", "concept_id": "CONCEPT-ORDER"}], "aggregates": []}, {"name": "shipping", "description": "Where a recorded promise is delivered.", "terms": [], "aggregates": []}]'
    CONCEPT_SECOND = '{"id": "CONCEPT-FULFILLMENT", "name": "Order", "context": "shipping", "definition": "The unit of delivery for a recorded promise.", "essence": "what and how much is delivered", "responsibilities": ["delivery quantity"], "evidence": ["domain-story:activity-4"]}'
}

# Exact string equality for REQ-004(h): neither entry equals "purchase intent"
# as a string, though one differs only in case and the other only in
# surrounding whitespace. A case-folding or trimming comparison would reject
# this contract; an exact one accepts it.
$exactStringEqualityOverride = @{ C_MUST_NOT_OWN = '["Purchase Intent", " purchase intent "]' }

Describe "T-004 cross-reference negative fixture allocation (tasks.md Negative Fixture Allocation table)" {

    It "contributes exactly 8 negative fixtures" {
        $crossReferenceFixtures.Count | Should Be 8
    }

    It "allocates 1 fixture to AC-006 (duplicate concept id)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-006" }).Count | Should Be 1
    }

    It "allocates 1 fixture to AC-007 (dangling concept.context)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-007" }).Count | Should Be 1
    }

    It "allocates 1 fixture to AC-008 (dangling distinguished_from.concept_id, self-reference included)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-008" }).Count | Should Be 1
    }

    It "allocates 1 fixture to AC-009 (dangling term.concept_id)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-009" }).Count | Should Be 1
    }

    It "allocates 1 fixture to AC-010 (responsibilities / must_not_own self-contradiction)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-010" }).Count | Should Be 1
    }

    It "allocates 1 fixture to AC-011 (duplicate name within one context)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-011" }).Count | Should Be 1
    }

    It "allocates 2 fixtures to AC-022 (reference-field pattern violations)" {
        @($crossReferenceFixtures | Where-Object { $_.Ac -eq "AC-022" }).Count | Should Be 2
    }

    It "gives every fixture a distinct contract body (no fixture silently duplicates another)" {
        # -CaseSensitive: two fixture bodies differing only in the case of a
        # reference value are genuinely different fixtures here, so the
        # default case-insensitive uniqueness test would under-count them.
        $bodies = @($crossReferenceFixtures | ForEach-Object { New-StructuralFixtureJson -Override $_.Override })
        @($bodies | Sort-Object -Unique -CaseSensitive).Count | Should Be 8
    }

    It "keeps every fixture body well-formed JSON, so only the declared cross-reference defect is under test" {
        foreach ($crossCase in $crossReferenceFixtures) {
            $body = New-StructuralFixtureJson -Override $crossCase.Override
            { ConvertFrom-Json -InputObject $body } | Should Not Throw
        }
    }

    It "makes every fixture a real mutation of the accepted base contract" {
        # -ceq, not `Should Not Be`: Pester's Be compares case-insensitively,
        # and the AC-022 (2) fixture differs from the base contract ONLY in the
        # case of its term reference value -- which is precisely the mutation
        # under test.
        $baseBody = New-StructuralFixtureJson -Override @{}
        foreach ($crossCase in $crossReferenceFixtures) {
            ((New-StructuralFixtureJson -Override $crossCase.Override) -ceq $baseBody) | Should Be $false
        }
    }
}

Describe "validate-domain-contract cross-reference integrity pass (TEST-006/007/008/009/010/011/022, REQ-004(d)-(i))" {

    foreach ($crossCase in $crossReferenceFixtures) {
        $crossLabel = $crossCase.Ac + " " + $crossCase.Case

        It ("ps1 twin -- " + $crossLabel) {
            $fixturePath = New-CrossReferenceFixtureFile -Override $crossCase.Override
            try {
                Assert-CrossReferenceViolations -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath) `
                    -Expected $crossCase.Expected -ForbiddenRuleIds $crossCase.Forbidden
            } finally {
                Remove-EphemeralPath -Path $fixturePath
            }
        }

        It ("sh twin -- " + $crossLabel) -Skip:(-not $shTwinAvailable) {
            $fixturePath = New-CrossReferenceFixtureFile -Override $crossCase.Override
            try {
                Assert-CrossReferenceViolations -Result (Invoke-ValidatorSh -ContractPath $fixturePath) `
                    -Expected $crossCase.Expected -ForbiddenRuleIds $crossCase.Forbidden
            } finally {
                Remove-EphemeralPath -Path $fixturePath
            }
        }
    }
}

Describe "validate-domain-contract permits the same concept name in different contexts (tasks.md Done When; INV-012)" {

    It "the control contract really does carry one name in two different contexts (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject (New-StructuralFixtureJson -Override $crossContextSameNameOverride)
        $names = @($document.concepts | ForEach-Object { $_.name })
        $contexts = @($document.concepts | ForEach-Object { $_.context })
        $names.Count | Should Be 2
        $names[0] | Should Be $names[1]
        $contexts[0] | Should Not Be $contexts[1]
        @($document.concepts | ForEach-Object { $_.id } | Sort-Object -Unique).Count | Should Be 2
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-CrossReferenceFixtureFile -Override $crossContextSameNameOverride
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixturePath
            $result.ExitCode | Should Be 0
            $result.StdOut.Length | Should Be 0
            $result.StdErr.Length | Should Be 0
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-CrossReferenceFixtureFile -Override $crossContextSameNameOverride
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

Describe "validate-domain-contract compares responsibilities and must_not_own by exact string equality (REQ-004(h))" {

    It "the control contract's must_not_own entries differ from the responsibility only in case and surrounding whitespace (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject (New-StructuralFixtureJson -Override $exactStringEqualityOverride)
        $responsibilities = @($document.concepts[0].responsibilities)
        $forbidden = @($document.concepts[0].must_not_own)
        $responsibilities[0] | Should Be "purchase intent"
        $forbidden.Count | Should Be 2
        @($forbidden | Where-Object { $_ -ceq "purchase intent" }).Count | Should Be 0
        @($forbidden | Where-Object { $_.Trim().ToLowerInvariant() -ceq "purchase intent" }).Count | Should Be 2
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-CrossReferenceFixtureFile -Override $exactStringEqualityOverride
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixturePath
            $result.ExitCode | Should Be 0
            $result.StdOut.Length | Should Be 0
            $result.StdErr.Length | Should Be 0
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-CrossReferenceFixtureFile -Override $exactStringEqualityOverride
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

# ---------------------------------------------------------------------------
# T-005 (Issue #290, sdd-domain-concept-contract Phase 0): the positive
# fixture corpus (REQ-005), the twin-parity harness across the full 78-item
# corpus (REQ-006, AC-013), and the REQ-007 non-regression closure (AC-015).
#
# The positive corpus proves the validator is not stuck-shut: a fully
# populated contract, an all-optionals-absent contract, a cross-context
# same-name contract, a term-to-concept link, and the two pattern boundary
# values must all be accepted with exit 0. Per this task's Out of Scope, no
# change to either validator twin or to the schema file is made here -- if
# any of the five families below were rejected, that would be a defect in
# T-002, T-003, or T-004, reported rather than worked around.
#
# Every fixture is a heredoc here-string, mktemp-scoped through the SAME
# New-EphemeralContractFile / Remove-EphemeralPath pair T-002 authored (DD-5,
# INV-006 -- no permanent fixture directory is added). All fixture vocabulary
# is synthetic Purchase / Fulfillment / Book / Placement domain nouns; no
# credential, token, personal, or customer-derived string appears in any of
# them (security-spec.md).
# ---------------------------------------------------------------------------

# The four INV-004 v1 consumers (investigation.md INV-004) and the eleven
# pre-existing tests/sdd-domain/ suites (this feature's own suite,
# contract-v2-schema.Tests.ps1, is excluded -- it is this feature's output,
# not a pre-existing suite). Used by the AC-015 non-regression closure below.
$inv004ConsumerPaths = @(
    "plugins/sdd-domain/skills/domain-sync/SKILL.md",
    "plugins/sdd-domain/agents/domain-reviewer-a.md",
    "plugins/sdd-domain/skills/domain-interviewer/SKILL.md",
    "plugins/sdd-quality-loop/scripts/check-domain-conformance.sh"
)
$preExistingSuitePaths = @(
    "tests/sdd-domain/absence-regression.Tests.ps1",
    "tests/sdd-domain/artifact-set.Tests.ps1",
    "tests/sdd-domain/check-domain-conformance.Tests.ps1",
    "tests/sdd-domain/contract-schema.Tests.ps1",
    "tests/sdd-domain/cross-model-gate.Tests.ps1",
    "tests/sdd-domain/domain-review-loop.Tests.ps1",
    "tests/sdd-domain/domain-sync.Tests.ps1",
    "tests/sdd-domain/drift-metrics.Tests.ps1",
    "tests/sdd-domain/reverse-seed.Tests.ps1",
    "tests/sdd-domain/template-language.Tests.ps1",
    "tests/sdd-domain/update-mode.Tests.ps1"
)
$v1SuiteTestsPath = Join-Path $repositoryRoot "tests/sdd-domain/contract-schema.Tests.ps1"
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
$gitAvailable = ($null -ne $gitCommand)

# --- The 5 positive fixture bodies (here-strings, DD-5) ---------------------

# AC-003 (REQ-002, REQ-005(a)): Order carries all 7 required fields and all 3
# optional fields populated (must_not_own, stakeholder_perspectives,
# distinguished_from), Fulfillment mirrors it with must_not_own naming
# purchase price, and the two are mutually distinguished_from each other. A
# third concept APIOrder (consecutive-uppercase name) inside a third context
# order-taking-2 (digit segment) supplies the pattern boundary positives
# AC-003 also requires.
$fixtureAc003PurchaseFulfillment = @'
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/domain-story.md"] },
  "contexts": [
    {
      "name": "order-taking",
      "description": "Where the purchase promise is made.",
      "terms": [
        { "canonical": "Order", "definition": "A recorded purchase promise.", "concept_id": "CONCEPT-ORDER" }
      ],
      "aggregates": []
    },
    {
      "name": "shipping",
      "description": "Where a recorded promise is delivered.",
      "terms": [],
      "aggregates": []
    },
    {
      "name": "order-taking-2",
      "description": "A second order-taking style context, proving the digit-segment context pattern is accepted.",
      "terms": [],
      "aggregates": []
    }
  ],
  "concepts": [
    {
      "id": "CONCEPT-ORDER",
      "name": "Order",
      "context": "order-taking",
      "definition": "The promise to buy, as recorded at order time.",
      "essence": "what was promised and at what price",
      "responsibilities": ["purchase intent", "purchase price"],
      "must_not_own": ["delivery quantity", "delivery state"],
      "stakeholder_perspectives": [
        { "actor": "purchasing", "concern": "price and quantity" },
        { "actor": "shipping", "concern": "destination and delivery date" }
      ],
      "distinguished_from": [
        { "concept_id": "CONCEPT-FULFILLMENT", "reasons": ["different reason for change", "different lifecycle", "different stakeholder perspective"] }
      ],
      "evidence": ["domain-story:activity-1"]
    },
    {
      "id": "CONCEPT-FULFILLMENT",
      "name": "Fulfillment",
      "context": "shipping",
      "definition": "The unit of delivery for a recorded promise.",
      "essence": "what and how much is delivered",
      "responsibilities": ["delivery quantity", "delivery state"],
      "must_not_own": ["purchase price", "purchase intent"],
      "stakeholder_perspectives": [
        { "actor": "warehouse", "concern": "what remains to be delivered" }
      ],
      "distinguished_from": [
        { "concept_id": "CONCEPT-ORDER", "reasons": ["different reason for change", "different lifecycle", "different stakeholder perspective"] }
      ],
      "evidence": ["domain-story:activity-4"]
    },
    {
      "id": "CONCEPT-APIORDER",
      "name": "APIOrder",
      "context": "order-taking-2",
      "definition": "The API representation of the order, exercising the concept-name pattern boundary.",
      "essence": "the API client's view of the order",
      "responsibilities": ["API payload shape"],
      "evidence": ["domain-story:activity-9"]
    }
  ],
  "relations": []
}
'@

# AC-004 (REQ-005(b)): Book.must_not_own names display position; Placement
# holds the ordering responsibility (display position and shelf ordering).
$fixtureAc004BookBookshelf = @'
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/domain-story.md"] },
  "contexts": [
    {
      "name": "shelving",
      "description": "Where books are physically arranged on a shelf.",
      "terms": [],
      "aggregates": []
    }
  ],
  "concepts": [
    {
      "id": "CONCEPT-BOOK",
      "name": "Book",
      "context": "shelving",
      "definition": "A single physical or catalog copy of a title.",
      "essence": "what title and copy this is",
      "responsibilities": ["title", "author", "isbn"],
      "must_not_own": ["display position", "shelf ordering"],
      "distinguished_from": [
        { "concept_id": "CONCEPT-PLACEMENT", "reasons": ["different reason for change", "different lifecycle"] }
      ],
      "evidence": ["domain-story:activity-2"]
    },
    {
      "id": "CONCEPT-PLACEMENT",
      "name": "Placement",
      "context": "shelving",
      "definition": "Where a book currently sits on a shelf.",
      "essence": "which shelf and position a book occupies",
      "responsibilities": ["display position", "shelf ordering"],
      "distinguished_from": [
        { "concept_id": "CONCEPT-BOOK", "reasons": ["different reason for change", "different lifecycle"] }
      ],
      "evidence": ["domain-story:activity-3"]
    }
  ],
  "relations": []
}
'@

# AC-005 (REQ-002, REQ-005(c)): the concept name Order appears in two
# different contexts under two distinct ids -- the positive pair to T-004's
# AC-011 negative (same name inside ONE context).
$fixtureAc005CrossContextSameName = @'
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/domain-story.md"] },
  "contexts": [
    { "name": "order-taking", "description": "Where the purchase promise is made.", "terms": [], "aggregates": [] },
    { "name": "shipping", "description": "Where a recorded promise is delivered.", "terms": [], "aggregates": [] }
  ],
  "concepts": [
    {
      "id": "CONCEPT-ORDER-PURCHASE",
      "name": "Order",
      "context": "order-taking",
      "definition": "The promise to buy, as recorded at order time.",
      "essence": "what was promised and at what price",
      "responsibilities": ["purchase intent"],
      "evidence": ["domain-story:activity-1"]
    },
    {
      "id": "CONCEPT-ORDER-SHIPPING",
      "name": "Order",
      "context": "shipping",
      "definition": "The unit of delivery tracked inside the shipping context, locally called an order.",
      "essence": "what the warehouse is told to move",
      "responsibilities": ["warehouse pick list"],
      "evidence": ["domain-story:activity-5"]
    }
  ],
  "relations": []
}
'@

# AC-025 (REQ-001, REQ-003, REQ-005(e)): contexts[].terms[].concept_id
# resolves to a declared concept id.
$fixtureAc025TermConceptLink = @'
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/domain-story.md"] },
  "contexts": [
    {
      "name": "order-taking",
      "description": "Where the purchase promise is made.",
      "terms": [
        { "canonical": "Order", "definition": "A recorded purchase promise.", "concept_id": "CONCEPT-ORDER" }
      ],
      "aggregates": []
    }
  ],
  "concepts": [
    {
      "id": "CONCEPT-ORDER",
      "name": "Order",
      "context": "order-taking",
      "definition": "The promise to buy, as recorded at order time.",
      "essence": "what was promised and at what price",
      "responsibilities": ["purchase intent"],
      "evidence": ["domain-story:activity-1"]
    }
  ],
  "relations": []
}
'@

# AC-026 (REQ-002, REQ-005(f)): the concept carries none of must_not_own,
# stakeholder_perspectives, distinguished_from -- the pair to AC-003's
# all-populated positive.
$fixtureAc026OptionalAbsent = @'
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["domain/domain-story.md"] },
  "contexts": [
    { "name": "order-taking", "description": "Where the purchase promise is made.", "terms": [], "aggregates": [] }
  ],
  "concepts": [
    {
      "id": "CONCEPT-ORDER",
      "name": "Order",
      "context": "order-taking",
      "definition": "The promise to buy, as recorded at order time.",
      "essence": "what was promised and at what price",
      "responsibilities": ["purchase intent"],
      "evidence": ["domain-story:activity-1"]
    }
  ],
  "relations": []
}
'@

function Assert-PositiveFixtureAccepted {
    # The shape every positive fixture must satisfy: exit 0 and NOTHING on
    # either stream (DD-7 -- a well-formed, fully valid contract produces no
    # violation lines at all).
    param($Result)
    $Result.ExitCode | Should Be 0
    $Result.StdOut.Length | Should Be 0
    $Result.StdErr.Length | Should Be 0
}

Describe "validate-domain-contract accepts the Purchase/Fulfillment positive fixture with pattern boundary values (TEST-003, AC-003, REQ-002, REQ-005(a))" {

    It "the fixture really carries all 7 required fields on Order, all 3 optional fields populated, and the two pattern boundary values (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject $fixtureAc003PurchaseFulfillment
        $order = @($document.concepts | Where-Object { $_.id -ceq "CONCEPT-ORDER" })[0]
        foreach ($key in @("id", "name", "context", "definition", "essence", "responsibilities", "evidence")) {
            (Get-PropSafe $order $key) | Should Not Be $null
        }
        @(Get-PropSafe $order "must_not_own").Count | Should BeGreaterThan 0
        @(Get-PropSafe $order "stakeholder_perspectives").Count | Should BeGreaterThan 0
        @(Get-PropSafe $order "distinguished_from").Count | Should BeGreaterThan 0

        $apiOrder = @($document.concepts | Where-Object { $_.name -ceq "APIOrder" })
        $apiOrder.Count | Should Be 1
        $orderTaking2 = @($document.contexts | Where-Object { $_.name -ceq "order-taking-2" })
        $orderTaking2.Count | Should Be 1
        $apiOrder[0].context | Should Be "order-taking-2"
    }

    It "APIOrder and order-taking-2 satisfy the schema-declared regex patterns directly (non-vacuity for the boundary claim, AC-018's paired positive)" {
        $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
        $namePattern = $contract.definitions.concept.properties.name.pattern
        $contextPattern = $contract.definitions.concept.properties.context.pattern
        [System.Text.RegularExpressions.Regex]::IsMatch("APIOrder", $namePattern) | Should Be $true
        [System.Text.RegularExpressions.Regex]::IsMatch("order-taking-2", $contextPattern) | Should Be $true
    }

    It "the optional fields' VALUES survive as input -- must_not_own, stakeholder_perspectives, distinguished_from (REQ-005(a) preservation)" {
        $document = ConvertFrom-Json -InputObject $fixtureAc003PurchaseFulfillment
        $order = @($document.concepts | Where-Object { $_.id -ceq "CONCEPT-ORDER" })[0]

        $mustNotOwn = @($order.must_not_own)
        $mustNotOwn.Count | Should Be 2
        ($mustNotOwn -ccontains "delivery quantity") | Should Be $true
        ($mustNotOwn -ccontains "delivery state") | Should Be $true

        $distinguished = @($order.distinguished_from)
        $distinguished.Count | Should Be 1
        $distinguished[0].concept_id | Should Be "CONCEPT-FULFILLMENT"
        $reasons = @($distinguished[0].reasons)
        $reasons.Count | Should Be 3
        ($reasons -ccontains "different reason for change") | Should Be $true
        ($reasons -ccontains "different lifecycle") | Should Be $true
        ($reasons -ccontains "different stakeholder perspective") | Should Be $true

        $perspectives = @($order.stakeholder_perspectives)
        $perspectives.Count | Should BeGreaterThan 0
        $purchasingPerspective = @($perspectives | Where-Object { $_.actor -ceq "purchasing" })
        $purchasingPerspective.Count | Should Be 1
        $purchasingPerspective[0].concern | Should Be "price and quantity"
    }

    It "Fulfillment.must_not_own names purchase price, and the two concepts are mutually distinguished_from each other" {
        $document = ConvertFrom-Json -InputObject $fixtureAc003PurchaseFulfillment
        $fulfillment = @($document.concepts | Where-Object { $_.id -ceq "CONCEPT-FULFILLMENT" })[0]
        $fulfillmentMustNotOwn = @($fulfillment.must_not_own)
        ($fulfillmentMustNotOwn -ccontains "purchase price") | Should Be $true
        $fulfillment.distinguished_from[0].concept_id | Should Be "CONCEPT-ORDER"
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc003PurchaseFulfillment
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc003PurchaseFulfillment
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorSh -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}

Describe "validate-domain-contract accepts the Book/Bookshelf positive fixture (TEST-004, AC-004, REQ-005(b))" {

    It "the fixture realizes REQ-005(b) exactly: Book.must_not_own carries display position, Placement holds the ordering responsibility (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject $fixtureAc004BookBookshelf
        $book = @($document.concepts | Where-Object { $_.name -ceq "Book" })[0]
        $placement = @($document.concepts | Where-Object { $_.name -ceq "Placement" })[0]
        $book | Should Not Be $null
        $placement | Should Not Be $null

        $bookMustNotOwn = @($book.must_not_own)
        ($bookMustNotOwn -ccontains "display position") | Should Be $true

        $placementResponsibilities = @($placement.responsibilities)
        ($placementResponsibilities -ccontains "display position") | Should Be $true
        ($placementResponsibilities -ccontains "shelf ordering") | Should Be $true
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc004BookBookshelf
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc004BookBookshelf
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorSh -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}

Describe "validate-domain-contract accepts two contexts carrying the same concept name with distinct ids (TEST-005, AC-005, REQ-002, REQ-005(c))" {

    It "the fixture really carries one name in two different contexts with distinct ids (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject $fixtureAc005CrossContextSameName
        $orders = @($document.concepts | Where-Object { $_.name -ceq "Order" })
        $orders.Count | Should Be 2
        ($orders[0].context -ceq $orders[1].context) | Should Be $false
        ($orders[0].id -ceq $orders[1].id) | Should Be $false
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc005CrossContextSameName
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc005CrossContextSameName
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorSh -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}

Describe "validate-domain-contract accepts a term-to-concept link and preserves it (TEST-025, AC-025, REQ-001, REQ-003, REQ-005(e))" {

    It "the v2 schema declares term.concept_id as optional with the concept-id pattern (structural assertion, AC-025 part a)" {
        $contract = Get-Content -Raw -Encoding Utf8 $v2SchemaPath | ConvertFrom-Json
        $termDef = $contract.definitions.term
        $termRequired = @($termDef.required)
        ($termRequired -ccontains "concept_id") | Should Be $false
        $termDef.properties.concept_id.pattern | Should Be '^CONCEPT-[A-Z][A-Z0-9-]*$'
    }

    It "the fixture's term.concept_id really does resolve to a declared concept id (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject $fixtureAc025TermConceptLink
        $term = $document.contexts[0].terms[0]
        $term.concept_id | Should Be "CONCEPT-ORDER"
        $conceptIds = @($document.concepts | ForEach-Object { $_.id })
        ($conceptIds -ccontains $term.concept_id) | Should Be $true
    }

    It "the value survives validation -- re-reading the fixture after the validator runs shows concept_id unchanged (AC-025 part b)" {
        # The validator emits only exit code and stderr, never a parse result
        # (DD-7), so "survives validation" is checked by re-reading the
        # fixture's OWN source text after invoking the validator against it,
        # not by inspecting any validator output.
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc025TermConceptLink
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixturePath
            $result.ExitCode | Should Be 0
            $reread = Get-Content -Raw -Encoding Utf8 -LiteralPath $fixturePath | ConvertFrom-Json
            $reread.contexts[0].terms[0].concept_id | Should Be "CONCEPT-ORDER"
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc025TermConceptLink
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc025TermConceptLink
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorSh -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}

Describe "validate-domain-contract accepts a concept missing all three optional fields (TEST-026, AC-026, REQ-002, REQ-005(f))" {

    It "the fixture's concept really has none of must_not_own, stakeholder_perspectives, distinguished_from (non-vacuity)" {
        $document = ConvertFrom-Json -InputObject $fixtureAc026OptionalAbsent
        $concept = $document.concepts[0]
        foreach ($key in @("must_not_own", "stakeholder_perspectives", "distinguished_from")) {
            (Get-PropSafe $concept $key) | Should Be $null
        }
    }

    It "ps1 twin: accepts it with exit 0 and no output at all" {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc026OptionalAbsent
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorPs1 -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }

    It "sh twin: accepts it with exit 0 and no output at all" -Skip:(-not $shTwinAvailable) {
        $fixturePath = New-EphemeralContractFile -Content $fixtureAc026OptionalAbsent
        try {
            Assert-PositiveFixtureAccepted -Result (Invoke-ValidatorSh -ContractPath $fixturePath)
        } finally {
            Remove-EphemeralPath -Path $fixturePath
        }
    }
}

Describe "T-005 optional two-state pairing (tasks.md Done When: optional fields are truly optional, not accidentally required)" {

    It "AC-003's Order concept populates all 3 optional fields and AC-026's concept populates none of them" {
        $populated = ConvertFrom-Json -InputObject $fixtureAc003PurchaseFulfillment
        $order = @($populated.concepts | Where-Object { $_.id -ceq "CONCEPT-ORDER" })[0]
        @($order.must_not_own).Count | Should BeGreaterThan 0
        @($order.stakeholder_perspectives).Count | Should BeGreaterThan 0
        @($order.distinguished_from).Count | Should BeGreaterThan 0

        $absent = ConvertFrom-Json -InputObject $fixtureAc026OptionalAbsent
        $concept = $absent.concepts[0]
        foreach ($key in @("must_not_own", "stakeholder_perspectives", "distinguished_from")) {
            (Get-PropSafe $concept $key) | Should Be $null
        }
    }
}

# --- AC-013 twin parity across the full 78-fixture corpus -------------------

function Get-T005NegativeFixtureBodies {
    # The 73 negative fixtures T-002 (3), T-003 (62) and T-004 (8) authored,
    # gathered from their EXISTING definitions without touching any of them.
    # T-002's 3 are referenced directly by the variables/function that task
    # already defined; T-003's 62 and T-004's 8 are re-expanded through the
    # SAME token-table expander those tasks authored
    # (New-StructuralFixtureJson), so this list can never silently diverge
    # from what those tasks' own Describe blocks actually exercise.
    $bodies = New-Object System.Collections.ArrayList
    [void]$bodies.Add($fixtureTruncatedJson)
    [void]$bodies.Add((New-OversizedContractFixture -TargetBytes ($maxContractBytes + 1)))
    [void]$bodies.Add($fixtureV1Contract)
    foreach ($structuralCase in $structuralFixtures) {
        [void]$bodies.Add((New-StructuralFixtureJson -Override $structuralCase.Override))
    }
    foreach ($crossCase in $crossReferenceFixtures) {
        [void]$bodies.Add((New-StructuralFixtureJson -Override $crossCase.Override))
    }
    return ,$bodies
}

$t005PositiveFixtureBodies = @(
    $fixtureAc003PurchaseFulfillment,
    $fixtureAc004BookBookshelf,
    $fixtureAc005CrossContextSameName,
    $fixtureAc025TermConceptLink,
    $fixtureAc026OptionalAbsent
)

function Get-T005FullParityCorpus {
    $bodies = New-Object System.Collections.ArrayList
    foreach ($body in $t005PositiveFixtureBodies) { [void]$bodies.Add($body) }
    foreach ($body in (Get-T005NegativeFixtureBodies)) { [void]$bodies.Add($body) }
    return ,$bodies
}

Describe "T-005 negative fixture grand total (tasks.md Negative Fixture Allocation; acceptance-tests.md tally)" {

    It "T-002 contributes exactly 3 negative fixtures (AC-017 x2, AC-012 x1)" {
        @($fixtureTruncatedJson, (New-OversizedContractFixture -TargetBytes ($maxContractBytes + 1)), $fixtureV1Contract).Count | Should Be 3
    }

    It "T-003 contributes exactly 62 and T-004 contributes exactly 8 (restated here for the sum below)" {
        $structuralFixtures.Count | Should Be 62
        $crossReferenceFixtures.Count | Should Be 8
    }

    It "the full negative corpus totals exactly 73 fixtures -- a divergence means a fixture was dropped or duplicated" {
        (Get-T005NegativeFixtureBodies).Count | Should Be 73
    }
}

Describe "validate-domain-contract twin parity across the full fixture corpus (TEST-013, AC-013, REQ-004, REQ-006)" {

    It "the full corpus totals 78 fixtures (5 positive families + 73 negative fixtures)" {
        (Get-T005FullParityCorpus).Count | Should Be 78
    }

    It "every fixture in the corpus produces an identical exit code and violation count on both twins [SKIPPED when bash/python3 is absent from PATH]" -Skip:(-not $shTwinAvailable) {
        $corpus = Get-T005FullParityCorpus
        $mismatches = New-Object System.Collections.ArrayList
        foreach ($body in $corpus) {
            $fixturePath = New-EphemeralContractFile -Content $body
            try {
                $ps1Result = Invoke-ValidatorPs1 -ContractPath $fixturePath
                $shResult = Invoke-ValidatorSh -ContractPath $fixturePath
                $ps1Lines = @(Get-StdErrViolationLines -Result $ps1Result)
                $shLines = @(Get-StdErrViolationLines -Result $shResult)
                if (($ps1Result.ExitCode -ne $shResult.ExitCode) -or ($ps1Lines.Count -ne $shLines.Count)) {
                    [void]$mismatches.Add(("exit ps1={0} sh={1}; violation-count ps1={2} sh={3}" -f $ps1Result.ExitCode, $shResult.ExitCode, $ps1Lines.Count, $shLines.Count))
                }
            } finally {
                Remove-EphemeralPath -Path $fixturePath
            }
        }
        ($mismatches -join "`n") | Should Be ""
        $mismatches.Count | Should Be 0
    }
}

# --- AC-015 non-regression closure -------------------------------------------

function Invoke-V1SuiteRun {
    # Runs the UNMODIFIED v1 suite in a fresh pwsh/PowerShell child process
    # under the same Pester version this suite itself uses (AC-015, REQ-007).
    # A separate process, not a nested Invoke-Pester call inside this
    # already-running Pester session, so the v1 run's state cannot leak into
    # or be affected by this suite's own Run phase.
    $runnerPath = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-t005-v1runner-" + [guid]::NewGuid().ToString("N") + ".ps1")
    $runnerBody = @"
`$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 4.10.1
`$result = Invoke-Pester -Script '$v1SuiteTestsPath' -PassThru -Show None
Write-Output ('RESULT ' + `$result.PassedCount + ' ' + `$result.FailedCount)
"@
    [System.IO.File]::WriteAllText($runnerPath, $runnerBody, (New-Object System.Text.UTF8Encoding($false)))
    try {
        $arguments = '-NoProfile -NonInteractive -File "{0}"' -f $runnerPath
        return Invoke-CapturedProcess -FilePath $powerShellHostPath -ArgumentString $arguments
    } finally {
        Remove-EphemeralPath -Path $runnerPath
    }
}

Describe "domain-contract.v1 suite non-regression closure (TEST-015, AC-015, REQ-007)" {

    It "the v1 suite file still exists" {
        Test-Path $v1SuiteTestsPath | Should Be $true
    }

    It "there really are exactly eleven pre-existing tests/sdd-domain/ suite files besides this one (non-vacuity)" {
        $preExistingSuitePaths.Count | Should Be 11
        $onDisk = @(Get-ChildItem -Path (Join-Path $repositoryRoot "tests/sdd-domain") -Filter "*.Tests.ps1" |
            Where-Object { $_.Name -cne "contract-v2-schema.Tests.ps1" } |
            ForEach-Object { "tests/sdd-domain/" + $_.Name } |
            Sort-Object)
        $onDisk.Count | Should Be 11
        $expected = @($preExistingSuitePaths | Sort-Object)
        for ($i = 0; $i -lt $onDisk.Count; $i++) {
            $onDisk[$i] | Should Be $expected[$i]
        }
    }

    It "the unmodified v1 suite runs green under Pester 4.10.1 in a fresh process" {
        $result = Invoke-V1SuiteRun
        $result.ExitCode | Should Be 0
        # Recorded baseline (task brief): 8 passed / 0 failed. Asserted
        # exactly, not merely "0 failed", so a silent addition or removal of
        # a v1 check -- which REQ-007 forbids -- is caught too.
        $result.StdOut | Should Match "^RESULT 8 0\s*$"
    }

    It "this feature's diff against main touches none of the four INV-004 v1 consumers or the eleven pre-existing suites [SKIPPED when git is absent from PATH]" -Skip:(-not $gitAvailable) {
        Push-Location $repositoryRoot
        try {
            $diffOutput = & $gitCommand.Source diff --name-only "main...HEAD" 2>$null
        } finally {
            Pop-Location
        }
        $changedPaths = @($diffOutput | Where-Object { $_.Length -gt 0 })
        # Non-vacuity: a branch reporting zero changed files would make the
        # exclusion check below vacuously true.
        $changedPaths.Count | Should BeGreaterThan 0
        $forbidden = @($inv004ConsumerPaths + $preExistingSuitePaths)
        $violations = @($forbidden | Where-Object { $changedPaths -ccontains $_ })
        ($violations -join ", ") | Should Be ""
        $violations.Count | Should Be 0
    }
}

# ---------------------------------------------------------------------------
# RT-20260819-001 (review ticket, severity critical, target T-002): the .ps1
# twin's PARSE VERDICT must equal the .sh twin's.
#
# The .sh twin parses with python3 `json.loads`, which is strict. The .ps1
# twin parsed with ConvertFrom-Json alone, which is lenient, so twelve classes
# of syntactically invalid JSON were INVALID to one twin and VALID to the
# other -- a fail-closed violation of REQ-004(a) and a verdict-level breach of
# REQ-006 twin parity (design.md DD-7 output contract).
#
# The parity target is `json.loads`, not RFC 8259: the ticket fixes the .ps1
# twin against the .sh twin and forbids changing the .sh twin. So the three
# documents python3 accepts as extensions to RFC 8259 -- NaN, Infinity and
# duplicate object keys -- must stay ACCEPTED here. A .ps1 twin that "improved"
# on json.loads by rejecting them would be a new divergence in the opposite
# direction, not a fix, so those classes are pinned below alongside the twelve
# that must reject.
#
# These are RT-20260819-001 regression fixtures, NOT additions to tasks.md's
# `## Negative Fixture Allocation` table: the T-002/T-003/T-004 fixture counts
# (3 / 62 / 8) and the T-005 78-fixture parity corpus above are deliberately
# left untouched.
#
# Every fixture is ONE single-point mutation of the same base contract the
# structural pass already proves is ACCEPTED at exit 0, expanded through the
# expander T-003 authored, so a rejection cannot be attributed to anything but
# the mutation under test. Fixtures stay ephemeral (DD-5, INV-006): each is
# written to a per-test temporary file the test deletes again, and no permanent
# fixture directory is added. All fixture vocabulary is the same synthetic
# Purchase / Fulfillment domain nouns; no credential, token, personal, or
# customer-derived string appears in any of them (security-spec.md).
# ---------------------------------------------------------------------------

# The malformed-JSON line BOTH twins must emit for a rejected document, byte
# for byte. The existing V2-PARSE rule id is reused rather than a new one
# minted, so the twins stay message-identical for this whole class.
$rtParseViolationLine = 'V2-PARSE: input is not well-formed JSON and was not parsed further'

# The unmutated, fully valid base contract every RT fixture mutates at exactly
# one point.
$rtBaseContractJson = New-StructuralFixtureJson -Override @{}

function Edit-RtFixtureText {
    # One single-point textual mutation. Throws when the literal is absent or
    # occurs more than once, so a fixture can never silently degrade into an
    # unmutated copy of the base and pass vacuously. Ordinal, never
    # culture-sensitive or case-insensitive comparison.
    param([string]$Text, [string]$Find, [string]$Replace)
    $first = $Text.IndexOf($Find, [System.StringComparison]::Ordinal)
    if ($first -lt 0) { throw ("RT fixture literal not found in the base contract: " + $Find) }
    $second = $Text.IndexOf($Find, $first + 1, [System.StringComparison]::Ordinal)
    if ($second -ge 0) { throw ("RT fixture literal is ambiguous in the base contract: " + $Find) }
    return $Text.Substring(0, $first) + $Replace + $Text.Substring($first + $Find.Length)
}

function ConvertTo-RtAsciiBytes {
    # Comma-wrapped: PowerShell unrolls an array returned from a function.
    param([string]$Text)
    return ,([System.Text.Encoding]::ASCII.GetBytes($Text))
}

function New-RtControlByteFixture {
    # Splices exactly ONE raw control byte into an otherwise pure-ASCII fixture
    # body at a byte offset. Built as an explicit byte array rather than a
    # string literal so the injected byte is unambiguous in this source file
    # and cannot be lost to an editor or encoding round-trip.
    param([string]$Text, [int]$Offset, [byte]$ControlByte)
    $source = [System.Text.Encoding]::ASCII.GetBytes($Text)
    if ($Offset -lt 0 -or $Offset -gt $source.Length) { throw "RT control-byte offset is out of range" }
    $result = New-Object 'System.Collections.Generic.List[byte]'
    for ($i = 0; $i -lt $Offset; $i++) { $result.Add($source[$i]) }
    $result.Add($ControlByte)
    for ($i = $Offset; $i -lt $source.Length; $i++) { $result.Add($source[$i]) }
    return ,$result.ToArray()
}

function New-EphemeralRawFixtureFile {
    # Ephemeral fixture written from raw bytes, so a fixture BODY may hold
    # bytes 0x00-0x1F. The fixture FILE NAME stays hex and ASCII hyphens only:
    # a 0x00-0x1F byte in a path is legal on POSIX but illegal on Win32 and
    # would kill the whole .ps1 side there.
    param([byte[]]$Bytes)
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-v2-rt20260819001-" + [guid]::NewGuid().ToString("N") + ".json")
    [System.IO.File]::WriteAllBytes($path, $Bytes)
    return $path
}

function New-RtParityCase {
    param([string]$Class, [string]$Verdict, [byte[]]$Bytes)
    return New-Object PSObject -Property @{
        Class   = $Class
        Verdict = $Verdict
        Bytes   = $Bytes
    }
}

# Offsets for the three raw-control-byte fixtures, derived from the base
# contract rather than hard-coded, so they stay correct if the base changes.
$rtNulBeforeCloseOffset = $rtBaseContractJson.Length - 1
$rtControlInStringOffset = $rtBaseContractJson.IndexOf('"Order"', [System.StringComparison]::Ordinal) + 2

$rtParityCases = @(
    # --- the twelve classes json.loads rejects and ConvertFrom-Json accepted --
    (New-RtParityCase -Class "class 01 trailing comma in an object" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"relations": []}' -Replace '"relations": [],}'))),
    (New-RtParityCase -Class "class 02 trailing comma in an array" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '["purchase intent"]' -Replace '["purchase intent",]'))),
    (New-RtParityCase -Class "class 03 single-quoted key" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"schema": ' -Replace "'schema': "))),
    (New-RtParityCase -Class "class 04 single-quoted value" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"1.0.0"' -Replace "'1.0.0'"))),
    (New-RtParityCase -Class "class 05 unquoted key" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"schema": ' -Replace 'schema: '))),
    (New-RtParityCase -Class "class 06 embedded NUL byte" -Verdict "reject" `
        -Bytes (New-RtControlByteFixture -Text $rtBaseContractJson -Offset $rtNulBeforeCloseOffset -ControlByte 0)),
    (New-RtParityCase -Class "class 07 leading NUL byte" -Verdict "reject" `
        -Bytes (New-RtControlByteFixture -Text $rtBaseContractJson -Offset 0 -ControlByte 0)),
    (New-RtParityCase -Class "class 08 block comment" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes ($rtBaseContractJson.Insert(1, '/* c */')))),
    (New-RtParityCase -Class "class 09 line comment after the document" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes ($rtBaseContractJson + ' // c'))),
    (New-RtParityCase -Class "class 10 raw control character inside a string" -Verdict "reject" `
        -Bytes (New-RtControlByteFixture -Text $rtBaseContractJson -Offset $rtControlInStringOffset -ControlByte 1)),
    (New-RtParityCase -Class "class 11 leading-zero number" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"version": "1.0.0"' -Replace '"version": 01'))),
    (New-RtParityCase -Class "class 12 hexadecimal number" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"version": "1.0.0"' -Replace '"version": 0x1F'))),
    # --- the class both twins already rejected, pinned against regression -----
    (New-RtParityCase -Class "class 13 a second value after the document" -Verdict "reject" `
        -Bytes (ConvertTo-RtAsciiBytes ($rtBaseContractJson + ' {"schema": "domain-contract/v2"}'))),
    # --- the three python3 extensions that must STAY accepted -----------------
    (New-RtParityCase -Class "class 14 NaN literal (json.loads accepts it; over-rejecting is a new divergence)" -Verdict "accept" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"version": "1.0.0"' -Replace '"version": NaN'))),
    (New-RtParityCase -Class "class 15 Infinity literal (json.loads accepts it; over-rejecting is a new divergence)" -Verdict "accept" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"version": "1.0.0"' -Replace '"version": Infinity'))),
    (New-RtParityCase -Class "class 16 duplicate object key (json.loads accepts it, last value wins)" -Verdict "accept" `
        -Bytes (ConvertTo-RtAsciiBytes (Edit-RtFixtureText -Text $rtBaseContractJson -Find '"version": "1.0.0"' -Replace '"version": "9.9.9", "version": "1.0.0"')))
)

Describe "RT-20260819-001 fixture corpus integrity (non-vacuity for the parity checks below)" {

    It "the corpus holds exactly 16 classes -- 13 that must reject, 3 that must stay accepted" {
        $rtParityCases.Count | Should Be 16
        @($rtParityCases | Where-Object { $_.Verdict -ceq "reject" }).Count | Should Be 13
        @($rtParityCases | Where-Object { $_.Verdict -ceq "accept" }).Count | Should Be 3
    }

    It "every fixture really does differ from the unmutated base contract" {
        $baseBytes = ConvertTo-RtAsciiBytes $rtBaseContractJson
        $identical = New-Object System.Collections.ArrayList
        foreach ($rtCase in $rtParityCases) {
            if ([System.Convert]::ToBase64String($rtCase.Bytes) -ceq [System.Convert]::ToBase64String($baseBytes)) {
                [void]$identical.Add($rtCase.Class)
            }
        }
        ($identical -join ", ") | Should Be ""
    }

    It "the three raw-control-byte fixtures really do carry a byte in 0x00-0x1F, and no other fixture does" {
        $withControlByte = New-Object System.Collections.ArrayList
        foreach ($rtCase in $rtParityCases) {
            foreach ($byteValue in $rtCase.Bytes) {
                if ([int]$byteValue -lt 32) { [void]$withControlByte.Add($rtCase.Class); break }
            }
        }
        $withControlByte.Count | Should Be 3
    }
}

Describe "RT-20260819-001 base contract stays accepted (the fix must not pass by rejecting everything)" {

    It "ps1 twin: accepts the unmutated base contract with exit 0 and no output at all" {
        $fixture = New-EphemeralRawFixtureFile -Bytes (ConvertTo-RtAsciiBytes $rtBaseContractJson)
        try {
            $result = Invoke-ValidatorPs1 -ContractPath $fixture
            $result.ExitCode | Should Be 0
            $result.StdOut.Length | Should Be 0
            $result.StdErr.Length | Should Be 0
        } finally {
            Remove-EphemeralPath -Path $fixture
        }
    }

    It "sh twin: accepts the unmutated base contract with exit 0 and no output at all [SKIPPED when bash/python3 is absent from PATH]" -Skip:(-not $shTwinAvailable) {
        $fixture = New-EphemeralRawFixtureFile -Bytes (ConvertTo-RtAsciiBytes $rtBaseContractJson)
        try {
            $result = Invoke-ValidatorSh -ContractPath $fixture
            $result.ExitCode | Should Be 0
            $result.StdOut.Length | Should Be 0
            $result.StdErr.Length | Should Be 0
        } finally {
            Remove-EphemeralPath -Path $fixture
        }
    }
}

Describe "RT-20260819-001 ps1 twin parse verdict (REQ-004(a) fail-closed parse)" {

    foreach ($rtCase in $rtParityCases) {
        $rtLabel = $rtCase.Class
        $rtVerdict = $rtCase.Verdict

        It ("ps1 twin -- " + $rtLabel) {
            $fixture = New-EphemeralRawFixtureFile -Bytes $rtCase.Bytes
            try {
                $result = Invoke-ValidatorPs1 -ContractPath $fixture
                $result.StdOut.Length | Should Be 0
                $lines = @(Get-StdErrViolationLines -Result $result)
                # -ceq, never `Should Be` alone, for the rule-id comparisons:
                # PowerShell's -eq and Pester 4's `Should Be` are both
                # case-insensitive and the rule ids are case-significant.
                if ($rtVerdict -ceq "reject") {
                    $result.ExitCode | Should Be 1
                    $lines.Count | Should Be 1
                    ($lines[0] -ceq $rtParseViolationLine) | Should Be $true
                } else {
                    @($lines | Where-Object { $_ -ceq $rtParseViolationLine }).Count | Should Be 0
                }
                $result.StdErr | Should Not Match "Traceback"
                $result.StdErr | Should Not Match "Exception"
                $result.StdErr | Should Not Match "CategoryInfo"
                $result.StdErr | Should Not Match "FullyQualifiedErrorId"
                $result.StdErr | Should Not Match "ScriptStackTrace"
                $result.StdErr | Should Not Match "at <ScriptBlock>"
                $result.StdErr | Should Not Match "^\s+\+ "
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }
    }
}

Describe "RT-20260819-001 sh/ps1 verdict parity (REQ-006, design.md DD-7)" {

    foreach ($rtCase in $rtParityCases) {
        $rtLabel = $rtCase.Class
        $rtVerdict = $rtCase.Verdict

        It ("both twins -- " + $rtLabel + " [SKIPPED when bash/python3 is absent from PATH]") -Skip:(-not $shTwinAvailable) {
            $fixture = New-EphemeralRawFixtureFile -Bytes $rtCase.Bytes
            try {
                $ps1Result = Invoke-ValidatorPs1 -ContractPath $fixture
                $shResult = Invoke-ValidatorSh -ContractPath $fixture

                $ps1Result.StdOut.Length | Should Be 0
                $shResult.StdOut.Length | Should Be 0

                $ps1Text = (@(Get-StdErrViolationLines -Result $ps1Result) -join "`n")
                $shText = (@(Get-StdErrViolationLines -Result $shResult) -join "`n")

                $ps1Result.ExitCode | Should Be $shResult.ExitCode
                # Reported first for a readable failure message, then pinned
                # case-sensitively -- `Should Be` alone is case-insensitive.
                $ps1Text | Should Be $shText
                ($ps1Text -ceq $shText) | Should Be $true

                if ($rtVerdict -ceq "reject") {
                    ($ps1Text -ceq $rtParseViolationLine) | Should Be $true
                } else {
                    ($ps1Text -ceq $rtParseViolationLine) | Should Be $false
                }
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }
    }
}

# ---------------------------------------------------------------------------
# T-003 REQ-002 pattern ANCHOR regression.
#
# The three REQ-002 patterns are COMPILED with \A ... \Z (.sh, Python) and
# \A ... \z (.ps1, .NET) rather than ^ ... $, while the text quoted back to the
# author stays ^ ... $. That asymmetry is deliberate and load-bearing:
# contracts/domain-contract.v2.schema.json declares these patterns for JSON
# Schema draft-07, whose `pattern` keyword is ECMA-262 WITHOUT the multiline
# flag, where `$` matches END OF INPUT only -- so the schema REJECTS "Order\n"
# as a concepts[].name. Python's `$` and .NET's `$` both ALSO match
# immediately before a final newline, so a twin anchored ^ ... $ would ACCEPT
# a value the schema it implements rejects.
#
# That behaviour shipped with zero regression protection: reverting either
# twin's three anchors to ^ ... $ left the whole suite green, because no
# fixture anywhere carried a trailing-newline value. The checks below close
# that hole -- each one FAILS if its twin's anchors are reverted.
#
# These are anchor-regression fixtures, NOT additions to tasks.md's
# `## Negative Fixture Allocation` table: the T-002 / T-003 / T-004 counts
# (3 / 62 / 8), the AC-018 allocation of 3, the 73-fixture negative total and
# the 78-fixture AC-013 parity corpus above are all deliberately left
# untouched. This follows the RT-20260819-001 precedent of keeping
# out-of-allocation regression fixtures in their own list.
#
# Every fixture is ONE single-point mutation of the same base contract the
# structural pass already proves is ACCEPTED at exit 0, expanded through the
# expander T-003 authored, and each is PAIRED with an otherwise byte-identical
# control carrying no newline that must still be ACCEPTED -- so this block
# cannot pass by rejecting everything. Fixtures stay ephemeral (DD-5,
# INV-006): each is written to a per-test temporary file the test deletes
# again in a finally block, and no permanent fixture directory is added. The
# fixture FILE NAME stays hex and ASCII hyphens only.
#
# The trailing newline is carried as the two-character JSON escape \n inside
# the string value, never as a raw 0x0A byte: a raw control byte inside a JSON
# string is invalid JSON and would be rejected at the PARSE step, which would
# exercise V2-PARSE instead of the anchors. The corpus-integrity block below
# asserts that directly, both at the byte level and by decoding the fixture.
# All fixture vocabulary is the same synthetic Purchase / Fulfillment domain
# nouns; no credential, token, personal, or customer-derived string appears in
# any of them (security-spec.md).
# ---------------------------------------------------------------------------

function New-AnchorRegressionCase {
    # $Value is the accepted, newline-free value. The rejecting body is the
    # SAME value with a trailing JSON `\n` escape appended, so the two bodies
    # differ at exactly those two characters and at nothing else. $Extra
    # carries any additional token the pair BOTH need -- the id case retargets
    # CONTEXTS to CONTEXTS_PLAIN so mutating concepts[0].id cannot also dangle
    # the terms[].concept_id link and report a second, unrelated violation.
    param(
        [string]$Field,
        [string]$Token,
        [string]$Property,
        [string]$Value,
        [string]$PatternText,
        [hashtable]$Extra = @{}
    )
    $accepted = @{}
    $rejected = @{}
    foreach ($extraKey in $Extra.Keys) {
        $accepted[$extraKey] = [string]$Extra[$extraKey]
        $rejected[$extraKey] = [string]$Extra[$extraKey]
    }
    $accepted[$Token] = '"' + $Property + '": "' + $Value + '", '
    $rejected[$Token] = '"' + $Property + '": "' + $Value + '\n", '
    return New-Object PSObject -Property @{
        Field        = $Field
        Property     = $Property
        Value        = $Value
        PatternText  = $PatternText
        AcceptedJson = (New-StructuralFixtureJson -Override $accepted)
        RejectedJson = (New-StructuralFixtureJson -Override $rejected)
    }
}

$anchorRegressionCases = @(
    (New-AnchorRegressionCase -Field "concepts[0].id" -Token "C_ID" -Property "id" `
        -Value "CONCEPT-ORDER" -PatternText '^CONCEPT-[A-Z][A-Z0-9-]*$' `
        -Extra @{ CONTEXTS = '%CONTEXTS_PLAIN%' }),
    (New-AnchorRegressionCase -Field "concepts[0].name" -Token "C_NAME" -Property "name" `
        -Value "Order" -PatternText '^[A-Z][A-Za-z0-9]*$'),
    (New-AnchorRegressionCase -Field "concepts[0].context" -Token "C_CONTEXT" -Property "context" `
        -Value "order-taking" -PatternText '^[a-z][a-z0-9]*(-[a-z0-9]+)*$')
)

function Assert-AnchorRegressionRejected {
    # The shape a trailing-newline fixture must produce on EITHER twin: exit 1,
    # nothing on stdout, no interpreter noise, and exactly one V2-PATTERN line
    # naming the field under test whose message quotes the DECLARED ^ ... $
    # source text back to the author. A twin re-anchored to ^ ... $ accepts the
    # value instead and emits no such line, which fails the Count assertion.
    param($Result, $AnchorCase)
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
    # -cmatch, never -match: the rule ids and field paths are case-significant
    # and PowerShell's -match is case-insensitive.
    $expectedPrefix = "^" + [regex]::Escape("V2-PATTERN: " + $AnchorCase.Field + ":")
    $matched = @($lines | Where-Object { $_ -cmatch $expectedPrefix })
    $matched.Count | Should Be 1
    $expectedTail = " does not match " + $AnchorCase.PatternText
    $matched[0].EndsWith($expectedTail, [System.StringComparison]::Ordinal) | Should Be $true
}

Describe "T-003 REQ-002 anchor regression fixture integrity (non-vacuity for the anchor checks below)" {

    It "the block holds exactly 3 cases -- one per REQ-002 pattern field -- with distinct field paths" {
        $anchorRegressionCases.Count | Should Be 3
        # -CaseSensitive: Sort-Object -Unique is case-insensitive by default.
        @($anchorRegressionCases | ForEach-Object { $_.Field } | Sort-Object -Unique -CaseSensitive).Count | Should Be 3
    }

    It "each rejecting body carries the newline as a two-character JSON escape and holds no raw 0x00-0x1F byte" {
        foreach ($anchorCase in $anchorRegressionCases) {
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($anchorCase.RejectedJson)
            $controlBytes = @($bytes | Where-Object { [int]$_ -lt 32 })
            $controlBytes.Count | Should Be 0
            # The escape is present in the rejecting body and absent from the
            # accepted control, and the two differ by exactly those 2 chars.
            $escapeToken = '\n'
            $anchorCase.RejectedJson.Contains($escapeToken) | Should Be $true
            $anchorCase.AcceptedJson.Contains($escapeToken) | Should Be $false
            ($anchorCase.RejectedJson.Length - $anchorCase.AcceptedJson.Length) | Should Be 2
        }
    }

    It "each rejecting body really decodes to a value ending in a real newline, and its control does not" {
        foreach ($anchorCase in $anchorRegressionCases) {
            $rejectedDoc = ConvertFrom-Json $anchorCase.RejectedJson
            $acceptedDoc = ConvertFrom-Json $anchorCase.AcceptedJson
            $rejectedConcept = @(Get-PropSafe -Obj $rejectedDoc -Name "concepts")[0]
            $acceptedConcept = @(Get-PropSafe -Obj $acceptedDoc -Name "concepts")[0]
            $rejectedValue = [string](Get-PropSafe -Obj $rejectedConcept -Name $anchorCase.Property)
            $acceptedValue = [string](Get-PropSafe -Obj $acceptedConcept -Name $anchorCase.Property)
            ($rejectedValue -ceq ($anchorCase.Value + [string][char]10)) | Should Be $true
            ($acceptedValue -ceq $anchorCase.Value) | Should Be $true
        }
    }
}

Describe "T-003 REQ-002 anchor regression -- newline-free values stay accepted (this block must not pass by rejecting everything)" {

    foreach ($anchorCase in $anchorRegressionCases) {
        $anchorLabel = $anchorCase.Field

        It ("ps1 twin accepts the newline-free control for " + $anchorLabel) {
            $fixture = New-EphemeralContractFile -Content $anchorCase.AcceptedJson
            try {
                $result = Invoke-ValidatorPs1 -ContractPath $fixture
                $result.ExitCode | Should Be 0
                $result.StdOut.Length | Should Be 0
                $result.StdErr.Length | Should Be 0
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }

        It ("sh twin accepts the newline-free control for " + $anchorLabel + " [SKIPPED when bash/python3 is absent from PATH]") -Skip:(-not $shTwinAvailable) {
            $fixture = New-EphemeralContractFile -Content $anchorCase.AcceptedJson
            try {
                $result = Invoke-ValidatorSh -ContractPath $fixture
                $result.ExitCode | Should Be 0
                $result.StdOut.Length | Should Be 0
                $result.StdErr.Length | Should Be 0
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }
    }
}

Describe "T-003 REQ-002 anchor regression -- a trailing newline is rejected by both twins (draft-07 pattern is non-multiline ECMA-262)" {

    foreach ($anchorCase in $anchorRegressionCases) {
        $anchorLabel = $anchorCase.Field

        It ("ps1 twin rejects a trailing newline in " + $anchorLabel + " -- FAILS if \A ... \z is reverted to ^ ... $") {
            $fixture = New-EphemeralContractFile -Content $anchorCase.RejectedJson
            try {
                Assert-AnchorRegressionRejected -Result (Invoke-ValidatorPs1 -ContractPath $fixture) -AnchorCase $anchorCase
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }

        It ("sh twin rejects a trailing newline in " + $anchorLabel + " -- FAILS if \A ... \Z is reverted to ^ ... $ [SKIPPED when bash/python3 is absent from PATH]") -Skip:(-not $shTwinAvailable) {
            $fixture = New-EphemeralContractFile -Content $anchorCase.RejectedJson
            try {
                Assert-AnchorRegressionRejected -Result (Invoke-ValidatorSh -ContractPath $fixture) -AnchorCase $anchorCase
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }

        It ("both twins agree byte for byte on the trailing newline in " + $anchorLabel + " [SKIPPED when bash/python3 is absent from PATH]") -Skip:(-not $shTwinAvailable) {
            $fixture = New-EphemeralContractFile -Content $anchorCase.RejectedJson
            try {
                $ps1Result = Invoke-ValidatorPs1 -ContractPath $fixture
                $shResult = Invoke-ValidatorSh -ContractPath $fixture

                $ps1Result.StdOut.Length | Should Be 0
                $shResult.StdOut.Length | Should Be 0
                $ps1Result.ExitCode | Should Be $shResult.ExitCode

                $ps1Text = (@(Get-StdErrViolationLines -Result $ps1Result) -join "`n")
                $shText = (@(Get-StdErrViolationLines -Result $shResult) -join "`n")
                # Reported first for a readable failure message, then pinned
                # case-sensitively -- `Should Be` alone is case-insensitive.
                $ps1Text | Should Be $shText
                ($ps1Text -ceq $shText) | Should Be $true
                ($ps1Text -ceq ("V2-PATTERN: " + $anchorCase.Field + ": value " + $anchorCase.Value + "  does not match " + $anchorCase.PatternText)) | Should Be $true
            } finally {
                Remove-EphemeralPath -Path $fixture
            }
        }
    }
}
