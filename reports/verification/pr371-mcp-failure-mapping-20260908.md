# PR371 MCP failure integration mapping — 2026-09-08

Diagnostic evidence, not a gate verdict or merge approval.

## Remote observation

Six open PRs retain the previously recorded exact heads: 245, 371, 381, 390,
394, 400. Their reported check runs are terminal; no live CI wait was found.
PR400 checks are green but the new design review is NEEDS_WORK. PR245 has
merge conflicts and no workload CI result in its rollup. No rerun or merge
was requested by this diagnostic.

## PR371 failure narrowed

Retrieved job 99111814881 in run 33256788058 from GitHub using gh run view.
Ubuntu MCP tests report 242 tests, 241 pass, 1 fail. The failed test is
`live shell comparison: parseTaskState matches check-task-state.sh for every golden feature`.
The assertion is `risk-adaptive-layer: verdict mismatch (shell exit 1)`;
actual parser verdict is pass, expected shell verdict fail. The stack names
dist-test/tests/golden/task-state-golden.test.js:51 and :72.

This is a golden-comparison failure, not evidence of dependency installation
failure. The log alone does not establish why the shell returned fail.

## Existing correction to preserve

Compared PR371 9e39c396f4ca8f9abe3c9aabb090868ada17b53f with main checkpoint
4366438f3b243210a4ece5a17f873ca2d920600a. Commit e72e4dcd already changes the
golden comparison to classify checkout-dependent evidence-bundle failures,
adds its helper and non-vacuity regression controls, and regenerates the
orphaned T-010 bundle. PR381 3971c93a5705dc15f86ba56cc62118613e4b19db carries
the same three golden test/helper files as that main checkpoint (empty
endpoint diff). The PR371-to-PR381 diff adds 171 lines in those three files.

Therefore do not author a duplicate golden workaround on PR371 or restore its
older tests during integration. Preserve the existing main/PR381 correction
and controls; reproduce the golden suite on the exact integrated checkout.
This comparison does not prove that correction alone explains the historical
shell failure, nor that every PR371 acceptance condition is satisfied.

## Remaining work

- PR371 still needs reconciliation of its substantive enhancements with PR381,
  fresh evaluation evidence, the required human disposition for issue 346,
  and successful Windows tests and all mandatory CI.
- PR381's reviewed human-copy application and formal verification remain open.
- No product code, protected target, frozen specification, task status,
  GitHub issue state, or branch was changed.

Memory recall produced no relevant verified root-cause record; unrelated and
empty historical entries were not treated as evidence. No durable memory
writeback is justified by this one diagnostic observation.

## Windows failure and source reconciliation follow-up

Read GitHub job 99111814795 of run 33256788058 directly. The Windows
cross-model suite recorded 60 passes and four failures in TEST-004(c): GPT
iterations 3/4 and Gemini iterations 2/4. Each failed with exit=1 and no
verdict under the unchanged 2000 ms runner budget. This log predates the
approved stdin-draining and stage-timing fixture changes; it cannot establish
their Windows outcome or the internal cause of these historical timeouts.

At the pinned PR371 and PR381 heads above, an endpoint diff of
tests/cross-model.tests.ps1 and both PowerShell panelist runners is empty.
Thus PR381's existing remote head does not itself supply a different version
of those files to resolve this Windows failure. The separately approved
fixture/runner lane must be verified and integrated, not bypassed by merging
PR381 or rerunning PR371 unchanged.

`git merge-base --is-ancestor` for PR371 → PR381 returns 1. A symmetric
`git log --left-right --cherry-pick` also retains PR371 commit 9e39c396 on
the left, so neither ancestry nor patch equivalence proves complete adoption.
Nevertheless all ten paths changed by that PR371 commit exist at PR381.
An exact ten-path endpoint comparison shows four unchanged artifacts:
ADR-0026, ADR-0027, evaluation.json, and reviewer-prompts.md. The remaining
six differ (three schemas, historical report, skill, report template), with
86 insertions and 18 deletions in total. The skill adds full commit-ID and
no-external-diff digest instructions; no existing skill text is removed.
PR381 commit 58062793 is the substantive hardened replacement candidate.

This narrows the outstanding adoption audit to those six changed artifacts
plus independent evaluation and issue acceptance conditions. It is not proof
that every requirement is preserved. Do not cherry-pick 9e39c396 wholesale
over the hardened schemas, close PR371 as redundant, or delete its branch
until that audit and the required verification complete.
