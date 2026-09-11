# sdd-forge Safe Consolidation and Symphony Execution Plan

Date: 2026-09-05  
Repository: `aharada54914/sdd-forge`  
Baseline: `origin/main@3749a252`  
Plan status: Reviewed, revised, and approved for gated execution  
Independent review: 2026-09-05, initial verdict NEEDS_WORK (3 Critical, 6 Major, 3 Minor); final verdict PASS (0 Critical, 0 Major)

## 1. Outcome and non-negotiable constraints

The program will improve `main` through small, reversible, independently verified waves while preserving every active line of work. It will not equate “no PR” with “abandoned,” and it will not let automation bypass the repository's SDD approval, review, provenance, or quality-gate boundaries.

The following constraints are mandatory:

1. Before assigning or integrating any issue, check five ownership signals: issue activity, open/closed PRs, remote branches, registered/local worktrees, and handoff/spec state.
2. Treat any checked-out worktree, recent handoff, nonterminal task, or recent unique commit as occupied until its current owner explicitly releases it.
3. Do not implement Draft or merely Planned SDD tasks. A human approval is required before implementation.
4. Implement one approved task at a time. Only the repository quality gate may mark it Done.
5. Do not rewrite, force-push, delete, close, merge, or otherwise mutate remote state as part of cleanup without an explicit, target-specific human decision.
6. Never resolve branch conflicts by choosing an entire side. Resolve path-by-path against the authoritative contract and preserve identity-ledger ordering.
7. Stop on ambiguous requirements, frozen-artifact changes, guard-protected files, human-copy paths, or a failed quality gate.
8. Existing PR checks never substitute for the repository SDD phases, independent reviewers, human task approval, or quality gate.
9. Do not create even a local integration commit until the human explicitly authorizes committing; verification checkouts produce evidence only.

## 2. Verified baseline and ownership map

The fresh local clone at `/Users/jrmag/sdd-forge` is isolated from the pre-existing active clone at `/Users/jrmag/Projects/active/sdd-forge`. The latter and all its worktrees are read-only inputs to this program unless their owners hand them off.

### Occupied work that must not be duplicated

| Work | Evidence | State | Program action |
|---|---|---|---|
| PR #389 / WFI-058 and WFI-059 | Primary active clone, clean checked-out branch, recent commits | Active; CI failures and review required | Observe only; consume its result after owner handoff |
| PR #386 / npm audit | Checked-out temporary worktree; one unique commit; checks green | Active verification candidate | Test its exact remote head in a disposable checkout; do not replay, reconstruct, commit, or compete while occupied |
| PR #245 / Epic #193 A5 | Dedicated worktree and current handoff; 369 unique patches, 19 conflicts, 1,208 changed files | Feature complete; human merge required | Quarantine from ordinary waves; use documented merge recipe in a dedicated human-led integration rehearsal |
| Epic #195 A7 | Dedicated clean worktree; T-012 In Progress and other tasks awaiting gates | Active without PR | Observe only until handoff and all task gates finish |
| Epic #196 A8 | Dedicated clean worktree; eight tasks Implementation Complete | Active without PR; verification incomplete | Observe only until all quality gates and external CI evidence finish |
| Epic #197 A9 | Dedicated clean worktree; spec review NEEDS_WORK | Blocked on human ruling for `plugins/domain/**` | Do not implement; resume only after ruling and spec-review remediation |
| `staging/cycle2-regate` | Dedicated clean worktree; 56 unique patches | Cross-model consensus failed; Done blocked | Preserve as evidence; no merge or cleanup |
| PR #364 / WFI-055 | Dedicated worktree; one unique commit; checks green | Occupied | Reproduce/review only after owner handoff |
| PR #363 / WFI-057 | Dedicated worktree; one unique commit; checks green | Occupied | Reproduce/review only after owner handoff |
| Epic #194 branch | Dedicated worktree; patch-equivalent to `main` | Probably integrated, but still occupied | Keep until owner confirms evidence/worktree retirement |
| Claude detached/local worktrees | Registered worktrees, including remote WFI-048 ancestry | Ownership uncertain | Inventory status and handoff before any classification |

### Open backlog groups

| Group | Items | Initial disposition |
|---|---|---|
| Immediate correctness/security issues | #387, #388, #359, #311, #289, #288, #291 | Highest-value investigation queue, excluding occupied or Human-Pending work |
| Immediate integration candidate | PR #386 | Verification-only while occupied; conditional integration after explicit handoff and SDD confirmation |
| Active staged work | #389, #245, #193-#197 | Preserve owners; integrate only via handoff and gates |
| Adversarial-review overlap | #345-#350, PR #371, Draft PR #381, and PR #382 merged only into #381's head branch | Build a patch-equivalence and requirements coverage matrix before choosing a survivor; do not mistake PR #382's merged state for inclusion in `main` |
| Dependency maintenance | PRs #372-#379 | Rebase/test as one coordinated wave after #386, then split only where package risk differs |
| Maintenance/audit | #295, #298, #380 | Convert current actionable findings into scoped tasks; close only with evidence |
| Strategic epics | #187, #290, #137, #66 | Keep as tracking/design work; do not mix into stabilization waves |
| Epic A5 follow-up | #353 | BLOCKED/DEPENDENT: wait for Epic #193 disposition and explicit human authorization for any frozen acceptance-contract amendment |

Snapshot note: counts and divergence values in this document were measured on 2026-09-05 JST. Dynamic decision packets must record measurement time, the owner clone's local HEAD, direct `git ls-remote` remote HEAD, merge base, and the exact measurement command; these values must never be reused as current facts without refresh.

## 3. Integration strategy

Every integration candidate moves through the following states:

`discovered -> ownership-cleared -> patch-equivalence-checked -> rebased/replayed -> scoped tests -> full local validation -> independent review -> local integration candidate -> human remote decision`

For each candidate, create an integration record containing:

- issue/PR/branch identifiers and owner/handoff evidence;
- merge base, ahead/behind counts, unique and patch-equivalent commits;
- exact changed paths and overlaps with other candidates;
- applicable requirements, task approvals, review gates, and frozen artifacts;
- CI status and local reproduction commands;
- selected integration method: fast-forward, rebase, cherry-pick, manual reconstruction, supersede, or defer;
- rollback commit/worktree and a proof that the original branch remains reachable.

The ownership scan covers every `refs/heads`, stash, detached worktree, and relevant reflog in every known local clone. Record a worktree's observed HEAD separately from direct `git ls-remote`; never fetch or mutate an owner's clone merely to refresh it. Work on unknown machines is inherently undetectable, so absence of local evidence never releases ownership. Before edits, require a timestamped human ownership claim/freeze naming the issue, paths, branch, owner, expected SHA, and lease expiry.

Selection rules:

- Prefer a minimal reviewed commit over merging a stale branch wholesale.
- Prefer reconstruction on current `main` when a branch is old, conflict-heavy, or contains mixed concerns.
- Keep documentation-only and dependency-only waves separate from workflow-engine changes.
- Treat generated artifacts, lockfiles, twins (`.sh`/`.ps1`), schemas, and dist bundles as atomic families.
- If two candidates solve the same requirement, select one canonical implementation after equivalence testing and record why the other is superseded.

## 4. Execution waves

### Wave 0 — Freeze, backup, and reproducibility

1. Refresh refs without pruning.
2. Export issue, PR, branch, worktree, CI, and handoff inventory with timestamps.
3. Create local archival tags or bundles for any cleanup candidate before a destructive recommendation; do not push them without authorization.
4. Run the clean-`main` baseline in a separate disposable worktree: repository validator, package tests, shell/PowerShell syntax checks, and platform-appropriate subsets. The four untracked operator planning artifacts in the primary fresh clone remain local and must not enter an integration commit.
5. Record known baseline failures separately from candidate regressions.

Exit: inventory is reproducible, every recent/occupied branch has an owner state, and baseline results are stored.

### Wave 1A — Occupied security PR verification

Candidate: PR #386.

1. Fetch the exact PR #386 remote head into the fresh clone and record its SHA without mutating the owner's clone.
2. Check out that exact SHA detached in a disposable verification worktree. Do not replay or reconstruct its changes and do not create a competing branch or commit.
3. Run audit commands for all affected MCP packages, their complete tests, repository validation, lockfile integrity, build/dist consistency, and prepare three-OS CI commands without dispatching them.
4. Obtain independent review focused on supply-chain changes, lockfile scope, generated bundles, compatibility, and repository SDD coverage.
5. Produce a decision packet only; leave the occupied branch and all remote state unchanged.

Exit: the exact head has independent verification evidence and a named owner/handoff status. This wave precedes Epic #193 and the Dependabot wave because the same audit failure currently obscures their CI signal.

### Wave 1B — Conditional security integration

Begin only after explicit owner handoff. Identify an existing approved task covering the exact dependency/lockfile/dist change or complete the repository's Phase 1 reviews, Phase 2 task review, and human approval. Symphony may stop at Implementation Complete; a separately identified evaluator must run quality-gate. Do not create a local commit until the human explicitly authorizes it. Integrate only the reviewed exact change and repeat all Wave 1A checks on the eventual candidate.

### Wave 2 — Small green documentation/workflow records

Candidates: PR #364 and PR #363, only after owner handoff.

Validate factual accuracy against current code, WFI schema/registry consistency, links, repository validation, and whether later branches already supersede the documents. Integrate separately so either can be reverted independently.

### Wave 3 — Current WFI implementation

Candidate: PR #389 after its active owner completes work.

Review WFI-058/059 requirements, confirm no collision with #387/#388 or Epic #193, diagnose current CI failures, and rerun twin/platform tests. Do not copy incomplete state from its occupied worktree.

### Wave 4 — Correctness defects with no cleared implementation owner

Provisional dispatchable order: #359 -> #311 -> #289/#288 -> #291. Issues #387 and #388 are `Audit-Status: Human-Pending` and remain non-dispatchable until the human approves their WFI documents; after approval, reprioritize them by dependency impact.

Before each item, rerun the ownership scan. Bootstrap or adopt an SDD spec, pass spec/implementation/task reviews, obtain human task approval, then implement exactly one task with TDD and quality-gate it. The order may change if dependencies or newly discovered active work require it.

Special handling:

- #387 after human WFI approval: preserve a minimal reproduction of the read-only command false positive; assess the forbidden-write instruction and Bash/PowerShell parity.
- #388 after human WFI approval: do not manufacture a frozen-document edit to advance a review round; design an investigation-only lawful transition.
- #359: recover the two existing patches from Epic #193 only after ownership clearance; separately fix and test greedy JSON extraction.
- #311: require structural scratch isolation and adversarial path/symlink tests, not behavioral convention alone.
- #289/#288: update contract, validator, templates, and frozen-evidence behavior as coordinated but separately traceable tasks.
- #291: test selective install/uninstall, all-plugin install, cache effects, and Bash/PowerShell parity.

### Wave 5 — Adversarial-review consolidation

Compare PR #371, Draft PR #381, PR #382's commits (merged into #381's head branch, not `main`), and issues #345-#350 at requirement and patch level. Split fixes already present on `main` from novel work. Reconstruct only missing, approved capabilities on current `main`; do not merge Draft PR #381 wholesale.

### Wave 6 — Coordinated dependency refresh

Do not begin until PR #386's disposition is final and an approved baseline containing the security fix has completed Wave 1B and its quality gate. Then rebase PRs #372-#379 onto that exact baseline, regenerate each affected lock/dist family, and run a matrix across `ci-mcp`, `local-env-mcp`, and `sdd-forge-mcp`. Merge order is GitHub Action update, type-only updates, runtime/library update, then inspector updates, unless test evidence establishes a different dependency.

### Wave 7 — Large epics

Epic #193 receives a dedicated integration rehearsal using its verified 19-path resolution recipe and a freshly measured identity-ledger tail. Human resolves guard-protected conflicts. Epics #195 and #196 follow only after every task reaches Done and their handoffs release ownership. Epic #197 remains blocked until its human specification ruling and all Phase 1 reviews pass. Tracking epics are updated only after constituent evidence lands.

## 5. Symphony local adoption

### Version and installation

Do not use the current `v0.0.2` binary for authenticated execution because it predates upstream commit `8001b52e3062495a16e520e4ceaf8f9de868c4d0`, which scrubs GitHub/GitLab credential aliases from child agents. Clone Symphony into an external, tool-owned directory; verify the upstream remote and GitHub-verified pinned commit; retain the pinned `mix.lock`; install the documented `mise` runtime; run `make -C elixir all`; and record the local executable's SHA-256. Keep Symphony code and runtime outside `sdd-forge`.

Production-repository execution is prohibited until Symphony runs under a dedicated OS user or container with an isolated `HOME`, no host `gh` configuration, no Git credential helper, no SSH-agent socket, and read-only mounts limited to pinned runtime inputs and the minimum Codex authentication material. Hooks run under an explicitly sanitized environment with every GitHub/GitLab token alias unset. Agent turns keep network access disabled; dependency bootstrap requiring network runs separately without tracker credentials.

### Pilot configuration

Use a local operator-owned workflow first; adding a repository-owned `WORKFLOW.md` is a separate governed SDD change.

- tracker: GitHub Issues for `aharada54914/sdd-forge`;
- dispatch filter: a new dedicated label such as `symphony-pilot`, plus `open` as the only active state;
- concurrency: `1`;
- workspace root: an isolated Symphony-only directory, never any existing worktree root;
- Codex sandbox: `workspace-write` restricted to the issue workspace;
- approval policy: reject sandbox elevation, rule changes, and MCP elicitation;
- credentials: a fine-grained GitHub token with repository metadata/issues read-only permissions, referenced only in the host-side isolated environment and never stored in the workflow, hook, logs, child environment, host `gh` config, Git credential helper, or SSH agent;
- hooks: fresh clone, exact baseline capture, repository validation, and no automatic push/merge/cleanup;
- turns: conservative cap with blocked/operator-input states surfaced;
- completion: stop at a review-ready handoff; do not close the issue or mark an SDD task Done.

The GitHub host tool must be constrained so POST/PATCH/PUT/DELETE fail. No production pilot may start until that negative property is demonstrated with the exact token and runtime boundary.

The workflow prompt must enforce the five-way ownership scan before any edit, require an approved single SDD task, preserve twins/generated artifacts, run TDD and scoped checks, and end with evidence plus rollback instructions. A missing ownership clearance or approval is a successful safe stop, not an automation failure.

### Durable ownership and cleanup hardening

Before production use, add or validate a single-instance filesystem lock and a durable claim ledger recording issue number, owner, baseline SHA, branch/workspace identity, claimed paths, lease generation, and checkpoint location. Restart must resume the same claim or stop safely; it must not create a second workspace/branch for an active claim.

Terminal reconciliation must never delete a dirty, unarchived, or uncheckpointed workspace. Because the reference implementation may remove a workspace even when `before_remove` fails, production use requires a tested local hardening patch or configuration that disables terminal cleanup. Every turn checkpoints a verified bundle outside the workspace root. Manual cleanup is restricted to canonical, validated Symphony-owned paths.

Keep every hardening change as an auditable patch series outside `sdd-forge`, rooted at the verified upstream commit. Record each patch SHA-256, the patched source-tree identity, retained `mix.lock` digest, and rebuilt executable SHA-256. A separate security reviewer must PASS the isolation, credential flow, claim/restart semantics, cleanup invariants, path canonicalization, and rollback design. Production pilot is forbidden until that review and every negative test pass. The rollback record must show how to stop the service, preserve claims/checkpoints, remove the patch overlay, restore the exact verified upstream source/binary, and revalidate its digest before any later use.

### Staged validation

1. Static validation: parse workflow, verify canonical paths, confirm safe policies, and verify commit/lock/binary digests.
2. Selection unit test: use the mock/memory adapter; do not call a production repository.
3. Disposable live E2E: use a scratch GitHub repository with the official GitHub adapter.
4. Credential negative tests: child `gh auth status` is unauthenticated; Git credential lookup and SSH-agent access fail; host `github_api` writes return 403; hook token aliases are absent; path escape toward active clones/worktrees fails.
5. Restart/claim test: kill and restart while active/blocked, confirm durable single ownership, the same workspace identity, and no duplicate dispatch.
6. Terminal cleanup test: close a scratch issue with dirty and unarchived states and prove the workspace/checkpoint cannot be lost.
7. Production polling test: use the read-only fine-grained token with agent launch disabled by an explicit tested local control.
8. Human-authorized single pilot: only after approval to create/apply the dedicated label to an exact issue; run one low-risk approved task to review-ready handoff, stopping before remote mutation and before Done.

Rollback: stop Symphony, revoke/unset its least-privilege token, acquire the single-instance lock, archive claims/checkpoints/logs after a secret scan, remove only clean and validated Symphony-owned workspaces after manual confirmation, and retain the pinned source/build metadata.

## 6. Verification plan

Each task uses a test pyramid proportional to risk:

1. Red reproduction or failing contract test before the fix.
2. Unit/scoped suite for the changed component.
3. Bash/PowerShell twin parity where either side changes.
4. Schema/template/fixture/generated-dist consistency checks.
5. MCP package audit/build/test for dependency or server changes.
6. `tests/validate-repository.sh` and affected workflow-state checks.
7. Full `tests/run-all.sh` and PowerShell equivalent for cross-cutting work.
8. Three-OS GitHub Actions for merge candidates when authorized.
9. Independent code/policy review, followed by the repository quality gate.
10. Post-integration smoke test from a fresh clone, plus patch-equivalence and provenance checks.

Failures never get hidden by broad allowlists or baseline updates. A flaky or environment-specific failure must be reproduced, classified, assigned an owner, and retained in the evidence record.

## 7. Branch and PR cleanup plan

Classification is recommendation-only until a human authorizes the exact remote action:

- **KEEP/ACTIVE:** occupied worktree, recent handoff, open PR, nonterminal task, or unresolved unique work.
- **MERGE CANDIDATE:** ownership released, requirements satisfied, rebased, independently reviewed, all gates green.
- **SUPERSEDED:** every unique patch is present in an identified canonical commit or intentionally rejected with recorded rationale.
- **ARCHIVE:** valuable failed experiment/evidence that must remain reachable but should leave the active queue.
- **DELETE CANDIDATE:** fully reachable from `main` or an immutable backup, no worktree, no active issue/PR/handoff, zero unique patches, owner confirmed.

Cleanup sequence:

1. Refresh refs without pruning and recompute patch IDs/reachability.
2. Ask active owners to confirm handoff/retirement.
3. Close or supersede PRs with a link to the canonical replacement and preserved review history.
4. Remove only clean, released local worktrees; prune stale registrations afterward.
5. Create and verify a local bundle/tag for unique archival work.
6. Delete a remote branch only after explicit target-specific authorization and a final reachability check.
7. Re-run issue/PR/branch inventory and verify no open item points to a deleted ref.

Initial recommendations: keep all currently occupied branches; retain #245 and `staging/cycle2-regate`; investigate the `codex/*`, `auto/*`, WFI-048, issue-137, human-copy, and Claude branches; consider `chore/agy-not-viable`, `fix/golden-test-checkout-robustness`, and Epic #194 only after owner confirmation despite their apparent reachability from `main`.

## 8. Reporting and decision gates

At the end of every wave, publish:

- exact baseline and candidate SHAs;
- ownership clearance evidence;
- changed paths and requirement/task traceability;
- test/review/gate results, including failures;
- local integration result and rollback procedure;
- issue/PR/branch status recommendations;
- explicit decisions still required from the human owner.

The program pauses for a human decision before: approving tasks, amending frozen specifications, resolving Epic #197's domain ownership, modifying guard/human-copy protected files, performing Epic #193's human merge, granting Symphony broader credentials/permissions, or every GitHub mutation—including label creation/application, comments, assignments, issue/PR state changes, workflow dispatch, releases, tags, pushes, merges, and deletions—unless the exact operation and target were already explicitly authorized.

## 9. Independent review resolution

| Review finding | Resolution |
|---|---|
| C1 duplicate implementation of occupied PR #386 | Accepted: Wave 1A is exact-SHA detached verification only; Wave 1B requires explicit owner handoff |
| C2 insufficient Symphony credential boundary | Accepted: isolated OS/container identity, sanitized hooks, read-only token, no host Git/SSH credentials, and negative tests are mandatory |
| C3 restart/terminal cleanup data loss | Accepted: durable claim ledger, single-instance lock, external checkpoints, and hardening/cleanup-disable gate added |
| M1 SDD and commit authorization gap | Accepted: explicit SDD coverage and target-specific commit authorization added |
| M2 ownership blind spots | Accepted: local refs/stashes/reflogs plus timestamped human claim/freeze and undetectable remote work caveat added |
| M3 missing issue #353 | Accepted: classified as blocked/dependent on Epic #193 and human frozen-contract ruling |
| M4 #387/#388 prematurely dispatchable | Accepted: moved to Human-Pending/non-dispatchable |
| M5 nonexistent generic dry-run | Accepted: replaced with mock selection, scratch live E2E, and agent-disabled production polling |
| M6 incomplete remote mutation list | Accepted: all GitHub mutations now require exact authorization |
| Minor inventory/build/artifact precision | Accepted: separated issues/PR, timestamped dynamic values, isolated clean baseline, and pinned build verification |
| Re-review: Wave 6 dependency ambiguity | Accepted: Wave 6 now requires a completed, quality-gated Wave 1B baseline containing the #386 security fix |
| Re-review: hardening review/provenance gap | Accepted: patch-series digests, independent security PASS, rebuilt identities, negative tests, and upstream rollback proof are production gates |
| Final focused re-review | PASS: 0 Critical, 0 Major; no new blocking finding |

## 10. Immediate next actions after review

1. Refresh all local-ref/worktree snapshots and record the remaining ownership unknowns without mutating owner clones.
2. Install and test the pinned security-fixed Symphony source in an isolated build environment; do not start an agent against the production repository.
3. Implement and prove the Symphony isolation, durable-claim, restart, and non-destructive-cleanup controls in a scratch environment.
4. Verify exact PR #386 head detached and produce the first decision packet without editing, committing, or dispatching CI.
5. Request only the precise human decisions necessary for the next state transition; leave remote `main` untouched until explicitly authorized.
