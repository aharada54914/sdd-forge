# Design: Structural Error Prevention

Impl-Review-Status: Pending
Feature Type: contributor verification integration

## Architecture

Reuse existing authorities and runners. The only confirmed execution gap selected for implementation is the excluded focused classifier suite. Keep one contributor map; append a dated current-state/correction and evidence handoff there rather than copying a new rulebook into skills. No production authority, public contract or data schema changes; no ADR is required for this integration. Any later change to those boundaries requires a separately reviewed design update.

## Source Map

Historical recurrence references below are the source map's explicitly recorded baseline `8818e33`; they establish recorded incidents, not present defect prevalence. Current mechanism references were checked against `d1719e66` on 2026-10-23. Do not rewrite the historical preparation to imply it observed later changes.

| Class | Historical evidence | Current enforcement and bounded delta | Human judgment retained |
|---|---|---|---|
| C1: independently maintained contract representations | WFI-039 successive mirror failures and prior occurrence; WFI-043 repeated second-edit ambiguity, as cited in the contributor map. | Generator `--check` is already wired at `.github/workflows/test.yml:365`; sync imports shared classification at `scripts/sync-human-copy-mirrors.py:34`; freshness twins invoke it at `tests/human-copy-mirror-freshness.tests.sh:54` and `.ps1:45`. Register the existing focused suite currently excluded at `tests/verification-catalog.json:1083`. | Whether divergent human-copy is pending/applied, new membership, and authorized successors; no automatic overwrite for ambiguous second edits. |
| C2: runtime defaults change contracts | WFI-044's multiple approval/precheck case mismatches; #619's corrected version-specific encoding explanation. | Aggregate writer is already explicit BOM-free UTF-8 at `plugins/sdd-quality-loop/scripts/check-cross-model.ps1:75-80`; `tests/cross-model.tests.ps1:518` actually invokes the encoding helper, including Desktop when available. Reuse this #619 work and record runtime evidence; no competing writer fix. | Supported runtime policy, intentional case semantics, and attribution of historical files to an unknown producer. |
| C3: incomplete measurement becomes conclusion | WFI-055 repeated local/CI omissions; WFI-051 misleading stale-hash attribution; #620 incomplete audit process. | Catalog tests cover registration, execution and runtime failures (`tests/verification-catalog.tests.py:42-110`); completion mutations exist at `tests/self-improvement-guard.tests.sh:250-290`. The workflow explicitly calls completion a session assertion, not independent execution proof (`.github/workflows/self-improvement.yml:273`). Reuse those gates and add paired interpretation cases to the contributor handoff, not a new audit state machine. | Cause confirmation, actual audit coverage, significance of findings, and improvement attribution require evidence review. |

## Registration and Regression Integration

`git grep` over `.github`, `scripts`, `tests` and `plugins` finds the focused classifier suite only in its excluded catalog entry. Freshness wrappers invoke classification, not the focused test suite. Replace exclusion with direct registration in existing compatible local and CI profiles; use the catalog's current schema and Python runtime declaration. Do not add a new runner or duplicate platform-specific classifier tests. Prove actual invocation through the existing runner receipt/output and an isolated failing-fixture mutation; metadata validity alone is insufficient.

Reuse `check_pins_never_waive`, `check_ship_successors`, `check_manifest_digest_independent` and the pending/missing controls in `tests/human-copy-mirrors-classification.tests.py:130-276`. Run existing generator, mirror freshness and catalog checks. Add a synthetic second-edit case to this existing suite only if its ambiguity is not covered: expected behavior is safe classification/diagnostic with no artifact modification, not inference of an authorization to sync. Test fixtures use temporary roots, never real historical records.

For C2, reuse actual producer tests, strict Python/Node consumers and runtime metadata. A deliberately BOM-prefixed payload must be rejected; it is a consumer negative, not evidence of producer origin. Old Core success is a valid control, not a Red. Actual Desktop old/new comparisons belong to #619 evidence; if unavailable, record unverified and retain the existing Windows execution route. Existing case-sensitivity regressions remain in place; do not invent a blanket operator lint rule.

For C3, reuse incomplete/malformed/stale/unrun completion negatives and valid-current completion controls. Add no validator purporting to infer product findings from process status. The deterministic gate validates its existing assertion contract only. The interpretation cases below require review now and eventual behavior evaluation in #600; they do not upgrade that assertion to execution proof.

## Evidence and Handoff

Append to `docs/contributor/issue-601-structural-prevention.md` using its existing class structure: symptom and source; runtime/version and reproduction; observations; hypothesis and counterevidence; confirmed cause or explicit unknown; correction/prevention; fixture and observed outcome; unresolved judgment; retention outcome. These are linked prose fields, not a new machine-readable schema. Preserve original historical text; correction addenda supersede explanations without rewriting evidence.

For #619, cite official PowerShell encoding documentation (`https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_character_encoding`) with the relevant version and actual runtime logs when available: Windows PowerShell 5.1 UTF8 writes a BOM, PowerShell 7 utf8 does not. Historical BOM artifacts alone leave the producer/cause unknown. No native execution is claimed by this Draft.

Deliver exactly C1/C2/C3 as source-backed candidates within #600's existing five-case portfolio, following `tests/golden/README.md` conventions. Each handoff has origin references, bad input, legitimate control, expected artifact/tool-trace outcome, and a grader mutation that would falsely accept the bad case or reject the control. C3 includes: incomplete audit with a real finding (retain both failure and finding, cause unknown); completed audit with genuine execution evidence and zero findings (valid); asserted completion without execution artifacts (not execution proof even if assertion validation accepts it). C1 includes pending and second-edit ambiguity; C2 includes Core passing control and actual/unverified Desktop distinction. No model calls or new golden runner belong to #601.

#600 owns concealed rubrics, tuning/held-out split, repetitions, model/configuration/budget and behavior results. #601 can finish deterministic registration and regression work with this documented handoff while #600 integration remains pending. Use existing why-why, Horizon and Retention sections (`plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md:203-229,414`); future observation evidence and counts are initially **Not evaluated**. Select/record the observation horizon through that existing process when applied; report recurrence and underlying evidence, not causal success from fixture PASS totals. Changes to graders, measurement thresholds or approval rules use the existing Meta-Change lane (`:392,407`); this feature does not grant promotion authority.

## Duplicate Validator Assessment

Retain the contributor map's two bounded candidates and verify consumers before proposing extraction: implementation-report parsing in the authoring validator, review-context admission twins and panel preparation; annotated approval grammar in Full and Lite checkers. Document what can share syntax/parsed representation and what cannot share policy. Strict current input/path/hash checks must not inherit tolerant historical parsing; Full two-person approval and Lite lifecycle responsibilities remain separate. Candidate assessment is the deliverable, not obligatory extraction. No validator deletion or weaker acceptance is authorized by this design.

## Layers and Compatibility

UX: contributor evidence reading, ux-spec.md#scope-and-user-journeys. Frontend: no UI change, frontend-spec.md#technology-stack. Infrastructure: existing catalog/CI, infra-spec.md#deployment-topology. Security: unchanged artifact/approval boundaries, security-spec.md#trust-boundaries. No user-facing product journey, data migration or package dependency. Claude/Codex/Copilot product instructions remain unchanged. Applicable native suites keep their existing platform routes and exit semantics; environment omissions remain explicit.
