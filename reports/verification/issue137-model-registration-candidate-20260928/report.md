# Exact-host model metadata refresh — 2026-09-28

This separately scoped metadata repair adds only `gpt-6-astra` to v2. Previous entries, v1, tier floors, effort policy, selectors and frozen continuity artifacts are unchanged. It supersedes the September 27 candidate's claim that routine metadata registration necessarily requires a new human decision; that diagnostic record remains intact.

The [official Astra model page](https://developers.openai.com/api/docs/models/gpt-6-astra), read September 28, identifies Astra as the most capable model for complex reasoning/coding and exposes low/medium/high/xhigh reasoning. Mapping it to the existing strong tier is the maintainer's capability judgment, not a measured benchmark or completed task. The current native host exposes exact `gpt-6-astra` with high effort; no prefixed alias is inferred. Registration uses only the selector's existing effort vocabulary.

The same page gives Standard USD/million-token input 10 and output 50, with long-context multipliers 2 and 1.5. The selected historical native preflight sample records 2,359,194 input and 13,741 output tokens. Its private Codex session was inspected again on September 28 by extracting only `turn_context` model/effort and the final `event_msg/token_count` cumulative counters: model `gpt-6-sol`, effort `high`, receipt timestamp `2026-09-27T13:26:23.488Z`, cached input 2,183,296 and reasoning output 2,068 (already included in output). This is a multi-turn blocked-preflight sample from another model, not an Astra implementation measurement; raw conversation and personal metadata are not published. These anonymized counters replace the unresolved September 27 report reference.

Assuming that historical workload transfers to this route, treating all input as uncached and all requests as long-context gives `(2359194*20 + 13741*75)/1000000 = 48.214455`, rounded upward to USD 48.22. This is a conditional, nonregional Standard API-equivalent estimate, excluding tool charges; not an invoice, subscription charge, future workload ceiling or completed implementation cost. No paid API call is made.

`launch-candidates.json` carries the estimate's source and observation timestamp; actual task launch must bind these into the immutable input manifest and re-confirm availability. `check.py` checks selection and rejected inputs without launching a worker. This record does not claim continuity implementation, live activation, CI or merge.

## Executed verification

- `check.py`: failed before the registration with the exact-host assertion; passed afterward, including empty/unavailable and malformed candidate rejection.
- `tests/agent-capabilities-v2.tests.sh`: 10 passed, 0 failed; v1 unchanged.
- `tests/agent-model-routing.tests.sh`: exit 0, routing structure verified.
- `tests/effort-policy-flip.tests.sh`: 10 passed, 2 failed, 1 skipped, exit 1. Its historical T-007 checks require a branch name containing T-007 and an Unreleased heading in the first five changelog lines; this continuity branch meets neither. The suite, changelog, v1 and selectors have no Git diff. The real-Codex smoke remains skipped, not successful. No checks were weakened to hide these results.
- Separate metadata diff review found no blocking findings and re-ran exact-host strong/high selection. That reviewer contributed to the earlier metadata proposal, so this is not a blind independent review of the tier design and is not a quality-gate verdict.
