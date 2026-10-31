# Implementation Policy Review Report: epic-194-a6-lite-integration — Round 1 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-194-a6-lite-integration |
| Round | 1 of 3 |
| Attempt | 2 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-08-25T03:04:39Z |

This round is a post-implementation provenance re-review
(`impl-review-precheck.sh ... --provenance-rereview`) opened after the
2026-08-24 and 2026-08-25 human-ruled amendments to this package. The two
reviewers ran blind: reviewer B received only `integrated-summary.json`
(reviewer A's check IDs and counts), never reviewer A's findings text.

## Reviewer-A Findings (Structural Soundness)

Verdict: PASS. All checks PASS or SKIP; no findings.

Check results:

- `ARCH-COVERAGE` — PASS
- `NO-CIRCULAR-DEPS` — PASS
- `DATA-COVERAGE` — PASS
- `API-COVERAGE` — PASS
- `SECURITY-COVERAGE` — PASS
- `FRONTEND-BACKEND-CONSISTENCY` — SKIP
- `TEST-STRATEGY-COVERAGE` — PASS
- `NO-UNDEFINED-COMPONENT` — PASS
- `ADR-PRESENT` — PASS
- `DESIGN-SYSTEM-CONFORMANCE` — SKIP
- `DOMAIN-CONFORMANCE` — SKIP

## Reviewer-B Findings (Implementability/Risk)

Verdict: NEEDS_WORK.

Check results:

- `DECISION-JUSTIFIED` — PASS
- `OPEN-QUESTIONS-RESOLVABLE` — PASS
- `ASSUMPTIONS-VALID` — FAIL
- `NO-REQ-CONTRADICTION` — PASS
- `PERF-ADDRESSED` — PASS
- `DEPLOYMENT-CONCRETE` — FAIL
- `MIGRATION-PLANNED` — PASS
- `INTEGRATION-IDENTIFIED` — PASS
- `DESIGN-WITHIN-SCOPE` — PASS
- `VERIFICATION-PATH-CONCRETE` — PASS
- `DOMAIN-CONFORMANCE` — SKIP

Findings (verbatim):

#### ASSUMPTIONS-VALID (Major)

design.md's and investigation.md's central 'still Phase 1, no live contracts/*.schema.json exists anywhere' premise (investigation.md INV-013: 'No contracts/*.schema.json artifact any Foundation epic (A1-A6) would define exists anywhere in any readable worktree yet — every epic, including this one, is still Phase 1', cited verbatim by design.md's header ('exactly like every sibling Foundation epic's own Phase 1 package'), Non-goals ('or do not yet exist anywhere (investigation.md INV-013)'), Cross-Layer Dependencies ('blocked until A2's own Phase 2 lands (contracts/capability-registry.schema.json does not exist yet, investigation.md INV-013)'), and the Components table ('not yet applicable — file does not exist')) is FALSE as of the current worktree state, independently verified: `contracts/capability-registry.schema.json`, `contracts/capability-registry.json`, `contracts/capability-summary.schema.json`, `contracts/facet-manifest.schema.json`, and `contracts/lite-upgrade-reason-catalog.json` all exist, are git-tracked, and were committed on 2026-07-23 (`e48c9008`, 'feat(epic-190-a2): author Capability Registry schema, instance, and lite-upgrade-reason catalog (T-001)') and 2026-08-17/2026-07-23 respectively (`de5220c6`, `a3a993bc`) — all predating this 2026-08-25 impl re-review by days to weeks, and all landing after investigation.md's own stated snapshot commit (`b085ec76`, 2026-07-19). Worse, `contracts/capability-registry.schema.json`, `contracts/capability-registry.json`, and `contracts/lite-upgrade-reason-catalog.json` are now themselves already listed in the live `plugins/sdd-quality-loop/references/guard-invariants.json`'s `protected_gate_suffixes` array (lines 46-48) — i.e. already agent-write-denied, R-10-protected files today — a fact design.md's Protected-File Statement, which otherwise claims to be a live-repository-snapshot re-verification of exactly this kind of fact for its own four `sdd-lite` targets and the CI-workflow fifth target, does not mention at all for these Registry/catalog targets. The live schema's own `lite_policy` definition (`eligible`, `upgrade_reasons` only, no `required_lite_checks`) does still match the 'current, v1, frozen' shape design.md assumes it is extending, so the technical content of REQ-001 is not itself falsified — but the load-bearing 'Epic A2's own Phase 2... this feature's own build scope never touches contracts/** at all' framing, repeated across Non-goals/Roles/Cross-Layer Dependencies/Components, is now stale: Epic A2's Phase 2 (T-001) and Epic A4's Phase 2 (T-001/T-002) have already landed, and the 'future A2-owned revision task' that would apply REQ-001's v1.1 lite_policy extension would now need to go through a human-copy application against an already-protected file, a consideration this design nowhere addresses. Concrete failure mode: a downstream implementer or reviewer trusting design.md's 'blocked until A2's own Phase 2 lands' / 'file does not exist' language will misjudge REQ-001's actual prerequisite state and the protected-file application path its own eventual live edit will require. Despite this investigation.md document being actively amended twice more (2026-08-24, 2026-08-25) after these files landed, none of those amendment passes re-verified or corrected this specific, easily-falsifiable, and pervasively-cited claim.

#### DEPLOYMENT-CONCRETE (Major)

design.md's own '## Deployment / CI Plan' section (two bullets) states only that the existing generate-gate-capabilities.py --check drift cycle re-runs unmodified and that a future test-pair wiring 'does not itself edit that file' — it names no CI pipeline change at all for the staged human-copy append to `.github/workflows/test.yml` that this same document's own Components table and Protected-File Statement commit to as the fifth of five declared payload targets (requirements.md AC-010/AC-031; design.md Protected-File Statement 'This runner's own required contract' item 2). Per investigation.md's own amendment record (## Amendment Re-Review Context, 'Amendment record extension (appended 2026-08-25)'), the 2026-08-25 human ruling required security-spec.md and infra-spec.md's equivalent CI/CD sections to be amended with an explicit reconciling paragraph naming the staged append and its human-apply path precisely because their prior 'unmodified'/'byte-unchanged' wording was reported as a blocker against the five-target payload set — both layer specs now carry that paragraph (security-spec.md Authentication Flow, 'CI workflow, scoped (2026-08-25 ruling)'; infra-spec.md CI/CD Sequence, same heading). design.md's own Deployment / CI Plan section, which states the identical 'this design does not itself edit that file' claim, was not given the same reconciling treatment and still makes no mention anywhere in that section of the CI-workflow deliverable this feature's own five-target payload set now commits to. A reader relying on the canonical Deployment / CI Plan section alone would not learn that this feature's own declared deliverables include a CI-workflow staging change.

## Proposed Changes

Both findings land on frozen, human-approved documents (`design.md`, and the
`investigation.md` claim design.md cites). Neither is remediated here. They are
recorded verbatim for the human to rule on, because both go to whether the
2026-08-24/25 amendments are *correct*, not merely whether they are new:

1. **ASSUMPTIONS-VALID.** Reviewer B reports that INV-013's "no
   `contracts/*.schema.json` exists anywhere yet — every epic is still Phase 1"
   premise, cited by design.md's header, Non-goals, Cross-Layer Dependencies and
   Components table, is false against the current worktree: five `contracts/`
   artifacts are tracked and committed (2026-07-23 … 2026-08-17), and three of
   them are already listed in `guard-invariants.json`'s
   `protected_gate_suffixes`. Reviewer B states the technical content of REQ-001
   is not falsified — the live `lite_policy` shape still matches what design.md
   assumes it extends — but that the "blocked until A2's own Phase 2 lands" /
   "file does not exist" framing is stale, and that the eventual live edit would
   now need a protected-file application path design.md nowhere addresses.

   A ruling is needed on whether to correct the framing in design.md (and the
   INV-013 claim it rests on), or to record why the stale framing is acceptable.

2. **DEPLOYMENT-CONCRETE.** Reviewer B reports that the 2026-08-25 ruling's
   reconciling paragraph — which names the staged `.github/workflows/test.yml`
   append and its human-apply path — was added to `security-spec.md` and
   `infra-spec.md` but *not* to design.md's own `## Deployment / CI Plan`
   section, which carries the identical "this design does not itself edit that
   file" claim. This is a left-behind sibling of the very amendment that was
   supposed to close the CI-workflow scoping gap.

   A ruling is needed on whether the 2026-08-25 scoping ruling extends to
   design.md's Deployment / CI Plan section.

Reviewer A independently reached PASS on all eleven structural checks and, on
the same amendment material, judged the four-to-five payload propagation
internally consistent (the four sites left at "four" are `sdd-lite`-owned counts,
a different predicate from the payload count) and the CI-workflow scoping
"defensible, non-evasive", applied identically in both layer specs. Reviewer A
did not examine design.md's Deployment / CI Plan section against the layer specs'
amended CI/CD sections; that comparison is reviewer B's own.

## Next Steps

1. Human ruling on the two Major findings above. Do not edit design.md or
   investigation.md without one — both are frozen, hash-bound, human-approved
   documents, and finding 2 is itself a report that an earlier amendment was
   applied incompletely.
2. After the ruling and any resulting edits, re-invoke the impl review at
   attempt 2 round 2 with `--edit-summary`, reserving fresh ledger identities
   for both reviewers.
3. Task review remains blocked: it is downstream of a passing impl stage, and
   this round did not pass.
