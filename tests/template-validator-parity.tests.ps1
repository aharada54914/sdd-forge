# Template-validator parity (WFI-005) - PowerShell twin of
# template-validator-parity.tests.sh, byte-equivalent in coverage.
# Renders each canonical gate-artifact template with fixture values and
# applies the SAME parsing rules the enforcing validators use, plus pins on
# the validator sources so parser drift breaks this suite too.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$implTemplate = Join-Path $repoRoot "plugins/sdd-implementation/templates/implementation-report.template.md"
$qgTemplate = Join-Path $repoRoot "plugins/sdd-quality-loop/templates/quality-report.template.md"
$validator = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
$bundleCheck = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh"
$implReportValidator = Join-Path $repoRoot "plugins/sdd-implementation/scripts/validate-implementation-report.sh"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$taskId = "T-777"
$feature = "example-feature"
$outPath = "plugins/example/skills/example/SKILL.md"
$outHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

function Render([string]$TemplatePath) {
    $text = [IO.File]::ReadAllText($TemplatePath)
    $text = $text.Replace("{{task_id}}", $taskId)
    $text = $text.Replace("{{feature}}", $feature)
    $text = $text.Replace("{{output_path}}", $outPath)
    $text = $text.Replace("{{output_sha256}}", $outHash)
    $text = $text.Replace("{{verdict}}", "PASS")
    $text = [regex]::Replace($text, "\{\{[A-Za-z_|]*\}\}", "fixture-value")
    return $text
}

# ---------------------------------------------------------------------------
# Implementation report template vs the evaluator launch boundary
# ---------------------------------------------------------------------------
$implRendered = Render $implTemplate
$implLines = $implRendered -split "`r?`n"

# Rule 1: line 1 must be exactly "# Implementation Report: T-NNN".
if ($implLines[0] -eq "# Implementation Report: $taskId") {
    Ok "impl-report template: heading line matches the evaluator boundary"
} else {
    Fail "impl-report template: heading line does not match (got: $($implLines[0]))"
}
if ((Get-Content -Raw $validator).Contains('Implementation Report: $task_id')) {
    Ok "validator pin: heading rule still present in launch boundary"
} else {
    Fail "validator pin: heading rule text changed in launch boundary -- update this suite and the template together"
}

# Rule 2: a full-line "- Task ID: T-NNN" must exist.
if (@($implLines) -contains "- Task ID: $taskId") {
    Ok "impl-report template: '- Task ID:' line present"
} else {
    Fail "impl-report template: '- Task ID:' full-line match missing"
}
if ((Get-Content -Raw $validator).Contains('- Task ID: $task_id')) {
    Ok "validator pin: Task ID rule still present in launch boundary"
} else {
    Fail "validator pin: Task ID rule text changed in launch boundary"
}

# Rule 3: the "## Outputs" table row must parse exactly as
# evaluator_output_is_declared does (replicated line-state machine).
$inOutputs = $false
$found = $false
$expectedLine = "| ``$outPath`` | ``$outHash`` |"
foreach ($line in $implLines) {
    if ($line -match "^## Outputs\s*$") { $inOutputs = $true; continue }
    if ($inOutputs -and $line -match "^##\s") { break }
    if ($inOutputs -and $line -ceq $expectedLine) { $found = $true }
}
if ($found) {
    Ok "impl-report template: Outputs table row parses via the evaluator's declared-output rule"
} else {
    Fail "impl-report template: Outputs table row NOT recognized by the evaluator's declared-output parser"
}
if ((Get-Content -Raw $validator).Contains('/^## Outputs[[:space:]]*$/')) {
    Ok "validator pin: Outputs-section parser still present in launch boundary"
} else {
    Fail "validator pin: Outputs-section parser changed in launch boundary"
}

# ---------------------------------------------------------------------------
# WFI-017 leg: implementation report template vs its OWN authoring-time
# validator (validate-implementation-report.sh). `Render` above only fills
# the placeholders the other legs care about, leaving every other field as
# inert "fixture-value" text -- not enough to satisfy the full validator
# (Test Result enum, Task Attempt Count, escalation vacuity, Isolation Mode,
# Current Status enum). `Render-ImplReportOk` renders straight from the
# template with the superset of substitutions needed to pass every rule,
# proving the template's CURRENT "## Outputs" table form satisfies the
# validator end-to-end, not just the single-row shape Rule 3 already pins.
# ---------------------------------------------------------------------------
function Render-ImplReportOk([string]$TemplatePath) {
    $text = [IO.File]::ReadAllText($TemplatePath)
    $text = $text.Replace("{{task_id}}", $taskId)
    $text = $text.Replace("{{output_path}}", $outPath)
    $text = $text.Replace("{{output_sha256}}", $outHash)
    $text = $text.Replace("{{model}}", "anthropic/opus")
    $text = $text.Replace("{{effort}}", "standard")
    $text = $text.Replace("{{PASS_or_FAIL_or_BLOCKED_or_NOT_RUN}}", "PASS")
    $text = $text.Replace("{{task_attempt_count}}", "1")
    $text = $text.Replace("{{escalation_prior_tier}}", "None")
    $text = $text.Replace("{{escalation_next_tier}}", "None")
    $text = $text.Replace("{{escalation_failure_class}}", "None")
    $text = $text.Replace("{{escalation_attempt_number}}", "None")
    $text = $text.Replace("{{escalation_reason}}", "None")
    $text = $text.Replace("{{isolation_mode}}", "fresh-agent")
    $text = $text.Replace("{{fallback_reason_or_none}}", "None")
    $text = $text.Replace("{{handoff_reload_evidence_hash_or_none}}", "None")
    $text = $text.Replace("{{handoff_status}}", "Implementation Complete")
    $text = [regex]::Replace($text, "\{\{[A-Za-z_|]*\}\}", "fixture-value")
    return $text
}

$implFullWork = Join-Path ([IO.Path]::GetTempPath()) ("template-parity-impl-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $implFullWork | Out-Null
try {
    $implFullRendered = Join-Path $implFullWork "impl-report-full.md"
    [IO.File]::WriteAllText($implFullRendered, (Render-ImplReportOk $implTemplate))

    $implValidatorOutput = (& bash $implReportValidator $implFullRendered 2>&1 | Out-String).Trim()
    if ($implValidatorOutput -eq "IMPLEMENTATION_REPORT_OK") {
        Ok "impl-report template: rendered report passes validate-implementation-report.sh"
    } else {
        Fail "impl-report template: rendered report rejected by validate-implementation-report.sh (got: $implValidatorOutput)"
    }
} finally {
    Remove-Item -Recurse -Force $implFullWork -ErrorAction SilentlyContinue
}
if ((Get-Content -Raw $implReportValidator).Contains('outputs_row_pattern = re.compile(')) {
    Ok "validator pin: Outputs-table row parser still present in validate-implementation-report.sh"
} else {
    Fail "validator pin: Outputs-table row parser missing from validate-implementation-report.sh"
}

# ---------------------------------------------------------------------------
# Quality gate report template vs the evidence-bundle validator
# ---------------------------------------------------------------------------
$qgRendered = Render $qgTemplate
$qgLines = $qgRendered -split "`r?`n"

# Rule 4: exactly one "Feature:" line whose value equals the contract feature.
$featureLines = @($qgLines | Where-Object { $_ -match "^Feature:" })
$featureValue = ""
if ($featureLines.Count -ge 1 -and $featureLines[0] -match "^Feature:\s*(.*?)\s*$") {
    $featureValue = $Matches[1]
}
if ($featureLines.Count -eq 1 -and $featureValue -eq $feature) {
    Ok "quality-report template: single Feature: line with the contract feature value"
} else {
    Fail "quality-report template: Feature: line count=$($featureLines.Count) value='$featureValue' (expected 1/'$feature')"
}
if ((Get-Content -Raw $bundleCheck) -match "Feature:") {
    Ok "validator pin: Feature rule still present in evidence-bundle validator"
} else {
    Fail "validator pin: Feature rule missing from evidence-bundle validator"
}

# Rule 5: "Task ID: T-NNN" line.
if (@($qgLines | Where-Object { $_ -match "^Task ID:\s*$([regex]::Escape($taskId))\s*$" }).Count -ge 1) {
    Ok "quality-report template: Task ID line present"
} else {
    Fail "quality-report template: Task ID line missing"
}

# Rule 6: "VERDICT:" line.
if (@($qgLines | Where-Object { $_ -match "^VERDICT:\s*PASS\s*$" }).Count -ge 1) {
    Ok "quality-report template: VERDICT line present"
} else {
    Fail "quality-report template: VERDICT line missing"
}

Write-Output ""
Write-Output "template-validator-parity.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
