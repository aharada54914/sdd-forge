# RT004 PowerShell read-boundary test — pending candidate

Status: DATA-only observer and parent candidates independently statically
reviewed within the stated scope. Not applied, extracted, parsed as PowerShell,
executed or included in the already-issued human application sequence.

Candidate: `adr-pwsh-read-boundary-driver-candidate-20260910.patch` in this
directory, SHA256
`01fe4aa4d5303e83b8faae7ad9dd7abf544ca69e3ab900d2c26aafdf444ced85`.
Textual patch-format inspection reports 100 additions to one new test fixture.
This is not a runtime validation result.

Independent static review of the previous candidate (SHA256
`006159d91528c9169c6fe6f1efee33892fe3ba9fdbabe4580fdaf658f0b2f21b`)
found a Major: early-poison could mistake observer setup failure for validator
rejection. The revised candidate initializes completed/observer_ok to false and
child_exit to null; only normal validator return with an observed integer exit,
successful cleanup and unchanged validator hash permits a completion receipt.
Independent limited recheck by rt004_snapshot_static_review at the revised
SHA256 confirmed that this Major is statically addressed. Parent integration
and runtime evidence remain pending; this is not a formal PASS.

## Boundary and rationale

The human-provided PowerShell source at attachment
`9797d8fe-7e59-49ba-8ad3-7261258bafa4/pasted-text.txt`, lines 1306–1327,
assigns calibrationRelative before constructing and reading precheckData and
precheckHash. The composed candidate retains that assignment after its
Read-AdrHistoryEvidence call. A unique exact source-line match anchors the
observer, rather than a line number that drifts with insertions.

Microsoft documents line breakpoints with an Action scriptblock for diagnostic
actions in the current session:
[Set-PSBreakpoint](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/set-psbreakpoint?view=powershell-7.6).
Using that capability at this boundary is a test-design inference, not proof
that this observer works on the target PowerShell versions. In particular,
access to Stage/Feature in the action and child exit propagation must be
established by real execution and the required hit receipts below.

The observer must execute only the original repository validator. It must not
replace functions, alter gate variables or return values, edit original code,
evaluate patch content, or claim that the Bash jq observer covers PowerShell.
Fixture data are the same synthetic extended PASS inputs as current-singleton;
the validated spec opening permits ordinary design staleness, not omission of
ADR bindings. No native Windows or atomic/ABA claim follows from this test.

## Required parent cases

| Case | Mutation | Required result and receipt |
| --- | --- | --- |
| control | None | Exit 0, exactly one impl boundary hit, changed=false, before=after=current fixture precheck SHA |
| early-poison | Precheck becomes the single ASCII byte `{` before invocation | Exit 1, zero boundary hits, changed=true, before differs from after, precheck remains the exact poison byte, ADR stage-provenance diagnostic |
| poison | Same poison byte at the observed impl boundary | Exit 0, exactly one hit, changed=true, before differs from after, precheck remains poison; use of retained validated evidence demonstrated only if both earlier controls succeed |

Parent integration must satisfy all of the following before release:

- Every matrix row, including expected rejection, requires completed=true,
  observer_ok=true and an integer child_exit equal to the observed process exit.
  Add a negative receipt case with early-poison hits=0/changed=true and exit=1
  but completion=false; it must never count as successful validator rejection.
- Use a fresh fixture per case; never share mutated state across cases.
- Require the existing legacy and current-singleton controls, then observer
  control and early-poison controls before accepting the late-poison result.
- Validate receipt schema, mode, absolute original validator identity, source
  digest, exact fixture target identity, integer hit count and boolean changed.
- Compute the before digest in the parent before the observer, compare the
  after digest against the resulting fixture bytes, and retain the complete
  child diagnostic output with runtime and case labels.
- Treat missing/duplicate boundary matches, debugger capability failures,
  receipt absence/malformed data, or invalid fixtures as failures, not SKIPs.
- Require unchanged original validator bytes before/after. Do not count the
  debugger receipt as proof that a production gate was independently reviewed.
- Run pre-fix and post-fix against the original path through human application.
  If the existing implementation cannot admit the synthetic extended control,
  record that limitation: its failure does not isolate the late-read defect.
  Never describe such a baseline as a demonstrated mutation-specific RED.

The current-consumption human steps remain independently executable and need
no modification for this pending observer. Do not ask the human to install this
new observer until its review and parent assertions are complete.

## Parent candidate, not yet released for human application

`adr-pwsh-boundary-parent-candidate-20260910.patch`, SHA256
`8c32800bbc8dbf715fece181a7ef06f8d6eaa7f69b26ec1d54aed8e0c427c8e8`,
is a follow-on to current-consumption candidate SHA256
`5f927cbc1ff7d1bd13f3c0fb15c12c04424b635b68743da9b2899d0cf7344975`.
It is not intended for application to the still-unmodified test driver.
Patch-format numstat reports 36 additions/2 deletions to that driver and 63
additions to the new receipt checker. No runtime result follows from numstat.

The new selector is `--pwsh-boundary-only`; it retains legacy and singleton
controls for both runtimes and adds three observer cases for PowerShell only.
The same cases are included in the full driver. The existing
`--current-adr-only` selection remains unchanged. Each case uses the existing
fresh, physically resolved fixture root. Neither original validator is copied.

The receipt checker rejects duplicate keys, enforces exact fields and scalar
types, compares source/fixture digests and original paths, checks the unique
source boundary, and rejects incomplete copies of every accepted receipt.
Control and early-poison receipts gate acceptance of the final late-poison
case. The expected-rejection case must also emit the stage-provenance ADR
diagnostic. Raw validator output is retained by the existing current-case log.

Independent limited static review by rt004_snapshot_static_review at the above
SHA found no new Critical/Major findings. Parent
application, Python/Bash syntax checks, observer operation, pre-fix/post-fix
measurements and native Windows execution remain unverified. No CI, merge,
review verdict or issue state was changed during candidate authoring.

## Applicability repair against current original driver (2026-09-10)

The original-path workflow selection now has fresh agent-executed evidence:
137 passed, 0 failed, recorded in `rt004-original-workflow-recheck-20260910.md`.
It does not include this pending observer.

Ordinary `git apply --check --verbose` rejected the parent candidate at its
first one-sided context hunk, despite the named line existing in the current
driver. After adding unchanged trailing context, the same check localized the
next such hunk at the current-singleton expectation. The repair adds unchanged
trailing context to the affected hunks and updates their line/count metadata.
No added or removed executable statement was changed, no validator was edited,
and no relaxed application option was used.

Current parent DATA patch SHA256:
`66ffa59b6e3cd2dcf87f1b00f047d2fd9eab40c02417a995f8b53b20f6f51187`.
The earlier `8c32800...` hash and its independent review remain historical;
the current digest is not claimed to have that independent approval.

Verification command (read-only):

```bash
rtk proxy git apply --check --verbose reports/verification/adr-pwsh-boundary-parent-candidate-20260910.patch reports/verification/adr-pwsh-read-boundary-driver-candidate-20260910.patch
```

Result: exit 0 for the current driver and both new fixtures. This proves
textual applicability only. Author review of the context-only delta found no
new executable behavior; observer runtime, receipt assertions, formal review
and original-path application remain unverified. Do not extract or execute
these DATA patches as an alternate way around a denied protected edit.
