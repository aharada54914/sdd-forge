# Tasks proposal (DRAFT, not tasks.md): Project skill observation (#594)

These are informal implementation packets for a later Phase 2 decomposition.
Nothing here is a task, an approval or a status. `tasks.md` is created only
after the spec and implementation-policy reviews pass; it then goes through
task review and human approval.

Proposed risk: high, because this is a trust boundary. The WFI-001 preflight
checklist therefore applies.

| Packet | Scope | Tests | Depends |
|---|---|---|---|
| P-1 Contracts | the two schemas and their vendored copies; finalising ADR-0040; a `PLUGIN-CONTRACTS.md` section; `CHANGELOG.md` | TEST-079, TEST-088, TEST-089, plus the schema-level rows of TEST-004–TEST-010, TEST-029–TEST-032, TEST-058/059, TEST-069/070 and TEST-075 | review passed |
| P-2 Validator | `validate-project-skill.{py,sh,ps1}`, fixtures, the suite and its catalog entry | TEST-001–TEST-060, TEST-073–TEST-075, TEST-077, TEST-082–TEST-087, TEST-090–TEST-094 | P-1 |
| P-3 Joint + compat | selected-plan joint fixtures (the test applies the projection; the evaluator is unchanged), plus non-adopter byte, structure and event checks | TEST-061–TEST-068, TEST-071, TEST-072, TEST-076, TEST-078, TEST-080, TEST-081 | P-2 |

Not included, because they belong to separate issues:
- #595: skill authoring and the trial runner.
- #596: wiring the validator and projection into Full/Lite, including putting
  the observation destination in `allowed_outputs`.
- #602: host projection.
- #605: research references.
