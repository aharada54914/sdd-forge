# Shared review launch integration (development record)

- Scope: approved first six environment repairs only: CLI aliases, shared non-TTY argv and real callers, pre-reservation input/path admission, permanent CI tests, WFI-030 traceability normalization wording and regression, and shared PowerShell review-hash normalization.
- Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`.
- Base HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807` (latest main at handoff). Initial worktree: clean.
- Risk: high/protected; launch, review admission, identity reservation ordering, guard policy and post-review evidence freeze are affected. This record is not a task-state transition or formal verdict.
- Contracts: existing `review-context-invocation/v2`, canonical ledger/receipt and stage-role input authorization; existing WFI-030 validator normalization; Claude non-TTY exact permissions and ordered proof; evaluator manifest pin and scratch delivery; existing protected-file inventory.
- Implementation exclusions: historical scratch recovery, unrelated T-002 product changes, installer, ledger reconstruction, frozen historical specs/tasks and private session evidence. Formal reservations and Git delivery remain separate authorized gates, not completed work.

## Preflight mismatch matrix

| Persisted field | Sibling contract / counterpart | Negative regression |
|---|---|---|
| Invocation manifest raw SHA-256 | Caller pin and admitted input digest | Wrong/missing pin fails before reservation in quality transport tests |
| Allowed input path/hash | Shared validator, conditional resolver and scratch projection | Missing, alias, symlink and hash-mismatch fixtures fail before reservation |
| Reserved run/session and receipt | Canonical ledger chain and native child proof | Preflight/preview failures leave the ledger unchanged; a mismatched post-append receipt stops launch and retains the consumed record without retry |
| Reviewer output/model/permissions | Role contract and exact Claude argv | Missing alias/flag, wrong model, compound Bash and outside Read fail |
| Task-stage traceability digest | WFI-030 persisted-state checker and AGENTS wording | Unknown/annotated status or Evidence-cell mutation fails |
| PowerShell reviewed hash | Previous PowerShell hash recipe and unchanged stage checks | LF/CRLF, case variants, malformed/empty contents and read failures retain the previous behavior; a digest is not authorization |

## Validation ledger

- Clean checkout focused tests: `quality-nontty-transport` 18/18; `review-conditional-inputs` 16/16; `spec-review-verify-inputs` 2/2; `host-review-preflight` 7/7; `unified-launch-order` 8/8; `unified-task-launch` 9/9; `task-structured-output` 13/13 after `npm ci --prefix mcp/ci-mcp --ignore-scripts --no-audit --no-fund`; `traceability-freeze-contract` 2/2; `review-hash-normalization.tests.ps1` passed.
- Existing review-context-boundary suite: 32 citation anchors and 84 fixture cases passed on Bash and PowerShell. These fixture reservations do not touch the repository's canonical identity ledger.
- Generated guard modules: `generate-guard-invariants.py --check` passed after protecting both direct helper dependencies; `git diff --check` passed.
- Guard parity passed 110/110; review-contract-foundation passed. Downstream review precheck and its Bash/PowerShell parity suite initially stopped on `registry-unregistered-directory` for the concurrently added `specs/shared-review-launch-repair/` directory. After registering only that new full-profile spec in `AGENTS.md` and `specs/workflow-state-registry.json`, both suites passed on rerun.
- First `task-structured-output` run failed 1/13 because the new checkout lacked ignored `mcp/ci-mcp/node_modules/ajv`; after lockfile-based dependency installation, all 13 passed. No source change was made for that environment setup.
- Independent diff review identified overclaims about PowerShell semantic rejection and post-reservation ledger immutability. Requirements, acceptance tests and design were corrected to existing approved behavior without runtime relaxation. This diff review is not a formal verdict.
- Formal specification and implementation-policy reviews passed. Task decomposition attempt 1, round 3 passed with both independent reviewers and zero findings; earlier rounds remain retained. The integrated task-review run is `6f6167e2-bc36-4e9c-8fb1-f70711bdac74`; its contract SHA-256 is `c9fcd187bb33b891191c4f25b555ee74a7102c83e9521453b4895885820ee692`. These are specification/design/plan verdicts, not implementation quality-gate verdicts.
- On 2026-10-08, the eight focused Python suites listed above were rerun: 75 tests passed, zero failed. The PowerShell hash-normalization parity suite and both Bash and PowerShell downstream-precheck suites completed with exit 0. The boundary suite rerun completed with `PASS: 84`, `FAIL: 0`, exit 0. These are local candidate regressions, not native activation, implementation quality-gate verdicts or exact-head CI evidence.
- CI wiring behavioral controls passed (21 cases); required-checks POSIX tests passed (4 methods). These structural checks do not establish clean-runner dependency availability.
- Open CI dependency defect: `tests/task-structured-output.tests.py:177` requires `mcp/ci-mcp/node_modules/ajv`, but its new `posix-regression` invocation has no dependency-install step. The existing installation at `.github/workflows/test.yml:93` belongs to the separate `posix-unwired-sharded` job. Reuse the lockfile-based install in the consuming job before running this suite; verify ordering and the clean-runner execution in T-004. No CI run has yet demonstrated this candidate.
- On 2026-10-08, human approval reflection was independently read back: T-001 through T-005 are `Approval: Approved` / `Status: Planned`; tasks.md SHA-256 is `bfc70a0ecaa14ba6cbad5879665e3acd84a29fa277c5ee45a4d5350b4d4819ea`. Execution order remains T-001 → T-005 → T-002 → T-003 → T-004. No implementation quality gate, exact-head CI, commit, push or merge has completed for this integration checkout. Focused green tests and task-review PASS do not authorize a Done transition.
