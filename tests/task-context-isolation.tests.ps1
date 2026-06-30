$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scriptDir = Join-Path $root 'plugins/sdd-implementation/scripts'
$validator = Join-Path $scriptDir 'validate-task-input-manifest.ps1'
$snapshot = Join-Path $scriptDir 'prepare-task-snapshot.ps1'
$selector = Join-Path $scriptDir 'select-agent-model.ps1'

function Fail([string]$Message) { throw "not ok: $Message" }
function Get-Sha256([string]$Path) {
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}
function Expect-Diagnostic([string]$Expected, [scriptblock]$Action) {
  try {
    & $Action 2>&1 | Out-Null
  } catch {
    if ($_.Exception.Message.StartsWith($Expected, [StringComparison]::Ordinal)) { return }
    Fail "expected $Expected, got: $($_.Exception.Message)"
  }
  Fail "expected $Expected"
}
function Write-Manifest(
  [string]$Path,
  [string]$TaskId,
  [string]$RunId,
  [string]$SessionId,
  [string]$AgentId,
  [string]$Mode = 'fresh-agent',
  [string]$FallbackReason = '',
  [string]$HandoffHash = ''
) {
  [ordered]@{
    schema = 'task-input-manifest/v1'
    task_id = $TaskId
    run_id = $RunId
    session_id = $SessionId
    agent_instance_id = $AgentId
    model_tier = 'standard'
    provider = 'codex'
    model = 'codex-general-medium'
    estimated_cost_per_attempt_usd = '0.125'
    cost_estimate_source = 'fixture-2026-06-30'
    cost_estimate_timestamp = '2026-06-30T00:00:00Z'
    isolation_mode = $Mode
    fallback_reason = $FallbackReason
    handoff_reload_evidence_hash = $HandoffHash
    allowed_inputs = @(
      [ordered]@{path='specs/demo/requirements.md'; sha256=$script:reqHash},
      [ordered]@{path='contracts/demo.json'; sha256=$script:contractHash}
    )
    allowed_outputs = @('reports/implementation/demo/T-002.md','specs/demo/verification/')
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
}

foreach ($required in @($validator, $snapshot, $selector)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { Fail "missing script: $required" }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("sdd-task-context-" + [guid]::NewGuid())
try {
  $repo = Join-Path $work 'repo'
  New-Item -ItemType Directory -Path (Join-Path $repo 'specs/demo') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $repo 'contracts') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $work 'manifests') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $work 'snapshots') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $repo 'specs/demo/requirements.md') -Value "requirement text`n" -NoNewline -Encoding utf8
  Set-Content -LiteralPath (Join-Path $repo 'contracts/demo.json') -Value "{`"contract`":true}`n" -NoNewline -Encoding utf8
  $script:reqHash = Get-Sha256 (Join-Path $repo 'specs/demo/requirements.md')
  $script:contractHash = Get-Sha256 (Join-Path $repo 'contracts/demo.json')
  $reloadHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("handoff`n"))).Replace('-','').ToLowerInvariant()

  $valid = Join-Path $work 'manifests/valid.json'
  $validSnapshot = Join-Path $work 'snapshots/run-001'
  Write-Manifest $valid T-002 run-001 session-001 agent-001
  & $snapshot -Manifest $valid -RepoRoot $repo -SnapshotRoot $validSnapshot | Out-Null
  $output = @(& $validator -Manifest $valid -SnapshotRoot $validSnapshot) -join ''
  if (-not $output.StartsWith('TASK_INPUT_OK', [StringComparison]::Ordinal)) { Fail "valid manifest was not accepted: $output" }
  if (-not $IsWindows) {
    $rootMode = [IO.File]::GetUnixFileMode($validSnapshot)
    $dirMode = [IO.File]::GetUnixFileMode((Join-Path $validSnapshot 'specs/demo'))
    $fileMode = [IO.File]::GetUnixFileMode((Join-Path $validSnapshot 'specs/demo/requirements.md'))
    $writeBits = [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::GroupWrite -bor [IO.UnixFileMode]::OtherWrite
    if (($rootMode -band $writeBits) -or ($dirMode -band $writeBits) -or ($fileMode -band $writeBits)) {
      Fail 'published snapshot contains writable Unix modes'
    }
  } elseif (-not ((Get-Item -LiteralPath (Join-Path $validSnapshot 'specs/demo/requirements.md') -Force).Attributes -band [IO.FileAttributes]::ReadOnly)) {
    Fail 'published snapshot file is not read-only on Windows'
  }
  try {
    Set-Content -LiteralPath (Join-Path $validSnapshot 'specs/demo/requirements.md') -Value "changed`n" -NoNewline -Encoding utf8 -ErrorAction Stop
    Fail 'published snapshot permitted post-publication mutation'
  } catch {
    if ($_.Exception.Message.StartsWith('not ok:', [StringComparison]::Ordinal)) { throw }
  }
  try {
    New-Item -ItemType File -Path (Join-Path $validSnapshot 'specs/demo/new.md') -ErrorAction Stop | Out-Null
    Fail 'published snapshot permitted post-publication file creation'
  } catch {
    if ($_.Exception.Message.StartsWith('not ok:', [StringComparison]::Ordinal)) { throw }
  }
  try {
    Remove-Item -LiteralPath (Join-Path $validSnapshot 'specs/demo/requirements.md') -ErrorAction Stop
    Fail 'published snapshot permitted post-publication deletion'
  } catch {
    if ($_.Exception.Message.StartsWith('not ok:', [StringComparison]::Ordinal)) { throw }
  }

  foreach ($idx in 1..3) {
    Write-Manifest (Join-Path $work "manifests/batch-$idx.json") ("T-00$idx") ("run-00$idx") ("session-00$idx") ("agent-00$idx")
  }
  & $validator -Batch @((Join-Path $work 'manifests/batch-1.json'), (Join-Path $work 'manifests/batch-2.json'), (Join-Path $work 'manifests/batch-3.json')) | Out-Null
  $reuse = Get-Content -Raw -LiteralPath (Join-Path $work 'manifests/batch-3.json') | ConvertFrom-Json
  $reuse.session_id = 'session-001'
  $reuse | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/batch-3-reuse.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_IDENTITY { & $validator -Batch @((Join-Path $work 'manifests/batch-1.json'), (Join-Path $work 'manifests/batch-2.json'), (Join-Path $work 'manifests/batch-3-reuse.json')) }

  Write-Manifest (Join-Path $work 'manifests/fallback-a.json') T-010 run-010 shared-session shared-agent same-session-file-reload same-session-file-reload $reloadHash
  Write-Manifest (Join-Path $work 'manifests/fallback-b.json') T-011 run-011 shared-session shared-agent same-session-file-reload same-session-file-reload $reloadHash
  & $validator -Batch @((Join-Path $work 'manifests/fallback-a.json'), (Join-Path $work 'manifests/fallback-b.json')) | Out-Null
  $chatOnly = Get-Content -Raw -LiteralPath (Join-Path $work 'manifests/fallback-a.json') | ConvertFrom-Json
  $chatOnly.handoff_reload_evidence_hash = ''
  $chatOnly | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/chat-only.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_HANDOFF { & $validator -Manifest (Join-Path $work 'manifests/chat-only.json') }

  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.task_id = 'T-999'
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/bad-task.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_IDENTITY { & $validator -Manifest (Join-Path $work 'manifests/bad-task.json') -ExpectedTask T-002 -SnapshotRoot $validSnapshot }
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.allowed_inputs[0].path = '../secrets.txt'
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/bad-path.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest (Join-Path $work 'manifests/bad-path.json') }
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.allowed_inputs[0].sha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/bad-sha.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_HASH { & $validator -Manifest (Join-Path $work 'manifests/bad-sha.json') -SnapshotRoot $validSnapshot }
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.PSObject.Properties.Remove('cost_estimate_source')
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/missing-field.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_COST { & $validator -Manifest (Join-Path $work 'manifests/missing-field.json') }
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.estimated_cost_per_attempt_usd = '1.2.3'
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/bad-cost.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_COST { & $validator -Manifest (Join-Path $work 'manifests/bad-cost.json') }
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.allowed_outputs += '../outside'
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/bad-output.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest (Join-Path $work 'manifests/bad-output.json') }
  foreach ($field in @('allowed_inputs','allowed_outputs')) {
    $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
    $bad.$field = 'not-an-array'
    $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work "manifests/scalar-$field.json") -Encoding utf8
    Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest (Join-Path $work "manifests/scalar-$field.json") }
  }
  foreach ($timestamp in @('2026-02-29T00:00:00Z','2026-04-31T00:00:00Z','2026-12-31T24:00:00Z','2026-99-99T99:99:99Z','2026-06-30T00:00:00+00:00')) {
    $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
    $bad.cost_estimate_timestamp = $timestamp
    $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/bad-time.json') -Encoding utf8
    Expect-Diagnostic TASK_INPUT_COST { & $validator -Manifest (Join-Path $work 'manifests/bad-time.json') }
  }
  foreach ($outputs in @(
    @('specs/demo'),
    @('specs'),
    @('specs/demo/requirements.md/child'),
    @('reports/','reports/out.md'),
    @('reports/out.md','reports')
  )) {
    $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
    $bad.allowed_outputs = $outputs
    $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/overlap.json') -Encoding utf8
    Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest (Join-Path $work 'manifests/overlap.json') }
  }
  New-Item -ItemType SymbolicLink -Path (Join-Path $repo 'specs/demo/link.md') -Target (Join-Path $repo 'specs/demo/requirements.md') | Out-Null
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.allowed_inputs[0].path = 'specs/demo/link.md'
  $bad.allowed_inputs[0].sha256 = $script:reqHash
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/symlink.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_PATH { & $snapshot -Manifest (Join-Path $work 'manifests/symlink.json') -RepoRoot $repo -SnapshotRoot (Join-Path $work 'snapshots/symlink') }
  $external = Join-Path $work 'external/specs'
  New-Item -ItemType Directory -Path $external -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo 'specs/demo/requirements.md') -Destination (Join-Path $external 'requirements.md')
  $linkedSnapshot = Join-Path $work 'snapshots/linked'
  New-Item -ItemType Directory -Path $linkedSnapshot -Force | Out-Null
  New-Item -ItemType SymbolicLink -Path (Join-Path $linkedSnapshot 'specs') -Target $external | Out-Null
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.allowed_inputs = @([pscustomobject]@{path='specs/requirements.md'; sha256=$script:reqHash})
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/snapshot-parent-link.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest (Join-Path $work 'manifests/snapshot-parent-link.json') -SnapshotRoot $linkedSnapshot }
  $finalLinkedSnapshot = Join-Path $work 'snapshots/final-link'
  New-Item -ItemType Directory -Path (Join-Path $finalLinkedSnapshot 'specs') -Force | Out-Null
  New-Item -ItemType SymbolicLink -Path (Join-Path $finalLinkedSnapshot 'specs/requirements.md') -Target (Join-Path $external 'requirements.md') | Out-Null
  Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest (Join-Path $work 'manifests/snapshot-parent-link.json') -SnapshotRoot $finalLinkedSnapshot }
  $rootLinkedSnapshot = Join-Path $work 'snapshots/root-link'
  New-Item -ItemType SymbolicLink -Path $rootLinkedSnapshot -Target $validSnapshot | Out-Null
  Expect-Diagnostic TASK_INPUT_PATH { & $validator -Manifest $valid -SnapshotRoot $rootLinkedSnapshot }

  $sourceParentTarget = Join-Path $repo 'linked-parent-target'
  New-Item -ItemType Directory -Path $sourceParentTarget -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $sourceParentTarget 'input.md') -Value "parent link input`n" -NoNewline -Encoding utf8
  $sourceParentHash = Get-Sha256 (Join-Path $sourceParentTarget 'input.md')
  New-Item -ItemType SymbolicLink -Path (Join-Path $repo 'linked-parent') -Target $sourceParentTarget | Out-Null
  $bad = Get-Content -Raw -LiteralPath $valid | ConvertFrom-Json
  $bad.allowed_inputs = @([pscustomobject]@{path='linked-parent/input.md'; sha256=$sourceParentHash})
  $bad | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $work 'manifests/source-parent-link.json') -Encoding utf8
  Expect-Diagnostic TASK_INPUT_PATH { & $snapshot -Manifest (Join-Path $work 'manifests/source-parent-link.json') -RepoRoot $repo -SnapshotRoot (Join-Path $work 'snapshots/source-parent-link') }

  if (-not $IsWindows) {
    [IO.File]::SetUnixFileMode((Join-Path $validSnapshot 'specs/demo/requirements.md'), [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
  } else {
    $target = Join-Path $validSnapshot 'specs/demo/requirements.md'
    [IO.File]::SetAttributes($target, [IO.File]::GetAttributes($target) -band (-bnot [IO.FileAttributes]::ReadOnly))
  }
  Set-Content -LiteralPath (Join-Path $validSnapshot 'specs/demo/requirements.md') -Value "tampered`n" -NoNewline -Encoding utf8
  Expect-Diagnostic TASK_INPUT_HASH { & $validator -Manifest $valid -SnapshotRoot $validSnapshot }

  $barrier = Join-Path $work 'publish-barrier'
  $boundarySnapshot = Join-Path $work 'snapshots/publication-boundary'
  $boundaryOut = Join-Path $work 'boundary.out'
  $boundaryErr = Join-Path $work 'boundary.err'
  New-Item -ItemType Directory -Path $barrier -Force | Out-Null
  $oldBarrier = $env:SDD_TEST_SNAPSHOT_PUBLISH_BARRIER_DIR
  $env:SDD_TEST_SNAPSHOT_PUBLISH_BARRIER_DIR = $barrier
  try {
    $pwshPath = (Get-Process -Id $PID).Path
    $process = Start-Process -FilePath $pwshPath -ArgumentList @(
      '-NoLogo','-NoProfile','-File',$snapshot,
      '-Manifest',$valid,'-RepoRoot',$repo,'-SnapshotRoot',$boundarySnapshot
    ) -RedirectStandardOutput $boundaryOut -RedirectStandardError $boundaryErr -PassThru
  } finally {
    $env:SDD_TEST_SNAPSHOT_PUBLISH_BARRIER_DIR = $oldBarrier
  }
  foreach ($attempt in 1..200) {
    if (Test-Path -LiteralPath (Join-Path $barrier 'ready')) { break }
    Start-Sleep -Milliseconds 10
  }
  if (-not (Test-Path -LiteralPath (Join-Path $barrier 'ready'))) { Fail 'snapshot builder did not reach publication boundary' }
  New-Item -ItemType Directory -Path $boundarySnapshot | Out-Null
  Set-Content -LiteralPath (Join-Path $boundarySnapshot 'marker') -Value "attacker-owned`n" -NoNewline -Encoding utf8
  New-Item -ItemType File -Path (Join-Path $barrier 'continue') | Out-Null
  $process.WaitForExit()
  if ($process.ExitCode -eq 0) { Fail 'snapshot builder overwrote destination injected at publication boundary' }
  $boundaryDiagnostic = Get-Content -Raw -LiteralPath $boundaryErr
  if (-not $boundaryDiagnostic.Contains('TASK_INPUT_PATH:', [StringComparison]::Ordinal)) { Fail "publication-boundary rejection lost TASK_INPUT_PATH diagnostic: $boundaryDiagnostic" }
  if ((Get-Content -Raw -LiteralPath (Join-Path $boundarySnapshot 'marker')).Trim() -cne 'attacker-owned') { Fail 'publication boundary destination was replaced' }

  $selection = @(& $selector -Risk high -Candidate @('codex/fast:lightweight:0.010', 'codex/general:standard:0.030', 'codex/strong:strong:0.090')) -join ''
  if ($selection -cne 'codex/strong strong') { Fail "unexpected selector output: $selection" }

  Write-Output 'ok: PowerShell task context isolation manifests, snapshots, fallback, and selector are deterministic'
} finally {
  if (Test-Path -LiteralPath $work) {
    if (-not $IsWindows) {
      Get-ChildItem -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
          if ($_.PSIsContainer) {
            [IO.File]::SetUnixFileMode($_.FullName, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
          } else {
            [IO.File]::SetUnixFileMode($_.FullName, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
          }
        } catch {}
      }
    } else {
      foreach ($snapshotRoot in @(Get-ChildItem -LiteralPath (Join-Path $work 'snapshots') -Directory -Force -ErrorAction SilentlyContinue)) {
        try {
          $acl = Get-Acl -LiteralPath $snapshotRoot.FullName
          $acl.SetAccessRuleProtection($false, $false)
          $acl.PurgeAccessRules([Security.Principal.WindowsIdentity]::GetCurrent().User)
          Set-Acl -LiteralPath $snapshotRoot.FullName -AclObject $acl
        } catch {}
      }
      Get-ChildItem -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.Attributes = $_.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly) } catch {}
      }
    }
  }
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
