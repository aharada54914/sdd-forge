# Symphony local use — synthetic-only

Date: 2026-09-05. Governing scheduling decision: EXECUTION_AMENDMENT.md and EXECUTION_REVIEW.md. Production enablement is deferred, NOT complete.

Pinned pristine source: `/Users/jrmag/.local/share/openai-symphony-8001b52e`, upstream `8001b52e3062495a16e520e4ceaf8f9de868c4d0`.
Isolated candidate: `/Users/jrmag/.local/share/openai-symphony-hardening-minimal-8001b52e/elixir`.
Runtime: mise 2026.9.1, Erlang 28.5, Elixir 1.19.5.

## Permitted use and evidence

Only credential-free memory/fake-worker tests. No real tracker polling, real-repository agent, credentials, reservation refs, privileged services or scheduled production runner.

From the candidate elixir directory, the repeatable focused check is:

```sh
rtk mise exec -- mix test test/symphony_elixir/core_test.exs:413 test/symphony_elixir/core_test.exs:553 test/symphony_elixir/core_test.exs:627 test/symphony_elixir/core_test.exs:695 test/symphony_elixir/core_test.exs:888 test/symphony_elixir/core_test.exs:1439 test/symphony_elixir/core_test.exs:1498
```

2026-09-05 result: 7 tests, 0 failures, 53 excluded, seed 591291. These exercise authority loss/startup refusal, rejected handshake, overlapping roots/restart, release and revalidation. They are synthetic tests, not actual issue execution or a production pilot. Earlier complete candidate gate: 340 tests, 0 failures, 6 skipped; see progress.md for exact slice history and independent reviews.

## Known limits

The v2 ledger accepts only an empty claim set; dispatch still uses in-memory ownership. Passing tests do not establish restart-safe durable task claims. A failed cleanup hook now preserves work, but successful/no-op cleanup can still delete workspaces. All production safety gates remain required if production work is resumed.

## Pause and rollback

No continuous real-tracker service was enabled by this work, so there is no authorized production daemon to keep running. For a manually started focused test, stop that specific terminal/test process; do not kill unrelated beam/codex processes by name. Retain the dirty candidate and pristine source separately. Do not reset, delete or overwrite the candidate patches to roll back. A future rollback to upstream means selecting the separate pinned pristine checkout for inspection only; upstream's previously observed failing security/test gate means it is not a production fallback.

Before any resume, recheck candidate hashes and upstream/candidate diffs, review the deferred hardening requirements and obtain explicit scope/credential authority. This runbook intentionally provides no live workflow-launch command.
