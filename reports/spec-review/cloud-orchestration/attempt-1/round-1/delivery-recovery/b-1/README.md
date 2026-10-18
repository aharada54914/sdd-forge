# Rejected delivery B-1

The orchestrator used the wrong schema identifier in the sanitized summary.
This delivery is not admitted as review evidence. Its real identity reservation
remains consumed in the canonical ledger; no records were deleted or reused.
The original summary and raw delivery are preserved here byte-for-byte. Its
manifest refers to the original canonical summary path with the old digest;
that path now holds the corrected summary for a fresh B invocation. Thus the
archived invocation is historical rejected evidence, not a current valid binding.
No substantive specification, A input, A output or precheck changed. Fresh B
will receive only the corrected sanitized summary, never the rejected findings.
The product finding about dependency failure and no-op coverage is retained in
the raw output and must not be suppressed during subsequent review.
