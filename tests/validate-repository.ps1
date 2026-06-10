$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$expectedPlugins = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")
$expectedSkills = @("sdd-bootstrap-interviewer", "implement-task", "quality-gate", "fix-by-review-ticket")
$expectedVersion = "0.2.0"

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
    "plugins/sdd-quality-loop/templates/review-ticket.template.yml"
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
foreach ($rule in @("Implementation Complete", "maximum of 3", "Done", "Playwright", "traceability")) {
    if ($qualitySkill -notmatch [regex]::Escape($rule)) {
        throw "Quality-gate skill is missing required rule: $rule"
    }
}

Write-Host "Repository validation passed."
