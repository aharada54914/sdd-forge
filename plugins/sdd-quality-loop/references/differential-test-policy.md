# Differential Test Policy

Apply to `refactor` and `bugfix` tasks to confirm that observable behaviour is
preserved after a change.

## Prerequisite

Locate `specs/<feature>/baseline-behavior.md`.  If the file does not exist,
this policy cannot be applied.  Record the absence in the quality-gate report
and do not block the task for differential reasons alone.

## Inputs

Each entry in `baseline-behavior.md` carries a `BL-xxx` identifier, a
description, and a `Must Preserve` flag (`yes` or `no`).  This policy covers
only entries where `Must Preserve: yes`.

## Procedure

For each `Must Preserve: yes` BL entry:

1. **Obtain the before-state.**  Use one of the following in priority order:
   - Stash the working changes (`git stash`) and run against the clean tree.
   - Checkout the merge-base or `main` branch in a scratch worktree.
   - Use the recorded evidence already stored in `baseline-behavior.md` when
     neither option above is practical (annotate the report accordingly).

2. **Obtain the after-state.**  Run the same inputs against the modified code.

3. **Use identical inputs.**  Parameterise tests, endpoint calls, or Playwright
   scripts so that both runs receive the same data.  Do not compare outputs that
   differ due to non-deterministic factors before normalisation (see below).

4. **Normalise environmental differences** before comparing:
   - Timestamps → replace with a fixed sentinel (e.g. `<TIMESTAMP>`).
   - Random seeds, UUIDs → replace with `<RANDOM>`.
   - Host-specific paths, port numbers → replace with `<ENV>`.
   After normalisation, re-run the comparison.  If normalised outputs still
   differ, classify as `fix-required`.

5. **Classify each BL entry** (exactly one of three values):

   | Classification | Meaning | Action |
   |---|---|---|
   | `fix-required` | After-state deviates from before-state in a way not intended by the task | Create a review ticket; block Done |
   | `accepted` | After-state intentionally differs (stated in the task description) | Require human Approved on the change; update `baseline-behavior.md` |
   | `environmental` | Difference eliminated after normalisation | No action required |

## Verification Methods

- **Unit / integration tests** — run the test suite scoped to the changed
  feature with both before- and after-states and compare pass/fail and output.
- **API endpoints** — replay identical HTTP requests; diff JSON responses after
  normalisation.
- **UI behaviour** — use Playwright or an equivalent browser driver; capture
  screenshots or DOM snapshots for visual diffing.

## Principle

Do not rely solely on AI-generated result reports.  Actually run the code in
both states and compare the evidence.  An AI summary that claims "behaviour
unchanged" without runnable proof is insufficient.

## Quality-Gate Report Section

Add a `Differential Baseline Verification` section to the quality-gate report
containing a table with one row per `Must Preserve: yes` BL entry:

| BL-ID | Description | Classification | Evidence |
|---|---|---|---|
| BL-001 | … | accepted / fix-required / environmental | link or inline |

If a `fix-required` row exists, set the task to `Blocked` and create a review
ticket.  If an `accepted` row exists and human approval is absent, retain
`Implementation Complete` and note the pending approval requirement.
