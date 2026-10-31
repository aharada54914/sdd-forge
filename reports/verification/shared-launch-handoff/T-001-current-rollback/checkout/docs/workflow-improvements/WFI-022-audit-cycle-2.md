# WFI Audit Report — Cycle 2

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-022 |
| Category | plugin-improvement |
| Cycle | 2 of 2 |
| Auditor Agent | wfi-auditor-b |
| Verdict | NEEDS_REVISION |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings (Advisory) | 1 |
| Generated | 2026-08-22T09:30:00Z |

## Verdict: NEEDS_REVISION

One deterministically-confirmed internal contradiction: Verification Plan step
(1) required all four replayed refusals to become allowed, while the Proposed
Change deliberately keeps the approval-removing sed refused (sed is not in
`SHELL_READ_ONLY_START_RE` and the broad write-capable match is kept), so
Target 0 was unreachable by the plan's own steps. Plus one staleness Minor:
WFI-012–015 were already flipped to Applied by human commit 5aa079c5
(2026-08-07), and the minimal Edit-path Applied transition is already allowed
and green-tested on all four twins. All revisions applied.

---

## Findings

### Critical Findings

None.

### Major Findings

- [MAJOR] VERIFICATION-COMPLETE — Baseline-4-to-Target-0 arithmetic counted an
  operation class (write-capable sed) the change deliberately does not unblock;
  step (1) contradicted the "Deliberately NOT proposed" paragraph.

### Minor Findings (Advisory)

- [MINOR] EFFECT-CONSISTENT-WITH-EVIDENCE — (a) the Edit-path Applied advance
  was claimed as newly allowed but is already allowed and green-tested
  (tests/guards.tests.sh sh/py/node legs; tests/hooks.tests.ps1); the actual
  2026-08-04 blockage was the shell-path sed. (b) Step (4) targeted WFI-012–015
  transitions a human already performed.

---

## Auditor Reasoning

All other checks PASS with evidence — notably META-CHANGE-ANTI-GOODHART
(Critical lane): anchoring cannot miss a real approval (no deterministic
consumer of the approval literal outside guard + suites); the Edit-path delta
still blocks every addition; the read-only exemption rides an invariant whose
loader fails closed (match-nothing on load error); check counts strictly
increase; the Target-Metric is tabulated by an untouched instrument. Full
detail: `WFI-022-auditor-b.json`.

---

## Proposed Revisions

1. `## Verification Metric` — exclude the write-capable-shell class from the
   Target-Metric; Baseline 4 → 3 with the sed reclassified expected-strict.
   **Applied.**
2. `## Verification Plan` step (1) + parity-suite row — 3 allowed + 3
   must-stay-refused (sed paired with its allowed Edit-path equivalent).
   **Applied.**
3. `## Expected Effect` + step (4) — Edit-path wording corrected; "Concretely"
   paragraph re-anchored to the future-WFI class with the 5aa079c5 fact; step
   (4) now targets WFI-022's own advance. **Applied.**
