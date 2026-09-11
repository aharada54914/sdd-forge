# RT004 remaining consumer-chain gap

Status: incomplete; no formal PASS, ticket resolution, push or merge.

The applied admission hashes remain f171435b6166904167712fe7e93c86f654b8dd3690777e29315298fce1b33903 (Bash) and 2a0eb682e2407e602710c97570680247ccce69fbae16740dcf95cb9113207de1 (PowerShell).
The 448-case successful suite is not proof that every required consumer supports ADR binding.

Current source inspection found no `adr_inputs`, `adr_inputs/v1` or `ADR` matches in:

- plugins/sdd-review-loop/scripts/impl-review-precheck.sh
- plugins/sdd-review-loop/scripts/impl-review-precheck.ps1
- plugins/sdd-review-loop/scripts/task-review-precheck.ps1
- plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh

The absence search is corroborated by the persisted allowlist in review-precheck-common.sh:113: its impl branch permits feature documents, calibration and round evidence, but no ADR path. This remains inconsistent with RT-20260908-004's required downstream binding. The successful round-2 suite exercises summary and investigation binding, not an ADR-bearing predecessor.

Read-only `git apply --check` independently rejected all four existing candidates:

| Candidate in reports/verification | Failing source anchor |
| --- | --- |
| adr-precheck-generation-candidate-20260909.patch | impl-review-precheck.sh:74 |
| adr-precheck-powershell-generation-candidate-20260909.patch | impl-review-precheck.ps1:9 |
| adr-persisted-bash-candidate-20260909.patch | lib/review-precheck-common.sh:1 |
| adr-persisted-powershell-candidate-20260909.patch | task-review-precheck.ps1:11 |

Correction after checking the patch format: these candidates use zero-context hunks. Running `git apply --check --unidiff-zero` independently for each of the four files exited 0. The earlier default-mode failures do NOT establish source drift. No patch was applied, and no enforcement denial occurred. Applicability does not prove candidate completeness or runtime correctness. Old candidate reports already label these incomplete; do not send them for blind human application.

Next work: reconcile these candidates against current original consumers, add/run producer and ADR-bearing predecessor regressions, retain legacy semantics and role isolation, and obtain the required independent review before protected application. Only then attempt fresh ADR-authorized formal review. Recovery-entry restrictions still apply; unrelated integration is not yet admitted. Native Windows remains distinct from macOS PowerShell evidence.

## Direct consumer RED evidence

Added the isolated `--precheck-only` mode to the existing tests/impl-review-adr-inputs.tests.sh driver. It runs the original Bash and PowerShell `--verify-inputs` consumers, with unique synthetic feature data and an existing ADR read only. It does not copy or execute candidates and does not modify the registry or existing review records. Temporary fixture directories are removed in finally.

Command: `bash tests/impl-review-adr-inputs.tests.sh --precheck-only`
Log: `/tmp/sdd-rt004-precheck-red.fclAvv`
Result: exit 1, passed=2 failed=8. Both valid controls passed. Both runtimes incorrectly accepted all four mutations: wrong ADR hash, missing ADR hash, null ADR list, and wrong aggregate input hash. This is expected TDD RED for missing implementation, not a new PASS. The new isolated mode is not yet included in the default invocation; integrate it before completion. Generation and downstream predecessor tests remain separate incomplete coverage.

## Independent candidate scrutiny

Reviewer task `/root/rt004_producer_review` reviewed the Bash generation candidate, current original source and approved plan, read only. It found that the candidate leaves impl-review-precheck.sh:253-257 unchanged: identical design hash rejects the next round even when a bound ADR was corrected. This violates plan consumer step 6. For an extended prior round, compare both design hash and canonical ADR set; preserve design-only behavior for legacy rounds, reject malformed extension, and do not require historical ADR hashes to match corrected current bytes. The reviewer reported no additional concrete serialization/verify-inputs defect within this limited static scope. This is advisory, not a formal PASS; cross-runtime parity and historical agreement were outside that review.

The first lightweight reviewer launch failed because that model is unsupported by the connected account. It produced no review. The successful independent task used the inherited model.

## Continuation: actual protection denial and default test wiring

After the read-only applicability checks above, an ordinary `apply_patch` attempt
to update `plugins/sdd-review-loop/scripts/impl-review-precheck.sh` with the
existing Bash generation candidate was rejected by the PreToolUse SDD guard:
"agents must not modify gate scripts, hook configuration, or critical test files".
The target was not changed. No alternate executor or relocated target was used.
This later actual denial supersedes only the earlier statement that no denial
had occurred at the applicability-check step, not the successful read-only checks.

The default ADR driver now runs `--precheck-only` after admission checks and
combines both exit statuses. It no longer silently omits the known consumer RED
cases. Bash syntax validation passed. The complete original-path rerun finished
under session 65757, log `/tmp/sdd-rt004-full-consumers.D2KGn6`, with exit 1:
admission passed=448 failed=0; precheck passed=2 failed=8. Both runtimes accepted
the wrong ADR hash, missing ADR hash, null ADR list and wrong aggregate input
hash. Overall this is 450 passing cases and 8 failing cases, not a gate PASS.
The default driver now exposes the missing consumer implementation as intended.
Post-run hashes match both human-applied validator hashes above; the registry
remains `21b10cd863c13a5d8399ea26dcc86ff9a0dedbe5eb3e91f89b6dbb134f0d18cf`.
Repository `git diff --check` exited 0. No review verdict, commit, push or merge
was performed.

A read-only GitHub refresh found 11 open PRs and no running CheckRuns. PRs
405/403/245 are conflicting; 404/402/401/394/390/381/371 have failed checks;
400 reports BLOCKED with no failed check in its rollup. This is not evidence of
formal gate completion or authorization to ignore the recovery-entry restriction.

## PowerShell generation candidate independent review

Read-only reviewer `/root/rt004_ps_candidate_audit` found a bounded blocker in
`adr-precheck-powershell-generation-candidate-20260909.patch`: lines 234–242
compare contract/precheck core and layer pins, but lines 265–285 compare the
two reviewer reservations and actual outputs only for design, precheck and ADR.
The original PowerShell next-round branch at impl-review-precheck.ps1:372–374
has no `Assert-ContractReviewerAgreement` call, unlike Bash. Its call inside
`Require-Pass` only covers the spec predecessor in this path. Ordinary next-round
review uses Pending design, so the Passed-stage checks cannot be assumed to
repair this missing binding.

Required next regression: keep contract/precheck agreement valid, change one
reviewer's requirements, acceptance or recorded layer pin, and require rejection
in the original next-round consumer, with a valid ADR-only correction control.
Minimal candidate repair then binds those pins in both reservations and outputs,
preserving existing non-ADR relocation rules. This is consistency checking, not
a claim of authentication against wholesale evidence rewriting. No candidate was
applied or executed in this review; it is not formal PASS.

The same reviewer checked the new default test wiring and found no recursion or
status masking: the child has `--precheck-only` and exits its leading branch,
while the parent retains admission failures and combines the child exit status.
This is static review, not a substitute for the ongoing complete run.

## Generation-path regression and candidate correction

The original-path `--generation-only` run completed with exit 1, passed=6
failed=14, log `/tmp/sdd-rt004-generation-red.ZEtT77`. Both Bash and PowerShell
successfully opened the design-change control and rejected unchanged inputs.
Both failed to emit the expected ADR set and aggregate hash, and rejected the
ADR-only correction that should permit the next round. Bash rejected mismatched
requirements/acceptance reservation pins, but accepted a mismatched layer
reservation and all three tested output pins. PowerShell accepted all six
reservation/output mismatch cases. These failures concern ordinary review
input consistency; they do not assume malicious simultaneous agents.

The fixture records four historical layer pins and runs actual original
precheck entry points under an isolated synthetic lite feature. This is not
full-profile or formal-review evidence. The registry was restored byte-for-byte
to `21b10cd863c13a5d8399ea26dcc86ff9a0dedbe5eb3e91f89b6dbb134f0d18cf`;
post-run `git diff --check` exited 0. Earlier development runs are retained at
`/tmp/sdd-rt004-generation-red.AnZn6Q` and
`/tmp/sdd-rt004-generation-red.a7zy1A`; the final run above supersedes their
fixture/assertion coverage, not their recorded outcomes.

The PowerShell generation candidate now checks exact-one matching requirement,
acceptance and recorded layer pins in both reservations and actual outputs.
Independent reviewer `/root/rt004_ps_candidate_audit` found its prior missing-pin
finding statically resolved and no new blocker in the added 18 lines. This is
not runtime or formal PASS: the protected original remains unchanged. Read-only
`git apply --check --unidiff-zero` succeeded for that candidate.

The review also requested checking emitted ADR data and including the generation
mode in the default driver. Both test changes are now present; the focused
20-case run above includes emission assertions. A complete default rerun after
this wiring change has not been performed. Prior 448-case admission and 10-case
verification results must not be presented as a new combined run.

Remaining: Bash candidate historical ADR-aware reopening and output/layer
binding, independent candidate review, permitted human application, original-path
regression reruns and downstream task-consumer verification. No failed case was
reclassified as PASS, and no formal verdict, commit, push or merge was changed.

## Bash producer correction and extended history baseline

The Bash generation candidate now compares the previous contract/precheck ADR
extension and pins requirements, acceptance, design, all recorded layers,
precheck and ADRs in both reviewer reservations and actual outputs. Historical
NEEDS_WORK pins are not compared to corrected current ADR bytes. The unchanged
rule now compares design plus ADR inputs for extended history, and design only
for legacy history. No protected original was modified.

Independent `/root/rt004_producer_review`, advisory correction cycle 1, found
its prior ADR-only reopening finding addressed and no additional definite
blocker on static inspection. It explicitly did not apply or execute the
candidate and did not give formal PASS. Candidate hashes:

- Bash: `a20fd24a8dc305688e858af84fdd5075f5038ead197072308a252605f8f0a0c9`
- PowerShell: `c9a6ad63345c3c3247ccf2fec89afbc4d4d8176f160c8ab8e3b51fa72b323f64`

Both passed read-only `git apply --check --unidiff-zero` against the originals.
The reviewer requested legacy and historical extension-mismatch coverage.
Added legacy design-change and unchanged controls, one-sided contract and
precheck extension removal, and null extension cases to the original-path
generation group. Its completed run, `/tmp/sdd-rt004-generation-history.ImxtGw`,
returned exit 1, passed=10 failed=20. All four added legacy controls passed;
both runtimes incorrectly accepted the three extension mutations. This is
additional baseline RED evidence, not a regression caused by applied code.
Registry restoration hash remains
`21b10cd863c13a5d8399ea26dcc86ff9a0dedbe5eb3e91f89b6dbb134f0d18cf`.

Prepared `rt004-producer-human-20260911.sh`: exact original/candidate hash
checks, both patches checked before application, private backup, syntax checks
only, no review status changes or Git publishing. Its own Bash syntax check
passed; the helper has not been executed. Applying it still requires the human.
Broader full-profile generation and downstream task consumption remain unproven.

The same independent reviewer subsequently checked the helper and additional
test cases, found the four expected hashes match, and reported no concrete
blocker. It confirmed backup-before-application and no publishing/bypass
operations, and that the historical mutations isolate the intended fields.
This was read-only advisory handoff scrutiny, not formal PASS or a new cycle.

GitHub read-only refresh still shows 11 open PRs and zero running CheckRuns:
405/403/245 DIRTY; 404/402/401 BEHIND with four failed checks each; 394 BLOCKED
with two failures; 390 BEHIND with two; 381 BEHIND with eleven; 371 BEHIND with
four; 400 BLOCKED with no failures in its returned rollup. No merge was attempted.

## Downstream consumer inspection while producer application is pending

Original producer hashes still match the helper's pre-application pins. The
two admission validator hashes match the human's supplied application output.
Neither observation establishes producer regression success.

Read-only application checks for both `adr-persisted-*-candidate-20260909.patch`
files succeeded together with `git apply --check --unidiff-zero`. They remain
unapplied and runtime-unverified.

The actual downstream path is task-review-precheck.sh:415 calling
`require_persisted_pass` in scripts/lib/review-precheck-common.sh; PowerShell
has its own predecessor consumer in task-review-precheck.ps1:160-299. The
current allowlists reject ADR manifest entries. The candidates add current
design-derived ADR-set and byte-hash checks before allowing those paths.

Existing downstream-review-precheck-parity.tests.sh builds legacy predecessor
fixtures with empty precheck objects, then tests contradictory identities and
cross-runtime output equivalence. It does not construct the ADR extension.
A scoped text search found no ADR references in downstream-review-precheck*.sh,
task-review-precheck.tests.sh or task-layer*.sh. This search is not proof about
all repository tests. The ADR-specific driver likewise has no task-precheck
invocation. Therefore its admission/generation results cannot establish
downstream task-stage correctness.

Required next original-path fixture coverage: valid extended predecessor,
unchanged legacy predecessor, current ADR hash drift, one-sided extension,
missing reviewer ADR binding, extra undeclared ADR, aggregate hash mismatch,
and lifecycle-only design normalization, in Bash and PowerShell. Use unique
fixture directories and guarded registry restoration, not the older parity
suite's fixed-name deletion and unconditional registry overwrite pattern.

Additional boundary to resolve before declaring consumer completeness:
task-review-precheck.sh:96-140 and .ps1:310-352 return from VerifyInputs before
predecessor validation. Neither downstream candidate changes that branch.
Thus the new candidate checks occur at task precheck generation, not at the
later task reviewer invocation check. Whether the approved contract requires
revalidation of predecessor ADRs at that later boundary must be resolved from
the scoped design; it is not yet a reproduced defect or a reason to silently
expand the implementation. No candidate was executed, production edited,
formal verdict changed, or CI/merge triggered during this inspection.

## Original-path downstream RED reproduced

Added `--downstream-only` to tests/impl-review-adr-inputs.tests.sh and wired it
into the ordinary no-argument driver. It creates unique lite fixture paths,
synthetic spec/impl predecessor evidence, and calls both original task-stage
prechecks. No candidate code or product function is substituted. Existing ADR
0033 is read, not modified. Registry restoration compares the fixture bytes
before restoring the exact original bytes; owned fixture trees are removed.

Completed focused run: `/tmp/sdd-rt004-downstream-red.OgQ38P`, exit 1,
passed=2 failed=4. Both legacy controls succeeded. Both extended-current and
lifecycle-normalized-design controls failed in each runtime: Bash reported
`persisted impl contract does not match canonical current inputs`, PowerShell
reported `persisted impl contract has an invalid allowed input manifest`.
These are intended RED results against unmodified task consumers, not formal
review failures, and not evidence of a fault in the human-applied admission fix.

Local test scrutiny: this slice uses no fixed feature name, modifies no real
ADR/review, checks emitted schema/feature as well as exit status, and keeps
raw failure output. No Critical issue identified in the bounded test slice;
this is author scrutiny, not the ticket's required independent review. Negative
mutations and full-profile cases remain to add after the positive path can be
exercised; candidate runtime behavior remains unproven. No full default suite
rerun after wiring, no native Windows run, no formal gate or publishing.

The approved plan's consumer sequence item 5 explicitly places ADR validation
in predecessor impl-contract consumption and does not authorize ADR reads for
task reviewers. The earlier VerifyInputs boundary observation is retained as
an observation, not used here to add a new task-review input contract.

## Expanded downstream negatives and independent candidate scrutiny

Completed original-path run `/tmp/sdd-rt004-downstream-mutations.FdzAt1`
returned exit 1: passed=2 failed=4 inconclusive=10. The five negative cases per
runtime are stale ADR hash, incorrect aggregate hash, missing contract
extension, missing precheck extension and missing reviewer ADR binding.
They all reject, but rejection is inconclusive while the extended positive
baseline fails. These are not ten successful negative tests.

Independent advisory reviewer `/root/rt004_producer_review` returned three
candidate blockers (static findings, not reproduced candidate runtime results):

- Reviewer output JSON is not cross-bound to the reservations: Bash patch
  lines 148–155 and PowerShell patch lines 229–245 inspect reservations only.
- Contract/precheck layer maps can disagree with reviewer layer pins: Bash
  patch lines 143–153 and PowerShell patch lines 227–245.
- Strict relative core design/precheck paths regress supported core-path
  relocation: Bash patch lines 150–151 and PowerShell patch lines 231–235.
  Raw ADR paths must remain canonical relative paths; this finding does not
  authorize relaxing ADR path validation.

The reviewer did not apply or execute candidates and did not issue a formal
PASS. A combined source-search/hash command was denied by the hook; the
reviewer did not reroute it and could not independently calculate candidate
hashes. Preserve that limitation. Next, verify the findings against the
approved contract, add corresponding fixtures, and repair the candidate pair
before another independent review and any human protected application.

## Core relocation candidate correction and layer controls

Added original-path `absolute-core` and `layer-bound` positive controls, plus
`layer-pin-mismatch`. The latter changes the contract/precheck layer hash and
recomputes the aggregate while keeping the reviewer layer pins current. It
is conclusive only if its own layer-bound positive baseline succeeds.
Run `/tmp/sdd-rt004-downstream-layers.UaVHqI` exited 1 with passed=2 failed=8
inconclusive=12. This proves missing extended acceptance in the original
consumer, not the candidate-specific layer defect, which remains static.

Corrected the core relocation candidate only: Bash reuses the existing jq
relative-path recipe for design/precheck lookups; PowerShell calls its existing
Get-ManifestRelativePath. ADR comparisons remain against raw paths. No original
consumer was edited or candidate executed. Combined `git apply --check
--unidiff-zero` and `git diff --check` succeeded. Current candidate hashes:

- Bash: `171dad1103b5ab0dfae46dbb888298dfac544b3635c1d0d90fdb3f9cfd8534a8`
- PowerShell: `d0544edb8859a33fc1e3bc39955f992f605e40b3ab6afc66d5a6a81c86b7ca6c`

Author review found the narrowed lookup change preserves raw ADR restriction
and existing runtime-specific relocation rules. Runtime verification and
independent re-review remain required. Reviewer-output and layer cross-binding
findings are not fixed by this change. No formal PASS or ticket resolution.

## Downstream output and document-binding candidate correction

Added four output-only mutations per runtime (ADR, precheck, design and run
identity). Fixtures now write synthetic reviewer output JSON using the actual
schema/stage/role/run_id/host_session_id/allowed_input_manifest representation.
Actual stored reviewer outputs do not have feature/attempt/round top-level
fields; the repair does not invent a requirement for them. Existing real
review evidence is unchanged.

`/tmp/sdd-rt004-downstream-outputs.g7JOxu` exited 1: passed=2 failed=8
inconclusive=20. Every rejecting mutation remains inconclusive because its
matching extended positive baseline fails. This is original-consumer evidence,
not candidate execution. The registry restored to its original hash.

Candidate updates now bind each reservation's core and layer document pins to
the precheck, read the two canonical reviewer outputs only for extended
contracts, check output identity against the reservation, and compare complete
normalized manifests. ADR paths are checked raw before admitting normalized
equivalence; core paths retain existing relocation rules. No legacy extension
is retrofitted. Both patches pass combined read-only application checks.
An initial Bash patch hunk line-count error was detected by git apply --check
and corrected; it never applied to a production file.

Independent advisory re-review requested from `/root/rt004_producer_review`.
Until that review and original-path runtime verification succeed, these remain
unapplied candidates, not a resolved ticket or formal PASS.

## Per-file JSON singleton correction

Independent re-review identified a Bash-only positional-slurp defect: a second
object in reviewer A's file could substitute for the actual reviewer B file.
The candidate now loads four independent slurp arrays and requires exactly one
object per file before binding outputs by role. The test adds
`output-multiple-json-empty-b` with both valid outputs in A and an empty B.
An intermediate concern about absolute-path fallback dropping entries was
withdrawn by the reviewer; no change was made for that withdrawn finding.

Original-path execution `/tmp/sdd-rt004-downstream-singleton.qUfqwf` exited 1:
passed=2 failed=8 inconclusive=22. The extended positive baselines still fail
on the unapplied originals, so no negative case is counted as successful.
Combined candidate apply-check, test-driver syntax and whitespace checks pass.
The human-applied admission hashes match the reported f171435b… / 2a0eb682….

Independent reviewer `/root/rt004_producer_review` found no remaining concrete
blocker in this bounded singleton change. This is static advisory review only,
not a formal gate or runtime PASS. Candidate Bash hash:
`3880a194e818f7c24b6ac329b747fb87dbec15866f38a4a0d887a85d1be12ba6`;
PowerShell hash:
`e8182f380ce64c0b1918e52aed0dae97758183660839c46838a3fc78bc995ecc`.
Human-only helper: `reports/verification/rt004-downstream-human-20260911.sh`.
Protected originals remain unapplied. The same independent reviewer completed
helper-only scrutiny with no concrete blocker: exact four hashes, applicability
check, unique backup before application, syntax checks and no publication.
Failure stops without automatic rollback; backups remain available. The helper
was not executed by the agent. This is not a formal gate verdict.
