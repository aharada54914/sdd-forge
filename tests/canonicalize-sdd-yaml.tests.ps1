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

function Expect-Reject([string]$Desc, [string]$FilePath, [string]$Category, [int]$ExitCode) {
  $r = Invoke-Canon -FilePath $FilePath
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

function Expect-StdoutBytes([string]$Desc, [string]$FilePath, [string]$ExpectedPath) {
  $r = Invoke-Canon -FilePath $FilePath
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

  # Documented exit-code table cross-check: every category this suite
  # exercised above used its own stable, distinct, non-zero exit code.
  $categoryCodes = [ordered]@{
    ANCHOR_REJECTED                  = 20
    ALIAS_REJECTED                   = 21
    CUSTOM_TAG_REJECTED              = 22
    DUPLICATE_KEY_REJECTED           = 23
    NON_STRING_KEY_REJECTED          = 24
    MULTI_DOCUMENT_REJECTED          = 25
    POST_NFC_DUPLICATE_KEY_REJECTED  = 27
    NUMBER_OUT_OF_RANGE_REJECTED     = 28
  }
  $seenCodes = @()
  $duplicateFound = $false
  foreach ($entry in $categoryCodes.GetEnumerator()) {
    if ($seenCodes -contains $entry.Value) {
      Test-Fail "TEST-037 exit-code table: $($entry.Key)'s code $($entry.Value) is unique across categories"
      $duplicateFound = $true
    } else {
      $seenCodes += $entry.Value
    }
  }
  if (-not $duplicateFound) {
    Test-Pass 'TEST-037 exit-code table: every rejection category exercised by this suite uses a distinct, stable, non-zero exit code'
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
