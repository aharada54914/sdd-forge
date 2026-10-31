# T-003 implementation attempt 4

Task ID: T-003
Feature: sdd-domain-multitarget
Run ID: t003-20261004-c43e18b9f2a7
Task Attempt Count: 4
Outcome: Blocked before RED and implementation

## Scope and handoff

Owner checkout: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
Sole admitted source snapshot: `specs/sdd-domain-multitarget/verification/T-003/snapshot-c43e18b9f2a7/`.
Admission manifest: `specs/sdd-domain-multitarget/verification/T-003/task-input-manifest-c43e18b9f2a7.json`; caller reported TASK_INPUT_OK.
The immutable task input has Approval Approved and historical Status Blocked. Caller authorized this fresh implementation and separately owns live status transitions. No task/status/ledger edits were performed here.

The implement-task skill and required implementation-policy, craft-policy, and delegation-policy references were read from the snapshot. AGENTS, target requirements/design/tasks/acceptance/traceability, all four layer specifications, ADR-0016/0017/0018, selected-plan schema, facet-manifest schema, handoff baseline, and design-boundary addendum were read there. Required Registry, verification-contract, and existing checker readings remain incomplete because the read command was refused. No alternate executor/read route was used for that target.

## Verification

- Structure precheck: PASS, exit 0; raw output `specs/sdd-domain-multitarget/verification/T-003/run-c43e18b9f2a7/precheck.txt`.
- QG consumer output baseline: independently verified SHA-256 `d0326f3617f0bf6de6ba7f99d7edc2388c79a6731866328133cff7bb1815b722`, matching admitted addendum. Consumer content was not edited.
- Sequencing deviation: requirements/tasks were included in a read before the structure precheck; the precheck subsequently passed. No implementation started before it.
- RED: NOT RUN. GREEN: NOT RUN. Task tests and related regressions: NOT RUN.
- Independent review: NOT RUN. No independent reviewer PASS, Implementation Complete, or Done claim.
- UI verification: not applicable; target task does not change rendered UI.

## High-risk preflight — incomplete, implementation must not start

These proposed mismatch tests follow the admitted selected-verification-plan/v1 schema and addendum. None was authored or executed. This table is a pending plan, not completed preflight evidence; legacy-required counterpart enumeration must first be checked against the admitted existing checker and verification-contract template.

| Persisted field | Counterpart | Required failing mismatch test |
|---|---|---|
| schema | selected-plan schema constant | reject unversioned or different schema |
| feature, task_id | Facet Manifest feature; current verification contract task identity | reject wrong feature or task |
| bindings.facet_manifest_sha256 | exact active Facet Manifest bytes | reject changed/missing manifest |
| bindings.registry_sha256 | exact canonical Registry bytes and manifest Registry binding | reject digest mismatch |
| bindings.verification_contract_sha256 | exact current verification-contract bytes | reject stale contract digest |
| checks[].id, sources | matched Capability gate IDs joined to canonical Registry; legacy-required check set | reject duplicate/dangling/omitted/misattributed ID |
| checks[].stage | canonical Registry stage; ADR-0017 implementation boundary | reject artifact/promotion entry |
| checks[].obligation, blocking | Registry blocking flag merged with unchanged legacy required flag | reject weakening a required check, invented conditional obligation |
| checks[].applicability, reason | v1 legacy-optional-not-selected eligibility; no legacy-required waiver | reject required N/A, selected blocking N/A, missing/wrong reason |
| checks[].result | inspected verification-contract observation and existing evidence/path policy | reject asserted success with absent evidence; distinguish unavailable/not-run/unknown/failed |
| checks[].evidence_path | existing path policy and actual referenced evidence | reject absent, escaping, or ambiguous evidence |
| verdict | all required outcomes plus unchanged check-contract execution | reject PASS on required non-pass, legacy checker failure, or empty plan |
| QG plan digest citation and decision | exact evaluated no-replace plan bytes and both consumers | reject missing invocation/digest mismatch/failed selected plan as PASS |
| AC-003/004/013 claims | TEST-003a–e, TEST-004, TEST-013; frozen traceability row | withhold coverage claim until concrete fixtures and test evidence exist |

## Actual blocker

The read-only `rtk proxy python3 -c` command naming snapshot `check-contract.py` alongside Registry/schema/template was rejected by PreToolUse. No shell command ran and there is no stdout/stderr from the requested read. Exact tool denial is preserved at `specs/sdd-domain-multitarget/verification/T-003/run-c43e18b9f2a7/protection-refusal.txt`.

Exact rejected command string (the shell never parsed it into executed argv):

```text
rtk proxy python3 -c 'from pathlib import Path; s=Path("specs/sdd-domain-multitarget/verification/T-003/snapshot-c43e18b9f2a7"); ps=["contracts/capability-registry.schema.json","contracts/capability-registry.json","plugins/sdd-quality-loop/templates/verification-contract.template.json","plugins/sdd-quality-loop/scripts/check-contract.py"]; [(print("\nFILE "+p+"\n"),print((s/p).read_text())) for p in ps]' 
```

Intended admitted input paths (each relative to the sole immutable snapshot):

- `contracts/capability-registry.schema.json`
- `contracts/capability-registry.json`
- `plugins/sdd-quality-loop/templates/verification-contract.template.json`
- `plugins/sdd-quality-loop/scripts/check-contract.py`

Exact hook diagnostic:

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo..
```

The refusal states: “SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。” The English message likewise prohibits modification of deterministic gate scripts, hooks, or critical tests. The actual command only attempted reading admitted immutable inputs, but the refusal was respected without rerouting. This is an actual hook refusal, not a guessed protection rule or an independent test failure.

## Changes and remaining work

Only this report and two raw evidence files were added under allowed outputs. Evaluator, tests/fixtures, QG skill, Foundation resolver, check-contract.py, frozen sources, immutable snapshot, ledger, and unrelated dirty files were not changed. No commit/push/PR/review was invoked.

Resume requires caller resolution of the protected required-input reading boundary; do not bypass the refusal through another executor. After authorized access is concretely restored, finish required contract readings and complete the field/counterpart/failing-test preflight, capture RED, implement the companion evaluator/semantic validator and mandatory QG consumer, then capture GREEN and matching disposable-stage regressions. Independent QG remains a separate caller-controlled step.
