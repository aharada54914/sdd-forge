# A9 bound rollback admission and applied evidence

Status: Accepted implementation decision. This adds the current executable
boundary for Issue 197 REQ-009 and OQ-004; it does not reapprove or rewrite the
historical requirements, design, approval hashes, or operational evidence.

## Problem and scope

The existing Context HMAC validator checks signed sidecar integrity and approver
membership. It does not independently recompute A9's approval branch from the
**current** approver count. In particular, a valid earlier solo sidecar can remain
HMAC-valid after a second registered identity is added. The generic human-copy
publisher deliberately checks safe byte publication, not rollback authorization.
Calling those tools independently therefore does not implement the A9 boundary.

`scripts/validate-a9-rollback-receipt.py` is the operational entry for the bounded
`required` → `advisory` transition. It reuses the existing Context schema/HMAC
validator, JCS and Ed25519 verification primitives, trusted signer registry, and
transactional human-copy publishers. Other Context changes require their own
normal review and approval. This entry is a repository operator tool, not an
installed plugin payload or a replacement for generic publisher internals.

The entry is read-only by default. `--apply` is an explicit operator action and is
not authorized merely by a validator test, model output, or CI success. All real
HMAC keys, signer keys, approvals, and registry entries remain human-managed.
Tests use disposable keys and synthetic identities exclusively in temporary
projects; their signatures are not operational rollback evidence.

## Authorization contract

A strict JSON `a9-rollback-authorization/v1` object contains exactly:

- `schema`, `requester`, `requested_at`, `application_at`,
  `application_result: "authorized"`, and integer `approval_epoch`;
- `bindings`, containing exactly `before_context`, `before_approval`,
  `candidate_context`, `candidate_approval`, `candidate_snapshot`, `manifest`,
  `request_registry`, and `current_registry`;
- `signer`, `signer_key_id`, and base64 `signature`.

Each binding is exactly `{ "path": "repository-relative-path", "sha256":
"64-lowercase-hex" }`. All eight paths are distinct regular files with canonical
relative paths; symlinks, reparse points, hard-linked files, stale bytes, and
changes during validation are rejected. Preserve predecessor Context/sidecar and
request-time registry copies outside the three publication targets. The signed
request registry is a request-time snapshot, not a second live trust registry.
The current approver registry is always `sdd/approver-registry.yaml`.

The staged directory contains exactly the three manifest targets in this order:

1. `sdd/project-context.yaml`
2. `sdd/project-context.approval.json`
3. `sdd/.approved-context/project-context.approved.yaml`

`MANIFEST.sha256` binds those exact raw bytes with lowercase digest, two spaces,
relative target, and LF per line. The Context and approved snapshot must have
identical raw bytes. The signed candidate sidecar binds the predecessor canonical
Context hash and next approval epoch. The only semantic Context change allowed
is `workflow.capability_enforcement: required` to `advisory`.

Before application, the actual fixed live Context, approved anchor, and sidecar
must match the signed predecessor. Alternate live-anchor command-line paths are
not supported. Zero identities at request or application reject admission.
Current membership is reevaluated on every invocation: at least two identities
require two distinct currently registered approvers; one requires a sole primary
approval and a signed effective time exactly 24 hours after that primary approval.
The signed application time must be at or after that boundary and not in the
future. The request cannot postdate approval. A sole requester approving their
own request is rejected. Registry changes therefore cannot reuse an obsolete
approval branch. A second approval also must fall within the request/application
interval.

The Ed25519 signer must be the HMAC primary approver and the identity of the
trusted key with `operator` purpose. Its signed message is:

```text
SHA256(JCS(authorization without signature) || UTF8(":a9-rollback-authorized"))
```

The signature operates on that 32-byte digest. This narrowly extends ADR-0028's
existing crypto primitives to A9; it does **not** import A8's independent
operator/reviewer pair requirement. OQ-004's permitted one-person branch still
needs only that one registered approving identity, after the cooldown. A trusted
registry override is an explicit caller-supplied trust root, not proof supplied
by an untrusted PR; use the default reviewed registry for normal operations.

## Normal operator route

After humans have supplied the actual reviewed candidate, HMAC sidecar and signed
authorization, run the entry from the project checkout:

```sh
python3 scripts/validate-a9-rollback-receipt.py \
  --receipt rollback/authorization.json --staging-dir rollback/staged
```

An `ADMISSIBLE` result records authorization validation only. It does not change
Context, create approvals, produce a signature, or complete the rollback
rehearsal. For the separately authorized application, rerun the same command with
`--apply`. Windows defaults to the existing PowerShell publisher; other systems
default to the existing shell publisher. `--publisher-runtime` can select either
existing implementation when available.

Admission is repeated immediately before copying. Only the three authenticated
payloads and exact manifest are placed in a private temporary snapshot, which is
passed to `apply-human-copy.sh` or `.ps1`. Changing the original staging manifest
after admission cannot expand the publisher's target set. Existing publisher
hash checks, anchored traversal, journaled publication and crash recovery remain
intact. Invalid preflight inputs never invoke the publisher. After successful
publication the entry verifies the three actual post-state hashes and emits an
**unsigned** `a9-rollback-application-result/v1` object. Capture this output as an
operator artifact. If the publisher or subsequent integrity check fails, inspect
the existing journal/recovery state and actual files; a nonzero result is not a
claim that no authorized write occurred after publication began.

The entry and its mandatory gate registry are protected by the existing hook
policy. This is the supported authorization route, not an OS permission boundary
preventing a human owner from invoking a lower-level publisher or editing files.
No HMAC or private signing key is distributed through untrusted PR CI.

## Signed applied evidence

An unsigned `APPLIED` result is not accepted as the persisted signed rehearsal.
After actual application, an authorized operator can externally sign a separate
strict `a9-rollback-applied/v1` attestation containing exactly:

- `schema`, `authorization` and `publisher_result` file bindings;
- `applied_at`, `signer`, `signer_key_id`, and base64 `signature`.

Its signature message is:

```text
SHA256(JCS(attestation without signature) || UTF8(":a9-rollback-applied"))
```

The tool does not generate this signature or infer that application occurred
before evidence exists. Verify the supplied attestation with:

```sh
python3 scripts/validate-a9-rollback-receipt.py \
  --receipt rollback/authorization.json --staging-dir rollback/staged \
  --applied-attestation rollback/applied.json
```

`APPLIED_VERIFIED` requires both signatures, both HMAC-bound Context states,
current registry policy, exact application-result bytes, publisher success and
three-target receipt, coherent actual application time, and the current live
Context/sidecar/approved-snapshot bytes matching the authorized candidate. The
attested application time cannot precede authorization or be in the future.
Missing signatures, changed result bytes, mismatched live files, stale registry
bindings and replay against a newer state are rejected. This is a current-state
verification; later legitimate Context/registry changes may invalidate it without
erasing the historical signed artifacts. Preserve those artifacts separately.

Synthetic regression success demonstrates the technical admission/application/
verification route. A real signed operational rehearsal, promotion, release
observations and post-promotion feature evidence remain separate acceptance facts.
