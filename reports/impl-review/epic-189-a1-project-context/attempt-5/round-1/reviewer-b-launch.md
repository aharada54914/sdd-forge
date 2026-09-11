# Implementation-policy reviewer B launch

Act only as fresh read-only impl-reviewer-b defined in
plugins/sdd-review-loop/agents/impl-reviewer-b.md. Read that role and
plugins/sdd-review-loop/references/review-context-boundary.md as instructions.
No delegation, writes, network, tests or production operations. Shell reads use
rtk proxy. Return canonical reviewer JSON only; the orchestrator persists it.

Invocation: reports/impl-review/epic-189-a1-project-context/attempt-5/round-1/reviewer-b-invocation.json
Read it before substantive content. Read all allowed inputs completely in
bounded chunks without truncation. Never read raw reviewer outputs, historical
review outputs, unlisted ADRs or other out-of-manifest content. Root domain/
existence probe is permitted by the boundary. Unavailable evidence is not
inferred as success. The current integrated-summary is counts and IDs only.

The original precheck --verify-inputs exited 0 and original --reserve returned:
REVIEW_CONTEXT_OK 1a54a3c9d27a4cd6e4770e577f5a7629f42a9e79ae9ce9b46095830d4d82e325 sequence=979 previous_record_sha256=2ceb8bb872dd7cdfea446cfd20880b7369dd0a90ce762d598b4568144be2ffac pre_append_tip_sequence=978 identity_unique=yes

Verify this reservation chain from the quoted line and invocation. Do not rerun
reservation or compare the pre-append ledger fingerprint with the appended
ledger. Run/session: 01a0863f-b335-73d3-92f7-f51867d8a947.
Fresh gpt-6-astra context, readOnly, networkAccess false, approvalPolicy never.

This is the scoped RT002 post-implementation amendment/provenance re-review,
attempt 5 round 1. Review current design and four layer documents against
requirements and acceptance criteria, using the calibration and disclosed
Amendment Re-Review Context. Historical differences alone neither waive nor
establish a content finding. No claim of TYPE-H byte-identical convergence
is supplied for amended content. No assumed PASS, live activation, ordinary
implementation, quality-gate completion or integration.

