#!/bin/sh
# Collection layer: detect available non-Anthropic panelist CLIs.
# Usage: detect-panel.sh [--quiet]
#
# Outputs a newline-separated list of available panelist slugs to stdout:
#   gpt      (requires: codex CLI — used to run OpenAI GPT panelist)
#   gemini   (requires: gemini CLI — used to run Google Gemini panelist)
#
# If no non-Anthropic panelists are available, prints a warning to stderr
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

quiet=0
for arg in "$@"; do
    case "$arg" in
        --quiet) quiet=1 ;;
        *) printf 'detect-panel: unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

found=""

# ── Detect: GPT panelist via codex CLI ─────────────────────────────────────
# The codex CLI is the standard way to invoke OpenAI models (GPT-4o, GPT-5.5)
# locally via Codex. Check for both `codex` and `openai` (fallback alias).
if command -v codex >/dev/null 2>&1; then
    found="${found}gpt
"
elif command -v openai >/dev/null 2>&1; then
    found="${found}gpt
"
fi

# ── Detect: Gemini panelist via gemini CLI ──────────────────────────────────
if command -v gemini >/dev/null 2>&1; then
    found="${found}gemini
"
fi

# ── Emit results ─────────────────────────────────────────────────────────────
# Trim trailing newline and print each slug.
if [ -n "$found" ]; then
    printf '%s' "$found"
    exit 0
else
    if [ "$quiet" = "0" ]; then
        printf 'detect-panel: WARNING: no non-Anthropic panelist CLIs found (codex/gemini not in PATH).\n' >&2
        printf 'detect-panel: The cross-model gate requires >= 1 non-Anthropic vendor verdict.\n' >&2
        printf 'detect-panel: Install codex or gemini CLI, or provide manual verdict JSONs.\n' >&2
    fi
    exit 1
fi
