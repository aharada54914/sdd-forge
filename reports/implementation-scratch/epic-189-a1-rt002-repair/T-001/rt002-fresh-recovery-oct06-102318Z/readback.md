# RT002 recovery prerequisite readback — 2026-10-06T10:23:18Z

Diagnostic only; not an implementation run, canonical report, reservation, or verdict.

Task: approved high-risk epic-189-a1-rt002-repair T-001, currently Implementation Complete. Owner supplied by the parent: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`; supplied HEAD `1e86fb272643e798db4e1ca0c89f0402317a2fc8` (no Git command was run by this diagnostic). Actual diagnostic agent identity: `/root/rt002_fresh_recovery_oct06`. This identity is not substituted into an earlier manifest. No model/cost/run identity is fabricated.

Read the owner AGENTS, task, canonical implementation report, preparation record, host-preparation handoff, implement-task skill and all three required policy references, implement-tasks isolation contract, quality-gate recovery clause, and the authorized recovery-entry contract. The owner structure check exited 0, with exact output:

```text
advisory: CLAUDE.md
host: github
check-sdd-structure: OK
```

## Existing preparation inputs

Retained existing preparation directory `reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/rt002-host-preparation-20261006T070021Z/`; no duplicate snapshot or manifest was created. Its receiver is retired according to its closure record. The manifest is preparation evidence only, not an active task handoff for this agent.

The following commands ran through `rtk proxy`, with login=false and owner cwd:

```text
bash plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/rt002-host-preparation-20261006T070021Z/task-input-manifest.json --snapshot-root reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/rt002-host-preparation-20261006T070021Z/snapshot --expected-task T-001
exit: 0
stdout: TASK_INPUT_OK
stderr: empty

pwsh -NoLogo -NoProfile -File plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1 -Manifest reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/rt002-host-preparation-20261006T070021Z/task-input-manifest.json -SnapshotRoot reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/rt002-host-preparation-20261006T070021Z/snapshot -ExpectedTask T-001
exit: 0
stdout: TASK_INPUT_OK
stderr: empty
```

Read-only Node SHA-256 and file-mode comparison exited 0. Exact output:

```json
{
  "timestamp": "2026-10-06T10:22:55.236Z",
  "manifest_sha256": "ba0fc7b153608bcdb8a7e9461fc2220085f2d2bec6d7089418058aa05b47486a",
  "inputs": 86,
  "source_and_snapshot_mismatches": [],
  "file_modes": {
    "444": 83,
    "555": 3
  },
  "snapshot_directories": 49,
  "recorded_identity": "01a11004-5d73-72f1-9dcb-c3df340e3ddc",
  "actual_diagnostic_agent": "/root/rt002_fresh_recovery_oct06",
  "identity_reused": false
}
```

All 86 source and snapshot byte hashes matched their manifest entries; snapshot file modes matched source modes masked by 0555, and all 49 snapshot directory modes were 0555. These file modes are not runtime output-root enforcement.

## Installed prerequisite and execution boundary

Read-only lstat checks exited 0 and returned these exact observations:

```text
ENOENT /Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/check-hook-activation-handshake.py
ENOENT /Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/check-hook-activation-handshake.sh
```

The standard baseline was intentionally removed according to the parent instruction. Absence is not treated as a defect or permission to reinstall. No installed candidate, fresh native dispatch or HOOK_ACTIVE was observed here.

The current agent's supplied filesystem permission profile is danger-full-access; this does not establish output-root enforcement. No enforcement probe, host allocation, transport, configuration/trust change, installation, or alternate executor was attempted.

`plugins/sdd-implementation/skills/implement-tasks/SKILL.md`, Implementation Loop item 5: “If launch identity, snapshot validation, saved reload evidence, or output-root enforcement cannot be established, fail closed before implementation.”

`reports/verification/hook-recovery-entry-contract-20260909.md`, Recovery entry item 1 admits only the repair-specific review route and explicitly does not admit “task implementation, quality-gate completion”; item 6 requires a NEW challenge, ONE actual native host dispatch, unchanged response and original installed-path HOOK_ACTIVE. T-001's Execution Preconditions likewise require fresh installed-candidate activation before ordinary execution/quality-gate.

Therefore the original feature suites were not rerun. Historical 984 Bash / 985 PowerShell diagnostic assertions remain historical diagnostics, not this context's execution or native/formal success. Canonical implementation report and its existing archive, task status, ledger, source files, frozen inputs and prior evidence remain unchanged. Only this new task-scoped diagnostic record was added.

## Next authorized route and missing prerequisite

Use an explicitly authorized isolated native environment with the exact installed candidate and effective output-only write policy; establish fresh TEST-089 in that same executing session. That is currently unavailable, not assumed impossible. No standard installation or trust promotion is implied by this readback.

Then validate a new actual-identity task manifest against current inputs before the original-path code recheck and complete raw logs. The existing sealed snapshot may supply unchanged input bytes after revalidation, but its retired preparation identity cannot be reused. Follow quality-gate's archive/supersession clause: independent comparison of old/new reports and hashes precedes canonical adoption. Evaluator reservation, quality verdict and Done remain later independent operations.

## Follow-up: existing isolated native route assessment

Parent explicitly requested another bounded read-only check for an existing authorized isolated native host; no repeated suite or sandbox diagnostic was run.

Read the actual `sandbox-output-1h727sb3/diagnostic-result.json`. It confirms a standalone `command/exec` transport with `thread_created: false`, `model_called: false`, server exit 0, inside-write exit 0, sealed-read exit 0, outside-write exit 1 with `Operation not permitted`, and identical sealed SHA before/after. Thus the existing path proves three filesystem cases, not native hook activation or a model turn. The stopped transport is not a live host to reuse, and its outside-write refusal was not retried by another executor.

Current bounded registration checks (each command exit 0 unless noted):

- `rg --files --hidden` over `/Users/jrmag/.codex/plugins` and `/Users/jrmag/.claude/plugins`, filtered for handshake verifier/installed-plugin/marketplace names, returned no handshake verifier path. This is a bounded inventory of those plugin roots, not a claim that all disks or remote hosts were searched.
- Parsed Claude `installed_plugins.json`: `sdd_plugin_keys: []`, `plugin_key_count: 17`.
- Read only marketplace sections of Codex config: openai-bundled, openai-primary-runtime, ponytail; no SDD marketplace. A broad SDD registration-line filter also matched `[projects."/Users/jrmag/Documents/SDD-Plugins"]`; that is a project trust section, not an installed plugin or isolated-host registration.
- Inspected existing `rt002-installed-118-human-20261003.py` and its pinned `apply-installed-verifier-human.py`: the adapter fixes the source and former 1.18.0 production target. `checked()` uses `O_RDONLY | O_NOFOLLOW` on an existing single-link regular target, and main checks the old target before `--check`/application. No isolated destination or create-from-absence option exists. No helper was executed again, rewritten or redirected.
- A search for install/host/sandbox/runtime filenames under owner `scripts/` and `.codex/` returned no matches (exit 1). An initially guessed installer path did not exist; this did not trigger installation or wider source searches.

Conclusion: the existing standalone sandbox mechanism is usable only as the already-recorded filesystem diagnostic. No currently registered isolated installed SDD host was established in the bounded local inventory. Re-running fixtures, generic restoration self-tests, the missing-target check, or the known sandbox canaries would not establish the missing native prerequisite, so none was substituted.

Minimum unblock input: select an already authorized isolated native host with an enabled real SDD hook and supply its exact installation path/version/hash; if none exists, explicit narrowly scoped authority to provision such a host is needed, preserving the standard-installation removal. This is not a request to reapprove T-001, reset its attempts, authorize standard reinstallation, or invent another manifest framework. Once available, read back exact candidate/dispatchers and the retained restoration evidence, verify output-only enforcement for the actual task turn, then make the same-session fresh native TEST-089 dispatch. Formal recovery remains gated on those observed results.
