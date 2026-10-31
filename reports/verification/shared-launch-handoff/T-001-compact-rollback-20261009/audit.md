# T-001 current compact caller: isolated rollback diagnostic

Delegated scope: approved T-001 current-code rollback verification only. Risk is
high; this is not a formal evaluator verdict. Owner source, old evidence, ledger,
task lifecycle and Git index are outside the write scope. All writes are confined
to this new directory. `context.json` records owner HEAD, dirty status and source
evidence hashes before candidate application. `target-hashes.json` pins the 22
candidate/baseline files, including supplemental-delivery-inputs.py so the
validator's optional caller dependency is not omitted from the delivered set.
Compact verification itself is implemented in validate-nontty-spec-launch.py,
not an unlisted external helper. validate-facet-manifest.py and the remaining
shared baseline dependencies are retained in the copied baseline checkout.

Preflight persisted-field checks:

| Field | Counterpart | Mismatch assertion |
| --- | --- | --- |
| Candidate SHA-256 | Pinned current owner bytes | check-candidate rejects any difference |
| Baseline SHA-256 | Immutable old disposable files | check-restored rejects changed or undeleted additions |
| Restored 26 hashes | Original before-hashes.json inputs | assert26 rejects missing, changed, or extra-count rows |
| Test exit values | Complete per-suite stdout/stderr | nonzero suite status makes tests mode fail |
| Owner and old evidence preservation | Initial hashes | each phase rechecks target source hashes and all 26 old hashes |

Procedure: copy the existing Git rollback baseline into checkout; verify all 26
original hashes; apply generated patch using apply_patch; check candidate hashes;
run six candidate suites; restore using apply_patch; check all 26 original hashes
and baseline/absence for 22 targets; run four baseline suites. TMPDIR is local to
this output and Python bytecode is disabled. The disposable checkout has its own
Git object store, no alternates/commondir. No host installation or native review
launch is exercised. Existing high-risk governance and official evidence remain
unchanged.

## Executed result

The first apply_patch was refused by ordinary 0444 copied file permissions before
any candidate target was changed. All 26 original hashes and 22 baseline targets
were rechecked successfully. After the owner completed its two typing corrections,
refresh-candidate pinned final hashes and made only disposable target copies
owner-writable. apply_patch then succeeded and check-candidate matched all 22
targets. No hook/executor bypass was used. The copied baseline modes were restored
after rollback.

Final transport SHA-256:
`9b635597729d85e4808b850c76961af2c0853213d40e52bf7a88efa4580b6d70`.
Final probe SHA-256:
`83abc29c14dc199a399ff7a92c19235e1c5ddc7688f98dbc46f39fa1f39db33c`.
Target inventory SHA-256:
`7ac191b2615cb4f62596b827df698a541d2b6b56e8a71f4409c2449571ffb4cd`.

| Suite | Current caller on old runtime baseline | Restored baseline |
| --- | --- | --- |
| quality-nontty-transport | 20 tests, exit 0 | 18 tests, exit 0 |
| host-review-preflight | 7 tests, exit 0 | 7 tests, exit 0 |
| unified-task-launch | 9 tests, exit 0 | 9 tests, exit 0 |
| unified-launch-order | 9 tests, 6 failures, exit 1 | 8 tests, exit 0 |
| review-conditional-inputs | 16 tests, 7 failures, exit 1 | Not a baseline suite |
| shared-launch-build | 1 test, exit 0 | Not a baseline suite |

The two failed current-caller suites exercise conditional admission against old
PowerShell runtime bytes. Examples: domain/context-map.md is rejected as
role-unlisted, while omit-all is incorrectly accepted. This mixed-version run is
not a current integrated candidate PASS. Logs preserve each failing assertion;
it does not justify changing criteria, skipping checks, or claiming formal failure
of untested native delivery. A separate current-runtime fixture would need the
current paired validators and their call dependencies before repeating the tests.

The candidate was restored using restore.patch with apply_patch. All 26 original
before-hashes match, all 22 targets match baseline bytes or expected absence,
original modes are restored, and owner/baseline inputs are unchanged. All four
restored-baseline suites pass (42 tests total). check-restored was rerun after
baseline testing and passed. See candidate-results.json, restored-results.json,
restored-26-hashes.json, check-restored.json and the complete phase-suite logs.
Formal gate, native execution, CI, installation and task-state changes: NOT RUN.
