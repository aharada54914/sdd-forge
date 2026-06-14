# Collection layer: detect available non-Anthropic panelist CLIs.
# Usage: detect-panel.ps1 [-Quiet]
#
# Outputs a newline-separated list of available panelist slugs to stdout:
#   gpt      (requires: codex CLI — used to run OpenAI GPT panelist)
#   gemini   (requires: gemini CLI — used to run Google Gemini panelist)
#
# If no non-Anthropic panelists are available, writes a warning to stderr
# and exits 1 (caller must handle graceful degrade; collection layer is
# never invoked by CI so non-zero here is informational, not a gate failure).
#
# Graceful degrade (fusion-fable detect_panel pattern):
#   - Missing CLI → slug omitted from output; no crash.
#   - Zero non-Anthropic slugs → exit 1 with warning (gate will fail if
#     run without supplementing with manual verdicts).
#   - Always exits cleanly (no unhandled errors).
#
# Exit codes:
#   0 = at least one non-Anthropic panelist found
#   1 = no non-Anthropic panelists found (graceful degrade)
#   2 = tool/invocation error
param(
    [switch]$Quiet
)
$ErrorActionPreference = "Stop"

$found = [System.Collections.Generic.List[string]]::new()

# ── Detect: GPT panelist via codex CLI ─────────────────────────────────────
# The codex CLI is the standard way to invoke OpenAI models locally via Codex.
# Check for both `codex` and `openai` (fallback alias).
$hasCodex = $null -ne (Get-Command "codex" -ErrorAction SilentlyContinue)
$hasOpenai = $null -ne (Get-Command "openai" -ErrorAction SilentlyContinue)
if ($hasCodex -or $hasOpenai) {
    $found.Add("gpt")
}

# ── Detect: Gemini panelist via gemini CLI ──────────────────────────────────
$hasGemini = $null -ne (Get-Command "gemini" -ErrorAction SilentlyContinue)
if ($hasGemini) {
    $found.Add("gemini")
}

# ── Emit results ─────────────────────────────────────────────────────────────
if ($found.Count -gt 0) {
    foreach ($slug in $found) {
        Write-Host $slug
    }
    exit 0
} else {
    if (-not $Quiet) {
        [Console]::Error.WriteLine("detect-panel: WARNING: no non-Anthropic panelist CLIs found (codex/gemini not in PATH).")
        [Console]::Error.WriteLine("detect-panel: The cross-model gate requires >= 1 non-Anthropic vendor verdict.")
        [Console]::Error.WriteLine("detect-panel: Install codex or gemini CLI, or provide manual verdict JSONs.")
    }
    exit 1
}
