# Hook safety workstream — integration and architecture evaluation

Date: 2026-09-05
Status: option B and equivalent independent Astra review procedure accepted by user; formal SDD contracts and protected execution remain pending

This is a mutable planning addendum to `task_plan.md`, not a replacement for the hash-bound `EXECUTION_AMENDMENT.md`, an approved SDD task, or a passed review gate. The user requested adversarial hook remediation and subsequently requested consideration of a full shell-analysis overhaul. That request expands the comparison, not permission to override runtime enforcement.

## Accepted direction and remaining contract details

- Users: agents and repository operators using the existing Python, JavaScript and PowerShell hook entry points. Fix instructions-file false positives without weakening role-file protection.
- Security: evaluate the received cache patch adversarially; preserve existing approval, enforcement-file and role-file denial boundaries. No executing attack examples, enforcement bypass, silent cache replacement, credentials or external egress.
- Reliability: malformed input, unsupported grammar and unavailable analysis must not become an allow decision for a potentially protected operation. A parser is not proof that a program has no side effects.
- Performance/scale assumption: synchronous per-tool-call local analysis, no network services or new background worker. Measure against existing representative payloads before choosing numeric budgets; input size, nesting and execution-time limits must be specified before implementing a new parser.
- Maintenance assumption: preserve all three runtime entry points and their full decision contracts. A new dependency/shared parser requires an explicit installation, version pinning, failure and cross-platform support decision; none is selected by this plan.
- Non-goals: changing personal skills, merging #389 remediation into this patch, silently absorbing #387 or Second-Approval work, enabling production Symphony, or deleting branches.
- Resolved direction: the user accepted option B (restricted supported syntax plus command/option policy) and the independent Astra equivalent-review procedure. Exact supported syntax, options, runtime/environment assumptions and resource limits still need formal contracts and review; this is not blanket approval of unspecified parser behavior.

## Observed architecture, not assumptions

The role-shell predicate is regex-based (`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1714`) and its full decision path runs after other approval/enforcement checks (`:1892`, `:1903`). The reader regex uses a word boundary and an unrestricted argument span (`:74`). The received delta and hashes are recorded in `hook-boundary-handoff-review.md`; do not confuse those cache bytes with source.

A shared simple tokenizer already exists (`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1087`, JavaScript `:253`, PowerShell `:595`). Python removes quote delimiters (`:1105`, `:1112`, `:1129`) and emits only word/separator pairs. It is not a lossless shell AST. Existing protected-write consumers add their own unsafe-token checks (`sdd-hook-guard.py:1235` onwards). Replacing that shared helper would therefore have wider consequences than repairing the role predicate; exact consumer/branch ownership reconciliation is mandatory immediately before implementation.

## Options under evaluation

| Option | Benefit | Principal risk / acceptance boundary |
|---|---|---|
| A. Conservative local boundary repair | Small change and narrow rollback; may address the immediate false positive | Must prove no newly allowed unresolved target and no NEW unsafe reader exemptions relative to the pinned baseline. Existing reader-policy gaps remain explicit residual risks; A cannot claim all existing reader behavior is safe. If closing those gaps is required, select B or C rather than silently expanding A. |
| B. Explicit supported grammar and command policy | Replace ad-hoc allow logic with literal/unknown distinctions, exact executable tokens, constrained options and structured decision reasons | User-accepted direction. Intentionally rejects unsupported shell constructs. Needs per-dialect rules, approved task contracts and compatibility evidence; existing lossy tokens must not be treated as literal-path proof. |
| C. Dialect-aware AST frontends plus shared policy | Retain quoting, expansion, redirection, compound-command and nested-command structure | Largest portability, dependency and denial-of-service surface. AST recognition alone cannot resolve aliases/functions, executable behavior, filesystem aliases or all dynamic paths. Must retain unknown/deny outcomes and bounded resources. No blanket allow for parse success. |

A whole-parser rewrite is not rejected for size alone. Conversely, it is not selected merely because it parses more syntax. Compare its false-positive reduction and protection coverage against B, using the same adversarial corpus and actual hook decisions. If C wins, reserve an ADR number only after rechecking `docs/adr/`, and place the ADR there, not in this staging directory.

Independent Astra review recommended B and the user subsequently accepted that direction. Its required shared decision model distinguishes proven non-target, candidate/unknown and proven safe read. The actual shell dialect must come from trusted host/tool context rather than the language running the guard. See `hook-adversarial-review.md` for four classified findings (one introduced Critical, one verification Major, two pre-existing Critical findings with explicit scope boundaries). This acceptance is not an implementation test result or formal gate passage.

### Approval record and safe execution alternatives — 2026-09-05

User response to the preceding design/procedure approval question: 「承認する」. This resolves option B and use of independent Astra adversarial review as the defined equivalent for the unavailable `multi-agent-brainstorming` skill. Do not ask for the same direction again; do not claim the missing skill actually ran. Formal SDD specification, design, task and quality gates remain required.

The same message suggested copying to another name when protected changes or verification are denied. That method is not adopted: renaming/copying, encoding payloads, switching tools or delegating the denied operation to another agent/runtime in order to escape enforcement would still reroute the same denied operation. No such copy, alternate test execution or guard change was attempted.

Permitted alternative workflow:

1. Continue specification and static independent review only using allowed operations and already available evidence. Do not create a runnable renamed guard, substitute test implementation or permissive policy to obtain a Green result. Keep H-ADV-01 through H-ADV-04 open until their respective evidence obligations are satisfied.
2. For the blocked ownership check, request a human maintainer's normal branch-content review/export. The handoff must identify the original repository, complete base/head object IDs, original repository-relative paths, actual diff, and any local worktree changes/ownership. A PR title or name-only diff is insufficient. No agent-run alternate route is scheduled.
3. Only after formal task approval and ownership clearance, prepare reviewable non-executed change/verification documentation where permitted. The human maintainer performs protected application and real validation through the repository's normal maintenance process; the agent does not drive another terminal/browser/agent to simulate that human action. Never disable the host hook or its protected target membership.
4. Validate the actual original-path candidate using the intended, unmodified verification interface. Require executor identity, execution timestamp, evidence sender/source, base/head identities, source/test SHA-256 values, working-tree status, runtime/OS versions, exact invocation, raw stdout/stderr and exit code, individual case cardinality, and explicit skips. Label human-supplied evidence separately from any agent-observed reproduction: matching hashes establish target identity, not who executed a check or proof of execution on their own. No generated/fabricated execution fields. Secrets must not be included in the evidence handoff.
5. Resume independent review against that exact evidence and final diff. Reject mismatched hashes, changed test contracts, missing cases, renamed-shadow-only results or stale evidence. Formal quality-gate and actual deployment checks remain separate. If a subsequent check is denied, stop that check; the earlier human result does not authorize a new bypass.

This is an operator handoff boundary, not a new approval request and not a claim that the human steps have occurred. The immediate missing input is authorized exact-content branch reconciliation; protected implementation/testing additionally requires the normal maintainer execution step once the approved task exists.

Independent follow-up review: `/root/hook_adversarial_review` returned PASS for this approval/alternative-workflow section only. Its minor provenance suggestion (executor, timestamp, source and human-versus-agent evidence distinction) was incorporated into step 4. No product, implementation or SDD-gate PASS follows from this limited review.

## Verification contract to bind into formal acceptance tests

Every row must expand into individual TEST-ID assertions in the eventual acceptance artifact; this table is not a claim of test execution.

| Family | Required individual cases and oracle |
|---|---|
| Genuine sibling reads | Unquoted and quoted instructions-file path, supported reader forms, wrappers explicitly classified; ALLOW only for the supported unambiguous forms |
| Target identity | Directory, descendant role file, mixed case, slash/backslash host semantics, normalized relative path, quoted segments; preserve documented protection |
| Unresolved target syntax | Variable, command, brace, wildcard, escaping and quoted-concatenation boundaries; UNKNOWN cannot short-circuit to non-target/ALLOW |
| Reader policy | Exact command token versus prefix/suffix, supported options versus executable/output options, end-of-options delimiter, extra operands; do not infer safety from the command's name alone |
| Command structure | Sequential and conditional compounds, pipes, redirects, nested commands, newline and malformed/unclosed input; inspect every relevant node or conservatively reject |
| Non-shell contracts | Baseline-characterize invalid and valid role Write, Edit/MultiEdit and patch move destinations. The reviewer reports existing gaps for edit-only content and move destinations: capture current versus desired oracles separately. Closing them requires explicit additional task scope; shell-regression preservation does not imply these legacy gaps are safe or fixed. Existing approval/enforcement rules must not be weakened. |
| Full entry points | Each supported tool-name/payload shape and emit mode across Python, JavaScript and PowerShell; compare complete decisions/reasons, not just a copied regex |
| Parser failure and cost | Missing/incompatible dependency, unsupported dialect, parse error, resource limits and timeout; no permissive fallback |
| Deployment | Exact source/installed digests, activation canary, review-bound test result, rollback baseline and actual post-install recheck; deployment is separate from implementation PASS |

Test payloads must remain inert data inside an authorized test runner. A previously blocked predicate probe must not be rerouted through an encoded payload, alternate writer, fixture or tool. If authorized execution remains unavailable, record BLOCKED rather than inventing Green evidence. Static reasoning and the sender's 17 limited rows are not full regression proof.

## Execution order and integration gates

1. Complete independent Astra adversarial review and cheap exact-ref branch-content audit. Record severity, introduced versus pre-existing defects, affected runtime twins and missing oracles.
2. Use the already accepted option B and equivalent-review direction; complete remaining detailed contracts and required bootstrap specification/design reviews, task decomposition review and task approval. Structure precheck passed; the native canary denial verified HOOK_ACTIVE, recorded in `hook-boundary-handshake.json`. Domain is absent, so no domain injection; project context is absent, so the documented full compatibility track applies.
3. Implement one approved task only. Before a high-risk implementation, enumerate every persisted evidence field, its counterpart and a failing mismatch test in the implementation report. Use independent low-cost implementation/testing roles only for authorized, bounded work; Astra retains adversarial design/final review.
4. Record Red/Green and full applicable guard suites, three-runtime parity, negative corpus, repository validation and relevant consumer regressions. Any platform skip newly made reachable must be executed on that platform or explicitly remain pending, never silently count as PASS.
5. Run independent exact-diff adversarial review (maximum three repair rounds; unresolved repeated findings escalate). Then run the repository quality gate; only it can mark Done. Ordinary adversarial intake review cannot substitute for formal review identities or gate evidence.
6. Separately approve and verify source/cache promotion. Preserve baseline hashes and a narrowly scoped rollback artifact; do not overwrite independently changed files. Never apply by disabling the executing guard. If it refuses, stop at a reviewed handoff for an authorized operator.
7. Integrate only passing work into the consolidation wave after rebasing/rechecking exact ownership. Any rebase, conflict resolution or subsequent byte change invalidates the old exact-diff review/testing for changed inputs: repeat independent final-diff review and applicable tests immediately before promotion. #389 stays on its own path; this work neither clears its findings nor inherits #386-only administrative merge permission. No branch deletion is scheduled by this addendum.

## Current result

Planning and activation checks only. No source/cache modification, implementation task completion, regression PASS or deployment approval is claimed. Existing received cache remains unendorsed pending review and remediation; its presence is not evidence of safety.

### Ownership investigation limitation

Cheap investigator `hook_overlap_audit` identified same-file changes on `origin/auto/improve-20260831` (`32a81f5e`) and `origin/auto/improve-20260817` (`f6e7427c`): Python/PowerShell guard and their test surfaces. Its attempts to inspect guarded-file diff contents were denied before execution. The resulting name-only evidence is **not** exact-hunk reconciliation; implementation ownership clearance is **BLOCKED**, not complete. No alternate inspection route was used to defeat that denial. The WFI-048 branch was reported as different work, but it is not certified conflict-free. Retain every branch and require authorized content inspection before assigning overlapping edits.

The adversarial reviewer also reported denied line-number-formatting reads; it used already available evidence and did not reroute those denied operations. These are tool-execution limitations, not product test failures or evidence that the reviewed fix passes.

Update after human export: the user supplied `/tmp/sdd-hook-review.rhDmpQ`. The complete exported deltas have now been inspected; `hook-branch-reconciliation.md` records original full IDs, hashes, duplicate Second-Approval implementation hunks and test limitations. This supersedes the missing-content blocker above, but does not certify current-main compatibility, release other owners, pass a task gate or permit protected execution. Treat the two branches as one correction candidate and keep it separate from role-shell policy work.
