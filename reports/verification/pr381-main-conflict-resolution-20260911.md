# PR381 main integration conflict verification

Source PR head: 63f735dc2dbdbac9a81f2a25ac210189df11ea49.
Merged main input: e08ea8847876db4604993031c120e57875385511.

The normal no-commit merge produced five conflicts. Each was inspected;
resolution retains the already-merged PR407 implementation in full:

- traceability.template.md retains Investigation provenance alongside Layer Spec.
- validate-layer-traceability.py and .ps1 accept canonical Requirement and legacy
  REQ-ID only in the first column, and reset table discovery on every non-pipe line.
- bootstrap-cross-layer-index.tests.sh retains legacy-header and H1-H6 boundary regressions.
- loop-driver.tests.sh uses a mis-cased req-id negative fixture; valid legacy REQ-ID is not rejected.

All five resolved files are byte-identical to the main input (git diff empty).
Reviewer role inspection found no new Critical issue in this conflict resolution.
This is not an approval review or a quality-gate verdict for the entire PR.

Executed on macOS with PowerShell available:

- `rtk proxy bash tests/bootstrap-cross-layer-index.tests.sh`: 54 PASS, 0 FAIL,
  including both Python and PowerShell branches.
- `rtk proxy bash tests/loop-driver.tests.sh`: 26 passed, 0 failed, 1 second;
  real spec-review fixture rounds executed, not skipped.
- `git diff --check` and `git diff --cached --check`: exit 0.
- `git diff --name-only --diff-filter=U` after staging five resolutions: empty.

Existing unstaged deterministic-lane-selfcheck changes and untracked CI repair
bundle were preserved, not included in this merge. The protected workflow batch
has not been applied. Known CI registration/mirror/aggregate issues therefore
remain; this local integration must not be represented as CI success or a
merge-ready PR. Third-party approval remains required for PR381.
