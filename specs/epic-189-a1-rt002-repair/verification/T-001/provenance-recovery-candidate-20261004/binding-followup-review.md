# Supplemental binding review candidate (not applied)

This is a supplemental, unapplied candidate for the existing eight-file
recovery patch, not a formal gate verdict. No protected source file or
canonical identity ledger was changed.

## Finding and contract

The new `verify_implementation_binding` / `Get-ImplementationBinding` routines
check schema and task/run/session but not `allowed_inputs`; their stricter
input helpers are no longer called once source authorization is correctly kept
on report `## Outputs` / `## Post-Fix Artifacts` alone. The shipped
`validate-task-input-manifest.sh` (`:253-260`) and `.ps1` (`:178-183`) require
`allowed_inputs` to be a nonempty array of exact path/hash objects. The
candidate's `issue311` clean fixture and two migrated caller fixtures each
construct an incomplete task-input manifest.

The binding routine is called only under reservation, so read-only preflight
accepts a report/manifest task or run mismatch that reservation rejects. The
minimal correction is to check nonempty, unique, canonical path/hash entries
inside the binding routine and call that routine for evaluator preflight as
well as reservation. Keep ledger reuse and evaluator-vs-implementation identity
checks under reservation if those are intended to be reservation-only. Do not
use `allowed_inputs` to authorize evaluator source/test access.

The companion `binding-followup-regression.py` constructs this correction in
temporary Bash/PowerShell overlays and exercises the existing `issue311`
isolation fixture. The correction is intentionally a narrow *candidate*, not
proof that the full `task-input-manifest/v1` schema is enforced; the production
handoff must still be validated by its canonical implementation-manifest
validator.

## Isolated result

`python3 binding-followup-regression.py --repo
/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`: exit 0,
24/24 expected outcomes. Each runtime independently exercised a valid
Outputs-declared input, missing `allowed_inputs`, string-typed `allowed_inputs`,
wrong task, wrong implementation run, and an input absent from Outputs. On the
unmodified #423 bytes, missing/malformed inputs reserved and changed only the
fixture ledger; identity mismatches passed read-only preflight but failed
reservation. On the temporary correction, the four invalid-manifest/identity
cases failed preflight and reservation with the fixture ledger unchanged.
Undeclared source access failed before and after. The valid Outputs case
succeeded before and after. No canonical ledger or protected source was used.

## Integrated candidate and reproducibility

`binding-followup-integrated.patch` is the fixed 10-file follow-up to
`shared-launch-auth-preserving.patch` (it applies to the latter's proposed
bytes, not directly to the RT002 checkout). SHA-256:
`2b0fff67fbc907cf62a947fc887f7b776c26655e77a35535b093047b41997087`.
It amends both validators, supplies complete implementation-manifest fixtures
in the three migrated tests, realigns validator line citations and their
anchors, and adds `tests/review-implementation-binding.tests.py` to both
`.github/workflows/test.yml` and `tests/run-all.sh`. The new suite covers
valid and undeclared Outputs sources plus missing, string, empty, duplicate,
bad-hash, trailing-newline hash, bad-path, newline/tab/NUL paths,
trailing-newline path, numeric/boolean paths,
task-mismatch, and run-mismatch manifests for Bash and PowerShell.
Each case checks preflight, reserve, fixture-ledger bytes, and
the expected error category/message, so an unrelated refusal cannot pass a
negative test. The new test file's proposed SHA-256 is
`d7af8955d31908e0a99d897098a62dff69752240bbb44f3c37a50ca55ae2165d`.

Generation and isolated test command from the RT002 checkout:

```sh
rtk proxy python3 -u specs/epic-189-a1-rt002-repair/verification/T-001/provenance-recovery-candidate-20261004/binding-followup-integrated.py /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
```

To regenerate only the fixed patch and its before/after hashes, append
`--emit-patch-only`. `git apply --check binding-followup-integrated.patch`
on the #423-equivalent tree exited 0. The full run exited 0: Bash syntax,
issue311 60/0, review-scratch-history 26/0, review-agent-isolation 26/0,
review-context-boundary 116/0, and new implementation-binding 20/0. The
run-specific captured command output is in
`binding-followup-full-20261003T181118465510Z-a389fca3b6f3.log` (SHA-256
`572a626a5ce3aeb8de26e6c83b08c87cab123b758a0d489eead8350a93bb688a`).
This 20/0 run belongs to the superseded candidate SHA-256
`a389fca3b6f3675ed48336b9527a2f3e52b98f10f8b3429bd38df2960fc1b512`;
it is retained as history, not proof of the revised patch.
The same persistent test against the unmodified #423 validators, with only
the three fixture updates in an isolated overlay, exited 1 as expected:
PASS 4 / FAIL 16. Both runtimes accepted and reserved all six invalid
`allowed_inputs` variants, and admitted task/run identity mismatches in
read-only preflight. Valid Outputs and undeclared-source controls passed.
The red run is recorded in
`binding-followup-binding-before-only-20261003T181829780481Z-a389fca3b6f3.log`.
These checks are local overlay evidence only; installed hosts, CI, formal
reviews, and application to RT002 remain unverified.

## Revised candidate: raw path type and control-character checks

An additional independent technical audit found that Bash split a JSON path
containing a newline (or NUL) after `jq -r`, while PowerShell's typed
`Test-CanonicalPath([string])` parameter converted JSON number/boolean values.
The revised Bash binding rejects C0 and DEL code points before extracting any
path as text. The PowerShell binding checks the original JSON value is a
string before calling the path helper. Neither change grants `allowed_inputs`
source authorization; the report Outputs/Post-Fix rules remain authoritative.

With the five new variants against the superseded candidate, the new suite
exited 1, PASS 25 / FAIL 5: Bash accepted newline and NUL; tab was refused by
the later path check rather than the expected manifest check; PowerShell
accepted numeric and boolean values. Both modes of the accepted cases changed
only disposable fixture ledgers. The run-specific RED log is
`binding-followup-binding-only-20261003T182703622962Z-a389fca3b6f3.log`
(SHA-256 `6cbb0fa26162b28ab64113c73743c380dce3361eee6cc7956e5b1466c3b48e3c`).

The revised candidate's isolated full run exited 0: Bash syntax, issue311
60/0, scratch-history 26/0, agent-isolation 26/0, context-boundary 116/0,
and implementation-binding 30/0. The run-specific GREEN log is
`binding-followup-full-20261003T182805174647Z-1f8a21505bc8.log`
(SHA-256 `c855f8998ea7d9c34926ab3605108826a6c8cd7cbd617963a92b01509ddb6695`).
This 30/0 run belongs to the superseded candidate SHA-256
`1f8a21505bc8c933ed15ea4817b31865c8051a979650d559e786468972d2bcb0`;
it is retained as history, not proof of the current patch.
All executions used an isolated overlay; no protected original or canonical
identity ledger was changed. The before/proposed file hashes for this revised
10-file patch are fixed in `binding-followup-hashes.json`.

## Final candidate: strict trailing-newline boundary

The subsequent technical audit found that regex `$` admits a final LF in
PowerShell canonical paths and SHA-256 values; the Bash SHA test also admitted
a final LF. Four new cases (two variants x two runtimes) were added to the
persistent suite. Against the superseded candidate, the isolated run exited 1,
PASS 31 / FAIL 3: both runtimes admitted the trailing-LF digest, and PowerShell
also admitted the trailing-LF path. Accepted reserve calls changed only the
disposable fixture ledger. Bash already rejected the trailing-LF path with its
control-character check. RED log:
`binding-followup-binding-only-20261003T183918099255Z-1f8a21505bc8.log`
(SHA-256 `4bc63ca647f90c3daf923d63e70506f6e43e9a670e6caf626c7b8072f047bd2d`).

The final candidate requires exactly 64 characters for both digest checks and
uses the strict `\z` anchor in PowerShell's canonical path matcher. It does
not alter evaluator source authorization. The isolated full run exited 0:
Bash syntax, issue311 60/0, scratch-history 26/0, agent-isolation 26/0,
context-boundary 116/0, implementation-binding 34/0. GREEN log:
`binding-followup-full-20261003T184042444787Z-2b0fff67fbc9.log`
(SHA-256 `75305ae6c2c7063817b4fa01aaa39da45f00229f707c71087193f8aa406a5b9d`).
This remains an unapplied shared-launch recovery candidate, not RT002 T-001
completion, formal review, installed-host proof or CI evidence.
