# Cross-script parity and installed-layout invocation harness -- PowerShell
# twin (T-007, REQ-006; TEST-031/AC-031, TEST-033/AC-033).
#
# Behaviourally identical to tests/capability-registry-parity.tests.sh: the
# same three simulated installed-plugin contexts
# (tests/fixtures/capability-registry/parity-runtime-*.json), the same shared
# fixture input, the same four scripts, the same golden comparisons, and the
# same check labels. See the bash twin's header for the full contract.
#
# Acceptance-first RED reproduction: set SDD_PARITY_INJECT=wrapper or
# SDD_PARITY_INJECT=runtime. The injection only ever patches the disposable
# staged copy inside this suite's own temp tree.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Native commands below are checked by exit code on purpose (a non-zero exit
# is data here, not an error), so keep PS 7.4+'s native-command error
# preference from turning them into terminating errors.
$PSNativeCommandUseErrorActionPreference = $false

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceDir = Join-Path $root 'plugins/sdd-quality-loop/scripts'
$fixtures = Join-Path $root 'tests/fixtures/capability-registry'
$repoContracts = Join-Path $root 'contracts'
$referenceRuntime = 'claude-code'
$runtimes = @('claude-code', 'codex-cli', 'copilot-cli')
$inject = $env:SDD_PARITY_INJECT
if ($null -eq $inject) { $inject = '' }

$script:PassCount = 0
$script:FailCount = 0
$script:DesignedRedCount = 0
function Ok([string]$Message) { $script:PassCount++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:FailCount++; [Console]::Error.WriteLine("not ok: $Message") }
# A DESIGNED-RED result is red *by design* until a human performs a step
# agents are structurally forbidden from performing (writing under
# specs/<feature>/human-copy/). Counted separately from Fail -- following
# tests/generate-gate-capabilities.tests.ps1's T-006 precedent -- but still
# makes this suite's exit code non-zero.
function DesignedRed([string]$Message) {
  $script:DesignedRedCount++
  [Console]::Error.WriteLine("DESIGNED-RED (pre-human-copy): $Message")
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('t007-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$workDir = (Resolve-Path -LiteralPath $workDir).Path
$outDir = Join-Path $workDir 'out'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$powerShellExe = (Get-Process -Id $PID).Path

function Get-ToolPath([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $command) { return $null }
  return $command.Source
}

$pythonExe = Get-ToolPath 'python3'
if ($null -eq $pythonExe) { $pythonExe = Get-ToolPath 'python' }
$bashExe = Get-ToolPath 'bash'
$nodeExe = Get-ToolPath 'node'
if (($null -eq $pythonExe) -or ($null -eq $bashExe) -or ($null -eq $nodeExe)) {
  [Console]::Error.WriteLine('capability-registry-parity: python3/python, bash and node are all required')
  Write-Host '---- summary: pass=0 fail=1 designed-red=0 ----'
  exit 1
}

# =====================================================================
# Shared fixture input -- written ONCE, handed unchanged to every runtime.
# =====================================================================
$sharedInput = Join-Path $workDir 'shared-input'
New-Item -ItemType Directory -Path $sharedInput -Force | Out-Null
$splitInputScript = @'
import json
import sys
from pathlib import Path

document = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
target = Path(sys.argv[2])
(target / "predicate.json").write_text(json.dumps(document["predicate"], indent=2) + "\n", encoding="utf-8")
(target / "component-properties.json").write_text(
    json.dumps(document["properties"], indent=2) + "\n", encoding="utf-8"
)
'@
$splitInputScript | & $pythonExe - (Join-Path $fixtures 'predicate-trigger-context.json') $sharedInput
$predicateInput = Join-Path $sharedInput 'predicate.json'
$propertiesInput = Join-Path $sharedInput 'component-properties.json'
$registryInput = Join-Path $fixtures 'validate-registry-fully-clean.json'

# =====================================================================
# Simulated installed-plugin context builder -- byte-for-byte the same
# program the bash twin runs (see that file for the commentary).
# =====================================================================
$buildContextScript = @'
import json
import os
import shutil
import sys
from pathlib import Path

descriptor = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
workdir = Path(sys.argv[2])
source_dir = Path(sys.argv[3])
fixtures = Path(sys.argv[4])
repo_contracts = Path(sys.argv[5])
suffix = sys.argv[6]

STAGED_SCRIPTS = [
    "evaluate-predicate.py", "evaluate-predicate.sh", "evaluate-predicate.ps1",
    "validate-capability-registry.py", "validate-capability-registry.sh",
    "validate-capability-registry.ps1",
    "generate-registry-digest.py", "generate-registry-digest.sh",
    "generate-registry-digest.ps1", "generate-registry-digest.js",
    "generate-gate-capabilities.py", "generate-gate-capabilities.sh",
    "generate-gate-capabilities.ps1",
    "registry_discovery.py", "canonicalize-sdd-yaml.py",
    "check-contract.py", "check-hook-activation-handshake.py",
    "check-component-coverage.py",
]


def root_for(key):
    segments = list(descriptor[key])
    if suffix:
        segments.append(suffix)
    return workdir.joinpath(*segments)


def populate_shared(root):
    packaged = root / "plugins" / "sdd-quality-loop" / "contracts"
    references = root / "plugins" / "sdd-quality-loop" / "references"
    monorepo_contracts = root / "contracts"
    for directory in (packaged, references, monorepo_contracts):
        directory.mkdir(parents=True, exist_ok=True)
    registry_fixture = fixtures / "gate-capabilities-clean-registry.json"
    shutil.copyfile(registry_fixture, packaged / "capability-registry.json")
    shutil.copyfile(registry_fixture, monorepo_contracts / "capability-registry.json")
    shutil.copyfile(
        repo_contracts / "capability-registry.schema.json",
        packaged / "capability-registry.schema.json",
    )
    shutil.copyfile(
        repo_contracts / "lite-upgrade-reason-catalog.json",
        packaged / "lite-upgrade-reason-catalog.json",
    )
    shutil.copyfile(
        source_dir.parent / "references" / "provider-terms.json",
        references / "provider-terms.json",
    )
    marker = root / descriptor["host_marker_path"]
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(descriptor["host_marker_content"], encoding="utf-8")


install_root = root_for("install_root_segments")
entry_root = root_for("entry_root_segments")

install_scripts = install_root / "plugins" / "sdd-quality-loop" / "scripts"
install_scripts.mkdir(parents=True, exist_ok=True)
for name in STAGED_SCRIPTS:
    shutil.copyfile(source_dir / name, install_scripts / name)
    os.chmod(install_scripts / name, 0o755)
populate_shared(install_root)

if descriptor["entry_via_symlink"]:
    entry_scripts = entry_root / "plugins" / "sdd-quality-loop" / "scripts"
    entry_scripts.mkdir(parents=True, exist_ok=True)
    for name in STAGED_SCRIPTS:
        link = entry_scripts / name
        if link.exists() or link.is_symlink():
            link.unlink()
        link.symlink_to(install_scripts / name)
    populate_shared(entry_root)

print(install_root)
print(entry_root)
'@

$injectScript = @'
import sys
from pathlib import Path

target = Path(sys.argv[1])
text = target.read_text(encoding="utf-8")
if target.suffix == ".ps1":
    patched = '[Console]::Out.Write("divergence-canary")\n' + text
else:
    lines = text.splitlines(keepends=True)
    shebang = lines[0] if lines and lines[0].startswith("#!") else ""
    rest = "".join(lines[1:]) if shebang else text
    patched = shebang + 'printf %s "divergence-canary"\n' + rest
target.resolve().write_text(patched, encoding="utf-8")
'@

$describeScript = @'
import sys
from pathlib import Path

left_path = Path(sys.argv[1])
right_path = Path(sys.argv[2])
for side, path in (("left", left_path), ("right", right_path)):
    if not path.is_file():
        print(f"{side} capture is missing ({path.name})")
        raise SystemExit(0)
left = left_path.read_bytes()
right = right_path.read_bytes()
if left == right:
    print("identical")
elif left.replace(b"\r\n", b"\n") == right.replace(b"\r\n", b"\n"):
    print(f"line-terminator-only difference ({len(left)} vs {len(right)} bytes)")
else:
    print(f"content difference ({len(left)} vs {len(right)} bytes)")
'@

function Build-Context {
  param([string]$Descriptor, [string]$Suffix = '')
  $lines = @($buildContextScript | & $pythonExe - (Join-Path $fixtures "$Descriptor.json") $workDir $sourceDir $fixtures $repoContracts $Suffix)
  return [PSCustomObject]@{ InstallRoot = $lines[0]; EntryRoot = $lines[1] }
}

function Add-Divergence {
  param([string]$ScriptsDir, [string]$Wrapper)
  $injectScript | & $pythonExe - (Join-Path $ScriptsDir $Wrapper) | Out-Null
}

function Get-DifferenceDescription {
  param([string]$Left, [string]$Right)
  return (($describeScript | & $pythonExe - $Left $Right) -join '').Trim()
}

function Test-BytesEqual {
  param([string]$Left, [string]$Right)
  if (-not (Test-Path -LiteralPath $Left) -or -not (Test-Path -LiteralPath $Right)) { return $false }
  $leftBytes = [IO.File]::ReadAllBytes($Left)
  $rightBytes = [IO.File]::ReadAllBytes($Right)
  return ([Convert]::ToHexString($leftBytes) -eq [Convert]::ToHexString($rightBytes))
}

function Get-CapturePath {
  param([string]$Runtime, [string]$Slot, [string]$Kind)
  return (Join-Path $outDir "$Runtime.$Slot.$Kind")
}

function Get-CapturedExitCode([string]$OutFile) {
  return ((Get-Content -LiteralPath "$OutFile.rc" -Raw) -replace '[\r\n]', '')
}

function Invoke-Wrapper {
  param([string]$Kind, [string]$ScriptsDir, [string]$Base, [string]$OutFile, [string[]]$Arguments = @())
  switch ($Kind) {
    'sh' { $fileName = $bashExe; $argumentList = @((Join-Path $ScriptsDir "$Base.sh")) + $Arguments }
    'ps1' { $fileName = $powerShellExe; $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $ScriptsDir "$Base.ps1")) + $Arguments }
    'js' { $fileName = $nodeExe; $argumentList = @((Join-Path $ScriptsDir "$Base.js")) + $Arguments }
    default { throw "unknown wrapper kind: $Kind" }
  }
  $process = Start-Process -FilePath $fileName -ArgumentList $argumentList -Wait -PassThru `
    -RedirectStandardOutput $OutFile -RedirectStandardError "$OutFile.err"
  Set-Content -LiteralPath "$OutFile.rc" -Value ([string]$process.ExitCode) -NoNewline
}

try {
  # ===================================================================
  # Invoke every wrapper of every script inside every runtime context.
  # ===================================================================
  foreach ($runtime in $runtimes) {
    $context = Build-Context -Descriptor "parity-runtime-$runtime"
    $scriptsDir = Join-Path $context.EntryRoot 'plugins/sdd-quality-loop/scripts'
    $generated = Join-Path $context.InstallRoot 'plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json'

    if (($inject -eq 'wrapper') -and ($runtime -eq $referenceRuntime)) {
      Add-Divergence -ScriptsDir $scriptsDir -Wrapper 'evaluate-predicate.ps1'
    }
    if (($inject -eq 'runtime') -and ($runtime -eq 'copilot-cli')) {
      Add-Divergence -ScriptsDir $scriptsDir -Wrapper 'evaluate-predicate.sh'
    }

    foreach ($kind in @('sh', 'ps1')) {
      Invoke-Wrapper -Kind $kind -ScriptsDir $scriptsDir -Base 'evaluate-predicate' `
        -OutFile (Get-CapturePath $runtime 'evaluate-predicate' $kind) `
        -Arguments @('--predicate', $predicateInput, '--component-properties', $propertiesInput)
      Invoke-Wrapper -Kind $kind -ScriptsDir $scriptsDir -Base 'validate-capability-registry' `
        -OutFile (Get-CapturePath $runtime 'validate' $kind) `
        -Arguments @('--registry', $registryInput, '--repo-root', $context.EntryRoot)
    }

    foreach ($kind in @('sh', 'ps1', 'js')) {
      Invoke-Wrapper -Kind $kind -ScriptsDir $scriptsDir -Base 'generate-registry-digest' `
        -OutFile (Get-CapturePath $runtime 'digest' $kind) -Arguments @('--whole')
    }

    foreach ($kind in @('sh', 'ps1')) {
      if (Test-Path -LiteralPath $generated) { Remove-Item -LiteralPath $generated -Force }
      $capture = Get-CapturePath $runtime 'gatecap' $kind
      Invoke-Wrapper -Kind $kind -ScriptsDir $scriptsDir -Base 'generate-gate-capabilities' -OutFile $capture
      if (Test-Path -LiteralPath $generated) {
        Copy-Item -LiteralPath $generated -Destination "$capture.file" -Force
      }
      Invoke-Wrapper -Kind $kind -ScriptsDir $scriptsDir -Base 'generate-gate-capabilities' `
        -OutFile (Get-CapturePath $runtime 'gatecapcheck' $kind) -Arguments @('--check')
    }
  }

  # ===================================================================
  # TEST-031 / AC-031 -- golden-fixture parity inside one fixed context.
  # ===================================================================
  function Assert-WrapperParity {
    param([string]$Label, [string]$Golden, [string]$Slot, [string[]]$Kinds)
    $reference = ''
    $problems = @()
    foreach ($kind in $Kinds) {
      $capture = Get-CapturePath $referenceRuntime $Slot $kind
      $rc = Get-CapturedExitCode $capture
      if ($rc -ne '0') { $problems += "${kind}:exit=$rc"; continue }
      if ($reference -eq '') { $reference = $capture; continue }
      if (-not (Test-BytesEqual $reference $capture)) {
        $problems += ("{0}:{1}" -f $kind, (Get-DifferenceDescription $reference $capture))
      }
    }
    if (($reference -ne '') -and ($Golden -ne '-') -and (-not (Test-BytesEqual $reference $Golden))) {
      $problems += ('golden:' + (Get-DifferenceDescription $reference $Golden))
    }
    if ($problems.Count -eq 0) { Ok $Label } else { Fail ("$Label -- " + ($problems -join ' ')) }
  }

  Assert-WrapperParity `
    -Label 'TEST-031(1): evaluate-predicate .sh/.ps1 stdout is byte-identical and matches the committed golden' `
    -Golden (Join-Path $fixtures 'parity-golden-evaluate-predicate.json') -Slot 'evaluate-predicate' -Kinds @('sh', 'ps1')

  Assert-WrapperParity `
    -Label 'TEST-031(2): validate-capability-registry .sh/.ps1 stdout is byte-identical and matches the committed golden' `
    -Golden (Join-Path $fixtures 'parity-golden-validate-capability-registry.txt') -Slot 'validate' -Kinds @('sh', 'ps1')

  Assert-WrapperParity `
    -Label 'TEST-031(3): generate-registry-digest .sh/.ps1/.js stdout is byte-identical' `
    -Golden '-' -Slot 'digest' -Kinds @('sh', 'ps1', 'js')

  # Reconstructed independently of the digest generator itself, so this row
  # cannot pass by all three wrappers echoing one common defect.
  $canonicalizerOutput = & $pythonExe (Join-Path $sourceDir 'canonicalize-sdd-yaml.py') `
    (Join-Path $fixtures 'gate-capabilities-clean-registry.json') --input-format json --hash-only
  $expectedDigest = ((($canonicalizerOutput -join '') -replace '[\r\n]', '') -replace '^sha256:', '')
  $actualDigest = ((Get-Content -LiteralPath (Get-CapturePath $referenceRuntime 'digest' 'sh') -Raw) -replace '[\r\n]', '')
  if (($expectedDigest -ne '') -and ($actualDigest -eq $expectedDigest)) {
    Ok 'TEST-031(4): the parity digest matches an independently reconstructed canonicalization of the same fixture Registry'
  } else {
    Fail "TEST-031(4): digest '$actualDigest' does not match the independently reconstructed '$expectedDigest'"
  }

  Assert-WrapperParity `
    -Label 'TEST-031(5): generate-gate-capabilities .sh/.ps1 stdout is byte-identical' `
    -Golden '-' -Slot 'gatecap' -Kinds @('sh', 'ps1')

  $gatecapSh = (Get-CapturePath $referenceRuntime 'gatecap' 'sh') + '.file'
  $gatecapPs1 = (Get-CapturePath $referenceRuntime 'gatecap' 'ps1') + '.file'
  $gatecapGolden = Join-Path $fixtures 'gate-capabilities-clean-expected.json'
  if ((Test-BytesEqual $gatecapSh $gatecapPs1) -and (Test-BytesEqual $gatecapSh $gatecapGolden)) {
    Ok 'TEST-031(6): generate-gate-capabilities .sh/.ps1 write byte-identical projections matching the committed golden'
  } else {
    Fail 'TEST-031(6): generate-gate-capabilities projection bytes differ between wrappers or from the committed golden'
  }

  # ===================================================================
  # TEST-033 / AC-033 -- 3-runtime invocation parity.
  # ===================================================================
  function Assert-RuntimeParity {
    param([string]$Label, [string]$Slot, [string]$Suffix, [string[]]$Kinds)
    $problems = @()
    foreach ($kind in $Kinds) {
      $reference = ''
      $referenceRc = ''
      foreach ($runtime in $runtimes) {
        $capture = Get-CapturePath $runtime $Slot $kind
        $rc = Get-CapturedExitCode $capture
        if ($reference -eq '') { $reference = $capture; $referenceRc = $rc; continue }
        if ($rc -ne $referenceRc) { $problems += "$kind/${runtime}:exit=$rc!=$referenceRc" }
        if (-not (Test-BytesEqual ($reference + $Suffix) ($capture + $Suffix))) {
          $problems += ("{0}/{1}:{2}" -f $kind, $runtime, (Get-DifferenceDescription ($reference + $Suffix) ($capture + $Suffix)))
        }
      }
    }
    if ($problems.Count -eq 0) { Ok $Label } else { Fail ("$Label -- " + ($problems -join ' ')) }
  }

  Assert-RuntimeParity `
    -Label 'TEST-033(1): evaluate-predicate yields identical exit codes and stdout in all three installed-plugin contexts' `
    -Slot 'evaluate-predicate' -Suffix '' -Kinds @('sh', 'ps1')
  Assert-RuntimeParity `
    -Label 'TEST-033(2): validate-capability-registry yields identical exit codes and stdout in all three installed-plugin contexts' `
    -Slot 'validate' -Suffix '' -Kinds @('sh', 'ps1')
  Assert-RuntimeParity `
    -Label 'TEST-033(3): generate-registry-digest yields identical exit codes and stdout in all three installed-plugin contexts' `
    -Slot 'digest' -Suffix '' -Kinds @('sh', 'ps1', 'js')
  Assert-RuntimeParity `
    -Label 'TEST-033(4): generate-gate-capabilities yields identical exit codes and stdout in all three installed-plugin contexts' `
    -Slot 'gatecap' -Suffix '' -Kinds @('sh', 'ps1')
  Assert-RuntimeParity `
    -Label 'TEST-033(5): generate-gate-capabilities writes an identical projection in all three installed-plugin contexts' `
    -Slot 'gatecap' -Suffix '.file' -Kinds @('sh', 'ps1')

  $checkProblems = @()
  foreach ($kind in @('sh', 'ps1')) {
    foreach ($runtime in $runtimes) {
      $rc = Get-CapturedExitCode (Get-CapturePath $runtime 'gatecapcheck' $kind)
      if ($rc -ne '0') { $checkProblems += "$kind/${runtime}:exit=$rc" }
    }
  }
  if ($checkProblems.Count -eq 0) {
    Ok 'TEST-033(6): generate-gate-capabilities --check exits zero in all three installed-plugin contexts, via both wrappers'
  } else {
    Fail ('TEST-033(6): --check exit codes diverged -- ' + ($checkProblems -join ' '))
  }

  # All three contexts resolved their Registry/catalog through the packaged
  # copy alone (AC-027's contract, re-asserted at invocation level).
  $discoveryProblems = @()
  foreach ($runtime in $runtimes) {
    foreach ($slot in @('evaluate-predicate', 'validate', 'digest', 'gatecap', 'gatecapcheck')) {
      foreach ($kind in @('sh', 'ps1', 'js')) {
        $errFile = (Get-CapturePath $runtime $slot $kind) + '.err'
        if (Test-Path -LiteralPath $errFile) {
          $errText = Get-Content -LiteralPath $errFile -Raw
          if (($null -ne $errText) -and ($errText -match 'registry-discovery')) {
            $discoveryProblems += "$runtime/$slot/$kind"
          }
        }
      }
    }
  }
  if ($discoveryProblems.Count -eq 0) {
    Ok 'TEST-033(7): no invocation in any of the three contexts fell back or failed closed on artifact discovery'
  } else {
    Fail ('TEST-033(7): registry-discovery diagnostics appeared in -- ' + ($discoveryProblems -join ' '))
  }

  # ===================================================================
  # Non-vacuity canary.
  # ===================================================================
  $canary = Build-Context -Descriptor "parity-runtime-$referenceRuntime" -Suffix 'canary'
  $canaryScripts = Join-Path $canary.EntryRoot 'plugins/sdd-quality-loop/scripts'
  $canaryShOut = Join-Path $outDir 'canary.evaluate-predicate.sh'
  $canaryPs1Out = Join-Path $outDir 'canary.evaluate-predicate.ps1'
  Invoke-Wrapper -Kind 'sh' -ScriptsDir $canaryScripts -Base 'evaluate-predicate' -OutFile $canaryShOut `
    -Arguments @('--predicate', $predicateInput, '--component-properties', $propertiesInput)
  Add-Divergence -ScriptsDir $canaryScripts -Wrapper 'evaluate-predicate.ps1'
  Invoke-Wrapper -Kind 'ps1' -ScriptsDir $canaryScripts -Base 'evaluate-predicate' -OutFile $canaryPs1Out `
    -Arguments @('--predicate', $predicateInput, '--component-properties', $propertiesInput)
  if (Test-BytesEqual $canaryShOut $canaryPs1Out) {
    Fail 'non-vacuity canary: an injected cross-wrapper divergence went undetected by the byte comparison'
  } else {
    Ok ('non-vacuity canary: an injected cross-wrapper divergence is detected (' + (Get-DifferenceDescription $canaryShOut $canaryPs1Out) + ')')
  }
  Remove-Item -LiteralPath $canary.InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $canary.EntryRoot -Recurse -Force -ErrorAction SilentlyContinue

  # ===================================================================
  # Done When #3 -- suite/CI registration and the final cumulative check.
  # ===================================================================
  $runAllSh = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.sh')
  if ($runAllSh.Contains('tests/capability-registry-parity.tests.sh')) {
    Ok 'self-registration: capability-registry-parity.tests.sh registered in tests/run-all.sh'
  } else {
    Fail 'self-registration: capability-registry-parity.tests.sh NOT registered in tests/run-all.sh'
  }
  $runAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.ps1')
  if ($runAllPs1.Contains('tests/capability-registry-parity.tests.ps1')) {
    Ok 'self-registration: capability-registry-parity.tests.ps1 registered in tests/run-all.ps1'
  } else {
    Fail 'self-registration: capability-registry-parity.tests.ps1 NOT registered in tests/run-all.ps1'
  }

  # This feature's suites in task order (T-001..T-007). design.md's Test
  # Strategy enumerates EIGHT items, but items 2 and 6 share one suite file:
  # acceptance-tests.md's TEST-020 places the provider-name fixtures in the
  # "same suite" as TEST-014 (validate-capability-registry). Eight strategy
  # items therefore land as seven physical suite pairs, and this is the
  # complete set.
  $suiteOrder = @(
    'capability-registry-schema', 'evaluate-predicate', 'registry-discovery',
    'validate-capability-registry', 'generate-registry-digest',
    'generate-gate-capabilities', 'capability-registry-parity'
  )

  function Test-WorkflowRegistersAllSuites {
    param([string]$WorkflowPath)
    $text = Get-Content -Raw -LiteralPath $WorkflowPath
    $missing = @()
    $positions = @()
    foreach ($suite in $suiteOrder) {
      $shMarker = "tests/$suite.tests.sh"
      $ps1Marker = "tests/$suite.tests.ps1"
      if (-not $text.Contains($shMarker)) { $missing += $shMarker; continue }
      if (-not $text.Contains($ps1Marker)) { $missing += $ps1Marker; continue }
      $positions += [PSCustomObject]@{ Suite = $suite; Index = $text.IndexOf($shMarker) }
    }
    if ($missing.Count -gt 0) { return 'missing CI steps: ' + ($missing -join ', ') }
    $ordered = @($positions | Sort-Object Index | ForEach-Object { $_.Suite })
    if (($ordered -join '|') -ne ($suiteOrder -join '|')) {
      return 'CI steps present but out of task order: ' + ($ordered -join ' -> ')
    }
    return 'ok'
  }

  $candidateDir = Join-Path $root 'specs/epic-190-a2-capability-registry/drafts/human-copy-candidate'
  $candidateWorkflow = Join-Path $candidateDir '.github/workflows/test.yml.candidate'
  $candidateManifest = Join-Path $candidateDir 'MANIFEST.sha256.candidate'
  $humanCopyDir = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy'
  $stagedWorkflow = Join-Path $humanCopyDir '.github/workflows/test.yml'
  $stagedManifest = Join-Path $humanCopyDir 'MANIFEST.sha256'

  if (Test-Path -LiteralPath $candidateWorkflow) {
    $candidateReport = Test-WorkflowRegistersAllSuites $candidateWorkflow
    if ($candidateReport -eq 'ok') {
      Ok "AC-030 (cumulative): the rebuilt CI workflow candidate carries every one of this feature's seven suite pairs in task order"
    } else {
      Fail "AC-030 (cumulative): rebuilt CI workflow candidate -- $candidateReport"
    }
  } else {
    Fail "AC-030 (cumulative): rebuilt CI workflow candidate is missing at $candidateWorkflow"
  }

  if ((Test-Path -LiteralPath $candidateManifest) -and (Test-Path -LiteralPath $candidateWorkflow)) {
    $candidateHash = (Get-FileHash -LiteralPath $candidateWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
    $candidateManifestLine = @(@(Get-Content -LiteralPath $candidateManifest) -match 'workflows/test\.yml')
    if ($candidateManifestLine.Count -gt 0) {
      $candidateManifestHash = ($candidateManifestLine[0] -split '\s+')[0].ToLowerInvariant()
      if ($candidateHash -eq $candidateManifestHash) {
        Ok "AC-030 (cumulative): the rebuilt CI workflow candidate's sha256 matches its own MANIFEST.sha256.candidate entry"
      } else {
        Fail 'AC-030 (cumulative): rebuilt CI workflow candidate sha256 does not match its MANIFEST.sha256.candidate entry'
      }
    } else {
      Fail 'AC-030 (cumulative): MANIFEST.sha256.candidate has no entry for the rebuilt CI workflow candidate'
    }
  } else {
    Fail 'AC-030 (cumulative): MANIFEST.sha256.candidate missing alongside the rebuilt CI workflow candidate'
  }

  # tasks.md Done When #3 points at human-copy/, so the real staged location
  # is checked directly and is DESIGNED-RED until the human apply lands.
  if (Test-Path -LiteralPath $stagedWorkflow) {
    $stagedReport = Test-WorkflowRegistersAllSuites $stagedWorkflow
    if ($stagedReport -eq 'ok') {
      Ok "human-copy/ staged workflow carries every one of this feature's suite pairs in task order (human apply already landed)"
    } else {
      DesignedRed "human-copy/ staged workflow does not yet carry this feature's full, task-ordered suite registration -- $stagedReport -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory's README.md), then re-run this suite"
    }
  } else {
    Fail 'human-copy/ staged .github/workflows/test.yml candidate is missing'
  }

  # Internal self-consistency only -- not a freshness proof.
  if ((Test-Path -LiteralPath $stagedManifest) -and (Test-Path -LiteralPath $stagedWorkflow)) {
    $stagedHash = (Get-FileHash -LiteralPath $stagedWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
    $stagedManifestLine = @(@(Get-Content -LiteralPath $stagedManifest) -match 'workflows/test\.yml')
    if ($stagedManifestLine.Count -gt 0) {
      $stagedManifestHash = ($stagedManifestLine[0] -split '\s+')[0].ToLowerInvariant()
      if ($stagedHash -eq $stagedManifestHash) {
        Ok 'human-copy: staged workflow sha256 matches MANIFEST.sha256 (self-consistency only, not a freshness proof)'
      } else {
        Fail 'human-copy: staged workflow sha256 does not match MANIFEST.sha256'
      }
    } else {
      Fail 'human-copy: MANIFEST.sha256 has no entry for the staged workflow'
    }
  } else {
    Fail 'human-copy: MANIFEST.sha256 missing'
  }

  # Done When #3: the LIVE, R-10-protected workflow must be byte-unchanged by
  # this task. Compared against its committed blob rather than a pinned hash.
  & git -C $root rev-parse --git-dir *> $null
  if ($LASTEXITCODE -eq 0) {
    & git -C $root diff --quiet HEAD -- .github/workflows/test.yml *> $null
    if ($LASTEXITCODE -eq 0) {
      Ok 'Done When #3: the live .github/workflows/test.yml is byte-unchanged relative to its committed state'
    } else {
      Fail 'Done When #3: the live .github/workflows/test.yml has an uncommitted modification -- this task must never write to it'
    }
  } else {
    Fail "Done When #3: cannot verify the live workflow is unmodified (no git repository resolved at $root)"
  }

  # Done When #3: no version string was mutated outside scripts/bump-version.sh.
  $versionHit = @()
  foreach ($candidate in @(
      (Join-Path $root 'tests/capability-registry-parity.tests.sh'),
      (Join-Path $root 'tests/capability-registry-parity.tests.ps1'),
      (Join-Path $fixtures 'parity-runtime-claude-code.json'),
      (Join-Path $fixtures 'parity-runtime-codex-cli.json'),
      (Join-Path $fixtures 'parity-runtime-copilot-cli.json'),
      (Join-Path $fixtures 'parity-golden-evaluate-predicate.json'),
      (Join-Path $fixtures 'parity-golden-validate-capability-registry.txt')
    )) {
    if ((Test-Path -LiteralPath $candidate) -and ((Get-Content -LiteralPath $candidate -Raw) -match '[0-9]+\.[0-9]+\.[0-9]+')) {
      $versionHit += (Split-Path -Leaf $candidate)
    }
  }
  if ($versionHit.Count -eq 0) {
    Ok "Done When #3: no semver-looking version string was hand-mutated in this task's own files (grep self-check)"
  } else {
    Fail ('Done When #3: a semver-looking version string was found in -- ' + ($versionHit -join ' '))
  }
} finally {
  if (Test-Path -LiteralPath $workDir) { Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ("---- summary: pass={0} fail={1} designed-red={2} ----" -f $script:PassCount, $script:FailCount, $script:DesignedRedCount)
if (($script:FailCount -eq 0) -and ($script:DesignedRedCount -eq 0)) {
  Write-Host "capability-registry-parity suite passed ($script:PassCount checks)"
  exit 0
}
if ($script:FailCount -eq 0) {
  Write-Host "capability-registry-parity suite is DESIGNED-RED ($script:PassCount passed, $script:DesignedRedCount designed-red, 0 genuine failures)"
  Write-Host 'HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory''s README.md "Human apply step"), then re-run this suite.'
  exit 1
}
Write-Host "capability-registry-parity suite FAILED ($script:PassCount passed, $script:FailCount failed, $script:DesignedRedCount designed-red)"
exit 1
