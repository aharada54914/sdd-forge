---
name: domain-review-loop
description: Independently review the domain/ artifact set (strategic + tactical) before human approval of Domain-Model-Status. Persists a validated domain review verdict and detects post-approval drift.
disable-model-invocation: true
user-invocable: false
---

# Domain Review Loop

Run this manually after `domain-interviewer` (T-002) has produced the seven
canonical `domain/` artifacts and before a human sets
`Domain-Model-Status: Approved` in `domain/context-map.md`. It is the only
workflow mechanism permitted to change `Domain-Model-Status: Pending` to
`Domain-Model-Status: Reviewed`. It never writes `Approved` — only a human may
do that, and the hook guard (T-006) rejects an agent-authored write of that
value.

## Invocation

```text
/sdd-domain:domain-review-loop [--edit-summary="..."] [--reset]
```

Invoked internally by `domain-model` (T-004); not a user-facing command
(`disable-model-invocation: true`, `user-invocable: false`).

## Preconditions

Read `domain/context-map.md` and confirm every one of the seven canonical
`domain/` artifacts exists (per `domain-interviewer`'s Seven-Stage Sequence
table) plus `domain/domain-contract.json`. The context-map header must
declare `Domain-Model-Status: Pending`. Determine the next attempt and round
from persisted `reports/domain-review/attempt-<M>/round-<N>/` evidence; do not
invent or replay a round. Invoke
`plugins/sdd-domain/scripts/domain-review-precheck.sh <attempt> <round>` with
the matching `--edit-summary` or `--reset` option before creating reviewer
input.

The precheck validates canonical paths, positive attempt/round counters,
status, input hashes, immutable destination, lock, and legal state
transition. It also performs the AC-014 drift check described below. Stop on
any error; do not write a report or status field. It records canonical hashes
used by the shared review-contract validation foundation.

## AC-014 Drift Detection (precondition, not the hook guard)

This is a distinct control from T-006's hook guard. The hook guard only
rejects an agent-authored write of `Domain-Model-Status: Approved`; it says
nothing about content changing *after* a human has already approved the
model. This precheck step is what detects that later drift and forces a
re-review before this loop may run again.

On every invocation (not only `--reset`), the precheck script:

1. Looks for a prior recorded Approved-state fingerprint at
   `reports/domain-review/last-approved-fingerprint.json`. This file is
   written only once, by this same precheck script, the first time it
   observes `Domain-Model-Status: Approved` in `domain/context-map.md` at
   the start of a run (i.e., a human approved since the last time this
   script ran). It is never written by a reviewer or by this skill's normal
   round-advancement path.
2. If no fingerprint file exists yet, there is no prior Approved state to
   drift from (the first-ever review, or every review before the first human
   approval) — skip drift detection entirely and proceed to the normal
   precondition checks.
3. If a fingerprint file exists, recompute the same normalized hash over the
   current `domain/` tree (every canonical artifact's SHA-256, using
   `context-map.md` with its `Domain-Model-Status:` line normalized to a
   fixed sentinel value before hashing — the same normalized-hash pattern
   `spec-review-precheck.sh` uses when substituting the `Spec-Review-Status:`
   line before its own input-hash computation, applied here to the
   `Domain-Model-Status:` field instead). Compare it to the fingerprint's
   recorded hash.
4. If the hashes match, no drift occurred since the last approval; proceed
   normally (this is the common case: re-review was invoked for an
   unrelated reason, or the fingerprint was just written this run).
5. If the hashes differ, a `domain/` file changed after the model was
   approved. Halt with a clear message naming which canonical path(s)
   changed (diff each artifact's individual SHA-256 against the fingerprint's
   per-file map) and instructing a human to reset
   `Domain-Model-Status` back to `Pending` in `domain/context-map.md` before
   re-review can proceed. Do not write a report, round directory, or status
   field. Do not attempt to reset the field automatically — only a human
   reset satisfies this halt, matching AC-014's requirement.

Once a human has reset the status field to `Pending` and this script is
invoked again, step 3's comparison naturally proceeds (the live status line
is normalized out of the hash, so the reset itself never re-triggers drift
detection) and review proceeds as a normal new attempt.

## Sequential launch boundary

Before each reviewer launch, persist one `review-context-invocation/v2`
manifest for that reviewer only. Bind its stage, role, feature, host-issued
run/session IDs, canonical input paths and SHA-256 values, plus the current
hash and final record hash of `reports/review-context/identity-ledger.json`.
The canonical identity ledger must already contain the invoking host/
implementation identity and every prior review/evaluation reservation; if it
is missing, stale, malformed, or has a broken hash chain, stop. Never
reconstruct history from caller-supplied ID lists.

`domain-review-loop` uses the fixed pseudo-feature slug `sdd-domain-model`
for the manifest's `feature` field (this gate reviews a project-level
`domain/` tree, not a per-feature `specs/<feature>/` tree, but the shared
`review-context-invocation/v2` schema requires a non-blank `feature` string;
`sdd-domain-model` is a stable, canonical stand-in value, not a real feature
slug under `specs/`).

Immediately before launching the named reviewer, reserve its identity with
one of:

```text
plugins/sdd-quality-loop/scripts/validate-review-context-set.sh <invocation-manifest> <repository-root> --reserve
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 -Manifest <invocation-manifest> -RepositoryRoot <repository-root> -Reserve
```

Require `REVIEW_CONTEXT_OK`, then launch exactly the role/run/session named in
that reserved manifest. A non-zero result blocks launch. Because reservation
is sequential, reviewer A never depends on a future reviewer B or any other
stage's context.

Note: `validate-review-context-set.{sh,ps1}`'s `path_is_authorized` function
must recognize the `domain:domain-reviewer-a` / `domain:domain-reviewer-b`
stage/role pair and its allowed-path patterns (the seven canonical `domain/`
artifacts, `domain/domain-contract.json`,
`plugins/sdd-domain/references/domain-review-calibration.md`,
`reports/domain-review/attempt-<M>/round-<N>/precheck-result.json`, and, for
reviewer B only, that round's `integrated-summary.json`), matching the
existing `spec`/`impl`/`task` cases exactly in structure. This task adds that
case to both language twins of the shared validator (not the hook guard,
which is a separate file with a separate, self-protected suffix list).

## Independent reviewer sequence

1. Build a stage `domain` allowed-input manifest from the precheck result.
   Include the seven canonical `domain/` Markdown artifacts,
   `domain/domain-contract.json`,
   `plugins/sdd-domain/references/domain-review-calibration.md`, and the
   precheck-result path with hashes.
2. Start `domain-reviewer-a` in a fresh host context with a new `run_id` and
   a host-session identifier that is distinct from every other reviewer
   session. Build and reserve its invocation manifest through the sequential
   launch boundary immediately before starting the host context. Persist its
   returned raw JSON as `reviewer-a.json`; reviewers themselves have no
   write capability.
3. Create `integrated-summary.json` containing only check IDs, severities,
   and counts. It must not reproduce any raw finding text.
4. Start `domain-reviewer-b` in a separate fresh host context. Its allowed-
   input manifest contains only the canonical artifacts, calibration
   reference, precheck result, and that sanitized summary. It must never
   receive `reviewer-a.json`. Build and reserve a new invocation manifest
   against the ledger state produced by reviewer A immediately before
   launch.
5. Validate both returned schemas, stage/role/run/session identity, allowed
   manifests, and input hashes. Derive the sanitized A summary from A's
   checks, then derive `integrated-verdict.json` from both outputs. Reject a
   duplicated or blank host-session ID, raw report path, altered input,
   malformed output, or a verdict/warning count that contradicts the checks.
6. Write `domain-review-contract.json` and the report from the supplied
   templates only after that validation. The contract must exactly repeat
   the derived verdict and `warningCount`; it is not an independent source
   of truth.

## Verdict aggregation (AC-005)

Identical aggregation rule to `spec-review-loop` / `impl-review-loop` /
`task-review-loop`. Compute across both reviewers' `checks` arrays combined:

- `critical` = count of `FAIL` checks with `severity: Critical`.
- `major` = count of `FAIL` checks with `severity: Major`.
- `minor` = count of `FAIL` checks with `severity: Minor`.

Merged verdict:

- `critical > 0 or major > 0`, round `< 3` → `NEEDS_WORK`, `warningCount: 0`.
- `critical > 0 or major > 0`, round `== 3` → `BLOCKED`, `warningCount: 0`.
- `critical == 0 and major == 0 and minor > 0`, round `< 3` → `NEEDS_WORK`,
  `warningCount: 0` (a round before the terminal round never resolves as a
  Minor-only PASS; only round 3 does).
- `critical == 0 and major == 0 and minor > 0`, round `== 3` → `PASS`,
  `warningCount: minor` (the round-3 Minor-only PASS carries a nonzero
  warning count forward as evidence, matching the existing gates).
- `critical == 0 and major == 0 and minor == 0` → `PASS`, `warningCount: 0`
  (clean pass, any round).

Never waive findings. Only a validated merged PASS may advance
`Domain-Model-Status`.

## State transition rules

| State | permitted invocation | result |
|---|---|---|
| Pending, no evidence | round 1 | PASS changes header to `Reviewed`; finding creates NEEDS_WORK |
| Pending, round 1/2 NEEDS_WORK | `--edit-summary`, next round | clean PASS changes header; otherwise writes NEEDS_WORK |
| Pending, round 2 NEEDS_WORK | `--edit-summary`, round 3 | Minor-only produces PASS (header -> `Reviewed`) with `warningCount > 0`; Major/Critical produces BLOCKED |
| Pending, blocked or completed attempt | `--reset`, next attempt round 1 | preserve prior evidence and retain Pending |
| Reviewed or Approved | any normal invocation | reject; a `Reviewed` or `Approved` model requires `--reset` (or, for `Approved`, the AC-014 drift path above) before another round may run |

A round-3 Minor-only PASS remains a PASS for downstream predecessor checks
(cross-model-verify, T-011, and eventual human approval).

## Required evidence

Each round directory
(`reports/domain-review/attempt-<M>/round-<N>/`) contains
`precheck-result.json`, reviewer output targets, `integrated-summary.json`,
`integrated-verdict.json`, `domain-review-contract.json`, and a rendered
report. Save only the orchestrator summary across reviewer boundaries. The
reviewer role files declare cross-stage raw-report denial and are
intentionally distinct from spec/impl/task review roles.

## Calibration Boundaries

Reviewers must read
`plugins/sdd-domain/references/domain-review-calibration.md` before emitting
findings. The calibration keeps this gate focused on strategic and tactical
domain-model soundness: context boundaries and relations must be
unambiguous, terms must be unique, events must be traced, invariants must be
verifiable, transaction boundaries must be realistic, and aggregates must be
neither god-aggregates nor anemic. The gate must not require downstream
conformance wiring, cross-model verdicts, or implementation-ready detail.

## Extension point: cross-model verification (T-011, implemented below)

When a round's merged verdict is `PASS` (clean or round-3 Minor-only), this
skill invokes cross-model-verify here, between the skill's own PASS
determination and the point where a human is invited to set
`Domain-Model-Status: Approved`.

> INSERT POINT (T-011): after Verdict aggregation yields PASS for the current
> round, and before reporting the round complete to the human, invoke
> cross-model-verify (`prepare-panelist-input.sh` / `check-cross-model.sh`)
> under human authorization. A vendor mismatch or `panelist-unavailable`
> result sets `requires_human_decision` and blocks auto-continuation
> (AC-006, AC-017). See "Cross-model verification (T-011)" below for the full
> invocation procedure.

## Cross-model verification (T-011)

This section runs only after this loop's own Verdict aggregation (above) has
produced `PASS` for the current round -- clean or round-3 Minor-only. It
never runs on `NEEDS_WORK` or `BLOCKED`. A cross-model PASS is required once
per review-loop PASS (not per round, and not re-run just because a human
later asks to re-inspect a `Reviewed` model); if this loop's own round is
re-run under `--reset` after a `BLOCKED` terminal state, the prior
cross-model result is stale and this step runs again against the new PASS.

### Why this cannot use the tasks.md-mediated consent path

`prepare-panelist-input.sh` (and its `.ps1` intent -- no `.ps1` twin exists
in this repository; see T-005's report for the established bash-only
precedent for this script class) gates every invocation on a fail-closed
consent check at lines 89-95: it looks for a line `Cross-Model: enabled`
inside the named task's own section of `--tasks-file` (default
`<spec-root>/<feature>/tasks.md`), and only falls back to a valid `SDD_SUDO`
token (lines 119-219) if that flag is absent. `domain/` is a project-level
tree with no `specs/<feature>/tasks.md` section of its own -- there is no
task section named `sdd-domain-model` in any `tasks.md` for the human-flag
path to read. This is exactly the residual risk design.md's Assumptions
section records against `prepare-panelist-input.sh:27-59` and
`check-cross-model.sh:35`: the scripts accept any non-empty `--task` and
`--input` value with no existence lookup, but the consent gate itself is
task-section-shaped and domain-review-loop has no task section to point it
at.

Verified directly against the current script source (not merely trusted
from design.md): `prepare-panelist-input.sh` lines 96-117 scan
`$tasks_file` line-by-line for a `## <task_id> ...` heading and a
`Cross-Model: enabled` line within that section; if the file does not exist,
or the section is never found, `consent_kind` stays empty and control falls
through to the `SDD_SUDO` check at line 120. No other code path grants
consent. This confirms the design.md Assumptions citation is accurate as
written -- the fallback path is real and is precisely `SDD_SUDO`, not a
tasks.md flag invented for this task.

Consequently, this skill **always** uses the `SDD_SUDO` consent path for the
domain gate, never the `Cross-Model: enabled` tasks.md flag. This is a
deliberate, human-authorized invocation, matching this task's Goal: "invoke
cross-model-verify's underlying scripts directly under human (`SDD_SUDO`-
style) authorization." Before invoking `prepare-panelist-input.sh`, confirm a
valid `SDD_SUDO` token is active (per `sudo-mode-policy.md`); if none is
active, stop and tell the human to run `/sdd-sudo` first -- do not attempt to
create, edit, or infer a token, and do not fall back to fabricating a
tasks.md flag for a tree that has no `tasks.md`.

### Preparing the sanitized bundle

Cross-model verification sends the reviewed `domain/` artifact set to
external vendor panelists. Per the B4 security-boundary row (design.md's
Security Boundaries table and `security-spec.md`'s Data Classification and
Protection section), the bundle must exclude real person names and
customer-identifying values -- role/system names only. This constraint is
layered, not single-point:

1. `domain-interviewer` (T-002) already states this constraint at stage 1
   intake, so canonical `domain/` Markdown should not contain real person or
   customer names in the first place.
2. `prepare-panelist-input.sh`'s own sanitization pass (credential
   assignments, AWS/GitHub/OpenAI-shaped tokens, absolute Unix/Windows
   paths, private/RFC-1918 URLs, internal/corp hostnames) is the second,
   independent line of defense and runs unconditionally on every bundle it
   writes, regardless of caller.
3. Before invoking the script, skim the assembled `domain/` artifact set
   (the seven canonical Markdown files) for any obvious real person name or
   customer identifier that the pattern-based sanitizer would not catch
   (patterns 1-9 in the script target secrets and paths, not proper nouns).
   If one is found, stop and report it rather than sending the bundle --
   this is a content-authoring defect in the reviewed model, not something
   this skill may silently redact and continue past.

Invoke with `--task DM-001 --feature sdd-domain-model --input domain/`,
matching the domain-scoped identifier pattern design.md's Assumptions
section already validated end-to-end for these scripts (`DM-001` is a
constant task-identifier label for this gate, distinct per invocation only
by attempt/round in the output path if desired; it is never a real
`specs/<feature>/tasks.md` task ID). `--feature sdd-domain-model` reuses the
same fixed pseudo-feature slug this skill's launch boundary already uses for
`review-context-invocation/v2`, keeping every artifact this loop produces
under one consistent, non-`specs/`-shaped label. Direct the bundle to
`reports/domain-review/attempt-<M>/round-<N>/cross-model/` via `--out` (not
the script's `specs/<feature>/verification/` default, which assumes a
`specs/` tree that does not exist for this project-level gate):

```text
plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh \
    --task DM-001 --feature sdd-domain-model --input domain/ \
    --out reports/domain-review/attempt-<M>/round-<N>/cross-model/DM-001.panelist-input.txt
```

Record the printed `input_digest` (the script's sole stdout line on success)
in the round directory; it is passed to `check-cross-model.sh` as
`--expect-digest` below so a panelist that received different content than
what was actually sent is caught rather than silently trusted.

A non-zero exit here (consent denied, missing `domain/` input, sanitization
tool error) means no bundle was written and no panelist may be invoked.
Treat this the same as `panelist-unavailable` for every configured vendor
slot (see below) -- halt with `requires_human_decision` rather than
proceeding without cross-model coverage.

### Invoking panelists

Once the sanitized bundle exists, invoke each configured panelist
(`sdd-quality-loop:sdd-panelist-gpt`, `sdd-quality-loop:sdd-panelist-gemini`
-- reused unchanged per design.md's Components table and the
`requirements.md` Assumptions) in a fresh, isolated context per the existing
cross-model-verification-policy.md contract: blind, parallel, no cross-talk,
no visibility into the other panelist's verdict, the evaluator's verdict, or
prior review-ticket history. Each panelist reads only the sanitized bundle
and writes its own `cross-model-verdict/v1` JSON to
`reports/domain-review/attempt-<M>/round-<N>/cross-model/DM-001.panelist-<vendor>.verdict.json`.

If a configured panelist's host context cannot be started, errors before
producing a verdict JSON, or produces no file within the invocation, record
that vendor slot as `panelist-unavailable` in this round's cross-model
summary and proceed to the gate step below with whatever verdict files did
get produced -- do not retry indefinitely and do not substitute a
fabricated verdict on the missing panelist's behalf.

### Running the deterministic gate

Invoke `check-cross-model.sh` (or `.ps1` on a host without bash) against the
same round directory used for `--out` above, passing the recorded digest so
a digest mismatch is caught as a hard failure rather than a silent pass:

```text
plugins/sdd-quality-loop/scripts/check-cross-model.sh \
    --task DM-001 --feature sdd-domain-model \
    --spec-root reports/domain-review/attempt-<M>/round-<N> \
    --expect-digest <input_digest from prepare-panelist-input.sh>
```

(`--spec-root` is repurposed here exactly as `--out`/`--input` were above:
the script only ever joins `<spec-root>/<feature>/verification/` as a plain
path, per design.md's Assumptions citation of `check-cross-model.sh:35`'s
string-interpolation construction, so pointing it at this round's own
directory keeps every cross-model artifact colocated with the round's other
evidence instead of scattered under a `specs/` tree that does not exist for
this gate.)

Read the resulting `cross-model-aggregate/v1` JSON
(`DM-001.cross-model.json`) written by the script. Three outcomes matter to
this skill:

1. **`result: "PASS"`, `requires_human_decision: false`** -- clean
   cross-model consensus (`vendors_distinct >= 2`, `non_anthropic_count >=
   1`, all collected verdicts `PASS`, no `Critical` finding, digest
   verified). Proceed: report the round complete to the human as ready for
   `Domain-Model-Status: Approved`, attaching both this round's
   `domain-review-contract.json` and the cross-model aggregate as evidence.
2. **`result: "FAIL"` from the diversity check
   (`vendors_distinct < 2` or `non_anthropic_count < 1`)** -- this is the
   observable shape of a `panelist-unavailable` outcome from the prior step:
   fewer usable verdict files were collected than the panel requires. Set
   `requires_human_decision: true` in this round's cross-model summary,
   record which vendor slot(s) are `panelist-unavailable`, and stop. Do not
   auto-continue to the human-approval invitation; report the round as
   cross-model-blocked, distinct from a normal `PASS`/`NEEDS_WORK`/`BLOCKED`
   verdict from this loop's own two-reviewer aggregation.
3. **`result: "FAIL"` from the consensus check (a collected verdict is not
   `PASS`, or any `Critical` finding is present), or `result: "NEEDS_HUMAN"`
   from a digest mismatch** -- a vendor mismatch. Set
   `requires_human_decision: true`, record the mismatching vendor(s) and the
   script's stated reason (`not all verdicts are PASS`, `Critical finding(s)
   present`, or `input_digest mismatch`) verbatim from its stderr output,
   and stop. Do not auto-continue.

In every case in outcomes 2 and 3, `requires_human_decision: true` blocks
auto-continuation exactly as it does for this loop's own two-reviewer
verdict (AC-006, AC-017): the human is told cross-model verification did not
cleanly pass and must decide how to proceed (re-run with a fixed panel,
accept the risk explicitly, or send the model back for another
domain-review-loop round) before `Domain-Model-Status: Approved` may be set.
This skill never sets `Domain-Model-Status: Approved` itself regardless of
cross-model outcome -- see Boundaries below.

### Recording the result

Write `reports/domain-review/attempt-<M>/round-<N>/cross-model-summary.json`
containing at minimum: the `input_digest`, the list of configured vendor
slots and which (if any) are `panelist-unavailable`, the raw
`cross-model-aggregate/v1` content, and the resulting
`requires_human_decision` boolean. This file, not a re-derivation, is what
the round's rendered report and the human-facing summary must cite -- the
same "write only after validation, never re-derive" discipline this skill's
Independent reviewer sequence already applies to
`integrated-verdict.json`/`domain-review-contract.json`.

Do not build, stub, or simulate the cross-model invocation for testing this
skill's documentation contract -- the deterministic parts
(`prepare-panelist-input.sh`, `check-cross-model.sh`, and the
consent-gate/argument-construction logic above) are covered by
`tests/sdd-domain/cross-model-gate.Tests.ps1`; the panelists themselves are
LLM subagents with no deterministic harness, consistent with how this
skill's own two reviewers are covered by
`tests/sdd-domain/domain-review-loop.Tests.ps1`.

## Boundaries

- Never write `Domain-Model-Status: Approved`. This skill only ever writes
  `Pending` (never, in the forward direction) or `Reviewed`; the Approved
  transition is exclusively a human edit, enforced by T-006's hook guard.
- Never invoke `domain-reviewer-a` and `domain-reviewer-b` in the same agent
  context. Each must run in a fresh, isolated context.
- Never pass `reviewer-a.json` directly to `domain-reviewer-b`. Use
  `integrated-summary.json` (counts and IDs only) as the only bridge.
- Never waive a finding or fabricate a PASS. Only a validated merge as
  described above may advance the status field.
- Never perform the AC-014 status reset on a human's behalf; halt and report
  instead.
- Never invoke cross-model-verify through the `Cross-Model: enabled`
  tasks.md flag path; `domain/` has no `specs/<feature>/tasks.md` section for
  that flag to live in. Always use the `SDD_SUDO` consent path and confirm a
  valid token is active before invoking `prepare-panelist-input.sh`.
- Never report a round as ready for `Domain-Model-Status: Approved` on this
  loop's own PASS alone. A round-PASS from the two-reviewer aggregation is a
  necessary, not sufficient, condition -- cross-model verification must also
  resolve to `result: "PASS"` with `requires_human_decision: false` first.
- Never auto-continue past a cross-model vendor mismatch or a
  `panelist-unavailable` slot. Both set `requires_human_decision: true` and
  stop this skill's flow at the cross-model step, exactly as a Critical/Major
  FAIL stops it at the two-reviewer aggregation step.
- Never send an unsanitized `domain/` bundle to a panelist. Skim for real
  person names or customer identifiers before invoking
  `prepare-panelist-input.sh` even though its own pattern-based sanitizer is
  the second line of defense; stop and report rather than redact and
  continue if one is found.
