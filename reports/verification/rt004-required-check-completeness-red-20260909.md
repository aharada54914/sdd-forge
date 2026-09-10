# RT004 required-check completeness regression

Date: 2026-09-09
Ticket: RT-20260908-004 (open)
Status: RED reproduced; production correction and independent review pending

## Scope and source evidence

The saved Bash candidate
`reports/verification/adr-workflow-bash-history-candidate-20260909.patch`
defines `review` with a nonempty checks array, unique IDs, recognized results
and internally derived verdict. It does not require the role's complete ID
sequence. This is a static candidate finding, not execution of that candidate.

Current role definitions require eleven ordered IDs:
`plugins/sdd-review-loop/agents/impl-reviewer-a.md:328` and
`plugins/sdd-review-loop/agents/impl-reviewer-b.md:325`.
However, the immutable historical fixture at
`reports/impl-review/workflow-state-integrity/attempt-1/round-2/`
has nine A checks and ten B checks. Its output schema names still end in
`/v1`. Therefore enforcing today's eleven IDs indiscriminately would reject
existing valid history, and selecting a profile by the supplied array length
would let an attacker choose a weaker profile. Neither is an acceptable fix.

## Test-first change

Added `missing-b-check` to `tests/impl-review-adr-inputs.tests.sh` for both
runtimes. Start with the existing extended-history positive fixture, assert
that B has ten checks including one PASS for DECISION-JUSTIFIED, then remove
only that check. Assert the result has nine PASS checks and a PASS verdict.
No failure counts, A summary, manifest, identity or precheck pins are changed.
The intended rejection is thus not explained by a stale summary hash or a
contradictory aggregate. Fixture files are temporary data; original historical
records and original-path executable validators remain unchanged.

Command:

```bash
rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only
```

Observed for both Bash and macOS PowerShell:

```text
ok: workflow history bash legacy
ok: workflow history bash equal-layer
not ok: workflow history bash missing-b-check (exit=0 expected=1 baseline=true)
workflow-state: ok
ok: workflow history pwsh legacy
ok: workflow history pwsh equal-layer
not ok: workflow history pwsh missing-b-check (exit=0 expected=1 baseline=true)
workflow-state: ok
```

This is a real missing-rejection RED, not a setup error and not a PASS.
The test calls the original Bash and PowerShell workflow validators with
`--opening impl:1:3`; it does not execute an extracted or copied candidate.
PowerShell on this host is not native Windows verification.

The complete workflow-only run terminated with exit 1:
`ADR workflow history: passed=10 failed=36` (five positive cases and eighteen
failed rejection cases per runtime). The two missing-b-check failures are
newly added cases; the other failures are existing RT004 gaps, not newly
introduced production regressions. Full output was captured in this turn's
terminal tool responses. Temporary fixture logs were removed by the suite's
existing cleanup trap; no retained raw-log file is claimed.

## Required correction boundary

- Preserve the no-extension historical validation semantics required by RT004.
- For new ADR-extension review contracts, bind a complete role-check contract
  at precheck/launch and validate it at persisted consumption. A reviewer must
  not choose the permitted list, and a caller-controlled version label alone
  must not authorize a weaker list.
- Resolve how the new extension fixtures acquire that contract before adding
  a blanket eleven-ID rule; cover full positive A/B sequences and each missing,
  duplicate, unknown, wrong-case and reordered ID in both runtimes.
- Separately reconcile the role's required-input-missing BLOCKED hard rule
  with verdict derivation. Do not rewrite past BLOCKED output or accept every
  arbitrary BLOCKED result as valid.
- No protected implementation change is applied by this regression. The
  ticket requires independent security/contract review before such application.

The test changes passed scoped whitespace checking. No formal review, CI,
task Done decision, ticket resolution, commit, push or merge is claimed.

## Candidate correction after independent design review

The independent agent `/root/rt004_check_contract_review` recommended using
extension presence (including an empty array) to select fixed A11/B11 ordered
lists for ADR-extension v1, leaving the no-extension branch unchanged. It
also required stable lists across future role revisions. Its inspection was
partly blocked by the live hook; it stopped the denied command and explicitly
relied on parent-supplied excerpts for branch and inventory evidence. This is
a limited independent candidate review, not a formal gate or full security
approval. A scoped parent search found no adr_inputs member in existing
implementation-review contracts/prechecks; that inventory is not a runtime
protection verdict.

Updated only synthetic extension fixtures to append A's design-system/domain
SKIPs and B's domain SKIP. Recomputed A's summary ID sequence and SKIP count.
Original no-extension historical data is untouched. The missing-B regression
now asserts eleven checks before removing DECISION-JUSTIFIED and ten after.
The complete original-path suite was rerun and again terminated exit 1 with
10 passed / 36 failed, including both new-format missing-B cases. This remains
RED; no candidate executable was run.

Candidate patch DATA was then amended with exact A/B ID sequence equality in
Bash and ordinal per-position equality after a count check in PowerShell.
Both standalone and composed candidates were synchronized:

| Candidate under reports/verification/ | SHA-256 |
|---|---|
| adr-workflow-bash-history-candidate-20260909.patch | 17c51d788c96fed38accabc7258fe2a54a00966b9109c16171a9f7da190a3eee |
| adr-workflow-bash-snapshot-composed-candidate-20260909.patch | fee3d720fc6b3517e5e4a9fe474d86bc838d6b62f684cec2b61e5b4da7ebff34 |
| adr-workflow-powershell-output-binding-candidate-20260909.patch | d05a428119160fdf889ed4e1294b6573a302e0c7ff3dc8e1cd70582765bee849 |
| adr-workflow-powershell-history-composed-candidate-20260909.patch | 9763f14b18310c9f83cd29788c849a3e272608e380f4ff65596d5bf4fe3cbfb1 |

Test source SHA-256 after this update:
`5fce2b16fee6491ec4c101e964a2d8f7e22d395aadd1395dfff2807180c90a6e`.
`git apply --numstat` parsed all four patches successfully without applying
them. Scoped test-source whitespace checking exited 0. One intermediate
composed-patch edit failed to match a hunk because edit contexts were supplied
out of file order; it made no change. The ordered patch edits succeeded and
the subsequent four-patch parse is the final result.

The same independent reviewer examined the supplied code delta and identified
no new defect in the exact-equality logic, conditional on the supplied arrays
and extension-only dispatch. It explicitly did not claim executable behavior,
full consumer parity or resolution of the BLOCKED inconsistency. No formal
gate status was changed.

Remaining before protected application: expand the mutation matrix to every
required ID and both roles; carry the same extension contract into all actual
consumers; resolve required-input BLOCKED semantics; complete independent
security/contract review of the full composed bundle. Human application and
original-path GREEN, native Windows evidence, formal review, mandatory CI and
main integration are still required. These four patches overlap by design:
standalone components and composed alternatives must not be applied together.

## Exhaustive matrix preparation and invalidated execution

Added thirty synthetic mutation cases per runtime: omission of each of eleven
check IDs for each reviewer, plus duplicate, unknown, wrong-case and reordered
IDs for each reviewer. The test independently asserts the resulting ID array
and regenerates summary counts, summary pins and integrated findings.

Session 36277 ran while its source was subsequently edited and terminated
with exit 2 and a shell syntax error after emitting case results. This is an
invalidated execution, not a completed suite result. Its A check-index-8
omission was rejected for an unrelated missing-manifest-input reason; the
test correctly did not count that rejection as a pass.

The fixture was corrected to retain a separate synthetic Major FAIL in B
when mutating A. This keeps the failed-round opening route selected even
after A's only FAIL is removed. This is temporary fixture data, not a claim
about any historical reviewer finding. The independent reviewer, relying on
supplied excerpts rather than execution, found this addresses the masking
path, but requested a positive anchored baseline and explicit post-mutation
binding assertions before candidate results can establish validity. These
additional controls remain pending; no formal gate approval is implied.

The corrected source passed `bash -n` and has SHA-256
`10f8864be7b73a6b863767ef7edaf940bad6249a097c25df746917d54a85091c`.
A fresh original-path run started as session 99950 with source edits paused
until termination. Its result must be recorded separately after completion.

Session 99950 subsequently terminated with exit 1, reporting **10 passed /
96 failed** across Bash and macOS PowerShell (106 cases). All thirty new
mutation cases per runtime returned 0 where rejection was required, including
A index 8: the unrelated rejection observed in the invalidated run no longer
masks that case. This is completed original-path RED evidence against the
current validator, not candidate GREEN or native Windows evidence. The source
was not edited during this execution. Additional positive-anchor and explicit
binding controls requested above are still required for the candidate test
claim. Test output is in the execution transcript, not a retained raw-log file.

## Positive-anchor controls and binding assertions

Added check-a-control-0 and check-b-control-0 before the corresponding mutation
series. Each control follows the same evidence regeneration path without
mutating IDs. Control success is tracked separately for A/B and reset for each
runtime; a failed control prevents any mutation in that series being counted
as a pass. Explicit jq assertions check the independent B Major FAIL for A
mutations, integrated findings/verdicts against both outputs, A summary counts
and IDs, B summary hash and B contract/output manifest equality.

Source SHA-256: `6932b2947fb7d0b547c82f34a576e6825c9425c23bc5b587aecc70468651b189`.
Syntax and scoped whitespace checks exited 0. Original-path session 63696
started with source edits paused until it terminates. The limited independent
reviewer assessed the supplied explanation as addressing its earlier concern,
conditional on runtime/role-specific control initialization and gating. It did
not read the actual delta because of the earlier guard denial, and did not
claim a formal gate result.

A further read-only rg comparison of required-check/BLOCKED rules in candidate
patches and role documents was rejected by PreToolUse. That command did not
run and was not retried via another executor or renamed target. The required
full contract comparison and independent security review remain incomplete.

Fresh GitHub inspection found eleven open PRs. PR 400 at
8fa3eb8561d6f59b692ec574900f87e181145928 has successful published CI but is
Draft, REVIEW_REQUIRED, with no submitted reviews. Its PR body and
RT-20260906-001 explicitly retain the independent quality-gate requirement;
CI success alone is not merge authorization under the requested conditions.
No CI run in the returned check lists was queued or in progress. No GitHub
mutation was made, and no blocked PR was treated as merge-ready.

## Human read-only comparison after guard denial

The RT004 ticket requires stopping a denied operation and preparing exact
human instructions rather than bypassing the guard. Run this in a terminal
and send the full output. It only reads the listed files; do not apply patches,
change review verdicts, commit, push or merge as part of this step.

```bash
cd /Users/jrmag/sdd-forge || exit 1
rtk proxy rg -n 'check_ids|expectedIds|Required input missing|BLOCKED|review\(' \
  reports/verification/adr-workflow-bash-history-candidate-20260909.patch \
  reports/verification/adr-workflow-powershell-output-binding-candidate-20260909.patch \
  plugins/sdd-review-loop/agents/impl-reviewer-a.md \
  plugins/sdd-review-loop/agents/impl-reviewer-b.md
printf 'comparison exit: %s\n' "$?"
```

This is the denied comparison, not a replacement execution route. Its output
alone will not prove candidate behavior or complete independent review.
Fresh issue inventory also returned 26 open issues; no issue was closed based
on partial tests, obsolete branch cleanup or successful diagnostic-only CI.

## Completed controlled RED execution

Session 63696 terminated exit 1: **14 passed / 96 failed**, 110 cases total
across Bash and macOS PowerShell. Both new positive controls passed in each
runtime. All sixty required-ID mutations still returned 0 where rejection
was required, after the fixture consistency assertions succeeded. This
strengthens the RED evidence without converting any negative result to PASS.
No test-source edit occurred during this run. Candidate GREEN, native Windows,
complete independent review, formal review and main integration remain pending.
