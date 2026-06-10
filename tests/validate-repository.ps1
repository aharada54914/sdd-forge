$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$expectedPlugins = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")
$expectedSkills = @("sdd-bootstrap-interviewer", "investigate-codebase", "implement-task", "quality-gate", "fix-by-review-ticket", "workflow-retrospective")
$expectedVersion = "0.3.0"

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path $path)) {
        throw "Missing required file: $RelativePath"
    }
    return Get-Content -Raw -Encoding Utf8 $path | ConvertFrom-Json
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
    if ($codexManifest.name -ne $name -or $claudeManifest.name -ne $name) {
        throw "Plugin directory and manifest names differ for $name."
    }
    if ($codexManifest.version -ne $expectedVersion -or $claudeManifest.version -ne $expectedVersion) {
        throw "Plugin version differs from $expectedVersion for $name."
    }
}

foreach ($plugin in $claudeMarketplace.plugins) {
    if ($plugin.version -ne $expectedVersion) {
        throw "Claude marketplace version differs from $expectedVersion for $($plugin.name)."
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
    "plugins/sdd-quality-loop/templates/ci-report.template.md"
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
    "plugins/sdd-quality-loop/templates/verification-contract.template.json",
    "plugins/sdd-quality-loop/templates/retrospective-report.template.md",
    "plugins/sdd-quality-loop/templates/workflow-improvement.template.md"
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
foreach ($rule in @("Implementation Complete", "maximum of 3", "Done", "Playwright", "traceability", "check-contract", "check-placeholders", "check-task-state", "sdd-evaluator")) {
    if ($qualitySkill -notmatch [regex]::Escape($rule)) {
        throw "Quality-gate skill is missing required rule: $rule"
    }
}

# Deterministic gate scripts must exist as portable sh/ps1 pairs.
foreach ($script in @("check-contract", "check-placeholders", "check-task-state")) {
    foreach ($extension in @("sh", "ps1")) {
        $scriptPath = "plugins/sdd-quality-loop/scripts/$script.$extension"
        if (-not (Test-Path (Join-Path $repositoryRoot $scriptPath))) {
            throw "Missing deterministic gate script: $scriptPath"
        }
    }
}
foreach ($scriptPath in @("plugins/sdd-quality-loop/scripts/guard-task-approval.sh",
                          "plugins/sdd-quality-loop/scripts/guard-task-approval.ps1",
                          "plugins/sdd-quality-loop/scripts/kill-switch.sh")) {
    if (-not (Test-Path (Join-Path $repositoryRoot $scriptPath))) {
        throw "Missing hook script: $scriptPath"
    }
}

# Hooks must parse as JSON and reference only bundled scripts.
$hooksConfig = Read-JsonFile "plugins/sdd-quality-loop/hooks/hooks.json"
if (-not $hooksConfig.hooks.PreToolUse) {
    throw "hooks.json does not define PreToolUse hooks."
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

# Side-effecting skills must not be auto-invocable by the model.
foreach ($skillFile in $skillFiles) {
    $content = Get-Content -Raw -Encoding Utf8 $skillFile.FullName
    if ($content -notmatch "(?m)^disable-model-invocation:\s*true$") {
        throw "Skill must set disable-model-invocation: true: $($skillFile.FullName)"
    }
}

Write-Host "Repository validation passed."
