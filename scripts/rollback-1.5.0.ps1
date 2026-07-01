param(
    [string]$Contract = "contracts/rollback-1.5.0.json",
    [string]$RepoRoot = ".",
    [string]$Validator = "",
    [ValidateRange(0, [int]::MaxValue)]
    [int]$InjectApplyFailureAfter = 0
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$expectedSchema = "rollback-1.5.0/v1"
$tempRoot = $null
$stage = $null
$worktreeAdded = $false

function Fail-Rollback {
    param([string]$Category, [string]$Message)
    throw "${Category}: $Message"
}

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = & git @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        Fail-Rollback "ROLLBACK_GIT" "git command failed: $($Arguments -join ' ')"
    }
    return $output
}

function Get-LowerHash {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Test-ExactProperties {
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string[]]$Names)
    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    $expected = @($Names | Sort-Object)
    return (($actual -join "`n") -ceq ($expected -join "`n"))
}

function Assert-RelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)
    if ($RelativePath -notmatch '^[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$' -or
        $RelativePath -match '(^|/)\.\.?(/|$)' -or
        $RelativePath.Contains('\') -or
        [IO.Path]::IsPathRooted($RelativePath)) {
        Fail-Rollback "ROLLBACK_PATH" "invalid repository-relative path: $RelativePath"
    }
    $cursor = $repo
    foreach ($part in $RelativePath.Split('/')) {
        $cursor = Join-Path $cursor $part
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if ($null -ne $item.LinkType) {
                Fail-Rollback "ROLLBACK_PATH" "symlink is forbidden: $RelativePath"
            }
        }
    }
}

function Test-GitObjectExists {
    param([string]$Commit, [string]$RelativePath)
    & git -C $repo cat-file -e "${Commit}:${RelativePath}" 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-GitBlobHash {
    param([string]$Commit, [string]$RelativePath)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command git).Source
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("-C", $repo, "show", "${Commit}:${RelativePath}")) {
        $null = $startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($startInfo)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha256.ComputeHash($process.StandardOutput.BaseStream)
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            Fail-Rollback "ROLLBACK_GIT" "cannot read Git object: $RelativePath"
        }
        return ([Convert]::ToHexString($bytes)).ToLowerInvariant()
    } finally {
        $sha256.Dispose()
        $process.Dispose()
    }
}

function Assert-CommitEntry {
    param([string]$Commit, [string]$RelativePath, $Expected, [string]$Label)
    $exists = Test-GitObjectExists $Commit $RelativePath
    if ($null -eq $Expected) {
        if ($exists) { Fail-Rollback "ROLLBACK_HASH" "$Label expected absent: $RelativePath" }
        return
    }
    if (-not $exists) { Fail-Rollback "ROLLBACK_HASH" "$Label file missing: $RelativePath" }
    $type = (& git -C $repo cat-file -t "${Commit}:${RelativePath}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or $type -cne "blob") {
        Fail-Rollback "ROLLBACK_PATH" "$Label path is not a file: $RelativePath"
    }
    if ((Get-GitBlobHash $Commit $RelativePath) -cne [string]$Expected) {
        Fail-Rollback "ROLLBACK_HASH" "$Label hash mismatch: $RelativePath"
    }
}

function Test-T008Output {
    param([string]$RelativePath)
    return $RelativePath -cin @(
        "scripts/rollback-1.5.0.sh",
        "scripts/rollback-1.5.0.ps1",
        "tests/rollback-1.5.0.tests.sh",
        "tests/rollback-1.5.0.tests.ps1",
        "tests/run-all.sh",
        "tests/run-all.ps1"
    )
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Fail-Rollback "ROLLBACK_RUNTIME" "git is required"
    }
    $repo = (Resolve-Path -LiteralPath $RepoRoot).Path
    $inside = Invoke-Git -C $repo rev-parse --is-inside-work-tree
    if ($inside -cne "true") { Fail-Rollback "ROLLBACK_PATH" "repository root is not a Git worktree" }
    $prefix = Invoke-Git -C $repo rev-parse --show-prefix
    if (-not [string]::IsNullOrEmpty([string]$prefix)) {
        Fail-Rollback "ROLLBACK_PATH" "repository root must be the Git worktree root"
    }

    if (-not [IO.Path]::IsPathRooted($Contract)) { $Contract = Join-Path $repo $Contract }
    if (-not (Test-Path -LiteralPath $Contract -PathType Leaf) -or
        $null -ne (Get-Item -LiteralPath $Contract).LinkType) {
        Fail-Rollback "ROLLBACK_CONTRACT" "contract must be a regular non-symlink file"
    }
    if (@(Invoke-Git -C $repo status --porcelain=v1 --untracked-files=all).Count -ne 0) {
        Fail-Rollback "ROLLBACK_DIRTY" "repository must be clean"
    }

    try {
        $data = Get-Content -Raw -Encoding Utf8 -LiteralPath $Contract | ConvertFrom-Json
    } catch {
        Fail-Rollback "ROLLBACK_CONTRACT" "invalid JSON"
    }
    if (-not (Test-ExactProperties $data @("schema", "baseline_commit", "reviewed_release_commit", "files")) -or
        $data.schema -cne $expectedSchema -or
        $data.baseline_commit -isnot [string] -or $data.baseline_commit -cnotmatch '^[a-f0-9]{40}$' -or
        $data.reviewed_release_commit -isnot [string] -or $data.reviewed_release_commit -cnotmatch '^[a-f0-9]{40}$' -or
        @($data.files).Count -eq 0) {
        Fail-Rollback "ROLLBACK_CONTRACT" "invalid or non-closed contract"
    }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $previous = $null
    foreach ($entry in @($data.files)) {
        if (-not (Test-ExactProperties $entry @("path", "baseline_sha256", "new_sha256")) -or
            $entry.path -isnot [string] -or
            ($null -ne $entry.baseline_sha256 -and
                ($entry.baseline_sha256 -isnot [string] -or $entry.baseline_sha256 -cnotmatch '^[a-f0-9]{64}$')) -or
            ($null -ne $entry.new_sha256 -and
                ($entry.new_sha256 -isnot [string] -or $entry.new_sha256 -cnotmatch '^[a-f0-9]{64}$')) -or
            ($null -eq $entry.baseline_sha256 -and $null -eq $entry.new_sha256)) {
            Fail-Rollback "ROLLBACK_CONTRACT" "invalid file entry"
        }
        Assert-RelativePath $entry.path
        if (-not $seen.Add([string]$entry.path) -or
            ($null -ne $previous -and [StringComparer]::Ordinal.Compare($previous, [string]$entry.path) -ge 0)) {
            Fail-Rollback "ROLLBACK_CONTRACT" "file paths must be unique and ordinal-sorted"
        }
        $previous = [string]$entry.path
    }

    $baseline = [string]$data.baseline_commit
    $reviewed = [string]$data.reviewed_release_commit
    & git -C $repo cat-file -e "$baseline^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { Fail-Rollback "ROLLBACK_CONTRACT" "baseline commit is unavailable" }
    & git -C $repo cat-file -e "$reviewed^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { Fail-Rollback "ROLLBACK_CONTRACT" "reviewed release commit is unavailable" }

    foreach ($entry in @($data.files)) {
        Assert-CommitEntry $baseline $entry.path $entry.baseline_sha256 "baseline"
        if ((Test-GitObjectExists $reviewed $entry.path) -and -not (Test-T008Output $entry.path)) {
            Assert-CommitEntry $reviewed $entry.path $entry.new_sha256 "reviewed"
        }
        $current = Join-Path $repo $entry.path
        if ($null -eq $entry.new_sha256) {
            if (Test-Path -LiteralPath $current) {
                Fail-Rollback "ROLLBACK_HASH" "current path expected absent: $($entry.path)"
            }
        } else {
            if (-not (Test-Path -LiteralPath $current -PathType Leaf) -or
                $null -ne (Get-Item -LiteralPath $current).LinkType) {
                Fail-Rollback "ROLLBACK_PATH" "current file is missing, non-regular, or a symlink: $($entry.path)"
            }
            if ((Get-LowerHash $current) -cne $entry.new_sha256) {
                Fail-Rollback "ROLLBACK_HASH" "current hash mismatch: $($entry.path)"
            }
        }
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-rollback-" + [guid]::NewGuid())
    $stage = Join-Path $tempRoot "stage"
    $backup = Join-Path $tempRoot "backup"
    New-Item -ItemType Directory -Path $tempRoot, $backup -Force | Out-Null
    & git -C $repo worktree add --quiet --detach $stage $baseline
    if ($LASTEXITCODE -ne 0) { Fail-Rollback "ROLLBACK_STAGE" "cannot create isolated baseline worktree" }
    $worktreeAdded = $true

    foreach ($entry in @($data.files)) {
        $staged = Join-Path $stage $entry.path
        if ($null -eq $entry.baseline_sha256) {
            if (Test-Path -LiteralPath $staged) {
                Fail-Rollback "ROLLBACK_HASH" "staged baseline expected absent: $($entry.path)"
            }
        } else {
            if (-not (Test-Path -LiteralPath $staged -PathType Leaf) -or
                $null -ne (Get-Item -LiteralPath $staged).LinkType -or
                (Get-LowerHash $staged) -cne $entry.baseline_sha256) {
                Fail-Rollback "ROLLBACK_HASH" "staged baseline hash mismatch: $($entry.path)"
            }
        }
    }

    Push-Location $stage
    try {
        if ($Validator) {
            $validatorPath = if ([IO.Path]::IsPathRooted($Validator)) {
                $Validator
            } else {
                Join-Path $repo $Validator
            }
            if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf) -or
                $null -ne (Get-Item -LiteralPath $validatorPath).LinkType) {
                Fail-Rollback "ROLLBACK_VALIDATION" "validator must be a regular non-symlink file"
            }
            if ([IO.Path]::GetExtension($validatorPath) -ieq ".ps1") {
                & (Get-Process -Id $PID).Path -NoProfile -File $validatorPath
            } else {
                & bash $validatorPath
            }
        } else {
            & (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $stage "tests/validate-repository.ps1")
        }
        if ($LASTEXITCODE -ne 0) {
            Fail-Rollback "ROLLBACK_VALIDATION" "isolated baseline validation failed"
        }
    } finally {
        Pop-Location
    }

    $backupState = [Collections.Generic.List[object]]::new()
    foreach ($entry in @($data.files)) {
        $source = Join-Path $repo $entry.path
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            $target = Join-Path $backup $entry.path
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
            $sourceHash = Get-LowerHash $source
            if ((Get-LowerHash $target) -cne $sourceHash) {
                Fail-Rollback "ROLLBACK_BACKUP" "backup verification failed: $($entry.path)"
            }
            $backupState.Add([pscustomobject]@{
                Path = [string]$entry.path
                Present = $true
                Hash = $sourceHash
            })
        } elseif (-not (Test-Path -LiteralPath $source)) {
            $backupState.Add([pscustomobject]@{
                Path = [string]$entry.path
                Present = $false
                Hash = $null
            })
        } else {
            Fail-Rollback "ROLLBACK_PATH" "cannot back up non-regular path: $($entry.path)"
        }
    }

    $applyCount = 0
    try {
        foreach ($entry in @($data.files)) {
            $target = Join-Path $repo $entry.path
            if ($null -eq $entry.baseline_sha256) {
                Remove-Item -Force -LiteralPath $target -ErrorAction Stop
            } else {
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                Copy-Item -Force -LiteralPath (Join-Path $stage $entry.path) -Destination $target
            }
            $applyCount++
            if ($InjectApplyFailureAfter -gt 0 -and $applyCount -eq $InjectApplyFailureAfter) {
                throw "injected partial-apply failure"
            }
        }
    } catch {
        $applyError = $_.Exception.Message
        try {
            foreach ($state in $backupState) {
                $target = Join-Path $repo $state.Path
                if (-not $state.Present) {
                    Remove-Item -Force -LiteralPath $target -ErrorAction SilentlyContinue
                } else {
                    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                    Copy-Item -Force -LiteralPath (Join-Path $backup $state.Path) -Destination $target
                    if ((Get-LowerHash $target) -cne $state.Hash) {
                        Fail-Rollback "ROLLBACK_RESTORE" "restored hash mismatch: $($state.Path)"
                    }
                }
            }
        } catch {
            Fail-Rollback "ROLLBACK_RESTORE" "apply failed and original tree could not be restored"
        }
        Fail-Rollback "ROLLBACK_APPLY" "apply failed; original tree restored byte-for-byte ($applyError)"
    }

    foreach ($entry in @($data.files)) {
        $target = Join-Path $repo $entry.path
        if ($null -eq $entry.baseline_sha256) {
            if (Test-Path -LiteralPath $target) {
                Fail-Rollback "ROLLBACK_APPLY" "post-apply path should be absent: $($entry.path)"
            }
        } elseif (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
            (Get-LowerHash $target) -cne $entry.baseline_sha256) {
            Fail-Rollback "ROLLBACK_APPLY" "post-apply hash mismatch: $($entry.path)"
        }
    }
    Write-Output "ROLLBACK_OK: 1.5.0 -> 1.4.0 complete"
} finally {
    if ($worktreeAdded -and $null -ne $stage) {
        & git -C $repo worktree remove --force $stage 2>$null | Out-Null
    }
    if ($null -ne $tempRoot) {
        Remove-Item -Recurse -Force -LiteralPath $tempRoot -ErrorAction SilentlyContinue
    }
}
