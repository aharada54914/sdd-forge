# Issue #423 cloud input reconciliation — 2026-10-16

Scope: T-002 completion closure and T-003 attempt10 policy/preflight history.
This record and `inventory.json` are transport inventories, not approval,
identity reservation, signature, quality verdict or current input admission.
The user authorized publication of non-sensitive originals only. No new
implementation, repair command, A8/A9 operation or shared repair application
was performed. All original owner files and existing public files are retained.

## What this checkpoint adds

49 original files are copied byte-for-byte, with their source-relative paths,
public locations, sizes and SHA-256 recorded in `inventory.json`:

- T-002's 2026-10-14 quality decision, completion note, independent Codex
  review, current-validation record and bounded recovery-source inspection.
- Three original resolved-ticket records, T-003 attempt2's original report,
  and the available T-002 build, boundary, lint, typecheck, Registry and
  task-state raw outputs. These are historical observations, not fresh runs.
- The local canonical T-002 implementation report is archived under
  `originals/reports/implementation/sdd-domain-multitarget/T-002.md` instead
  of replacing the different existing public canonical report. Its historical
  original-report archive and revalidation log retain their original paths.
- attempt10's original input manifest, baseline map and admitted non-sensitive
  missing inputs, plus its non-sensitive GREEN, packaging and failed-check logs.
  `design-boundary-addendum-20261004.md` retains its original candidate-only
  wording; publication does not approve it.
- Historical AGENTS, task-plan and Registry-helper input bytes are archived
  under `attempt10-inputs/`. They are evidence inputs, not active checkout
  policy, task-state updates or installed code. The receipt-bound `install.sh`
  is likewise an inactive byte-identical original under `originals/`.

No source evidence was redacted. Native session identifiers in retained records
are historical handles, not credentials or newly reserved identities. The
FilesOnly build log contains opaque temporary-directory paths but no personal
owner name, authentication data or real signing key; it remains unchanged and
does not prove host registration.

## Public and local task states remain different

The active public plan at the starting commit
`36e498950bb0a3084fc4997e42f9c39d376c8e73` is:

| Task | Public state | Local owner observation |
| --- | --- | --- |
| T-001 | Implementation Complete | Done |
| T-002 | Blocked | Done |
| T-003 | Planned | In Progress |
| T-004..T-006 | Planned | Planned |

All six approvals are Approved. No state or approval field is changed by this
checkpoint. Original ticket-resolution records report a historical local
decision; adding them does not complete the public closure or release T-003.
The local T-002 Done field itself is insufficient: a later stored task-state
check failed as described below. Retain the historical decision and investigate
its delivery gap rather than silently changing either plan to reconcile it.

## T-002: exact closure and remaining failures

The generated dated bundle has raw SHA-256
`241011521219dc1dc2c3eb61434f9a7a9ee2d68a0026e2d2566fe3e419ec3d19`.
It names nine artifact path/hash pairs; eight originals are now available at
their exact public paths and match. The ninth is its private contract:

| Private original retained locally | SHA-256 |
| --- | --- |
| `specs/sdd-domain-multitarget/verification/T-002.contract.json` | `7935c20fd18cc34b0b3c0f756ca56eb5e41928cc81c5c98e6fbb29ee4ab5e281` |
| `specs/sdd-domain-multitarget/verification/20261014/T-002.evidence.json` | `241011521219dc1dc2c3eb61434f9a7a9ee2d68a0026e2d2566fe3e419ec3d19` |

The dated alias `verification/T-002-20261014.evidence.json` is byte-identical.
Both bundle paths contain a personal local path and local builder identifier;
the contract contains a personal cache path. They are not published.

The required canonical `specs/sdd-domain-multitarget/verification/T-002.evidence.json`
is absent in both the owner and public checkout. The existing checker requires
that exact task-scoped filename (`check-task-state.sh:110-117`). The original
`attempt10-20261016/output/qg-taskstate.log` records exit 1 for this absence.
The earlier standalone dated-bundle PASS is preserved; it does not prove that
the later task-state consumer can locate the canonical bundle. No generator,
rename or status-only workaround was executed here.

The reviewed payload also differs from the public active implementation:

| Artifact | Reviewed owner SHA-256 | Public active SHA-256 at the starting commit |
| --- | --- | --- |
| `plugins/sdd-quality-loop/scripts/registry_discovery.py` | `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea` | `385c849f6c0bc7f71fc2717e2c2bfb5ea9e3ff4a5fe7496d8889cc75f420ad4a` |
| `install.sh` | `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50` | `9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719` |

Their reviewed bytes are available in inactive archives; the public validator
and boundary suite already match the recorded reviewed hashes. The source
report, helper/installer byte differences, recovery declarations, and current
input admission must be reconciled through the authorized workflow before
claiming current-head T-002 acceptance. T-001's public prerequisite state also
needs its own genuine completion closure, not an inferred Done transition.

## T-003: available history is not a fresh preflight

The original attempt10 manifest SHA-256 is
`90a5eb8fb83c2d71f20d4bf777a95a3528319cb3670d29ab9329322b4e641654`.
All 183 path/hash inputs matched the retained historical snapshot during this
reconciliation. Of these, 182 are now available by exact hash through the
explicit mapping in `inventory.json`; three are archives rather than active
canonical paths. The one held manifest input is
`reports/implementation/sdd-domain-multitarget/T-003-preflight-handoff-20261016-fresh.md`,
SHA-256 `b9e1e52b68edcc50369eb7d57a4d0f6ba389c32c896233ff4d8f4643d298aeec`.
Thus the public checkout is not a valid 183-input original-path admission.

The full attempt10 implementation report, SHA-256
`90f2a4f1a8ec14775c4a6683cbf72975c5dcc56b563e7860e7a4e7d00450c586`,
and the additional `T-003-preflight-handoff-20261016-complete-fresh.md`, SHA-256
`ee164c593363c00f8df9be90f574fd9b29bfc79433516090f51c04cbe9d8fa87`,
also remain private because they contain personal owner paths. The report
records the parent-relayed approved policy and high-risk field/counterpart/
mismatch table, historical RED/GREEN and packaging authority. This inventory
does not recreate the original human instruction or mint a new approval.

The recorded policy is: required checks are never omitted; unexecuted or
unavailable required checks block; only originally optional unselected checks
may be reasoned N/A; Registry v1 defines no conditional gate to invent. This
paragraph is a reading guide, not a substitute for the admitted original.

Historical nonzero results are retained without repair:

- `qg-types.log`: exit 1, 18 strict-type errors for the selected-plan evaluator.
- `qg-taskstate.log`: exit 1, canonical T-002 bundle missing.
- `qg-workflow.log`: exit 1, invalid CLI argument; no successful workflow-state
  validation was completed by that invocation.

The logs preserve the observations they contain; they are not independently
signed execution attestations or fresh checks of this publication head. No
failed check is converted to PASS, and no new product tests were repeated for
this evidence-only publication.

## Private transport and user decision

A local private transport archive contains 15 unchanged originals: the T-002
contract/dated bundle; three T-003 report/handoff files; three scratch-owner/
observation/source-inspection records; and six RED logs plus the packaging
generation log. Its exact relative file list and per-file hashes are under
`private_originals_held` in `inventory.json`. Archive SHA-256:
`5ae6ca102e842d68ac63b4d02cb010f1cdd6f5453a07c2a129df04bb57e77d59`.
It remains local; no upload, repository commit, recipient, ACL change or new
external access was performed. No real signing key, authentication file or
raw environment/session dump is included.

The remaining user decision is the existing authorized private file-transfer
destination for the intended cloud context. Transfer only that bounded archive,
verify its container and raw-file hashes in a private workspace, and retain the
originals unchanged. A usable private destination must actually be available;
this document does not grant one. Do not put the payload, passwords, real keys
or tokens into the public repository, issue, PR or launch prompt.

Redacting the contract changes its raw hash and breaks the bundle's artifact
binding. Redacting a report, handoff or RED log creates different evidence and
cannot satisfy an existing raw pin. Even metadata that a particular signature
scheme omits still changes the raw file hash. No redacted derivative, relocated
archive or old signature is presented here as equivalent admitted evidence.
If private transport is unavailable, a new portable evidence version requires
an explicitly authorized evidence-migration procedure and independent validation;
do not rewrite the old contract, bundle, manifest, signature or verdict.

Before formal cloud implementation resumes, establish exclusive implementation
ownership and stop/admit prior contexts through the legitimate mechanism;
official stop inspection is unavailable here and source stability is not stop
proof. Then reconcile the genuine T-001/T-002 prerequisite closure, required
canonical bundle location, reviewed versus active bytes and private provenance;
bind fresh current inputs and independent review under the approved workflow.
The preserved attempt10 IDs/snapshot are history, not reusable fresh identities.
