# Implementation Policy Review: A7 attempt 5, round 1

Offline confirmation after review: both live-refresh self-test suites passed
27 assertions, including six new invocation-failure preservation assertions
per runtime (authentication failure, service failure, and valid output followed
by nonzero process exit, each with an existing and an absent target).
These exercise a local stub only, not actual provider availability or credentials.

Verdict: NEEDS_WORK
Critical: 0
Major: 3
Minor: 0

Independent reviewer A and B both returned NEEDS_WORK. The original outputs
are preserved in reviewer-a.json and reviewer-b.json. The deterministic
contract binds the exact inputs and identities. Historical Passed evidence
is not rewritten or reused to approve the changed design.

## impl-reviewer-a

### SECURITY-COVERAGE — Major

The sanctioned AC-031 external-model boundary is missing from the normative security model. design.md:1114-1136 explicitly permits an authenticated external Claude CLI call, transmitting F1/F2 inputs and extracting the returned result into corpus artifacts. However, security-spec.md:14-34 still frames the entire attack surface as local; its B1-B5 boundary table at :59-65 describes B5 as recorded-response substitution, not the live provider crossing; and :79-84 still states every actor is within the local OS/filesystem/git boundary. infra-spec.md:56-59 likewise asserts there is no network boundary. Non-gating execution does not remove this trust boundary. Carry the sanctioned exception into the security/infra refinements, explicitly model the outbound fixture and inbound model-response boundary with the existing CLI-session authentication and relevant integrity controls, and scope the local-only claims to the offline/gating paths. This is a current cross-layer coverage contradiction, not a finding based solely on amendment history.

## impl-reviewer-b

### OPEN-QUESTIONS-RESOLVABLE — Major

design.md:1191-1204 carries OQ-004 forward and specifies a concrete closure vehicle: amend AC-009, fix assert_terminal firing semantics, and extend TEST-026 on the existing harness. However, it names no role owning resolution and supplies no 'Blocks Implementation: yes/no' field. requirements.md's corresponding OQ-004 at line 919 likewise does not assign that owner. Consequently, the known-unsatisfied producer contract has an acceptance condition but no accountable resolution owner or explicit implementation-blocking disposition. Assign a resolution role and state the blocking disposition; preserve the existing concrete closure test. This is a current open-question completeness finding, not a demand to undo the documented deferral or historical amendment.

### INTEGRATION-IDENTIFIED — Major

design.md:1112-1134 explicitly permits the AC-031/T-012 live Claude refresh integration and specifies claude -p --output-format json, existing CLI-session authentication, F1/F2 inputs, and result extraction. It does not define what the refresh does when the CLI, authentication, or external service is unavailable, nor how failed or unusable responses affect the existing corpus. The parser-hard-fail rule at design.md:957-963 concerns recorded-artifact canonicalization, not an unavailable live integration. Non-gating status does not determine whether refresh fails, skips, or preserves corpus output. security-spec.md's Framing and Authentication Flow also still characterize the feature as entirely local by quoting the superseded External Integrations 'None' statement. Specify the live refresh's failure outcome and corpus-preservation behavior, and reconcile the layer description with the sanctioned external boundary.

## Scoped remedy

1. Reconcile security-spec.md and infra-spec.md with the authorized manual
   AC-031/T-012 external refresh: fixture prompts leave the local process;
   provider output is untrusted until structural validation; authentication
   stays with the existing CLI. Gating tests remain offline.
2. In design.md specify nonzero failure for unavailable CLI/auth/service or
   unusable response, with no replacement of the affected corpus file.
   Existing Bash refresh_one and PowerShell Invoke-Refresh already check
   invocation and candidate validation before replacement. Confirm both
   failure paths with offline stub regressions before relying on this claim.
   The all-fixtures operation is sequential, not an atomic two-file update;
   do not promise whole-corpus rollback without implementing it.
3. Assign OQ-004 to the A7 producer-contract maintainer and explicitly block
   closure of AC-026/final A7 acceptance until its existing concrete TEST-026
   closure condition is met. Do not falsely block unrelated implementation or
   turn the deferred producer bug into a PASS.

The review skill requires human-applied frozen-document changes between
rounds. These are proposed amendments, not changes to those documents.
No new approval request is needed for ordinary non-frozen implementation.
A subsequent fresh review must assess the actual amended inputs; no
implementation, CI, merge or Issue completion is certified by this report.
