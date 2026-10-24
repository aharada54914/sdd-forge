# macOS Bash launch correction

Native CI40087047427 at source7dffd37b/tested merge76b51ef2 completed all731 PowerShell cases on macOS26.6.2 with PowerShell7.6.6/.NET10.0.12/Arm64, then failed before Bash recovery cases at shell line5 (`@: unbound variable`). The PowerShell cache-isolation correction succeeded in that actual step; the later shell launch failure is separate.

The only harness change guards positional expansion with `${1+"$@"}` under nounset. It expands nothing when no first argument exists and preserves an explicitly empty first argument and exact quoting otherwise. All embedded Python bytes remain identical (SHA2565b4373e9925fc865514db4d3204370e6eff93ed3cb16831a0ff567337370788f), so all731 cases, assertions, concurrency and PowerShell execution behavior are unchanged. Product prechecks and the PowerShell wrapper are unchanged.

Local current-Linux-Bash checks cover no arguments, empty/spaced/literal arguments and exact child exit7 propagation. They are not a local Bash3 reproduction. The old native failure is preserved; corrected native macOS Bash and final-head aggregate CI remain pending. No redundant PowerShell suite was run locally. Independent bounded review accepted the launch correction.

The previous current-binding artifact remains in public commit7dffd37b, SHA2568c42e34049700649104e5e3c7f82433fad868e1e732b7ce470ffa0307e59073a. This additive correction binds the new harness and these records without rewriting historical manifests, reports or results. T001 remains In Progress; the approved v2 criterion amendment still awaits genuine task-stage rebinding, and the restored old all-cases Red→Green criterion is not deemed satisfied. No Done, model adoption, actual recovery or A9 activation is claimed.
