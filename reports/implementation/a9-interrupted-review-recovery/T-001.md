# Implementation Report: T-001

- Task ID: T-001
- Model: not exposed in Work
- Effort: not exposed in Work

Report Schema: implementation-report/v2
Task ID: T-001
Feature: a9-interrupted-review-recovery
Run ID: work-a9-t001-authoring-20261024
Task Attempt Count: 1

This reconciled Work report records preserved evidence and explicitly retrospective supplementary executions. The original authoring report is preserved at `specs/a9-interrupted-review-recovery/verification/T-001/v2/original-authoring-report.md`. This report does not change task status or claim quality PASS. Model, effort and native session metadata were not exposed to the Work author; the literal disclosure below is not a session identifier or an observation of a model. No managed task-input manifest or native identity is claimed.

## Target

The existing approved T-001 closed recovery admission implementation only. Live historical recovery, activation and required-mode promotion are excluded.

## Summary

The actual Work author context was /root/a9_t001_impl, freshly allocated for this task. The Run ID is the actual author-assigned local execution label recorded in the preserved report; it is not a native/provider-generated ID. This document records the original authoring run and its preserved tests, plus separately timed retrospective boundary probes. The user approved criterion v2, and the task owner initially applied it in d4d10f8a6666608f09eaa307d28073bcb41a123f. The canonical task artifact is now restored exactly to the previously reviewed f0e1da226fe41e49c852053192143e58b1016fb6 bytes while the approved amendment awaits genuine formal rebinding. The supplementary classification is assessed against that approved amendment; it does not satisfy the restored old all-variants Red→Green criterion. The task owner also accepted nine bounded TEST-041/042 negative observations, while the frozen origin experiment remains FAIL for missing completion.json. No original NOT_RUN or Green-only history is rewritten.

## Files Changed

Two precheck twins contain pure admission functions; two new test twins exercise the actual functions and existing validators in synthetic disposable repositories. The existing Bash parent suite and portable catalog connect these tests. CLI dispatch/publication remains T-002; saved provenance consumption remains T-003.

## Tests Added Or Updated

The original local admission candidate has 728 named runtime cases and three controls, with 731 PASS in each runtime. The nine separate TEST-041/042 negative observations are credited in a derived table and are not added to the 731 runtime checks. The frozen native experiment remains FAIL. This count is not a quality verdict or task completion claim.

## Outputs

| Path | SHA-256 |
|---|---|
| `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` | `88062b265569f02573565aa904d26b4385eea5f4e45b82e4c819732f476752f2` |
| `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` | `fc41fea4e6c6c3eeb39bb2e9ca4f5f96d7a1a9c70ce78fe47d9934000966b60e` |
| `tests/spec-review-interrupted-recovery.tests.sh` | `9ad841a45612250dbff1284d92615e7ffd4fd1936872f12c3bdc959aa29835f9` |
| `tests/spec-review-interrupted-recovery.tests.ps1` | `9f6807548dbe273d0a89c3e218e15c7dcc9b211c518bb1e050230bdf1ecb8d6d` |
| `tests/spec-review-loop.tests.sh` | `4bbc3cc63f97e8f954dd2731a8a609656fe1fbf66a80bc900a8a9eb8862ff79b` |
| `tests/verification-catalog.json` | `128837b2664db266b0a8234c5f75e32a767c28ad91d20e2f11bd4b9065c25317` |

## Test Evidence

- **Test Command**: bash tests/spec-review-interrupted-recovery.tests.sh ; /workspace/.tools/sdd-forge-dev/bin/pwsh -NoLogo -NoProfile -File tests/spec-review-interrupted-recovery.tests.ps1
- **Test Result**: PASS
- **Test Evidence Path**: specs/a9-interrupted-review-recovery/verification/T-001/reviewed-bash.json

PASS above is scoped to the two recorded local suite runs only. The second receipt is `specs/a9-interrupted-review-recovery/verification/T-001/reviewed-powershell.json`; each receipt identifies its exact command, exit, timestamps, log and unchanged source hashes. The original runs used Linux PowerShell. This reconciliation additionally executed actual original-source and current-source boundary probes, with exact times and source revisions in the supplementary receipts under `specs/a9-interrupted-review-recovery/verification/T-001/v2/`. Separately, exact-head Windows evidence now records 731 PASS/0FAIL on committed f0e1da226fe41e49c852053192143e58b1016fb6 (tested merge revision 3b3bf161ffa2865f205e3bbe78ea13398fc8feb2); all six source pins match the original local candidate. CI attempt 1 overall failed: macOS recorded 718 passes and 13 native SIGABRT/FileLoadException failures. The single same-head attempt 2 also failed: 728 passes and 3 SIGABRT exits (-6) in TEST-057-H13 nonhex/short/incorrect, with recurring FileLoadException. The prior 13 aborted cases now passed; the 3 newly aborted cases passed previously. All 731 case names were retained. The runtime/harness cause remains under investigation; no further blind rerun of this unchanged head is authorized. That restriction does not prohibit authorized diagnostics or CI for a corrected revision. The approved task criterion and this evidence supplement postdate the f0e CI runs and are not claimed tested by them.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

No managed model routing/escalation is asserted by these None fields.

## Isolation Evidence

- **Scratch Root**: /workspace/sdd-a9-recovery/specs/a9-interrupted-review-recovery/verification/T-001
- **Run ID**: work-a9-t001-authoring-20261024
- **Session ID**: not exposed in Work
- **Agent Instance ID**: /root/a9_t001_impl
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

The Agent Instance ID records the actual visible Work context name, not a native provider UUID. Session ID is explicitly unavailable; its disclosure must not be transformed into a purported task-input-manifest session identity. Fresh-agent describes the actual per-task Work allocation documented by the original author. No unsupported-host fallback is claimed. Unavailable native metadata does not prevent truthful Work report authorship or by itself block Implementation Complete. A later formal quality workflow has its own actual evidence and identity checks; these disclosures must never be copied into purported native identity proof.

## Regression Tests Run

Preserved evidence records successful Bash parent/child integration, real child exit-7 propagation, boundary regression, catalog validation and six rollback scenarios. Exact results are retained in the original authoring report and verification addendum. The supplementary source-level probes use actual f8746874413e96775f4b64671a3696be2cc90e7d and f5815d27cbc87ead72fb9c539cad31fa4a3ecc95 validators, byte-identical for the six reused function/file boundaries. They are new retrospective executions, not historical preimplementation tests. Of 114 candidates at each source/runtime, 112 exhibit the existing expected behavior; two syntactically valid diagnostics are accepted by the old boundary and correctly belong to the new interruption-eligibility rule. No production source is edited by the probes.

## Specification Differences

The exact human-approved criterion-v2 sentence remains Approved, pending genuine formal task provenance rebinding. Its initial d4 application set Task-Review-Status Pending, which conflicts with existing Approved/In Progress states. The complete canonical tasks.md is restored byte-for-byte to f0e1da226fe41e49c852053192143e58b1016fb6 (SHA-256 `68198040940bf591c595875a7964f47ab27ff3d4df006686f20a04dff0ea1c1d`): the historical Passed header belongs only to that exact reviewed body. All three approvals and T-001 In Progress remain; no approval is revoked and no new Passed is asserted. Acceptance, design, traceability and layers are unchanged. The v2 evidence remains useful against the approved pending amendment and is not represented as satisfaction of the still-effective old criterion.

## Unresolved Items

Genuine formal rebinding of the already-approved amendment, with the restored old all-variants Red→Green criterion still unsatisfied; corrected macOS/full-CI disposition; later quality gate before Done. The origin experiment's missing completion.json is retained as a protocol failure and does not erase the accepted negative behavior observations or create a new filename requirement in TEST-041/042. No actual AUTH-001 application, positive-origin recognition or live recovery is claimed.

Model/Effort/Session ID unavailable disclosures are accurate Work report fields, not an automatic Implementation Complete barrier. The task owner decides completion after required evidence review; T-002 may depend on Implementation Complete or Done, not exclusively Done. No task status is changed by this report.

## Quality Gate Focus

Use exact frozen input/source/evidence hashes and independent context. Review each evidence category without converting retrospective checks into earlier tests. Independently assess the derived negative-origin observations while preserving experiment FAIL and private raw replay limitations. The bounded independent evidence review is distinct from the later quality gate and does not establish readiness for Done.

## Working Notes

Preserved original authoring report: `specs/a9-interrupted-review-recovery/verification/T-001/v2/original-authoring-report.md`, SHA-256 `d97a7f5792ac44b8a3b9a519256d26393ab47e21891770e78cf54bfdfefec2a8`. Its complete preflight matrix, checkpoint chronology, actual source evidence and scope limitations remain unchanged and are incorporated by reference. Spec revision is recorded at `specs/a9-interrupted-review-recovery/verification/T-001/spec-revision.json`. This report does not retroactively change the original author's preserved report or claim another actor authored that code. The original 119-pin candidate manifest, SHA-256 `cc1482ea9625936756e2d68143e712145f35adf22bb61524197e7f50b0c707fb`, is a historical binding; it does not assert that amended task/report bytes still match the prior candidate.


## Approved-v2 supplementary evidence

These rows remain evidence assessed against the human-approved amendment awaiting formal rebinding. They do not deem the restored old all-variants Red→Green criterion satisfied.

| Runtime | Observed defect with actual named Red→Green | Reused behavior with actual retrospective baseline and regression | New admission contract with shared missing-admission Red and individual assertion |
|---|---:|---:|---:|
| Bash |15|110|606|
| PowerShell |30|110|591|

The sums are 731 per runtime. Exact names, original checkpoint states, actual source revisions/times and links are in `specs/a9-interrupted-review-recovery/verification/T-001/v2/per-case-classification.json` and its sibling `per-case-table.md`. The 110 reused rows in each runtime use actual original/current-boundary results; they are not a relabeling of the earlier 689 Green-only entries. New-contract rows identify their actual acceptance behavior and variant, retain original NOT_RUN where applicable, and explicitly claim no individual Red. Observed-defect rows retain actual original Red logs. All 74 executable base IDs and 78 assigned expanded IDs remain individually mapped. The two remaining base IDs are the nine bounded negative-origin observations below.

The origin table (`specs/a9-interrupted-review-recovery/verification/T-001/v2/origin-negative-derived.md/.json`) is extracted from independent judgment hashes 9a3259a4dda3a4a01d13f95d70973164fb9e3475c98cdeb5464b1f50d974253d (Markdown) and de708e889bd50c0ba32478efc79582ba47afff535fe2949346b39e1477336a25 (JSON). It credits only the specified negative caller decisions, backed by 16 paired read actions and unchanged inputs. The frozen experiment remains FAIL for missing completion.json; proof remains unverified. Raw native events, summary, state, IDs and cwd are not published in this evidence set, and full replay requires authorized access to retained private evidence. No invented public source file substitutes for that capture.

Windows proof was read from the CI owner's external receipt, SHA256 82a184425db16573317f1dd19a16d07d0560428a4cbfb06e103f8baded0d1ccf. CI attempt 1 failure summary SHA256 6516218dfba9b58dcc11c131efa4f4ebbc6fe13544b9d84d1748c7214d6631c4 remains authoritative for that failed attempt. Final attempt 2 summary SHA256 827cda3318fefa556ee872f7a4b79ffb308a411a671074f46be431ca30ab2a04 and two-attempt comparison SHA256 850c7e406b3792682ba14f5e37f6f7acff51e3005a06e3206bd5eaba2978dace preserve the second failure. Canonical CI remains 416 PASS + 1 EXPECTED_SKIP + 33 FAIL, with all 33 failed obligations bound to actual macOS source attempt 2; copied API job rows are not new executions. The CI claims above bind the cited receipt hashes and tested revisions; they do not extend to later source or evidence changes.


## Bounded independent evidence review

The independent Work reviewer `review_mode_compat` accepted the bounded approved-v2 evidence packet with manifest SHA-256 `4368ab7be8ad2780e5e7c5d509cdeed3f5d185d6848d6e819b068385b1f4105d`; the task owner accepted its substantive classification and origin evidence. Review report SHA-256: `81849e1928db76ae46bdd127f106dd551e8f85a02aa30ec2d40bb2b2e2f9147e`; structured review SHA-256: `757555ecc5eaffa5b1e2ffcfde80966c5734ab203e397e3e3050cbc7fa125e5d`. That conclusion preserves experiment FAIL, private raw replay limits and the original test history. It is not full-CI or quality PASS: the review records T-001 In Progress/NEEDS_WORK because the recurring macOS failure remains unresolved.

## 2026-10-24 bounded startup-cache follow-up

After the two failed macOS runs, the task owner authorized a correction prepared by the separate Work author `review_bootstrap_route`, confined to `tests/spec-review-interrupted-recovery.tests.sh`. The current harness SHA-256 is `9ad841a45612250dbff1284d92615e7ffd4fd1936872f12c3bdc959aa29835f9`; the original assertion/run/classification evidence remains bound to `7a4eb91262f8e6bf97da089565d691fa9745e6a658805b16c88571901b67a85c`. The other five source pins and both production prechecks are unchanged. No old receipt, NOT_RUN entry, classification or historical manifest is rewritten.

Each Unix PowerShell child now gets its own disposable `XDG_CACHE_HOME` through one shared launch helper. Four workers, all 731 names and all prior assertions remain. A startup probe records the actual PowerShell/runtime/platform metadata and fails the suite if unavailable. There is no retry, ignored signal, runtime downgrade, product change or global-cache cleanup. The actual before/after probe records shared cache before the fix, distinct caches after it, cleanup, unchanged parent environment/HOME/config/data, and preserved exit 7. It does not claim to reproduce the intermittent macOS crash locally.

The corrected full local PowerShell run passed all 731 checks in 161.58 seconds on PowerShell 7.6.7/.NET 10.0.13, Debian GNU/Linux 13 X64. Evidence is under `specs/a9-interrupted-review-recovery/verification/T-001/v2/cache-correction/`: `full-powershell-exit.json`, `full-powershell.log`, `final-coverage.json`, `before-isolation.json`, `after-isolation.json`, `source-scope-check.json` and the source author's preserved `README.md`. The coverage record verifies exactly the previous 731 unique names in the same order. The scope check establishes byte-identical original logic after reversing only the helper/call/startup additions. Bash launch behavior was unchanged and no new full Bash execution is claimed for this follow-up.

[PowerShell issue 26528](https://github.com/PowerShell/PowerShell/issues/26528) and [dotnet/runtime issue 121977](https://github.com/dotnet/runtime/issues/121977) match the startup-profile-cache failure class. The actual CI runner's cache corruption remains unproven; no upstream fixed-release claim is made. The corrected macOS 731-case run and CI disposition remain required. Historical Windows success and both macOS failures are retained under `v2/ci/`; those old-head results are not attributed to the corrected harness. No full-CI, Implementation Complete, quality PASS or Done claim follows.

The separate cache author's edits and executions are credited by the preserved source packet; they are not attributed to the original admission author. Independent Work review accepted this bounded follow-up for integration and corrected-revision CI; its report SHA-256 is `d41fbd670f5485461f09ac5c2318ed6255b91f32c63fa3d14a48ca0a9194d937` (`v2/cache-correction/independent-review.md`). That acceptance does not prove the macOS root cause or execution result.

The additive current binding is `specs/a9-interrupted-review-recovery/verification/T-001/current-binding.json`. The original `final-manifest.json` remains unchanged as the historical 119-pin binding. The actual user criterion approval, approved patch and application receipt are retained under `v2/`.

## 2026-10-24 exact task-artifact staging

The approved v2 amendment was initially applied in d4, but its Pending review header conflicts with the existing approved/advanced lifecycle. The canonical task artifact has therefore been restored byte-for-byte to the previously reviewed version while the amendment is held pending genuine formal task provenance rebinding. Its human approval remains valid. The exact approved patch/receipt and d4 application history are retained; this is neither an approval revocation nor a new Passed verdict for the amended body.

Actual Bash and PowerShell `check-workflow-state --feature a9-interrupted-review-recovery` both returned exit 0 and `workflow-state: ok` after exact Git-backed sparse materialization. Only 60 tracked public review artifacts (178,354 bytes) and 47 actual tracked files for registry directory presence (1,554,506 bytes) were materialized. The registry was unchanged, no dummy directories or alternate task input were supplied, and no ledger was accessed. The initial 47 unrelated sparse-directory errors in each runtime are preserved. This validates the selected A9 feature, not every registered feature; it is not full CI or task completion.

`specs/a9-interrupted-review-recovery/verification/T-001/v2/lifecycle-staging/staging-receipt.json` binds the restoration, actual checker receipts and retained d4 history. The d4 `current-binding.json` is preserved byte-for-byte as `v2/lifecycle-staging/d4-current-binding.json`; the current binding is refreshed for the restored task/report state. The old 119-pin manifest remains unchanged and historical.

The next genuine task attempt 3 using `--provenance-rereview` may apply the exact already-approved sentence to the single canonical tasks.md, freeze it in the fresh reviewer input set and obtain the real new contract/canonical validation. The route retains the historical Passed header while stale bindings are replaced; that intermediate header is not proof the new body passed. No further human permission is needed for the unchanged approved sentence. No checker rule is weakened and no second live task input is introduced.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Run the required corrected macOS/CI verification and genuine task provenance re-review with the already-approved amendment; keep the restored old criterion unsatisfied until the new binding is real.
- **Unresolved Items**: Recurring platform failure, CI disposition and later provenance/quality obligations above; no automatic status promotion follows from report-format validation.
