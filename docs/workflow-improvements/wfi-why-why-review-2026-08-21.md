# WFI Why-Why (5 Whys) Retroactive Review — 2026-08-21

## Purpose

The WFI flow now requires a `## Why-Why Analysis` causal chain in every new
Draft (template + workflow-retrospective step 1.75, audited by wfi-auditor-a's
`WHY-CHAIN-VALID` check). This review re-examines every WFI drafted before
that requirement existed and asks one question per WFI: does its
`## Root Cause Hypothesis` reach a controllable process/mechanism cause, or
does it stop at a symptom, an intermediate cause, or blame?

Historical WFI bodies are intentionally NOT edited by this review:

- `Audit-Content-Hash:` fields bind audit state to the exact body text.
- `Status:` transitions are governed (hook guard; human-only Approved).

This document is a sidecar. Where a chain was found deficient, the
recommendation column says what to do the next time that WFI (or its friction
pattern) is touched — typically: rebuild the why-chain and, if the terminal
cause differs from what was fixed, draft a follow-up WFI against the deeper
cause.

## Method

- Scope: every `docs/workflow-improvements/WFI-*.md` present on 2026-08-21
  (WFI-001–025, 029, 034–038; 31 documents). Auditor JSONs and audit-cycle
  reports were not consulted — the review grades the WFI document itself.
- Each WFI was read in full and its Root Cause Hypothesis classified:
  - **ROOT-CAUSE-REACHED** — names a specific controllable process/mechanism
    cause, and the Proposed Change acts on that cause.
  - **INTERMEDIATE-CAUSE** — a real mechanism, but a deeper "why" exists that
    the Proposed Change does not address (mitigation, not removal).
  - **SYMPTOM-LEVEL** — restates the friction or is circular.
  - **BLAME-STOP** — terminates at human/agent error or an uncontrollable
    cause.
- For every verdict below ROOT-CAUSE-REACHED, a reconstructed why-chain is
  recorded; speculative links are marked `(hypothesis)`.
- Cross-check: `Status: Regressed` / `Status: Rejected` outcomes were compared
  against the verdict — a fix that later regressed is prima facie evidence the
  chain stopped above the root cause.

## Summary

(to be filled from per-WFI findings)

## Per-WFI Findings

(to be filled)

## Follow-Up Recommendations

(to be filled)
