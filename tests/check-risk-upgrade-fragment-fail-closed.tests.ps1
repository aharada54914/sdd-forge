# check-risk-upgrade-fragment-fail-closed.tests.ps1
# (epic-194-a6-lite-integration, T-002, design.md Test Strategy item 13,
# TEST-013, AC-027, Blocker [B3]). PowerShell twin of
# check-risk-upgrade-fragment-fail-closed.tests.sh -- see that file's header
# for the canonical staged human-copy SUT-path note.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Sut = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.ps1'
$PowerShell = (Get-Process -Id $PID).Path

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t002-fc-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

function Assert-FragmentInvalid([string]$Label, [string]$FragmentPath) {
    $cleanPath = Join-Path $Work 'clean.txt'
    $output = & $PowerShell -NoProfile -File $Sut -Path $cleanPath -CapabilityReasons $FragmentPath 2>&1
    $exitCode = $LASTEXITCODE
    $joined = ($output -join "`n")
    if ($exitCode -eq 2) { Ok "$Label`: exits 2" } else { Bad "$Label`: expected exit 2, got $exitCode. Output: $joined" }
    if ($joined -eq 'risk-upgrade: capability-reasons fragment invalid') { Ok "$Label`: prints the dedicated fragment-invalid diagnostic" } else { Bad "$Label`: unexpected output: $joined" }
}

try {
    Set-Content -LiteralPath (Join-Path $Work 'clean.txt') -Value 'clean source, no keyword match at all.' -NoNewline

    Write-Host '=== TEST-013a: unreadable (missing) fragment path ==='
    Assert-FragmentInvalid 'TEST-013a' (Join-Path $Work 'does-not-exist.json')

    Write-Host '=== TEST-013b: malformed (not valid JSON) fragment ==='
    Set-Content -LiteralPath (Join-Path $Work 'malformed.json') -Value 'not valid json {{{ at all' -NoNewline
    Assert-FragmentInvalid 'TEST-013b' (Join-Path $Work 'malformed.json')

    Write-Host "=== TEST-013c: shape-invalid -- missing 'capabilities' key ==="
    Set-Content -LiteralPath (Join-Path $Work 'no-capabilities-key.json') -Value '{"not_capabilities": []}' -NoNewline
    Assert-FragmentInvalid 'TEST-013c' (Join-Path $Work 'no-capabilities-key.json')

    Write-Host "=== TEST-013d: shape-invalid -- 'capabilities' is not an array ==="
    Set-Content -LiteralPath (Join-Path $Work 'not-array.json') -Value '{"capabilities": "not-an-array"}' -NoNewline
    Assert-FragmentInvalid 'TEST-013d' (Join-Path $Work 'not-array.json')

    Write-Host "=== TEST-013e: shape-invalid -- entry missing 'id' ==="
    Set-Content -LiteralPath (Join-Path $Work 'missing-id.json') -Value '{"capabilities": [{"eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013e' (Join-Path $Work 'missing-id.json')

    Write-Host "=== TEST-013f: shape-invalid -- entry missing 'eligible' ==="
    Set-Content -LiteralPath (Join-Path $Work 'missing-eligible.json') -Value '{"capabilities": [{"id": "x"}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013f' (Join-Path $Work 'missing-eligible.json')

    Write-Host '=== TEST-013g: distinct from the omitted-argument case ==='
    $omitOutput = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') 2>&1
    $omitExit = $LASTEXITCODE
    $omitJoined = ($omitOutput -join "`n")
    if ($omitExit -eq 0 -and $omitJoined -eq 'lite-eligible') { Ok 'TEST-013g: omitted-argument case is unaffected (exit 0, lite-eligible)' } else { Bad "TEST-013g: omitted-argument case regressed. exit=$omitExit output=$omitJoined" }

    # -------------------------------------------------------------------
    # TEST-013h-n: cross-model panelist findings (T-002 remediation) --
    # supplied-but-empty is SUPPLIED not omitted; a scalar upgrade_reasons;
    # eligible:null/0/"false" are all shape-invalid, never a silent
    # degrade or a fail-open/fail-closed runtime divergence; an id
    # carrying a grammar delimiter cannot forge a second trigger entry.
    # -------------------------------------------------------------------
    Write-Host "=== TEST-013h: supplied-but-empty -CapabilityReasons '' (SUPPLIED, not omitted) ==="
    $hOutput = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') -CapabilityReasons '' 2>&1
    $hExit = $LASTEXITCODE
    $hJoined = ($hOutput -join "`n")
    if ($hExit -eq 2) { Ok 'TEST-013h: exits 2 (empty value is SUPPLIED, matching presence-based ContainsKey detection)' } else { Bad "TEST-013h: expected exit 2, got $hExit. Output: $hJoined" }
    if ($hJoined -eq 'risk-upgrade: capability-reasons fragment invalid') { Ok 'TEST-013h: prints the dedicated fragment-invalid diagnostic, no silent degrade' } else { Bad "TEST-013h: unexpected output: $hJoined" }

    Write-Host "=== TEST-013i: shape-invalid -- 'upgrade_reasons' is a scalar, not an array ==="
    Set-Content -LiteralPath (Join-Path $Work 'scalar-reasons.json') -Value '{"capabilities": [{"id": "x", "eligible": false, "upgrade_reasons": "scalar-not-array"}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013i' (Join-Path $Work 'scalar-reasons.json')

    Write-Host "=== TEST-013j: shape-invalid -- 'eligible' is null (not a boolean) ==="
    Set-Content -LiteralPath (Join-Path $Work 'eligible-null.json') -Value '{"capabilities": [{"id": "x", "eligible": null}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013j' (Join-Path $Work 'eligible-null.json')

    Write-Host "=== TEST-013k: shape-invalid -- 'eligible' is 0 (numeric, not boolean) ==="
    Set-Content -LiteralPath (Join-Path $Work 'eligible-zero.json') -Value '{"capabilities": [{"id": "x", "eligible": 0}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013k' (Join-Path $Work 'eligible-zero.json')

    Write-Host '=== TEST-013l: shape-invalid -- eligible is the string "false" (not boolean) ==='
    Set-Content -LiteralPath (Join-Path $Work 'eligible-string-false.json') -Value '{"capabilities": [{"id": "x", "eligible": "false"}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013l' (Join-Path $Work 'eligible-string-false.json')

    Write-Host "=== TEST-013m: shape-invalid -- id carries a ',' delimiter (cannot forge a second trigger entry) ==="
    Set-Content -LiteralPath (Join-Path $Work 'id-comma.json') -Value '{"capabilities": [{"id": "evil,forged-trigger", "eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013m' (Join-Path $Work 'id-comma.json')

    Write-Host "=== TEST-013n: shape-invalid -- id carries a ';' delimiter (cannot forge a second trigger entry) ==="
    Set-Content -LiteralPath (Join-Path $Work 'id-semicolon.json') -Value '{"capabilities": [{"id": "evil;forged-trigger", "eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013n' (Join-Path $Work 'id-semicolon.json')

    # ---------------------------------------------------------------
    # TEST-013o-r: cross-model panelist re-run (T-002 remediation,
    # Critical) -- a bare object for "capabilities" (not wrapped in an
    # array) must not be silently treated as a one-element array; an id
    # carrying an embedded newline must not slip through the grammar via
    # the trailing-newline `$` quirk; an explicitly empty id must not
    # produce a degenerate "ineligible:" token; a bare
    # 2-positional-argument invocation (no -CapabilityReasons flag) must
    # not be treated as SUPPLIED.
    # ---------------------------------------------------------------
    Write-Host "=== TEST-013o: shape-invalid -- 'capabilities' is a bare object, not an array ==="
    Set-Content -LiteralPath (Join-Path $Work 'capabilities-object.json') -Value '{"capabilities": {"id": "x", "eligible": false}}' -NoNewline
    Assert-FragmentInvalid 'TEST-013o' (Join-Path $Work 'capabilities-object.json')

    Write-Host '=== TEST-013p: shape-invalid -- id carries an embedded newline (single-line contract) ==='
    # PowerShell single-quoted strings are raw literals, so `\n` here is
    # the two literal characters backslash-n -- a valid JSON \n escape
    # that decodes to an actual newline character inside the parsed "id"
    # string (see the sh twin's own note on why a raw newline BYTE would
    # instead be a JSON syntax error, a different and less specific
    # failure mode).
    Set-Content -LiteralPath (Join-Path $Work 'id-newline.json') -Value '{"capabilities": [{"id": "x\ntriggers=NONE", "eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013p' (Join-Path $Work 'id-newline.json')

    Write-Host "=== TEST-013q: shape-invalid -- id is an explicit empty string (no degenerate 'ineligible:' token) ==="
    Set-Content -LiteralPath (Join-Path $Work 'id-empty.json') -Value '{"capabilities": [{"id": "", "eligible": false, "upgrade_reasons": []}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013q' (Join-Path $Work 'id-empty.json')

    Write-Host '=== TEST-013r: a bare 2-positional-argument invocation (no -CapabilityReasons flag) is NOT treated as supplied ==='
    Set-Content -LiteralPath (Join-Path $Work 'would-be-merged.json') -Value '{"capabilities": [{"id": "would-be-merged", "eligible": false}]}' -NoNewline
    $rOutput = & $PowerShell -NoProfile -File $Sut (Join-Path $Work 'clean.txt') (Join-Path $Work 'would-be-merged.json') 2>&1
    $rExit = $LASTEXITCODE
    $rJoined = ($rOutput -join "`n")
    if ($rExit -ne 0 -and $rExit -ne 10) {
        Ok "TEST-013r: 2-positional-arg call is rejected (exit $rExit), never silently merges the second path as a capability fragment (exit 10 would mean the fragment was accepted)"
    } else {
        Bad "TEST-013r: expected a non-zero, non-10 rejection, got exit $rExit. Output: $rJoined"
    }

    # ---------------------------------------------------------------
    # TEST-013s-u: cross-model panel, T-002 OpenAI slot -- "the supplied
    # negative tests cover only missing keys and a non-array top-level
    # capabilities value. They do not demonstrate fail-closed handling for
    # empty/non-string ids, non-boolean eligible values, non-array
    # upgrade_reasons, or non-string reason elements."
    #
    # Empty id (013q), non-boolean eligible (013j/k/l) and non-array
    # upgrade_reasons (013i) were closed in an earlier round -- the panel
    # reviewed a bundle that predates them. The two the slot names that
    # genuinely had no assertion are a NON-STRING id and a non-string
    # element inside upgrade_reasons. Both are added here.
    # ---------------------------------------------------------------
    Write-Host '=== TEST-013s: shape-invalid -- id is a NUMBER, not a non-empty string ==='
    Set-Content -LiteralPath (Join-Path $Work 'id-number.json') -Value '{"capabilities": [{"id": 7, "eligible": false, "upgrade_reasons": ["x"]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013s' (Join-Path $Work 'id-number.json')

    Write-Host '=== TEST-013t: shape-invalid -- id is an object, not a non-empty string ==='
    Set-Content -LiteralPath (Join-Path $Work 'id-object.json') -Value '{"capabilities": [{"id": {"nested": "x"}, "eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013t' (Join-Path $Work 'id-object.json')

    Write-Host '=== TEST-013u: shape-invalid -- id is an array, not a non-empty string ==='
    Set-Content -LiteralPath (Join-Path $Work 'id-array.json') -Value '{"capabilities": [{"id": ["x"], "eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013u' (Join-Path $Work 'id-array.json')

    # ---------------------------------------------------------------
    # TEST-013v-af: upgrade_reasons ELEMENT validation (cross-model
    # panel, T-002 OpenAI slot: "non-string reason elements", plus the
    # sibling sweep that finding prompted). See the sh twin's own block
    # for the full reasoning; the short form is that the container was
    # type-checked and its elements were not, then coerced with
    # [string]/str(), which (a) let a reason token forge fields in the
    # same single-line output record the id grammar exists to protect,
    # and (b) left the two runtimes silently disagreeing on null,
    # object and nested-array elements.
    #
    # TEST-013z is the divergence case specifically: @() flattens one
    # level in PowerShell, so [["x"]] used to arrive as the bare string
    # "x" here and pass, while sh emitted "['x']".
    # ---------------------------------------------------------------
    Write-Host '=== TEST-013v: upgrade_reasons element is a number, not a string ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-number.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [5]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013v' (Join-Path $Work 'reason-number.json')

    Write-Host '=== TEST-013w: upgrade_reasons element is a boolean, not a string ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-bool.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [true]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013w' (Join-Path $Work 'reason-bool.json')

    Write-Host '=== TEST-013x: upgrade_reasons element is null (runtimes previously disagreed) ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-null.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [null]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013x' (Join-Path $Work 'reason-null.json')

    Write-Host '=== TEST-013y: upgrade_reasons element is an object (runtimes previously disagreed) ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-object.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [{"k": "v"}]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013y' (Join-Path $Work 'reason-object.json')

    Write-Host '=== TEST-013z: upgrade_reasons element is a nested array (ps1 flattened it, sh did not) ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-nested.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [["x"]]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013z' (Join-Path $Work 'reason-nested.json')

    Write-Host '=== TEST-013aa: upgrade_reasons element is the empty string (AC-001: non-empty strings) ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-empty.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [""]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013aa' (Join-Path $Work 'reason-empty.json')

    Write-Host "=== TEST-013ab: upgrade_reasons element carries ',' (cannot forge a second trigger entry) ==="
    Set-Content -LiteralPath (Join-Path $Work 'reason-comma.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["evil,forged"]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013ab' (Join-Path $Work 'reason-comma.json')

    Write-Host "=== TEST-013ac: upgrade_reasons element carries ';' (cannot forge a second output field) ==="
    Set-Content -LiteralPath (Join-Path $Work 'reason-semicolon.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["x; triggers=NONE"]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013ac' (Join-Path $Work 'reason-semicolon.json')

    Write-Host '=== TEST-013ad: upgrade_reasons element carries an embedded newline (single-line contract) ==='
    # PowerShell single-quoted strings are raw literals, so `\n` here is the
    # two literal characters backslash-n -- a valid JSON \n escape decoding
    # to a real newline inside the parsed token (see TEST-013p's own note).
    Set-Content -LiteralPath (Join-Path $Work 'reason-newline.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["x\ntriggers=NONE"]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013ad' (Join-Path $Work 'reason-newline.json')

    Write-Host '=== TEST-013ae: upgrade_reasons element is uppercase (lowercase grammar, like the id grammar) ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-upper.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["Financial_Settlement"]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013ae' (Join-Path $Work 'reason-upper.json')

    # Positive control -- all ten negatives above would still pass if the
    # grammar were tightened to reject everything, certifying a checker that
    # never emits a Capability-derived trigger at all (AC-027's forbidden
    # silent degrade). Also pins the tokens reaching the output VERBATIM,
    # which is what proves the [string] cast is gone rather than bypassed.
    Write-Host '=== TEST-013af: a legitimate snake_case + hyphenated reason pair still Blocks with its own tokens ==='
    Set-Content -LiteralPath (Join-Path $Work 'reason-valid.json') -Value '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["financial_settlement", "should-not-appear"]}]}' -NoNewline
    $afOutput = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') -CapabilityReasons (Join-Path $Work 'reason-valid.json') 2>&1
    $afExit = $LASTEXITCODE
    $afJoined = ($afOutput -join "`n")
    if ($afExit -eq 10 -and $afJoined -eq 'full-required: financial_settlement; triggers=financial_settlement,should-not-appear') {
        Ok 'TEST-013af: valid snake_case and hyphenated tokens pass the grammar and reach the output verbatim, uncoerced'
    } else {
        Bad "TEST-013af: expected exit 10 and the exact two-token record, got exit $afExit. Output: $afJoined"
    }

    # TEST-013ag/ah pin amended design.md 2b (2026-08-28, RT-20260828-001):
    # upgrade_reasons shape/grammar is validated for EVERY entry, before
    # eligibility is consulted. The assertion must be exit 2; asserting the
    # absence of forged tokens would be vacuous (an eligible:true entry
    # emits nothing even while defective). Twin of the sh suite's ag-aj.
    Write-Host '=== TEST-013ag: eligible:true entry with a truthy non-array upgrade_reasons (amended 2b) ==='
    Set-Content -LiteralPath (Join-Path $Work 'true-scalar.json') -Value '{"capabilities": [{"id": "a", "eligible": true, "upgrade_reasons": "risk"}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013ag' (Join-Path $Work 'true-scalar.json')

    Write-Host '=== TEST-013ah: eligible:true entry with a delimiter-carrying upgrade_reasons element (amended 2b) ==='
    Set-Content -LiteralPath (Join-Path $Work 'true-malformed-element.json') -Value '{"capabilities": [{"id": "a", "eligible": true, "upgrade_reasons": ["evil,forged"]}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013ah' (Join-Path $Work 'true-malformed-element.json')

    Write-Host '=== TEST-013ai: eligible:false with present-but-falsy upgrade_reasons is absent, yielding the synthetic token ==='
    Set-Content -LiteralPath (Join-Path $Work 'false-falsy.json') -Value '{"capabilities": [{"id": "x", "eligible": false, "upgrade_reasons": false}]}' -NoNewline
    $aiOutput = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') -CapabilityReasons (Join-Path $Work 'false-falsy.json') 2>&1
    $aiExit = $LASTEXITCODE
    $aiJoined = ($aiOutput -join "`n")
    if ($aiExit -eq 10 -and $aiJoined -eq 'full-required: ineligible:x; triggers=ineligible:x') {
        Ok 'TEST-013ai: present-but-falsy upgrade_reasons on eligible:false is treated as absent (synthetic token, exit 10)'
    } else {
        Bad "TEST-013ai: expected exit 10 with the synthetic ineligible:x record, got exit $aiExit. Output: $aiJoined"
    }

    Write-Host '=== TEST-013aj: eligible:true with present-but-falsy upgrade_reasons contributes nothing ==='
    Set-Content -LiteralPath (Join-Path $Work 'true-falsy.json') -Value '{"capabilities": [{"id": "a", "eligible": true, "upgrade_reasons": 0}]}' -NoNewline
    $ajOutput = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') -CapabilityReasons (Join-Path $Work 'true-falsy.json') 2>&1
    $ajExit = $LASTEXITCODE
    $ajJoined = ($ajOutput -join "`n")
    if ($ajExit -eq 0 -and $ajJoined -eq 'lite-eligible') {
        Ok 'TEST-013aj: present-but-falsy upgrade_reasons on eligible:true is treated as absent, contributing nothing (exit 0)'
    } else {
        Bad "TEST-013aj: expected exit 0 lite-eligible, got exit $ajExit. Output: $ajJoined"
    }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
