# Scoped native comparison and held-out controls

The same checker (`86fc4955`), configuration and pinned native tools scanned the
entire independently enumerated baseline (`555bfb5f`) and integration (`e72813ab`)
populations on Linux. Baseline: 11,353 tracked files, 853 inspected native inputs,
285 findings. Integration: 11,545 tracked files, 873 inspected native inputs,
zero findings. Each excludes one exact-content syntax-error fixture. The baseline
received only untracked checker configuration/adapters/dependencies; no product
source was changed. These counts cover the selected native rule subsets, not all
coding standards or all embedded fragments.

`native-comparison.json` records versions/counts and `native-evidence.zip` contains
complete source-bound scan JSON, catalog log and receipt. The integration scan ran
through the existing `coding-standards` catalog profile: 12 checker tests passed,
then the whole native scan passed in 64.98 seconds. The receipt is non-reusable;
`clean_after: false` records untracked report preparation during this run. The
scan verifies selected source hashes before completion. Baseline duration and
token consumption were not instrumented and are unknown; no speed/cost claim follows.

`heldout.py` fixes nine additional case sources and expected diagnostic sets after
the checker was frozen. It uses actual Ruff, ShellCheck, PowerShell/PSScriptAnalyzer
and TypeScript, isolated from the development fixtures. All nine passed once with
zero observed false positives or false negatives within this small sample; see
`heldout.json`. They were not used to modify the checker. This is a deterministic
native-tool evaluation, not a blinded model experiment or an independent reviewer.

Contextual review remains unknown for the full population. No native
Claude/Codex/Copilot invocation, macOS/Windows execution, project instruction
adoption or all-rule compliance is established by this evidence. Root integration
owns later source changes, final census, mirrors and three-OS CI evidence. Neither
#692 nor #685 can be closed on the strength of these native checks alone.
