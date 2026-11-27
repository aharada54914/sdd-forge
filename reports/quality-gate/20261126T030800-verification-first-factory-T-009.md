Task ID: T-009
Feature: verification-first-factory
Run ID: 20adf5b4-3569-410d-9990-67923dddd87d
VERDICT: NEEDS_WORK
Critical: 0
Major: 1
Minor: 0

# T-009 independent quality gate · first integration review

- **VERDICT**: FAIL
- Reviewed commit `cd27d0a4a90bd4cede2197072aeac5b8625dc258`, ledger sequence 1197, evaluator session `01a21390-1bcf-7e92-bec4-0c2a7c389d30`.
- The reviewer confirmed all 20 admitted input hashes. The mechanical run `920911b0-a741-4bd1-9838-3848d0216596` had clean specification drift and four successful commands. The package suite passed 369/369, stdio passed 25/25 and Wave 3 passed 10/10.
- AC-012 and AC-013 were evaluated against the release contract and five measured paths. All 25 candidate/release pairs agreed on exit status, with a maximum increase of 113.64 ms.

| Perspective | Result | Evidence |
|---|---|---|
| G1 — acceptance and Done When | FAIL | The install test used FilesOnly and skipped host installation. It could pass even if MCP registration defaulted to on for a real host. NFR-003 requires default off. |
| G2 — scope and amendments | PASS | The reserved task inputs matched the specification. |
| G3 — regression and failures | PASS | The package, protocol, integration and differential receipts were verified. |
| G4 — non-functional behavior | PASS | Read-only tools and configured diagnostic adapters were checked. |
| G5 — domain and design system | N/A | This task changes neither the domain model nor the UI. |

## Required repair

Exercise the default installation against a registrable isolated host and observe zero registrations. Enable `--with-mcp` on that host and observe the expected server registration. Task status at this decision remained `Implementation Complete`.

## Non-checks

The five measured paths cover one local environment. The broad legacy runtime profile is tracked under T-010. This review did not qualify a deployed host.
