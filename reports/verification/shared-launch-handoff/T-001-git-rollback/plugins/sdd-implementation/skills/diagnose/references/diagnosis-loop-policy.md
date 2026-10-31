# Diagnosis Loop Policy

Phase 1 of `diagnose` is the whole skill: build **one command that goes red on
_this_ bug**. Everything after it (bisection, hypothesis testing, instrumentation)
just consumes that loop. Spend disproportionate effort here.

## Ten ways to construct a loop (try in roughly this order)

1. **Failing test** at whatever seam reaches the bug (unit / integration / e2e).
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser** (Playwright / Puppeteer) driving the UI, asserting on DOM/console/network.
5. **Replay a captured trace** — save a real request/payload/event log, replay it through the code path in isolation.
6. **Throwaway harness** — a minimal subset of the system (one service, mocked deps) exercising the bug path in a single call.
7. **Property / fuzz loop** — for "sometimes wrong output", run 1000 random inputs and look for the failure.
8. **Bisection harness** — if it appeared between two known-good states, automate "boot at state X, check, repeat" for `git bisect run`.
9. **Differential loop** — run the same input through old vs new (or two configs) and diff outputs.
10. **HITL bash script** (last resort) — if a human must click, drive them with `scripts/hitl-loop.template.sh` so the loop stays structured; captured output feeds back.

## Tighten the loop (treat it as a product)

- **Faster**: cache setup, skip unrelated init, narrow scope.
- **Sharper signal**: assert the specific symptom, not "didn't crash".
- **More deterministic**: pin time, seed RNG, isolate filesystem, freeze network.

A 30-second flaky loop is barely better than none; a 2-second deterministic one is a superpower.

## Non-deterministic bugs

Goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×,
parallelize, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is
debuggable; 1% is not — keep raising the rate until it is.

## Completion criterion — a tight loop that goes red

Done when you can name **one command** you have **already run at least once**
(paste invocation + output) that is:

- [ ] **Red-capable** — drives the actual bug path and asserts the user's exact symptom.
- [ ] **Deterministic** — same verdict every run (flaky: a pinned, high repro rate).
- [ ] **Fast** — seconds, not minutes.
- [ ] **Agent-runnable** — runs unattended (human only via the HITL template).

No red-capable command, no Phase 2. If you cannot build one, stop and ask the human
for environment access, a captured artifact (HAR / log dump / core dump / timed
recording), or permission for temporary instrumentation — do not hypothesize blind.
