# ADR 0028: Ed25519 signing and a maintainer-committed trusted-signer registry for live-host verification records

Status: Proposed

Date: 2026-07-23

## Context

Epic A8 (`epic-196-a8-integration`) specifies a live-host proof surface
(REQ-003/REQ-006, AC-026/AC-028) that discharges ADR-0019's own
hook-activation-handshake defense claim: a
`live-host-verification-record/v1` JSON record, produced per semantic
matrix cell, attesting that a real, installed-toolchain CLI session
exercised the hook-activation handshake. An editable, self-attested JSON
record with only a freeform transcript excerpt and a self-reported verdict
cannot, by construction, discharge that claim — an agent or operator could
simply write a record claiming success. The design's own round-2 remedy
history (`specs/epic-196-a8-integration/design.md`, Data Plan §
`live-host-verification-record/v1`) already rejected weaker alternatives:
a self-reported verdict alone, a single-party attestation, and a
capture-script-only proof each fail to bind the record to a specific real
session under a specific accountable identity.

This repository already has one precedent for solving a structurally
similar problem — ADR-0019's Project Context approval sidecar uses an
external-key HMAC to bind "a human issued this record" to content-hash
binding of "this hash matches this content." That mechanism assumes a
single external key held outside any agent's reach. Epic A8's problem
shape is different: proof requires two distinct, named, accountable human
identities (an operator and an independent reviewer) attesting to
different roles over the same record, verifiable independently of each
other, without a shared external secret either party could imitate the
other with. This repository has no prior use of Ed25519 or any
public-key/asymmetric-signature scheme anywhere (`grep -rli 'ed25519|
digital signature|public.key|private.key'` across `docs/`, `plugins/`,
`scripts/`, `tests/` finds no genuinely related hit outside this epic's
own spec) — this is a new class of cryptographic mechanism entering the
repository.

ADR-0008 (`docs/adr/0008-evidence-deep-verify-no-signature-crypto.md`)
already treats a comparably-scoped decision — who is permitted to perform
cryptographic signature verification, and where — as ADR-level material:
its own Consequences state that any component newly performing signature
verification "requires this ADR's supersession and a new security
review." Epic A8's `impl-review` gate (`impl-reviewer-a`, ADR-PRESENT
check, attempt-1/round-1) independently identified the same gap: the
epic's own `## ADR Change Log` cited only ADR-0019 (a different,
unrelated defense claim) and proposed no ADR for the signing mechanism it
actually introduces.

## Decision

Epic A8's future implementation task (Phase 2/3, not this Phase-1 spec
package) will introduce:

1. **Algorithm**: Ed25519 for all live-host-verification-record
   signatures (`operator_signature`, `reviewer_signature`), chosen as the
   standard, unambiguous default for asymmetric message signing with no
   implementation ambiguity (small fixed-size keys/signatures, no
   parameter-choice surface, broad language/library support across the
   sh/PowerShell/Node toolchains this repository already spans).
2. **Domain-separated signing targets**: each signer signs a distinct
   payload derived from `sha256(JCS(record without *_signature fields) ||
   ":" || "<role>")`, where `<role>` is `operator` or `reviewer` — so an
   operator's signature can never be replayed as a reviewer's, or vice
   versa, even under key reuse (design.md, Signing Contract).
3. **A maintainer-committed Trusted-Signer Registry**
   (`plugins/sdd-review-loop/references/a8-trusted-signers.json`, schema
   `a8-trusted-signers/v1`): an append-only `key_id -> {identity,
   public_key, role, added_at}` mapping. `validate-live-host-proof`
   resolves each record's `operator_key_id`/`reviewer_key_id` against
   this registry, verifies the claimed identity and role match the
   registry entry, verifies each signature against the resolved public
   key under its own domain-separated target, and rejects an untrusted
   key ID, an invalid signature, an identity mismatch, or a public-key
   collision between the two resolved entries (named error codes in
   design.md, Signing Contract).
4. **Scope boundary, matching ADR-0008's own precedent**: this decision
   authorizes signature verification for exactly one purpose — validating
   `live-host-verification-record/v1` attestations inside
   `validate-live-host-proof` — not a general-purpose signing/verification
   capability available to other components. A future component that
   wants to newly perform signature verification for a different purpose
   needs its own ADR (or this ADR's explicit extension), matching
   ADR-0008's own stated bar for signature-verification-scoped decisions.
5. **Key custody**: private keys are held by the named operator/reviewer
   individuals, never committed to the repository or held by any
   automated agent; only public keys and identity/role metadata are
   committed to the Trusted-Signer Registry. This mirrors ADR-0019's own
   "external, agent-unreachable key" principle, applied to a two-party
   asymmetric scheme instead of a single external HMAC key.

## Consequences

- A new cryptographic-mechanism class (Ed25519 asymmetric signing) enters
  this repository for the first time, alongside the existing HMAC-based
  mechanism ADR-0019 established. The two are not redundant: HMAC serves
  a single-external-key "a human issued this" binding; Ed25519 here
  serves independently-verifiable, per-identity, two-party attestation
  where each party must be individually accountable and neither can
  forge the other's signature.
- `validate-live-host-proof` becomes a new signature-verification
  component whose correctness (canonicalization, domain separation, key
  resolution, error taxonomy) is now itself a review/test surface for
  Epic A8's own Phase 2/3 implementation task, not something this Phase-1
  spec package builds.
- The Trusted-Signer Registry is a new maintainer-custody artifact:
  registering a new operator or reviewer requires a maintainer-committed
  edit to `a8-trusted-signers.json`, the same governance weight as any
  other `plugins/sdd-review-loop/references/` reference file.
- Any future component wanting to perform signature verification for a
  different purpose must either extend this ADR explicitly or author its
  own, per the ADR-0008-established bar — this ADR does not implicitly
  authorize a general signing/verification capability.
- design.md's `## ADR Change Log` is updated to cite this ADR instead of
  "None," closing the impl-review `ADR-PRESENT` (Major) finding from
  attempt-1/round-1.

## References

- `specs/epic-196-a8-integration/design.md`, Data Plan § `live-host-
  verification-record/v1` and § Signing Contract; `## Security
  Boundaries` (B1).
- `specs/epic-196-a8-integration/requirements.md`, Security Boundaries
  table (B1: live-host hook-activation handshake session).
- ADR-0008 (`0008-evidence-deep-verify-no-signature-crypto.md`) —
  precedent for scoping signature-verification decisions to ADR level,
  and for the "any new signature-verification component requires this
  ADR's supersession or its own ADR" bar this decision follows.
- ADR-0019 (`0019-approval-sidecar-protection.md`) — this repository's
  existing external-key-signed authenticity precedent (HMAC, single
  external key), contrasted above against this decision's two-party
  asymmetric scheme.
- `reports/impl-review/epic-196-a8-integration/attempt-1/round-1/
  reviewer-a.json` (ADR-PRESENT finding that identified this gap).
- **Numbering note**: 2026-07-23 cross-branch 採番調整により 0028 を
  割当。0025 は `epic-189-a1-project-context`/`epic-190-a2-
  capability-registry`/`epic-191-a3-*` の3ブランチが独立に別決定へ既に
  使用済み（3重衝突、未マージ）；その解決空間（0026/0027 が
  README documented renumber 手順でこの3件に割り振られる見込み）を
  空けたまま、この決定には衝突しない 0028 を割り当てた。0025 の
  3重衝突自体の解決はこの orchestrator の管轄外で、最終マージフェーズ
  （PR 順序設計）の作業として引き継がれる。(EN: assigned 0028 via a
  2026-07-23 cross-branch numbering coordination check; 0025 is already
  triple-claimed by three unrelated, unmerged branches for different
  decisions, expected to resolve into 0025/0026/0027 via the README's
  documented renumber procedure at merge time — 0028 leaves that
  resolution space untouched. Resolving the 0025 triple-claim itself is
  out of this orchestrator's scope, carried forward to the final
  merge-ordering phase.)
