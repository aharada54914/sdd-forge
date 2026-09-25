# epic-193-a5 → main merge resolution recipe — v2 after codex (sol) verification

Status: v3, 2026-08-29. v1 returned **RECIPE-UNSAFE** from codex
(gpt-5.6-sol) with seven refutations; v2 incorporated all seven and returned
**RECIPE-NEEDS-CHANGES** with five documentation-precision corrections, all
incorporated here. Both passes were read-only with silent correction
forbidden; each v1/v2 error is kept visible where it changed a resolution. **No agent applies this: several
conflicting files are guard-protected, and the guard forbids agent
modification regardless of intent. A human performs the merge.**

## What v1 got wrong (codex sol findings, all accepted)

1. **Omitted a real conflict**: `prepare-panelist-input.sh` was missing from
   every group. (Now Group 1: my side's full diff vs the merge-base is
   +976/-88 lines — v2 said "+722", which counted only added lines longer
   than 30 characters, an artifact of the probe script's filter; 10/10
   probes in main, marker counts match — my bundle-composition rewrite
   landed.)
2. **Treated replacements as additions**: the six `run-panelist-effort`
   test lines are not additive — they replace exact-argv assertions, and
   main's runner now uses `model_reasoning_effort`, `--sandbox read-only`,
   `--skip-git-repo-check`, `-C`, stdin `-`. Re-adding mine would contradict
   main's tests. (Resolution changed to: take main's tests wholesale.)
3. **`project_doc_max_bytes` re-add unjustified**: `project_doc_max_bytes`
   itself never landed on main; what main commit `a367dda1` deliberately
   replaced was the older `--no-project-doc` isolation approach, superseding
   it with an isolated scratch directory + `--sandbox read-only`. Either way
   the conclusion stands: blindly re-adding my flag ignores an evolved,
   documented design. (Resolution changed to: take main; treat the
   flag as superseded. If anyone wants it back, that is a design question
   for the owner, not a merge step.)
4. **Ledger justification was false**: reviewer manifests DO pin
   `sequence`, `previous_record_sha256` and `identity_ledger_sha256`, so
   re-chaining changes pinned values. (Resolution now carries an explicit
   archival rule, below.)
5. **Registry union overstated**: only the feature-key line is unique;
   braces/comma/`"profile": "full"` must not be duplicated.
6. **Epic-191 manifest cannot "take main"**: the two rows differ across
   merge-base, branch AND main. Escalate to the epic-191 owner.
7. **WFI-060 is not a conflict** in the three-tree result; it needs no
   resolution step at all.

## Group 1 — take main (`git checkout --theirs`)

My branch's changes to every file below either landed in main (verbatim, or
refactored into `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh`
for the sh prechecks) or were superseded by main's evolved design of the same
concern (the gpt-runner isolation). Verified by probe lines; codex's passes
added full-diff containment on the largest files and found nothing of the
branch's lost by take-main beyond the withdrawn/superseded isolation flag.

- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` / `.ps1`
  (investigation-amendment tolerance confirmed present in main's both
  runtimes: `investigation_amendment_reconciles` et al.)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh`
- `plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh`
- `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` / `.ps1`
  (v1 wanted to re-add `-c project_doc_max_bytes=0`; WITHDRAWN — see item 3)
- `plugins/sdd-review-loop/scripts/impl-review-precheck.sh`
- `plugins/sdd-review-loop/scripts/task-review-precheck.sh`
  (the `.ps1` twins were listed in v2 but the second pass's re-derived
  three-tree conflict list shows they merge cleanly — they need no
  resolution step and are removed rather than left to invite one)
- `tests/workflow-state.tests.sh`
- `tests/downstream-review-precheck.tests.ps1`
- `tests/run-panelist-effort.tests.sh` / `.ps1` (moved from Group 2 — see
  item 2)

## Group 2 — union: main's version + exactly these lines

- `AGENTS.md`: add my single feature-registration line
  `` - `specs/epic-193-a5-capability-resolver/` `` at the list position main's
  ordering implies.
- `tests/run-all.sh`: add the nine suite registrations (verified by codex as
  all absent from main): `tests/resolver-evidence-schema.tests.sh`,
  `tests/resolve-project-context-{block,match,cli,discovery,lite}.tests.sh`,
  `tests/validate-resolver-evidence.tests.sh`,
  `tests/resolve-project-context-{parity,metamorphic}.tests.sh`.
- `tests/run-all.ps1`: the same nine as `.ps1`.
- `specs/workflow-state-registry.json`: insert ONLY the
  `epic-193-a5-capability-resolver` feature-key entry into main's registry
  (do not duplicate braces/commas/`"profile": "full"` scaffolding).

## Group 3 — escalations, not merge steps

- `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256`: the two
  rows differ across merge-base, branch and main. This belongs to epic-191's
  owner; surface it, do not resolve it here.
- `docs/workflow-improvements/WFI-060.md`: no conflict — keep main's
  WFI-038.md and this branch's WFI-060.md. Listed only so nobody "resolves"
  it into damage.

## Group 4 — identity ledger re-chain, with the corrected rule

`reports/review-context/identity-ledger.json`: merge-base 764 records is an
exact prefix of both sides; branch adds 92 unique tail records (no hash or
run-id overlap with main's 959, codex-verified).

Procedure: keep main's 959 as the base; re-append the branch's 92 in order
with recomputed `sequence`, `previous_record_sha256` and record hashes.

**Archival rule (replacing v1's false claim):** reviewer manifests pin
sequence-dependent values (`sequence`, `previous_record_sha256`,
`identity_ledger_sha256`), so re-chaining makes those historical pins
non-replayable against the merged ledger. The second verification pass
confirmed the properties that make this safe TODAY: main's validator checks
the resulting chain end to end, and stage-provenance checks review artifacts
without referencing identity-ledger fields. Historical manifests attest what
the ledger looked like when their review ran. At least one prior
parallel-branch merge in this repository used tail re-chaining; "every prior
merge did" is not substantiated and is not claimed. What must hold after re-chain: (a) the
merged chain itself re-validates end to end; (b) the 92 re-appended records
keep their original `run_id`/`host_session_id` and content fields byte-for-
byte, changing ONLY the three chain fields; (c) the pre-merge branch ledger
remains recoverable from git history for audit. No manifest is edited.

## Verification checklist for the codex (sol) second pass

1. Confirm every v1 refutation is addressed above and none introduced a new
   error.
2. Confirm the Group 1 list now covers ALL conflicting paths except those in
   Groups 2-4, and re-derive the conflict list to prove nothing is missing.
3. Full-diff containment for `run-panelist-gpt.sh`: with the flag re-add
   withdrawn, confirm nothing else of the branch's is lost by take-main.
4. Confirm the nine run-all registrations and the registry feature-key line
   are still absent from main at verification time.
5. Same explicit-disagreement discipline: VERIFIED / REFUTED / CANNOT-VERIFY
   per claim; end with RECIPE-SOUND or RECIPE-NEEDS-CHANGES or RECIPE-UNSAFE.
