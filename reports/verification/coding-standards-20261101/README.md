# Scoped native comparison and held-out controls

Current task comparison: baseline `82b53695` versus integration `7d53b1bf` used identical checker SHA256 `29cb08b6e8285d20e8fe9abb8916c6a4df17f1a1bf7c260f2ba51d385afbeef5` and native tools on Linux. Baseline: 11,501 tracked files, 856 inspected inputs, 285 findings in 70.06s. Final: 11,797 tracked files, 884 inspected inputs, 0 findings in 70.25s. Each excludes one exact-content invalid-source fixture. `task-native-evidence.zip` retains both complete scans and timings plus the prior `bd94f864` completed scan; `native-comparison.json` records the current comparison and the separate historical comparison below.

The prior `bd94f864` native zero was followed by a macOS CI failure: an alias of the same physical root was mistaken for a directory cycle. That scan is retained as historical evidence and superseded by the current result after the helper repair.

The earlier final attempt aborted after65.96s with exit2 because a selected source changed mid-scan; it remains an error record, never a PASS. A native zero covers only configured rules and selected inputs. Whole-context review, embedded-fragment coverage and the final census are separate audit evidence. Model token cost was not measured; one native run per revision does not establish a speed/cost improvement.

The following `555bfb5f` comparison is historical and is not the baseline for this task.

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

Follow-up: [two bounded Codex probes](guidance-eval/README.md) exercised actual
conditional guidance reads. The source case read all common rules; broad model
adherence is still not established. [Linux child-timeout observation](timeout-child.json)
found an exited zombie, not a running descendant; other OS transports remain untested.
