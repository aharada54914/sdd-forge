# RT002 snapshot mode v4: original-path post-application observation

Observed 2026-10-06, execution environment timestamp 06:34:35 UTC. Supplemental verification only, not a formal gate verdict or implementation identity.

## Scope and owner

- Owner: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`.
- HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`.
- Scope: user-applied four-file v4 repair; readback and original-path regression only. High-risk/protected snapshot enforcement, connected to existing `RT-20260821-011.yml` scope extension (line 46), supporting RT002 T-001 revalidation. No new implementation, identity, reservation, approval or lifecycle transition.
- Existing dirty tree: 17 tracked modified paths plus existing untracked RT002 records. These include the four applied files, workflow, AGENTS, ticket, review-context validators/contracts/tests, registry and run-all. No cleanup or unrelated edit performed.
- Governing reads: owner AGENTS, `sdd-verification-apply`, `evidence-v4.md`, current task/ticket, prior preparation handoff. Skill required separating user-reported application from observed readback and runtime regression.
- Contracts retained: task-input-manifest/v1, immutable snapshot publication, source-change rejection, nofollow checks. Manifest v1 binds content/path, not executable mode; this limitation remains.

## Four-original hash readback

Application was reported by the user through the parent; the agent did not execute the human-only batch. Direct SHA-256 readback before and after both suites matches every supplied v4 expected value:

| Original | SHA-256 |
|---|---|
| `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh` | `83302522785440208bc235ab6ad54ac679632c15a0f0e1edf8b4d59502e26b6b` |
| `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1` | `fbbde93b2d90d2cbdae5dac65121a361df30fef07eefb6e0ec8a5ac7a9cd7b75` |
| `tests/task-context-isolation.tests.sh` | `3f4c0daa832c41db0c2b9899073508616f910a867dbf6673f43afc0cb15a04b5` |
| `tests/task-context-isolation.tests.ps1` | `ef3954581c1578914943e43cc3f73fd2bfd9e50ccd0d1f0355c632b25da8a1ae` |

Canonical T-001 report remains SHA-256 `f3c151a105a1d0b1d0c90fb050f63a8b81005596d9484d95e158cb0490067533`. Prior manifest remains `f1707552c74d70ea2b2b247872f8a1e53499ec40495adf36ff9371bde5355e18`. Existing sealed snapshot was not changed or reused for execution.

## Original-path execution

Both commands ran with owner cwd and `login=false`, on Darwin 27.0.0 arm64, GNU Bash 5.3.9 and PowerShell 7.6.2. Neither command uses a candidate-path substitution. Both tool sessions completed; no running job remains from these commands.

```text
$ rtk proxy bash tests/task-context-isolation.tests.sh
ok: task context isolation manifests, snapshots, fallback, and selector are deterministic
exit: 0

$ rtk proxy pwsh -NoProfile -File tests/task-context-isolation.tests.ps1
ok: PowerShell task context isolation manifests, snapshots, fallback, and selector are deterministic
exit: 0
```

No SKIP output was emitted. Unix branches apply on this host: six execute-mask cases including nonexecutable and special-bit sources; actual direct executable invocation; rejection of a nonexecutable direct invocation; mode-only source-race rejection with no published/leaked snapshot; existing readonly/content-change/collision and manifest/selector checks. Source locations: Bash suite lines 113–191 and 199 onward; PowerShell suite lines 88–182. Bash release-following child wait is bounded at lines 163–176; PowerShell uses WaitForExit(15000) at line 156. Historical stopped-child injection remains evidence-v4.md, not rerun here.

This is fresh execution of the applied original scripts against disposable fixtures. It is not fresh RT002 implementation-snapshot execution, installed native activation, Windows execution, CI or formal independent quality verification. Native Windows and Linux were not exercised in this observation. No original protected code, task status, registry, ledger or Git state was written by this work.

## Next legitimate snapshot entry (not executed)

`plugins/sdd-implementation/skills/implement-tasks/SKILL.md:129–145` requires current hash-bound inputs, new task/run identity, immutable snapshot preparation and validation, then a genuinely fresh agent receiving only declared inputs. This resumed context is not that fresh implementation context. The existing sealed 0444 snapshot must remain historical; do not chmod/reseal it or reuse its identity claim.

After current input inventory, routing/identity and declared output roots have been established through the existing workflow, use a NEW manifest and previously nonexistent snapshot destination:

```sh
rtk proxy bash plugins/sdd-implementation/scripts/prepare-task-snapshot.sh --manifest NEW_MANIFEST --repo-root OWNER --snapshot-root NEW_SNAPSHOT
rtk proxy bash plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest NEW_MANIFEST --snapshot-root NEW_SNAPSHOT --expected-task T-001
```

These are parameterized entry commands, not fabricated identities or ready-to-run evidence. The builder consumes a prepared manifest; it does not generate one. Re-audit source hashes and source executable modes, including any newly changed input, and verify structural completeness before the RT002 original handshake suites. Keep the prior 79-input preparation and its 77-input inventory as historical evidence rather than silently updating them. Perform the required batch validation before formal launch where applicable. No reservation/launch was attempted here.

The older USD 10.00 entry is a provisional planning estimate, not usage, billed cost, vendor pricing or new spending authorization. No new estimate or implementation identity is asserted here. Remaining formal approval/dependency conditions in the existing ticket and RT002 tasks are unchanged; local regression success does not close them or make T-001 Done.
