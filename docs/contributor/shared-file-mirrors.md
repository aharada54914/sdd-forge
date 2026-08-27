# Editing a repository-shared file

Some files in this repository are snapshotted inside per-epic `human-copy`
bundles under `specs/`. Editing one of those files without refreshing its
snapshots turns CI red, and — before WFI-039 — surfaced the snapshots one CI
round at a time, because each enforcing suite only knew about its own bundle.

**Before pushing an edit to any file under `plugins/` or `tests/`, run:**

```
python3 scripts/sync-human-copy-mirrors.py --check
```

If it reports stale mirrors, drop `--check` to sync them, and commit the result
alongside your edit. `tests/human-copy-mirror-freshness.tests.{sh,ps1}` runs the
same enumeration in CI and fails with the complete list, so forgetting is loud
rather than silent — but finding out locally is cheaper.

## Why a file has mirrors

A `human-copy` bundle is the record of what a human reviewed before applying a
change by hand: the staged bytes are frozen so that what gets applied is what
was approved. That works well for files an epic owns.

It works less well for files nobody owns. The guard invariants
(`plugins/sdd-quality-loop/references/guard-invariants.json`, its generator, and
the four generated modules) are repository-wide, so every epic that ever needed a
human to apply a guard change took its own snapshot. As of WFI-039 those six
files exist in five places, under four different freshness rules, each enforced
by a different suite:

| Location | Rule | Enforced by |
|---|---|---|
| `specs/epic-189-a1-project-context/human-copy/` | live equals the pre-apply baseline **or** the staged candidate | `tests/guard-invariants-epic-a1.tests.sh` |
| `specs/epic-190-a2-capability-registry/human-copy/` | staged is byte-identical to live | `tests/phase2-guard-invariants.tests.sh` |
| `specs/epic-191-a3-path-ownership/human-copy/` | same | same |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/` | candidate is a pure superset of live | `tests/generate-gate-capabilities.tests.sh` |

`tests/guard-parity.tests.sh` is mirrored in `specs/epic-136-phase2-gates/`, and
the reviewer role definitions in `specs/epic-159-pillar-c/`.

Nothing in the file being edited announces this. The one pointer that exists is
inverted: `phase2_human_copy_targets`, the array deciding which files one of
those suites requires to be byte-identical, lives *inside*
`guard-invariants.json` itself.

## Stale is not the same as pending

`scripts/human_copy_mirrors.py` classifies each mirror three ways, and the
distinction matters more than it looks:

- **fresh** — staged bytes equal live bytes.
- **stale** — staged differs from live *and* equals `origin/main`'s live bytes.
  The bundle was already applied; your edit moved live past it. Sync it.
- **pending** — staged differs from live *and* from `origin/main`. The bundle is
  a reviewed change still waiting for a human to apply. **Leave it alone.**

`specs/epic-159-pillar-c/human-copy/` is pending today. A tool that treated
"staged differs from live" as stale would overwrite reviewed human work, and CI
would go green, because no suite enforces byte-identity for that bundle. The
sync tool refuses to touch pending mirrors for exactly this reason.

## When the sync tool is not enough

The tool rewrites digests for paths already registered in a bundle's
`MANIFEST.sha256`. It will not add a new entry: deciding that a bundle should
start snapshotting a file it never carried is a review decision, not a sync, and
the tool reports the path instead of inventing a line.

`MANIFEST.sha256` also rejects `#` comment lines with exit 13, so when a bundle's
staged bytes change for a reason outside that epic's own inventory, the
convention is a sibling note file — see
`specs/epic-189-a1-project-context/human-copy/NOTES-epic-190-a2-refresh.md` and
`NOTES-wfi-030-037-refresh.md` for the two precedents.
