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
# Liveness probe: a CLI is only reported available if it answers `--version`
# successfully (binary presence alone is not proof it can actually run).
# For codex, a `codex` that resolves to the `codex-sync` wrapper (git sync
# + banner side effects, not the panelist CLI) is never reported available
# either, even if `codex-sync --version` would happen to succeed.
#
# Graceful degrade (fusion-fable detect_panel pattern):
#   - Missing CLI → slug omitted from output; no crash.
#   - CLI present but `--version` fails, or codex resolves to codex-sync →
#     slug omitted (same as missing; this is the false-positive class this
#     script must not report).
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
# Check for both `codex` and `openai` (fallback alias). `--version` is a
# cheap liveness probe (never invokes a model); a codex that only resolves
# to the codex-sync wrapper is treated as unavailable.
function Test-CliVersion([string]$Exe) {
    try {
        & $Exe --version *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

$codexCmd = Get-Command "codex" -ErrorAction SilentlyContinue
$codexUsable = $false
if ($codexCmd) {
    $target = $codexCmd.Source
    if ($codexCmd.CommandType -eq "Alias" -and $codexCmd.Definition) { $target = $codexCmd.Definition }
    try {
        $item = Get-Item -LiteralPath $codexCmd.Source -ErrorAction Stop
        if ($item.LinkType -and $item.Target) { $target = "$target;$($item.Target -join ';')" }
    } catch { }
    if ($target -notlike "*codex-sync*") {
        $codexUsable = Test-CliVersion $codexCmd.Source
    }
}
$openaiCmd = Get-Command "openai" -ErrorAction SilentlyContinue
$openaiUsable = $false
if ($openaiCmd) { $openaiUsable = Test-CliVersion $openaiCmd.Source }
if ($codexUsable -or $openaiUsable) {
    $found.Add("gpt")
}

# ── Detect: Gemini panelist via gemini CLI ──────────────────────────────────
# `--version` is a cheap liveness probe (never invokes a model).
$geminiCmd = Get-Command "gemini" -ErrorAction SilentlyContinue
if ($geminiCmd -and (Test-CliVersion $geminiCmd.Source)) {
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
