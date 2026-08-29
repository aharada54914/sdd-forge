# epic-193-a5 → main merge resolution recipe (DRAFT for co-verification)

Status: DRAFT — co-produced with codex (sol model) under owner instruction
2026-08-29. Every claim below carries its evidence method; the codex
verification pass re-derives each independently before this is offered for
human application. **No agent applies this: the conflicting files include
guard-protected gate scripts, and the guard forbids agent modification
regardless of intent. A human performs the merge with this recipe.**

## Context

- Branch `feature/epic-193-a5-capability-resolver` is 575 commits behind
  `origin/main`; `git merge-tree --write-tree HEAD origin/main` reports 19
  conflicting paths.
- Probe method: for each conflicting file, take the lines MY branch added
  since the merge-base (`git diff $(git merge-base HEAD origin/main) HEAD`),
  select up to 8-10 non-comment lines >30 chars, and test verbatim membership
  in `origin/main`'s version of the file (or, for the sh prechecks, in
  main's new `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh`).

## Group 1 — take main (`git checkout --theirs`), my changes already landed

Probe evidence: every probe line already present in main's version.

| File | Probe result |
|---|---|
| `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | 8/8 in main |
| `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1` | 8/8 in main |
| `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` | 8/8 in main |
| `plugins/sdd-review-loop/scripts/task-review-precheck.ps1` | 8/8 in main |
| `plugins/sdd-review-loop/scripts/impl-review-precheck.sh` | 10/10 in main's `lib/review-precheck-common.sh` (main refactored the sh prechecks into a shared library; my additions live there) |
| `plugins/sdd-review-loop/scripts/task-review-precheck.sh` | 10/10 in main's lib |
| `tests/workflow-state.tests.sh` | 8/8 in main |
| `tests/downstream-review-precheck.tests.ps1` | 8/8 in main |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh` | no additions on my side — conflict is delete/modify or context-only; take main |

Risk note for the verifier: probe-line membership is NECESSARY, not
sufficient — 8 lines present does not prove all my added lines are present.
The verification pass should diff my full addition set against main for at
least the two largest (check-workflow-state.sh, workflow-state.tests.sh).

## Group 2 — union: main's version + my branch's specific lines

| File | My lines to re-add on top of main |
|---|---|
| `AGENTS.md` | one line registering `` `specs/epic-193-a5-capability-resolver/` `` in the feature list |
| `tests/run-all.sh` | nine suite registrations: resolver-evidence-schema, resolve-project-context-{block,match,cli,discovery,lite}, validate-resolver-evidence, resolve-project-context-{parity,metamorphic} (each as `tests/<name>.tests.sh`) |
| `tests/run-all.ps1` | the same nine, `.ps1` twins |
| `tests/run-panelist-effort.tests.sh` | 3 added lines (to be enumerated by the verifier from the diff) |
| `tests/run-panelist-effort.tests.ps1` | 3 added lines (same) |
| `specs/workflow-state-registry.json` | my one added registration entry for epic-193-a5-capability-resolver, inserted into main's version of the registry |

## Group 3 — the one judgement call: `run-panelist-gpt.{sh,ps1}`

My branch passes `-c project_doc_max_bytes=0` to every codex invocation (and
documents why: prevents the panelist from pulling extra project context into
a blind review). `origin/main`'s current version has NO occurrence of
`project_doc_max_bytes` in either runtime (measured by substring count = 0),
while it DOES carry the `_model_args` / `--effort` handling (6 and 12
occurrences respectively in the sh version).

Proposed resolution: take main, then re-apply the `-c
project_doc_max_bytes=0` argument to each codex invocation plus its two
comment lines. Open question for the verifier: check main's git history for
whether the flag was ever present and deliberately REMOVED (in which case
this is a human decision, not a mechanical re-add), or simply never landed
(in which case re-adding restores blind-review hygiene).

## Group 4 — data files: append/re-chain, not textual merge

| File | Method |
|---|---|
| `reports/review-context/identity-ledger.json` | Append-only hash-chained ledger. Both sides appended entries with overlapping seq numbers. Known procedure (recorded in this repo's own merge-sweep history): keep main's chain as the base, re-append my branch's entries at the tail with renumbered seq, recomputing each entry's chain hash; reviewer manifests referencing old seq stay valid because they pin content hashes, not seq. |
| `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` | NOT this epic's file. My branch carries 2 changed lines from an earlier cross-epic sweep. Verifier: determine whether main's version already reflects the same hashes for those rows; if yes take main, if no this needs the epic-191 owner, not us. |
| `docs/workflow-improvements/WFI-060.md` | No real conflict remains: my branch renamed its WFI-038 to WFI-060 precisely because main's WFI-038 is a different document. If the merge still reports WFI-038.md as delete/modify, resolution is: keep main's WFI-038.md, keep my WFI-060.md. |

## Verification checklist for the codex (sol) pass

1. Re-derive the 19-path conflict list from `git merge-tree --write-tree
   HEAD origin/main` and confirm it matches the union of the groups above
   (no file missing, none invented).
2. For Group 1: full-diff containment check on the two largest files, not
   just probes.
3. For Group 2: enumerate the exact union lines from the diffs and confirm
   each is absent from main (a line already in main must not be re-added).
4. For Group 3: `git log -S project_doc_max_bytes origin/main --
   plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` — removed
   deliberately, or never present?
5. For Group 4 ledger: confirm main's ledger is a strict prefix of neither
   side (i.e. both appended), and count my branch's tail entries needing
   re-chain.
6. Report every disagreement with this draft explicitly; do not silently
   correct it.
