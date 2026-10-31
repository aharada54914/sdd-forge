# A7 transport inventory recovery candidate

Owner: this A7 worktree. Scope: approved interrupted-review recovery repair.
Risk: high (recovery evidence contract). No original protected files changed.
No reservation, verdict, task status or Git operations performed.

## Cause and bounded change

The original shared helper admits the seven saved A18 transport files only for
next attempt 19, with an embedded digest map. The ordinary A20 precheck rejects
that legacy extension. A19 separately retained eleven transport files; reducing
either directory to the old three-file shape would discard original evidence.

The candidate retains the original v2 and single-inventory behavior. An opt-in
plural inventory extension admits the observed A18/A19 transport filenames only,
bound to the exact partial attempt, complete evidence hashes, current input hashes,
next attempt and existing historical ledger chain. The approval audit additionally
pins the inventory. That audit is an orchestrator transcription, not a signature.
Unknown files and incomplete, duplicate or mismatched inventories are rejected.
Transport output remains diagnostic-only, never a reviewer verdict.

Both runtime callers already delegate to this shared helper and revalidate under
their transition lock; neither caller requires an alternative launch route.
SKILL.candidate.md documents the explicit addition alongside the old shape.

## Executed verification

`rtk proxy python3 -B reports/verification/a7-inventory-recovery-candidate-20261006/inventory.tests.py`

13 tests passed, exit 0 (2026-10-06). Disposable copies of the existing A18/A19
history and ledger only; the owner history is unchanged. Cases: normal admission,
old single-inventory compatibility, original-helper rejection of the new format,
missing file, byte mutation, repinning without approval binding, wrong attempt,
unknown addition, duplicate path, wrong type, path escape, undeclared inventory,
and null inventory. The first test run had one expectation-string typo, corrected
without changing validator behavior; the complete rerun passed.

Independent candidate diff review (`boundary_verify`, 2026-10-06) found no
blocking issue and independently reran all 13 cases successfully. This is not
formal SDD review or actual A20 admission. The adoption script's check-only run
also passed against both unchanged originals and both pinned candidates.

## Remaining

Sanctioned application of two protected targets;
original-path regressions; newly pinned A20 recovery contract/audit; ordinary
precheck; isolated formal review with a new identity and verified delivery;
required CI and merge. No current diagnostic result is a formal PASS.

Human-only application, after independent candidate review:

```sh
rtk proxy python3 -B /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-inventory-recovery-candidate-20261006/apply-human.py --apply-human
```

The script verifies both source and candidate hashes, saves and verifies originals,
then applies the two candidates and verifies readback. It does not reserve identities
or change review state. Existing original/audit/contract files remain untouched
until this explicit application; prior A19 output is not adopted.
Already-applied or partially-applied targets fail the before-hash check without
further writes. Any interrupted application retains its originals in the printed
backup directory; do not rerun it to overwrite or automatically roll back changes.
