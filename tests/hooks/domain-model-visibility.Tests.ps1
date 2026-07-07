$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# T-004: domain-model entry skill visibility contract (AC-001).
#
# Confirms that:
#   1. domain-model's SKILL.md frontmatter is a public entry: it omits
#      `user-invocable: false` (matching sdd-bootstrap:bootstrap's own
#      public-entry convention) but still carries
#      `disable-model-invocation: true`.
#   2. Every other sdd-domain skill built so far (domain-interviewer,
#      domain-reverse) carries BOTH `user-invocable: false` AND
#      `disable-model-invocation: true` -- scanned from their actual
#      frontmatter, not asserted by assumption.
#
# Pester 3.4.0 / Windows PowerShell 5.1 only on this host: uses
# `Describe`/`It`/`BeforeAll`, `-contains` for collection membership
# (Pester 3.4.0's `Should Contain` is a file-content assertion, not a
# collection-membership one), and `Invoke-Pester -Script <path>` legacy
# invocation. No non-ASCII literals.

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$domainSkillsRoot = Join-Path $repositoryRoot "plugins/sdd-domain/skills"

function Get-Frontmatter {
    param([string]$SkillMdPath)

    if (-not (Test-Path -LiteralPath $SkillMdPath)) {
        return $null
    }

    $lines = Get-Content -LiteralPath $SkillMdPath
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne "---") {
        return $null
    }

    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "---") {
            $endIndex = $i
            break
        }
    }
    if ($endIndex -lt 0) {
        return $null
    }

    return $lines[1..($endIndex - 1)]
}

function Test-FrontmatterHasKeyValue {
    param([string[]]$FrontmatterLines, [string]$Key, [string]$Value)

    if ($null -eq $FrontmatterLines) {
        return $false
    }

    $pattern = "^" + [regex]::Escape($Key) + ":\s*" + [regex]::Escape($Value) + "\s*$"
    foreach ($line in $FrontmatterLines) {
        if ($line -match $pattern) {
            return $true
        }
    }
    return $false
}

Describe "domain-model SKILL.md is the public entry point (AC-001)" {

    $skillPath = Join-Path $domainSkillsRoot "domain-model/SKILL.md"

    It "exists" {
        Test-Path -LiteralPath $skillPath | Should Be $true
    }

    $frontmatter = Get-Frontmatter -SkillMdPath $skillPath

    It "has parseable frontmatter" {
        ($null -ne $frontmatter) | Should Be $true
    }

    It "carries disable-model-invocation: true" {
        Test-FrontmatterHasKeyValue -FrontmatterLines $frontmatter -Key "disable-model-invocation" -Value "true" | Should Be $true
    }

    It "omits user-invocable: false (it is the public entry)" {
        Test-FrontmatterHasKeyValue -FrontmatterLines $frontmatter -Key "user-invocable" -Value "false" | Should Be $false
    }

    It "declares name: domain-model" {
        Test-FrontmatterHasKeyValue -FrontmatterLines $frontmatter -Key "name" -Value "domain-model" | Should Be $true
    }
}

Describe "sdd-bootstrap:bootstrap precedent confirms the public-entry convention" {

    $bootstrapSkillPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
    $bootstrapFrontmatter = Get-Frontmatter -SkillMdPath $bootstrapSkillPath

    It "bootstrap SKILL.md exists as the reference public-entry skill" {
        Test-Path -LiteralPath $bootstrapSkillPath | Should Be $true
    }

    It "bootstrap carries disable-model-invocation: true" {
        Test-FrontmatterHasKeyValue -FrontmatterLines $bootstrapFrontmatter -Key "disable-model-invocation" -Value "true" | Should Be $true
    }

    It "bootstrap omits user-invocable: false, same as domain-model" {
        Test-FrontmatterHasKeyValue -FrontmatterLines $bootstrapFrontmatter -Key "user-invocable" -Value "false" | Should Be $false
    }
}

Describe "Every other sdd-domain skill built so far is internal (contrast with domain-model)" {

    # Only skills that actually exist on disk at the time this task runs.
    # domain-review-loop (T-005) and domain-sync (T-007) are out of scope
    # for this task and may or may not exist yet; this suite only asserts
    # against skills confirmed present, per the task brief's instruction to
    # scan actual frontmatter rather than assume a fixed skill list.
    $expectedInternalSkills = @("domain-interviewer", "domain-reverse")
    $foundInternalSkills = @()

    foreach ($skillName in $expectedInternalSkills) {
        $path = Join-Path $domainSkillsRoot "$skillName/SKILL.md"
        if (Test-Path -LiteralPath $path) {
            $foundInternalSkills += $skillName
        }
    }

    It "found at least the two internal skills known to be built (domain-interviewer, domain-reverse)" {
        ($foundInternalSkills.Count -ge 2) | Should Be $true
    }

    foreach ($skillName in $expectedInternalSkills) {
        $path = Join-Path $domainSkillsRoot "$skillName/SKILL.md"

        Context "Skill: $skillName" {
            It "SKILL.md exists" {
                Test-Path -LiteralPath $path | Should Be $true
            }

            $fm = Get-Frontmatter -SkillMdPath $path

            It "carries user-invocable: false" {
                Test-FrontmatterHasKeyValue -FrontmatterLines $fm -Key "user-invocable" -Value "false" | Should Be $true
            }

            It "carries disable-model-invocation: true" {
                Test-FrontmatterHasKeyValue -FrontmatterLines $fm -Key "disable-model-invocation" -Value "true" | Should Be $true
            }
        }
    }
}

Describe "Contrast assertion: domain-model differs from every other sdd-domain skill" {

    $allSkillDirs = @()
    if (Test-Path -LiteralPath $domainSkillsRoot) {
        $allSkillDirs = Get-ChildItem -LiteralPath $domainSkillsRoot -Directory | Select-Object -ExpandProperty Name
    }

    It "found at least three sdd-domain skill directories (domain-model plus at least two internal skills)" {
        ($allSkillDirs.Count -ge 3) | Should Be $true
    }

    It "domain-model is present among discovered skill directories" {
        ($allSkillDirs -contains "domain-model") | Should Be $true
    }

    # Only skills with a SKILL.md actually present are classified. A skill
    # directory that exists but has no SKILL.md yet (a sibling task still
    # in progress, e.g. domain-review-loop scaffolding under T-005) is
    # neither public nor internal yet -- it has no frontmatter to read --
    # and must not be treated as a visibility-contract violation by this
    # test, which scans real frontmatter, not directory existence alone.
    $publicSkills = @()
    $internalSkills = @()
    $skillsWithoutFrontmatterYet = @()

    foreach ($skillName in $allSkillDirs) {
        $path = Join-Path $domainSkillsRoot "$skillName/SKILL.md"
        if (-not (Test-Path -LiteralPath $path)) {
            $skillsWithoutFrontmatterYet += $skillName
            continue
        }
        $fm = Get-Frontmatter -SkillMdPath $path
        $isUserInvocableFalse = Test-FrontmatterHasKeyValue -FrontmatterLines $fm -Key "user-invocable" -Value "false"
        if ($isUserInvocableFalse) {
            $internalSkills += $skillName
        } else {
            $publicSkills += $skillName
        }
    }

    It "exactly one sdd-domain skill (with a SKILL.md present) omits user-invocable: false (domain-model only)" {
        $publicSkills.Count | Should Be 1
    }

    It "the one public sdd-domain skill is domain-model" {
        ($publicSkills -contains "domain-model") | Should Be $true
    }

    It "every non-domain-model sdd-domain skill with a SKILL.md present carries user-invocable: false" {
        $nonDomainModelSkills = $allSkillDirs | Where-Object { ($_ -ne "domain-model") -and (-not ($skillsWithoutFrontmatterYet -contains $_)) }
        $allInternal = $true
        foreach ($skillName in $nonDomainModelSkills) {
            if (-not ($internalSkills -contains $skillName)) {
                $allInternal = $false
            }
        }
        $allInternal | Should Be $true
    }
}
