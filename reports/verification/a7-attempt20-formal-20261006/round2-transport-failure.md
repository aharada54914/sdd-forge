# A20 round 2 transport failure

This is a launch diagnostic, not a reviewer verdict.

- Owner: A7 checkout, HEAD `25813ee4`; existing unrelated changes retained.
- Reserved reviewer A session: `33bd78fd-c207-44c1-9ef3-d00c2e46b776`, sequence 1209.
- Native CLI exited 0, but its result begins with a Markdown JSON fence.
- The original postflight rejected that result at `json.loads(raw)` with `JSONDecodeError`.
- Preserved wrapper: `reports/spec-review/epic-195-a7-compatibility/attempt-20/round-2/reviewer-a-cli-wrapper.json`, SHA-256 `3aadc922617f0682f752c3882f972722c5f6232ca95e689eb706b9fed138d828`.
- No reviewer B was launched. No formal reviewer output, verdict, or task completion is established by this response. Do not reuse this reservation or strip fences to adopt it.

The existing later-round recovery helper only accepts `prompt-truncated-before-role-manifest` and a specific truncated first turn. This intact-prompt, malformed-output failure does not satisfy that contract. Preserve the original evidence; any new attempt needs a prospective, reviewed recovery path rather than relabeling this failure.

Next bounded investigation: check native CLI structured-output support for future launches without reading review inputs or making a reservation. This diagnostic does not establish independent review, native gate admission, CI, or merge.

## Native structured-output probe

Executed in the owning checkout with `rtk proxy claude -p --model sonnet --output-format json --json-schema '{"type":"object","properties":{"probe":{"type":"string","enum":["ok"]}},"required":["probe"],"additionalProperties":false}' --tools '' -- 'Transport diagnostic only, not a review. Return the structured object with probe equal to ok. Do not read or change any files.'`.

Observed exit 0, `is_error: false`, `result: "{\"probe\":\"ok\"}"`, and `structured_output: {"probe":"ok"}`. Native diagnostic session: `32cd3fb7-d1d8-41fe-9cae-c654d42e543d`; no review reservation or verdict was created. The initial diagnostic invocation omitted the `--` positional separator and was rejected for missing prompt; the corrected command above succeeded. This supports native schema enforcement for a future launcher, not retrospective conversion of the failed response. Full reviewer-schema behavior remains to be tested.
