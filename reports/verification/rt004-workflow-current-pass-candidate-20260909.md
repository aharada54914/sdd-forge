# RT004 Bash current-PASS wiring — 2026-09-09

Status: partial patch DATA, not an applied or executed validator, not an independent review or quality-gate PASS.

Candidate: reports/verification/adr-workflow-bash-history-candidate-20260909.patch
SHA256: 3756bf0ccfd239fbe31dbc65281256ece419b07032223104c76bed49609b5fd0
Actual Bash validator remains 15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e.

## Change and primary review

- Connect verified historical ADR bindings to the impl-only manifest allowlist. Historical binding checks raw ADR paths before the older relocation path logic, preserving the prohibition on ADR aliases.
- Add the same restricted design-declaration lexer used in the persisted-consumer candidate. Current PASS verifies the exact declared path set, including the all-omitted case; declaration-set changes fail without freshness tolerance.
- Check design path safety and raw hash before/after parsing. Existing reviewed_hash_accepted and manifest_has_reviewed_hash still govern lifecycle normalization at check-workflow-state.sh:1172 onward.
- Check ADR path components before and after the existing manifest-byte check. The existing default raw hash comparison at check-workflow-state.sh:946 is retained, including its already-defined strictly-downstream opening tolerance. No new freshness tolerance is introduced.
- Failed historical openings still return before current design/ADR inspection, but only after saved-state validation.
- Primary review caught a malformed-contract error being indistinguishable from absent extension in the new helper's jq -e branch. The candidate now parses one object explicitly and errors on invalid JSON/read failure.

Static check only: all seven hunk counts, source anchors and cumulative offsets match the current original source; 333 added lines. No copied/extracted/candidate validator was executed.

## Unresolved

- PowerShell 5.1 workflow equivalent and complete positive/negative consumer fixtures remain pending. Existing actual historical regression stays 2 passed / 6 failed; this turn did not rerun it or claim the candidate fixes it.
- Integrated verdict formula must still be reconciled with the canonical producer: impl-review-loop/SKILL.md:180-185 defines persisted merge outcomes, while :264-269 prints terminal BLOCKED for round-3 unresolved major findings. Do not infer the persisted value solely from the terminal message. The candidate formula has not been changed on that inference.
- Historical predecessor-summary/layer completeness, Windows reparse behavior, concurrent replacement limits and duplicate JSON keys remain review points.
- Independent security/contract review before protected human application, actual scoped tests, fresh formal review and required CI remain mandatory.
- Seven open PR heads freshly checked and unchanged (401, 400, 394, 390, 381, 371, 245). No commit/push/merge/issue close or verdict modification.

Preparation errors were non-executing: an ambiguous textual anchor was narrowed; apply_patch rejected a delete/add pair targeting the same file, after which a normal Update File patch was used. Neither failed preparation changed a protected target.
