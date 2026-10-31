# T-004 fresh launch preparation and input freshness

Date: 2026-10-05
Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`

Preparation only. This is neither a fresh implementation report nor an evaluator
verdict. No formal identity was reserved; no historical report, ledger, task
status, verification contract, panel verdict, or canonical bundle was changed.

## Executed freshness check

The shipped producer was executed without modification, through `rtk proxy`
with `login=false`:

```sh
bash plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh --task T-004 --feature epic-196-a8-integration --input specs/epic-196-a8-integration --out /tmp/a8-t004-input-freshness-20261005.qJvmah/T-004.panelist-input.current.txt
```

Exit 0. Current body digest:
`5dc196bd90bf2a89615baabb8b706ac6db14589424adaf3f458a194f37bf9b6b`.
Whole generated file SHA-256:
`2e873bfd132f447e099fc7549682f09ba6f483388b094ea6a277dea5a2dcb0e5`.
Both saved panel verdicts instead bind body digest
`3dc43bd2241d3e746a9cacdb6de3dcdb331f8d9b507b95c3d294cf1c9cfb181a`.

Section-by-section comparison: old 18, current 37, added 19, changed 0,
removed 0. The 19 additions are the current T-004 contract, ten files in
`T-004/gate-preparation-20261004/`, two files in
`T-004/recovery-fresh-20261004/`, and six files in
`T-004/recovery-validation-20261004/`. Existing specification, implementation,
and original evidence sections are unchanged. This is still a different
admitted input bundle, not current-input proof from the old panel PASSes.

Therefore no current aggregate was generated. Passing the old digest to force
consensus would omit the current admitted evidence. Passing the new digest to
the current aggregate checker would correctly reject both old verdicts; no
need to mutate an aggregate merely to rediscover the known mismatch. No
primary evaluator result exists, and none was supplied as PASS.

## Pinned launch inputs (read back this preparation)

These are concrete starter pins, not a complete authorized evaluator manifest.
The fresh implementer must recheck them and explicitly enumerate any additional
source, guard dependency, baseline, or evidence file it reads or produces.

| Repository-relative path | SHA-256 |
|---|---|
| `AGENTS.md` | `8da12bb2769988d0f5313a74acfffda9a1638ef61a6a8090e7524533ddeb1b73` |
| `specs/epic-196-a8-integration/tasks.md` | `8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66` |
| `specs/epic-196-a8-integration/requirements.md` | `f841443d88b4f58fdbb9e32ee050edf8395f3767ebbc08cc2d9d6be76cb3ac44` |
| `specs/epic-196-a8-integration/design.md` | `14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c` |
| `specs/epic-196-a8-integration/acceptance-tests.md` | `4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1` |
| `specs/epic-196-a8-integration/investigation.md` | `888868de019e903375b3cf8b8d25c89f2abf84b950178e99afb534ab8495a77f` |
| `tests/cli-hook-enforcement.ps1` | `343aa50f12d790619dc5d636831d6f1c7d1559745b9ca289ad67fb28564a3bec` |
| `docs/troubleshooting.md` | `11b27875c049db13f5b15e6fe2d5970ff8e0e5902c26b1d63773a3a077efec65` |
| `reports/implementation/epic-196-a8-integration/T-004.md` | `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f` |
| `reports/implementation/epic-196-a8-integration/T-004.pre-recovery-20261004.md` | `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f` |
| `specs/epic-196-a8-integration/verification/T-004.contract.json` | `1106f19fd784fa89ab5f54d1b5ee032c1684d893e57040716108cacddd25be79` |
| `specs/epic-196-a8-integration/verification/T-004/recovery-validation-20261004/readiness.md` | `eed0eb9cd5020312e45e4122a6a33e12c8543e2eca47b27193bf45d0a5dd8138` |

## Fresh implementation deliverable boundary

The new context must emit a distinct noncanonical report, e.g.
`reports/implementation/epic-196-a8-integration/T-004.recovery-<observed-run>.md`,
and `handoffs/<fresh-directory>/manifest.json`. The historical canonical report
is input, not allowed output. Its archive hash above must remain intact.

`validate-task-input-manifest.sh:53-60` requires exactly these keys:
`schema`, `task_id`, `run_id`, `session_id`, `agent_instance_id`, `model_tier`,
`provider`, `model`, `estimated_cost_per_attempt_usd`, `cost_estimate_source`,
`cost_estimate_timestamp`, `isolation_mode`, `fallback_reason`,
`handoff_reload_evidence_hash`, `allowed_inputs`, `allowed_outputs`.
No `scratch_root` extension is permitted. Real canonical absolute scratch goes
in the report; fresh mode has empty fallback fields. No fabricated identity or
zero-cost placeholder was emitted by this preparation. The current long-lived,
compacted helper context is not a fresh implementation session.

After actual fresh implementation checks, an independent context must compare
old and new reports and all pins before canonical adoption. Rebuild the final
panel bundle only after the report and admitted evidence are stable; then obtain
fresh permitted-vendor verdicts for that digest. An aggregate may omit
`--evaluator` and record `evaluator_verdict: null` when only panel consensus is
being aggregated; this is not independent primary evaluation or Done. Formal
reservation stays with the coordinator and occurs only immediately before the
actual isolated evaluator launch. T-007/T-008 native proof remains separate.

## Handoff

`check-sdd-structure.sh` returned exit 0 / OK during this preparation. Existing
local regression suites were not redundantly rerun. The implementation policy
requires a fresh context after compaction; this note therefore hands off actual
identity-bound implementation/report creation rather than claiming fresh work
from this helper. No protective refusal was encountered or bypassed.
