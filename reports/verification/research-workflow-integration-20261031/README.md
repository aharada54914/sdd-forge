# Research workflow integration repair

Independent review found that the split main candidate omitted the research-enabled
workflow owner changes and eleven related regression cases. Restored the exact
four source files from tested task source b1c82835: Bash/PowerShell owner, bounded
session adapter and conditional-input suite. The audited Bash gate hash remains
8ddf68a6dea4adc4193007db61e4a024d3ea4b7cf50a9e75cc97885757b042be.

The expanded suite passes all 20 tests, including research-only inputs, failed
review repair, status normalization, relocated paths and separately bound ADRs.
The bounded-session suite passes 10 tests with the restored gate. This is local
Linux/POSIX plus Linux PowerShell validation; hosted native platforms require CI.
Earlier split-branch CI did not exercise the omitted cases and is not proof of
this repaired source. No frozen review records or input identities were rewritten.
