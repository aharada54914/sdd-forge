# Component path ownership resolver — PowerShell twin (INV-008 convention).
#
# epic-191-a3-path-ownership T-001: implements REQ-001 (glob semantics,
# normalization, schema conformance) and REQ-002 (exclusive/shared
# classification, overlap/unowned detection, excluded-match evidence).
# This is a full, independent parallel implementation of
# resolve-component-paths.py's logic (not a wrapper that shells out to
# Python) — the same INV-008 convention check-contract.ps1/.py already
# establish in this repository. T-006's dual-runtime parity harness diffs
# this script's output against the Python master's, directly.
#
# Usage (classification mode):
#   resolve-component-paths.ps1 -Config <project-context.yaml> `
#       [-ChangedPathsFile <file, one raw path per line>] [-Json]
#   (omitting -ChangedPathsFile reads newline-separated raw paths from stdin)
#   (-Json is an accepted no-op; stdout is JSON in every mode regardless)
#
# Usage (schema-conformance mode, AC-011 — FAIL-closed on absence):
#   resolve-component-paths.ps1 -CheckSchemaConformance `
#       [-Schema <path, default contracts/project-context.template.yaml>]
#
# Exit code 0 on a clean resolve (even with UNOWNED/OVERLAP results present
# — classification results are data, not failure by themselves). Non-zero
# on a config-shape error, an unsupported-metacharacter pattern, or an
# NFC-collision (REQ-001); non-zero in schema-conformance mode whenever the
# artifact is absent or divergent (AC-011).
#
# This restricted YAML-subset parser mirrors resolve-component-paths.py's
# own — deliberately not a general YAML 1.2 implementation (no
# Microsoft.PowerShell.Yaml module dependency is assumed to be installed in
# CI). Its schema-conformance mode validates the projection against Epic A1's
# landed canonical schema and template.

param(
    [string]$Config,
    [string]$ChangedPathsFile,
    [string]$SourceRev = "HEAD",
    [string]$TargetRev,
    [bool]$IncludeUntracked = $true,
    [string]$RepoRoot = ".",
    [switch]$CheckSchemaConformance,
    [string]$Schema = "contracts/project-context.template.yaml",
    [string]$SchemaContract = "contracts/project-context.schema.json",
    [switch]$Diagnose,
    [string]$ProviderBindings = "sdd/provider-bindings.yaml",
    # Accepted no-op, mirroring the Python master's --json. Every mode of both
    # runtimes already writes JSON to stdout unconditionally and neither has an
    # alternative output format, but this script's usage text and design.md's
    # API/Contract Plan both advertise the flag, so the documented invocation
    # must not fall through to the unknown-argument rejection below.
    [switch]$Json
)

# A plain PowerShell param() block leaves unknown named arguments in $args.
# Reject them explicitly so this independent twin preserves argparse's
# observable CLI contract: usage-shaped stderr, the argument name, and exit 2.
if ($args.Count -gt 0) {
    $scriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Path)
    [Console]::Error.WriteLine("usage: $scriptName [options]")
    [Console]::Error.WriteLine("${scriptName}: error: unrecognized arguments: $($args -join ' ')")
    exit 2
}

$ErrorActionPreference = "Stop"

$MATCHER_SEMANTICS_VERSION = "1.0.0"
$RESOLVER_VERSION = "1.1.0"
$PROJECT_CONTEXT_SCHEMA_VERSION = "sdd-project-context/v1"
$UNSUPPORTED_METACHARS = @("?", "[", "]", "{", "}", "(", ")", "!", "+", "@", "^", "$", "|", "~")

class ConfigError : System.Exception {
    ConfigError([string]$message) : base($message) {}
}
class CollisionError : System.Exception {
    CollisionError([string]$message) : base($message) {}
}

function Get-CanonicalDigest {
    param($Value)
    $canonicalizer = Join-Path $PSScriptRoot "canonicalize-sdd-yaml.ps1"
    $tempPath = Join-Path ([IO.Path]::GetTempPath()) ("resolve-component-paths-" + [guid]::NewGuid().ToString("N") + ".json")
    try {
        $json = $Value | ConvertTo-Json -Depth 30 -Compress
        [IO.File]::WriteAllText($tempPath, $json, [Text.UTF8Encoding]::new($false))
        $powerShell = (Get-Process -Id $PID).Path
        $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $canonicalizer $tempPath --input-format json --hash-only 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } catch {
        throw [ConfigError]::new("ownership digest canonicalizer could not be invoked: $($_.Exception.Message)")
    } finally {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
    if ($exitCode -ne 0) {
        throw [ConfigError]::new("ownership digest canonicalization failed (exit ${exitCode}): $($output.Trim())")
    }
    $digest = $output.Trim()
    if ($digest -cnotmatch '^sha256:[0-9a-f]{64}$') {
        throw [ConfigError]::new("ownership digest canonicalizer returned a malformed digest")
    }
    return $digest
}

# --------------------------------------------------------------------------
# Minimal restricted YAML-subset parser (mirrors the Python master exactly)
# --------------------------------------------------------------------------

function Strip-Comment {
    param([string]$Line)
    $inSingle = $false
    $inDouble = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $ch = $Line[$i]
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle }
        elseif ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble }
        elseif ($ch -eq '#' -and -not $inSingle -and -not $inDouble) {
            if ($i -eq 0 -or $Line[$i - 1] -eq ' ' -or $Line[$i - 1] -eq "`t") {
                return $Line.Substring(0, $i)
            }
        }
    }
    return $Line
}

function Parse-ScalarValue {
    param([string]$Raw)
    $s = $Raw.Trim()
    # The canonical project-context template intentionally ships with an
    # empty component inventory. Support exactly the empty flow sequence;
    # all other flow-style YAML remains outside this restricted parser.
    if ($s -ceq "[]") {
        return ,([object[]]@())
    }
    if ($s.Length -ge 2 -and $s[0] -eq '"' -and $s[-1] -eq '"') {
        return $s.Substring(1, $s.Length - 2)
    }
    if ($s.Length -ge 2 -and $s[0] -eq "'" -and $s[-1] -eq "'") {
        return $s.Substring(1, $s.Length - 2)
    }
    foreach ($forbidden in @("[", "]", "{", "}", "&", "*", "!", "|", ">", "%", "@", "``")) {
        if ($s.StartsWith($forbidden)) {
            throw [ConfigError]::new("unsupported YAML construct at start of scalar: '$Raw' (quote glob patterns beginning with '$forbidden')")
        }
    }
    return $s
}

function Get-IndentOf {
    param([string]$Line)
    return $Line.Length - $Line.TrimStart(" ").Length
}

function Get-LeadingWhitespace {
    # Deliberately trims BOTH " " and "`t" here (unlike Get-IndentOf, which
    # only trims " " to measure a space-only indent depth), so the tab
    # guard below sees the true leading-whitespace run. A bare leading tab
    # has zero leading SPACES, so `$raw.Substring(0, (Get-IndentOf $raw))`
    # -- taking only as many characters as Get-IndentOf counted -- was
    # always the empty string for such a line and could never contain a
    # tab; the same held for spaces-then-tab indentation, since
    # Get-IndentOf stops counting at the first non-space character. That
    # made the guard this replaces permanently unable to fire for any
    # tab-indented line, not just a bare leading tab (mirrors the identical
    # fix in resolve-component-paths.py's _leading_whitespace).
    param([string]$Line)
    $trimmedLen = $Line.TrimStart(" ", "`t").Length
    return $Line.Substring(0, $Line.Length - $trimmedLen)
}

class YamlLineReader {
    [System.Collections.Generic.List[object]]$Lines
    [int]$Pos

    YamlLineReader([string]$Text) {
        $this.Lines = [System.Collections.Generic.List[object]]::new()
        $this.Pos = 0
        $normalized = $Text -replace "`r`n", "`n" -replace "`r", "`n"
        foreach ($raw in $normalized -split "`n") {
            $stripped = (Strip-Comment $raw).TrimEnd()
            if ($stripped.Trim() -eq "") { continue }
            if ((Get-LeadingWhitespace $raw).Contains("`t")) {
                throw [ConfigError]::new("YAML indentation must use spaces, not tabs")
            }
            $indent = Get-IndentOf $stripped
            $this.Lines.Add(@{ Indent = $indent; Content = $stripped.Trim() })
        }
    }

    [object] Peek() {
        if ($this.Pos -ge $this.Lines.Count) { return $null }
        return $this.Lines[$this.Pos]
    }

    [object] Advance() {
        $item = $this.Lines[$this.Pos]
        $this.Pos += 1
        return $item
    }
}

function Test-LooksLikeMappingEntry {
    param([string]$S)
    $idx = $S.IndexOf(":")
    if ($idx -eq -1) { return $false }
    if ($idx -eq $S.Length - 1) { return $true }
    return $S[$idx + 1] -eq " "
}

function New-OrdinalMapping {
    # PowerShell's [ordered]@{} uses a case-insensitive comparer. YAML/JSON
    # contract field names are case-sensitive, so use an insertion-ordered
    # dictionary whose comparer is explicitly ordinal (WFI-012).
    return [System.Collections.Specialized.OrderedDictionary]::new(
        [System.StringComparer]::Ordinal
    )
}

function Parse-Block {
    param([YamlLineReader]$Lines, [int]$Indent)
    $peeked = $Lines.Peek()
    if ($null -eq $peeked) { return (New-OrdinalMapping) }
    if ($peeked.Indent -ne $Indent) {
        throw [ConfigError]::new("unexpected indentation at: '$($peeked.Content)'")
    }
    if ($peeked.Content.StartsWith("- ")) {
        return Parse-Sequence -Lines $Lines -Indent $Indent
    }
    return Parse-Mapping -Lines $Lines -Indent $Indent
}

function Parse-Sequence {
    param([YamlLineReader]$Lines, [int]$Indent)
    $items = [System.Collections.Generic.List[object]]::new()
    while ($true) {
        $peeked = $Lines.Peek()
        if ($null -eq $peeked -or $peeked.Indent -ne $Indent -or -not $peeked.Content.StartsWith("-")) { break }
        $entry = $Lines.Advance()
        $content = $entry.Content
        $rest = if ($content -eq "-") { "" } else { $content.Substring(1).TrimStart() }
        if ($rest -eq "") {
            $nxt = $Lines.Peek()
            if ($null -eq $nxt -or $nxt.Indent -le $Indent) {
                $items.Add($null)
                continue
            }
            $items.Add((Parse-Block -Lines $Lines -Indent $nxt.Indent))
            continue
        }
        if (Test-LooksLikeMappingEntry $rest) {
            $afterDashCol = $Indent + $content.IndexOf($rest[0])
            $items.Add((Parse-InlineMappingEntry -Lines $Lines -FirstRest $rest -KeyCol $afterDashCol))
            continue
        }
        $items.Add((Parse-ScalarValue $rest))
    }
    return , $items.ToArray()
}

function Parse-InlineMappingEntry {
    param([YamlLineReader]$Lines, [string]$FirstRest, [int]$KeyCol)
    $result = New-OrdinalMapping
    $idx = $FirstRest.IndexOf(":")
    $key = $FirstRest.Substring(0, $idx).Trim()
    $value = $FirstRest.Substring($idx + 1).Trim()
    if ($value -eq "") {
        $nxt = $Lines.Peek()
        if ($null -ne $nxt -and $nxt.Indent -gt $KeyCol) {
            $result[$key] = Parse-Block -Lines $Lines -Indent $nxt.Indent
        } else {
            $result[$key] = $null
        }
    } else {
        $result[$key] = Parse-ScalarValue $value
    }
    while ($true) {
        $nxt = $Lines.Peek()
        if ($null -eq $nxt -or $nxt.Indent -ne $KeyCol) { break }
        $entry = $Lines.Advance()
        $c = $entry.Content
        if (-not (Test-LooksLikeMappingEntry $c)) {
            throw [ConfigError]::new("expected 'key: value' inside list item, got: '$c'")
        }
        $idx2 = $c.IndexOf(":")
        $k = $c.Substring(0, $idx2).Trim()
        $v = $c.Substring($idx2 + 1).Trim()
        if ($v -eq "") {
            $nxt2 = $Lines.Peek()
            if ($null -ne $nxt2 -and $nxt2.Indent -gt $KeyCol) {
                $result[$k] = Parse-Block -Lines $Lines -Indent $nxt2.Indent
            } else {
                $result[$k] = $null
            }
        } else {
            $result[$k] = Parse-ScalarValue $v
        }
    }
    return $result
}

function Parse-Mapping {
    param([YamlLineReader]$Lines, [int]$Indent)
    $result = New-OrdinalMapping
    while ($true) {
        $peeked = $Lines.Peek()
        if ($null -eq $peeked -or $peeked.Indent -ne $Indent) { break }
        if ($peeked.Content.StartsWith("- ")) { break }
        $entry = $Lines.Advance()
        $content = $entry.Content
        if (-not (Test-LooksLikeMappingEntry $content)) {
            throw [ConfigError]::new("expected 'key: value' mapping entry, got: '$content'")
        }
        $idx = $content.IndexOf(":")
        $key = $content.Substring(0, $idx).Trim()
        $value = $content.Substring($idx + 1).Trim()
        if ($value -eq "") {
            $nxt = $Lines.Peek()
            if ($null -ne $nxt -and $nxt.Indent -gt $Indent) {
                $result[$key] = Parse-Block -Lines $Lines -Indent $nxt.Indent
            } else {
                $result[$key] = $null
            }
        } else {
            $result[$key] = Parse-ScalarValue $value
        }
    }
    return $result
}

function ConvertFrom-MinimalYaml {
    param([string]$Text)
    $lines = [YamlLineReader]::new($Text)
    if ($null -eq $lines.Peek()) { return (New-OrdinalMapping) }
    $topIndent = $lines.Peek().Indent
    $value = Parse-Block -Lines $lines -Indent $topIndent
    if ($null -ne $lines.Peek()) {
        throw [ConfigError]::new("unexpected trailing content at: '$($lines.Peek().Content)'")
    }
    if ($value -isnot [System.Collections.IDictionary]) {
        throw [ConfigError]::new("top-level YAML document must be a mapping")
    }
    return $value
}

# --------------------------------------------------------------------------
# Glob compiler and matcher (REQ-001)
# --------------------------------------------------------------------------

function ConvertTo-Nfc {
    param([string]$S)
    return $S.Normalize([System.Text.NormalizationForm]::FormC)
}

function Confirm-AndNormalizePattern {
    param([string]$Pattern)
    if ([string]::IsNullOrEmpty($Pattern)) {
        throw [ConfigError]::new("pattern must be a non-empty string")
    }
    $normalized = $Pattern.Replace("\", "/")
    foreach ($ch in $normalized.ToCharArray()) {
        if ($UNSUPPORTED_METACHARS -contains [string]$ch) {
            throw [ConfigError]::new("unsupported glob metacharacter '$ch' in pattern '$Pattern' (only '**', '*', '/', and literal path characters are supported)")
        }
    }
    return ConvertTo-Nfc $normalized
}

function Get-SegmentRegex {
    param([string]$Segment)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("^")
    foreach ($ch in $Segment.ToCharArray()) {
        if ($ch -eq "*") {
            [void]$sb.Append("[^/]*")
        } else {
            [void]$sb.Append([regex]::Escape([string]$ch))
        }
    }
    [void]$sb.Append("$")
    return [regex]::new($sb.ToString())
}

function Test-SegmentsMatch {
    param([string[]]$PatSegs, [string[]]$PathSegs)
    $memo = @{}
    function Recurse([int]$pi, [int]$si) {
        $key = "$pi|$si"
        if ($memo.ContainsKey($key)) { return $memo[$key] }
        if ($pi -eq $PatSegs.Count) {
            $result = ($si -eq $PathSegs.Count)
            $memo[$key] = $result
            return $result
        }
        $seg = $PatSegs[$pi]
        if ($seg -eq "**") {
            $result = $false
            for ($k = $si; $k -le $PathSegs.Count; $k++) {
                if (Recurse ($pi + 1) $k) { $result = $true; break }
            }
            $memo[$key] = $result
            return $result
        }
        if ($si -eq $PathSegs.Count) {
            $memo[$key] = $false
            return $false
        }
        $rx = Get-SegmentRegex $seg
        if (-not $rx.IsMatch($PathSegs[$si])) {
            $memo[$key] = $false
            return $false
        }
        $result = Recurse ($pi + 1) ($si + 1)
        $memo[$key] = $result
        return $result
    }
    return Recurse 0 0
}

function Test-PatternMatches {
    param([string]$PatternNormalized, [string]$PathNfc)
    $patSegs = $PatternNormalized -split "/"
    $pathSegs = $PathNfc -split "/"
    return Test-SegmentsMatch -PatSegs $patSegs -PathSegs $pathSegs
}

# --------------------------------------------------------------------------
# Config loading and validation
# --------------------------------------------------------------------------

function Get-StringList {
    # NOTE: callers must not rely on PowerShell pipeline unrolling of the
    # returned array — `return ,@()` (leading comma) is required, or a
    # zero-element result collapses to $null across the function-call
    # boundary, which then makes `$null | ForEach-Object { ... }` invoke the
    # scriptblock ONCE with $_ = $null (PowerShell's well-known
    # empty-array-vs-$null pipeline pitfall) instead of zero times.
    param($Value, [string]$Field)
    if ($null -eq $Value) { return , @() }
    if ($Value -isnot [System.Array] -and $Value -isnot [System.Collections.IEnumerable]) {
        throw [ConfigError]::new("$Field must be a list")
    }
    if ($Value -is [string]) {
        throw [ConfigError]::new("$Field must be a list")
    }
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $Value) {
        if ($null -eq $item -or $item -isnot [string]) {
            throw [ConfigError]::new("$Field entries must be strings")
        }
        $out.Add($item)
    }
    return , $out.ToArray()
}

function ConvertTo-NormalizedPatternList {
    # Uses the `foreach` statement keyword, not the `ForEach-Object`
    # cmdlet/pipeline: `foreach ($x in $null) {}` correctly performs zero
    # iterations in PowerShell, avoiding the pipeline null-unrolling trap
    # `$null | ForEach-Object { ... }` falls into (see Get-StringList).
    param([string[]]$Patterns)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $Patterns) {
        $out.Add((Confirm-AndNormalizePattern $p))
    }
    return , $out.ToArray()
}

function New-ComponentObject {
    param([string]$Name, [string[]]$IncludeRaw, [string[]]$ExcludeRaw)
    $include = ConvertTo-NormalizedPatternList -Patterns $IncludeRaw
    $exclude = ConvertTo-NormalizedPatternList -Patterns $ExcludeRaw
    return [pscustomobject]@{
        Name       = $Name
        IncludeRaw = $IncludeRaw
        ExcludeRaw = $ExcludeRaw
        Include    = $include
        Exclude    = $exclude
    }
}

function New-SharedPathEntryObject {
    param([string]$PatternRaw, $Components, $Classification)
    return [pscustomobject]@{
        PatternRaw     = $PatternRaw
        Pattern        = Confirm-AndNormalizePattern $PatternRaw
        Components     = $Components
        Classification = $Classification
    }
}

function ConvertTo-ConfigObject {
    param($Data)
    if ($Data -isnot [System.Collections.IDictionary]) {
        throw [ConfigError]::new("config must be a mapping")
    }
    $componentsRaw = $Data["components"]
    if ($null -eq $componentsRaw -or $componentsRaw -isnot [System.Array]) {
        throw [ConfigError]::new("config.components must be a list")
    }
    $components = [System.Collections.Generic.List[object]]::new()
    # Ordinal, not PowerShell's default case-insensitive @{} (see the
    # nfcToRaw comment in Invoke-ClassifyPaths for the same pitfall) — two
    # component names differing only by case are distinct names.
    $seenNames = [System.Collections.Generic.Dictionary[string, bool]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $componentsRaw) {
        if ($entry -isnot [System.Collections.IDictionary]) {
            throw [ConfigError]::new("each components[] entry must be a mapping")
        }
        $hasId = $entry.Contains("id") -and $null -ne $entry["id"]
        $hasName = $entry.Contains("name") -and $null -ne $entry["name"]
        if ($hasName) {
            throw [ConfigError]::new("legacy 'name' is not supported; use canonical component field 'id'")
        }
        $name = if ($hasId) { $entry["id"] } else { $null }
        if ([string]::IsNullOrEmpty($name)) {
            throw [ConfigError]::new("each component requires a non-empty 'id'")
        }
        if ($seenNames.ContainsKey($name)) {
            throw [ConfigError]::new("duplicate component name: $name")
        }
        $seenNames[$name] = $true
        $paths = $entry["paths"]
        if ($paths -isnot [System.Collections.IDictionary]) {
            throw [ConfigError]::new("component '$name' requires a 'paths' mapping")
        }
        $includeRaw = Get-StringList -Value $paths["include"] -Field "component '$name' paths.include"
        $excludeRaw = Get-StringList -Value $paths["exclude"] -Field "component '$name' paths.exclude"
        if ($includeRaw.Count -eq 0) {
            throw [ConfigError]::new("component '$name' has an empty paths.include list")
        }
        $components.Add((New-ComponentObject -Name $name -IncludeRaw $includeRaw -ExcludeRaw $excludeRaw))
    }

    $sharedPaths = [System.Collections.Generic.List[object]]::new()
    $sharedRaw = $Data["shared_paths"]
    if ($null -ne $sharedRaw) {
        if ($sharedRaw -isnot [System.Array]) {
            throw [ConfigError]::new("config.shared_paths must be a list")
        }
        foreach ($entry in $sharedRaw) {
            if ($entry -isnot [System.Collections.IDictionary]) {
                throw [ConfigError]::new("each shared_paths[] entry must be a mapping")
            }
            $pattern = $entry["pattern"]
            if ([string]::IsNullOrEmpty($pattern)) {
                throw [ConfigError]::new("each shared_paths[] entry requires a non-empty 'pattern'")
            }
            $hasComponents = $entry.Contains("components") -and $null -ne $entry["components"]
            $classification = $entry["classification"]
            $hasClassification = $null -ne $classification
            if ($hasComponents -eq $hasClassification) {
                throw [ConfigError]::new("shared_paths entry '$pattern' must carry exactly one of 'components' (bounded) or 'classification: cross-cutting' (unbounded), never both or neither")
            }
            if ($hasClassification) {
                if ($classification -cne "cross-cutting") {
                    throw [ConfigError]::new("shared_paths entry '$pattern' has unsupported classification '$classification' (only 'cross-cutting' is defined)")
                }
                $sharedPaths.Add((New-SharedPathEntryObject -PatternRaw $pattern -Components $null -Classification "cross-cutting"))
            } else {
                $compList = Get-StringList -Value $entry["components"] -Field "shared_paths '$pattern' components"
                if ($compList.Count -eq 0) {
                    throw [ConfigError]::new("shared_paths entry '$pattern' has an empty 'components' list (bounded form requires an explicit non-empty list)")
                }
                $sharedPaths.Add((New-SharedPathEntryObject -PatternRaw $pattern -Components $compList -Classification $null))
            }
        }
    }

    return [pscustomobject]@{
        Components  = $components
        SharedPaths = $sharedPaths
        Raw         = $Data
    }
}

function Import-ConfigText {
    param([string]$Text)
    $data = ConvertFrom-MinimalYaml $Text
    return ConvertTo-ConfigObject $data
}

function Import-ConfigFile {
    param([string]$Path)
    $text = Get-Content -Raw -LiteralPath $Path -Encoding utf8
    return Import-ConfigText $text
}

# --------------------------------------------------------------------------
# Classification (REQ-002)
# --------------------------------------------------------------------------

function Invoke-ClassifyPaths {
    param($Config, [string[]]$RawPaths)

    # NOTE: PowerShell's -eq/-ne operators use culture-aware string
    # comparison by default, under which an NFD-encoded and NFC-encoded
    # form of the same visual text compare EQUAL even though their
    # underlying UTF-16 code points differ (a real, observed PowerShell
    # pitfall — confirmed here: "café" -eq "café" is $true under
    # the default culture-aware comparer). AC-010's collision check is
    # explicitly about raw BYTE identity, so it must use ordinal comparison
    # ([string]::Equals(...,[StringComparison]::Ordinal)), never -eq/-ne.
    # NOTE: a bare `@{}` hashtable literal in PowerShell defaults to
    # CASE-INSENSITIVE key comparison (confirmed: @{}["Src/x"]="A";
    # @{}["src/x"]="B" collapses to ONE entry) — a third, distinct
    # PowerShell string-comparison pitfall alongside the -eq/-ne
    # culture-awareness issue above and the null-pipeline issue in
    # Get-StringList. An ordinal Dictionary is required here or two
    # same-NFC-key paths differing only by case (never a real AC-010
    # collision) would be misreported as one.
    $nfcToRaw = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($raw in $RawPaths) {
        $nfc = ConvertTo-Nfc $raw
        if ($nfcToRaw.ContainsKey($nfc) -and -not [string]::Equals($nfcToRaw[$nfc], $raw, [System.StringComparison]::Ordinal)) {
            throw [CollisionError]::new("NFC-normalization collision: '$($nfcToRaw[$nfc])' and '$raw' both normalize to '$nfc'")
        }
        $nfcToRaw[$nfc] = $raw
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $exclusiveOwners = [System.Collections.Generic.HashSet[string]]::new()
    $boundedSharedTouched = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($raw in $RawPaths) {
        $nfc = ConvertTo-Nfc $raw
        $sharedHit = $null
        foreach ($entry in $Config.SharedPaths) {
            if (Test-PatternMatches -PatternNormalized $entry.Pattern -PathNfc $nfc) {
                $sharedHit = $entry
                break
            }
        }

        if ($null -ne $sharedHit) {
            if ($null -ne $sharedHit.Components) {
                $classification = "SHARED_BOUNDED"
                $owning = @($sharedHit.Components)
                foreach ($c in $owning) { [void]$boundedSharedTouched.Add($c) }
            } else {
                $classification = "SHARED_CROSS_CUTTING"
                $owning = @()
            }
            $records.Add([ordered]@{
                raw_path        = $raw
                normalized_path = $nfc
                classification  = $classification
                owning_components = $owning
                evidence        = [ordered]@{ excluded_match = $null }
            })
            continue
        }

        $residualOwners = [System.Collections.Generic.List[string]]::new()
        $excludedMatchEvidence = [System.Collections.Generic.List[object]]::new()
        $anyIncludeMatched = $false
        foreach ($comp in $Config.Components) {
            $included = $false
            foreach ($p in $comp.Include) {
                if (Test-PatternMatches -PatternNormalized $p -PathNfc $nfc) { $included = $true; break }
            }
            if (-not $included) { continue }
            $anyIncludeMatched = $true
            $matchedExcludes = @($comp.Exclude | Where-Object { Test-PatternMatches -PatternNormalized $_ -PathNfc $nfc })
            if ($matchedExcludes.Count -gt 0) {
                foreach ($matchedPattern in $matchedExcludes) {
                    $excludedMatchEvidence.Add([ordered]@{ component = $comp.Name; pattern = $matchedPattern })
                }
                continue
            }
            $residualOwners.Add($comp.Name)
        }

        if ($residualOwners.Count -eq 1) {
            $classification = "EXCLUSIVE"
            [void]$exclusiveOwners.Add($residualOwners[0])
            $evidence = [ordered]@{ excluded_match = $null }
        } elseif ($residualOwners.Count -eq 0) {
            $classification = "UNOWNED"
            if ($anyIncludeMatched -and $excludedMatchEvidence.Count -gt 0) {
                $evidence = [ordered]@{ excluded_match = $excludedMatchEvidence.ToArray() }
            } else {
                $evidence = [ordered]@{ excluded_match = $null }
            }
        } else {
            $classification = "OVERLAP"
            if ($excludedMatchEvidence.Count -gt 0) {
                $evidence = [ordered]@{ excluded_match = $excludedMatchEvidence.ToArray() }
            } else {
                $evidence = [ordered]@{ excluded_match = $null }
            }
        }

        $records.Add([ordered]@{
            raw_path          = $raw
            normalized_path   = $nfc
            classification    = $classification
            owning_components = $residualOwners.ToArray()
            evidence          = $evidence
        })
    }

    # AC-010: "a stable sort over raw path bytes, deterministic even when a
    # [NFC] collision is present". PowerShell's Sort-Object uses
    # culture-aware string comparison by default (the same pitfall as the
    # collision check above), so this sorts by ordinal byte comparison of
    # each raw_path's UTF-8 encoding explicitly, via a stable .NET List
    # sort (List<T>.Sort is documented as NOT guaranteed-stable, so ties are
    # broken by original input index to keep the sort stable in practice).
    $indexed = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $records.Count; $i++) {
        $indexed.Add(@{ Index = $i; Record = $records[$i]; Bytes = [System.Text.Encoding]::UTF8.GetBytes($records[$i].raw_path) })
    }
    $comparer = [Comparison[object]] {
        param($a, $b)
        $ab = $a.Bytes
        $bb = $b.Bytes
        $minLen = [Math]::Min($ab.Length, $bb.Length)
        for ($k = 0; $k -lt $minLen; $k++) {
            if ($ab[$k] -ne $bb[$k]) { return [int]$ab[$k] - [int]$bb[$k] }
        }
        if ($ab.Length -ne $bb.Length) { return $ab.Length - $bb.Length }
        return $a.Index - $b.Index
    }
    $indexed.Sort($comparer)
    $sortedRecords = @($indexed | ForEach-Object { $_.Record })

    # Ordinal (not PowerShell's default culture-aware) sort/uniqueness, for
    # the same reason as the raw_path sort above and to keep this wrapper
    # byte-for-byte comparable with the Python master (T-006 parity harness).
    $affectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($n in $exclusiveOwners) { [void]$affectedSet.Add($n) }
    foreach ($n in $boundedSharedTouched) { [void]$affectedSet.Add($n) }
    $affectedList = [System.Collections.Generic.List[string]]::new($affectedSet)
    $affectedList.Sort([System.StringComparer]::Ordinal)
    $affectedComponents = @($affectedList)

    $ownershipInputComponents = @($Config.Components | ForEach-Object {
        [ordered]@{
            id    = $_.Name
            paths = [ordered]@{ include = $_.IncludeRaw; exclude = $_.ExcludeRaw }
        }
    })
    $ownershipInputShared = @($Config.SharedPaths | ForEach-Object {
        [ordered]@{ pattern = $_.PatternRaw; components = $_.Components; classification = $_.Classification }
    })

    $ownershipInput = [ordered]@{
        components                = $ownershipInputComponents
        shared_paths              = $ownershipInputShared
        matcher_semantics_version = $MATCHER_SEMANTICS_VERSION
    }
    $ownershipDigest = Get-CanonicalDigest $ownershipInput
    $ruleSetRevision = Get-CanonicalDigest ([ordered]@{
        matcher_semantics_version = $MATCHER_SEMANTICS_VERSION
    })

    return [ordered]@{
        records             = @($sortedRecords)
        affected_components = @($affectedComponents)
        ownership_input      = $ownershipInput
        context_binding      = [ordered]@{
            ownership_digest = $ownershipDigest
        }
        resolver             = [ordered]@{
            version           = $RESOLVER_VERSION
            rule_set_revision = $ruleSetRevision
        }
    }
}

# --------------------------------------------------------------------------
# Schema conformance (AC-011)
# --------------------------------------------------------------------------

function Test-JsonSchemaNodeType {
    param($Node, [string]$Expected)
    return $null -ne $Node -and $Node.type -is [string] -and $Node.type -ceq $Expected
}

function Test-RequiredField {
    param($Node, [string]$Field)
    if ($null -eq $Node.required) { return $false }
    return @($Node.required) -ccontains $Field
}

# JSON Schema draft-07 SUBSET validator — PowerShell twin of the Python
# master's `_schema_validate` (INV-008 parity, T-006). Same bounded-subset
# rationale and the same stated limit: the instance comes from this file's
# restricted YAML-subset parser, which yields every scalar as a string, so
# "boolean"/"integer"/"number" keywords accept string scalars rather than
# falsely rejecting them. Epic A1's schema declares booleans only under
# components[].characteristics, which the canonical template leaves unset.
function Test-JsonSchemaInstanceType {
    param($Expected, $Instance)
    if ($Expected -is [System.Array]) {
        foreach ($candidate in $Expected) {
            if (Test-JsonSchemaInstanceType $candidate $Instance) { return $true }
        }
        return $false
    }
    switch -CaseSensitive ($Expected) {
        "object"  { return ($Instance -is [System.Collections.IDictionary]) }
        "array"   { return ($Instance -is [System.Array]) }
        "string"  { return ($Instance -is [string]) }
        "null"    { return ($null -eq $Instance) }
        "boolean" { if ($Instance -is [string]) { return $true } return ($Instance -is [bool]) }
        "integer" { if ($Instance -is [string]) { return $true } return ($Instance -is [int] -or $Instance -is [long]) }
        "number"  { if ($Instance -is [string]) { return $true } return ($Instance -is [int] -or $Instance -is [long] -or $Instance -is [double]) }
        # Unknown type names fail CLOSED: a typo'd "type" keyword must reject
        # every instance, never silently validate all of them (INV-008 parity
        # with the Python master's _schema_type_ok).
        default   { return $false }
    }
}

function Test-JsonSchemaInstance {
    param($Schema, $Instance, [string]$Path = "/", $Root = $null)
    if ($null -eq $Schema) { return @() }
    if ($null -eq $Root) { $Root = $Schema }
    $keys = @($Schema.PSObject.Properties.Name)
    $errors = @()

    if ($keys -ccontains '$ref') {
        $ref = $Schema.'$ref'
        if ($ref -isnot [string] -or -not $ref.StartsWith('#/definitions/')) {
            return @("${Path}: unsupported `$ref '$ref'")
        }
        $target = $Root.definitions.($ref.Substring('#/definitions/'.Length))
        if ($null -eq $target) { return @("${Path}: unresolvable `$ref '$ref'") }
        return Test-JsonSchemaInstance $target $Instance $Path $Root
    }

    if ($keys -ccontains 'const' -and $Schema.const -cne $Instance) {
        $errors += "${Path}: expected const '$($Schema.const)', got '$Instance'"
    }
    if ($keys -ccontains 'enum' -and -not (@($Schema.enum) -ccontains $Instance)) {
        $errors += "${Path}: '$Instance' not in enum"
    }
    if ($keys -ccontains 'type' -and -not (Test-JsonSchemaInstanceType $Schema.type $Instance)) {
        $errors += "${Path}: expected $($Schema.type)"
    }

    $prefix = $Path.TrimEnd('/')
    if ($Instance -is [System.Collections.IDictionary]) {
        foreach ($req in @($Schema.required)) {
            if ($null -ne $req -and -not $Instance.Contains($req)) {
                $errors += "${Path}: missing required field '$req'"
            }
        }
        $propNames = @()
        if ($keys -ccontains 'properties') { $propNames = @($Schema.properties.PSObject.Properties.Name) }
        if (($keys -ccontains 'additionalProperties') -and ($Schema.additionalProperties -is [bool]) -and (-not $Schema.additionalProperties)) {
            foreach ($key in @($Instance.Keys)) {
                if ($propNames -cnotcontains $key) {
                    $errors += "${Path}: additional property '$key' not allowed"
                }
            }
        }
        foreach ($key in @($Instance.Keys)) {
            if ($propNames -ccontains $key) {
                $errors += Test-JsonSchemaInstance $Schema.properties.$key $Instance[$key] "$prefix/$key" $Root
            }
        }
    } elseif (($Instance -is [System.Array]) -and ($keys -ccontains 'items')) {
        for ($i = 0; $i -lt $Instance.Count; $i++) {
            $errors += Test-JsonSchemaInstance $Schema.items $Instance[$i] "$prefix/$i" $Root
        }
    } elseif (($Instance -is [string]) -and ($keys -ccontains 'minLength')) {
        if ($Instance.Length -lt $Schema.minLength) {
            $errors += "${Path}: shorter than minLength $($Schema.minLength)"
        }
    }

    if ($keys -ccontains 'oneOf') {
        $matched = 0
        foreach ($branch in @($Schema.oneOf)) {
            if (@(Test-JsonSchemaInstance $branch $Instance $Path $Root).Count -eq 0) { $matched++ }
        }
        if ($matched -ne 1) {
            $errors += "${Path}: oneOf matched $matched branches (need exactly 1)"
        }
    }
    return $errors
}

function Test-SchemaConformance {
    param([string]$SchemaPath, [string]$SchemaContractPath)
    if (-not (Test-Path -LiteralPath $SchemaContractPath -PathType Leaf)) {
        return @{ Conformant = $false; Diagnostic = "schema contract absent: $SchemaContractPath" }
    }
    try {
        $contract = Get-Content -Raw -LiteralPath $SchemaContractPath -Encoding utf8 | ConvertFrom-Json
        $properties = $contract.properties
        $rootPropertyNames = @($properties.PSObject.Properties.Name)
        foreach ($field in @("schema", "components", "shared_paths")) {
            if ($rootPropertyNames -cnotcontains $field) {
                throw [ConfigError]::new("contract properties must contain exact-case field '$field'")
            }
        }
        $schemaNode = $properties.schema
        $componentsNode = $properties.components
        $componentItem = $componentsNode.items
        $componentProperties = $componentItem.properties
        $componentPropertyNames = @($componentProperties.PSObject.Properties.Name)
        foreach ($field in @("id", "paths")) {
            if ($componentPropertyNames -cnotcontains $field) {
                throw [ConfigError]::new("components[] properties must contain exact-case field '$field'")
            }
        }
        $pathsNode = $componentProperties.paths
        $pathProperties = $pathsNode.properties
        $pathPropertyNames = @($pathProperties.PSObject.Properties.Name)
        foreach ($field in @("include", "exclude")) {
            if ($pathPropertyNames -cnotcontains $field) {
                throw [ConfigError]::new("components[].paths properties must contain exact-case field '$field'")
            }
        }
        $sharedNode = $properties.shared_paths
        $sharedItem = $sharedNode.items

        if ($null -eq $schemaNode -or $schemaNode.const -isnot [string] -or $schemaNode.const -cne $PROJECT_CONTEXT_SCHEMA_VERSION) {
            throw [ConfigError]::new("properties.schema.const must equal '$PROJECT_CONTEXT_SCHEMA_VERSION'")
        }
        if (-not (Test-JsonSchemaNodeType $componentsNode "array") -or -not (Test-JsonSchemaNodeType $componentItem "object")) {
            throw [ConfigError]::new("properties.components must be an array of objects")
        }
        if (-not (Test-RequiredField $componentItem "id") -or -not (Test-JsonSchemaNodeType $componentProperties.id "string")) {
            throw [ConfigError]::new("components[] must require string field 'id'")
        }
        if (-not (Test-JsonSchemaNodeType $pathsNode "object")) {
            throw [ConfigError]::new("components[].paths must be an object when present")
        }
        foreach ($field in @("include", "exclude")) {
            $node = $pathProperties.$field
            if (-not (Test-JsonSchemaNodeType $node "array") -or -not (Test-JsonSchemaNodeType $node.items "string")) {
                throw [ConfigError]::new("components[].paths.$field must be an array of strings")
            }
        }
        if (-not (Test-JsonSchemaNodeType $sharedNode "array") -or -not (Test-JsonSchemaNodeType $sharedItem "object") -or -not (Test-RequiredField $sharedItem "pattern")) {
            throw [ConfigError]::new("shared_paths must be an array of objects requiring 'pattern'")
        }
        $branches = @($sharedItem.oneOf)
        $bounded = @($branches | Where-Object { Test-RequiredField $_ "components" })
        $crossCutting = @($branches | Where-Object {
            (Test-RequiredField $_ "classification") -and $_.properties.classification.const -ceq "cross-cutting"
        })
        if ($bounded.Count -ne 1 -or $crossCutting.Count -ne 1) {
            throw [ConfigError]::new("shared_paths[] must define bounded components and cross-cutting classification branches")
        }
        $boundedComponents = $bounded[0].properties.components
        if (-not (Test-JsonSchemaNodeType $boundedComponents "array") -or -not (Test-JsonSchemaNodeType $boundedComponents.items "string")) {
            throw [ConfigError]::new("bounded shared_paths[].components must be an array of strings")
        }
    } catch {
        return @{ Conformant = $false; Diagnostic = "schema contract at $SchemaContractPath diverges: $($_.Exception.Message)" }
    }

    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        return @{ Conformant = $false; Diagnostic = "schema artifact absent: $SchemaPath" }
    }
    try {
        $text = Get-Content -Raw -LiteralPath $SchemaPath -Encoding utf8
        $data = ConvertFrom-MinimalYaml $text
        if ($data["schema"] -cne $PROJECT_CONTEXT_SCHEMA_VERSION) {
            throw [ConfigError]::new("top-level schema must equal '$PROJECT_CONTEXT_SCHEMA_VERSION'")
        }
        if ($data["components"] -isnot [System.Array]) {
            throw [ConfigError]::new("top-level components must be a list")
        }
        if ($data["shared_paths"] -isnot [System.Array]) {
            throw [ConfigError]::new("top-level shared_paths must be a list")
        }
    } catch {
        return @{ Conformant = $false; Diagnostic = "schema artifact at $SchemaPath diverges: $($_.Exception.Message)" }
    }

    # AC-011's substantive step (parity with the Python master): validate the
    # parsed artifact as an INSTANCE against Epic A1's real JSON Schema, not
    # merely parse it and shape-check the schema.
    $instanceErrors = @(Test-JsonSchemaInstance $contract $data)
    if ($instanceErrors.Count -gt 0) {
        $joined = ($instanceErrors | Select-Object -First 5) -join "; "
        return @{
            Conformant = $false
            Diagnostic = "schema artifact at $SchemaPath does not validate against ${SchemaContractPath}: $joined"
        }
    }

    try {
        [void](ConvertTo-ConfigObject $data)
    } catch {
        return @{ Conformant = $false; Diagnostic = "schema artifact at $SchemaPath components[] shape diverges: $($_.Exception.Message)" }
    }

    return @{ Conformant = $true; Diagnostic = "schema artifact $SchemaPath validates against $SchemaContractPath and conforms to the resolver projection" }
}

# --------------------------------------------------------------------------
# Git-diff basis collector (REQ-003, T-002) — full parallel PowerShell
# implementation of resolve-component-paths.py's own collector (INV-008;
# not a wrapper calling into Python). See the Python master for the full
# rationale; this port keeps identical constants, exit/diagnostic
# conventions, and the same TOCTOU retry-once-then-fail-closed rule.
# --------------------------------------------------------------------------

$RENAME_SIMILARITY_THRESHOLD = 50
$RENAME_LIMIT = 1000

class GitDiffError : System.Exception {
    GitDiffError([string]$message) : base($message) {}
}

$Utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

function Invoke-GitRaw {
    # Runs git as a real subprocess and returns raw bytes for stdout/stderr
    # (never PowerShell's own text/console decoding), reading both streams
    # concurrently via CopyToAsync to avoid a classic redirect deadlock.
    param([string]$RepoRoot, [string[]]$GitArgs)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "git"
    [void]$psi.ArgumentList.Add("-C")
    [void]$psi.ArgumentList.Add($RepoRoot)
    foreach ($a in $GitArgs) { [void]$psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    try {
        [void]$proc.Start()
    } catch {
        throw [GitDiffError]::new("git executable not found: $($_.Exception.Message)")
    }
    $stdoutMs = [System.IO.MemoryStream]::new()
    $stderrMs = [System.IO.MemoryStream]::new()
    $outTask = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutMs)
    $errTask = $proc.StandardError.BaseStream.CopyToAsync($stderrMs)
    $outTask.Wait()
    $errTask.Wait()
    $proc.WaitForExit()
    return @{ ExitCode = $proc.ExitCode; Stdout = $stdoutMs.ToArray(); Stderr = $stderrMs.ToArray() }
}

function ConvertTo-PathStrict {
    param([byte[]]$Raw)
    try {
        return $Utf8Strict.GetString($Raw)
    } catch {
        throw [GitDiffError]::new("invalid UTF-8 in a git-reported path: $([System.BitConverter]::ToString($Raw)) ($($_.Exception.Message))")
    }
}

function Resolve-CommitOid {
    param([string]$RepoRoot, [string]$Rev)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -GitArgs @("rev-parse", "--verify", "$Rev^{commit}")
    if ($r.ExitCode -ne 0) {
        $errText = [System.Text.Encoding]::UTF8.GetString($r.Stderr).Trim()
        throw [GitDiffError]::new("unresolvable rev '$Rev': $errText")
    }
    return [System.Text.Encoding]::ASCII.GetString($r.Stdout).Trim()
}

function Get-MergeBaseOid {
    param([string]$RepoRoot, [string]$SourceOid, [string]$TargetOid)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -GitArgs @("merge-base", $SourceOid, $TargetOid)
    if ($r.ExitCode -ne 0) {
        $errText = [System.Text.Encoding]::UTF8.GetString($r.Stderr).Trim()
        throw [GitDiffError]::new("no merge-base between $SourceOid and $TargetOid (unrelated histories?): $errText")
    }
    return [System.Text.Encoding]::ASCII.GetString($r.Stdout).Trim()
}

function Get-RepoFingerprint {
    param([string]$RepoRoot)
    $r1 = Invoke-GitRaw -RepoRoot $RepoRoot -GitArgs @("rev-parse", "HEAD")
    $head = if ($r1.ExitCode -eq 0) { [System.Text.Encoding]::ASCII.GetString($r1.Stdout).Trim() } else { "(unborn)" }
    $r2 = Invoke-GitRaw -RepoRoot $RepoRoot -GitArgs @("status", "--porcelain=v1", "-z", "--untracked-files=all")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($r2.Stdout)
    $statusHash = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
    return @{ Head = $head; StatusHash = $statusHash }
}

function Split-NulBytes {
    param([byte[]]$Raw)
    $out = [System.Collections.Generic.List[byte[]]]::new()
    if ($Raw.Length -eq 0) { return , $out.ToArray() }
    $start = 0
    for ($i = 0; $i -lt $Raw.Length; $i++) {
        if ($Raw[$i] -eq 0) {
            $len = $i - $start
            $segment = [byte[]]::new($len)
            [Array]::Copy($Raw, $start, $segment, 0, $len)
            $out.Add($segment)
            $start = $i + 1
        }
    }
    if ($start -lt $Raw.Length) {
        $len = $Raw.Length - $start
        $segment = [byte[]]::new($len)
        [Array]::Copy($Raw, $start, $segment, 0, $len)
        $out.Add($segment)
    }
    return , $out.ToArray()
}

function Get-TrackedDiff {
    param([string]$RepoRoot, [string]$BaselineOid)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -GitArgs @(
        "-c", "diff.renameLimit=$RENAME_LIMIT",
        "diff", "--no-ext-diff", "-M${RENAME_SIMILARITY_THRESHOLD}%",
        "--ignore-submodules=dirty", "--name-status", "-z", $BaselineOid
    )
    $errText = [System.Text.Encoding]::UTF8.GetString($r.Stderr)
    if ($errText -match "too many files" -or $errText -match "rename detection was skipped") {
        throw [GitDiffError]::new("rename-detection limit exceeded (pinned diff.renameLimit=$RENAME_LIMIT); failing closed rather than silently falling back to an unrelated add+delete pair")
    }
    if ($r.ExitCode -ne 0) {
        throw [GitDiffError]::new("git diff against baseline $BaselineOid failed: $($errText.Trim())")
    }

    $tokens = Split-NulBytes -Raw $r.Stdout
    $entries = [System.Collections.Generic.List[string]]::new()
    $renames = [System.Collections.Generic.List[object]]::new()
    $i = 0
    while ($i -lt $tokens.Count) {
        $status = [System.Text.Encoding]::ASCII.GetString($tokens[$i])
        if ($status.StartsWith("R") -or $status.StartsWith("C")) {
            if ($i + 2 -ge $tokens.Count) {
                throw [GitDiffError]::new("malformed rename/copy entry in git diff --name-status -z output")
            }
            $oldPath = ConvertTo-PathStrict $tokens[$i + 1]
            $newPath = ConvertTo-PathStrict $tokens[$i + 2]
            $entries.Add($oldPath)
            $entries.Add($newPath)
            $renames.Add([ordered]@{ old_path = $oldPath; new_path = $newPath; status = $status })
            $i += 3
        } else {
            if ($i + 1 -ge $tokens.Count) {
                throw [GitDiffError]::new("malformed status entry in git diff --name-status -z output")
            }
            $path = ConvertTo-PathStrict $tokens[$i + 1]
            $entries.Add($path)
            $i += 2
        }
    }
    return @{ Entries = @($entries); Renames = @($renames) }
}

function Get-UntrackedFiles {
    param([string]$RepoRoot)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -GitArgs @("ls-files", "--others", "--exclude-standard", "-z")
    if ($r.ExitCode -ne 0) {
        $errText = [System.Text.Encoding]::UTF8.GetString($r.Stderr).Trim()
        throw [GitDiffError]::new("git ls-files --others failed: $errText")
    }
    $tokens = Split-NulBytes -Raw $r.Stdout
    return @($tokens | ForEach-Object { ConvertTo-PathStrict $_ })
}

function Get-ChangedPaths {
    param([string]$RepoRoot, [string]$SourceRev, [string]$TargetRev, [bool]$IncludeUntracked = $true)
    $attempt = 0
    while ($true) {
        $attempt += 1
        $fpBefore = Get-RepoFingerprint -RepoRoot $RepoRoot

        $sourceOid = Resolve-CommitOid -RepoRoot $RepoRoot -Rev $SourceRev
        $targetOid = Resolve-CommitOid -RepoRoot $RepoRoot -Rev $TargetRev
        $baselineOid = Get-MergeBaseOid -RepoRoot $RepoRoot -SourceOid $sourceOid -TargetOid $targetOid
        $tracked = Get-TrackedDiff -RepoRoot $RepoRoot -BaselineOid $baselineOid
        $untracked = if ($IncludeUntracked) { Get-UntrackedFiles -RepoRoot $RepoRoot } else { @() }

        $fpAfter = Get-RepoFingerprint -RepoRoot $RepoRoot
        if ($fpBefore.Head -eq $fpAfter.Head -and $fpBefore.StatusHash -eq $fpAfter.StatusHash) {
            break
        }
        if ($attempt -ge 2) {
            throw [GitDiffError]::new("single-writer/TOCTOU snapshot mismatch persisted after one retry; failing closed rather than returning a mixed-snapshot result")
        }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $changedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($p in (@($tracked.Entries) + @($untracked))) {
        if ($seen.Add($p)) { $changedPaths.Add($p) }
    }

    return @{
        SourceOid   = $sourceOid
        TargetOid   = $targetOid
        BaselineOid = $baselineOid
        ChangedPaths = @($changedPaths)
        Renames     = @($tracked.Renames)
    }
}

# --------------------------------------------------------------------------
# --diagnose (T-004, resolver-only diagnostics — never Gate-invoked)
# --------------------------------------------------------------------------

function Invoke-Diagnose {
    param($ClassifyResult, [string]$ProviderBindingsPath)
    $records = $ClassifyResult.records
    $findings = [System.Collections.Generic.List[object]]::new()

    $unowned = @($records | Where-Object { $_.classification -eq "UNOWNED" } | ForEach-Object { $_.raw_path })
    $findings.Add([ordered]@{ id = "Fail-1"; triggered = ($unowned.Count -gt 0); detail = [ordered]@{ unowned_paths = $unowned } })

    $overlap = @($records | Where-Object { $_.classification -eq "OVERLAP" } | ForEach-Object { $_.raw_path })
    $findings.Add([ordered]@{ id = "Fail-3"; triggered = ($overlap.Count -gt 0); detail = [ordered]@{ overlap_paths = $overlap } })

    $excludedMatch = @($records | Where-Object { $_.classification -eq "UNOWNED" -and $_.evidence.excluded_match } | ForEach-Object { $_.raw_path })
    $findings.Add([ordered]@{ id = "Fail-5"; triggered = ($excludedMatch.Count -gt 0); detail = [ordered]@{ excluded_match_paths = $excludedMatch } })

    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($ProviderBindingsPath -and (Test-Path -LiteralPath $ProviderBindingsPath -PathType Leaf)) {
        $text = Get-Content -Raw -LiteralPath $ProviderBindingsPath
        try {
            $data = $text | ConvertFrom-Json -AsHashtable
        } catch {
            $data = ConvertFrom-MinimalYaml $text
        }
        $bindings = if ($data -is [System.Collections.IDictionary]) { $data["bindings"] } else { $null }
        $exclusiveByComponent = @{}
        foreach ($r in $records) {
            if ($r.classification -eq "EXCLUSIVE") {
                foreach ($comp in $r.owning_components) {
                    if (-not $exclusiveByComponent.ContainsKey($comp)) { $exclusiveByComponent[$comp] = [System.Collections.Generic.List[string]]::new() }
                    $exclusiveByComponent[$comp].Add($r.raw_path)
                }
            }
        }
        $matches = [System.Collections.Generic.List[object]]::new()
        if ($bindings) {
            foreach ($binding in $bindings) {
                $adapterPaths = $binding["adapter_paths"]
                $joined = $binding["provider_binding_ids"]
                if ($null -eq $adapterPaths) {
                    $warnings.Add("Fail-6: a provider binding declares no adapter_paths; evaluation not possible for it")
                    continue
                }
                # Hoisted: validate each declared pattern once per binding.
                # A malformed pattern is surfaced as a warning instead of
                # being silently re-swallowed per (component, path) pair.
                $usablePatterns = [System.Collections.Generic.List[object]]::new()
                foreach ($pattern in $adapterPaths) {
                    try {
                        $usablePatterns.Add(@($pattern, (Confirm-AndNormalizePattern $pattern)))
                    } catch {
                        $warnings.Add("Fail-6: a provider binding declares an unusable adapter path pattern; it cannot match anything: " + [string]$pattern)
                    }
                }
                if (-not $joined) { continue }
                foreach ($comp in $joined) {
                    if (-not $exclusiveByComponent.ContainsKey($comp)) { continue }
                    foreach ($path in $exclusiveByComponent[$comp]) {
                        $nfcPath = ConvertTo-Nfc $path
                        foreach ($pair in $usablePatterns) {
                            if (Test-PatternMatches -PatternNormalized $pair[1] -PathNfc $nfcPath) {
                                $matches.Add([ordered]@{ component = $comp; path = $path; pattern = $pair[0] })
                            }
                        }
                    }
                }
            }
        }
        $findings.Add([ordered]@{ id = "Fail-6"; triggered = ($matches.Count -gt 0); detail = [ordered]@{ matches = @($matches) } })
    } else {
        $findings.Add([ordered]@{ id = "Fail-6"; triggered = $false; detail = [ordered]@{ status = "not-applicable (provider-bindings absent)" } })
        $warnings.Add("Fail-6: provider-bindings file absent; recorded N/A")
    }

    return [ordered]@{ schema = "resolve-component-paths-diagnose/v1"; findings = @($findings); warnings = @($warnings) }
}

# --------------------------------------------------------------------------
# CLI entry point
# --------------------------------------------------------------------------

function ConvertTo-CanonicalJson {
    param($Value)
    return ($Value | ConvertTo-Json -Depth 20 -Compress:$false)
}

# T-004: check-component-coverage.ps1 dot-sources this script to reuse its
# config/classification/git-diff functions without a second, potentially-
# diverging implementation. Guard the executable CLI dispatch below so a
# dot-source (". resolve-component-paths.ps1", InvocationName "." with no
# bound parameters) only defines functions/classes and does NOT also run
# this script's own CLI logic (which would try to classify with no -Config
# and `exit 1` the CALLING script's session too, in the same in-process
# scope, since `.`-sourcing shares scope and `exit` is not scope-limited).
if ($MyInvocation.InvocationName -ne '.') {

if ($CheckSchemaConformance) {
    $result = Test-SchemaConformance -SchemaPath $Schema -SchemaContractPath $SchemaContract
    $out = [ordered]@{ conformant = $result.Conformant; diagnostic = $result.Diagnostic }
    Write-Output (ConvertTo-CanonicalJson $out)
    if ($result.Conformant) { exit 0 } else { exit 1 }
}

if ([string]::IsNullOrEmpty($Config)) {
    Write-Error ("resolve-component-paths: -Config is required")
    exit 1
}

try {
    $cfg = Import-ConfigFile -Path $Config
} catch [ConfigError] {
    Write-Error ("resolve-component-paths: config error: $($_.Exception.Message)")
    exit 1
} catch {
    Write-Error ("resolve-component-paths: cannot read config: $($_.Exception.Message)")
    exit 1
}

$diffBasis = $null
if (-not [string]::IsNullOrEmpty($TargetRev)) {
    try {
        $diffBasis = Get-ChangedPaths -RepoRoot $RepoRoot -SourceRev $SourceRev -TargetRev $TargetRev -IncludeUntracked $IncludeUntracked
    } catch [GitDiffError] {
        Write-Error ("resolve-component-paths: $($_.Exception.Message)")
        exit 1
    }
    $rawPaths = @($diffBasis.ChangedPaths)
} else {
    try {
        if ([string]::IsNullOrEmpty($ChangedPathsFile)) {
            $text = [Console]::In.ReadToEnd()
        } else {
            $text = Get-Content -Raw -LiteralPath $ChangedPathsFile -Encoding utf8
        }
    } catch {
        Write-Error ("resolve-component-paths: cannot read changed-paths-file: $($_.Exception.Message)")
        exit 1
    }
    $normalizedText = $text -replace "`r`n", "`n" -replace "`r", "`n"
    $rawPaths = @($normalizedText -split "`n" | Where-Object { $_ -ne "" })
}

try {
    $result = Invoke-ClassifyPaths -Config $cfg -RawPaths $rawPaths
} catch [ConfigError] {
    Write-Error ("resolve-component-paths: $($_.Exception.Message)")
    exit 1
} catch [CollisionError] {
    Write-Error ("resolve-component-paths: $($_.Exception.Message)")
    exit 1
}

if ($Diagnose) {
    $diag = Invoke-Diagnose -ClassifyResult $result -ProviderBindingsPath $ProviderBindings
    Write-Output (ConvertTo-CanonicalJson $diag)
    exit 0
}

if ($null -ne $diffBasis) {
    $classificationByPath = @{}
    foreach ($rec in $result.records) { $classificationByPath[$rec.raw_path] = $rec }
    $renamesWithEvidence = [System.Collections.Generic.List[object]]::new()
    foreach ($rename in $diffBasis.Renames) {
        $oldRec = $classificationByPath[$rename.old_path]
        $newRec = $classificationByPath[$rename.new_path]
        # NOTE: a FOURTH distinct PowerShell collection-unwrapping pitfall
        # (alongside Get-StringList's null-pipeline issue, the -eq/-ne
        # culture-awareness issue, and the @{} case-insensitivity issue
        # documented elsewhere in this file): any IEnumerable (a HashSet<T>,
        # here) returned through an expression's "output stream" — via
        # `return`, or as the trailing value of an if/else block used as an
        # expression — gets enumerated and unrolled item-by-item, exactly
        # like an array does. A single-element HashSet<string> therefore
        # collapses to its bare scalar string element instead of staying a
        # HashSet (confirmed: a minimal repro assigning `$x = if ($true)
        # {[HashSet[string]]::new($oneElementArray)} else {$null}` produced
        # $x as a [string], not a [HashSet]). The leading comma operator
        # forces the object through as a single item, not a collection to
        # unroll — the same protection already applied to array-returning
        # helpers elsewhere in this file.
        $oldOwners = if ($oldRec) { , [System.Collections.Generic.HashSet[string]]::new([string[]]$oldRec.owning_components) } else { , [System.Collections.Generic.HashSet[string]]::new() }
        $newOwners = if ($newRec) { , [System.Collections.Generic.HashSet[string]]::new([string[]]$newRec.owning_components) } else { , [System.Collections.Generic.HashSet[string]]::new() }
        $crossComponent = -not $oldOwners.SetEquals($newOwners)
        $renamesWithEvidence.Add([ordered]@{
            old_path = $rename.old_path
            new_path = $rename.new_path
            status = $rename.status
            cross_component = $crossComponent
        })
    }
    # $result is an [ordered] hashtable (not a PSCustomObject) -- set the
    # key directly rather than Add-Member, which would attach to the
    # wrapping PSObject instead of the hashtable ConvertTo-Json serializes.
    $result["diff_basis"] = [ordered]@{
        source_oid   = $diffBasis.SourceOid
        target_oid   = $diffBasis.TargetOid
        baseline_oid = $diffBasis.BaselineOid
        renames      = @($renamesWithEvidence)
    }
}

Write-Output (ConvertTo-CanonicalJson $result)
exit 0

} # end: if ($MyInvocation.InvocationName -ne '.')
