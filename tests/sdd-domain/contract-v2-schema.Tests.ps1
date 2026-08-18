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
