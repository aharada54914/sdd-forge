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

Write-Host "ok: design-system contract tests passed"
