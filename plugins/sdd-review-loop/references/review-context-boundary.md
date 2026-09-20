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
   ledger **as it stands before the reservation** (`:525`, and again under the
   reservation lock at `:869`).
2. Append the reserved record to the ledger (`:879-888`).
3. Print the `REVIEW_CONTEXT_OK` line — the record hash followed by the
   chain facts the validator proved before printing (WFI-037):
   `REVIEW_CONTEXT_OK <record_sha256> sequence=<n> previous_record_sha256=<hash|-> pre_append_tip_sequence=<n|-> identity_unique=yes`.

Step 1 is the only time `identity_ledger_sha256` is meaningful. Step 2 changes the
file it describes. By the time the reviewer is launched, the field necessarily
describes a ledger state that no longer exists on disk.

This is not tampering and not a defect in the reservation. It is what "the manifest
was validated against the ledger it extends" means: the field pins the *pre-image*,
and the appended record is the *extension*.

## Field table

| Field | Validator checks | Reviewer re-verifies? |
|---|---|---|
| `schema` | must equal `review-context-invocation/v2` (`:312`) | **yes** — cheap, and a wrong schema means a wrong contract |
| `input_mode` | must equal `file-manifest` (`:313`) | **yes** |
| `fallback_mode` | must equal `none` (`:314`) | **yes** |
| `read_only` | must equal `true` (`:315`) | **yes** |
| `stage`, `role` | must be an authorized pair (`:359-361`) | **yes** — confirm they match the role you actually are |
| `feature` | charset only (`:316`) | **yes** — confirm it is the feature you were asked to review |
| `sequence` | integer >= 2, and must equal `last_record.sequence + 1` (`:317`, `:527`) | **yes** — via the caller-quoted `REVIEW_CONTEXT_OK` line, see below |
| `previous_record_sha256` | must equal the last record's `record_sha256` (`:527`) | **yes** — via the caller-quoted line; this is the chain |
| `identity_ledger_path` | must be exactly `reports/review-context/identity-ledger.json` (`:318`) | **yes** — it is a constant |
| `identity_ledger_sha256` | hex-format (`:319`); equality against the ledger **before** the append (`:525`, `:869`) | **NO — see below** |
| `allowed_input_manifest[].path` | canonical, no symlink component, role-authorized, not a raw reviewer report (`:609-615`) | **yes** — and read nothing outside it |
| `allowed_input_manifest[].sha256` | equality against the file on disk (`:627`) | **yes** — this is the substantive integrity check |
| `task_id` (quality stage only) | `^T-[0-9]{3}$`, and the implementation report must match it (`:295`, `:547-560`) | **yes** |
| `gate_report_declaration` (quality stage only, OPTIONAL) | shape (`:296-301`); the named document must be a canonical, symlink-free, regular file under `reports/quality-gate/` and must hash to the pinned `sha256` before any row is read from it (`:578-594`); its `## Post-Fix Artifacts` rows then authorize manifest entries the frozen implementation report cannot describe (`:187-192`, WFI-036) | **yes** -- it is a second authorization source, so confirm it is the gate report for the cycle you were launched for |

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

**Verify the record chain from the caller-quoted `REVIEW_CONTEXT_OK` line
instead.** The ledger itself is an authorized input for **no role** — a
manifest naming `reports/review-context/identity-ledger.json` fails
`REVIEW_CONTEXT_PATH` — so a procedure that requires reading it cannot be
performed by its audience (WFI-037; measured, not hypothesized). The
validator therefore emits, on the OK line itself, every chain fact it
proved before printing:

`REVIEW_CONTEXT_OK <record_sha256> sequence=<n> previous_record_sha256=<hash|-> pre_append_tip_sequence=<n|-> identity_unique=yes`

Every step below is checkable from evidence a role actually has — the
quoted line and its own manifest — with no file read outside the manifest:

1. `sequence` on the quoted line matches your manifest's `sequence`, and —
   on a reservation — equals `pre_append_tip_sequence + 1`: the validator
   proved your record extends the pre-append tip and appended it as the
   new last record. `pre_append_tip_sequence=-` marks the verification of
   an already-persisted identity, where later records are legitimate and
   tip position is meaningless. (evidence: caller-quoted line)
2. `previous_record_sha256` on the quoted line matches your manifest's
   `previous_record_sha256` — the chain link the validator proved against
   its unconditional whole-ledger walk. (evidence: caller-quoted line + manifest)
3. `<record_sha256>` recomputes as
   `sha256("<sequence>|<stage>|<role>|<run_id>|<host_session_id>|<previous_record_sha256>")`
   from your manifest's own fields — the same construction the validator
   uses at `:426` and `:857`. (evidence: caller-quoted line + manifest)
   For new scratch-bound quality reservations, compute the declaration digest as
   SHA256 of UTF-8 `feature + LF + scratch_root` with no terminal newline. Append
   `|scratch-declaration-v1|<declaration digest>` to the original chain text before
   computing its record hash. The ledger stores `scratch_declaration_sha256` for
   these records only. Historical reservations lacking that field retain the old
   hash recipe; their original quoted receipt must be used, not a new reservation.
   For new spec/impl reservations, compute the input digest as SHA256 of the
   ordered manifest entries, each encoded as UTF-8 `path + TAB + sha256`,
   joined by LF without a terminal newline. Append
   `|allowed-inputs-v1|<input digest>` to the original chain text before hashing.
   These records store `allowed_inputs_sha256`; persisted verification rejects
   input additions, removals and hash changes. Historical records without this
   extension retain the original recipe and do not prove a historical input set.
4. `identity_unique=yes` — the validator refuses to print the line unless
   your `run_id`/`host_session_id` pair appears exactly once: nowhere
   before the append on a reservation, exactly one persisted record on a
   verification. (evidence: caller-quoted line)

If all four hold, your launch identity is verified to the full strength the
validator proved — all four properties, from caller-supplied evidence. The
falsifiability that makes that evidence worth quoting: a fabricated OK line
fails step 3 arithmetically unless its facts are internally consistent, and
an internally consistent fabrication describes a record the ledger does not
contain, which the next validator invocation's unconditional chain walk and
identity checks refuse — the fabricator gains one launch that the
deterministic gate then strands (an orphan at best), never a persisted
review identity.

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

**One case read as a contradiction and is documented here so no one else
re-derives it wrongly.** Until 2026-08-01, `impl-reviewer-a.md` said:

> Do not read any reviewer-b.json or integrated-summary.json from prior rounds.

while `review-precheck-common.sh:274` **fails the round** unless impl-reviewer-a's
manifest carries the *previous* round's `integrated-summary.json`, and
`validate-review-context-set.sh` authorizes it for `impl-reviewer-a` with an
explicit comment:

> Issue #143: impl-review-precheck requires impl-reviewer-a to carry the PREVIOUS
> round's integrated-summary.json when round > 1 … Without this, reviewer-a's
> required input is rejected as role-unlisted and impl-review can never pass at
> round > 1.

The role text forbade reading a file the gate required the role to carry. Both
statements were load-bearing and could not both be followed.

**This is resolved.** `fea5ccd0` narrowed the prohibition to `reviewer-b.json` and
gave the role file the Issue #143 exception explicitly: at round > 1 reviewer A's
manifest carries the previous round's `integrated-summary.json`, read as counts
and check IDs only, with reasoning from reviewer B's findings still forbidden —
which is the independence property the original line existed to protect.
`impl-review-loop`'s SKILL.md STEP 2 and STEP 5 now state the same contract for
the orchestrator that builds the manifest, and
`tests/impl-review-round2-contract.tests.sh` holds the round-2 shape end to end,
including that binding the previous round's summary to reviewer B instead is
still rejected.

The account above is kept rather than deleted because the contradiction was real
for long enough to be re-reported as live from a stale branch two weeks after it
was fixed. If you are looking at a role file that still carries the old wording,
you are reading a checkout that predates `fea5ccd0` — check `git log` before
filing it.

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

Closed, and listed here so they are not re-derived from an old copy of this file:

- **`impl-reviewer-a.md` vs the precheck's previous-round requirement.** Closed by
  `fea5ccd0` (2026-08-01): the role text gained the Issue #143 carve-out. See the
  section above.
- **An `--edit-summary` message naming a flag the script did not accept.** No such
  message exists in `impl-review-precheck.sh` any more, and mode acceptance
  (`impl-review-precheck.sh:69`) now admits `--verify-inputs` and `--provenance-rereview`, so neither
  half of the claim still holds.

## Feature-wide scratch reservations

For quality invocations declaring `scratch_root`, both validators require Python
3 and check every declared Scratch Root in the feature's implementation reports,
plus the original invocation evidence for prior evaluator reservations. Equal,
ancestor and descendant roots are rejected; sibling names sharing only a string
prefix are allowed. Missing bound history or conflicting declarations block launch.
Legacy invocations without a declared root do not assert a historical root.
Restore missing original evidence; never synthesize it or delete ledger records.

Under the existing ledger lock, a new reservation saves its invocation in
`reports/review-context/scratch-reservations/<record_sha256>.json` before the
ledger append. A failed append may leave an orphan snapshot: preserve it and
investigate the failure, rather than replacing evidence. A persisted identity's
declared scratch root cannot change or disappear on verification. New declared
quality roots are bound into their ledger record hash through the optional
`scratch_declaration_sha256` extension. All prior record bytes and hashes remain
unchanged. Legacy records without that extension may lack history and provide no
proof of past scratch isolation; known legacy roots still prevent overlap. These are declared-location checks, not proof
of operating-system isolation or of live host activation.
