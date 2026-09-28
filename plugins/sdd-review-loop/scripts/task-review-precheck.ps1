# Usage: task-review-precheck.ps1 -Feature <feature-slug> -Attempt <attempt> -Round <round> [-VerifyInputs|-ProvenanceRereview]
param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round,
  [switch]$VerifyInputs,
  [switch]$ProvenanceRereview
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "task-review-precheck: $Message" }
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

# Current PASS predecessor only; not historical NEEDS_WORK progress validation.
function Get-PersistedAdrJson {
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
function Get-PersistedAdrPassPaths {
  param([string]$RepoRoot, $Contract, [string]$FeatureName,
        [string]$DesignReviewedHash, [string]$DesignCurrentHash)
  $relativeRoot = "reports/impl-review/$FeatureName/attempt-$($Contract.attempt)/round-$($Contract.round)"
  $precheckRelative = "$relativeRoot/precheck-result.json"
  $designRelative = "specs/$FeatureName/design.md"
  if (-not (Test-AdrBoundFilePath $RepoRoot "$relativeRoot/impl-review-contract.json") -or
      -not (Test-AdrBoundFilePath $RepoRoot $precheckRelative)) { Fail 'unsafe persisted ADR contract/precheck' }
  $precheckPath = Join-Path $RepoRoot $precheckRelative
  $precheckHash = (Get-FileHash -LiteralPath $precheckPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json -NoEnumerate
  if ($precheck -isnot [pscustomobject]) { Fail 'persisted ADR precheck must be an object' }
  $contractHasAdr = @($Contract.PSObject.Properties.Name) -ccontains 'adr_inputs'
  $precheckHasAdr = @($precheck.PSObject.Properties.Name) -ccontains 'adr_inputs'
  if ($contractHasAdr -ne $precheckHasAdr) { Fail 'one-sided persisted ADR extension' }
  if (-not $contractHasAdr) { return }
  if ($precheck.schema -cne 'impl-review-precheck/v1' -or $precheck.feature -cne $FeatureName -or
      $precheck.attempt -isnot [long] -or $precheck.round -isnot [long] -or
      $precheck.attempt -ne $Contract.attempt -or $precheck.round -ne $Contract.round) {
    Fail 'persisted ADR precheck identity mismatch'
  }
  $recorded = Get-PersistedAdrJson $precheck.adr_inputs
  if ((Get-PersistedAdrJson $Contract.adr_inputs) -cne $recorded) { Fail 'persisted ADR sets disagree' }
  foreach ($field in @('design_sha256','requirements_sha256','acceptance_sha256')) {
    if ($precheck.$field -isnot [string] -or $precheck.$field.Length -ne 64 -or
        $precheck.$field -cnotmatch '\A[0-9a-f]{64}\z' -or
        $Contract.$field -isnot [string] -or $Contract.$field -cne $precheck.$field) {
      Fail 'persisted ADR core pins disagree'
    }
  }
  $layers = Get-AdrLayerJson $precheck.layer_sha256
  if ((Get-AdrLayerJson $Contract.layer_sha256) -cne $layers) { Fail 'persisted ADR layer pins disagree' }
  foreach ($reviewer in $Contract.reviewers) {
    $letter = switch -CaseSensitive ($reviewer.role) { 'impl-reviewer-a' { 'a' } 'impl-reviewer-b' { 'b' } default { Fail 'invalid persisted ADR reviewer role' } }
    $outputRelative = "$relativeRoot/reviewer-$letter.json"
    if (-not (Test-AdrBoundFilePath $RepoRoot $outputRelative)) { Fail 'unsafe persisted ADR reviewer output' }
    $output = Get-Content -LiteralPath (Join-Path $RepoRoot $outputRelative) -Raw | ConvertFrom-Json -NoEnumerate
    if ($output -isnot [pscustomobject] -or $output.schema -cne "$($reviewer.role)/v1" -or
        $output.stage -cne 'impl' -or $output.role -cne $reviewer.role) { Fail 'persisted ADR output identity mismatch' }
    foreach ($field in @('run_id','host_session_id')) {
      if ($output.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($output.$field) -or
          $output.$field -cne $reviewer.$field) { Fail 'persisted ADR output provenance mismatch' }
    }
    $manifests = @()
    foreach ($source in @($reviewer, $output)) {
      if ($source.allowed_input_manifest -isnot [array]) { Fail 'invalid persisted ADR output manifest' }
      $map = [Collections.Generic.SortedDictionary[string,string]]::new([StringComparer]::Ordinal)
      foreach ($entry in $source.allowed_input_manifest) {
        if ($entry.path -isnot [string] -or $entry.sha256 -isnot [string]) { Fail 'invalid persisted ADR output pin' }
        $relative = Get-ManifestRelativePath $entry.path $RepoRoot
        if ($null -eq $relative -or $map.ContainsKey($relative)) { Fail 'invalid or duplicate persisted ADR output path' }
        if ($relative.StartsWith('docs/adr/', [StringComparison]::Ordinal) -and $entry.path -cne $relative) { Fail 'ADR output path must be raw canonical relative' }
        $map.Add($relative, $entry.sha256)
      }
      $canonical = @($map.Keys | ForEach-Object { [ordered]@{path=$_;sha256=$map[$_]} })
      $manifests += ConvertTo-Json -InputObject $canonical -Compress -Depth 4
    }
    if ($manifests[0] -cne $manifests[1]) { Fail 'persisted ADR output manifest differs from reservation' }
    # The checks below bind the now-identical reservation and output to the precheck.
    $entries = @($reviewer.allowed_input_manifest)
    $documentPins = [ordered]@{
      'requirements.md' = $precheck.requirements_sha256
      'acceptance-tests.md' = $precheck.acceptance_sha256
    }
    foreach ($layer in $precheck.layer_sha256.PSObject.Properties) { $documentPins[$layer.Name] = $layer.Value }
    foreach ($document in $documentPins.Keys) {
      $expectedPath = "specs/$FeatureName/$document"
      $pins = @($entries | Where-Object { $_.path -is [string] -and (Get-ManifestRelativePath $_.path $RepoRoot) -ceq $expectedPath })
      if ($pins.Count -ne 1 -or $pins[0].sha256 -isnot [string] -or $pins[0].sha256 -cne $documentPins[$document]) {
        Fail "persisted ADR reviewer document binding mismatch: $document"
      }
    }
    $pcPins = @($entries | Where-Object { $_.path -is [string] -and (Get-ManifestRelativePath $_.path $RepoRoot) -ceq $precheckRelative })
    $designPins = @($entries | Where-Object { $_.path -is [string] -and (Get-ManifestRelativePath $_.path $RepoRoot) -ceq $designRelative })
    if ($pcPins.Count -ne 1 -or $pcPins[0].sha256 -cne $precheckHash -or
        $designPins.Count -ne 1 -or $designPins[0].sha256 -cne $precheck.design_sha256) {
      Fail 'reviewer lacks exact persisted ADR precheck/design binding'
    }
    $adrMap = [Collections.Generic.SortedDictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($entry in $entries) {
      if ($entry.path -isnot [string]) { Fail 'invalid reviewer manifest path type' }
      if (-not $entry.path.StartsWith('docs/adr/', [StringComparison]::Ordinal)) { continue }
      if ($adrMap.ContainsKey($entry.path)) { Fail 'duplicate reviewer ADR entry' }
      $adrMap.Add($entry.path, [pscustomobject]@{path=$entry.path;sha256=$entry.sha256})
    }
    if ((Get-PersistedAdrJson @($adrMap.Values)) -cne $recorded) { Fail 'incomplete reviewer ADR set' }
  }
  if ($precheck.design_sha256 -cne $DesignReviewedHash -and
      $precheck.design_sha256 -cne $DesignCurrentHash) { Fail 'persisted ADR design changed beyond lifecycle fields' }
  $actual = Get-AdrPrecheckInputsJson $RepoRoot $designRelative $DesignCurrentHash
  if ($actual -cne $recorded) { Fail 'current design-derived ADR inputs differ from review' }
  $material = "$($precheck.design_sha256):$($precheck.requirements_sha256):$($precheck.acceptance_sha256)"
  if ($layers -cne '{}') { $material += ':' + $layers }
  $material += ':adr_inputs/v1:' + $recorded
  $inputHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($material))).ToLowerInvariant()
  if ($precheck.input_sha256 -isnot [string] -or $precheck.input_sha256 -cne $inputHash) {
    Fail 'persisted ADR input hash mismatch'
  }
  if (-not (Test-AdrBoundFilePath $RepoRoot $precheckRelative) -or
      (Get-FileHash -LiteralPath $precheckPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $precheckHash) {
    Fail 'persisted ADR precheck changed during validation'
  }
  foreach ($entry in $precheck.adr_inputs) { $entry.path }
}
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
# WFI-025: the STATUS-NORMALIZED task-plan digest -- the same recipe as
# check-workflow-state.ps1 Get-NormalizedHash for the task stage (canonical
# form 1), which the accepting side already admits. Recorded instead of the
# raw digest when the plan's statuses are mixed, so the binding survives the
# lifecycle transitions the workflow is supposed to perform.
function Get-TasksNormalizedHash([string]$Path) {
  $text = [IO.File]::ReadAllText($Path)
  $text = [regex]::Replace($text, "(?m)^Task-Review-Status:[^\r\n]*(\r?)$", 'Task-Review-Status: Pending$1')
  $text = [regex]::Replace($text, "(?m)^Approval:[^\r\n]*(\r?)$", 'Approval: Draft$1')
  $text = [regex]::Replace($text, "(?m)^Status:[^\r\n]*(\r?)$", 'Status: Planned$1')
  $text = [regex]::Replace($text, "(?m)^Second Approval:[^\r\n]*\r?\n?", '')
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($text))
  ).ToLower()
}
# WFI-025: uniform = every ^Status: line carries one value (or none exist).
# Uniqueness is ORDINAL (case-sensitive): Sort-Object -Unique folds case by
# default, which would classify a Done/done plan as uniform here while the
# sh twin's LC_ALL=C sort -u calls it mixed (PR #336 review; the AGENTS.md
# case-sensitivity sweep's cmdlet layer).
function Test-TasksStatusesMixed([string]$Path) {
  $values = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($line in [IO.File]::ReadAllLines($Path)) {
    $m = [regex]::Match($line, '^Status:[ \t]*(.*?)[ \t]*$')
    if ($m.Success) { [void]$values.Add($m.Groups[1].Value) }
  }
  return $values.Count -gt 1
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
    $allowed += "specs/$FeatureName/tasks.md", "specs/$FeatureName/design.md",
      "specs/$FeatureName/traceability.md",
      "specs/$FeatureName/ux-spec.md", "specs/$FeatureName/frontend-spec.md",
      "specs/$FeatureName/infra-spec.md", "specs/$FeatureName/security-spec.md"
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
  $reviewers = @($contract.reviewers); $expectedRoles = @("$Stage-reviewer-a", "$Stage-reviewer-b")
  if ($reviewers.Count -ne 2 -or @($expectedRoles | Where-Object { $expectedRole = $_; @($reviewers | Where-Object { Test-OrdinalEqual $_.role $expectedRole }).Count -ne 1 }).Count -gt 0) { Fail "persisted $Stage contract has invalid reviewers" }
  if (@($reviewers.host_session_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.host_session_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract does not isolate reviewer sessions" }
  if (@($reviewers.run_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.run_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract has invalid reviewer run IDs" }
  $verifiedAdrPaths = @()
  if (Test-OrdinalEqual $Stage 'impl') {
    $verifiedAdrPaths = @(Get-PersistedAdrPassPaths $repoRoot $contract $FeatureName $DesignHash $DesignCurrentHash)
  }
  $manifest = @($reviewers | ForEach-Object { @($_.allowed_input_manifest) })
  $calibrationPath = if ($Stage -eq 'spec') { 'plugins/sdd-review-loop/references/spec-review-calibration.md' } else { 'plugins/sdd-review-loop/references/reviewer-calibration.md' }
  $calibrationHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $calibrationPath) -Algorithm SHA256).Hash.ToLower()
  $invalidManifest = @($reviewers | ForEach-Object {
    $role = $_.role
    @($_.allowed_input_manifest) | Where-Object {
      $relativePath = Get-ManifestRelativePath $_.path $repoRoot
      [string]::IsNullOrWhiteSpace($relativePath) -or
        $_.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        (-not (Test-AllowedManifestPath $role $relativePath $Stage $FeatureName $contract.attempt $contract.round $calibrationPath) -and
         -not ((Test-OrdinalEqual $Stage 'impl') -and $verifiedAdrPaths -ccontains $_.path))
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
    $contractLayerProperties = if ($null -eq $contract.psobject.Properties['layer_sha256']) { @() } else { @($contract.layer_sha256.psobject.Properties) }
    if ($Stage -eq 'impl' -and $contractLayerProperties.Count -gt 0) {
      foreach ($layer in @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')) {
        $layerPath = Join-Path $repoRoot "specs/$FeatureName/$layer"
        if (-not (Test-ManifestEntry $reviewer "specs/$FeatureName/$layer" @((Get-FileHash -LiteralPath $layerPath -Algorithm SHA256).Hash.ToLower()))) {
          Fail "persisted impl contract does not bind every reviewer to canonical layer inputs"
        }
      }
    }
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
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path; $spec = Join-Path $root "specs/$Feature"; $report = Join-Path $root "reports/task-review/$Feature/attempt-$Attempt/round-$Round"
if (-not (Test-Path -LiteralPath $spec -PathType Container) -or (Get-Item -LiteralPath $spec).LinkType) { Fail 'feature specification directory must be a real directory' }
$registry = Get-Content -LiteralPath (Join-Path $root 'specs/workflow-state-registry.json') -Raw | ConvertFrom-Json
$profileEntry = @($registry.entries | Where-Object { Test-OrdinalEqual $_.feature $Feature } | Select-Object -Last 1)
$fullProfile = $profileEntry.Count -eq 1 -and (Test-OrdinalEqual $profileEntry[0].profile 'full')
$layerNames = @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')
$requirements = Join-Path $spec 'requirements.md'; $design = Join-Path $spec 'design.md'; $acceptance = Join-Path $spec 'acceptance-tests.md'; $tasks = Join-Path $spec 'tasks.md'; $traceability = Join-Path $spec 'traceability.md'

if ($VerifyInputs) {
  $precheckPath = Join-Path $report 'precheck-result.json'
  if (-not (Test-Path -LiteralPath $precheckPath -PathType Leaf) -or (Get-Item -LiteralPath $precheckPath).LinkType) { Fail 'precheck evidence is missing or substituted' }
  foreach ($path in @($requirements, $acceptance, $tasks)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "review input is missing or substituted: $path" }
  }
  $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json
  # WFI-025: verify the task plan against the digest FORM the precheck
  # declared. A normalized record tolerates the lifecycle flips it exists to
  # absorb; a body edit still changes the normalized digest and fails here.
  $tasksVerifyHash = (Get-FileHash -LiteralPath $tasks -Algorithm SHA256).Hash.ToLower()
  $declaredForm = 'raw'
  if ($null -ne $precheck.psobject.Properties['tasks_sha256_form']) { $declaredForm = [string]$precheck.tasks_sha256_form }
  if ($declaredForm -ceq 'normalized') { $tasksVerifyHash = Get-TasksNormalizedHash $tasks }
  if (-not (Test-OrdinalEqual $precheck.schema 'task-review-precheck/v1') -or
      -not (Test-OrdinalEqual $precheck.feature $Feature) -or
      [int64]$precheck.attempt -ne [int64]$Attempt -or [int64]$precheck.round -ne [int64]$Round -or
      -not (Test-OrdinalEqual $precheck.tasks_sha256 $tasksVerifyHash) -or
      -not (Test-OrdinalEqual $precheck.requirements_sha256 ((Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower())) -or
      -not (Test-OrdinalEqual $precheck.acceptance_sha256 ((Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower()))) {
    Fail 'core review inputs changed after precheck'
  }
  $persistedLayerProperties = if ($null -eq $precheck.psobject.Properties['layer_sha256']) { @() } else { @($precheck.layer_sha256.psobject.Properties) }
  if ($fullProfile -or $persistedLayerProperties.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $design -PathType Leaf) -or (Get-Item -LiteralPath $design).LinkType) { Fail 'design review input is missing or substituted' }
    if (-not (Test-OrdinalEqual $precheck.design_sha256 ((Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower()))) { Fail 'design review input changed after precheck' }
    if (-not (Test-Path -LiteralPath $traceability -PathType Leaf) -or (Get-Item -LiteralPath $traceability).LinkType) { Fail 'traceability review input is missing or substituted' }
    if (-not (Test-OrdinalEqual $precheck.traceability_sha256 ((Get-FileHash -LiteralPath $traceability -Algorithm SHA256).Hash.ToLower()))) { Fail 'traceability review input changed after precheck' }
    & (Join-Path $PSScriptRoot 'validate-layer-traceability.ps1') -Path $traceability -RequirementsPath $requirements
    $boundNames = @($precheck.layer_sha256.psobject.Properties.Name)
    if ($boundNames.Count -ne $layerNames.Count -or @($layerNames | Where-Object { $_ -notin $boundNames }).Count -gt 0) { Fail 'precheck layer manifest is incomplete' }
    foreach ($name in $layerNames) {
      $path = Join-Path $spec $name
      if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "layer review input is missing or substituted: $path" }
      if (-not (Test-OrdinalEqual $precheck.layer_sha256.$name ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()))) { Fail "layer review input changed after precheck: $path" }
    }
  }
  Write-Output 'task-review-precheck: inputs verified for reviewer invocation.'
  exit 0
}

if (Test-Path -LiteralPath $report) { Fail 'round destination already exists (replay is forbidden)' }
$powerShellExe = (Get-Process -Id $PID).Path
if ($ProvenanceRereview) {
  $taskReviewRoot = Join-Path $root "reports/task-review/$Feature"
  $priorPass = $false
  if (Test-Path -LiteralPath $taskReviewRoot -PathType Container) {
    foreach ($verdictFile in @(Get-ChildItem -LiteralPath $taskReviewRoot -Filter integrated-verdict.json -File -Recurse -ErrorAction SilentlyContinue)) {
      try {
        $verdictData = Get-Content -LiteralPath $verdictFile.FullName -Raw | ConvertFrom-Json
      } catch {
        continue
      }
      if ((Test-OrdinalEqual $verdictData.feature $Feature) -and (Test-OrdinalEqual $verdictData.stage 'task') -and (Test-OrdinalEqual $verdictData.verdict 'PASS')) {
        $priorPass = $true
        break
      }
    }
  }
  if (-not $priorPass) { Fail 'provenance re-review requires a prior persisted task-review PASS verdict' }
  & $powerShellExe -NoProfile -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1') --feature $Feature
  if ($LASTEXITCODE -ne 0) {
    Write-Warning ('task-review-precheck: canonical workflow-state validation failed; ' +
      'proceeding under -ProvenanceRereview (task-stage evidence re-binding in progress).')
  }
} else {
  & $powerShellExe -NoProfile -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1') --feature $Feature
  if ($LASTEXITCODE -ne 0) { Fail 'canonical workflow-state validation failed' }
}
foreach ($path in @($requirements, $design, $acceptance, $tasks)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" } }
if ($fullProfile) {
  foreach ($path in @($traceability) + @($layerNames | ForEach-Object { Join-Path $spec $_ })) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" }
  }
}
$specStatus = (Select-String -LiteralPath $requirements -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim(); $implStatus = (Select-String -LiteralPath $design -Pattern '^Impl-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if ($specStatus -ne 'Passed') { Fail 'requirements.md must declare Spec-Review-Status: Passed' }; if ($implStatus -ne 'Passed') { Fail 'design.md must declare Impl-Review-Status: Passed' }
$edges = @(); $nodes = @(); $current = ''; $expectBlockers = $false
foreach ($line in Get-Content -LiteralPath $tasks) {
  if ($line -match '^##\s+(T-[0-9]{3})(\s|$)') { if ($expectBlockers) { Fail "$current Blockers value is missing" }; $current=$Matches[1]; $nodes += $current; $expectBlockers=$false; continue }
  if ($current -and $line -match '^Blockers:\s*(.*)$') {
    $value = $Matches[1].Trim(); if (-not $value -or $value -eq 'None') { $expectBlockers=$false; continue }
    foreach ($target in $value.Split(',')) { if ($target.Trim() -notmatch '^T-[0-9]{3}$') { Fail 'Blockers format is invalid' }; $edges += [ordered]@{from=$current;to=$target.Trim()} }
    $expectBlockers=$false; continue
  }
  if ($line -match '^###\s+Blockers\s*$') { $expectBlockers=$true; continue }
  if ($expectBlockers -and $line.Trim()) { if ($line.Trim() -ne 'None') { foreach ($target in $line.Split(',')) { if ($target.Trim() -notmatch '^T-[0-9]{3}$') { Fail 'Blockers format is invalid' }; $edges += [ordered]@{from=$current;to=$target.Trim()} } }; $expectBlockers=$false }
}
if ($expectBlockers) { Fail "$current Blockers value is missing" }
$adjacency=@{}; foreach($node in $nodes){ $adjacency[$node]=[Collections.Generic.List[string]]::new() }
foreach($edge in $edges){ if(-not $adjacency.ContainsKey($edge.to)){ Fail 'Blockers reference an unknown task' }; $adjacency[$edge.from].Add($edge.to) }
# Three-colour DFS, same algorithm as the .sh twin: absent = unvisited,
# 1 = on the current path (reaching it again means a cycle), 2 = fully explored.
# Written with an EXPLICIT stack rather than recursion — the
# validate-domain-contract.ps1 precedent — because PowerShell's call-depth/
# stack protection can abort deep recursion within the accepted T-001..T-999
# chain length, and a precheck must never crash on a valid long chain.
# Stack frames are ('enter',node)/('exit',node) pairs: a node is colour 1
# exactly while its 'exit' frame is still on the stack, so popping an 'enter'
# for a colour-1 node proves a path from that node back to itself.
function Test-GraphHasCycleFrom { param([string]$Node,[hashtable]$Adjacency,[hashtable]$Visit)
  if ($Visit[$Node]) { return $false }
  $stack = [Collections.Generic.Stack[object[]]]::new()
  $stack.Push(@('enter', $Node))
  while ($stack.Count -gt 0) {
    $frame = $stack.Pop(); $op = $frame[0]; $current = $frame[1]
    if ($op -eq 'exit') { $Visit[$current] = 2; continue }
    if ($Visit[$current] -eq 1) { return $true }
    if ($Visit[$current] -eq 2) { continue }
    $Visit[$current] = 1
    $stack.Push(@('exit', $current))
    foreach ($next in $Adjacency[$current]) { $stack.Push(@('enter', $next)) }
  }
  return $false
}
$visitState=@{}
foreach($node in $nodes){ if(Test-GraphHasCycleFrom -Node $node -Adjacency $adjacency -Visit $visitState){ Fail 'Blockers dependency graph contains a cycle' } }
$tasksHash=(Get-FileHash -LiteralPath $tasks -Algorithm SHA256).Hash.ToLower(); $requirementsHash=(Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower(); $acceptanceHash=(Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower(); $designHash=(Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower()
# WFI-025: a mixed-status plan records the normalized digest (see the helper's
# header); a uniform plan keeps today's raw behaviour byte-for-byte.
$tasksHashForm = 'raw'
if (Test-TasksStatusesMixed $tasks) {
  $tasksHashForm = 'normalized'
  $tasksHash = Get-TasksNormalizedHash $tasks
}
$traceabilityHash = ''
$layerHashes = [ordered]@{}
if ($fullProfile) {
  $traceabilityHash = (Get-FileHash -LiteralPath $traceability -Algorithm SHA256).Hash.ToLower()
  foreach ($name in $layerNames) { $layerHashes[$name] = (Get-FileHash -LiteralPath (Join-Path $spec $name) -Algorithm SHA256).Hash.ToLower() }
  & (Join-Path $PSScriptRoot 'validate-layer-traceability.ps1') -Path $traceability -RequirementsPath $requirements
}
$calibration = Join-Path $root 'plugins/sdd-review-loop/references/reviewer-calibration.md'
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Get-Item -LiteralPath $calibration).LinkType) { Fail 'plugins/sdd-review-loop/references/reviewer-calibration.md not found' }
$calibrationHash = (Get-FileHash -LiteralPath $calibration -Algorithm SHA256).Hash.ToLower()
$specReviewedRequirementsHash = Get-ReviewedHash $requirements 'Spec-Review-Status' 'Pending'
$implReviewedDesignHash = Get-ReviewedHash $design 'Impl-Review-Status' 'Pending'
Require-Pass (Join-Path $root "reports/spec-review/$Feature") 'spec' $Feature $specReviewedRequirementsHash $acceptanceHash '' $requirementsHash ''
Require-Pass (Join-Path $root "reports/impl-review/$Feature") 'impl' $Feature $requirementsHash $acceptanceHash $implReviewedDesignHash $requirementsHash $designHash
$riskScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/check-risk.ps1'
if (-not (Test-Path -LiteralPath $riskScript -PathType Leaf)) { Fail 'shared risk gate is missing' }
& $riskScript -TasksPath $tasks
if ($LASTEXITCODE -ne 0) { Fail 'Risk/Required Workflow mismatches must be fixed before creating evidence' }
# WFI-030 STEP 2b, twin of the awk block in task-review-precheck.sh. Detection
# only: the exit code is unaffected by a non-empty result. Continuation lines
# are joined into whole items before matching, because two of the three known
# real cases put the artifact name and the write verb on different lines.
$fdwLines = [IO.File]::ReadAllLines($tasks)
$fdwItems = @(); $fdwTask = ''; $fdwIn = $false; $fdwCur = $null
for ($fdwI = 0; $fdwI -lt $fdwLines.Count; $fdwI++) {
  $fdwL = $fdwLines[$fdwI]
  if ($fdwL -match '^##\s+(T-\d+)') {
    if ($fdwCur) { $fdwItems += $fdwCur; $fdwCur = $null }
    $fdwTask = $Matches[1]; $fdwIn = $false; continue
  }
  if ($fdwL -match 'Done When') {
    if ($fdwCur) { $fdwItems += $fdwCur; $fdwCur = $null }
    $fdwIn = $true; continue
  }
  if ($fdwL -match '^(##|###)\s' -or $fdwL -match '^[A-Za-z][A-Za-z ]*:') {
    if ($fdwCur) { $fdwItems += $fdwCur; $fdwCur = $null }
    $fdwIn = $false; continue
  }
  if (-not $fdwIn) { continue }
  if ($fdwL -match '^- \[') {
    if ($fdwCur) { $fdwItems += $fdwCur }
    $fdwCur = [ordered]@{ task = $fdwTask; line = ($fdwI + 1); item = $fdwL }; continue
  }
  if ($fdwL -match '^[ \t]+\S') { if ($fdwCur) { $fdwCur.item = $fdwCur.item + ' ' + $fdwL.TrimStart() }; continue }
  if ($fdwCur) { $fdwItems += $fdwCur; $fdwCur = $null }
}
if ($fdwCur) { $fdwItems += $fdwCur }
$frozenDoneWhen = @($fdwItems | Where-Object { $_.item -match '(traceability|design|tasks)\.md' -and $_.item -match '(^|[^a-zA-Z])(record|records|update|updates|add|write|edit|append)([^a-zA-Z]|$)' })
$inputMaterial = if ($fullProfile) {
  $layerJson = $layerHashes | ConvertTo-Json -Compress
  "$tasksHash`:$requirementsHash`:$acceptanceHash`:$designHash`:$traceabilityHash`:$layerJson"
} else {
  "$tasksHash`:$requirementsHash`:$acceptanceHash"
}
$inputHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($inputMaterial))).ToLower()
$base=Join-Path $root 'reports/task-review'; New-Item -ItemType Directory -Path $base -Force | Out-Null; $temporaryContract=[IO.Path]::GetTempFileName()
try { [ordered]@{schema='review-contract/v1';stage='task';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;input_sha256=$inputHash;run_id='task-precheck';verdict='PASS'}|ConvertTo-Json -Compress|Set-Content -LiteralPath $temporaryContract -Encoding utf8NoBOM; & (Join-Path $PSScriptRoot 'review-contract-validate.ps1') -Feature $Feature -Attempt $Attempt -Round $Round -Stage task -ReportRoot (Join-Path $root "reports/task-review/$Feature") -Contract $temporaryContract | Out-Null } finally { Remove-Item -LiteralPath $temporaryContract -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $report | Out-Null
$graph=[ordered]@{schema='dependency-graph/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;nodes=$nodes;edges=$edges;generated_at=[DateTime]::UtcNow.ToString('o')}; $graph|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $report 'dependency-graph.json') -Encoding utf8NoBOM
[ordered]@{schema='task-review-precheck/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;workflow_match_precheck='PASS';blockers_format_valid=$true;tasks_sha256=$tasksHash;tasks_sha256_form=$tasksHashForm;requirements_sha256=$requirementsHash;acceptance_sha256=$acceptanceHash;design_sha256=$designHash;traceability_sha256=$traceabilityHash;frozen_artifact_done_when=$frozenDoneWhen;layer_sha256=$layerHashes;input_sha256=$inputHash;generated_at=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $report 'precheck-result.json') -Encoding utf8NoBOM
Write-Output "task-review-precheck: complete. Output written to $report/"
