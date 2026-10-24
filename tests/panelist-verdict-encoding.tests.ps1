# panelist-verdict-encoding.tests.ps1 - issue #619: run-panelist-{gpt,gemini}.ps1 verdict bytes
# Runs the legacy (non-selected-policy) runners under the runtime named by -Producer
# against a fake codex/gemini CLI (never a real provider) and reads each published
# verdict with strict Python and Node JSON consumers.
# Must stay Windows PowerShell 5.1 compatible: ASCII-only source, no ::new(),
# no $IsWindows, and native stderr must not trip a Stop preference.
param(
    [Parameter(Mandatory = $true)][string]$Producer,
    [ValidateSet('Desktop', 'Core')][string]$ExpectEdition = 'Core'
)
$ErrorActionPreference = 'Continue'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sdd-panelist-encoding-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
$noBom = New-Object System.Text.UTF8Encoding($false)
$script:Pass = 0
$script:Fail = 0
function Ok { param([string]$Name) Write-Host "ok: $Name"; $script:Pass++ }
function Fail { param([string]$Name) Write-Host "FAIL: $Name"; $script:Fail++ }

# Non-ASCII built from code points so the source stays ASCII under 5.1's ANSI read.
$model = 'model-' + (-join [char[]](0x30E2, 0x30C7, 0x30EB, 0x00E9))
$note = 'note-' + (-join [char[]](0x00FC, 0x4E2D))
function ConvertTo-AsciiEscaped { param([string]$Text)
    -join ($Text.ToCharArray() | ForEach-Object {
        if ([int]$_ -gt 127) { '\u{0:x4}' -f [int]$_ } else { [string]$_ } })
}

function Resolve-Tool { param([string[]]$Names)
    foreach ($n in $Names) {
        $c = Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    return $null
}
$python = Resolve-Tool @('python3', 'python')
$node = Resolve-Tool @('node')

# Fake CLI: drains stdin, records the call, prints a transcript whose last
# cross-model verdict object carries non-ASCII text as raw UTF-8 bytes.
$worker = Join-Path $workDir 'fake-panelist-cli.py'
[System.IO.File]::WriteAllText($worker, @'
import json, os, sys
sys.stdin.buffer.read()
with open(os.environ['STUB_MARKER'], 'a') as marker:
    marker.write('called\n')
mode = os.environ.get('STUB_MODE', 'PASS')
if mode == 'exit':
    sys.stderr.write('fake panelist failure\n')
    sys.exit(3)
verdict = {'schema': 'cross-model-verdict/v1', 'task_id': 'x', 'feature': 'x', 'vendor': 'x',
           'model': 'model-\u30e2\u30c7\u30eb\u00e9', 'verdict': 'NEEDS_WORK' if mode == 'NEEDS_WORK' else 'PASS',
           'findings': [{'severity': 'Minor', 'ref': 'a.md:1', 'note': 'note-\u00fc\u4e2d'}],
           'blind': mode != 'unblind', 'input_digest': 'a' * 64, 'consent': {'kind': 'human-flag', 'ref': 'r'}}
out = 'preamble\n' + json.dumps(verdict, ensure_ascii=False) + '\ntrailer\n'
sys.stdout.buffer.write(out.encode('utf-8'))
'@, $noBom)
$stubDir = Join-Path $workDir 'stub-bin'
New-Item -ItemType Directory -Path $stubDir | Out-Null
$onWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
foreach ($commandName in @('codex', 'gemini')) {
    if ($onWindows) {
        [System.IO.File]::WriteAllText((Join-Path $stubDir "$commandName.cmd"),
            "@echo off`r`n`"$python`" `"$worker`" %*`r`n", (New-Object System.Text.ASCIIEncoding))
    } else {
        $wrapper = Join-Path $stubDir $commandName
        [System.IO.File]::WriteAllText($wrapper, "#!/bin/sh`nexec `"$python`" `"$worker`" `"`$@`"`n", $noBom)
        & chmod +x $wrapper
    }
}

# Both consumers print the same ASCII-escaped projection, or fail on a BOM.
$pyConsumer = Join-Path $workDir 'consumer.py'
[System.IO.File]::WriteAllText($pyConsumer, @'
import json, sys
d = json.loads(open(sys.argv[1], 'rb').read().decode('utf-8'))
print(json.dumps([d['vendor'], d['model'], d['verdict'], d['findings'][0]['note'], d['task_id'], d['feature']],
                 separators=(',', ':')))
'@, $noBom)
$jsConsumer = Join-Path $workDir 'consumer.js'
[System.IO.File]::WriteAllText($jsConsumer, @'
const d = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const s = JSON.stringify([d.vendor, d.model, d.verdict, d.findings[0].note, d.task_id, d.feature]);
console.log(s.replace(/[^\x00-\x7f]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')));
'@, $noBom)

$inputBundle = Join-Path $workDir 'bundle.txt'
[System.IO.File]::WriteAllText($inputBundle, "# input_digest: $('a' * 64)`n# consent: human-flag`nfixture bundle`n", $noBom)

$saved = @{}
foreach ($name in @('PATH', 'STUB_MODE', 'STUB_MARKER', 'SDD_PANELIST_CODEX_CMD', 'SDD_PANELIST_TIMEOUT')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    $runtime = @(& $Producer -NoProfile -Command '$PSVersionTable.PSEdition; $PSVersionTable.PSVersion.ToString(); [Environment]::NewLine.Length')
    Write-Host "producer runtime: $Producer => $($runtime -join ' ')"
    if ($runtime.Count -ge 3 -and $runtime[0] -eq $ExpectEdition) {
        Ok "CM-017a: producer runtime is $ExpectEdition $($runtime[1])"
    } else {
        Fail "CM-017a: producer runtime must be $ExpectEdition, got '$($runtime -join ' ')'"
    }
    $crlf = ($runtime.Count -ge 3 -and $runtime[2] -eq '2')
    if (-not $python) { Fail 'CM-017: python3/python not found on PATH (fake CLI and strict consumer)' }
    if (-not $node) { Fail 'CM-017: strict Node consumer (node) not found on PATH' }

    # The stub directory shadows any real codex/gemini; the runner timeout stays far away.
    $env:PATH = $stubDir + [System.IO.Path]::PathSeparator + $saved['PATH']
    [Environment]::SetEnvironmentVariable('SDD_PANELIST_CODEX_CMD', $null)
    $env:SDD_PANELIST_TIMEOUT = '120'
    $marker = Join-Path $workDir 'stub-calls.txt'
    $env:STUB_MARKER = $marker

    $runners = @(
        @{ Name = 'gpt'; Script = 'run-panelist-gpt.ps1'; Vendor = 'openai' },
        @{ Name = 'gemini'; Script = 'run-panelist-gemini.ps1'; Vendor = 'google' }
    )
    $q = { param($s) "'" + ($s -replace "'", "''") + "'" }
    foreach ($runner in $runners) {
        $runnerPath = Join-Path $scriptsDir $runner.Script
        $verdictName = "T-001.panelist-$($runner.Vendor).verdict.json"
        $cases = @(
            @{ Name = 'pass'; Mode = 'PASS'; Exit = 0; Verdict = 'PASS' },
            @{ Name = 'needs-work'; Mode = 'NEEDS_WORK'; Exit = 0; Verdict = 'NEEDS_WORK' },
            @{ Name = 'session'; Mode = 'PASS'; Exit = 0; Verdict = 'PASS' },
            @{ Name = 'cli-failure'; Mode = 'exit'; Exit = 1; Verdict = $null },
            @{ Name = 'invalid-verdict'; Mode = 'unblind'; Exit = 1; Verdict = $null }
        )
        foreach ($case in $cases) {
            $label = "CM-017 [$ExpectEdition/$($runner.Name)/$($case.Name)]"
            $caseRoot = Join-Path $workDir "$($runner.Name)-$($case.Name)"
            New-Item -ItemType Directory -Path $caseRoot | Out-Null
            $env:STUB_MODE = $case.Mode
            if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
            $runArgs = @('--task', 'T-001', '--feature', 'f1', '--input', $inputBundle, '--spec-root', 'specs')
            if ($case.Name -eq 'session') {
                # In-session call with PS location != process directory: the verdict
                # must land under the PS location, as Set-Content resolved it.
                $command = "Set-Location -LiteralPath $(& $q $caseRoot); " +
                    "[Environment]::CurrentDirectory = $(& $q $workDir); " +
                    "if ([Environment]::CurrentDirectory -eq (Get-Location).ProviderPath) { exit 3 }; " +
                    "& $(& $q $runnerPath) $(($runArgs | ForEach-Object { & $q $_ }) -join ' '); exit `$LASTEXITCODE"
                $runOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1
            } else {
                # Relative --spec-root: a -File child starts in the caller's location.
                Push-Location -LiteralPath $caseRoot
                $runOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -File $runnerPath @runArgs 2>&1
                Pop-Location
            }
            $runExit = $LASTEXITCODE
            if (Test-Path -LiteralPath $marker) { Ok "$label fake CLI (not a provider) was invoked" }
            else { Fail "$label fake CLI was not invoked`n$(($runOutput | Out-String).Trim())" }
            if ($runExit -eq $case.Exit) { Ok "$label exit $runExit" }
            else { Fail "$label expected exit $($case.Exit), got $runExit`n$(($runOutput | Out-String).Trim())" }

            $verdictPath = Join-Path $caseRoot "specs/f1/verification/$verdictName"
            if (Test-Path -LiteralPath (Join-Path $workDir 'specs')) { Fail "$label verdict written relative to process directory" }
            if (-not $case.Verdict) {
                if (Test-Path -LiteralPath $verdictPath) { Fail "$label failure published a verdict" }
                else { Ok "$label failure publishes no verdict" }
                continue
            }
            if (-not (Test-Path -LiteralPath $verdictPath)) { Fail "$label verdict not written"; continue }
            $bytes = [System.IO.File]::ReadAllBytes($verdictPath)
            $head = ($bytes[0..([Math]::Min(2, $bytes.Length - 1))] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                Fail "$label verdict starts with UTF-8 BOM ($head)"
            } else { Ok "$label verdict has no UTF-8 BOM ($head)" }

            # Former Set-Content framing: native line endings, exactly one trailing newline.
            $text = $noBom.GetString($bytes)
            $nl = if ($crlf) { "`r`n" } else { "`n" }
            $lf = ([regex]::Matches($text, "`n")).Count
            $cr = ([regex]::Matches($text, "`r")).Count
            $nativeEndings = if ($crlf) { $cr -eq $lf -and ([regex]::Matches($text, "`r`n")).Count -eq $lf } else { $cr -eq 0 }
            if ($nativeEndings -and $lf -gt 1 -and $text.EndsWith($nl) -and -not $text.EndsWith($nl + $nl)) {
                Ok "$label verdict keeps native line endings and one trailing newline"
            } else {
                Fail "$label verdict line framing changed (LF=$lf CR=$cr crlf=$crlf)"
            }

            $expected = '["' + $runner.Vendor + '","' + (ConvertTo-AsciiEscaped $model) + '","' + $case.Verdict +
                '","' + (ConvertTo-AsciiEscaped $note) + '","T-001","f1"]'
            foreach ($consumer in @(@('python', $python, @('-I', $pyConsumer, $verdictPath)),
                                    @('node', $node, @($jsConsumer, $verdictPath)))) {
                if (-not $consumer[1]) { continue }
                $parsed = & $consumer[1] @($consumer[2]) 2>&1
                $parsedText = ($parsed | Out-String).Trim()
                if ($LASTEXITCODE -eq 0 -and $parsedText -ceq $expected) {
                    Ok "$label strict $($consumer[0]) parse keeps verdict and non-ASCII fields"
                } else {
                    Fail "$label strict $($consumer[0]) parse: expected $expected, got exit $LASTEXITCODE`n$parsedText"
                }
            }
        }
    }
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

Write-Host "Results: $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
exit 0
