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
# Liveness probe: a CLI is only reported available if it answers `--version`
# successfully (binary presence alone is not proof it can actually run --
# e.g. a CLI with no valid auth still resolves via `command -v`). For
# codex, a `codex` that resolves to the `codex-sync` wrapper (git sync +
# banner side effects, not the panelist CLI) is never reported available
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
# `--version` is a cheap liveness probe (never invokes a model); a codex
# that only resolves to the codex-sync wrapper is treated as unavailable.
_dp_codex="$(command -v codex 2>/dev/null || true)"
if [ -n "$_dp_codex" ]; then
    _dp_codex_real="$_dp_codex"
    if command -v readlink >/dev/null 2>&1; then
        _dp_codex_real="$(readlink -f "$_dp_codex" 2>/dev/null || printf '%s' "$_dp_codex")"
    fi
    case "$_dp_codex_real" in
        *codex-sync*) _dp_codex="" ;;
    esac
fi
if [ -n "$_dp_codex" ] && "$_dp_codex" --version >/dev/null 2>&1; then
    found="${found}gpt
"
elif command -v openai >/dev/null 2>&1 && openai --version >/dev/null 2>&1; then
    found="${found}gpt
"
fi

# ── Detect: Gemini panelist via gemini CLI ──────────────────────────────────
# `--version` is a cheap liveness probe (never invokes a model).
if command -v gemini >/dev/null 2>&1 && gemini --version >/dev/null 2>&1; then
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
