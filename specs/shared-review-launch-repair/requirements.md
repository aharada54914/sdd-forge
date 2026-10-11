# Requirements: shared-review-launch-repair

Spec-Review-Status: Passed

## Scope and baseline

Bounded repair of the six existing environment concerns in `reports/verification/shared-review-launch-integration.md:3-8`; this document does not define a new review architecture or change product T-002. Existing native invocation, ledger, and receipt semantics remain authoritative (`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:37-77`). Historical implementation and diagnostic evidence are inputs for investigation only, not a verdict. Re-verify every shared-state fact below against the final review HEAD.

## Requirements

### REQ-001 — CLI aliases and shared non-TTY route

The real stage/role callers must construct CLI arguments accepted by the installed Claude CLI, with the existing model, exact permissions, one proposed session identity, and no fallback executor or silently weakened guard. Missing flags, wrong model, compound commands, and outside reads must be rejected. The current shared construction and native proof are in `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py:119,183-236,301-350`, `plugins/sdd-review-loop/scripts/probe-nontty-review.py:154-250`, and `plugins/sdd-review-loop/scripts/launch-impl-review.py:321-365`.

### REQ-002 — pre-reservation admission

Every required stage/role input must be canonical, allowed, path-exact, and hash-bound before reservation. Invocation raw SHA-256, ordered input hashes, conditional inputs, native permission proof, and preview receipt must agree; a pre-reservation mismatch blocks with the ledger unchanged. If the reservation result differs from the preview after append, stop without launching or retrying the consumed identity and retain the ledger record. Existing checks and order are in `plugins/sdd-review-loop/scripts/launch-impl-review.py:143-230,344-374` and `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:709,924,985-997`.

### REQ-003 — persistent CI execution

The focused transport and traceability regressions must be registered in normal test and CI paths, without a fake proxy dependency. Current entries are `tests/run-all.sh:70-76`, `tests/run-all.ps1:135`, and `.github/workflows/test.yml:39-42`; final-head CI remains a separate required observation. Skipped/native-host branches are reported separately, not passed by implication.

### REQ-004 — WFI-030 traceability freeze

The task-stage traceability rule must normalize only a REQ row's final status cell to `Planned`; unknown or annotated status and all other cells remain raw-bound. Existing AGENTS text states the exception at `AGENTS.md:58-62`; focused regressions are registered at `tests/run-all.sh:74-76` and `.github/workflows/test.yml:40-42`.

### REQ-005 — PowerShell review-hash parity

The shared PowerShell helper must preserve the pre-existing impl/task hash recipe, including CRLF, case variants, malformed content and read errors. It computes a digest, not lifecycle authorization: stage-specific state validation and existing outputs remain in callers. This refactor must neither add a new state grammar nor broaden permitted transitions. The helper is `plugins/sdd-review-loop/scripts/review-hash-normalization.ps1:1-15`; `tests/review-hash-normalization.tests.ps1` compares it with the retained pre-refactor recipe. WFI-030 semantic rejection is separately covered by REQ-004.

### REQ-006 — protection and evidence boundary

Exactly the six bounded shared entrypoints must be present in the canonical protection inventory and generated projections, while unrelated paths remain unchanged; write denial and read allowance must both be exercised. The six paths are visible in `plugins/sdd-quality-loop/references/guard-invariants.json:56-62` and `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:130-136`. A protected refusal remains a refusal. No historical verdict, ledger entry, frozen artifact, task status, installation, or product T-002 input may be rewritten for this repair.

## Acceptance criteria

- AC-001 (REQ-001): current CLI help aliases and real stage/role caller argv are accepted; missing flag, wrong model, compound Bash, and outside Read cases stop.
- AC-002 (REQ-002): complete ordered input admission and raw invocation pin succeed; absent, altered, alias, symlink, or out-of-scope input and wrong preview receipt fail before reservation with ledger unchanged. A post-append receipt mismatch prevents launch and retains the consumed record without retry.
- AC-003 (REQ-003): focused suites execute from both run-all entrypoints where applicable and permanent CI; unavailable native/Windows checks are explicit pending observations.
- AC-004 (REQ-004): only the enumerated REQ final-status cell normalizes; unknown/annotated status and evidence/other-cell edits invalidate the bound digest.
- AC-005 (REQ-005): shared and pre-refactor PowerShell recipes produce identical digests or read failures for LF/CRLF, case variants, malformed and empty content; caller-specific state checks and outputs are preserved.
- AC-006 (REQ-006): all six protected paths deny writes and permit authorized reads across generated runtimes; generator drift and unregistered CI fail; unrelated membership does not expand.

## Non-goals and assumptions

No new externally consumed protocol, ledger schema, reviewer topology, immutable-input architecture, installer change, or product T-002 acceptance change. Actual CLI availability and installed-host/native-Windows behavior must be verified in the target environment; local fixtures alone cannot establish them. Re-verify protected membership and CI registration at pre-review and pre-merge consumption because both are shared git-tracked state; do not treat the cited line numbers as permanently current.
