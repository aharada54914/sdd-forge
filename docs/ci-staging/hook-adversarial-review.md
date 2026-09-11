# Independent Astra adversarial intake review

Date: 2026-09-05
Reviewer: `/root/hook_adversarial_review` (GPT-6 Astra, independent fresh context)
Verdict: NEEDS_WORK
Scope: received cache delta, current source and proposed architecture/integration plan

Subsequent approval/procedure-only follow-up: the user accepted option B and the independent Astra equivalent procedure. The same independent reviewer returned PASS for the integration plan's new "Approval record and safe execution alternatives" section only. It confirmed no rename/tool/agent bypass, no expansion of design approval into execution/gate approval, and no claim that human steps occurred. Its minor suggestion to add executor, timestamp, evidence source and human-versus-agent provenance was incorporated. The product verdict above remains NEEDS_WORK and all four findings below remain open.

This document records the independent agent's returned findings. It is not a formal SDD gate report, approval ledger entry, runtime reproduction, or claim that any task is Done. No reviewer edits to product, cache or tests occurred. Three additional formatting reads were denied by PreToolUse and were not rerouted. The prior predicate-probe denial remains respected.

## Findings

### H-ADV-01 — Critical, introduced adoption blocker: unresolved suffix becomes non-target

The received target-prefilter excludes expansion/glob/brace suffix syntax immediately after the literal role-directory name, returning non-target before conservative syntax rejection. The old word boundary recognized these positions. Moving the new metacharacter check alone is insufficient because that check also omits wildcard/brace characters. Keep target uncertainty distinct from proven non-target; any literal sibling exemption must be operand-local and must not suppress other role references in the command. Preserve the received delta's improvement that prevents a leading reader match from hiding a later compound operation.

Evidence: received `outputs/hook-fix.diff` lines 9, 24 and 37 under `/Users/jrmag/Documents/Codex/2026-09-05/agents-md/`; source Python predicate `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1714`, JavaScript `:1215`, PowerShell `:264`; full decision calls Python `:1903`, JavaScript `:1896`, PowerShell `:1872`. Static-only finding; not runtime reproduced here.

### H-ADV-02 — Major, adoption blocker: limited tests are not complete shell decisions

The received 17-row report is 14 shell-predicate cases and three full malformed-role Write cases. JS/PS run extracted functions, Python calls the predicate; shell tool envelopes, emit modes and complete reasons are not exercised. The driver uses `zip` without asserting result cardinality. Require original source identity, runtime versions, complete hook invocation, explicit decision/reason oracles, exact result counts, and all supported output modes. Do not rerun a denied probe or overwrite the sender's helper/report as a workaround.

Evidence: sender `work/test_hook_boundary.py:4`, `:25`, `:42`, `:44`; `outputs/hook-boundary-tests.json:114`. These existing reports are useful limited evidence, not Green for a new implementation.

### H-ADV-03 — Critical, pre-existing: reader-name recognition is not side-effect proof

The reader regex uses a word boundary rather than the entire executable token and accepts unrestricted arguments. Reader-name suffixes can therefore qualify, and legitimate readers may offer execution/configuration-dependent options. The reviewer inspected local ripgrep 15.2.0 help only: `--pre` invokes an external process; `--no-config` disables configuration loading. Exact reader names alone are insufficient. A stronger policy needs explicit safe options/operands, command identity and environment assumptions, and rejection of unknown behavior.

Evidence: Python reader regex `sdd-hook-guard.py:74`, JS `sdd-hook-guard.js:132`, PS `sdd-hook-guard.ps1:269`; local help excerpts reported by reviewer. This predates the delta. It invalidates a general safe-reader claim, but is not falsely attributed to the received boundary change.

### H-ADV-04 — Critical, pre-existing and additional scope: incomplete structured-write coverage

Role validation depends on `content`, while Edit/MultiEdit can carry `new_string`/`edits`. Patch checks scan Add/Update/Delete headers but not move destinations. A broader all-interface protection guarantee must explicitly cover these cases. Closing them is a separate behavior-changing remediation contract, not silently preserving every current decision.

Evidence: Python `sdd-hook-guard.py:926`, `:1745`, `:898`; JavaScript `sdd-hook-guard.js:1606`, `:1180`; PowerShell `sdd-hook-guard.ps1:1666`, `:1592`. Record current and desired oracles separately before approval. No runtime reproduction is claimed.

## Architecture recommendation

Recommend **B: explicit restricted grammar plus semantic command/option policy**. A narrow regex repair (A) may only claim no newly weakened denials and explicitly accepted literal sibling exceptions; it does not resolve H-ADV-03/04. A dialect-aware AST frontend (C) remains a valid full-overhaul candidate if measured compatibility gains justify dependency, packaging and maintenance cost, but still requires B's semantic policy.

Required analysis states are `proven-non-target`, `candidate-or-unknown`, and `proven-safe-read`, not a boolean prefilter that conflates unknown with harmless. Choose actual shell dialect from trusted host/tool metadata, not the guard implementation language. Do not use interpretation or expansion execution to resolve unknowns.

The existing tokenizer strips quote delimiters and outputs word/separator pairs (`sdd-hook-guard.py:1087`); consumers add separate safety checks (`:1235`). It cannot be reused as proof of literalness without a revised contract. Bound bytes, tokens/nodes, nesting, time and output. Parser absence, errors or budget exhaustion must not allow potentially protected operations. AST parsing alone cannot establish executable behavior, aliases/functions, configuration, filesystem alias/case semantics or freedom from check/use races.

No parser dependency was selected or installed. Any future candidate requires primary-source evaluation, exact version and platform support, a contract/ADR and independent review before use.

## Required acceptance expansion

Bind individual assertions for: genuine sibling operands; sibling plus role references in both orders; bare/descendant/case/separator identity; variable/substitution/backtick/wildcard/brace boundaries; literal versus active quoting and adjacent quote segments; exact reader names and safe/unsafe/unknown flags/config; sequential/conditional/background/pipeline/CR/LF structure; redirects and here-documents; nested/interpreter execution; path/directory/alias uncertainty; malformed and supported tool payloads; all three runtimes and output modes; parser resource failures; unchanged unrelated approval/enforcement controls. Structured Edit/MultiEdit/move gaps require explicit additional scope rather than an implied fix.

The complete acceptance-family table is in `hook-safety-integration-plan.md`. Neither table is executed test evidence.

## Plan review and disposition

The reviewer found the proposed plan directionally sound, with refinements rather than a formal PASS. Primary incorporated the requested distinctions: A promises no NEW unsafe reader exemptions; non-shell baseline and desired oracles are separate; branch-content reconciliation is explicitly BLOCKED; merge/rebase or any changed reviewed bytes requires final-diff re-review and relevant tests before promotion. The three-state analysis requirement is added as an explicit design constraint.

Proceed in this order: select the intended guarantee and approve design → bind exhaustive specifications and SDD task reviews/approval → one authorized implementation task → full three-runtime evidence → exact-diff adversarial review and formal quality gate → separate deployment/rollback verification. Name-only branch overlap is not clearance; existing installed cache is not endorsed. The unavailable `multi-agent-brainstorming` dependency requires an explicitly accepted equivalent independent-review procedure before implementation; this review must not be represented as that skill having run.
