# render-agent-frontmatter.ps1 (T-003, epic-159-pillar-c, #151) -- REQ-003 /
# AC-014..AC-020. PowerShell twin of render-agent-frontmatter.sh; see that
# file's header comment for the full design rationale.
#
# PowerShell case-sensitivity (T-002 implementation report,
# reports/implementation/epic-159-pillar-c/T-002.md, "PowerShell
# case-sensitivity (2 layers)"): PSObject dot-access (`$obj.Name`) and
# PowerShell's default `-eq`/`switch` operators resolve string keys
# case-INSENSITIVELY. Every comparison against a registry-sourced string in
# this script (canonical_tier, effort_control.'codex-cli', role_defaults
# keys) uses an explicit case-sensitive operator (-ceq/-cne/-cmatch) or
# enumerates .PSObject.Properties and matches Name with -ceq, never bare
# dot-access on an untrusted key. A mis-cased registry fixture pair
# (role_defaults key, canonical_tier value) is exercised in
# tests/render-agent-frontmatter.tests.ps1 to prove both twins reject the
# mis-cased value rather than silently aliasing it.
param(
    [switch]$Check,
    [string]$Registry = '',
    [string]$RepoRoot = '',
    [string]$TargetsFile = '',
    # Scalar (not array) parameters, deliberately: `-File`-mode native argv
    # binding does not reliably collect multiple bare tokens into a
    # `[string[]]` parameter across a nested subprocess invocation (verified
    # directly -- tests/render-agent-frontmatter.tests.ps1's own
    # subprocess-based Invoke-Render helper is exactly such a caller), so
    # the resolve-target debug surface uses one flag per value instead
    # (documented twin divergence from the .sh CLI's positional-args form,
    # matching the `-HostName`-vs-`--host` precedent in
    # plugins/sdd-implementation/scripts/select-agent-model.ps1, T-002).
    [string]$ResolveTargetRawPath = '',
    [string]$ResolveTargetRawProtected = '',
    [string]$ResolveTargetRole = '',
    [string]$ResolveTargetKind = '',
    [string]$ResolveTargetRelPath = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $RepoRoot) {
    $RepoRoot = $PSScriptRoot
}
$RepoRoot = (Resolve-Path $RepoRoot).Path

$HumanCopyRelDir = 'specs/epic-159-pillar-c/human-copy'

function Get-DefaultTargets {
    return @(
        [pscustomobject]@{ Role = 'sdd-evaluator'; Kind = 'claude'; Path = 'plugins/sdd-quality-loop/agents/evaluator.md'; Protected = $false }
        [pscustomobject]@{ Role = 'sdd-evaluator'; Kind = 'codex'; Path = '.codex/agents/sdd-evaluator.toml'; Protected = $false }
        [pscustomobject]@{ Role = 'sdd-investigator'; Kind = 'claude'; Path = 'plugins/sdd-bootstrap/agents/investigator.md'; Protected = $false }
        [pscustomobject]@{ Role = 'sdd-investigator'; Kind = 'codex'; Path = '.codex/agents/sdd-investigator.toml'; Protected = $false }
        [pscustomobject]@{ Role = 'spec-reviewer'; Kind = 'claude'; Path = 'plugins/sdd-review-loop/agents/spec-reviewer-a.md'; Protected = $false }
        [pscustomobject]@{ Role = 'spec-reviewer'; Kind = 'claude'; Path = 'plugins/sdd-review-loop/agents/spec-reviewer-b.md'; Protected = $false }
        [pscustomobject]@{ Role = 'impl-reviewer'; Kind = 'claude'; Path = 'plugins/sdd-review-loop/agents/impl-reviewer-a.md'; Protected = $true }
        [pscustomobject]@{ Role = 'impl-reviewer'; Kind = 'claude'; Path = 'plugins/sdd-review-loop/agents/impl-reviewer-b.md'; Protected = $true }
        [pscustomobject]@{ Role = 'task-reviewer'; Kind = 'claude'; Path = 'plugins/sdd-review-loop/agents/task-reviewer-a.md'; Protected = $true }
        [pscustomobject]@{ Role = 'task-reviewer'; Kind = 'claude'; Path = 'plugins/sdd-review-loop/agents/task-reviewer-b.md'; Protected = $true }
    )
}

function Resolve-WriteTargetRaw([string]$RelPath, [bool]$Protected) {
    # The write-target resolution FUNCTION itself (AC-019/TEST-019): this
    # branch is the ENTIRE decision -- protected targets structurally never
    # resolve to `RepoRoot/RelPath`, regardless of registry content.
    if ($Protected) {
        return (Join-Path $RepoRoot (Join-Path $HumanCopyRelDir $RelPath))
    }
    return (Join-Path $RepoRoot $RelPath)
}

function Resolve-WriteTarget($Targets, [string]$Role, [string]$Kind, [string]$RelPath) {
    foreach ($t in $Targets) {
        if ($t.Role -ceq $Role -and $t.Kind -ceq $Kind -and $t.Path -ceq $RelPath) {
            return Resolve-WriteTargetRaw -RelPath $t.Path -Protected $t.Protected
        }
    }
    throw "RENDER_ERROR: target not found in table: $Role/$Kind/$RelPath"
}

function Split-ContentLines([string]$Content) {
    $trailingNl = $Content.EndsWith("`n")
    $parts = $Content -split "`n"
    if ($trailingNl) {
        $parts = $parts[0..($parts.Count - 2)]
    }
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($p in $parts) { $list.Add($p) }
    return [pscustomobject]@{ Lines = $list; TrailingNl = $trailingNl }
}

function Join-ContentLines($Lines, [bool]$TrailingNl) {
    $text = [string]::Join("`n", $Lines)
    if ($TrailingNl) { $text += "`n" }
    return $text
}

function Get-Registry([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "RENDER_ERROR: registry not found: $Path"
    }
    $raw = [System.IO.File]::ReadAllText($Path)
    $data = $raw | ConvertFrom-Json
    if ($data.schema -cne 'agent-model-capabilities/v2') {
        throw "RENDER_ERROR: registry schema must be agent-model-capabilities/v2, got '$($data.schema)'"
    }
    return $data
}

function Get-EffortControlValue($Model, [string]$HostKey) {
    if ($null -eq $Model.effort_control) { return $null }
    foreach ($prop in $Model.effort_control.PSObject.Properties) {
        if ($prop.Name -ceq $HostKey) { return [string]$prop.Value }
    }
    return $null
}

function Get-ModelForTier($Registry, [string]$Tier, [string]$Kind) {
    foreach ($m in $Registry.models) {
        if ($null -eq $m.name -or $m.canonical_tier -cne $Tier) { continue }
        if ($Kind -ceq 'claude') {
            if ($m.name -cmatch '^anthropic/') {
                return ($m.name -split '/', 2)[1]
            }
        } else {
            if ((Get-EffortControlValue $m 'codex-cli') -ceq 'flag') {
                return [string]$m.name
            }
        }
    }
    throw "RENDER_ERROR: no $Kind model found for tier '$Tier'"
}

function Get-RoleValues($Registry, [string]$Role) {
    $entry = $null
    if ($null -ne $Registry.role_defaults) {
        foreach ($prop in $Registry.role_defaults.PSObject.Properties) {
            # Case-sensitive role key match: a mis-cased role_defaults key
            # (e.g. "Sdd-Evaluator") must never silently satisfy a lookup
            # for "sdd-evaluator" (T-002 case-sensitivity precedent).
            if ($prop.Name -ceq $Role) { $entry = $prop.Value; break }
        }
    }
    if ($null -eq $entry -or -not $entry.minimum_tier -or -not $entry.default_effort) {
        throw "RENDER_ERROR: role_defaults missing or incomplete for role '$Role'"
    }
    return [pscustomobject]@{ Tier = [string]$entry.minimum_tier; Effort = [string]$entry.default_effort }
}

function Convert-ClaudeContent([string]$Content, [string]$ModelName, [string]$Effort) {
    $split = Split-ContentLines $Content
    $lines = $split.Lines
    $trailingNl = $split.TrailingNl

    if ($lines.Count -eq 0 -or $lines[0] -cne '---') {
        throw 'RENDER_ERROR: claude target missing opening frontmatter delimiter'
    }
    $closeIdx = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -ceq '---') { $closeIdx = $i; break }
    }
    if ($closeIdx -lt 0) {
        throw 'RENDER_ERROR: claude target missing closing frontmatter delimiter'
    }

    $modelIdx = -1
    for ($i = 1; $i -lt $closeIdx; $i++) {
        if ($lines[$i] -cmatch '^model:\s*(\S+)\s*$') { $modelIdx = $i; break }
    }

    $changed = $false
    if ($modelIdx -ge 0) {
        $currentValue = [regex]::Match($lines[$modelIdx], '^model:\s*(\S+)\s*$').Groups[1].Value
        if ($currentValue -ceq 'inherit') {
            # AC-018 exclusion: model: inherit agents are never rewritten.
            return [pscustomobject]@{ Content = $Content; Changed = $false }
        }
        if ($currentValue -cne $ModelName) {
            $lines[$modelIdx] = "model: $ModelName"
            $changed = $true
        }
    } else {
        $lines.Insert($closeIdx, "model: $ModelName")
        $closeIdx++
        $changed = $true
    }

    $afterIdx = $closeIdx + 1
    if ($afterIdx -lt $lines.Count -and $lines[$afterIdx] -cmatch '^<!-- x-sdd-effort: (\S+) -->$') {
        $currentEffort = [regex]::Match($lines[$afterIdx], '^<!-- x-sdd-effort: (\S+) -->$').Groups[1].Value
        if ($currentEffort -cne $Effort) {
            $lines[$afterIdx] = "<!-- x-sdd-effort: $Effort -->"
            $changed = $true
        }
    } else {
        $lines.Insert($afterIdx, "<!-- x-sdd-effort: $Effort -->")
        $changed = $true
    }

    $newContent = Join-ContentLines $lines $trailingNl
    return [pscustomobject]@{ Content = $newContent; Changed = $changed }
}

function Convert-CodexContent([string]$Content, [string]$ModelName, [string]$Effort) {
    $split = Split-ContentLines $Content
    $lines = $split.Lines
    $trailingNl = $split.TrailingNl

    $i = 0
    while ($i -lt $lines.Count -and (
        $lines[$i] -cmatch '^# x-sdd-model: \S+$' -or
        $lines[$i] -cmatch '^# x-sdd-effort: \S+$'
    )) { $i++ }

    $rest = New-Object System.Collections.Generic.List[string]
    if ($i -lt $lines.Count) {
        $rest = $lines.GetRange($i, $lines.Count - $i)
    }
    $newLines = New-Object System.Collections.Generic.List[string]
    $newLines.Add("# x-sdd-model: $ModelName")
    $newLines.Add("# x-sdd-effort: $Effort")
    $newLines.AddRange($rest)

    $newContent = Join-ContentLines $newLines $true
    $changed = ($newContent -cne $Content)
    return [pscustomobject]@{ Content = $newContent; Changed = $changed }
}

function Get-Sha256OfText([string]$Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    return -join ($hash | ForEach-Object { $_.ToString('x2') })
}

function Update-Manifest([string]$ManifestPath, [string]$RelPath, [string]$Sha) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path $ManifestPath) {
        foreach ($l in [System.IO.File]::ReadAllLines($ManifestPath)) { $lines.Add($l) }
    }
    $replaced = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '^\S+\s+(.+?)\s*$' -and $Matches[1] -ceq $RelPath) {
            $lines[$i] = "$Sha  $RelPath"
            $replaced = $true
        }
    }
    if (-not $replaced) {
        $lines.Add("$Sha  $RelPath")
    }
    $parent = Split-Path -Parent $ManifestPath
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $text = ([string]::Join("`n", $lines)) + "`n"
    [System.IO.File]::WriteAllText($ManifestPath, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-RenderTarget($Registry, $Target, [bool]$CheckMode, [string]$ManifestPath) {
    $roleValues = Get-RoleValues $Registry $Target.Role
    $kindForModel = if ($Target.Kind -ceq 'claude') { 'claude' } else { 'codex' }
    $modelName = Get-ModelForTier $Registry $roleValues.Tier $kindForModel
    $effort = $roleValues.Effort

    $realPath = Join-Path $RepoRoot $Target.Path
    if (-not (Test-Path $realPath)) {
        throw "RENDER_ERROR: target file not found: $($Target.Path)"
    }
    $current = [System.IO.File]::ReadAllText($realPath)

    if ($Target.Kind -ceq 'claude') {
        $result = Convert-ClaudeContent $current $modelName $effort
    } else {
        $result = Convert-CodexContent $current $modelName $effort
    }
    $computed = $result.Content
    $changed = $result.Changed

    if ($CheckMode) {
        $drift = ($computed -cne $current)
        return [pscustomobject]@{ RelPath = $Target.Path; Protected = $Target.Protected; Drift = $drift }
    }

    if ($Target.Protected) {
        $stagedPath = Resolve-WriteTargetRaw -RelPath $Target.Path -Protected $true
        $stagedParent = Split-Path -Parent $stagedPath
        if (-not (Test-Path $stagedParent)) { New-Item -ItemType Directory -Path $stagedParent -Force | Out-Null }
        [System.IO.File]::WriteAllText($stagedPath, $computed, (New-Object System.Text.UTF8Encoding($false)))
        $sha = Get-Sha256OfText $computed
        Update-Manifest -ManifestPath $ManifestPath -RelPath $Target.Path -Sha $sha
        return [pscustomobject]@{ RelPath = $Target.Path; Protected = $true; Staged = $stagedPath; Changed = $changed }
    }

    if ($computed -cne $current) {
        [System.IO.File]::WriteAllText($realPath, $computed, (New-Object System.Text.UTF8Encoding($false)))
    }
    return [pscustomobject]@{ RelPath = $Target.Path; Protected = $false; Changed = $changed }
}

# --- Dispatch -----------------------------------------------------------
# The whole dispatch body runs inside a top-level try/catch that prints a
# PLAIN (non-ANSI, non-wrapped) diagnostic line to stderr and exits 1 on any
# error. Without this, an uncaught `throw` renders through pwsh 7's default
# colorized/wrapped ConciseView error formatter, which breaks any caller
# (including this suite's own subprocess-based assertions) that does a
# plain substring match against the error text.
try {

if ($ResolveTargetRawPath) {
    if ($ResolveTargetRawProtected -cnotin @('0', '1')) { throw 'RENDER_ERROR: -ResolveTargetRawProtected must be 0 or 1' }
    $protectedFlag = ($ResolveTargetRawProtected -ceq '1')
    Write-Output (Resolve-WriteTargetRaw -RelPath $ResolveTargetRawPath -Protected $protectedFlag)
    exit 0
}

$targets = Get-DefaultTargets
if ($TargetsFile) {
    $raw = [System.IO.File]::ReadAllText((Resolve-Path $TargetsFile).Path)
    $parsed = $raw | ConvertFrom-Json
    $targets = @()
    foreach ($p in $parsed) {
        $targets += [pscustomobject]@{ Role = [string]$p.role; Kind = [string]$p.kind; Path = [string]$p.path; Protected = [bool]$p.protected }
    }
}

if ($ResolveTargetRole) {
    if (-not $ResolveTargetKind -or -not $ResolveTargetRelPath) {
        throw 'RENDER_ERROR: -ResolveTargetRole requires -ResolveTargetKind and -ResolveTargetRelPath'
    }
    Write-Output (Resolve-WriteTarget -Targets $targets -Role $ResolveTargetRole -Kind $ResolveTargetKind -RelPath $ResolveTargetRelPath)
    exit 0
}

if (-not $Registry) {
    $Registry = Join-Path $RepoRoot 'contracts/agent-model-capabilities.v2.json'
}
$registryData = Get-Registry $Registry
$manifestPath = Join-Path $RepoRoot (Join-Path $HumanCopyRelDir 'MANIFEST.sha256')

$results = @()
foreach ($t in $targets) {
    $results += (Invoke-RenderTarget -Registry $registryData -Target $t -CheckMode:([bool]$Check) -ManifestPath $manifestPath)
}

if ($Check) {
    $driftCount = 0
    foreach ($r in $results) {
        $status = if ($r.Drift) { 'DRIFT' } else { 'OK' }
        $tag = if ($r.Protected) { ' (protected, read-only)' } else { '' }
        Write-Output "${status}: $($r.RelPath)$tag"
        if ($r.Drift) { $driftCount++ }
    }
    Write-Output "---- check summary: $($results.Count) targets, $driftCount drift ----"
    if ($driftCount -gt 0) { exit 1 } else { exit 0 }
} else {
    foreach ($r in $results) {
        $tag = if ($r.Changed) { '(changed)' } else { '(unchanged)' }
        if ($r.Protected) {
            Write-Output "STAGED: $($r.RelPath) -> $($r.Staged) $tag"
        } else {
            Write-Output "RENDERED: $($r.RelPath) $tag"
        }
    }
    exit 0
}

} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
