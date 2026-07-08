$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$workflowStateValidator = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1"
$workflowStateArguments = @("-NoProfile", "-File", $workflowStateValidator)
& (Get-Process -Id $PID).Path @workflowStateArguments
if ($LASTEXITCODE -ne 0) {
    throw "Workflow-state validation failed with exit code $LASTEXITCODE."
}

$expectedPlugins = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop", "sdd-ship", "sdd-domain")
$expectedSkills = @("sdd-bootstrap-interviewer", "investigate-codebase", "implement-task", "quality-gate", "fix-by-review-ticket", "workflow-retrospective", "sdd-adopt", "sdd-sudo", "cross-model-verify", "lite-spec", "lite-gate", "implement-tasks", "diagnose", "spec-review-loop", "impl-review-loop", "task-review-loop", "wfi-audit-cycle", "bootstrap", "ship", "design-sync-loop", "visual-verify-loop", "domain-model", "domain-interviewer", "domain-reverse", "domain-review-loop", "domain-sync")
$expectedVersions = @{
    "sdd-bootstrap"      = "1.10.0"
    "sdd-implementation" = "1.10.0"
    "sdd-quality-loop"   = "1.10.0"
    "sdd-lite"           = "1.10.0"
    "sdd-review-loop"    = "1.10.0"
    "sdd-ship"           = "1.10.0"
    "sdd-domain"         = "1.10.0"
}
$releasePlugins = $expectedPlugins

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path $path)) {
        throw "Missing required file: $RelativePath"
    }
    return Get-Content -Raw -Encoding Utf8 $path | ConvertFrom-Json
}

$readmeLines = Get-Content -Encoding Utf8 (Join-Path $repositoryRoot "README.md")
$readmeCurrentRelease = $readmeLines |
    Where-Object { $_ -match "^v\d+\.\d+\.\d+(?:\s|$)" } |
    Select-Object -First 1
if ($null -eq $readmeCurrentRelease -or $readmeCurrentRelease -notmatch "^v1\.10\.0(?:\s|$)") {
    throw "README.md current release must be v1.10.0."
}

$changelog = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "CHANGELOG.md")
$currentReleaseHeadings = [regex]::Matches($changelog, "(?m)^## v1\.10\.0(?:\s|$)")
if ($currentReleaseHeadings.Count -ne 1) {
    throw "CHANGELOG.md must contain exactly one v1.10.0 release heading."
}

$codexMarketplace = Read-JsonFile ".agents/plugins/marketplace.json"
$claudeMarketplace = Read-JsonFile ".claude-plugin/marketplace.json"

foreach ($name in $expectedPlugins) {
    if ($name -notin $codexMarketplace.plugins.name) {
        throw "Codex marketplace does not contain $name."
    }
    if ($name -notin $claudeMarketplace.plugins.name) {
        throw "Claude marketplace does not contain $name."
    }

    $codexManifest = Read-JsonFile "plugins/$name/.codex-plugin/plugin.json"
    $claudeManifest = Read-JsonFile "plugins/$name/.claude-plugin/plugin.json"
    $copilotManifest = Read-JsonFile "plugins/$name/.plugin/plugin.json"
    if ($codexManifest.name -ne $name -or $claudeManifest.name -ne $name -or $copilotManifest.name -ne $name) {
        throw "Plugin directory and manifest names differ for $name."
    }
    $expectedVersion = $expectedVersions[$name]
    if ($codexManifest.version -ne $expectedVersion -or $claudeManifest.version -ne $expectedVersion -or $copilotManifest.version -ne $expectedVersion) {
        throw "Plugin version differs from $expectedVersion for $name."
    }
}

foreach ($plugin in $claudeMarketplace.plugins) {
    if ($plugin.name -notin $expectedVersions.Keys) { continue }
    $expectedVersion = $expectedVersions[$plugin.name]
    if ($plugin.version -ne $expectedVersion) {
        throw "Claude marketplace version differs from $expectedVersion for $($plugin.name)."
    }
}

# Every plugin carries the same explicit release version in both host
# marketplaces so cache recovery and host discovery are unambiguous.
foreach ($name in $releasePlugins) {
    $expectedVersion = $expectedVersions[$name]
    $codexEntry = @($codexMarketplace.plugins | Where-Object { $_.name -eq $name })
    $claudeEntry = @($claudeMarketplace.plugins | Where-Object { $_.name -eq $name })
    if ($codexEntry.Count -ne 1 -or $claudeEntry.Count -ne 1) {
        throw "Expected exactly one marketplace entry for release plugin $name."
    }
    if ($codexEntry[0].version -ne $expectedVersion -or $claudeEntry[0].version -ne $expectedVersion) {
        throw "Marketplace version differs from $expectedVersion for $name."
    }
    if ([version]$expectedVersion -le [version]"1.1.0") {
        throw "Release plugin version must be newer than 1.1.0 for $name."
    }
}

$skillFiles = Get-ChildItem (Join-Path $repositoryRoot "plugins") -Recurse -Filter "SKILL.md"
$skillNames = foreach ($skillFile in $skillFiles) {
    $content = Get-Content -Raw -Encoding Utf8 $skillFile.FullName
    if ($content -notmatch "(?m)^name:\s*(.+)$") {
        throw "Skill has no name: $($skillFile.FullName)"
    }
    $Matches[1].Trim()
}
if (@($skillNames).Count -ne $expectedSkills.Count) {
    throw "Expected $($expectedSkills.Count) public skills but found $(@($skillNames).Count): $($skillNames -join ', ')"
}
foreach ($name in $expectedSkills) {
    if ($name -notin $skillNames) {
        throw "Missing public skill: $name"
    }
}

$forbiddenPaths = @(
    "plugins/sdd-quality-loop/skills/update-traceability/SKILL.md",
    "plugins/sdd-quality-loop/templates/traceability.template.md",
    "plugins/sdd-quality-loop/templates/ci-report.template.md",
    # Superseded by sdd-hook-guard; must NOT reappear.
    "plugins/sdd-quality-loop/scripts/guard-task-approval.sh",
    "plugins/sdd-quality-loop/scripts/guard-task-approval.ps1",
    # Merged into sdd-review-loop; must NOT reappear (ADR-002).
    "plugins/sdd-impl-review",
    "plugins/sdd-task-review"
)
foreach ($relativePath in $forbiddenPaths) {
    if (Test-Path (Join-Path $repositoryRoot $relativePath)) {
        throw "Obsolete path still exists: $relativePath"
    }
}

$requiredFiles = @(
    "USERGUIDE.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-github.template.yml",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-gitlab.template.yml",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ai-task.template.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/gitlab-issue.template.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/pull-request.template.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/merge-request.template.md",
    "plugins/sdd-implementation/templates/implementation-report.template.md",
    "plugins/sdd-quality-loop/templates/review-ticket.template.yml",
    "plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md",
    "plugins/sdd-bootstrap/skills/investigate-codebase/templates/investigation.template.md",
    "plugins/sdd-bootstrap/skills/investigate-codebase/templates/baseline-behavior.template.md",
    "plugins/sdd-bootstrap/skills/investigate-codebase/templates/codemap.template.md",
    "plugins/sdd-bootstrap/agents/investigator.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/architecture-review-checklist.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-context.template.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-container.template.md",
    "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-component.template.md",
    "plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md",
    "plugins/sdd-quality-loop/agents/evaluator.md",
    "plugins/sdd-quality-loop/hooks/hooks.json",
    "plugins/sdd-quality-loop/references/deterministic-check-policy.md",
    "plugins/sdd-quality-loop/references/differential-test-policy.md",
    "plugins/sdd-quality-loop/references/evaluation-rubric.md",
    "plugins/sdd-quality-loop/references/sudo-mode-policy.md",
    "plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md",
    "plugins/sdd-quality-loop/templates/verification-contract.template.json",
    "plugins/sdd-quality-loop/templates/evidence-bundle.template.json",
    "plugins/sdd-quality-loop/templates/retrospective-report.template.md",
    "plugins/sdd-quality-loop/templates/workflow-improvement.template.md",
    "plugins/sdd-bootstrap/.plugin/plugin.json",
    "plugins/sdd-implementation/.plugin/plugin.json",
    "plugins/sdd-quality-loop/.plugin/plugin.json",
    "plugins/sdd-quality-loop/hooks/copilot-hooks.json",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js",
    "plugins/sdd-quality-loop/scripts/kill-switch.ps1",
    "plugins/sdd-quality-loop/scripts/kill-switch.js",
    "plugins/sdd-quality-loop/hooks/claude-hooks.json",
    "plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md",
    "plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md",
    ".codex/agents/sdd-investigator.toml",
    ".codex/agents/sdd-evaluator.toml",
    "plugins/sdd-bootstrap/skills/sdd-adopt/SKILL.md",
    "plugins/sdd-bootstrap/scripts/check-sdd-structure.sh",
    "plugins/sdd-bootstrap/scripts/check-sdd-structure.ps1",
    "plugins/sdd-quality-loop/scripts/check-workflow-state.sh",
    "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1",
    "contracts/workflow-state-registry.schema.json",
    "specs/workflow-state-registry.json",
    "plugins/sdd-review-loop/.claude-plugin/plugin.json",
    "plugins/sdd-review-loop/.codex-plugin/plugin.json",
    "plugins/sdd-review-loop/.plugin/plugin.json",
    "plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md",
    "plugins/sdd-review-loop/skills/task-review-loop/SKILL.md"
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path (Join-Path $repositoryRoot $relativePath))) {
        throw "Missing required file: $relativePath"
    }
}

$reviewTicketTemplate = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/templates/review-ticket.template.yml")
foreach ($field in @("ticket_id:", "status:", "type:", "severity:", "target:", "summary:", "problem:", "expected_fix:", "references:", "auto_fix_allowed:", "requires_human_decision:", "review_cycles:")) {
    if ($reviewTicketTemplate -notmatch [regex]::Escape($field)) {
        throw "Review-ticket template is missing required field: $field"
    }
}

$tasksTemplate = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/tasks.template.md")
foreach ($field in @("Source Issue:", "Approval:", "Status:", "Goal", "Must Read", "Scope", "Done When", "Out of Scope", "Blockers")) {
    if ($tasksTemplate -notmatch [regex]::Escape($field)) {
        throw "Task template is missing required field: $field"
    }
}
foreach ($status in @("Draft", "Approved", "In Progress", "Blocked", "Implementation Complete", "Done")) {
    if ($tasksTemplate -notmatch [regex]::Escape($status)) {
        throw "Task template is missing lifecycle status: $status"
    }
}

$implementationSkill = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/SKILL.md")
foreach ($rule in @("Approved", "In Progress", "Blocked", "Implementation Complete", "git status", "git diff")) {
    if ($implementationSkill -notmatch [regex]::Escape($rule)) {
        throw "Implement-task skill is missing required rule: $rule"
    }
}

$qualitySkill = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md")
foreach ($rule in @("Implementation Complete", "maximum of 3", "Done", "Playwright", "traceability", "check-contract", "check-evidence-bundle", "check-placeholders", "check-task-state", "sdd-evaluator")) {
    if ($qualitySkill -notmatch [regex]::Escape($rule)) {
        throw "Quality-gate skill is missing required rule: $rule"
    }
}

# Deterministic gate scripts must exist as portable sh/ps1 pairs.
foreach ($script in @("check-contract", "check-evidence-bundle", "check-placeholders", "check-task-state")) {
    foreach ($extension in @("sh", "ps1")) {
        $scriptPath = "plugins/sdd-quality-loop/scripts/$script.$extension"
        if (-not (Test-Path (Join-Path $repositoryRoot $scriptPath))) {
            throw "Missing deterministic gate script: $scriptPath"
        }
    }
}
# Review-loop prechecks use the same portable contract on every supported host.
foreach ($script in @("review-contract-validate", "impl-review-precheck", "task-review-precheck")) {
    foreach ($extension in @("sh", "ps1")) {
        $scriptPath = "plugins/sdd-review-loop/scripts/$script.$extension"
        if (-not (Test-Path (Join-Path $repositoryRoot $scriptPath))) {
            throw "Missing portable review-loop script: $scriptPath"
        }
    }
}
# Evidence bundle runner must exist as portable sh/ps1 pair.
foreach ($extension in @("sh", "ps1")) {
    $scriptPath = "plugins/sdd-quality-loop/scripts/generate-evidence-bundle.$extension"
    if (-not (Test-Path (Join-Path $repositoryRoot $scriptPath))) {
        throw "Missing evidence bundle runner: $scriptPath"
    }
}
foreach ($scriptPath in @("plugins/sdd-quality-loop/scripts/kill-switch.sh")) {
    if (-not (Test-Path (Join-Path $repositoryRoot $scriptPath))) {
        throw "Missing hook script: $scriptPath"
    }
}

# ---------------------------------------------------------------------------
# Codex agent TOML validation
# ---------------------------------------------------------------------------
$agentSourceDir = Join-Path (Join-Path $repositoryRoot ".codex") "agents"
if (-not (Test-Path $agentSourceDir)) {
    throw "Missing required directory: .codex/agents"
}
foreach ($tomlFile in (Get-ChildItem -Path $agentSourceDir -Filter "*.toml")) {
    # The installers only copy sdd-*.toml; anything else would silently not install.
    if ($tomlFile.Name -notmatch '^sdd-.*\.toml$') {
        throw "Codex agent role file would not be installed (must be named sdd-*.toml): $($tomlFile.Name)"
    }
    $bytes = [System.IO.File]::ReadAllBytes($tomlFile.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "Codex agent role file has UTF-8 BOM (must not): $($tomlFile.Name)"
    }
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($content -match "`r") {
        throw "Codex agent role file contains CR characters (must be LF-only): $($tomlFile.Name)"
    }
    if ($content -notmatch '(?m)^name\s*=') {
        throw "Codex agent role file lacks required 'name =' line: $($tomlFile.Name)"
    }
    if ($content -notmatch '(?m)^description\s*=') {
        throw "Codex agent role file lacks required 'description =' line: $($tomlFile.Name)"
    }
    if ($content -notmatch '(?m)^developer_instructions\s*=\s*"""') {
        throw "Codex agent role file lacks a developer_instructions multiline string: $($tomlFile.Name)"
    }
    if ($content -notmatch '(?s)developer_instructions\s*=\s*"""\s*\S.*?"""') {
        throw "Codex agent role file has empty developer_instructions: $($tomlFile.Name)"
    }
}

# Policy regression markers
$agentPolicyFile = Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md"
if (Test-Path $agentPolicyFile) {
    $agentPolicyContent = Get-Content -Raw -Encoding Utf8 $agentPolicyFile
    if ($agentPolicyContent -notmatch [regex]::Escape("Agent Role File Rules (Codex)")) {
        throw "agent-delegation-policy.md missing required text: 'Agent Role File Rules (Codex)'"
    }
    if ($agentPolicyContent -notmatch [regex]::Escape("developer_instructions")) {
        throw "agent-delegation-policy.md missing required text: 'developer_instructions'"
    }
}

$qualityGateFile = Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
if (Test-Path $qualityGateFile) {
    $qualityGateContent = Get-Content -Raw -Encoding Utf8 $qualityGateFile
    if ($qualityGateContent -notmatch [regex]::Escape("do not create new agent role files")) {
        throw "quality-gate SKILL.md missing required text: 'do not create new agent role files'"
    }
}

$installPsFile = Join-Path $repositoryRoot "install.ps1"
if (Test-Path $installPsFile) {
    $installPsContent = Get-Content -Raw -Encoding Utf8 $installPsFile
    if ($installPsContent -notmatch [regex]::Escape("SDD_CODEX_HOME")) {
        throw "install.ps1 missing required text: 'SDD_CODEX_HOME'"
    }
    if ($installPsContent -notmatch [regex]::Escape("developer_instructions")) {
        throw "install.ps1 missing required text: 'developer_instructions'"
    }
}

$installShFile = Join-Path $repositoryRoot "install.sh"
if (Test-Path $installShFile) {
    $installShContent = Get-Content -Raw -Encoding Utf8 $installShFile
    if ($installShContent -notmatch [regex]::Escape("SDD_CODEX_HOME")) {
        throw "install.sh missing required text: 'SDD_CODEX_HOME'"
    }
    if ($installShContent -notmatch [regex]::Escape("developer_instructions")) {
        throw "install.sh missing required text: 'developer_instructions'"
    }
}

# Hooks must parse as JSON and reference only bundled scripts.
$hooksConfig = Read-JsonFile "plugins/sdd-quality-loop/hooks/hooks.json"
if (-not $hooksConfig.hooks.PreToolUse) {
    throw "hooks.json does not define PreToolUse hooks."
}
$allHookEntries = $hooksConfig.hooks.PreToolUse | ForEach-Object { $_.hooks } | Where-Object { $_ }
foreach ($hookEntry in $allHookEntries) {
    if (-not $hookEntry.command) {
        throw "hooks.json hook entry is missing 'command' field."
    }
    if (-not $hookEntry.command_windows) {
        throw "hooks.json hook entry is missing 'command_windows' field."
    }
}
$allMatchers = $hooksConfig.hooks.PreToolUse | Select-Object -ExpandProperty matcher
$hasApplyPatch = $allMatchers | Where-Object { $_ -match "apply_patch" }
if (-not $hasApplyPatch) {
    throw "hooks.json does not have any matcher containing 'apply_patch'."
}
$hasShellMatcher = $allMatchers | Where-Object { $_ -match "shell|Bash|exec_command|exec" }
if (-not $hasShellMatcher) {
    throw "hooks.json does not have any matcher containing shell tool names."
}

# copilot-hooks.json must parse and have expected structure.
$copilotHooks = Read-JsonFile "plugins/sdd-quality-loop/hooks/copilot-hooks.json"
if ($copilotHooks.version -ne 1) {
    throw "copilot-hooks.json version must be 1."
}
foreach ($entry in $copilotHooks.hooks.preToolUse) {
    if (-not $entry.bash) {
        throw "copilot-hooks.json preToolUse entry is missing 'bash' field."
    }
    if (-not $entry.powershell) {
        throw "copilot-hooks.json preToolUse entry is missing 'powershell' field."
    }
    if ($entry.bash -notmatch '"permissionDecision":"deny"') {
        throw "copilot-hooks.json bash fallback must deny when the guard is unavailable."
    }
    if ($entry.powershell -notmatch '"permissionDecision":"deny"') {
        throw "copilot-hooks.json powershell fallback must deny when the guard is unavailable."
    }
}

# claude-hooks.json must parse, define PreToolUse, and use exec-form Node.js hooks.
$claudeHooks = Read-JsonFile "plugins/sdd-quality-loop/hooks/claude-hooks.json"
if (-not $claudeHooks.hooks.PreToolUse) {
    throw "claude-hooks.json does not define PreToolUse hooks."
}
$claudeHookEntries = $claudeHooks.hooks.PreToolUse | ForEach-Object { $_.hooks } | Where-Object { $_ }
foreach ($entry in $claudeHookEntries) {
    if ($entry.command -ne "node") {
        throw "claude-hooks.json hook entry must have command = 'node' (found '$($entry.command)')."
    }
    if (-not $entry.args -or $entry.args.Count -eq 0) {
        throw "claude-hooks.json hook entry must have a non-empty 'args' array."
    }
    $firstArg = [string]$entry.args[0]
    if (-not $firstArg.StartsWith('${CLAUDE_PLUGIN_ROOT}')) {
        throw "claude-hooks.json hook entry first arg must start with '\${CLAUDE_PLUGIN_ROOT}' (found '$firstArg')."
    }
}

# .claude-plugin/plugin.json for sdd-quality-loop must reference claude-hooks.json.
$claudePluginManifest = Read-JsonFile "plugins/sdd-quality-loop/.claude-plugin/plugin.json"
if ($claudePluginManifest.hooks -ne "./hooks/claude-hooks.json") {
    throw ".claude-plugin/plugin.json for sdd-quality-loop must have hooks = './hooks/claude-hooks.json' (found '$($claudePluginManifest.hooks)')."
}

# .codex-plugin/plugin.json for sdd-quality-loop must have a hooks field pointing at hooks/hooks.json.
$codexPluginManifest = Read-JsonFile "plugins/sdd-quality-loop/.codex-plugin/plugin.json"
if ($codexPluginManifest.hooks -ne "./hooks/hooks.json") {
    throw ".codex-plugin/plugin.json for sdd-quality-loop must have hooks = './hooks/hooks.json' (found '$($codexPluginManifest.hooks)')."
}

# claude-hooks.json approval-guard matcher must contain 'apply_patch'.
$approvalGuardMatchers = $claudeHooks.hooks.PreToolUse | Select-Object -ExpandProperty matcher
$hasApplyPatchClaude = $approvalGuardMatchers | Where-Object { $_ -match "apply_patch" }
if (-not $hasApplyPatchClaude) {
    throw "claude-hooks.json does not have any PreToolUse matcher containing 'apply_patch'."
}

# The verification contract template must stay Default-FAIL.
$contractTemplate = Read-JsonFile "plugins/sdd-quality-loop/templates/verification-contract.template.json"
foreach ($check in $contractTemplate.checks) {
    if ($check.passes) {
        throw "Verification contract template must default every check to passes=false (violated by '$($check.id)')."
    }
}
foreach ($checkId in @("lint", "unit-tests", "build", "placeholder-scan", "task-state-check")) {
    if ($checkId -notin $contractTemplate.checks.id) {
        throw "Verification contract template is missing check: $checkId"
    }
}
foreach ($check in $contractTemplate.checks) {
    $props = $check | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    if ("waiver_reason" -notin $props) {
        throw "Verification contract template check '$($check.id)' is missing 'waiver_reason' property."
    }
}

# CI template must fail closed until its project-command replacement marker is resolved.
$ciTemplate = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-github.template.yml")
$projectCommandMarker = "TO" + "DO_REPLACE_WITH_PROJECT_COMMANDS"
if ($ciTemplate -notmatch [regex]::Escape($projectCommandMarker)) {
    throw "ci-github.template.yml does not contain the required project-command replacement marker."
}

# Side-effecting skills must not be auto-invocable by the model.
# Only the two entry commands and human-only utilities may appear in the
# user-facing slash menu; every other skill must also set user-invocable: false.
$userVisibleSkills = @("bootstrap", "ship", "sdd-sudo", "fix-by-review-ticket", "diagnose", "domain-model")
foreach ($skillFile in $skillFiles) {
    $content = Get-Content -Raw -Encoding Utf8 $skillFile.FullName
    if ($content -notmatch "(?m)^disable-model-invocation:\s*true$") {
        throw "Skill must set disable-model-invocation: true: $($skillFile.FullName)"
    }
    if ($content -notmatch "(?m)^name:\s*(.+)$") {
        throw "Skill has no name: $($skillFile.FullName)"
    }
    $skillName = $Matches[1].Trim()
    $hasUserInvocableFalse = $content -match "(?m)^user-invocable:\s*false$"
    if ($skillName -in $userVisibleSkills) {
        if ($hasUserInvocableFalse) {
            throw "User-facing skill must not set user-invocable: false: $($skillFile.FullName)"
        }
    } elseif (-not $hasUserInvocableFalse) {
        throw "Internal skill must set user-invocable: false: $($skillFile.FullName)"
    }
}

Write-Host "Repository validation passed."

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above.
exit 0
