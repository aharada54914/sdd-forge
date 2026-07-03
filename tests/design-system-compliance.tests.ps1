$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$checkPs1 = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-design-system.ps1"

$fix = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-ds-compliance-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fix | Out-Null

function New-Fixture([string]$dir) {
    New-Item -ItemType Directory -Path (Join-Path $dir "design-system") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "src") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "specs/demo") -Force | Out-Null
    $tokens = '{ "meta": { "schema": "design-system-contract/v1", "version": "0.1.0", "generated_by": "manual", "profile": "custom" }, "color": { "primary": { "$type": "color", "$value": "#0f62fe" } }, "typography": {}, "spacing": {} }'
    Set-Content -Encoding Ascii -Path (Join-Path $dir "design-system/design-tokens.json") -Value $tokens
    Set-Content -Encoding Ascii -Path (Join-Path $dir "src/app.css") -Value '.button { color: var(--color-primary); }'
    Set-Content -Encoding Ascii -Path (Join-Path $dir "specs/demo/design.md") -Value "# Design: demo`n`n## Design System Compliance`n`n- Design-System-Version: 0.1.0"
}

try {
    # CDS-001 skip when no design-system/
    $empty = Join-Path $fix "empty"; New-Item -ItemType Directory -Path $empty | Out-Null
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $empty 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'skipped: no design-system/') { throw "not ok: CDS-001 skip ($out)" }
    Write-Host "ok: CDS-001 skip without design-system"

    # CDS-002 conforming project passes
    $ok = Join-Path $fix "ok"; New-Fixture $ok
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $ok -DesignMd (Join-Path $ok "specs/demo/design.md") -ChangedFiles @((Join-Path $ok "src/app.css")) 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'check-design-system passed\.') { throw "not ok: CDS-002 conforming ($out)" }
    Write-Host "ok: CDS-002 conforming project"

    # CDS-003 raw value -> WARN exit 0
    $warn = Join-Path $fix "warn"; New-Fixture $warn
    Set-Content -Encoding Ascii -Path (Join-Path $warn "src/bad.css") -Value '.bad { color: #ff0000; }'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $warn -DesignMd (Join-Path $warn "specs/demo/design.md") -ChangedFiles @((Join-Path $warn "src/bad.css")) 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'check-design-system WARN' -or $out -notmatch 'raw style value' -or $out -notmatch 'ff0000') { throw "not ok: CDS-003 warn ($out)" }
    Write-Host "ok: CDS-003 warn on raw value"

    # CDS-004 enforce mode -> exit 1
    $env:SDD_DESIGN_SYSTEM_ENFORCE = 'error'
    try {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $warn -DesignMd (Join-Path $warn "specs/demo/design.md") -ChangedFiles @((Join-Path $warn "src/bad.css")) 2>&1 | Out-String
        if ($LASTEXITCODE -ne 1 -or $out -notmatch 'check-design-system FAILED') { throw "not ok: CDS-004 enforce ($out)" }
    } finally { Remove-Item Env:SDD_DESIGN_SYSTEM_ENFORCE -ErrorAction SilentlyContinue }
    Write-Host "ok: CDS-004 enforce mode fails"

    Write-Host "ok: design-system compliance tests passed"
} finally {
    Remove-Item -LiteralPath $fix -Recurse -Force -ErrorAction SilentlyContinue
}
