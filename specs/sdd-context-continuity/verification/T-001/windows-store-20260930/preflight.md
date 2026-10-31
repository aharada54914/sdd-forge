# T-001 Windows new-store slice preflight

Run ID: windows-store-20260930
Task Attempt Count: 1
Source: c0cf516b3cea89bde5912c7fa6aef9f5438e95d0
Carried correction budget: 2/3; one remains.

No conversation/entity fields are persisted by this slice; only an empty new directory and sanitized verification evidence are produced. Before production:

| Evidence/property | Counterpart | Failing mismatch check |
|---|---|---|
| Windows dispatch after owner/path/Git validation, then revalidation | security-spec.md authorization; existing validate entrance | WINDOWS-DISPATCH: synthetic module dependencies record validation before/after native adapter; absent dispatch fails |
| Native creator timeout uses remaining monotonic core deadline | security-spec.md 1000ms core budget | WINDOWS-BUDGET: exhausted remaining budget cannot invoke adapter |
| Adapter receives only fixed owned store path and remaining timeout | design.md fixed .sdd/context locator | WINDOWS-ADAPTER: native process arguments/timeout are checked with synthetic child-process dependency |
| Native failure/output is content-free validation-rejected | security-spec.md B4 | WINDOWS-FAILURE: adapter failure rejects without native exception fields |
| Created owner=current token SID, protected DACL, current SID only Allow; existing target never changed | security-spec.md restrictive creation and no existing repair | WINDOWS-NATIVE: runnable Windows-only helper acceptance verifies ACL/owner and preexisting ACL/content preservation; opened identity is checked by the helper but still needs real Windows verification |
| RED/GREEN result, environment and source provenance | tasks.md TDD requirement; this record | Recorded output is actual synthetic macOS behavior, never native Windows proof |

Tests use real production module source with synthetic dependency modules to exercise Windows dispatch on macOS; this cannot prove Win32 ACL, junction or opened-identity behavior. No same-SID ancestor-race immunity, installer provenance, T-001 completion or quality-gate verdict is claimed. Frozen specifications and the three preexisting dirty files are preserved.

Native Windows end-to-end `prepareStore` with a real `OwnerV1` and elapsed-time assertion under the existing 1000 ms core deadline is pending. A cold `pwsh` process plus `Add-Type` compilation may exceed that budget; no timeout extension or native success is inferred from the synthetic tests.
