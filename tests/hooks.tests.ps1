$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Behavioral tests for the unified cross-runtime PreToolUse guard and kill switch.
# Covers sdd-hook-guard.ps1 directly and sdd-hook-guard.sh when bash+python3 exist.

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts"
$hooksDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/hooks"
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-hook-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null

$failures = 0
function Assert {
    param([string]$Name, [bool]$Condition)
    if ($Condition) { Write-Host "ok: $Name" }
    else { Write-Host "FAIL: $Name"; $script:failures++ }
}

# Invoke the PowerShell guard with a stdin payload; returns @{Code; Out}.
function Invoke-GuardPs {
    param([string]$Payload, [string]$EmitMode = "exit")
    $outFile = Join-Path $workDir ("out-" + [guid]::NewGuid() + ".txt")
    $Payload | & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "sdd-hook-guard.ps1") -Emit $EmitMode > $outFile 2>$null
    $code = $LASTEXITCODE
    $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
    return @{ Code = $code; Out = $out }
}

# Invoke the kill-switch.ps1 hook in a given working directory.
function Invoke-KillSwitchPs {
    param([string]$Cwd)
    Push-Location $Cwd
    try {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "kill-switch.ps1") *> $null
        return $LASTEXITCODE
    } finally { Pop-Location }
}

function Write-SudoFlag {
    # C-04: Mint a fully signed SDD_SUDO capability token.
    # Matches guards.tests.sh write_sudo_flag and the canonical string defined in all guards.
    # Requires $env:SDD_SUDO_KEY to be set (set near the sudo test section below).
    param([string]$Path, [int64]$ExpiresEpoch, [int64]$IssuedEpoch = -1)
    if ($IssuedEpoch -lt 0) { $IssuedEpoch = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) }

    # Resolve the canonical (symlink-resolved) repo path EXACTLY as the guard
    # process sees it. getcwd() resolves symlinks (e.g. macOS /var ->
    # /private/var), and a freshly-spawned guard derives its repo from that
    # resolved cwd; mirroring it here keeps the signed repo field byte-identical
    # to the guard's binding on every platform.
    $repoPath = $null
    $savedCwd = [System.IO.Directory]::GetCurrentDirectory()
    try {
        [System.IO.Directory]::SetCurrentDirectory($Path)
        $repoPath = [System.IO.Directory]::GetCurrentDirectory()
    } catch {
        try { $repoPath = (Resolve-Path -LiteralPath $Path).Path } catch { $repoPath = [System.IO.Path]::GetFullPath($Path) }
    } finally {
        try { [System.IO.Directory]::SetCurrentDirectory($savedCwd) } catch { }
    }

    # Generate a 32-byte (64 hex char) nonce
    $nonceBytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
    $nonce = -join ($nonceBytes | ForEach-Object { $_.ToString("x2") })

    $issuer = "testuser@testhost"

    # Canonical string: issuer\nnonce\nrepo\nissued-epoch\nexpires-epoch (no trailing newline)
    $issuedStr  = [string]$IssuedEpoch
    $expiresStr = [string]$ExpiresEpoch
    $canonical  = ($issuer, $nonce, $repoPath, $issuedStr, $expiresStr) -join "`n"

    # Compute HMAC-SHA256 using the test key from $env:SDD_SUDO_KEY
    $keyBytes      = [System.Text.Encoding]::UTF8.GetBytes($env:SDD_SUDO_KEY)
    $canonicalBytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    $hmacObj       = New-Object System.Security.Cryptography.HMACSHA256(,$keyBytes)
    $macBytes      = $hmacObj.ComputeHash($canonicalBytes)
    $hmacObj.Dispose()
    $sig = -join ($macBytes | ForEach-Object { $_.ToString("x2") })

    @"
enabled-by: human via /sdd-sudo
enabled-at: 2026-06-13T00:00:00Z
issuer: $issuer
nonce: $nonce
repo: $repoPath
issued-epoch: $IssuedEpoch
expires-epoch: $ExpiresEpoch
duration: 1h
sig: $sig
"@ | Set-Content -Encoding Utf8 (Join-Path $Path "SDD_SUDO")
}

Push-Location $workDir
try {
    New-Item -ItemType Directory -Path "specs/x" -Force | Out-Null

    # --- Claude Edit payload adding Approval: Approved -> deny ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    Assert "ps: edit adds approval -> deny (exit 2)" ($r.Code -eq 2)

    # --- status-only change -> allow ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Status: Planned","new_string":"Status: In Progress"}}'
    Assert "ps: status-only change -> allow (exit 0)" ($r.Code -eq 0)

    # --- Write content payload: N on disk, N content -> allow; N+1 -> deny ---
    $diskTasks = Join-Path $workDir "specs/x/tasks.md"
    @"
# Tasks
## T-001
Approval: Approved
## T-002
Approval: Draft
"@ | Set-Content -Encoding Utf8 $diskTasks
    # On disk has 1 approval. content with 1 approval -> allow.
    $payloadN = (@{ tool_name = "Write"; tool_input = @{ file_path = $diskTasks; content = "Approval: Approved`nApproval: Draft" } } | ConvertTo-Json -Compress -Depth 5)
    $r = Invoke-GuardPs $payloadN
    Assert "ps: write content same count -> allow" ($r.Code -eq 0)
    # content with 2 approvals -> deny.
    $payloadN1 = (@{ tool_name = "Write"; tool_input = @{ file_path = $diskTasks; content = "Approval: Approved`nApproval: Approved" } } | ConvertTo-Json -Compress -Depth 5)
    $r = Invoke-GuardPs $payloadN1
    Assert "ps: write content extra approval -> deny" ($r.Code -eq 2)

    # --- Codex apply_patch adding Approval: Approved to tasks.md -> deny ---
    $patchDeny = "{`"tool_name`":`"apply_patch`",`"tool_input`":{`"command`":`"*** Begin Patch\n*** Update File: specs/x/tasks.md\n-Approval: Draft\n+Approval: Approved\n*** End Patch`"}}"
    $r = Invoke-GuardPs $patchDeny
    Assert "ps: apply_patch adds approval to tasks.md -> deny" ($r.Code -eq 2)

    # --- apply_patch to another file -> allow ---
    $patchOther = "{`"tool_name`":`"apply_patch`",`"tool_input`":{`"command`":`"*** Begin Patch\n*** Update File: src/a.py\n-x\n+Approval: Approved\n*** End Patch`"}}"
    $r = Invoke-GuardPs $patchOther
    Assert "ps: apply_patch to other file -> allow" ($r.Code -eq 0)

    # --- Codex shell echo Approval >> tasks.md -> deny ---
    $shellDeny = "{`"tool_name`":`"shell`",`"tool_input`":{`"command`":`"echo 'Approval: Approved' >> specs/x/tasks.md`"}}"
    $r = Invoke-GuardPs $shellDeny
    Assert "ps: shell appends approval to tasks.md -> deny" ($r.Code -eq 2)

    # --- copilot emit: allow case -> valid JSON, exit 0 ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}' "copilot"
    $okJson = $false
    try { $okJson = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "allow") } catch { }
    Assert "ps: copilot allow -> JSON allow, exit 0" ($r.Code -eq 0 -and $okJson)

    # --- copilot emit: deny case -> valid JSON deny, exit 0 ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
    $okDeny = $false
    try { $okDeny = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "deny") } catch { }
    Assert "ps: copilot deny -> JSON deny, exit 0" ($r.Code -eq 0 -and $okDeny)

    # --- malformed payload -> deny ---
    $r = Invoke-GuardPs 'this is not json'
    Assert "ps: malformed payload -> deny (exit 2)" ($r.Code -eq 2)

    # --- Agent-role guard tests for PowerShell ---
    # 1. DENY: Write-style payload to agent role path without developer_instructions
    $r = Invoke-GuardPs '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\n"}}'
    Assert "ps: Write agent role without developer_instructions -> deny (exit 2)" ($r.Code -eq 2)

    # 2. ALLOW: Write-style payload to agent role path WITH developer_instructions
    $r = Invoke-GuardPs '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\ndeveloper_instructions = \"\"\"test\"\"\"\n"}}'
    Assert "ps: Write agent role with developer_instructions -> allow (exit 0)" ($r.Code -eq 0)

    # 3. ALLOW: Write-style payload lacking developer_instructions key to NON-agent path
    $r = Invoke-GuardPs '{"tool_name":"Write","tool_input":{"file_path":"/tmp/pyproject.toml","content":"name = \"project\"\n"}}'
    Assert "ps: Write to non-agent path -> allow (exit 0)" ($r.Code -eq 0)

    # 4. DENY: apply_patch Add File targeting agent role path with empty body
    $r = Invoke-GuardPs '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
    Assert "ps: apply_patch Add File agent role with empty body -> deny (exit 2)" ($r.Code -eq 2)

    # 4b. ALLOW: apply_patch Add File with developer_instructions
    $r = Invoke-GuardPs '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n+name = \"regression-judge\"\n+developer_instructions = \"\"\"test\"\"\"\n*** End Patch"}}'
    Assert "ps: apply_patch Add File agent role with developer_instructions -> allow (exit 0)" ($r.Code -eq 0)

    # 4c. DENY: apply_patch Delete File targeting agent role path
    $r = Invoke-GuardPs '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Delete File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
    Assert "ps: apply_patch Delete File agent role -> deny (exit 2)" ($r.Code -eq 2)

    # 5. DENY: apply_patch Update File section touching agent role path (partial diff)
    $r = Invoke-GuardPs '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: /home/u/.codex/agents/judge.toml\n-name = \"old\"\n+name = \"judge\"\n*** End Patch"}}'
    Assert "ps: apply_patch Update File agent role -> deny (exit 2)" ($r.Code -eq 2)

    # 6. DENY: shell payload redirect into agent role path without developer_instructions in command
    $r = Invoke-GuardPs '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=1\nEOF"}}'
    Assert "ps: shell redirect into agent role without developer_instructions -> deny (exit 2)" ($r.Code -eq 2)

    # 7. ALLOW: shell payload read from agent role path (no redirect)
    $r = Invoke-GuardPs '{"tool_name":"shell","tool_input":{"command":"cat ~/.codex/agents/judge.toml"}}'
    Assert "ps: shell read agent role path -> allow (exit 0)" ($r.Code -eq 0)

    $r = Invoke-GuardPs '{"tool_name":"shell","tool_input":{"command":"cd ~/.codex/agents && cat > judge.toml <<EOF\nname=judge\nEOF"}}'
    Assert "ps: relative write after cd into agent role directory -> deny (exit 2)" ($r.Code -eq 2)
    $r = Invoke-GuardPs '{"tool_name":"shell","tool_input":{"command":"cp /tmp/source.toml ~/.codex/agents/evil.toml"}}'
    Assert "ps: cp into agent role directory -> deny (exit 2)" ($r.Code -eq 2)

    # 8. DENY: shell heredoc command containing developer_instructions still counts as a write
    $r = Invoke-GuardPs '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=judge\ndeveloper_instructions=\"\"\"test\"\"\"\nEOF"}}'
    Assert "ps: shell heredoc with developer_instructions -> deny (exit 2)" ($r.Code -eq 2)

    # --- kill-switch.ps1: AGENT_STOP present -> 2; absent -> 0 ---
    $ksDir = Join-Path $workDir "ks"
    New-Item -ItemType Directory -Path $ksDir -Force | Out-Null
    $env:CLAUDE_PROJECT_DIR = $null
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    Assert "ps: kill-switch absent -> 0" ((Invoke-KillSwitchPs $ksDir) -eq 0)
    "stop" | Set-Content -Encoding Utf8 (Join-Path $ksDir "AGENT_STOP")
    Assert "ps: kill-switch present -> 2" ((Invoke-KillSwitchPs $ksDir) -eq 2)

    # --- POSIX dispatcher via bash+python3 when available ---
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if ($bash -and $py) {
        function Invoke-GuardSh {
            param([string]$Payload, [string]$EmitMode = "exit")
            $outFile = Join-Path $workDir ("sh-" + [guid]::NewGuid() + ".txt")
            $Payload | & bash (Join-Path $scriptsDir "sdd-hook-guard.sh") "--emit" $EmitMode > $outFile 2>$null
            $code = $LASTEXITCODE
            $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
            return @{ Code = $code; Out = $out }
        }
        $r = Invoke-GuardSh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
        Assert "sh: edit adds approval -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}'
        Assert "sh: other file -> allow" ($r.Code -eq 0)
        $r = Invoke-GuardSh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
        $okDeny = $false
        try { $okDeny = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "deny") } catch { }
        Assert "sh: copilot deny -> JSON deny, exit 0" ($r.Code -eq 0 -and $okDeny)
        $r = Invoke-GuardSh 'not json'
        Assert "sh: malformed -> deny" ($r.Code -eq 2)

        # Agent-role guard tests for sh dispatcher
        $r = Invoke-GuardSh '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\n"}}'
        Assert "sh: Write agent role without developer_instructions -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\ndeveloper_instructions = \"\"\"test\"\"\"\n"}}'
        Assert "sh: Write agent role with developer_instructions -> allow (exit 0)" ($r.Code -eq 0)
        $r = Invoke-GuardSh '{"tool_name":"Write","tool_input":{"file_path":"/tmp/pyproject.toml","content":"name = \"project\"\n"}}'
        Assert "sh: Write to non-agent path -> allow (exit 0)" ($r.Code -eq 0)
        $r = Invoke-GuardSh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
        Assert "sh: apply_patch Add File agent role with empty body -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n+name = \"regression-judge\"\n+developer_instructions = \"\"\"test\"\"\"\n*** End Patch"}}'
        Assert "sh: apply_patch Add File agent role with developer_instructions -> allow (exit 0)" ($r.Code -eq 0)
        $r = Invoke-GuardSh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Delete File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
        Assert "sh: apply_patch Delete File agent role -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: /home/u/.codex/agents/judge.toml\n-name = \"old\"\n+name = \"judge\"\n*** End Patch"}}'
        Assert "sh: apply_patch Update File agent role -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=1\nEOF"}}'
        Assert "sh: shell redirect into agent role without developer_instructions -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"shell","tool_input":{"command":"cat ~/.codex/agents/judge.toml"}}'
        Assert "sh: shell read agent role path -> allow (exit 0)" ($r.Code -eq 0)
        $r = Invoke-GuardSh '{"tool_name":"shell","tool_input":{"command":"cd ~/.codex/agents && cat > judge.toml <<EOF\nname=judge\nEOF"}}'
        Assert "sh: relative write after cd into agent role directory -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"shell","tool_input":{"command":"cp /tmp/source.toml ~/.codex/agents/evil.toml"}}'
        Assert "sh: cp into agent role directory -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=judge\ndeveloper_instructions=\"\"\"test\"\"\"\nEOF"}}'
        Assert "sh: shell heredoc with developer_instructions -> deny (exit 2)" ($r.Code -eq 2)
    } else {
        Write-Host "bash+python3 not both found; skipping POSIX dispatcher tests."
    }

    # --- Node.js guard (sdd-hook-guard.js / kill-switch.js) when node is available ---
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        function Invoke-GuardNode {
            param([string]$Payload, [string]$EmitMode = "exit")
            $outFile = Join-Path $workDir ("node-" + [guid]::NewGuid() + ".txt")
            $Payload | & node (Join-Path $scriptsDir "sdd-hook-guard.js") "--emit" $EmitMode > $outFile 2>$null
            $code = $LASTEXITCODE
            $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
            return @{ Code = $code; Out = $out }
        }

        function Invoke-KillSwitchNode {
            param([string]$Cwd, [string]$ProjectDir = $null)
            $savedDir = $env:CLAUDE_PROJECT_DIR
            if ($ProjectDir) { $env:CLAUDE_PROJECT_DIR = $ProjectDir } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
            try {
                Push-Location $Cwd
                & node (Join-Path $scriptsDir "kill-switch.js") *> $null
                return $LASTEXITCODE
            } finally {
                Pop-Location
                if ($savedDir) { $env:CLAUDE_PROJECT_DIR = $savedDir } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
            }
        }

        # --- Edit payload adding Approval: Approved -> deny ---
        $r = Invoke-GuardNode '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
        Assert "node: edit adds approval -> deny (exit 2)" ($r.Code -eq 2)

        # --- status-only change -> allow ---
        $r = Invoke-GuardNode '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Status: Planned","new_string":"Status: In Progress"}}'
        Assert "node: status-only change -> allow (exit 0)" ($r.Code -eq 0)

        # --- Write content payload: same count -> allow; extra approval -> deny ---
        $r = Invoke-GuardNode $payloadN
        Assert "node: write content same count -> allow" ($r.Code -eq 0)
        $r = Invoke-GuardNode $payloadN1
        Assert "node: write content extra approval -> deny" ($r.Code -eq 2)

        # --- apply_patch adding Approval: Approved to tasks.md -> deny ---
        $r = Invoke-GuardNode $patchDeny
        Assert "node: apply_patch adds approval to tasks.md -> deny" ($r.Code -eq 2)

        # --- apply_patch to another file -> allow ---
        $r = Invoke-GuardNode $patchOther
        Assert "node: apply_patch to other file -> allow" ($r.Code -eq 0)

        # --- shell echo Approval >> tasks.md -> deny ---
        $r = Invoke-GuardNode $shellDeny
        Assert "node: shell appends approval to tasks.md -> deny" ($r.Code -eq 2)

        # --- copilot emit: allow case -> valid JSON allow, exit 0 ---
        $r = Invoke-GuardNode '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}' "copilot"
        $okJson = $false
        try { $okJson = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "allow") } catch { }
        Assert "node: copilot allow -> JSON allow, exit 0" ($r.Code -eq 0 -and $okJson)

        # --- copilot emit: deny case -> valid JSON deny, exit 0 ---
        $r = Invoke-GuardNode '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
        $okDeny = $false
        try { $okDeny = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "deny") } catch { }
        Assert "node: copilot deny -> JSON deny, exit 0" ($r.Code -eq 0 -and $okDeny)

        # --- malformed payload -> deny ---
        $r = Invoke-GuardNode 'this is not json'
        Assert "node: malformed payload -> deny (exit 2)" ($r.Code -eq 2)

        # --- Agent-role guard tests for Node.js ---
        # 1. DENY: Write-style payload to agent role path without developer_instructions
        $r = Invoke-GuardNode '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\n"}}'
        Assert "node: Write agent role without developer_instructions -> deny (exit 2)" ($r.Code -eq 2)

        # 2. ALLOW: Write-style payload to agent role path WITH developer_instructions
        $r = Invoke-GuardNode '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\ndeveloper_instructions = \"\"\"test\"\"\"\n"}}'
        Assert "node: Write agent role with developer_instructions -> allow (exit 0)" ($r.Code -eq 0)

        # 3. ALLOW: Write-style payload lacking developer_instructions key to NON-agent path
        $r = Invoke-GuardNode '{"tool_name":"Write","tool_input":{"file_path":"/tmp/pyproject.toml","content":"name = \"project\"\n"}}'
        Assert "node: Write to non-agent path -> allow (exit 0)" ($r.Code -eq 0)

        # 4. DENY: apply_patch Add File targeting agent role path with empty body
        $r = Invoke-GuardNode '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
        Assert "node: apply_patch Add File agent role with empty body -> deny (exit 2)" ($r.Code -eq 2)

        # 4b. ALLOW: apply_patch Add File with developer_instructions
        $r = Invoke-GuardNode '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n+name = \"regression-judge\"\n+developer_instructions = \"\"\"test\"\"\"\n*** End Patch"}}'
        Assert "node: apply_patch Add File agent role with developer_instructions -> allow (exit 0)" ($r.Code -eq 0)

        # 4c. DENY: apply_patch Delete File targeting agent role path
        $r = Invoke-GuardNode '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Delete File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
        Assert "node: apply_patch Delete File agent role -> deny (exit 2)" ($r.Code -eq 2)

        # 5. DENY: apply_patch Update File section touching agent role path (partial diff)
        $r = Invoke-GuardNode '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: /home/u/.codex/agents/judge.toml\n-name = \"old\"\n+name = \"judge\"\n*** End Patch"}}'
        Assert "node: apply_patch Update File agent role -> deny (exit 2)" ($r.Code -eq 2)

        # 6. DENY: shell payload redirect into agent role path without developer_instructions in command
        $r = Invoke-GuardNode '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=1\nEOF"}}'
        Assert "node: shell redirect into agent role without developer_instructions -> deny (exit 2)" ($r.Code -eq 2)

        # 7. ALLOW: shell payload read from agent role path (no redirect)
        $r = Invoke-GuardNode '{"tool_name":"shell","tool_input":{"command":"cat ~/.codex/agents/judge.toml"}}'
        Assert "node: shell read agent role path -> allow (exit 0)" ($r.Code -eq 0)
        $r = Invoke-GuardNode '{"tool_name":"shell","tool_input":{"command":"cd ~/.codex/agents && cat > judge.toml <<EOF\nname=judge\nEOF"}}'
        Assert "node: relative write after cd into agent role directory -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardNode '{"tool_name":"shell","tool_input":{"command":"cp /tmp/source.toml ~/.codex/agents/evil.toml"}}'
        Assert "node: cp into agent role directory -> deny (exit 2)" ($r.Code -eq 2)

        # 8. DENY: shell heredoc command containing developer_instructions still counts as a write
        $r = Invoke-GuardNode '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=judge\ndeveloper_instructions=\"\"\"test\"\"\"\nEOF"}}'
        Assert "node: shell heredoc with developer_instructions -> deny (exit 2)" ($r.Code -eq 2)

        # --- kill-switch.js: AGENT_STOP absent via CLAUDE_PROJECT_DIR -> 0 ---
        $ksNodeDir = Join-Path $workDir "ks-node"
        New-Item -ItemType Directory -Path $ksNodeDir -Force | Out-Null
        Assert "node: kill-switch absent -> 0" ((Invoke-KillSwitchNode $ksNodeDir $ksNodeDir) -eq 0)

        # --- kill-switch.js: AGENT_STOP present via CLAUDE_PROJECT_DIR -> 2 ---
        "stop" | Set-Content -Encoding Utf8 (Join-Path $ksNodeDir "AGENT_STOP")
        Assert "node: kill-switch present -> 2" ((Invoke-KillSwitchNode $ksNodeDir $ksNodeDir) -eq 2)
    } else {
        Write-Host "node not found; skipping Node.js guard tests."
    }

    # =========================================================
    # Wave 2 additions
    # =========================================================

    # 4a. MultiEdit edits[] payload: deny if edits add approval to tasks.md
    $multiEditDeny = '{"tool_name":"MultiEdit","tool_input":{"file_path":"/p/specs/x/tasks.md","edits":[{"old_string":"Approval: Draft","new_string":"Approval: Approved"}]}}'
    $r = Invoke-GuardPs $multiEditDeny
    Assert "ps: MultiEdit edits[] approval in tasks.md -> deny" ($r.Code -eq 2)

    # 4b. Case-insensitive path test: file_path ending TASKS.MD (uppercase) -> deny
    $upperPathDeny = '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/TASKS.MD","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    $r = Invoke-GuardPs $upperPathDeny
    Assert "ps: TASKS.MD uppercase path -> deny" ($r.Code -eq 2)

    # 4c. Write content-mode to a NONEXISTENT tasks.md with Approval: Approved in content -> deny
    $nonexistentTasksPath = Join-Path $workDir "nonexistent-tasks.md"
    # Ensure it doesn't exist (file on disk = 0 approvals -> 1 in content = increase)
    if (Test-Path $nonexistentTasksPath) { Remove-Item $nonexistentTasksPath }
    $writeNewDeny = (@{ tool_name = "Write"; tool_input = @{ file_path = $nonexistentTasksPath; content = "Approval: Approved" } } | ConvertTo-Json -Compress -Depth 5)
    $r = Invoke-GuardPs $writeNewDeny
    Assert "ps: Write to nonexistent tasks.md with approval -> deny" ($r.Code -eq 2)

    # 4d. Kill-switch dual-path test: AGENT_STOP in cwd while CLAUDE_PROJECT_DIR points elsewhere
    $ksDualCwd = Join-Path $workDir "ks-dual-cwd"
    $ksDualProject = Join-Path $workDir "ks-dual-project"
    New-Item -ItemType Directory -Path $ksDualCwd -Force | Out-Null
    New-Item -ItemType Directory -Path $ksDualProject -Force | Out-Null
    # Place AGENT_STOP in cwd, NOT in CLAUDE_PROJECT_DIR
    "stop" | Set-Content -Encoding Utf8 (Join-Path $ksDualCwd "AGENT_STOP")
    $env:CLAUDE_PROJECT_DIR = $ksDualProject  # points elsewhere (no AGENT_STOP there)
    $dualResult = $null
    try {
        Push-Location $ksDualCwd
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "kill-switch.ps1") *> $null
        $dualResult = $LASTEXITCODE
    } finally { Pop-Location }
    Assert "ps: kill-switch cwd has AGENT_STOP while CLAUDE_PROJECT_DIR doesn't -> 2" ($dualResult -eq 2)
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue

    # Node.js MultiEdit, case-insensitive, Write-nonexistent, and kill-switch dual-path
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        function Invoke-GuardNodeLocal {
            param([string]$Payload, [string]$EmitMode = "exit")
            $outFile = Join-Path $workDir ("node2-" + [guid]::NewGuid() + ".txt")
            $Payload | & node (Join-Path $scriptsDir "sdd-hook-guard.js") "--emit" $EmitMode > $outFile 2>$null
            $code = $LASTEXITCODE
            $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
            return @{ Code = $code; Out = $out }
        }

        $r = Invoke-GuardNodeLocal $multiEditDeny
        Assert "node: MultiEdit edits[] approval -> deny" ($r.Code -eq 2)

        $r = Invoke-GuardNodeLocal $upperPathDeny
        Assert "node: TASKS.MD uppercase -> deny" ($r.Code -eq 2)

        $r = Invoke-GuardNodeLocal $writeNewDeny
        Assert "node: Write nonexistent tasks.md with approval -> deny" ($r.Code -eq 2)

        # Kill-switch dual-path for node
        $env:CLAUDE_PROJECT_DIR = $ksDualProject
        $nodeDualResult = $null
        try {
            Push-Location $ksDualCwd
            & node (Join-Path $scriptsDir "kill-switch.js") *> $null
            $nodeDualResult = $LASTEXITCODE
        } finally { Pop-Location }
        Assert "node: kill-switch cwd AGENT_STOP while CLAUDE_PROJECT_DIR elsewhere -> 2" ($nodeDualResult -eq 2)
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    } else {
        Write-Host "node not found; skipping Wave-2 Node.js kill-switch dual-path test."
    }

    # 4d: kill-switch.sh dual-path (bash conditional)
    $bash2 = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash2) {
        $env:CLAUDE_PROJECT_DIR = $ksDualProject
        $shDualResult = $null
        try {
            Push-Location $ksDualCwd
            & bash (Join-Path $scriptsDir "kill-switch.sh") *> $null
            $shDualResult = $LASTEXITCODE
        } finally { Pop-Location }
        Assert "sh: kill-switch cwd AGENT_STOP while CLAUDE_PROJECT_DIR elsewhere -> 2" ($shDualResult -eq 2)
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    } else {
        Write-Host "bash not found; skipping Wave-2 sh kill-switch dual-path test."
    }

    # 4e. Direct python3 sdd-hook-guard.py tests
    # Functional probe rather than Get-Command alone: on Windows, "python3" can
    # resolve to the Microsoft Store alias stub, which is not a working Python.
    $py3 = $null
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        try {
            if ((& python3 -c "print(123)" 2>$null) -eq "123") { $py3 = $true }
        } catch { }
    }
    if ($py3) {
        function Invoke-GuardPy {
            param([string]$Payload, [string]$EmitMode = "exit")
            $outFile = Join-Path $workDir ("py-" + [guid]::NewGuid() + ".txt")
            $Payload | & python3 (Join-Path $scriptsDir "sdd-hook-guard.py") "--emit" $EmitMode > $outFile 2>$null
            $code = $LASTEXITCODE
            $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
            return @{ Code = $code; Out = $out }
        }

        # basic deny
        $r = Invoke-GuardPy '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
        Assert "py: edit adds approval -> deny (exit 2)" ($r.Code -eq 2)

        # basic allow
        $r = Invoke-GuardPy '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Status: Planned","new_string":"Status: In Progress"}}'
        Assert "py: status-only change -> allow (exit 0)" ($r.Code -eq 0)

        # malformed
        $r = Invoke-GuardPy 'this is not json'
        Assert "py: malformed payload -> deny (exit 2)" ($r.Code -eq 2)

        # copilot mode deny
        $r = Invoke-GuardPy '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
        $okDenyPy = $false
        try { $okDenyPy = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "deny") } catch { }
        Assert "py: copilot deny -> JSON deny, exit 0" ($r.Code -eq 0 -and $okDenyPy)

        # copilot mode allow
        $r = Invoke-GuardPy '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}' "copilot"
        $okAllowPy = $false
        try { $okAllowPy = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "allow") } catch { }
        Assert "py: copilot allow -> JSON allow, exit 0" ($r.Code -eq 0 -and $okAllowPy)

        # TTY-no-hang: run with </dev/null (stdin redirected, not a TTY) - should allow
        if ($bash2) {
            $ttyResult = $null
            $ttyResult = & bash -c ("python3 '" + (Join-Path $scriptsDir "sdd-hook-guard.py").Replace("'","'\\''") + "' < /dev/null; echo $?") 2>$null
            # Should exit 0 (allow)
            Assert "py: TTY guard with empty stdin does not hang -> allow" ($ttyResult -match "^0$" -or ($LASTEXITCODE -eq 0))
        }

        # 4f. Assert js and py --emit copilot outputs are byte-identical for both allow and deny
        if ($node) {
            # allow case
            $allowPayload = '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}'
            $jsAllow = Invoke-GuardNodeLocal $allowPayload "copilot"
            $pyAllow = Invoke-GuardPy $allowPayload "copilot"
            Assert "js/py copilot allow output byte-identical" ($jsAllow.Out -eq $pyAllow.Out)

            # deny case
            $denyPayload = '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
            $jsDeny = Invoke-GuardNodeLocal $denyPayload "copilot"
            $pyDeny = Invoke-GuardPy $denyPayload "copilot"
            Assert "js/py copilot deny output byte-identical" ($jsDeny.Out -eq $pyDeny.Out)
        } else {
            Write-Host "node not found; skipping js/py byte-identical comparison."
        }

        # py MultiEdit
        $r = Invoke-GuardPy $multiEditDeny
        Assert "py: MultiEdit edits[] approval -> deny" ($r.Code -eq 2)

        # py uppercase TASKS.MD
        $r = Invoke-GuardPy $upperPathDeny
        Assert "py: TASKS.MD uppercase -> deny" ($r.Code -eq 2)

        # py Write to nonexistent tasks.md
        $r = Invoke-GuardPy $writeNewDeny
        Assert "py: Write nonexistent tasks.md with approval -> deny" ($r.Code -eq 2)
    } else {
        Write-Host "python3 not found; skipping direct py guard tests."
    }

    # =========================================================
    # (end Wave 2 additions)
    # =========================================================

    # =========================================================
    # Sudo mode (SDD_SUDO flag) tests — PowerShell guard
    # =========================================================

    # C-04: Export a known test key for all sudo tests so both Write-SudoFlag
    # (signing) and the guard's verification use the same key.
    $env:SDD_SUDO_KEY = "test-key-do-not-use"

    # Test a: valid sudo (future epoch) + Edit payload that increases Approval -> ALLOW
    $sudoDirA = Join-Path $workDir "sudo-ps-a"
    New-Item -ItemType Directory -Path $sudoDirA -Force | Out-Null
    $sudoEpoch = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) + 3600
    Write-SudoFlag $sudoDirA $sudoEpoch
    $sudoPayload = '{"tool_name":"Edit","tool_input":{"file_path":"tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    Push-Location $sudoDirA
    $sudoRa = $null
    try {
        $sudoRa = Invoke-GuardPs $sudoPayload "exit"
    } finally { Pop-Location }
    Assert "ps sudo: valid future epoch + approval increase -> allow (exit 0)" ($sudoRa.Code -eq 0)
    Remove-Item -Recurse -Force $sudoDirA -ErrorAction SilentlyContinue

    # Test b: expired sudo (past epoch) + same payload -> DENY
    $sudoDirB = Join-Path $workDir "sudo-ps-b"
    New-Item -ItemType Directory -Path $sudoDirB -Force | Out-Null
    $expiredEpoch = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - 10
    Write-SudoFlag $sudoDirB $expiredEpoch
    Push-Location $sudoDirB
    $sudoRb = $null
    try {
        $sudoRb = Invoke-GuardPs $sudoPayload "exit"
    } finally { Pop-Location }
    Assert "ps sudo: expired epoch + approval increase -> deny (exit 2)" ($sudoRb.Code -eq 2)
    Remove-Item -Recurse -Force $sudoDirB -ErrorAction SilentlyContinue

    # Test c: malformed flag (no expires-epoch line) + same payload -> DENY
    $sudoDirC = Join-Path $workDir "sudo-ps-c"
    New-Item -ItemType Directory -Path $sudoDirC -Force | Out-Null
    "some-other-field: value" | Set-Content -Encoding Utf8 (Join-Path $sudoDirC "SDD_SUDO")
    Push-Location $sudoDirC
    $sudoRc = $null
    try {
        $sudoRc = Invoke-GuardPs $sudoPayload "exit"
    } finally { Pop-Location }
    Assert "ps sudo: malformed flag + approval increase -> deny (exit 2)" ($sudoRc.Code -eq 2)
    Remove-Item -Recurse -Force $sudoDirC -ErrorAction SilentlyContinue

    # Test d: valid sudo AND AGENT_STOP both present -> DENY (kill switch wins)
    $sudoDirD = Join-Path $workDir "sudo-ps-d"
    New-Item -ItemType Directory -Path $sudoDirD -Force | Out-Null
    Write-SudoFlag $sudoDirD $sudoEpoch
    "stop" | Set-Content -Encoding Utf8 (Join-Path $sudoDirD "AGENT_STOP")
    Push-Location $sudoDirD
    $sudoRd = $null
    try {
        $sudoRd = Invoke-GuardPs $sudoPayload "exit"
    } finally { Pop-Location }
    Assert "ps sudo: valid sudo + AGENT_STOP -> deny (exit 2, kill switch wins)" ($sudoRd.Code -eq 2)
    Remove-Item -Recurse -Force $sudoDirD -ErrorAction SilentlyContinue

    # Test e: valid sudo + invalid agent-role Write payload -> DENY (sudo does not bypass check 3)
    $sudoDirE = Join-Path $workDir "sudo-ps-e"
    New-Item -ItemType Directory -Path $sudoDirE -Force | Out-Null
    Write-SudoFlag $sudoDirE $sudoEpoch
    $agentPayload = '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\foo.toml","content":"name = \"foo\"\n"}}'
    Push-Location $sudoDirE
    $sudoRe = $null
    try {
        $sudoRe = Invoke-GuardPs $agentPayload "exit"
    } finally { Pop-Location }
    Assert "ps sudo: valid sudo + invalid agent role -> deny (exit 2, check 3 not bypassed)" ($sudoRe.Code -eq 2)
    Remove-Item -Recurse -Force $sudoDirE -ErrorAction SilentlyContinue

    # Node.js sudo mode tests (if node available)
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        # Test a: valid sudo + approval increase -> ALLOW
        $sudoDirNodeA = Join-Path $workDir "sudo-node-ps-a"
        New-Item -ItemType Directory -Path $sudoDirNodeA -Force | Out-Null
        Write-SudoFlag $sudoDirNodeA $sudoEpoch
        Push-Location $sudoDirNodeA
        $sudoNodeRa = Invoke-GuardNode $sudoPayload "exit"
        Pop-Location
        Assert "node sudo (ps context): valid future epoch + approval increase -> allow (exit 0)" ($sudoNodeRa.Code -eq 0)
        Remove-Item -Recurse -Force $sudoDirNodeA -ErrorAction SilentlyContinue

        # Test b: expired sudo + approval increase -> DENY
        $sudoDirNodeB = Join-Path $workDir "sudo-node-ps-b"
        New-Item -ItemType Directory -Path $sudoDirNodeB -Force | Out-Null
        Write-SudoFlag $sudoDirNodeB $expiredEpoch
        Push-Location $sudoDirNodeB
        $sudoNodeRb = Invoke-GuardNode $sudoPayload "exit"
        Pop-Location
        Assert "node sudo (ps context): expired epoch + approval increase -> deny (exit 2)" ($sudoNodeRb.Code -eq 2)
        Remove-Item -Recurse -Force $sudoDirNodeB -ErrorAction SilentlyContinue

        # Test c: malformed flag + approval increase -> DENY
        $sudoDirNodeC = Join-Path $workDir "sudo-node-ps-c"
        New-Item -ItemType Directory -Path $sudoDirNodeC -Force | Out-Null
        "some-other-field: value" | Set-Content -Encoding Utf8 (Join-Path $sudoDirNodeC "SDD_SUDO")
        Push-Location $sudoDirNodeC
        $sudoNodeRc = Invoke-GuardNode $sudoPayload "exit"
        Pop-Location
        Assert "node sudo (ps context): malformed flag + approval increase -> deny (exit 2)" ($sudoNodeRc.Code -eq 2)
        Remove-Item -Recurse -Force $sudoDirNodeC -ErrorAction SilentlyContinue

        # Test d: valid sudo + AGENT_STOP both present -> DENY
        $sudoDirNodeD = Join-Path $workDir "sudo-node-ps-d"
        New-Item -ItemType Directory -Path $sudoDirNodeD -Force | Out-Null
        Write-SudoFlag $sudoDirNodeD $sudoEpoch
        "stop" | Set-Content -Encoding Utf8 (Join-Path $sudoDirNodeD "AGENT_STOP")
        Push-Location $sudoDirNodeD
        $sudoNodeRd = Invoke-GuardNode $sudoPayload "exit"
        Pop-Location
        Assert "node sudo (ps context): valid sudo + AGENT_STOP -> deny (exit 2)" ($sudoNodeRd.Code -eq 2)
        Remove-Item -Recurse -Force $sudoDirNodeD -ErrorAction SilentlyContinue

        # Test e: valid sudo + invalid agent role -> DENY
        $sudoDirNodeE = Join-Path $workDir "sudo-node-ps-e"
        New-Item -ItemType Directory -Path $sudoDirNodeE -Force | Out-Null
        Write-SudoFlag $sudoDirNodeE $sudoEpoch
        Push-Location $sudoDirNodeE
        $sudoNodeRe = Invoke-GuardNode $agentPayload "exit"
        Pop-Location
        Assert "node sudo (ps context): valid sudo + invalid agent role -> deny (exit 2)" ($sudoNodeRe.Code -eq 2)
        Remove-Item -Recurse -Force $sudoDirNodeE -ErrorAction SilentlyContinue
    }

    # =========================================================
    # WFI approval guard — 'Status: Approved' in workflow-improvements/*.md is
    # human-only and NEVER bypassed by sudo (mirrors tasks.md approval guard).
    # =========================================================
    $wfiApprove = '{"tool_name":"Edit","tool_input":{"file_path":"/p/docs/workflow-improvements/WFI-001.md","old_string":"Status: Draft","new_string":"Status: Approved"}}'
    $r = Invoke-GuardPs $wfiApprove
    Assert "ps: WFI Edit Status: Approved -> deny (exit 2)" ($r.Code -eq 2)

    $wfiApplied = '{"tool_name":"Edit","tool_input":{"file_path":"/p/docs/workflow-improvements/WFI-001.md","old_string":"Status: Draft","new_string":"Status: Applied"}}'
    $r = Invoke-GuardPs $wfiApplied
    Assert "ps: WFI Edit Status: Applied -> allow (exit 0)" ($r.Code -eq 0)

    $wfiPatch = "{`"tool_name`":`"apply_patch`",`"tool_input`":{`"command`":`"*** Begin Patch\n*** Update File: docs/workflow-improvements/WFI-002.md\n-Status: Draft\n+Status: Approved\n*** End Patch`"}}"
    $r = Invoke-GuardPs $wfiPatch
    Assert "ps: WFI apply_patch Status: Approved -> deny (exit 2)" ($r.Code -eq 2)

    # KEY: WFI approval is NOT bypassed by valid sudo.
    $wfiSudoDir = Join-Path $workDir "wfi-sudo-ps"
    New-Item -ItemType Directory -Path $wfiSudoDir -Force | Out-Null
    Write-SudoFlag $wfiSudoDir $sudoEpoch
    $wfiSudoPayload = '{"tool_name":"Edit","tool_input":{"file_path":"docs/workflow-improvements/WFI-001.md","old_string":"Status: Draft","new_string":"Status: Approved"}}'
    Push-Location $wfiSudoDir
    $wfiSudoR = $null
    try { $wfiSudoR = Invoke-GuardPs $wfiSudoPayload "exit" } finally { Pop-Location }
    Assert "ps sudo: WFI Status: Approved denied even with valid sudo (exit 2)" ($wfiSudoR.Code -eq 2)
    Remove-Item -Recurse -Force $wfiSudoDir -ErrorAction SilentlyContinue

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        $r = Invoke-GuardNode $wfiApprove
        Assert "node: WFI Edit Status: Approved -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardNode $wfiApplied
        Assert "node: WFI Edit Status: Applied -> allow (exit 0)" ($r.Code -eq 0)
        $r = Invoke-GuardNode $wfiPatch
        Assert "node: WFI apply_patch Status: Approved -> deny (exit 2)" ($r.Code -eq 2)
    }

    # Clear the test signing key after the sudo test section.
    Remove-Item Env:\SDD_SUDO_KEY -ErrorAction SilentlyContinue
    # --- hooks.json parses; referenced scripts exist; each entry has command_windows ---
    $hooksJson = Get-Content -Raw -Encoding Utf8 (Join-Path $hooksDir "hooks.json") | ConvertFrom-Json
    Assert "hooks.json parses with PreToolUse" ($null -ne $hooksJson.hooks.PreToolUse)
    foreach ($entry in $hooksJson.hooks.PreToolUse) {
        foreach ($h in $entry.hooks) {
            Assert "hooks.json entry has command_windows" ($null -ne $h.command_windows -and $h.command_windows -ne "")
            # Extract the referenced script filename(s) and confirm existence.
            foreach ($scriptName in @("kill-switch.sh", "kill-switch.ps1", "sdd-hook-guard.sh", "sdd-hook-guard.ps1")) {
                if ($h.command -match [regex]::Escape($scriptName) -or $h.command_windows -match [regex]::Escape($scriptName)) {
                    Assert "hooks.json references existing script $scriptName" (Test-Path (Join-Path $scriptsDir $scriptName))
                }
            }
        }
    }
    $guardMatchers = $hooksJson.hooks.PreToolUse | Select-Object -ExpandProperty matcher
    Assert "hooks.json matcher covers shell tools" (($guardMatchers -join " ") -match "shell" -and ($guardMatchers -join " ") -match "exec_command")

    # --- copilot-hooks.json parses; version 1; preToolUse entries have bash + powershell ---
    $copJson = Get-Content -Raw -Encoding Utf8 (Join-Path $hooksDir "copilot-hooks.json") | ConvertFrom-Json
    Assert "copilot-hooks.json version 1" ($copJson.version -eq 1)
    Assert "copilot-hooks.json has preToolUse" ($null -ne $copJson.hooks.preToolUse)
    foreach ($e in $copJson.hooks.preToolUse) {
        Assert "copilot-hooks.json entry has bash" ($null -ne $e.bash -and $e.bash -ne "")
        Assert "copilot-hooks.json entry has powershell" ($null -ne $e.powershell -and $e.powershell -ne "")
        Assert "copilot-hooks.json bash fallback is deny" ($e.bash -match '"permissionDecision":"deny"')
        Assert "copilot-hooks.json powershell fallback is deny" ($e.powershell -match '"permissionDecision":"deny"')
    }

    if ($failures -gt 0) { throw "$failures hook test(s) failed." }
    Write-Host "Hook guard tests passed."
} finally {
    Pop-Location
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above
# (e.g. a guard test that intentionally exits 2 on deny).
exit 0
