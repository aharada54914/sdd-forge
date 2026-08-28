[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [AllowEmptyString()]
    [string]$Path,

    # NOT positional (no Position attribute) -- deliberately named-only,
    # matching design.md API/Contract Plan's own documented CLI surface
    # `check-risk-upgrade.ps1 -Path <source-path> [-CapabilityReasons
    # <fragment-path>]`. `check-risk-upgrade.ps1 <src> <frag>` (two bare
    # positional arguments, no flag) must not silently bind <frag> to this
    # parameter -- the sh twin has no positional form for
    # --capability-reasons either (its own `case "$#"` only recognizes 1
    # or 3 args; a bare 2-arg call falls into the `*)` default arm and
    # exits 2), so a positional CapabilityReasons would let the two
    # runtimes disagree on an identical-arity invocation (cross-model
    # panelist finding, T-002 remediation).
    [AllowNull()]
    [string]$CapabilityReasons
)

# epic-194-a6-lite-integration T-002 (REQ-002): extended with an optional
# -CapabilityReasons <fragment-path> parameter. Omitted entirely -> byte-
# identical to the pre-T-002 script (AC-007). Supplied -> unreadable/
# malformed/shape-invalid fragment is a hard error, exit 2, no trigger
# reporting (Blocker [B3]); a valid fragment's eligible:$false entries
# contribute their own upgrade_reasons tokens, or a synthetic
# "ineligible:<id>" token when upgrade_reasons is empty/absent (Blocker
# [B4]), appended AFTER the existing keyword-derived tokens (AC-008).

$ErrorActionPreference = 'Stop'

function Write-InputUnavailable {
    [Console]::Out.WriteLine('risk-upgrade: input unavailable')
    exit 2
}

function Write-FragmentInvalid {
    [Console]::Out.WriteLine('risk-upgrade: capability-reasons fragment invalid')
    exit 2
}

function ConvertTo-AsciiLower([string]$Value) {
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Value.ToCharArray()) {
        $codePoint = [int][char]$character
        if ($codePoint -ge 65 -and $codePoint -le 90) {
            [void]$builder.Append([char]($codePoint + 32))
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString()
}

function Test-BoundedMatch([string]$Value, [string]$Expression) {
    return [regex]::IsMatch($Value, '(^|[^a-z0-9_])(?:' + $Expression + ')(?=$|[^a-z0-9_])')
}

function Test-PythonFalsy($Value) {
    # ps1 twin of sh's `entry.get("upgrade_reasons") or []` -- Python
    # falsiness for the JSON scalar/array types ConvertFrom-Json can
    # produce, so a falsy-but-present upgrade_reasons value (0, "", false,
    # an empty array) is treated as absent on BOTH runtimes, and only a
    # truthy non-array value falls through to the array-type Block.
    if ($null -eq $Value) { return $true }
    if ($Value -is [bool]) { return -not $Value }
    if ($Value -is [string]) { return $Value.Length -eq 0 }
    if ($Value -is [array]) { return $Value.Count -eq 0 }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return $Value -eq 0 }
    return $false
}

try {
    if ($null -eq $Path -or $Path.Length -eq 0) {
        Write-InputUnavailable
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes -contains [byte]0) {
        Write-InputUnavailable
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $source = $utf8.GetString($bytes)
} catch {
    Write-InputUnavailable
}

$normalized = ConvertTo-AsciiLower $source
$normalized = $normalized.Replace("`r`n", "`n").Replace("`r", "`n")
$normalized = [regex]::Replace($normalized, '[ \t\n]+', ' ')
$normalized = [regex]::Replace(
    $normalized,
    '(^|[^a-z0-9_])design tokens?(?=$|[^a-z0-9_])',
    '$1 '
)

$rules = @(
    [PSCustomObject]@{ Id = 'AUTH_BOUNDARY'; Expression = 'auth|authentication|authorization|oauth|oidc' },
    [PSCustomObject]@{ Id = 'TOKEN_CREDENTIAL'; Expression = 'token|tokens|credential|credentials|password|passwords|private key(?:s)?' },
    [PSCustomObject]@{ Id = 'MCP'; Expression = 'mcp' },
    [PSCustomObject]@{ Id = 'EXTERNAL_API'; Expression = 'external[ -]+api(?:s)?|third[ -]+party[ -]+api(?:s)?' },
    [PSCustomObject]@{ Id = 'SECRET'; Expression = 'secret|secrets' },
    [PSCustomObject]@{ Id = 'GITHUB_ACTIONS'; Expression = 'github actions' }
)

$keywordTriggers = @($rules | Where-Object { Test-BoundedMatch $normalized $_.Expression } | ForEach-Object { $_.Id })

$capabilityTriggers = @()
# Presence of the parameter is what decides, not its emptiness --
# -CapabilityReasons '' is SUPPLIED (matches bash's argc-based
# capability_reasons_supplied=1 for `--capability-reasons ''`), not
# omitted. requirements.md Security Boundaries: the only condition that
# legitimately degrades is the second argument's own total absence
# (cross-model panelist finding, T-002 remediation).
if ($PSBoundParameters.ContainsKey('CapabilityReasons')) {
    try {
        if ($null -eq $CapabilityReasons -or $CapabilityReasons.Length -eq 0) { Write-FragmentInvalid }
        if (-not (Test-Path -LiteralPath $CapabilityReasons -PathType Leaf)) { Write-FragmentInvalid }
        $fragmentBytes = [IO.File]::ReadAllBytes($CapabilityReasons)
        $fragmentUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $fragmentText = $fragmentUtf8.GetString($fragmentBytes)
        $fragment = $fragmentText | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $fragment -or $null -eq $fragment.PSObject.Properties['capabilities']) {
            Write-FragmentInvalid
        }
        if ($fragment.capabilities -isnot [array]) {
            # ps1 twin of sh's `if not isinstance(capabilities, list): raise
            # ValueError("capabilities is not an array")` -- design.md API/
            # Contract Plan step 2b lists "capabilities not an array" as a
            # mandatory exit-2 condition. Without this check, @(...) below
            # silently wraps a bare object (e.g. `{"capabilities":
            # {"id":"x","eligible":false}}`) into a one-element array and
            # the object is then processed as a single valid entry
            # (cross-model panelist finding, T-002 remediation, escalated
            # to Critical).
            Write-FragmentInvalid
        }
        $capabilities = @($fragment.capabilities)
        foreach ($entry in $capabilities) {
            if ($null -eq $entry -or $null -eq $entry.PSObject.Properties['id'] -or $null -eq $entry.PSObject.Properties['eligible']) {
                Write-FragmentInvalid
            }
            $entryId = $entry.id
            if ($entryId -isnot [string] -or -not ($entryId -cmatch '\A[a-z0-9][a-z0-9-]*\z')) {
                # id must conform to the same capability-id grammar A2's own
                # Registry already enforces (contracts/capability-registry.
                # schema.json: "id": {"type": "string", "pattern":
                # "^[a-z0-9][a-z0-9-]*$"}) -- reusing an existing, already-
                # audited allowlist rather than inventing a bare comma/
                # semicolon blacklist (same "bounded grammar over an
                # unconstrained string" reasoning as NEW-01/INV-021's
                # required_lite_checks pattern). This also rejects the
                # empty string (requirements.md Field Definitions: "id"
                # is a non-empty string) and any embedded newline/space,
                # so a hostile id can never forge a second trigger entry
                # or break the single-line output-grammar contract
                # (cross-model panelist finding, T-002 remediation,
                # escalated to Critical). `\A`/`\z` (not `^`/`$`) are used
                # because .NET regex's `$` matches just before a trailing
                # `\n`, which would let an id ending in a newline slip
                # through undetected.
                Write-FragmentInvalid
            }
            if ($entry.eligible -isnot [bool]) {
                # eligible must be an actual JSON boolean, never a
                # truthy/falsy analog (0, "false", null, ...) -- a
                # shape-invalid entry must Block (exit 2), never silently
                # contribute nothing (AC-027's forbidden silent degrade;
                # cross-model panelist finding, T-002 remediation).
                Write-FragmentInvalid
            }
            # Amended design.md 2b (2026-08-28, RT-20260828-001): ps1 twin
            # of sh's unconditional shape/grammar validation -- EVERY
            # entry, in this loop, BEFORE eligibility is consulted (2b
            # runs before 2c). Under the pre-amendment placement (inside
            # the eligible -eq $false branch below) an eligible:true entry
            # carrying a malformed value was silently accepted (exit 0,
            # lite-eligible), the conformance fail-open all three
            # cross-model panelists flagged. A present-but-falsy value is
            # absent (Test-PythonFalsy), matching sh's `or []` --
            # ratified live behavior, TEST-013ai/aj.
            if ($null -ne $entry.PSObject.Properties['upgrade_reasons'] -and $null -ne $entry.upgrade_reasons -and -not (Test-PythonFalsy $entry.upgrade_reasons)) {
                if ($entry.upgrade_reasons -isnot [array]) {
                    # ps1 twin of sh's `if not isinstance(reasons, list):
                    # raise ValueError(...)` -- a scalar upgrade_reasons
                    # value must Block (exit 2), not be silently wrapped
                    # into a one-element array and emitted as a trigger
                    # token (cross-model panelist finding, T-002
                    # remediation).
                    Write-FragmentInvalid
                }
                # Validate the elements of the RAW array, before @()
                # touches it. @() flattens one level, so a nested array
                # ([["x"]]) would otherwise arrive here as the bare
                # string "x" and pass -- which is precisely how the two
                # runtimes came to disagree on that input before this
                # fix (measured: sh emitted "['x']", ps1 emitted "x").
                # Iterating the raw array keeps the nested element an
                # [object[]], which is -isnot [string], so both runtimes
                # now Block it identically.
                #
                # ps1 twin of sh's upgrade_reason_pattern -- see that
                # script for the full reasoning (same output grammar as
                # the id field, bounded allowlist rather than a
                # delimiter blacklist, shape not catalog vocabulary).
                # \A/\z (not ^/$) for the same trailing-newline reason
                # as the id pattern above.
                foreach ($token in $entry.upgrade_reasons) {
                    if ($token -isnot [string] -or -not ($token -cmatch '\A[a-z0-9][a-z0-9_-]*\z')) {
                        Write-FragmentInvalid
                    }
                }
            }
        }
        foreach ($entry in $capabilities) {
            # design.md API/Contract Plan: "entry['eligible'] == false" --
            # entry.eligible is already validated as a real [bool] above,
            # so -eq performs no coercion here. This loop only EMITS:
            # shape/grammar was validated for every entry in the loop
            # above (amended 2b).
            if ($entry.eligible -eq $false) {
                $reasons = @()
                if ($null -ne $entry.PSObject.Properties['upgrade_reasons'] -and $null -ne $entry.upgrade_reasons -and -not (Test-PythonFalsy $entry.upgrade_reasons)) {
                    $reasons = @($entry.upgrade_reasons)
                }
                # No [string] cast anywhere below: every token is a validated
                # [string] and $entry.id was validated as a [string] above, so
                # the casts these two lines used to carry were the mechanism
                # of the defect, not a safeguard. Their absence is the
                # property -- a future edit reintroducing [string]/str() here
                # reintroduces the bug.
                if ($reasons.Count -gt 0) {
                    foreach ($token in $reasons) { $capabilityTriggers += $token }
                } else {
                    $capabilityTriggers += ('ineligible:' + $entry.id)
                }
            }
        }
    } catch {
        Write-FragmentInvalid
    }
}

$allTriggers = @($keywordTriggers + $capabilityTriggers)
if ($allTriggers.Count -eq 0) {
    [Console]::Out.WriteLine('lite-eligible')
    exit 0
}

[Console]::Out.WriteLine(('full-required: {0}; triggers={1}' -f $allTriggers[0], ($allTriggers -join ',')))
exit 10
