# Concept reverse and C4 ownership: Phase 4

Issue #290 Phase 4 is implemented on top of the Concept Authoring changes.
The domain lane now has seven stages: Domain Story, Event Storming, Concept
Model, Ubiquitous Language, Context Map, Aggregates and Message Flow.

## Changes

Reverse seeds add `candidate_concepts` and `concept_smells` to the existing
five buckets. Every proposal retains its INV-NNN evidence join to original
file:line findings. Multi-role models and responsibility conflicts require
observed responsibilities/lifecycles or both sides of an ownership conflict.
Names alone do not establish identity or a defect. Same/different/undecided
remains a human decision; no automatic split, merge, code edit or canonical
concept adoption is introduced. Future-only cases remain low-confidence
questions. The interviewer explicitly consumes both new buckets at Concept Model.

C4 is deprecated as a domain checkpoint and its active template/authoring
responsibility belongs to bootstrap architecture. The duplicate domain template
is removed. Bootstrap chooses relevant C4 levels for actual architecture
requirements in feature design/infra artifacts and records logical-to-deployment
mapping without assuming one concept/context equals one container. Existing
user C4 files are not deleted or automatically migrated.

Domain create/resume/update, template stage labels and both review prechecks use
the seven-stage set. Neither a missing historical C4 file nor its unrelated
content changes block domain precheck or alter the bound canonical domain digest.
Review-role C4 removal and concept criteria are delivered by the separate
Phase 3 changes; integrate Phase 2, Phase 4, then Phase 3.

## Verification

- Focused Pester suites: artifact-set, template-language, update-mode,
  domain-review-loop and reverse-seed: **211 passed, 0 failed, 0 skipped**.
- Real Bash precheck before/after: the Phase 2 precheck rejected the same
  C4-less fixture; the current precheck accepted it. The fixture still has the
  required Concept Model and all other domain artifacts.
- Both Bash and PowerShell prechecks reject missing Concept Model and bind its
  changed content; both accept absent C4 and ignore added historical C4 in the
  input digest.
- Repository validation passed; mirror check reported no stale applied mirrors;
  `git diff --check` passed.
- Independent behavior review confirmed the purchase/dispatch fixture supports
  candidate multi-role and ownership-conflict questions, while same-name-only
  and hypothetical-future-only controls do not justify automatic new concepts.
  This is a review of the product contract and fixture, not a measured native
  model session. Existing tests correctly identify hand-worked seed examples.

A broader domain run also exposed pre-existing historical-diff and Windows-only
runner assumptions. Those are being repaired in the combined #290 work, not
hidden by changing this phase's acceptance checks. The historical absence
comparison already reports removed lines on main before these changes. Final
combined CI and post-merge verification remain required for issue closure.
