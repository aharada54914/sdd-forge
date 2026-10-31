---
name: diagnose
description: Execution discipline for hard bugs, regressions, flaky tests, and performance issues. Build a tight red feedback loop first, then reproduce/minimize, rank falsifiable hypotheses, instrument one variable at a time, and fix behind a regression test. Use before spec-ing a bugfix, or when the user says something is broken/throwing/failing/flaky/slow. Supplies the evidence that task-reviewer-b's BUGFIX-DIAGNOSTIC-PATH check requires.
disable-model-invocation: true
model: sonnet
---

# Diagnose

A discipline for hard bugs. Its output — a tight reproduction command, a
minimized case, a root cause, and a regression test — is exactly the evidence
`task-reviewer-b`'s `BUGFIX-DIAGNOSTIC-PATH` check verifies. Run `diagnose`
**before** writing the bugfix spec, so the spec and tasks are driven by a
confirmed root cause instead of a guess.

> **Adapted from** the field-tested `diagnosing-bugs` discipline. The rule is
> the same: **no red-capable loop, no hypothesis.**

## Invocation

Claude Code:

```txt
/sdd-implementation:diagnose <issue URL | symptom + reproduction steps>
```

Codex:

```txt
Use the diagnose skill. Symptom: <...>
```

## Preconditions

- Read `AGENTS.md`; if the repo has `CONTEXT.md` or ADRs for the affected
  modules, read them to build a mental model before touching code.
- `diagnose` is read-mostly: it may add a **failing test / harness** and
  **tagged temporary probes**, but the actual fix lands through
  `implement-task` after a spec + human approval.

## The five phases

Skip a phase only with an explicit, written justification.

1. **Build a feedback loop (this is the skill).** Construct one command that goes
   **red on _this_ bug**. See `references/diagnosis-loop-policy.md` for the ten
   ways to build one (failing test → curl → CLI+fixture → headless browser →
   trace replay → throwaway harness → property/fuzz → bisection → differential →
   HITL). **Completion criterion:** you can paste one command you have already
   run whose output is red, and it is red-capable (asserts the user's exact
   symptom), deterministic, fast (seconds), and agent-runnable. **If you catch
   yourself theorizing before this command exists, stop.**
2. **Reproduce + minimize.** Run the loop red; confirm it is the user's symptom
   (not a nearby one). Shrink to the smallest case that still goes red — every
   remaining element must be load-bearing. This becomes the regression test.
3. **Hypothesize (3–5, ranked, falsifiable).** Each in the form
   `If X is the cause, then changing Y makes it disappear / Z makes it worse.`
   Show the ranked list to the human before testing (cheap re-rank); proceed on
   your ranking if they are AFK.
4. **Instrument (one variable at a time).** Debugger/REPL > targeted logs at
   hypothesis boundaries > never "log everything and grep". Tag every temporary
   log with a unique prefix (e.g. `[DEBUG-a4f2]`) so cleanup is one grep. For
   performance, measure (baseline → bisect), do not log.
5. **Fix + regression test (test before fix).** Write the regression test at a
   **correct seam** first, watch it fail, then fix. **If no correct seam exists,
   that itself is the finding** — the architecture cannot lock the bug down;
   record it and recommend an architecture task. Remove all `[DEBUG-*]` probes.

## Output

Write `reports/diagnosis/<id>.md` from
`plugins/sdd-implementation/templates/diagnosis-report.template.md`, capturing:
the one reproduction command + its red output, the minimized case, the ranked
hypotheses and which survived, the root cause, and the regression test. This
report is the input to the bugfix spec and the evidence the
`BUGFIX-DIAGNOSTIC-PATH` check reads.

## Handoff — the lightweight bugfix track

Most bugfixes should **not** run the full three-review-loop flow. After
`diagnose`:

1. Default to the **lite track**: `/sdd-lite:lite-spec` (requirements/design/
   tasks driven by the diagnosis) → single human approval → `implement-task` →
   `lite-gate`. The diagnosis report and regression test satisfy
   `BUGFIX-DIAGNOSTIC-PATH`.
2. **Escalate to full track** only when the fix touches a `Risk: high/critical`
   surface (auth, payment, PII, migration, public API). Additive graduation:
   add `Risk:` + evidence bundle per `risk-gate-matrix.md`.

## Boundaries

- Do not land the fix here; `diagnose` produces evidence, `implement-task`
  applies the change under approval.
- Do not set `Approval` or `Done`; do not self-approve (hook guard enforces).
- Do not leave `[DEBUG-*]` probes or throwaway harnesses in committed code
  (keep the regression test, delete the scaffolding).
- If you genuinely cannot build a loop, stop and say so: list what you tried and
  ask the human for environment access, a captured artifact, or permission to
  add temporary instrumentation. Do not hypothesize without a loop.
