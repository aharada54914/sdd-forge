# Waiver Record: RT-20260821-016 — agci T-007 isolation-mode contradiction

- Date: 2026-08-23
- Decision maker: repository maintainer (aharada54914), via session directive
- Verbatim directive: 「標準判断についても承認する」 — approving the recorded
  recommendation for this item: "(b) waiver 受理 + WFI 起票"
- Recorded by: the session agent, from the maintainer's directive. The
  DECISION is the maintainer's; only the transcription is agent-authored.

## What is waived

The T-007 implementation report declares `Isolation Mode: fresh-agent /
Fallback Reason: none` while its own narrative describes a quota
interruption after which the orchestrator completed the work via
file-backed handoff — the `same-session-file-reload` path, which REQ-006
requires to be recorded with a fallback marker and a reload evidence
hash. That hash cannot be produced today without fabrication. The
retroactive isolation-marker requirement for this one attempt is waived.

## Why waiver rather than re-run

All six T-007 deliverables are byte-identical to implementation commit
`8af2b1fc` (commit-anchored); a re-run would reproduce the same bytes at
real cost. The "removed failing suites from run-all" suspicion was
separately PROVEN FALSE from git history (the removal was internal to the
attempt; the commit is purely additive) — that part needs no waiver.

## Root-cause follow-up (not waived)

The enforcement gap — no validator forces the fallback marker when an
orchestrator resumes after a quota interruption — is the subject of
WFI-044 (docs/workflow-improvements/WFI-044.md). This waiver is
contingent on that WFI remaining on file.

## Scope

Covers ONLY the missing isolation marker/hash for the recorded attempt.
The REQ-011 release-surface declarations and CI-evidence items from
RT-016 are NOT covered and remain open.
