# A8 native `apply_patch` safety candidate — static only

Status: **static patch candidate, not applied or runtime-verified**. The sibling `a8-copilot-patch-safety-candidate-20261002.patch` passed `git apply --check` in the A8 owner checkout on 2026-10-02. This only proves that the patch format and source context match; it is not a guard test, a native PASS or approval to enable the inert adapter. The actual Copilot hook stdin remains unobserved. The live host event showed raw patch-string tool arguments and a native `malformed hook payload` denial; that event is not a capture of hook stdin (`a8-post-update-live-20261002.md`, session `e31b07fe-3c47-4814-8407-561b026093a1`).

## Minimal repair boundary

Only the Python and JavaScript guard patch paths that the inert adapter would reach are in scope. Preserve the native adapter's strict `apply_patch` string envelope check and every existing read/write, sudo, approval and protected-file decision. Do not infer a `toolCalls[]` stdin contract from host events; no batch or generic write allow is proposed. The PowerShell guard is not included in that adapter and must remain fail-closed for unrecognized native `apply_patch` input. Before any cross-platform claim, separately implement/verify equivalent PowerShell behavior or explicitly scope the enabled adapter to the Python/JS runtime.

1. **Move destinations.** The revised bounded patch candidate evaluates both operands: existing source-header checks remain, while each `*** Move to:` destination is routed through existing SDD_SUDO, protected-gate, agent-role, tasks, WFI, domain-map and design-path predicates. Moves into those sensitive paths are denied because unchanged content is not visible in patch deltas. Ordinary moves between non-sensitive paths remain allowed. Malformed move-like directives that the patch tool might accept under another spelling require a separate parser-compatibility test before activation.

2. **Per-section, not cross-file, approval deltas.** For ordinary non-move sections, the candidate finalizes the previous section at each file header and resets `added/removed`; its end-of-patch check handles the last section. Therefore a removal in one file cannot cancel an addition in another. A same-file removal/addition within one section retains existing net semantics. Two separate sections targeting the same file may be conservatively denied even if they cancel overall; this is a documented false-denial risk, not a false allow. The `tasks.md` Approval and Second Approval counters remain separate; likewise WFI and domain markers.

3. **Impl-Review-Status patch route.** The candidate extends `impl_review_status_passed_increases` / `implReviewStatusPassedIncreases` to inspect patch section additions. For a `specs/<feature>/design.md` target, an added `Impl-Review-Status: Passed` requires `_impl_review_verdict_exists` / `implReviewVerdictExists` for that same feature; another feature's verdict is insufficient. Every move is already denied. The existing edit/write/multiedit branch is unchanged; sudo does not waive this check. A patch re-adding the marker to a file that already has it may be conservatively denied without verdict, pending runtime tests.

## Required regression matrix before adoption

Use synthetic fixtures in the existing guard test harness; no alternate executor may be used to push a previously rejected protected write through. Each case must be asserted against both Python and JS guard decisions, and must include one allowed non-protected control:

| Case | Expected |
|---|---|
| `Update File: src/a` then `Move to: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | deny R10 |
| `Update File: src/a` then `Move to: SDD_SUDO` target | deny SDD_SUDO |
| Move to an agent-role path | deny according to existing role protection |
| Move into `specs/x/tasks.md`, WFI path or domain/context-map.md with unchanged approval context | deny until full resulting-state proof exists |
| Remove `Approval: Approved` from `specs/a/tasks.md`, add it to `specs/b/tasks.md` in one patch | deny |
| Analogous cross-file Second Approval and WFI Approval transfers | deny |
| Same-file removal with no new approval | retain current allow semantics |
| Add `Impl-Review-Status: Passed` to `specs/x/design.md`, no x verdict | deny |
| Same addition with unrelated y verdict | deny |
| Same addition with valid x PASS verdict | allow only if all other checks pass |
| Move into `specs/x/design.md` without x verdict | deny |
| Malformed or out-of-section `Move to` | deny malformed patch |
| Native Copilot patch-string call vs legacy patch call with identical safe/unsafe patches | same decisions, one decision object per call |

Regression input candidate (construct each as a complete `*** Begin Patch` / `*** End Patch` string, then run through the existing guard harness for both Python and JS without modifying the protected source):

```text
# cross-file tasks transfer: deny
*** Begin Patch
*** Update File: specs/a/tasks.md
@@
-Approval: Approved
+Approval: Pending
*** Update File: specs/b/tasks.md
@@
-Approval: Pending
+Approval: Approved
*** End Patch

# design status addition without same-feature verdict: deny
*** Begin Patch
*** Update File: specs/a/design.md
@@
-Impl-Review-Status: Pending
+Impl-Review-Status: Passed
*** End Patch

# otherwise harmless source, protected destination: deny before path checks
*** Begin Patch
*** Update File: scratch/ordinary.md
*** Move to: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
@@
-old
+new
*** End Patch
```

An executable candidate to extend the existing shell harness is `a8-copilot-patch-safety-regression-20261002.patch`; it passed `git apply --check` but has not been applied or run. It covers ordinary and sensitive moves, cross-file transfers for all four markers, a design status without verdict, and a same-feature PASS verdict. The primary-agent continuation added five cases: empty move destination, same-file approval removal, unchanged same-file approval count, unrelated-feature verdict rejection, and a move into SDD_SUDO. The added shell fragment passed `bash -n`; both source and regression patches passed `git apply --check` again. These are syntax/applicability checks, not runtime results. Out-of-section and alternate-spelling move cases remain unverified. Native Copilot envelope parity still requires actual hook stdin capture; host events alone do not establish that envelope.

After candidate code and fixture tests pass, perform a new *native* Copilot run with actual hook stdin/decision evidence, exact output-byte checks including newline behavior and both nonce contributions. A CLI exit code alone is insufficient. Then complete formal review and ordinary release checks; this note is neither a guard deployment nor AC-003/AC-004 verification.
