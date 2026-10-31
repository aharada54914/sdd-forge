# T-001 deterministic quality-gate preparation

Preparation only: no formal quality-gate verdict, reviewer reservation, Done change, or production CI claim.

- Inventory fixture: 17 tests passed. The same suite supplies unit negative-case and TEST-001a–i acceptance evidence; these are not two independent executions.
- Scratch isolation: PASS 58 / FAIL 0, Bash and PowerShell.
- Review context boundary: 32 citation anchors; TEST-RCB-001–010 in both runtimes; regular 116/0, hardlink 84/0, symlink 84/0. Raw JSON records include negative-reservation ledger_unchanged assertions.
- Risk, scoped placeholder, six-task state and workflow-state checks: exit 0. Workflow log retains growth-only amendment warnings.
- Component coverage: PreToolUse refusal, unexecuted, no exit code. The contract intentionally remains false for this required invocation. ProjectContext absence is not substituted for an actual component verdict.
- Contract checker: exit 1, sole finding is required check-component-coverage passes=false. This is expected Default-FAIL behavior, not QG PASS.

Applicability: stack spec is scoped to the JSON inventory and its Python verification fixture. No production application compiler/linter/typechecker is declared for these outputs; the contract records explicit lint/typecheck/build waivers. Repository MCP application toolchains are not asserted absent. Tests remain mandatory and actually executed. The eventual gate report must preserve these waiver reasons and the independent evaluator may challenge applicability.

Evidence files are repository-relative. executions.json records measured commands/times/exits. Capture timestamps for long sessions are observation-completion times, not precise process-exit timestamps. Raw logs are complete, untruncated captured stdout/stderr streams. Historical reports, adopted implementation manifest, five human-applied files and owner identity ledger were not edited by this preparation.

