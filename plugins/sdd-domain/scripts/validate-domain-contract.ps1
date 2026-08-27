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
# PS5.1-safe by construction. Validity is decided by the hand-written strict
# JSON scanner below (Test-StrictJsonText), which accepts exactly what the .sh
# twin's python3 `json.loads` accepts; ConvertFrom-Json only BUILDS the object
# from text that scanner has already accepted, and it is called without any
# parameter introduced after Windows PowerShell 5.1. The PS6+ JSON-schema test
# cmdlet, the PS6+ hashtable output switch, .NET 5+ hex-conversion helpers,
# ternary and null-coalescing operators, and the $IsWindows-style automatic
# variables are all deliberately avoided, as is any external dependency,
# network access, or write (design.md DD-4, INV-005, security-spec.md). This
# comment names none of those constructs literally so that a repository-wide
# scan for them does not false-positive on this file.
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

# The three patterns requirements.md `## Field Definitions` declares (T-003,
# REQ-002). Each is kept in two forms: the declared source text, which is what
# a violation message quotes back to the author, and the form actually matched
# against a value. The matched form is anchored with \A ... \z rather than
# ^ ... $ because a .NET `$` also matches immediately before a trailing
# newline, which would accept "Order" followed by a newline as a valid concept
# name. Matching goes through [Regex]::IsMatch and never through -match: these
# patterns are case-significant and PowerShell's -match is case-insensitive.
# Keep both forms identical to the *_PATTERN_TEXT / *_RE pair in the .sh twin.
$ConceptIdPatternText = '^CONCEPT-[A-Z][A-Z0-9-]*$'
$ConceptIdMatchPattern = '\ACONCEPT-[A-Z][A-Z0-9-]*\z'
$ConceptNamePatternText = '^[A-Z][A-Za-z0-9]*$'
$ConceptNameMatchPattern = '\A[A-Z][A-Za-z0-9]*\z'
$ContextPatternText = '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
$ContextMatchPattern = '\A[a-z][a-z0-9]*(-[a-z0-9]+)*\z'

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

function Find-ContractMember {
    # ORDINAL member lookup (RT-20260819-002). `PSObject.Properties[$Name]`
    # indexes CASE-INSENSITIVELY, so it resolved keys the .sh twin does not:
    # that twin reads members with python `dict.get` / `in`, which is ordinal.
    # The difference was inert until T-004's cross-reference pass consumed
    # these helpers, at which point it became an exit-code divergence in both
    # directions -- .ps1 accepting a contract whose `contexts[0]` was spelled
    # "Name" (REQ-004(e)), and .ps1 rejecting one whose OPTIONAL
    # `must_not_own` was spelled "Must_Not_Own" and is, ordinally, simply
    # absent. Walking the collection with [StringComparison]::Ordinal makes
    # this twin resolve exactly the keys the .sh twin resolves (REQ-006,
    # design.md DD-7).
    #
    # Duplicate case-variant names: the FIRST match in enumeration order wins.
    # That case is not reachable through this script -- ConvertFrom-Json
    # REFUSES to build an object whose keys differ only in case, so such a
    # document is already rejected as V2-PARSE before any member is read -- so
    # this is a determinism guarantee rather than a live path. First-match is
    # chosen because it is the value python's `dict.get` returns for the same
    # document, and because both callers below share this one function and so
    # can never disagree about WHICH member matched.
    #
    # A linear walk replaces an O(1) hash index. Contract objects carry a
    # handful of members and the validator runs once per file, so the cost is
    # not measurable; correctness across the twins is the requirement.
    #
    # PS5.1-safe: no ::new(), no ternary, no null-coalescing, no .NET 5+ API.
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    foreach ($property in $Object.PSObject.Properties) {
        if ([string]::Equals($property.Name, $Name, [StringComparison]::Ordinal)) {
            return $property
        }
    }
    return $null
}

function Test-ContractMemberPresent {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $false }
    return ($null -ne (Find-ContractMember -Object $Object -Name $Name))
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

function Get-ContractValue {
    # Reads a member value WITHOUT the pipeline unrolling that would otherwise
    # turn an empty JSON array into $null on return and make it
    # indistinguishable from an absent key -- which would report a minItems
    # violation as a type or key violation. The leading comma wraps the value
    # so that exactly one object is emitted whatever its type.
    #
    # Resolution goes through Find-ContractMember, so this read is ORDINAL and
    # selects the same member Test-ContractMemberPresent reported present
    # (RT-20260819-002).
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = Find-ContractMember -Object $Object -Name $Name
    if ($null -eq $property) { return $null }
    return ,$property.Value
}

function Test-JsonTypeMatches {
    # Does the value's JSON type equal the type Field Definitions declares?
    param($Value, [string]$Expected)
    if ($Expected -eq 'string') { return ($Value -is [string]) }
    if ($Expected -eq 'array') {
        if ($Value -is [string]) { return $false }
        return ($Value -is [System.Collections.IList])
    }
    if ($Expected -eq 'object') { return (Test-IsJsonObject $Value) }
    return $false
}

function Test-DeclaredMember {
    # The single type-then-presence gate every declared member passes through.
    #
    # This function is where REQ-004(c)'s precedence rule lives: it returns
    # $true ONLY when the member is present and its JSON type conforms. Every
    # caller treats $false as "stop -- do not run pattern, minLength or
    # minItems on this value", which is what keeps a mistyped field away from a
    # regex or a length test and out of a raw interpreter error.
    param($Container, [string]$Name, [string]$Expected, [string]$Path,
          [switch]$Optional, [switch]$AtRoot)
    if (-not (Test-ContractMemberPresent $Container $Name)) {
        if (-not $Optional) {
            if ($AtRoot) {
                Add-Violation 'V2-MISSING-KEY' ($Path + ': required key is absent at the contract root')
            } else {
                Add-Violation 'V2-MISSING-KEY' ($Path + ': required key is absent')
            }
        }
        return $false
    }
    $value = Get-ContractValue $Container $Name
    if (-not (Test-JsonTypeMatches -Value $value -Expected $Expected)) {
        Add-Violation 'V2-TYPE-MISMATCH' ($Path + ': expected ' + $Expected + ', found ' + (Get-JsonTypeName -Value $value -RawText $null))
        return $false
    }
    return $true
}

function Test-DeclaredPattern {
    param([string]$Value, [string]$MatchPattern, [string]$PatternText, [string]$Path)
    if (-not ([System.Text.RegularExpressions.Regex]::IsMatch($Value, $MatchPattern))) {
        Add-Violation 'V2-PATTERN' ($Path + ': value ' + (ConvertTo-SafeText $Value) + ' does not match ' + $PatternText)
    }
}

function Test-DeclaredNonEmptyString {
    param([string]$Value, [string]$Path)
    if ($Value.Length -eq 0) {
        Add-Violation 'V2-EMPTY-STRING' ($Path + ': value is an empty string; at least one character is required')
    }
}

function Test-DeclaredStringArray {
    # minItems, then per-element type, then per-element minLength.
    param($Values, [string]$Path, [switch]$MinItemsOne)
    if ($MinItemsOne -and $Values.Count -eq 0) {
        Add-Violation 'V2-EMPTY-ARRAY' ($Path + ': array is empty; at least one entry is required')
        return
    }
    for ($index = 0; $index -lt $Values.Count; $index++) {
        $itemPath = ('{0}[{1}]' -f $Path, $index)
        $item = $Values[$index]
        if (-not ($item -is [string])) {
            Add-Violation 'V2-TYPE-MISMATCH' ($itemPath + ': expected string, found ' + (Get-JsonTypeName -Value $item -RawText $null))
            continue
        }
        Test-DeclaredNonEmptyString -Value $item -Path $itemPath
    }
}

function Test-ConceptStructure {
    # One concepts[] element against requirements.md `## Field Definitions`.
    param($Concept, [string]$Path)

    if (Test-DeclaredMember -Container $Concept -Name 'id' -Expected 'string' -Path ($Path + '.id')) {
        Test-DeclaredPattern -Value (Get-ContractValue $Concept 'id') `
            -MatchPattern $ConceptIdMatchPattern -PatternText $ConceptIdPatternText -Path ($Path + '.id')
    }
    if (Test-DeclaredMember -Container $Concept -Name 'name' -Expected 'string' -Path ($Path + '.name')) {
        Test-DeclaredPattern -Value (Get-ContractValue $Concept 'name') `
            -MatchPattern $ConceptNameMatchPattern -PatternText $ConceptNamePatternText -Path ($Path + '.name')
    }
    if (Test-DeclaredMember -Container $Concept -Name 'context' -Expected 'string' -Path ($Path + '.context')) {
        Test-DeclaredPattern -Value (Get-ContractValue $Concept 'context') `
            -MatchPattern $ContextMatchPattern -PatternText $ContextPatternText -Path ($Path + '.context')
    }

    foreach ($key in @('definition', 'essence')) {
        $memberPath = $Path + '.' + $key
        if (Test-DeclaredMember -Container $Concept -Name $key -Expected 'string' -Path $memberPath) {
            Test-DeclaredNonEmptyString -Value (Get-ContractValue $Concept $key) -Path $memberPath
        }
    }

    foreach ($key in @('responsibilities', 'evidence')) {
        $memberPath = $Path + '.' + $key
        if (Test-DeclaredMember -Container $Concept -Name $key -Expected 'array' -Path $memberPath) {
            Test-DeclaredStringArray -Values (Get-ContractValue $Concept $key) -Path $memberPath -MinItemsOne
        }
    }

    # must_not_own is optional and declares no minItems: an absent key and an
    # empty array are both valid (requirements.md Edge Cases).
    $memberPath = $Path + '.must_not_own'
    if (Test-DeclaredMember -Container $Concept -Name 'must_not_own' -Expected 'array' -Path $memberPath -Optional) {
        Test-DeclaredStringArray -Values (Get-ContractValue $Concept 'must_not_own') -Path $memberPath
    }

    $memberPath = $Path + '.stakeholder_perspectives'
    if (Test-DeclaredMember -Container $Concept -Name 'stakeholder_perspectives' -Expected 'array' -Path $memberPath -Optional) {
        $entries = Get-ContractValue $Concept 'stakeholder_perspectives'
        for ($index = 0; $index -lt $entries.Count; $index++) {
            $entryPath = ('{0}[{1}]' -f $memberPath, $index)
            $entry = $entries[$index]
            if (-not (Test-IsJsonObject $entry)) {
                Add-Violation 'V2-TYPE-MISMATCH' ($entryPath + ': expected object, found ' + (Get-JsonTypeName -Value $entry -RawText $null))
                continue
            }
            foreach ($key in @('actor', 'concern')) {
                $fieldPath = $entryPath + '.' + $key
                if (Test-DeclaredMember -Container $entry -Name $key -Expected 'string' -Path $fieldPath) {
                    Test-DeclaredNonEmptyString -Value (Get-ContractValue $entry $key) -Path $fieldPath
                }
            }
        }
    }

    $memberPath = $Path + '.distinguished_from'
    if (Test-DeclaredMember -Container $Concept -Name 'distinguished_from' -Expected 'array' -Path $memberPath -Optional) {
        $entries = Get-ContractValue $Concept 'distinguished_from'
        for ($index = 0; $index -lt $entries.Count; $index++) {
            $entryPath = ('{0}[{1}]' -f $memberPath, $index)
            $entry = $entries[$index]
            if (-not (Test-IsJsonObject $entry)) {
                Add-Violation 'V2-TYPE-MISMATCH' ($entryPath + ': expected object, found ' + (Get-JsonTypeName -Value $entry -RawText $null))
                continue
            }
            # This pass fixes only the declared JSON type of concept_id. Its
            # pattern is AC-022 and its dangling-reference check is AC-008,
            # both allocated to T-004 (tasks.md Negative Fixture Allocation).
            [void](Test-DeclaredMember -Container $entry -Name 'concept_id' -Expected 'string' -Path ($entryPath + '.concept_id'))
            $reasonsPath = $entryPath + '.reasons'
            if (Test-DeclaredMember -Container $entry -Name 'reasons' -Expected 'array' -Path $reasonsPath) {
                Test-DeclaredStringArray -Values (Get-ContractValue $entry 'reasons') -Path $reasonsPath -MinItemsOne
            }
        }
    }
}

function Test-ContextsStructure {
    # The one member requirements.md `## Field Definitions` declares inside the
    # contexts subtree is `contexts[].terms[].concept_id` -- the v2 addition
    # (REQ-003). The v1-inherited boundedContext / term shape around it is
    # declared by the schema file but is outside this pass's authority table and
    # outside the Negative-path coverage matrix, so a non-conforming
    # intermediate is walked past here rather than reported.
    param($Contexts)
    for ($index = 0; $index -lt $Contexts.Count; $index++) {
        $entry = $Contexts[$index]
        if (-not (Test-IsJsonObject $entry)) { continue }
        if (-not (Test-ContractMemberPresent $entry 'terms')) { continue }
        $terms = Get-ContractValue $entry 'terms'
        if ($terms -is [string]) { continue }
        if (-not ($terms -is [System.Collections.IList])) { continue }
        for ($termIndex = 0; $termIndex -lt $terms.Count; $termIndex++) {
            $term = $terms[$termIndex]
            if (-not (Test-IsJsonObject $term)) { continue }
            if (-not (Test-ContractMemberPresent $term 'concept_id')) { continue }
            [void](Test-DeclaredMember -Container $term -Name 'concept_id' -Expected 'string' `
                -Path ('contexts[{0}].terms[{1}].concept_id' -f $index, $termIndex) -Optional)
        }
    }
}

function Invoke-StructureCheck {
    # REQ-004(c) -- JSON type conformance, then required-key presence, then
    # pattern, minLength and minItems; a value whose type does not conform is
    # recorded and then excluded from the later checks.
    #
    # Owned by T-003. Appends through Add-Violation only: it does not write to
    # stderr and does not exit. Runs only after the document has been admitted
    # as domain-contract/v2 by the dispatch below. Rule ids: V2-TYPE-MISMATCH /
    # V2-MISSING-KEY / V2-PATTERN / V2-EMPTY-ARRAY / V2-EMPTY-STRING (design.md
    # Error Handling).
    param($Document)

    # `schema` is deliberately absent from this pass: admission has already
    # established that it is present, a string, and equal to domain-contract/v2,
    # so re-checking it here would emit that violation twice.
    if (Test-DeclaredMember -Container $Document -Name 'meta' -Expected 'object' -Path 'meta' -AtRoot) {
        $meta = Get-ContractValue $Document 'meta'
        [void](Test-DeclaredMember -Container $meta -Name 'version' -Expected 'string' -Path 'meta.version')
        [void](Test-DeclaredMember -Container $meta -Name 'status' -Expected 'string' -Path 'meta.status')
        [void](Test-DeclaredMember -Container $meta -Name 'generated_from' -Expected 'array' -Path 'meta.generated_from')
    }

    if (Test-DeclaredMember -Container $Document -Name 'contexts' -Expected 'array' -Path 'contexts' -AtRoot) {
        Test-ContextsStructure -Contexts (Get-ContractValue $Document 'contexts')
    }

    if (Test-DeclaredMember -Container $Document -Name 'concepts' -Expected 'array' -Path 'concepts' -AtRoot) {
        $concepts = Get-ContractValue $Document 'concepts'
        if ($concepts.Count -eq 0) {
            # minItems 1 -- distinct from the absent-key path above, which is
            # why the rule id differs (AC-016 versus AC-021(4)).
            Add-Violation 'V2-EMPTY-ARRAY' 'concepts: array is empty; at least one entry is required'
        } else {
            for ($index = 0; $index -lt $concepts.Count; $index++) {
                $conceptPath = ('concepts[{0}]' -f $index)
                $concept = $concepts[$index]
                if (-not (Test-IsJsonObject $concept)) {
                    Add-Violation 'V2-TYPE-MISMATCH' ($conceptPath + ': expected object, found ' + (Get-JsonTypeName -Value $concept -RawText $null))
                    continue
                }
                Test-ConceptStructure -Concept $concept -Path $conceptPath
            }
        }
    }
}

function Test-ReferenceWellFormed {
    # Is this reference value a well-formed concept id?
    #
    # A reference whose value does not match the concept-id pattern is a
    # MALFORMED reference, which is a different defect from a well-formed
    # reference that resolves to nothing (AC-022 versus AC-008 / AC-009). It is
    # reported here as V2-PATTERN, in the wording Test-DeclaredPattern already
    # uses, and is then excluded from resolution. That is REQ-004(c)'s
    # precedence idea one level further down: type before pattern, pattern
    # before reference resolution. A reader can therefore always tell which of
    # the two defects fired, and neither value is ever reported twice.
    param([string]$Value, [string]$Path)
    if ([System.Text.RegularExpressions.Regex]::IsMatch($Value, $ConceptIdMatchPattern)) { return $true }
    Test-DeclaredPattern -Value $Value -MatchPattern $ConceptIdMatchPattern `
        -PatternText $ConceptIdPatternText -Path $Path
    return $false
}

function Get-JsonStringMember {
    # The member value when it is present AND a JSON string; $null otherwise.
    param($Object, [string]$Name)
    if (-not (Test-ContractMemberPresent $Object $Name)) { return $null }
    $value = Get-ContractValue $Object $Name
    if (-not ($value -is [string])) { return $null }
    return $value
}

function Get-JsonArrayMember {
    # The member value when it is present AND a JSON array; $null otherwise.
    # Comma-wrapped on return so that an EMPTY array survives as an empty
    # array instead of unrolling to $null and reading as an absent key.
    param($Object, [string]$Name)
    if (-not (Test-ContractMemberPresent $Object $Name)) { return $null }
    $value = Get-ContractValue $Object $Name
    if (-not (Test-JsonTypeMatches -Value $value -Expected 'array')) { return $null }
    return ,$value
}

function Get-DeclaredStringValueSet {
    # The set of $Name values across an array of objects.
    #
    # Only entries that are objects whose $Name is present and a string are
    # indexed. A value that is not a string was already reported by the
    # structural pass and can never be equal to a well-formed reference, so
    # leaving it out changes no verdict. HashSet[string] uses the ordinal
    # comparer, so the index is case-significant -- matching the .sh twin's
    # raw string equality. Comma-wrapped on return: a HashSet is enumerable
    # and would otherwise unroll to its elements.
    param($Entries, [string]$Name)
    $found = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($index = 0; $index -lt $Entries.Count; $index++) {
        $entry = $Entries[$index]
        if (-not (Test-IsJsonObject $entry)) { continue }
        $value = Get-JsonStringMember -Object $entry -Name $Name
        if ($null -eq $value) { continue }
        [void]$found.Add($value)
    }
    return ,$found
}

function Invoke-CrossReferenceCheck {
    # REQ-004(d)-(i) -- duplicate concept ids, dangling concept.context,
    # dangling distinguished_from.concept_id, dangling term.concept_id,
    # responsibilities/must_not_own self-contradiction, duplicate concept name
    # within one context. Also the pattern check for the two reference fields
    # that share the concept-id pattern (AC-022), which T-003 left here so that
    # the malformed and unresolvable cases could be told apart in one place.
    #
    # Owned by T-004. Same rules as Invoke-StructureCheck: append through
    # Add-Violation only; it does not write to stderr and does not exit. Rule
    # ids: V2-DUP-CONCEPT-ID / V2-DANGLING-CONTEXT / V2-DANGLING-DISTINCTION /
    # V2-DANGLING-TERM / V2-SELF-CONTRADICTION / V2-DUP-NAME-IN-CONTEXT, plus
    # V2-PATTERN for a malformed reference (design.md Error Handling).
    #
    # These six checks are why this validator exists rather than a JSON Schema
    # run: draft-07 cannot express referential integrity (DD-1, INV-003).
    param($Document)

    $concepts = Get-JsonArrayMember -Object $Document -Name 'concepts'
    $contexts = Get-JsonArrayMember -Object $Document -Name 'contexts'
    $conceptsDeclared = ($null -ne $concepts)
    $contextsDeclared = ($null -ne $contexts)

    # The two referent indexes, each built only when the array it comes from
    # really is an array. When `concepts` or `contexts` is absent or mistyped
    # the structural pass has already reported that root cause; resolving
    # references against an index that could not be built would add a cascade
    # of derived failures naming fields the author did not get wrong.
    $declaredConceptIds = $null
    if ($conceptsDeclared) {
        $declaredConceptIds = Get-DeclaredStringValueSet -Entries $concepts -Name 'id'
    }
    $declaredContextNames = $null
    if ($contextsDeclared) {
        $declaredContextNames = Get-DeclaredStringValueSet -Entries $contexts -Name 'name'
    }

    if ($conceptsDeclared) {
        # --- (d) duplicate concept id -------------------------------------
        # Raw string equality, case-significant: CONCEPT-ORDER and
        # concept-order are different ids (and the second is separately a
        # pattern violation). The message names the duplicated id (AC-006).
        $seenIds = New-Object 'System.Collections.Generic.HashSet[string]'
        for ($index = 0; $index -lt $concepts.Count; $index++) {
            $concept = $concepts[$index]
            if (-not (Test-IsJsonObject $concept)) { continue }
            $identifier = Get-JsonStringMember -Object $concept -Name 'id'
            if ($null -eq $identifier) { continue }
            if (-not $seenIds.Add($identifier)) {
                Add-Violation 'V2-DUP-CONCEPT-ID' (('concepts[{0}].id: id ' -f $index) + (ConvertTo-SafeText $identifier) + ' is already declared by an earlier concept; concept ids must be unique')
            }
        }

        # --- (e) dangling concept.context ---------------------------------
        if ($null -ne $declaredContextNames) {
            for ($index = 0; $index -lt $concepts.Count; $index++) {
                $concept = $concepts[$index]
                if (-not (Test-IsJsonObject $concept)) { continue }
                $contextName = Get-JsonStringMember -Object $concept -Name 'context'
                if ($null -eq $contextName) { continue }
                if (-not ([System.Text.RegularExpressions.Regex]::IsMatch($contextName, $ContextMatchPattern))) {
                    # Malformed, not unresolvable. The structural pass already
                    # reported this value as V2-PATTERN; reporting it again as
                    # a dangling reference would blur the two defects.
                    continue
                }
                if (-not $declaredContextNames.Contains($contextName)) {
                    Add-Violation 'V2-DANGLING-CONTEXT' (('concepts[{0}].context: context ' -f $index) + (ConvertTo-SafeText $contextName) + ' is not declared in contexts')
                }
            }
        }

        # --- (f) dangling distinguished_from.concept_id -------------------
        # Pattern first (AC-022), then the self-reference case, then
        # resolution. requirements.md Edge Cases makes a concept pointing at
        # its own id invalid as part of this same check.
        for ($index = 0; $index -lt $concepts.Count; $index++) {
            $concept = $concepts[$index]
            if (-not (Test-IsJsonObject $concept)) { continue }
            $ownId = Get-JsonStringMember -Object $concept -Name 'id'
            $distinctions = Get-JsonArrayMember -Object $concept -Name 'distinguished_from'
            if ($null -eq $distinctions) { continue }
            for ($entryIndex = 0; $entryIndex -lt $distinctions.Count; $entryIndex++) {
                $distinction = $distinctions[$entryIndex]
                if (-not (Test-IsJsonObject $distinction)) { continue }
                $reference = Get-JsonStringMember -Object $distinction -Name 'concept_id'
                if ($null -eq $reference) { continue }
                $referencePath = 'concepts[{0}].distinguished_from[{1}].concept_id' -f $index, $entryIndex
                if (-not (Test-ReferenceWellFormed -Value $reference -Path $referencePath)) { continue }
                if (($null -ne $ownId) -and [string]::Equals($reference, $ownId, [StringComparison]::Ordinal)) {
                    Add-Violation 'V2-DANGLING-DISTINCTION' ($referencePath + ': ' + (ConvertTo-SafeText $reference) + " is the concept's own id; a concept cannot be distinguished from itself")
                    continue
                }
                if (($null -ne $declaredConceptIds) -and (-not $declaredConceptIds.Contains($reference))) {
                    Add-Violation 'V2-DANGLING-DISTINCTION' ($referencePath + ': ' + (ConvertTo-SafeText $reference) + ' does not resolve to any declared concept id')
                }
            }
        }
    }

    # --- (g) dangling contexts[].terms[].concept_id ------------------------
    if ($contextsDeclared -and ($null -ne $declaredConceptIds)) {
        for ($index = 0; $index -lt $contexts.Count; $index++) {
            $entry = $contexts[$index]
            if (-not (Test-IsJsonObject $entry)) { continue }
            $terms = Get-JsonArrayMember -Object $entry -Name 'terms'
            if ($null -eq $terms) { continue }
            for ($termIndex = 0; $termIndex -lt $terms.Count; $termIndex++) {
                $term = $terms[$termIndex]
                if (-not (Test-IsJsonObject $term)) { continue }
                $reference = Get-JsonStringMember -Object $term -Name 'concept_id'
                if ($null -eq $reference) { continue }
                $termPath = 'contexts[{0}].terms[{1}].concept_id' -f $index, $termIndex
                if (-not (Test-ReferenceWellFormed -Value $reference -Path $termPath)) { continue }
                if (-not $declaredConceptIds.Contains($reference)) {
                    Add-Violation 'V2-DANGLING-TERM' ($termPath + ': ' + (ConvertTo-SafeText $reference) + ' does not resolve to any declared concept id')
                }
            }
        }
    }

    if ($conceptsDeclared) {
        # --- (h) responsibilities / must_not_own self-contradiction --------
        # REQ-004(h) says the same STRING, so the comparison is exact: not
        # case-folded, not trimmed, not otherwise normalized. Each distinct
        # colliding string is reported once even if must_not_own repeats it.
        for ($index = 0; $index -lt $concepts.Count; $index++) {
            $concept = $concepts[$index]
            if (-not (Test-IsJsonObject $concept)) { continue }
            $responsibilities = Get-JsonArrayMember -Object $concept -Name 'responsibilities'
            if ($null -eq $responsibilities) { continue }
            $forbidden = Get-JsonArrayMember -Object $concept -Name 'must_not_own'
            if ($null -eq $forbidden) { continue }
            $owned = New-Object 'System.Collections.Generic.HashSet[string]'
            for ($itemIndex = 0; $itemIndex -lt $responsibilities.Count; $itemIndex++) {
                $item = $responsibilities[$itemIndex]
                if ($item -is [string]) { [void]$owned.Add($item) }
            }
            $reported = New-Object 'System.Collections.Generic.HashSet[string]'
            for ($itemIndex = 0; $itemIndex -lt $forbidden.Count; $itemIndex++) {
                $item = $forbidden[$itemIndex]
                if (-not ($item -is [string])) { continue }
                if (-not $owned.Contains($item)) { continue }
                if (-not $reported.Add($item)) { continue }
                Add-Violation 'V2-SELF-CONTRADICTION' (('concepts[{0}]: ' -f $index) + (ConvertTo-SafeText $item) + ' appears in both responsibilities and must_not_own')
            }
        }

        # --- (i) duplicate concept name inside ONE context -----------------
        # Names are indexed per context. That pairing is exactly what makes
        # the same name in two DIFFERENT contexts legal (requirements.md Edge
        # Cases, INV-012) while a repeat inside one context is not.
        $namesByContext = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'
        for ($index = 0; $index -lt $concepts.Count; $index++) {
            $concept = $concepts[$index]
            if (-not (Test-IsJsonObject $concept)) { continue }
            $conceptName = Get-JsonStringMember -Object $concept -Name 'name'
            if ($null -eq $conceptName) { continue }
            $owningContext = Get-JsonStringMember -Object $concept -Name 'context'
            if ($null -eq $owningContext) { continue }
            if (-not $namesByContext.ContainsKey($owningContext)) {
                $namesByContext[$owningContext] = New-Object 'System.Collections.Generic.HashSet[string]'
            }
            if (-not $namesByContext[$owningContext].Add($conceptName)) {
                Add-Violation 'V2-DUP-NAME-IN-CONTEXT' (('concepts[{0}].name: name ' -f $index) + (ConvertTo-SafeText $conceptName) + ' is already declared by another concept in context ' + (ConvertTo-SafeText $owningContext) + '; names must be unique within a context')
            }
        }
    }
}

function Test-StrictJsonLiteralAt {
    # Ordinal, case-SIGNIFICANT literal match at an index. -ceq, never -eq:
    # PowerShell's -eq on strings is case-insensitive, and `NaN` must not be
    # spelled `nan` any more than `null` may be spelled `NULL`.
    param([string]$Text, [int]$Start, [string]$Literal)
    if ($Start + $Literal.Length -gt $Text.Length) { return $false }
    return ($Text.Substring($Start, $Literal.Length) -ceq $Literal)
}

function Get-StrictJsonStringEnd {
    # Scans one JSON string literal starting AT its opening quote and returns
    # the index just past its closing quote, or -1 when the literal is not
    # well-formed. Raw U+0000..U+001F bytes are rejected inside a string --
    # that is python3's strict scanner and it is where the embedded-NUL class
    # is caught -- while the SAME characters are accepted when escaped. Only
    # the eight single-character escapes and \uXXXX with exactly four hex
    # digits are legal; every other escape is a rejection.
    param([char[]]$Chars, [int]$Start)
    $limit = $Chars.Length
    $index = $Start + 1
    while ($index -lt $limit) {
        $code = [int]$Chars[$index]
        if ($code -eq 34) { return ($index + 1) }
        if ($code -eq 92) {
            $index++
            if ($index -ge $limit) { return -1 }
            $escape = [int]$Chars[$index]
            if ($escape -eq 117) {
                if ($index + 4 -ge $limit) { return -1 }
                for ($offset = 1; $offset -le 4; $offset++) {
                    $hex = [int]$Chars[$index + $offset]
                    if (-not (($hex -ge 48 -and $hex -le 57) -or
                              ($hex -ge 97 -and $hex -le 102) -or
                              ($hex -ge 65 -and $hex -le 70))) { return -1 }
                }
                $index += 5
                continue
            }
            # " \ / b f n r t, compared by character CODE so the comparison
            # cannot be case-folded the way PowerShell's -eq on a char is.
            if ($escape -eq 34 -or $escape -eq 92 -or $escape -eq 47 -or
                $escape -eq 98 -or $escape -eq 102 -or $escape -eq 110 -or
                $escape -eq 114 -or $escape -eq 116) {
                $index++
                continue
            }
            return -1
        }
        if ($code -lt 32) { return -1 }
        $index++
    }
    return -1
}

function Get-StrictJsonNumberEnd {
    # Consumes the longest prefix at $Start matching python3's number grammar
    #     -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?
    # and returns the index just past it, or -1 when no number starts here.
    # The two optional groups are consumed ONLY when they match in full, so a
    # trailing '.' or a bare exponent marker is left unconsumed and the
    # caller's next-token check rejects it -- exactly what python does. A
    # leading zero likewise ends the number after the '0', leaving the
    # following digit to be rejected as an unexpected token, which is how
    # `01` and `0x1F` are caught.
    param([char[]]$Chars, [int]$Start)
    $limit = $Chars.Length
    $index = $Start
    if ($index -lt $limit -and [int]$Chars[$index] -eq 45) { $index++ }
    if ($index -ge $limit) { return -1 }
    $code = [int]$Chars[$index]
    if ($code -eq 48) {
        $index++
    } elseif ($code -ge 49 -and $code -le 57) {
        $index++
        while ($index -lt $limit -and [int]$Chars[$index] -ge 48 -and [int]$Chars[$index] -le 57) { $index++ }
    } else {
        return -1
    }
    if ($index -lt $limit -and [int]$Chars[$index] -eq 46) {
        $scan = $index + 1
        if ($scan -lt $limit -and [int]$Chars[$scan] -ge 48 -and [int]$Chars[$scan] -le 57) {
            while ($scan -lt $limit -and [int]$Chars[$scan] -ge 48 -and [int]$Chars[$scan] -le 57) { $scan++ }
            $index = $scan
        }
    }
    if ($index -lt $limit) {
        $code = [int]$Chars[$index]
        if ($code -eq 101 -or $code -eq 69) {
            $scan = $index + 1
            if ($scan -lt $limit) {
                $sign = [int]$Chars[$scan]
                if ($sign -eq 43 -or $sign -eq 45) { $scan++ }
            }
            if ($scan -lt $limit -and [int]$Chars[$scan] -ge 48 -and [int]$Chars[$scan] -le 57) {
                while ($scan -lt $limit -and [int]$Chars[$scan] -ge 48 -and [int]$Chars[$scan] -le 57) { $scan++ }
                $index = $scan
            }
        }
    }
    return $index
}

function Test-StrictJsonText {
    # The strictness gate REQ-004(a) needs and RT-20260819-001 records as
    # missing. Returns $true for EXACTLY the documents the .sh twin's python3
    # `json.loads` accepts -- no more and no less -- so the two twins reach
    # the same verdict on the same bytes (REQ-006, design.md DD-7).
    #
    # The parity target is `json.loads`, NOT RFC 8259. python3 accepts three
    # things RFC 8259 forbids -- the bare literals NaN, Infinity and
    # -Infinity, and duplicate object keys (last value wins) -- so this
    # scanner accepts them too. "Improving" on json.loads by rejecting them
    # would replace one twin divergence with another in the opposite
    # direction, which is why they are called out here rather than left to
    # look like oversights.
    #
    # Written as one pass over the text with an EXPLICIT container stack
    # rather than mutual recursion, so a deeply nested document cannot
    # exhaust the PowerShell call stack. Every character test compares
    # integer character codes, never characters or strings through -eq: -eq
    # is case-insensitive in PowerShell, which would silently accept \U as an
    # escape prefix and `NAN` as a literal.
    param([string]$Text)

    $chars = $Text.ToCharArray()
    $limit = $chars.Length
    $position = 0

    # 123 marks an open object on the stack, 91 an open array.
    $stack = New-Object 'System.Collections.Generic.List[int]'

    # value          -- a value must start here
    # value-or-close -- a value or the ']' of an empty array
    # key            -- an object member name must start here
    # key-or-close   -- a member name or the '}' of an empty object
    # after          -- a complete value was just read
    $state = 'value'
    $documentComplete = $false

    while ($true) {
        # RFC 8259 and python's whitespace class agree on exactly four
        # characters between tokens: space, tab, LF, CR. Nothing else -- not
        # a form feed, not a vertical tab, not U+00A0 -- separates tokens.
        while ($position -lt $limit) {
            $code = [int]$chars[$position]
            if ($code -eq 32 -or $code -eq 9 -or $code -eq 10 -or $code -eq 13) { $position++ } else { break }
        }

        if ($state -ceq 'after') {
            if ($stack.Count -eq 0) { $documentComplete = $true; break }
            if ($position -ge $limit) { return $false }
            $code = [int]$chars[$position]
            if ($stack[$stack.Count - 1] -eq 123) {
                if ($code -eq 125) { $position++; $stack.RemoveAt($stack.Count - 1); continue }
                # A ',' inside an object must be followed by another member
                # name, never by '}'. That is the trailing-comma rejection.
                if ($code -eq 44) { $position++; $state = 'key'; continue }
                return $false
            }
            if ($code -eq 93) { $position++; $stack.RemoveAt($stack.Count - 1); continue }
            if ($code -eq 44) { $position++; $state = 'value'; continue }
            return $false
        }

        if ($state -ceq 'key-or-close') {
            if ($position -lt $limit -and [int]$chars[$position] -eq 125) {
                $position++
                $stack.RemoveAt($stack.Count - 1)
                $state = 'after'
                continue
            }
            $state = 'key'
        }

        if ($state -ceq 'key') {
            # A member name is a STRING literal. An unquoted or single-quoted
            # name is rejected here.
            if ($position -ge $limit -or [int]$chars[$position] -ne 34) { return $false }
            $end = Get-StrictJsonStringEnd -Chars $chars -Start $position
            if ($end -lt 0) { return $false }
            $position = $end
            while ($position -lt $limit) {
                $code = [int]$chars[$position]
                if ($code -eq 32 -or $code -eq 9 -or $code -eq 10 -or $code -eq 13) { $position++ } else { break }
            }
            if ($position -ge $limit -or [int]$chars[$position] -ne 58) { return $false }
            $position++
            $state = 'value'
            continue
        }

        if ($state -ceq 'value-or-close') {
            if ($position -lt $limit -and [int]$chars[$position] -eq 93) {
                $position++
                $stack.RemoveAt($stack.Count - 1)
                $state = 'after'
                continue
            }
            $state = 'value'
        }

        if ($position -ge $limit) { return $false }
        $code = [int]$chars[$position]
        if ($code -eq 123) { $stack.Add(123); $position++; $state = 'key-or-close'; continue }
        if ($code -eq 91) { $stack.Add(91); $position++; $state = 'value-or-close'; continue }
        if ($code -eq 34) {
            $end = Get-StrictJsonStringEnd -Chars $chars -Start $position
            if ($end -lt 0) { return $false }
            $position = $end
            $state = 'after'
            continue
        }
        if ($code -eq 110 -and (Test-StrictJsonLiteralAt -Text $Text -Start $position -Literal 'null')) { $position += 4; $state = 'after'; continue }
        if ($code -eq 116 -and (Test-StrictJsonLiteralAt -Text $Text -Start $position -Literal 'true')) { $position += 4; $state = 'after'; continue }
        if ($code -eq 102 -and (Test-StrictJsonLiteralAt -Text $Text -Start $position -Literal 'false')) { $position += 5; $state = 'after'; continue }
        if ($code -eq 45 -or ($code -ge 48 -and $code -le 57)) {
            $end = Get-StrictJsonNumberEnd -Chars $chars -Start $position
            if ($end -ge 0) { $position = $end; $state = 'after'; continue }
            # A '-' that opens no number can still open python3's -Infinity.
            if ($code -eq 45 -and (Test-StrictJsonLiteralAt -Text $Text -Start $position -Literal '-Infinity')) {
                $position += 9
                $state = 'after'
                continue
            }
            return $false
        }
        # The two remaining python3 extensions. See the parity note above:
        # accepted on purpose, because the .sh twin accepts them.
        if ($code -eq 78 -and (Test-StrictJsonLiteralAt -Text $Text -Start $position -Literal 'NaN')) { $position += 3; $state = 'after'; continue }
        if ($code -eq 73 -and (Test-StrictJsonLiteralAt -Text $Text -Start $position -Literal 'Infinity')) { $position += 8; $state = 'after'; continue }
        return $false
    }

    # Exactly ONE top-level value, with nothing but whitespace after it.
    while ($position -lt $limit) {
        $code = [int]$chars[$position]
        if ($code -eq 32 -or $code -eq 9 -or $code -eq 10 -or $code -eq 13) { $position++ } else { break }
    }
    return ($documentComplete -and $position -eq $limit)
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
    # The strictness gate (RT-20260819-001). ConvertFrom-Json is lenient: it
    # accepts trailing commas, single-quoted and unquoted member names,
    # comments, raw control bytes, leading-zero and hexadecimal numbers, all
    # of which the .sh twin's python3 `json.loads` rejects. Left to decide
    # validity on its own it therefore declared invalid contracts VALID at
    # exit 0 while the .sh twin rejected them -- a fail-closed breach of
    # REQ-004(a) and a verdict-level twin divergence (REQ-006). The scanner
    # now decides; ConvertFrom-Json only builds the object afterwards, and
    # its own failure still falls back to the same single V2-PARSE line, so
    # the parse step stays fail-closed either way.
    if (-not (Test-StrictJsonText $text)) {
        Add-Violation 'V2-PARSE' 'input is not well-formed JSON and was not parsed further'
        return (Complete-Validation)
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
