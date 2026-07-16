$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# TEST-010 / TEST-011: native export contract and check-only rejection paths.
$root = Split-Path -Parent $PSScriptRoot
$sourceLoop = Join-Path $root 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop'
$generator = Join-Path $sourceLoop 'scripts/generate-guard-invariants.py'
$generated = Join-Path $sourceLoop 'scripts/generated'
$required = @(
    'SCHEMA_VERSION', 'PROTECTED_GATE_SUFFIXES', 'PROTECTED_GATE_PLUGIN_JSON_SUFFIXES',
    'SHELL_COMPOUND_RE', 'SHELL_WRITE_ARG_CMDS', 'SHELL_WRITE_DEST_CMDS',
    'SHELL_PS_WRITE_CMDS', 'SHELL_INDIRECT_CMDS', 'SHELL_UNSAFE_TOKEN_CHARS',
    'SHELL_REDIRECT_TOKEN_RE', 'SHELL_FD_DUP_RE', 'SHELL_CD_CMDS',
    'SHELL_SUDO_WRITE_RE', 'SHELL_READ_ONLY_START_RE',
    'SUDO_SIGNATURE_HEX_LENGTH', 'PHASE2_HUMAN_COPY_TARGETS'
)
$passCount = 0
$failCount = 0

function Ok([string]$Message) { Write-Host "ok: $Message"; $script:passCount++ }
function Bad([string]$Message) { Write-Host "FAIL: $Message"; $script:failCount++ }
function Assert-True([bool]$Condition, [string]$Message) { if ($Condition) { Ok $Message } else { Bad $Message } }
function Get-PlatformCommand([string]$WindowsName, [string]$PosixName, [string]$Label) {
    $name = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $WindowsName } else { $PosixName }
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($null -eq $command) { throw "$Label command is required: $name" }
    return $command.Source
}

$pythonCommand = Get-PlatformCommand 'python.exe' 'python3' 'Python'
$nodeCommand = Get-PlatformCommand 'node.exe' 'node' 'Node'
$powerShellCommand = Get-PlatformCommand 'powershell.exe' 'pwsh' 'PowerShell'

Assert-True (Test-Path -LiteralPath $generator -PathType Leaf) 'staged generator exists'
foreach ($name in @('guard_invariants.py', 'guard-invariants.generated.js', 'guard-invariants.generated.ps1', 'guard-invariants.generated.sh')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $generated $name) -PathType Leaf) "generated output exists: $name"
}

& $pythonCommand $generator --check
Assert-True ($LASTEXITCODE -eq 0) 'generator --check succeeds'

$pyCheck = @"
import importlib.util
import sys
path = sys.argv[1]
spec = importlib.util.spec_from_file_location('check', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
required = set(sys.argv[2].split(','))
assert {name for name in dir(module) if name.isupper()} == required
assert module.SCHEMA_VERSION == 1 and module.SUDO_SIGNATURE_HEX_LENGTH == 64
"@
$pyFile = Join-Path ([IO.Path]::GetTempPath()) ('phase2-invariants-' + [guid]::NewGuid().ToString() + '.py')
[IO.File]::WriteAllText($pyFile, $pyCheck, [Text.Encoding]::ASCII)
try {
    & $pythonCommand $pyFile (Join-Path $generated 'guard_invariants.py') ($required -join ',')
    Assert-True ($LASTEXITCODE -eq 0) 'Python output exports the exact v1 key set'
} finally { Remove-Item -LiteralPath $pyFile -Force -ErrorAction SilentlyContinue }

$actual = & $nodeCommand -e "const x=require(process.argv[1]); console.log(Object.keys(x).sort().join(','))" (Join-Path $generated 'guard-invariants.generated.js')
Assert-True (($actual -join '') -eq (($required | Sort-Object) -join ',')) 'Node output exports the exact v1 key set'

$GuardInvariants = $null
. (Join-Path $generated 'guard-invariants.generated.ps1')
Assert-True ((@($GuardInvariants.Keys) | Sort-Object) -join ',' -eq (($required | Sort-Object) -join ',')) 'PowerShell output exports the exact v1 key set'
Assert-True (($GuardInvariants.SCHEMA_VERSION -eq 1) -and ($GuardInvariants.SUDO_SIGNATURE_HEX_LENGTH -eq 64)) 'PowerShell schema/version constants are v1/64'

function New-SourceLoopFixture([string]$Prefix) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ($Prefix + '-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    Copy-Item -LiteralPath $sourceLoop -Destination $fixture -Recurse -Force
    return Join-Path $fixture 'sdd-quality-loop'
}

function Invoke-GeneratorCheck([string]$Fixture) {
    $fixtureGenerator = Join-Path $Fixture 'scripts/generate-guard-invariants.py'
    $ErrorActionPreference = 'Continue'
    try {
        & $pythonCommand $fixtureGenerator --check 1>$null 2>$null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
}

# TEST-011: invalid canonical syntax and an OSError while reading canonical
# input both fail closed in --check mode without touching staged candidates.
$generatorFixture = New-SourceLoopFixture 'phase2-generator-malformed'
try {
    [IO.File]::WriteAllText((Join-Path $generatorFixture 'references/guard-invariants.json'), '{ malformed', [Text.Encoding]::UTF8)
    Assert-True ((Invoke-GeneratorCheck $generatorFixture) -ne 0) 'generator --check rejects malformed canonical JSON'
} finally { Remove-Item -LiteralPath (Split-Path -Parent $generatorFixture) -Recurse -Force -ErrorAction SilentlyContinue }

$generatorFixture = New-SourceLoopFixture 'phase2-generator-io'
try {
    $canonical = Join-Path $generatorFixture 'references/guard-invariants.json'
    Move-Item -LiteralPath $canonical -Destination ($canonical + '.backing') -Force
    New-Item -ItemType Directory -Path $canonical -Force | Out-Null
    Assert-True ((Invoke-GeneratorCheck $generatorFixture) -ne 0) 'generator --check rejects canonical read I/O errors'
} finally { Remove-Item -LiteralPath (Split-Path -Parent $generatorFixture) -Recurse -Force -ErrorAction SilentlyContinue }

# TEST-012: all guard runtimes load only the module next to their script.
$scripts = Join-Path $sourceLoop 'scripts'
$pyGuard = Join-Path $scripts 'sdd-hook-guard.py'
$jsGuard = Join-Path $scripts 'sdd-hook-guard.js'
$psGuard = Join-Path $scripts 'sdd-hook-guard.ps1'
$shGuard = Join-Path $scripts 'sdd-hook-guard.sh'
function Assert-Contains([string]$Path, [string]$Needle, [string]$Message) {
    Assert-True ((Test-Path -LiteralPath $Path -PathType Leaf) -and (Get-Content -Raw -LiteralPath $Path).Contains($Needle)) $Message
}
function Assert-NotContains([string]$Path, [string]$Needle, [string]$Message) {
    Assert-True ((Test-Path -LiteralPath $Path -PathType Leaf) -and -not (Get-Content -Raw -LiteralPath $Path).Contains($Needle)) $Message
}
Assert-Contains $pyGuard 'spec_from_file_location' 'Python uses explicit importlib fixed loader'
Assert-Contains $pyGuard 'guard_invariants.py' 'Python loader names fixed native module'
Assert-Contains $jsGuard 'guard-invariants.generated.js' 'Node loader names fixed native module'
Assert-Contains $jsGuard 'path.join(__dirname, "generated"' 'Node loader is not CWD-relative'
Assert-Contains $psGuard 'guard-invariants.generated.ps1' 'PowerShell loader names fixed native module'
Assert-Contains $psGuard '$PSScriptRoot' 'PowerShell loader is not PWD-relative'
Assert-Contains $shGuard 'guard-invariants.generated.sh' 'dispatcher sources only schema/provenance output'
foreach ($guard in @($pyGuard, $jsGuard, $psGuard, $shGuard)) {
    Assert-NotContains $guard 'guard-invariants.json' "runtime avoids canonical JSON: $([IO.Path]::GetFileName($guard))"
}

function Invoke-Exit([string]$Command, [string[]]$Arguments, [string]$Payload, [string]$WorkingDirectory) {
    $saved = (Get-Location).Path
    $savedPayload = $env:PAYLOAD
    try {
        Set-Location -LiteralPath $WorkingDirectory
        $env:PAYLOAD = $Payload
        $ErrorActionPreference = 'Continue'
        & $Command @Arguments 2>$null | Out-Null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
        if ($null -eq $savedPayload) { Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue } else { $env:PAYLOAD = $savedPayload }
        Set-Location -LiteralPath $saved
    }
}

$loaderWork = Join-Path ([IO.Path]::GetTempPath()) ('phase2-loader-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $loaderWork | Out-Null
try {
    $payload = '{"tool_name":"bash","tool_input":{"command":"cat plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'
    Assert-True ((Invoke-Exit $pythonCommand @($pyGuard, '--emit', 'exit') $payload $loaderWork) -eq 0) 'Python staged guard preserves shared read-only corpus from another CWD'
    Assert-True ((Invoke-Exit $nodeCommand @($jsGuard, '--emit', 'exit') $payload $loaderWork) -eq 0) 'Node staged guard preserves shared read-only corpus from another CWD'
    Assert-True ((Invoke-Exit $powerShellCommand @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $psGuard, '-Emit', 'exit') $payload $loaderWork) -eq 0) 'PowerShell staged guard preserves shared read-only corpus from another CWD'
} finally {
    Remove-Item -LiteralPath $loaderWork -Recurse -Force -ErrorAction SilentlyContinue
}

# TEST-012: each decision-making runtime must deny when its fixed generated
# module is missing or has an unconsumed export. Fixtures are copied trees,
# never the staged candidate itself.
$loaderSpecs = @(
    [PSCustomObject]@{ Runtime = 'Python'; Command = $pythonCommand; Guard = 'scripts/sdd-hook-guard.py'; Module = 'scripts/generated/guard_invariants.py'; Arguments = @('--emit', 'exit'); Poison = "UNCONSUMED_V1_EXPORT = 1`n" },
    [PSCustomObject]@{ Runtime = 'Node'; Command = $nodeCommand; Guard = 'scripts/sdd-hook-guard.js'; Module = 'scripts/generated/guard-invariants.generated.js'; Arguments = @('--emit', 'exit'); Poison = "module.exports = { UNCONSUMED_V1_EXPORT: 1 };`n" },
    [PSCustomObject]@{ Runtime = 'PowerShell'; Command = $powerShellCommand; Guard = 'scripts/sdd-hook-guard.ps1'; Module = 'scripts/generated/guard-invariants.generated.ps1'; Arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File'); Poison = "`$GuardInvariants = [ordered]@{ UNCONSUMED_V1_EXPORT = 1 }`n" }
)
foreach ($spec in $loaderSpecs) {
    $fixture = New-SourceLoopFixture ('phase2-loader-missing-' + $spec.Runtime.ToLowerInvariant())
    try {
        $guard = Join-Path $fixture $spec.Guard
        $module = Join-Path $fixture $spec.Module
        Remove-Item -LiteralPath $module -Force
        $arguments = @($spec.Arguments + @($guard))
        if ($spec.Runtime -ne 'PowerShell') { $arguments = @($guard) + $spec.Arguments } else { $arguments += @('-Emit', 'exit') }
        Assert-True ((Invoke-Exit $spec.Command $arguments $payload (Split-Path -Parent $fixture)) -ne 0) "TEST-012 $($spec.Runtime) denies a missing fixed generated module"
    } finally { Remove-Item -LiteralPath (Split-Path -Parent $fixture) -Recurse -Force -ErrorAction SilentlyContinue }

    $fixture = New-SourceLoopFixture ('phase2-loader-poisoned-' + $spec.Runtime.ToLowerInvariant())
    try {
        $guard = Join-Path $fixture $spec.Guard
        $module = Join-Path $fixture $spec.Module
        [IO.File]::WriteAllText($module, $spec.Poison, [Text.Encoding]::ASCII)
        $arguments = @($spec.Arguments + @($guard))
        if ($spec.Runtime -ne 'PowerShell') { $arguments = @($guard) + $spec.Arguments } else { $arguments += @('-Emit', 'exit') }
        Assert-True ((Invoke-Exit $spec.Command $arguments $payload (Split-Path -Parent $fixture)) -ne 0) "TEST-012 $($spec.Runtime) denies an unconsumed fixed-module export"
    } finally { Remove-Item -LiteralPath (Split-Path -Parent $fixture) -Recurse -Force -ErrorAction SilentlyContinue }
}

# The superseded full-batch Slice 3 experiment is retained only as an inactive
# record while the bootstrap validator is implemented as the current slice.
<#
# TEST-013 RED gate: the immutable runner, CI candidate, and complete manifest
# are staged only after this test records their absence.
$stageRoot = Join-Path $root 'specs/epic-136-phase2-gates/human-copy'
$runner = Join-Path $stageRoot 'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
$stagedCi = Join-Path $stageRoot '.github/workflows/test.yml'
$manifest = Join-Path $stageRoot 'MANIFEST.sha256'
$test13Targets = @(
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
    'plugins/sdd-quality-loop/scripts/check-contract.ps1',
    'plugins/sdd-lite/references/risk-upgrade-policy.md',
    'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
    'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
    'plugins/sdd-lite/skills/lite-spec/SKILL.md',
    'plugins/sdd-ship/skills/ship/SKILL.md',
    'plugins/sdd-quality-loop/references/guard-invariants.json',
    'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py',
    'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh',
    '.github/workflows/test.yml',
    'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
)

function Write-Test13Text([string]$Path, [string[]]$Lines) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), $encoding)
}

function Test-Test13Manifest([string]$StagePath) {
    $path = Join-Path $StagePath 'MANIFEST.sha256'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $lines = @(Get-Content -LiteralPath $path)
    if ($lines.Count -ne $test13Targets.Count) { return $false }
    $seen = @{}
    foreach ($line in $lines) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { return $false }
        $digest = $matches[1]
        $target = $matches[2]
        if ($seen.ContainsKey($target) -or -not ($test13Targets -contains $target)) { return $false }
        $source = Join-Path $StagePath $target
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { return $false }
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $digest) { return $false }
        $seen[$target] = $true
    }
    foreach ($target in $test13Targets) { if (-not $seen.ContainsKey($target)) { return $false } }
    return $true
}

function New-Test13Fixture([bool]$WithLiveCanonical) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('phase2-runner-' + [guid]::NewGuid().ToString())
    $featureParent = Join-Path $fixture 'specs/epic-136-phase2-gates'
    New-Item -ItemType Directory -Path $featureParent -Force | Out-Null
    Copy-Item -LiteralPath $stageRoot -Destination $featureParent -Recurse -Force
    $fixtureTests = Join-Path $fixture 'tests'
    New-Item -ItemType Directory -Path $fixtureTests -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'tests/phase2-guard-invariants.tests.ps1') -Destination $fixtureTests -Force
    Copy-Item -LiteralPath (Join-Path $root 'tests/phase2-guard-invariants.tests.sh') -Destination $fixtureTests -Force
    if ($WithLiveCanonical) {
        $liveCanonical = Join-Path $fixture 'plugins/sdd-quality-loop/references/guard-invariants.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $liveCanonical) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json') -Destination $liveCanonical -Force
    }
    return $fixture
}

function Write-Test13Manifest([string]$Fixture) {
    $fixtureStage = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy'
    $lines = @()
    foreach ($target in $test13Targets) {
        $source = Join-Path $fixtureStage $target
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "missing fixture source: $target" }
        $lines += ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $target)
    }
    Write-Test13Text (Join-Path $fixtureStage 'MANIFEST.sha256') $lines
    return $lines
}

function Set-Test13StagedTargets([string]$Fixture, [string[]]$Targets) {
    $path = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json'
    $data = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    $data.phase2_human_copy_targets = @($Targets)
    Write-Test13Text $path @($data | ConvertTo-Json -Depth 8)
}

function Invoke-Test13Runner([string]$Fixture, [bool]$Bootstrap) {
    $fixtureRunner = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
    if (-not (Test-Path -LiteralPath $fixtureRunner -PathType Leaf)) { return 127 }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $fixtureRunner)
    if ($Bootstrap) { $arguments += '-Bootstrap' }
    $ErrorActionPreference = 'Continue'
    try {
        & powershell.exe @arguments 1>$null 2>$null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
}

function Try-NewTest13Junction([string]$Link, [string]$Target) {
    try {
        New-Item -ItemType Junction -Path $Link -Target $Target -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

Assert-True (Test-Path -LiteralPath $runner -PathType Leaf) 'TEST-013 staged immutable runner exists'
Assert-True (Test-Path -LiteralPath $stagedCi -PathType Leaf) 'TEST-013 staged CI candidate exists'
Assert-True (Test-Test13Manifest $stageRoot) 'TEST-013 manifest has exact lowercase hashes and 18 staged targets'

$runnerIsAsciiNoBom = $false
if (Test-Path -LiteralPath $runner -PathType Leaf) {
    $runnerBytes = [IO.File]::ReadAllBytes($runner)
    $runnerIsAsciiNoBom = (($runnerBytes.Length -lt 3 -or -not (($runnerBytes[0] -eq 239) -and ($runnerBytes[1] -eq 187) -and ($runnerBytes[2] -eq 191))) -and (($runnerBytes | Where-Object { $_ -gt 127 }).Count -eq 0))
}
Assert-True $runnerIsAsciiNoBom 'TEST-013 runner is PowerShell 5.1 ASCII/no-BOM'
if (Test-Path -LiteralPath $runner -PathType Leaf) {
    $runnerText = Get-Content -Raw -LiteralPath $runner
    Assert-True ((-not $runnerText.Contains('LinkType')) -and $runnerText.Contains('ReparsePoint') -and $runnerText.Contains('before copying any file')) 'TEST-013 runner rejects reparse points and prevalidates all hashes'
} else { Bad 'TEST-013 runner rejects reparse points and prevalidates all hashes' }

if (Test-Path -LiteralPath $stagedCi -PathType Leaf) {
    $ciText = Get-Content -Raw -LiteralPath $stagedCi
    Assert-True (($ciText.IndexOf('generate-guard-invariants.py --check') -ge 0) -and ($ciText.IndexOf('generate-guard-invariants.py --check') -lt $ciText.IndexOf('Test hook guards'))) 'TEST-013 CI runs generator check before guard suites'
} else { Bad 'TEST-013 CI runs generator check before guard suites' }

$allCandidatesExist = (@($test13Targets | Where-Object { -not (Test-Path -LiteralPath (Join-Path $stageRoot $_) -PathType Leaf) }).Count -eq 0)
Assert-True $allCandidatesExist 'TEST-013 all protected candidates are staged'

if ($env:SDD_PHASE2_RUNNER_CHILD -eq '1') {
    Ok 'TEST-013 runner child avoids recursive disposable-fixture execution'
} elseif ($allCandidatesExist -and (Test-Test13Manifest $stageRoot)) {
    $fixture = New-Test13Fixture $false
    try {
        Write-Test13Manifest $fixture | Out-Null
        Assert-True ((Invoke-Test13Runner $fixture $true) -eq 0) 'TEST-013 bootstrap installs exact batch, then runs generator and focused suites'
        $copyOk = $true
        foreach ($target in $test13Targets) {
            $source = Join-Path $fixture ('specs/epic-136-phase2-gates/human-copy/' + $target)
            $targetPath = Join-Path $fixture $target
            if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf) -or ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash)) { $copyOk = $false }
        }
        Assert-True $copyOk 'TEST-013 bootstrap copy order leaves every target equal to its staged source'
        $guard = Join-Path $fixture 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1'
        $payload = '{"tool_name":"write","tool_input":{"file_path":"' + ((Join-Path $fixture '.github/workflows/test.yml').Replace('\', '/')) + '","content":"changed"}}'
        $savedPayload = $env:PAYLOAD
        try {
            $env:PAYLOAD = $payload
            $ErrorActionPreference = 'Continue'
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guard -Emit exit 1>$null 2>$null
            $guardExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = 'Stop'
            if ($null -eq $savedPayload) { Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue } else { $env:PAYLOAD = $savedPayload }
        }
        Assert-True ($guardExit -eq 2) 'TEST-013 installed guard denies protected test.yml writes'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-Test13Fixture $true
    try {
        Write-Test13Manifest $fixture | Out-Null
        Assert-True ((Invoke-Test13Runner $fixture $false) -eq 0) 'TEST-013 normal update uses the installed canonical authority'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    $fixture = New-Test13Fixture $false
    try {
        $expanded = @($test13Targets + 'outside/inventory.txt')
        Set-Test13StagedTargets $fixture $expanded
        Write-Test13Manifest $fixture | Out-Null
        Assert-True ((Invoke-Test13Runner $fixture $true) -ne 0) 'TEST-013 bootstrap rejects staged inventory expansion'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    $fixture = New-Test13Fixture $true
    try {
        $reordered = @($test13Targets)
        [Array]::Reverse($reordered)
        Set-Test13StagedTargets $fixture $reordered
        Write-Test13Manifest $fixture | Out-Null
        Assert-True ((Invoke-Test13Runner $fixture $false) -ne 0) 'TEST-013 normal update rejects staged/live canonical list mismatch'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    foreach ($case in @('malformed', 'hash', 'missing', 'duplicate', 'absolute', 'traversal')) {
        $fixture = New-Test13Fixture $false
        try {
            $lines = @(Write-Test13Manifest $fixture)
            if ($case -eq 'malformed') { $lines[0] = 'not a manifest line' }
            if ($case -eq 'hash') {
                $replacement = '0'
                if ($lines[0].Substring(0, 1) -eq '0') { $replacement = '1' }
                $lines[0] = $replacement + $lines[0].Substring(1)
            }
            if ($case -eq 'missing') { $lines = @($lines | Select-Object -Skip 1) }
            if ($case -eq 'duplicate') { $lines[$lines.Count - 1] = $lines[0] }
            if ($case -eq 'absolute') { $lines[0] = ($lines[0].Substring(0, 64) + '  C:/outside.txt') }
            if ($case -eq 'traversal') { $lines[0] = ($lines[0].Substring(0, 64) + '  ../outside.txt') }
            Write-Test13Text (Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256') $lines
            Assert-True ((Invoke-Test13Runner $fixture $true) -ne 0) "TEST-013 runner rejects $case manifest input"
        } finally { Remove-BootstrapFixture $fixture }
    }

    $fixture = New-Test13Fixture $false
    try {
        Write-Test13Manifest $fixture | Out-Null
        $remappedSource = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-lite/references/risk-upgrade-policy.md'
        $remappedDirectory = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/remapped'
        New-Item -ItemType Directory -Path $remappedDirectory -Force | Out-Null
        Move-Item -LiteralPath $remappedSource -Destination (Join-Path $remappedDirectory 'risk-upgrade-policy.md') -Force
        Assert-True ((Invoke-Test13Runner $fixture $true) -ne 0) 'TEST-013 runner rejects remapped staged source'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-Test13Fixture $false
    try {
        Write-Test13Manifest $fixture | Out-Null
        $sentinel = Join-Path $fixture '.github/workflows/test.yml'
        New-Item -ItemType Directory -Path (Split-Path -Parent $sentinel) -Force | Out-Null
        Write-Test13Text $sentinel @('sentinel')
        $before = [IO.File]::ReadAllBytes($sentinel)
        [IO.File]::AppendAllText((Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'), "`n# hash mismatch`n", (New-Object System.Text.UTF8Encoding($false)))
        $exitCode = Invoke-Test13Runner $fixture $true
        $after = [IO.File]::ReadAllBytes($sentinel)
        Assert-True (($exitCode -ne 0) -and ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String($after))) 'TEST-013 validates every hash before any live copy'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-Test13Fixture $false
    try {
        Write-Test13Manifest $fixture | Out-Null
        $sourceParent = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-lite/references'
        $sourceBacking = $sourceParent + '.backing'
        Move-Item -LiteralPath $sourceParent -Destination $sourceBacking -Force
        if (Try-NewTest13Junction $sourceParent $sourceBacking) {
            Assert-True ((Invoke-Test13Runner $fixture $true) -ne 0) 'TEST-013 runner rejects staged-source reparse points'
        } else { Ok 'TEST-013 staged-source reparse test skipped on unsupported host' }
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-Test13Fixture $false
    try {
        Write-Test13Manifest $fixture | Out-Null
        $targetParent = Join-Path $fixture 'plugins/sdd-lite/references'
        $targetBacking = Join-Path $fixture 'target-reparse-backing'
        New-Item -ItemType Directory -Path (Split-Path -Parent $targetParent) -Force | Out-Null
        New-Item -ItemType Directory -Path $targetBacking -Force | Out-Null
        if (Try-NewTest13Junction $targetParent $targetBacking) {
            Assert-True ((Invoke-Test13Runner $fixture $true) -ne 0) 'TEST-013 runner rejects target-parent reparse points'
        } else { Ok 'TEST-013 target-parent reparse test skipped on unsupported host' }
    } finally { Remove-BootstrapFixture $fixture }
} else {
    Bad 'TEST-013 disposable runner fixtures require all staged candidates and the exact manifest'
}
#>

# TEST-013 Slice 3: isolated bootstrap validation only. The runner deliberately
# stops after validating all 18 staged hashes; no fixture live target is copied.
$bootstrapTargets = @(
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
    'plugins/sdd-quality-loop/scripts/check-contract.ps1',
    'plugins/sdd-lite/references/risk-upgrade-policy.md',
    'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
    'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
    'plugins/sdd-lite/skills/lite-spec/SKILL.md',
    'plugins/sdd-ship/skills/ship/SKILL.md',
    'plugins/sdd-quality-loop/references/guard-invariants.json',
    'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py',
    'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh',
    '.github/workflows/test.yml',
    'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
)
$bootstrapStage = Join-Path $root 'specs/epic-136-phase2-gates/human-copy'
$bootstrapRunner = Join-Path $bootstrapStage 'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
$bootstrapManifest = Join-Path $bootstrapStage 'MANIFEST.sha256'
$bootstrapCi = Join-Path $bootstrapStage '.github/workflows/test.yml'

function Test-FinalStagedManifest {
    if (-not (Test-Path -LiteralPath $bootstrapManifest -PathType Leaf)) { return $false }
    $lines = @([IO.File]::ReadAllLines($bootstrapManifest))
    if ($lines.Count -ne $bootstrapTargets.Count) { return $false }
    for ($index = 0; $index -lt $bootstrapTargets.Count; $index++) {
        $target = $bootstrapTargets[$index]
        $candidate = Join-Path $bootstrapStage $target
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $false }
        $expected = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $target
        if ($lines[$index] -cne $expected) { return $false }
    }
    return $true
}

function Write-BootstrapText([string]$Path, [string[]]$Lines) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), $encoding)
}

function New-BootstrapFixture {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('phase2-bootstrap-' + [guid]::NewGuid().ToString())
    $fixtureFull = [IO.Path]::GetFullPath($fixture)
    $workspaceFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    if ($fixtureFull.StartsWith($workspaceFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'fixture root must be outside the repository workspace' }
    $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
    foreach ($target in $bootstrapTargets) {
        $source = Join-Path $fixtureStage $target
        New-Item -ItemType Directory -Path (Split-Path -Parent $source) -Force | Out-Null
        if ($target -eq 'plugins/sdd-quality-loop/references/guard-invariants.json') {
            Copy-Item -LiteralPath (Join-Path $bootstrapStage $target) -Destination $source -Force
        } elseif ($target -eq 'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1') {
            Copy-Item -LiteralPath $bootstrapRunner -Destination $source -Force
        } else {
            Write-BootstrapText $source @("fixture candidate: $target")
        }
    }
    $lines = @()
    foreach ($target in $bootstrapTargets) {
        $source = Join-Path $fixtureStage $target
        $lines += ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $target)
    }
    Write-BootstrapText (Join-Path $fixtureStage 'MANIFEST.sha256') $lines
    return $fixture
}

function Invoke-BootstrapValidator([string]$Fixture) {
    $runner = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
    $ErrorActionPreference = 'Continue'
    try {
        & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File $runner -Bootstrap 1>$null 2>$null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
}

function Install-FixtureCanonical([string]$Fixture) {
    $source = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json'
    $destination = Join-Path $Fixture 'plugins/sdd-quality-loop/references/guard-invariants.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    return $destination
}

function Invoke-NormalUpdateValidator([string]$Fixture) {
    $runner = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
    $ErrorActionPreference = 'Continue'
    try {
        & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File $runner -RepositoryRoot $Fixture 1>$null 2>$null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
}

function Remove-BootstrapFixture([string]$Fixture) {
    $fixtureFull = [IO.Path]::GetFullPath($Fixture)
    $workspaceFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    if ($fixtureFull.StartsWith($workspaceFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'refusing to clean a fixture inside the repository workspace' }
    Remove-Item -LiteralPath $fixtureFull -Recurse -Force -ErrorAction SilentlyContinue
}

function Try-NewFixtureSymbolicLink([string]$Path, [string]$Target) {
    try {
        New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Try-NewFixtureJunction([string]$Path, [string]$Target) {
    try {
        New-Item -ItemType Junction -Path $Path -Target $Target -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

$allStagedCandidatesExist = (@($bootstrapTargets | Where-Object { -not (Test-Path -LiteralPath (Join-Path $bootstrapStage $_) -PathType Leaf) }).Count -eq 0)
Assert-True $allStagedCandidatesExist 'TEST-013 staged batch contains each exact protected candidate'
Assert-True (Test-FinalStagedManifest) 'TEST-013 final manifest has exact ordered lowercase staged hashes'
if (Test-Path -LiteralPath $bootstrapCi -PathType Leaf) {
    $ciText = Get-Content -Raw -LiteralPath $bootstrapCi
    $checkout = $ciText.IndexOf('uses: actions/checkout')
    $firstValidation = $ciText.IndexOf('Install recorded Claude Code CLI')
    $firstGuardSuite = $ciText.IndexOf('Test hook guards')
    $windowsGenerator = [regex]::IsMatch($ciText, "(?ms)- name: Verify generated guard invariants \(Windows\).*?if: runner\.os == 'Windows'.*?shell: pwsh.*?run: python ./plugins/sdd-quality-loop/scripts/generate-guard-invariants\.py --check")
    $posixGenerator = [regex]::IsMatch($ciText, "(?ms)- name: Verify generated guard invariants \(POSIX\).*?if: runner\.os != 'Windows'.*?shell: bash.*?run: python3 ./plugins/sdd-quality-loop/scripts/generate-guard-invariants\.py --check")
    $windowsInvariantSuite = [regex]::IsMatch($ciText, "(?ms)- name: Test Phase 2 guard invariants \(pwsh\).*?if: runner\.os == 'Windows'.*?shell: pwsh.*?run: ./tests/phase2-guard-invariants\.tests\.ps1")
    $posixInvariantSuite = [regex]::IsMatch($ciText, "(?ms)- name: Test Phase 2 guard invariants \(bash\).*?if: runner\.os != 'Windows'.*?shell: bash.*?run: bash ./tests/phase2-guard-invariants\.tests\.sh")
    $generatorBeforeValidation = (($ciText.IndexOf('Verify generated guard invariants (Windows)') -gt $checkout) -and ($ciText.IndexOf('Verify generated guard invariants (POSIX)') -gt $checkout) -and ($ciText.IndexOf('Verify generated guard invariants (Windows)') -lt $firstValidation) -and ($ciText.IndexOf('Verify generated guard invariants (POSIX)') -lt $firstValidation) -and ($ciText.IndexOf('Verify generated guard invariants (Windows)') -lt $firstGuardSuite) -and ($ciText.IndexOf('Verify generated guard invariants (POSIX)') -lt $firstGuardSuite))
    Assert-True (($checkout -ge 0) -and ($firstValidation -ge 0) -and ($firstGuardSuite -ge 0) -and $windowsGenerator -and $posixGenerator -and $windowsInvariantSuite -and $posixInvariantSuite -and $generatorBeforeValidation) 'TEST-011 staged CI uses platform-native generator and invariant suites before validation and guards'
} else { Bad 'TEST-011 staged CI uses platform-native generator and invariant suites before validation and guards' }

function New-InstallationFixture {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('phase2-install-' + [guid]::NewGuid().ToString())
    $fixtureFull = [IO.Path]::GetFullPath($fixture)
    $workspaceFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    if ($fixtureFull.StartsWith($workspaceFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'installation fixture root must be outside the repository workspace' }
    $featureParent = Join-Path $fixture 'specs/epic-136-phase2-gates'
    New-Item -ItemType Directory -Path $featureParent -Force | Out-Null
    Copy-Item -LiteralPath $bootstrapStage -Destination $featureParent -Recurse -Force
    $fixtureTests = Join-Path $fixture 'tests'
    New-Item -ItemType Directory -Path $fixtureTests -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'tests/phase2-guard-invariants.tests.ps1') -Destination $fixtureTests -Force
    Copy-Item -LiteralPath (Join-Path $root 'tests/phase2-guard-invariants.tests.sh') -Destination $fixtureTests -Force
    $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
    $lines = @()
    foreach ($target in $bootstrapTargets) {
        $source = Join-Path $fixtureStage $target
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "installation fixture is missing staged candidate: $target" }
        $lines += ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $target)
    }
    Write-BootstrapText (Join-Path $fixtureStage 'MANIFEST.sha256') $lines
    return $fixture
}

function Update-FixtureManifest([string]$Fixture) {
    $fixtureStage = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy'
    $lines = @()
    foreach ($target in $bootstrapTargets) {
        $source = Join-Path $fixtureStage $target
        $lines += ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $target)
    }
    Write-BootstrapText (Join-Path $fixtureStage 'MANIFEST.sha256') $lines
}

function Patch-FixtureRunner([string]$Fixture, [string]$Marker, [string]$Replacement) {
    $runner = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
    $text = [IO.File]::ReadAllText($runner, [Text.Encoding]::ASCII)
    if ([regex]::Matches($text, [regex]::Escape($Marker)).Count -ne 1) { return $false }
    [IO.File]::WriteAllText($runner, $text.Replace($Marker, $Replacement), [Text.Encoding]::ASCII)
    Update-FixtureManifest $Fixture
    return $true
}

function Initialize-FixturePreviousBatch([string]$Fixture) {
    $fixtureStage = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy'
    $hashes = @{}
    $bytes = @{}
    $immutableGenerated = @(
        'plugins/sdd-quality-loop/references/guard-invariants.json',
        'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py',
        'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py',
        'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js',
        'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1',
        'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh'
    )
    foreach ($target in $bootstrapTargets) {
        $source = Join-Path $fixtureStage $target
        $destination = Join-Path $Fixture $target
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
        if ($target -notin $immutableGenerated) {
            $comment = if ($target -like '*.js') { "`n// fixture previous batch`n" } else { "`n# fixture previous batch`n" }
            [IO.File]::AppendAllText($destination, $comment, [Text.Encoding]::ASCII)
        }
        $raw = [IO.File]::ReadAllBytes($destination)
        $bytes[$target] = [Convert]::ToBase64String($raw)
        $hashes[$target] = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return [PSCustomObject]@{ Hashes = $hashes; Bytes = $bytes }
}

function Test-FixtureBatchHashes([string]$Fixture, $Expected) {
    foreach ($target in $bootstrapTargets) {
        $destination = Join-Path $Fixture $target
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { return $false }
        if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Expected[$target]) { return $false }
    }
    return $true
}

function Restore-FixtureRollbackSources([string]$Fixture, $PreviousBytes) {
    $fixtureStage = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy'
    foreach ($target in $bootstrapTargets) {
        [IO.File]::WriteAllBytes((Join-Path $fixtureStage $target), [Convert]::FromBase64String([string]$PreviousBytes[$target]))
    }
    Update-FixtureManifest $Fixture
}

function Try-NewFixtureHardLink([string]$Path, [string]$Target) {
    try {
        New-Item -ItemType HardLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Invoke-IsolatedInstall([string]$Fixture) {
    $runner = Join-Path $Fixture 'specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
    $ErrorActionPreference = 'Continue'
    try {
        & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File $runner -Bootstrap -RepositoryRoot $Fixture 1>$null 2>$null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
}

Assert-True (Test-Path -LiteralPath $bootstrapRunner -PathType Leaf) 'TEST-013 staged bootstrap validator exists'
if (Test-Path -LiteralPath $bootstrapRunner -PathType Leaf) {
    $bytes = [IO.File]::ReadAllBytes($bootstrapRunner)
    $asciiNoBom = (($bytes.Length -lt 3 -or -not (($bytes[0] -eq 239) -and ($bytes[1] -eq 187) -and ($bytes[2] -eq 191))) -and (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0))
    Assert-True $asciiNoBom 'TEST-013 bootstrap validator is ASCII/no-BOM for PowerShell 5.1'

    $runnerText = [Text.Encoding]::ASCII.GetString($bytes)
    $nativeNames = @(
        'class AnchoredCopySession', 'NtCreateFile', 'RootDirectory',
        'FILE_OPEN_REPARSE_POINT', 'GetFileInformationByHandleEx',
        'SetFileInformationByHandle', 'NtSetInformationFile', 'FileRenameInfo', 'ReplaceIfExists',
        'DangerousAddRef', 'DangerousRelease'
    )
    $nativeContract = (@($nativeNames | Where-Object { -not $runnerText.Contains($_) }).Count -eq 0)
    Assert-True $nativeContract 'TEST-013 runner binds the reviewed anchored native API contract'
    Assert-True (-not $runnerText.Contains('[IO.File]::Copy') -and -not $runnerText.Contains('Get-FileHash')) 'TEST-013 runner has no path-based copy or source-hash fallback'
    Assert-True ($runnerText.Contains("LanguageMode -ne 'FullLanguage'") -and $runnerText.Contains("DriveFormat -ne 'NTFS'")) 'TEST-013 runner fails closed outside FullLanguage and local NTFS capability floor'
    if ($env:SDD_PHASE2_RUNNER_CHILD -ne '1') {
        $fixtureMarkers = @('// TEST_FIXTURE_SOURCE_SUBSTITUTION', '// TEST_FIXTURE_PARENT_SUBSTITUTION', '// TEST_FIXTURE_AFTER_PREPARE_ITEM', '// TEST_FIXTURE_BEFORE_RENAME')
        Assert-True (@($fixtureMarkers | Where-Object { -not $runnerText.Contains($_) }).Count -eq 0) 'TEST-013 isolated fixtures have inert source, parent, prepare, and rename patch markers'
    } else { Ok 'TEST-013 runner child permits its fixture-only marker replacement' }
}

if ((Test-Path -LiteralPath $bootstrapRunner -PathType Leaf) -and ($env:SDD_PHASE2_RUNNER_CHILD -ne '1')) {
    $fixture = New-InstallationFixture
    try {
        Assert-True ((Invoke-IsolatedInstall $fixture) -eq 0) 'TEST-013 bootstrap accepts literal-order canonical data and installs the exact batch'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    foreach ($case in @('expansion', 'grammar', 'hash', 'missing', 'duplicate')) {
        $fixture = New-BootstrapFixture
        try {
            $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
            $manifestPath = Join-Path $fixtureStage 'MANIFEST.sha256'
            $lines = @(Get-Content -LiteralPath $manifestPath)
            if ($case -eq 'expansion') {
                $canonicalPath = Join-Path $fixtureStage 'plugins/sdd-quality-loop/references/guard-invariants.json'
                $canonical = Get-Content -Raw -LiteralPath $canonicalPath | ConvertFrom-Json
                $canonical.phase2_human_copy_targets = @($bootstrapTargets + 'outside/inventory.txt')
                Write-BootstrapText $canonicalPath @($canonical | ConvertTo-Json -Depth 8)
            }
            if ($case -eq 'grammar') { $lines[0] = 'not a GNU manifest line' }
            if ($case -eq 'hash') { $lines[0] = '0' + $lines[0].Substring(1) }
            if ($case -eq 'missing') { $lines = @($lines | Select-Object -Skip 1) }
            if ($case -eq 'duplicate') { $lines[$lines.Count - 1] = $lines[0] }
            if ($case -ne 'expansion') { Write-BootstrapText $manifestPath $lines }
            Assert-True ((Invoke-BootstrapValidator $fixture) -ne 0) "TEST-013 bootstrap rejects $case invariant mismatch"
        } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
    }

    $fixture = New-InstallationFixture
    try {
        Install-FixtureCanonical $fixture | Out-Null
        Assert-True ((Invoke-NormalUpdateValidator $fixture) -eq 0) 'TEST-013 normal update validates only the installed live canonical authority'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    $fixture = New-BootstrapFixture
    try {
        Assert-True ((Invoke-NormalUpdateValidator $fixture) -ne 0) 'TEST-013 normal update rejects an absent live canonical file'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    $fixture = New-BootstrapFixture
    try {
        $liveCanonical = Install-FixtureCanonical $fixture
        Write-BootstrapText $liveCanonical @('{ invalid json')
        Assert-True ((Invoke-NormalUpdateValidator $fixture) -ne 0) 'TEST-013 normal update rejects an invalid live canonical file'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    $fixture = New-BootstrapFixture
    try {
        Install-FixtureCanonical $fixture | Out-Null
        $stagedCanonical = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json'
        $canonical = Get-Content -Raw -LiteralPath $stagedCanonical | ConvertFrom-Json
        $canonical.phase2_human_copy_targets = @($bootstrapTargets | Select-Object -Skip 1)
        Write-BootstrapText $stagedCanonical @($canonical | ConvertTo-Json -Depth 8)
        Assert-True ((Invoke-NormalUpdateValidator $fixture) -ne 0) 'TEST-013 normal update rejects staged/live ordered-array mismatch'
    } finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    foreach ($case in @('absolute', 'traversal', 'remap')) {
        $fixture = New-BootstrapFixture
        try {
            $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
            $manifestPath = Join-Path $fixtureStage 'MANIFEST.sha256'
            $lines = @(Get-Content -LiteralPath $manifestPath)
            if ($case -eq 'absolute') { $lines[0] = $lines[0].Substring(0, 64) + '  C:/outside.txt' }
            if ($case -eq 'traversal') { $lines[0] = $lines[0].Substring(0, 64) + '  ../outside.txt' }
            if ($case -eq 'remap') {
                $source = Join-Path $fixtureStage 'plugins/sdd-lite/references/risk-upgrade-policy.md'
                $remapped = Join-Path $fixtureStage 'remapped/risk-upgrade-policy.md'
                New-Item -ItemType Directory -Path (Split-Path -Parent $remapped) -Force | Out-Null
                Move-Item -LiteralPath $source -Destination $remapped -Force
            } else { Write-BootstrapText $manifestPath $lines }
            Assert-True ((Invoke-BootstrapValidator $fixture) -ne 0) "TEST-013 validation rejects $case path remapping"
        } finally { Remove-BootstrapFixture $fixture }
    }

    $fixture = New-BootstrapFixture
    try {
        $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
        $source = Join-Path $fixtureStage 'plugins/sdd-lite/references/risk-upgrade-policy.md'
        $backing = $source + '.backing'
        Move-Item -LiteralPath $source -Destination $backing -Force
        if (Try-NewFixtureSymbolicLink $source $backing) {
            Assert-True ((Invoke-BootstrapValidator $fixture) -ne 0) 'TEST-013 validation rejects a staged source final link'
        } else { Ok 'TEST-013 staged source final-link test skipped on unsupported host' }
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-BootstrapFixture
    try {
        $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
        $sourceParent = Join-Path $fixtureStage 'plugins/sdd-lite/references'
        $backing = $sourceParent + '.backing'
        Move-Item -LiteralPath $sourceParent -Destination $backing -Force
        if (Try-NewFixtureJunction $sourceParent $backing) {
            Assert-True ((Invoke-BootstrapValidator $fixture) -ne 0) 'TEST-013 validation rejects a staged source intermediate junction'
        } else { Ok 'TEST-013 staged source junction test skipped on unsupported host' }
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-BootstrapFixture
    try {
        $target = Join-Path $fixture 'plugins/sdd-lite/references/risk-upgrade-policy.md'
        $backing = Join-Path $fixture 'target-final-link-backing.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Write-BootstrapText $backing @('target backing')
        if (Try-NewFixtureSymbolicLink $target $backing) {
            Assert-True ((Invoke-BootstrapValidator $fixture) -ne 0) 'TEST-013 validation rejects a target final link'
        } else { Ok 'TEST-013 target final-link test skipped on unsupported host' }
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-BootstrapFixture
    try {
        $targetParent = Join-Path $fixture 'plugins/sdd-lite/references'
        $backing = Join-Path $fixture 'target-parent-junction-backing'
        New-Item -ItemType Directory -Path (Split-Path -Parent $targetParent) -Force | Out-Null
        New-Item -ItemType Directory -Path $backing -Force | Out-Null
        if (Try-NewFixtureJunction $targetParent $backing) {
            Assert-True ((Invoke-BootstrapValidator $fixture) -ne 0) 'TEST-013 validation rejects a target parent junction'
        } else { Ok 'TEST-013 target parent junction test skipped on unsupported host' }
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        Assert-True ((Invoke-IsolatedInstall $fixture) -eq 0) 'TEST-013 isolated install completes after full validation'
        $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
        $allCopied = $true
        foreach ($target in $bootstrapTargets) {
            $source = Join-Path $fixtureStage $target
            $destination = Join-Path $fixture $target
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash)) { $allCopied = $false }
        }
        Assert-True $allCopied 'TEST-013 isolated install copies every staged candidate in inventory order'
        $guard = Join-Path $fixture 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1'
        $payload = '{"tool_name":"write","tool_input":{"file_path":"' + ((Join-Path $fixture '.github/workflows/test.yml').Replace('\', '/')) + '","content":"changed"}}'
        $savedPayload = $env:PAYLOAD
        try {
            $env:PAYLOAD = $payload
            $ErrorActionPreference = 'Continue'
            & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File $guard -Emit exit 1>$null 2>$null
            $guardExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = 'Stop'
            if ($null -eq $savedPayload) { Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue } else { $env:PAYLOAD = $savedPayload }
        }
        Assert-True ($guardExit -eq 2) 'TEST-013 post-install guard denies protected test.yml write'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $sentinel = Join-Path $fixture 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
        New-Item -ItemType Directory -Path (Split-Path -Parent $sentinel) -Force | Out-Null
        Write-BootstrapText $sentinel @('early target sentinel')
        $before = [IO.File]::ReadAllBytes($sentinel)
        $manifestPath = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256'
        $lines = @(Get-Content -LiteralPath $manifestPath)
        $last = $lines.Count - 1
        $replacement = '0'
        if ($lines[$last].Substring(0, 1) -eq '0') { $replacement = '1' }
        $lines[$last] = $replacement + $lines[$last].Substring(1)
        Write-BootstrapText $manifestPath $lines
        $exitCode = Invoke-IsolatedInstall $fixture
        $after = [IO.File]::ReadAllBytes($sentinel)
        Assert-True (($exitCode -ne 0) -and ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String($after))) 'TEST-013 later hash failure leaves early destination sentinel untouched'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $target = Join-Path $fixture 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
        $alias = Join-Path $fixture 'outside-inventory-hardlink.py'
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Write-BootstrapText $target @('fixture previous hard-link bytes')
        $oldAlias = [Convert]::ToBase64String([IO.File]::ReadAllBytes($target))
        if (Try-NewFixtureHardLink $alias $target) {
            $exitCode = Invoke-IsolatedInstall $fixture
            $expected = (Get-FileHash -LiteralPath (Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py') -Algorithm SHA256).Hash
            Assert-True (($exitCode -eq 0) -and ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $expected) -and ([Convert]::ToBase64String([IO.File]::ReadAllBytes($alias)) -ceq $oldAlias)) 'TEST-013 atomic rename preserves an out-of-inventory hard-link alias'
        } else { Bad 'TEST-013 hard-link fixture is required on the reviewed NTFS host' }
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $patched = Patch-FixtureRunner $fixture '// TEST_FIXTURE_SOURCE_SUBSTITUTION' 'if (plan.Index == 0) { string original = Path.Combine(_repositoryPath, plan.SourceRelative.Replace("/", "\\")); bool denied = false; try { File.Move(original, original + ".fixture-moved"); } catch (IOException) { denied = true; } if (!denied) { throw new InvalidOperationException("fixture source substitution succeeded"); } }'
        Assert-True ($patched -and ((Invoke-IsolatedInstall $fixture) -eq 0)) 'TEST-013 held source handle denies late source substitution and supplies copied bytes'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $patched = Patch-FixtureRunner $fixture '// TEST_FIXTURE_PARENT_SUBSTITUTION' 'if (plan.Index == 0) { string original = Path.Combine(_repositoryPath, plan.DestinationParentRelative.Replace("/", "\\")); bool denied = false; try { Directory.Move(original, original + ".fixture-moved"); } catch (IOException) { denied = true; } if (!denied) { throw new InvalidOperationException("fixture parent substitution succeeded"); } }'
        Assert-True ($patched -and ((Invoke-IsolatedInstall $fixture) -eq 0)) 'TEST-013 held destination parent denies late namespace substitution'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $previous = Initialize-FixturePreviousBatch $fixture
        $patched = Patch-FixtureRunner $fixture '// TEST_FIXTURE_AFTER_PREPARE_ITEM' 'if (plan.Index == 3) { throw new IOException("fixture preparation failure"); }'
        $exitCode = if ($patched) { Invoke-IsolatedInstall $fixture } else { 0 }
        $orphans = @(Get-ChildItem -LiteralPath $fixture -Recurse -Force -Filter '.sdd-phase2-*' -ErrorAction SilentlyContinue)
        Assert-True ($patched -and ($exitCode -eq 2) -and (Test-FixtureBatchHashes $fixture $previous.Hashes) -and ($orphans.Count -eq 0)) 'TEST-013 preparation failure changes no live file and cleans every temporary'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $previous = Initialize-FixturePreviousBatch $fixture
        $patched = Patch-FixtureRunner $fixture '// TEST_FIXTURE_BEFORE_RENAME' 'if (index == 3) { throw new IOException("fixture rename failure"); }'
        $exitCode = if ($patched) { Invoke-IsolatedInstall $fixture } else { 0 }
        $fixtureStage = Join-Path $fixture 'specs/epic-136-phase2-gates/human-copy'
        $prefixState = $patched -and ($exitCode -eq 2)
        for ($index = 0; $index -lt $bootstrapTargets.Count; $index++) {
            $target = $bootstrapTargets[$index]
            $actual = (Get-FileHash -LiteralPath (Join-Path $fixture $target) -Algorithm SHA256).Hash.ToLowerInvariant()
            $expected = if ($index -lt 3) { (Get-FileHash -LiteralPath (Join-Path $fixtureStage $target) -Algorithm SHA256).Hash.ToLowerInvariant() } else { [string]$previous.Hashes[$target] }
            if ($actual -cne $expected) { $prefixState = $false }
        }
        Restore-FixtureRollbackSources $fixture $previous.Bytes
        $rollbackExit = Invoke-IsolatedInstall $fixture
        Assert-True ($prefixState -and ($rollbackExit -eq 0) -and (Test-FixtureBatchHashes $fixture $previous.Hashes)) 'TEST-013 fixed-index failure leaves exact new prefix and complete rollback restores every prior digest'
    } finally { Remove-BootstrapFixture $fixture }

    $fixture = New-InstallationFixture
    try {
        $previous = Initialize-FixturePreviousBatch $fixture
        $patched = Patch-FixtureRunner $fixture 'EntryPoint = "NtCreateFile"' 'EntryPoint = "NtCreateFileMissing"'
        $exitCode = if ($patched) { Invoke-IsolatedInstall $fixture } else { 0 }
        Assert-True ($patched -and ($exitCode -eq 2) -and (Test-FixtureBatchHashes $fixture $previous.Hashes)) 'TEST-013 unavailable native API fails before the first live replacement'
    } finally { Remove-BootstrapFixture $fixture }
} elseif (Test-Path -LiteralPath $bootstrapRunner -PathType Leaf) {
    Ok 'TEST-013 runner child skips nested installation fixtures'
} else {
    Bad 'TEST-013 isolated bootstrap fixture cannot run without its staged validator'
}

Write-Host "phase2-guard-invariants.tests.ps1: $passCount passed, $failCount failed"
if ($failCount -gt 0) { exit 1 }
exit 0
