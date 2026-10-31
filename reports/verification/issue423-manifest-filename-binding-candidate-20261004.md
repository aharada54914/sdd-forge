# Issue 423: versioned implementation manifest binding candidate

Status: BLOCKED at protected apply; not implemented, not GREEN, not a formal review.
Owner HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.

## Root cause and scope

`validate-review-context-set.sh:422` and its PowerShell counterpart at line 495
only admit `handoffs/<directory>/manifest.json`. The task-manifest producer-side
validator accepts a caller-supplied manifest path (`validate-task-input-manifest.sh:345-346`),
and snapshot preparation opens that supplied path (`prepare-task-snapshot.sh:161`).
The approved recovery report cites `manifest-archive-input.json` at line 72.
This immutable manifest uses the archived original report as input and the refresh
directory as output. The earlier `manifest.json` instead pins the former canonical
report and the earlier output directory. Substituting the earlier manifest would
change the evidence contract, not merely correct a spelling.

Allow a bounded versioned basename in both consumer implementations. Preserve
exact path/hash admission, report citation, task/run/session identity, read-only
mode, scratch isolation, and all other authorization checks. Do not rename,
rewrite, or substitute historical manifests or reports.

## Exact base pins (SHA-256)

| Repository-relative file | SHA-256 |
| --- | --- |
| plugins/sdd-quality-loop/scripts/validate-review-context-set.sh | 011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b |
| plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 | e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925 |
| plugins/sdd-review-loop/references/review-context-boundary.md | 07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a |
| tests/issue311-scratch-isolation.tests.py | 05c0dd308f81dc276a5d468f618382392edfc098f7f6f10c60b0ad9586c71bf8 |
| handoffs/issue423-t002-recovery-20261003/manifest.json | 6b1ef6c572d4d0faf1aedd7f6366aef7c21c25e53d9d039ba8b5d688ed2a6f68 |
| handoffs/issue423-t002-recovery-20261003/manifest-archive-input.json | 7c6fef1602a1fa5608b7b78a4dd6a57d1838ffcc1f1ff8e58a98a79d51d70163 |
| reports/implementation/sdd-domain-multitarget/T-002.md | 3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4 |

## Proposed protected change (data only; NOT applied)

In the Bash and PowerShell path predicates, replace exactly:

```text
^handoffs/[A-Za-z0-9._-]+/manifest[.]json$
```

with:

```text
^handoffs/[A-Za-z0-9._-]+/manifest(-[A-Za-z0-9][A-Za-z0-9_-]*)?[.]json$
```

In `review-context-boundary.md`, under Same-task evaluator implementation binding,
document that `manifest.json` and `manifest-<version>.json` are accepted; version
starts with an ASCII alphanumeric character and otherwise consists only of ASCII
alphanumerics, underscore, or hyphen. Versioning preserves historical handoffs
without relaxing exact evidence binding. Never select an older manifest merely
because it has the unversioned basename.

## Executed regression and refusal

Normal apply_patch accepted the focused fixture extension. It runs the real owner
validators against disposable fixture ledgers; it does not reserve owner identities.

Command: `rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo . --manifest-only`

Observed: **12 PASS / 2 FAIL** (expected RED). Both versioned-positive cases fail
before reservation. Bash reports `REVIEW_CONTEXT_CONTRACT: required fields,
file-manifest input, read-only mode, or no-fallback contract is invalid`;
PowerShell reports `REVIEW_CONTEXT_CONTRACT: implementation_manifest requires a
canonical path and SHA-256`. Citation mismatch, hash mismatch, empty suffix,
traversal, mis-cased prefix, and nested suffix were refused in both runtimes with
no ledger change. Before implementation, those negative cases can be rejected by
the old filename predicate; GREEN must prove the specific binding constraints
remain effective after valid versioned names are admitted.

Normal apply_patch for the two protected validators and contract documentation
was blocked before execution:

> SDD deterministic gate: agents must not modify gate scripts, hook configuration,
> or critical test files. These are part of the enforcement chain and cannot be
> bypassed by sudo.

No alternative executor, patched executable copy, or historical artifact rewrite
was used. The proposed protected edits remain unapplied.

## Required continuation

After authorized protected application, reverify the base pins before applying,
then run the focused command and the complete fixture command without
`--manifest-only`. Existing canonical basename cases must remain passing; versioned
positive cases must pass preflight, reservation, unchanged verification, and reject
changed/omitted bound scratch roots. All six negative cases must still refuse
without ledger mutation. Run `git diff --check`. Recompute evaluator input hashes;
this local filename repair does not supply strong evaluator identity, resolve
protected input-read refusals, or establish formal quality-gate/Done/delivery status.
