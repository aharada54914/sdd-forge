# Issue #423 T-002 final-input path-safety check — 2026-10-05

Non-formal, read-only check of `reports/verification/issue423-t002-evaluator-input-candidate-20261005-final.json` in the owner checkout. No protected apply, reservation, evaluator, Git operation, or publication.

`rtk proxy python3 -c '...'` (login=false) parsed the candidate and checked each of its 72 allowed-input rows and two metadata rows for relative paths without `.`/`..`, in-checkout resolved location, no symlink component, regular-file type, and SHA-256 equality with current bytes. It also checked uniqueness within the allowed-input array. Final result: exit 0; 72 allowed rows/72 unique paths, two metadata rows, one intentional metadata overlap with the allowed implementation manifest, zero invalid paths/types/hashes. The first two diagnostic attempts exited 1 because their checker incorrectly treated that cross-section overlap as an invalid duplicate; the corrected indexed check exited 0. No candidate defect is inferred from those diagnostics.

The three still-unapplied guarded targets retain their recorded before hashes (`rtk proxy shasum -a 256 -- ...`, exit 0):

| Target | Current SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a` |

This closes only an untested path-safety question for the current preparation candidate. The protected filename-binding apply, post-apply regressions, normal caller admission, fresh evaluator and Done decision remain unperformed. Prior 34/43-test results were not rerun.
