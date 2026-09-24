[CmdletBinding()]
param(
    [string]$Fixture,
    [string]$TraceFile,
    [switch]$SelfTestActivation,
    [switch]$LiveE2E
)

$ErrorActionPreference = 'Stop'
$fixtureNewline = [char]10
$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $Fixture) { $Fixture = Join-Path $repoRoot 'tests/fixtures/cross-runtime-handoff' }
$tasksFile = if ($env:SDD_CROSS_RUNTIME_TASKS_PATH) { $env:SDD_CROSS_RUNTIME_TASKS_PATH } else { Join-Path $repoRoot 'specs/epic-196-a8-integration/tasks.md' }
$mainRef = if ($env:SDD_CROSS_RUNTIME_MAIN_REF) { $env:SDD_CROSS_RUNTIME_MAIN_REF } else { 'origin/main' }
$allowlist = Join-Path $repoRoot 'plugins/sdd-review-loop/references/a8-skip-allowlist.json'
$tempRoot = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$evidenceDir = Join-Path $tempRoot ('sdd-a8-handoff-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $evidenceDir)
$evidenceDir = (Resolve-Path $evidenceDir).Path

function Stop-Test([string]$Message) {
    [Console]::Error.WriteLine("cross-runtime-handoff: $Message")
    [Console]::Error.WriteLine("Evidence preserved: $evidenceDir")
    exit 1
}
function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Get-TaskStatus([string]$Path) {
    $text = [IO.File]::ReadAllText($Path)
    $match = [regex]::Match($text, '(?ms)^## T-005 .+?^Status: ([^\r\n]+)')
    if (-not $match.Success) { Stop-Test 'could not read T-005 lifecycle status' }
    $match.Groups[1].Value.Trim()
}
function Test-HandshakeOnMain {
    $paths = @(
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py',
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh',
        'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1'
    )
    foreach ($path in $paths) {
        $lines = & git ls-tree -r $mainRef -- $path
        if ($LASTEXITCODE -ne 0) { return $false }
        if (-not ($lines | Where-Object { $_ -match ('\s' + [regex]::Escape($path) + '$') })) { return $false }
    }
    return $true
}
function Test-CanaryActivated([string]$Status) {
    if ($Status -in @('In Progress', 'Implementation Complete', 'Done')) { return (Test-HandshakeOnMain) }
    if ($Status -in @('Planned', 'Draft', 'Blocked')) { return $false }
    Stop-Test "unknown T-005 status: $Status"
}
function Invoke-ActivationSelfTest {
    $tasksText = [IO.File]::ReadAllText($tasksFile)
    foreach ($status in @('Planned', 'Draft', 'Blocked', 'In Progress', 'Implementation Complete', 'Done')) {
        $pattern = '(?ms)(^## T-005 .+?^Status: )[^\r\n]+'
        if (-not [regex]::IsMatch($tasksText, $pattern)) { Stop-Test 'could not locate T-005 status for disposable fixture' }
        $copy = [regex]::Replace($tasksText, $pattern, ('$1' + $status), 1)
        $copyPath = Join-Path $evidenceDir 'tasks.md'
        [IO.File]::WriteAllText($copyPath, $copy, [Text.UTF8Encoding]::new($false))
        $fixtureStatus = Get-TaskStatus $copyPath
        $expected = $status -in @('In Progress', 'Implementation Complete', 'Done')
        $actual = Test-CanaryActivated $fixtureStatus
        if ([bool]$actual -ne [bool]$expected) { Stop-Test "activation predicate mismatch for $status" }
    }
    [Console]::Out.WriteLine('ok: AC-006 activation gate evaluated all six lifecycle values using disposable tasks.md copies; main handshake paths are present')
}
function Invoke-ContractSelfTest {
    $one = Join-Path $Fixture 'handoff-01-claude-to-codex.yaml'
    $two = Join-Path $Fixture 'handoff-02-codex-to-copilot.md'
    $expectedOne = [Text.Encoding]::UTF8.GetBytes('token: "<PLACEHOLDER>' + '"' + $fixtureNewline)
    $expectedTwo = [Text.Encoding]::UTF8.GetBytes('<!-- nonce: PLACEHOLDER -->' + $fixtureNewline)
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($one)) -cne [Convert]::ToBase64String($expectedOne)) { Stop-Test 'handoff-01 initial bytes differ from contract' }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($two)) -cne [Convert]::ToBase64String($expectedTwo)) { Stop-Test 'handoff-02 initial bytes differ from contract' }
    $contract = Get-Content -LiteralPath $allowlist -Raw | ConvertFrom-Json
    if ($contract.schema -cne 'a8-skip-allowlist/v1') { Stop-Test 'invalid A8 skip allowlist schema' }
    $entries = @{}
    foreach ($entry in @($contract.entries)) { $entries[$entry.case_id] = $entry }
    foreach ($caseId in @('AC-006', 'AC-015', 'AC-016')) {
        if (-not $entries.ContainsKey($caseId)) { Stop-Test "missing $caseId allowlist entry" }
    }
    $ac006 = $entries['AC-006']
    $blobIdCount = @($ac006.upstream_epic_a1_path_blob_ids.PSObject.Properties).Count
    if ($ac006.reason -notlike '*#189*' -or $ac006.reason -notlike '*#187*' -or $blobIdCount -ne 3) { Stop-Test 'AC-006 allowlist lacks issue references or A1 blob IDs' }

    $work = Join-Path $evidenceDir 'pseudo-cli'
    [void](New-Item -ItemType Directory -Path $work)
    $copyOne = Join-Path $work 'handoff-01-claude-to-codex.yaml'
    $copyTwo = Join-Path $work 'handoff-02-codex-to-copilot.md'
    [IO.File]::WriteAllBytes($copyOne, [IO.File]::ReadAllBytes($one))
    [IO.File]::WriteAllBytes($copyTwo, [IO.File]::ReadAllBytes($two))
    $nonce1 = [guid]::NewGuid().ToString('N')
    $nonce2 = [guid]::NewGuid().ToString('N')
    if ($nonce1 -ceq $nonce2) { Stop-Test 'independent nonce collision' }
    $initialOne = Get-Sha256 $copyOne
    $initialTwo = Get-Sha256 $copyTwo
    $bytesOne = [IO.File]::ReadAllBytes($copyOne)
    $textOne = [Text.Encoding]::UTF8.GetString($bytesOne).Replace('<PLACEHOLDER>', $nonce1)
    [IO.File]::WriteAllText($copyOne, $textOne, [Text.UTF8Encoding]::new($false))
    if ([IO.File]::ReadAllText($copyOne) -cne ('token: "' + $nonce1 + '"' + $fixtureNewline)) { Stop-Test 'pseudo Claude producer changed unexpected handoff-01 bytes' }
    $consumerStdout = 'HANDOFF-01:' + ([IO.File]::ReadAllText($copyOne) -replace '(?s)^token: "([^"]+)"\r?\n$', '$1')
    if (-not $consumerStdout.Contains('HANDOFF-01:' + $nonce1)) { Stop-Test 'pseudo Codex consumer marker mismatch' }
    $textTwo = [IO.File]::ReadAllText($copyTwo).Replace('PLACEHOLDER', $nonce2)
    [IO.File]::WriteAllText($copyTwo, $textTwo, [Text.UTF8Encoding]::new($false))
    if ([IO.File]::ReadAllText($copyTwo) -cne ('<!-- nonce: ' + $nonce2 + ' -->' + $fixtureNewline)) { Stop-Test 'pseudo Codex producer changed unexpected handoff-02 bytes' }
    $output = Join-Path $work 'handoff-02-output.txt'
    [IO.File]::WriteAllBytes($output, [Text.Encoding]::UTF8.GetBytes('COPILOT-CONSUMED:' + $nonce2))
    $expectedOutputHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes('COPILOT-CONSUMED:' + $nonce2))).ToLowerInvariant()
    if ((Get-Sha256 $output) -cne $expectedOutputHash) { Stop-Test 'pseudo Copilot generated-file hash mismatch' }
    if ($initialOne -cne ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expectedOne))).ToLowerInvariant()) { Stop-Test 'handoff-01 initial hash mismatch' }
    if ($initialTwo -cne ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expectedTwo))).ToLowerInvariant()) { Stop-Test 'handoff-02 initial hash mismatch' }
    [Console]::Out.WriteLine('ok: pseudo-CLI contract exercised fixture mutation, stdout marker, generated-file hash, and independent nonces')
}
function Invoke-Cli([string]$Name, [string[]]$Arguments, [string]$WorkingDirectory, [string]$LogPath) {
    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { Stop-Test "required headless CLI unavailable: $Name" }
    Push-Location $WorkingDirectory
    try {
        $output = & $command.Source @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        [IO.File]::WriteAllText($LogPath, (($output | Out-String) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
        if ($exitCode -ne 0) { Stop-Test "$Name exited $exitCode; see $(Split-Path -Leaf $LogPath)" }
        return ($output | Out-String)
    } finally { Pop-Location }
}
function Invoke-LiveE2E {
    $work = Join-Path $evidenceDir 'work'
    $fixtureWork = Join-Path $work 'tests/fixtures/cross-runtime-handoff'
    [void](New-Item -ItemType Directory -Force -Path $fixtureWork)
    Copy-Item -LiteralPath (Join-Path $Fixture 'handoff-01-claude-to-codex.yaml') -Destination $fixtureWork
    Copy-Item -LiteralPath (Join-Path $Fixture 'handoff-02-codex-to-copilot.md') -Destination $fixtureWork
    $one = Join-Path $fixtureWork 'handoff-01-claude-to-codex.yaml'
    $two = Join-Path $fixtureWork 'handoff-02-codex-to-copilot.md'
    $nonce1 = [guid]::NewGuid().ToString('N')
    $nonce2 = [guid]::NewGuid().ToString('N')
    while ($nonce1 -ceq $nonce2) { $nonce2 = [guid]::NewGuid().ToString('N') }
    $initial1 = Get-Sha256 $one
    $initial2 = Get-Sha256 $two
    $expected1 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(('token: "' + $nonce1 + '"' + $fixtureNewline)))).ToLowerInvariant()
    $expected2 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(('<!-- nonce: ' + $nonce2 + ' -->' + $fixtureNewline)))).ToLowerInvariant()
    $prompt = "In the current isolated temporary workspace, edit only tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml. Replace the exact YAML value <PLACEHOLDER> with $nonce1, preserving all other bytes. Do not inspect or modify anything else. Do not run shell commands. End with a short confirmation."
    [void](Invoke-Cli 'claude' @('--print', '--output-format', 'text', '--permission-mode', 'acceptEdits', '--permission-prompts', 'none', '--allowedTools', 'Read,Edit', '--', $prompt) $work (Join-Path $evidenceDir 'claude-producer.log'))
    if ((Get-Sha256 $one) -cne $expected1) { Stop-Test 'Claude-produced handoff-01 bytes/hash mismatch' }
    $prompt = 'Read and parse tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml in this isolated workspace. Extract its token field and emit exactly the marker HANDOFF-01:<token> in your final response. Do not modify files or run shell commands.'
    $codexConsumer = Invoke-Cli 'codex' @('exec', '--ephemeral', '--skip-git-repo-check', '--sandbox', 'read-only', '--ask-for-approval', 'never', '--cd', $work, $prompt) $work (Join-Path $evidenceDir 'codex-consumer.log')
    if (-not $codexConsumer.Contains('HANDOFF-01:' + $nonce1)) { Stop-Test 'Codex consumer output did not contain the exact handoff marker' }
    $prompt = "Read and parse tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml and verify its token is $nonce1. Then edit only tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md, replacing the exact PLACEHOLDER in its HTML comment with $nonce2, preserving all other bytes. Do not run shell commands and do not modify any other file. End with the exact marker CODEX-PRODUCED:$nonce2."
    $codexProducer = Invoke-Cli 'codex' @('exec', '--ephemeral', '--skip-git-repo-check', '--sandbox', 'workspace-write', '--ask-for-approval', 'never', '--cd', $work, $prompt) $work (Join-Path $evidenceDir 'codex-producer.log')
    if (-not $codexProducer.Contains('CODEX-PRODUCED:' + $nonce2)) { Stop-Test 'Codex producer did not attest its nonce' }
    if ((Get-Sha256 $two) -cne $expected2) { Stop-Test 'Codex-produced handoff-02 bytes/hash mismatch' }
    $prompt = 'Read tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md, extract the nonce in the HTML comment, and create only tests/fixtures/cross-runtime-handoff/handoff-02-output.txt with the exact bytes COPILOT-CONSUMED:<nonce> (no trailing newline). Do not run shell commands or access the network.'
    [void](Invoke-Cli 'copilot' @('-p', $prompt, '-C', $work, '--disable-builtin-mcps', '--available-tools=read,write', '--allow-tool=read,write') $work (Join-Path $evidenceDir 'copilot-consumer.log'))
    $output = Join-Path $fixtureWork 'handoff-02-output.txt'
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { Stop-Test 'Copilot did not produce handoff-02-output.txt' }
    $outputBytes = [Text.Encoding]::UTF8.GetBytes('COPILOT-CONSUMED:' + $nonce2)
    $expectedOutput = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($outputBytes)).ToLowerInvariant()
    if ((Get-Sha256 $output) -cne $expectedOutput) { Stop-Test 'Copilot-generated file hash mismatch' }
    $status = Get-TaskStatus $tasksFile
    $activated = Test-CanaryActivated $status
    $canaryResult = if ($activated) { 'FAIL' } else { 'SKIP' }
    $topResult = if ($activated) { 'FAIL' } else { 'PASS' }
    $skipReason = if ($activated) { 'T-005 is active and the Epic A1 handshake files exist on main; live-host proof remains owned by T-005 (#189/#187).' } else { "AC-006 presence-only in T-001; live-host handshake remains tracked by #189/#187 and T-005 is not started (status: $status)." }
    $trace = [ordered]@{
        schema = 'cross-runtime-handoff-trace/v1'; fixture_id = 'cross-runtime-handoff'; result = $topResult
        coverage_complete = $false; skip_allowlist_version = 'a8-skip-allowlist/v1'; upstream_commit = $null
        headless_contracts = @(
            @{ runtime = 'claude'; status = 'confirmed'; invocation = 'claude --print'; evidence = 'https://docs.anthropic.com/en/docs/claude-code/cli-usage' },
            @{ runtime = 'codex'; status = 'confirmed'; invocation = 'codex exec'; evidence = 'https://github.com/openai/codex/blob/main/codex-rs/exec/src/cli.rs' },
            @{ runtime = 'copilot'; status = 'confirmed'; invocation = 'copilot -p'; evidence = 'https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/run-cli-programmatically' }
        )
        steps = @(
            @{ producer_runtime = 'claude'; consumer_runtime = 'codex'; artifact_path = 'tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml'; artifact_initial_sha256 = "sha256:$initial1"; artifact_final_sha256 = "sha256:$expected1"; mutation_nonce = $nonce1; consumer_observable = @{ kind = 'stdout_substring'; expected = "HANDOFF-01:$nonce1" }; invocation_mode = 'automated'; result = 'PASS'; evidence_refs = @('claude-producer.log', 'codex-consumer.log') },
            @{ producer_runtime = 'codex'; consumer_runtime = 'copilot'; artifact_path = 'tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md'; artifact_initial_sha256 = "sha256:$initial2"; artifact_final_sha256 = "sha256:$expected2"; mutation_nonce = $nonce2; consumer_observable = @{ kind = 'generated_file_hash'; expected = "sha256:$expectedOutput" }; invocation_mode = 'automated'; result = 'PASS'; evidence_refs = @('codex-producer.log', 'copilot-consumer.log') }
        )
        canary_case = @{ present = $true; result = $canaryResult; skip_reason = $skipReason }
    }
    $tracePath = Join-Path $evidenceDir 'trace.json'
    [IO.File]::WriteAllText($tracePath, ($trace | ConvertTo-Json -Depth 12) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    if ($TraceFile) { Copy-Item -LiteralPath $tracePath -Destination $TraceFile; Get-Content -LiteralPath $TraceFile -Raw } else { Get-Content -LiteralPath $tracePath -Raw }
    [Console]::Error.WriteLine("Evidence directory: $evidenceDir")
    if ($activated) { exit 1 }
}
if ($SelfTestActivation) { Invoke-ActivationSelfTest; exit 0 }
if (-not (Test-Path -LiteralPath $allowlist -PathType Leaf)) { Stop-Test 'missing AC-006 allowlist' }
if (-not $LiveE2E) {
    Invoke-ContractSelfTest
    Invoke-ActivationSelfTest
    [Console]::Out.WriteLine('Live CLI E2E not run; pass -LiveE2E and set SDD_A8_ALLOW_LIVE_CLI=1 for explicit authenticated sessions.')
    exit 0
}
if ($env:SDD_A8_ALLOW_LIVE_CLI -cne '1') { Stop-Test '-LiveE2E requires explicit SDD_A8_ALLOW_LIVE_CLI=1' }
Invoke-LiveE2E
