# Issue 423 T-002 distribution and evaluator readiness — 2026-10-04

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`

This is preparation evidence, not independent quality verification, CI, a host activation result, or a Done decision. Existing dirty changes, reports, reservations, and historical logs were preserved. No evaluator was launched or reserved.

## Checks executed

All commands used `rtk proxy`, owner cwd, and `login=false`.

| Command after `rtk proxy` | Exit | Observed result |
|---|---:|---|
| `bash scripts/check-sdd-structure.sh` | 0 | `check-sdd-structure: OK` |
| `python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -q` | 0 | 28 tests, OK |
| `bash tests/registry-discovery.tests.sh` | 0 | 21 passed, 0 failed |
| `bash plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh T-002 sdd-domain-multitarget` | 0 | `continue` |
| `bash plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry contracts/capability-registry.json` | 0 | All 9 checks passed |
| `bash plugins/sdd-quality-loop/scripts/check-risk.sh specs/sdd-domain-multitarget/tasks.md T-002` | 0 | Risk check passed |
| `bash -n reports/verification/issue423-t002-build-human-run.sh` | 0 | Syntax check passed |
| `git diff --check` | 0 | No whitespace errors |
| `uvx --from ruff==0.13.3 ruff check plugins/sdd-quality-loop/scripts/validate-capability-registry.py plugins/sdd-quality-loop/scripts/registry_discovery.py` | 0 | All checks passed |
| `uvx --from mypy==1.18.2 mypy --strict plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | 0 | No issues found in 1 source file |

Readback of all 21 path/hash rows in `reports/quality-gate/issue423-t002-post-fix-declaration-20261003.md` matched current bytes. Six of seven canonical implementation-report Outputs matched; its historical validator hash `68fd8421489cd549d8dcf51c48236a4dde9bc1d057f941d4fa3ecd9f93753b72` differs from current `4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788`, which is explicitly admitted by the post-fix declaration. The historical report was not edited.

## Identity and source pins

| Path | SHA-256 |
|---|---|
| `install.sh` | `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50` |
| `reports/verification/issue423-t002-build-human-run.sh` | `d1c2ede3c719ea144190f5baa2d45bc3afd5436abbf4cd7e5bb4e5bb3c895642` |
| `reports/implementation/sdd-domain-multitarget/T-002.md` | `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4` |
| `handoffs/issue423-t002-recovery-20261003/manifest-archive-input.json` | `7c6fef1602a1fa5608b7b78a4dd6a57d1838ffcc1f1ff8e58a98a79d51d70163` |
| `reports/quality-gate/issue423-t002-post-fix-declaration-20261003.md` | `c42eb9c13c3d0d7d0943aa2bb333f0b3702808ab8a7614a7d800561935184de8` |

## Remaining admission repair

1. The distribution runner still states `Human-run ... Do not run as an agent.` Its actual assembly operation was not executed in this check. This is a preserved human-only boundary, not a new tool refusal. No alternative executor or copied runner was used. The prior PreToolUse refusal remains in `qg-prep-20261003/python-toolchain-evidence.md`.
2. Run the authorized normal FilesOnly distribution verification against installer `87bcebf...` and retain a new log separately. The existing `current-build-and-checks.md` and contract `build=true` cite an assembly using installer `9b43d5...`; they must not be represented as verification of the new installer. FilesOnly does not prove host registration.
3. Record the new observed build result in a new non-frozen evidence note. If provided to an evaluator, admit that note by an exact path/hash row in a new post-fix declaration. Preserve the prior declaration and its point-in-time hashes; copy still-required authorized rows into the new declaration rather than treating broad directory membership as authority.
4. Prepare a new T-002 one-role `review-context-invocation/v2`, not a reused T-001 invocation. Include exactly one canonical T-002 report, its implementation manifest, required specifications/calibration, and only exact Outputs/new Post-Fix Artifacts pairs. Bind the new declaration hash. Allocate a distinct actual evaluator session/run and unused absolute scratch root; use the current canonical ledger hash and chain tip immediately before atomic reservation.
5. Enter through `ship` for `specs/sdd-domain-multitarget/tasks.md#T-002`, perform its current-session handshake and track resolution, and only launch the fresh evaluator after deterministic `REVIEW_CONTEXT_OK`. A cycle-limit `continue` and local green tests are not evaluator admission or a verdict.

Task state remains `Approval: Approved`, `Status: Implementation Complete`, `Risk: medium`. Formal QG, CI, native Windows, merge and post-merge verification remain unperformed by this check.

## Human-only next command

The coordinator confirmed that the runner's human-only boundary remains in force. Run the existing pinned file manually; no source edit or extra approval mutation is needed:

```sh
rtk proxy bash /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge/reports/verification/issue423-t002-build-human-run.sh
```

The script internally selects the owner cwd, validates all three source pins, creates a new isolated temporary install tree and a new owner-side log, runs FilesOnly assembly with registration disabled, compares validator/helper bytes, and executes the installed validator. It retains the log and temporary tree and prints their paths. Capture its complete output and exit status; do not substitute the old successful log. Current source pins were verified above, but any intervening source change must cause a fresh review of a mismatch rather than an automatic pin rewrite.
