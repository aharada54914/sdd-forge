param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round,
  [switch]$VerifyInputs,
  [switch]$ProvenanceRereview
)

$ErrorActionPreference = 'Stop'
function Test-AdrBoundFilePath {
    param([string]$Root, [string]$Relative)
    if ($Relative -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or
        $Relative.EndsWith('/', [StringComparison]::Ordinal) -or
        $Relative.Contains('//') -or $Relative -cmatch '(^|/)[.]{1,2}(/|$)') {
        return $false
    }
    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    if (-not $rootItem.PSIsContainer -or
        ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        return $false
    }
    $current = $Root
    $components = $Relative.Split('/')
    for ($index = 0; $index -lt $components.Length; $index++) {
        $component = $components[$index]
        $matches = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop |
            Where-Object { [string]::Equals($_.Name, $component, [StringComparison]::Ordinal) })
        if ($matches.Count -ne 1) { return $false }
        $item = $matches[0]
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $false
        }
        if ($index -lt $components.Length - 1) {
            if (-not $item.PSIsContainer) { return $false }
        }
        else {
            if ($item -isnot [IO.FileInfo] -or $item.PSIsContainer -or
                ($item.Attributes -band [IO.FileAttributes]::Device) -ne 0) {
                return $false
            }
            if (-not $IsWindows) {
                # FileInfo/Leaf also describe POSIX devices; require lstat type.
                $statProperty = $item.PSObject.Properties['UnixStat']
                if ($null -eq $statProperty -or $null -eq $statProperty.Value -or
                    -not [string]::Equals([string]$statProperty.Value.ItemType,
                        'File', [StringComparison]::Ordinal)) {
                    return $false
                }
            }
        }
        $current = $item.FullName
    }
    # The consuming hash/read must still fail closed on access/open failure.
    return $true
}

# RT-20260908-004: the same restricted byte-oriented line grammar as Bash.
function Get-AdrDeclaredPaths {
    param([string]$DesignPath)
    # Latin-1 preserves each byte, including a BOM; the grammar is ASCII only.
    # ReadAllText would strip a BOM and diverge from LC_ALL=C awk at fences.
    $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($DesignPath))
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    function Get-AdrRunWidth([string]$Line, [int]$Start, [char]$Delimiter) {
        $width = 0
        while (($Start + $width) -lt $Line.Length -and $Line[$Start + $width] -ceq $Delimiter) { $width++ }
        return $width
    }
    function Test-AdrRunEscaped([string]$Line, [int]$Start) {
        $slashes = 0
        while ($Start -gt 0 -and $Line[$Start - 1] -ceq [char]92) { $slashes++; $Start-- }
        return (($slashes % 2) -ne 0)
    }
    $fence = [char]0
    $fenceWidth = 0
    foreach ($rawLine in $text.Split([char]10)) {
        $line = $rawLine
        if ($line.Length -gt 0 -and $line[$line.Length - 1] -ceq [char]13) {
            $line = $line.Substring(0, $line.Length - 1)
        }
        $indent = 0
        while ($indent -lt $line.Length -and $line[$indent] -ceq [char]32) { $indent++ }
        $rest = $line.Substring($indent)
        $first = [char]0
        if ($rest.Length -gt 0) { $first = $rest[0] }
        if ($fence -cne [char]0) {
            if ($indent -le 3 -and $first -ceq $fence) {
                $width = Get-AdrRunWidth $rest 0 $fence
                if ($width -ge $fenceWidth -and $rest.Substring($width) -cmatch '^[ \t]*$') {
                    $fence = [char]0
                }
            }
            continue
        }
        if ($indent -ge 4 -or $first -ceq [char]9) { continue }
        if ($first -ceq [char]96 -or $first -ceq [char]126) {
            $width = Get-AdrRunWidth $rest 0 $first
            if ($width -ge 3) { $fence = $first; $fenceWidth = $width; continue }
        }
        $i = 0
        while ($i -lt $line.Length) {
            if ($line[$i] -cne [char]96) { $i++; continue }
            $width = Get-AdrRunWidth $line $i ([char]96)
            if (Test-AdrRunEscaped $line $i) { $i += $width; continue }
            $j = $i + $width
            $closed = $false
            while ($j -lt $line.Length) {
                if ($line[$j] -cne [char]96) { $j++; continue }
                $closeWidth = Get-AdrRunWidth $line $j ([char]96)
                if ($closeWidth -eq $width -and -not (Test-AdrRunEscaped $line $j)) {
                    $closed = $true
                    break
                }
                $j += $closeWidth
            }
            if (-not $closed) { break }
            $value = $line.Substring($i + $width, $j - $i - $width)
            if ($width -eq 1 -and $value -cmatch '^docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md$') {
                [void]$paths.Add($value)
            }
            $i = $j + $width
        }
    }
    [string[]]$result = @($paths)
    [Array]::Sort($result, [StringComparer]::Ordinal)
    return $result
}
# Return JSON as a scalar to preserve both empty and singleton arrays.
function Get-AdrPrecheckInputsJson {
    param([string]$Root, [string]$DesignRelative, [string]$ExpectedDesign)
    if ($ExpectedDesign -cnotmatch '^[0-9a-f]{64}$' -or
        -not (Test-AdrBoundFilePath $Root $DesignRelative)) {
        Fail 'unsafe design ADR authority'
    }
    $designPath = Join-Path $Root $DesignRelative
    $before = (Get-FileHash -LiteralPath $designPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($before -cne $ExpectedDesign) { Fail 'design changed before ADR collection' }
    $entries = [Collections.Generic.List[object]]::new()
    foreach ($path in @(Get-AdrDeclaredPaths $designPath)) {
        if (-not (Test-AdrBoundFilePath $Root $path)) { Fail "unsafe ADR input: $path" }
        $digest = (Get-FileHash -LiteralPath (Join-Path $Root $path) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($digest -cnotmatch '^[0-9a-f]{64}$') { Fail 'invalid ADR digest' }
        $entries.Add([ordered]@{path=$path;sha256=$digest})
    }
    if (-not (Test-AdrBoundFilePath $Root $DesignRelative)) { Fail 'design path changed during collection' }
    $after = (Get-FileHash -LiteralPath $designPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($after -cne $ExpectedDesign) { Fail 'design changed during ADR collection' }
    return ConvertTo-Json -InputObject ($entries.ToArray()) -Depth 4 -Compress
}
# Only extension material uses this canonical order; legacy evidence is untouched.
function Get-AdrLayerJson {
    param($Layers)
    if ($null -eq $Layers -or ($Layers -isnot [pscustomobject] -and
        $Layers -isnot [Collections.IDictionary])) { Fail 'invalid layer object' }
    $names = if ($Layers -is [Collections.IDictionary]) { @($Layers.Keys) }
             else { @($Layers.PSObject.Properties.Name) }
    $expected = @('frontend-spec.md','infra-spec.md','security-spec.md','ux-spec.md')
    if ($names.Count -ne 0 -and $names.Count -ne 4) { Fail 'invalid layer key count' }
    foreach ($name in $names) {
        if ($name -isnot [string] -or $expected -cnotcontains $name) { Fail 'invalid layer key' }
    }
    $canonical = [ordered]@{}
    if ($names.Count -gt 0) {
        foreach ($name in $expected) {
            if ($names -cnotcontains $name) { Fail 'missing layer key' }
            $value = if ($Layers -is [Collections.IDictionary]) { $Layers[$name] }
                     else { $Layers.PSObject.Properties[$name].Value }
            if ($value -isnot [string] -or $value.Length -ne 64 -or $value -cnotmatch '^[0-9a-f]{64}$') {
                Fail 'invalid layer digest'
            }
            $canonical[$name] = $value
        }
    }
    return ConvertTo-Json -InputObject $canonical -Compress
}
function Get-AdrHistoryJson {
  param($Entries)
  if ($Entries -isnot [array]) { Fail 'invalid persisted ADR array' }
  $normalized = [Collections.Generic.List[object]]::new()
  $previous = $null
  foreach ($entry in $Entries) {
    if ($null -eq $entry -or $entry -isnot [pscustomobject]) { Fail 'invalid persisted ADR entry' }
    $keys = @($entry.PSObject.Properties.Name)
    if ($keys.Count -ne 2 -or $keys -cnotcontains 'path' -or $keys -cnotcontains 'sha256' -or
        $entry.path -isnot [string] -or $entry.sha256 -isnot [string] -or
        $entry.path -cnotmatch '\Adocs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md\z' -or
        $entry.sha256.Length -ne 64 -or $entry.sha256 -cnotmatch '\A[0-9a-f]{64}\z') {
      Fail 'invalid persisted ADR fields'
    }
    if ($null -ne $previous -and [StringComparer]::Ordinal.Compare($previous, $entry.path) -ge 0) {
      Fail 'persisted ADR entries must be sorted and unique'
    }
    $previous = $entry.path
    $normalized.Add([ordered]@{path=$entry.path;sha256=$entry.sha256})
  }
  return ConvertTo-Json -InputObject ($normalized.ToArray()) -Compress -Depth 4
}
function Get-AdrPreviousRoundJson {
  param([string]$RepoRoot, $Prior, [string]$FeatureName, [long]$AttemptNumber, [long]$RoundNumber)
  $relativeRoot = "reports/impl-review/$FeatureName/attempt-$AttemptNumber/round-$RoundNumber"
  $precheckRelative = "$relativeRoot/precheck-result.json"
  if (-not (Test-AdrBoundFilePath $RepoRoot "$relativeRoot/impl-review-contract.json") -or
      -not (Test-AdrBoundFilePath $RepoRoot $precheckRelative)) { Fail 'unsafe previous ADR evidence path' }
  $precheckPath = Join-Path $RepoRoot $precheckRelative
  $precheckHash = (Get-FileHash -LiteralPath $precheckPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json -NoEnumerate
  if ($Prior -isnot [pscustomobject] -or $precheck -isnot [pscustomobject]) {
    Fail 'previous ADR evidence must contain objects'
  }
  $priorHasAdr = @($Prior.PSObject.Properties.Name) -ccontains 'adr_inputs'
  $precheckHasAdr = @($precheck.PSObject.Properties.Name) -ccontains 'adr_inputs'
  if ($priorHasAdr -ne $precheckHasAdr) { Fail 'one-sided previous ADR extension' }
  if (-not $priorHasAdr) {
    foreach ($reviewer in @($Prior.reviewers)) {
      foreach ($entry in @($reviewer.allowed_input_manifest)) {
        $relative = Get-ManifestRelativePath ([string]$entry.path) $RepoRoot
        if ($relative -is [string] -and $relative.StartsWith('docs/adr/', [StringComparison]::Ordinal)) {
          Fail 'legacy previous contract cannot admit ADR inputs'
        }
      }
    }
    return $null
  }
  if ($Prior.schema -cne 'impl-review-contract/v1' -or $Prior.stage -cne 'impl' -or
      $Prior.feature -cne $FeatureName -or $Prior.verdict -cne 'NEEDS_WORK' -or
      $precheck.schema -cne 'impl-review-precheck/v1' -or $precheck.feature -cne $FeatureName) {
    Fail 'invalid previous ADR review identity or verdict'
  }
  foreach ($document in @($Prior, $precheck)) {
    if ($document.attempt -isnot [long] -or $document.round -isnot [long] -or
        $document.attempt -ne $AttemptNumber -or $document.round -ne $RoundNumber) {
      Fail 'previous ADR attempt/round differs from directory'
    }
  }
  $recorded = Get-AdrHistoryJson $precheck.adr_inputs
  if ((Get-AdrHistoryJson $Prior.adr_inputs) -cne $recorded) { Fail 'previous ADR sets disagree' }
  foreach ($field in @('design_sha256','requirements_sha256','acceptance_sha256')) {
    if ($precheck.$field -isnot [string] -or $precheck.$field.Length -ne 64 -or
        $precheck.$field -cnotmatch '\A[0-9a-f]{64}\z' -or
        $Prior.$field -isnot [string] -or $Prior.$field -cne $precheck.$field) {
      Fail 'previous ADR core pins disagree'
    }
  }
  $layers = Get-AdrLayerJson $precheck.layer_sha256
  if ((Get-AdrLayerJson $Prior.layer_sha256) -cne $layers) { Fail 'previous ADR layer pins disagree' }
  $reviewers = @($Prior.reviewers)
  if ($reviewers.Count -ne 2) { Fail 'previous ADR review requires two reviewers' }
  foreach ($role in @('impl-reviewer-a','impl-reviewer-b')) {
    $matches = @($reviewers | Where-Object { $_.role -is [string] -and $_.role -ceq $role })
    if ($matches.Count -ne 1) { Fail 'previous ADR reviewer roles differ' }
    $reviewerRelative = "$relativeRoot/$($role.Substring(5)).json"
    if (-not (Test-AdrBoundFilePath $RepoRoot $reviewerRelative)) { Fail 'unsafe previous ADR reviewer output' }
    $reviewerPath = Join-Path $RepoRoot $reviewerRelative
    $reviewerHash = (Get-FileHash -LiteralPath $reviewerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $output = Get-Content -LiteralPath $reviewerPath -Raw | ConvertFrom-Json -NoEnumerate
    if ($output -isnot [pscustomobject] -or $output.schema -cne "$role/v1" -or
        $output.stage -cne 'impl' -or $output.role -cne $role) {
      Fail 'previous ADR reviewer output identity mismatch'
    }
    foreach ($field in @('run_id','host_session_id')) {
      if ($output.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($output.$field) -or
          $matches[0].$field -isnot [string] -or $output.$field -cne $matches[0].$field) {
        Fail 'previous ADR reviewer output provenance mismatch'
      }
    }
    # Opening a failed round can return before workflow-state's PASS checks.
    # Bind actual reviewer output as well as the contract's claimed inputs here.
    foreach ($source in @($matches[0], $output)) {
      if ($source.allowed_input_manifest -isnot [array]) { Fail 'invalid previous ADR reviewer manifest' }
      $entries = @($source.allowed_input_manifest)
      $documentPins = [ordered]@{
        'requirements.md' = $precheck.requirements_sha256
        'acceptance-tests.md' = $precheck.acceptance_sha256
      }
      foreach ($layer in $precheck.layer_sha256.PSObject.Properties) {
        $documentPins[$layer.Name] = $layer.Value
      }
      foreach ($document in $documentPins.Keys) {
        $expectedPath = "specs/$FeatureName/$document"
        $bound = @($entries | Where-Object {
          $_.path -is [string] -and
          (Get-ManifestRelativePath $_.path $RepoRoot) -ceq $expectedPath
        })
        if ($bound.Count -ne 1 -or $bound[0].sha256 -isnot [string] -or
            $bound[0].sha256 -cne $documentPins[$document]) {
          Fail "previous ADR reviewer document binding mismatch: $document"
        }
      }
      $pcPins = @($entries | Where-Object { $_.path -is [string] -and $_.path -ceq $precheckRelative })
      $designPins = @($entries | Where-Object { $_.path -is [string] -and $_.path -ceq "specs/$FeatureName/design.md" })
      if ($pcPins.Count -ne 1 -or $pcPins[0].sha256 -isnot [string] -or $pcPins[0].sha256 -cne $precheckHash -or
          $designPins.Count -ne 1 -or $designPins[0].sha256 -isnot [string] -or $designPins[0].sha256 -cne $precheck.design_sha256) {
        Fail 'previous ADR reviewer precheck/design binding mismatch'
      }
      $adrMap = [Collections.Generic.SortedDictionary[string,object]]::new([StringComparer]::Ordinal)
      foreach ($entry in $entries) {
        if ($entry.path -isnot [string]) { Fail 'invalid previous reviewer path type' }
        $relative = Get-ManifestRelativePath $entry.path $RepoRoot
        if ($relative -is [string] -and $relative.StartsWith('docs/adr/', [StringComparison]::Ordinal) -and
            $entry.path -cne $relative) { Fail 'previous ADR reviewer path must be raw canonical relative' }
        if (-not $entry.path.StartsWith('docs/adr/', [StringComparison]::Ordinal)) { continue }
        if ($adrMap.ContainsKey($entry.path)) { Fail 'duplicate previous reviewer ADR entry' }
        $adrMap.Add($entry.path, [pscustomobject]@{path=$entry.path;sha256=$entry.sha256})
      }
      if ((Get-AdrHistoryJson @($adrMap.Values)) -cne $recorded) { Fail 'incomplete previous reviewer ADR set' }
    }
    if (-not (Test-AdrBoundFilePath $RepoRoot $reviewerRelative) -or
        (Get-FileHash -LiteralPath $reviewerPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $reviewerHash) {
      Fail 'previous ADR reviewer output changed during validation'
    }
  }
  $material = "$($precheck.design_sha256):$($precheck.requirements_sha256):$($precheck.acceptance_sha256)"
  if ($layers -cne '{}') { $material += ':' + $layers }
  $material += ':adr_inputs/v1:' + $recorded
  $inputHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($material))).ToLowerInvariant()
  if ($precheck.input_sha256 -isnot [string] -or $precheck.input_sha256 -cne $inputHash) {
    Fail 'previous ADR input hash mismatch'
  }
  if (-not (Test-AdrBoundFilePath $RepoRoot $precheckRelative) -or
      (Get-FileHash -LiteralPath $precheckPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $precheckHash) {
    Fail 'previous ADR precheck changed during validation'
  }
  # Deliberately do not hash current ADR files against historical failed inputs.
  return $recorded
}
function Fail([string]$Message) { throw "impl-review-precheck: $Message" }
function Test-OrdinalEqual([object]$Left, [object]$Right) {
  return [string]::Equals([string]$Left, [string]$Right, [StringComparison]::Ordinal)
}
function Get-ReviewedHash([string]$Path, [string]$StatusField, [string]$ReviewedStatus) {
  $content = [IO.File]::ReadAllText($Path)
  $normalized = [Text.RegularExpressions.Regex]::Replace(
    $content,
    "(?m)^$([Text.RegularExpressions.Regex]::Escape($StatusField)):[^\r\n]*(\r?)$",
    "${StatusField}: $ReviewedStatus`$1"
  )
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalized))
  ).ToLower()
}
function Get-ManifestRelativePath([string]$Path, [string]$RepoRoot) {
  $normalizedPath = $Path.Replace('\', '/')
  $normalizedRoot = $RepoRoot.Replace('\', '/').TrimEnd('/')
  if ($normalizedPath.StartsWith("$normalizedRoot/", [StringComparison]::Ordinal)) {
    $normalizedPath = $normalizedPath.Substring($normalizedRoot.Length + 1)
  } elseif ([IO.Path]::IsPathRooted($Path) -or $normalizedPath -match '^[A-Za-z]:/') {
    # Contracts persisted by predecessor gates record absolute paths of the
    # checkout that generated them. Relativize against the known repository
    # anchors so evidence stays verifiable from any checkout (issue #61).
    $anchorMatch = [Text.RegularExpressions.Regex]::Match(
      $normalizedPath, '^.*/(?<tail>(specs|reports|plugins)/.+)$')
    if (-not $anchorMatch.Success) { return $null }
    $normalizedPath = $anchorMatch.Groups['tail'].Value
  }
  if ($normalizedPath -match '(^|/)\.\.?(/|$)') { return $null }
  return $normalizedPath
}
# A round's verdict belongs to the text its two reviewers actually read: the
# two reviewers must have pinned the same hash for each reviewed document, and
# the contract must record that hash and no other. Mirrors
# lib/review-precheck-common.sh assert_contract_reviewer_agreement; the gap it
# closes (a contract recording a hash neither reviewer read) surfaced on
# epic-136-phase4-docs attempt 2 round 2.
function Assert-ContractReviewerAgreement([object]$Contract, [string]$Stage, [string]$FeatureName, [string]$RepoRoot) {
  $docKeys = @{ 'requirements.md' = 'requirements_sha256'; 'acceptance-tests.md' = 'acceptance_sha256'; 'design.md' = 'design_sha256' }
  foreach ($doc in @('requirements.md', 'acceptance-tests.md', 'design.md')) {
    $target = "specs/$FeatureName/$doc"
    $pinned = @{}
    foreach ($suffix in @('a', 'b')) {
      $role = "$Stage-reviewer-$suffix"
      $entries = @($Contract.reviewers |
        Where-Object { Test-OrdinalEqual $_.role $role } |
        ForEach-Object { $_.allowed_input_manifest } |
        Where-Object { Test-OrdinalEqual (Get-ManifestRelativePath ([string]$_.path) $RepoRoot) $target })
      $pinned[$suffix] = if ($entries.Count -ge 1) { [string]$entries[0].sha256 } else { '' }
    }
    if (-not $pinned['a'] -or -not $pinned['b']) { continue }
    if (-not (Test-OrdinalEqual $pinned['a'] $pinned['b'])) {
      Fail "persisted $Stage contract: reviewer-a and reviewer-b pinned different ${doc}; they did not review the same text"
    }
    $keyProp = $Contract.PSObject.Properties[$docKeys[$doc]]
    $contractHash = if ($null -ne $keyProp -and $null -ne $keyProp.Value) { [string]$keyProp.Value } else { '' }
    if ($contractHash -and -not (Test-OrdinalEqual $contractHash $pinned['a'])) {
      Fail "persisted $Stage contract records a ${doc} hash neither reviewer read; the verdict does not belong to that text"
    }
  }
}
function Test-AllowedManifestPath(
  [string]$Role,
  [string]$Path,
  [string]$Stage,
  [string]$FeatureName,
  [int]$Attempt,
  [int]$Round,
  [string]$CalibrationPath
) {
  $roleA = "$Stage-reviewer-a"
  $roleB = "$Stage-reviewer-b"
  $attemptRoot = "reports/$Stage-review/$FeatureName/attempt-$Attempt"
  $roundRoot = "$attemptRoot/round-$Round"
  $allowed = @(
    "specs/$FeatureName/requirements.md",
    "specs/$FeatureName/acceptance-tests.md",
    $CalibrationPath,
    "$roundRoot/precheck-result.json"
  )
  if (Test-OrdinalEqual $Stage 'spec') {
    $allowed += "specs/$FeatureName/investigation.md"
    if (Test-OrdinalEqual $Role $roleB) { $allowed += "$roundRoot/integrated-summary.json" }
  } elseif (Test-OrdinalEqual $Stage 'impl') {
    $allowed += "specs/$FeatureName/design.md", "specs/$FeatureName/investigation.md",
      "specs/$FeatureName/ux-spec.md", "specs/$FeatureName/frontend-spec.md",
      "specs/$FeatureName/infra-spec.md", "specs/$FeatureName/security-spec.md"
    if (Test-OrdinalEqual $Role $roleB) { $allowed += "$roundRoot/integrated-summary.json" }
    if ((Test-OrdinalEqual $Role $roleA) -and $Round -gt 1) {
      $allowed += "$attemptRoot/round-$($Round - 1)/integrated-summary.json"
    }
  } elseif (Test-OrdinalEqual $Stage 'task') {
    $allowed += "specs/$FeatureName/tasks.md", "specs/$FeatureName/traceability.md"
    if (Test-OrdinalEqual $Role $roleA) { $allowed += "$roundRoot/dependency-graph.json" }
    if (Test-OrdinalEqual $Role $roleB) {
      $allowed += "$roundRoot/integrated-summary.json",
        'plugins/sdd-quality-loop/references/risk-gate-matrix.md',
        'plugins/sdd-quality-loop/references/risk-classification-policy.md'
    }
  }
  $validRole = (Test-OrdinalEqual $Role $roleA) -or (Test-OrdinalEqual $Role $roleB)
  $validPath = @($allowed | Where-Object { Test-OrdinalEqual $_ $Path }).Count -gt 0
  return $validRole -and $validPath
}
function Require-Pass(
  [string]$Root,
  [string]$Stage,
  [string]$FeatureName,
  [string]$RequirementsHash,
  [string]$AcceptanceHash,
  [string]$DesignHash,
  [string]$RequirementsCurrentHash,
  [string]$DesignCurrentHash
) {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
  if (-not (Test-Path -LiteralPath $Root -PathType Container) -or (Get-Item -LiteralPath $Root).LinkType) { Fail "missing $Stage predecessor report root" }
  $verdictCandidates = @(Get-ChildItem -LiteralPath $Root -Filter integrated-verdict.json -File -Recurse)
  if ($verdictCandidates.Count -eq 0) { Fail "missing persisted $Stage PASS verdict" }
  $canonicalCandidates = foreach ($candidate in $verdictCandidates) {
    $relativeDirectory = [IO.Path]::GetRelativePath($Root, $candidate.DirectoryName).Replace('\', '/')
    $match = [Text.RegularExpressions.Regex]::Match($relativeDirectory, '^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)$')
    if (-not $match.Success) { Fail "persisted $Stage verdict is outside a canonical attempt/round directory" }
    [pscustomobject]@{ File = $candidate; Attempt = [int64]$match.Groups[1].Value; Round = [int64]$match.Groups[2].Value }
  }
  $verdict = ($canonicalCandidates | Sort-Object Attempt, Round | Select-Object -Last 1).File
  $data = Get-Content -LiteralPath $verdict.FullName -Raw | ConvertFrom-Json
  $validVerdict = (Test-OrdinalEqual $data.feature $FeatureName) -and (Test-OrdinalEqual $data.stage $Stage) -and (Test-OrdinalEqual $data.verdict 'PASS') -and $data.attempt -gt 0 -and $data.round -gt 0
  if (Test-OrdinalEqual $Stage 'spec') { $validVerdict = $validVerdict -and (Test-OrdinalEqual $data.schema 'spec-review-integrated-verdict/v1') -and -not [string]::IsNullOrWhiteSpace($data.reviewer_a_run_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_b_run_id) -and -not (Test-OrdinalEqual $data.reviewer_a_run_id $data.reviewer_b_run_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_a_host_session_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_b_host_session_id) -and -not (Test-OrdinalEqual $data.reviewer_a_host_session_id $data.reviewer_b_host_session_id) } else { $validVerdict = $validVerdict -and (Test-OrdinalEqual $data.schema 'integrated-verdict/v1') -and -not [string]::IsNullOrWhiteSpace($data.run_id) }
  if (-not $validVerdict) { Fail "persisted $Stage verdict is not a complete PASS contract" }
  $contractPath = Join-Path $verdict.DirectoryName "$Stage-review-contract.json"
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf) -or (Get-Item -LiteralPath $contractPath).LinkType) { Fail "missing persisted $Stage review contract" }
  $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
  if (-not (Test-OrdinalEqual $contract.schema "$Stage-review-contract/v1") -or -not (Test-OrdinalEqual $contract.stage $Stage) -or -not (Test-OrdinalEqual $contract.feature $FeatureName) -or -not (Test-OrdinalEqual $contract.verdict 'PASS') -or $contract.attempt -le 0 -or $contract.round -le 0 -or [string]::IsNullOrWhiteSpace($contract.run_id)) { Fail "persisted $Stage contract is incomplete" }
  $expectedContractDirectory = [IO.Path]::GetFullPath((Join-Path $Root "attempt-$($contract.attempt)/round-$($contract.round)"))
  if (-not (Test-OrdinalEqual ([IO.Path]::GetFullPath($verdict.DirectoryName)) $expectedContractDirectory)) { Fail "persisted $Stage contract attempt/round do not match its report path" }
  $reviewers = @($contract.reviewers)
  $expectedRoles = @("$Stage-reviewer-a", "$Stage-reviewer-b")
  if ($reviewers.Count -ne 2 -or @($expectedRoles | Where-Object { $expectedRole = $_; @($reviewers | Where-Object { Test-OrdinalEqual $_.role $expectedRole }).Count -ne 1 }).Count -gt 0) { Fail "persisted $Stage contract has invalid reviewers" }
  if (@($reviewers.host_session_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.host_session_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract does not isolate reviewer sessions" }
  if (@($reviewers.run_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.run_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract has invalid reviewer run IDs" }
  $manifest = @($reviewers | ForEach-Object { @($_.allowed_input_manifest) })
  $calibrationPath = if ($Stage -eq 'spec') { 'plugins/sdd-review-loop/references/spec-review-calibration.md' } else { 'plugins/sdd-review-loop/references/reviewer-calibration.md' }
  $calibrationHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $calibrationPath) -Algorithm SHA256).Hash.ToLower()
  $invalidManifest = @($reviewers | ForEach-Object {
    $role = $_.role
    @($_.allowed_input_manifest) | Where-Object {
      $relativePath = Get-ManifestRelativePath $_.path $repoRoot
      [string]::IsNullOrWhiteSpace($relativePath) -or
        $_.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        -not (Test-AllowedManifestPath $role $relativePath $Stage $FeatureName $contract.attempt $contract.round $calibrationPath)
    }
  }).Count -gt 0
  $duplicateManifestPath = $false
  foreach ($reviewer in $reviewers) {
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      $relativePath = Get-ManifestRelativePath $entry.path $repoRoot
      if (-not [string]::IsNullOrWhiteSpace($relativePath) -and -not $seenPaths.Add($relativePath)) { $duplicateManifestPath = $true }
    }
  }
  if ($manifest.Count -eq 0 -or $invalidManifest -or $duplicateManifestPath) { Fail "persisted $Stage contract has an invalid allowed input manifest" }
  function Test-ManifestEntry([object]$Reviewer, [string]$ExpectedPath, [string[]]$AllowedHashes) {
    foreach ($entry in @($Reviewer.allowed_input_manifest)) {
      $relativePath = Get-ManifestRelativePath $entry.path $repoRoot
      if (Test-OrdinalEqual $relativePath $ExpectedPath) {
        foreach ($allowedHash in $AllowedHashes) {
          if (Test-OrdinalEqual $entry.sha256 $allowedHash) { return $true }
        }
      }
    }
    return $false
  }
  $expected = @(
    @("specs/$FeatureName/requirements.md", @($RequirementsHash, $RequirementsCurrentHash)),
    @("specs/$FeatureName/acceptance-tests.md", @($AcceptanceHash))
  )
  if ($Stage -eq 'impl') { $expected += ,@("specs/$FeatureName/design.md", @($DesignHash, $DesignCurrentHash)) }
  foreach ($reviewer in $reviewers) {
    foreach ($pair in $expected) {
      if (-not (Test-ManifestEntry $reviewer $pair[0] $pair[1])) { Fail "persisted $Stage contract does not match canonical current inputs for every reviewer" }
    }
    if (-not (Test-ManifestEntry $reviewer $calibrationPath @($calibrationHash))) { Fail "persisted $Stage contract does not match canonical current inputs for every reviewer" }
    $precheckPath = "reports/$Stage-review/$FeatureName/attempt-$($contract.attempt)/round-$($contract.round)/precheck-result.json"
    $precheckHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $precheckPath) -Algorithm SHA256).Hash.ToLower()
    if (-not (Test-ManifestEntry $reviewer $precheckPath @($precheckHash))) { Fail "persisted $Stage contract does not bind every reviewer to precheck evidence" }
  }
  $reviewerA = @($reviewers | Where-Object { Test-OrdinalEqual $_.role "$Stage-reviewer-a" })[0]
  $reviewerB = @($reviewers | Where-Object { Test-OrdinalEqual $_.role "$Stage-reviewer-b" })[0]
  $summaryPath = "reports/$Stage-review/$FeatureName/attempt-$($contract.attempt)/round-$($contract.round)/integrated-summary.json"
  $summaryHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $summaryPath) -Algorithm SHA256).Hash.ToLower()
  if (-not (Test-ManifestEntry $reviewerB $summaryPath @($summaryHash))) { Fail "persisted $Stage contract does not bind reviewer B to the integrated summary" }
  if ((Test-OrdinalEqual $Stage 'impl') -and $contract.round -gt 1) {
    $previousSummaryPath = "reports/$Stage-review/$FeatureName/attempt-$($contract.attempt)/round-$($contract.round - 1)/integrated-summary.json"
    $previousSummaryHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $previousSummaryPath) -Algorithm SHA256).Hash.ToLower()
    if (-not (Test-ManifestEntry $reviewerA $previousSummaryPath @($previousSummaryHash))) { Fail "persisted impl contract does not bind reviewer A to the previous integrated summary" }
  }
  # investigation.md's expected pin is derived from the contract under
  # validation -- never from the live working tree. Every other entry checked
  # above comes from an immutable or deliberately-current source:
  # requirements/acceptance/design carry BOTH the contract's recorded hash and
  # the current one, so an untouched file and a sealed file are both accepted;
  # precheck-result.json and integrated-summary.json are frozen round artifacts
  # that nothing may append to. investigation.md was the lone outlier, pinned to
  # live bytes with no recorded-hash alternative, and it is the single worst file
  # to read live: by design it is the document that accumulates the amendment
  # record ACROSS stages, so it grows after a round is sealed as a matter of
  # course. Reading it live compared today's bytes against the correctly-pinned
  # ones and refused the downstream stage outright -- permanently, since nothing
  # can un-grow the file (epic-196: 'persisted spec contract reviewer manifest is
  # missing investigation evidence', with this validation running unconditionally
  # so -ProvenanceRereview granted no way past it). A sealed contract is evidence
  # about the past; validating it against the present is a category error. The
  # live-vs-pinned question belongs to check-workflow-state.ps1, which asks it
  # deliberately and carries the amendment-record growth tolerance for exactly
  # this file.
  #
  # Same discipline as spec-review-precheck.ps1's Test-ValidateContract: every
  # reviewer that pinned the file must have pinned the SAME bytes (the unique set
  # must collapse to one value), and that value must be a well-formed digest, so
  # a contract whose reviewer A and reviewer B disagree about what they read is
  # still refused. The per-reviewer binding below is unchanged: once any reviewer
  # pinned the file, BOTH must have. Absent from the manifest entirely means the
  # reviewers declared they did not read it, which is legal -- the allowed-path
  # table permits investigation.md for the spec and impl stages but never
  # requires it -- so nothing is expected and the file merely existing today
  # cannot invalidate a contract sealed before it was written.
  $investigationPath = "specs/$FeatureName/investigation.md"
  $investigationPins = @()
  foreach ($reviewer in $reviewers) {
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      if (Test-OrdinalEqual (Get-ManifestRelativePath $entry.path $repoRoot) $investigationPath) {
        $investigationPins += [string]$entry.sha256
      }
    }
  }
  $uniqueInvestigationPins = @($investigationPins | Select-Object -Unique)
  if ($uniqueInvestigationPins.Count -gt 1) { Fail "persisted $Stage contract reviewer manifest records an ambiguous or malformed investigation evidence pin" }
  if ($uniqueInvestigationPins.Count -eq 1) {
    $investigationPin = [string]$uniqueInvestigationPins[0]
    if ($investigationPin -cnotmatch '^[0-9a-f]{64}$') { Fail "persisted $Stage contract reviewer manifest records an ambiguous or malformed investigation evidence pin" }
    foreach ($reviewer in $reviewers) {
      if (-not (Test-ManifestEntry $reviewer $investigationPath @($investigationPin))) { Fail "persisted $Stage contract does not bind every reviewer to investigation.md" }
    }
  }
  Assert-ContractReviewerAgreement $contract $Stage $FeatureName $repoRoot
  if ($contract.attempt -ne $data.attempt -or $contract.round -ne $data.round -or -not (Test-OrdinalEqual $contract.verdict $data.verdict)) { Fail "persisted $Stage verdict and contract contradict each other" }
  if (Test-OrdinalEqual $Stage 'spec') {
    if (-not (Test-OrdinalEqual $reviewerA.run_id $data.reviewer_a_run_id) -or -not (Test-OrdinalEqual $reviewerB.run_id $data.reviewer_b_run_id) -or -not (Test-OrdinalEqual $reviewerA.host_session_id $data.reviewer_a_host_session_id) -or -not (Test-OrdinalEqual $reviewerB.host_session_id $data.reviewer_b_host_session_id)) { Fail 'persisted spec verdict and contract reviewer identities contradict each other' }
  } elseif (-not (Test-OrdinalEqual $contract.run_id $data.run_id)) { Fail "persisted $Stage verdict and contract run IDs contradict each other" }
}
if ($Feature -notmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'invalid feature slug' }
if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$spec = Join-Path $root "specs/$Feature"
$report = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-$Round"
if (-not (Test-Path -LiteralPath $spec -PathType Container) -or (Get-Item -LiteralPath $spec).LinkType) { Fail 'feature specification directory must be a real directory' }
$registry = Get-Content -LiteralPath (Join-Path $root 'specs/workflow-state-registry.json') -Raw | ConvertFrom-Json
$profileEntry = @($registry.entries | Where-Object { Test-OrdinalEqual $_.feature $Feature } | Select-Object -Last 1)
$fullProfile = $profileEntry.Count -eq 1 -and (Test-OrdinalEqual $profileEntry[0].profile 'full')
$layerNames = @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')
$requirements = Join-Path $spec 'requirements.md'; $design = Join-Path $spec 'design.md'; $acceptance = Join-Path $spec 'acceptance-tests.md'

if ($VerifyInputs) {
  $precheckPath = Join-Path $report 'precheck-result.json'
  if (-not (Test-AdrBoundFilePath $root "reports/impl-review/$Feature/attempt-$Attempt/round-$Round/precheck-result.json") -or
      -not (Test-AdrBoundFilePath $root "specs/$Feature/design.md")) { Fail 'unsafe precheck or design input path' }
  if (-not (Test-Path -LiteralPath $precheckPath -PathType Leaf) -or (Get-Item -LiteralPath $precheckPath).LinkType) { Fail 'precheck evidence is missing or substituted' }
  foreach ($path in @($requirements, $design, $acceptance)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "review input is missing or substituted: $path" }
  }
  $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json
  if (-not (Test-OrdinalEqual $precheck.schema 'impl-review-precheck/v1') -or
      -not (Test-OrdinalEqual $precheck.feature $Feature) -or
      [int64]$precheck.attempt -ne [int64]$Attempt -or [int64]$precheck.round -ne [int64]$Round -or
      -not (Test-OrdinalEqual $precheck.design_sha256 ((Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower())) -or
      -not (Test-OrdinalEqual $precheck.requirements_sha256 ((Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower())) -or
      -not (Test-OrdinalEqual $precheck.acceptance_sha256 ((Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower()))) {
    Fail 'core review inputs changed after precheck'
  }
  $persistedLayerProperties = if ($null -eq $precheck.psobject.Properties['layer_sha256']) {
    @()
  } else {
    @($precheck.layer_sha256.psobject.Properties)
  }
  if ($fullProfile -or $persistedLayerProperties.Count -gt 0) {
    $boundNames = @($precheck.layer_sha256.psobject.Properties.Name)
    if ($boundNames.Count -ne $layerNames.Count -or
        @($layerNames | Where-Object { $_ -notin $boundNames }).Count -gt 0) {
      Fail 'precheck layer manifest is incomplete'
    }
    foreach ($name in $layerNames) {
      $path = Join-Path $spec $name
      if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "layer review input is missing or substituted: $path" }
      $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
      if (-not (Test-OrdinalEqual $precheck.layer_sha256.$name $actual)) { Fail "layer review input changed after precheck: $path" }
    }
  }
  if (@($precheck.PSObject.Properties.Name) -ccontains 'adr_inputs') {
    if ($precheck.adr_inputs -isnot [array]) { Fail 'invalid ADR input array' }
    $normalized = [Collections.Generic.List[object]]::new()
    $previous = $null
    foreach ($entry in $precheck.adr_inputs) {
      if ($null -eq $entry -or $entry -isnot [pscustomobject]) { Fail 'invalid ADR manifest entry' }
      $keys = @($entry.PSObject.Properties.Name)
      if ($keys.Count -ne 2 -or $keys -cnotcontains 'path' -or $keys -cnotcontains 'sha256' -or
          $entry.path -isnot [string] -or $entry.sha256 -isnot [string] -or
          $entry.path -cnotmatch '^docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md$' -or
          $entry.sha256 -cnotmatch '^[0-9a-f]{64}$') { Fail 'invalid ADR manifest fields' }
      if ($null -ne $previous -and [StringComparer]::Ordinal.Compare($previous, $entry.path) -ge 0) {
        Fail 'ADR manifest is not sorted and unique'
      }
      $previous = $entry.path
      $normalized.Add([ordered]@{path=$entry.path;sha256=$entry.sha256})
    }
    $recordedAdrJson = ConvertTo-Json -InputObject ($normalized.ToArray()) -Depth 4 -Compress
    $actualAdrJson = Get-AdrPrecheckInputsJson $root "specs/$Feature/design.md" $precheck.design_sha256
    if ($recordedAdrJson -cne $actualAdrJson) { Fail 'ADR inputs changed after precheck' }
    foreach ($field in @('design_sha256','requirements_sha256','acceptance_sha256')) {
      if ($precheck.$field -isnot [string] -or $precheck.$field.Length -ne 64 -or
          $precheck.$field -cnotmatch '^[0-9a-f]{64}$') {
        Fail 'invalid core input digest'
      }
    }
    $boundLayerJson = Get-AdrLayerJson $precheck.layer_sha256
    $material = "$($precheck.design_sha256):$($precheck.requirements_sha256):$($precheck.acceptance_sha256)"
    if ($boundLayerJson -cne '{}') { $material += ':' + $boundLayerJson }
    $material += ':adr_inputs/v1:' + $actualAdrJson
    $expectedInput = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($material))).ToLowerInvariant()
    if ($precheck.input_sha256 -isnot [string] -or $precheck.input_sha256 -cne $expectedInput) {
      Fail 'ADR input material hash mismatch'
    }
  }
  Write-Output 'impl-review-precheck: inputs verified for reviewer invocation.'
  exit 0
}

if (Test-Path -LiteralPath $report) { Fail 'round destination already exists (replay is forbidden)' }
$powerShellExe = (Get-Process -Id $PID).Path
if ($ProvenanceRereview) {
  # Post-implementation evidence re-binding; POSIX parity with
  # impl-review-precheck.sh's --provenance-rereview. Same guard: a prior
  # persisted PASS at this stage must already exist, so the mode can only
  # re-bind evidence for a design that genuinely passed. The canonical gate is
  # advisory rather than fatal here, because a stale impl-stage contract hash is
  # the condition this mode exists to repair.
  $priorPass = $false
  $verdictRoot = Join-Path $root "reports/impl-review/$Feature"
  if (Test-Path -LiteralPath $verdictRoot) {
    foreach ($verdictFile in (Get-ChildItem -LiteralPath $verdictRoot -Recurse -File -Filter 'integrated-verdict.json' -ErrorAction SilentlyContinue)) {
      if ($verdictFile.LinkType) { continue }
      try { $verdict = Get-Content -Raw -LiteralPath $verdictFile.FullName | ConvertFrom-Json } catch { continue }
      if ((Test-OrdinalEqual $verdict.feature $Feature) -and
          (Test-OrdinalEqual $verdict.stage 'impl') -and
          (Test-OrdinalEqual $verdict.verdict 'PASS')) { $priorPass = $true; break }
    }
  }
  if (-not $priorPass) { Fail 'provenance re-review requires a prior persisted impl-review PASS verdict' }
  & $powerShellExe -NoProfile -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1') --feature $Feature --opening "impl:${Attempt}:${Round}"
  if ($LASTEXITCODE -ne 0) {
    Write-Warning 'impl-review-precheck: canonical workflow-state validation failed; proceeding under -ProvenanceRereview (impl-stage evidence re-binding in progress).'
  }
} else {
  & $powerShellExe -NoProfile -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1') --feature $Feature --opening "impl:${Attempt}:${Round}"
  if ($LASTEXITCODE -ne 0) { Fail 'canonical workflow-state validation failed' }
}
foreach ($path in @($requirements, $design, $acceptance)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" } }
$specStatus = (Select-String -LiteralPath $requirements -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
$implStatus = (Select-String -LiteralPath $design -Pattern '^Impl-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if ($specStatus -ne 'Passed') { Fail 'requirements.md must declare Spec-Review-Status: Passed' }
if ($ProvenanceRereview) {
  # The header stays Passed for the whole re-binding, deliberately. Flipping it
  # to Pending is not an option: check-workflow-state's task-lifecycle rule
  # requires every stage to read Passed once any task is Approved or past
  # Planned, so a Pending header on a shipped feature trades this stage's
  # contradiction for a worse one.
  if ($implStatus -ne 'Passed') { Fail "-ProvenanceRereview requires design.md to declare Impl-Review-Status: Passed; it declares '$implStatus'. Without a prior pass there is no provenance to re-bind -- run an ordinary attempt instead." }
} elseif ($implStatus -ne 'Pending') { Fail 'design.md must declare Impl-Review-Status: Pending' }
if (-not (Test-AdrBoundFilePath $root "specs/$Feature/design.md")) { Fail 'unsafe design input path' }
$designHash = (Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower(); $requirementsHash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower(); $acceptanceHash = (Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower()
$adrInputJson = Get-AdrPrecheckInputsJson $root "specs/$Feature/design.md" $designHash
$calibration = Join-Path $root 'plugins/sdd-review-loop/references/reviewer-calibration.md'
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Get-Item -LiteralPath $calibration).LinkType) { Fail 'plugins/sdd-review-loop/references/reviewer-calibration.md not found' }
$calibrationHash = (Get-FileHash -LiteralPath $calibration -Algorithm SHA256).Hash.ToLower()
$layerSha256 = [ordered]@{}
if ($fullProfile) {
  foreach ($name in $layerNames) {
    $path = Join-Path $spec $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "layer review input is missing or substituted: $path" }
    $layerSha256[$name] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
  }
}
$specReviewedRequirementsHash = Get-ReviewedHash $requirements 'Spec-Review-Status' 'Pending'
Require-Pass (Join-Path $root "reports/spec-review/$Feature") 'spec' $Feature $specReviewedRequirementsHash $acceptanceHash '' $requirementsHash ''
$requiredFields = @('## Components', 'Feature Type:', 'Data Entities:', 'Existing Data Affected:', '## Security Boundaries')
$legacyDesign = (@($requiredFields | Where-Object { -not (Select-String -LiteralPath $design -SimpleMatch -Quiet -Pattern $_) }).Count -ge 3)
$designReqDrift = $false
if ([int64]$Round -gt 1) {
  $priorRound = [int64]$Round - 1
  $priorContract = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-$priorRound/impl-review-contract.json"
  if (Test-Path -LiteralPath $priorContract -PathType Leaf) {
    $prior = Get-Content -LiteralPath $priorContract -Raw | ConvertFrom-Json
    $previousAdrJson = Get-AdrPreviousRoundJson $root $prior $Feature ([long]$Attempt) $priorRound
    $designUnchanged = Test-OrdinalEqual $prior.design_sha256 $designHash
    $adrUnchanged = $null -eq $previousAdrJson -or $previousAdrJson -ceq $adrInputJson
    if ($designUnchanged -and $adrUnchanged) {
      Fail "design and admitted ADR inputs are unchanged from round $priorRound"
    }
    $roundOneContract = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-1/impl-review-contract.json"
    if (Test-Path -LiteralPath $roundOneContract -PathType Leaf) {
      $roundOne = Get-Content -LiteralPath $roundOneContract -Raw | ConvertFrom-Json
      if ($roundOne.requirements_sha256 -and $roundOne.requirements_sha256 -ne $requirementsHash) { $designReqDrift = $true }
    }
  }
}
# AC coverage. Every AC-NNN in requirements.md must be named in design.md;
# behavioural twin of impl-review-precheck.sh's gate, which carries the full
# epic-136-phase4-docs history: reviewer rounds were being burned finding, one
# per round, criteria that spec review had added late as gap-closers and the
# design had dropped silently. A design that does not name an AC cannot be
# audited for covering it.
#
# NARROW EXCEPTION (human ruling, 2026-08-24). Criteria whose OWN defining row
# in requirements.md's acceptance table declares Global scope are process-and-
# registration content, not design content, and are excused. The exception keys
# on a property the requirements document states about ITSELF, never on a list
# of AC ids: the requirement-trace cell is bimodal across this repository --
# either a REQ-NNN trace or a Global-scope declaration -- and both spellings in
# use (`| AC-023 | Global |` and `| AC-035 (Global) | - |`) are read here. Only
# the first cell and the trace cell of the criterion's own defining row are
# consulted, and the first matching row decides; an AC id mentioned in prose or
# in another criterion's text is never a declaration of scope.
function Test-AcScopedGlobal([string]$Id, [string[]]$Lines) {
  foreach ($rawLine in $Lines) {
    $line = $rawLine -creplace '\r$', ''
    if (-not $line.StartsWith('|', [StringComparison]::Ordinal)) { continue }
    $cells = $line -split '\|'
    if ($cells.Count -lt 4) { continue }
    $c1 = $cells[1] -creplace '^[ \t]+', '' -creplace '[ \t]+$', ''
    $c2 = $cells[2] -creplace '^[ \t]+', '' -creplace '[ \t]+$', ''
    $annotated = $false
    if ($c1 -cmatch '\(Global\)$') {
      $annotated = $true
      $c1 = ($c1 -creplace '\(Global\)$', '') -creplace '[ \t]+$', ''
    }
    if (-not (Test-OrdinalEqual $c1 $Id)) { continue }
    return ($annotated -or (Test-OrdinalEqual $c2 'Global'))
  }
  return $false
}
$requirementsRaw = [IO.File]::ReadAllText($requirements)
$requirementsLines = $requirementsRaw -split "`n"
$designRaw = [IO.File]::ReadAllText($design)
$acIds = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
foreach ($acMatch in [Text.RegularExpressions.Regex]::Matches($requirementsRaw, 'AC-[0-9]{3}')) { [void]$acIds.Add($acMatch.Value) }
$acMissing = @()
$acGlobal = @()
foreach ($acId in $acIds) {
  if (Test-AcScopedGlobal $acId $requirementsLines) { $acGlobal += $acId; continue }
  if (-not $designRaw.Contains($acId)) { $acMissing += $acId }
}
# Never silent: an exercised exception is reported whether or not the gate then
# fails, so a reader can see which criteria were excused and go check the rows
# that excused them.
if ($acGlobal.Count -gt 0) {
  [Console]::Error.WriteLine("NOTE: impl-review-precheck: not requiring design.md to name these criteria, which requirements.md scopes Global (process and registration, not design): $($acGlobal -join ' ')")
}
if ($acMissing.Count -gt 0) {
  Fail ("design.md never names these acceptance criteria: $($acMissing -join ' '). Each appears in requirements.md without being scoped Global there -- so each states behaviour this design must plan for -- yet none of these strings occurs anywhere in design.md, so an implementer could satisfy the plan and still not deliver them.")
}
$layerHashJson = $layerSha256 | ConvertTo-Json -Compress
$layerHashJson = Get-AdrLayerJson $layerSha256
$inputMaterial = if ($fullProfile) { "$designHash`:$requirementsHash`:$acceptanceHash`:$layerHashJson" } else { "$designHash`:$requirementsHash`:$acceptanceHash" }
$inputMaterial += ':adr_inputs/v1:' + $adrInputJson
$inputHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($inputMaterial))).ToLower()
$base = Join-Path $root 'reports/impl-review'; New-Item -ItemType Directory -Path $base -Force | Out-Null
$temporaryContract = [IO.Path]::GetTempFileName()
try {
  [ordered]@{schema='review-contract/v1';stage='impl';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;input_sha256=$inputHash;run_id='impl-precheck';verdict='PASS'} | ConvertTo-Json -Compress | Set-Content -LiteralPath $temporaryContract -Encoding utf8NoBOM
  & (Join-Path $PSScriptRoot 'review-contract-validate.ps1') -Feature $Feature -Attempt $Attempt -Round $Round -Stage impl -ReportRoot (Join-Path $root "reports/impl-review/$Feature") -Contract $temporaryContract | Out-Null
} finally { Remove-Item -LiteralPath $temporaryContract -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $report | Out-Null
[ordered]@{schema='impl-review-precheck/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;impl_review_status_field=$implStatus;legacy_design=$legacyDesign;design_req_drift=$designReqDrift;design_sha256=$designHash;requirements_sha256=$requirementsHash;acceptance_sha256=$acceptanceHash;layer_sha256=$layerSha256;adr_inputs=(ConvertFrom-Json -InputObject $adrInputJson -NoEnumerate);input_sha256=$inputHash;generated_at=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $report 'precheck-result.json') -Encoding utf8NoBOM
Write-Output "impl-review-precheck: complete. Output written to $report/"
