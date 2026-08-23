# Quality Gate Report

Task ID: T-005
Task: T-005
Feature: epic-193-a5-capability-resolver
VERDICT: NEEDS_WORK
Critical: 0
Major: 1
Minor: 6

- Model: claude-opus-5
- Effort: high

Run ID: RUN-epic-193-a5-capability-resolver-qg-T-005-seq0767
Host Session ID: SESS-qg-epic-193-a5-capability-resolver-T-005-0767
Cycles: 3 of 3 (limit reached)
Outcome: task retains `Implementation Complete`; one review ticket raised.

## Deterministic gates

All run against the live tree, output read rather than inferred.

| Gate | Result |
|---|---|
| `check-risk` | passed — `medium`, non-empty rationale |
| `check-placeholders` | passed |
| `check-workflow-state` (no `--feature`) | `workflow-state: ok`, every registered specification |
| `check-task-state` | passed for 10 tasks |
| `check-contract` | passed for T-005 |
| `check-component-coverage` | `not-applicable (disabled-legacy)`, exit 0 |
| `check-traceability` | not tier-required at `medium` |

`check-evidence-bundle` was not run: it applies to tasks reaching `Done`, and
this one does not.

Suites re-executed by the gate rather than transcribed from the report:
`resolve-project-context-match.tests.sh` and `.ps1`, **65 passed / 0 failed**
each. `tests/run-all.sh` returns the standing baseline of two failing suites,
both self-declaring `DESIGNED-RED`; `run-all.ps1` returns one, the absent
PowerShell twin of `deterministic-lane-selfcheck` accounting for the
difference.

## What the three cycles established

The suite grew 59 → 63 → 65 assertions. Every closure below is recorded with
the mutant that dies, because a fix nobody can demonstrate killing something
is not demonstrated.

### Cycle 1 (seq 0765) — NEEDS_WORK, 3 Major

- **AC-044's identity clause could not fail.** The check compared
  `_resolver_block()` against constants read from the same in-process module
  load, so a per-invocation derivation was invisible. Proved by folding
  `os.getpid()` into `RULE_SET_STRING`: the suite reported 59/0 with
  `rule_set_revision` different on every single invocation.
- **The persisted RED demonstrated nothing.** It reverted to pre-T-004, so
  every fixture exited 0 and the driver died on an `AttributeError` before
  AC-006/007/008/043/044/052 executed at all. None of the three defect classes
  `tasks.md` names was shown.
- **The records described code that no longer existed.** The report claimed
  37/0 against a 59-assertion driver, and its second-pass outputs sat in a
  separate `## Outputs` table — which is why this gate's own cycle-1 manifest
  omitted TEST-056's evidence. That omission was the gate's error, not the
  task's, and is recorded as such.

### Cycle 2 (seq 0766) — NEEDS_WORK, 3 Major

Cycle 1's first two Majors confirmed closed by re-injection: the identity
mutant now dies at 62/1, killed by the new out-of-process probe and by nothing
else, while the original in-process comparison still passes under it — the
diagnosis reproduced exactly. Each new RED capture fails at its own named
assertion.

Three new Majors opened, and the evaluator named the pattern they share:

> Where an expectation is produced by the implementation under test, the
> assertion is decorative.

- **AC-003's byte-identity check** computed its expectation from
  `resolver_module._projection(...)`, the function under test. With the real
  resolver emitting a projection whose every `paths.include` was replaced by
  garbage, the suite stayed 63/0.
- **AC-044's `~` escape rule** had no component id containing `~`, so dropping
  the `~`→`~0` rule survived.
- **AC-043's "names every contributing instance"** had exactly one contributor,
  so "every" and "the first" were indistinguishable.

The evaluator also found and disclosed an error in its own harness: the module
under test ends with a `__main__` guard, so mutations appended after it never
execute on the CLI path. Two earlier "kills" were artefacts of that and were
withdrawn before the remaining mutants were re-run.

### Cycle 3 (seq 0767) — NEEDS_WORK, 1 Major

- **AC-044's `~` rule — closed.** `other~thing` exists in the fixture; dropping
  the escape dies at 60/5. The kill is doubly sourced: the pointer assertion
  fires, and the resolver's own step-12 schema self-validation independently
  rejects the non-canonical pointer.
- **AC-043 — closed.** `cap-beta` declares a second always-false
  `solo-never-facet`; naming only the first instance dies at 64/1 by exactly
  the one assertion that exists for it.
- **AC-003 — partially closed.** The valuable half is real: the expectation is
  now literal data and it discriminates. The second assertion added to close
  the other half does not, and that is the surviving Major below.

## Findings

### Major — AC-003's `projection_sha256` clause has no discriminating test

`tests/resolve-project-context-match-check.py:398-410`.

The assertion added to close cycle 2's Major A compares two values the driver
computed from data it had already compared one assertion earlier. The
canonicalizer is key-order insensitive, so canonical bytes are a pure function
of the parsed value, which means `captured == expected_projection` (`:255`)
logically entails `resolver_projection_sha256 == hand_projection_sha256`
(`:404`). The second assertion cannot fail unless the first already has.

Decisive measurement: the value AC-003 actually names — the Resolver's own
`projection_sha256` — survives replacement with `sha256:000…0` at 65/0.

Classified **Accepted**. Three routes close it: capture the resolver's own
derived value and compare against it; add a structural white-box check on
`main()`'s derivation; or disclose it as a structurally unverifiable remainder
alongside AC-044's `resolver.version` and withdraw the claim that cycle 2's
Major A is closed. The third is honest but leaves an acceptance criterion
unlocked, so it needs a decision rather than an edit.

Review ticket: `docs/review-tickets/RT-20260823-001.yml`.

### Minor findings

All classified **Accepted** and carried on the ticket.

1. `reports/implementation/epic-193-a5-capability-resolver/T-005.md`,
   Specification Differences item 2 — "independently recomputes every
   `context_binding` scalar" describes input construction, not verification.
2. `tests/resolve-project-context-match-check.py:462-481` — the Facet
   Manifest's `affected_components` is unasserted. Outside AC-007's enumerated
   field list, hence Minor rather than Major.
3. `:724-729`, `:785-805` — warn `detail` is asserted by substring only.
4. `verification/qg/T-005/focused-tests-{sh,ps1}.log`, and four other sh/ps1
   pairs, are byte-identical: the output format carries no runtime marker, so
   the `.ps1` artefacts cannot evidence that pwsh produced them. The gate ran
   pwsh itself and confirms both runtimes execute.
5. `red-misaggregated-facet-*.log` and `red-noncanonical-provenance-*.log` are
   63-assertion-era captures showing 62/1. Disclosed as historical rather than
   re-taken; each still fails at its own named assertion.
6. Two known-vacuous mutants remain open and were deliberately not closed:
   MUT-7 (`_required_facets` ignoring the matched set) and MUT-9 (truncating
   `_iter_warn_nodes` per evidence tree). Cycle 3 re-verified both are vacuous
   by fixture even after this cycle's fixture edits, and judged leaving them
   defensible.

## Notes on the gate's own conduct

Two defects in the gate machinery surfaced while running it, and both were
fixed rather than worked around.

`evaluator_output_is_declared` required a whole-line match on `## Outputs`
rows, so a row carrying annotation — which the workflow asks reports to write —
could not authorize its file even with an exact path and hash. epic-193 T-005
could not start a gate at all until that was fixed (`9c789bd7`), and its `.ps1`
parity twin was corrected in `7d55b5f0` after the drift-detector it pins caught
the omission.

Cycle 1's manifest was built from the first of two `## Outputs` tables and
therefore withheld TEST-056's own evidence from the evaluator. That was the
gate's error; the tables were merged and cycles 2 and 3 could reach them.

One structural limit is worth recording rather than fixing here. The evaluator
of a test-authoring task cannot line-read the code its tests exercise: the
role's allowlist admits Outputs-declared paths, and T-005 correctly declares
none of the resolver, because its Out of Scope forbids touching it. All three
cycles' mutation work was therefore performed blind, by scripted transforms in
an isolated copy, and reported by operator and function name rather than by
source content. The mutation evidence is strong on its own terms, but no cycle
performed a line-level review of the module under test.

## Disposition

`Status:` remains `Implementation Complete`. The cycle limit is reached, so no
further gate cycle may run for this task without human intervention.
