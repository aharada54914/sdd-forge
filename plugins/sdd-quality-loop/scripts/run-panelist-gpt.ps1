# Collection layer: run OpenAI GPT panelist via codex CLI in isolated scratch.
# Usage:
#   run-panelist-gpt.ps1 --task T-NNN --feature <f> --input <bundle-path>
#                        [--spec-root <dir>] [--model <model-id>]
#                        [--effort <low|medium|high|xhigh>]
#                        [--digest <64-hex>] [--consent <kind>]
#
# Writes verdict JSON to:
#   specs/<feature>/verification/T-NNN.panelist-openai.verdict.json
#
# Graceful degrade: codex CLI absent -> exit 1 (not exit 2; not a tool error).
# Scratch dir always cleaned up via try/finally.
# Key isolation: SDD_EVIDENCE_KEY / SDD_SUDO_KEY never passed to panelist.
#
# --effort (epic-159-pillar-c T-006, REQ-006/AC-035): optional, forwarded
# verbatim to the codex invocation alongside --model. Omitted entirely
# preserves today's exact invocation (design.md API/Contract Plan; Breaking
# API: no).
#
# Injection rejection (REQ-006 AC-052; security-spec.md B3): --model and
# --effort are validated BEFORE the codex ArgumentList is assembled. Values
# containing whitespace, a leading "-"/"--" (flag-injection shape), or a
# ";" (command-separator shape) are rejected fail-closed; --effort is
# additionally rejected when it is not one of the ordinal-checked
# {low, medium, high, xhigh} values (mirrors emit-run-record.ps1's
# established 2-layer PowerShell case-sensitivity discipline: an ordinal
# HashSet entry gate here, since there is no branch-dispatch layer 2 to
# pair it with in this script).
#
# Exit codes: 0=success  1=CLI absent or panelist failure  2=bad args/rejected value
param()
$ErrorActionPreference = "Stop"

$TaskId      = ""
$Feature     = ""
$InputPath   = ""
$SpecRoot    = "specs"
$Model       = "gpt-4o"
$Effort      = ""
$InputDigest = ""
$ConsentKind = "human-flag"

$argIdx = 0
$passedArgs = $args
while ($argIdx -lt $passedArgs.Count) {
    switch ($passedArgs[$argIdx]) {
        "--task"      { $TaskId      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--feature"   { $Feature     = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--input"     { $InputPath   = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--spec-root" { $SpecRoot    = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--model"     { $Model       = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--effort"    { $Effort      = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--digest"    { $InputDigest = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--consent"   { $ConsentKind = $passedArgs[$argIdx+1]; $argIdx += 2 }
        default {
            [Console]::Error.WriteLine("run-panelist-gpt: unknown argument: $($passedArgs[$argIdx])")
            exit 2
        }
    }
}

# ── Reject argv-injection-shaped --model/--effort values (AC-052) ───────────
# Runs BEFORE any other validation or the codex ArgumentList is assembled,
# so a rejected value never reaches the codex command line.
$validEfforts = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("low", "medium", "high", "xhigh"),
    [System.StringComparer]::Ordinal)

function Assert-NotInjectionShaped([string]$FlagName, [string]$Value) {
    if ($Value -cmatch '\s') {
        [Console]::Error.WriteLine("run-panelist-gpt: $FlagName contains whitespace (rejected, argv-injection shape): $Value")
        exit 2
    }
    if ($Value.StartsWith('-', [StringComparison]::Ordinal)) {
        [Console]::Error.WriteLine("run-panelist-gpt: $FlagName has a leading ""-"" (rejected, flag-injection shape): $Value")
        exit 2
    }
    if ($Value.Contains(';', [StringComparison]::Ordinal)) {
        [Console]::Error.WriteLine("run-panelist-gpt: $FlagName contains "";"" (rejected, command-separator shape): $Value")
        exit 2
    }
}

if ($Model) { Assert-NotInjectionShaped "--model" $Model }
if ($Effort) {
    Assert-NotInjectionShaped "--effort" $Effort
    if (-not $validEfforts.Contains($Effort)) {
        [Console]::Error.WriteLine("run-panelist-gpt: --effort must be one of low|medium|high|xhigh (got: $Effort)")
        exit 2
    }
}

if (-not $TaskId)    { [Console]::Error.WriteLine("run-panelist-gpt: --task is required");    exit 2 }
if (-not $Feature)   { [Console]::Error.WriteLine("run-panelist-gpt: --feature is required"); exit 2 }
if (-not $InputPath) { [Console]::Error.WriteLine("run-panelist-gpt: --input is required");   exit 2 }
if (-not (Test-Path $InputPath)) {
    [Console]::Error.WriteLine("run-panelist-gpt: input file not found: $InputPath"); exit 1
}

# ── Check CLI availability ───────────────────────────────────────────────────
$CodexCmd = $null
if (Get-Command "codex"  -ErrorAction SilentlyContinue) { $CodexCmd = "codex" }
elseif (Get-Command "openai" -ErrorAction SilentlyContinue) { $CodexCmd = "openai" }

if (-not $CodexCmd) {
    [Console]::Error.WriteLine("run-panelist-gpt: codex CLI not found in PATH — skipping GPT panelist (graceful degrade)")
    exit 1
}

# ── Key isolation ────────────────────────────────────────────────────────────
$env:SDD_EVIDENCE_KEY  = $null
$env:SDD_SUDO_KEY      = $null
$env:SDD_SUDO_KEY_FILE = $null

$scratch = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
New-Item -ItemType Directory -Path $scratch -Force | Out-Null

try {
    $outDir  = Join-Path $SpecRoot (Join-Path $Feature "verification")
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $outPath = Join-Path $outDir "$TaskId.panelist-openai.verdict.json"

    $promptText = @'
You are an independent panelist reviewing a software implementation. You are
running BLIND: you have not seen any other panelist's verdict, the primary
evaluator's verdict, or any prior review feedback on this task.

Your role is READ-ONLY. You must not suggest, write, or edit code. You must
not approve or set any task status. Return a structured verdict JSON only.

## Input

The sanitized input bundle follows this message. Review it for correctness,
completeness, and adherence to the stated requirements and design.

## Output Format

Return ONLY a JSON object in this exact schema (no markdown, no prose):

{
  "schema": "cross-model-verdict/v1",
  "task_id": "<task_id>",
  "feature": "<feature>",
  "vendor": "openai",
  "model": "<model>",
  "verdict": "PASS" or "NEEDS_WORK",
  "findings": [
    { "severity": "Critical" or "Major" or "Minor", "ref": "<file:line or section>", "note": "<description>" }
  ],
  "blind": true,
  "input_digest": "<digest-from-bundle-header>",
  "consent": { "kind": "<consent-kind>", "ref": "<ref>" }
}

Rules:
- verdict MUST be "PASS" or "NEEDS_WORK".
- findings MUST be an array (empty [] if none).
- blind MUST be true (boolean, not string).
- input_digest: copy the value from the "# input_digest:" comment in the bundle header.
- consent.kind: copy from the "# consent:" comment in the bundle header.
- consent.ref: the tasks.md flag or SDD_SUDO reference from the bundle.
- Do not include any text outside the JSON object.
'@

    $bundleContent = Get-Content -Raw -Encoding Utf8 $InputPath
    $combined = $promptText + "`n`n## Sanitized Input Bundle`n`n" + $bundleContent
    $combinedFile = Join-Path $scratch "combined.txt"
    Set-Content -Encoding Utf8 -Path $combinedFile -Value $combined

    # Codex ArgumentList: --model, [--effort <e>] (only when supplied,
    # AC-035), --no-project-doc -- omitted entirely preserves today's exact
    # invocation order/shape (Breaking API: no).
    $codexArgs = @("--model", $Model)
    if ($Effort) { $codexArgs += @("--effort", $Effort) }
    $codexArgs += @("--no-project-doc")

    if ($Effort) {
        [Console]::Error.WriteLine("run-panelist-gpt: invoking $CodexCmd --model $Model --effort $Effort (task=$TaskId feature=$Feature)")
    } else {
        [Console]::Error.WriteLine("run-panelist-gpt: invoking $CodexCmd --model $Model (task=$TaskId feature=$Feature)")
    }

    $rawOutput = Join-Path $scratch "raw-output.txt"
    try {
        $proc = Start-Process -FilePath $CodexCmd `
            -ArgumentList $codexArgs `
            -RedirectStandardInput  $combinedFile `
            -RedirectStandardOutput $rawOutput `
            -RedirectStandardError  (Join-Path $scratch "stderr.txt") `
            -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            [Console]::Error.WriteLine("run-panelist-gpt: codex CLI exited $($proc.ExitCode)")
            Get-Content (Join-Path $scratch "stderr.txt") | ForEach-Object { [Console]::Error.WriteLine($_) }
            exit 1
        }
    } catch {
        [Console]::Error.WriteLine("run-panelist-gpt: failed to start codex: $_")
        exit 1
    }

    # ── Extract and validate JSON ─────────────────────────────────────────────
    $raw = Get-Content -Raw -Encoding Utf8 $rawOutput
    $jsonMatch = [regex]::Match($raw, '\{[\s\S]*\}')
    if (-not $jsonMatch.Success) {
        [Console]::Error.WriteLine("run-panelist-gpt: no JSON object found in codex output")
        [Console]::Error.WriteLine("raw: $($raw.Substring(0, [Math]::Min(500, $raw.Length)))")
        exit 1
    }

    try {
        $verdict = $jsonMatch.Value | ConvertFrom-Json
    } catch {
        [Console]::Error.WriteLine("run-panelist-gpt: invalid JSON from codex: $_")
        exit 1
    }

    # Minimal validation
    if ($verdict.schema -ne "cross-model-verdict/v1") {
        [Console]::Error.WriteLine("run-panelist-gpt: wrong schema: $($verdict.schema)"); exit 1
    }
    if ($verdict.blind -ne $true) {
        [Console]::Error.WriteLine("run-panelist-gpt: blind must be true"); exit 1
    }
    if ($verdict.input_digest -notmatch '^[0-9a-f]{64}$') {
        [Console]::Error.WriteLine("run-panelist-gpt: input_digest must be 64 lowercase hex"); exit 1
    }
    if ($verdict.verdict -notin @("PASS","NEEDS_WORK")) {
        [Console]::Error.WriteLine("run-panelist-gpt: verdict must be PASS or NEEDS_WORK"); exit 1
    }

    # Normalize fields
    $verdict.task_id = $TaskId
    $verdict.feature = $Feature
    $verdict.vendor  = "openai"

    $verdict | ConvertTo-Json -Depth 10 | Set-Content -Encoding Utf8 -Path $outPath
    [Console]::Error.WriteLine("run-panelist-gpt: verdict written to $outPath")
    Write-Host $outPath

} finally {
    Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
}

exit 0
