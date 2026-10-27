# Open issue dependency and execution plan

## Active continuation — 2026-10-27 UTC

The owner has now operated the remotely deployed MCP comparison and **rejected
both displays**: the supplied mobile screenshot showed 0/4 and described raw data
as unfriendly. Individual answers/times were not supplied. An evidence-backed
iteration 2 was implemented and deployed to the same owner-private Site, showing
plain-language state, reason and next action, optional raw evidence and copyable
feedback. Logic checks pass; direct browser QA awaits the required response, and
iteration-2 human evaluation/adoption remains pending. The original result is
preserved. [Feedback and deployment](../../reports/verification/mcp-real-app-v2-20261027/README.md).

Dependency PR #655 now has genuinely successful final-source hosted CI
40426135022 (41 successful jobs, one expected skip) at `4f602f7a`, and is
MERGEABLE with REVIEW_REQUIRED. No merge bypass or self-approval was performed.
Two separate actual configured-PAT probes returned HTTP 403 for PR writes and
contents-ref writes; the successful weekly run did not repair this secret.
The owner GitHub confirmation remains pending; no secret values were inspected.


The fresh two-case cohort completed 12 native trials: 6/6 per side, including
all repetitions of each real-incident control, without prompt/rubric changes.
The source was frozen at `b45eb529` before collection. Earlier failed and
public-contract epochs are retained separately; no automatic adoption or
framework superiority is inferred. [Fresh held-out evidence](../../reports/verification/golden-heldout-20261027/README.md).

Actual weekly run 40426096944 at `4ac41d51` subsequently passed both audit and
final recovery jobs. The workflow verified completion and closed **#620** at
2026-10-27T00:30:26Z; the run/Issue snapshot is in the native Actions packet.
This supersedes the earlier failed-audit checkpoint below. The production main
integration and separate configured PAT are not inferred changed by that run.

The revised public-contract epoch completed another 30 native trials, with
15/15 exact grades on each side. It remains diagnostic because those original
cases were exposed, and does not override the frozen failed first epoch.
[Revised-epoch evidence](../../reports/verification/golden-contract-20261027/README.md).
Two additional real-incident-derived controls were frozen as the separate
fresh held-out cohort reported above; no prompts were tuned from their outcomes.

The dedicated Actions run actually created Draft PR #655 with the ordinary
workflow token, and cancellation/restart observations passed the existing
source-origin reconciler replay. An actual cancelled-attempt artifact had
child exit zero, and is correctly rejected both before and after the genuine
successful retry. This is positive bounded executor evidence, not a complete
factory lease/admission implementation or proof of child termination.
[Native Actions evidence](../../reports/verification/actions-executor-20261027/README.md).
The reused dependency branch's lockfile-only source exposed missing bundle
rebuilds; all three bundles were regenerated, audited clean and passed 498
tests plus type checks. Final-source CI subsequently passed on PR #655 as recorded above.

Concrete release packaging was also performed at `4ac41d51`: source archive,
101-component SBOM, checksums and 34+76 passing release loop prerequisites.
No tag, release, signing or promotion was fabricated.
[Packaging receipt](../../reports/verification/release-preparation-20261027/README.md).
The pinned Action documentation drift found by the real audit (#654) is fixed
with upstream source citations; executable permissions/token selection remain
unchanged and 71 guard plus 10 credential-preflight tests pass.

The owner explicitly instructed continued repair and selected sdd-forge MCP for
real-app evaluation. Earlier deferred-app and authentication-blocked descriptions
below are historical checkpoints, superseded by these observations:

- Official device authentication succeeded. Both local CLI account probes now
  verify, and an actual native model turn completed. The existing protected
  runtime credential was not overwritten, copied or inspected.
- #602's generated custom skill was actually invoked by authenticated Codex,
  read its real fixture note, preserved fixture bytes and disappeared from
  native discovery after cleanup. [Native evidence](../../reports/verification/native-skill-20261027/README.md).
- #600's first actual 30-trial reduced-stage comparison completed: 6/15 exact
  grades per side, with no all-success or adoption claim. Missing public output
  grammars caused exact-wording failures despite several correct judgments.
  The failed v1 result is retained; separate revised cases expose the grammar,
  not the private expected verdict. Original held-out cases are now exposed.
  [Protocol and raw evidence](../../reports/verification/golden-native-20261027/README.md).
- #624's actual selected MCP app completed 36 native requests with exact
  baseline/candidate response parity and unchanged tracked source. A local
  interactive snapshot comparison is prepared for the owner; human operation,
  choice and subsequent chosen-feature acceptance are still pending.
  [Real-app pilot](../../reports/verification/mcp-real-app-20261027/README.md).
- #620: authenticated owner browser inspection found repository Actions PR
  creation/approval disabled. It was enabled and saved while retaining default
  read-only permissions. A genuine weekly audit at `4271e1c5`, run
  [40422211534](https://github.com/aharada54914/sdd-forge/actions/runs/40422211534),
  passed all five required checks but correctly remained FAILED because its
  completion record was `partial`. The original failure is preserved; the
  subsequent real recovery is recorded above. Existing session-token details require
  owner GitHub confirmation; a setup handoff is pending. Token values were not
  read or changed. The separate bounded native default-token PR-write/lifecycle
  proof completed on the isolated verification branch.
- The actual native `userVerification/status` API exists in Codex 0.159.2 but
  returns `providerUnavailable` on this build/account. No enrollment, token
  issuance or agent-created human proof was attempted. #616 still needs an
  available protected host issuer; local account repair does not provide it.
- #197's existing Phase-1 candidate validator passes with
  `promotion_authorized: false`, `signed_approval: not_issued`, and release
  evidence not collected. There are no published repository releases. Genuine
  signed activation, a full advisory release cycle and later authorized
  promotion/real-feature completion cannot be replaced by a simulated cycle.

The tested integration source `4271e1c5` passed hosted run 40350525560 attempt 2
(45 successful jobs, one expected skip); the historical attempt-1 cancellation
and failed aggregate remain intact. New fixture/report changes need their own
verification. No merge, promotion or release publication is implied; the only
recorded Issue closure is #620's actual workflow-driven recovery above.

## Development-session correction — 2026-10-25 (JST)

The user explicitly clarified that this is development **of** sdd-forge, not a
session governed by the plugin's own workflow. Product AGENTS/skill text,
reviewer-model adoption, and internal Draft/Approved/Passed state are development
artifacts, not prerequisites for implementing these Issues in this session.
The earlier decision to stop implementation on those prerequisites was mistaken.
Independent review and behavior-evaluation delegation is now explicitly allowed.
Implementation proceeds directly against the Issue requirements and acceptance
criteria, with independent code review and actual tests. Product-side authorization,
trust boundaries, legacy compatibility and truthful evidence remain requirements;
historical review/approval records are not fabricated or retroactively rewritten.

The consolidation-only head `c5a02f06` passed hosted CI run `40164678505`.
Subsequent implementation changes need their own checks. Real app evaluation for
#624 remains pending by the user's explicit selection; its fixture work proceeds.

## Research workflow integration checkpoint — 2026-10-25

Research-only and relocated manifests now reach the real workflow and downstream
precheck validators. Each reviewer must pin the full research input closure;
research ADRs remain separate from strict design ADR declarations. Local Bash /
PowerShell integration passed 18 tests, resolver tests 18, owner tests 7 and loop
consistency 34. [Evidence](../../reports/verification/research-workflow-gates-20261025/README.md).
Independent review then reproduced and verified fixes for NEEDS_WORK reopening
after packet repair and the normal requirements Pending-to-Passed transition.
The lifecycle suite now passes 20 integration tests, with 14 independent historical
negative/positive cases. [Follow-up evidence](../../reports/verification/research-lifecycle-20261025/README.md).
Historical failed pins grant no current approval. Final hosted CI and remaining
Issue acceptance are tracked separately; #624 real-app evaluation remains pending
by the user's instruction.

## Optional PDF follow-up — 2026-10-25

#606/#607 now share actual isolated PDF layout extraction and original-byte
re-verification on supported Linux/pypdf runtimes. The existing process supervisor
owns nested fetch/parser descendants and bounded output. Acquisition/PDF tests
pass 27 cases and existing project lifecycle tests pass 35; independent timeout
probes confirm complete ordinary descendant reaping. [Evidence](../../reports/verification/research-pdf-20261025/README.md).
Shared-storage access and subtitle/video-time support remain implementation gaps;
unsupported PDF platforms are not reported as passing. #615/#618 reuse and the
external acceptance items below remain open work.

## Acceptance audit and research follow-up — 2026-10-25

The latest independent audit separates real development gaps from unnecessary
production/model/live-evaluation prerequisites. #608/#609 now have the internal
research skill, canonical claim planning and interviewer adoption boundary;
#611 adds opt-in watch v2 with actual check time and metadata/cache drift even
without new feed items. Independent review verified preserved-history planning
and rejection of cross-feature watch-state replay. The discovery/watch suite
passed 19 tests; repository and installed Bash/PowerShell checks passed.
[Evidence](../../reports/verification/research-followup-20261025/README.md).

The 36-suite shared Python profile completed with all exit codes zero, but its
receipt is explicitly non-reusable because development commits changed during
the run. Hosted final-source CI remains separate. #615 stage-two same-session
full-result reuse and #618 heavy-result reuse are **implementation gaps**, not
approval waits. Licensed shared storage/access and subtitle support remain
research implementation gaps; supported Linux PDF work is recorded above; optional live networking is not substituted for
fixture acceptance. Historical status sections below are superseded, not gates
for this development session.

## CI and prospective evidence follow-up — 2026-10-25

`d6200026` fixed native temporary-directory aliases and explicit historical/live
successor comparisons. Hosted run `40192305692` subsequently exposed two further
fixture integration gaps: four mirrors lacked exact successor registration, and
the clean registry fixture lacked the newly registered source-evidence gate.
Both are corrected without modifying frozen staged files. Mirror classification
passed 135 regression checks, and the registry suite passed 28 checks in Bash
and Linux PowerShell. Hosted rerun is still required for the new head.

The #617 collector now captures prospective Red and Green in the same live
process, keeps sealed tests/command/environment fixed, permits only explicit
implementation input changes, and binds both originals in the existing evidence
artifact. Its 21 tests include the real CLI handoff and synthetic critical
prepare/dirty rejection/clean commit/signature verification. Independent review
reproduced and verified fixes for admission replacement, key inheritance,
runtime substitution, and output-grant widening. High/critical capture prepares
artifacts only; independent review and existing signing remain separate.
See [collection procedure](project-evidence-collection.md). No production review,
signing authority, lost historical Red, or actual app evaluation is fabricated.

The scripted #617 comparison retained six matched pairs (12 real executions) at
`aecd3136`: success and exit-3 paths preserve identical report bytes and contract
semantics, with matching original validator verdicts. Caller-side scripted
transfers (20) and explicit artifact writes (3) move behind the collector API;
internal copying/writes still happen. Both paths needed zero corrections. This
is not measured human productivity, error-rate reduction, or causal speedup.
[Protocol and all raw artifacts](../../reports/verification/collector-comparison-20261025/README.md).

An actual public-source search/acquisition exercise retained real GitHub results
and empty alternative-route results. Acquisition returned `proxy-adapter-required`
in the enforced proxy environment; later original/citation/display/graph stages
were not executed. This is an unsupported adapter, not an approval condition.
[Bounded report](../../reports/verification/research-workflow-20261025/README.md).
That live exercise is distinct from #610's local-fixture display acceptance.
An independent Chromium evaluation passed 15 real interaction checks and six
invalid-input preservation checks with exact offline fixture bytes, including
source navigation, keyboard/click expansion, distinct translation labels, and
inert injected script/image strings. Direct `file://` navigation was blocked by
managed browser policy; no policy was changed.
[Browser receipt and screenshot](../../reports/verification/research-display-20261025/README.md).

## Implementation checkpoint — 2026-10-25

Follow-up `d36f7849` closes the independent execution-observation/manifest races
and history ancestor deletion findings. The accepted guard run passed 372 legacy
checks plus 63 new cases in Python, Node and Linux PowerShell; independent replay
confirmed the reported bypasses reject while read-only controls remain allowed.
The registered shared Python profile ran 36 suites: 31 passed initially; all five
failure groups were resolved through the explicit protection-inventory update and
reruns with installed `rtk`/PowerShell correctly exposed. Original failed receipt
and separate successful reruns are retained in
[`reports/verification/open-issues-20261025`](../../reports/verification/open-issues-20261025).
These mixed-development runs are not reusable final-head receipts. Hosted final
CI remains separate. The research gate is registered in the canonical capability
registry and its vendored/generated projections. Existing A9 synthetic tests now
bind the current registry in memory; historical evidence was not edited.


The implementation checkpoint is `fefbcb7a`, on draft PR
[#652](https://github.com/aharada54914/sdd-forge/pull/652). This is code and fixture
progress, not a claim that all 33 Issues meet every acceptance condition.

| Issues | Implemented and exercised | Remaining acceptance |
|---|---|---|
| #594 | Closed skill/observation contracts, passive validators and projection | Final integration CI |
| #595–#598 | Internal create/maintain skills; seal/run/maintain; isolated inputs and observed process cleanup; drift and invalidation fixtures | Linux execution backend only; unsupported platforms return not-run; unexercised document procedures remain draft |
| #599 | Five bounded playbooks attached to existing bootstrap/ship entry points; routing/authority fixtures | Final integration CI; native discovery requirements belong to #602 |
| #600 | Five real-failure-derived golden cases, blinded prepare/grade/compare and provenance checks | Native comparison cannot run: supported auth check reports reauthentication_required; no adoption result invented |
| #601 | Source-backed regression cases and structural classification checks | Final integration CI; no claim that prose alone prevents every recurrence |
| #602 | Canonical host wrappers; actual Codex 0.159.2 skills/list discovery and removal verified in the isolated profile | Actual model invocation is auth-blocked; Claude/Copilot unavailable |
| #603 | Real TLC counterexample plus real Bash reservation-tail concurrency mutation/recovery | Bounded two-contender proof only; not whole-app verification |
| #605 | Closed research evidence contract and packaged identical schema | Final integration CI |
| #606 | Bounded HTML/text, isolated PDF and direct WebVTT/SRT acquisition; licensed Linux group store; source/rights/hash and deadline controls | Final CI; remote shared stores and proxy adapters unsupported |
| #607 | Fresh original-byte/extractor/citation verification; actual distinct Linux reader permission/expiry/deletion CI step passed | Final integration CI; unsupported storage platforms remain explicit |
| #608 | Internal research skill, 3–6 canonical claims with pinned current revisions, bounded two-route procedure, citation-follow/stop/typed-handoff fixtures | Final integration CI; procedure execution is coordinator-owned. Optional live fetch is unsupported in this proxy environment |
| #609 | Existing review/contract-owner integration plus interviewer SRC/CLM revision validation and unresolved-question handoff | Final integration CI |
| #610 | Escaped HTML, PDF provenance and derived subtitle cue ranges; independent browser and preservation checks; shared-reader enforcement | Final CI; real-video synchronization, direct file opening and other native platforms unverified |
| #611 | Opt-in watch v2 records actual check time and independently detects metadata/cache/feed changes, with feature/source-bound state | Final integration CI; no background scheduler implied |
| #612 | Validated graph/impact lookup, cycles and traceability integration | Final integration CI |
| #614 | Owner measurement; 80 paired baseline/candidate trials retained | Final integration CI; uncontrolled host load prevents causal speedup claims |
| #615 | Feature feedback plus bounded same-process sealed full-check batches and final input revalidation | Final CI; original large/historical workload remains cold and half-time target unmet |
| #616 | Conflicting sudo guidance corrected, negative cases retained, actual host trust boundary documented | Authentic host-side issuer unavailable; no fabricated enablement |
| #617 | Actual runner-to-contract/bundle collector, prospective Red/Green, high/critical preparation; independent review and 21 tests; 6 matched comparison pairs preserve contracts/reports/verdicts | Final integration CI; human-time and error-rate benefit unmeasured. No production-key or production-review prerequisite is imposed on development. |
| #618 | Fixed-input reviewer navigation plus shared full-workflow batch reuse, with source-bound origin runs and comparative measurements | Final CI; arbitrary build/test caching is outside the initial proven profile; independent reviews remain fresh |
| #620 | PR-access preflight and sanitized failure diagnostics; authenticated browser reached token list | GitHub Confirm access (2FA) required before token details/repair; successful weekly run still pending |
| #622 | Pinned decision packets and existing human-only signer extension for adopt/reject/hold history; independent guard review closed | Final integration CI |
| #623 | Source-pinned inventory and ADR for existing executor capabilities | No suitable cancellation/resume/lease adapter established; Issue-defined stop condition, no new scheduler |
| #624 | Real paired fixture execution, 3baseline+3candidate runs and measured preparation spans | Real-app UX evaluation intentionally pending by user instruction; no benefit claim |
| #197 | Existing advisory dogfood implementation retained | Actual release-cycle evidence, authorized promotion and facet-hybrid end-to-end run |
| #187/#593/#604/#613/#621 | Dependency tracking retained | Parent completion follows the unresolved child acceptance above |

Independent review found and drove fixes for quoted-text forgery, evidence
replacement after validation, acquisition timeout escape, decision replay and
publication-journal bypass. Further integration findings are fixed before handoff.
No historical approval or frozen evidence was rewritten to manufacture acceptance.

## Consolidation and branch cleanup — 2026-10-25 (JST)

The current request authorizes work on all 33 open Issues and reuse/removal of
existing branches. Work proceeds on
`work-20261025-140557-resolve-open-issues`, based on `work` at `cf155d02`.
The requested `work/<timestamp>-<task>` spelling cannot coexist with the existing
local and remote `work` ref, so this task uses `work-<timestamp>-<task>`.

- Reused the original #614, #594, #605 and #601 draft branches by merging their
  history into the task branch. All 33 feature specification files retain the
  original branch bytes. Conflicts were confined to additive active-spec, ADR
  index and workflow-registry entries; all four entries are retained. Original
  draft PRs #631, #633, #637 and #638 remain open for their provenance and reviews.
- Included current `main` at `0535c3c1` (the yearly Dependabot schedule). This is
  a task-branch integration, not a merge into `main` or `work`.
- Audited 80 remote branches and deleted 33 already integrated branches in one
  atomic push. Every deleted tip is still an ancestor of `cf155d02`; none was an
  open PR head/base. Retained unique history, active PR branches and verification/
  release refs. The [branch ledger](branch-cleanup-20261025.json) records every
  original ref/SHA and disposition. After cleanup and the new task branch, the
  remote has 48 branches. No force push was used.
- Local verification passed: whole-repository workflow state; each of the four
  draft feature states; registry suites in Bash and Linux PowerShell; placeholder
  scanning; original-spec byte comparison; and the existing registered
  `tests/eval.tests.sh` fixture suite (16 assertions). The latter exercises real
  gates with normal, forged, missing-evidence and risk/traceability cases. It is
  regression groundwork, not implementation or acceptance of the proposed factory
  contracts, and not a model/UX comparison. Native Windows/macOS and hosted CI
  for this consolidation have not been executed at this point.
- The user explicitly selected fixture-only progress for #624. Real-app evaluation
  remains pending; no app, human UX judgment, adoption decision or parallel 2/4/8
  experiment is fabricated. #599/#600/#614/#622 implementation and the relevant
  #617/#618 contracts still precede an end-to-end factory fixture evaluation.
- The current policy has no adoption references for spec-reviewer-B,
  implementation-policy-reviewer-B or evaluator. Existing failed/unclear
  qualification results remain unchanged. Formal review and implementation
  statuses are still Pending/Draft; consolidation is not formal review.
- A fresh read of `actions/permissions/workflow` returned HTTP 403. The latest
  weekly run remains `40088779741`, completed with failure. #620 therefore still
  needs the actual PR-token/permission remediation and a complete guarded run;
  neither is implied by successful ordinary branch pushes. #616 still needs the
  separately authenticated human-input/issuer boundary described in its host
  readiness report.

No Issue was closed by this consolidation. At that checkpoint no additional model
evaluation had run; the development-session correction above supersedes the
earlier delegation and implementation-blocking interpretation.
The remaining Issue dependencies and original acceptance conditions below apply.

## Historical pre-implementation status — superseded

This retained historical section is superseded by the implementation checkpoints
and development-session correction above. Its old approval/adoption/implementation
blocks are not prerequisites for this development session. The dependency graph
is provenance only; use the current acceptance table.
A fresh unauthenticated [GitHub query](https://api.github.com/repos/aharada54914/sdd-forge/issues?state=open&per_page=100)
found **33 open Issues, excluding pull requests**. #619 remains closed, and
[#642](https://github.com/aharada54914/sdd-forge/issues/642) is now closed as completed
within its `work`-branch scope. Default `main` is now at `0535c3c1`; these changes
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
- **Implementation-policy reviewer A adoption is human-approved; B remains
  withheld.** Eight fixed Sonnet/medium calls completed with no retries; all eight
  output/execution contracts passed. A fresh separate-context source judgment
  accepted seven outputs: A passed four of four outputs and all 44 checks; B passed
  three of four and 43 of 44 checks. The B failure is an unsupported no-test-coverage
  assertion against planned TEST-003; its additional Major scope finding is valid
  and retained. The original joint HOLD report is preserved; the frozen promotion
  rule permits a separate passing-role-only human decision. The user approved the A-only proposal on 2026-10-25 (JST); the integration
  adds the genuine receipt and a pinned Sonnet/medium reference for A only, while
  preserving the five existing role references and candidate lifecycle. Evidence covers a small
  nonlegacy CLI/full-profile workload without domain/design-system contracts in a
  later-lifecycle context. A9 is labelled `bugfix` and uses local Bash/PowerShell
  tooling without a frontend; the approved application scope explicitly includes that local non-fullstack
  tooling surface, without claiming a bugfix-labelled benchmark was executed.
  First-time/fullstack/legacy/domain/design-system targets remain excluded. Amendment binding, convergence, protected entry,
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

## Direct subtitle follow-up — 2026-10-25

#606/#610 now support direct WebVTT/SRT URLs using a strict plain-cue subset.
Original-byte re-extraction derives quote time ranges for HTML; ordinary v1
results are unchanged. Unsupported markup/settings/timestamp maps fail explicitly.
Acquisition 29, consumer 15 and Bash/PowerShell owner 8 tests pass, with independent
negative controls. [Evidence](../../reports/verification/research-subtitles-20261025/README.md).
This does not establish live video synchronization or licensed shared storage.
The CI all_pins missing type annotation is fixed; the same ruff/mypy check passes.

## Licensed local-group storage follow-up — 2026-10-25

#606/#607 reuse the existing cache lifecycle and Source v1 for explicit Linux
local-group licensed_shared storage. Current filesystem permissions, ACL exclusion,
receipt and rights are checked before fresh verification. Original group readers
cannot write; unsupported remote/macOS/Windows profiles fail explicitly. Local
acquisition has 30 PASS / 1 SKIP (distinct reader identities need privileged CI).
The dedicated Linux CI case is added but its actual result remains pending.
[Evidence](../../reports/verification/research-shared-store-20261025/README.md).

The distinct Linux group-reader test subsequently passed in hosted run 40208046008
(f7ebf27a, step completed 15:53:33 UTC). The test uses readable copies of actual
product modules without changing runner-home permissions; child stderr now
surfaces any failure. The wider hosted suite remains separately tracked.

## Bounded full-workflow reuse follow-up — 2026-10-25

#615/#618 now have an opt-in batch on the existing full checker. It uses the
existing project process owner, sealed actual input/runtime bytes, same-process
successful origins and final full revalidation. No saved PASS is admitted. Git
history reconciliation and conditional external validators remain cold; ordinary
Bash/PowerShell Full/Lite/legacy behavior and other minimum gates are unchanged.
Nine actual session/negative tests, 35 existing project-runner tests and 419 guard
parity checks pass. Independent review reproduced and closed a separate-audit-read
race; independent normal parity and Passed Full cold-only behavior are recorded.
[Verification](../../reports/verification/workflow-session-20261025/README.md).

The original #614 frozen repository exceeds the initial sealed-file bound and
has zero reuse. Its two-full-check component was 78.003 s ordinary versus 79.237 s
with batch refusal/fallback (one pair). An additional, separately identified
48-Pending-Full workload improved by 22.2% at five requests and 43.5% at ten, but
was 13.4% slower at two. No half-time goal or whole-lifecycle speedup is claimed.
The optional path is recommended only after measured total-time benefit; the
implementation does not broaden closure or omit inputs to manufacture a hit.
[Comparison](../../reports/verification/workflow-session-comparison-20261025/README.md).

## Native/authentication follow-up — 2026-10-25

Actual Codex 0.159.2 app-server skills/list discovers the product-generated custom
wrapper in the isolated verify workspace, then confirms removal after cleanup.
[Evidence](../../reports/verification/project-skill-native-discovery-20261025/README.md).
The supported explicit auth probe still reports reauthentication_required for both
CLI profiles. A separate native model request also failed with HTTP 401 and
turn.failed requesting sign-in again at 16:24 UTC; no model comparison or
invocation success is claimed for #600/#602.

For #620, API workflow-permission access still returns HTTP 403. The previously
signed-in TinyFish GitHub profile reached the token list as the expected account,
but token detail/permission pages require GitHub Confirm access (2FA). No token
value was accessed and no settings changed. A user reauthentication question is
pending; the existing authorization to repair PR permissions has not been withdrawn.
#197 has no published GitHub release-cycle evidence; release/promotion acceptance
is not fabricated. #624 real-app evaluation remains pending by explicit instruction.

## Hosted integration follow-up — 2026-10-26 (JST)

Run [40211941204](https://github.com/aharada54914/sdd-forge/actions/runs/40211941204)
at `819aa9fc` completed with a failure in the shared Python profile: the shared-store
fixture used the hosted runner home, whose ancestor ACL is correctly refused by
the product. The workflow now provisions an isolated runner-owned directory under
`/var/lib` for that fixture and removes it in an always-run cleanup step. Runner-home permissions
and product admission rules are unchanged. The local acquisition suite passes
30 tests with one root-only skip, including a new actual ancestor-ACL rejection.
Final-source hosted CI is still required; this fixes test placement, not an ACL
exception in shared storage.

## macOS integration follow-up — 2026-10-27 (JST)

Run [40242573713](https://github.com/aharada54914/sdd-forge/actions/runs/40242573713)
at `3f488686` completed with 43 successful jobs, one expected skip and two failed
jobs (macOS version gates and the required-checks aggregate). The POSIX shared
profile and isolated shared-store fixture now pass. The sole underlying failure
was check-component-coverage TEST-036.2: `grep -q` closed its pipe early and
`printf` failed with Broken pipe under `pipefail`. The suite now drains piped
text while retaining matching/nonmatching exit status. Local suite: 46/46 PASS;
a 1 MiB reproduction returns 141 before the fix, 0 after it, and 1 for a missing
marker. This does not disable pipefail or alter product validation. Native macOS
confirmation and final-source CI remain pending.
