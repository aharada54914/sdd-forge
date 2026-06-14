# Collection layer: run Google Gemini panelist via gemini CLI in isolated scratch.
# Usage:
#   run-panelist-gemini.ps1 --task T-NNN --feature <f> --input <bundle-path>
#                           [--spec-root <dir>] [--model <model-id>]
#                           [--digest <64-hex>] [--consent <kind>]
#
# Writes verdict JSON to:
#   specs/<feature>/verification/T-NNN.panelist-google.verdict.json
#
# Graceful degrade: gemini CLI absent -> exit 1 (not exit 2; not a tool error).
# Key isolation: SDD_EVIDENCE_KEY / SDD_SUDO_KEY never passed to panelist.
#
# Exit codes: 0=success  1=CLI absent or panelist failure  2=bad args
param()
$ErrorActionPreference = "Stop"

$TaskId      = ""
$Feature     = ""
$InputPath   = ""
$SpecRoot    = "specs"
$Model       = "gemini-2.0-flash"
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
        "--digest"    { $InputDigest = $passedArgs[$argIdx+1]; $argIdx += 2 }
        "--consent"   { $ConsentKind = $passedArgs[$argIdx+1]; $argIdx += 2 }
        default {
            [Console]::Error.WriteLine("run-panelist-gemini: unknown argument: $($passedArgs[$argIdx])")
            exit 2
        }
    }
}

if (-not $TaskId)    { [Console]::Error.WriteLine("run-panelist-gemini: --task is required");    exit 2 }
if (-not $Feature)   { [Console]::Error.WriteLine("run-panelist-gemini: --feature is required"); exit 2 }
if (-not $InputPath) { [Console]::Error.WriteLine("run-panelist-gemini: --input is required");   exit 2 }
if (-not (Test-Path $InputPath)) {
    [Console]::Error.WriteLine("run-panelist-gemini: input file not found: $InputPath"); exit 1
}

# ── Check CLI availability ───────────────────────────────────────────────────
if (-not (Get-Command "gemini" -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("run-panelist-gemini: gemini CLI not found in PATH — skipping Gemini panelist (graceful degrade)")
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
    $outPath = Join-Path $outDir "$TaskId.panelist-google.verdict.json"

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
  "vendor": "google",
  "model": "<model>",
  "verdict": "PASS" or "NEEDS_WORK",
  "findings": [],
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
- Do not include any text outside the JSON object.
'@

    $bundleContent = Get-Content -Raw -Encoding Utf8 $InputPath
    $combined = $promptText + "`n`n## Sanitized Input Bundle`n`n" + $bundleContent
    $combinedFile = Join-Path $scratch "combined.txt"
    Set-Content -Encoding Utf8 -Path $combinedFile -Value $combined

    [Console]::Error.WriteLine("run-panelist-gemini: invoking gemini --model $Model (task=$TaskId feature=$Feature)")

    $rawOutput = Join-Path $scratch "raw-output.txt"
    try {
        $proc = Start-Process -FilePath "gemini" `
            -ArgumentList "--model", $Model `
            -RedirectStandardInput  $combinedFile `
            -RedirectStandardOutput $rawOutput `
            -RedirectStandardError  (Join-Path $scratch "stderr.txt") `
            -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            [Console]::Error.WriteLine("run-panelist-gemini: gemini CLI exited $($proc.ExitCode)")
            Get-Content (Join-Path $scratch "stderr.txt") | ForEach-Object { [Console]::Error.WriteLine($_) }
            exit 1
        }
    } catch {
        [Console]::Error.WriteLine("run-panelist-gemini: failed to start gemini: $_")
        exit 1
    }

    $raw = Get-Content -Raw -Encoding Utf8 $rawOutput
    $jsonMatch = [regex]::Match($raw, '\{[\s\S]*\}')
    if (-not $jsonMatch.Success) {
        [Console]::Error.WriteLine("run-panelist-gemini: no JSON object found in gemini output")
        exit 1
    }

    try {
        $verdict = $jsonMatch.Value | ConvertFrom-Json
    } catch {
        [Console]::Error.WriteLine("run-panelist-gemini: invalid JSON from gemini: $_")
        exit 1
    }

    if ($verdict.schema -ne "cross-model-verdict/v1") {
        [Console]::Error.WriteLine("run-panelist-gemini: wrong schema: $($verdict.schema)"); exit 1
    }
    if ($verdict.blind -ne $true) {
        [Console]::Error.WriteLine("run-panelist-gemini: blind must be true"); exit 1
    }
    if ($verdict.input_digest -notmatch '^[0-9a-f]{64}$') {
        [Console]::Error.WriteLine("run-panelist-gemini: input_digest must be 64 lowercase hex"); exit 1
    }
    if ($verdict.verdict -notin @("PASS","NEEDS_WORK")) {
        [Console]::Error.WriteLine("run-panelist-gemini: verdict must be PASS or NEEDS_WORK"); exit 1
    }

    $verdict.task_id = $TaskId
    $verdict.feature = $Feature
    $verdict.vendor  = "google"

    $verdict | ConvertTo-Json -Depth 10 | Set-Content -Encoding Utf8 -Path $outPath
    [Console]::Error.WriteLine("run-panelist-gemini: verdict written to $outPath")
    Write-Host $outPath

} finally {
    Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
}

exit 0
