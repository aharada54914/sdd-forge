# UX: verification-measurement

The only user-facing surfaces are opt-in CLI flags, the helper CLI and the
benchmark driver output. Each failure prints one fixed `run-measurement:
<code>: <message>` line without paths or file contents. Summaries say
`null` plus a reason instead of guessed values, label effort versus elapsed,
distinguish `not-observed` (null) from observed zero, never derive a
duration from UTC, and report `complete: false`
whenever a blocking diagnostic exists. No interactive prompt is added.
