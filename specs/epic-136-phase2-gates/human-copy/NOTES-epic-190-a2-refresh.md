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

> **CORRECTION (2026-08-11, PR #243 CI triage):** "remain red on Windows
> for the same pre-existing reason" understated the impact. On
> windows-latest CI these are nine hard failures of
> `tests/phase2-guard-invariants.tests.ps1` (61 passed / 9 failed, run
> 31490719703), all with the runner diagnostic `staged canonical bootstrap
> inventory target count differs` — they are not environmental there, and
> they hold `test (windows-latest)` red on PR #243. main is not equally
> red: its Windows job fails on an unrelated timing flake in a different
> suite. The refresh candidate below closes them once applied.

---

## Runner refresh candidate — prepared, awaiting human apply (2026-08-11)

An agent-prepared refresh of the R-10 runner sits beside it as
`apply-protected-files.refresh-candidate-20260811.ps1`
(sha256 `54c3b3d192f2bd7784614ddd8b52e67b19d618ebed9794980a3936e67f06bde2`).
It executes the RT-20260811-002 rulings inside the runner itself:

- `$BootstrapTargets` becomes this bundle's 18-entry staging inventory
  (workflow snapshot evicted), byte-order-identical to `MANIFEST.sha256`
  and to the TEST-013 pin.
- A new `$RegistryTargets` pin carries the 26-entry repository-wide
  protection registry in canonical order; the canonical authority check
  (`Assert-SameOrder` against the staged canonical, both modes) binds it,
  so a mutated canonical still fails closed — including the TEST-013
  `expansion` mutation (19 entries) — while the legitimate 26-entry
  registry is accepted.
- The copy plan is always the 18-entry bundle inventory; normal-update
  mode keeps the staged==live canonical equality check.

Verified before staging: PowerShell parser clean; ASCII/no-BOM; every
ACTIVE TEST-013 static pin holds (anchored native API names, no
`Get-FileHash`/path-copy fallback, FullLanguage+NTFS floor, all four
fixture markers unique); `$RegistryTargets` == live canonical
`phase2_human_copy_targets` (26/26, exact order); `$BootstrapTargets` ==
`MANIFEST.sha256` target order (18/18); selection-block simulation 7/7
(accepts real canonical with plan=18 in both modes; rejects expansion,
staged-mutation, live-tamper, invalid-live, absent-live).

**Human apply steps** (from the repository root; both copies must stay
byte-identical, and the manifest digest travels in the same commit):

1. Copy the candidate over BOTH protected copies:
   - `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
   - `specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
2. In `specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256`, replace the
   digest on the final line (target
   `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`,
   currently `e00f76b6…`) with
   `54c3b3d192f2bd7784614ddd8b52e67b19d618ebed9794980a3936e67f06bde2`.
   No line is added, removed, or reordered.
3. Delete `apply-protected-files.refresh-candidate-20260811.ps1`.
4. Verify: `shasum -a 256 -c` against the manifest (18/18 OK) and
   `bash tests/phase2-guard-invariants.tests.sh` (35/0). On Windows,
   `tests/phase2-guard-invariants.tests.ps1` is expected to go 70/0 —
   the nine runner-emulation assertions turn green (the companion
   `New-InstallationFixture` change in the same PR supplies the live
   workflow to the runner's post-install child suites, which TEST-011
   needs after the eviction).

> **APPLIED** — the human executed steps 1–4; `MANIFEST.sha256`'s final line
> carries `54c3b3d1…` today and the candidate file is gone. The section below
> supersedes this one with a NEW candidate for the same runner.

---

## Class fix extended — registry-projection snapshot evicted (2026-08-14)

The 2026-08-11 ruling evicted the repo-shared **CI workflow** snapshot. The
same defect class then fired a fourth time, on a different repo-shared file:
on 2026-08-14 a sanctioned refresh of epic-190-a2's bundle advanced live
`guard-invariants.json`, which left THIS bundle's staged copy stale and turned
PR #244's CI red on all six jobs across all three OSes with
`FAIL: WFI-016 staged targets are byte-identical to live (no stale staging)`.

### Why these six files are the same class

`guard-invariants.json`, its generator, and the four `generated/` siblings are
a **projection of a repository-wide registry with many writers**. Membership
test for the class: *the file's LIVE bytes can change without this epic
changing anything*. Measured on `main`, the live canonical has been written by
three separate epics plus one framework fix:

| commit | writer |
|---|---|
| `2b8a52f6` | epic-136-phase2-gates (creation) |
| `848e46d1` | WFI-016 hook-guard CWD fix |
| `8297945a` | epic-189-a1 protected-path registration |
| `025b2f0d` | epic-190-a2 capability-registry registration |

A per-epic snapshot of such a file cannot stay fresh, and every apply of a
stale one silently un-protects whatever the other writers added.
Refresh-to-live only resets the clock; eviction removes the class.

### Executed in this bundle

- `MANIFEST.sha256`: the six registry-projection entries REMOVED; 18 → 12
  entries, no other line touched, no digest rewritten, order preserved
  (`shasum -a 256 -c` = 12/12 OK).
- The six staged files DELETED.
- `tests/phase2-guard-invariants.tests.{sh,ps1}` amended in step:
  - the TEST-013 inventory pin is the 12-entry list;
  - the class lock is now **data-driven over all seven evicted paths**
    (workflow + the six), asserting ABSENCE of both the staged file and any
    manifest entry, so re-adding any of them fails the suite;
  - TEST-010/011/012 retarget their subject from the staged plugin tree to the
    **LIVE** `plugins/sdd-quality-loop` — the single source of truth, exactly
    the retargeting TEST-011 received on 2026-08-11;
  - the fixture helpers that read the staged canonical now read the LIVE one
    (`Install-FixtureCanonical`), and the two mutation cases that mutated the
    staged canonical now mutate the surfaces that survive eviction.

**The guard's protection of these six paths is unchanged.** They remain in the
live `protected_gate_suffixes` (77) and `phase2_human_copy_targets` (26); only
the per-epic *snapshot* is gone. Verified: all seven evicted paths are still
present in the runner's `$RegistryTargets` pin.

### Proof

- **Non-vacuity, both lanes, one suite run per mutation state**: for each of
  the seven evicted paths, re-adding the staged file and (separately) the
  manifest entry flips **exactly that path's lock to FAIL while the other six
  stay ok**; restoring returns all seven to ok. 16 vectors per lane, 7/7 locks
  each, zero violations (sh and ps1).
- **Real-publisher rehearsal**, 46 legs in a scratch tree, measuring 25 live
  paths plus the CI step-name set plus every array in the live canonical —
  not the two-array measurement that produced the cycle-5 false all-clear:
  **ZERO REMOVALS** (no live file deleted, no live line lost, no CI step lost,
  no registry key lost). Legs: whole-batch ×2 (both refused
  `DUPLICATE_BASENAME_IN_BATCH` exit 19), single-target ×29 (every manifest
  entry of both bundles), adversarial replay ×14, runner ×1.
- **Adversarial replay** — hand-crafting the deleted manifest line and applying
  it as a single-target batch, the exact 2026-08-11 hazard shape — is REFUSED
  for all seven evicted paths against this bundle (exit 10, staged candidate
  absent), with the live workflow and canonical byte-unchanged.

### OPEN — needs this epic's owner, human-only

The R-10 runner `apply-protected-files.ps1` read the staged canonical as its
inventory authority (`:662-664`), so the eviction leaves it **fail-closed**: no
apply path can remove anything, but a legitimate whole-bundle runner apply is
impossible until a human refreshes it. A candidate sits beside it as
`apply-protected-files.refresh-candidate-20260814.ps1`
(sha256 `4b75bc1df75d0295e2f92758af94ab4bf54b0ccdabf2c71effae89dd731cebf1`).
It makes exactly two changes:

- `$BootstrapTargets` becomes this bundle's 12-entry inventory (the six
  evicted), byte-order-identical to `MANIFEST.sha256` and to the TEST-013 pin;
- the staged-canonical authority read is removed. The reviewed
  `$RegistryTargets` pin — the very list the staged snapshot was only ever
  checked *against* — becomes the bootstrap authority, and normal-update mode
  validates the INSTALLED LIVE canonical against that same pin. This is
  strictly stronger than the former staged/live equality check: it binds live
  to a reviewed immutable list instead of to another mutable snapshot.
  `$RegistryTargets` itself is unchanged (26 entries).

Verified before staging: PowerShell parser CLEAN; ASCII/no-BOM; `diff` against
the protected runner is exactly the two changes above and nothing else;
`$BootstrapTargets` == `MANIFEST.sha256` target order (12/12, exact);
`$RegistryTargets` == live `phase2_human_copy_targets` (26/26, exact);
`$BootstrapTargets` is a subset of `$RegistryTargets`; none of the seven
evicted paths appears in `$BootstrapTargets`; all seven still appear in
`$RegistryTargets`.

**NOT verified, and this is a real gap:** the runner is Windows-only
(`apply-protected-files: Windows is required`, exit 2 on macOS), so its install
path could not be executed on the authoring host. The nine runner-emulation
assertions in the ps1 suite are macOS platform failures both before and after
this change (identical failure list). Their behaviour on windows-latest after
the human apply is **unproven** and must be confirmed by CI.

**Human apply steps** (from the repository root; both copies must stay
byte-identical, and the manifest digest travels in the same commit):

1. Copy the candidate over BOTH protected copies:
   - `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
   - `specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
2. In `specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256`, replace the
   digest on the final line (target
   `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`,
   currently `54c3b3d1…`) with
   `4b75bc1df75d0295e2f92758af94ab4bf54b0ccdabf2c71effae89dd731cebf1`.
   No line is added, removed, or reordered.
3. Delete `apply-protected-files.refresh-candidate-20260814.ps1`.
4. Verify: `shasum -a 256 -c` against the manifest (12/12 OK) and
   `bash tests/phase2-guard-invariants.tests.sh` (41/0). On Windows, run
   `tests/phase2-guard-invariants.tests.ps1` and record the actual result —
   it is deliberately not predicted here.

### Sibling bundle NOT closed

`specs/epic-189-a1-project-context/human-copy/` still stages all six
registry-projection files, and the rehearsal measured that its single-target
applies of them still succeed (exit 0). That is a no-op today only because
staged == live; it re-arms the moment live advances. It is NOT closed here
because doing so requires amending AC-021 in a hash-bound `acceptance-tests.md`
— see the PR body and that bundle's own NOTES.
