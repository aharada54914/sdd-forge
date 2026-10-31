# Issue #423: staged Registry/resolver paired regression

Date: 2026-10-01
Scope: RT-20260930-001 candidate validation; not a quality-gate verdict.

## Tested bytes

The human staged six targets in the isolated clone. The agent checked their
hashes before and after the tests; all matched the supplied readback.
Clone HEAD: `06bc32cc26f2d67adb02e827610b5230e1658f72`.
The working diff contained only those six targets before and after execution.

| Targets | SHA-256 |
|---|---|
| canonical and vendored capability-registry.json | 42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1 |
| live and A5 human-copy resolve-project-context.py | ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511 |
| generated/gate-capabilities.json | e9db61b7a9eeb28c1c50668e017fd8d570e490684daf68bc5d98f5348b0a31e1 |
| A5 human-copy/MANIFEST.sha256 | cde02121eed5f7d0e9726c77b223bc72ff5e462cbd139bfcdcda45f09178ec5d |

## Agent-executed checks

Environment: macOS, PowerShell 7.6.2. PowerShell on macOS is not native
Windows execution. Every command below exited 0, with process completion
confirmed, rather than inferred from a partial log.

Registry command:
`rtk proxy sh plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry contracts/capability-registry.json`.
Result: all 9 checks passed.

Each driver was executed from the isolated clone using either
`rtk proxy bash tests/<driver>.tests.sh` or
`rtk proxy pwsh -NoLogo -NoProfile -File tests/<driver>.tests.ps1`.

| Driver | Bash | PowerShell |
|---|---|---|
| resolve-project-context-match | 125 passed, 0 failed | 125 passed, 0 failed |
| resolve-project-context-cli | 13 passed, 0 failed | 13 passed, 0 failed |
| resolve-project-context-block | 407 passed, 0 failed | 407 passed, 0 failed |
| resolve-project-context-lite | 18 passed, 0 failed | 18 passed, 0 failed |
| resolve-project-context-parity | 70 passed, 0 failed | 70 passed, 0 failed |
| resolve-project-context-caller-contract | PASS, exit 0 | PASS, exit 0 |

These are 12 successful driver executions: 1,266 counted checks plus two
caller-contract driver successes. Repeated checks are not counted as unique
acceptance criteria. `rtk proxy git diff --check` also exited 0.

### Remaining four suite pairs

The remaining resolver drivers were executed against the same isolated
candidate on 2026-10-01. Each Bash command used the invocation above; each
PowerShell command used `pwsh -NoProfile -NonInteractive -File`. All eight
processes completed with exit 0.

| Driver | Bash | PowerShell |
|---|---|---|
| resolver-evidence-schema | 20 passed, 0 failed | 20 passed, 0 failed |
| resolve-project-context-discovery | 24 passed, 0 failed | 24 passed, 0 failed |
| resolve-project-context-metamorphic | 150 passed, 0 failed | 150 passed, 0 failed |
| validate-resolver-evidence | 138 passed, 0 failed | 138 passed, 0 failed |

Combined: 20 successful driver executions, 1,930 counted assertions and two
caller-contract driver successes. These are not 1,932 unique acceptance
criteria. The supplemental outputs were captured in the tool transcript,
not added to the twelve-file stdout/stderr archive below. Post-test Git
status still lists only the same six candidate targets; all six readback
hashes still match the table above. Native Windows execution remains pending.

### CI admission gap found during verification

An independent read-only audit of main
`49e1602459108fd8ef318b644b51301a3b61d0b1` found the ten dedicated resolver
PowerShell suites registered in `tests/run-all.ps1:70-79`, but no workflow
call to that driver. The POSIX inventory route
(`.github/workflows/test.yml:62-81`, `tests/run-ci-unwired.sh:68-80,120-145`)
executes Bash suites. The Bash parity route invokes the product PowerShell
wrapper (`tests/resolve-project-context-parity.tests.sh:16-19`, its Python
driver at `:126-131`, and `resolve-project-context-block-check.py:1553-1556`),
not the dedicated PowerShell test suites. Existing product parity coverage
therefore does not establish native execution of all ten PowerShell drivers.

The minimal proposed repair is a Windows-only step in the existing matrix,
running those ten drivers and rejecting each nonzero exit. Do not run the
whole PowerShell inventory again or remove any existing job. A5's historical
approved tasks are all Done and must not be silently reopened to adopt this
repair. The old workflow candidate from the #359 worktree would also remove
current required POSIX jobs and is unsuitable for publication.

The existing candidate-specific `registry-migration-cli.tests.py` was rerun
from the owner checkout: 5 methods / 9 subcases passed, exit 0. Its candidate
Registry and Python hashes match the staged bytes, but the driver itself
uses fixture copies; this is not a Windows, CI, or installed-host claim.
It covers affected Full/Lite legacy contexts with both PII values rejecting
before success publication; unrelated and unaffected contexts retain their
existing publication behavior, and malformed input remains rejected.

## Saved command logs

### Custom Registry supplement

After the five-method run above, the candidate CLI driver gained one
explicit custom-Registry case retaining `durable-workflow` and its real
`check-contract` obligation. The updated driver passed all six methods
(ten subcases), exit 0. The added test asserts published capability identity,
blocking stage/check obligations, predicate-selected facets and empty
diagnostics. Its initial failure was an incorrect test expectation for facet
objects, corrected without changing candidate production bytes. A separate
ordinary reviewer reran that one method successfully. This proves resolver
publication, not execution of the selected check or a formal gate verdict.

Independent ordinary code review (Sol, 2026-10-01) found no concrete new
defects in the six-file staged diff. The retired capability's original
`affected_component.artifact_kinds contains durable_workflow` trigger and
the replacement guard use the same affected components; rejection precedes
both Full/Lite processing and publication. The four real gate registrations
agree with their generated projection. This review did not execute tests or
reserve a formal quality-gate identity. Custom Registry execution cases were
not covered by the five candidate methods: a retained `durable-workflow` ID
continues using its custom obligations; absence of that ID activates the
new fail-closed boundary. Formal T-002 evaluation remains pending.

Full stdout/stderr: `/tmp/issue423-paired-regression.DdlUQS/` (local only).

| Log | SHA-256 |
|---|---|
| block-bash.log | 94b491b955c434f070bee5026b2c86cf542a2c129f3a7a49bd8f60096bc5d3f6 |
| block-pwsh.log | 8492a2e4446d79af20c8f890e64513e305b62d44123a91da8939f532ab4711ed |
| match-bash.log | 97cb8b55464e605b8ba19dff886315765900c3ff884890b32528658b7f298291 |
| match-pwsh.log | 2925903fdbdc1742ac06d0263afa18818e417b8a1e236dc6437ebb92e69d01a4 |
| cli-bash.log | e5f536142935d6ec15a1258a22099d1d0647a6fe959da501c8ce7d12f77bc34e |
| cli-pwsh.log | 99d980dc63470cdd24b176b5d35b3518721d8e6a2176ccafdd34edfbcd13453d |
| lite-bash.log | d451353ae3358ffb7b3a0d90605bf2816d4140160b21e5def75b15496506c707 |
| lite-pwsh.log | a049e52deeacf35f31a53d27e5a58e16412724c12341680546ccf04bb999026e |
| parity-bash.log | 45db08bcdd14646eb8ddcbd25a2f4e7f091bdef95d951f5de8ef813ea3c6b06e |
| parity-pwsh.log | 65cb82e6f123b37141009acbc2eb3a6ed6952b7c43daadfcc088c811abe6b203 |
| caller-bash.log | 554cef31ff57534ad765b1e5df45ed39ccf37dd1a91f555c98f5636a2545f89f |
| caller-pwsh.log | 310c3523cd0c6e3c42d73c8c216afb8383b9a5a8896abb4a4bb515dbe439ed89 |

## Not executed / remaining boundaries

The agent attempted:
`rtk proxy python3 plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py --check`.
PreToolUse refused the command before execution, with the deterministic-gate
protected-file diagnostic. There was no process exit code and no agent
generator-check PASS. No alternate route around the refusal was attempted.
The human staging helper includes generation and `--check`; its successful
staging output is human-reported evidence, distinct from these agent checks.

Only the isolated clone contains the six applied targets. Production
application, a fresh isolated T-002 evaluator and complete quality gate,
latest-head cross-platform CI, merge, and post-merge confirmation remain
pending. RT-20260930-001 remains open; no task approval/status, review
verdict, commit, push, merge, or Issue closure was changed by this verification.

## Single human publication step prepared, not executed

### Readback follow-up

After the repeated isolated-clone staging readback, the agent confirmed all
six target digests were unchanged and reran the task-specific checks:
T-001 consumer inventory: 17 tests passed, exit 0; T-002 migration CLI:
six methods / ten subcases passed in 8.510 seconds, exit 0. The latter still
uses candidate fixture copies, not the unmodified owner production files.
The unchanged paired Bash/PowerShell drivers were not redundantly rerun.
These results do not change task status or supply an independent gate verdict.

The existing staging helper now accepts `--owner-worktree`, limited to the
fixed approved worktree and the same six targets. Its current HEAD and all
six baseline hashes were checked and match the isolated clone baseline.
Unrelated dirty files are not publication targets. The generator itself is
pinned to `fba1559b635fedaa30b2e4cf716143e31ccf8f7d7b8bffd21f83fe4fca2b3eaa`
in both worktrees. Backups, generator/check commands and six-file readback
remain part of the existing human-only application path.

Command from the owner checkout:

```sh
rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/human-stage-isolated-clone.py --owner-worktree
```

Required typed confirmation: `APPLY-ISSUE423-OWNER-WORKTREE`.
Preparation checks: AST syntax passed; an unsupported option exited 2 before
any application. Neither the default application nor owner application was
executed by the agent. After human readback, rerun checks against the actual
worktree and complete the independent T-002 gate before starting T-003.

### T-001 ship launch, not a gate verdict

On 2026-10-01, `check-sdd-structure.sh` and
`check-quality-gate-cycle-limit.sh T-001 sdd-domain-multitarget` exited 0.
The next read-only command, `check-hook-activation-handshake.py --help`,
was refused by PreToolUse before execution with the protected-file
diagnostic; no handshake process ran and no `HOOK_ACTIVE` was established.
The advisory MCP selector returned `auto-select-multiple-active`; the
explicit T-001 target remains unambiguous, but advisory selection does not
override the missing launch condition. No evaluator, gate verdict or Done
transition was created. The existing protected-host repair remains the
dependency; these passing local checks do not satisfy that dependency.

## Additional registry and mirror checks, 2026-10-01

Against the same isolated clone, seven additional drivers completed with
exit 0: capability-registry-schema (Bash and macOS PowerShell: each 6 accept
and 16 reject fixtures), capability-registry-parity (each 22 passed / 0
failed), validate-capability-registry (each 27 passed / 0 failed), and
human-copy-mirror-freshness (6 passed / 0 failed / 17 pending informational).
The pending mirrors are older unapplied candidates, not newly applied bytes.

After these runs, all six target SHA-256 values still matched the human
staging receipt, git diff --check exited 0, and git status contained exactly
the six intended target modifications. No extra production file changed.
These fixture and macOS checks are not native Windows or live activation
proof. Owner application, independent quality verification, CI and merge
remain pending; task statuses and historical verdicts remain unchanged.
