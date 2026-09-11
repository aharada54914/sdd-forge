# RT-20260909-001: approval and formal-entry blocker

## Authorization and completed work

The human explicitly approved preserving every existing mandatory dependency
and check, additionally requiring full POSIX inventory success, specification
amendment, implementation, regression tests and formal re-review. The ticket
records that decision and remains open. Approval need not be requested again.

Recovery checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`.
The requirements document now has a dated supersession note and revised
AC-017; its Spec-Review-Status is Pending. This is an incomplete amendment,
not a passed specification. Sibling design, acceptance, infrastructure,
security, task and traceability propagation has not yet been applied.
Historical verdicts were not changed. Workflow and test implementation did
not begin. Preserve all pre-existing dirty recovery changes.

## Actual checks

- Structural precheck: exit 0, `check-sdd-structure: OK`.
- MCP advisory: multiple active features; explicit RT001 target takes
  precedence over auto-selection. This was not the blocking check.
- Actual canary apply_patch call: denied by the host's PreToolUse hook.
- Raw response recorded in `rt001-hook-response-20260909.json`.
- Original handshake verifier: exit 65, `CAPABILITY_RUNTIME_UNAVAILABLE`,
  reason `PLUGIN_HOOKS_DISABLED`.

The last category is the verifier's label, NOT a proven statement that hooks
are disabled: the actual host denied the call. The response lacks the two
boolean fields the verifier requires (`plugin_hooks_enabled` and
`denied_by_plugin_hooks`), so their values were not fabricated. This is a
host-result/verification-contract evidence mismatch.

## Stop rule and next action

Installed `sdd-bootstrap/1.17.0/skills/bootstrap/SKILL.md`, Routing, handshake
step 4: "Any other outcome — stop with CAPABILITY_RUNTIME_UNAVAILABLE;
never fall back to legacy behaviour silently." No formal reviewers launched,
no new PASS/Done claim, no commit/push/merge or issue closure.

Resume formal entry only with genuine host evidence satisfying that contract,
or a separately authorized and reviewed repair of the evidence-capture
contract. Repeating approval for the POSIX amendment does not supply those
missing observations. Do not disable hooks, manufacture booleans, or invoke
review prechecks directly to evade the required entry handshake.

Once entry is restored: complete BL-001/REQ-004/AC-017/TEST-017/needs sibling
sweep; formally rebind specification, design and task provenance; record
high-risk persisted-field mismatch preflight; reproduce dependency and
result-check omissions; implement the smallest protected workflow amendment
through the authorized application path; add actual-aggregator result and
independent deletion-mutation regressions; preserve all existing dependencies,
commands, pins, timeouts and platforms; synchronize candidates and manifests
without overwriting unrelated staged changes; execute scoped tests, complete
POSIX inventory, native mandatory CI and independent quality verification.
