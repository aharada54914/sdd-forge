# T-002 ordinary role-read recheck

Status: launch blocked; no evaluator reservation or verdict.

After the reported six-target human guard update, the coordinator retried the
original read in the owner checkout on 2026-10-06:

```sh
rtk proxy rg -n 'gpt-6.1-sol|gpt-5.6-sol|gpt-6-sol|gpt-6-luna|sdd-evaluator' contracts/agent-model-capabilities.v2.json .codex/agents/sdd-evaluator.toml
```

PreToolUse again rejected it as an agent-role write without
`developer_instructions`. The command did not execute. No alternate executor or
rewritten read was tried.

Separate ordinary source inspection found the installed 1.18.0 Python guard has
SHA-256 `248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227`,
matching the human application's reported installed Python hash. The 1.17.0
Python guard path no longer exists. This file observation is not proof of which
guard the host executed.

In that installed source, `_role_proxy_rg_read_only` lines 1733-1734 requires
both `--no-config` and `-n`. The original command lacks `--no-config`, so it does
not satisfy this sanctioned read grammar. This explains a source-level rejection
without assuming the installed update was absent. The explicit no-config
constraint must be preserved when reconciling the review launch contract; do not
remove a safety condition merely to admit the old command.

Next: reconcile the approved launch procedure with the installed reader contract,
then verify the normal admitted path under the project's protected-repair rules.
Until that is established, do not reserve the evaluator or count the 74 passing
regressions as formal evaluation or live activation.

## Sanctioned reader verification

The human-applied guard repair's source procedure explicitly defines the
`rtk proxy rg --no-config -n` grammar (primary repository,
`reports/verification/guard-read-candidate-20261003/README.md`, exact integration
delta). The caller must disable external rg configuration; no guard change or
alternate executor is needed. After checking that procedure, the same search
with `--no-config` ran through the normal tool path and exited 0:

```text
contracts/agent-model-capabilities.v2.json:152:    "sdd-evaluator": {
.codex/agents/sdd-evaluator.toml:3:name = "sdd-evaluator"
```

This resolves the caller's read-admission mismatch only. It does not establish
evaluator activation, a review verdict, or task completion. The earlier rejected
command and its evidence remain unchanged.
