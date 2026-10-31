# T-004 current public delivery evidence

This additive record does not replace the frozen implementation report or its
attempt-1 manifest. It records delivery verification, not a quality-gate verdict.

## Scope and ownership

- Task: shared-review-launch-repair T-004; high-risk review-launch/CI integration.
- Public checkout: `sdd-shared-launch-public-20261011`, branch
  `codex/shared-launch-public-integration`.
- Verified head: `228cc336a1b3f2f0f953eb46ff0f576d8b37cded`.
- Integration base: `0b2951b6855bbd136938fafa901ee8af8bbe4855`.
- Public worktree was clean when this record was prepared.
- The owner checkout retains unrelated existing changes. Its working files are
  not asserted to be identical to the public commit.

## Exact-head CI

[PR 558](https://github.com/aharada54914/sdd-forge/pull/558) has
[run 38106440887](https://github.com/aharada54914/sdd-forge/actions/runs/38106440887)
at the verified head above. The GitHub API observation on 2026-10-11 reported
`completed/success`, with all 37 jobs successful, including `required-checks`,
the complete POSIX regression inventory, POSIX shards, native Windows lanes,
macOS lanes, installers and the three-host CLI hook enforcement jobs.
The required-checks job completed at `2026-10-11T03:08:36Z`.

This supersedes only the pending-CI statement in the earlier public integration
record. It does not retrospectively change the result of earlier runs.

## Bounded repair and retained evidence

The initial Ubuntu run failed because RTK was absent from the runner. Commit
`228cc336a1b3f2f0f953eb46ff0f576d8b37cded` installs RTK v0.51.0 with archive
SHA-256 `5028d3b19a8f0990d30fec9fbb07e32782bc5698e618fb1861aad8a9ccba4eb5`
verified before extraction, without dropping required tests. The focused
registration regression changed from four passing/one failing checks to five
passing checks. Independent diff review found no blocking findings; it is not
a formal task quality-gate verdict.

The frozen implementation report remains SHA-256
`266f4c37db646ba7eee2e5719a68e9b26df89a4b6c108f3175ee8f87825f0e5c` and the
attempt-1 manifest remains
`565e5fcccf4b60629d24aad73a3d246c9e69b036a634829c211be63c68688a90`.
Their isolated-attempt claims are not rewritten as public-delivery claims.
The combined disposable rollback verification restored all 78 targets and
completed its 12 commands successfully; this is not installed-host rollback.

## Still required

- Formal evaluation must bind the actual public source and these additional
  delivery inputs; owner/public source differences must not be hidden.
- Formal quality-gate decision and any lifecycle transition remain pending.
- PR readiness, current base/mergeability and required review must be checked
  immediately before merge.
- Merge commit, post-merge CI and final delivery confirmation remain pending.
- Four high-severity development-only npm audit findings were observed in
  unchanged baseline dependencies; production-only audit reported none. They
  are not silently repaired or represented as a clean full dependency audit.

No reservation, review verdict, task status, commit, push or merge is performed
by adding this record.
