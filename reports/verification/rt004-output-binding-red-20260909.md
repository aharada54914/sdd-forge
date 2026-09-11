# RT004 — historical output-binding regression baseline

Scope: RT-20260908-004, approved ADR contract and consumer correction.
This is RED evidence, not a quality-gate PASS or a completed implementation.

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`
Actual execution used a pipefail wrapper and tee to preserve complete output at
`/tmp/rt004-output-binding.NIxn5A`. Session 14309 ended with exit 1.
Result: 6 passed, 16 failed. Prior cases contributed 6 passes and 10 failures;
the three new mutations each failed in Bash and macOS PowerShell (6 additional
failures). Every new case returned exit 0 with `workflow-state: ok` when rejection
was required. No native Windows execution is claimed.

## Added cases

- `duplicate-check`: replace the second reviewer A check ID with its first ID;
  an independent jq assertion proves duplication in the constructed fixture.
- `wrong-finding-count`: change both contract and integrated-verdict Major
  counts to 2, leaving actual checks with one Major failure. An independent jq
  assertion compares the contract count with both actual reviewer check arrays.
  Contract/verdict mutual agreement is intentionally insufficient.
- `wrong-reviewer-run`: change only reviewer A output run ID. An independent
  jq assertion proves it differs from the contract's reviewer A identity.

Each starts from the existing equal-layer extended history fixture, whose
three core pins and input digest have independent format/digest checks.
Precheck and input-manifest hashes remain unchanged by these three mutations.
Only isolated fixture DATA is copied/modified; original repository validators
execute with `--opening impl:1:3`. No candidate validator is copied or executed.
Legacy, equal-layer and output-only-layer positive controls still return 0.
This early-return baseline does not prove the positive fixture satisfies every
check of the not-yet-applied corrected implementation.

## Review and preserved boundaries

Root static review found no Critical defect in the added fixture mutations.
Limitation: negative output matching currently requires the stage-provenance
and ADR diagnostic family, not a distinct message per mutation. Green testing
must confirm rejection is from the intended binding check, not an unrelated
fixture defect. Independent full candidate review remains mandatory.
Bash syntax validation exited 0. No protected runtime changes, historical
review changes, status changes, commit, push, merge or issue closure occurred.

Current SHA-256:

- test: `7d6e5c26727f9ef9b07f191a3bad46be1c37e218ab916aafd8217c4bf1bdbf89`
- original Bash workflow validator: `15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`
- original PowerShell workflow validator: `7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644`

Next: complete the PowerShell workflow history candidate's reviewer output,
summary, identity and aggregate bindings and its callers, matching the approved
Bash contract; compose a coherent complete protected patch for independent
review before human application. These RED tests do not authorize bypassing
protection or merging a failing PR.
