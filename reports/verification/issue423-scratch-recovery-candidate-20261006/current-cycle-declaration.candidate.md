# Issue 423 T-002 scratch recovery: current-cycle declaration candidate

Draft only. This file is outside `reports/quality-gate/` and is **not** a valid
`gate_report_declaration` target. It does not identify or authorize a current
cycle, reserve an identity, admit inputs, or issue a review verdict. Preserve
the existing quality-gate declarations and historical report unchanged.

Proposed independent source-inspection reference:
`reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.source-inspection.candidate.md`,
SHA-256 `7cb1e2731938d8a2cb1f8bb035ce3bcf5cc93223fb200966b87a70c1c9bafe1f`.
That record inspected native tool-level owner and report-creation observations;
it is candidate recovery evidence, not a formal quality-gate decision or a
signature. Before adoption, the authorized independent recovery reviewer must
confirm this record and its native source for the actual current cycle. The
normal launcher must verify that cycle relationship before constructing inputs.

## Post-Fix Artifacts

| Path | SHA-256 |
|---|---|
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md` | `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462` |
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.scratch-owner.json` | `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.owner-observation.candidate.json` | `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679` |

The adjacent receipt row is a **future target**. Its exact candidate bytes now
exist only at `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.scratch-owner.candidate.json`;
the declared adjacent file does not exist and must not be treated as admitted.
Any changed bytes require fresh digests and review. After separately authorized
contract/protected adoption and canonical receipt placement, a new declaration
under `reports/quality-gate/` must pin these actual files, cite the completed
independent recovery review, be itself hash-bound as `gate_report_declaration`,
and bind all three paths in the invocation's `allowed_input_manifest`.
