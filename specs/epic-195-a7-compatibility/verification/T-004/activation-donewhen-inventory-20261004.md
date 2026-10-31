# T-004 current Done When evidence inventory

Run ID: epic-195-a7-compatibility-t004-f3-activation-20261004
Task Attempt Count: 3

Implementation-side verification only. No independent verdict, lifecycle
transition, frozen specification change, commit or push is made here.

## Current evidence

| Done When item (tasks.md:674 onward) | Current evidence and disposition |
|---|---|
| 1. F1 full and F2 lite structure against unchanged templates | `activation-final-sh-20261004.log` / `activation-final-ps1-20261004.log`: exact paths, frontmatter/headings and status names. Corpus and template source were not refreshed. |
| 2. REQ/AC identifier grammar | Both full/lite generated-identifier assertions in the final logs. |
| 3. F4 governed skip until A4 merge | Current AC-007 condition is active; final logs exercise F4 full-track validation, rather than emitting an obsolete skip. |
| 4. F3 and compound F5/F6 dependencies | Current AC-042 is active and exercises F3; F5/F6 still emit AC-043 skips and both emitted lines pass the allowlist audit. |
| 5. Offline corpus and hard parser failure | Current suite uses local corpus/canonicalizer; current F3 malformed and coherent template/corpus malformed mutations are killed in both runtimes. Product-free checks fail closed (below). No live model execution. |
| 6. Malformed RED, full GREEN, independent gate PASS | Historical malformed RED must use `red-accounting-correction-20260927.md` (113/3 classification, not withdrawn 115/1). Fresh activation RED and current full GREEN are in the repair addendum. Independent gate PASS is still pending. |
| 7. Aggregate runner registration | Both final logs assert their shipped registration. Registration is not a claim that the whole aggregate was rerun or passes. |
| 8. Report, gate and traceability | Report/addendum exist; frozen traceability already maps T-004 to REQ-002 and all six ACs at lines 77/98/121/133/134. Its old verification status is not edited. Gate PASS remains pending. WFI-004 requires the coordinator to reconcile the literal frozen-document-update Done When through approved amendment and provenance re-review, not deem it satisfied merely by this addendum. |

## Completed supplementary checks

- Final current-tree GREEN: `activation-final-sh-20261004.log` is **77/0**;
  `activation-final-ps1-20261004.log` is **84/0**, each exit 0 with the F3 active
  regression passing. PowerShell's seven extra checks exercise registration syntax.
- `activation-mutation-{sh,ps1}-20261004.log`: each **5 killed / 0 survived**.
  Cases: F3 missing required path, wrong heading, extra status field, malformed
  heading; coherent malformed requirements template plus F1 corpus.
- `activation-classifier-20261004.log`: ANSI and wrap classifier mutations
  each rejected with exit 2; restored classifier exit 0.
- `activation-manifest-20261004.log`: valid candidate manifest, isolated
  corruption rejected, restored manifest valid. This does not resolve ownership.
- `activation-product-free-{sh,ps1}-20261004.log`: source test helpers and corpus
  copied to isolated task scratch, but required plugin/spec surfaces absent;
  each suite exits 1 with **0 passed / 4 failed** as expected. Scratch removed
  by its exact-path exit trap; source files unchanged.
- `bash -n` on the Bash suite and new activation regression/mutation drivers,
  `git diff --check`, repository structure checker all pass. Structure has only
  the existing CLAUDE.md advisory.
- `git diff --exit-code` confirms no diff in recorded corpus, frozen
  requirements/design/acceptance/traceability or either aggregate runner.

## Inputs at the final verification boundary

| Input | SHA-256 |
|---|---|
| tests/structural-compatibility.tests.sh | 8c763a5f321f6eaed481cc7d4b7756f074a1df562a7c3f3c15c318580ce76222 |
| tests/structural-compatibility.tests.ps1 | f4a18da6ce7f898572d6a166bc303bd2866bb5df630aff1ce52b52110089af60 |
| tests/lib/skip-allowlist-evaluator.sh | ac68f74849237b00739c37028e745b9a2ee3ec5eca00dda4abc2e94c314cb5c3 |
| tests/lib/skip-allowlist-evaluator.ps1 | 27cb8ac6b1974614a9c8908cf3a7a8f28624480b81ca0b5b19255f6eeee1af7b |
| tests/fixtures/skip-allowlist-manifest.json | 7bf84702a21059211f0b4d43189fbb88fc6a1decb933a59fb04206df8b1dc15a |

Shared evaluator/manifest changes belong to T-010. This report records the
consumed bytes, not ownership or approval of those changes.

## Gate preparation / unrenewed claims

The parent coordinator must resolve gate preconditions and reserve an independent
evaluator. Include the activation repair, this inventory, fresh final and
mutation logs, malformed RED correction, relevant current tests/helpers and
frozen task/spec inputs in the admitted evidence. Do not rely on old 40/0 or
historical output-hash rows as current-head proof.

The implementation report's historical protected CI candidate scope finding is
still not resolved by a valid manifest: T-011 owns CI wiring. Do not rewrite
the protected workflow or claim that this task owns its application.

Full 116-mutation, depth-1, bump replay, aggregate runners and CI were not rerun.
They are historical supplementary claims, not fresh proof of this activation
delta. The old f3-skip mutation expects inactive behavior now unreachable under
current origin/main; depth-1 and bump scratch drivers omit current activation
ancestry evidence. Their unmodified rerun would not meaningfully validate the
same historic claim. Any renewal must first define the intended current
condition, isolate Git evidence, and preserve the protection boundary. This
inventory does not authorize that semantic change or silently drop the checks.

Reproduction for current focused GREEN:
`rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-regression-20261004.sh sh`
and replace `sh` with `ps1`; mutation uses `activation-mutation-20261004.sh`
with the same runtime arguments. Formal gate remains the next authority.
