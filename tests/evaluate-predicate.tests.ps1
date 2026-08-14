# TDD suite for the Predicate DSL evaluator (T-002, REQ-002, ADR-0020) -- PowerShell twin.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$evalScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/evaluate-predicate.ps1'
$fixturesDir = Join-Path $root 'tests/fixtures/capability-registry'

$script:PassCount = 0
$script:FailCount = 0

function Ok([string]$Message) {
  $script:PassCount++
  Write-Host "ok: $Message"
}

function Fail([string]$Message) {
  $script:FailCount++
  [Console]::Error.WriteLine("not ok: $Message")
}

function Get-Keys($obj) {
  if ($obj -is [System.Management.Automation.PSCustomObject]) {
    $names = @($obj.PSObject.Properties | ForEach-Object { $_.Name })
    return , $names
  }
  return , @()
}

function Test-IsObject($v) { return ($v -is [System.Management.Automation.PSCustomObject]) }
function Test-IsArray($v) { if ($null -eq $v) { return $false }; return ($v -is [System.Array]) }

function Test-KeysWithin($obj, [string[]]$Allowed) {
  foreach ($k in (Get-Keys $obj)) { if ($Allowed -notcontains $k) { return $false } }
  return $true
}

$AllowedOperators = @('all', 'any', 'not', 'equals', 'not_equals', 'contains', 'in', 'exists')
$AllowedOutcomes = @('match', 'no-match', 'warn')

function Test-EvidenceValid($node) {
  if (-not (Test-IsObject $node)) { return $false }
  if (-not (Test-KeysWithin $node @('operator', 'path', 'outcome', 'reason', 'children'))) { return $false }
  $keys = Get-Keys $node
  if ($keys -notcontains 'operator' -or $keys -notcontains 'path' -or $keys -notcontains 'outcome') { return $false }
  if ($AllowedOperators -notcontains $node.operator) { return $false }
  if ($null -ne $node.path -and -not ($node.path -is [string])) { return $false }
  if ($AllowedOutcomes -notcontains $node.outcome) { return $false }
  if ($node.outcome -eq 'warn') {
    if ($keys -notcontains 'reason' -or -not ($node.reason -is [string]) -or $node.reason.Length -eq 0) { return $false }
  }
  if ($keys -contains 'children') {
    if (-not (Test-IsArray $node.children)) { return $false }
    foreach ($child in $node.children) { if (-not (Test-EvidenceValid $child)) { return $false } }
  }
  return $true
}

function Test-EvidenceConforms($outJson) {
  try {
    $parsed = $outJson | ConvertFrom-Json
  } catch {
    return $false
  }
  if (-not (Test-HasProp $parsed 'evidence')) { return $false }
  if (-not (Test-IsArray $parsed.evidence)) { return $false }
  foreach ($e in $parsed.evidence) { if (-not (Test-EvidenceValid $e)) { return $false } }
  return $true
}

function Test-HasProp($obj, [string]$name) {
  return ((Get-Keys $obj) -contains $name)
}

function Invoke-Predicate([string]$FixtureName) {
  $fixturePath = Join-Path $fixturesDir "$FixtureName.json"
  $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
  $predPath = New-TemporaryFile
  $propsPath = New-TemporaryFile
  ($fixture.predicate | ConvertTo-Json -Depth 50 -Compress) | Set-Content -LiteralPath $predPath -NoNewline
  ($fixture.properties | ConvertTo-Json -Depth 50 -Compress) | Set-Content -LiteralPath $propsPath -NoNewline

  $powerShellExe = (Get-Process -Id $PID).Path
  $stderrPath = New-TemporaryFile
  $stdout = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $evalScript `
    --predicate $predPath --component-properties $propsPath 2>$stderrPath
  $rc = $LASTEXITCODE
  $errText = (Get-Content -Raw -LiteralPath $stderrPath -ErrorAction SilentlyContinue)
  Remove-Item -LiteralPath $predPath, $propsPath, $stderrPath -ErrorAction SilentlyContinue

  return [PSCustomObject]@{
    Out  = ($stdout -join "`n")
    Rc   = $rc
    Err  = $errText
  }
}

function Assert-SchemaError([string]$Name, $Invocation) {
  if ($Invocation.Rc -eq 0) {
    Fail "$Name`: expected non-zero exit for PREDICATE_SCHEMA_ERROR, got 0"
    return
  }
  if ($Invocation.Err -notmatch '^PREDICATE_SCHEMA_ERROR:') {
    Fail "$Name`: expected stderr to start with PREDICATE_SCHEMA_ERROR:, got: $($Invocation.Err)"
    return
  }
  Ok $Name
}

function Assert-Predicate([string]$Name, $Invocation, [scriptblock]$Check) {
  if ($Invocation.Rc -ne 0) {
    Fail "$Name`: expected exit 0, got $($Invocation.Rc) (stderr: $($Invocation.Err))"
    return
  }
  try {
    $parsed = $Invocation.Out | ConvertFrom-Json
  } catch {
    Fail "$Name`: output is not valid JSON: $($Invocation.Out)"
    return
  }
  try {
    $checkResult = & $Check $parsed
  } catch {
    Fail "$Name`: assertion raised an exception (unexpected shape) -- actual: $($Invocation.Out) -- $($_.Exception.Message)"
    return
  }
  if ($checkResult) {
    Ok $Name
  } else {
    Fail "$Name`: assertion failed -- actual: $($Invocation.Out)"
  }
}

# =====================================================================
# TEST-007: fail-closed general rule x4 operators x3 cases (12 cases)
# =====================================================================
foreach ($case in @('equals', 'not-equals', 'contains', 'in')) {
  foreach ($cond in @('missing', 'null')) {
    $fixture = "predicate-fail-closed-$case-$cond"
    $inv = Invoke-Predicate $fixture
    Assert-Predicate "TEST-007 $fixture`: result=false" $inv { param($p) $p.result -eq $false }
    Assert-Predicate "TEST-007 $fixture`: evidence[0].outcome=warn" $inv { param($p) $p.evidence[0].outcome -eq 'warn' }
    Assert-Predicate "TEST-007 $fixture`: evidence[0].reason populated" $inv { param($p) ($p.evidence[0].reason -is [string]) -and $p.evidence[0].reason.Length -gt 0 }
    if (Test-EvidenceConforms $inv.Out) { Ok "TEST-013 $fixture`: evidence conforms" } else { Fail "TEST-013 $fixture`: evidence conforms" }
  }
}
$inv = Invoke-Predicate 'predicate-fail-closed-equals-type-mismatch'
Assert-Predicate 'TEST-007 equals-type-mismatch: warn/type-mismatch' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'warn' -and $p.evidence[0].reason -eq 'type-mismatch' }
$inv = Invoke-Predicate 'predicate-fail-closed-not-equals-type-mismatch'
Assert-Predicate 'TEST-007 not-equals-type-mismatch: warn (never a true match on type mismatch)' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'warn' -and $p.evidence[0].reason -eq 'type-mismatch' }
$inv = Invoke-Predicate 'predicate-fail-closed-contains-nonarray'
Assert-Predicate 'TEST-007 contains-nonarray: warn' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'warn' }
$inv = Invoke-Predicate 'predicate-fail-closed-in-malformed-value'
Assert-Predicate 'TEST-007 in-malformed-value: warn/malformed-value-array' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'warn' -and $p.evidence[0].reason -eq 'malformed-value-array' }

# =====================================================================
# TEST-008: exists x3
# =====================================================================
$inv = Invoke-Predicate 'predicate-exists-present-null'
Assert-Predicate 'TEST-008 exists present-with-null: match (true), no type inspection' $inv { param($p) $p.result -eq $true -and $p.evidence[0].outcome -eq 'match' }
$inv = Invoke-Predicate 'predicate-exists-present-value'
Assert-Predicate 'TEST-008 exists present-with-value: match (true)' $inv { param($p) $p.result -eq $true -and $p.evidence[0].outcome -eq 'match' }
$inv = Invoke-Predicate 'predicate-exists-absent'
Assert-Predicate 'TEST-008 exists absent: false + WARN' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'warn' -and $p.evidence[0].reason -eq 'missing-path' }

# =====================================================================
# TEST-009: all/any empty/true/false/mixed, no short-circuit
# =====================================================================
$inv = Invoke-Predicate 'predicate-all-empty'
Assert-Predicate 'TEST-009 all-empty: true (vacuous)' $inv { param($p) $p.result -eq $true -and $p.evidence[0].outcome -eq 'match' -and @($p.evidence[0].children).Count -eq 0 }
$inv = Invoke-Predicate 'predicate-all-true'
Assert-Predicate 'TEST-009 all-true: true, 2 children recorded' $inv { param($p) $p.result -eq $true -and @($p.evidence[0].children).Count -eq 2 -and @(@($p.evidence[0].children) | Where-Object { $_.outcome -ne 'match' }).Count -eq 0 }
$inv = Invoke-Predicate 'predicate-all-false'
Assert-Predicate 'TEST-009 all-false: false, both children recorded (no short-circuit)' $inv { param($p) $p.result -eq $false -and @($p.evidence[0].children).Count -eq 2 }
$inv = Invoke-Predicate 'predicate-any-empty'
Assert-Predicate 'TEST-009 any-empty: false (vacuous)' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'no-match' -and @($p.evidence[0].children).Count -eq 0 }
$inv = Invoke-Predicate 'predicate-any-mixed-no-shortcircuit'
Assert-Predicate 'TEST-009 any-mixed: true, all 3 children recorded despite match on child 2' $inv { param($p) $p.result -eq $true -and @($p.evidence[0].children).Count -eq 3 }
$inv = Invoke-Predicate 'predicate-any-false'
Assert-Predicate 'TEST-009 any-false: false, both children recorded' $inv { param($p) $p.result -eq $false -and @($p.evidence[0].children).Count -eq 2 }

# =====================================================================
# TEST-010: trigger vs conditional_facets[].when share one evaluator
# =====================================================================
$invTrigger = Invoke-Predicate 'predicate-trigger-context'
$invWhen = Invoke-Predicate 'predicate-when-context'
if ($invTrigger.Out -eq $invWhen.Out) {
  Ok 'TEST-010: trigger-context and when-context produce byte-identical evidence (single shared evaluator)'
} else {
  Fail 'TEST-010: trigger-context and when-context evidence diverged'
}

# =====================================================================
# TEST-011: field-allowlist PREDICATE_SCHEMA_ERROR + drift-check fixture
# =====================================================================
$inv = Invoke-Predicate 'predicate-bad-field'
Assert-SchemaError 'TEST-011: field outside allowlist rejected as PREDICATE_SCHEMA_ERROR' $inv

$powerShellExe = (Get-Process -Id $PID).Path
& $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $evalScript --check-field-allowlist (Join-Path $fixturesDir 'project-context-fixture-match.json') | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'TEST-011: drift-check passes against a matching Project Context fixture' } else { Fail 'TEST-011: drift-check unexpectedly failed against a matching fixture' }

& $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $evalScript --check-field-allowlist (Join-Path $fixturesDir 'project-context-fixture-drift.json') | Out-Null
if ($LASTEXITCODE -ne 0) { Ok 'TEST-011: drift-check fails against a diverging Project Context fixture' } else { Fail 'TEST-011: drift-check wrongly passed against a diverging fixture' }

# =====================================================================
# TEST-012: not arity + truth table
# =====================================================================
$inv = Invoke-Predicate 'predicate-not-zero-children'
Assert-SchemaError 'TEST-012: not with zero children is PREDICATE_SCHEMA_ERROR' $inv
$inv = Invoke-Predicate 'predicate-not-two-children'
Assert-SchemaError 'TEST-012: not with two children is PREDICATE_SCHEMA_ERROR' $inv
$inv = Invoke-Predicate 'predicate-not-child-true'
Assert-Predicate 'TEST-012: not(child=true) -> false' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'no-match' -and $p.evidence[0].children[0].outcome -eq 'match' }
$inv = Invoke-Predicate 'predicate-not-child-false'
Assert-Predicate 'TEST-012: not(child=false) -> true' $inv { param($p) $p.result -eq $true -and $p.evidence[0].outcome -eq 'match' -and $p.evidence[0].children[0].outcome -eq 'no-match' }
$inv = Invoke-Predicate 'predicate-not-child-warn'
Assert-Predicate 'TEST-012: not(child=warn) -> false (not naive negation), child WARN preserved' $inv { param($p) $p.result -eq $false -and $p.evidence[0].outcome -eq 'no-match' -and $p.evidence[0].children[0].outcome -eq 'warn' -and $p.evidence[0].children[0].reason.Length -gt 0 }

# =====================================================================
# TEST-013: Evidence-JSON-Schema conformance (all non-error fixtures) +
# nested depth-first stable ordering
# =====================================================================
$allOkFixtures = @(
  'predicate-fail-closed-equals-missing', 'predicate-fail-closed-equals-null', 'predicate-fail-closed-equals-type-mismatch',
  'predicate-fail-closed-not-equals-missing', 'predicate-fail-closed-not-equals-null', 'predicate-fail-closed-not-equals-type-mismatch',
  'predicate-fail-closed-contains-missing', 'predicate-fail-closed-contains-null', 'predicate-fail-closed-contains-nonarray',
  'predicate-fail-closed-in-missing', 'predicate-fail-closed-in-null', 'predicate-fail-closed-in-malformed-value',
  'predicate-exists-present-null', 'predicate-exists-present-value', 'predicate-exists-absent',
  'predicate-all-empty', 'predicate-all-true', 'predicate-all-false', 'predicate-any-empty', 'predicate-any-mixed-no-shortcircuit', 'predicate-any-false',
  'predicate-trigger-context', 'predicate-when-context',
  'predicate-not-child-true', 'predicate-not-child-false', 'predicate-not-child-warn',
  'predicate-nested-depth-first'
)
$conformFailures = 0
foreach ($f in $allOkFixtures) {
  $inv = Invoke-Predicate $f
  if ($inv.Rc -ne 0) { Fail "TEST-013 $f`: expected exit 0 for evidence-conformance sweep"; $conformFailures++; continue }
  if (-not (Test-EvidenceConforms $inv.Out)) { Fail "TEST-013 $f`: evidence does not conform to the Evidence JSON Schema"; $conformFailures++ }
}
if ($conformFailures -eq 0) { Ok 'TEST-013: every non-error fixture''s evidence conforms to the Evidence JSON Schema' }

$first = Invoke-Predicate 'predicate-nested-depth-first'
$second = Invoke-Predicate 'predicate-nested-depth-first'
if ($first.Out -eq $second.Out) {
  Ok 'TEST-013: nested all/any/not tree produces byte-identical, stably-ordered evidence across repeated runs'
} else {
  Fail 'TEST-013: nested tree evidence ordering is not stable across repeated runs'
}
Assert-Predicate 'TEST-013: nested tree depth-first order (all[0]=any, all[1]=not)' $first {
  param($p)
  $p.evidence[0].operator -eq 'all' -and @($p.evidence[0].children).Count -eq 2 -and
    $p.evidence[0].children[0].operator -eq 'any' -and $p.evidence[0].children[1].operator -eq 'not'
}

# =====================================================================
# TEST-040: forbidden operator token, independent of TEST-011
# =====================================================================
$inv = Invoke-Predicate 'predicate-bad-operator-regex'
Assert-SchemaError "TEST-040: 'regex' operator token rejected as PREDICATE_SCHEMA_ERROR" $inv
$inv = Invoke-Predicate 'predicate-bad-operator-jsonpath'
Assert-SchemaError "TEST-040: 'jsonpath' operator token rejected as PREDICATE_SCHEMA_ERROR" $inv

# =====================================================================
# Suite/CI registration self-checks
# =====================================================================
$runAllSh = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.sh')
if ($runAllSh -match [regex]::Escape('tests/evaluate-predicate.tests.sh')) {
  Ok 'self-registration: evaluate-predicate.tests.sh registered in tests/run-all.sh'
} else {
  Fail 'self-registration: evaluate-predicate.tests.sh NOT registered in tests/run-all.sh'
}
$runAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.ps1')
if ($runAllPs1 -match [regex]::Escape('tests/evaluate-predicate.tests.ps1')) {
  Ok 'self-registration: evaluate-predicate.tests.ps1 registered in tests/run-all.ps1'
} else {
  Fail 'self-registration: evaluate-predicate.tests.ps1 NOT registered in tests/run-all.ps1'
}

$humanCopyDir = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy'
$stagedWorkflow = Join-Path $humanCopyDir '.github/workflows/test.yml'
$stagedManifest = Join-Path $humanCopyDir 'MANIFEST.sha256'
if (Test-Path -LiteralPath $stagedWorkflow) {
  $stagedText = Get-Content -Raw -LiteralPath $stagedWorkflow
  if (($stagedText -match [regex]::Escape('tests/evaluate-predicate.tests.sh')) -and ($stagedText -match [regex]::Escape('tests/evaluate-predicate.tests.ps1'))) {
    Ok "human-copy: staged workflow candidate registers this suite's CI steps"
  } else {
    Fail "human-copy: staged workflow candidate missing this suite's CI steps"
  }
  if (Test-Path -LiteralPath $stagedManifest) {
    $stagedHash = (Get-FileHash -LiteralPath $stagedWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestLines = @(Get-Content -LiteralPath $stagedManifest)
    $manifestLine = @($manifestLines -match 'workflows/test\.yml')
    if ($manifestLine.Count -gt 0) {
      $manifestHash = ($manifestLine[0] -split '\s+')[0].ToLowerInvariant()
      if ($stagedHash -eq $manifestHash) { Ok 'human-copy: staged workflow candidate sha256 matches MANIFEST.sha256' }
      else { Fail 'human-copy: staged workflow candidate sha256 does not match MANIFEST.sha256' }
    } else {
      Fail 'human-copy: MANIFEST.sha256 has no entry for the staged workflow candidate'
    }
  } else {
    Fail 'human-copy: MANIFEST.sha256 missing'
  }
} else {
  Fail 'human-copy: staged .github/workflows/test.yml candidate missing'
}

Write-Host ("---- summary: pass={0} fail={1} ----" -f $script:PassCount, $script:FailCount)
if ($script:FailCount -eq 0) {
  Write-Host "evaluate-predicate suite passed ($script:PassCount checks)"
  exit 0
} else {
  Write-Host "evaluate-predicate suite FAILED ($script:PassCount passed, $script:FailCount failed)"
  exit 1
}
