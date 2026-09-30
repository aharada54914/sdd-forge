# Traceability: SDD context continuity

Status: Partial implementation; acceptance and native completion remain unverified.

The current specification/design lineage is spec a2r3 and impl a3r1; earlier
contracts remain historical. The revised task plan requires fresh provenance
review. Code paths below describe ownership, not completed implementation or
executed acceptance. Verification finalization belongs to non-frozen feature
addenda after task-stage binding.

| Requirement | Acceptance | Tests | Layer Spec | Tasks | Planned code / contract | Status |
|---|---|---|---|---|---|---|
| REQ-001 | AC-001–003, AC-015 | TEST-001–003, TEST-047–050 | infra-spec.md#scaling-strategy; security-spec.md#trust-boundaries | T-001, T-002, T-006, T-007 | contracts/sdd-context; plugins/sdd-context privacy/store | Planned |
| REQ-002 | AC-001–003, AC-005, AC-018 | TEST-001–003, TEST-009–011, TEST-063–064 | ux-spec.md#interaction-sequence; frontend-spec.md#state-shape | T-002, T-003, T-007 | journal/decisions/recovery | Planned |
| REQ-003 | AC-004, AC-011 | TEST-004–008, TEST-036–037, TEST-065, TEST-067 | frontend-spec.md#api-client-strategy | T-004, T-008, T-007 | separate Claude (T-004) / Codex (T-008) adapters | Planned |
| REQ-004 | AC-005–006 | TEST-009–018 | frontend-spec.md#state-shape | T-003, T-007 | authority/projection; existing parseTaskState | Planned |
| REQ-005 | AC-007, AC-016 | TEST-019–023, TEST-052–056, TEST-062 | security-spec.md#authorization | T-001–003, T-005–007 | owner/path/registry; existing root/path interpretation | Planned |
| REQ-006 | AC-008, AC-017 | TEST-024–026, TEST-057–059, TEST-066 | infra-spec.md#scaling-strategy | T-002, T-005–007 | serialized store/cleanup | Planned |
| REQ-007 | AC-009–010, AC-015 | TEST-027–035, TEST-047–051 | ux-spec.md#component-states; frontend-spec.md#performance-budget | T-002, T-004, T-008, T-007 | failure outcomes/host feedback | Planned |
| REQ-008 | AC-011 | TEST-036–037 | frontend-spec.md#testing | T-004, T-008, T-007 | separate native registrations/serializers | Planned |
| REQ-009 | AC-013–014, AC-016 | TEST-041–043, TEST-044a–i, TEST-045a–i, TEST-046a–c, TEST-052–056 | infra-spec.md#data-residency-and-retention; security-spec.md#secrets-management | T-001–003, T-005–007 | privacy/expiry/cleanup/scheduler | Planned |
| REQ-010 | AC-018 | TEST-060, TEST-063–064 | frontend-spec.md#performance-budget; ux-spec.md#navigation-map | T-003, T-004, T-008, T-007 | bounded recovery/serializer | Planned |
| REQ-011 | AC-006, AC-018 | TEST-012–018, TEST-061–062 | frontend-spec.md#component-tree | T-003, T-007 | existing MCP task/root/path parser + build entry | Planned |
| REQ-012 | AC-012, AC-015 | TEST-038–040, TEST-047–051 | infra-spec.md#rollback; ux-spec.md#component-states | T-001, T-004–008 | existing installer/internal bundle | Planned |

TEST-044/045/046 parent rows and all suffix branches remain part of acceptance;
range notation is inclusive. No task waives any acceptance row. T-006 owns only
delivery integration; T-007 reconciles the complete test inventory and release
evidence, while primary tasks supply their specific evidence.

## Investigation lineage

| Evidence IDs | Decision / reuse | Tasks | Status |
|---|---|---|---|
| INV-001–006 | Files remain authority; reuse parser/root/path; MCP readonly regressions | T-003, T-007 | Planned |
| INV-007–008, INV-011–014 | Existing enforcement is not lifecycle proof; separate actual hosts and no-SDD fallback | T-004, T-006–008 | Planned |
| INV-009–010 | Fresh materialization, ownership/integrity/retry boundary | T-001–003 | Planned |
| INV-015 | Effective ignore/tracked refusal; installer provisioning only | T-001, T-006 | Planned |
| INV-016–017 | Transport-free build, preserve read errors vs absence | T-003, T-006, T-007 | Planned |

No BL identifiers exist for this feature-mode investigation. Baseline facts are
reverified at consumption, not treated as permanent shared-state truths.

## Open-question ownership and evidence destination

| Question | Tasks | Evidence required | Status |
|---|---|---|---|
| OQ-001–004 | All | Human choices already resolved; do not reopen 30-day deletion/redaction/warn-continue/local ownership | Resolved policy; implementation Planned |
| OQ-005 | T-002, T-004, T-008 | Actual stable ID/retry observations; otherwise preserve deliveries | Pending |
| OQ-006 | T-002, T-005 | Native three-OS sync/replace/crash/lock guarantees and limits | Pending |
| OQ-007–008 | T-004, T-008 | Actual schemas, coverage, registered lifecycle, safe barrier/warning visibility | Pending |
| OQ-009 | T-001, T-005 | Native owner/path/ACL/Git positive and negative tests | Pending |
| OQ-010 | T-005 | Actual daily/catch-up/failure scheduler triggers per OS | Pending mechanism; policy resolved |
| OQ-011 | T-001 | Exact rule-v1 synthetic all-path verification; design review already passed, execution not performed | Pending execution |
| OQ-012 | T-003, T-004, T-008 | Escaped UTF-8 final size, core deadline and native termination/input limits | Pending execution |

ADR-0033 is Proposed design authority, not implementation approval. Future schema
artifacts derive from design Data/API Plans, not new unapproved contract choices.
Public evidence is synthetic/content-free and repo-relative; private journals,
transcripts, personal data, secrets and absolute ownership paths are excluded.
