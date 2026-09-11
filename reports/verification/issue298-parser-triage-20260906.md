# Issue #298: parser triage, not a registry update

Inspected main ae4dc095ecde352f980ef06dec469b9b286ad10c read-only. The divergence issue contains many numeric/CSS/SVG-shaped tokens alongside model-shaped labels; neither category alone proves an actual supported-model registry mismatch.

The current implementation explains how noise reaches the report: `.github/scripts/check-model-freshness.sh:161-162` extracts whitespace-delimited words using only a full ASCII letters/digits/dot/hyphen allowlist and the presence of one digit. It does not establish that a token is a model identifier. `compute_divergence` compares these tokens against registry names/basenames at line 150. This is static source evidence, not a fresh vendor-source verification or an executed regression test.

The existing fixture suite has divergence/dedup coverage at `tests/model-freshness-check.tests.sh:306`, no-difference coverage at line 360, and issue-body adversarial-content coverage at line 384. A repair must retain those behaviors and registry read-only handling while adding a concrete HTML/CSS/SVG noise fixture and genuine model-positive controls. No existing assertion should be weakened merely to filter the observed report.

The locally available all-ref history for the script returns e8cdd746 (Pillar D integration #186) only. A targeted search of current specs/review tickets for `#298`, `Issue 298`, and `issue-298` found no match. These bounded checks do not establish that no unpublished or differently named work exists. No remote branch was deleted or rewritten, and no source, test, registry, workflow, frozen specification, or issue state was changed.

Next: reconcile remote branch inventory and the Pillar D task contract, then define an explicitly reviewed model-token admission design and fixture matrix. Do not close #298 until both false-positive detection and any real registry divergence are resolved with evidence. Do not execute the live script as a diagnostic: its main function invokes GitHub issue creation/comment operations.

## Existing investigation recovered

The root `ISSUE298_INVESTIGATION.md` already records the same defect, a pinned 31-remote-head comparison, and baseline fixture-suite verification at 9dd531f94882eb18fe7f783de395cd1c7a8ee208 (40 Bash / 29 PowerShell successes). Those are historical observations, not new executions at the main SHA above. Reuse that investigation rather than starting a duplicate feature. Its proposed recognition-contract work is explicitly not Approved; the bounded current search does not supersede that authorization status. This continuation therefore adds current-source confirmation only, not a newly discovered fix or closure evidence.
