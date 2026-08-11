# Shared F1-F4 fixture-matrix builder for epic-195-a7-compatibility.
# Dot-source this file from acceptance suites; it defines functions only and
# is intentionally not an independent tests/run-all.ps1 entry.

if ($script:_SddFixtureMatrixBuilderSourced) { return }
$script:_SddFixtureMatrixBuilderSourced = $true

function Resolve-FixtureMatrixPhysicalDirectory {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $resolvedPath = (Resolve-Path -LiteralPath $LiteralPath).Path
    $pathRoot = [IO.Path]::GetPathRoot($resolvedPath)
    $currentPath = $pathRoot
    $relativePath = $resolvedPath.Substring($pathRoot.Length)
    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

    foreach ($component in $relativePath.Split($separators, [StringSplitOptions]::RemoveEmptyEntries)) {
        $item = Get-Item -LiteralPath ([IO.Path]::Combine($currentPath, $component)) -Force
        $linkTarget = $item.ResolveLinkTarget($true)
        $currentPath = if ($null -ne $linkTarget) { $linkTarget.FullName } else { $item.FullName }
    }

    return [IO.Path]::GetFullPath($currentPath)
}

$script:FixtureMatrixRepoRoot = Resolve-FixtureMatrixPhysicalDirectory (Join-Path $PSScriptRoot '../..')

function build_fixture {
    param(
        [Parameter(Position = 0)][string]$project_context,
        [Parameter(Position = 1)][string]$agents_marker,
        [Parameter(Position = 2)][string]$capability_enforcement,
        [Parameter(Position = 3)][string]$valid_or_invalid,
        [Parameter(Position = 4)][string]$track_flag
    )

    $argumentCount = $PSBoundParameters.Count + $args.Count
    if ($argumentCount -ne 5) {
        throw "build_fixture: expected 5 arguments, received $argumentCount"
    }
    if (-not (@('absent', 'present') -ccontains $project_context)) {
        throw 'build_fixture: project_context must be absent or present'
    }
    if (-not (@('absent', 'present') -ccontains $agents_marker)) {
        throw 'build_fixture: agents_marker must be absent or present'
    }
    if (-not (@('disabled-legacy', 'advisory', 'required') -ccontains $capability_enforcement)) {
        throw 'build_fixture: capability_enforcement must be disabled-legacy, advisory, or required'
    }
    if (-not (@('valid', 'PROJECT_CONTEXT_INVALID') -ccontains $valid_or_invalid)) {
        throw 'build_fixture: valid_or_invalid must be valid or PROJECT_CONTEXT_INVALID'
    }
    if (-not (@('none', '--full', '--lite') -ccontains $track_flag)) {
        throw 'build_fixture: track_flag must be none, --full, or --lite'
    }
    if ($project_context -ceq 'present' -and $capability_enforcement -ceq 'disabled-legacy') {
        throw 'build_fixture: present project context requires advisory or required enforcement'
    }

    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('sdd-fixture-matrix.' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $fixtureRoot = Resolve-FixtureMatrixPhysicalDirectory $fixtureRoot

    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $repositoryPrefix = $script:FixtureMatrixRepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $insideRepository = [string]::Equals($fixtureRoot, $script:FixtureMatrixRepoRoot, $comparison) -or
        $fixtureRoot.StartsWith($repositoryPrefix, $comparison)
    if ($insideRepository) {
        Remove-Item -LiteralPath $fixtureRoot
        throw 'build_fixture: fixture root resolved inside the repository working tree'
    }

    try {
        $utf8NoBom = [Text.UTF8Encoding]::new($false)
        if ($agents_marker -ceq 'present') {
            [IO.File]::WriteAllText((Join-Path $fixtureRoot 'AGENTS.md'), "spec_profile: lite`n", $utf8NoBom)
        }

        if ($project_context -ceq 'present') {
            $sddDirectory = Join-Path $fixtureRoot 'sdd'
            New-Item -ItemType Directory -Path $sddDirectory | Out-Null
            $schemaVersion = if ($valid_or_invalid -ceq 'PROJECT_CONTEXT_INVALID') {
                'sdd-project-context/v0'
            } else {
                'sdd-project-context/v1'
            }
            $content = @(
                "schema: $schemaVersion"
                'workflow:'
                '  spec_profile: full'
                '  artifact_layout: legacy-seven-layer'
                "  capability_enforcement: $capability_enforcement"
            ) -join "`n"
            [IO.File]::WriteAllText((Join-Path $sddDirectory 'project-context.yaml'), $content + "`n", $utf8NoBom)
        }
    } catch {
        if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
            Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
        }
        throw
    }

    return $fixtureRoot
}
