# 2026-09-11 Adversarial Review — PR407

## Report Metadata (original reviewed target)

```yaml
schema_version: adversarial-review-report.v1
merge_base_sha: 4366438f3b243210a4ece5a17f873ca2d920600a
head_sha: 4d8213e566e6ab5b362ed0a302adab04ca5fae67
diff_sha256: 8b7232cfe8784885ae85fcf11f89c12155b75fa2c9b6f69eaa2db806c2ca0810
created_at: 2026-09-11T06:44:48.370Z
skill_version: c2b7f25b9e3d4d4857dc546a363325c881e81f50
reviewer_run_ids:
  reviewer_a: /root/pr407_pilot_a
  reviewer_b: /root/pr407_pilot_b
```

Manual standalone pilot on the full PR407 diff (eight files), related to
Issue289. Workflow-surface changes trigger the skill's review predicate.
ADR0027 remains Proposed; this does not activate automatic SDD wiring.
Native reviewer IDs are not SDD ledger reservations or GitHub approvals.

## Phase 1 and synthesis

Two fresh reviewers, separate lenses and same pinned context, independently
found one MEDIUM defect each: A-1 and B-1 are the same table-state leak.
Original Python34–44 and PowerShell26–31 reset state on blanks/H2 only;
other non-pipe lines merely continue. A directly adjacent H3 and separate
Requirement/Notes table then treats supplementary prose as a Layer Spec.
Both reproduced this using the actual Python main with in-memory input reads;
those probes are not actual PowerShell executions or full-suite runs.

Root consolidated the two reports into one adopted MEDIUM repair, not two
independent bugs. Original assessment: REQUEST CHANGES. No rejected findings.

## Phase 2 cross-critique

Both original agents resumed, received the other complete report verbatim,
and read/applied the full Phase2 prompt from reviewer-prompts.md.

- A on B-1: SUPPORT, code_evidence, citing Python34–44, PowerShell26–31,
  tests/bootstrap-cross-layer-index.tests.sh87–98 (blank-separated fixture).
- B on A-1: SUPPORT, code_evidence, citing those locations plus Python55–59
  where retained column state produces the wrong diagnostic.
- Both assessed substantive scope as in_scope under Issue289's explicit
  supplementary-table objective and the user's root-fix authorization.
  No formal REQ/AC/task IDs exist for this extracted fix; arrays remained
  empty instead of inventing IDs. This is a recorded scope-contract limitation,
  not a claim of canonical cross-critique schema compliance.
- Both retained their own finding at MEDIUM; no missed findings, rejected
  findings, severity changes, human dispositions, or additional fixes.

The proposed fix is a local state reset, not a new Markdown parsing library.
Header aliases, anchor rules, and coverage requirements remain unchanged.

## Remediation and fresh Phase R

Fix commit on PR407: `3bb7d192` (after the original reviewed HEAD).
Python and PowerShell now clear both state fields for non-pipe lines.
Twenty-four new checks cover H1–H6, ignoring unrelated side tables, and
re-entering independently arranged traceability tables, with both valid and
invalid anchors in both runtimes. Negative checks require the exact invalid
anchor diagnostic, preventing unrelated premature failures from passing.

Actual implementer runs on macOS:

- Before production edits: bootstrap cross-layer suite 34 pass / 20 fail.
- After edits, identical suite: 54 pass / 0 fail.
- Task-layer inputs: Bash9 pass; PowerShell7 pass; whitespace check exit0.

Fresh `/root/pr407_fix_verify` returned A-1/B-1 VERIFIED, citing current
Python34–37, PowerShell26–29, and test150–182. No introduced issue found.
This reviewer did not rerun temporary-file-writing tests under its read-only
instruction. It verified the source and structural counts, not historical
runtime results. This is one consolidated VERIFIED finding.

## Verified non-findings

Both reviewers checked canonical Requirement and existing REQ-ID headers,
case-sensitive comparisons, header-based Layer Spec lookup, requirement
coverage and input-substitution rejection. Actual ci-mcp inputs passed both
runtimes during Phase1. Manifest allocation fails before construction and
uses trailing Xs; existing cleanup remains. No new secrets, dependencies,
network actions, or authorization changes were found. A tentative Windows
CRLF concern was discarded before Phase1 reporting because the actual reader
already strips CR; it is not counted as a rejected published finding.

## Status and limitations

The adopted defect is fixed and locally verified. Latest fix-commit CI,
required third-party approval, safe merge, main verification, and Issue closure
are outstanding. The metadata deliberately pins the original reviewed diff;
the report is stale relative to the subsequent fix HEAD, not silently re-bound.
The fix verification above is a separate, explicitly scoped review.
No SDD status, frozen evidence, required check, or approval was changed.

Three total launches (two Phase1, one PhaseR), both Phase1 agents resumed.
Complete-run token telemetry and pre-launch time are unavailable; evaluation
records null with reasons, not estimates. This is a structural pilot for #350,
not a human promotion decision or measured performance benefit.
