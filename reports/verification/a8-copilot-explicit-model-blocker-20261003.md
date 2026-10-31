# A8 native Copilot `apply_patch` diagnostic — explicit-model blocker (2026-10-03)

Checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`, detached HEAD `8fdfdb6ff84c4d0a4d4fc1ffb065e318cf5132d4`.

The installed Copilot CLI reports version 1.0.91. Its `help commands` documents `/model` as the interactive model picker; `help` exposes no non-interactive model-list command. In an `rtk proxy` PTY, both the ordinary CLI and `--screen-reader --no-color` accepted `/model` input but emitted no menu to the captured terminal; each was canceled without a model selection or generation. `gh auth status` exited 0; account details were not recorded. Searching local Copilot logs by filename only for `available.model|models.available|model.catalog|supported.models|model.list` found no candidate file.

An isolated additive project `preToolUse` observer was prepared in `/tmp/a8-copilot-observe.3jZJLK/.github/hooks/`. It records only JSON shape metadata and does not replace or disable the installed protective plugin hook. Four explicit, non-Gemini model attempts each exited 1 before tool or hook execution:

| `--model` | CLI result |
|---|---|
| `gpt-5.4` | `Error: Model "gpt-5.4" from --model flag is not available.` |
| `gpt-6-luna` | `Error: Model "gpt-6-luna" from --model flag is not available.` |
| `claude-sonnet-4.6` | `Error: Model "claude-sonnet-4.6" from --model flag is not available.` |
| `claude-sonnet-4.5` | `Error: Model "claude-sonnet-4.5" from --model flag is not available.` |

No `output.txt` or observer `shape.jsonl` was created. Therefore there is **no live native `apply_patch` stdin-shape observation, guard-denial observation, or live regression proof** from this diagnostic. Auto was not used because it could select Gemini. No guard refusal was bypassed, and no protected repository source or frozen approval artifact was changed.

Minimum unblock: obtain an account-confirmed, explicitly selectable non-Gemini Copilot model ID (for example through a readable `/model` picker). Only then retry the isolated native diagnostic with the protective hook still active. The prior adapter and safety patches remain unapplied candidates, not live proof.
