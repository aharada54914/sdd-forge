# boundary-reference-authorization-parity.tests.ps1 -- WFI-037 twin of the sh
# suite: guidance and the authorization allowlist must not drift apart again.
# Assertion groups mirror the sh leg: A (evidence-tagged verification steps),
# B (allowlist still refuses the ledger), C (both twins emit the chain-fact
# keys), D (nine role docs carry one identical prohibition paragraph).
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Doc = Join-Path $Root "plugins/sdd-review-loop/references/review-context-boundary.md"
$ValidatorSh = Join-Path $Root "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
$ValidatorPs1 = Join-Path $Root "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"

$script:Pass = 0
$script:Fail = 0
function Ok([string]$Message)   { Write-Output "ok: $Message";   $script:Pass++ }
function Nope([string]$Message) { Write-Output "FAIL: $Message"; $script:Fail++ }

foreach ($f in @($Doc, $ValidatorSh, $ValidatorPs1)) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Output "FAIL: missing input $f"; exit 1 }
}

# --- A: evidence-tagged verification steps ---------------------------------
$docText = Get-Content -Raw -LiteralPath $Doc
$blockMatch = [regex]::Match($docText, '(?s)\*\*Verify the record chain.*?^If all four hold', [Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $blockMatch.Success) {
    Nope "A: the record-chain verification block is gone from the boundary reference"
} else {
    $block = $blockMatch.Value
    $steps = ([regex]::Matches($block, '(?m)^[0-9]\.')).Count
    if ($steps -ne 4) { Nope "A: expected 4 numbered verification steps, found $steps" }
    else { Ok "A: the verification procedure has exactly 4 steps" }
    $tags = [regex]::Matches($block, '\(evidence: [^)]*\)')
    if ($tags.Count -ne 4) { Nope "A: expected every step to name its evidence source, found $($tags.Count) tags" }
    else { Ok "A: every step names its evidence source" }
    $badTags = @($tags | Where-Object { $_.Value -notmatch 'caller-quoted line' })
    if ($badTags.Count -ne 0) { Nope "A: a step's evidence source is not the caller-quoted line (+ manifest)" }
    else { Ok "A: no step's evidence requires anything beyond the quoted line and the manifest" }
    if ($block -match '(?i)read the ledger|open the ledger|hash the ledger') {
        Nope "A: the verification block instructs a ledger read again"
    } else { Ok "A: the verification block instructs no ledger read" }
}

# --- B: the allowlist still refuses the ledger -----------------------------
$shText = Get-Content -Raw -LiteralPath $ValidatorSh
$authSh = [regex]::Match($shText, '(?s)^path_is_authorized\(\).*?^\}', [Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $authSh.Success) { Nope "B: path_is_authorized() not found in the sh validator" }
elseif ($authSh.Value -match 'identity-ledger') { Nope "B: the sh allowlist names the identity ledger" }
else { Ok "B: sh path_is_authorized still refuses the identity ledger" }

$ps1Text = Get-Content -Raw -LiteralPath $ValidatorPs1
$authPs1 = [regex]::Match($ps1Text, '(?s)^function Test-AuthorizedPath.*?^\}', [Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $authPs1.Success) { Nope "B: Test-AuthorizedPath not found in the ps1 validator" }
elseif ($authPs1.Value -match 'identity-ledger') { Nope "B: the ps1 allowlist names the identity ledger" }
else { Ok "B: ps1 Test-AuthorizedPath still refuses the identity ledger" }

# --- C: both twins emit the chain-fact keys on the OK line -----------------
foreach ($key in @('sequence=', 'previous_record_sha256=', 'pre_append_tip_sequence=', 'identity_unique=yes')) {
    $shHas = @($shText -split "`n" | Where-Object { $_ -match 'REVIEW_CONTEXT_OK' -and $_.Contains($key) }).Count -gt 0
    $psHas = @($ps1Text -split "`n" | Where-Object { $_ -match 'REVIEW_CONTEXT_OK' -and $_.Contains($key) }).Count -gt 0
    if ($shHas -and $psHas) { Ok "C: both twins emit $key on the OK line" }
    else { Nope "C: OK-line chain fact $key missing (sh=$shHas ps1=$psHas)" }
}

# --- D: nine role docs, one identical prohibition paragraph ----------------
$roleDocs = @(
    "plugins/sdd-review-loop/agents/spec-reviewer-a.md",
    "plugins/sdd-review-loop/agents/spec-reviewer-b.md",
    "plugins/sdd-review-loop/agents/impl-reviewer-a.md",
    "plugins/sdd-review-loop/agents/impl-reviewer-b.md",
    "plugins/sdd-review-loop/agents/task-reviewer-a.md",
    "plugins/sdd-review-loop/agents/task-reviewer-b.md",
    "plugins/sdd-domain/agents/domain-reviewer-a.md",
    "plugins/sdd-domain/agents/domain-reviewer-b.md",
    "plugins/sdd-quality-loop/agents/evaluator.md"
)
$referencePara = $null
foreach ($doc in $roleDocs) {
    $text = Get-Content -Raw -LiteralPath (Join-Path $Root $doc)
    $para = ($text -split "(\r?\n){2,}" | Where-Object { $_ -match 'Never run `validate-review-context-set` against your own manifest' } | Select-Object -First 1)
    if (-not $para) { Nope "D: $doc lacks the self-validation prohibition paragraph"; continue }
    $para = $para -replace "`r`n", "`n"
    if ($null -eq $referencePara) {
        $referencePara = $para
        Ok "D: $doc carries the prohibition paragraph (reference copy)"
    } elseif ($para -ceq $referencePara) {
        Ok "D: $doc matches the reference paragraph byte-for-byte"
    } else {
        Nope "D: $doc's prohibition paragraph differs from the reference copy"
    }
}

Write-Output ""
Write-Output "boundary-reference-authorization-parity.tests.ps1: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
