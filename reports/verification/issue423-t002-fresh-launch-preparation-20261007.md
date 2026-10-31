# T-002 fresh evaluator launch preparation

Non-frozen preparation record. No formal reservation, evaluator launch, verdict,
task-state change, commit, installation or global permission change was made.

## Scope and current inputs

- Owner: `issue423-approved-recovery/sdd-forge`; HEAD
  `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Existing dirty implementation, contracts, reports and ledger were retained.
  This record is preparation for the high-risk existing T-002, not a new approval.
- `issue423-t002-evaluator-input-candidate-20261006-dependency-closure.json`
  remains a preparation-only candidate, not an invocation. Its 93 unique input
  hashes, implementation binding and declaration (95 checks) matched when checked
  during this preparation. Recheck immediately before launch; matching hashes do
  not independently prove executable dependency closure.
- Binding: `handoffs/issue423-t002-recovery-20261003/manifest-archive-input.json`,
  SHA-256 `7c6fef1602a1fa5608b7b78a4dd6a57d1838ffcc1f1ff8e58a98a79d51d70163`.
- Declaration: `issue423-t002-post-provider-key-declaration-20261006.md`,
  SHA-256 `cc70770f49d39bb87f78b79aae92887cbe26d94d4da3d426b0b4f1012cf524c3`.
  It is caller preparation authority, not automatically an evaluator input.
- Existing ledger sequence 1200 is not reusable. No fresh identities have been
  obtained and therefore no fresh formal invocation has been fabricated.

## CLI and effective permissions

Local executable help was queried without launching a model:
`/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`, version
`0.160.0`. The old app resource path ending simply in `/codex` is absent.
`exec --help` supports `--sandbox read-only`, `-C`, `--json`; global help supports
`--no-daemon` and `-a never`. There is no `exec --agent` option. A CLI root is not
the required shipped-role evaluator child.

Proposed caller command shape, NOT EXECUTED:

```text
rtk proxy <verified-codex-binary> --no-daemon -a never exec --sandbox read-only -C <owner> --json <caller-prompt>
```

`issue423-t002-sandbox-scratch-diagnosis-20261006.md` records an actual earlier
caller narrowed through `exec resume -c 'sandbox_mode="read-only"'`: persisted
turn context was read-only/approval-never, and a shell temporary-file write was
denied. This proves that caller only. The old child remained recorded as
danger-full-access and was not resumed. Other historical native-identity records
also show danger-full-access for both caller and evaluator despite the role's
read-only declaration. The cause of that discrepancy is not established.

Read-only limits writes, not reads to the admitted manifest. The role's input
allowlist is an instruction and the delivery helper verifies admitted paths and
hashes; neither is OS-level denial of arbitrary out-of-scope reads. `--add-dir`
extends writable access and cannot establish that read boundary.

No exposed task tool providing trusted child effective-policy readback was found
in the available tool inventory. The CLI advertises app-server schema generation,
but its existence is not proof of an available live child-policy API. No new
adapter/server or permission profile was implemented. Caller-side historical
session metadata can show recorded model/effort/sandbox/parent identity; that is
not a successful new child runtime proof. Raw session logs must not be delivered
to the evaluator.

## Required ordering and remaining checks

1. Obtain a fresh native caller and shipped-role child through the existing
   authorized host path, with actual child policy/selector metadata. Do not
   reserve until effective read-only and the required read boundary are verified.
   The parent is coordinating this step; this preparation did not launch them.
2. Caller prepares admitted fixture bytes, dependencies and readback outside the
   evaluator. Installation/build operations remain caller-only. Do not recreate
   historical Git metadata to make candidate-mode tests pass in a scratch tree.
   The registration suite's default mode omits two historical candidate checks;
   record those omissions explicitly, not as passes. Use `python3 -B` and disable
   bytecode for imported Python tests in a read-only evaluation.
3. Recheck current 93-input closure, implementation binding, unique identities,
   exact outputs, scratch history/non-overlap and all raw hashes. Freeze the real
   invocation only after genuine IDs exist. Run `check-evaluator-delivery.py`
   non-reserving with caller-pinned manifest hash and prepared scratch, then its
   reserving path with the same validated inputs. Preserve every prior receipt.
4. Deliver only the pinned invocation and complete receipt through the actual
   evaluator path. Child verifies manifest bytes before parsing; it does not
   prepare fixtures, inspect the ledger, or rerun reservation.

Still unverified: fresh child effective permission/read boundary, actual native
delivery, fresh formal evaluation, CI and release. A successful help query,
historical caller narrowing or local delivery regression does not satisfy these.

## Current local recheck and shared-helper coordination

`python3 -B tests/review-scratch-history.tests.py --repo .` completed with
`PASS: 26; FAIL: 0` (Bash and PowerShell, exit 0). The initial invocation omitted
the required `--repo` argument and exited 2 at argument parsing; the corrected
command above executed the suite. Focused `git diff --check` also exited 0.

A7's current `preflight-host-review.py` accepts a pinned invocation plus optional
`--host-cli` and repeated `--required-flag` values. Its admission contract is
A7-specific and does not establish effective permissions. Its owner is actively
editing it. No copy or second CLI-help parser was added here: the quality-stage
implementation binding must remain with the existing canonical validator, and
CLI-help success would not resolve the unproven child read boundary.

## Independent review of delivery-preflight naming repair

The independent read-only `issue423_launch_diff_review` found no Critical or
Major findings. It verified both live callers use `preflight-evaluator-delivery.py`,
and the old name remains only in historical reports. Its independent Bash and
PowerShell registry runs each passed 27 checks with zero failures; Python AST,
Bash syntax and focused whitespace checks also passed. Ledger-unchanged and
exactly-one fixture reservation assertions remain present.

Limits: the old untracked helper's saved hash was unavailable, so byte-for-byte
identity across the rename was not independently proven. The reviewer inspected,
but did not rerun, the isolation suite; its execution evidence remains the
implementation run. This diff review is not formal evaluation, native admission,
CI or release evidence. No reservation or task state was changed.

## Current-owner delivery recheck (2026-10-07)

HEAD remains `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`; the existing dirty
checkout was preserved. The canonical plan still records T-002 as Approved /
Implementation Complete, with dependent T-003 Blocked and T-004–T-006 Planned.
No task or review state was changed by this recheck.

- Recomputed the preparation candidate's 93 unique allowed-input raw hashes,
  implementation binding and declaration: 95 checked, zero mismatches/missing
  files, exit 0. The preparation document is still not an invocation manifest.
- `rtk proxy bash tests/review-agent-isolation.tests.sh`: exit 0. The actual
  canonical validator accepted prepared delivery and rejected wrong caller pin,
  changed fixture, missing fixture and source drift. The disposable fixture
  ledger stayed unchanged on rejection; prepared delivery delegated exactly one
  synthetic reservation. The included Bash/PowerShell scratch-history suite
  completed with `PASS: 26; FAIL: 0`.
- Focused `git diff --check` on the evaluator role, quality-gate caller, isolation
  suite and this preparation report: exit 0 before this evidence append.

These are local caller/validator regression results, not proof of native child
permissions. Formal launch remains stopped before reservation: no trusted
readback has established that the actual child denies reads outside admitted
inputs and compound commands. `sandbox_mode = "read-only"` establishes neither
property. An input allowlist in role instructions or a successful CLI help probe
cannot replace this evidence. No historical reservation (including sequence 1200)
was reused; no real evaluator was launched. No new host adapter, permissions,
installation or task-state changes were introduced to hide this limitation.
