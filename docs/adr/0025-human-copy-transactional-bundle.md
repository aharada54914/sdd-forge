# ADR 0025: Human-copy publisher journaled multi-target transactional bundle

Status: Accepted

Date: 2026-07-21

## Context

ADR-0011 gives `apply-human-copy`'s predecessor runner a single-file
publication primitive — held handle, handle-relative traversal, temp-then-
rehash, atomic rename, no path-based copy fallback — and explicitly accepts
a residual multi-file risk in its own Consequences section:

> Each target rename is atomic, but the 18-target batch is not one
> transaction. A rename-time OS failure may leave a deterministic installed
> prefix and must be recovered with a reviewed full rollback batch.

Epic A1 (`epic-189-a1-project-context`) stages every human-copy application
across MORE THAN ONE live target: REQ-004's sidecar+anchor publish (the
approval sidecar and its accompanying approved-context anchor snapshot),
REQ-007's own six-file guard-invariants batch, and REQ-007's self-protection
batch that includes `apply-human-copy.{sh,ps1}`'s own two basenames.
ADR-0011's single-file primitive is necessary but not sufficient for these
batches: a crash between renaming target 1 and target 2 must never be
observable as "target 1 advanced, target 2 did not" — this is exactly the
"the anchor publishes but the sidecar doesn't (or vice versa)" partial-
publish gap that ADR-0011 knowingly left as an unautomated, human-reviewed
residual rather than a mechanism with an automatic, provable convergence
guarantee.

This ADR supersedes that accepted residual for the specific multi-target
batches Epic A1 introduces, replacing "recover with a reviewed full
rollback batch" with an automatic crash-recovery protocol that converges
every batch to exactly one of two terminal states without a human-reviewed
rollback step.

## Decision

`apply-human-copy` always applies a STAGED batch (one or more targets) as a
single journaled, multi-target transaction, in six steps:

1. **Prepare**: immediately before entering the commit phase, re-hash every
   target's staged candidate TOGETHER, as one step, closing any TOCTOU
   window between validating the first target in a large batch and reaching
   the last. For every target that already has live content, also copy that
   PRE-transaction live content, byte-exact, into the same batch's staging
   subdirectory (`sdd/.staging/<batch-nonce>/pre/<target-basename>`), making
   a full rollback possible without depending on the live filesystem still
   holding the old bytes.
2. **Journal**: before ANY live rename, write a transaction journal —
   `sdd/.staging/<batch-nonce>/TRANSACTION.json` — listing, in commit order,
   each target's live path, its PRE-transaction hash (or `"ABSENT"`), its
   POST-transaction (staged-candidate) hash, the batch's nonce, and
   `status: "in-progress"`. The journal is written via the same
   temp-then-rehash-then-atomic-rename discipline as any other file this
   tool writes, so the journal's own existence is itself all-or-nothing —
   there is no torn-journal case.
3. **Commit**: rename each target from its staged candidate to its live
   path, atomically, one target at a time, in the journal's recorded order,
   using the existing single-file held-handle/temp-rehash/atomic-rename-only
   primitive per target (unchanged from ADR-0011).
4. **Complete**: once every target's rename has succeeded, delete the
   journal (an ordinary unlink; a delete failure here just leaves a
   stale-but-fully-applied journal, trivially resolved by recovery below).
5. **Crash/interrupt recovery** (mandatory; runs automatically at the start
   of every subsequent `apply-human-copy` invocation, before staging or
   applying any new batch): scan `sdd/.staging/*/TRANSACTION.json` for any
   journal still present and, for each one found, re-hash every listed
   target's current live bytes (or note `"ABSENT"`). If every target's
   current hash equals its journal-recorded POST value, the transaction had
   already fully committed before the crash — delete the stale journal, no
   data movement needed. If every target's current hash equals its
   journal-recorded PRE value (or both are `"ABSENT"`), the transaction
   never began committing — delete the stale journal; the staged candidates
   remain available for a human to re-run the publish. If there is a MIX
   (at least one target at its POST hash, at least one other still at its
   PRE hash or absent), recovery rolls every already-committed target BACK
   to its PRE-transaction state — restoring from the journal's own
   `pre/<target-basename>` backup via the same atomic-rename primitive (or
   deleting the live file if its PRE state was `"ABSENT"`) — until every
   target is confirmed back at PRE, then deletes the journal. Recovery
   always drives the system to exactly one of two terminal states —
   fully-applied (all POST) or fully-reverted (all PRE) — never a third,
   standing mixed state; recovery is itself idempotent and re-entrant, so a
   crash DURING recovery is itself safely resumable by the next invocation.
6. **Reader-side generation-consistency check**: any script reading more
   than one of a transaction's targets together, and depending on their
   mutual consistency, fails closed (`HUMAN_COPY_PUBLISH_IN_PROGRESS`) on a
   live journal naming a path it just read, rather than risk reading
   possibly-torn cross-file state.

This journal-plus-backup protocol was chosen at the PROTOCOL layer over two
alternatives. (a) A single filesystem-level atomic operation spanning
multiple files was rejected because no such primitive exists portably: no
POSIX or Win32 primitive renames N≥2 files as one atomic unit —
`renameat2`'s `RENAME_EXCHANGE` swaps exactly two existing paths and has no
portable equivalent across the target platform set. (b) Accepting the
partial-publish risk as a documented residual — ADR-0011's own posture —
was rejected for these batches because it is precisely the "core of the
approval mechanism" gap this decision closes, not a residual to continue
documenting around. Since no single-syscall multi-file atomic primitive is
available, correctness is instead achieved at the protocol layer: a
durably-written (itself atomically-published) journal recording intent
before any live mutation, plus a byte-exact backup of every target's
pre-transaction state, makes the overall batch's observable end state
binary even though the individual renames inside it are not jointly atomic.

## Consequences

- Recovery always converges to exactly one of two terminal states —
  fully-applied (all-POST) or fully-reverted (all-PRE) — never a third,
  standing mixed state.
- Recovery is itself idempotent and re-entrant: a crash during recovery is
  safely resumable by the next invocation, since every recovery step only
  ever compares current-vs-journaled hashes and acts accordingly, never
  assumes prior recovery progress.
- The journal itself is written via the same temp-then-rehash-then-atomic-
  rename discipline as any other file this tool writes, so its own
  existence is all-or-nothing; there is no torn-journal case.
- Readers of more than one transaction target perform their own
  generation-consistency check and fail closed
  (`HUMAN_COPY_PUBLISH_IN_PROGRESS`) rather than risk reading torn
  cross-file state.
- This protocol is narrower in scope than ADR-0011's own runner (a Windows
  PowerShell 5.1-specific native implementation using `NtCreateFile` /
  `SetFileInformationByHandle`): it is implemented directly in
  `apply-human-copy.sh` / `apply-human-copy.ps1` (REQ-007;
  requirements.md/design.md Components) rather than as a native
  Windows-only mechanism, and applies only to the multi-target batches
  Epic A1 stages (REQ-004's sidecar+anchor publish, REQ-007's six-file
  guard-invariants batch, REQ-007's self-protection batch) — it does not
  itself revise or replace ADR-0011's per-file publication primitive, which
  remains unchanged and is reused, unmodified, as the commit-phase
  mechanism for each individual target rename (Decision, above).
- No human-reviewed rollback step remains for these batches: where
  ADR-0011 required "a reviewed full rollback batch" after a rename-time
  OS failure, this protocol converges automatically and unattended on the
  next `apply-human-copy` invocation.

## Verification

This closes AC-033's extended proof (`specs/epic-189-a1-project-context/acceptance-tests.md`):
a simulated crash injected between the first and second rename of a
two-target batch (sidecar + anchor, or any other pair this epic stages
together), recovered on the next invocation, always converges to either
both targets at their PRE bytes or both at their POST bytes, never one
advanced without the other; a crash before the first rename recovers to
all-pre; a crash after the last rename but before journal deletion
recovers to all-post; a second crash injected during recovery itself still
converges correctly on the following invocation.

TEST-033 (`specs/epic-189-a1-project-context/security-spec.md`, Security
Tests table, closing threat B8) proves this directly: "Multi-target
crash-recovery proof: crash injected between renames, at journal-write, and
mid-recovery" — "Converges to exactly one of two terminal states (all-PRE
or all-POST), never a mix; recovery itself proven idempotent under a second
injected crash" — via `tests/apply-human-copy.tests.sh`/`.ps1`.
