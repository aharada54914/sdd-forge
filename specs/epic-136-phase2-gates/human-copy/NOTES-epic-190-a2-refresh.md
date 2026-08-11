# Refresh note — regenerated against live 77/26 by epic-190-a2 (2026-08-11)

`MANIFEST.sha256` cannot carry prose (its parser rejects `#` comment lines
with exit 13), so this note records why six staged bytes in this bundle
changed, and flags one item that needs this epic's owner.

## What happened

A human applied `epic-190-a2-capability-registry`'s human-copy bundle to the
live tree. That apply added seven paths to the shared, repository-wide
`PHASE2_TARGETS` tuple in `generate-guard-invariants.py` — the very tuple this
bundle owns — moving live `guard-invariants.json` from 70/19 to 77/26:

| Array | before | after |
|---|---|---|
| `protected_gate_suffixes` | 70 | 77 |
| `phase2_human_copy_targets` | 19 | 26 |

The seven added paths:

```
contracts/capability-registry.schema.json
contracts/capability-registry.json
contracts/lite-upgrade-reason-catalog.json
plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py
plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json
plugins/sdd-quality-loop/contracts/capability-registry.json
plugins/sdd-quality-loop/contracts/capability-registry.schema.json
```

This bundle still carried the pre-apply 70/19 bytes. Because these are
whole-file replacement candidates, applying this bundle would have **removed**
all seven paths from **both** arrays — silently un-protecting them.

## What changed here

Six files, refreshed to the now-live bytes, plus their six `MANIFEST.sha256`
digests updated in place. **No manifest line was added, removed, or
reordered** — `TEST-013` in `tests/phase2-guard-invariants.tests.{sh,ps1}`
pins this manifest to exactly 19 entries in a fixed order, so only the digest
field of the six changed entries was rewritten:

```
plugins/sdd-quality-loop/references/guard-invariants.json
plugins/sdd-quality-loop/scripts/generate-guard-invariants.py
plugins/sdd-quality-loop/scripts/generated/guard_invariants.py
plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js
plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1
plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh
```

The four `generated/` siblings were produced by running the real
`generate-guard-invariants.py` against a scratch copy of this bundle's own
tree — never hand-authored. Non-vacuity was demonstrated by tampering with each
generated output and the canonical JSON in turn, confirming `--check` exits 1,
then restoring and confirming exit 0.

## Safety property

Applying this bundle to the current live tree is a no-op on both arrays:

| Array | live before | post-apply | removals |
|---|---|---|---|
| `protected_gate_suffixes` | 77 | 77 | **0** |
| `phase2_human_copy_targets` | 26 | 26 | **0** |

Verified: `generate-guard-invariants.py --check` exits 0 and
`shasum -a 256 -c MANIFEST.sha256` exits 0 (19/19 OK).

## OPEN — needs this epic's owner

`tests/phase2-guard-invariants.tests.{sh,ps1}`'s WFI-016 assertion
("staged targets are byte-identical to live") still fails. It failed **before**
this refresh too, and the suite totals are unchanged by it — sh 33 passed / 1
failed, ps1 59 passed / 10 failed (nine of the ten are macOS-environmental,
`apply-protected-files: Windows is required`) — but the reason list changed and
the residue is not A2's to decide:

1. **Seven `missing:` entries.** WFI-016 iterates the *staged* canonical
   JSON's `phase2_human_copy_targets` and requires each entry to exist inside
   this stage. That array is now 26, but this bundle stages 19 files. Closing
   this means either staging seven files that belong to `epic-190-a2` into
   *this* epic's bundle, or registering them in this manifest — and the latter
   is impossible without editing `TEST-013`, which hardcodes 19 entries in a
   fixed order. Both are scope decisions for this epic.

   Root cause: WFI-016 was written when `phase2_human_copy_targets` was exactly
   this bundle's inventory (19 = 19). A2's registration turned that array into
   a repository-wide registry while WFI-016 still reads it as this bundle's
   staging manifest. The two meanings have diverged.

2. **`.github/workflows/test.yml` `out of sync:`.** This bundle's staged
   workflow is the pre-apply `HEAD` copy (854 lines); live is now 991 lines
   after the A2 apply. Refreshing it would import A2's and T-005's CI steps
   into this epic's staged candidate. Pre-apply these were byte-identical, so
   this is a direct consequence of the same apply.

A2 deliberately stopped short of both rather than expanding another epic's
bundle unilaterally. The un-protection hazard — the part that was actively
dangerous — is fully resolved above.
