# Refresh note — regenerated against live 111/26 by WFI-030 / WFI-037 (2026-08-20)

`MANIFEST.sha256` cannot carry prose (its parser rejects `#` comment lines with
exit 13), so this note records why six staged bytes in this bundle changed
without any change to this epic's own inventory. Same shape and same reason as
`NOTES-epic-190-a2-refresh.md`; that note is the precedent this one follows.

## What happened

A human applied WFI-037 step (a) and the WFI-037 write-vocabulary change to the
live tree. Both edit the shared, repository-wide guard invariants:

| Array | before | after |
|---|---|---|
| `protected_gate_suffixes` | 80 | 111 |
| `shell.indirect_cmds` | 8 | 20 |
| `phase2_human_copy_targets` | 26 | 26 (unchanged) |

The 31 added suffixes are the enforcement-chain scripts WFI-037 measured as
unprotected — both `check-workflow-state` twins, both
`validate-review-context-set` twins, all three `*-review-precheck.sh`, both
`emit-run-record` twins, and the rest enumerated in
`docs/workflow-improvements/WFI-037.md`. The twelve added `indirect_cmds` are
the writers the shell analyser could not see: `sed`, `patch`, `install`, `ln`,
`truncate`, `dd`, `python`, `python3`, `perl`, `ruby`, `node`, `git`.
`shell.sudo_write_re` was extended in the same edit; it is a scalar inside
`guard-invariants.json` rather than a separate staged file.

## Why the bundle had to move

`TEST-022` in `tests/guard-invariants-epic-a1.tests.sh` requires each of the six
live guard-invariants files to be in exactly one of two states: the pre-apply
baseline digest recorded before T-009, or this bundle's staged candidate. A
third value fails closed, on the reasoning that the live file drifted to bytes
nobody reviewed.

That is the correct default, and it fired exactly as designed: PR #305 moved the
six live files to a third value and `version-gates` plus `test` went red on all
three runners with `live ... is neither the pre-apply baseline nor the staged
candidate`. Refreshing the staged candidate to the reviewed bytes restores the
invariant the test exists to protect — live equals what a human reviewed —
rather than weakening it.

## Structural note for whoever hits this next

This bundle belongs to `epic-189-a1-project-context`, but the six files it
stages are repository-wide. Any later change to the guard invariants, from any
epic or WFI, must refresh this bundle in lockstep or `TEST-022` goes red — which
is now the second recorded instance (`epic-190-a2`, then this one). The coupling
is not obvious from either side: nothing in `guard-invariants.json` points here,
and nothing in `docs/workflow-improvements/` warns that editing it touches a
frozen per-epic snapshot. That is worth its own workflow improvement rather than
a third refresh note.

## Digests

| File | before | after |
|---|---|---|
| `references/guard-invariants.json` | `1726e3fe…` | `bfd084ea…` |
| `scripts/generate-guard-invariants.py` | `4d06449a…` | `621773a2…` |
| `scripts/generated/guard_invariants.py` | `fc81eec6…` | `caa82a5d…` |
| `scripts/generated/guard-invariants.generated.js` | `ca0ccdcb…` | `d651aecd…` |
| `scripts/generated/guard-invariants.generated.ps1` | `f264ff4f…` | `f6526577…` |
| `scripts/generated/guard-invariants.generated.sh` | `35cbaa1c…` | `397f0adf…` |

All six paths are under `plugins/sdd-quality-loop/`. The "after" column matches
the digests CI reported as the rejected live values, which is how the diagnosis
was confirmed rather than inferred.
