# Requirements: Structural Error Prevention

Spec-Review-Status: Pending

## Overview

Issue: [#601](https://github.com/aharada54914/sdd-forge/issues/601). This preliminary Draft was authored by Codex on 2026-10-23 against `d1719e6632d497d22af20a17704c6d6a27246efd`. An actual Claude author attempt stopped at a usage limit before producing files; it is not authorship or review evidence for these documents. No formal review, task approval, implementation, or verification result is asserted.

Repository contributors need to know which recurring mistakes existing mechanisms prevent, which executable coverage is missing, and which decisions remain human. The historical source map is `docs/contributor/issue-601-structural-prevention.md`; its older baseline is not current implementation evidence. Current-tree corrections are in design.md; its shared-state-reverification section requires rechecking the catalog and consumers at formal review and implementation entry.

## Requirements and Acceptance Criteria

| Requirement | Required outcome | Acceptance criterion |
|---|---|---|
| REQ-001 | Map exactly three recurring-error classes: independently maintained contract representations; runtime defaults changing producer/consumer contracts; incomplete or ambiguous measurements promoted into conclusions. Each links recorded recurrence, enforcement, negative/control fixtures and remaining judgment. | AC-001: Each class has source-backed recurrence and a concrete enforcement or reason to retain human judgment; no invented recurrence or fourth class. |
| REQ-002 | Prefer one authority/architecture, existing schema, lint/CI and tests in that order before adding prose. Reuse the guard generator, shared mirror classifier and verification catalog. Close the existing focused mirror classification suite's execution-registration gap. | AC-002: Existing focused cases execute through an existing local/CI catalog profile, with execution evidence rather than a registration-only assertion; no new classifier or duplicated rule text. |
| REQ-003 | Demonstrate historical bad cases are rejected and legitimate controls preserved by the relevant mechanisms. Distinguish synthetic rejection tests from actual producer/runtime reproduction. | AC-003: Mirror bad-pin/digest versus pending/fresh controls, encoding rejection versus valid producer output, and incomplete versus valid audit completion are exercised or explicitly recorded as unverified for unavailable environments. |
| REQ-004 | Keep symptom, observations, runtime/version, reproduction, hypothesis, counterevidence, confirmed cause or unknown, correction, prevention and retention fixture linked through existing WFI sections/addenda. | AC-004: #619's Desktop 5.1/Core 7 correction and unknown historical producer are explicit; #620 process failure is separate from product findings and completed-zero findings. No causal claim follows merely from passing tests or correlation. |
| REQ-005 | Preserve frozen historical bytes, pending human-copy and approval/admission defenses. Assess duplicate-validator reduction candidates through actual consumers without merging incompatible semantics. | AC-005: Candidate analysis distinguishes strict-current admission from tolerant historical parsing and Full/Lite approval responsibilities; no automatic sync, validator deletion, historical rewrite or gate relaxation. |
| REQ-006 | Use existing catalog/CI and applicable Bash/PowerShell parity/mirror checks. Keep missing required runtime and unexecuted platform results honest. | AC-006: Existing runner executes the selected suites; missing required runtime cannot become success, optional skips stay visible, and Linux/macOS/Windows coverage or limitations are identified. |
| REQ-007 | Hand the three source-backed negative/control cases to #600 using its existing golden-case conventions. Separate deterministic regression completion from future held-out behavior and retention evaluation. | AC-007: Handoff records expected outcomes and grader mutations, #600 ownership and unmeasured results. Existing Horizon/Retention and Meta-Change lanes remain authoritative; PASS counts cannot promote an improvement. |

## Scope, Roles and Compatibility

Contributors maintain the map and tests; existing CI checks execute deterministic suites; independent reviewers and humans retain review/approval decisions. Ordinary formal gates precede implementation. The accompanying tasks-proposal.md is preliminary planning, not a formal tasks.md or authorization to execute it.

No new CLI/API/schema, dependency, WFI state machine, model runner, UI, provider permission or approval policy. No broad runtime writer rewrite: #619 owns encoding fixes. No refactor is required solely because validators look similar. Do not replicate enforceable rules across SKILL.md files. Synchronize contributor documentation and CHANGELOG for actual implementation changes; update other public documentation only if its stated behavior changes.

Pending versus already applied human-copy after a second branch edit can be ambiguous: preserve the artifact and require judgment. Historical BOM bytes do not identify their producer. Missing audit evidence permits an unknown cause and retained real findings. Supported runtime failures are not waived as optional merely to pass this feature.

## Dependencies and Open Evidence

No issue dependency blocks deterministic implementation. #600 owns later held-out evaluation, not #601's completion gate. Future observation windows and actual recurrence counts are not yet available. Native runtime results must come from actual execution; this Draft supplies none. Security boundaries and unchanged approval authority are specified in security-spec.md.
