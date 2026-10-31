# Issue 678: owner-authorized delegated cloud signature

The owner explicitly authorized proxy operation in the cloud: 「君が代理でクラウド環境でやってください 承認する」. In the preceding conversation, the approval concerned the prospective T-001 scope, single-owner registry, and exact Phase-1 advisory Context in the [review packet](../a9-operational-preparation-20261031/ready/README.md). This record is an agent transcription of that conversation, not an independently authenticated GitHub review or human signature.

The existing issuer created the [staged public approval](staged/sdd/project-context.approval.json). The existing validator returned [VALID](validation.txt), and every issuer manifest entry was checked against its actual file bytes. Candidate raw SHA-256 is `a43669c40d374b1411df0ba2f3ed84c4fb05d337c33e850e157f9c612702076a`. The approved snapshot is byte-identical to that candidate. No production code or signing algorithm was changed.

## Custody and acceptance limits

This is **delegated cloud signing**, not human/CI-only signing. A fresh dedicated key was generated under `/workspace/.private/sdd-forge-678/delegated-context-key`, outside Git, with directory mode 0700 and file mode 0600. The key was passed to the existing signer/validator by file path. No key bytes were printed or included in this packet. These filesystem permissions do not isolate the key from the development agent. No inherited signing key was overwritten or enrolled as a default runtime key.

Consequently this signature does **not** satisfy ADR-0019's agent-inaccessible external-key custody requirement. HMAC verification here proves consistency under this cloud key, not independent human authorship. The user authorized the operation; this report does not silently amend the product trust contract. The public sidecar has no built-in field identifying delegated custody, so it must remain accompanied by this report and must not be promoted to live approval as if it met that contract.

The original review packet remains an immutable historical draft. Owner approval is recorded separately in [approval-observation.json](approval-observation.json). T-001 remains Planned, and its Done conditions are unchanged. No live `sdd/` files, release, advisory activation, promotion or completed operational acceptance are claimed. Issue #678 remains open.

## Remaining operational work

To meet the existing production trust contract, reissue the same approved Context through an independently controlled human/CI signer with an agent-inaccessible key. No further decision on this candidate's scope is being requested. Then publish through the existing approved-copy mechanism, commit the real request/contract, collect authentic advisory results, and complete the real release interval. The current environment reports no managed secret bindings or independent outbound identities; no independent signer was available for this run.

This cloud key is session-local storage, not durable managed key custody. Retain it only for reproducing this delegated verification; do not use it as evidence of external isolation. No repository secret, workflow secret or runtime default was configured.
