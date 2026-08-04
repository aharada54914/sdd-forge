# Review-Context Launch Boundary: what a reviewer verifies, and what it must not

Normative for every role that receives a `review-context-invocation/v2` manifest:
`spec-reviewer-{a,b}`, `impl-reviewer-{a,b}`, `task-reviewer-{a,b}`, `sdd-evaluator`,
`domain-reviewer-{a,b}`.

The role definitions tell a reviewer to reject a launch on "hash mismatch". Taken
literally that instruction is unsatisfiable: one manifest field is guaranteed to
mismatch by the time a reviewer reads it. This document states which fields the
deterministic validator consumes and when, so a reviewer knows what its own
re-verification can and cannot establish.

**Authority.** `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`
(and its `.ps1` twin) is the authority on manifest validity. This document
describes that script; it does not add rules. Where the two disagree, the script
wins and this document is the defect.

## The ordering that makes one field stale

`--reserve` runs in this order:

1. Validate every manifest field, including `identity_ledger_sha256`, against the
   ledger **as it stands before the reservation** (`:208`, and again under the
   reservation lock at `:313`).
2. Append the reserved record to the ledger (`:318-332`).
3. Print `REVIEW_CONTEXT_OK <record_sha256>` (`:339`).

Step 1 is the only time `identity_ledger_sha256` is meaningful. Step 2 changes the
file it describes. By the time the reviewer is launched, the field necessarily
describes a ledger state that no longer exists on disk.

This is not tampering and not a defect in the reservation. It is what "the manifest
was validated against the ledger it extends" means: the field pins the *pre-image*,
and the appended record is the *extension*.

## Field table

| Field | Validator checks | Reviewer re-verifies? |
|---|---|---|
| `schema` | must equal `review-context-invocation/v2` (`:157`) | **yes** — cheap, and a wrong schema means a wrong contract |
| `input_mode` | must equal `file-manifest` (`:158`) | **yes** |
| `fallback_mode` | must equal `none` (`:159`) | **yes** |
| `read_only` | must equal `true` (`:160`) | **yes** |
| `stage`, `role` | must be an authorized pair (`:189-192`) | **yes** — confirm they match the role you actually are |
| `feature` | charset only (`:161`) | **yes** — confirm it is the feature you were asked to review |
| `sequence` | integer >= 2, and must equal `last_record.sequence + 1` (`:162`, `:260`) | **yes** — via the ledger record, see below |
| `previous_record_sha256` | must equal the last record's `record_sha256` (`:260`) | **yes** — this is the chain |
| `identity_ledger_path` | must be exactly `reports/review-context/identity-ledger.json` (`:163`) | **yes** — it is a constant |
| `identity_ledger_sha256` | hex-format (`:164`); equality against the ledger **before** the append (`:208`, `:313`) | **NO — see below** |
| `allowed_input_manifest[].path` | canonical, no symlink component, role-authorized, not a raw reviewer report (`:284-301`) | **yes** — and read nothing outside it |
| `allowed_input_manifest[].sha256` | equality against the file on disk (`:302-304`) | **yes** — this is the substantive integrity check |
| `task_id` (quality stage only) | `^T-[0-9]{3}$`, and the implementation report must match it (`:154`, `:268-282`) | **yes** |

## `identity_ledger_sha256`: do not re-verify

A reviewer that hashes `reports/review-context/identity-ledger.json` and compares
it to this field will always find a mismatch, and — following the role text's
"reject on hash mismatch" — will always return BLOCKED.

That has happened. During `epic-136-phase4-docs` impl review, the reviewer at
sequence 402 performed exactly this check and blocked. Its reasoning was correct
under a literal reading of its role. Reviewer A at sequence 401 had passed the
same boundary moments earlier only because it did not happen to check that
particular field.

That is the real cost of the ambiguity: **whether a launch succeeds depends on
which fields a reviewer chooses to verify.** Two roles reading the same contract
reached opposite verdicts about the same intact ledger. Nondeterminism inside a
deterministic gate is worse than a straightforward failure, because it looks like
a finding.

**Verify the record chain instead.** It is the actual integrity guarantee, it is
verifiable after the append, and it is strictly stronger than a whole-file hash:

1. The record at your `sequence` exists, is the **last** record, and its `run_id`
   and `host_session_id` match yours.
2. Its `previous_record_sha256` equals the previous record's `record_sha256`.
3. Its `record_sha256` equals the `REVIEW_CONTEXT_OK` value your caller quoted,
   and recomputes as
   `sha256("<sequence>|<stage>|<role>|<run_id>|<host_session_id>|<previous_record_sha256>")`
   — the same construction the validator uses at `:245` and `:307`.
4. Your `run_id` and `host_session_id` appear nowhere else in the ledger. (The
   validator enforces this at `:262-265`; the ledger contract additionally
   requires both to be globally unique, `:234-235`.)

If all four hold, the ledger you are reading is chain-consistent through your own
record. A reviewer cannot do better than this, because it cannot see the
pre-append state at all.

### Gaps in the chain are legitimate

A reserved sequence with no corresponding review output is a **consumed
reservation**, not evidence of tampering. Reservations are append-only and are
never rewritten, so an orchestrator that reserves an identity and then cannot use
it — a mid-round edit invalidating the frozen hashes, a run that blocked at its own
boundary, a crashed launch — leaves an orphan record behind.

The correct response is to note it, not to block on it. A caller should disclose
known orphans in the launch prompt; an undisclosed orphan is worth a sentence in
your output, not a BLOCKED verdict. Chain continuity (`previous_record_sha256`
linking every record) is what matters, and an orphan does not break it.

## Manifest contents are the caller's contract, not yours to second-guess

`path_is_authorized` defines, per stage and role, which paths may appear in a
manifest. It is the gate's decision. If a file is in your manifest, it was
authorized.

**One case is actively confusing and is documented here so no one else re-derives
it wrongly.** `impl-reviewer-a.md:43` says:

> Do not read any reviewer-b.json or integrated-summary.json from prior rounds.

But `impl-review-precheck.sh:207-210` **fails the round** unless impl-reviewer-a's
manifest carries the *previous* round's `integrated-summary.json`, and
`validate-review-context-set.sh` authorizes it for `impl-reviewer-a` with an
explicit comment:

> Issue #143: impl-review-precheck requires impl-reviewer-a to carry the PREVIOUS
> round's integrated-summary.json when round > 1 … Without this, reviewer-a's
> required input is rejected as role-unlisted and impl-review can never pass at
> round > 1.

So the role text forbids reading a file the gate requires the role to carry. Both
statements are load-bearing and they cannot both be followed.

Until a human resolves this (see Open items), the operative reading is: the file's
presence in the manifest is mandatory and correct; the role text's prohibition is
about *reasoning from reviewer B's findings*, and `integrated-summary.json` carries
counts and check IDs only, no narrative. A reviewer that notices the tension should
disclose it — as the `epic-136-phase4-docs` sequence-411 reviewer did — rather than
either blocking or silently ignoring its own role text.

`reviewer-a.json` and `reviewer-b.json` are a different matter: those are
categorically forbidden in any manifest (`is_forbidden_review_output`), enforced by
the validator, with no exception.

## What still warrants BLOCKED

Verifying less does not mean accepting more. Return BLOCKED for:

- Any of items 1–4 of the chain check failing.
- A manifest field in the table above, other than `identity_ledger_sha256`, not
  matching what the validator requires.
- Any `allowed_input_manifest` entry whose sha256 does not match the file on disk.
- A file you need that is not in the manifest. Ask for a corrected manifest; do not
  read it.
- A round whose `precheck-result.json` pins a hash that disagrees with your
  manifest's hash for the same file. That means the round is internally
  inconsistent — different reviewers would be judging different documents.

Do not read outside the manifest to "check something quickly". A directory-scoped
`Grep` or `Glob` is not manifest-safe: it returns content from files you were not
authorized to see. The single permitted exception is testing whether a `domain/`
directory exists at the project root, which `DOMAIN-CONFORMANCE` requires in order
to decide whether it applies at all.

## Open items for a human

1. **`identity_ledger_sha256` vs the role text.** Either the reviewer roles should
   name this field as validator-only (this document is the interim answer), or
   `--reserve` should rewrite the manifest's field after appending so the value a
   reviewer reads is checkable. The second is a behaviour change to a deterministic
   gate and is not made unilaterally.
2. **`impl-reviewer-a.md:43` vs `impl-review-precheck.sh:207-210`.** The role file
   is in `PROTECTED_GATE_SUFFIXES`, so an agent cannot edit it. A human decides
   whether the role text gains the Issue #143 carve-out, or the precheck stops
   requiring the file.
3. **`impl-review-precheck.sh:368`** tells the caller to "provide `--edit-summary`"
   when `design.md` is unchanged between rounds, but `:231` rejects every mode
   except `--verify-inputs`. The message names a flag the script does not accept.
