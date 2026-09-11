# RT004 raw duplicate JSON members — regression evidence

Scope: approved RT-20260908-004, isolated fixture DATA only. No protected
validator or candidate implementation was executed through an alternate path.
This is root diagnostic/static review, not independent approval or a quality gate.

## Finding and reproduction

Both installed jq and macOS PowerShell ConvertFrom-Json accept
`{"adr_inputs":null,"adr_inputs":[]}` and retain only the final empty array.
Consequently, checks on parsed object keys cannot prove that the original
JSON had unique members. The Bash history candidate
`adr-workflow-bash-history-candidate-20260909.patch` (SHA-256
`87f3f4547b3a75e10bf57df2f1b9686add25c456c893cbb068e594fb43dab3f1`)
uses ordinary jq parsing for extension selection and object validation; its
current slice has no raw duplicate-key check. The unfinished PowerShell caller
also must not rely on ConvertFrom-Json to establish this property.

This finding is about ambiguous input rejection, not evidence that a deployed
attacker changed an approved verdict. Candidate behavior was not executed.

Two regression modes were added to `tests/impl-review-adr-inputs.tests.sh`:
`duplicate-adr-key` and `duplicate-escaped-adr-key`. Both start from the same
extended equal-layer positive fixture and prepend a null member to the contract;
the latter spells the first key as `\u0061dr_inputs`. jq streaming independently
asserts two decoded root-key events, with values `[null,[]]`. There is no ordinary
JSON reserialization after injection. No review summary or precheck hash changes.

## Actual validator results

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`
(executed under pipefail with tee).
Session: 29345, terminal exit 1.
Full log: `/tmp/rt004-duplicate-json.Jbk4tJ`.
Result: **6 passed, 24 failed**. All 30 cases reached.
Both new cases returned exit 0 / `workflow-state: ok` in both actual runtimes
instead of rejection: four additional RED observations. The prior 20 failures
remain failures. Legacy/equal-layer/output-only-layer positive controls remain
successful. Native Windows was not run. No candidate GREEN claim is made.

Test source SHA-256: `08bed4748f3298a39193eaf27d2d1e584db4cbb1bbff8647a2f5ad38beec9208`.
Bash syntax and repository whitespace checks exited 0. Static test review found
the attack assertions preserve duplicate keys and both decoded spellings; it
does not substitute for independent review of the completed implementation.

## Required next change

Before composing the callers, add raw JSON member-uniqueness validation in both
runtime candidates, including escaped-equivalent names and nested objects,
before object parsing can erase evidence. Tie parsing to the validated byte
snapshot. Preserve valid no-extension historical semantics; do not use a broad
current-file freshness failure to reject these historical malformed cases.
Keep candidate changes as unapplied DATA until complete independent review and
human application. Then require mutation-specific rejection, not only exit 1.

Fresh GitHub check: seven open PRs, no active CheckRuns; five retain failed
checks, PR400 has no failed checks but outstanding local/formal findings, and
PR245 has no Actions checks. Nothing was committed, pushed, merged or closed.
