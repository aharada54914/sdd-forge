# T-002 (epic-189-a1-project-context, REQ-003): acceptance checks for
# plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py and its
# .sh/.ps1/.js dispatcher wrappers.
#
# PowerShell parity port of tests/canonicalize-sdd-yaml.tests.sh. See that
# file's header for the TEST-005..TEST-037/AC-005..AC-037 mapping.
#
# Every invocation below runs the wrapper (or a copy of it) in a CHILD
# process via Start-Process with -RedirectStandardOutput/-RedirectStandardError
# (never PowerShell's own `>`/`2>` redirection, and never an in-process `&`
# call): canonicalize-sdd-yaml.ps1 itself calls `exit $LASTEXITCODE`, which
# would terminate THIS test session if invoked in-process; Start-Process
# also gives byte-exact stdout/stderr capture via real OS file handles,
# which this suite's byte-exact-framing assertions (TEST-037) depend on.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("canon-yaml-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$CanonSh = Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh'
$CanonPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py'
$CanonPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.ps1'
$CanonJs = Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.js'
# The SAME PowerShell binary currently running this suite (pwsh or
# powershell.exe), matching tests/run-all.ps1's own convention.
$PowerShellExe = (Get-Process -Id $PID).Path

$script:PassCount = 0
$script:FailCount = 0

function Test-Pass([string]$Label) {
  $script:PassCount++
  Write-Output "PASS: $Label"
}

function Test-Fail([string]$Label, [string]$Detail = '') {
  $script:FailCount++
  Write-Output "FAIL: ${Label}: $Detail"
}

# Invoke-Canon: runs canonicalize-sdd-yaml.ps1 (or $Exe/$ExeArgsPrefix, if
# given, for the .py/.sh/.js cross-runtime checks) as a real child process,
# returning @{ ExitCode; StdoutPath; StderrPath }.
#
# Deliberately uses [System.Diagnostics.Process] with raw BaseStream reads
# into a MemoryStream, NOT `Start-Process -RedirectStandardOutput <file>`:
# on this host, Start-Process's file-based redirection was found to append
# a spurious trailing newline byte to EVERY captured child stdout,
# independent of the child process (reproduced with plain /bin/echo -n and
# /bin/cat, i.e. a Start-Process-specific artifact, not a bug in
# canonicalize-sdd-yaml.ps1 itself -- confirmed byte-exact when invoked via
# plain shell redirection). Reading the raw output stream directly avoids
# that layer entirely, which this suite's byte-exact-framing assertions
# (TEST-037) require.
function Invoke-Canon {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [string[]]$ExtraArgs = @(),
    [string]$Exe = $PowerShellExe,
    [string[]]$ExeArgsPrefix = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $CanonPs1)
  )
  $outPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.out')
  $errPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.err')
  $allArgs = @($ExeArgsPrefix) + @($FilePath) + $ExtraArgs

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $Exe
  foreach ($a in $allArgs) { $psi.ArgumentList.Add($a) }
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $proc = [System.Diagnostics.Process]::Start($psi)
  $stdoutStream = [System.IO.MemoryStream]::new()
  $stderrStream = [System.IO.MemoryStream]::new()
  $copyOutTask = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
  $copyErrTask = $proc.StandardError.BaseStream.CopyToAsync($stderrStream)
  $proc.WaitForExit()
  $copyOutTask.GetAwaiter().GetResult()
  $copyErrTask.GetAwaiter().GetResult()
  [System.IO.File]::WriteAllBytes($outPath, $stdoutStream.ToArray())
  [System.IO.File]::WriteAllBytes($errPath, $stderrStream.ToArray())

  return @{ ExitCode = $proc.ExitCode; StdoutPath = $outPath; StderrPath = $errPath }
}

function Get-Sha256Hex([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Expect-Reject([string]$Desc, [string]$FilePath, [string]$Category, [int]$ExitCode, [string[]]$ExtraArgs = @()) {
  $r = Invoke-Canon -FilePath $FilePath -ExtraArgs $ExtraArgs
  if ($r.ExitCode -ne $ExitCode) {
    Test-Fail $Desc "exit code: got $($r.ExitCode), want $ExitCode"
    return
  }
  $stderrText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
  if (-not $stderrText -or $stderrText -notmatch [regex]::Escape($Category)) {
    Test-Fail $Desc "stderr does not name category ${Category}: $stderrText"
    return
  }
  $stdoutBytes = [System.IO.File]::ReadAllBytes($r.StdoutPath)
  if ($stdoutBytes.Length -ne 0) {
    Test-Fail $Desc "stdout not empty on rejection ($($stdoutBytes.Length) bytes)"
    return
  }
  Test-Pass $Desc
}

function Expect-StdoutBytes([string]$Desc, [string]$FilePath, [string]$ExpectedPath, [string[]]$ExtraArgs = @()) {
  $r = Invoke-Canon -FilePath $FilePath -ExtraArgs $ExtraArgs
  if ($r.ExitCode -ne 0) {
    $stderrText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
    Test-Fail $Desc "exit code: got $($r.ExitCode), want 0; stderr: $stderrText"
    return
  }
  $actual = [System.IO.File]::ReadAllBytes($r.StdoutPath)
  $expected = [System.IO.File]::ReadAllBytes($ExpectedPath)
  if (Compare-Object $actual $expected -SyncWindow 0) {
    Test-Fail $Desc "stdout byte mismatch"
    return
  }
  Test-Pass $Desc
}

try {
  $Py = $null
  foreach ($candidate in @('python3', 'python')) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) { $Py = $candidate; break }
  }
  if (-not $Py) {
    Write-Output 'FAIL: no python3/python interpreter available'
    exit 1
  }

  # -------------------------------------------------------------------
  # TEST-005: rejection-category lock (AC-005).
  # -------------------------------------------------------------------

  $t005Anchor = Join-Path $Work 't005_anchor.yaml'
  Set-Content -LiteralPath $t005Anchor -NoNewline -Encoding utf8 -Value "key: &anchor value`nother: value2`n"
  Expect-Reject 'TEST-005 anchor rejected' $t005Anchor 'ANCHOR_REJECTED' 20

  $t005Alias = Join-Path $Work 't005_alias.yaml'
  Set-Content -LiteralPath $t005Alias -NoNewline -Encoding utf8 -Value "key: value`nother: *key`n"
  Expect-Reject 'TEST-005 alias rejected' $t005Alias 'ALIAS_REJECTED' 21

  $t005Tag = Join-Path $Work 't005_tag.yaml'
  Set-Content -LiteralPath $t005Tag -NoNewline -Encoding utf8 -Value "key: !!str value`n"
  Expect-Reject 'TEST-005 custom tag rejected' $t005Tag 'CUSTOM_TAG_REJECTED' 22

  $t005Dup = Join-Path $Work 't005_dup.yaml'
  Set-Content -LiteralPath $t005Dup -NoNewline -Encoding utf8 -Value "a: 1`nb: 2`na: 3`n"
  Expect-Reject 'TEST-005 duplicate key rejected' $t005Dup 'DUPLICATE_KEY_REJECTED' 23

  # -------------------------------------------------------------------
  # TEST-006: YAML-1.2-core-schema boolean-coercion avoidance (AC-006).
  # -------------------------------------------------------------------

  $t006Tokens = Join-Path $Work 't006_tokens.yaml'
  Set-Content -LiteralPath $t006Tokens -NoNewline -Encoding utf8 `
    -Value "a: yes`nb: no`nc: on`nd: off`ne: Yes`nf: TRUE`ng: FALSE`n"
  $t006Expected = Join-Path $Work 't006_expected.json'
  Set-Content -LiteralPath $t006Expected -NoNewline -Encoding utf8 `
    -Value '{"a":"yes","b":"no","c":"on","d":"off","e":"Yes","f":true,"g":false}'
  Expect-StdoutBytes 'TEST-006 1.1-only tokens (yes/no/on/off, any casing) stay strings; true/TRUE/FALSE resolve as booleans' `
    $t006Tokens $t006Expected

  # -------------------------------------------------------------------
  # TEST-007: NFC-normalization proof (AC-007).
  # -------------------------------------------------------------------

  $t007Precomposed = Join-Path $Work 't007_precomposed.yaml'
  [System.IO.File]::WriteAllBytes($t007Precomposed, [byte[]](0x61, 0x3a, 0x20, 0x63, 0x61, 0x66, 0xc3, 0xa9, 0x0a))
  $t007Decomposed = Join-Path $Work 't007_decomposed.yaml'
  [System.IO.File]::WriteAllBytes($t007Decomposed, [byte[]](0x61, 0x3a, 0x20, 0x63, 0x61, 0x66, 0x65, 0xcc, 0x81, 0x0a))

  $rPre = Invoke-Canon -FilePath $t007Precomposed
  $rDec = Invoke-Canon -FilePath $t007Decomposed
  $preBytes = [System.IO.File]::ReadAllBytes($rPre.StdoutPath)
  $decBytes = [System.IO.File]::ReadAllBytes($rDec.StdoutPath)
  if (-not (Compare-Object $preBytes $decBytes -SyncWindow 0)) {
    Test-Pass 'TEST-007 precomposed vs. decomposed NFC fixture pair produce byte-identical canonical output'
  } else {
    Test-Fail 'TEST-007 precomposed vs. decomposed NFC fixture pair produce byte-identical canonical output'
  }

  $rPreHash = Invoke-Canon -FilePath $t007Precomposed -ExtraArgs @('--hash-only')
  $rDecHash = Invoke-Canon -FilePath $t007Decomposed -ExtraArgs @('--hash-only')
  $hashPre = (Get-Content -Raw -LiteralPath $rPreHash.StdoutPath).Trim()
  $hashDec = (Get-Content -Raw -LiteralPath $rDecHash.StdoutPath).Trim()
  if ($hashPre -and $hashPre -eq $hashDec) {
    Test-Pass 'TEST-007 precomposed vs. decomposed NFC fixture pair produce an identical SHA-256'
  } else {
    Test-Fail 'TEST-007 precomposed vs. decomposed NFC fixture pair produce an identical SHA-256' "got '$hashPre' vs '$hashDec'"
  }

  # -------------------------------------------------------------------
  # TEST-008: JCS-compliance proof against a hand-computed golden byte
  # sequence (AC-008).
  # -------------------------------------------------------------------

  $t008Golden = Join-Path $Work 't008_golden.yaml'
  Set-Content -LiteralPath $t008Golden -NoNewline -Encoding utf8 -Value @'
zebra: 1.50
apple: 100
middle:
  b: 2
  a: 1
count: 0x1F
flag: TRUE
nothing: null
empty_list: []
'@
  $t008Expected = Join-Path $Work 't008_expected.json'
  Set-Content -LiteralPath $t008Expected -NoNewline -Encoding utf8 `
    -Value '{"apple":100,"count":31,"empty_list":[],"flag":true,"middle":{"a":1,"b":2},"nothing":null,"zebra":1.5}'
  Expect-StdoutBytes 'TEST-008 JCS golden byte sequence (key sort, hex int, trailing-zero float, bool/null)' `
    $t008Golden $t008Expected

  # -------------------------------------------------------------------
  # TEST-009: multi-runtime hash equality + dispatch-target proof (AC-009).
  # -------------------------------------------------------------------

  $t009Fixture = Join-Path $Work 't009_fixture.yaml'
  Set-Content -LiteralPath $t009Fixture -NoNewline -Encoding utf8 -Value "schema: sdd-project-context/v1`ncomponents: []`n"

  $rPy = Invoke-Canon -FilePath $t009Fixture -ExtraArgs @('--hash-only') -Exe $Py -ExeArgsPrefix @($CanonPy)
  $hashPy = (Get-Content -Raw -LiteralPath $rPy.StdoutPath).Trim()
  $rPs1 = Invoke-Canon -FilePath $t009Fixture -ExtraArgs @('--hash-only')
  $hashPs1 = (Get-Content -Raw -LiteralPath $rPs1.StdoutPath).Trim()
  if ($hashPy -and $hashPy -eq $hashPs1) {
    Test-Pass 'TEST-009 .py and .ps1 produce an identical SHA-256'
  } else {
    Test-Fail 'TEST-009 .py and .ps1 produce an identical SHA-256' "py='$hashPy' ps1='$hashPs1'"
  }

  $bashLike = $null
  foreach ($candidate in @('bash', 'sh')) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) { $bashLike = $candidate; break }
  }
  if ($bashLike) {
    $rSh = Invoke-Canon -FilePath $t009Fixture -ExtraArgs @('--hash-only') -Exe $bashLike -ExeArgsPrefix @($CanonSh)
    $hashSh = (Get-Content -Raw -LiteralPath $rSh.StdoutPath).Trim()
    if ($hashSh -eq $hashPy) {
      Test-Pass 'TEST-009 .sh produces the identical SHA-256 as .py'
    } else {
      Test-Fail 'TEST-009 .sh produces the identical SHA-256 as .py' "sh='$hashSh' py='$hashPy'"
    }
  } else {
    Write-Output 'SKIP: TEST-009 .sh hash-equality (bash/sh not found)'
  }

  if (Get-Command node -ErrorAction SilentlyContinue) {
    $rJs = Invoke-Canon -FilePath $t009Fixture -ExtraArgs @('--hash-only') -Exe 'node' -ExeArgsPrefix @($CanonJs)
    $hashJs = (Get-Content -Raw -LiteralPath $rJs.StdoutPath).Trim()
    if ($hashJs -eq $hashPy) {
      Test-Pass 'TEST-009 .js produces the identical SHA-256 as .py'
    } else {
      Test-Fail 'TEST-009 .js produces the identical SHA-256 as .py' "js='$hashJs' py='$hashPy'"
    }
  } else {
    Write-Output 'SKIP: TEST-009 .js hash-equality (node not found)'
  }

  # Dispatch-target proof: copy the .ps1 wrapper ALONE (no
  # canonicalize-sdd-yaml.py beside it) and confirm it FAILS.
  $DispatchOnly = Join-Path $Work 'dispatch-only'
  New-Item -ItemType Directory -Path $DispatchOnly -Force | Out-Null
  Copy-Item -LiteralPath $CanonPs1 -Destination $DispatchOnly
  $fixtureCopy = Join-Path $DispatchOnly 'fixture.yaml'
  Copy-Item -LiteralPath $t009Fixture -Destination $fixtureCopy
  $rDispatch = Invoke-Canon -FilePath $fixtureCopy -ExeArgsPrefix @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $DispatchOnly 'canonicalize-sdd-yaml.ps1'))
  if ($rDispatch.ExitCode -eq 0) {
    Test-Fail 'TEST-009 .ps1 dispatch-not-reimplement proof (.ps1 alone, without .py, unexpectedly succeeded)'
  } else {
    Test-Pass 'TEST-009 .ps1 dispatch-not-reimplement proof (.ps1 alone, without .py, fails -- no native PowerShell fallback exists)'
  }

  # CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3) fail-closed proof: an empty
  # PATH (no python3/python resolvable) must deny with the documented exit
  # code and diagnostic, and write nothing to stdout.
  $emptyPathDir = Join-Path $Work 'empty-path'
  New-Item -ItemType Directory -Path $emptyPathDir -Force | Out-Null
  $savedPath = $env:PATH
  try {
    $env:PATH = $emptyPathDir
    $rNoPy = Invoke-Canon -FilePath $t009Fixture
  } finally {
    $env:PATH = $savedPath
  }
  $stderrNoPy = Get-Content -Raw -LiteralPath $rNoPy.StderrPath -ErrorAction SilentlyContinue
  $stdoutNoPyBytes = [System.IO.File]::ReadAllBytes($rNoPy.StdoutPath)
  if ($rNoPy.ExitCode -eq 3 -and $stderrNoPy -and $stderrNoPy -match 'CANONICALIZER_RUNTIME_UNAVAILABLE' -and $stdoutNoPyBytes.Length -eq 0) {
    Test-Pass 'TEST-009 .ps1 denies fail-closed with CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3) when no python3/python is on PATH'
  } else {
    Test-Fail 'TEST-009 .ps1 denies fail-closed with CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3) when no python3/python is on PATH' `
      "exit=$($rNoPy.ExitCode) stderr=$stderrNoPy stdoutBytes=$($stdoutNoPyBytes.Length)"
  }

  # -------------------------------------------------------------------
  # TEST-037: accepted-domain boundary vectors (AC-037).
  # -------------------------------------------------------------------

  $t037MultiDoc = Join-Path $Work 't037_multidoc.yaml'
  Set-Content -LiteralPath $t037MultiDoc -NoNewline -Encoding utf8 -Value "a: 1`n---`nb: 2`n"
  Expect-Reject 'TEST-037 multi-document rejection' $t037MultiDoc 'MULTI_DOCUMENT_REJECTED' 25

  $t037NonStringKey = Join-Path $Work 't037_nonstringkey.yaml'
  Set-Content -LiteralPath $t037NonStringKey -NoNewline -Encoding utf8 -Value "123: value`n"
  Expect-Reject 'TEST-037 non-string-key rejection' $t037NonStringKey 'NON_STRING_KEY_REJECTED' 24

  $t037PostNfcDup = Join-Path $Work 't037_postnfcdup.yaml'
  [System.IO.File]::WriteAllBytes($t037PostNfcDup, [byte[]](
      0x63, 0x61, 0x66, 0xc3, 0xa9, 0x3a, 0x20, 0x31, 0x0a,
      0x63, 0x61, 0x66, 0x65, 0xcc, 0x81, 0x3a, 0x20, 0x32, 0x0a))
  Expect-Reject 'TEST-037 post-NFC duplicate-key collision rejection' $t037PostNfcDup 'POST_NFC_DUPLICATE_KEY_REJECTED' 27

  $t037Inf = Join-Path $Work 't037_inf.yaml'
  Set-Content -LiteralPath $t037Inf -NoNewline -Encoding utf8 -Value "a: .inf`n"
  Expect-Reject 'TEST-037 non-finite number rejection (.inf)' $t037Inf 'NUMBER_OUT_OF_RANGE_REJECTED' 28

  $t037Nan = Join-Path $Work 't037_nan.yaml'
  Set-Content -LiteralPath $t037Nan -NoNewline -Encoding utf8 -Value "a: .nan`n"
  Expect-Reject 'TEST-037 non-finite number rejection (.nan)' $t037Nan 'NUMBER_OUT_OF_RANGE_REJECTED' 28

  $t037NumBoundary = Join-Path $Work 't037_numboundary.yaml'
  Set-Content -LiteralPath $t037NumBoundary -NoNewline -Encoding utf8 `
    -Value "huge: 1e21`nbig: 1e20`ntiny: 1.0e-6`nsmaller: 1.0e-7`n"
  $t037NumBoundaryExpected = Join-Path $Work 't037_numboundary_expected.json'
  Set-Content -LiteralPath $t037NumBoundaryExpected -NoNewline -Encoding utf8 `
    -Value '{"big":100000000000000000000,"huge":1e+21,"smaller":1e-7,"tiny":0.000001}'
  Expect-StdoutBytes 'TEST-037 RFC 8785 §3.2.2.3 numeric-formatting boundary vector (1e20/1e21, 1e-6/1e-7)' `
    $t037NumBoundary $t037NumBoundaryExpected

  # byte-exact stdout-framing + documented exit-code assertion for success
  # and every rejection path (rejection half already asserted by every
  # Expect-Reject call above via its byte-exact-empty-stdout check).
  $rSuccess = Invoke-Canon -FilePath $t009Fixture
  $successBytes = [System.IO.File]::ReadAllBytes($rSuccess.StdoutPath)
  if ($successBytes.Length -eq 0 -or $successBytes[-1] -ne 0x0a) {
    Test-Pass 'TEST-037 byte-exact stdout framing: default mode has no trailing newline byte'
  } else {
    Test-Fail 'TEST-037 byte-exact stdout framing: default mode has no trailing newline byte' 'found trailing 0x0a'
  }
  $expectedSuccess = [System.Text.Encoding]::UTF8.GetBytes('{"components":[],"schema":"sdd-project-context/v1"}')
  if ($successBytes.Length -eq $expectedSuccess.Length) {
    Test-Pass "TEST-037 byte-exact stdout framing: default mode byte count matches exactly ($($successBytes.Length) bytes)"
  } else {
    Test-Fail 'TEST-037 byte-exact stdout framing: default mode byte count matches exactly' `
      "got $($successBytes.Length) want $($expectedSuccess.Length)"
  }

  $rHashOnly = Invoke-Canon -FilePath $t009Fixture -ExtraArgs @('--hash-only')
  $hashLine = (Get-Content -Raw -LiteralPath $rHashOnly.StdoutPath)
  $hashLineTrimmed = $hashLine.TrimEnd("`n", "`r")
  if ($hashLineTrimmed -match '^sha256:[0-9a-f]{64}$') {
    Test-Pass "TEST-037 byte-exact stdout framing: --hash-only emits exactly 'sha256:' + 64 hex chars"
  } else {
    Test-Fail "TEST-037 byte-exact stdout framing: --hash-only emits exactly 'sha256:' + 64 hex chars" "got '$hashLineTrimmed'"
  }
  $hashOnlyBytes = [System.IO.File]::ReadAllBytes($rHashOnly.StdoutPath)
  if ($hashOnlyBytes.Length -gt 0 -and $hashOnlyBytes[-1] -eq 0x0a) {
    Test-Pass 'TEST-037 byte-exact stdout framing: --hash-only output ends with exactly one trailing newline'
  } else {
    Test-Fail 'TEST-037 byte-exact stdout framing: --hash-only output ends with exactly one trailing newline'
  }

  # Documented exit-code table cross-check (remedy, quality-gate seq0346
  # Minor finding: the prior version asserted only literals typed into
  # THIS file and never read the script's own table, so it could not
  # detect drift). Reads CATEGORY_EXIT_CODES directly out of
  # canonicalize-sdd-yaml.py via a python3 subprocess and diffs it
  # against the documented table below -- a real, non-tautological
  # comparison that fails if the two diverge.
  $tableScript = @"
import importlib.util
spec = importlib.util.spec_from_file_location('canon', r'$CanonPy')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
for k, v in sorted(mod.CATEGORY_EXIT_CODES.items()):
    print('%s=%s' % (k, v))
"@
  $actualTable = (& $Py -c $tableScript | Out-String).Trim() -replace "`r`n", "`n"
  $expectedTable = @(
    'ALIAS_REJECTED=21',
    'ANCHOR_REJECTED=20',
    'CANONICALIZER_RUNTIME_UNAVAILABLE=3',
    'CUSTOM_TAG_REJECTED=22',
    'DUPLICATE_KEY_REJECTED=23',
    'INVALID_JSON_REJECTED=11',
    'INVALID_UTF8_REJECTED=10',
    'MULTI_DOCUMENT_REJECTED=25',
    'NON_STRING_KEY_REJECTED=24',
    'NUMBER_OUT_OF_RANGE_REJECTED=28',
    'POST_NFC_DUPLICATE_KEY_REJECTED=27',
    'UNSUPPORTED_SYNTAX_REJECTED=26'
  ) -join "`n"
  if ($actualTable -eq $expectedTable) {
    Test-Pass 'TEST-037(remedy) CATEGORY_EXIT_CODES read from canonicalize-sdd-yaml.py itself matches the documented table'
  } else {
    Test-Fail 'TEST-037(remedy) CATEGORY_EXIT_CODES read from canonicalize-sdd-yaml.py itself matches the documented table' "got: $actualTable"
  }

  # -------------------------------------------------------------------
  # Remedy (quality-gate seq0346, NEEDS_WORK): lone-surrogate escapes,
  # plain-scalar embedded ": " rejection, previously-uncovered exit
  # codes (26/10/11), and JSON input mode.
  # -------------------------------------------------------------------

  # (a) Lone (unpaired) UTF-16 surrogate -> INVALID_UTF8_REJECTED (10),
  # never an uncaught UnicodeEncodeError. Value + key, YAML + JSON mode.
  $remedySurrogateVal = Join-Path $Work 'remedy_surrogate_val.yaml'
  Set-Content -LiteralPath $remedySurrogateVal -NoNewline -Encoding utf8 -Value ('a: "\ud800"' + "`n")
  Expect-Reject 'TEST-REMEDY lone surrogate in a double-quoted scalar VALUE (YAML mode) is INVALID_UTF8_REJECTED, not an uncaught exception' `
    $remedySurrogateVal 'INVALID_UTF8_REJECTED' 10
  Expect-Reject 'TEST-REMEDY lone surrogate in a double-quoted scalar VALUE (YAML mode, --hash-only) is INVALID_UTF8_REJECTED' `
    $remedySurrogateVal 'INVALID_UTF8_REJECTED' 10 @('--hash-only')

  $remedySurrogateKeyYaml = Join-Path $Work 'remedy_surrogate_key.yaml'
  Set-Content -LiteralPath $remedySurrogateKeyYaml -NoNewline -Encoding utf8 -Value ('"\udfff": 1' + "`n")
  Expect-Reject 'TEST-REMEDY lone surrogate in a quoted mapping KEY (YAML mode) is INVALID_UTF8_REJECTED' `
    $remedySurrogateKeyYaml 'INVALID_UTF8_REJECTED' 10

  $remedySurrogateValJson = Join-Path $Work 'remedy_surrogate_val.json'
  Set-Content -LiteralPath $remedySurrogateValJson -NoNewline -Encoding utf8 -Value '{"a":"\ud800"}'
  Expect-Reject 'TEST-REMEDY lone surrogate in a string VALUE (JSON input mode) is INVALID_UTF8_REJECTED' `
    $remedySurrogateValJson 'INVALID_UTF8_REJECTED' 10

  $remedySurrogateKeyJson = Join-Path $Work 'remedy_surrogate_key.json'
  Set-Content -LiteralPath $remedySurrogateKeyJson -NoNewline -Encoding utf8 -Value '{"\udfff":1}'
  Expect-Reject 'TEST-REMEDY lone surrogate in an object KEY (JSON input mode) is INVALID_UTF8_REJECTED' `
    $remedySurrogateKeyJson 'INVALID_UTF8_REJECTED' 10

  # Regression guard: a correctly-paired surrogate escape (a real astral
  # character) must keep succeeding -- the fix must not over-reject.
  $remedyPair = Join-Path $Work 'remedy_pair.yaml'
  Set-Content -LiteralPath $remedyPair -NoNewline -Encoding utf8 -Value ('a: "😀"' + "`n")
  $remedyPairExpected = Join-Path $Work 'remedy_pair_expected.json'
  [System.IO.File]::WriteAllBytes($remedyPairExpected, [System.Text.Encoding]::UTF8.GetBytes('{"a":"😀"}'))
  Expect-StdoutBytes 'TEST-REMEDY a correctly-paired surrogate escape (astral character) still succeeds' `
    $remedyPair $remedyPairExpected

  # (b) A plain scalar containing ": " or ending with ":" is ambiguous
  # with a nested mapping entry -> UNSUPPORTED_SYNTAX_REJECTED (26) with
  # a quote-the-scalar hint, never best-effort-kept as scalar text.
  $remedyEmbeddedColon = Join-Path $Work 'remedy_embedded_colon.yaml'
  Set-Content -LiteralPath $remedyEmbeddedColon -NoNewline -Encoding utf8 -Value "a: b: c`n"
  Expect-Reject 'TEST-REMEDY plain scalar value ''b: c'' (embedded '': '') is rejected, not best-effort-interpreted' `
    $remedyEmbeddedColon 'UNSUPPORTED_SYNTAX_REJECTED' 26
  $rEmbedded = Invoke-Canon -FilePath $remedyEmbeddedColon
  $embeddedStderr = Get-Content -Raw -LiteralPath $rEmbedded.StderrPath -ErrorAction SilentlyContinue
  if ($embeddedStderr -match 'quote the scalar') {
    Test-Pass "TEST-REMEDY embedded ': ' rejection carries the quote-the-scalar hint"
  } else {
    Test-Fail "TEST-REMEDY embedded ': ' rejection carries the quote-the-scalar hint" $embeddedStderr
  }

  $remedyTrailingColon = Join-Path $Work 'remedy_trailing_colon.yaml'
  Set-Content -LiteralPath $remedyTrailingColon -NoNewline -Encoding utf8 -Value "key: value:`n"
  Expect-Reject "TEST-REMEDY plain scalar value 'value:' (trailing ':') is rejected" `
    $remedyTrailingColon 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedySeqEmbedded = Join-Path $Work 'remedy_seq_embedded_colon.yaml'
  Set-Content -LiteralPath $remedySeqEmbedded -NoNewline -Encoding utf8 -Value "- a: b: c`n"
  Expect-Reject "TEST-REMEDY embedded ': ' is rejected inside an inline '- key: value' mapping too" `
    $remedySeqEmbedded 'UNSUPPORTED_SYNTAX_REJECTED' 26

  # Regression guards: legitimate ':'-bearing content must keep working.
  $remedyUrl = Join-Path $Work 'remedy_url.yaml'
  Set-Content -LiteralPath $remedyUrl -NoNewline -Encoding utf8 -Value "a: http://example.com`n"
  $remedyUrlExpected = Join-Path $Work 'remedy_url_expected.json'
  Set-Content -LiteralPath $remedyUrlExpected -NoNewline -Encoding utf8 -Value '{"a":"http://example.com"}'
  Expect-StdoutBytes "TEST-REMEDY a URL value (':' not followed by a space) still succeeds" `
    $remedyUrl $remedyUrlExpected

  $remedyQuotedColon = Join-Path $Work 'remedy_quoted_colon.yaml'
  Set-Content -LiteralPath $remedyQuotedColon -NoNewline -Encoding utf8 -Value ('a: "b: c"' + "`n")
  $remedyQuotedColonExpected = Join-Path $Work 'remedy_quoted_colon_expected.json'
  Set-Content -LiteralPath $remedyQuotedColonExpected -NoNewline -Encoding utf8 -Value '{"a":"b: c"}'
  Expect-StdoutBytes "TEST-REMEDY a QUOTED value containing ': ' still succeeds" `
    $remedyQuotedColon $remedyQuotedColonExpected

  # (c) Previously-uncovered exit codes: UNSUPPORTED_SYNTAX_REJECTED (26)
  # via several independent out-of-subset constructs,
  # INVALID_UTF8_REJECTED (10) via genuinely invalid input bytes (not
  # just a surrogate escape), and INVALID_JSON_REJECTED (11) via
  # malformed JSON.
  $remedyBlockScalar = Join-Path $Work 'remedy_blockscalar.yaml'
  Set-Content -LiteralPath $remedyBlockScalar -NoNewline -Encoding utf8 -Value "a: |`n  block`n  scalar`n"
  Expect-Reject 'TEST-REMEDY(26) block scalar indicator is UNSUPPORTED_SYNTAX_REJECTED' `
    $remedyBlockScalar 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedyFlow = Join-Path $Work 'remedy_flow.yaml'
  Set-Content -LiteralPath $remedyFlow -NoNewline -Encoding utf8 -Value "a: [1, 2]`n"
  Expect-Reject 'TEST-REMEDY(26) non-empty flow sequence is UNSUPPORTED_SYNTAX_REJECTED' `
    $remedyFlow 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedyTab = Join-Path $Work 'remedy_tab.yaml'
  Set-Content -LiteralPath $remedyTab -NoNewline -Encoding utf8 -Value ("`ta: 1`n")
  Expect-Reject 'TEST-REMEDY(26) tab indentation is UNSUPPORTED_SYNTAX_REJECTED' `
    $remedyTab 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedyLeadMarker = Join-Path $Work 'remedy_leadmarker.yaml'
  Set-Content -LiteralPath $remedyLeadMarker -NoNewline -Encoding utf8 -Value "---`nkey: value`n"
  Expect-Reject "TEST-REMEDY(26) a leading '---' marker on a single document is UNSUPPORTED_SYNTAX_REJECTED" `
    $remedyLeadMarker 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedyBadUtf8 = Join-Path $Work 'remedy_badutf8.yaml'
  [System.IO.File]::WriteAllBytes($remedyBadUtf8, [byte[]](0xff, 0xfe, 0x20, 0x62, 0x61, 0x64, 0x0a))
  Expect-Reject 'TEST-REMEDY(10) genuinely invalid UTF-8 input BYTES (not an escape) is INVALID_UTF8_REJECTED' `
    $remedyBadUtf8 'INVALID_UTF8_REJECTED' 10

  $remedyBadJson = Join-Path $Work 'remedy_badjson.json'
  Set-Content -LiteralPath $remedyBadJson -NoNewline -Encoding utf8 -Value '{"a": 1,}'
  Expect-Reject 'TEST-REMEDY(11) malformed JSON input is INVALID_JSON_REJECTED' `
    $remedyBadJson 'INVALID_JSON_REJECTED' 11

  # JSON input mode generally (REQ-003's second declared input mode; the
  # T-003 HMAC-preimage path). Extension auto-detection, explicit
  # --input-format override, duplicate-key rejection, and non-finite
  # constant rejection.
  $remedyJsonRoundtrip = Join-Path $Work 'remedy_json_roundtrip.json'
  Set-Content -LiteralPath $remedyJsonRoundtrip -NoNewline -Encoding utf8 -Value '{"b":2,"a":1}'
  $remedyJsonRoundtripExpected = Join-Path $Work 'remedy_json_roundtrip_expected.json'
  Set-Content -LiteralPath $remedyJsonRoundtripExpected -NoNewline -Encoding utf8 -Value '{"a":1,"b":2}'
  Expect-StdoutBytes 'TEST-REMEDY JSON input mode round-trips and re-sorts keys (extension auto-detection)' `
    $remedyJsonRoundtrip $remedyJsonRoundtripExpected

  $remedyJsonRoundtripNoExt = Join-Path $Work 'remedy_json_roundtrip.noext'
  Copy-Item -LiteralPath $remedyJsonRoundtrip -Destination $remedyJsonRoundtripNoExt
  Expect-StdoutBytes 'TEST-REMEDY JSON input mode round-trips via explicit --input-format json (no .json extension)' `
    $remedyJsonRoundtripNoExt $remedyJsonRoundtripExpected @('--input-format', 'json')

  $remedyJsonDup = Join-Path $Work 'remedy_json_dup.json'
  Set-Content -LiteralPath $remedyJsonDup -NoNewline -Encoding utf8 -Value '{"a":1,"a":2}'
  Expect-Reject 'TEST-REMEDY JSON input mode rejects a duplicate object key' `
    $remedyJsonDup 'DUPLICATE_KEY_REJECTED' 23

  $remedyJsonNan = Join-Path $Work 'remedy_json_nan.json'
  Set-Content -LiteralPath $remedyJsonNan -NoNewline -Encoding utf8 -Value '{"a": NaN}'
  Expect-Reject 'TEST-REMEDY JSON input mode rejects the non-standard NaN constant' `
    $remedyJsonNan 'NUMBER_OUT_OF_RANGE_REJECTED' 28

  $remedyJsonInf = Join-Path $Work 'remedy_json_inf.json'
  Set-Content -LiteralPath $remedyJsonInf -NoNewline -Encoding utf8 -Value '{"a": Infinity}'
  Expect-Reject 'TEST-REMEDY JSON input mode rejects the non-standard Infinity constant' `
    $remedyJsonInf 'NUMBER_OUT_OF_RANGE_REJECTED' 28

  # -------------------------------------------------------------------
  # Remedy 2 (quality-gate seq0347, NEEDS_WORK): block-sequence '-' marker
  # separator handling -- more than one space, a tab, or an inline nested
  # sequence ('- - value') after '-' is now rejected
  # UNSUPPORTED_SYNTAX_REJECTED (26) with a construct-specific diagnostic.
  # Plus construct-specific diagnostics for '%'/'?'.
  # -------------------------------------------------------------------

  $remedy2MultiSpace = Join-Path $Work 'remedy2_multispace.yaml'
  Set-Content -LiteralPath $remedy2MultiSpace -NoNewline -Encoding utf8 -Value "-  a`n"
  Expect-Reject "TEST-REMEDY2 sequence item '-  a' (2 spaces) is rejected, not silently parsed as ' a'" `
    $remedy2MultiSpace 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedy2MultiSpace3 = Join-Path $Work 'remedy2_multispace3.yaml'
  Set-Content -LiteralPath $remedy2MultiSpace3 -NoNewline -Encoding utf8 -Value "-   a`n"
  Expect-Reject "TEST-REMEDY2 sequence item '-   a' (3 spaces) is rejected" `
    $remedy2MultiSpace3 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedy2MultiSpaceKey = Join-Path $Work 'remedy2_multispace_key.yaml'
  Set-Content -LiteralPath $remedy2MultiSpaceKey -NoNewline -Encoding utf8 -Value "-  k: v`n"
  Expect-Reject "TEST-REMEDY2 sequence inline mapping '-  k: v' (2 spaces) is rejected, not key-corrupted" `
    $remedy2MultiSpaceKey 'UNSUPPORTED_SYNTAX_REJECTED' 26

  $remedy2Coupled = Join-Path $Work 'remedy2_coupled.yaml'
  Set-Content -LiteralPath $remedy2Coupled -NoNewline -Encoding utf8 -Value "x:`n  -   k: v`n    j: w`n"
  $rCoupled = Invoke-Canon -FilePath $remedy2Coupled
  $coupledStderr = Get-Content -Raw -LiteralPath $rCoupled.StderrPath -ErrorAction SilentlyContinue
  $coupledStdoutBytes = [System.IO.File]::ReadAllBytes($rCoupled.StdoutPath)
  if ($rCoupled.ExitCode -eq 26 -and $coupledStderr -match "sequence '-' marker" -and $coupledStdoutBytes.Length -eq 0) {
    Test-Pass "TEST-REMEDY2 the multi-line coupled fixture now gets the construct-specific separator diagnostic, not the misleading generic one"
  } else {
    Test-Fail "TEST-REMEDY2 the multi-line coupled fixture now gets the construct-specific separator diagnostic" "exit=$($rCoupled.ExitCode) stderr=$coupledStderr"
  }

  $remedy2Tab = Join-Path $Work 'remedy2_tab.yaml'
  Set-Content -LiteralPath $remedy2Tab -NoNewline -Encoding utf8 -Value ("-`ta`n")
  Expect-Reject "TEST-REMEDY2 sequence item '-<TAB>a' is rejected, not reinterpreted as a bare scalar document" `
    $remedy2Tab 'UNSUPPORTED_SYNTAX_REJECTED' 26
  $rTab = Invoke-Canon -FilePath $remedy2Tab
  $tabStderr = Get-Content -Raw -LiteralPath $rTab.StderrPath -ErrorAction SilentlyContinue
  if ($tabStderr -match '(?i)tab') {
    Test-Pass "TEST-REMEDY2 the tab-separator rejection names 'tab' specifically"
  } else {
    Test-Fail "TEST-REMEDY2 the tab-separator rejection names 'tab' specifically" $tabStderr
  }

  $remedy2NestedLike = Join-Path $Work 'remedy2_nestedlike.yaml'
  Set-Content -LiteralPath $remedy2NestedLike -NoNewline -Encoding utf8 -Value "- - a`n"
  Expect-Reject "TEST-REMEDY2 inline nested-sequence lookalike '- - a' is rejected, not swallowed as '- a'" `
    $remedy2NestedLike 'UNSUPPORTED_SYNTAX_REJECTED' 26

  # Regression guards.
  $remedy2Baseline = Join-Path $Work 'remedy2_baseline.yaml'
  Set-Content -LiteralPath $remedy2Baseline -NoNewline -Encoding utf8 -Value "- k: v`n"
  $remedy2BaselineExpected = Join-Path $Work 'remedy2_baseline_expected.json'
  Set-Content -LiteralPath $remedy2BaselineExpected -NoNewline -Encoding utf8 -Value '[{"k":"v"}]'
  Expect-StdoutBytes "TEST-REMEDY2 correct single-space '- k: v' still succeeds" `
    $remedy2Baseline $remedy2BaselineExpected

  $remedy2MultilineNested = Join-Path $Work 'remedy2_multiline_nested.yaml'
  Set-Content -LiteralPath $remedy2MultilineNested -NoNewline -Encoding utf8 -Value "-`n  - a`n  - b`n-`n  - c`n"
  $remedy2MultilineNestedExpected = Join-Path $Work 'remedy2_multiline_nested_expected.json'
  Set-Content -LiteralPath $remedy2MultilineNestedExpected -NoNewline -Encoding utf8 -Value '[["a","b"],["c"]]'
  Expect-StdoutBytes "TEST-REMEDY2 multi-line nested sequence (bare '-' + indented block) still succeeds" `
    $remedy2MultilineNested $remedy2MultilineNestedExpected

  # (c) construct-specific diagnostics for '%' directives and '?' explicit keys.
  $remedy2Directive = Join-Path $Work 'remedy2_directive.yaml'
  Set-Content -LiteralPath $remedy2Directive -NoNewline -Encoding utf8 -Value "%YAML 1.2`na: 1`n"
  Expect-Reject "TEST-REMEDY2(c) a '%' directive gets a construct-specific diagnostic" `
    $remedy2Directive 'UNSUPPORTED_SYNTAX_REJECTED' 26
  $rDirective = Invoke-Canon -FilePath $remedy2Directive
  $directiveStderr = Get-Content -Raw -LiteralPath $rDirective.StderrPath -ErrorAction SilentlyContinue
  if ($directiveStderr -match '(?i)directive') {
    Test-Pass "TEST-REMEDY2(c) the '%' rejection names 'directive' specifically"
  } else {
    Test-Fail "TEST-REMEDY2(c) the '%' rejection names 'directive' specifically" $directiveStderr
  }

  $remedy2ExplicitKey = Join-Path $Work 'remedy2_explicitkey.yaml'
  Set-Content -LiteralPath $remedy2ExplicitKey -NoNewline -Encoding utf8 -Value "? a`n: 1`n"
  Expect-Reject "TEST-REMEDY2(c) a '?' explicit key gets a construct-specific diagnostic" `
    $remedy2ExplicitKey 'UNSUPPORTED_SYNTAX_REJECTED' 26
  $rExplicitKey = Invoke-Canon -FilePath $remedy2ExplicitKey
  $explicitKeyStderr = Get-Content -Raw -LiteralPath $rExplicitKey.StderrPath -ErrorAction SilentlyContinue
  if ($explicitKeyStderr -match '(?i)explicit-key') {
    Test-Pass "TEST-REMEDY2(c) the '?' rejection names 'explicit-key' specifically"
  } else {
    Test-Fail "TEST-REMEDY2(c) the '?' rejection names 'explicit-key' specifically" $explicitKeyStderr
  }

  # -------------------------------------------------------------------
  # Self-registration (design.md Test Strategy item 11).
  # -------------------------------------------------------------------

  $RunAllSh = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.sh')
  if ($RunAllSh -match 'canonicalize-sdd-yaml\.tests\.sh') {
    Test-Pass 'self-registration: tests/canonicalize-sdd-yaml.tests.sh registered in tests/run-all.sh'
  } else {
    Test-Fail 'self-registration: tests/canonicalize-sdd-yaml.tests.sh registered in tests/run-all.sh'
  }
  $RunAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.ps1')
  if ($RunAllPs1 -match 'canonicalize-sdd-yaml\.tests\.ps1') {
    Test-Pass 'self-registration: tests/canonicalize-sdd-yaml.tests.ps1 registered in tests/run-all.ps1'
  } else {
    Test-Fail 'self-registration: tests/canonicalize-sdd-yaml.tests.ps1 registered in tests/run-all.ps1'
  }

  Write-Output "PASS: $script:PassCount"
  Write-Output "FAIL: $script:FailCount"
  if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
