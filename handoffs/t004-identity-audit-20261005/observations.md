# T-004 recovery input and host-identity audit

Date: 2026-10-05
Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`

Preparation only. This is not an implementation report, task-input manifest,
formal launch receipt, independent evaluator verdict, or task-state transition.

## Read-back checks

Commands used `rtk proxy` with `login=false`.

- `bash scripts/check-sdd-structure.sh`: exit 0, `check-sdd-structure: OK`.
- Recomputed all 12 starter path/hash pairs in
  `reports/verification/a8-t004-fresh-launch-preparation-20261005.md`: 12 MATCH,
  zero mismatch.
- Recomputed all eight after pins in
  `reports/verification/a8-t004-recovery-v2-pins.json`: 8 MATCH, zero mismatch.
- Recomputed all five Outputs pairs in the canonical T-004 implementation
  report: 5 MATCH, zero mismatch.
- `git diff --check`: exit 0, empty output.
- T-004 still reads `Approval: Approved (sudo 2026-08-08T16:33:11Z)` and
  `Status: Implementation Complete`. No status or approval was changed.

Canonical and archived reports remain pinned to
`48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`.
The unchanged recovery source/test pins and existing same-day continuity
record justify avoiding duplicate regression execution in this preparatory
context. Existing test logs are historical observations, not newly executed
tests or a formal independent verdict here.

## Concrete identity limitation

The current runtime exposes `CODEX_THREAD_ID` as
`01a107a5-d4e6-74e1-8e4c-6e2897f6f134`. The parent confirmed that the spawn
response supplied only the task name `/root/a8_fresh_implementation`, with no
model override and no separately returned UUID or cost metadata. The inherited
thread environment therefore does not establish a distinct physical host
session or an observed implementation run identity. A task-path label is not
silently substituted for those fields.

`plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` requires
run/session/agent identity, concrete provider/model/tier, and a decimal cost
estimate with source and UTC timestamp. Missing data was not replaced by
fabricated UUIDs, a guessed concrete model, or a zero-cost placeholder. No
manifest or recovery implementation report was produced.

## Next executable launch boundary

The coordinator must first supply a concrete model route and sourced cost
estimate and obtain a distinct implementation context's actual host receipt.
The existing `a8-codex-appserver-idle-allocation-20261005.md` diagnostic proves
only that an idle `thread/start` can return `thread.id`, status idle and zero
turns; it does not establish the mapping for every required identity field.
Resolve that mapping against the installed contract before using this native
path. Do not reuse the diagnostic thread or invent a second host identity.

Prepare exact input hashes, an immutable snapshot and explicitly named output
paths with the checked-in implementation scripts. The required consumer path is
`handoffs/<new-directory>/manifest.json`; validate the closed schema and snapshot
before implementation work. The native first turn must receive the validated
files and declared outputs only, without the coordinator conversation. Record
the canonical absolute task scratch root in the new report, not as an extra
manifest key. No implementation ledger reservation is permitted.

The fresh context must read the complete required specifications and policies,
recheck the current implementation, execute its required T-004 checks, then
produce a distinct noncanonical recovery report. Independently compare the old
and new reports and hashes before canonical promotion. Only after admitted
evidence stabilizes, rebuild the panel bundle, obtain new permitted-vendor
verdicts for that exact digest, and perform the normal one-role evaluator
precheck/reservation immediately before actual evaluator launch.

The old 18-section panel PASSes remain unusable for the changed 37-section
bundle documented by the prior producer run. No aggregate was generated here.
No protected refusal was encountered or bypassed. No source, historical report,
ledger, reservation, frozen artifact, contract, or task field was edited.

## Native identity diagnostic follow-up (2026-10-05)

This section supersedes any inference above that the native response cannot
supply a session identity. It does not change a frozen report or constitute a
formal launch receipt. The earlier diagnostic filtered out fields that are
present in the full response.

Using the bundled CLI, a new diagnostic process received only `initialize`,
`initialized`, and `thread/start` with the owner cwd and `ephemeral: true`.
No model, sandbox, approval-policy, or other configuration overrides were used.
The safe response projection was:

```json
{"thread_id":"01a107ad-a96d-7730-8350-09bfd435b1a7","session_id":"01a107ad-a96d-7730-8350-09bfd435b1a7","parent_thread_id":null,"status":{"type":"idle"},"model":"gpt-6.1-sol","model_provider":"openai","reasoning_effort":"high","turn_start_sent":false,"reservation_performed":false}
```

The process ended with exit 0. This terminated ephemeral context must not be
reused as a formal implementation or evaluator context. No model turn ran.
An empty `thread.turns` on thread/start is not independent evidence of history;
the controlled request trace records that no turn/start, resume, or fork was sent.

The existing generated schema at
`/tmp/codex-appserver-schema.F7W5fu/v2/ThreadStartResponse.json` defines
`thread.id` as a host-generated UUIDv7 (line 1381), `thread.sessionId` as the
session-tree identifier (line 1475), and model/modelProvider as required response
fields (lines 3075-3080). It supplies no field literally named `run_id` or
`agent_instance_id`; their task-scoped host mapping must be stated explicitly,
not fabricated. The task manifest validator does not require those fields to
have different values inside one record, but forbids fresh identity reuse across
the batch (`validate-task-input-manifest.sh:228-230,303-323`).

Cost is not a native thread/start prerequisite. It is a mandatory SDD manifest
field trio (validator lines 236-241), supplied as a sourced invocation estimate,
not necessarily a host-reported bill (agent-delegation-policy.md:77-78).

## Native model catalog comparison (2026-10-05)

A separate process of the same bundled CLI received only `initialize`,
`initialized`, then `model/list` with `includeHidden: true` and `limit: 100`.
The response contained ten models and no next cursor; the process ended with
exit 0. No thread/start or turn/start was sent in this catalog probe.

Observed model IDs, including hidden entries:

- `gpt-6.1-sol` (default)
- `gpt-6-astra`
- `gpt-6-sol`
- `gpt-6-luna`
- `gpt-reserve` (hidden)
- `gpt-5.6-sol`
- `gpt-5.6-terra`
- `gpt-5.6-luna`
- `gpt-5.5`
- `codex-auto-review` (hidden)

Each catalog entry reported high reasoning support. A catalog entry is not
evidence of a completed model turn or quota/billing success.

The owner's `contracts/agent-model-capabilities.json` registers these OpenAI
routes only: `openai/gpt-5.1-codex-mini`, `openai/gpt-5.1-codex`,
`openai/gpt-5.2-codex`, and `openai/gpt-5.1-codex-max`. Their exact model-name
intersection with the complete native catalog is empty. There is no existing
registered Sol route. Availability of the absent legacy routes was not assumed
or tested by a model turn. Likewise, visible Sol models were not assigned a
canonical tier by guesswork.

Agent Delegation Policy lines 90-95 require registry filtering and same-tier
registered substitutions, otherwise `model-tier-unavailable`. The selector's
candidate-file path resolves model names through that registry
(`select-agent-model.sh:289-315`). Therefore no honest available registered
candidate for this native host was established. No synthetic candidate file,
selector PASS, new model registration, contract change, formal turn, reservation,
or task-state change was made.

The valid native syntax for a later approved registered/available route is
`thread/start` with `params.model` set to that exact native model ID and
`params.modelProvider` set to `openai`; preserve permission settings. This is
only parameter syntax, not evidence that any absent GPT-5 legacy route works.
Next resolution is an authorized registry/model-route decision or verified
availability of a currently registered route on a permitted host, followed by
the sourced estimate and normal selector. The current evidence does not justify
launching the formal implementation with either an unregistered Sol route or an
unobserved legacy route.
