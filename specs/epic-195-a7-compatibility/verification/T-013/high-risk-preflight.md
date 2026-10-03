# T-013 High-Risk Persisted-Evidence Preflight

Recorded before implementation, as required by WFI-001.

| Persisted evidence field | Sibling contract / traceability counterpart | Failing mismatch test written before implementation |
|---|---|---|
| Bash/PowerShell case tally: three cases each | `acceptance-tests.md` TEST-040 plus TEST-041's two independent branches; `tasks.md` T-013 Done When twin-tally clause | RED twins deliberately omit all three enforcement checks; their expected three-case oracle reports `0 passed, 3 failed` in both runtimes |
| AC-040 workflow-scan verdict for both forbidden command fragments | REQ-006 AC-040; `design.md` Golden-baseline capture/promote contract; `security-spec.md` B1 | RED workflow fixtures contain each forbidden fragment while a deliberately permissive scan accepts them; each branch must fail its hard-fail oracle |
| AC-041 `CI`-set exit status and before-I/O guarantee | REQ-006 AC-041; the leading `CI` guard in `tests/promote-golden-baseline.{sh,ps1}` | RED permissive promote stubs return zero and touch both read/write probes when `CI` is non-empty; the refusal oracle must fail |
| AC-041 missing/empty `--approved-by` exit status and canonical no-write guarantee | REQ-006 AC-041; the approval guard in `tests/promote-golden-baseline.{sh,ps1}` | RED permissive promote stubs return zero and overwrite a canonical sentinel when approval is omitted; the refusal oracle must fail |
| Suite registration in both aggregate runners | T-013 Planned Files and Done When; `traceability.md` T-013 deliverables row | Post-implementation registration check compares the exact Bash and PowerShell entries; removing either entry in a temporary runner copy must make the check fail |
| T-013 implementation status and REQ-006/AC-040/AC-041 evidence claim | `tasks.md` T-013 lifecycle; `traceability.md` REQ-006/T-013 and AC mapping rows | Post-implementation metadata check requires `Status: Implementation Complete` and the exact T-013 mapping; a temporary mismatched status/mapping must fail |

No production implementation begins until the genuine RED runs record all
three missing enforcement checks in both runtimes.
