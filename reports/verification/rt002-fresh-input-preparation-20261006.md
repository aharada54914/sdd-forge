# RT002 fresh-run input preparation — 2026-10-06

Preparation only; not a manifest, implementation verdict, or reservation.
Owner: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`.
Observed HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`.
Existing dirty work, historical 67-input manifest, and canonical report are preserved.

The original-path diagnostic results remain Bash 984/0 and PowerShell 985/0,
both exit 0, recorded in `rt002-original-diagnostic-20261006.md` beside this file.
Those 1,969 assertions were not rerun during this preparation.

## Command-scoped dependency audit

The prospective recovery run will execute the two original handshake suites,
the existing task-input-manifest validator, and the existing structure precheck.
Both suites call the handshake wrappers; those wrappers load their respective
`lib/py-dispatch` helper. The helpers select Python and invoke the supplied master;
the master imports only Python standard-library modules.

The suites additionally execute `tests/run-all.sh --list` and read
`tests/run-all.ps1` (Bash suite lines 580/586; PowerShell suite lines 522/528).
`tests/run-all.sh:21-25` reads `tests/suite-inventory.posix`; its `--list` branch
at lines 27-30 prints the inventory and exits before running any registered suite.
Consequently the files named *inside* that inventory are not executed or read by
this selected command. Loading every registered suite into this closure is not
required by this call path.

The task-input validator uses inline standard-library Python. The structure
precheck sources no repository helper; it performs structural existence checks.
Runtime versions and environmental dependencies must be recorded by the fresh
run rather than represented as fabricated repository inputs.

## Five missing repository inputs and observed SHA-256

```text
abde8035c825c318a56a3d9e1b24b2fd618553f10f9784ceae8ab2173eeadf0c  plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh
b15ef1ee7b8b89fb7717ed09b4d7c0e6150bbbd87478594f61a146b6596b30fb  plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1
30a0caf034ba9414a1760a0603085056a410f45a68b0d03cb64336e83d79075a  tests/run-all.sh
57ec5e6657afb475b93bae4f998d7c2a5fdb0df8df9ff6be25e24bc19016ad20  tests/run-all.ps1
6eb645004eab2da53797f3d92d029eec11884476b2580c9eece4336f10f1a938  tests/suite-inventory.posix
```

Retaining all 67 historical paths plus these five yields a 72-path candidate
inventory. This is not a certified new manifest: the fresh run must select and
hash current contract/evidence inputs, including any newly admitted recovery
records, and validate its own identity and snapshot. Historical pins must not be
silently repurposed as current pins.

## Concrete next operation

Independently check this bounded dependency inventory, then start the already
authorized fresh implementation recovery context and create its task-only
snapshot with actual run/session identity. Pin current bytes before executing
the selected commands and run the existing manifest validator. Preserve raw logs
and exit codes in that run. Follow the existing quality-gate recovery contract
for independent old/new evidence comparison and canonical adoption; reserve the
evaluator only after those prerequisites, never from these diagnostic results.

No protected source, canonical report, approval, verdict, task state, Git history,
or identity ledger was changed. Formal run execution, native activation, latest
dirty-head CI, merge, and Done are not proved by this preparation.

## Session handoff: fresh recovery context required

This investigating subagent has handled multiple tasks and undergone compaction.
It must not identify itself as the fresh implementation recovery context:
`plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md:51-60`
requires a fresh per-task context on capable hosts and ends a compacted session.
The canonical implementation report remains unchanged as directed; this is a
non-frozen preparation handoff, not an implementation report or verdict.

The historical manifest is:
`reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/RUN-RT002-T001-REVALIDATION-20261005T043106Z-497150f9-9afe-4686-9f8a-9619f4014c6d/task-input-manifest.json`.
Its recorded SHA-256 is
`affe26456f270f2fdf79552076f39ec1c43f18605569f52efaab4072fee7cfa5`.
That run validated with the owner checkout as `--snapshot-root`; it does not
prove creation of an isolated snapshot. Preserve that limitation and its identity.

A fresh context must first read the approved task and implementation report,
then the implement-task references and quality-gate recovery contract. Use the
existing `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh` with
`--manifest`, `--repo-root`, and a new `--snapshot-root`, followed by
`plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest
<new-manifest> --snapshot-root <new-snapshot> --expected-task T-001`.
The snapshot preparer consumes a manifest; it does not generate one. Include
newly consumed preparation/recovery contract files in the current input audit
rather than assuming the 72-path proposal is final. Record the new context's
actual identity and invocation model/cost inputs, not the historical values.

No new manifest, snapshot, reservation, or test execution was performed at this
handoff. The 1,969 diagnostic assertions must not be rerun merely to prepare it.
