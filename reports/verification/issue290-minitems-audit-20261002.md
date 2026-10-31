# Concept input cardinality audit

Status: repair present; focused checks and both local regression drivers passed.

## Current verification (2026-10-02; supersedes status below)

The current validator contains the shared `minItems` assertion and has SHA-256
`5f1fe69df13bc90baac757aefa56e2e36c82a175b6db1000cee71592e22cbc74`.
No application was performed during this verification; the changed bytes were
already present. The previous source's `--test` run failed at the first
empty-array assertion. On the current source, the following commands exited 0:

- `rtk proxy python3 reports/verification/issue290-minitems-human-apply.py --test`: six boundary checks passed.
- `rtk proxy bash tests/validate-approval-sidecar.tests.sh`: 113 passed, 0 failed.
- `rtk proxy pwsh -NoProfile -File tests/validate-approval-sidecar.tests.ps1`: 112 passed, 0 failed (macOS PowerShell, not native Windows).
- `rtk proxy bash plugins/sdd-quality-loop/scripts/check-placeholders.sh contracts/approval-sidecar.schema.json contracts/concept-test.v1.schema.json plugins/sdd-quality-loop/scripts/concept_test_render.py plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py`: passed; the previously reported comment finding is resolved.
- `rtk proxy python3 specs/sdd-domain-concept-test/verification/T-001/check-validator-rollback.py`: 6 passed, 0 failed, using archived baseline `badbb7aa5d16114be542c33018967c58770d1a41` (disposable rollback only; production unchanged).

The boundary helper is separate from the existing registered regression drivers.
These results do not establish independent review, current-head CI, merge, or
completion of T-001. No approval, review verdict, task state or Git history was
changed by this verification.

## Earlier observation (retained; no longer current)

### Additional audit disposition (2026-10-02)

The separate implementation audit reproduced copying signed Concept Test JSON,
Markdown and sidecar from feature A to feature B: both invocations returned
`VALID`. The diagnostic uses only a disposable directory and a synthetic key
(`specs/sdd-domain-concept-test/verification/T-001/diagnose-feature-copy.py`).
This is not a confirmed T-001 defect: TEST-051/057/063/069 require agreement
between the signed feature and Markdown, not rejection based on the parent
directory name. The auditor withdrew the proposed T-001 blocker. No new
acceptance condition or quality verdict is introduced by this observation.

The same audit did not establish a defect in resolving relative input paths
from the working directory: the current implementation explicitly uses that
convention, and the admitted contract does not prescribe another base.
Caller-specific feature binding remains a caller-contract question, not an
additional T-001 acceptance gate.

`contracts/concept-test.v1.schema.json:28` requires at least one input.
`plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:568` implements
the shared schema validator, but its array branch at line 619 checks only
individual items. An empty array therefore produces no cardinality error.
`_validate_content` calls this shared function at line 687; registry and
sidecar validation also use it. The correction belongs in the shared function,
not a concept-only exception or a weakened schema.

The read-only Python import/assertion command was rejected before execution
by PreToolUse. It supplied no RED result. Existing Bash 113/0 and PowerShell
112/0 results do not cover this defect and are not proof of the new repair.

The human-only `issue290-minitems-human-apply.py` beside this report pins the
source to SHA-256
`01411086bb889967f62b33249a0f42b0399f1945ec98f7f0a25f8576fe46bcd1`.
It first checks the original defect, backs up the original bytes, adds the
array cardinality assertion, fixes the separately identified misleading
comment, and runs six boundary checks. Its `--test` mode repeats those checks
without applying changes. The helper passed AST parsing; it has not run.

After human application: run both existing sidecar regression drivers, retain
full logs and exact source hashes, then resume independent verification. No
task state, review verdict, reservation, commit, push or merge was changed.
