# T-003 attempt10 — bounded preflight and RED

Report Schema: implementation-report/v2
Run ID: t003-20261016-attempt10
Task Attempt Count: 10

## Target and Scope

- Issue #423; sdd-domain-multitarget T-003; Approved / In Progress; high risk; TDD.
- Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
- HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Actual implementation session: `01a140ef-6584-7453-a8c3-e51adad974e4`.
- Existing dirty changes are captured in `specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/owner-dirty-before.txt`; preserve them. No Git mutation, network, credential access, installed-baseline replacement or evaluator work.
- Manifest: `specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/task-input-manifest.json` (183 inputs); immutable snapshot: `/tmp/issue423-t003-attempt10-inputs-20261016`.
- Executed structure precheck, snapshot preparation and manifest validation: exit 0, `check-sdd-structure: OK`, `TASK_INPUT_OK`, `TASK_INPUT_OK` respectively.
- Intended affected readers/writers: new companion evaluator writes the versioned selected plan; schema and independent QG read it; mandatory QG invocation consumes its exit/result. Existing Resolver, Registry and check-contract remain unchanged. Focused test and both runners are the affected verification callers. No existing evaluator caller exists (scoped search returned only the draft schema).

## High-risk preflight (before tests or product edits)

The following persisted fields are the defined subset of the proposed versioned
plan. Every mismatch case is assigned a concrete test below before implementation.
The candidate addendum is not authority for resolving the pending policy rows.

| Persisted field | Counterpart / invariant | Failing mismatch test |
|---|---|---|
| schema | selected-verification-plan/v1 schema | test_output_identity_and_bindings (wrong version) |
| feature, task_id | facet-manifest feature and verification-contract task_id | test_output_identity_and_bindings (wrong feature/task) |
| bindings.facet_manifest_sha256 | exact input bytes | test_output_identity_and_bindings (wrong hash) |
| bindings.registry_sha256 | exact input bytes; manifest registry_digest separately equals canonical Registry digest | test_registry_digest_mismatch, test_output_identity_and_bindings |
| bindings.verification_contract_sha256 | exact input bytes | test_output_identity_and_bindings (wrong contract hash) |
| checks[].id, sources | exact matched Capability gate IDs joined to canonical Registry, plus unchanged legacy required checks | test_registry_projection_mismatch, test_duplicate_gate, test_legacy_required_not_removed |
| checks[].stage | canonical Registry stage; selected plan implementation only | test_implementation_only_keeps_foundation_stages |
| checks[].obligation, blocking | Registry blocking flag and legacy required:true, with no downgrade | test_legacy_required_not_removed, test_required_missing_observation |
| checks[].applicability | legacy required checks stay applicable before versioned migration | test_legacy_required_not_removed |
| checks[].result, reason | required missing/unrun/unknown cannot satisfy REQ-003; legacy missing is migration-pending | test_required_missing_observation, test_design_selection_is_not_gate_success |
| checks[].evidence_path | existing check-contract evidence path policy and referenced file | test_evidence_escape |
| verdict | all required observations and unchanged check-contract.run acceptance | test_required_missing_observation, test_legacy_required_not_removed, test_design_selection_is_not_gate_success |

Pending policy (no product implementation authorized by this report): approved
design Resolution Model §3 names conditional and not-applicable; Registry v1 has
no gate predicate or N/A eligibility field. Candidate addendum newly proposes
reserving conditional and allowing unselected legacy-optional checks to become
N/A with `legacy-optional-not-selected`. Those choices are not yet derived from
approved policy. No successful N/A path or conditional policy is implemented.
The parent is resolving this exact difference. Required/unrun/stage/hash/path
assertions do not depend on it. Full preflight remains incomplete until that
policy and its mismatch cases are settled.

## Verification

RED: executed with `rtk proxy python3 specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/run-red.py`.
Raw output: `specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/red.log`.
Initial 10 tests: one five-target resolver selection test passed; 13 subtest/test
failures all identify the absent selected-plan evaluator; exit 1. This proves
missing new functionality, not runtime correctness. After that run, the negative
fixtures were tightened to use passing legacy observations so a pre-existing
legacy failure cannot mask a digest/path rejection; a five-target PASS fixture
was added. The tightened run is in `output/red-tightened.log` (11 tests,
18 expected failures). A final control test then ran the unchanged legacy
checker on the success fixture: it returned no failures. The final complete
RED is `output/red-final.log` (12 tests, two passing control tests, 18 expected
test/subtest failures, exit 1); all failures still identify the absent evaluator.
The original logs remain unchanged. All fixtures explicitly represent synthetic observations, never real
deployment or actual verification of the implementation.

GREEN, product implementation, runner integration,
independent review, quality gate, native CI and Done: NOT RUN / NOT COMPLETE.

## Session Handoff

No task state or historical evidence changed. This is implementation evidence,
not an independent verdict. UI verification is not applicable (no UI changes).

### Resumption handoff after compaction (2026-10-16)

The parent relayed explicit human approval of the minimum policy: required
checks cannot be omitted; unexecuted or unavailable required checks are BLOCKED;
only originally optional and unselected checks may be N/A with a reason; no
conditional obligation may be invented because Registry v1 defines no condition.
This resolves the pending policy choice above for subsequent implementation; it
does not retroactively change the historical RED evidence or mark preflight,
implementation, review or quality verification complete.

### Approved-policy preflight completion (2026-10-16, final continuation)

The parent assigned `/root/t003_implement_final` sole ownership of T-003 product,
tests and report writes. This names the current coordination context, not a new
reserved Run ID or a claim that the historical session ID above is current.
The existing attempt10 snapshot and current owning checkout both returned
`TASK_INPUT_OK` immediately before edits; HEAD remains
`3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. Structure precheck also passed.
Existing dirty QG/runners were inspected and will receive additive changes only.

The human-approved policy relayed by the parent supersedes the pending-policy
paragraph above: required checks never become N/A; unavailable/unrun required
checks block; only originally optional and target-unselected checks may be
reasoned N/A. Registry v1 defines no conditional gate, so this version does not
emit a conditional obligation. Frozen design/layer wording remains historical;
this addendum records the approved narrowing without editing reviewed bytes.

| Persisted fields | Counterpart / mismatch proof before product edits |
|---|---|
| schema, feature, task_id, all three bindings | `test_persisted_field_mismatches_rejected` mutates each field separately against independently generated expected input bindings |
| checks[].id, sources, stage, obligation, blocking, applicability, result, reason, evidence_path | Same test mutates every field separately; schema plus exact recomputation readback must reject each mismatch |
| verdict | Same mismatch test; required execution-state tests independently assert BLOCKED versus NEEDS_WORK |
| optional N/A reason/applicability/result | `test_optional_unselected_na_and_selected_not_run` contrasts originally optional unselected versus selected checks for all five targets |
| no required omission/downgrade | `test_required_cannot_be_downgraded_or_disappear`, plus existing Registry projection/legacy protection cases |
| execution outcome and verifier availability | `test_required_execution_states`, `test_verifier_unavailable` assert missing/inconsistent observations cannot become PASS |

All persisted fields now have named sibling invariants and concrete negative
fixtures. The added cases will be captured as RED before the evaluator/schema/
caller implementation. Required regression scope: focused T-003, unchanged
legacy contract suites, Registry/manifest/resolver suites and runner syntax.
Independent diff review, quality gate, native CI and Done remain parent-owned.

Compaction occurred in this implementation context before the resumption request.
The implement-task implementation-policy Context Management rule requires a
handoff and session end after compaction. A fresh implementation context must
re-read canonical task/specification records and this report, record the approved
policy in a non-frozen addendum, complete the persisted-field mismatch preflight,
then implement and verify the evaluator, schema, mandatory QG invocation and
runner connections. Preserve all attempt10 raw logs and frozen evidence; do not
set Done or mutate approval/identity ledgers. No product implementation was made
in this resumed context.

### Session Handoff — final continuation implementation (2026-10-16)

This dated entry supersedes the preceding continuation's statement that no
product implementation was made. Coordination context `/root/t003_implement_final`
implemented the following local changes, without inventing a new run identity,
reserving the ledger, changing frozen records, or changing task status:

- Added `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py`, reusing
  existing contract, Registry and facet-manifest validation. It verifies the
  Registry projection/digest and input bindings, evaluates execution observations,
  blocks missing required execution, and validates persisted-plan readback.
- Tightened `contracts/selected-verification-plan.schema.json`: only required or
  optional obligations; reasoned N/A only for optional target-unselected checks.
- Added the evaluator invocation to quality-gate step 6 and connected the focused
  permanent test suite to both `tests/run-all.sh` and `tests/run-all.ps1`, preserving
  their unrelated existing changes.
- Expanded the focused test suite to 19 tests, including all-field mismatch,
  required omission/downgrade, verifier availability, execution-state consistency,
  optional selection, Registry projection and caller/runner connections.

Before product edits, the expanded suite failed as expected: 19 tests, 33
failures, exit 1. Raw output is retained at
`specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/red-approved-policy.log`.
Both the original snapshot and owning checkout had passed task-input validation
before edits; structure validation also passed. No GREEN test or post-edit
regression has yet been executed. These are implementation changes, not evidence
of correctness or Implementation Complete.

Compaction occurred immediately after implementation. The implement-task Context
Management instruction requires writing this handoff and ending this context.
Next fresh context must run the focused suite first, repair within the bounded
three-cycle limit, then run unchanged legacy-contract and relevant
Registry/manifest/resolver regressions plus shell/PowerShell runner syntax checks.
Inspect stage collisions (a legacy observation for a non-implementation Registry
gate), required legacy rows missing from a malformed contract, and installed
schema discovery before claiming acceptance. Preserve historical attempt10 logs.
Independent diff review, quality gate, exact-head CI, task-state decisions and
Done remain parent-owned and have NOT RUN in this context.

### GREEN continuation preflight (2026-10-16)

Coordination context `/root/t003_green_finish` continues the same Run ID and
attempt; the historical implementation session above is not this context's
identity. HEAD and dirty work were re-read; canonical requirements, design,
tasks, acceptance tests, traceability, relevant ADRs and implementation policies
were re-read. Structure check passed. Task/approval/ledger/frozen bytes are not
owned by this continuation. The first focused run executed 19 tests and failed
with 11 failures and 15 errors: schema discovery derived the selected schema
directory from the already-vendored Facet schema, so the root-only new schema
was never found. This result is NOT GREEN.

Additional mismatch preflight: a missing or illegally downgraded risk-required
legacy row must remain explicitly required in the emitted plan; the existing
`test_required_cannot_be_downgraded_or_disappear` now asserts that row and its
migration-pending reason. `test_nonimplementation_observation_cannot_be_relabelled`
rejects artifact/promotion Registry IDs used as legacy observations rather than
misrepresenting them as implementation evidence. Schema discovery must work per
requested filename, including a standalone packaged layout.

### Session Handoff — GREEN continuation (2026-10-16)

Coordination context `/root/t003_green_finish` completed corrective cycle 1 of
the bounded three-cycle continuation, retaining Run ID `t003-20261016-attempt10`
and Task Attempt Count 10. It did not reserve identity, change approval/task
status, commit, push, or edit frozen evidence. The historical implementation
session ID remains historical and is not claimed as this continuation's ID.

Changes made by this continuation:

- `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py`: discover the
  requested schema filename in the packaged directory or Git-root contracts;
  reject non-implementation Registry gates supplied as legacy observations;
  reuse the legacy checker's risk-required IDs (including its existing
  capability-state gating and explicit non-code compile waiver) and retain
  absent/illegally downgraded required rows as unknown/migration-pending-required.
- `tests/sdd-domain-multitarget-T-003.tests.py`: assert the persisted missing
  required row and add artifact/promotion observation collision cases.
- `specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/run-verification.py`:
  an exclusive-create raw-output capture helper; existing evidence is never
  overwritten.
- This implementation report, plus the two new raw logs named below.

Executed evidence (owning checkout; shell entry points used `rtk proxy`):

| Check | Result | Raw evidence |
|---|---|---|
| Structure check | PASS, exit 0, advisory CLAUDE.md message | Tool output in this continuation |
| Strengthened focused suite before correction | RED, 20 tests, 12 failures and 16 errors, exit 1 | `output/red-continuation.log` |
| Focused suite after corrective cycle 1 | PASS, 20 tests, 8.997 seconds, exit 0 | `output/green-cycle1.log` |

Both log paths are relative to
`specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/`.
The successful run command was
`rtk proxy python3 specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/run-verification.py green-cycle1.log python3 tests/sdd-domain-multitarget-T-003.tests.py`.
These are synthetic fixture observations, not native provider verification.

Unresolved: installed schema availability is NOT VERIFIED. The canonical schema
exists at `contracts/selected-verification-plan.schema.json`, but no matching
packaged copy exists under `plugins/sdd-quality-loop/contracts/`. The protected
`plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` has an explicit
ARTIFACTS list that does not include it. No protected vendor change was made;
the parent was notified that sanctioned packaging/discovery work remains.
Unchanged legacy-contract, Registry, facet-manifest and resolver regression
suites, runner syntax checks, independent diff review, quality gate and exact
final-head CI have NOT RUN in this continuation. This focused PASS does not
establish Implementation Complete or Done.

Compaction occurred after the focused GREEN. The required implementation-policy
Context Management instruction says: "If the session has grown long or compaction
has occurred, write the current state to the Session Handoff section of the report
and end the session." This context therefore ends here. A fresh continuation must
re-read canonical records and current changes, resolve installed schema packaging
within authorized boundaries, run the outstanding regressions and runner syntax,
and record results without repeating unchanged evidence or replacing historical
logs. Corrective cycle 1 is consumed; at most two corrective cycles remain in
this bounded continuation. Parent retains independent review/QG ownership.

### Session Handoff — packaging investigation (2026-10-16)

Coordination context `/root/t003_package_finish` retained Run ID
`t003-20261016-attempt10` and Task Attempt Count 10. Owning checkout is
`/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; observed
HEAD is `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. Existing extensive dirty
changes were preserved. Applicable AGENTS, implement-task policies, development
policy and canonical feature artifacts were read. No product/test edits, identity
reservation, task-state change, commit, push or installation occurred. This
context did not revalidate the historical task-input manifest or rerun the
unchanged 20-test focused GREEN evidence.

Executed commands used `rtk proxy`, `login=false`, and the owning checkout.
The structure check passed (exit 0; advisory CLAUDE.md message). The following
unchanged suites ran through the existing exclusive-create capture helper at
`specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/run-verification.py`:

| Suite command after capture helper | Result | New raw log in the same output directory |
|---|---|---|
| `bash tests/capability-registry-schema.tests.sh` | exit 0; 6 accept + 16 reject fixtures pass; canonical instance valid | `registry-schema-package-finish.log` |
| `bash tests/validate-capability-registry.tests.sh` | exit 0; 27 passed, 0 failed | `registry-validator-package-finish.log` |
| `bash tests/facet-manifest-schema.tests.sh` | exit 0; 57 passed, 0 failed | `facet-schema-package-finish.log` |
| `bash tests/resolve-project-context-match.tests.sh` | exit 0; 125 passed, 0 failed | `resolver-match-package-finish.log` |

Each full invocation was `rtk proxy python3 <capture-helper> <log-name>
bash <suite-path>` with the concrete paths and names in the table above. These
are local synthetic regressions, not installed-host or provider verification.

Packaging findings and next exact scope:

- Add only `selected-verification-plan.schema.json` to `ARTIFACTS` in
  `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py`, then use the
  normal generator for its matching packaged copy and run `--check`.
- Before the edit, record a scope/hash-pinned application and backup in this
  report. Observed vendor before SHA-256:
  `0ece9e8ed1a0a1d2af66b54b889ece5f6234f91ab5e8080c39fb36f12b7e54a9`.
  Canonical selected-schema SHA-256:
  `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe`.
  Focused test-suite SHA-256:
  `2d1f491f065fd9446b7e6601836f8643be86a387118d85a3805f7a494d009440`.
  No backup or application was performed in this context.
- The parent relayed explicit user authority for self-application with the
  standard plugin uninstalled. Protected membership alone is not a refusal.
  Use the scoped `apply_patch` path, never an old human-only script or alternative
  executor to bypass denial. No executable control refused an operation here;
  preserve any actual future refusal verbatim and stop that write.
- Both existing drift fixtures enumerate the generator inputs manually:
  `tests/registry-discovery.tests.sh` around line 159 and
  `tests/registry-discovery.tests.ps1` around line 169. Add the new schema to
  their fixture-copy lists and run both suites. Wrappers need no change; CI
  already runs generator `--check`.
- Add a focused test for canonical/package byte parity and actual evaluation
  from a standalone packaged scripts/contracts layout outside a Git checkout;
  capture its RED before the packaging edit and GREEN afterward. Do not count
  a checkout fallback as installed-layout proof.
- Remaining unchanged affected checks include legacy-contract/scenario,
  Registry discovery/digest, facet semantics as appropriate, and Bash/PowerShell
  runner syntax. Inspect `tests/gates.tests.sh` before executing: its missing
  runtime fixture temporarily removes/restores the live check-contract Python
  file, so use an isolated layout or otherwise preserve dirty source bytes.

Changed-file inventory for this context is this report plus the four new raw
logs above only. The generator, canonical schema, packaged schema, focused tests,
frozen inputs and identity ledger were not edited. Installed packaging,
independent final-byte diff review, quality gate and exact-head CI remain NOT
RUN / NOT VERIFIED; implementation-ready status is not claimed.

Compaction occurred after investigation and regression execution. Per
`plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md`
Context Management: "If the session has grown long or compaction has occurred,
write the current state to the Session Handoff section of the report and end
the session." This context ends with the above handoff. No corrective cycle was
consumed here; corrective cycle 1 remains the only consumed cycle and at most
two remain. Parent retains independent review and QG ownership.

### Scoped packaging application preflight (2026-10-16)

Continuation `/root/t003_package_minimal` retains this report's Run ID and
attempt count, owner checkout and HEAD above. T-003 remains Approved / In
Progress and high risk. Existing dirty work is preserved; no lifecycle or
identity-ledger write is in scope. The user-authorized self-application path is
`apply_patch` plus the normal vendoring generator; any actual denial stops it.

Targets and observed before SHA-256:

| Target | Before SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` | `0ece9e8ed1a0a1d2af66b54b889ece5f6234f91ab5e8080c39fb36f12b7e54a9` |
| `tests/registry-discovery.tests.sh` | `6fdeabbf86bcc09b504cfbdb8f3c2492d74b43784a9fe05e090feda0b06862fc` |
| `tests/registry-discovery.tests.ps1` | `eaa428e7174c68fe8137864877e1d1f043e05ece1127771acc47c6b66369f443` |
| `tests/sdd-domain-multitarget-T-003.tests.py` | `2d1f491f065fd9446b7e6601836f8643be86a387118d85a3805f7a494d009440` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan.schema.json` | absent |

Backup before edits: `specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/packaging-before/before.tar`
contains the four existing targets and existing packaged contracts. The normal
generator rewrites its existing six outputs with canonical bytes; verify no
unrelated byte changes. Canonical selected-schema hash remains
`0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe`.
No schema semantics change. New mismatch case compares canonical/packaged schema
bytes and executes the evaluator from copied standalone scripts/contracts with
no Git ancestor. Capture RED before vendoring; then GREEN, vendor `--check`, both
registry-discovery runtimes, and runner syntax. Independent review/QG/CI remain
the parent's responsibility.

### Packaging result and handoff (2026-10-16)

Scoped application completed without an executable refusal. The generator adds
one ARTIFACTS entry and produces the selected schema; the two drift fixtures
copy that input. The focused suite adds standalone package execution and schema
byte parity; its subprocess runs from the fixture root. Existing six packaged
contracts match the pre-edit backup byte-for-byte. No evaluator/schema semantics,
frozen specification, identity, task state or installed baseline changed.

Evidence directory: `specs/sdd-domain-multitarget/verification/T-003/attempt10-20261016/output/`.
Every row below used `rtk proxy python3 <directory>/run-verification.py <log>
<command>` in the owning checkout with `login=false`:

| Log | Command / result |
|---|---|
| `packaging-red.log` | `python3 tests/sdd-domain-multitarget-T-003.tests.py SelectedPlanTests.test_standalone_package_schema_and_evaluation`; exit 1, `schema-discovery-failed: selected-verification-plan.schema.json` |
| `packaging-generate.log` | `python3 plugins/sdd-quality-loop/scripts/vendor-capability-registry.py`; exit 0, 7 artifacts |
| `packaging-green.log` | `python3 tests/sdd-domain-multitarget-T-003.tests.py`; exit 0, 21 tests passed |
| `packaging-vendor-check.log` | `python3 plugins/sdd-quality-loop/scripts/vendor-capability-registry.py --check`; exit 0, no drift |
| `packaging-discovery-bash.log` | `bash tests/registry-discovery.tests.sh`; exit 0, 21 passed / 0 failed |
| `packaging-discovery-pwsh.log` | `pwsh -NoProfile -File tests/registry-discovery.tests.ps1`; exit 0, 21 passed / 0 failed |
| `packaging-bash-syntax.log` | `bash -n tests/run-all.sh tests/registry-discovery.tests.sh`; exit 0 |
| `packaging-pwsh-syntax.log` | PowerShell Parser.ParseFile for `tests/run-all.ps1` and `tests/registry-discovery.tests.ps1`; exit 0 |
| `packaging-existing-bytes.log` | Read-only tar comparison of all six existing packaged contracts; exit 0, unchanged |

`rtk proxy git diff --check` passed. Scoped self-review found only the intended
packaging delta; no new SKIP condition or runtime validation branch was added.
The archive SHA-256 is `b941f5abe1c8ad2c32ffd0346a14a3555074da2fff815d828591b97869931e13`.
Final source hashes for independent admission:

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` | `d5ee1d34c9fcd6cfd6deec47a80bfb01ea55263f34ef60fa1124f52df880b49b` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan.schema.json` | `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe` |
| `tests/sdd-domain-multitarget-T-003.tests.py` | `69187b77ad54b2fed21099bf8dba38d5d1570f49814d5aef5767d33826074cd6` |
| `tests/registry-discovery.tests.sh` | `9597c9edda9bcb6e265816190009c3982f10e8ae6f9b03f682b92db3660a9478` |
| `tests/registry-discovery.tests.ps1` | `e144fccac70bc06dd96d071b0d48f3e8355d00f2cf53d568024377b1b3e317d3` |

This is corrective cycle 2 (one cycle remains), with no additional repair loop.
Packaging is ready for independent final-byte review and QG admission. Historical
input manifests were not rewritten or claimed current. Parent must collect any
remaining task-wide checks and fresh admitted inputs before formal evaluation.
Native Windows/installed-host activation, independent QG, exact-head CI, commit,
push and merge are NOT RUN here. macOS PowerShell and a standalone copied package
are local fixtures, not native Windows or actual installation evidence. The
canonical task remains In Progress; no Done/Implementation Complete claim is made.

### Corrective cycle 3 and independent review (2026-10-16)

This entry supersedes the cycle-2 progress statement, not its historical results.
Cycle 3 repairs schema identity validation: the selected-plan schema must carry
the expected `$id` and `$schema`, not merely otherwise usable validation rules.
The original validator failed the new negative cases (22 tests, four failures);
`output/schema-identity-green.log` records the repaired suite: 22 tests passed,
exit 0. `output/qg-types-cycle3-uvx.log` records mypy 1.18.2 strict success;
`output/qg-lint.log` records ruff 0.13.3 success. Paths are relative to the evidence
directory above. Earlier failures remain retained; no historical result changed.

Final evaluator SHA-256:
`e82e090a32afc773c2528d24c8cfd2eb51f9eabc5be38f444a4f5869a788ef11`.
Final focused-suite SHA-256:
`020a1f1a0f2fb800f56d2664cf6a5d66da0083c7e9e51a53e43269f1ff3d576c`.
Canonical and packaged schema SHA-256 remains
`0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe`.

Independent reviewer `/root/t003_cycle3_review` returned NEEDS_WORK:
Critical 0, Major 1, Minor 0. This is an independent development review, not a
formal quality-gate verdict or a reservation in its ledger. The reviewer verified
the final hashes and independently executed: focused suite 22 PASS; registry
discovery Bash 21 PASS and PowerShell 21 PASS; vendoring check without drift;
facet-manifest schema 57 PASS; resolver match 125 PASS; evaluator suite 16 PASS;
Bash runner syntax and PowerShell runner parsing PASS. PowerShell ran on macOS,
not native Windows.

The remaining Major is acceptance coverage, at
`tests/sdd-domain-multitarget-T-003.tests.py:35-44,94-100` against
`specs/sdd-domain-multitarget/acceptance-tests.md:15-19`: the five fixtures assert
same-named target selection, but not the concrete required artifacts/checks and
forbidden requirements of TEST-003a/b/d/e. A passing name-selection test cannot
prove CLI/library packaging and UI/cloud exclusions, UI flows/contracts without
mandatory remote design, IaC policy/plan versus apply distinction, or low-code
permissions/process/package boundaries without mandatory source build. The
candidate-only design addendum does not supersede these acceptance conditions.

Required follow-up is bounded: enrich the synthetic Registry/Context fixtures
with the approved target-specific check sets and assert inclusions/exclusions;
retain all legacy-required checks and fail-closed behavior. No real provider
integration or acceptance weakening is needed. Re-run affected regressions and
obtain fresh independent review after that repair.

The current three-cycle limit has been reached; no fourth repair was started.
Task status remains In Progress. Formal quality-gate PASS, Done, complete runner,
native Windows/installed-host proof, exact-head CI, commit, push and merge remain
unverified or unperformed. Do not consume this entry as completion evidence.
