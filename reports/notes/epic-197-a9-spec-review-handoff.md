# epic-197 A9 — spec-review handoff note (2026-09-04)

Written for any other session (codex or Claude) picking this up. It records
what is done, what the current blocker is, and the two procedural traps that
cost this session four discarded reviewer runs.

## Where the work is

- Branch: `feature/epic-197-a9-dogfood`
- Worktree used: `/Users/jrmag/Projects/active/sdd-forge-wt-epic-197`
- Spec package: `specs/epic-197-a9-dogfood/` (14 REQ, 29 AC, 29 TEST, 6 tasks,
  all Draft/Planned). `Spec-Review-Status: Pending`, `Human-Spec-Approval: Pending`.
- Round-1 evidence: `reports/spec-review/epic-197-a9-dogfood/attempt-1/round-1/`

## Status

Attempt 1 round 1 is COMPLETE with verdict **NEEDS_WORK** (Critical 1, Major 3).
`Spec-Review-Status` correctly remains `Pending`.

Authoritative reviewer records in that round directory:

| Role | run / ledger seq | Verdict | Result |
|---|---|---|---|
| spec-reviewer-a | `...-a2-seq0964` | PASS | 6 PASS + 1 SKIP, no FAIL |
| spec-reviewer-b | `...-b4-seq0965` | NEEDS_WORK | 1 Critical + 3 Major FAIL |

Files ending in `-superseded-*.json` in the same directory are DISCARDED earlier
launches kept only as audit trail. Do not read them as evidence and do not feed
them to a reviewer.

## Reviewer B's findings (what round 2 must answer)

1. **Critical — CONTRADICTION.** `investigation.md` INV-012 records seven
   top-level plugin packages including `domain`; the human-approved OQ-001
   resolution names only six plugins (plus `mcp`, `installer`). So
   `plugins/domain/**` is neither an owned component path nor in OQ-002's
   cross-cutting list, and the spec's own Edge Cases rule ("a tracked path
   matches no component and no shared rule: block Phase 1") makes AC-005/AC-006
   unsatisfiable as written. **This needs a new human ruling** — ninth
   component, fold into an existing component, or cross-cutting. It is NOT yet
   decided.
2. Major — AMBIGUITY: REQ-013/AC-025's "growing path" is never enumerated
   beyond the single `specs/` example.
3. Major — EDGE-CASE-COVERAGE: three of the five named Edge Cases have no AC
   (unowned path blocks, multi-match blocks, approver-registry change between
   rollback request and effective time).
4. Major — DOWNSTREAM-READINESS: consequence of 1 and 2.

## Remediation already drafted (currently REVERTED — see below)

Commit `4349ae40` contains the round-1 remediation, and commit `ccdc3817`
reverts it. The revert is deliberate, not an abandonment: round-1 evidence must
be produced against the round-1 bytes, and the reviewers cannot be launched
while the reviewed documents differ from the precheck's pinned hashes. **After
round-1 evidence is committed, revert the revert (`git revert ccdc3817`) to
restore the remediation, then run the round-2 precheck.**

That drafted remediation covers, per the owner's ruling of 2026-09-04
(verbatim: 「characteristic override 機構を追加」):

- REQ-004 gains an additive scoped characteristic-override contract; OQ-001 is
  amended to keep eight components; AC-030/AC-031 are its presence and
  rejection oracles.
- AC-032 (reverse-coverage + ownership-digest), AC-033 (premature
  required-enforcement rejection), AC-034 (mid-cooldown registry-cardinality
  change), plus a Field Definitions entry defining "representative change" as
  full-track plugin-code, never docs-only.

It does NOT yet answer reviewer B's `plugins/domain/**` Critical. Round 2 needs
that decision added.

## Two procedural traps (read before running any reviewer)

### 1. Strict ordering: reviewer A -> integrated-summary -> reviewer B

`integrated-summary.json` is derived from reviewer A's checks, and reviewer B
pins that file's sha256 in its own manifest. Running B before A, or re-running A
afterwards, invalidates B's record and forces another B run. This session burned
two B runs on exactly that.

Equally: do not edit `specs/` between the precheck and the reviewers. The
identity-ledger reservation refuses with `REVIEW_CONTEXT_ROUND: manifest freezes
... at a hash this round's precheck did not pin`.

### 2. Reviewers must emit REAL sha256 digests

The precheck's `validate_reviewer_output()` rejects any manifest entry that is
not 64 lowercase hex characters. Both reviewer roles emitted placeholder strings
("not computed by this role", "unavailable-...") on their first runs, which
silently invalidated those records — the failure only surfaces later, as
`prior round contract is malformed or does not require work`. Always instruct
the reviewer explicitly to run `shasum -a 256` on every input it reads.

Related: reviewer B refuses to review at all unless the caller quotes the
`REVIEW_CONTEXT_OK ...` line from its own `--reserve` step verbatim in the launch
prompt (this is the documented fail-closed boundary). Omitting it produces a
BLOCKED record with every check FAIL — a launch failure, not a content verdict.

## The artifact generator

`validate_contract()` in the spec-review precheck driver is the specification
for the three orchestrator-written artifacts. A working generator lives in this
session's scratchpad (`build-a9-round-artifacts.py`, not committed). It reads the
reviewer records and emits `integrated-verdict.json`,
`spec-review-contract.json`, and `spec-review-report.md`. Rules it encodes, all
transcribed from the validator:

- Contract keys exactly: `acceptance_sha256, attempt, feature,
  requirements_sha256, reviewers, round, run_id, schema, stage, verdict,
  warningCount`.
- Reviewer A's contract manifest = requirements, acceptance-tests,
  precheck-result, calibration reference (+ investigation.md when pinned),
  sorted by path. Reviewer B's = that set plus integrated-summary.json.
- requirements/acceptance digests come from the frozen `precheck-result.json`;
  precheck-result and integrated-summary digests are computed live; calibration
  and investigation digests are taken from the reviewer manifests and must be
  identical across both reviewers.
- `integrated-summary.json` schema is `integrated-summary/v1` with keys exactly
  `attempt, generated_at, reviewer_a_checks, reviewer_a_fail_count,
  reviewer_a_pass_count, reviewer_a_skip_count, round, schema`, and
  `reviewer_a_checks` must equal `jq -c '[.checks[] | {id, result, severity}]'`
  of reviewer-a.json exactly.
- Verdict rule: any Critical or Major FAIL -> NEEDS_WORK (BLOCKED in round 3);
  Minor-only -> PASS with `warningCount` in round 3, else NEEDS_WORK; none -> PASS.

If you rebuild this generator, consider promoting it into `scripts/` — every
spec-review round needs it, and hand-writing the contract is what failed here.

## Identity ledger

Sequences 960-965 belong to this feature. 961 is reserved-but-unused (the
launch-failure note in the round directory records why). The chain is intact;
never hand-edit the ledger — always go through `--reserve`.

## Next steps, in order

1. Commit the round-1 evidence (this commit).
2. Get a human ruling on `plugins/domain/**` (reviewer B's Critical).
3. `git revert ccdc3817` to restore the drafted remediation, add the domain
   ruling to it, commit.
4. Run the round-2 precheck with `--edit-summary`, then reviewer A -> summary ->
   reviewer B in that order, then regenerate the artifacts.

Note on this host: the spec-review precheck sometimes hangs under an
orchestrator subprocess environment (a known local-environment class also seen
with `guard-parity` scenario 16 and the spec-review-loop fixtures; it reproduces
on unpatched trees, so it is not caused by any pending change). Run it as a
backgrounded command with output redirected to a log rather than in the
foreground.
