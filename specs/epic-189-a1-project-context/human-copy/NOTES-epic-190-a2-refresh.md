# Refresh note — regenerated against live 77/26 by epic-190-a2 (2026-08-11)

`MANIFEST.sha256` cannot carry prose (its parser rejects `#` comment lines
with exit 13), so this note records why six staged bytes in this bundle
changed without any change to this epic's own inventory.

## What happened

A human applied `epic-190-a2-capability-registry`'s human-copy bundle to the
live tree. That apply added seven paths to the shared, repository-wide
`PHASE2_TARGETS` tuple in `generate-guard-invariants.py`, moving live
`guard-invariants.json` from 70/19 to 77/26:

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
all seven paths from **both** arrays — silently un-protecting them. That is the
destructive-superset failure mode inverted, and it was live rather than
hypothetical.

## What changed here

Six files, refreshed to the now-live bytes, plus their six `MANIFEST.sha256`
digests updated in place (no manifest line added, removed, or reordered):

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

**Nothing in this epic's own inventory changed.** `EPIC_A1_TARGETS` and this
bundle's 28 manifest paths are untouched; the seven new paths land inside the
`PHASE2_TARGETS` block of the generator's composition order
(`BASELINE_SUFFIXES + PHASE2_TARGETS + EPIC_A1_TARGETS`), so this epic's
28-path tail of `protected_gate_suffixes` is preserved exactly.

## Safety property

Applying this bundle to the current live tree is a no-op on both arrays:

| Array | live before | post-apply | removals |
|---|---|---|---|
| `protected_gate_suffixes` | 77 | 77 | **0** |
| `phase2_human_copy_targets` | 26 | 26 | **0** |

Verified: `generate-guard-invariants.py --check` exits 0 and
`shasum -a 256 -c MANIFEST.sha256` exits 0 (18/18 OK).

`tests/guard-invariants-epic-a1.tests.{sh,ps1}` — which encodes exactly this
"staged equals live, or staged equals live-plus-manifest" invariant — returns
to green as a result: 81/0 (sh) and 85/0 (ps1), with no assertion edited.

---

## Ruling note — staged workflow entry (2026-08-11, RT-20260811-002)

QG cycle 6 (seq0679) found this bundle's staged `.github/workflows/test.yml`
(854 lines, `8beba70c…`) stale against live (991 lines, `a37a3795…`): its
purpose — this epic's own CI steps — is already served by the live workflow,
and applying the entry would **remove 137 lines / 18 named live steps**,
including epic-190-a2 T-006's four drift locks (measured end-to-end:
`specs/epic-190-a2-capability-registry/verification/T-006/cycle6-apply-rehearsal.log`;
the whole-batch publisher refuses this manifest outright with
`DUPLICATE_BASENAME_IN_BATCH` exit 19, but the single-target batch
convention this bundle's own RUNBOOK-pr229.md documents applies the entry
cleanly, so the batch refusal protects nothing).

The human ruling of 2026-08-11 on RT-20260811-002 directed removing the
`.github/workflows/test.yml` entry from this bundle's `MANIFEST.sha256` to
disarm the hazard class. **That removal is deliberately NOT performed**,
under the same ruling's own constraint (stop rather than break a pinned
invariant): this epic's suite pins the entry —
`tests/guard-invariants-epic-a1.tests.sh:532-534` asserts the CI-staging
workflow entry is present exactly once ("T-009 must neither drop nor
duplicate it"; `tests/guard-invariants-epic-a1.tests.ps1:399-400` asserts
the same), and the per-entry loop requires staged bytes to exist for every
manifest entry, so deleting the staged file is equally pinned. Both suites
are green today (81/0 sh, 85/0 ps1); executing the removal flips them red.

Until this epic's owner either refreshes the staged workflow to live bytes
(digest updated in place — the technique the section above already proved)
or amends the pinning assertions and removes the entry:

**DO NOT APPLY this bundle's `.github/workflows/test.yml` entry, in any
batch size.** The stale copy deletes live CI enforcement. The remaining
17 entries are unaffected (byte-identical to live; rehearsal measured zero
removals outside the workflow target). Tracked in
`docs/review-tickets/RT-20260811-002.yml`.
