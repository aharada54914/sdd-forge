# WFI-045 deterministic gate (PowerShell twin of check-criterion-freeze.py).
# A commit may not rewrite frozen criterion prose in a reviewed tasks.md while
# also changing files outside specs/.
# Usage: check-criterion-freeze.ps1 -Commit <ref> -RepoRoot <path>
# Exit 0 = ok, 1 = criterion-prose edit in a mixed commit, 2 = runtime error.
#
# Diagnostics are byte-identical to the python implementation; the twins are
# pinned against each other in tests/criterion-freeze.tests.sh.
param(
    [string]$Commit = "HEAD",
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$GitArgs, [switch]$AllowFail)
    $out = & git -C $RepoRoot @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFail) { return $null }
        [Console]::Error.WriteLine(
            "check-criterion-freeze: git $($GitArgs -join ' ') failed: $out")
        exit 2
    }
    return ($out -join "`n")
}

function ConvertTo-NormalizedLines {
    param([string]$Text)
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($raw in ($Text -split "`n")) {
        $line = $raw -replace "`r$", ""
        if ($line.StartsWith("Second Approval:")) { continue }
        if ($line.StartsWith("Task-Review-Status:")) {
            $result.Add("Task-Review-Status: Pending"); continue
        }
        if ($line.StartsWith("Approval:")) { $result.Add("Approval: Draft"); continue }
        if ($line.StartsWith("Status:")) { $result.Add("Status: Planned"); continue }
        $result.Add([regex]::Replace($line, '^(\s*)- \[[ xX]\]', '${1}- [ ]'))
    }
    return $result
}

function Split-TaskBlocks {
    param([System.Collections.Generic.List[string]]$Lines)
    $blocks = [ordered]@{}
    $current = ""
    $blocks[$current] = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        $m = [regex]::Match($line, '^## (T-[0-9]{3})\b')
        if ($m.Success) {
            $current = $m.Groups[1].Value
            if (-not $blocks.Contains($current)) {
                $blocks[$current] = New-Object System.Collections.Generic.List[string]
            }
        }
        $blocks[$current].Add($line)
    }
    return $blocks
}

if ($null -eq (Invoke-Git -GitArgs @("rev-parse", "--verify", "--quiet", "$Commit^{commit}") -AllowFail)) {
    [Console]::Error.WriteLine("check-criterion-freeze: not a commit: $Commit")
    exit 2
}

$short = $Commit
$resolved = Invoke-Git -GitArgs @("rev-parse", $Commit)
if ($resolved) { $short = $resolved.Trim().Substring(0, 12) }

$parents = (Invoke-Git -GitArgs @("rev-list", "--parents", "-n", "1", $Commit)) -split '\s+' |
    Where-Object { $_ -ne "" }
if ($parents.Count -lt 2) {
    Write-Output "check-criterion-freeze: $short has no parent; nothing to compare"
    exit 0
}
$parent = $parents[1]

$changed = @((Invoke-Git -GitArgs @("diff", "--name-only", $parent, $Commit)) -split "`n" |
    Where-Object { $_ -ne "" })
if ($changed.Count -eq 0) {
    Write-Output "check-criterion-freeze: $short changes no files"
    exit 0
}

$outside = @($changed | Where-Object { -not $_.StartsWith("specs/") })
if ($outside.Count -eq 0) {
    Write-Output "check-criterion-freeze: $short is specs-only; criterion edits are reviewable on their own"
    exit 0
}

$tasksFiles = @($changed | Where-Object { $_ -cmatch '^specs/[^/]+/tasks\.md$' })
if ($tasksFiles.Count -eq 0) {
    Write-Output "check-criterion-freeze: $short touches no reviewed tasks.md"
    exit 0
}

$violations = New-Object System.Collections.Generic.List[object]
foreach ($path in $tasksFiles) {
    $after = Invoke-Git -GitArgs @("show", "${Commit}:${path}") -AllowFail
    $before = Invoke-Git -GitArgs @("show", "${parent}:${path}") -AllowFail
    if ($null -eq $after -or $null -eq $before) { continue }
    if ($after -cnotmatch '(?m)^Task-Review-Status:[ \t]*Passed[ \t]*\r?$') { continue }

    $beforeBlocks = Split-TaskBlocks (ConvertTo-NormalizedLines $before)
    $afterBlocks = Split-TaskBlocks (ConvertTo-NormalizedLines $after)
    $keys = @($beforeBlocks.Keys) + @($afterBlocks.Keys) | Sort-Object -Unique
    foreach ($key in $keys) {
        $b = if ($beforeBlocks.Contains($key)) { ($beforeBlocks[$key] -join "`n") } else { $null }
        $a = if ($afterBlocks.Contains($key)) { ($afterBlocks[$key] -join "`n") } else { $null }
        if ($b -cne $a) {
            $label = if ($key -eq "") { "(file preamble)" } else { $key }
            $violations.Add([pscustomobject]@{ Path = $path; Key = $label })
        }
    }
}

if ($violations.Count -gt 0) {
    [Console]::Error.WriteLine(
        "check-criterion-freeze: commit $short changes $($outside.Count) file(s) outside specs/ AND rewrites frozen criterion prose:")
    foreach ($v in $violations) {
        [Console]::Error.WriteLine("  - $($v.Path): $($v.Key)")
    }
    [Console]::Error.WriteLine(
        "Lifecycle edits (Status, Approval, Second Approval, Task-Review-Status, Done-When checkboxes) are permitted here; criterion prose must travel as a specs-only commit.")
    exit 1
}

Write-Output "check-criterion-freeze: $short keeps frozen criterion prose intact ($($tasksFiles.Count) reviewed tasks.md checked)"
exit 0
