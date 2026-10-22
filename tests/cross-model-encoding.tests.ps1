# cross-model-encoding.tests.ps1 - issue #619: check-cross-model.ps1 aggregate bytes
# Runs the producer under the runtime named by -Producer (not the runtime hosting
# this file) and reads its aggregate with strict Python and Node JSON consumers.
# Must stay Windows PowerShell 5.1 compatible: ASCII-only source, no ::new(),
# no $IsWindows, and native stderr must not trip a Stop preference.
param(
    [Parameter(Mandatory = $true)][string]$Producer,
    [ValidateSet('Desktop', 'Core')][string]$ExpectEdition = 'Core'
)
$ErrorActionPreference = 'Continue'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$gate = Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts/check-cross-model.ps1'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sdd-cross-model-encoding-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
$noBom = New-Object System.Text.UTF8Encoding($false)
$script:Pass = 0
$script:Fail = 0
function Ok { param([string]$Name) Write-Host "ok: $Name"; $script:Pass++ }
function Fail { param([string]$Name) Write-Host "FAIL: $Name"; $script:Fail++ }

# Non-ASCII built from code points so the source stays ASCII under 5.1's ANSI read.
$model = 'model-' + (-join [char[]](0x30E2, 0x30C7, 0x30EB, 0x00E9))
$modelEscaped = -join ($model.ToCharArray() | ForEach-Object {
    if ([int]$_ -gt 127) { '\u{0:x4}' -f [int]$_ } else { [string]$_ } })
$digest = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'

# Both consumers print the same ASCII-escaped projection, or fail on a BOM.
$pyConsumer = Join-Path $workDir 'consumer.py'
[System.IO.File]::WriteAllText($pyConsumer, @'
import json, sys
d = json.loads(open(sys.argv[1], 'rb').read().decode('utf-8'))
print(json.dumps([d['result'], [p['model'] for p in d['panelists']]], separators=(',', ':')))
'@, $noBom)
$jsConsumer = Join-Path $workDir 'consumer.js'
[System.IO.File]::WriteAllText($jsConsumer, @'
const d = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const s = JSON.stringify([d.result, d.panelists.map(p => p.model)]);
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

try {
    $runtime = @(& $Producer -NoProfile -Command '$PSVersionTable.PSEdition; $PSVersionTable.PSVersion.ToString()')
    Write-Host "producer runtime: $Producer => $($runtime -join ' ')"
    if ($runtime.Count -ge 2 -and $runtime[0] -eq $ExpectEdition) {
        Ok "CM-016a: producer runtime is $ExpectEdition $($runtime[1])"
    } else {
        Fail "CM-016a: producer runtime must be $ExpectEdition, got '$($runtime -join ' ')'"
    }
    if (-not $python) { Fail 'CM-016: strict Python consumer (python3/python) not found on PATH' }
    if (-not $node) { Fail 'CM-016: strict Node consumer (node) not found on PATH' }

    $cases = @(
        @{ Name = 'pass'; Second = 'PASS'; Exit = 0; Result = 'PASS' },
        @{ Name = 'fail'; Second = 'NEEDS_WORK'; Exit = 1; Result = 'FAIL' }
    )
    foreach ($case in $cases) {
        $label = "CM-016 [$ExpectEdition/$($case.Name)]"
        $verification = Join-Path $workDir "$($case.Name)/specs/f1/verification"
        New-Item -ItemType Directory -Path $verification -Force | Out-Null
        foreach ($panel in @(@('anthropic', 'PASS'), @('openai', $case.Second))) {
            $verdict = [ordered]@{
                schema = 'cross-model-verdict/v1'; task_id = 'T-002'; feature = 'f1'
                vendor = $panel[0]; model = $model; verdict = $panel[1]; findings = @()
                blind = $true; input_digest = $digest; consent = @{ kind = 'human-flag' }
            }
            [System.IO.File]::WriteAllText((Join-Path $verification "T-002.panelist-$($panel[0]).verdict.json"),
                ($verdict | ConvertTo-Json -Depth 5), $noBom)
        }

        $gateOutput = & $Producer -NoProfile -ExecutionPolicy Bypass -File $gate `
            --task T-002 --feature f1 --spec-root (Join-Path $workDir "$($case.Name)/specs") 2>&1
        $gateExit = $LASTEXITCODE
        if ($gateExit -eq $case.Exit) { Ok "$label exit $gateExit" }
        else { Fail "$label expected exit $($case.Exit), got $gateExit`n$(($gateOutput | Out-String).Trim())" }

        $aggregate = Join-Path $verification 'T-002.cross-model.json'
        if (-not (Test-Path -LiteralPath $aggregate)) { Fail "$label aggregate not written"; continue }
        $bytes = [System.IO.File]::ReadAllBytes($aggregate)
        $head = ($bytes[0..([Math]::Min(2, $bytes.Length - 1))] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Fail "$label aggregate starts with UTF-8 BOM ($head)"
        } else { Ok "$label aggregate has no UTF-8 BOM ($head)" }

        $expected = '["' + $case.Result + '",["' + $modelEscaped + '","' + $modelEscaped + '"]]'
        foreach ($consumer in @(@('python', $python, @('-I', $pyConsumer, $aggregate)),
                                @('node', $node, @($jsConsumer, $aggregate)))) {
            if (-not $consumer[1]) { continue }
            $parsed = & $consumer[1] @($consumer[2]) 2>&1
            $parsedText = ($parsed | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $parsedText -ceq $expected) {
                Ok "$label strict $($consumer[0]) parse keeps result and non-ASCII model"
            } else {
                Fail "$label strict $($consumer[0]) parse: expected $expected, got exit $LASTEXITCODE`n$parsedText"
            }
        }
    }
} finally {
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

Write-Host "Results: $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
exit 0
