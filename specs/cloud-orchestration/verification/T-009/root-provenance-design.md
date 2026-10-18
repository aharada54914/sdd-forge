# T-009 provenance boundary design clarification

This is root design guidance within approved REQ-008/AC-008, not a spec change, waiver, completed test or independent review.

Grounding: design.md Data Plan explicitly says hashes identify integrity rather than authority; Public Invocation Contract says verify consumes authenticated observations. cloud_verification.py:425 publish_collection receives actual collector results and calls reduce with the existing in-process native decision. Both provider observe functions establish fresh federation, original native operation and transport identity before this call. The saved evidence manifest explicitly says saved_receipt_authorizes_nothing. T-009 is protected profile dispatch; T-010 owns predecessor receipt admission.

Desired caller: the existing trusted, governed fresh-collection path selects the protected versioned profile and computes the applicable IaC/provider checks. The file-only legacy consumers preserve legacy semantics; an explicit cloud branch may validate selection/integrity but must not emit an overall successful cloud gate on saved native/PASS labels alone.

Compared shapes:
1. Trust saved result labels/digests: rejected; not provenance.
2. Introduce an issuer/signing policy or a second generic artifact authority: unnecessary new trust root and scope. Existing authenticated GitHub artifact acquisition can be reused where T-010 needs cross-run receipts, with exact successful verify-job/code/request binding; artifact existence alone is insufficient.
3. Reuse the existing in-process fresh authenticated collector boundary for the positive cloud path, and connect deterministic protected profile selection/reduction there. Prefer this small seam. Public file-only consumers fail closed when fresh trusted context is absent; they do not promote synthetic records or local approval flags. Selection tests can be positive without claiming a live deployment gate. Explicitly distinguish schema/selection success from authoritative overall health PASS.

Implement option 3 if supported by the actual callers, including the smallest necessary cloud_verification/provider-call integration seam within T-009; this is profile dispatch, not new provider execution or dependency scheduling. Root approval covers this required integration, but no requirement is waived. Preserve the old profile version/default and required legacy check sets. No new public trust boolean/CLI override or result-file authority. The authenticated native path must be reachable through the real governed collector, not an uncalled helper or an always-BLOCKED implementation. Synthetic tests retain synthetic public status; real cloud acceptance remains blocked by missing sandbox.

If current code makes this small seam infeasible, report the exact conflicting callable/contract rather than inventing an authority or pausing all unrelated profile inventory/tests. Root will resolve against approved existing trust boundaries.
