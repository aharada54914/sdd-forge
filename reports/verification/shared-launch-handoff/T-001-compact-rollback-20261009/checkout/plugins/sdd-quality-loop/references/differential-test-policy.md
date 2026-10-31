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

### Sudo Mode

Under a valid `SDD_SUDO` flag, the human approval required for an `accepted`
classification auto-passes: mark the change `(sudo <ISO8601 UTC>)` and update
`baseline-behavior.md`. A `fix-required` classification is never auto-passed — it
always creates a review ticket and blocks `Done`. The differential comparison
itself always runs regardless of sudo.

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
`Implementation Complete` and note the pending approval requirement — unless a
valid `SDD_SUDO` flag is active, in which case the `accepted` approval
auto-passes (see "Sudo Mode" above).

## Refactor Tasks under the TDD Workflow (Red-Evidence Mapping)

Added for risk-adaptive-layer T-004, which makes `check-contract.{sh,ps1,py}`
require non-empty `red_evidence` and `green_evidence` on the `unit-tests` and
`acceptance-tests` checks (when marked `required: true`) whenever the contract
carries `required_workflow: tdd`. Other check ids (e.g. `regression`) are not
covered by the gate even when required; the refactor mapping below still
applies to them as policy, without gate enforcement. A refactor task cannot
produce the feature-work form of red evidence (a new test failing because the
behaviour does not exist yet), so this section defines the refactor mapping.

**The differential baseline IS the red evidence.** For a `refactor` (or
behaviour-preserving `bugfix`) task under `required_workflow: tdd`:

- `red_evidence` points to the **before-state capture**: the log produced by
  running the covered tests/inputs against the clean tree (Procedure step 1),
  recording the pre-change behaviour for every `Must Preserve: yes` BL entry
  in scope. The capture must state which tree it ran against (stash, scratch
  worktree of the merge-base, or recorded `baseline-behavior.md` evidence,
  annotated per step 1).
- `green_evidence` points to the **after-state capture**: the same inputs
  re-run against the modified tree (Procedure steps 2-4), after
  normalisation.
- Both files obey the gate's existing rules: existing, non-empty, path-safe,
  inside the repository.
- The pair is only meaningful when the two files are **distinct**. The gate
  accepts `red_evidence == green_evidence` (a schema-level residual risk noted
  at T-004's quality gate); this policy does NOT - a refactor task whose two
  fields name the same file has not demonstrated a differential and the
  reviewer must treat the evidence as absent.

The comparison itself, the classification table, and the
`Differential Baseline Verification` report section above apply unchanged;
this mapping only defines where the contract's two evidence fields point for
the refactor case. When `baseline-behavior.md` does not exist, the
Prerequisite rule above already applies: record the absence in the
quality-gate report; the task then needs conventional red/green TDD evidence
or a workflow decision by the human approver - the absence of a baseline
never waives the gate's non-empty-evidence requirement.
