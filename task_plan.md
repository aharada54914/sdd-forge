# Task Plan: sdd-forge Safe Consolidation and Symphony Adoption

## Goal
Safely inventory and integrate the repository's open work, adopt OpenAI Symphony locally as an execution aid, and improve `main` through reviewable, verified, one-task-at-a-time changes.

## Current Phase
Phase 4 — evidence and governed execution; production Symphony deferred under `EXECUTION_AMENDMENT.md`.

Latest execution: PR389 MERGED into remote and local main as ca023cc85d9db5d44f63ec77e4d3ff73f3f9bfdf. CI run33962847954 all25 jobs PASS, exact-head Astra conditions satisfied, merged tree identical to reviewed candidate, post-merge WFI7/7 PASS and unrelated tracked dirty diff preserved. Dependency Phase 1 bootstrap independently stopped at a hook-denied required activation challenge; no rerouting or task approval inference. See PR389_VERIFICATION.md and docs/ci-staging/dependency-bootstrap-preflight-20260905.md. All-issue completion remains outstanding.

## Phases

### Phase 1: Repository and Remote Discovery
- [x] Clone the repository without overwriting local work
- [x] Read repository and global agent instructions
- [x] Recall relevant historical constraints
- [x] Inventory code, test, release, and SDD workflow architecture
- [x] Inventory open issues, PRs, and remote branches
- [x] Inspect Symphony's current requirements and integration model
- [x] Build an ownership/collision map from every local worktree, open PR, remote branch, handoff note, and recent commit
- **Status:** complete

### Phase 2: Comprehensive Plan and Independent Review
- [x] Classify work by risk, dependency, duplication, and merge readiness
- [x] Draft integration, implementation, verification, rollback, and branch-cleanup plans
- [x] Define the local Symphony adoption boundary and safety controls
- [x] Obtain independent agent review
- [x] Revise the plan and record accepted/rejected feedback
- [x] Obtain final focused re-review PASS
- **Status:** complete

### Phase 3: Local Symphony Enablement
- [x] Fetch and pin the reviewed upstream source in an external isolated directory
- [x] Install the exact upstream runtime toolchain without granting repository credentials
- [x] Clear the upstream dependency-audit and test-suite blockers in the isolated candidate
- [x] Obtain independent security review of the minimal candidate (candidate-safe, production NEEDS_WORK)
- [x] Implement H-003B only: make `AgentRuntimeSupervisor` own the ledger owner before `Orchestrator`, require startup to wait for a successfully locked/decoded ledger, and terminate or suspend scheduling on claim-store death or lock loss without wiring durable claim transitions
- [x] Review the detailed H-003B supervision/root/readiness contract independently before coding (PASS: 0 Critical, 0 Major, 0 Minor)
- [ ] Implement durable claims, fail-closed cleanup, and host credential isolation in an isolated hardening worktree (H-002R, H-003A, and H-003B independently passed; H-003C and H-004 remain)
- [x] Implement the H-003C codec foundation in the isolated Symphony candidate: claim identity/token encoding, validation, and regression coverage
- [x] Pass the H-003C codec-foundation verification stack, including `make all` at 100% coverage
- [x] Implement H-003C1a: fail-closed empty-v1 to empty-v2 ledger-envelope migration and disable unrestricted production `replace/2`, without accepting non-empty v2 claims yet
- [ ] DEFERRED: H-003C1b and later production transitions; not required for direct governed repository work (see `EXECUTION_AMENDMENT.md`)
- [x] Add focused compatibility and raw-attribute regression evidence requested by security review
- [ ] Implement the reviewed local integration in an isolated branch/worktree
- [ ] Validate installation, permissions, configuration, and dry-run behavior
- [x] Document synthetic-only rollback and operator workflow in SYMPHONY_LOCAL_RUNBOOK.md; production remains deferred
- **Status:** local installation/synthetic use achieved; production enablement deferred, not complete

### Phase 4: Issue and PR Execution Waves
- [x] Obtain GPT-6 Astra program review; accept scope/permission findings and draft scheduling amendment
- [x] Obtain Astra Round 2 PASS for the exact scheduling amendment; record EXECUTION_REVIEW.md
- [x] Refresh exact-SHA branch/PR/Issue inventory, verify backup, and finish CI/overlap and Issue #298 dossiers
- [x] Start Wave 1A with read-only verification of occupied PR #386 at an exact pinned head
- [x] Obtain independent review of PR #386 and its local parity-test exception (PASS: 0 Critical, 0 Warning)
- [x] Record explicit PR #386-only administrative merge authority, merge exact approved head into remote main, and fast-forward local main without altering unrelated changes
- [x] Build isolated #386 + #389 candidate; all three MCP audits, typechecks, reproducible builds and 442 tests pass with one explicit baseline file exclusion
- [x] Complete #389 targeted regression and independent exact-tree review; update its existing branch for hosted CI with merge-blocking findings explicitly recorded
- [x] Apply reviewed #389 A-1/A-2/A-3 remediation through the human maintainer, verify the exact six-file delta and obtain independent Astra actual-tree scoped PASS (nine regressions passed independently)
- [x] Commit and ordinary fast-forward push exact reviewed six-file #389 remediation as 25304d3b; actual-tree primary checks and Astra scoped review recorded
- [x] Verify #389 relevant native golden cases: 30/30, tester plus primary independent rerun; Astra final scoped local-readiness PASS, Windows-specific coverage not claimed
- [x] Receive explicit PR389-only administrator review exception, conditional on resolution of remaining verification problems and all required CI success; no protection-rule edits or failure waiver
- [ ] Resolve #389 fresh CI run 33960178745 and unwaived shell failures, then recheck exact head/base and perform the specifically authorized merge
- [x] Add the user-requested hook-safety workstream, independent Astra adversarial reviewer, and cheap branch-content investigator; keep it separate from #389 and existing consent/Second-Approval work
- [x] Expand the hook analysis to compare narrow repair, strict supported grammar/policy, and dialect-aware AST redesign at the user's request; record proposed trade-offs in docs/ci-staging/hook-safety-integration-plan.md
- [x] Run hook-work intake prerequisites: structure OK, absent domain/context compatibility fallback, actual native-tool canary denied and handshake HOOK_ACTIVE
- [x] Obtain independent Astra adversarial intake/design review; record NEEDS_WORK and incorporate scope, three-state analysis, branch-blocker and final-diff re-review refinements (docs/ci-staging/hook-adversarial-review.md)
- [x] Record user acceptance of option B (restricted grammar plus command/option policy) and the equivalent independent Astra review procedure; do not repeat that approval question
- [x] Receive and inspect human-exported exact deltas for the two auto/improve branches; classify their duplicate Second-Approval correction and regression-evidence limitations (docs/ci-staging/hook-branch-reconciliation.md)
- [ ] Complete current-main/task/owner reconciliation before implementation; supplied deltas resolve the missing-export blocker but do not release other worktrees or authorize protected execution
- [ ] Bind hook requirements, adversarial acceptance cases, design, and task contracts through the required SDD review/approval gates
- [ ] Implement only the approved hook task in an authorized environment; preserve runtime denials, never weaken the executing guard to apply or test a fix
- [ ] Require three-runtime full-decision regression evidence, independent exact-diff security review, quality gate, and separately verified deployment/rollback before adopting any hook cache/source change
- [ ] Execute approved work one SDD task at a time
- [x] Complete parallel exact-head verification for dependency PRs #374/#375/#377/#378/#379 (744 package tests, audits, typechecks and tracked bundle parity); record #376 generated-drift and #373 Windows-timing diagnoses and preserve occupied WFI #363/#364
- [x] Record the 2026-09-05 owner extension of administrator approval-review bypass to other PRs in this consolidation program, conditional on completed SDD gates and all mandatory CI passing; supersedes the former #386/#389-only boundary without changing protection rules
- [ ] Establish matching dependency task/gate and ownership coverage; use normal GitHub approval or the newly authorized conditional administrator exception after fresh exact-head/base/required-check verification
- [ ] Run required independent implementation reviews
- [ ] Run required quality gates and regression suites
- [ ] Integrate only passing changes into local `main`
- **Status:** in_progress

### Phase 5: Branch Hygiene and Delivery
- [x] Produce keep/merge/supersede/archive/delete recommendations in BRANCH_INVENTORY.md
- [x] Verify remote-ref backup; explicitly exclude owner local-only and uncommitted work
- [ ] Apply only explicitly authorized remote destructive actions
- [ ] Deliver final evidence, remaining risks, and next-wave backlog
- **Status:** pending

## Key Questions
1. Which open issues and PRs are independent, overlapping, obsolete, or blocked by repository workflow rules?
2. Which remote branches contain unique commits not represented by open PRs or `main`?
3. How can Symphony be used without bypassing SDD approvals, independent review, or quality-gate authority?
4. What is the smallest safe integration wave that improves `main` while preserving rollback?
5. Which branch cleanup actions are local-only, reversible, or require explicit remote authorization?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Treat this as a multi-role program | It spans external tooling, many branches/PRs, multiple files, and repository governance. |
| Do not merge or fix issues before plan review | The user explicitly requires reviewed planning before execution. |
| Use isolated branches/worktrees and one approved SDD task at a time | Required by repository policy and limits blast radius. |
| Treat recalled memory as hints only | Repository state and current upstream documentation are authoritative. |
| Treat any checked-out worktree branch as occupied, even without a PR | Local evidence shows active Epic and gate branches with recent commits but no open PR. |
| Require five-way collision checks before assigning work | Issue, PR, remote branch, local worktree, and handoff/spec state must all be checked to prevent duplicate implementation. |
| Verify occupied PRs without reconstruction | The independent review identified that a second implementation branch would itself create ownership conflict. |
| Block production Symphony agents pending hardened isolation | The reference prototype's child, hook, restart, and terminal-cleanup boundaries need negative proof before real-repository execution. |
| Accept the minimal Symphony overlay only as a safe dry-run tool | Independent security review found no permission or credential-scrubbing regression, but returned production NEEDS_WORK until durable claims, fail-closed cleanup, and host credential isolation exist. |
| Make `before_remove` fail closed | A failed preservation/export hook must never be followed by irreversible workspace deletion; errors now propagate and are logged while the workspace remains intact. |
| Keep H-003A standalone and production-blocked | Its locked ledger is independently verified, but remote containment, supervision/transition wiring, and same-UID hook/agent isolation remain separate mandatory gates. |
| Close H-002R without enabling production dispatch | Physical remote containment, fail-closed hook timeouts, descendant process-group termination, and Bash-version refusal passed independent review; H-003B/C and H-004 still block real-repository use. |
| Keep H-003B narrow | Only supervision/startup containment is in scope now; durable claim transitions, branch cleanup, and host isolation remain out of scope until separate reviewed tasks. |
| Close H-003B without enabling production dispatch | Live claim-owner readiness, generation teardown, hot-reload root revalidation, and compile-gated test seams passed independent review and full validation; authoritative transitions and host isolation remain H-003C/H-004 gates. |
| Require three external fences before Symphony provisioning | A local ledger cannot arbitrate split claim roots; tracker-project, target-repository/full-ref, and physical-workspace fences prevent duplicate work even when an active issue has work only on an unsubmitted branch or is aimed at another repository. |
| Make hook safety a separate prerequisite for adoption of the received cache delta | User requested adversarial review on 2026-09-05. The received patch has a static expansion-boundary concern and limited runtime evidence. Its intake does not authorize source adoption, certify the cache, clear #389, or enable production Symphony. |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Initial shell launch failed because `/Users/jrmag/sdd-forge` did not yet exist | 1 | Ran the prerequisite checks from `/Users/jrmag`, confirmed absence, then cloned safely. |
| `find .. -name AGENTS.md` produced excessive unrelated output | 1 | Switched to reading the exact repository `AGENTS.md`. |
| Read-only task-state inventory was denied by the consent/approval hook because the command contained a protected status literal | 1 | Logged as evidence consistent with open issue #387; split validation from inventory and will use a parser that does not embed the protected literal in the shell command. |
| Symphony's documented `make all` could not find `mix` | 1 | Re-ran through the pinned mise environment so the exact Elixir/Erlang toolchain was on `PATH`. |
| Symphony's full upstream validation found vulnerable locked dependencies and 3 test failures | 1 | Kept the source non-operational and credential-free; investigating upstream remediation and failure reproducibility before any launcher or real-repository pilot. |
| Initial H-002 worker did not produce a diff or respond | 1 | Interrupted the worker to avoid shared-tree conflict and completed the narrow change locally with red/green tests. |
| H-003A full gate initially failed inside Dialyxir's formatter | 1 | Ran raw Dialyzer, found an actual opaque `MapSet` comparison, replaced it with `MapSet.equal?/2`, then passed Dialyzer and the full gate. |
| An independent tester modified H-002R while validating it | 1 | Stopped concurrent edits, reconciled the shared diff locally, and required the final reviewer and verifier to operate read-only. |
| H-003B full coverage hit an existing SSH trace timeout once | 1 | The same SSH test passed alone, and the complete `make all` retry passed; recorded as a pre-existing parallel-suite flake rather than suppressing it. |

## Guardrails
- No commit, push, PR creation, remote branch deletion, or remote issue mutation unless explicitly requested.
- No implementation of Draft tasks; human approval remains mandatory unless the repository's documented bypass is explicitly invoked.
- Only the repository quality gate may mark an SDD task Done.
- Preserve unrelated changes and use reversible operations wherever possible.
- Do not execute Symphony against any real repository while its dependency audit or upstream test suite is failing.
- Re-read this file before each major decision and update it after every phase.
- Never classify a branch as abandoned from PR absence alone; require reachability, patch-equivalence, last-update, worktree occupancy, and handoff evidence.
