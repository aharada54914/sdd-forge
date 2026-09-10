# A8 specification review resumption — 2026-09-08 JST

This is a launch/progress record, not a gate verdict or completion claim.

## Current inputs and reservations

Worktree: `/Users/jrmag/.local/share/sdd-forge-a8-verify-20260905`.
Existing attempt 4 round 2 precheck is retained, not replayed. Current
requirements, acceptance tests, and calibration hashes still match it
(ae6329). Investigation SHA-256 is
`dffb5e44ce29f734f5d07d6286eda469a92a8eb3a14f35f12aa0c41e36df83be`.
No source or frozen artifact was changed for this launch.

The reconciled ledger was checked before reservation. Fresh host allocation
used the installed Codex Desktop 0.153.4 app-server, Astra, ephemeral,
read-only, and no network access for the turn. No safety hook or trust setting
was disabled. Actual host-issued run/session:
`01a07cec-2ebe-7253-a7e9-33e977a23f14`.

The persisted reviewer-A invocation binds all five canonical inputs, including
investigation. The actual validator with `--reserve` exited 0 (4fde76):

```text
REVIEW_CONTEXT_OK 87a5b85adb745071ef5f931e3c83e272846f8576cf84ed622f1f246758961e6b sequence=968 previous_record_sha256=a5e370d1b7af862fb08f981da6fcaaf60935276428132b9227d8d897f874f4b8 pre_append_tip_sequence=967 identity_unique=yes
```

Post-append full-ledger validation (8cdb96) verified all 968 sequential records,
hash links, record hashes, unique run/session IDs, and invoking-host presence.

## Actual model launch

The initial long JSON request was not accepted by the terminal line input
(no turn response; a subsequent newline emitted a bell). The pending line was
cleared using Ctrl-U, and a short request referencing the persisted launch
instructions was sent to the same already-allocated host. No server restart,
new reservation, fallback, or substantive turn replay occurred.

The server accepted actual turn `01a07cee-0a4e-7013-b345-52afe2b6b2a4`
and emitted `inProgress` (81e74f). Subsequent actual tool-completion events
show the reviewer reading its instructions, invocation, calibration, and
canonical requirements/investigation inputs with exit 0. The reviewer has no
write authority and has not been given earlier raw reviewer findings.

Both reviewer outputs are now captured and validated (8ef019). Reviewer A
reported a Critical amendment-commit-citation finding. Its original incorrect
NEEDS_WORK verdict is preserved in reviewer-a-initial.json; the same reviewer
corrected only that field to BLOCKED in turn
`01a07cf1-4422-7ce3-bc7f-cd8cc7d5fe67`. JSON comparison confirmed no finding
or other field changed.

Reviewer B used a fresh host-issued run/session
`01a07cf2-80eb-75b1-8d9c-0b325369f53d`, reservation sequence 969 (3f236c),
and actual completed turn `01a07cf3-6176-72b1-8016-3d13ecf9582d`.
Its sixth input was only the sanitized A summary with SHA-256
`66c584c43a843060b9ae44c286fa57d97b28ba1ee3a3dffe8829afd250c92ac6`;
it did not receive A's raw findings. B independently reported Critical
APPROVAL-BOUNDARY and Major EDGE-CASE-COVERAGE failures.

The round directory now preserves both raw outputs, the integrated verdict,
contract, and report. Integrated attempt 4 round 2 verdict: NEEDS_WORK,
Critical 2 / Major 1 / Minor 0, preserving overlapping independent findings.
Identity/manifests, all current input hashes, correction-only semantics,
finding counts, and derived verdict consistency passed local verification.
This is artifact-consistency validation, not a successful specification gate.
Spec status remains Pending; no task completion or merge is authorized.

## External state

Snapshot a8d0e3: six open PR heads unchanged. PR #400 current head has no
non-success checks but remains draft/blocked; its specification gate is still
unpassed. PRs #394/#390 have completed Windows/aggregate failures; #381 and
#371 retain multiple completed failures; #245 remains conflicted. No merge,
push, issue closure, or active CI wait is claimed by this resumption.

Ordinary implementation and investigation remain with the main agent per
the user's latest cost preference. Only mandatory independent reviews use
fresh model contexts.

## Round-2 remediation proposal

The next goal turn produced `spec-round-2-proposed-changes.md` in the A8
round directory. It specifies the two exact missing amendment commit IDs and
48 unique Planned acceptance assertions for AC-026/027/028, including
individual missing fields, request/result digest failures, independent
signature failures, and each of the five missing semantic cells. Verification
60676d re-read historical Git blobs and confirmed the quoted SHA-256 values,
unique case IDs, Planned states, and unchanged canonical acceptance and
investigation inputs. Diff check a8f485 exited 0. This is a proposed human
amendment, not implementation or executed acceptance tests.

The installed bootstrap-interviewer Specification Review Gate step 4 requires
presenting NEEDS_WORK changes and awaiting human editing. No canonical
specification was edited in this turn. Round 3 has not launched. The proposal
also flags an existing general-versus-field-specific nullability inconsistency
in frozen design.md (7a65ba); it does not silently amend the design.

Remote snapshot 1a9917 confirmed the same six open PR heads and terminal
check outcomes; no live CI wait, push, merge, or issue closure occurred.
This goal turn made progress by resolving exact remediation inputs and
producing a validated change proposal, not by claiming unchanged CI as work.
