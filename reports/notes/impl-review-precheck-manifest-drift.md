# Drift note: impl-review-loop SKILL vs. task-review-precheck.sh / validate-review-context-set.sh

**Discovered**: 2026-07-22, feature `epic-189-a1-project-context`, during
Phase 2 task-decomposition orchestration.

**Symptom**: `task-review-precheck.sh`'s `require_persisted_pass` function
requires the persisted impl-review PASS evidence's impl-reviewer-a
`allowed_input_manifest` to include the *previous* round's
`integrated-summary.json` whenever the persisted PASS round is `> 1`:

```
if [[ "$stage" == "impl" && "$stored_round" -gt 1 ]]; then
  local previous_summary="reports/impl-review/${FEATURE}/attempt-${stored_attempt}/round-$((stored_round - 1))/integrated-summary.json"
  manifest_has "$role_a" "$previous_summary" ... ||
    fail "persisted impl reviewer-a manifest is missing previous-round summary"
```

`epic-189-a1-project-context`'s already-completed impl-review
attempt-1/round-2 (evidence committed at `661e05d`, genuine PASS, untouched)
does not include `attempt-1/round-1/integrated-summary.json` in
impl-reviewer-a's manifest, so `task-review-precheck.sh` refuses to run
against it (STEP 1 fails before any task-review evidence is created).

**Root cause**: `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md`
STEP 2 ("Invoke impl-reviewer-a") never instructs the orchestrator to add
the previous round's `integrated-summary.json` to impl-reviewer-a's manifest
when re-invoking at round > 1 ("Re-Invocation After Human Edits" section,
lines 244-251, says only to increment the round and require
`--edit-summary`). The evidence that was produced is therefore fully
compliant with the SKILL's own documented process, yet fails a stricter
downstream validator.

**Partial existing mitigation**: `validate-review-context-set.sh`'s
`path_is_authorized` function already anticipates this — its `impl:` case
has an inline comment citing **Issue #143** and explicitly authorizes
`reports/impl-review/<feature>/attempt-*/round-*/integrated-summary.json`
for *both* impl-reviewer-a and impl-reviewer-b, specifically so that
including the previous round's summary in reviewer-a's manifest does not
get rejected as "role-unlisted." This confirms the gap is already tracked
upstream (issue #143) but `impl-review-loop/SKILL.md`'s own STEP 2/
"Re-Invocation After Human Edits" text was never updated to actually
*require* the orchestrator to include it.

**This session's handling**: attempt-1's evidence was left untouched
(commit `661e05d` unmodified). A fresh impl-review attempt-2 was started via
the SKILL's own `--reset` semantics (`Impl-Review-Status: Passed` → `Pending`,
commit `11cf74a`) specifically to regenerate compliant evidence. For
attempt-2, if round > 1 is ever reached, the previous round's
`integrated-summary.json` will be explicitly included in impl-reviewer-a's
`allowed_input_manifest` (the precheck-script requirement is treated as
authoritative even where the SKILL text is silent, matching Issue #143's own
allowlist accommodation).

**Suggested permanent fix** (out of scope for this session — SKILL.md and
`plugins/sdd-quality-loop/scripts/` are protected paths this session does not
edit): update `impl-review-loop/SKILL.md` STEP 2 / "Re-Invocation After Human
Edits" to explicitly state that impl-reviewer-a's manifest must include the
immediately-previous round's `integrated-summary.json` whenever round > 1,
mirroring `task-review-precheck.sh`'s `require_persisted_pass` requirement
and closing Issue #143 for good (rather than only being accommodated
downstream in `validate-review-context-set.sh`'s allowlist).

Related: `docs/adr/` none directly; `AGENTS.md` "Review gate precheck
fallback" (issue #61) covers a different, adjacent class of precheck defect
(manual-precheck fallback requiring explicit human approval) and was
considered but not used here, since a self-contained genuine re-attempt
(this note) fully resolves the gap without needing that fallback.
