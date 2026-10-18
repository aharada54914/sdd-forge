# T-011 routing guard repair preflight

Run ID: 01a15001-1554-7b30-a10d-2104952bfd18
Task Attempt Count: 2

Scope: RT-20261018-CLOUD-ROUTING-GUARD, REQ-011/012. Hypothesis: the five
publicly referenced paths are missing from `protected_gate_suffixes`; generated
consumers therefore allow writes. No missing-component test or prior candidate
work is counted as Red. The original caller's 261 PASS / 1 FAIL and canonical
report remain read-only; no evaluator was launched.

| Persisted field / claim | Counterpart | Executed failing mismatch / control |
|---|---|---|
| Five exact `protected_gate_suffixes` members | WFI-037 public call-chain scan | `red-guard-parity.log`: existing scanner identifies exactly the five omissions. |
| Generated Python/JS/PS/shell source digest and path inventories | Canonical guard JSON and generator | Same Red executes Python/Node, real Bash dispatcher (shell module), and PowerShell module: write, redirect, Set-Content and invocation-output overwrite incorrectly return 0 instead of 2. Existing `--check` / parity drift assertion binds all four modules. |
| Guard exit 2 for protected mutations; exit 0 for reads/script inputs | Actual payload operation and REQ-011 reachability | Red includes passing read/cat/Get-Content and bare/resolved-environment/documented-variable invocation controls paired with failing mutation cases for the same paths. |
| Run/session/instance, task attempt, manifest input paths/hashes | Caller identity and task-input-manifest/v1; preserved initial scratch files | `red-manifest-mismatch.log`: substituting the first input hash yields `TASK_INPUT_HASH`, exit 1; canonical manifest validates. Identity is caller supplied, not a generated fixture or inherited environment. Report validator will check canonical declarations. |
| spec_revision, preservation, Outputs path/hash claims | Raw eight-file revision and captured entry files | Entry SHA records bind the frozen report, original failure, native acceptance/source bindings, five protected sources and mirrors; preservation checker will compare exact bytes. Deliberate input-hash mismatch above proves hash disagreement is rejected. |
| Red/Green and rollback exit claims | Actual process returns / captured entry and reapplied modules | Red mismatch assertions fail on existing running guards; disposable rollback must reproduce those failures with read controls intact, and reapply must restore Green. Logs preserve actual commands/exits, not a quality verdict. |

No new cloud artifact/verdict schema, provider implementation or public skill
behavior is introduced. No status/approval/traceability write. Pending mirrors
are not editable historical evidence. Only the checker-classified stale applied
parity-test mirror and its existing manifest may be refreshed.
