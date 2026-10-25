# Tasks proposal: Research evidence foundation (#605)

DRAFT / Planned. This is an informal decomposition for later Phase 2, not
`tasks.md`, a task approval, or execution authorization. Spec and implementation
reviews remain Pending. Create the actual Draft task plan only after those
reviews, then run task review and obtain selected human approvals.

Proposed risk: high because records carry provenance, rights assertions and
untrusted data. The existing WFI-001 field/counterpart/negative-test preflight
applies before later implementation. No current task is marked Approved/Done.

| Packet | Proposed scope | Acceptance | Depends |
|---|---|---|---|
| P-1 | Finalize the contract/ADR under review; root/packaged schema, contract docs, shape fixtures | AC-001, AC-002, AC-014 | normal reviewed/approved task prerequisites |
| P-2 | Passive validator and transparent wrappers; identity/history/status/hash/quote/path/secret checks | AC-003–AC-010, AC-012 | P-1 |
| P-3 | Reference-interface fixtures, non-adopter compatibility, catalog/doc synchronization | AC-011, AC-013, AC-014 | P-2 |

TEST rows in acceptance-tests.md owned by #605 are the proposed local suite.
AC-015 and AC-016 rows are downstream consumer obligations; P-3 publishes
the contract fixtures and clearly marks their runtime execution pending. It
does not implement #606 acquisition/cache/egress, #607 source comparison,
#612 graph, #609 review wiring or #610 HTML/export. #594 requires interface
coordination only and is not a completion prerequisite.

Before review/integration recheck ADR numbering (0039 #614, 0040 #594,
0041 this proposal), shared schema helper behavior, catalog/jobs, upload globs
and current explicit-path collectors. Record unavailable OS/hosts as unverified
in later implementation evidence, never by rewriting frozen specifications.
