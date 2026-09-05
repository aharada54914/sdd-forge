# T-004 Independent Implementation Review

Date: 2026-08-12; remediation re-review 2026-08-14

Role: independent reviewer

Final verdict: APPROVED for the T-004 implementation scope. This is not the
formal `quality-gate` Done verdict.

## Initial findings

1. Major — the Bash canonicalizer sorted corpus artifacts by path while the
   PowerShell twin retained JSON array order. This made the twins disagree on
   whether artifact order was comparison-significant.
2. Major — the initial implementation had not recorded the two-layer WFI-012
   case-sensitivity sweep or its required mis-cased negative fixtures.

## Resolution reviewed

- PowerShell now uses ordinal path sorting, and both twins explicitly prove
  that benign artifact-array reordering stays green. Removing the sort is
  mutation-killed.
- Comparison operators use case-sensitive forms where the Bash source is
  case-sensitive. Regex, `switch`, sorting, and raw string comparisons use
  explicit ordinal/case-sensitive semantics except for the one intentional
  case-insensitive comparison that mirrors `grep -i`.
- Separate operator-layer and language-feature-layer mis-cased negative
  fixtures fail through the real suite path and are mutation-killed.
- Both focused suites pass at 40/0; the final mutation proof reports 116
  killed and 0 survived; the staged CI manifest verifies.

## Quality-gate cycle 1 remediation re-review

- PowerShell now resets, captures, and checks each canonicalizer process exit
  status before comparing canonical output, so two parse failures cannot
  collapse into an empty-string equality.
- The saved pre-fix malformed-corpus run kills the Bash mutation and exposes
  the PowerShell false GREEN as the sole survivor (115/1, exit 1). The restored
  implementation kills that same coherent corpus-and-template mutation in both
  runtimes.
- The mutation classifier removes ANSI control sequences and compacts wrapped
  diagnostics before matching. Independent mutations removing ANSI stripping
  and newline compaction each fail its self-test with exit 2; restoration exits
  0. The complete regenerated run reports 116 killed, 0 survived, exit 0.
- The re-review found no remaining Critical, Major, or Minor issues. It also
  confirmed both focused twins at 40/0, a clean `git diff --check`, and no edits
  to the task plan, live workflow, protected gate tests, or fixture builders.

## Final findings

- Critical: 0
- Major: 0
- Minor: 0
