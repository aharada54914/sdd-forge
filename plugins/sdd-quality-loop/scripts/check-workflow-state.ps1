# Validate the repository-wide SDD workflow state. Keep rule IDs in parity with Bash.
$ErrorActionPreference = "Stop"

function Stop-WorkflowState([string]$Feature, [string]$Rule, [string]$Message) {
    [Console]::Error.WriteLine("workflow-state: ${Feature}: ${Rule}: ${Message}")
    exit 1
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Get-NormalizedHash([string]$Path, [string]$Stage) {
    $text = [IO.File]::ReadAllText($Path)
    switch ($Stage) {
        "spec" {
            $text = [regex]::Replace(
                $text, "(?m)^Spec-Review-Status:[^\r\n]*(\r?)$", 'Spec-Review-Status: Pending$1')
        }
        "impl" {
            $text = [regex]::Replace(
                $text, "(?m)^Impl-Review-Status:[^\r\n]*(\r?)$", 'Impl-Review-Status: Pending$1')
        }
        "task" {
            $text = [regex]::Replace(
                $text, "(?m)^Task-Review-Status:[^\r\n]*(\r?)$", 'Task-Review-Status: Pending$1')
            $text = [regex]::Replace(
                $text, "(?m)^Approval:[^\r\n]*(\r?)$", 'Approval: Draft$1')
            $text = [regex]::Replace(
                $text, "(?m)^Status:[^\r\n]*(\r?)$", 'Status: Planned$1')
        }
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-Header([string]$Path, [string]$Header) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $match = [regex]::Match([IO.File]::ReadAllText($Path), "(?m)^$([regex]::Escape($Header)):\s*(\S+)")
    if ($match.Success) { return $match.Groups[1].Value.TrimEnd("`r") }
    return ""
}
function Get-RepositoryRelativePath([string]$Path, [string]$RepositoryRoot) {
    $normalizedPath = $Path.Replace("\", "/")
    $normalizedRoot = $RepositoryRoot.Replace("\", "/").TrimEnd("/")
    $roots = @($normalizedRoot)
    if ($normalizedRoot.StartsWith("/private/var/")) {
        $roots += "/var/" + $normalizedRoot.Substring("/private/var/".Length)
    } elseif ($normalizedRoot.StartsWith("/var/")) {
        $roots += "/private/var/" + $normalizedRoot.Substring("/var/".Length)
    }
    if (-not [IO.Path]::IsPathRooted($Path)) { return $normalizedPath }
    foreach ($root in $roots) {
        if ($normalizedPath.StartsWith("$root/", [StringComparison]::OrdinalIgnoreCase)) {
            return $normalizedPath.Substring($root.Length + 1)
        }
    }
    return $null
}
function Test-ManifestHash(
    $Contract, [string]$Suffix, [string]$Expected, [string]$RepositoryRoot
) {
    $target = $Suffix.TrimStart("/")
    foreach ($reviewer in @($Contract.reviewers)) {
        $found = $false
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $path = Get-RepositoryRelativePath ([string]$item.path) $RepositoryRoot
            if ($null -ne $path -and $path -ceq $target -and
                [string]$item.sha256 -eq $Expected) {
                $found = $true
                break
            }
        }
        if (-not $found) { return $false }
    }
    return @($Contract.reviewers).Count -gt 0
}
function Test-ManifestPaths(
    $Contract, [string]$Feature, [string]$Stage, [int]$Attempt, [int]$Round,
    [string]$RepositoryRoot
) {
    $attemptRoot = "reports/$Stage-review/$Feature/attempt-$Attempt"
    $roundRoot = "$attemptRoot/round-$Round"
    foreach ($reviewer in @($Contract.reviewers)) {
        $role = [string]$reviewer.role
        $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($path in @(
            "specs/$Feature/requirements.md",
            "specs/$Feature/acceptance-tests.md",
            "specs/$Feature/investigation.md",
            "$roundRoot/precheck-result.json"
        )) { [void]$allowed.Add($path) }
        if ($Stage -eq "spec") {
            [void]$allowed.Add("plugins/sdd-review-loop/references/spec-review-calibration.md")
        } else {
            [void]$allowed.Add("plugins/sdd-review-loop/references/reviewer-calibration.md")
        }
        if ($Stage -eq "impl") { [void]$allowed.Add("specs/$Feature/design.md") }
        if ($Stage -eq "task") {
            [void]$allowed.Add("specs/$Feature/tasks.md")
            [void]$allowed.Add("specs/$Feature/traceability.md")
        }
        if ($role -eq "$Stage-reviewer-b") { [void]$allowed.Add("$roundRoot/integrated-summary.json") }
        if ($Stage -eq "impl" -and $role -eq "impl-reviewer-a" -and $Round -gt 1) {
            [void]$allowed.Add("$attemptRoot/round-$($Round - 1)/integrated-summary.json")
        }
        if ($Stage -eq "task" -and $role -eq "task-reviewer-a") {
            [void]$allowed.Add("$roundRoot/dependency-graph.json")
        }
        if ($Stage -eq "task" -and $role -eq "task-reviewer-b") {
            [void]$allowed.Add("plugins/sdd-quality-loop/references/risk-gate-matrix.md")
            [void]$allowed.Add("plugins/sdd-quality-loop/references/risk-classification-policy.md")
        }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $path = Get-RepositoryRelativePath ([string]$item.path) $RepositoryRoot
            if ($null -eq $path) { return $false }
            if ($path -match "(^|/)\.\.?(/|$)" -or -not $allowed.Contains($path) -or
                -not $seen.Add($path)) { return $false }
        }
    }
    return $true
}

$ScriptRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
$Registry = Join-Path $ScriptRoot "specs/workflow-state-registry.json"
$FeatureFilter = ""
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ([string]$args[$i]) {
        "--feature" {
            if (++$i -ge $args.Count) { Stop-WorkflowState "repository" "cli-usage" "--feature requires a value" }
            $FeatureFilter = [string]$args[$i]
        }
        "--registry" {
            if (++$i -ge $args.Count) { Stop-WorkflowState "repository" "cli-usage" "--registry requires a value" }
            $Registry = [string]$args[$i]
        }
        default { Stop-WorkflowState "repository" "cli-usage" "unknown argument: $($args[$i])" }
    }
}
if ($FeatureFilter -and $FeatureFilter -notmatch "^[a-z0-9][a-z0-9-]*$") {
    Stop-WorkflowState $FeatureFilter "cli-usage" "invalid feature slug"
}
if (-not (Test-Path -LiteralPath $Registry -PathType Leaf) -or
    (Get-Item -LiteralPath $Registry -Force).LinkType) {
    Stop-WorkflowState "repository" "registry-unreadable" "registry is missing, linked, or unreadable"
}
try { $RegistryText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Registry).Path) }
catch { Stop-WorkflowState "repository" "registry-unreadable" "registry is missing, linked, or unreadable" }
try { $RegistryData = $RegistryText | ConvertFrom-Json }
catch { Stop-WorkflowState "repository" "registry-malformed" "registry is not valid JSON" }
if ($RegistryData.schema_version -ne 1 -or -not @($RegistryData.entries).Count) {
    Stop-WorkflowState "repository" "registry-malformed" "registry shape or version is invalid"
}
foreach ($entry in @($RegistryData.entries)) {
    if ([string]$entry.feature -notmatch "^[a-z0-9][a-z0-9-]*$" -or
        [string]$entry.profile -notin @("full", "lite", "legacy")) {
        Stop-WorkflowState "repository" "registry-malformed" "registry shape or version is invalid"
    }
}
$Schema = Join-Path $ScriptRoot "contracts/workflow-state-registry.schema.json"
if (-not (Test-Path -LiteralPath $Schema -PathType Leaf)) {
    Stop-WorkflowState "repository" "registry-schema" "registry schema is unavailable"
}
try {
    $schemaOk = Test-Json -Json $RegistryText -SchemaFile $Schema -ErrorAction Stop
} catch {
    $schemaOk = $false
}
if (-not $schemaOk) {
    Stop-WorkflowState "repository" "registry-schema" "registry entry violates the bounded schema"
}

$SpecsRoot = (Resolve-Path (Split-Path -Parent $Registry)).Path
$RepoRoot = (Resolve-Path (Join-Path $SpecsRoot "..")).Path
$duplicate = @($RegistryData.entries | Group-Object feature | Where-Object Count -gt 1 | Select-Object -First 1)
if ($duplicate) { Stop-WorkflowState $duplicate[0].Name "registry-duplicate" "feature is registered more than once" }
$declared = @{}
foreach ($entry in @($RegistryData.entries)) {
    $feature = [string]$entry.feature
    $declared[$feature] = $true
    $candidate = Join-Path $SpecsRoot $feature
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        Stop-WorkflowState $feature "registry-dangling-entry" "registered specification directory is missing"
    }
    $item = Get-Item -LiteralPath $candidate -Force
    if ($item.LinkType) {
        $target = [string]$item.Target
        if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $item.Parent.FullName $target }
        $resolved = [IO.Path]::GetFullPath($target)
    } else {
        $resolved = (Resolve-Path -LiteralPath $candidate).Path
    }
    $prefix = $SpecsRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not ($resolved + [IO.Path]::DirectorySeparatorChar).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-WorkflowState $feature "registry-path-escape" "registered directory escapes specs root"
    }
    if ($item.LinkType) {
        Stop-WorkflowState $feature "registry-linked-entry" "registered specification directory must not be linked"
    }
}
foreach ($directory in @(Get-ChildItem -LiteralPath $SpecsRoot -Directory -Force)) {
    if (-not $declared.ContainsKey($directory.Name)) {
        Stop-WorkflowState $directory.Name "registry-unregistered-directory" "specification directory is not registered"
    }
}
if ($FeatureFilter -and -not $declared.ContainsKey($FeatureFilter)) {
    Stop-WorkflowState $FeatureFilter "registry-unknown-feature" "feature is not registered"
}

function Test-PassedStage([string]$Feature, [string]$Stage, [string]$FeatureDir) {
    $root = Join-Path $RepoRoot "reports/$Stage-review/$Feature"
    if (-not (Test-Path -LiteralPath $root -PathType Container) -or (Get-Item $root -Force).LinkType) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage PASS has no review report root"
    }
    $candidates = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter integrated-verdict.json -Recurse -Force)) {
        if ($file.LinkType -or -not (Test-Path -LiteralPath $file.FullName -PathType Leaf)) {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage verdict evidence is linked or unreadable"
        }
        $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace("\", "/")
        if ($relative -notmatch "^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/integrated-verdict\.json$") {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage verdict has a noncanonical path"
        }
        $candidates += [pscustomobject]@{ File=$file; Attempt=[int]$Matches[1]; Round=[int]$Matches[2] }
    }
    $latest = $candidates | Sort-Object Attempt, Round -Descending | Select-Object -First 1
    if (-not $latest) { Stop-WorkflowState $Feature "stage-provenance" "$Stage PASS has no integrated verdict" }
    $contractPath = Join-Path $latest.File.DirectoryName "$Stage-review-contract.json"
    if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf) -or (Get-Item $contractPath -Force).LinkType) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage PASS has no readable review contract"
    }
    try {
        $verdict = Get-Content -LiteralPath $latest.File.FullName -Raw | ConvertFrom-Json
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    } catch { Stop-WorkflowState $Feature "stage-provenance" "$Stage review evidence is malformed" }
    $reviewerAPath = Join-Path $latest.File.DirectoryName "reviewer-a.json"
    $reviewerBPath = Join-Path $latest.File.DirectoryName "reviewer-b.json"
    $summaryPath = Join-Path $latest.File.DirectoryName "integrated-summary.json"
    foreach ($evidencePath in @($reviewerAPath, $reviewerBPath, $summaryPath)) {
        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf) -or
            (Get-Item -LiteralPath $evidencePath -Force).LinkType) {
            Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer evidence is missing, linked, or unreadable"
        }
    }
    try {
        $reviewerA = Get-Content -LiteralPath $reviewerAPath -Raw | ConvertFrom-Json
        $reviewerB = Get-Content -LiteralPath $reviewerBPath -Raw | ConvertFrom-Json
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    } catch { Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer evidence is malformed" }
    $identityOk = [string]$verdict.feature -eq $Feature -and [string]$verdict.stage -eq $Stage -and
        [int]$verdict.attempt -eq $latest.Attempt -and [int]$verdict.round -eq $latest.Round -and
        ([string]$verdict.verdict -eq "PASS" -or
         ($Stage -ne "spec" -and [string]$verdict.verdict -eq "PASS-with-warnings"))
    if ($Stage -eq "spec") {
        $identityOk = $identityOk -and [string]$verdict.schema -eq "spec-review-integrated-verdict/v1" -and
            $verdict.reviewer_a_run_id -and $verdict.reviewer_b_run_id -and
            $verdict.reviewer_a_host_session_id -and $verdict.reviewer_b_host_session_id -and
            $verdict.reviewer_a_run_id -ne $verdict.reviewer_b_run_id -and
            $verdict.reviewer_a_host_session_id -ne $verdict.reviewer_b_host_session_id
    } else {
        $identityOk = $identityOk -and [string]$verdict.schema -eq "integrated-verdict/v1" -and
            -not [string]::IsNullOrWhiteSpace([string]$verdict.run_id) -and
            [string]$verdict.reviewer_a_verdict -in @("PASS", "NEEDS_WORK") -and
            [string]$verdict.reviewer_b_verdict -in @("PASS", "NEEDS_WORK") -and
            [int]$verdict.findings_critical -eq 0 -and [int]$verdict.findings_major -eq 0
    }
    if (-not $identityOk) { Stop-WorkflowState $Feature "stage-provenance" "$Stage integrated verdict is not a valid PASS" }
    $roles = @($contract.reviewers | ForEach-Object { [string]$_.role } | Sort-Object)
    $runs = @($contract.reviewers | ForEach-Object { [string]$_.run_id } | Sort-Object -Unique)
    $hosts = @($contract.reviewers | ForEach-Object { [string]$_.host_session_id } | Sort-Object -Unique)
    $contractOk = [string]$contract.schema -eq "$Stage-review-contract/v1" -and
        [string]$contract.feature -eq $Feature -and [string]$contract.stage -eq $Stage -and
        [int]$contract.attempt -eq $latest.Attempt -and [int]$contract.round -eq $latest.Round -and
        ([string]$contract.verdict -eq "PASS" -or
         ($Stage -ne "spec" -and [string]$contract.verdict -eq "PASS-with-warnings")) -and
        -not [string]::IsNullOrWhiteSpace([string]$contract.run_id) -and
        ($Stage -eq "spec" -or (
            [string]$contract.reviewer_a_verdict -in @("PASS", "NEEDS_WORK") -and
            [string]$contract.reviewer_b_verdict -in @("PASS", "NEEDS_WORK") -and
            [int]$contract.findings_critical -eq 0 -and [int]$contract.findings_major -eq 0)) -and
        ($roles -join ",") -eq "$Stage-reviewer-a,$Stage-reviewer-b" -and
        $runs.Count -eq 2 -and $hosts.Count -eq 2 -and -not ($runs -contains "") -and -not ($hosts -contains "")
    if (-not $contractOk) { Stop-WorkflowState $Feature "stage-provenance" "$Stage review contract identity is invalid" }
    if (-not (Test-ManifestPaths $contract $Feature $Stage $latest.Attempt $latest.Round $RepoRoot)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest paths are not canonical"
    }
    $statusNeutral = @(
        "specs/$Feature/requirements.md",
        "specs/$Feature/design.md",
        "specs/$Feature/tasks.md",
        "specs/$Feature/traceability.md",
        "specs/$Feature/acceptance-tests.md"
    )
    foreach ($reviewer in @($contract.reviewers)) {
        foreach ($item in @($reviewer.allowed_input_manifest)) {
            $manifestPath = [string]$item.path
            $manifestRelative = Get-RepositoryRelativePath $manifestPath $RepoRoot
            if ($null -eq $manifestRelative) {
                Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest path escapes repository"
            }
            $manifestFile = Join-Path $RepoRoot $manifestRelative
            if ($statusNeutral -contains $manifestRelative) { continue }
            if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf) -or
                (Get-Item -LiteralPath $manifestFile -Force).LinkType) {
                Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest input is missing or unreadable"
            }
            if ((Get-Sha256 $manifestFile) -ne [string]$item.sha256) {
                Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifest input hash is stale"
            }
        }
    }
    if ($Stage -eq "spec") {
        $map = @{}; foreach ($r in $contract.reviewers) { $map[[string]$r.role] = $r }
        $linked = $map["spec-reviewer-a"].run_id -eq $verdict.reviewer_a_run_id -and
            $map["spec-reviewer-b"].run_id -eq $verdict.reviewer_b_run_id -and
            $map["spec-reviewer-a"].host_session_id -eq $verdict.reviewer_a_host_session_id -and
            $map["spec-reviewer-b"].host_session_id -eq $verdict.reviewer_b_host_session_id
    } else { $linked = [string]$contract.run_id -eq [string]$verdict.run_id }
    if (-not $linked) { Stop-WorkflowState $Feature "stage-provenance" "$Stage contract and verdict contradict each other" }

    $reviewerMap = @{}
    foreach ($entry in @($contract.reviewers)) { $reviewerMap[[string]$entry.role] = $entry }
    if ($Stage -eq "task") {
        $reviewerIdentityOk =
            [string]$reviewerA.schema -eq "task-reviewer-a/v1" -and
            [string]$reviewerA.stage -eq "task-review" -and [string]$reviewerA.role -eq "reviewer-a" -and
            [string]$reviewerB.schema -eq "task-reviewer-b/v1" -and
            [string]$reviewerB.stage -eq "task" -and [string]$reviewerB.role -eq "task-reviewer-b" -and
            [string]$reviewerA.feature -eq $Feature -and [string]$reviewerB.feature -eq $Feature -and
            [int]$reviewerA.attempt -eq $latest.Attempt -and [int]$reviewerB.attempt -eq $latest.Attempt -and
            [int]$reviewerA.round -eq $latest.Round -and [int]$reviewerB.round -eq $latest.Round
        $manifestA = @($reviewerA.manifest)
        $manifestB = @($reviewerB.manifest.allowed_inputs)
        $resultProperty = "status"
    } else {
        $reviewerIdentityOk =
            [string]$reviewerA.schema -eq "$Stage-reviewer-a/v1" -and
            [string]$reviewerA.stage -eq $Stage -and [string]$reviewerA.role -eq "$Stage-reviewer-a" -and
            [string]$reviewerB.schema -eq "$Stage-reviewer-b/v1" -and
            [string]$reviewerB.stage -eq $Stage -and [string]$reviewerB.role -eq "$Stage-reviewer-b"
        $manifestA = @($reviewerA.allowed_input_manifest)
        $manifestB = @($reviewerB.allowed_input_manifest)
        $resultProperty = "result"
    }
    $contractA = $reviewerMap["$Stage-reviewer-a"]
    $contractB = $reviewerMap["$Stage-reviewer-b"]
    $reviewerIdentityOk = $reviewerIdentityOk -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerA.run_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerA.host_session_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerB.run_id) -and
        -not [string]::IsNullOrWhiteSpace([string]$reviewerB.host_session_id) -and
        [string]$reviewerA.run_id -eq [string]$contractA.run_id -and
        [string]$reviewerA.host_session_id -eq [string]$contractA.host_session_id -and
        [string]$reviewerB.run_id -eq [string]$contractB.run_id -and
        [string]$reviewerB.host_session_id -eq [string]$contractB.host_session_id
    $canonicalManifestA = @($manifestA | ForEach-Object {
        "$([string]$_.path)`t$([string]$_.sha256)"
    } | Sort-Object)
    $canonicalManifestB = @($manifestB | ForEach-Object {
        "$([string]$_.path)`t$([string]$_.sha256)"
    } | Sort-Object)
    $canonicalContractA = @($contractA.allowed_input_manifest | ForEach-Object {
        "$([string]$_.path)`t$([string]$_.sha256)"
    } | Sort-Object)
    $canonicalContractB = @($contractB.allowed_input_manifest | ForEach-Object {
        "$([string]$_.path)`t$([string]$_.sha256)"
    } | Sort-Object)
    $reviewerIdentityOk = $reviewerIdentityOk -and
        (($canonicalManifestA -join "`n") -ceq ($canonicalContractA -join "`n")) -and
        (($canonicalManifestB -join "`n") -ceq ($canonicalContractB -join "`n"))
    $failedA = @($reviewerA.checks | Where-Object { [string]$_.$resultProperty -eq "FAIL" })
    $reviewerBResultProperty = if ($Stage -eq "task") { "result" } else { $resultProperty }
    $failedB = @($reviewerB.checks | Where-Object {
        [string]$_.$reviewerBResultProperty -eq "FAIL"
    })
    if ($Stage -eq "task") {
        $findingsA = @($reviewerA.findings)
        $findingsB = @($reviewerB.findings)
        $reviewerIdentityOk = $reviewerIdentityOk -and
            $failedA.Count -eq $findingsA.Count -and $failedB.Count -eq $findingsB.Count
    } else {
        $findingsA = $failedA
        $findingsB = $failedB
    }
    $expectedVerdictA = if (@($findingsA | Where-Object severity -eq "Critical").Count) {
        "BLOCKED"
    } elseif ($findingsA.Count) { "NEEDS_WORK" } else { "PASS" }
    $expectedVerdictB = if (@($findingsB | Where-Object severity -eq "Critical").Count) {
        "BLOCKED"
    } elseif ($findingsB.Count) { "NEEDS_WORK" } else { "PASS" }
    $reviewerIdentityOk = $reviewerIdentityOk -and
        [string]$reviewerA.verdict -eq $expectedVerdictA -and
        [string]$reviewerB.verdict -eq $expectedVerdictB
    $summaryIds = if ($Stage -eq "spec") {
        @($summary.reviewer_a_checks | ForEach-Object { [string]$_.id } | Sort-Object)
    } else { @($summary.reviewer_a_check_ids | ForEach-Object { [string]$_ } | Sort-Object) }
    $reviewerAIds = @($reviewerA.checks | ForEach-Object { [string]$_.id } | Sort-Object)
    $summaryOk = [string]$summary.schema -eq "integrated-summary/v1" -and
        [int]$summary.attempt -eq $latest.Attempt -and [int]$summary.round -eq $latest.Round -and
        (($summaryIds -join "`n") -ceq ($reviewerAIds -join "`n")) -and
        [int]$summary.reviewer_a_fail_count -eq $failedA.Count -and
        [int]$summary.reviewer_a_pass_count -eq
            @($reviewerA.checks | Where-Object { [string]$_.$resultProperty -eq "PASS" }).Count -and
        [int]$summary.reviewer_a_skip_count -eq
            @($reviewerA.checks | Where-Object { [string]$_.$resultProperty -eq "SKIP" }).Count
    $allFindings = @($findingsA) + @($findingsB)
    $criticalCount = @($allFindings | Where-Object severity -eq "Critical").Count
    $majorCount = @($allFindings | Where-Object severity -eq "Major").Count
    $minorCount = @($allFindings | Where-Object severity -eq "Minor").Count
    $severityCount = $criticalCount + $majorCount + $minorCount
    $finalEvidenceOk = $severityCount -eq $allFindings.Count -and
        $criticalCount -eq 0 -and $majorCount -eq 0 -and
        ($minorCount -eq 0 -or $latest.Round -eq 3)
    if ($Stage -eq "spec") {
        $finalEvidenceOk = $finalEvidenceOk -and
            [string]$contract.verdict -eq "PASS" -and [string]$verdict.verdict -eq "PASS" -and
            [int]$contract.warningCount -eq $minorCount -and
            [int]$verdict.warningCount -eq $minorCount -and
            [int]$verdict.finding_counts.critical -eq $criticalCount -and
            [int]$verdict.finding_counts.major -eq $majorCount -and
            [int]$verdict.finding_counts.minor -eq $minorCount
    } else {
        $expectedFinalVerdict = if ($minorCount) { "PASS-with-warnings" } else { "PASS" }
        $finalEvidenceOk = $finalEvidenceOk -and
            [string]$contract.verdict -eq $expectedFinalVerdict -and
            [string]$verdict.verdict -eq $expectedFinalVerdict -and
            [int]$contract.findings_critical -eq $criticalCount -and
            [int]$contract.findings_major -eq $majorCount -and
            [int]$contract.findings_minor -eq $minorCount -and
            [int]$verdict.findings_critical -eq $criticalCount -and
            [int]$verdict.findings_major -eq $majorCount -and
            [int]$verdict.findings_minor -eq $minorCount -and
            [string]$contract.reviewer_a_verdict -eq [string]$reviewerA.verdict -and
            [string]$contract.reviewer_b_verdict -eq [string]$reviewerB.verdict -and
            [string]$verdict.reviewer_a_verdict -eq [string]$reviewerA.verdict -and
            [string]$verdict.reviewer_b_verdict -eq [string]$reviewerB.verdict
    }
    if (-not $reviewerIdentityOk -or -not $summaryOk -or -not $finalEvidenceOk) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer outputs or integrated summary contradict the final PASS"
    }

    $requirements = Join-Path $FeatureDir "requirements.md"
    $acceptance = Join-Path $FeatureDir "acceptance-tests.md"
    if (-not (Test-Path $requirements -PathType Leaf) -or -not (Test-Path $acceptance -PathType Leaf)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage canonical inputs are missing"
    }
    if ($Stage -eq "spec") { $reqHash = Get-NormalizedHash $requirements "spec" }
    else { $reqHash = Get-Sha256 $requirements }
    if ([string]$contract.requirements_sha256 -ne $reqHash -or
        [string]$contract.acceptance_sha256 -ne (Get-Sha256 $acceptance)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage top-level contract hashes are stale"
    }
    if (-not (Test-ManifestHash $contract "/specs/$Feature/requirements.md" $reqHash $RepoRoot) -or
        -not (Test-ManifestHash $contract "/specs/$Feature/acceptance-tests.md" (Get-Sha256 $acceptance) $RepoRoot)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage contract hashes are stale"
    }
    $calibrationRelative = if ($Stage -eq "spec") {
        "plugins/sdd-review-loop/references/spec-review-calibration.md"
    } else {
        "plugins/sdd-review-loop/references/reviewer-calibration.md"
    }
    $calibration = Join-Path $RepoRoot $calibrationRelative
    $precheckRelative = "reports/$Stage-review/$Feature/attempt-$($latest.Attempt)/round-$($latest.Round)/precheck-result.json"
    $precheck = Join-Path $RepoRoot $precheckRelative
    if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or
        (Get-Item -LiteralPath $calibration -Force).LinkType -or
        -not (Test-Path -LiteralPath $precheck -PathType Leaf) -or
        (Get-Item -LiteralPath $precheck -Force).LinkType) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage required review inputs are missing"
    }
    if (-not (Test-ManifestHash $contract "/$calibrationRelative" (Get-Sha256 $calibration) $RepoRoot) -or
        -not (Test-ManifestHash $contract "/$precheckRelative" (Get-Sha256 $precheck) $RepoRoot)) {
        Stop-WorkflowState $Feature "stage-provenance" "$Stage reviewer manifests omit required inputs"
    }
    if ($Stage -eq "impl") {
        $design = Join-Path $FeatureDir "design.md"
        $designHash = Get-NormalizedHash $design "impl"
        if (-not (Test-ManifestHash $contract "/specs/$Feature/design.md" $designHash $RepoRoot)) {
            Stop-WorkflowState $Feature "stage-provenance" "implementation design hash is stale"
        }
        if ([string]$contract.design_sha256 -ne $designHash) {
            Stop-WorkflowState $Feature "stage-provenance" "implementation top-level design hash is stale"
        }
    } elseif ($Stage -eq "task") {
        $tasks = Join-Path $FeatureDir "tasks.md"
        $tasksHash = Get-NormalizedHash $tasks "task"
        if (-not (Test-ManifestHash $contract "/specs/$Feature/tasks.md" $tasksHash $RepoRoot)) {
            Stop-WorkflowState $Feature "stage-provenance" "task plan hash is stale"
        }
        if ([string]$contract.tasks_sha256 -ne $tasksHash) {
            Stop-WorkflowState $Feature "stage-provenance" "task top-level plan hash is stale"
        }
    }
}

function Test-Legacy([string]$Feature, [string]$Directory, $Entry) {
    $stages = @(
        @("spec", "requirements.md", "Spec-Review-Status", "spec_status"),
        @("impl", "design.md", "Impl-Review-Status", "impl_status"),
        @("task", "tasks.md", "Task-Review-Status", "task_status")
    )
    foreach ($stage in $stages) {
        $value = Get-Header (Join-Path $Directory $stage[1]) $stage[2]
        if (-not $value) {
            if (@($Entry.legacy.allowed_missing_stages) -notcontains $stage[0]) {
                Stop-WorkflowState $Feature "legacy-state" "missing $($stage[0]) status is not declared"
            }
        } else {
            $allowed = @($Entry.legacy.allowed_noncanonical_statuses.($stage[3]))
            if ($allowed -notcontains $value) {
                Stop-WorkflowState $Feature "legacy-state" "$($stage[0]) status is broader than the migration record"
            }
        }
    }
    $tasks = Join-Path $Directory "tasks.md"
    if (Test-Path $tasks -PathType Leaf) {
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($tasks), "(?m)^Approval:\s*([^\r\n(]+)")) {
            if (@($Entry.legacy.allowed_task_approvals) -notcontains $match.Groups[1].Value.Trim()) {
                Stop-WorkflowState $Feature "legacy-state" "task approval is broader than the migration record"
            }
        }
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($tasks), "(?m)^Status:\s*([^\r\n]+)")) {
            if (@($Entry.legacy.allowed_task_statuses) -notcontains $match.Groups[1].Value.Trim()) {
                Stop-WorkflowState $Feature "legacy-state" "task lifecycle is broader than the migration record"
            }
        }
    }
}

foreach ($entry in @($RegistryData.entries)) {
    $feature = [string]$entry.feature
    if ($FeatureFilter -and $feature -ne $FeatureFilter) { continue }
    $profile = [string]$entry.profile
    $directory = Join-Path $SpecsRoot $feature
    if ($profile -eq "lite") { continue }
    if ($profile -eq "legacy") { Test-Legacy $feature $directory $entry; continue }
    foreach ($required in @("requirements.md", "design.md", "acceptance-tests.md")) {
        $path = Join-Path $directory $required
        if (-not (Test-Path $path -PathType Leaf) -or (Get-Item $path -Force).LinkType) {
            Stop-WorkflowState $feature "stage-input" "$required is missing, linked, or unreadable"
        }
    }
    $spec = Get-Header (Join-Path $directory "requirements.md") "Spec-Review-Status"
    $impl = Get-Header (Join-Path $directory "design.md") "Impl-Review-Status"
    $tasks = Join-Path $directory "tasks.md"
    $taskItem = Get-Item -LiteralPath $tasks -Force -ErrorAction SilentlyContinue
    if ($taskItem -and ($taskItem.LinkType -or -not (Test-Path -LiteralPath $tasks -PathType Leaf))) {
        Stop-WorkflowState $feature "stage-input" "tasks.md is linked or unreadable"
    }
    $task = Get-Header $tasks "Task-Review-Status"
    if ($taskItem -and -not $task) { Stop-WorkflowState $feature "stage-status" "tasks.md has no Task-Review-Status" }
    if ($spec -notin @("Pending", "Passed")) { Stop-WorkflowState $feature "stage-status" "Spec status is missing or invalid" }
    if ($impl -notin @("Pending", "Passed")) { Stop-WorkflowState $feature "stage-status" "Impl status is missing or invalid" }
    if ($task -and $task -notin @("Pending", "Passed")) { Stop-WorkflowState $feature "stage-status" "Task status is invalid" }
    if ($impl -eq "Passed" -and $spec -ne "Passed") { Stop-WorkflowState $feature "stage-order" "Impl Passed requires Spec Passed" }
    if ($task -eq "Passed" -and ($spec -ne "Passed" -or $impl -ne "Passed")) {
        Stop-WorkflowState $feature "stage-order" "Task Passed requires Spec and Impl Passed"
    }
    if ((Test-Path $tasks -PathType Leaf) -and ($spec -ne "Passed" -or $impl -ne "Passed")) {
        Stop-WorkflowState $feature "task-lifecycle" "tasks.md requires Spec and Impl Passed"
    }
    if (Test-Path $tasks -PathType Leaf) {
        $taskText = [IO.File]::ReadAllText($tasks)
        $approvals = @([regex]::Matches($taskText, "(?m)^Approval:\s*([^\r\n]+)") |
            ForEach-Object { $_.Groups[1].Value.Trim() })
        $statuses = @([regex]::Matches($taskText, "(?m)^Status:\s*([^\r\n]+)") |
            ForEach-Object { $_.Groups[1].Value.Trim() })
        foreach ($approval in $approvals) {
            if ($approval -ne "Draft" -and $approval -notmatch "^Approved(?:\s+\([^)]*\))?$") {
                Stop-WorkflowState $feature "task-lifecycle" "task approval is invalid"
            }
        }
        foreach ($status in $statuses) {
            if ($status -notin @("Planned", "In Progress", "Implementation Complete", "Done")) {
                Stop-WorkflowState $feature "task-lifecycle" "task status is invalid"
            }
        }
        if ($approvals.Count -eq 0 -or $approvals.Count -ne $statuses.Count) {
            Stop-WorkflowState $feature "task-lifecycle" "task lifecycle fields are incomplete"
        }
        if ($task -eq "Pending") {
            foreach ($match in [regex]::Matches($taskText, "(?m)^Approval:\s*([^\r\n]+)")) {
                if ($match.Groups[1].Value.Trim() -ne "Draft") {
                    Stop-WorkflowState $feature "task-lifecycle" "pending task review permits only Draft approvals"
                }
            }
            foreach ($match in [regex]::Matches($taskText, "(?m)^Status:\s*([^\r\n]+)")) {
                if ($match.Groups[1].Value.Trim() -ne "Planned") {
                    Stop-WorkflowState $feature "task-lifecycle" "pending task review permits only Planned statuses"
                }
            }
        }
        if (($taskText -match "(?m)^Approval:\s*Approved" -or
             $taskText -match "(?m)^Status:\s*(In Progress|Implementation Complete|Done)") -and
            ($spec -ne "Passed" -or $impl -ne "Passed" -or $task -ne "Passed")) {
            Stop-WorkflowState $feature "task-lifecycle" "executable task state requires all reviews Passed"
        }
    }
    if ($spec -eq "Passed") { Test-PassedStage $feature "spec" $directory }
    if ($impl -eq "Passed") { Test-PassedStage $feature "impl" $directory }
    if ($task -eq "Passed") { Test-PassedStage $feature "task" $directory }
}

Write-Output "workflow-state: ok"
exit 0
