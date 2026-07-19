# ADR 0019: Approval Sidecar Protection

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), cross-checked against the
sdd-forge repository's actual code, per
`docs/ai-dlc-foundation-decision-v2.md` §9 (Q8: Project Context approval
defense). It is one of the three groups v2 revised relative to v1 (the
concrete approval-defense mechanism), including a designer ruling that
conditional two-person approval activates only under specific conditions.

A bare `status: Approved` field inside `project-context.yaml` is
insufficient: an agent could set it directly. v1 proposed splitting
content from its approval record into a sidecar and extending the
repository's existing hook-guard "approval-count-increase detection"
pattern to that sidecar. **Both independent review passes constructed the
same attack against that extension, independently, making it a
Blocker**: an agent can modify the YAML, then run the public
canonicalization procedure to recompute the hash, and rewrite
`context_sha256` alone — no approval count increases, so every existing
guard layer passes. An unsigned SHA-256 is a *binding* (this hash matches
this content), not an *authenticity* claim (a human produced this
record); increase-count detection only defends the latter by assuming the
former is untouchable, which this attack breaks.

## Decision

Split `project-context.yaml` (and, identically, `provider-bindings.yaml`)
from its approval record: `sdd/project-context.yaml` (content) and
`sdd/project-context.approval.json` (approval record, plus the
`provider-bindings.approval.json` sibling):

```json
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:...",
  "primary_approval": {"status": "Approved", "approver": "name", "approved_at": "ISO8601"},
  "second_approval": null,
  "hmac": "…"
}
```

1. **Increase-detection is abandoned for this sidecar.** Unlike
   `tasks.md`, `*.approval.json` is not mixed with agent-editable content,
   so it is protected instead by **`PROTECTED_GATE_SUFFIXES`**: agent
   writes are denied entirely (no partial permission, no `sudo` bypass).
   Changes flow only through the human-copy procedure (ADR-0011).
2. **External-key HMAC.** Following the repository's existing
   external-key-signed evidence-bundle (`SDD_EVIDENCE_KEY`) and
   `SDD_SUDO` precedent, the **entire approval record is signed with an
   external-key HMAC**, unreadable by any agent. Hash comparison
   establishes "content matches record"; HMAC establishes "a human issued
   this record" — neither substitutes for the other. The **HMAC preimage
   is defined as**: the approval object with the `hmac` field excluded,
   canonicalized per decision-document v2 §18.3 (YAML/JSON parse → NFC
   normalization → JCS) — i.e. the UTF-8 byte sequence produced by
   applying that canonicalization to the field-excluded object. This
   avoids the self-reference that would otherwise result from signing a
   record that contains its own signature.
3. **The verification machinery itself is protected**: the canonicalizer,
   hash generator, approval validator, policy-weakening detector,
   resolver, and any generated projection are added to `guard-invariants`
   (`PROTECTED_GATE_SUFFIXES`), an explicit Epic A1 deliverable.
4. **Two-tier defense-claim scope (new in v2).** The hook layer cannot
   fully prevent indirect writes (e.g. an inline interpreter bypassing
   shell-command inspection) — an already-admitted limitation this plan
   does not change. The claim is stated in two tiers: **hook layer +
   deterministic validator** prevents misoperation and simple
   self-approval (a footgun guard); **adversarial-agent resistance**
   comes from the protected file, the external-key HMAC, branch
   protection/CODEOWNERS, and human review as the external boundary. No
   unconditional "defended across all three runtimes" claim is made; it
   is conditioned on the hook-activation handshake (v2 §7).
5. **`SDD_SUDO` remains non-bypassing** (unchanged): Project Context
   approval cannot be bypassed with `sudo`, matching the existing
   never-sudo class (WFI / Second Approval / gate-script protection).
6. **Conditional two-person approval (designer ruling).** Required only
   for **policy-weakening** changes (weakening enforcement, removing a
   Capability, narrowing a component path, de-scoping public
   distribution, lowering criticality, widening a provider allowlist,
   changing a production write path, removing a required Gate, or moving
   `full` to `lite`). Within that scope: mandatory only when the approver
   registry has **2 or more real registered identities**; with a single
   maintainer it relaxes to "first approval + 24-hour cooldown," reusing
   `SDD_SUDO`'s TTL/HMAC machinery (effective time HMAC-signed; the
   validator rejects early application). This lets solo-maintainer
   dogfood (Epic A9) execute a required-to-advisory rollback without
   inventing a second identity as governance theater.

## Consequences

- The Blocker attack (hash recomputation without an approval-count
  increase) is closed at the tool-mediated layer: direct agent writes
  through guarded tool paths are denied entirely; adversarial resistance
  additionally relies on the external boundary (HMAC, branch protection,
  human review) per the two-tier scope, not on the guarded-tool-path
  denial alone.
- Every legitimate approval-record change now requires the human-copy
  procedure, heavier than the previous guard — an accepted cost given the
  Blocker severity.
- The guard-invariants surface grows (canonicalizer, hash generator,
  validator, weakening detector, resolver, projection), each needing its
  own protection registration and test coverage in Epic A1.
- Solo-maintainer projects are not blocked by an unreachable two-person
  requirement, but every policy-weakening change is delayed by the
  24-hour cooldown — deliberate friction, not an oversight.
- Shipped documentation must state the two-tier defense scope explicitly
  and never claim adversarial-agent resistance from the hook layer alone.

## References

- Decision document v2 §9 (Q8) — `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0011 (Handle-relative protected-file publication, human-copy
  procedure), ADR-0007 (Controlled rebinding via provenance re-review)
