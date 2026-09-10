# Implementation-policy reviewer A launch

Act only as fresh read-only impl-reviewer-a defined in
plugins/sdd-review-loop/agents/impl-reviewer-a.md. Read that role and
plugins/sdd-review-loop/references/review-context-boundary.md as instructions.
No delegation, writes, network, tests or production operations. Shell reads use
rtk proxy. Return canonical reviewer JSON only; the orchestrator persists it.

Invocation: reports/impl-review/epic-189-a1-project-context/attempt-5/round-1/reviewer-a-invocation.json
Read this before substantive content. Read all allowed inputs completely in
bounded chunks, without truncation. Never read raw reviewer outputs, historical
review outputs, unlisted ADRs or other out-of-manifest content. Root domain/
existence probe is permitted by the boundary. Absent/unavailable evidence is
not inferred as success.

The original precheck --verify-inputs exited 0, and original --reserve returned:
REVIEW_CONTEXT_OK 2ceb8bb872dd7cdfea446cfd20880b7369dd0a90ce762d598b4568144be2ffac sequence=978 previous_record_sha256=591e76a6f191601f1487151d38b8f7210e420b04646e53cde12e192a91f7910e pre_append_tip_sequence=977 identity_unique=yes

Verify this reservation chain from the quoted line and your invocation.
Do not rerun reservation or compare the pre-append ledger fingerprint with
the appended ledger. Run/session: 01a08638-58e7-7181-a1f3-00bbe36c83ac.
Fresh gpt-6-astra context, readOnly, networkAccess false, approvalPolicy never.

This is the scoped RT002 post-implementation amendment/provenance re-review,
attempt 5 round 1. Review current design and four layer documents against
requirements and acceptance criteria, using the calibration and disclosed
Amendment Re-Review Context. Historical differences alone do not waive or
establish a content finding. No claim of TYPE-H byte-identical convergence
is supplied for amended content. An earlier attempt-4 precheck is preserved
as stale; no reviewer result from it is supplied. No assumed PASS, live
activation, ordinary implementation, quality-gate completion or integration.

