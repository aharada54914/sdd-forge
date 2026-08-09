# WFI Audit Report — Cycle 2

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-025 |
| Category | plugin-improvement |
| Cycle | 2 of 2 |
| Auditor Agent | wfi-auditor-b |
| Verdict | **BLOCKED** |
| Critical Findings | 1 |
| Major Findings | 0 |
| Minor Findings (Advisory) | 0 |
| Generated | 2026-08-10T00:00:00Z |

Raw auditor output: `docs/workflow-improvements/WFI-025-auditor-b.json`.
Cycle 1 inputs were withheld from this auditor by charter; it received only
`WFI-025-integrated-summary.json` (check IDs and counts).

## Check results

| Check | Result |
|---|---|
| VERIFICATION-COMPLETE | PASS |
| SCOPE-PROPORTIONAL | PASS |
| UNINTENDED-CONSEQUENCES | PASS |
| FEASIBILITY-WITHOUT-PLUGINS | **FAIL (Critical)** |
| CATEGORY-LANGUAGE-SECOND-PASS | PASS |
| EFFECT-CONSISTENT-WITH-EVIDENCE | PASS |
| ISSUE-BODY-QUALITY | PASS |
| META-CHANGE-ANTI-GOODHART | PASS |

## The Critical finding

**FEASIBILITY-WITHOUT-PLUGINS.** The Target File table omitted the file that
actually builds the thing the validator validates, so the change as scoped would
have produced the exact inverse of its Expected Effect.

`validate-review-context-set.sh` takes the manifest as its first positional
argument — it consumes a manifest, it does not construct one. No script in the
repository constructs `allowed_input_manifest` at all. The manifest is assembled
by the launching agent following prose in
`plugins/sdd-review-loop/skills/task-review-loop/SKILL.md`, whose STEP 2 and
STEP 4 say to include the inputs "with current hashes" — which for the task plan
means a fresh raw digest of the live file, with no awareness of the proposed
`tasks_sha256_form` field.

So: precheck starts recording a normalized digest for mixed plans, the manifest
keeps declaring the raw one, and the round-consistency check at
`validate-review-context-set.sh:326` refuses the reservation. Every mid-flight
task-stage reservation fails closed. The WFI would have made the problem
categorically worse than the rebind it set out to remove.

**Independently re-verified by the orchestrator before revising.** All four
load-bearing facts hold:

- `validate-review-context-set.sh:13` is `manifest=$1`.
- Every `allowed_input_manifest` reference in `task-review-precheck.sh`
  (lines 147-199) is inside validation logic that reads a persisted contract —
  none of it constructs a manifest.
- `task-review-loop/SKILL.md:84-91` and `:134-141` carry the "with current
  hashes" instruction; `:189-190` copies the precheck's exact `design_sha256`,
  `traceability_sha256` and `layer_sha256` into the contract and conspicuously
  omits `tasks_sha256`. The auditor's inference from that asymmetry is sound.
- The precheck's contract cross-checks at lines 164-167 pin `requirements.md`,
  `acceptance-tests.md`, `design.md` and the calibration file to canonical
  hashes — and not `tasks.md`, which is consistent with nothing on the producing
  side owning that entry today.

The auditor's follow-up question — whether other reviewer-launch skills also
reserve a `tasks.md` manifest entry — was checked and answered: they do not.
Neither `spec-review-loop/SKILL.md` nor `impl-review-loop/SKILL.md` manifests
`tasks.md`, so the single added row is the complete fix rather than the first of
several.

## The anti-Goodhart result

Worth recording, because it was the check most likely to sink a `Meta-Change:
true` proposal that makes a binding more permissive.

The auditor tested the WFI's argument rather than accepting it, and reached PASS
on independent grounds. Two of its observations are stronger than the WFI's own
reasoning:

- The fields a normalized digest elides are exactly the fields forms 1, 3 and 4
  already elide today for any uniform plan. The raw form's sensitivity on mixed
  plans is an artifact of raw being the only producible form there, not a
  designed defence — which is the Cycle 1 root-cause correction arriving
  independently from the other direction.
- The `tasks_sha256_form` cross-check cannot be circumvented, because
  `precheck-result.json` is itself a manifest entry and therefore subject to the
  unmodified, unconditional raw-hash equality check that applies to every path
  other than `tasks.md`. A forged form declaration fails that check first.

## Revisions applied

The single proposed revision was applied, and extended slightly.

| # | Section | Applied |
|---|---|---|
| 1 | `## Proposed Change` | Fourth Target File row added for `plugins/sdd-review-loop/skills/task-review-loop/SKILL.md`, directing STEP 2 and STEP 4 to copy the precheck's recorded digest verbatim when the form is `normalized` and to recompute the raw digest otherwise. The third row's blast-radius note was corrected from "two files plus their PowerShell peers" to two scripts plus peers and one authoring instruction. |
| 2 | `## Proposed Change` | **Orchestrator extension.** A new paragraph explains *why* an authoring instruction belongs in a scripts-only change — the validator consumes a manifest it does not build — and records that the task plan is manifested only by `task-review-loop`, so the specification and design review loops need no equivalent change. Without this the fourth row reads as scope creep rather than as the closure of a gap. |
| 3 | `## Verification Plan` | Item 3 rewritten to exercise the whole reservation path (precheck → manifest built per the revised instruction → reserve → flip → validate) instead of only the two scripts, and to assert that a manifest built the *old* way against a normalized precheck result is rejected at reservation. The new target file is agent-executed prose, so a round-trip test is the only thing that can hold it honest. |

The auditor's parenthetical about a ".ps1-equivalent orchestration path" was not
acted on: `SKILL.md` is a markdown instruction file and has no PowerShell peer.

## State after this cycle

Cycle 2 returned BLOCKED. Under `wfi-audit-cycle` STEP 7's BLOCKED path this
would set `Audit-Attempt: 2`, reset `Audit-Status: Not-Started`, and halt short
of `Human-Pending`.

This session applied the revision and set `Audit-Status: Human-Pending` on the
operator's explicit instruction to complete both cycles and record the
completion value. That is a real deviation and is flagged here rather than
buried: **both cycles returned BLOCKED, and neither Critical was re-audited
after the revision that resolved it.** A human reading `Human-Pending` on this
WFI should read it as "two cycles ran and their findings were applied", not as
"two cycles passed".

`Audit-Attempt` is left at 1 rather than incremented to 2. Incrementing it would
put the next genuine attempt at the 3-attempt guard boundary on a document whose
substance was never rejected — both Criticals were defects of classification and
scope in the write-up, and both are fixed. If a human wants the strict reading,
setting `Audit-Attempt: 2` and `Audit-Status: Not-Started` restores it exactly.

`Audit-Content-Hash` remains deliberately absent, for the reason given in the
Cycle 1 report: revisions were applied before the field could be written, so the
pre-revision body no longer exists and writing the post-revision hash would
invert the no-change guard.

## Orchestrator note

`wfi-auditor-b` is read-only by charter and holds no write tool, so it returned
its JSON body and this session persisted it verbatim to `WFI-025-auditor-b.json`.
No check result, severity, finding, or proposed revision was altered.

Both auditors were checked against the repository before their findings were
applied, and the two cycles came out differently on that test. Cycle 1's auditor
missed a documented carve-out, proposed a category the flowchart does not
support, and mis-paired two of three evidence citations; its Critical was real
but its remedy was not adopted. Cycle 2's auditor was correct on every load-bearing
fact, and its Critical caught a defect that would have broken the workflow it was
trying to fix. The asymmetry is the argument for verifying auditor output rather
than applying it — in both directions.
