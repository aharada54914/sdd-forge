# Requirements: Feature Concept Test

Source: Issue #290, Phase 1
Spec-Review-Status: Pending

## Scope

Before full-profile bootstrap consumes a v2 domain model, compare the real feature
request with existing concepts and retain the human's boundary decisions. Phase
2 authoring, Phase 3 reviewer semantics, and Phase 4 reverse/C4 changes remain
separate. No v1 migration or second loader is added.

- REQ-001: Record feature, one of the four proposal classifications, rationale,
  confirmed same/different/undecided distinctions, and every input path/SHA-256.
- REQ-002: Humans confirm distinctions. Do not automatically create concepts or
  modify domain/; future scenarios alone justify only low-confidence candidates.
- REQ-003: Require matching Markdown/JSON evidence. Non-FITS records require a
  signed registered human decision using the existing approval infrastructure.
  Reuse content/schema/hash/HMAC/registry checks, not provenance-only validation.
- REQ-004: FITS without a decision or signed proceed continues. Signed defer holds;
  signed rejected stops. Missing, corrupt, stale, or unapproved evidence blocks.
  Every nonzero outcome stops domain-sync and generation. No domain/ preserves
  the existing skip behavior. Lite integration is outside this phase.
- REQ-005: Spec, implementation, task and quality review inputs include the same
  evidence, required approval, and all recorded inputs. Admission repeats the
  domain-reference and signed-decision validation; missing, changed, unapproved,
  deferred or rejected evidence blocks review. Fixed reviews validate their
  selected revision, including its approver registry, without live-file fallback.
- REQ-006: Publish the internal skill through the existing directory manifests;
  ship Bash and PowerShell dispatchers sharing one deterministic implementation.

## Confirmed decisions

The prior Phase 1 branch's owner decisions are retained: reuse signed approval;
proceed/defer-to-domain-update/rejected are distinct outcomes. Production signing
is human/CI-only. Development permission does not fabricate runtime human
confirmation or production approval.
