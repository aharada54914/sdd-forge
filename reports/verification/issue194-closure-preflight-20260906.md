# Issue 194 missing-proof preflight

Date: 2026-09-06 JST
Status: OPEN — diagnostic findings, not a quality-gate PASS
User instruction: explicitly address Issue #194's unproven conditions.
Inspected main: 633dcdf6d3289054f832ebbed066e6680e25d645
Inspected A5 PR #245 head: 54b1ff247081971e0560cf20d45f4369e01b5c0d

## Confirmed gaps

1. The existing A6 suite explicitly uses a synthetic trigger fragment, not a real A2 invocation (`tests/lite-spec-capability-block.tests.sh:13-20`). Its success cannot prove the producer/consumer handoff. A real A2 evaluator now exists at `plugins/sdd-quality-loop/scripts/evaluate-predicate.py:1-35`; the historical absence comment is not current evidence.
2. `validate-capability-summary.py:1-45` is a schema validator, not the A5 producer. A lightweight investigation's claim that it was the resolver was rejected by primary review.
3. PR #245 contains the real producer in `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py`. At that pinned ref, lines 1175-1187 and 3521-3524 publish **both** `capability-summary.yaml` and `resolver-evidence.yaml` for Lite. The live issue requires no capability-related artifact except the summary. Primary then checked A5 `design.md` at that exact ref: lines 31-43 explicitly require Summary AND Evidence; lines 164-185 enumerate both successful Lite outputs and evidence-only Block outputs. Thus the extra evidence is NOT merely an accidental implementation artifact. This is a cross-epic contract conflict, not a passing count check. No evidence-file exemption is assumed, and mandatory provenance must not be removed to make a count pass.
4. At the same PR ref, `tests/resolve-project-context-lite-check.py:1-55` documents forced snapshot-mismatch testing plus reconstruction of the summary using the implementation's assembler. That is not observation of a successful published Lite bundle. Its statement that T-007 has not landed is historical: current producer code contains bundle publication. Recheck actual code and assertions, not this stale comment, before selecting coverage.
5. No elapsed-time baseline comparison has been performed. The 22-suite/440-assertion result in the earlier closure report remains scoped functional evidence, not a performance result.

## Concrete continuation sequence

1. Reconcile the issue's artifact restriction with the A5 publication contract using the governing A5/A6 design and ADRs. If no existing explicit exception resolves it, carry the conflict into a scoped specification amendment and independent review; do not silently relax the issue, delete provenance, or expand an already-frozen Done task.
2. Reuse PR #245's producer and A2's evaluator; do not author another resolver. Complete its isolated integration against current main, preserving approval, enforcement and evidence contracts. The already-recorded 23-conflict merge preflight is not a merged implementation.
3. Verify actual producer output consumed by the A4 validator and A6 gate. Cover matched eligible/ineligible capabilities, each catalog upgrade reason, zero matches, missing checks under advisory versus required enforcement, both compatibility fallbacks, invalid combinations, and Lite-to-Full migration. Keep synthetic fixture checks separate from real CLI-chain checks and genuine host-workflow checks.
4. Capture the entire before/after file inventory, including path, type and digest, not just expected filenames. Distinguish feature artifacts, required evidence, shared outputs, and temporary files; disclose every category in the total. For intake Blocks assert no partial Lite specification. For successful Lite resolution assert absence of individual Facet files and Full-track outputs. Apply the reconciled exact output contract, not an invented four-file allowance.
5. Measure legacy-to-legacy performance separately from new Capability Mode overhead. Baseline candidate is pre-A6-integration main `807a818d4b1f3dd15f342d9edb3021e334bc7707`: its live Lite skill has the one-argument risk checker and the same three-file Process. Verify each relevant dependency and payload before fixing this as the benchmark baseline. Compare identical source, host/model, toolchain and cache conditions against the exact integrated candidate; save raw paired durations and output inventories. Predeclare sample count and decision rule before measurement. Do not use suite duration as product latency or add a tolerated regression percentage without a reviewed requirement.
6. Genuine agent-facing workflow measurement must include the actual skill execution and active-hook prerequisites. A shell microbenchmark may diagnose checker cost, but cannot establish end-to-end latency, live-host hook interception or agent-generated artifact count. Existing handshake/auth blockers remain real; no synthetic successful handshake or disabled guard is authorized.

## Evidence boundary

This file is a non-frozen diagnostic/continuation addendum. No product files, protected files, task approvals, frozen specifications, quality verdicts or issue state were changed. Missing metrics remain missing. A5's evidence-vs-count conflict is being investigated before a new acceptance contract is claimed.

## Historical decision request — superseded by approval below

Recommended resolution: retain A5's mandatory Resolver Evidence, explicitly amend the issue-level artifact rule to allow that single provenance artifact in addition to the Summary, keep individual Facet and Full-track outputs forbidden, and report provenance in the complete file count rather than hiding it. This is a change to the literal issue-level acceptance condition and is **not yet approved** by the generic request to address the issue. It requires an explicit human decision and the applicable specification re-review. The alternative of retaining a strict summary-only rule needs a reviewed redesign of A5's evidence storage and its consumers; it must not be implemented as simple evidence deletion. Performance verification is still required under either choice.

## Explicit human approval — 2026-09-06

The user explicitly approved: 「監査証跡 resolver-evidence.yaml を保持し、#194 の『Summary のみ』にこの1ファイルを例外として認める仕様変更を承認する」.

External record: https://github.com/aharada54914/sdd-forge/issues/194#issuecomment-5557047514. The primary subsequently replaced exactly the original Summary-only Done-condition bullet in the live Issue body with the approved two-file allowance, retaining every other bullet unchanged, and re-read the resulting body to verify the mutation. Issue remains OPEN.

This decision supersedes the pending-approval statement above, not the remaining verification requirements. The revised capability-artifact allowance for Lite is `capability-summary.yaml` plus the single audit-provenance exception `resolver-evidence.yaml`. Individual Facet files, Full-track artifacts and any further capability-artifact exception remain forbidden. Preserve existing A5 success/Block publication semantics; this approval does not authorize creating partial Lite specifications on Block or deleting mandatory evidence. Count and disclose the evidence file in the complete before/after inventory. Do not claim the historical artifact-count baseline is unchanged; compare against this explicitly amended allowance and retain independent latency verification.

Next: sweep A5/A6 requirements, design, acceptance tests, layer specifications and task references for the old restriction; propose the narrow corresponding amendment and submit applicable independent re-review. Frozen artifacts and already-Done evidence are not rewritten by this addendum. No implementation PASS, Done, merge or Issue closure follows from approval alone.

### Primary source reconciliation after delegated sweep

The delegated assertion that current A6 `acceptance-tests.md:99-103` requires always-emitted Resolver Evidence is rejected: those lines actually describe required-enforcement/key-absence and a cross-epic A5 addendum. A5 evidence semantics cannot be attributed to A6 by substituting the file identity. Primary verified A5 pinned design's Technical Summary requires Summary and Resolver Evidence only, but did not treat that as proof of an already-reviewed A6 exception.

Primary also read A6 `requirements.md:1054-1056`: the three-file statement describes the Lite specification generation Process; `:1057-1060` separately describes later A5 resolution. A spec-file count is not an entire-run output inventory. Verification must keep these distinct and account for the newly permitted evidence file without hiding it in either category. The new approval resolves the Issue-level policy decision, not the missing end-to-end evidence.

### Review-input boundary correction — 2026-09-06

Primary read the installed `sdd-review-loop/1.17.0/skills/spec-review-loop/SKILL.md`
in full. Its independent-review input allowlist contains canonical requirements,
acceptance tests, optional investigation, calibration and precheck evidence;
it does not include this report as an arbitrary additional input. Therefore the
delegated claim that this addendum is directly a valid gate input is not
established. A passed specification also rejects normal invocation until its
sanctioned reset; an informal review cannot re-bind that frozen contract.

The repeated delegated proposal to supersede A6 acceptance-tests lines 96–110
is rejected: those lines concern the historical required-enforcement/key-absence
contract, not the new output-file exception. The exception does not authorize
changing that predicate or the protected-file scope. No canonical specification
was edited on that advice. A scoped canonical amendment and legal gate transition
must be determined before launching reviewers; the existing output and performance
verification obligations remain unchanged.
