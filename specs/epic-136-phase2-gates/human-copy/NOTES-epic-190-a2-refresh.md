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

> **CORRECTION (2026-08-11, QG cycle 7, gate seq0680):** the "failed
> before this refresh too" claim above is false. Measured from git
> history: the sh suite was **34 passed / 0 failed** (WFI-016 green) at
> `6277cde0` and `340f0149`, and went **33/1** at `36339788` — the very
> commit this note documents. The refresh regenerated the staged canonical
> to 26 registry targets against 19 staged files, which is what turned
> WFI-016 red; the regression was A2-caused, not pre-existing. The
> underlying refresh was itself necessary (it disarmed the un-protection
> hazard); only the attribution was wrong. Resolved 2026-08-11 by the
> class fix recorded at the end of this file (WFI-016 now iterates this
> bundle's own staging inventory and is green: sh 35/0, ps1 61/9 with the
> nine pre-existing macOS platform failures).

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

---

## Ruling note — staged workflow entry (2026-08-11, RT-20260811-002)

> **SUPERSEDED, same day** — see "Ruling executed" below. The pinned
> invariants this note describes were amended under the follow-up human
> ruling (option (b), class fix), and the entry eviction described here as
> blocked has been executed. The DO-NOT-APPLY instruction is now moot:
> there is no staged workflow entry left to apply.

QG cycle 6 (seq0679) found this bundle's staged `.github/workflows/test.yml`
(854 lines, `8beba70c…`, item 2 of the OPEN section above) is not merely out
of sync: applying that one entry would **remove 137 lines / 18 named live
steps** — epic-190-a2 T-006's four drift locks plus the 14 CI-registration
steps for all seven epic-190 suites (measured end-to-end:
`specs/epic-190-a2-capability-registry/verification/T-006/cycle6-apply-rehearsal.log`).
The generic publisher refuses this manifest as a whole batch
(`DUPLICATE_BASENAME_IN_BATCH` exit 19: two `SKILL.md` targets), but this
epic's own Windows-only `apply-protected-files.ps1` applies all 19 targets
in one transaction, and a single-target batch through the generic publisher
applies the entry cleanly — the hazard is live on both paths.

The human ruling of 2026-08-11 on RT-20260811-002 directed removing the
`.github/workflows/test.yml` entry from this bundle's `MANIFEST.sha256` to
disarm the hazard class. **That removal is deliberately NOT performed**,
under the same ruling's own constraint (stop rather than break a pinned
invariant): `TEST-013` in `tests/phase2-guard-invariants.tests.sh:45-92`
pins this manifest to exactly 19 entries in a fixed order with
`.github/workflows/test.yml` at position 18, and requires the staged
candidate file to exist; the ps1 twin (`:189-233`, `:294-296`) pins the
same list and asserts the staged CI candidate exists, and `TEST-011`
asserts its content. Removing the entry or the staged file breaks all of
these; the resolution is this epic's owner's decision (already flagged as
item 4 of RT-20260811-002 together with the WFI-016 semantics question).

Until that decision — refresh the staged workflow to live bytes with the
digest updated in place (the technique the section above already proved,
which TEST-013 permits), or amend TEST-013/TEST-011 and remove the entry:

**DO NOT APPLY this bundle's `.github/workflows/test.yml` entry, via
`apply-protected-files.ps1`, any publisher batch, or manual copy.** The
stale copy deletes live CI enforcement. The other 18 entries are unaffected
(byte-identical to live; the rehearsal measured zero removals outside the
workflow target).

---

## Ruling executed — workflow snapshot evicted (2026-08-11, RT-20260811-002, class fix)

After QG cycle 7 (seq0680) measured both remaining options, the human ruled
**option (b) directly**: amend this epic's pinning assertions so the
shared-file snapshot is evicted from per-epic bundles entirely — the class
fix, not the instance fix — explicitly accepting that epic-190-a2's
completion waits on it. Rationale, as ruled: a per-epic staged snapshot of a
repo-shared file (`.github/workflows/test.yml`) is structurally doomed to go
stale and become a deletion hazard — three such surfaces were found in the
week of 2026-08-11 alone; refresh-to-live (option (a)) would rot again as CI
grows, eviction removes the class. The cross-epic edits are human-authorized
under this ruling.

Executed in this bundle:

- `MANIFEST.sha256`: the `.github/workflows/test.yml` entry (position 18,
  `8beba70c…`, the stale 854-line snapshot) is REMOVED; 19 -> 18 entries, no
  other line touched (`shasum -a 256 -c` remains 18/18 OK).
- The staged file
  `specs/epic-136-phase2-gates/human-copy/.github/workflows/test.yml`
  is DELETED.
- `tests/phase2-guard-invariants.tests.{sh,ps1}` amended in step:
  - TEST-013 pins the 18-entry fixed-order inventory (workflow evicted);
  - a new TEST-013 **class lock** asserts the ABSENCE of both the staged
    file and any manifest entry for the repo-shared workflow, so a future
    re-adding fails the suite instead of rotting silently;
  - TEST-011 now asserts the CI ordering invariant against the LIVE
    workflow (the single source of truth);
  - WFI-016 iterates this bundle's own staging inventory (the TEST-013
    list) instead of the canonical JSON's `phase2_human_copy_targets`,
    which epic-190-a2's registration turned into a repository-wide
    protection registry (19 -> 26) — the item-4 semantics decision of
    RT-20260811-002, resolved as "per-bundle staging inventory".

What this closes: the 137-line / 18-step deletion hazard on every apply path
(whole batch, single-target batch, runner) — there is no stale snapshot left
to apply. The WFI-016 red (1 out-of-sync + 7 missing) clears.

Known residue, this epic's owner, human-only: the staged immutable runner
`apply-protected-files.ps1` is R-10 protected and still embeds the OLD
19-entry `$BootstrapTargets` list (workflow at position 18), while the live
canonical registry now has 26 entries. Whole-bundle applies through the
runner were ALREADY fail-closed before this eviction (staged canonical 26 !=
runner 19 in bootstrap mode; manifest line count != 26 targets in normal
mode) and remain fail-closed after it — nothing can apply the evicted entry —
but the runner cannot complete a legitimate whole-bundle apply either until
its embedded list is refreshed by a human (it is R-10; no agent path). The
corresponding runner-emulation assertions in the ps1 suite remain red on
Windows for the same pre-existing reason (macOS shows them as the nine
platform failures). Single-target applies of the remaining 18 entries
through the generic publisher are unaffected.
