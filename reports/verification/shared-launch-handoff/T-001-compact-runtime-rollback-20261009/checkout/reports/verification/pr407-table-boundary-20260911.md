# PR407: supplementary-table boundary regression

Issue: #289. Reviewed base HEAD: 4d8213e566e6ab5b362ed0a302adab04ca5fae67.

## Root cause and repair

Both validators retained the active traceability table and column index across
non-pipe lines other than blank lines and literal H2 headings. A valid table
followed immediately by H1 or H3–H6 and a Requirement/Notes table therefore
treated unrelated prose as a Layer Spec. Reset both fields at non-pipe lines;
later supported headers establish their own column layout. No accepted header,
anchor/exclusion, requirement coverage, input-substitution, or CI check is removed.

## Reproduction and verification

On macOS, using actual Python and PowerShell processes:

- `sh tests/bootstrap-cross-layer-index.tests.sh` before production edits:
  34 passed, 20 failed, exit 1. Failures named supplementary prose as an invalid
  Layer Spec. Negative cases also checked the expected invalid-anchor diagnostic,
  so a premature unrelated failure could not pass.
- Identical command after edits: 54 passed, 0 failed, exit 0.
- Added 24 checks: six heading levels × two subsequent anchor cases × two
  runtimes. They cover ignoring the supplementary table and re-entering a
  supported table with a different column layout. Existing 30 checks retained.
- `sh tests/task-layer-review-inputs.tests.sh`: 9 checks passed, exit 0.
- `pwsh -NoProfile -File tests/task-layer-review-inputs.tests.ps1`:
  7 checks passed, exit 0.
- `git diff --check`: exit 0.

## Independent review

Standalone adversarial reviewers `/root/pr407_pilot_a` and
`/root/pr407_pilot_b` independently reported the same MEDIUM issue (A-1/B-1).
Both resumed contexts supported the other's finding with code citations; no
additional findings arose. Root consolidated these into one repair, directly
within Issue289's supplementary-table objective. Formal REQ/AC/task IDs were
not supplied for this extracted fix; none were invented.

Fresh reviewer `/root/pr407_fix_verify` returned VERIFIED, citing Python34–37,
PowerShell26–29, and test150–182. No new issues identified. That reviewer read
the source but did not run the temporary-file-writing suite; execution results
above are the implementer's actual runs, not independent runtime verification.
Native agent IDs are not SDD ledger reservations or GitHub approvals.

Latest-commit CI, required third-party approval, safe merge, main verification,
and Issue closure remain separate obligations. Earlier-head CI is not evidence
for this change; this document does not set an SDD task or review status.
