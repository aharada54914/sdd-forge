# emit-run-record-encoding.tests.ps1 - issue #619: emit-run-record.ps1 record bytes
# Runs the producer under the runtime named by -Producer (not the runtime hosting
# this file) and reads its v1/v2 records with strict Python and Node JSON consumers.
# Must stay Windows PowerShell 5.1 compatible: ASCII-only source, no ::new(),
# no $IsWindows, and native stderr must not trip a Stop preference.
# The selected-model record is covered with its real validator by
# tests/model-policy-launch.tests.py (ModelRunRecords.accepted_record).
param(
    [Parameter(Mandatory = $true)][string]$Producer,
    [ValidateSet('Desktop', 'Core')][string]$ExpectEdition = 'Core'
)
$ErrorActionPreference = 'Continue'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$emitter = Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts/emit-run-record.ps1'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sdd-run-record-encoding-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
$noBom = New-Object System.Text.UTF8Encoding($false)
$script:Pass = 0
$script:Fail = 0
function Ok { param([string]$Name) Write-Host "ok: $Name"; $script:Pass++ }
function Fail { param([string]$Name) Write-Host "FAIL: $Name"; $script:Fail++ }

# Non-ASCII built from code points so the source stays ASCII under 5.1's ANSI read.
$model = 'model-' + (-join [char[]](0x30E2, 0x30C7, 0x30EB, 0x00E9))
$track = 'lite-' + (-join [char[]](0x00FC, 0x4E2D))
function ConvertTo-AsciiEscaped { param([string]$Text)
    -join ($Text.ToCharArray() | ForEach-Object {
        if ([int]$_ -gt 127) { '\u{0:x4}' -f [int]$_ } else { [string]$_ } })
}

# Both consumers print the same ASCII-escaped projection, or fail on a BOM.
$pyConsumer = Join-Path $workDir 'consumer.py'
[System.IO.File]::WriteAllText($pyConsumer, @'
import json, sys
d = json.loads(open(sys.argv[1], 'rb').read().decode('utf-8'))
print(json.dumps([d['schema'], d['model_ids']['main'], d['track']], separators=(',', ':')))
'@, $noBom)
$jsConsumer = Join-Path $workDir 'consumer.js'
[System.IO.File]::WriteAllText($jsConsumer, @'
const d = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const s = JSON.stringify([d.schema, d.model_ids.main, d.track]);
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

function New-CaseRoot { param([string]$Name, [bool]$WithTasks = $true)
    $root = Join-Path $workDir $Name
    New-Item -ItemType Directory -Path (Join-Path $root 'specs/f1') -Force | Out-Null
    if ($WithTasks) {
        [System.IO.File]::WriteAllText((Join-Path $root 'specs/f1/tasks.md'), "## T-001 only task`nStatus: Done`n", $noBom)
    }
    return $root
}

try {
    $runtime = @(& $Producer -NoProfile -Command '$PSVersionTable.PSEdition; $PSVersionTable.PSVersion.ToString(); [Environment]::NewLine.Length')
    Write-Host "producer runtime: $Producer => $($runtime -join ' ')"
    if ($runtime.Count -ge 3 -and $runtime[0] -eq $ExpectEdition) {
        Ok "RR-619a: producer runtime is $ExpectEdition $($runtime[1])"
    } else {
        Fail "RR-619a: producer runtime must be $ExpectEdition, got '$($runtime -join ' ')'"
    }
    $crlf = ($runtime.Count -ge 3 -and $runtime[2] -eq '2')
    if (-not $python) { Fail 'RR-619: strict Python consumer (python3/python) not found on PATH' }
    if (-not $node) { Fail 'RR-619: strict Node consumer (node) not found on PATH' }

    $effortArgs = @('-EffortMain', 'high', '-EffortControlMain', 'flag', '-EffortAppliedMain', 'high')
    $cases = @(
        @{ Name = 'v1'; Schema = 'sdd-run-record/v1'; Extra = @() },
        @{ Name = 'v2'; Schema = 'sdd-run-record/v2'; Extra = $effortArgs },
        @{ Name = 'session'; Schema = 'sdd-run-record/v1'; Extra = @() }
    )
    foreach ($case in $cases) {
        $label = "RR-619 [$ExpectEdition/$($case.Name)]"
        $caseRoot = New-CaseRoot $case.Name
        if ($case.Name -eq 'session') {
            # In-session call with PS location != process directory: the record
            # must land under the PS location, as Set-Content resolved it.
            $q = { param($s) "'" + ($s -replace "'", "''") + "'" }
            $command = "Set-Location -LiteralPath $(& $q $caseRoot); " +
                "[Environment]::CurrentDirectory = $(& $q $workDir); " +
                "if ([Environment]::CurrentDirectory -eq (Get-Location).ProviderPath) { exit 3 }; " +
                "& $(& $q $emitter) -Feature f1 -Track $(& $q $track) -ModelMain $(& $q $model); exit `$LASTEXITCODE"
            $emitOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1
        } else {
            # Relative reports/runs output: a -File child starts in the caller's location.
            Push-Location -LiteralPath $caseRoot
            $emitArgs = @('-Feature', 'f1', '-Track', $track, '-ModelMain', $model) + $case.Extra
            $emitOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -File $emitter @emitArgs 2>&1
            Pop-Location
        }
        $emitExit = $LASTEXITCODE
        if ($emitExit -eq 0) { Ok "$label exit 0" }
        else { Fail "$label expected exit 0, got $emitExit`n$(($emitOutput | Out-String).Trim())" }

        if (Test-Path -LiteralPath (Join-Path $workDir 'reports')) { Fail "$label record written relative to process directory" }
        $records = @(Get-ChildItem -LiteralPath (Join-Path $caseRoot 'reports/runs') -Filter 'RUN-*-f1.json' -ErrorAction SilentlyContinue)
        if ($records.Count -ne 1) { Fail "$label expected one record, found $($records.Count)"; continue }
        $bytes = [System.IO.File]::ReadAllBytes($records[0].FullName)
        $head = ($bytes[0..([Math]::Min(2, $bytes.Length - 1))] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Fail "$label record starts with UTF-8 BOM ($head)"
        } else { Ok "$label record has no UTF-8 BOM ($head)" }

        # Set-Content framing: native line endings, exactly one trailing newline.
        $text = $noBom.GetString($bytes)
        $nl = if ($crlf) { "`r`n" } else { "`n" }
        $lf = ([regex]::Matches($text, "`n")).Count
        $cr = ([regex]::Matches($text, "`r")).Count
        $nativeEndings = if ($crlf) { $cr -eq $lf -and ([regex]::Matches($text, "`r`n")).Count -eq $lf } else { $cr -eq 0 }
        if ($nativeEndings -and $lf -gt 1 -and $text.EndsWith($nl) -and -not $text.EndsWith($nl + $nl) -and
            -not $text.TrimEnd("`r", "`n").EndsWith(' ')) {
            Ok "$label record keeps native line endings and one trailing newline"
        } else {
            Fail "$label record line framing changed (LF=$lf CR=$cr crlf=$crlf)"
        }

        $expected = '["' + $case.Schema + '","' + (ConvertTo-AsciiEscaped $model) + '","' + (ConvertTo-AsciiEscaped $track) + '"]'
        foreach ($consumer in @(@('python', $python, @('-I', $pyConsumer, $records[0].FullName)),
                                @('node', $node, @($jsConsumer, $records[0].FullName)))) {
            if (-not $consumer[1]) { continue }
            $parsed = & $consumer[1] @($consumer[2]) 2>&1
            $parsedText = ($parsed | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $parsedText -ceq $expected) {
                Ok "$label strict $($consumer[0]) parse keeps schema and non-ASCII fields"
            } else {
                Fail "$label strict $($consumer[0]) parse: expected $expected, got exit $LASTEXITCODE`n$parsedText"
            }
        }
    }

    # Fail-closed paths stay fail-closed and publish nothing.
    $failures = @(
        @{ Name = 'missing-tasks'; Tasks = $false; Args = @('-Feature', 'f1') },
        @{ Name = 'partial-model'; Tasks = $true; Args = @('-Feature', 'f1', '-ModelSlot', 'main') }
    )
    foreach ($failure in $failures) {
        $label = "RR-619 [$ExpectEdition/$($failure.Name)]"
        $caseRoot = New-CaseRoot $failure.Name $failure.Tasks
        Push-Location -LiteralPath $caseRoot
        $failArgs = $failure.Args
        $null = & $Producer -NoProfile -ExecutionPolicy Bypass -File $emitter @failArgs 2>&1
        $failExit = $LASTEXITCODE
        Pop-Location
        $published = @(Get-ChildItem -LiteralPath (Join-Path $caseRoot 'reports/runs') -Filter 'RUN-*.json' -ErrorAction SilentlyContinue)
        if ($failExit -eq 1 -and $published.Count -eq 0) { Ok "$label exits 1 without publishing a record" }
        else { Fail "$label expected exit 1 and no record, got exit $failExit and $($published.Count) record(s)" }
    }
} finally {
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

Write-Host "Results: $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
exit 0
