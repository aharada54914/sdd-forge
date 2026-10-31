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

## 2026-10-11 continuation (earlier observations retained)

- The canonical task plan now records T-001, T-005, T-002 and T-003 as Approved/Done, and T-004 as Approved/In Progress. This entry does not change task states or review verdicts.
- T-004 added the lockfile-based Ajv installation to the consuming POSIX job. Its implementation report records the missing-dependency reproduction, registration mutation checks and local validation. The earlier open dependency observation above is historical; clean-runner success for the complete integration candidate remains unproved.
- History-preserving disposable fixtures completed the full POSIX and PowerShell regression drivers with exit 0 (`All POSIX regression tests passed` and `All PowerShell regression tests passed`). Logs: `/tmp/shared-launch-history.BDfwRH/full-posix-corrected.log` and `/tmp/shared-launch-pwsh.nSz20U/full-pwsh-corrected.log`. Those runs predate the dependency update below and are not exact-current-head or native Windows proof.
- Production dependency repair is isolated in PR #547, head `762c28a728531131a3319ab434da01650303ca40`. Local MCP suites passed 471 tests, production audits found zero vulnerabilities, and bundles were rebuilt reproducibly; details are in `shared-launch-dependency-audit-repair.md`. All three MCP suites and CLI-hook enforcement passed CI on Windows, macOS and Ubuntu. Other CI jobs remain running; neither this PR nor the integration is declared merged.
- Remaining delivery gates: complete final-head CI and post-merge confirmation for the dependency repair; T-004 independent quality evaluation; an exact committed integration candidate with applicable CI, safe merge and post-merge checks. Existing aggregate fixture successes do not substitute for these gates.

### Dependency repair completion and current-candidate recheck

- PR #547 merged as `0b2951b6855bbd136938fafa901ee8af8bbe4855`. Its exact merge-head CI run `38084602992` completed successfully (https://github.com/aharada54914/sdd-forge/actions/runs/38084602992). This supersedes only the dependency PR's pending status above, not the shared-launch integration gates.
- The disposable history-preserving fixture incorporated that main commit and the already-reviewed frozen-snapshot cleanup. Its local validation commit is `a2379c76`; the full POSIX recheck log is `/tmp/shared-launch-current-posix.kDuqa6`. This is a validation-only snapshot, not a publishable integration branch or a completed test result.
- The owner-checkout full PowerShell run is still in progress, with log `/tmp/sdd-full-pwsh.HHR3gH`. T-004 formal quality evaluation, final integration CI and merge remain unverified.
- That owner run reports failures in the facet-manifest and resolver parity suites because they require the live workflow to match its committed bytes. Both assertions remain intact. Rerunning both suites in the committed candidate fixture passed: facet-manifest 329/329 and resolver 70/70, both exit 0 (`/tmp/shared-launch-committed-pwsh-parity.Qsq1WE`). This resolves those two checkout-context failures only; it does not turn the owner run or pending CI into a PASS.
- The owner full PowerShell run subsequently completed with exit 1: five suites failed on dirty-checkout assertions (facet-manifest parity, resolver parity, A8 process integrity, capability-registry parity and component-path-ownership parity). The A8 assertion detected the already-merged dependency version changes against the older owner HEAD. No assertion was removed or relaxed.
- All five affected suites passed in the committed fixture. In addition to the two results above, A8 process integrity, capability-registry parity (22 checks) and component-path-ownership parity (25 checks) completed with exit 0; log `/tmp/shared-launch-remaining-parity.g6okhI`. These targeted reruns resolve the observed failures, but are not a new full-driver PASS or native Windows CI proof. Full POSIX completion, T-004 formal evaluation and integration delivery gates remain pending.

### Current candidate full-driver verification

- The full POSIX driver completed with exit 0 and `All POSIX regression tests passed.` in the committed disposable fixture `a2379c76`; complete log: `/tmp/shared-launch-current-posix.kDuqa6`. This supersedes the POSIX pending result above only.
- The same fixture's full PowerShell driver is running; its log is `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/tmpJBg4ym.tmp`. No full-driver success is claimed before process completion. macOS PowerShell execution does not establish native Windows behavior.
- Formal T-004 evaluation, publishable integration assembly, exact-head mandatory CI, merge and post-merge verification remain pending. Private fixture history and raw review/session evidence must not be published as integration commits.

### PowerShell full-driver completion

- The same committed disposable fixture `a2379c76` completed its full PowerShell driver with exit 0 and `All PowerShell regression tests passed.`; log: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/tmpJBg4ym.tmp`. This supersedes the running status above. Both full drivers now pass for this validation snapshot; native Windows and the final public commit still require CI.
