# Findings & Decisions

## Latest continuation evidence — 2026-09-05

- #389 at c5d32307 has a successful hosted Actions run (33938647223, 25 jobs including required-checks). It still needs the reviewed A-1/A-2/A-3 human-applied corrections, actual in-tree revalidation and final approval before merge. The old PR body's original WFI staging text is stale, not evidence those original fixes remain unapplied.
- Existing `second-approval-mask/tasks.md:99` excludes the hook guard, so its historical approval cannot govern the duplicate hook corrections supplied by the user. Primary review corrected the delegated misclassification.
- Local gh authentication fails with HTTP 401; the existing GitHub connector can read metadata and CI. This is not permission to export browser credentials or alter authentication settings.

## Hook-safety workstream update — 2026-09-05

The user requested independent adversarial hook remediation and consideration of full shell-analysis redesign. `docs/ci-staging/hook-safety-integration-plan.md` records the options, verification boundaries and integration sequence. Independent Astra review returned NEEDS_WORK; `docs/ci-staging/hook-adversarial-review.md` records the classified findings. The user subsequently accepted option B (restricted grammar plus command/option policy) and the equivalent independent Astra review procedure; those approvals are no longer pending. Implementation has not begun. The received installed-cache patch remains unendorsed. Structure and actual host activation prechecks passed, but those are not safety regression results.

Static evidence separates two problems: the received prefilter can miss unresolved syntax before its conservative metacharacter check, while the original reader allowance already has command-token/option ambiguity. The shared tokenizer strips quotation information, so reusing it as proof of literal target identity is not sufficient. See the addendum's source anchors and recorded adversarial report; runtime reproduction remains unavailable.

The initial cheap branch audit was denied guarded-file diff inspection. The user subsequently supplied `/tmp/sdd-hook-review.rhDmpQ`; both complete exported deltas were read successfully and their hashes/identities recorded in `docs/ci-staging/hook-branch-reconciliation.md`. They contain a duplicate Second-Approval correction, not role-shell parser changes. The missing-export blocker is resolved; current-main, formal-task and other-worktree ownership reconciliation remain required. No denied execution was rerouted. The high-risk brainstorming dependency `multi-agent-brainstorming` is unavailable; the user accepted the defined independent Astra equivalent procedure, not a formal gate PASS. Required SDD contracts/approvals and authorized protected execution remain outstanding.

For clarity, the historical #386 disposition below is superseded by the later integration evidence in `progress.md` and `PR386_VERIFICATION.md`: #386 merged at the specifically authorized head. Its administrative exception does not authorize another PR bypass. Existing PR389 remediation remains separate and unapplied.

## Current execution disposition — 2026-09-05

This dated section supersedes historical scheduling conclusions below, not their recorded evidence. GPT-6 Astra reviewed the execution amendment to PASS in Round 2; exact hash and scope are in EXECUTION_REVIEW.md. Production Symphony remains deferred/incomplete and does not block direct governed repository work.

Current evidence: BRANCH_INVENTORY.md (31 remote heads, verified backup, occupied/unique work preserved); PR_INTEGRATION_DOSSIER.md (#386-before-#389 recommendation and #371/#381/#382 semantic distinctions); ISSUE298_INVESTIGATION.md (actual false-positive reproduction, no committed affected-path patches on the 31 pinned branches, full local suite hung and was stopped); SYMPHONY_LOCAL_RUNBOOK.md (synthetic-only 7/7 pass, no live agent dispatch). Independent dossier review PASS, with remote freshness recheck required before use.

The exact-head #386 owner/governance/integration handoff is not established. No new task approval, product fix, main integration, Issue resolution, PR closure or branch deletion is claimed. Task memory is blocked on that concrete human boundary, not on the deferred Symphony engineering. No reusable long-term memory promotion: these are task-scoped snapshots.

## Requirements
- Pull `aharada54914/sdd-forge` to the local machine.
- Build a comprehensive safe integration, implementation, verification, and branch-cleanup plan.
- Have a separate agent review the plan and improve it before implementation.
- Bring OpenAI Symphony into the local workflow and use it during execution.
- Resolve the repository's issue/PR backlog and improve `main` incrementally.

## Research Findings
- The requested target directory did not exist; the repository was cloned fresh and `main` initially matched `origin/main`.
- Repository policy mandates a Spec-Anchored AI Development workflow with independent spec, implementation-policy, task, and quality reviews.
- Work must proceed one approved SDD task at a time; only the quality gate may mark a task Done.
- Repository policy forbids commits, pushes, and PR creation unless explicitly requested.
- Issue #61 currently permits only a tightly controlled, explicitly human-approved manual precheck fallback.
- Issue #86 tracks review-role schema drift relevant to post-implementation provenance re-review.
- Historical memory contains no directly authoritative sdd-forge integration decision; current repository evidence will govern.
- Current repository version is 1.17.0 and supports Codex CLI, Claude Code, and Copilot CLI.
- CI runs a large cross-platform matrix (Windows, macOS, Ubuntu) with repository validation, deterministic gates, guard tests, review-loop prechecks, cross-model tests, scenario tests, and parity checks.
- Remote inventory at 2026-09-05: 26 open issues, 15 open PRs, and 31 remote refs including `main` (30 non-main refs, one of which is the remote alias entry).
- PR risk is highly uneven: two PRs are only one commit ahead of current `main` (#386 and #389), while #245 is 388 commits ahead / 579 behind and changes 1,208 files, so it cannot be treated as an ordinary merge candidate.
- Open PR state: #389 and #386 are currently BLOCKED; #245 is DIRTY; #381 is Draft; the remaining PRs are mostly BEHIND or UNKNOWN and all require review.
- Several dependency PRs are parallel near-identical updates across three MCP packages, suggesting a coordinated dependency wave rather than arbitrary individual merges.
- Open issues include current correctness defects (#388, #387, #359, #311, #289, #288, #291), workflow-improvement batches (#345-#350), strategic epics (#187, #193-#197, #290), and maintenance/audit trackers (#295, #298, #380).
- Remote branches without obvious open PRs include old automation, staging, fix, and epic branches; branch deletion cannot be inferred solely from age or ahead/behind counts.
- Symphony is currently an engineering-preview scheduler/runner: it polls a tracker, creates one isolated workspace per issue, starts Codex app-server sessions, retries/reconciles work, and exposes structured status.
- Symphony's repository-owned contract is `WORKFLOW.md`; the prompt and YAML configuration control tracker selection, required labels/states, workspace hooks, concurrency, Codex sandbox/approval policy, and timeouts.
- The current Elixir reference implementation includes a GitHub Issues adapter, but OpenAI labels it prototype/evaluation software and recommends a hardened implementation for production use.
- Symphony explicitly supports handoff completion (for example human review) rather than forcing tracker issues to Done. This aligns with sdd-forge only if Symphony stops at SDD human-approval and quality-gate boundaries.
- Safer reference defaults use workspace-write isolation and reject approval/sandbox/MCP elicitation automatically; blocked approvals are surfaced rather than silently bypassed.
- A conservative pilot should therefore use a dedicated required label, one concurrent agent, isolated workspace root, no automatic merge/close/delete, and a prompt that treats Draft/unapproved work as non-implementable.
- A separate existing clone at `/Users/jrmag/Projects/active/sdd-forge` is currently checked out on `feature/wfi-058-059-implementation` (PR #389), confirming ongoing work outside the new clone.
- Existing local worktrees occupy `fix/npm-audit-fasturi-qs-20260903` (PR #386), `staging/cycle2-regate`, Epic #194, #193, #195, #196, #197, WFI-055, WFI-057, and Claude-created branches/detached workspaces.
- Several occupied branches have no open PR but very recent commits: Epic #195 (Sep 2), #196 (Sep 3), #197 (Sep 4), plus the staging/QG branches. These must be treated as actively owned until their handoff evidence says otherwise.
- Main's local repository validation passes. It emits tolerated amendment-record growth notices for Epic #195/#196, then reports workflow state and protected mirror drift checks as clean.
- Epic #195 is active without a PR: T-012 is In Progress, T-004 through T-011 and T-013 are Implementation Complete, and its handoff still requests independent review/regression work.
- Epic #196 is active without a PR: all eight tasks are Implementation Complete, with remaining quality/CI evidence work.
- Epic #197 is active without a PR and cannot proceed to implementation: spec review is NEEDS_WORK and a Critical finding requires a human ownership ruling for `plugins/domain/**`.
- Epic #193's current handoff declares its ten tasks Done but requires a human merge across 19 conflicts; its merge recipe must remeasure the identity-ledger tail.
- Symphony release `v0.0.2` predates upstream commit `8001b52e3062495a16e520e4ceaf8f9de868c4d0`, which removes GitHub/GitLab authentication aliases from child-agent environments. Authenticated use should build a pinned source revision containing that fix instead of using the older binary.
- PR #382 is marked merged, but its base was the head branch of Draft PR #381 rather than `main`; its changes must not be classified as landed on `main`.
- All three inspected Claude worktrees are clean, but two are detached and one is a local branch. Clean status does not establish release of ownership; their unique WFI/guard work remains quarantined pending handoff evidence.
- The pinned Symphony source revision builds only inside its documented mise toolchain; the exact local runtime is Erlang 28.5 with Elixir 1.19.5/OTP 28.
- Symphony's current upstream lockfile fails its own dependency audit with multiple High/Medium advisories, including Bandit, HPAX, Mint, Phoenix, Plug, and Req findings. This is a production-use blocker even before repository-specific hardening.
- The same upstream validation ran 296 tests with 3 failures and 6 skips. Two failures concern status-table truncation expectations and one is a retry-timing boundary assertion; none is being dismissed as harmless until reproduced and classified.
- A hardened isolated overlay at `/Users/jrmag/.local/share/openai-symphony-hardening-minimal-8001b52e` now passes `mix test test/symphony_elixir/core_test.exs` and `make all` after local dependency updates and test stabilization.
- Wave 1A pinned occupied PR #386 to exact head `1bd368aa3584a6a435e9b7ad4849dfb7019e3ec7` and verified it only in a disposable detached worktree; its owner worktree and all remote state remain untouched.
- PR #386's `ci-mcp` and `local-env-mcp` packages passed clean install, production audit, typecheck, all 199 tests, and generated-bundle reproducibility checks.
- PR #386's `sdd-forge-mcp` passed clean install, production audit, typecheck, all 243 discovered tests outside the one baseline parity exception, build reproducibility, and repository-wide validation.
- PR #386 independent review passed with 0 Critical and 0 Warning; independent QA passed with 243 successes, 0 failures, and 0 cancellations outside the explicit base-reproduced exception.
- One unchanged baseline test, `golden/deep-verify-parity.test.js`, does not terminate locally and is cancelled by Node with a pending-Promise diagnostic. A detached base `3749a252` worktree reproduces the identical behavior, proving it is not introduced by PR #386. The base install also reproduces one high and one moderate vulnerability while the PR audit is clean. This remains an explicit local limitation pending independent review.
- Symphony provenance after H-001/H-002 is pinned by digest: upstream lock `f707a715e6a4e91fc865c1c78d286a5211759a94659caa87e6cd6bad12a6f90c`, candidate lock `4760bfb2ebc2c1ced2d213a50173561bad22cb4ed6ae7c0fde4fbd8f03bc037c`, candidate binary `23c3e5c2a2ca025a7f0364df0f5b50134bc732c86ad727e3af00a08beba2d0f9`, and patch stream `2cc50d262d2e8815e21820e5c072057b372992362c8b56fc0e8cf99e58c371fb`.
- A credential-free Symphony eligibility/revalidation dry-run executed seven focused tests covering blocked providers, foreign assignment, missing labels, ready issues, last-moment revalidation, orchestrator restart overlap, and retry claim release; all seven passed. This uses Symphony's dispatch controls without granting it a real tracker or repository.
- Independent Symphony security review returned production `NEEDS_WORK` (1 Critical, 2 Major, 1 Minor). The minimal diff itself was assessed as candidate-safe with no evident permission expansion or credential-scrubbing regression, but it does not implement the production gates: durable claims, fail-closed cleanup, and host credential isolation.
- The same review requests explicit compatibility/boundary evidence for the broad framework dependency bumps and broader raw-attribute regression coverage for the command-validation change. Its isolated `app_server_test.exs` wait is tracked separately from the previously passing full `make all` run.
- Symphony H-002 now fails closed: local and remote `before_remove` failures/timeouts return an error, retain the workspace, and prevent remote deletion commands; cleanup wrappers no longer silently convert these failures to success.
- Orchestrator cleanup paths now log failed-closed preservation without hook output. Multi-host cleanup attempts every host and reports an aggregate failure. Independent review passed 0 Critical/0 Major/0 Minor; workspace/config, core, and full gates passed 57/57, 52/52, and 299/299 respectively.
- Direct raw-attribute regression coverage now proves `codex.command` defaults only when omitted, rejects explicit empty/whitespace atom and string keys, and preserves nonblank values. The focused security re-review marked the prior H-001 dependency/config findings CLOSED; the final suite passed 300 tests with 0 failures.
- H-003 cannot safely use an in-memory BEAM registration or stale PID/directory marker as its sole ownership boundary. The lock must be held for the process lifetime and released by the OS on death; an absent ledger is normal only on the first locked initialization, while corrupt or unsupported records must block startup.
- H-003A now passes independently with a lifetime OS lock, pre/post inode validation, atomic owner-only ledger files, strict schema/resource uniqueness, crash markers, and cleanup-path isolation. It deliberately does not claim protection from a hostile same-UID process; H-004 must deny hook and agent writes before production.
- H-002R closed the remote `Workspace.remove/2` containment gap: physical root/parent resolution, a strict root-child boundary, validation/hook/removal in one remote command, process-group timeout cleanup, and deterministic old-Bash refusal passed focused tests and independent review. Production remains blocked by H-003B/C and H-004.
- H-003B's smallest safe slice is supervision/startup containment only: `AgentRuntimeSupervisor` currently starts `Task.Supervisor` then `Orchestrator` under `:one_for_all` (`lib/symphony_elixir/agent_runtime_supervisor.ex:15-32`), while `Orchestrator.init/1` currently starts polling immediately after `Config.settings/0` and `run_terminal_workspace_cleanup/0` (`lib/symphony_elixir/orchestrator.ex:43-74`). The narrow task is to add the claim owner before the Orchestrator, block Orchestrator startup until a locked/decoded ledger is present, and make lock loss/owner death terminate or suspend scheduling before another poll cycle or worker dispatch begins. Durable claim transitions stay out of scope until H-003C.
- H-003B now closes that supervision/startup slice: the claim owner is first in a `:one_for_all` generation, readiness verifies the live Port and lock inode plus the current hot-reloaded workspace boundary, and every new poll/retry/final worker-start path fails closed on authority loss. A controlled race test proves a worker that starts in the narrow post-check window dies with the old TaskSupervisor before replacement polling.
- All H-003B fault-injection and worker-barrier seams are compile-time disabled in production builds, including direct ClaimStore and Orchestrator startup paths. A production-profile probe supplied every hook/fault and verified none executed and all stored hook/fault fields remained nil.
- Two simultaneously live custom runtimes with distinct exact registered names and claim roots passed isolation coverage. After an additive delegated change, the exact current tree was independently re-reviewed PASS with 0 Critical, 0 Major, and 0 Minor findings; focused tests passed 79/79, Dialyzer reported 0, and the final `make all` retry exited 0. The first full-gate attempt hit the known isolated fake-SSH trace timeout; that test passed alone before the unchanged full retry.
- H-003B does not persist claim-before-dispatch or recovery transitions. Therefore it does not prevent restart redispatch by itself, and H-003C/H-004 continue to prohibit Symphony from touching real issues, credentials, branches, or repositories.
- H-003C must treat `current_lease_id` and `active_lease` as one atomic nullable pair: both null or both present with identical IDs. Parent-entry, normal completion, abnormal fencing, restart validation, and crash tests must install or clear the pair atomically while preserving immutable terminated history.
- A host-local fence file cannot arbitrate split schedulers on different hosts. Production dispatch therefore requires an adapter-attested, project-scoped, linearizable non-recreatable create-once namespace; GitHub dispatch remains disabled unless that stronger no-bypass/tombstone guarantee can be proven.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Separate discovery/planning from implementation | Required by the user's sequencing and reduces accidental integration risk. |
| Model Symphony as an orchestrator constrained by repository gates | Automation must not weaken approval, provenance, or independent-review controls. |
| Use evidence-based branch classification | Cleanup must be based on reachability, unique commits, PR state, and replacement relationships. |
| Keep all occupied worktrees read-only | PR absence is not evidence of inactivity; current no-PR Epic work has explicit in-progress handoffs. |
| Pin Symphony to the security-fixed source commit or later reviewed revision | The newest tagged binary is older than a material credential-isolation fix. |
| Require isolated identity and durable Symphony claims before production use | Child environment scrubbing alone does not remove host Git/SSH credentials, and in-memory blocked state/terminal cleanup can cause duplicate dispatch or data loss. |
| Treat occupied PR verification as read-only evidence work | Reimplementation in a second branch would create the exact ownership collision the program is meant to avoid. |
| Keep the fetched Symphony revision non-operational | A failed dependency audit and non-green upstream test suite violate the reviewed enablement gate; no launcher or credentials will be added until both are resolved and independently reviewed. |
| Use the hardened isolated overlay only as a local validation aid | The upstream source was fixed and verified in scratch space; no real-repository launch or mutation was performed. |
| Do not convert PR #386 verification into implicit merge approval | The exact-head evidence packet still requires independent review, owner handoff, head revalidation, and explicit human authorization before integration. |
| Keep Symphony production dispatch blocked after security review | Candidate-safe is not production-ready; the Critical production gate remains open and must be implemented and re-reviewed. |
| Propagate cleanup errors instead of retaining the previous `:ok` facade | Silent success would release ownership state after data-preservation failure and make startup/terminal reconciliation unsafe. |
| Reopen H-002 for remote containment as H-002R | Hook failure handling was correct, but remote path validation did not prove that the deletion target belonged to the configured workspace root. |
| Close H-002R after independent review | Unsafe remote paths and timed-out hook descendants are contained and the old-shell branch fails closed, but this does not authorize real issue/repository dispatch. |
| Close H-003B after independent review | Scheduler generations can no longer outlive their claim authority, but the ledger is still non-authoritative until H-003C and same-UID/credential isolation remains H-004. |
| Re-review any delegated post-PASS mutation as a new snapshot | Shared-tree changes invalidate earlier hashes and evidence even when additive; the exact tree must regain focused, static, full-gate, and independent-review evidence before later work proceeds. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Workspace path in session context did not exist | Confirmed from parent directory, then cloned into the exact target. |
| A read-only `awk` inventory command was blocked because it mentioned a protected approval-status string | This is direct local evidence supporting issue #387's false-positive guard diagnosis; no bypass or write was attempted. |

## Resources
- Repository: https://github.com/aharada54914/sdd-forge
- Symphony: https://github.com/openai/symphony
- Symphony specification: https://github.com/openai/symphony/blob/main/SPEC.md
- Symphony Elixir setup: https://github.com/openai/symphony/blob/main/elixir/README.md
- Local policy: `/Users/jrmag/sdd-forge/AGENTS.md`
- CI workflow: `/Users/jrmag/sdd-forge/.github/workflows/test.yml`

## Visual/Browser Findings
- None yet.
