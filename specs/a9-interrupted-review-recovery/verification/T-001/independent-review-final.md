# Independent T-001 review — corrected frozen candidate

**Production code: ACCEPT within this bounded review; no open production finding. Task acceptance: NEEDS_WORK.** The frozen evidence criterion and independent origin procedures remain unresolved. This is not a formal model-adopted quality gate, Passed, Done or authorization for live recovery.

Reviewed commit `f5815d27cbc87ead72fb9c539cad31fa4a3ecc95`. Final manifest SHA-256: `cc1482ea9625936756e2d68143e712145f35adf22bb61524197e7f50b0c707fb`. All **119 manifest pins**, all six committed source blobs and both final run receipts were verified. Source hashes remained unchanged after independent probes. Reviewer is Work context `/root/review_mode_compat`, independent of author `/root/a9_t001_impl`; no native reviewer identity or unexposed model/effort/cost is claimed.

## Corrected findings

**F1, ambiguous source-B attribution — addressed.** The original dot and unknown absolute-prefix counterexamples now reject in both actual runtimes. Clean admission controls still pass. Correlated spec reservations now need one canonical matching-feature precheck; unresolved source aliases, omitted/mis-cased prechecks and the PowerShell trailing-newline case have named regression evidence. No malformed input is reclassified as proof that B did not launch.

**F4, intermediate domain compatibility regression — addressed.** The first correction's broad precheck-stage whitelist rejected an otherwise verifier-admitted domain record. That restriction was removed in favor of lexical and source-specific ambiguity checks. I reran the same owned synthetic domain fixture: the actual persisted domain verifier and recovery admission both returned0 on Bash and PowerShell. The original B negatives returned1. All fixture bytes remained unchanged. This proves synthetic verifier/admission behavior, not a genuine native domain execution.

**F3, exact hash/canonical coverage — addressed.** reviewer_a.record_sha256 now has explicit uppercase/nonhex/short cases, with missing/null and incorrect cases mapped individually. Their already-passing pre-repair baselines are accurately labeled. Full admission covers escaped-equivalent values, key-order/whitespace, incorrect digest, extra hash-input newline, omitted target and reordered inventory digest. Actual production canonical-helper probes separately prove ensure_ascii for non-ASCII/supplementary Unicode and preserved nonsorted array order. They are correctly labeled unit evidence: an inadmissible Unicode identity is not passed off as a valid whole-record fixture, and sorting an already-sorted valid inventory is not claimed as a distinct rejecting case.

## Remaining acceptance finding

**F2 — Major, frozen criterion remains unsatisfied.** The original checkpoint genuinely failed the missing-admission control while leaving530 cases NOT_RUN per runtime. Final logs contain731 passing cases per runtime, but individual Red evidence is available only for15 Bash and30 PowerShell cases. Explicit existing-pass baselines cover27 Bash and12 PowerShell cases. **689 cases per runtime remain retrospective Green without an individual Red claim.** The final report now states this accurately; accuracy does not satisfy the frozen all-variants Red→Green sentence.

The already-presented one-sentence proposal (patch SHA-256 `6e72240b5298c43925d80a463477b267fb122287ce21d290b23032a48e23c244`) is **not sufficient literally** to reconcile these689 cases: its “Changed defect and negative-mutation ... Red then Green” wording still requires individual Reds for many Green-only negatives. This final assessment supersedes my earlier conditional judgment that the proposal's evidence-classification intent was adequate. The reviewed task body is unchanged; no proposal is treated as applied or as passing evidence.

The minimum honest reconciliation must distinguish three evidence categories while preserving every behavior, assigned variant and runtime:

1. Observed defects: actual named Red→Green.
2. Newly introduced admission-contract cases: genuine missing-admission control Red plus each post-implementation assertion; retain original NOT_RUN and explicitly state that this is not an individual historical Red.
3. Reused already-correct behavior: actual baseline/regression pinned to source revision and execution time; label retrospective checks truthfully.

Each case needs classification; the689 cases cannot all be relabeled by assumption. This would amend the evidentiary criterion and must not silently replace the proposal already presented to the user. Root owns the authorization/provenance reconciliation. No test, origin check or behavior is waived here.

TEST-041/042's independent orchestrator procedures remain unexecuted, and genuine AUTH-001 original human approval/application evidence is unavailable. Those are separate acceptance boundaries. Synthetic content/hash validation cannot authenticate human authorship.

## Verification and scope

I matched all731 unique named outcomes in each final log exactly to728 variants plus3 controls and checked before/after hashes against the final six-file pin set. Claimed genuine Reds and explicit baselines resolve to their actual named FAIL/PASS entries across28 saved logs. The saved752-entry preparation remains design-only; the final reconciliation makes no false one-to-one execution claim. No full suite was repeated.

Independent final probes executed two clean admission controls, four source-B rejections and four domain-verifier/admission controls, all with expected outcomes. Earlier six PowerShell parser probes established string/date preservation, distinct scalar types, decoded duplicate rejection and overflow rejection. The final change leaves that parser intact. System.Text.Json is framework-provided on the script's existing modern .NET floor. Linux PowerShell7.6.7 was exercised; Windows CI remains pending, as the author states.

The reviewed task adds internal admission functions, preserves existing own-stage/reviewer/identity validation and leaves live publication/locking to T-002 and saved consumption to T-003. Actual provider calls, live recovery/reservations and live/root/other-worktree ledger reads were not performed. No source/Git mutation was made by this reviewer.

## History and source binding

The original prior716 review is preserved verbatim in `a9-t001-independent-review-20261024.prior716.md` and `.json`. Original counterexamples, intermediate domain rejection and final successful corrections remain separate artifacts under `/workspace/a9-t001-independent-probes-20261024/`. Companion JSON carries precise findings, statuses and artifact hashes.

Final source hashes:

- `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1`: `fc41fea4e6c6c3eeb39bb2e9ca4f5f96d7a1a9c70ce78fe47d9934000966b60e`.
- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh`: `88062b265569f02573565aa904d26b4385eea5f4e45b82e4c819732f476752f2`.
- `tests/spec-review-interrupted-recovery.tests.ps1`: `9f6807548dbe273d0a89c3e218e15c7dcc9b211c518bb1e050230bdf1ecb8d6d`.
- `tests/spec-review-interrupted-recovery.tests.sh`: `7a4eb91262f8e6bf97da089565d691fa9745e6a658805b16c88571901b67a85c`.
- `tests/spec-review-loop.tests.sh`: `4bbc3cc63f97e8f954dd2731a8a609656fe1fbf66a80bc900a8a9eb8862ff79b`.
- `tests/verification-catalog.json`: `128837b2664db266b0a8234c5f75e32a767c28ad91d20e2f11bd4b9065c25317`.

## Separate criterion proposal v2 review

**Adequate for human consideration; not approved or applied.** Verified v2 patch SHA-256 `3cabed2704e775c3f5e3ac1364ed4081ae5c3fe0b94d85729d8c941484041844`. The earlier presented patch remains unchanged at `6e72240b5298c43925d80a463477b267fb122287ce21d290b23032a48e23c244`.

V2 explicitly distinguishes observed defects, newly introduced admission contracts, and reused already-correct behavior. It requires per-case classification from tested behavior, retains original NOT_RUN and retrospective labels, and does not allow blanket recategorization of689 Green-only cases. Every assigned case/variant, both runtimes and path-safe unit/acceptance/regression evidence remain required. Unexecuted cases stay unverified; adjacent rollback, independent review and quality-gate conditions remain intact. TEST-041/042 and real AUTH-001 are not waived.

This deliberately changes the historical evidence criterion for new contracts; it does not reduce the behavioral contract or test coverage. It can reconcile the wording only after actual authorization and applicable provenance handling, followed by the required per-case classification. It does not itself prove all689 cases belong to the new-contract category or complete T-001.

Correction to my earlier assessment: the first proposal's intent was sound, but its literal negative-mutation Red→Green wording was insufficient. That adequacy assessment is withdrawn. V2 addresses the wording defect; neither version is silently substituted for a user decision, and current task acceptance remains NEEDS_WORK.
