$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$expectedPlugins = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop", "sdd-ship", "sdd-domain", "sdd-azure-cloud", "sdd-aws-cloud")
$expectedSkills = @("research-sources", "create-project-skill", "maintain-project-skill", "sdd-bootstrap-interviewer", "investigate-codebase", "implement-task", "quality-gate", "fix-by-review-ticket", "workflow-retrospective", "sdd-adopt", "sdd-sudo", "cross-model-verify", "lite-spec", "lite-gate", "implement-tasks", "diagnose", "spec-review-loop", "impl-review-loop", "task-review-loop", "wfi-audit-cycle", "bootstrap", "ship", "design-sync-loop", "visual-verify-loop", "domain-model", "domain-interviewer", "domain-reverse", "domain-review-loop", "domain-sync", "concept-test", "orchestrate", "orchestrate")
$expectedVersions = @{
    "sdd-bootstrap"      = "1.22.1"
    "sdd-implementation" = "1.22.1"
    "sdd-quality-loop"   = "1.22.1"
    "sdd-lite"           = "1.22.1"
    "sdd-review-loop"    = "1.22.1"
    "sdd-ship"           = "1.22.1"
    "sdd-domain"         = "1.22.1"
    "sdd-azure-cloud"    = "1.22.1"
    "sdd-aws-cloud"      = "1.22.1"
}
$releasePlugins = $expectedPlugins

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required file: $RelativePath"
    }
    return Get-Content -Raw -Encoding Utf8 -LiteralPath $path | ConvertFrom-Json
}

$readmeLines = Get-Content -Encoding Utf8 (Join-Path $repositoryRoot "README.md")
$readmeCurrentRelease = $readmeLines |
    Where-Object { $_ -match "^v\d+\.\d+\.\d+(?:\s|$)" } |
    Select-Object -First 1
if ($null -ceq $readmeCurrentRelease -or $readmeCurrentRelease -cnotmatch "^v1\.22\.1(?:\s|$)") {
    throw "README.md current release must be v1.22.1."
}

$changelog = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "CHANGELOG.md")
$currentReleaseHeadings = [regex]::Matches($changelog, "(?m)^## v1\.22\.1(?:\s|$)")
if ($currentReleaseHeadings.Count -cne 1) {
    throw "CHANGELOG.md must contain exactly one v1.22.1 release heading."
}

$codexMarketplace = Read-JsonFile ".agents/plugins/marketplace.json"
$claudeMarketplace = Read-JsonFile ".claude-plugin/marketplace.json"

foreach ($name in $expectedPlugins) {
    if ($name -cnotin $codexMarketplace.plugins.name) {
        throw "Codex marketplace does not contain $name."
    }
    if ($name -cnotin $claudeMarketplace.plugins.name) {
        throw "Claude marketplace does not contain $name."
    }

    $codexManifest = Read-JsonFile "plugins/$name/.codex-plugin/plugin.json"
    $claudeManifest = Read-JsonFile "plugins/$name/.claude-plugin/plugin.json"
    $copilotManifest = Read-JsonFile "plugins/$name/.plugin/plugin.json"
    if ($codexManifest.name -cne $name -or $claudeManifest.name -cne $name -or $copilotManifest.name -cne $name) {
        throw "Plugin directory and manifest names differ for $name."
    }
    $expectedVersion = $expectedVersions[$name]
    if ($codexManifest.version -cne $expectedVersion -or $claudeManifest.version -cne $expectedVersion -or $copilotManifest.version -cne $expectedVersion) {
        throw "Plugin version differs from $expectedVersion for $name."
    }
}

foreach ($plugin in $claudeMarketplace.plugins) {
    if ($plugin.name -cnotin $expectedVersions.Keys) { continue }
    $expectedVersion = $expectedVersions[$plugin.name]
    if ($plugin.version -cne $expectedVersion) {
        throw "Claude marketplace version differs from $expectedVersion for $($plugin.name)."
    }
}

# Every plugin carries the same explicit release version in both host
# marketplaces so cache recovery and host discovery are unambiguous.
foreach ($name in $releasePlugins) {
    $expectedVersion = $expectedVersions[$name]
    $codexEntry = @($codexMarketplace.plugins | Where-Object { $_.name -ceq $name })
    $claudeEntry = @($claudeMarketplace.plugins | Where-Object { $_.name -ceq $name })
    if ($codexEntry.Count -cne 1 -or $claudeEntry.Count -cne 1) {
        throw "Expected exactly one marketplace entry for release plugin $name."
    }
    if ($codexEntry[0].version -cne $expectedVersion -or $claudeEntry[0].version -cne $expectedVersion) {
        throw "Marketplace version differs from $expectedVersion for $name."
    }
    if ([version]$expectedVersion -le [version]"1.1.0") {
        throw "Release plugin version must be newer than 1.1.0 for $name."
    }
}

# Cloud plugins are explicit public entries. Host caches may contain only one
# provider directory, so their runtime mirrors must be byte-identical to the
# canonical shared dependency, including the protected registry and schemas.
foreach ($name in @("sdd-azure-cloud", "sdd-aws-cloud")) {
    foreach ($hostDirectory in @(".claude-plugin", ".codex-plugin", ".plugin")) {
        $manifest = Read-JsonFile "plugins/$name/$hostDirectory/plugin.json"
        $expectedSkillsPath = if ($hostDirectory -ceq ".plugin") { "skills/" } else { "./skills/" }
        $skillPaths = @($manifest.skills)
        if ($skillPaths.Count -cne 1 -or $skillPaths[0] -cne $expectedSkillsPath) {
            throw "Cloud skill export differs for $name/$hostDirectory."
        }
        if ($hostDirectory -ceq ".claude-plugin" -and $manifest.skills -isnot [array]) {
            throw "Cloud Claude skills must be an array for $name."
        }
        if ($hostDirectory -cne ".claude-plugin" -and $manifest.skills -isnot [string]) {
            throw "Cloud skills must be a string for $name/$hostDirectory."
        }
    }
    $codexEntry = @($codexMarketplace.plugins | Where-Object { $_.name -ceq $name })[0]
    $claudeEntry = @($claudeMarketplace.plugins | Where-Object { $_.name -ceq $name })[0]
    if ($codexEntry.source.source -cne "local" -or
        $codexEntry.source.path -cne "./plugins/$name" -or
        $claudeEntry.source -cne "./plugins/$name" -or
        $codexEntry.policy.installation -cne "AVAILABLE" -or
        $codexEntry.policy.authentication -cne "ON_INSTALL") {
        throw "Cloud marketplace source or opt-cin policy differs for $name."
    }
    $runtimeSources = @{}
    foreach ($module in @("cloud_contracts.py", "cloud_authorization.py", "cloud_verification.py", "cloud_dependencies.py")) {
        $runtimeSources["scripts/$module"] = "plugins/sdd-quality-loop/scripts/$module"
    }
    $runtimeSources["references/cloud-verification-registry.json"] = "plugins/sdd-quality-loop/references/cloud-verification-registry.json"
    foreach ($schemaFile in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "contracts") -File |
        Where-Object { $_.Name -cmatch '^cloud-.*\.schema\.json$' }) {
        $runtimeSources["contracts/$($schemaFile.Name)"] = "contracts/$($schemaFile.Name)"
    }
    foreach ($schemaName in @("verification-contract-v3.schema.json", "selected-verification-plan-v2.schema.json")) {
        $runtimeSources["contracts/$schemaName"] = "plugins/sdd-quality-loop/contracts/$schemaName"
    }
    foreach ($relativePath in $runtimeSources.Keys) {
        $canonical = Join-Path $repositoryRoot $runtimeSources[$relativePath]
        $packaged = Join-Path $repositoryRoot "plugins/$name/runtime/$relativePath"
        if (-not (Test-Path -LiteralPath $canonical -PathType Leaf)) {
            throw "Cloud canonical runtime is missing: $canonical"
        }
        # Source trees carry canonical inputs; installers materialize runtime/.
        # This validator needs the full source tree; any materialized mirror in
        # that tree must also match. Installed-payload tests run separately.
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot "plugins/$name/runtime"))) { continue }
        if (-not (Test-Path -LiteralPath $packaged -PathType Leaf) -or
            (Get-Item -LiteralPath $packaged).Attributes -band [IO.FileAttributes]::ReparsePoint -or
            (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash -cne
            (Get-FileHash -LiteralPath $packaged -Algorithm SHA256).Hash) {
            throw "Cloud runtime mirror differs: plugins/$name/runtime/$relativePath"
        }
    }
}

# Pinned upstream reference trees are data, not exported public skills.
$skillFiles = foreach ($pluginName in $expectedPlugins) {
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "plugins/$pluginName/skills") -Recurse -File |
        Where-Object { $_.Name -ceq "SKILL.md" }
}
$skillNames = foreach ($skillFile in $skillFiles) {
    $content = Get-Content -Raw -Encoding Utf8 $skillFile.FullName
    if ($content -cnotmatch "(?m)^name:\s*(.+)$") {
        throw "Skill has no name: $($skillFile.FullName)"
    }
    $Matches[1].Trim()
}
if (@($skillNames).Count -cne $expectedSkills.Count) {
    throw "Expected $($expectedSkills.Count) public skills but found $(@($skillNames).Count): $($skillNames -join ', ')"
}
foreach ($name in $expectedSkills) {
    if ($name -cnotin $skillNames) {
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
    # Released features must remain present in the full source tree.
    "install-payload.txt",
    "install.sh",
    "install.ps1",
    "render-agent-frontmatter.sh",
    "render-agent-frontmatter.ps1",
    "plugins/sdd-implementation/scripts/model-policy.py",
    "plugins/sdd-implementation/scripts/managed-model-entry.py",
    "plugins/sdd-implementation/scripts/select-agent-model.sh",
    "plugins/sdd-implementation/scripts/select-agent-model.ps1",
    "plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py",
    "plugins/sdd-review-loop/scripts/launch-impl-review.py",
    "plugins/sdd-quality-loop/scripts/lib/native-arguments.ps1",
    "plugins/sdd-azure-cloud/scripts/cloud.py",
    "plugins/sdd-azure-cloud/scripts/azure_local.py",
    "plugins/sdd-aws-cloud/scripts/cloud.py",
    "plugins/sdd-aws-cloud/scripts/aws_local.py",
    "plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh",
    "plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1",
    "plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh",
    "plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1",
    "contracts/agent-model-capabilities.v2.json",
    "contracts/model-policy.v1.json",
    "contracts/model-adoption/ci-model-modernization-20261021.json",
    "contracts/model-policy.schema.json",
    "contracts/model-policy-request.schema.json",
    "contracts/model-policy-error.schema.json",
    "contracts/model-observation.schema.json",
    "contracts/model-selection.schema.json",
    "contracts/model-launch-controls.schema.json",
    "contracts/model-delivery.schema.json",
    "contracts/model-role-config.schema.json",
    "contracts/verification-ci-plan.schema.json",
    "contracts/verification-ci-observations.schema.json",
    "contracts/verification-ci-result.schema.json",
    "docs/adr/0036-thin-cloud-orchestration.md",
    "docs/adr/0037-conservative-ci-selection.md",
    "docs/adr/0038-current-model-role-policy.md",
    "tests/ci-dependency-cache.py",
    "tests/verification-workflow.py",
    "tests/verification-impact.py",
    "tests/verification-ci.py",
    "tests/model-identity.tests.py",
    "tests/model-observation.tests.py",
    "tests/model-policy.tests.py",
    "tests/model-policy-launch.tests.py",
    "tests/model-policy-launch-platform.tests.py",
    "tests/model-policy-installed.tests.py",
    "tests/verification-ci-plan.tests.py",
    "tests/verification-ci.tests.py",
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
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        throw "Missing required file: $relativePath"
    }
}

# These are source-release completeness checks, not schema validation or installed
# execution proof. The model/CI suites and installed-runtime tests own behavior.
$schemaIdentities = @{
    "contracts/model-policy.schema.json" = "model-policy/v1"
    "contracts/model-policy-request.schema.json" = "model-policy-request/v1"
    "contracts/model-policy-error.schema.json" = "model-policy-error/v1"
    "contracts/model-observation.schema.json" = "model-observation/v1"
    "contracts/model-selection.schema.json" = "model-selection/v1"
    "contracts/model-launch-controls.schema.json" = "model-launch-controls/v1"
    "contracts/model-delivery.schema.json" = "model-delivery/v1"
    "contracts/model-role-config.schema.json" = "model-role-config/v1"
    "contracts/verification-ci-plan.schema.json" = "verification-ci-plan/v1"
    "contracts/verification-ci-observations.schema.json" = "verification-ci-observations/v1"
}
foreach ($relativePath in $schemaIdentities.Keys) {
    $schema = Read-JsonFile $relativePath
    if ($schema.'$schema' -cne "https://json-schema.org/draft/2020-12/schema" -or
        $schema.properties.schema.const -cne $schemaIdentities[$relativePath]) {
        throw "Schema identity differs: $relativePath"
    }
}
$ciResult = Read-JsonFile "contracts/verification-ci-result.schema.json"
if ($ciResult.'$schema' -cne "https://json-schema.org/draft/2020-12/schema" -or
    $ciResult.'$defs'.result.properties.schema.const -cne "verification-ci-result/v1" -or
    $ciResult.'$defs'.error.properties.schema.const -cne "verification-ci-error/v1") {
    throw "Schema identity differs: contracts/verification-ci-result.schema.json"
}
$policy = Read-JsonFile "contracts/model-policy.v1.json"
$registry = Read-JsonFile "contracts/agent-model-capabilities.v2.json"
$adoption = Read-JsonFile "contracts/model-adoption/ci-model-modernization-20261021.json"
if ($policy.schema -cne "model-policy/v1" -or $registry.schema -cne "agent-model-capabilities/v2" -or
    $adoption.schema -cne "t010-role-decisions/v1") {
    throw "Model policy, capability registry or adoption record identity differs."
}
$policySchema = Read-JsonFile "contracts/model-policy.schema.json"
$policyRoles = @($policy.roles.PSObject.Properties.Name)
if ((($policyRoles | Sort-Object) -join "`n") -cne
    ((@($policySchema.properties.roles.required) | Sort-Object) -join "`n")) {
    throw "Model policy roles differ from the policy contract."
}
foreach ($role in $policy.roles.PSObject.Properties) {
    $capabilityRole = $role.Value.capability_role
    if ($null -cne $capabilityRole -and
        $capabilityRole -cnotin @($registry.role_defaults.PSObject.Properties.Name)) {
        throw "Model policy role references an unknown registry role: $($role.Name) -> $capabilityRole"
    }
    if ($capabilityRole -cne $policySchema.properties.roles.properties.($role.Name).properties.capability_role.const) {
        throw "Model policy capability role differs from its contract: $($role.Name)"
    }
}

# CI planning tools/tests are required in this checkout, but deliberately excluded
# from product installation. Check admission only for the bundled runtime closure.
$manifestPath = Join-Path $repositoryRoot "install-payload.txt"
if ((Get-Item -LiteralPath $manifestPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Install payload manifest must not be a link."
}
$payloadEntries = @(foreach ($line in Get-Content -LiteralPath $manifestPath -Encoding Utf8) {
    $entry = $line.Trim()
    if (-not $entry -or $entry.StartsWith("#")) { continue }
    if ($entry -cnotmatch '^[A-Za-z0-9._@+-]+(/[A-Za-z0-9._@+-]+)*/?$' -or
        $entry -cmatch '(^|/)\.+(/|$)') {
        throw "Invalid install payload entry: $entry"
    }
    $entry
})
if ($payloadEntries.Count -eq 0) { throw "Install payload manifest is empty." }
$runtimeFiles = @($requiredFiles | Where-Object {
    $_ -cmatch '^(plugins/|\.codex/|contracts/)' -and $_ -cnotmatch '^contracts/verification-ci-'
}) + @("install-payload.txt", "install.sh", "install.ps1", "render-agent-frontmatter.sh", "render-agent-frontmatter.ps1",
    ".agents/plugins/marketplace.json", ".claude-plugin/marketplace.json")
foreach ($relativePath in $runtimeFiles) {
    $admitted = $false
    foreach ($entry in $payloadEntries) {
        if ($relativePath -ceq $entry -or
            ($entry.EndsWith("/") -and $relativePath.StartsWith($entry, [StringComparison]::Ordinal))) {
            $admitted = $true
            break
        }
    }
    if (-not $admitted) { throw "Install payload excludes required runtime: $relativePath" }
}

$workflowStateValidator = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1"
$workflowStateArguments = @("-NoProfile", "-File", $workflowStateValidator)
& (Get-Process -Id $PID).Path @workflowStateArguments
if ($LASTEXITCODE -cne 0) {
    throw "Workflow-state validation failed with exit code $LASTEXITCODE."
}

# render-agent-frontmatter --check (T-003, #151, AC-016/AC-020): read-only
# drift detection between rendered Claude .md/Codex .toml agent targets and
# the current contracts/agent-model-capabilities.v2.json role_defaults,
# including (read-only) the four R-10 protected review-loop reviewer
# targets. A non-zero exit here means either an unprotected target has
# drifted from role_defaults (a real defect) or a human maintainer has not
# yet applied the staged specs/epic-159-pillar-c/human-copy/ candidates for
# the four protected reviewer files (an expected, documented pending-action
# state until that human step occurs -- design.md Protected-File Statement).
$renderAgentFrontmatterValidator = Join-Path $repositoryRoot "render-agent-frontmatter.ps1"
$renderAgentFrontmatterArguments = @("-NoProfile", "-File", $renderAgentFrontmatterValidator, "-Check")
& (Get-Process -Id $PID).Path @renderAgentFrontmatterArguments
if ($LASTEXITCODE -cne 0) {
    throw "render-agent-frontmatter --check reported drift with exit code $LASTEXITCODE (see output above; if this is only the four protected reviewer targets, a human maintainer has not yet applied specs/epic-159-pillar-c/human-copy/)."
}

$reviewTicketTemplate = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/templates/review-ticket.template.yml")
foreach ($field in @("ticket_id:", "status:", "type:", "severity:", "target:", "summary:", "problem:", "expected_fix:", "references:", "auto_fix_allowed:", "requires_human_decision:", "review_cycles:")) {
    if ($reviewTicketTemplate -cnotmatch [regex]::Escape($field)) {
        throw "Review-ticket template is missing required field: $field"
    }
}

$tasksTemplate = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/tasks.template.md")
foreach ($field in @("Source Issue:", "Approval:", "Status:", "Goal", "Must Read", "Scope", "Done When", "Out of Scope", "Blockers")) {
    if ($tasksTemplate -cnotmatch [regex]::Escape($field)) {
        throw "Task template is missing required field: $field"
    }
}
foreach ($status in @("Draft", "Approved", "In Progress", "Blocked", "Implementation Complete", "Done")) {
    if ($tasksTemplate -cnotmatch [regex]::Escape($status)) {
        throw "Task template is missing lifecycle status: $status"
    }
}

$implementationSkill = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/SKILL.md")
foreach ($rule in @("Approved", "In Progress", "Blocked", "Implementation Complete", "git status", "git diff")) {
    if ($implementationSkill -cnotmatch [regex]::Escape($rule)) {
        throw "Implement-task skill is missing required rule: $rule"
    }
}

$qualitySkill = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md")
foreach ($rule in @("Implementation Complete", "maximum of 3", "Done", "Playwright", "traceability", "check-contract", "check-evidence-bundle", "check-placeholders", "check-task-state", "sdd-evaluator")) {
    if ($qualitySkill -cnotmatch [regex]::Escape($rule)) {
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
    if ($tomlFile.Name -cnotmatch '^sdd-.*\.toml$') {
        throw "Codex agent role file would not be installed (must be named sdd-*.toml): $($tomlFile.Name)"
    }
    $bytes = [System.IO.File]::ReadAllBytes($tomlFile.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -ceq 0xEF -and $bytes[1] -ceq 0xBB -and $bytes[2] -ceq 0xBF) {
        throw "Codex agent role file has UTF-8 BOM (must not): $($tomlFile.Name)"
    }
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($content -match "`r") {
        throw "Codex agent role file contains CR characters (must be LF-only): $($tomlFile.Name)"
    }
    if ($content -cnotmatch '(?m)^name\s*=') {
        throw "Codex agent role file lacks required 'name =' line: $($tomlFile.Name)"
    }
    if ($content -cnotmatch '(?m)^description\s*=') {
        throw "Codex agent role file lacks required 'description =' line: $($tomlFile.Name)"
    }
    if ($content -cnotmatch '(?m)^developer_instructions\s*=\s*"""') {
        throw "Codex agent role file lacks a developer_instructions multiline string: $($tomlFile.Name)"
    }
    if ($content -cnotmatch '(?s)developer_instructions\s*=\s*"""\s*\S.*?"""') {
        throw "Codex agent role file has empty developer_instructions: $($tomlFile.Name)"
    }
}

# Policy regression markers
$agentPolicyFile = Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md"
if (Test-Path $agentPolicyFile) {
    $agentPolicyContent = Get-Content -Raw -Encoding Utf8 $agentPolicyFile
    if ($agentPolicyContent -cnotmatch [regex]::Escape("Agent Role File Rules (Codex)")) {
        throw "agent-delegation-policy.md missing required text: 'Agent Role File Rules (Codex)'"
    }
    if ($agentPolicyContent -cnotmatch [regex]::Escape("developer_instructions")) {
        throw "agent-delegation-policy.md missing required text: 'developer_instructions'"
    }
}

$qualityGateFile = Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
if (Test-Path $qualityGateFile) {
    $qualityGateContent = Get-Content -Raw -Encoding Utf8 $qualityGateFile
    if ($qualityGateContent -cnotmatch [regex]::Escape("do not create new agent role files")) {
        throw "quality-gate SKILL.md missing required text: 'do not create new agent role files'"
    }
}

$installPsFile = Join-Path $repositoryRoot "install.ps1"
if (Test-Path $installPsFile) {
    $installPsContent = Get-Content -Raw -Encoding Utf8 $installPsFile
    if ($installPsContent -cnotmatch [regex]::Escape("SDD_CODEX_HOME")) {
        throw "install.ps1 missing required text: 'SDD_CODEX_HOME'"
    }
    if ($installPsContent -cnotmatch [regex]::Escape("developer_instructions")) {
        throw "install.ps1 missing required text: 'developer_instructions'"
    }
}

$installShFile = Join-Path $repositoryRoot "install.sh"
if (Test-Path $installShFile) {
    $installShContent = Get-Content -Raw -Encoding Utf8 $installShFile
    if ($installShContent -cnotmatch [regex]::Escape("SDD_CODEX_HOME")) {
        throw "install.sh missing required text: 'SDD_CODEX_HOME'"
    }
    if ($installShContent -cnotmatch [regex]::Escape("developer_instructions")) {
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
if ($copilotHooks.version -cne 1) {
    throw "copilot-hooks.json version must be 1."
}
foreach ($entry in $copilotHooks.hooks.preToolUse) {
    if (-not $entry.bash) {
        throw "copilot-hooks.json preToolUse entry is missing 'bash' field."
    }
    if (-not $entry.powershell) {
        throw "copilot-hooks.json preToolUse entry is missing 'powershell' field."
    }
    if ($entry.bash -cnotmatch '"permissionDecision":"deny"') {
        throw "copilot-hooks.json bash fallback must deny when the guard is unavailable."
    }
    if ($entry.powershell -cnotmatch '"permissionDecision":"deny"') {
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
    if ($entry.command -cne "node") {
        throw "claude-hooks.json hook entry must have command = 'node' (found '$($entry.command)')."
    }
    if (-not $entry.args -or $entry.args.Count -ceq 0) {
        throw "claude-hooks.json hook entry must have a non-empty 'args' array."
    }
    $firstArg = [string]$entry.args[0]
    if (-not $firstArg.StartsWith('${CLAUDE_PLUGIN_ROOT}')) {
        throw "claude-hooks.json hook entry first arg must start with '\${CLAUDE_PLUGIN_ROOT}' (found '$firstArg')."
    }
}

# .claude-plugin/plugin.json for sdd-quality-loop must reference claude-hooks.json.
$claudePluginManifest = Read-JsonFile "plugins/sdd-quality-loop/.claude-plugin/plugin.json"
if ($claudePluginManifest.hooks -cne "./hooks/claude-hooks.json") {
    throw ".claude-plugin/plugin.json for sdd-quality-loop must have hooks = './hooks/claude-hooks.json' (found '$($claudePluginManifest.hooks)')."
}

# .codex-plugin/plugin.json for sdd-quality-loop must have a hooks field pointing at hooks/hooks.json.
$codexPluginManifest = Read-JsonFile "plugins/sdd-quality-loop/.codex-plugin/plugin.json"
if ($codexPluginManifest.hooks -cne "./hooks/hooks.json") {
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
    if ($checkId -cnotin $contractTemplate.checks.id) {
        throw "Verification contract template is missing check: $checkId"
    }
}
foreach ($check in $contractTemplate.checks) {
    $props = $check | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    if ("waiver_reason" -cnotin $props) {
        throw "Verification contract template check '$($check.id)' is missing 'waiver_reason' property."
    }
}

# CI template must fail closed until its project-command replacement marker is resolved.
$ciTemplate = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-github.template.yml")
$projectCommandMarker = "TO" + "DO_REPLACE_WITH_PROJECT_COMMANDS"
if ($ciTemplate -cnotmatch [regex]::Escape($projectCommandMarker)) {
    throw "ci-github.template.yml does not contain the required project-command replacement marker."
}

# Skill reachability contract (WFI-054). Every skill must have exactly one
# reachable caller class:
#   - the six user-facing entries: model-uninvocable (a human types them) and
#     visible in the slash menu (no user-invocable: false);
#   - every other skill: a ship/bootstrap-delegated stage, so it MUST be
#     model-invocable (the delegating skill is the model executing its
#     instructions) and MUST stay out of the menu (user-invocable: false).
# The forbidden state is both flags together -- disable-model-invocation: true
# with user-invocable: false refuses the model AND the human, which left
# sixteen skills unreachable by anyone until 2026-08-25.
$userVisibleSkills = @("bootstrap", "ship", "sdd-sudo", "fix-by-review-ticket", "diagnose", "domain-model", "orchestrate")
foreach ($skillFile in $skillFiles) {
    $content = Get-Content -Raw -Encoding Utf8 $skillFile.FullName
    if ($content -cnotmatch "(?m)^name:\s*(.+)$") {
        throw "Skill has no name: $($skillFile.FullName)"
    }
    $skillName = $Matches[1].Trim()
    $hasDisableModelTrue = $content -match "(?m)^disable-model-invocation:\s*true$"
    $hasDisableModelFalse = $content -match "(?m)^disable-model-invocation:\s*false$"
    if (-not ($hasDisableModelTrue -or $hasDisableModelFalse)) {
        throw "Skill must declare disable-model-invocation explicitly: $($skillFile.FullName)"
    }
    $hasUserInvocableFalse = $content -match "(?m)^user-invocable:\s*false$"
    if ($hasDisableModelTrue -and $hasUserInvocableFalse) {
        throw "Unreachable skill (disable-model-invocation: true AND user-invocable: false refuses every caller, WFI-054): $($skillFile.FullName)"
    }
    if ($skillName -cin $userVisibleSkills) {
        if (-not $hasDisableModelTrue) {
            throw "User-facing entry skill must set disable-model-invocation: true: $($skillFile.FullName)"
        }
        if ($hasUserInvocableFalse) {
            throw "User-facing skill must not set user-invocable: false: $($skillFile.FullName)"
        }
    } else {
        if (-not $hasUserInvocableFalse) {
            throw "Internal skill must set user-invocable: false: $($skillFile.FullName)"
        }
        if (-not $hasDisableModelFalse) {
            throw "Internal skill must set disable-model-invocation: false (its only caller is the delegating skill the model executes, WFI-054): $($skillFile.FullName)"
        }
    }
}

Write-Host "Repository validation passed."

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above.
exit 0
