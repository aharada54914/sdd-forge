# T-002 — OQ-002 / INV-013 fresh re-verification (before staging)

Per `tasks.md` T-002 Done-When item 1: the insertion point (`## Preconditions`
`:45-53`, directly before `## Step 1` `:55`) is re-verified fresh against the
*current* live `plugins/sdd-ship/skills/ship/SKILL.md` at implementation
start, not assumed from `tasks.md`'s own line numbers. Run before staging any
candidate.

```
$ grep -n '^## Preconditions$\|^## Step 1' plugins/sdd-ship/skills/ship/SKILL.md
45:## Preconditions
55:## Step 1 — Target Selection
```

Full read of the live file (lines 1-333, via the Read tool) additionally
confirmed the exact body boundaries:

- `## Preconditions` starts at line 45; its body is lines 47-53 (two short
  paragraphs: the `AGENTS.md` / `check-sdd-structure` check, then the
  `sdd-sudo` prohibition); line 54 is a blank separator line.
- `## Step 1 — Target Selection` starts at line 55.

## Conclusion

`tasks.md`'s own citation (`## Preconditions` `:45-53`, `## Step 1` `:55`) is
accurate as of this re-check — no drift was found; no re-derivation of the
insertion point was necessary. The candidate's probe section is inserted
directly after live line 53 (before the file's line 54 blank separator,
which becomes the candidate's own pre-section blank line) and directly
before what was live line 55 (`## Step 1 — Target Selection`, which shifts
to candidate line 77 after the 22-line insertion — confirmed post-stage in
`02-verification-record.md`).

## Re-verification of the *Protected Files* table (requirements.md
`## Protected Gate Files` re-verification instruction)

Read directly (via the Read tool, not a shell command that merely mentions
the path, per INV-012) at implementation start, not carried forward from
`requirements.md`'s or `tasks.md`'s own snapshot:

```
plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4
PROTECTED_GATE_SUFFIXES = (..., 'plugins/sdd-ship/skills/ship/SKILL.md', ...)

plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:18
PHASE2_HUMAN_COPY_TARGETS = (..., 'plugins/sdd-ship/skills/ship/SKILL.md', ...)
```

`plugins/sdd-ship/skills/ship/SKILL.md` is confirmed, fresh, today, to be a
member of both tuples. The human-copy staging plan (OQ-007 resolution) is
therefore the correct plan, not a stale assumption.
