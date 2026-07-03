$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repositoryRoot "contracts/design-system.contract.v1.schema.json"
$tokensPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json"

# DS-001 both JSON files must parse (PS5.1-safe: ConvertFrom-Json, no Test-Json)
$schema = Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json
$tokens = Get-Content -Raw -Encoding Utf8 $tokensPath | ConvertFrom-Json

if ($schema.'$id' -ne 'https://sdd-forge.dev/contracts/design-system.contract.v1.schema.json') {
    throw "not ok: DS-001 schema `$id mismatch"
}
if ($schema.properties.meta.properties.schema.const -ne 'design-system-contract/v1') {
    throw "not ok: DS-001 schema const mismatch"
}
Write-Host "ok: DS-001 contract schema envelope"

# DS-002 tokens template conforms to the meta contract (domain assertions replicate the schema)
if ($tokens.meta.schema -ne 'design-system-contract/v1') { throw "not ok: DS-002 meta.schema" }
if ($tokens.meta.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw "not ok: DS-002 meta.version semver" }
if (@('design-sync-loop','ui-ux-pro-max','manual','figma-dtcg-import') -notcontains $tokens.meta.generated_by) { throw "not ok: DS-002 meta.generated_by enum" }
if ($tokens.meta.profile -ne 'custom') { throw "not ok: DS-002 meta.profile" }
foreach ($group in @('color','typography','spacing')) {
    if ($null -eq $tokens.$group) { throw "not ok: DS-002 token group $group missing" }
}
if ($tokens.color.primary.'$value' -notmatch '^#[0-9a-fA-F]{6}$') { throw "not ok: DS-002 color.primary DTCG value" }
Write-Host "ok: DS-002 tokens template conforms"

# DS-003 / DS-004 markdown templates
$dsPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md"
$uipPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md"
$ds = Get-Content -Raw -Encoding Utf8 $dsPath
$uip = Get-Content -Raw -Encoding Utf8 $uipPath
# PS5.1 reads BOM-less .ps1 as ANSI, so non-ASCII literals must be built from code points.
$em = [string][char]0x2014
foreach ($section in @("## Layer 1 $em Tokens (machine-extracted)", "## Layer 2 $em Do / Don't (component conventions)", "## Layer 3 $em Review checklist (human-curated)", '## Change Process')) {
    if ($ds -notmatch [regex]::Escape($section)) { throw "not ok: DS-003 missing section $section" }
}
if ($ds -notmatch 'WCAG 2\.2 AA') { throw "not ok: DS-003 WCAG 2.2 AA missing" }
Write-Host "ok: DS-003 design-system template sections"
foreach ($section in @('## Actions', '## Dialogs', '## Icons', '## Flow', '## States', '## Cognitive Load')) {
    if ($uip -notmatch [regex]::Escape($section)) { throw "not ok: DS-004 missing section $section" }
}
Write-Host "ok: DS-004 ui-patterns template sections"

# DS-005 PLUGIN-CONTRACTS section
# PS5.1 reads BOM-less .ps1 files as ANSI, so non-ASCII literals (the arrow in
# the heading) must be constructed from code points, never written literally.
$arrow = [string][char]0x2192
$pc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "PLUGIN-CONTRACTS.md")
if ($pc -notmatch [regex]::Escape("## sdd-bootstrap design-system artifacts $arrow consumers (v1.8.0+)")) { throw "not ok: DS-005 contract section missing" }
if ($pc -notmatch 'absence never blocks') { throw "not ok: DS-005 absence contract missing" }
Write-Host "ok: DS-005 PLUGIN-CONTRACTS section"

# DS-006 design-sync-loop v2 (ASCII-only assertions; the em-dash fallback note is asserted by the sh twin)
$dsl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md")
foreach ($needle in @('## Ensure design-system/', 'ui-ux-pro-max', 'design-system --persist', 'figma-dtcg-import', 'design-system/design-tokens.json', 'MASTER.md')) {
    if ($dsl -notmatch [regex]::Escape($needle)) { throw "not ok: DS-006 missing $needle" }
}
Write-Host "ok: DS-006 design-sync-loop v2"

# DS-007 investigate-codebase design inventory
$inv = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md")
if ($inv -notmatch 'Design Inventory') { throw "not ok: DS-007 Design Inventory missing" }
Write-Host "ok: DS-007 investigate-codebase design inventory"

# DS-008 / DS-009 design templates
$dt = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md")
if ($dt -notmatch [regex]::Escape('## Design System Compliance')) { throw "not ok: DS-008 compliance section missing" }
if ($dt -notmatch 'ds_profile: none') { throw "not ok: DS-008 none rule missing" }
$dl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-lite/templates/design-lite.md")
if ($dl -notmatch 'design-system/') { throw "not ok: DS-009 lite declaration missing" }
Write-Host "ok: DS-008/DS-009 design templates"

Write-Host "ok: design-system contract tests passed"
