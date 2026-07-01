# Diagnosis Report: <id>

- **Symptom (user's words)**: <exact observed failure>
- **Source**: <issue URL / report>

## Phase 1 — Feedback loop
- **Command** (already run, goes red on this bug):
  ```
  <one command>
  ```
- **Red output** (proves it catches the symptom):
  ```
  <pasted failing output>
  ```
- Loop properties: red-capable [ ] · deterministic [ ] · fast [ ] · agent-runnable [ ]

## Phase 2 — Reproduce + minimize
- Confirmed it is the user's symptom (not a nearby one): <yes/notes>
- **Minimized case** (every element load-bearing):
  <smallest scenario still going red>

## Phase 3 — Hypotheses (ranked, falsifiable)
1. If <X> is the cause, then <Y> makes it disappear / <Z> makes it worse. — <survived? refuted?>
2. ...
3. ...

## Phase 4 — Instrumentation
- Probes used (tagged `[DEBUG-*]`, since removed): <what / where>
- Evidence that distinguished the hypotheses: <observation>

## Phase 5 — Root cause + fix
- **Root cause**: <one sentence>
- **Correct seam existed?**: <yes → regression test path | no → architecture finding + recommended task>
- **Regression test** (written before the fix, at the correct seam): <path / name>
- **Fix summary** (applied via implement-task under approval): <what changed>

## Handoff
- Track: <lite | full (Risk: high/critical reason)>
- Next: `/sdd-lite:lite-spec` (or full sdd-bootstrap) driven by this root cause.
