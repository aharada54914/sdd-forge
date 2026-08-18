# Usage: validate-domain-contract.ps1 <contract.json>
#
# Deterministic validator for a domain-contract/v2 contract file. PowerShell
# half of the sh/ps1 twin pair; validate-domain-contract.sh is the other half
# and must stay verdict-identical to it (REQ-006 twin parity, checked by
# T-005).
#
# Issue #290, sdd-domain-concept-contract Phase 0. T-002 implements REQ-004
# steps (a) fail-closed JSON parse and (b) `schema` value dispatch, plus the
# shared skeleton the later steps extend:
#   - one `RULE-ID: message` line per violation on stderr, nothing on stdout,
#     exit 0 or 1 only, never a partial verdict (design.md DD-7);
#   - a single violation accumulator that T-003 (structural checks,
#     REQ-004(c)) and T-004 (cross-reference checks, REQ-004(d)-(i)) append to
#     through the Invoke-StructureCheck / Invoke-CrossReferenceCheck extension
#     points below. Later steps must not introduce a second output path.
#
# PS5.1-safe by construction. ConvertFrom-Json is the only parser used, and it
# is called without any parameter introduced after Windows PowerShell 5.1. The
# PS6+ JSON-schema test cmdlet, the PS6+ hashtable output switch, .NET 5+
# hex-conversion helpers, ternary and null-coalescing operators, and the
# $IsWindows-style automatic variables are all deliberately avoided, as is any
# external dependency, network access, or write (design.md DD-4, INV-005,
# security-spec.md). This comment names none of those constructs literally so
# that a repository-wide scan for them does not false-positive on this file.
#
# Contract content is data, never instruction: no value read from the contract
# is ever used to build a command, resolve a path, or reach Invoke-Expression
# (security-spec.md content-as-data rule).
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# Keep identical to MAX_CONTRACT_BYTES in the .sh twin (requirements.md Edge
# Cases: a contract file exceeding 10MB is abnormal input the validator
# rejects fail-closed, without a best-effort parse). Checked BEFORE the file
# is read, so an oversized input is never parsed at all.
$MaxContractBytes = 10485760

$ExpectedSchema = 'domain-contract/v2'

# Longest interpolated fragment allowed in one violation message.
$MessageValueLimit = 120

# The single violation accumulator. Every check appends `RULE-ID: message`
# strings here; nothing writes to stderr directly. Exit status is 1 when this
# list is non-empty and 0 when it is empty -- there is no third outcome.
$Violations = New-Object System.Collections.ArrayList

function Add-Violation {
    param([string]$RuleId, [string]$Message)
    [void]$Violations.Add(("{0}: {1}" -f $RuleId, $Message))
}

function ConvertTo-SafeText {
    # Render an untrusted value for a one-line stderr message. Control
    # characters would break the one-violation-per-line contract, so they are
    # folded to spaces; the result is truncated so a large value cannot flood
    # stderr. Purely a rendering step -- the value is never interpreted.
    param([string]$Text)
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Text.ToCharArray()) {
        $code = [int][char]$character
        if ($code -lt 32 -or $code -eq 127) {
            [void]$builder.Append(' ')
        } else {
            [void]$builder.Append($character)
        }
    }
    $rendered = $builder.ToString()
    if ($rendered.Length -gt $MessageValueLimit) {
        $rendered = $rendered.Substring(0, $MessageValueLimit) + '...'
    }
    return $rendered
}

function Get-JsonTypeName {
    param($Value, [string]$RawText)
    if ($null -eq $Value) {
        # PowerShell collapses an empty JSON array to $null on assignment, so
        # recover the declared type from the raw text before reporting null.
        if ($null -ne $RawText) {
            $trimmed = $RawText.TrimStart()
            if ($trimmed.Length -gt 0 -and $trimmed[0] -eq '[') { return 'array' }
        }
        return 'null'
    }
    if ($Value -is [bool]) { return 'boolean' }
    if ($Value -is [string]) { return 'string' }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or
        $Value -is [decimal] -or $Value -is [single] -or $Value -is [byte] -or
        $Value -is [int16] -or $Value -is [uint32] -or $Value -is [uint64]) {
        return 'number'
    }
    if ($Value -is [System.Collections.IDictionary]) { return 'object' }
    if ($Value -is [System.Collections.IList]) { return 'array' }
    if ($Value -is [System.Management.Automation.PSCustomObject]) { return 'object' }
    return 'unknown'
}

function Test-IsJsonObject {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return $false }
    if ($Value -is [System.Collections.IList]) { return $false }
    return ($Value -is [System.Management.Automation.PSCustomObject]) -or
           ($Value -is [System.Collections.IDictionary])
}

function Get-JsonProperty {
    # Safe member read: Set-StrictMode makes dot-notation throw on a missing
    # property, so every contract field is read through here instead.
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-ContractMemberPresent {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $false }
    return ($null -ne $Object.PSObject.Properties[$Name])
}

function Complete-Validation {
    # Flushes the accumulator and RETURNS the process exit status; it never
    # calls `exit` itself. `exit` inside a try block is flow control whose
    # catchability is not identical across PowerShell versions, and this
    # script must behave the same on Windows PowerShell 5.1 as on pwsh, so
    # every status travels back to the single top-level `exit` below.
    foreach ($line in $Violations) {
        [Console]::Error.WriteLine($line)
    }
    if ($Violations.Count -gt 0) { return 1 }
    return 0
}

function Invoke-StructureCheck {
    # REQ-004(c) -- required keys, JSON type conformance, pattern, minLength,
    # minItems, in that order (type conformance precedes the rest).
    #
    # EXTENSION POINT owned by T-003. Append violations through Add-Violation;
    # do not write to stderr and do not exit from here. Runs only after the
    # document has been admitted as domain-contract/v2 by the dispatch below.
    # Rule ids: V2-TYPE-MISMATCH / V2-MISSING-KEY / V2-PATTERN /
    # V2-EMPTY-ARRAY / V2-EMPTY-STRING (design.md Error Handling).
    param($Document)
    return
}

function Invoke-CrossReferenceCheck {
    # REQ-004(d)-(i) -- duplicate concept ids, dangling concept.context,
    # dangling distinguished_from.concept_id, dangling term.concept_id,
    # responsibilities/must_not_own self-contradiction, duplicate concept name
    # within one context.
    #
    # EXTENSION POINT owned by T-004. Same rules as Invoke-StructureCheck:
    # append through Add-Violation only. Rule ids: V2-DUP-CONCEPT-ID /
    # V2-DANGLING-CONTEXT / V2-DANGLING-DISTINCTION / V2-DANGLING-TERM /
    # V2-SELF-CONTRADICTION / V2-DUP-NAME-IN-CONTEXT.
    param($Document)
    return
}

function Invoke-Validation {
    param([string]$ContractPath)

    # --- Step (a): fail-closed acquisition and parse of the input ----------
    if (-not (Test-Path -LiteralPath $ContractPath)) {
        Add-Violation 'V2-INPUT-NOT-FOUND' ("input path does not exist: " + (ConvertTo-SafeText $ContractPath))
        return (Complete-Validation)
    }
    if (-not (Test-Path -LiteralPath $ContractPath -PathType Leaf)) {
        Add-Violation 'V2-INPUT-NOT-FILE' ("input path is not a regular file: " + (ConvertTo-SafeText $ContractPath))
        return (Complete-Validation)
    }
    $size = -1
    try {
        $size = (Get-Item -LiteralPath $ContractPath -Force).Length
    } catch {
        Add-Violation 'V2-INPUT-UNREADABLE' ("input path could not be read: " + (ConvertTo-SafeText $ContractPath))
        return (Complete-Validation)
    }
    if ($size -gt $MaxContractBytes) {
        Add-Violation 'V2-INPUT-TOO-LARGE' ("input is {0} bytes, above the {1} byte ceiling; the file is rejected without being parsed" -f $size, $MaxContractBytes)
        return (Complete-Validation)
    }
    $bytes = $null
    try {
        $bytes = [System.IO.File]::ReadAllBytes($ContractPath)
    } catch {
        Add-Violation 'V2-INPUT-UNREADABLE' ("input path could not be read: " + (ConvertTo-SafeText $ContractPath))
        return (Complete-Validation)
    }
    $text = $null
    try {
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $strictUtf8.GetString($bytes)
    } catch {
        Add-Violation 'V2-PARSE' 'input is not valid UTF-8 text and cannot be parsed as JSON'
        return (Complete-Validation)
    }
    # Strip a leading UTF-8 BOM if present, so both twins see the same text.
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 65279) {
        $text = $text.Substring(1)
    }
    $document = $null
    try {
        $document = ConvertFrom-Json -InputObject $text
    } catch {
        Add-Violation 'V2-PARSE' 'input is not well-formed JSON and was not parsed further'
        return (Complete-Validation)
    }

    # --- Step (b): dispatch on the declared `schema` value (DD-6) ----------
    # A document that does not identify itself as domain-contract/v2 is not
    # measured against v2's structure; it is rejected here with one named
    # line. The three non-v2-value branches use the structural rule ids
    # design.md Error Handling assigns, so T-003's structural pass inherits
    # them unchanged rather than having to restate them.
    if (-not (Test-IsJsonObject $document)) {
        Add-Violation 'V2-TYPE-MISMATCH' ("root: expected object, found " + (Get-JsonTypeName -Value $document -RawText $text))
        return (Complete-Validation)
    }
    if (-not (Test-ContractMemberPresent $document 'schema')) {
        Add-Violation 'V2-MISSING-KEY' 'schema: required key is absent at the contract root'
        return (Complete-Validation)
    }
    $schemaValue = Get-JsonProperty $document 'schema'
    if (-not ($schemaValue -is [string])) {
        Add-Violation 'V2-TYPE-MISMATCH' ("schema: expected string, found " + (Get-JsonTypeName -Value $schemaValue -RawText $null))
        return (Complete-Validation)
    }
    if ([string]::Equals($schemaValue, $ExpectedSchema, [StringComparison]::Ordinal) -eq $false) {
        Add-Violation 'V2-WRONG-SCHEMA' ("schema is {0}; this validator checks {1} only" -f (ConvertTo-SafeText $schemaValue), $ExpectedSchema)
        return (Complete-Validation)
    }

    # --- Steps (c) and (d)-(i): appended by T-003 and T-004 ---------------
    # [void] so that a future check accidentally emitting to the pipeline
    # cannot corrupt this function's returned exit status.
    [void](Invoke-StructureCheck -Document $document)
    [void](Invoke-CrossReferenceCheck -Document $document)
    return (Complete-Validation)
}

$exitCode = 1
try {
    if ($args.Count -ne 1) {
        Add-Violation 'V2-USAGE' 'exactly one argument is required: validate-domain-contract.ps1 <contract.json>'
        $exitCode = Complete-Validation
    } else {
        $exitCode = Invoke-Validation -ContractPath ([string]$args[0])
    }
} catch {
    # Fail closed with a single line. No stack trace and no raw PowerShell
    # error record ever reaches stderr (requirements.md Edge Cases,
    # security-spec.md fail-closed parsing).
    [Console]::Error.WriteLine('V2-INTERNAL: the validator stopped on an unexpected internal error')
    $exitCode = 1
}
exit $exitCode
