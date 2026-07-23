# Defect/decision note: `epic-196-a8-integration` registry profile blocks impl-review-precheck

Status: **resolved by human authorization (2026-07-23) — candidate 2
selected.** See "Human authorization" section below for the verbatim
decision and its scope. Originally filed by the impl-review-loop
orchestrator for `epic-196-a8-integration` after `impl-review-precheck.sh`
failed before any reviewer was invoked and before any evidence directory
was created.

## Timeline

1. `bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh
   epic-196-a8-integration 1 1` failed:
   `ERROR: impl-review-precheck: layer review input is missing or
   substituted: specs/epic-196-a8-integration/ux-spec.md` (exit 1, no
   `reports/impl-review/epic-196-a8-integration/` created).
2. Root cause: `specs/workflow-state-registry.json` registers
   `epic-196-a8-integration` as `"profile": "full"`, which
   `impl-review-precheck.sh` (lines ~343-350) requires to mean `ux-spec.md`
   / `frontend-spec.md` / `infra-spec.md` / `security-spec.md` exist and are
   hash-bound. None of the four exist in
   `specs/epic-196-a8-integration/` (only `acceptance-tests.md`,
   `design.md`, `investigation.md`, `requirements.md` do) — by design:
   `design.md`'s own `## Layer Specifications` section (line 122) states
   these four files are deliberately not produced, citing
   `requirements.md`'s Risks section and `investigation.md` INV-018.
3. A proposed remedy — author the four layer files as pure restatements of
   `design.md`'s already-fixed determinations, following
   `epic-195-a7-compatibility` ("Epic A7") as precedent — was investigated
   and then withdrawn before any file was written, for two reasons found by
   direct inspection of the cited precedent and this feature's own spec:
   - **A7 is not a clean precedent.** `specs/epic-195-a7-compatibility/
     design.md`'s own `## Layer Specifications` section (unchanged since
     authoring) still asserts "no ux-spec.md/frontend-spec.md/
     infra-spec.md/security-spec.md is produced ... folded into this
     document instead," even though the four files now physically exist —
     `git show --stat b0df179` (in the `sdd-forge-wt-epic-195` worktree)
     shows the commit that added them touched only the four new files,
     never `design.md`'s contradicting prose. A7's own impl-review is also
     unresolved: its round-2 remedy commit `a807ff5` states one finding is
     "NOT applied" and "round 3 not yet invoked." A7 is a live,
     self-contradictory, in-progress case, not an established pattern to
     copy.
   - **`epic-196-a8-integration`'s own `requirements.md` (already
     `Spec-Review-Status: Passed`) explicitly forbids the proposed fix.**
     Its Risks section (lines 783-791) names this exact scenario — a
     4-file, no-layer-spec deviation matching Epic A7's precedent — and
     states in plain text that the resulting `check-sdd-structure.sh`
     missing-file report is "intentional per this task's explicit
     Phase-1-only mandate, **not a defect to silently 'fix' with
     placeholder files**." Authoring the four layer files, even as
     restatement-only content, would contradict an already-approved,
     specific spec decision — not something an orchestrator (or a
     coordinator agent) may override unilaterally.
4. A second candidate remedy — correct the registry's `profile` value away
   from `full` — was investigated mechanically by reading how `profile` is
   consumed by every relevant script, and by verifying two cited reference
   cases directly. Conclusion below: **no existing profile value fits.**

## Mechanical profile-branch reading

- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` — never reads
  `profile`. No value affects it.
- `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` — never reads
  `profile` either. Given a feature argument it always requires all nine
  canonical per-feature files (including the four layer specs) and reports
  the rest as `missing:`; this is the exact, already-accepted behavior
  `requirements.md`'s Risks section names as intentional, independent of
  registry profile.
- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` (the script
  that gates every review-precheck, including `impl-review-precheck.sh`
  line ~269) — lines 650-717: for a `lite`-profile entry (line 655) or a
  `legacy`-profile entry (line 656), the per-feature loop hits `continue`
  immediately. This does not just waive the four-layer-file requirement —
  it also skips the `requirements.md`/`design.md`/`acceptance-tests.md`
  existence checks **and** `validate_passed_stage()`, the function that
  cryptographically verifies a claimed `Spec/Impl/Task-Review-Status:
  Passed` against its hash-bound reviewer evidence. Reassigning this
  feature's profile away from `full` would silently stop
  `check-workflow-state.sh` from ever validating this feature's actual
  review-loop provenance again — a materially larger rigor loss than the
  missing-layer-files problem it would solve.
- `legacyEntry` in `contracts/workflow-state-registry.schema.json` is a
  closed `oneOf` enumeration of exact pre-existing `const` objects. A new
  feature cannot be assigned `profile: legacy` without editing the schema
  file itself (a contract change, outside this orchestrator's authority
  and outside impl-review-loop's scope).

## Reference-case verification

- **`sdd-domain`** (suggested as a near-precedent): registered `legacy`,
  and does have `reports/impl-review/sdd-domain/` evidence across three
  attempts. But `specs/sdd-domain/` physically has all four layer files,
  and the registry entry's own `legacy.reason` states "spec and impl stage
  provenance validate clean under **the full profile**" — it was
  grandfathered solely for a task-review-round-2 evidence-schema
  nonconformance caused by `jq` being absent on the authoring machine, not
  for omitting layer specs. Not a precedent for this feature's situation.
- **`lite`-profile features** (`p0-hardening`, `sdd-diagnose`, `sdd-lite`):
  none has a `reports/impl-review/<feature>/` directory — none has ever run
  through `impl-review-loop`. This matches `impl-review-loop`'s own
  SKILL.md LITE-SKIP clause: `lite` means the formal review loop is skipped
  entirely, not "full review rigor without layer specs."

## Conclusion

`full` (current — blocks precheck on missing layer files), `lite`
(schema-legal but drops all `check-workflow-state.sh` provenance
verification for this feature), and `legacy` (schema-closed to a fixed
historical list; also semantically wrong here) each fail to reproduce the
one shape this feature's already-passed spec actually calls for: full
review-loop provenance rigor, with no layer-spec requirement. No registry
edit was made.

## Candidate resolutions for human decision

1. Add a new registry profile value (e.g. `full-no-layers`) recognized by
   `contracts/workflow-state-registry.schema.json`,
   `check-workflow-state.sh`, and `impl-review-precheck.sh` — a
   gate-infrastructure change outside impl-review-loop's own scope.
2. **SELECTED by human authorization, 2026-07-23.** Grant an
   explicit, case-scoped deviation authorization analogous to AGENTS.md's
   issue #61 manual-precheck fallback: a human-approved manual
   `impl-review-precheck` that waives only the four-layer-file existence
   check while keeping identity-ledger reservation, hash-manifest binding,
   and reviewer strictness fully intact (the same shape as the human's
   prior choice for `epic-195-a7-compatibility` round 2's manual
   spec-review precheck, commit `c5de142` in the A7 worktree).

   Open check resolved before use, 2026-07-23: does
   `check-workflow-state.sh`'s `validate_passed_stage()` (lines 561-575,
   `impl` branch) re-demand the four layer files once `Impl-Review-Status`
   reaches `Passed`? Re-read directly: the entire layer-file verification
   block is gated by
   `if [[ "$(jq -r '(.layer_sha256 // {}) | length' "$precheck")" -gt 0 ]]`
   — it reads only `precheck-result.json`'s own `layer_sha256` field, never
   the registry's `profile` value. A manual `precheck-result.json` that
   records `layer_sha256: {}` (the only honest value, since the four files
   do not exist) makes this condition false, so the block — and with it
   any re-demand of the four layer files — never executes. **Confirmed: no
   re-trigger.** This holds regardless of the registry keeping
   `profile: full` (which it does; no registry edit was made or is planned
   under this authorization).
3. Human amendment of `requirements.md`'s Risks section (765-791) to
   retract the "not a defect to silently fix with placeholder files"
   language and formally authorize adding the four layer files after all —
   reopens an already-passed spec-review artifact and was not pursued
   without explicit authorization.

## Human authorization

Record of the human's decision (not this orchestrator's own signature, and
not the coordinator's own signature — a record of what the human said).
Date: 2026-07-23. Channel: the coordinator agent's own chat with the human
(this orchestrator has no direct channel to the human); relayed to this
orchestrator by the coordinator, who quoted it verbatim. Context: the
coordinator had added this note's escalation to a numbered list of pending
human decisions across this session's several parallel orchestrators, with
this feature's issue filed as "判断5" ("decision/judgment 5"), and had
recommended candidate 2 above as the answer to decision 5. Verbatim human
instruction, as relayed by the coordinator: "判断2・5については認可する"
("I authorize decisions/judgments 2 and 5") — decision 5 being this note's
escalation; decision 2 belongs to a different, unrelated orchestrator
thread in this session and is out of scope for this note.

Scope of what is authorized, as stated by the coordinator when relaying the
decision: a case-scoped manual `impl-review-precheck` for
`epic-196-a8-integration`'s impl-review only — the four-layer-file
existence/hash check is waived for this feature's impl-review-precheck
alone, while identity-ledger reservation, hash-manifest binding, and
reviewer strictness all remain fully intact and unmodified. Explicitly
**not** a standing exemption from the full-profile layer-file requirement,
and **not** any of: a registry `profile` change, a new registry profile
value, or an amendment to `requirements.md`'s Risks section (candidates 1
and 3 above remain unauthorized and unapplied). No review finding is
waived by this authorization — it concerns precheck-input scope only, not
review outcome.

## Pointers

- Failing command: `bash plugins/sdd-review-loop/scripts/
  impl-review-precheck.sh epic-196-a8-integration 1 1`
- `specs/epic-196-a8-integration/design.md:122-128` (Layer Specifications)
- `specs/epic-196-a8-integration/requirements.md:765-791` (Risks)
- `specs/epic-196-a8-integration/investigation.md:57` (INV-018)
- `specs/workflow-state-registry.json` (epic-196-a8-integration entry,
  `sdd-domain` entry)
- `contracts/workflow-state-registry.schema.json` (`legacyEntry` closed
  enumeration)
- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:650-717`
- Cross-worktree reference (read-only, `sdd-forge-wt-epic-195`):
  `specs/epic-195-a7-compatibility/design.md:97-113`, commits `b0df179`,
  `a807ff5`, `c5de142`.
