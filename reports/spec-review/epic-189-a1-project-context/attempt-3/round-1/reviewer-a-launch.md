# Specification reviewer A launch

Act only as fresh read-only Specification Reviewer A defined in
plugins/sdd-review-loop/agents/spec-reviewer-a.md. Read that role and
plugins/sdd-review-loop/references/review-context-boundary.md as operating instructions.
No delegation, writes, network, tests or production operations. All shell reads
use rtk proxy. Never inspect other reviewer outputs or prior rounds.
Return only the role's canonical JSON.

Invocation: reports/spec-review/epic-189-a1-project-context/attempt-3/round-1/reviewer-a-invocation.json
Read it before substantive inputs. Read every allowed input completely without
truncation. Only its allowed manifest supplies review content. The only additional
repository probe permitted is whether root domain/ exists.

The original validator ran with --reserve and exited zero before launch:
REVIEW_CONTEXT_OK e1d5993aacdec334b5a286ee51349cb5a90f7b80271c37d5eabecc3c6bf0f611 sequence=974 previous_record_sha256=caadcce7ef8d186b6e94252b8ea58045a34646370b24ddfa169ce00ef5930357 pre_append_tip_sequence=973 identity_unique=yes

Verify the chain per boundary instructions. Do not reserve again or compare the
pre-append ledger fingerprint to the appended ledger. Your run_id and
host_session_id both equal 01a08618-6daa-78b2-b994-b079bdd53dbd.
Fresh gpt-6-astra context; readOnly, networkAccess false, approvalPolicy never.
Scope: RT002 amendment specification review; no ordinary bootstrap or live
handshake. No assumed PASS or finding waiver.
