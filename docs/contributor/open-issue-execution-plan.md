# Open issue dependency and execution plan

Dependency snapshot: 2026-10-22; integration update: 2026-10-23. The 34 open Issues were rechecked against GitHub; their
bodies had not changed since the dependency extraction. Baseline: `work` at
`07ed2e984ec58160892e765d7c437c47d5daf332`; default `main` is still `fcb8275`.
Dependencies below describe acceptance/integration prerequisites, not an assertion
that all predecessors need completion before any design work can start.

## Current execution

PR #635 was merged into `work` at `d1719e6632d497d22af20a17704c6d6a27246efd` after native run 39881975684 passed **449 obligations plus one expected skip**, all execution origins from attempt 1. Its fixed source was `86437dda`, base `913573ca`, and tested merge `0708d657`; retained plan digest `5fba4c02efd3ed8c449fa89a636a9e078e37c0fbc92ce6d4a05870b30bda76dc`. The merge preserves #629 and #634 ancestry, and GitHub confirms both PRs merged. Their earlier results below remain historical evidence. #619's four neighboring JSON writers subsequently passed six native comparison jobs at `7b54be1a`; [details and preserved failures](issue-619-neighbor-writers.md#2026-10-23-implementation-and-actual-native-comparison). Their normal integration CI is still required. Neither #619 nor #620 is closed by the aggregate merge alone.

| Issue | Reviewable work | Remaining acceptance |
|---|---|---|
| #619 | [PR #629](https://github.com/aharada54914/sdd-forge/pull/629): explicit BOM-free aggregate writer and runtime regression. Native Windows 5.1 Red, then 5.1/Core Green (17 assertions each). Normal CI run 39809890748 attempt 2 passed: 448 verified obligations plus one expected skip; native evidence is from attempt 1. | Review/integration; [neighboring-writer investigation](issue-619-neighbor-writers.md) localizes remaining risks and original-producer limits. Historical records were preserved. This bounded fix does not claim all encoding work complete. |
| #620 | [PR #634](https://github.com/aharada54914/sdd-forge/pull/634), replacing closed-unmerged #630: deterministic JSON/YAML checker, immutable exceptions, candidate coverage and CI wiring; 13 behavioral tests, 71 guards and catalog checks pass. Includes bounded metadata refresh (89 collector/54 planner tests). Native run 39834531255 attempt 2 passed at source `f9b4b1ca`, fixed base `913573ca`, tested merge `9d5b822f`: **449 verified obligations plus one expected skip**. Exactly 446 origins are from attempt 1; three use a targeted Windows MCP re-execution in attempt 2. [Diagnosis and preserved failures](issue-620-ci-aggregate-diagnosis.md) distinguish the old plan/Git mismatch from a persistent incomplete API job row. PR is ready for review. | Fresh per-run model request provisioning, genuine Claude/self-improvement role adoption with required human review, then a real complete weekly run. An Actions probe confirmed the request is unset; a path variable alone is insufficient. |
| #614 | [PR #631](https://github.com/aharada54914/sdd-forge/pull/631): requirements/design/AC/layer drafts, Proposed ADR and task proposal. Independent content checks corrected concrete benchmark gaps. Normal CI run 39815368531 attempt 1 passed at source `12079211`, including required-checks. | Formal spec/design/task reviews and implementation; no measured baseline exists. Trusted current actor registration and reviewer-role model adoption/fresh input are not established in this environment. Status remains Pending/Draft. |
| #594 | [PR #633](https://github.com/aharada54914/sdd-forge/pull/633): contract/ownership drafts with 95 planned acceptance cases, Proposed ADR-0040 and task proposal. Admitted inputs/output contents bind freshness; trial observations stay non-gating. Normal CI run 39820862322 attempt 1 passed at source `d0a49f73`, tested merge `f9c86a03`: 448 verified obligations plus one expected skip, all execution origins from attempt 1. | Formal reviews and implementation before dependent #595/#596/#602 integrations. Content rechecks are not formal gate results; status remains Pending/Draft. |
| #605 | [Draft branch](https://github.com/aharada54914/sdd-forge/compare/work...feat/issue-605-research): Source/Claim contract, 200 planned acceptance cases (176 local, 24 downstream), Proposed ADR-0041 and task proposal. Targeted draft checks pass. No predecessor completion is required. | Formal reviews and implementation. This is a mixed Claude/Codex draft, not an independent review; no runtime/schema code or whole-repository CI result is claimed. |
| #601 | [Three-class structural prevention map](issue-601-structural-prevention.md): existing guards, actual negative/control fixtures, deduplication candidates and a confirmed focused-test registration gap. | Reviewed scope and implementation; #600 held-out/model trials and retention outcomes are not produced by this investigation. |
| #616 | [Host readiness matrix](issue-616-host-readiness.md): installed CLI versions, existing enforcement and documented prompt-event surfaces checked. No host is marked supported. | A real authenticated human-input issuer isolated from agent authority, then direct-chat/slash enable/status/off and replay/revocation proofs. Existing local hooks and sudo do not repair review-author provenance. |

No Issue is closed by this plan. A passing local check, draft specification or
bounded producer correction is not equivalent to the complete Issue acceptance.
PRs #629, #631, #633 and #634 target `work`; #630 is closed without merging and points to #634. [PR #632](https://github.com/aharada54914/sdd-forge/pull/632) is a separate CI follow-up stacked on #629: re-read unfinished job metadata under one shared 60-second deadline without weakening identity or aggregation. Local collector/planner tests pass (89/54). Native run 39820601216 attempt 1 passed at source `232e940f`, tested merge `e2da7032`: 448 verified obligations plus one expected skip, all execution origins from attempt 1. PR #632 is closed without merging as superseded by #634, which includes the same collector code/tests and now has a successful combined native result. The successful native run does not prove that the refresh branch was exercised; original incident observation bytes remain unavailable.

PRs #629, #634 and #635 are merged into `work`; #631 and #633 remain draft. Merging the entire modernization branch into `main` is a separate integration action. Live checks and the exact tested merge revision are authoritative; a passing draft PR does not satisfy formal feature reviews.

Coding and draft corrections were delegated to actual Claude CLI sessions;
separate content checks and native CI supplied additional evidence. Claude completed the #619/#620 fixes, #614/#594 drafts and CI refresh corrections. During #605 drafting it reported a session limit: `resets 9:10pm (UTC)` on 2026-10-22. Do not retry before **2026-10-22 21:10 UTC / 2026-10-23 06:10 JST**; verify availability after that time before delegating again. Codex completed the interrupted docs-only packet; remaining CI verification is recorded separately. After reset, inspect the current branch before resuming any prior Claude context so that completed fallback work is not duplicated.


## Action order

Start with #619 runtime-specific BOM investigation/fix and #620 audit failure diagnosis as independent defects. #620 is not proven caused by #619. Then prioritize #614 measurement baseline and #594 skill/observation contracts; #605 research contract, #601 structural prevention and #616 trusted-host sudo can start independently.

Full integration layers (conditional pilot dependencies remain scoped):

- 0: #594, #601, #605, #614, #616, #619, #620
- 1: #595, #606, #612, #615
- 2: #596, #600, #602, #607, #608
- 3: #597, #599, #609, #610, #617
- 4: #598, #611, #618
- 5: #603, #622
- 6: #623, #624

## Exact blocking structure

| Issue | Explicit predecessor(s) | Completion/acceptance |
|---|---|---|
| #187 | tracking children: #197 | Close only after A9 #197; A0–A8 checkboxes are complete in snapshot. |
| #197 | #189, #190, #191, #192, #193, #194, #195, #196 | One release cycle with every PR passing advisory Capability gates; promote to required and complete one facet-hybrid feature E2E; record WFI even if none. |
| #593 | tracking children: #594, #595, #596, #597, #598, #599, #600, #601, #602, #603 | Complete #594–603 with CLI and Web/API generation, observed execution, existing gates and maintenance; retain approval/compatibility. |
| #594 | none | Versioned manifest/observation contracts, identities/digests, default-fail unknowns, no authority or required-set changes; legacy compatibility. |
| #595 | #594 | Generate verification skill and actually run one isolated feature from empty data through cleanup; distinguish draft/blocked/untried and preserve hand edits. |
| #596 | #594, #595 | Bind runner observation to Full/Lite contract/plan/bundle; reject fake/stale PASS, block required unexecutable paths, preserve owned cleanup/evidence. |
| #597 | #595, #596 | Validate source and actually execute all feature files; report clean/changed/blocked, maintain skill only and rerun modified harness. |
| #598 | #594, #595, #597 | Extend creation/maintenance to command/docs/tool-delegation skills, require demonstration for validated, preserve user edits and invalidation. |
| #599 | #596 | Use-case routing/playbooks including isolated UX prototypes without weakening Full/Lite approval or shipping unapproved work. |
| #600 | #595 | Blind failure-derived comparison with equal budgets, fixed scoring, n/k and time/token/model versions; reject any approval/safety/required-check regression. |
| #601 | none | Map recurrent mistakes to structural enforcement or justified prose; retain immutable evidence and approval controls; measure recurrence via WFI. |
| #602 | #594, #595 | Single-source host projections; actual discovery/invocation/result checks on Claude/Codex/Copilot; unsupported required function BLOCKED. |
| #603 | #594, #596, #598, #600 | Opt-in formal checks with fixed versions/runtime/path scope; report counterexamples and bounded proof limits, preserve normal tests/review. |
| #604 | tracking children: #605, #606, #607, #608, #609, #610, #611, #612 | Complete R-01–R-08 with quote/hash/security negatives, offline-compatible legacy flows and independently reviewed semantic grounding. |
| #605 | none | Source/Claim versioned contracts and trust/storage boundary; typed graph reference interface, no dual source of truth or approval authority. |
| #606 | #605 | Isolated safe acquisition with SSRF/path/bomb rejection; honest unreachable states, version/hash/provenance, rights-aware cache/storage lifecycle. |
| #607 | #605, #606 | Deterministic quote/hash/version gate with real source; reject fabricated quote/path/stale hash and do not upgrade missing-source statuses. |
| #608 | #605, #606 | Two-path primary-source exploration/citation trail and stopping records; serial fallback allowed; no direct approval/spec status writes. |
| #609 | #605, #607, #608, #612 | Bind verified source/claim identity to REQ/ADR/review; preserve freeze/role isolation and require renewed review for changed input. |
| #610 | #605, #607 | Local HTML short-excerpt/unresolved report with quote verification, escaping/no CDN, rights-aware display, no full-text exposure by default. |
| #611 | #606, #608, #609, #612 | Opt-in external source monitoring and stale impact analysis; inaccessible is distinct from unchanged, never automatically fail frozen design. |
| #612 | #605 | Deterministic file/JSON typed relation graph and impact query joined to existing traceability; many-to-many, cycles and invalid references tested. |
| #613 | tracking children: #614, #615, #616, #617, #618 | Complete #614–618 while preserving gates; measure repetitive verification improvement under fixed conditions; sudo independent. |
| #614 | none | Reproducible monotonic stage timings and baseline equivalence; wall/machine/human active/wait distinct, null missing cost, unchanged gate outcomes. |
| #615 | #614 | Reduce repeated all-spec checks while preserving final global consistency; dependency-bound invalidation and full-scan fallback. |
| #616 | none | Trusted host-issued human chat/slash enable/status/off, strict direct-input parsing, nonce/repo/expiry/revocation, no agent self-issuance. |
| #617 | #614; scoped: #594,#596 (Shared observation contract/runner integration only; existing runner must be reused.) | Reuse runner observation to generate existing contract/report/bundle; reject missing/stale/fake evidence, true Red before implementation, no state engine. |
| #618 | #614, #617 | Measured heavy-check reuse bound to full input/environment closure; independent review input and original evidence retained; invalidate all changes. |
| #619 | none | Correct runtime-specific BOM claim, establish supported PS5.1/7 producer→Python/Node results, version-independent write regression; investigate other writers without rewriting frozen evidence. |
| #620 | none | Diagnose run 39191099402 completion evidence/session report; restore successful valid audit completion and verify failure classification. |
| #621 | tracking children: #622, #623, #624 | Measured minimal factory pilot with human judgment, comparable budget/quality, no duplicate authority/runner/state; adoption may be deferred or reduced. |
| #622 | none; scoped: #599,#617,#618 (Integration uses their reference contracts; contract and display fixtures may proceed first.) | Human decision packet max 3 variants with traceable logs/preview, unknowns and stale detection; actual human choice preserved separately from LLM view. |
| #623 | #614, #622 | Select supported existing executor adapter via ADR, then admission by dependency/ownership/budget/reviewer/human queue; demonstrate cancel/resume and bounded 2/4/8. |
| #624 | #599, #600, #614, #622; scoped: #594,#595,#596,#617,#618 (Only portions used by selected pilot.); #623 (Parallel 2/4/8 evaluation only; single-host pilot may proceed without it.); #197 (sdd-forge Capability operational demonstration only; not every external app.) | One user-specified real app UX issue, fixed matched experiment and human blind interaction/choice, normal approved implementation/gate; human adoption decision and WFI. |

## Boundaries and external acceptance

- #187 closes after #197. #197 needs a real release cycle, human-reviewed promotion, one required/facet-hybrid feature E2E and WFI. Its A1–A8 prerequisites are marked complete in #187, not independently live-verified here.
- #604 parent order explicitly requires #612 before #609 and #611. #612 is not blocked by every research child. #605/#594 coordination, #610/#600 reuse and #618/#609 alignment are references/interfaces, not universal completion waits.
- #622 contract/display fixtures can start before integration; #623 needs measurements plus an existing suitable executor; #624 needs #623 only for parallel evaluation and #197 only for sdd-forge Capability proof. Real app and human adoption choice are external acceptance gates.
- #616 needs trusted human-input events and issuer separation on real hosts; hook registration alone is insufficient. #602 likewise requires actual supported hosts to claim complete support.
- #619 corrected text is authoritative: Windows PowerShell 5.1 UTF8 emits BOM; PowerShell 7 utf8 does not. The baseline writer used Set-Content; PR #629 corrects the aggregate producer and adds native regressions. Historical frozen data remains intact; its original runtime cannot be inferred from the bytes.
- #620 original Actions run 39191099402 records `json_yaml=false` and `status=partial`, with the other four checks successful. It does not identify the original parser command or exact failing paths. The parser correction and present managed-launch prerequisites are separate findings; a new successful weekly run is still required.
- All feature families preserve reviewed contracts/tasks, applicable human approval, Full/Lite/legacy behavior, existing test catalog and immutable evidence. Tests on unavailable OS/hosts remain unverified. Current task authorization must be evaluated separately from old issue-registration-only notes.

Recheck the original Issue bodies before consuming a dependency or acceptance
condition. Do not infer completion from an Issue number, a reference-only link or
this snapshot. Tracking parents close after their children and operational
acceptance; conditional pilot/host requirements remain conditional as shown.

## Next execution rule

Finish and verify each concrete packet before taking its dependents. On a real
external acceptance barrier, record the evidence and continue an independent
root; never create an approval, model observation, identity or host result to
make the graph appear unblocked. Review/implementation status stays in the
existing feature artifacts, not in this planning document. #197 and #624 need
actual operational/human trials and cannot be closed by static code inspection.

