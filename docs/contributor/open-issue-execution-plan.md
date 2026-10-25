# Open issue dependency and execution plan

## Current status — 2026-10-25 (JST)

This section supersedes older authentication, task-exception, author-limit and
execution-status statements below. The historical dependency graph is unchanged.
A fresh unauthenticated [GitHub query](https://api.github.com/repos/aharada54914/sdd-forge/issues?state=open&per_page=100)
found **33 open Issues, excluding pull requests**. #619 remains closed, and
[#642](https://github.com/aharada54914/sdd-forge/issues/642) is now closed as completed
within its `work`-branch scope. Default `main` remains at `fcb8275a`; these changes
have not been released or integrated into `main`.

- **#619 and host-registration infrastructure are integrated into `work`.**
  [PR #636](https://github.com/aharada54914/sdd-forge/pull/636) and
  [PR #639](https://github.com/aharada54914/sdd-forge/pull/639) each completed
  449-obligation CI plus one expected skip. The supported helper registered the
  target native host; its continuation succeeded after the 10:20 UTC reset and
  registration recheck passed. Earlier session-limit failures remain recorded.
  Host registration does not itself establish reviewer adoption or feature gates.
- **#620 production recovery remains incomplete.** Human-approved
  self-improvement-only Opus/medium adoption and the maintained capture corrections
  are integrated by [PR #641](https://github.com/aharada54914/sdd-forge/pull/641)
  at `5dfd7cc2`, with the exact tested tree and
  [449 PASS plus one expected skip](https://github.com/aharada54914/sdd-forge/actions/runs/40092423174).
  The actual [weekly run 40088779741](https://github.com/aharada54914/sdd-forge/actions/runs/40088779741)
  captured fresh configuration, completed its native audit and reported all five checks successful, but
  remained **partial**: PR creation returned 403 under the configured token and
  finalization was skipped. The user authorized token-permission remediation on 2026-10-25 (JST).
  The current API connection returns HTTP 403 for both repository Secret
  metadata and Actions workflow permissions. TinyFish is now connected for the
  requested browser operation, but its Default profile has no recorded GitHub
  sign-in; the login-state/setup response is pending. PR-write remediation remains
  authorized, preserving Contents write and repository selection. No token value
  was requested, and no permission change or retry is claimed.
  A complete guarded production run is still required for #620.
- **#642's encoding correction is integrated and verified.**
  [PR #643](https://github.com/aharada54914/sdd-forge/pull/643) merged at
  [`a46ad52b`](https://github.com/aharada54914/sdd-forge/commit/a46ad52b4c181691fa16e0d7edc14f071f46f3b6),
  with verified tree `feda49b0`, matching tested merge `f485250c`.
  [CI 40095251343](https://github.com/aharada54914/sdd-forge/actions/runs/40095251343)
  completed **449 PASS plus one expected skip**, including all 36 installer
  obligations. Actual Windows Desktop 5.1 and Windows Core each passed all 98
  encoding checks; Linux Core also passed 98. The three existing PowerShell
  writers preserve BOM-free input, Unicode/newlines, consent and relative-location
  behavior. Earlier parser/fixture failures remain preserved.
- **Distribution scope remains bounded.** #643 changes three existing admitted
  runtime scripts and one excluded test helper. It adds no installed path,
  package or temporary comparison workflow; installer and payload-selector bytes
  are unchanged. Static selection remains 613 paths, including the required
  existing weekly-adoption record. Earlier actual installer parity covered 612
  paths and is retained as historical evidence, distinct from current static
  membership and the current 36 CI installer obligations. Installation still
  copies all admitted plugin directories and may download the full source archive
  before filtering; selected-plugin-only copying is not claimed.
- **Spec-reviewer-A and task A/B adoption are integrated.**
  [PR #649](https://github.com/aharada54914/sdd-forge/pull/649) merged into `work`
  at `fa196c92`, with tree `d23651a0` matching the tested merge.
  [CI 40150536853](https://github.com/aharada54914/sdd-forge/actions/runs/40150536853)
  completed 45 successful jobs and one expected skip, including all six installer
  jobs; final required-checks succeeded. Local policy validation passed 59 tests.
  Artifact/log access was unavailable, so this run is not independently reported
  as a 449-obligation aggregate. The user accepted the
  prepared proposal on 2026-10-25 (JST); the integration adds its actual receipt
  and hash-bound policy reference for explicitly pinned Opus/high, limited to
  ordinary Phase-1/no-domain A reviews. Candidate lifecycle remains unchanged.
  It preserves clean native PASS/PASS, dirty native UNCLEAR/UNCLEAR and separate
  source adjudication of D5. Spec-reviewer-B remains unadopted. Its completed
  clarified-fixture Sonnet/medium experiment has **zero PASS, two FAIL and two
  ADJUDICATION_PENDING outcomes**: clean citation defects, missed dirty D4 and unresolved
  source-grounded concerns remain recorded. A separately versioned Opus/high
  qualification completed four native calls with no retries: independent semantic
  judgment accepted three outputs and rejected one for unsupported mandatory
  design demands. Both dirty repetitions detected all five seeded defects; that
  recall does not erase the false positive. **B adoption remains on hold** under
  the existing all-criteria/two-repetition promotion rule. Its control was clarified
  before these calls, so it is not a paired comparison against the earlier Sonnet
  inputs. The same Work judge knew the profile/history; only output/repetition
  mapping was hidden. These small adaptive experiments do not establish
  domain/amendment coverage or normal settings/hooks equivalence.
- **Task-reviewer-A/B adoption is human-approved.** The user accepted the
  prepared proposal on 2026-10-25 (JST); the integration records explicitly pinned
  Sonnet/medium only for supervised post-implementation provenance re-review.
  Candidate lifecycle and caller effort/risk constraints remain unchanged. Eight native
  Sonnet/medium outputs passed their contracts; independent semantic judgment
  accepted all eight outputs and supported 92 checks. Candidate decisions remain
  **four clean PASS and four seeded-defect BLOCKED**. Scope is one compact synthetic
  two-task workload with two repetitions per role/control pair. The approved integration adds the two role references and real approval
  receipt; it does not establish formal task-review PASS, first-time Draft review
  coverage, backend identity or protected-role admission.
- **Interrupted-review recovery remains In Progress.**
  [PR #640](https://github.com/aharada54914/sdd-forge/pull/640) at `563006cc` completed
  [449 PASS plus one expected skip](https://github.com/aharada54914/sdd-forge/actions/runs/40090187421),
  including native platform suites. That CI used the older `1c95ede8` base and
  does not validate integration with current `work`. A separate local integration preserves the original #614 draft branch and
  its registered native host. One actual Claude continuation applied the approved
  v2 criterion without changing task statuses, then the real task precheck stopped:
  the old implementation-policy review pins a reviewer-calibration hash changed
  by `bc7be7f7`, before this adoption integration. All seven frozen specification
  hashes still match. Repair requires implementation-policy provenance re-review
  before task rebinding; the old contract was not rewritten. No child reviewer
  launched, and T-001 is not Done. T-002 recovery and T-003 compatibility
  remain ordered dependents. Implementation approval excludes live historical
  recovery and A9 activation; actual recovery requires its original human
  approval/application provenance.
- **Implementation-policy reviewer A has bounded qualifying evidence; B remains
  withheld.** Eight fixed Sonnet/medium calls completed with no retries; all eight
  output/execution contracts passed. A fresh separate-context source judgment
  accepted seven outputs: A passed four of four outputs and all 44 checks; B passed
  three of four and 43 of 44 checks. The B failure is an unsupported no-test-coverage
  assertion against planned TEST-003; its additional Major scope finding is valid
  and retained. The original joint HOLD report is preserved; the frozen promotion
  rule permits a separate passing-role-only human decision. An A-only proposal is
  prepared for human approval; no role is activated by these results. Evidence covers a small
  nonlegacy CLI/full-profile workload without domain/design-system contracts in a
  later-lifecycle context. A9 is labelled `bugfix` and uses local Bash/PowerShell
  tooling without a frontend; any proposed application mapping must be explicit
  in the human adoption decision. Amendment binding, convergence, protected entry,
  actual A9 execution and first-time review remain separately unproved.
- **Evaluator adoption is also on hold.** A separately versioned first-role
  Opus/high qualification completed four native calls and a fresh Work judgment
  with candidate identity withheld: **one ACCEPT, one NEEDS_WORK and two UNCLEAR**.
  Both defect outputs identified the Critical missing validation call and omitted
  build, but two outputs misquoted checker-hash suffixes while claiming a match.
  The actual artifact hashes match; the false statements are in the responses.
  The clean-case catalog-to-commit ownership concern remains unresolved and is
  not classified as a false positive. These results do not satisfy the frozen
  all-criteria/two-repetition adoption rule. The previous one-call experiment and
  its three unrun cells remain preserved, alongside independently confirmed
  parser overconstraints and two real test-coverage gaps corrected before the
  four-call qualification. There is no evaluator adoption or T-001 quality PASS.
- **Other feature work remains open.** #614/#594/#605/#601 retain draft work in
  [#631](https://github.com/aharada54914/sdd-forge/pull/631),
  [#633](https://github.com/aharada54914/sdd-forge/pull/633),
  [#637](https://github.com/aharada54914/sdd-forge/pull/637) and
  [#638](https://github.com/aharada54914/sdd-forge/pull/638), respectively. Formal
  reviews, applicable approvals and implementation remain. #616 still requires
  authenticated human-origin host proof. #197 retains its eleven-component
  unactivated candidate and needs the actual advisory cycle, human promotion
  decision, post-promotion E2E and WFI disposition; #187 depends on that acceptance.

Keep the historical graph below for provenance, skip completed #619/#642 work,
and check current acceptance before closing any remaining Issue. Completed CI,
Issue closure, human adoption and formal feature gates retain their separate scopes.

## Historical snapshot — 2026-10-22

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
