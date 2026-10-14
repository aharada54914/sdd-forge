# Issue 559 / PR 562 recovery correction

## Pre-edit scope (2026-10-14)

- Owner: PR 562 recovery implementer; checkout `issue559-bounded-audit/sdd-forge`,
  branch `codex/issue559-bounded-audit`.
- Starting HEAD: `473d2cdac228c34e03ba165a4942ddfdd3b0fbf5`; working tree clean.
- Finding: PRRT_kwDOS1iq_c6sLfP1. A partial audit can exit normally with no PR,
  allowing the vacuous PR guard to pass and the recovery job to close an old issue.
- Scope: workflow completion predicate, prompt completion handoff, focused tests.
- Risk: recovery evidence boundary; explicitly authorized PR correction, retaining
  mandatory verification and issue ownership checks. No product authorization,
  identity ledger, frozen evidence, task lifecycle or installed hooks are changed.
- Authority: direct scoped user instruction relayed by the parent; repository
  development with independent fresh Codex review, not a formal product gate.
  Current development policy was read from the main checkout because this older
  checkout does not contain `docs/development-policy.md`; no policy file is copied.
- Contract/readers/writers: the session writes a run-bound completion record;
  a workflow step validates it and exports a job output; recovery requires that
  output and full job success. A model-authored record is an explicit completion
  assertion, not independent proof that its reported tests ran.
- Validation: RED missing/partial record regression, positive and negative record
  fixtures executing the actual workflow step, existing closure/guard regressions,
  shell/workflow syntax, independent final diff review and exact-head CI by parent.
- Preflight counterparts: status -> completion output -> partial/missing negative;
  run/attempt/HEAD -> workflow environment/current HEAD -> stale identity negative;
  mandatory checks -> all five named checks -> missing/failed check negative;
  recovery -> job success plus completion output -> absent output cannot close.

## Results

- RED: existing guard suite plus new regressions: 25 passed, 5 failed. Missing,
  partial and false completion allowed issue writes; validator and output wiring
  were absent.
- GREEN: `bash tests/self-improvement-guard.tests.sh`: 43 passed, 0 failed.
  Executes the actual workflow validator and close-step bodies using local
  fixtures and mocked GitHub writes. Includes missing/malformed/duplicate status,
  partial/unknown status, stale run/attempt/HEAD, missing/failed/unrun/boolean check
  values, positive completion, and existing reporter-issue ownership tests.
- `bash -n tests/self-improvement-guard.tests.sh`: passed. Ruby YAML parsing and
  `bash -n` for every workflow run block: passed. `git diff --check`: passed.
- Completion validation runs after existing PR guard and CI-safety steps, so an
  incomplete record cannot prevent those existing checks from executing. Failure
  reporting names incomplete evidence; recovery requires both the affirmative
  job output and successful whole-job completion, including post actions.
- Limitations: completion/check status is reported by the session, not independent
  test execution proof. No live Claude/Actions run, exact-head CI or independent
  review has been performed by this implementer. Parent owns those delivery
  steps and commit/push/merge. No issue was closed by these isolated tests.

## Independent review — 2026-10-14

Fresh-context Codex reviewer `pr562_independent_final` returned PASS with no
blocking findings. It independently executed the 43-case suite (43 passed,
0 failed), shell syntax and whitespace checks, and inspected the actual workflow
validator and recovery entry conditions. Review input HEAD was
`473d2cdac228c34e03ba165a4942ddfdd3b0fbf5`; tracked binary diff SHA-256 was
`cca992a67bf50f3042332af4b504a483a8b5c02fc26b83f80e46624edb671693`.
This is repository-development independent evidence, not a historical product
review-ledger verdict. Live Actions, exact final-head CI and post-merge checks
remain separate delivery requirements. The session assertion limitation above
remains; fixture success is not proof of a completed scheduled audit.
