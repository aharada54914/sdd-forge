# evidence-bundle-encoding.tests.ps1 - issue #619: generate-evidence-bundle.ps1 bytes
# Runs the producer under the runtime named by -Producer (not the runtime hosting
# this file) and reads its bundle with strict Python and Node JSON consumers.
# Must stay Windows PowerShell 5.1 compatible: ASCII-only source, no ::new(),
# no $IsWindows, and native stderr must not trip a Stop preference.
param(
    [Parameter(Mandatory = $true)][string]$Producer,
    [ValidateSet('Desktop', 'Core')][string]$ExpectEdition = 'Core'
)
$ErrorActionPreference = 'Continue'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts/generate-evidence-bundle.ps1'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sdd-evidence-bundle-encoding-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
$noBom = New-Object System.Text.UTF8Encoding($false)
$script:Pass = 0
$script:Fail = 0
function Ok { param([string]$Name) Write-Host "ok: $Name"; $script:Pass++ }
function Fail { param([string]$Name) Write-Host "FAIL: $Name"; $script:Fail++ }

# Non-ASCII built from code points so the source stays ASCII under 5.1's ANSI read.
$feature = 'feat-' + (-join [char[]](0x30E2, 0x30C7, 0x30EB, 0x00E9))
$runtimeLabel = 'runtime-' + (-join [char[]](0x00FC, 0x4E2D))
function ConvertTo-AsciiEscaped { param([string]$Text)
    -join ($Text.ToCharArray() | ForEach-Object {
        if ([int]$_ -gt 127) { '\u{0:x4}' -f [int]$_ } else { [string]$_ } })
}

# Both consumers print the same ASCII-escaped projection, or fail on a BOM.
$pyConsumer = Join-Path $workDir 'consumer.py'
[System.IO.File]::WriteAllText($pyConsumer, @'
import json, sys
d = json.loads(open(sys.argv[1], 'rb').read().decode('utf-8'))
print(json.dumps([d['task_id'], d['feature'], d['review_verdict']['verdict'], d['builder']['runtime'],
                  len(d['spec_revision'])], separators=(',', ':')))
'@, $noBom)
$jsConsumer = Join-Path $workDir 'consumer.js'
[System.IO.File]::WriteAllText($jsConsumer, @'
const d = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const s = JSON.stringify([d.task_id, d.feature, d.review_verdict.verdict, d.builder.runtime, d.spec_revision.length]);
console.log(s.replace(/[^\x00-\x7f]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')));
'@, $noBom)

function Resolve-Tool { param([string[]]$Names)
    foreach ($n in $Names) {
        $c = Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    return $null
}
$python = Resolve-Tool @('python3', 'python')
$node = Resolve-Tool @('node')
$git = Resolve-Tool @('git')

function New-CaseRoot { param([string]$Name, [string]$TaskId = 'T-001')
    $root = Join-Path $workDir $Name
    New-Item -ItemType Directory -Path (Join-Path (Join-Path $root 'specs') $feature) -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'verification') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path (Join-Path (Join-Path $root 'specs') $feature) 'requirements.md'), "# Requirements`n", $noBom)
    $contract = '{"task_id":"' + $TaskId + '","feature":"' + (ConvertTo-AsciiEscaped $feature) + '","checks":[]}'
    [System.IO.File]::WriteAllText((Join-Path $root 'verification/T-001.contract.json'), $contract + "`n", $noBom)
    [System.IO.File]::WriteAllText((Join-Path $root 'reports/qg.md'),
        "Task ID: T-001`nFeature: f`nVERDICT: PASS`nCritical: 0`nMajor: 0`nMinor: 0`n", $noBom)
    $null = & $git -C $root init -q 2>&1
    $null = & $git -C $root add -A 2>&1
    $null = & $git -C $root -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false commit -q -m fixture 2>&1
    return $root
}

$savedRuntime = $env:SDD_RUNTIME
try {
    $runtime = @(& $Producer -NoProfile -Command '$PSVersionTable.PSEdition; $PSVersionTable.PSVersion.ToString(); [Environment]::NewLine.Length')
    Write-Host "producer runtime: $Producer => $($runtime -join ' ')"
    if ($runtime.Count -ge 3 -and $runtime[0] -eq $ExpectEdition) {
        Ok "EB-619a: producer runtime is $ExpectEdition $($runtime[1])"
    } else {
        Fail "EB-619a: producer runtime must be $ExpectEdition, got '$($runtime -join ' ')'"
    }
    $crlf = ($runtime.Count -ge 3 -and $runtime[2] -eq '2')
    if (-not $python) { Fail 'EB-619: strict Python consumer (python3/python) not found on PATH' }
    if (-not $node) { Fail 'EB-619: strict Node consumer (node) not found on PATH' }
    if (-not $git) { Fail 'EB-619: git not found on PATH' }

    # EB-619b: Windows PowerShell 5.1 Join-Path binds only Path and ChildPath, so a
    # third positional segment stops the 5.1 producer before it reaches the writer.
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($generator, [ref]$tokens, [ref]$parseErrors)
    $joinPaths = @($ast.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Join-Path' }, $true))
    $wide = @($joinPaths | Where-Object {
        $values = @($_.CommandElements | Select-Object -Skip 1 | Where-Object {
            -not ($_ -is [System.Management.Automation.Language.CommandParameterAst]) })
        $names = @($_.CommandElements | Where-Object {
            $_ -is [System.Management.Automation.Language.CommandParameterAst] } | ForEach-Object { $_.ParameterName })
        $values.Count -gt 2 -or ($names -like 'Add*').Count -gt 0 })
    if ($joinPaths.Count -gt 0 -and $wide.Count -eq 0) {
        Ok "EB-619b: every Join-Path in the producer uses only Path and ChildPath ($($joinPaths.Count) calls)"
    } else {
        Fail "EB-619b: Join-Path beyond Path/ChildPath at line(s) $(($wide | ForEach-Object { $_.Extent.StartLineNumber }) -join ', ')"
    }

    $env:SDD_RUNTIME = $runtimeLabel
    $relativeArgs = @('-ContractPath', 'verification/T-001.contract.json', '-QualityReport', 'reports/qg.md',
        '-RepoRoot', '.', '-OutputPath', 'out/T-001.evidence.json')
    foreach ($name in @('default', 'relative', 'session')) {
        $label = "EB-619 [$ExpectEdition/$name]"
        $caseRoot = New-CaseRoot $name
        if ($name -eq 'default') {
            $bundlePath = Join-Path $caseRoot 'verification/T-001.evidence.json'
            $genOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -File $generator `
                -ContractPath (Join-Path $caseRoot 'verification/T-001.contract.json') `
                -QualityReport (Join-Path $caseRoot 'reports/qg.md') -RepoRoot $caseRoot 2>&1
        } elseif ($name -eq 'relative') {
            # Relative -OutputPath: a -File child starts in the caller's location.
            $bundlePath = Join-Path $caseRoot 'out/T-001.evidence.json'
            Push-Location -LiteralPath $caseRoot
            $genOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -File $generator @relativeArgs 2>&1
            Pop-Location
        } else {
            # In-session call with PS location != process directory: the bundle
            # must land under the PS location, as Set-Content resolved it.
            $bundlePath = Join-Path $caseRoot 'out/T-001.evidence.json'
            $q = { param($s) "'" + ($s -replace "'", "''") + "'" }
            $command = "Set-Location -LiteralPath $(& $q $caseRoot); " +
                "[Environment]::CurrentDirectory = $(& $q $workDir); " +
                "if ([Environment]::CurrentDirectory -eq (Get-Location).ProviderPath) { exit 3 }; " +
                "& $(& $q $generator) $($relativeArgs -join ' '); exit `$LASTEXITCODE"
            $genOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1
        }
        $genExit = $LASTEXITCODE
        if ($genExit -eq 0) { Ok "$label exit 0" }
        else { Fail "$label expected exit 0, got $genExit`n$(($genOutput | Out-String).Trim())" }

        if (Test-Path -LiteralPath (Join-Path $workDir 'out')) { Fail "$label bundle written relative to process directory" }
        if (-not (Test-Path -LiteralPath $bundlePath)) { Fail "$label bundle not written"; continue }
        $bytes = [System.IO.File]::ReadAllBytes($bundlePath)
        $head = ($bytes[0..([Math]::Min(2, $bytes.Length - 1))] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Fail "$label bundle starts with UTF-8 BOM ($head)"
        } else { Ok "$label bundle has no UTF-8 BOM ($head)" }

        # Former Set-Content + Add-Content framing: native endings, two trailing newlines.
        $text = $noBom.GetString($bytes)
        $nl = if ($crlf) { "`r`n" } else { "`n" }
        $lf = ([regex]::Matches($text, "`n")).Count
        $cr = ([regex]::Matches($text, "`r")).Count
        $nativeEndings = if ($crlf) { $cr -eq $lf -and ([regex]::Matches($text, "`r`n")).Count -eq $lf } else { $cr -eq 0 }
        if ($nativeEndings -and $lf -gt 2 -and $text.EndsWith($nl + $nl) -and -not $text.EndsWith($nl + $nl + $nl)) {
            Ok "$label bundle keeps native line endings and two trailing newlines"
        } else {
            Fail "$label bundle line framing changed (LF=$lf CR=$cr crlf=$crlf)"
        }

        $expected = '["T-001","' + (ConvertTo-AsciiEscaped $feature) + '","PASS","' + (ConvertTo-AsciiEscaped $runtimeLabel) + '",64]'
        foreach ($consumer in @(@('python', $python, @('-I', $pyConsumer, $bundlePath)),
                                @('node', $node, @($jsConsumer, $bundlePath)))) {
            if (-not $consumer[1]) { continue }
            $parsed = & $consumer[1] @($consumer[2]) 2>&1
            $parsedText = ($parsed | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $parsedText -ceq $expected) {
                Ok "$label strict $($consumer[0]) parse keeps fields, spec revision and non-ASCII values"
            } else {
                Fail "$label strict $($consumer[0]) parse: expected $expected, got exit $LASTEXITCODE`n$parsedText"
            }
        }
    }

    # Fail-closed paths stay fail-closed and publish nothing.
    foreach ($failure in @(@{ Name = 'missing-report'; Task = 'T-001' }, @{ Name = 'invalid-task'; Task = 'X-1' })) {
        $label = "EB-619 [$ExpectEdition/$($failure.Name)]"
        $caseRoot = New-CaseRoot $failure.Name $failure.Task
        if ($failure.Name -eq 'missing-report') { Remove-Item -LiteralPath (Join-Path $caseRoot 'reports/qg.md') }
        Push-Location -LiteralPath $caseRoot
        $null = & $Producer -NoProfile -ExecutionPolicy Bypass -File $generator @relativeArgs 2>&1
        $failExit = $LASTEXITCODE
        Pop-Location
        if ($failExit -eq 1 -and -not (Test-Path -LiteralPath (Join-Path $caseRoot 'out'))) {
            Ok "$label exits 1 without publishing a bundle"
        } else { Fail "$label expected exit 1 and no bundle, got exit $failExit" }
    }
} finally {
    $env:SDD_RUNTIME = $savedRuntime
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

Write-Host "Results: $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
exit 0
