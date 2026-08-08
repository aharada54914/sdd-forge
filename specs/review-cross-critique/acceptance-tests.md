# Acceptance Tests: review-cross-critique

Every AC whose language enumerates branches or quantifies over conditions is
expanded here into its individual branches, each with its own TEST row and its
own concrete assertion, per AGENTS.md `## Rules` item 4 (`AGENTS.md:213-222`,
WFI-014). Where a branch set is covered by one data-driven case instead of one
row each, the reason is stated explicitly in the row and a separate non-vacuity
row pins the property that made the economy safe.

Test types follow this repository's convention: a case that drives a real script
or a real agent launch is **integration**, even when it exercises one file; a
case that reads a document or a JSON fixture without launching a process is
**unit** unless it invokes a real validator, in which case it is integration.
The `epic-136-phase4-mcp` gate recorded a Minor for this mislabelling, so the
tier is stated deliberately.

## Test Matrix

### REQ-001 — a non-triggering run is indistinguishable from today's run

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-001a | AC-001 | integration (real precheck + ledger) | `spec` stage | non-triggering run: exactly 2 reviewer launches and exactly 2 new ledger records |
| TEST-001b | AC-001 | integration | `impl` stage | same, at the impl stage |
| TEST-001c | AC-001 | integration | `task` stage | same, at the task stage |
| TEST-002a | AC-002 | integration (real round directory) | `spec` stage | non-triggering run: round-directory file set **equals** the pre-feature set |
| TEST-002b | AC-002 | integration | `impl` stage | same, at the impl stage |
| TEST-002c | AC-002 | integration | `task` stage | same, at the task stage |

### REQ-002 — the primary blind pass is unchanged

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-003a | AC-003 | integration (`spec-review-precheck.sh`) | `spec` stage | reviewer B's blind-pass manifest **equals** `expected_b` exactly |
| TEST-003b | AC-003 | integration (`impl-review-precheck.sh`) | `impl` stage | same, including the four layer specs |
| TEST-003c | AC-003 | integration (`task-review-precheck.sh`) | `task` stage | same, including `design.md` and `traceability.md` |
| TEST-004a | AC-004 | integration (`spec-review-precheck.sh`) | `spec` stage | reviewer A's blind-pass manifest **equals** `expected_a` exactly |
| TEST-004b | AC-004 | integration (`impl-review-precheck.sh`) | `impl` stage | same, plus the round > 1 previous-round summary (`impl-review-precheck.sh:248-252`) |
| TEST-004c | AC-004 | integration (`task-review-precheck.sh`) | `task` stage | same, at the task stage |
| TEST-005 | AC-005 | integration (real `validate-review-context-set.sh`) | six roles, enumerated | a manifest containing a raw reviewer report is refused for **each** of `spec-reviewer-a`, `spec-reviewer-b`, `impl-reviewer-a`, `impl-reviewer-b`, `task-reviewer-a`, `task-reviewer-b` |
| TEST-006 | AC-006 | integration (mutation) | `validate-review-context-set.{sh,ps1}` | a mutation exempting any single role from `is_forbidden_review_output` makes TEST-005 fail |

### REQ-003 — a relaxation lands everywhere the rule is stated

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-007a | AC-007 | unit (document read) | L1 role prose, six files under `plugins/sdd-review-loop/agents/` | if L3 behaviour changed, every role file's statement of the changed rule changed too |
| TEST-007b | AC-007 | unit (frontmatter read) | L2 `disallowedTools` / `disallowedPaths`, same six files | same, for the capability declaration |
| TEST-007c | AC-007 | integration (real validator) | L3 `validate-review-context-set.{sh,ps1}` | the validator's actual behaviour matches what L1/L2/L5 claim |
| TEST-007d | AC-007 | integration (real precheck) | L4 `{spec,impl,task}-review-precheck.{sh,ps1}` | the contract replay's actual behaviour matches the same claim |
| TEST-007e | AC-007 | unit (document read) | L5 `reviewer-calibration.md`, `spec-review-calibration.md` | the calibration text's statement of the changed rule changed too |
| TEST-008 | AC-008 | unit (document read) | `review-context-boundary.md` | the impl-reviewer-a item is past tense, names `fea5ccd0`, and is absent from the open-items list |

### REQ-004 — the merged-verdict derivation

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-009a | AC-009 | integration (real script) | `spec-review-precheck.sh` | merged verdict + `warningCount` for a fixed reviewer-output pair |
| TEST-009b | AC-009 | integration (real script) | `spec-review-precheck.ps1` | identical result to TEST-009a |
| TEST-009c | AC-009 | integration (real script) | `check-workflow-state.sh` | identical result to TEST-009a |
| TEST-009d | AC-009 | integration (real script) | `check-workflow-state.ps1` | identical result to TEST-009a |
| TEST-010a | AC-010 | integration | a `SUPPORT` verdict in a triggering run | merged verdict unchanged from the severity-derived value |
| TEST-010b | AC-010 | integration | a `SUPPLEMENT` verdict | merged verdict unchanged from the severity-derived value |
| TEST-010c | AC-010 | integration | a `SEVERITY_CHANGE` verdict | merged verdict unchanged **unless** OQ-7 permits, in which case all four derivations of AC-009 reflect it |
| TEST-010d | AC-010 | integration | a `REJECT` verdict | the rejected finding is still counted, per INV-015 — **unless** OQ-8 resolves otherwise |

### REQ-005 — one vocabulary, both runtimes

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-011a | AC-011 | unit (source scan) | the `SUPPORT` token | exactly one spelling across every artifact this feature writes |
| TEST-011b | AC-011 | unit (source scan) | the reject token | exactly one of `REJECT` / `PROPOSE-REJECT`, never both |
| TEST-011c | AC-011 | unit (source scan) | the severity-change token | exactly one of `SEVERITY_CHANGE` / `PROPOSE-SEVERITY-CHANGE`, never both |
| TEST-011d | AC-011 | unit (source scan) | the `SUPPLEMENT` token | exactly one spelling across every artifact |
| TEST-012a | AC-012 | integration (Claude Code path) | fixed input bundle → `SUPPORT` | the Claude path returns `SUPPORT` |
| TEST-012b | AC-012 | integration (Claude Code path) | → reject verdict | the Claude path returns the reject token |
| TEST-012c | AC-012 | integration (Claude Code path) | → severity-change verdict | the Claude path returns the severity-change token |
| TEST-012d | AC-012 | integration (Claude Code path) | → `SUPPLEMENT` | the Claude path returns `SUPPLEMENT` |
| TEST-013a | AC-012 | integration (Codex path) | → `SUPPORT` | the Codex path returns `SUPPORT` |
| TEST-013b | AC-012 | integration (Codex path) | → reject verdict | the Codex path returns the reject token |
| TEST-013c | AC-012 | integration (Codex path) | → severity-change verdict | the Codex path returns the severity-change token |
| TEST-013d | AC-012 | integration (Codex path) | → `SUPPLEMENT` | the Codex path returns `SUPPLEMENT` |
| TEST-014 | AC-012 | integration (cross-runtime) | both paths, same bundle | the two runtimes' verdict sets are equal, asserted as set equality |

### REQ-006 — the round counter

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-015a | AC-013 | integration (real precheck) | `spec`, phase did **not** run | round 4 is refused |
| TEST-015b | AC-013 | integration | `spec`, phase **ran** | round 4 is still refused |
| TEST-015c | AC-013 | integration | `impl`, phase did **not** run | round 4 is refused |
| TEST-015d | AC-013 | integration | `impl`, phase **ran** | round 4 is still refused |
| TEST-015e | AC-013 | integration | `task`, phase did **not** run | round 4 is refused |
| TEST-015f | AC-013 | integration | `task`, phase **ran** | round 4 is still refused |
| TEST-016a | AC-014 | integration (real precheck) | `--edit-summary` rule | rounds 2 and 3 still refuse a missing or whitespace-only summary |
| TEST-016b | AC-014 | integration (real precheck) | inputs-changed rule | a round whose reviewed documents are unchanged is still refused |

### REQ-007 — protected gate files

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-017a | AC-015 | integration (git diff of the delivery) | `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` | not written by an agent; delivered via `human-copy/` with a manifest entry |
| TEST-017b | AC-015 | integration | `plugins/sdd-review-loop/skills/task-review-loop/SKILL.md` | same |
| TEST-017c | AC-015 | integration | `plugins/sdd-review-loop/agents/impl-reviewer-a.md` | same |
| TEST-017d | AC-015 | integration | `plugins/sdd-review-loop/agents/impl-reviewer-b.md` | same |
| TEST-017e | AC-015 | integration | `plugins/sdd-review-loop/agents/task-reviewer-a.md` | same |
| TEST-017f | AC-015 | integration | `plugins/sdd-review-loop/agents/task-reviewer-b.md` | same |
| TEST-018 | AC-016 | integration (real guard) | `sdd-hook-guard.{py,js,ps1,sh}` | an agent write to a protected target is DENIED, and the guard is confirmed loaded |

### REQ-008 — persisted artifacts are gate-validated

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-019a | AC-017 | integration (real validator) | the `.sh` validator | every persisted cross-critique artifact validates |
| TEST-019b | AC-017 | integration (real validator) | the `.ps1` validator | identical acceptance to TEST-019a |
| TEST-020a | AC-018 | integration (mutation) | extra key | rejected |
| TEST-020b | AC-018 | integration (mutation) | missing required key | rejected |
| TEST-020c | AC-018 | integration (mutation) | verdict value outside the REQ-005 enumeration | rejected |

### REQ-009 / REQ-010 — open questions and ENH-21

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-021 | AC-019 | unit (document read, 15 enumerated rows) | OQ-1 … OQ-15 | each of the fifteen carries a resolution with a named human decider, or an explicit do-not-proceed |
| TEST-022 | AC-020 | unit (document read) | `design.md` | no decision on OQ-1 … OQ-15 lacks an attributed human resolution |
| TEST-023 | AC-021 | unit (document read) | the delivery's ENH-21 statement | names `skills/adversarial-review`, its self-exclusion, the vocabulary difference, and the define/consume/avoid relationship |

## Test Details

### TEST-001a/b/c (AC-001) — the launch and reservation count, per stage

Drive a full non-triggering round at each stage against fixture artifacts, and
assert two counts: the number of reviewer agent launches, and the number of
records appended to `reports/review-context/identity-ledger.json`. Both must be
exactly 2.

**Why the reservation count and not only the launch count.** A design that
reserves an identity before deciding whether to fire leaves an orphan ledger
record on every non-triggering run (requirements Edge Case 4). Orphans are
legitimate and must not be treated as tampering
(`review-context-boundary.md:90-101`), so no existing gate would flag them —
which means a launch-count-only test would pass against a design that grows the
ledger on every routine run. The ledger is append-only and chain-verified
(`validate-review-context-set.sh:239-258`), so this is a cheap, exact count.

**Why three stages and not one.** The three stages differ in the one variable
this test is sensitive to. Their sanitized bridges differ (`reviewer_a_checks`
with severities at the spec stage, `reviewer_a_check_ids` at impl and task —
`check-workflow-state.sh:508-510`), their manifests differ (four layer specs at
impl and task), and under the risk-tier reading of OQ-1 the trigger predicate is
not even evaluable at the spec and impl stages (requirements Edge Case 3). A
spec-stage-only result would not generalise to either of the others.

### TEST-002a/b/c (AC-002) — set equality, not containment

Compare the round directory's file set against the pre-feature set captured from
the same fixture at the parent commit. **Set equality.** A containment assertion
passes against a design that writes an empty `cross-critique.json` on every
routine run, which is exactly the cost increase issue AC 2 forbids.

### TEST-003a/b/c and TEST-004a/b/c (AC-003, AC-004) — exact manifest equality

Assert against the precheck's own computed expectation, not against a
hand-written list: `expected_a` at `spec-review-precheck.sh:231-234` and
`expected_b` at `:235`, compared with `==` at `:240`. A hand-written expected
list in the test would drift from the script and turn the test into a decoration
— the same defect class as a duplicated constant.

The three stages are separate rows because their expected sets are genuinely
different documents: the impl stage adds `design.md` and the four layer specs,
the task stage adds `tasks.md` and `traceability.md`, and impl round > 1 adds the
previous round's summary (`impl-review-precheck.sh:248-252`).

### TEST-005 (AC-005) — six roles, one data-driven case, with the reason stated

Six enumerated fixtures — one per existing reviewer role — each a manifest
containing `reports/spec-review/<f>/attempt-1/round-1/reviewer-a.json`, each
asserted to be refused with the `forbidden raw reviewer report` failure.

They are six fixtures in one case rather than six independent cases because the
enforcement is a single role-independent code path:
`is_forbidden_review_output` (`validate-review-context-set.sh:57-61`) is applied
unconditionally at `:287-288`, before `path_is_authorized` is consulted at all.
Six near-identical cases would exercise the same three lines six times.

That economy is only safe if the role-independence is itself pinned, which is
TEST-006's job. Without TEST-006 the six fixtures could all pass against an
implementation that had grown a per-role exception list — the exact shape a
cross-critique carve-out would take.

### TEST-006 (AC-006) — the non-vacuity check for TEST-005

Mutate `is_forbidden_review_output` (or its call site) to exempt exactly one
role, and assert TEST-005 fails. A guard that cannot be made to fail is not a
guard.

Per BL-007 (`AGENTS.md:190-197`, WFI-012), this suite must not embed the
contiguous vocabulary strings it scans for in its own source: assemble
`SUPPORT`, the reject token, the severity-change token and `SUPPLEMENT` at
runtime from non-contiguous literals, so the suite is never a false-positive
target of a detection gate this repository runs over that vocabulary.

### TEST-007a–e (AC-007) — five layers, five rows

The five layers are five separate files with no mechanism binding them, so they
get five rows rather than one aggregate:

| Row | Layer | Why it can drift alone |
|---|---|---|
| TEST-007a | L1 role prose | the four impl/task role files are protected (INV-020) and can only be changed by a human, so they lag by construction |
| TEST-007b | L2 capability frontmatter | lives in the same protected files but is machine-readable, so it can be checked even when the prose cannot be edited |
| TEST-007c | L3 validator | **writable by an agent** — this is the layer most likely to move first |
| TEST-007d | L4 contract replay | also writable, and has its own PowerShell twin that can lag the shell |
| TEST-007e | L5 calibration text | writable, and is a hash-bound reviewer input, so drift here misleads a live reviewer |

The asymmetry in the middle column is the whole point: L3 and L4 are agent-
writable while L1 and L2 are not (INV-020), which is the exact gradient that
produced INV-023. An aggregate check would pass on a delivery that moved L3 and
L4 and left L1, L2 and L5 stating the old rule.

### TEST-008 (AC-008) — the live staleness this feature must not inherit

Assert that `review-context-boundary.md`'s treatment of the impl-reviewer-a
contradiction is past tense, names commit `fea5ccd0`, and does not appear in the
`## Open items for a human` list at `:158-171`.

This is independent of the cross-critique design. `impl-reviewer-a.md:43` no
longer contains the prohibition the document describes, and `:45-48` carries the
Issue #143 carve-out explicitly — but the reference document, which every
reviewer role names as required reading (`spec-reviewer-a.md:49-54`,
`spec-reviewer-b.md:51-56`), still tells a reviewer the contradiction is open.
Verified directly against both files rather than taken from either one.

### TEST-009a–d (AC-009) — four derivations, four rows

Feed one fixed pair of reviewer outputs to each of the four independent
derivations and assert all four produce the same merged verdict and
`warningCount`. Two of the four are PowerShell; a shell-only assertion is the
dual-runtime gap BL-004 exists to prevent, and `check-workflow-state.ps1:679-680`
shows the twin carries its own copy of the stage-branching logic, so it can drift.

### TEST-010a–d (AC-010) — the four verdicts are not symmetric

Four rows because the four verdicts propose four different things to the
arithmetic, and a single "cross-critique does not move the verdict" case would
exercise whichever one the fixture happened to use:

- **(a) `SUPPORT`** adds no new arithmetic input. The assertion is that the
  merged verdict is unchanged — which it must be under every resolution of OQ-7.
- **(b) `SUPPLEMENT`** adds evidence to an existing finding without changing its
  severity. Same expectation, different code path if supplements are persisted
  as new finding entries.
- **(c) `SEVERITY_CHANGE`** is the only verdict that proposes a *different*
  severity, and severity is the sole input to all four derivations
  (`spec-review-precheck.sh:255-267`; `check-workflow-state.sh:517-544`). This is
  the row that fails if OQ-7 was resolved silently.
- **(d) `REJECT`** is the only verdict that proposes *removing* an input, which
  is what `impl-review-loop/SKILL.md:261-262` forbids the orchestrator to do.
  This is the row that fails if OQ-8 was resolved silently.

Rows (c) and (d) are conditional on OQ-7 and OQ-8 respectively. That is stated
in the row rather than resolved: the assertion is "unchanged **unless** the
recorded human resolution says otherwise, in which case all four derivations of
AC-009 reflect it", which is checkable either way and is not satisfiable by an
undocumented change.

### TEST-011a–d (AC-011) — four tokens, four rows

One row per verdict token, each asserting that exactly one spelling appears
across every artifact the feature writes or edits. Four rows rather than one
"the vocabulary is consistent" check, because the realistic failure is a
half-migration — a SKILL updated to `REJECT` while a template still says
`PROPOSE-REJECT` — and an aggregate consistency check also passes against a
document that simply omits one of the four tokens entirely.

Rows (b) and (c) are phrased as "exactly one of X / Y, never both" rather than
naming a winner, because OQ-9 has not been resolved. The test is written so it
passes under either resolution and fails under a mixture.

Per BL-007, the scanner must not embed the contiguous tokens in its own source.

### TEST-012a–d, TEST-013a–d, TEST-014 (AC-012) — two runtimes × four verdicts, plus equality

Eight enumerated cases plus one cross-runtime set-equality assertion. Expanded to
eight because "both runtimes agree" is unfalsifiable if one runtime is only ever
exercised for one of the four verdicts, and the addendum's requirement is
specifically that both return **the same 判定** — a claim about all four.

**Constrained by OQ-12 and stated as such.** No reviewer role exists for Codex
(INV-024), the guard refuses agent creation of one, and any new role requires
`developer_instructions`. Under a shared-SKILL design (the addendum's own first
suggestion) TEST-013a–d are runnable. Under a new-Codex-role design they are
runnable only after a human places the file, and the task plan must say so rather
than discovering it at implementation time.

### TEST-015a–f (AC-013) — the cross-product, expanded rather than sampled

Three stages × two states (the cross-critique phase ran / did not run), because
the failure this guards against is a placement that consumes a round **only on
the triggering path**. A did-not-run-only test cannot see it. A spec-stage-only
test would miss it entirely if OQ-2 resolves to per-stage divergence, which
INV-005/INV-006's bridge asymmetry makes plausible.

The assertion in every row is the same: `round 4` is refused, i.e.
`spec-review-precheck.sh:35`'s `round must be between 1 and 3` still fires. What
differs between rows is the state the fixture is driven into first.

### TEST-016a/b (AC-014) — two rules, two rows

(a) `--edit-summary` required and non-empty for rounds 2 and 3
(`spec-review-precheck.sh:36-38`); (b) a round refused when neither reviewed
document changed (`:286-287`). Two rows because they are two independent guards
in the same script and rule (b) is the one a cross-critique placement is most
likely to need relaxed — a cross-critique pass changes no reviewed document by
construction (INV-003).

### TEST-017a–f (AC-015) — per protected target

Six rows, one per protected file, rather than one aggregate. The aggregate
("no protected file was written by an agent") passes against a delivery that
quietly dropped one target's change altogether; the per-target form asserts both
halves — not agent-written **and** present in the `human-copy/` manifest — so a
silently-dropped target fails.

The membership of each of the six must be re-derived from
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` at the time
the test runs, by `endswith()` against the repo-relative path, per the
re-verification instruction in requirements REQ-007 (AGENTS.md sweep 3,
`AGENTS.md:203-211`, WFI-013). A test carrying its own frozen copy of the
protected list is the same defect as a test carrying its own copy of a constant.

### TEST-018 (AC-016) — the non-vacuity check for TEST-017

Assert that the guard actually denies an agent write to a protected target,
**and** that the guard is loaded. `sdd-hook-guard.py:952` sets
`_PROTECTED_GATE_SUFFIXES = ()` when the generated invariants module fails to
import, in which case every AC-015 row passes trivially. The loaded-ness check is
what makes the six rows above mean something.

### TEST-020a/b/c (AC-018) — three malformation classes, three rows

A `jq keys == [...]` equality check plus an enumeration check has three distinct
failure paths, and a single "malformed input is rejected" case exercises at most
one of them: (a) extra key — caught by `keys ==` on the left; (b) missing key —
caught by `keys ==` on the right; (c) an out-of-enumeration verdict value — not
caught by `keys ==` at all, and caught only if the enumeration check exists.
Row (c) is the one that fails against an implementation that validated shape but
not values, which is the failure `spec-review-precheck.sh:153-155` guards against
for the existing `severity` field.

### TEST-021 (AC-019) — fifteen rows, one per Open Question

Fifteen enumerated rows: OQ-1 through OQ-15. Each asserts that the question
carries either a resolution naming the human who decided it, or an explicit
statement that the feature does not proceed on that path.

Enumerated rather than counted, because a count check ("fifteen resolutions
exist") passes against fifteen rows of which several say nothing substantive, and
because the questions are not interchangeable: OQ-1 blocks OQ-2, OQ-5 and OQ-7
cannot be answered independently (requirements Edge Case 5), and OQ-15 blocks
task planning outright.

### TEST-022 (AC-020) — the negative half

Scan `design.md` for any decision on OQ-1 … OQ-15 not attributed to a recorded
human resolution. This catches the actual failure mode: a design that answers an
open question in prose while the Open Question list still calls it open. AC-019
alone does not catch it — a design can carry fifteen resolutions *and* an
unattributed sixteenth decision.

## Notes

- **Every `file:line` in this document must be re-verified at implementation
  start.** Citations accurate when written and stale when used are a recorded,
  recurring defect class (WFI-011, `AGENTS.md:138-146`). One instance was caught
  while writing this specification: `review-context-boundary.md:110-132`
  describes a contradiction that commit `fea5ccd0` resolved (INV-023), and
  TEST-008 exists because of it.
- **BL-007 applies to this whole suite** (`AGENTS.md:190-197`, WFI-012). Any case
  asserting against the literal verdict vocabulary must assemble the marker at
  runtime from non-contiguous literals. The suite must never be a false-positive
  target of the detection gates this repository runs over that vocabulary.
- **BL-008 applies at delivery** (`AGENTS.md:224-236`, WFI-015). Several rows
  here — TEST-009b, TEST-009d, TEST-013a–d, TEST-019b — execute only on the
  Windows CI leg or only once a Codex role exists. If this delivery makes a
  previously-SKIPped branch newly reachable, the implementation report must name
  the branch and the environment and either exercise it or flag it as pending
  first real execution.
- **No case may invoke a live vendor CLI, a network, or a real credential.** A
  test that cannot run in CI is not a regression signal.
- **Rows conditioned on an Open Question state the condition rather than
  assuming an answer** — TEST-010c (OQ-7), TEST-010d (OQ-8), TEST-011b/c (OQ-9),
  TEST-013a–d (OQ-12). Each is written to pass under either resolution and fail
  under an undocumented one. That is the point: the suite must not become the
  place a design decision gets made by default.
