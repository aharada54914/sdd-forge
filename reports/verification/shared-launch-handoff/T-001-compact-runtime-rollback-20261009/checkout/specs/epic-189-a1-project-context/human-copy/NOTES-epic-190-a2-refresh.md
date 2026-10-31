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

> **SUPERSEDED, same day** — see "Ruling executed" below. The pinning
> assertions this note describes were amended under the follow-up human
> ruling (option (b), class fix), and the entry eviction described here as
> blocked has been executed. The DO-NOT-APPLY instruction is now moot:
> there is no staged workflow entry left to apply.

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

- `MANIFEST.sha256`: the `.github/workflows/test.yml` entry (position 1,
  `8beba70c…`, the stale 854-line snapshot) is REMOVED; 18 -> 17 entries, no
  other line touched (`shasum -a 256 -c` remains 17/17 OK).
- The staged file
  `specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml`
  is DELETED.
- `tests/guard-invariants-epic-a1.tests.{sh,ps1}` amended in step: the old
  TEST-HARDEN "present exactly once" assertion is replaced by a **class
  lock** asserting the ABSENCE of both the manifest entry and the staged
  snapshot file — so a future re-adding fails the suite instead of rotting
  silently. The per-entry digest loop is untouched (the evicted entry simply
  no longer participates). This closes the cycle-7 evaluator's point that
  this bundle had "no deterministic gate on it at all — the only protection
  is prose in a NOTES file".

What this closes: the 137-line / 18-step deletion hazard on this bundle's
only reachable apply path (the single-target batch convention documented in
`RUNBOOK-pr229.md`) — there is no stale snapshot left to apply. The
remaining 17 entries and the RUNBOOK batches are unaffected.

---

## Class fix NOT extended here — blocked on a hash-bound AC (2026-08-14)

The 2026-08-11 eviction covered the repo-shared CI workflow. The same class
fired again on 2026-08-14 against a different repo-shared file — the canonical
`guard-invariants.json` and its five projection siblings — turning PR #244's
CI red on all six jobs across all three OSes. Those six files were EVICTED from
`specs/epic-136-phase2-gates/human-copy/` under the same rationale. **They are
deliberately NOT evicted from this bundle**, and this note records exactly why,
so the next agent does not rediscover it the hard way.

### This bundle is exposed to the same class

Measured with the real publisher in a scratch tree (2026-08-14 rehearsal, leg
group 3): a hand-crafted single-target apply of each of the six still succeeds
against this bundle (`exit 0`), where the identical replay against
epic-136-phase2's post-fix bundle is REFUSED (`exit 10`, staged candidate
absent). Today that apply is a harmless no-op **only because staged == live**.
It re-arms the moment any epic advances the live registry — which is routine:
three separate epics have written the live canonical (`2b8a52f6`, `8297945a`,
`025b2f0d`), and seven epic branches are in flight.

Detection, meanwhile, is already wired: `TEST-022`'s `check_live`
(`tests/guard-invariants-epic-a1.tests.sh:497-517`) hard-binds each of the six
live files to *either* the pre-apply baseline *or* this bundle's staged bytes.
When live advances, that assertion goes red — the same "CI red on an unrelated
PR" symptom the class fix exists to remove.

### Why eviction is blocked (and what would unblock it)

Unlike epic-136-phase2 — whose pins live only in writable test files — this
bundle's six staged files are named by **frozen, hash-bound specification
documents** of a feature that is 13/13 tasks `Done`:

1. **`specs/epic-189-a1-project-context/acceptance-tests.md`, AC-021 row.**
   It requires, verbatim, the *staged* artefacts: "staged
   `human-copy/.../guard-invariants.json` candidate's `protected_gate_suffixes`
   includes every path in `PROTECTED-MANIFEST.md` … matching staged
   `generate-guard-invariants.py` candidate's new `EPIC_A1_TARGETS` …
   **staged-tree `--check` passes**". Deleting the staged tree makes AC-021
   unverifiable as written. This file is hash-bound:
   `check-workflow-state.sh:611` requires each verification contract to record
   its sha256, and all 13 of this feature's `verification/T-*.contract.json`
   do.
2. **`security-spec.md`** names "staged-tree `generate-guard-invariants.py`
   `--check` suite" and "TEST-021 (staged-tree `--check` proof)" as the
   mitigation evidence of record for threat boundaries **B6** (generator
   self-defence) and **B9** (publisher self-protection).
3. **`traceability.md`, REQ-007 row** lists all six as Code Targets:
   "`guard-invariants.json` (human-copy); `generate-guard-invariants.py`
   (human-copy); `generated/guard_invariants.py` + 3 siblings (human-copy)".

Evicting the files without amending those three documents would leave the
specification declaring evidence that no longer exists. Amending them is a
change to a frozen, hash-bound spec of a closed feature, which per repository
rule goes through the **sanctioned provenance re-review path**, not an edit —
so it is stopped here and reported rather than executed.

What a future owner needs to decide, precisely:

- amend the AC-021 row so its subject is the **LIVE** tree rather than the
  staged snapshot (the post-apply state TEST-021's own second branch already
  tolerates: "staged `protected_gate_suffixes` equals the live list (human
  apply landed)"), plus the matching `security-spec.md` B6/B9 evidence cells
  and `traceability.md` REQ-007 Code Target cells;
- then evict the six, add the same seven-path ABSENCE class lock this bundle's
  TEST-HARDEN already carries for the workflow, and retarget TEST-021/TEST-022
  to live.

No HMAC re-signing is involved: all 175 evidence bundles were scanned and none
hash-declares any of the six staged paths (6 bundles carry a signature block;
none covers this surface).

Until that decision: this bundle's six registry-projection entries stay
appliable and stay in sync by refresh. **Do not apply them when
`tests/guard-invariants-epic-a1.tests.{sh,ps1}` is red on `TEST-022`** — that
is the signal that the staged copies have gone stale and that applying them
would un-protect whatever another epic has since registered.
