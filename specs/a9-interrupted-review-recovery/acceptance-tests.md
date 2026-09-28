# Acceptance Tests: a9-interrupted-review-recovery

All rows are Planned contract/integration fixtures against both spec prechecks, never the live A9 rounds. A valid fixture reproduces A9 3/2 NEEDS_WORK then 3/3 interrupted A; target 4/1. Every negative row mutates exactly the named property and asserts nonzero and unchanged input/history/status/ledger hashes. Validation rejection before publication also asserts no target output. TEST-095 instead exercises interrupted publication: any partial target is quarantined failure evidence, never a successful precheck or reusable/reset/PASS destination; separate authorized remediation is required. Run every row in Bash and PowerShell. No UI Integration Checklist: no view/dialog/menu/context action.

| AC | REQ | Test ID | Concrete fixture / assertion | Status |
|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | Valid explicit recovery creates 4/1 precheck and blank report only. | Planned |
| AC-001 | REQ-001 | TEST-002 | No recovery option for 4/1 rejects. | Planned |
| AC-001 | REQ-001 | TEST-003 | Ordinary reset on actual interrupted latest shape still rejects terminal-contract check. | Planned |
| AC-001 | REQ-001 | TEST-004 | Recovery plus reset rejects. | Planned |
| AC-001 | REQ-001 | TEST-005 | Unknown option rejects. | Planned |
| AC-001 | REQ-001 | TEST-006 | Mis-cased recovery option rejects. | Planned |
| AC-001 | REQ-001 | TEST-007 | Duplicate recovery option rejects. | Planned |
| AC-002 | REQ-002 | TEST-008 | Source round 2 while round 3 exists rejects. | Planned |
| AC-002 | REQ-002 | TEST-009 | Source attempt 2 for target 4 rejects. | Planned |
| AC-002 | REQ-002 | TEST-010 | Target attempt 5 for source 3 rejects. | Planned |
| AC-002 | REQ-002 | TEST-011 | Target round 2 rejects. | Planned |
| AC-002 | REQ-002 | TEST-012 | Passed status rejects without normalizing it. | Planned |
| AC-002 | REQ-002 | TEST-013 | Missing status rejects. | Planned |
| AC-002 | REQ-002 | TEST-014 | Unknown non-Pending status rejects. | Planned |
| AC-002 | REQ-002 | TEST-015 | Mis-cased Pending rejects. | Planned |
| AC-002 | REQ-002 | TEST-016 | Prior NEEDS_WORK contract absent rejects. | Planned |
| AC-002 | REQ-002 | TEST-017 | Prior contract malformed rejects. | Planned |
| AC-002 | REQ-002 | TEST-018 | Prior contract PASS rejects. | Planned |
| AC-002 | REQ-002 | TEST-019 | Prior contract BLOCKED rejects. | Planned |
| AC-002 | REQ-002 | TEST-020 | Prior summary missing rejects own-stage validation. | Planned |
| AC-002 | REQ-002 | TEST-021 | Prior summary counts inconsistent rejects. | Planned |
| AC-002 | REQ-002 | TEST-022 | Prior reviewer manifest inconsistent rejects. | Planned |
| AC-002 | REQ-002 | TEST-023 | Prior integrated verdict inconsistent rejects. | Planned |
| AC-002 | REQ-002 | TEST-024 | B invocation for source round rejects. | Planned |
| AC-002 | REQ-002 | TEST-025 | B ledger reservation attributable to source round rejects, even without local output. | Planned |
| AC-002 | REQ-002 | TEST-026 | B reservation receipt present rejects. | Planned |
| AC-002 | REQ-002 | TEST-027 | B raw output present rejects. | Planned |
| AC-002 | REQ-002 | TEST-028 | B host receipt present rejects. | Planned |
| AC-002 | REQ-002 | TEST-029 | Integrated summary present rejects. | Planned |
| AC-002 | REQ-002 | TEST-030 | Integrated verdict present rejects. | Planned |
| AC-002 | REQ-002 | TEST-031 | Integrated contract present rejects. | Planned |
| AC-002 | REQ-002 | TEST-032 | Completed NEEDS_WORK round as source rejects. | Planned |
| AC-002 | REQ-002 | TEST-033 | A host receipt says execution started rejects v1 shape. | Planned |
| AC-002 | REQ-002 | TEST-034 | A output asserts completed substantive review instead of unreadable-input interruption rejects. | Planned |
| AC-003 | REQ-003 | TEST-035 | Authorization file absent rejects. | Planned |
| AC-003 | REQ-003 | TEST-036 | Authorization hash wrong rejects. | Planned |
| AC-003 | REQ-003 | TEST-037 | Authorization names another feature rejects. | Planned |
| AC-003 | REQ-003 | TEST-038 | Authorization names another source rejects. | Planned |
| AC-003 | REQ-003 | TEST-039 | Authorization names another target rejects. | Planned |
| AC-003 | REQ-003 | TEST-040 | Authorization permits more than three rounds rejects. | Planned |
| AC-003 | REQ-003 | TEST-041 | Unsigned conversation copy claimed as a signed receipt rejects. | Planned |
| AC-003 | REQ-003 | TEST-042 | Orchestrator rejects launch without matching original human user-channel approval plus actual human application report for the exact content/binding digest; agent selfclaim, summary, artifact alone or human-copy log alone rejects. Validator separately rejects content/hash/binding mismatch; it does not authenticate human authorship. | Planned |
| AC-003 | REQ-003 | TEST-043 | Authorization recovery digest wrong rejects. | Planned |
| AC-003 | REQ-003 | TEST-044 | Wrong schema rejects. | Planned |
| AC-003 | REQ-003 | TEST-045 | Record feature does not match CLI feature rejects. | Planned |
| AC-003 | REQ-003 | TEST-046 | Record source attempt disagrees with actual source rejects. | Planned |
| AC-003 | REQ-003 | TEST-047 | Record source round disagrees with actual source rejects. | Planned |
| AC-003 | REQ-003 | TEST-048 | Record target attempt disagrees with CLI target rejects. | Planned |
| AC-003 | REQ-003 | TEST-049 | Record target round disagrees with CLI target rejects. | Planned |
| AC-003 | REQ-003 | TEST-050 | Missing required field (one fixture per closed-contract field) rejects. | Planned |
| AC-003 | REQ-003 | TEST-051 | Wrong type (one fixture per field; boolean/fractional/string attempt) rejects. | Planned |
| AC-003 | REQ-003 | TEST-052 | Unknown field rejects at each object level. | Planned |
| AC-003 | REQ-003 | TEST-053 | Duplicate decoded JSON member at each object level rejects. | Planned |
| AC-003 | REQ-003 | TEST-054 | Case-variant schema rejects. | Planned |
| AC-003 | REQ-003 | TEST-055 | Case-variant field rejects at each level. | Planned |
| AC-003 | REQ-003 | TEST-056 | Malformed JSON rejects. | Planned |
| AC-003 | REQ-003 | TEST-057 | Malformed/uppercase/non-64hex digest rejects (each hash slot independently). | Planned |
| AC-003 | REQ-003 | TEST-058 | Changed live requirements rejects. | Planned |
| AC-003 | REQ-003 | TEST-059 | Changed live acceptance tests rejects. | Planned |
| AC-003 | REQ-003 | TEST-060 | Changed live investigation rejects. | Planned |
| AC-003 | REQ-003 | TEST-061 | Changed live calibration rejects. | Planned |
| AC-003 | REQ-003 | TEST-062 | Missing/altered interrupted precheck rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-063 | Missing/altered A raw rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-064 | Missing/altered A allocation host receipt rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-065 | Missing/altered A reservation receipt rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-066 | Missing/altered A invocation rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-067 | Missing/altered interrupted diagnostic source report rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-068 | Missing/extra/duplicate inventory entry rejects (three fixtures). | Planned |
| AC-003 | REQ-003 | TEST-069 | Wrong persisted sequence rejects. | Planned |
| AC-003 | REQ-003 | TEST-070 | Wrong run identity rejects. | Planned |
| AC-003 | REQ-003 | TEST-071 | Wrong host-session identity rejects. | Planned |
| AC-003 | REQ-003 | TEST-072 | Wrong stage rejects. | Planned |
| AC-003 | REQ-003 | TEST-073 | Wrong role rejects. | Planned |
| AC-003 | REQ-003 | TEST-074 | Wrong record hash rejects. | Planned |
| AC-003 | REQ-003 | TEST-075 | Tampered previous hash / ledger prefix rejects (two fixtures). | Planned |
| AC-003 | REQ-003 | TEST-076 | Wrong reserved input binding rejects. | Planned |
| AC-003 | REQ-003 | TEST-077 | Duplicate persisted identity rejects. | Planned |
| AC-003 | REQ-003 | TEST-078 | Partial run/session collision rejects (each field). | Planned |
| AC-003 | REQ-003 | TEST-079 | Later valid ledger records accept; no current-tip hash requirement. | Planned |
| AC-003 | REQ-003 | TEST-080 | B absence cannot be established from manifest/ledger correlation rejects. | Planned |
| AC-003 | REQ-003 | TEST-081 | Prior contract digest wrong rejects. | Planned |
| AC-003 | REQ-003 | TEST-082 | Interrupted precheck composite input digest inconsistent rejects. | Planned |
| AC-003 | REQ-003 | TEST-083 | Empty/absolute/traversal/backslash/control-character path rejects (each reference slot). | Planned |
| AC-004 | REQ-004 | TEST-084 | Source directory symlink rejects. | Planned |
| AC-004 | REQ-004 | TEST-085 | Record symlink rejects. | Planned |
| AC-004 | REQ-004 | TEST-086 | Evidence/authorization file symlink rejects (each reference slot). | Planned |
| AC-004 | REQ-004 | TEST-087 | Output ancestor symlink rejects. | Planned |
| AC-004 | REQ-004 | TEST-088 | Any intermediate input ancestor symlink rejects (each reference slot). | Planned |
| AC-004 | REQ-004 | TEST-089 | Existing target directory rejects. | Planned |
| AC-004 | REQ-004 | TEST-090 | Existing target file/dangling symlink rejects (two fixtures). | Planned |
| AC-004 | REQ-004 | TEST-091 | Two concurrent writers: one success maximum, loser nonzero, no old mutation. | Planned |
| AC-004 | REQ-004 | TEST-092 | Pin changes after pure validation before locked recheck reject. | Planned |
| AC-004 | REQ-004 | TEST-093 | Latest round advances before locked recheck rejects. | Planned |
| AC-004 | REQ-004 | TEST-094 | Target appears before locked recheck rejects. | Planned |
| AC-004 | REQ-004 | TEST-095 | Writer failure is nonzero; release own lock and preserve history. Any partial target is quarantined failure evidence with no successful precheck, automatic cleanup/reuse/reset/PASS; rerun rejects it until separate authorized remediation. | Planned |
| AC-004 | REQ-004 | TEST-096 | Success preserves hashes of all historical rounds, inputs, status, ledger and creates no new reservation/verdict. | Planned |
| AC-005 | REQ-005 | TEST-097 | New saved provenance record path/hash matches exact recovery bytes; altered provenance rejects consumption. | Planned |
| AC-005 | REQ-005 | TEST-098 | Recovery provenance alone cannot satisfy spec PASS. | Planned |
| AC-005 | REQ-005 | TEST-099 | Legacy precheck without recovery field retains existing acceptance rules. | Planned |
| AC-005 | REQ-005 | TEST-100 | Existing normal-reset suite unchanged and passes including PASS/BLOCKED reset. | Planned |
| AC-005 | REQ-005 | TEST-101 | Both downstream precheck suites and parity suite preserve PASS/hash behavior. | Planned |
| AC-005 | REQ-005 | TEST-102 | Loop driver/inventory/consistency/escalation suites in both runtimes pass. | Planned |
| AC-005 | REQ-005 | TEST-103 | PowerShell operator sweep and mis-cased schema negative match Bash. | Planned |
| AC-005 | REQ-005 | TEST-104 | Independent cmdlet/language sweep and mis-cased filename negative match Bash. | Planned |
| AC-005 | REQ-005 | TEST-105 | Missing runtime/prerequisite rejects; unavailable PowerShell is unverified, never pass. | Planned |
| AC-005 | REQ-005 | TEST-106 | Test source avoids contiguous banned markers; existing detection gates have no new self false positive. | Planned |
| AC-005 | REQ-005 | TEST-107 | Prompt calibration, layer inputs, guard ASCII/invariants and compatibility event traces remain compatible. | Planned |

Parameterized rows explicitly cover finite field/path sets enumerated in the recovery contract. Each parameter must be a separately named runtime case in implementation evidence; no sampling. Existing own-stage negative fixtures supplement TEST-017/020-023, not replace them. No results are claimed at preparation time.

## Explicit field and reference expansion

Each ID below is a separate case on each runtime, with the same nonzero/no-mutation oracle. Array labels identify their canonical path entries, not new JSON keys. `precheck.recovery` tests consumption after a valid publication. These rows expand TEST-050/051/057/083/086/088/097; none is a sample.

| Missing-field ID | Wrong-type ID | Exact field | Concrete negative mutation |
|---|---|---|---|
| TEST-050-F01 | TEST-051-F01 | schema | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F02 | TEST-051-F02 | feature | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F03 | TEST-051-F03 | source | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F04 | TEST-051-F04 | source.attempt | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F05 | TEST-051-F05 | source.round | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F06 | TEST-051-F06 | target | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F07 | TEST-051-F07 | target.attempt | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F08 | TEST-051-F08 | target.round | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F09 | TEST-051-F09 | authorization | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F10 | TEST-051-F10 | previous_contract | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F11 | TEST-051-F11 | interrupted_precheck | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F12 | TEST-051-F12 | pinned_inputs | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F13 | TEST-051-F13 | interrupted_artifacts | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F14 | TEST-051-F14 | reviewer_a | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F15 | TEST-051-F15 | reviewer_a.invocation | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F16 | TEST-051-F16 | reviewer_a.sequence | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F17 | TEST-051-F17 | reviewer_a.stage | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F18 | TEST-051-F18 | reviewer_a.role | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F19 | TEST-051-F19 | reviewer_a.run_id | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F20 | TEST-051-F20 | reviewer_a.host_session_id | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |
| TEST-050-F21 | TEST-051-F21 | reviewer_a.record_sha256 | Delete field / replace with null; integer fields additionally string, boolean, fractional; arrays additionally object; objects additionally array. |

| Path case | Hash case | Exact reference slot | Concrete assertions |
|---|---|---|---|
| TEST-083-P01, TEST-086-P01, TEST-088-P01 | TEST-057-H01 | authorization | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P02, TEST-086-P02, TEST-088-P02 | TEST-057-H02 | previous_contract | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P03, TEST-086-P03, TEST-088-P03 | TEST-057-H03 | interrupted_precheck | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P04, TEST-086-P04, TEST-088-P04 | TEST-057-H04 | pinned_inputs.requirements | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P05, TEST-086-P05, TEST-088-P05 | TEST-057-H05 | pinned_inputs.acceptance | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P06, TEST-086-P06, TEST-088-P06 | TEST-057-H06 | pinned_inputs.investigation | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P07, TEST-086-P07, TEST-088-P07 | TEST-057-H07 | pinned_inputs.calibration | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P08, TEST-086-P08, TEST-088-P08 | TEST-057-H08 | interrupted_artifacts.precheck | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P09, TEST-086-P09, TEST-088-P09 | TEST-057-H09 | interrupted_artifacts.a_raw | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P10, TEST-086-P10, TEST-088-P10 | TEST-057-H10 | interrupted_artifacts.a_reservation | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P11, TEST-086-P11, TEST-088-P11 | TEST-057-H11 | interrupted_artifacts.a_host_receipt | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P12, TEST-086-P12, TEST-088-P12 | TEST-057-H12 | interrupted_artifacts.diagnostic_report | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P13, TEST-086-P13, TEST-088-P13 | TEST-057-H13 | interrupted_artifacts.a_invocation | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P14, TEST-086-P14, TEST-088-P14 | TEST-057-H14 | reviewer_a.invocation | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |
| TEST-083-P15, TEST-086-P15, TEST-088-P15 | TEST-057-H15 | precheck.recovery | Independently reject empty, absolute, traversal, backslash, control path, leaf symlink, ancestor symlink; independently reject missing/null/uppercase/nonhex/short/incorrect SHA256. |

Closed-object unknown/duplicate/mis-cased key cases TEST-052/053/055 run separately for the root, source, target, reviewer_a, every reference slot above, and saved precheck.recovery. For each use `unexpected`, duplicate `path` (including Unicode-escaped alias where applicable), and an uppercase variant of one required key. Each concrete variant's runtime case name appends its object slot and mutation name; all listed combinations are mandatory. Authorization line tests independently remove, duplicate and change each binding below; every mutation rejects before publication with no target. No executed results are claimed.

| TEST-ID | Binding | Required value |
|---|---|---|
| TEST-050-A01 | Feature | recovery record feature |
| TEST-050-A02 | Source Attempt | recovery record source.attempt |
| TEST-050-A03 | Source Round | recovery record source.round |
| TEST-050-A04 | Target Attempt | recovery record target.attempt |
| TEST-050-A05 | Target Round | exactly 1, matching target.round |
| TEST-050-A06 | Maximum Rounds | exactly 3 |
| TEST-050-A07 | Decision | exactly `Authorize interrupted A-before-B recovery` |
| TEST-050-A08 | Recovery Binding SHA256 | lowercase 64-hex canonical record digest defined in requirements.md |
