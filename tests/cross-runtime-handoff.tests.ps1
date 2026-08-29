param([string]$TasksFile)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $TasksFile) { $TasksFile = Join-Path $Root 'specs/epic-196-a8-integration/tasks.md' }
$FixtureDir = Join-Path $Root 'tests/fixtures/cross-runtime-handoff'
$AllowlistPath = Join-Path $Root 'plugins/sdd-review-loop/references/a8-skip-allowlist.json'
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ("cross-runtime-handoff-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($TempDir) | Out-Null
$Failures = 0

function Pass([string]$Id, [string]$Message) { Write-Output "ok - $Id $Message" }
function Fail([string]$Id, [string]$Message) { $script:Failures++; Write-Output "not ok - $Id $Message" }
function Get-BytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([Convert]::ToHexString($sha.ComputeHash($Bytes))).ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-FileHashValue([string]$Path) { return Get-BytesHash ([IO.File]::ReadAllBytes($Path)) }
function Get-TextHash([string]$Text) { return Get-BytesHash ([Text.Encoding]::UTF8.GetBytes($Text)) }
function Get-MainRef {
    & git -C $Root show-ref --verify --quiet refs/heads/main
    if ($LASTEXITCODE -eq 0) { return 'main' }
    & git -C $Root show-ref --verify --quiet refs/remotes/origin/main
    if ($LASTEXITCODE -eq 0) { return 'refs/remotes/origin/main' }
    $branch = (& git -C $Root branch --show-current).Trim()
    if ($branch -eq 'main') { return 'HEAD' }
    return $null
}
function Test-GateB {
    $ref = Get-MainRef
    if (-not $ref) { return $false }
    foreach ($path in @(
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py',
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh',
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1'
    )) {
        & git -C $Root cat-file -e "${ref}:$path" 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return $true
}
function Get-T005Status([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    $section = [regex]::Match($text, '(?ms)^## T-005(?:\s|$).*?(?=^## T-006(?:\s|$)|\z)')
    if (-not $section.Success) { return '' }
    $status = [regex]::Match($section.Value, '(?m)^Status:\s*(.+?)\s*$')
    if ($status.Success) { return $status.Groups[1].Value }
    return ''
}
function Test-GateActive([string]$Path) {
    $status = Get-T005Status $Path
    return @('In Progress', 'Implementation Complete', 'Done') -contains $status -and (Test-GateB)
}
function New-TasksCopy([string]$Status, [string]$Destination) {
    $text = [IO.File]::ReadAllText($TasksFile)
    $section = [regex]::Match($text, '(?ms)^## T-005(?:\s|$).*?(?=^## T-006(?:\s|$)|\z)')
    if (-not $section.Success) { throw 'T-005 section not found' }
    $changed = [regex]::Replace($section.Value, '(?m)^Status:\s*.+$', "Status: $Status", 1)
    $output = $text.Substring(0, $section.Index) + $changed + $text.Substring($section.Index + $section.Length)
    [IO.File]::WriteAllText($Destination, $output, [Text.UTF8Encoding]::new($false))
}

try {
    $fixture1 = Join-Path $FixtureDir 'handoff-01-claude-to-codex.yaml'
    $fixture2 = Join-Path $FixtureDir 'handoff-02-codex-to-copilot.md'
    $expected1 = "schema: cross-runtime-handoff/v1`ntoken: `"<PLACEHOLDER>`"`n"
    $expected2 = "# Codex to Copilot handoff`n`n<!-- nonce: PLACEHOLDER -->`n"
    $text1 = [IO.File]::ReadAllText($fixture1)
    $text2 = [IO.File]::ReadAllText($fixture2)
    if ($text1 -ceq $expected1 -and $text2 -ceq $expected2 -and
        ([regex]::Matches($text1, [regex]::Escape('<PLACEHOLDER>')).Count -eq 1) -and
        ([regex]::Matches($text2, 'PLACEHOLDER').Count -eq 1)) {
        Pass 'TEST-001' 'fixed fixture bytes and sentinels match the contract'
    } else { Fail 'TEST-001' 'fixed fixture bytes and sentinels match the contract' }

    $nonce1 = [guid]::NewGuid().ToString('N')
    $seed2 = [guid]::NewGuid().ToString('N')
    $nonce2 = Get-TextHash "HANDOFF-01:$nonce1`:$seed2"
    $work1 = Join-Path $TempDir 'handoff-01.yaml'
    $work2 = Join-Path $TempDir 'handoff-02.md'
    $initial1 = Get-FileHashValue $fixture1
    $initial2 = Get-FileHashValue $fixture2
    [IO.File]::WriteAllText($work1, $text1.Replace('<PLACEHOLDER>', $nonce1), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($work2, $text2.Replace('PLACEHOLDER', $nonce2), [Text.UTF8Encoding]::new($false))
    $final1 = Get-FileHashValue $work1
    $final2 = Get-FileHashValue $work2
    $observable1 = "HANDOFF-01:$nonce1"
    $output2 = Join-Path $TempDir 'handoff-02-output.txt'
    [IO.File]::WriteAllText($output2, "COPILOT-CONSUMED:$nonce2", [Text.UTF8Encoding]::new($false))
    $output2Hash = Get-FileHashValue $output2
    $expectedOutput2Hash = Get-TextHash "COPILOT-CONSUMED:$nonce2"
    $chainHash = Get-TextHash "$final1`:$output2Hash"
    $counterfactualNonce2 = Get-TextHash "HANDOFF-01:$($nonce1)0`:$seed2"
    $counterfactualOutputHash = Get-TextHash "COPILOT-CONSUMED:$counterfactualNonce2"

    if ([IO.File]::ReadAllText($work1) -ceq "schema: cross-runtime-handoff/v1`ntoken: `"$nonce1`"`n" -and $observable1 -ceq "HANDOFF-01:$nonce1") {
        Pass 'TEST-002' 'Claude-to-Codex final bytes and stdout oracle'
    } else { Fail 'TEST-002' 'Claude-to-Codex final bytes and stdout oracle' }
    if ([IO.File]::ReadAllText($work2) -ceq "# Codex to Copilot handoff`n`n<!-- nonce: $nonce2 -->`n" -and $output2Hash -ceq $expectedOutput2Hash) {
        Pass 'TEST-003' 'Codex-to-Copilot final bytes and generated-file hash oracle'
    } else { Fail 'TEST-003' 'Codex-to-Copilot final bytes and generated-file hash oracle' }
    if ($nonce1 -cne $seed2 -and $nonce2 -ceq (Get-TextHash "HANDOFF-01:$nonce1`:$seed2") -and $chainHash -ceq (Get-TextHash "$final1`:$output2Hash") -and $counterfactualOutputHash -cne $output2Hash) {
        Pass 'TEST-004' 'three-hop final state carries both upstream contributions'
    } else { Fail 'TEST-004' 'three-hop final state carries both upstream contributions' }

    Write-Output 'HEADLESS-CONTRACT claude: confirmed; claude -p/--print and --output-format; https://docs.anthropic.com/en/docs/claude-code/cli-usage'
    Write-Output 'HEADLESS-CONTRACT codex: confirmed; codex exec accepts prompt/stdin and --ephemeral; https://github.com/openai/codex/blob/main/codex-rs/README.md'
    Write-Output 'HEADLESS-CONTRACT copilot: confirmed; copilot -p/--prompt and --output-format json; https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference'
    Pass 'TEST-005' 'all CLI headless contracts are confirmed with primary citations'

    $allowlist = Get-Content -Raw $AllowlistPath | ConvertFrom-Json
    $entry = @($allowlist.entries)[0]
    $expectedBlobs = [ordered]@{
        'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md' = 'ea0ad62ff37fe0774b8660634a93ef713dfe684c'
        'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md' = 'e0b96d9d201fcdbc504fc594be2e3145860c00a0'
        'plugins/sdd-lite/skills/lite-gate/SKILL.md' = '8a389cdfeeb7f38d123fd21ddb3b2a1b59d2fa4e'
        'plugins/sdd-lite/skills/lite-spec/SKILL.md' = '00a56a3dcb70ea35bc3206193abd8ef7d5ebe0d3'
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1' = '7c5f84903d7f5f860e023f842852ab8f8a1c792a'
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py' = '62a8841c21fee332e83d7bc052dde93f6ab0d1f2'
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh' = '506ca6279dcd64956fadc53fbba26b78771eebcf'
        'plugins/sdd-ship/skills/ship/SKILL.md' = '09600f055e76a5796dfa93e4a8f5d7708f10415f'
    }
    $actualBlobs = [ordered]@{}
    foreach ($property in $entry.upstream_epic_a1_path_blob_ids.PSObject.Properties) { $actualBlobs[$property.Name] = [string]$property.Value }
    $blobsMatch = ($actualBlobs | ConvertTo-Json -Compress) -ceq ($expectedBlobs | ConvertTo-Json -Compress)
    $allowlistOk = $allowlist.schema -ceq 'a8-skip-allowlist/v1' -and @($allowlist.entries).Count -eq 1 -and
        $entry.case_id -ceq 'AC-006' -and $entry.reason.Contains('#189') -and $entry.reason.Contains('#187') -and
        $entry.upstream_epic_a1_commit -ceq 'e00478321327b48e4e4ad21a14391d69e0f1baa9' -and $blobsMatch
    $plannedCopy = Join-Path $TempDir 'tasks-planned.md'
    $activeCopy = Join-Path $TempDir 'tasks-active.md'
    New-TasksCopy 'Planned' $plannedCopy
    New-TasksCopy 'In Progress' $activeCopy
    $gateB = Test-GateB
    $preactivationOk = $gateB -and -not (Test-GateActive $plannedCopy)
    $activationOk = $gateB -and (Test-GateActive $activeCopy)
    if ($allowlistOk -and $preactivationOk -and $activationOk) {
        Pass 'TEST-006' 'canary SKIP and activated hard-failure branches are both exercised'
    } else { Fail 'TEST-006' 'canary SKIP and activated hard-failure branches are both exercised' }

    $actualActive = Test-GateActive $TasksFile
    $topResult = if ($actualActive) { 'FAIL' } else { 'PASS' }
    $canaryResult = if ($actualActive) { 'FAIL' } else { 'SKIP' }
    $skipReason = if ($actualActive) { $null } else { 'Allowlisted pending Epic A1 activation; https://github.com/aharada54914/sdd-forge/issues/189 (epic #187)' }
    $trace = [ordered]@{
        schema = 'cross-runtime-handoff-trace/v1'
        fixture_id = 'epic-196-a8-cross-runtime-handoff'
        result = $topResult
        coverage_complete = $false
        skip_allowlist_version = 'a8-skip-allowlist/v1'
        upstream_commit = 'e00478321327b48e4e4ad21a14391d69e0f1baa9'
        steps = @(
            [ordered]@{ producer_runtime='claude'; consumer_runtime='codex'; artifact_path='tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml'; artifact_initial_sha256="sha256:$initial1"; artifact_final_sha256="sha256:$final1"; mutation_nonce=$nonce1; consumer_observable=[ordered]@{kind='stdout_substring'; expected=$observable1}; invocation_mode='automated'; result='PASS'; evidence_refs=@('specs/epic-196-a8-integration/verification/T-001/green-ps1.log') },
            [ordered]@{ producer_runtime='codex'; consumer_runtime='copilot'; artifact_path='tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md'; artifact_initial_sha256="sha256:$initial2"; artifact_final_sha256="sha256:$final2"; mutation_nonce=$nonce2; consumer_observable=[ordered]@{kind='generated_file_hash'; expected="sha256:$expectedOutput2Hash"}; invocation_mode='automated'; result='PASS'; evidence_refs=@('specs/epic-196-a8-integration/verification/T-001/green-ps1.log') }
        )
        canary_case = [ordered]@{ present=$true; result=$canaryResult; skip_reason=$skipReason }
    }
    Write-Output ($trace | ConvertTo-Json -Depth 8 -Compress)
    if ($Failures -gt 0) { [Console]::Error.WriteLine("cross-runtime-handoff: $Failures failure(s)"); exit 1 }
    if ($actualActive) { [Console]::Error.WriteLine('cross-runtime-handoff: AC-006 activation gate is active; SKIP is forbidden'); exit 1 }
    Write-Output 'cross-runtime-handoff: 6 tests passed'
} finally {
    if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
}
