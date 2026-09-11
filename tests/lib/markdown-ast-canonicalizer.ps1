param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Normalize-HorizontalWhitespace([string]$Value) {
    return ([regex]::Replace($Value, '[ \t]+', ' ', [Text.RegularExpressions.RegexOptions]::CultureInvariant)).Trim()
}

try {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "markdown file does not exist: $Path"
    }

    $Text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path)) -creplace "\r\n?", "`n"
    $Lines = $Text.Split("`n", [StringSplitOptions]::None)
    $Frontmatter = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $Headings = [Collections.Generic.List[object]]::new()
    $InFrontmatter = $false
    $SawFrontmatter = $false
    $ClosedFrontmatter = $false

    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        $Line = $Lines[$Index]
        $LineNumber = $Index + 1
        if ($Index -eq 0 -and $Line -ceq '---') {
            $InFrontmatter = $true
            $SawFrontmatter = $true
            continue
        }
        if ($InFrontmatter) {
            if ($Line -ceq '---') {
                $InFrontmatter = $false
                $ClosedFrontmatter = $true
                continue
            }
            if ($Line -cmatch '^[ \t]*$' -or $Line -cmatch '^[ \t]*#') { continue }
            $Entry = [regex]::Match($Line, '^([A-Za-z0-9_.-]+)[ \t]*:(.*)$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
            if (-not $Entry.Success) { throw "malformed frontmatter entry at line $LineNumber" }
            $Key = $Entry.Groups[1].Value
            if ($Frontmatter.ContainsKey($Key)) { throw "duplicate frontmatter key $Key" }
            $Frontmatter.Add($Key, (Normalize-HorizontalWhitespace $Entry.Groups[2].Value))
            continue
        }
        if ($Line.StartsWith('#', [StringComparison]::Ordinal)) {
            $Heading = [regex]::Match($Line, '^(#+)[ \t]+(.*)$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
            if (-not $Heading.Success -or $Heading.Groups[1].Value.Length -gt 6) {
                throw "unrecognized heading grammar at line $LineNumber"
            }
            $HeadingText = Normalize-HorizontalWhitespace $Heading.Groups[2].Value
            if ([string]::IsNullOrEmpty($HeadingText)) { throw "empty heading at line $LineNumber" }
            $Headings.Add([ordered]@{ level = $Heading.Groups[1].Value.Length; text = $HeadingText })
            continue
        }
        if ($Line -cmatch '^[ \t]*(?:={3,}|-{3,})[ \t]*$') {
            throw "setext heading grammar is unsupported at line $LineNumber"
        }
    }
    if ($SawFrontmatter -and (-not $ClosedFrontmatter -or $InFrontmatter)) {
        throw 'unterminated frontmatter'
    }

    [string[]]$Keys = @($Frontmatter.Keys)
    [Array]::Sort($Keys, [StringComparer]::Ordinal)
    $SortedFrontmatter = @($Keys | ForEach-Object { [ordered]@{ key = $_; value = $Frontmatter[$_] } })
    [ordered]@{ frontmatter = $SortedFrontmatter; headings = @($Headings) } |
        ConvertTo-Json -Depth 5 -Compress
}
catch {
    [Console]::Error.WriteLine("markdown AST parse failure: $($_.Exception.Message)")
    exit 2
}
