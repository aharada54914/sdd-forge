# Whole-population audit contract v1

The initial `population.json` enumerates every tracked entry from base commit `82b536954626e73b36853711b264cbf5df400d22`, including code, configuration, tests, distribution templates, embedded fenced code, unknown executable labels and symlinks. `git_blob` pins the index blob; `source_sha256` pins observed bytes (symlink target text for symlinks). This initial clean-tree census has no dirty-source mismatch. Re-run the shared `tests/coding_standards.py census --root .` on the integration tree; include added tracked paths and do not silently carry old review evidence across changed hashes.

Classification is routing, not an exemption. Historical/spec/report paths can still be runtime inputs; inspect references before declaring them out of scope. Current generated outputs remain auditable together with their generator. Human-copy artifacts require the existing pending/stale/fresh mirror owner; do not rewrite protected evidence. Intentional bad fixtures need a named negative test and a normal control. Third-party bytes require owner/license/provenance; no directory name alone proves vendor status. Embedded commands in current Markdown, heredocs/here-strings, workflow run bodies and inline scripts require their receiving-language review. The initial classifier's surface tags are candidate discovery, not proof that all embedded grammar was parsed.

States are `unreviewed`, `needs-review`, `confirmed-violation`, `false-positive`, `fixed`, `justified-exception`, `out-of-scope`, `reviewed`. Unknown is never zero. `reviewed` means the entry has applicable tool coverage AND context judgment (or a precise explanation of why a category cannot apply), pinned to bytes and execution evidence. `fixed` needs regression and fix evidence. `false-positive` needs a demonstrated normal control. `justified-exception` needs exact assumptions, scope, rationale and contrasting verification. Neither exceptions nor out-of-scope records may be used as a blanket baseline.

Population fields: `path`, `git_blob`, `source_sha256`, `classification`, `surfaces`, `state`, `owner_issue` (null until assigned), `evidence` (repository links or revision/command/result references), `reason`. Evidence must identify executed tools/versions, actual scope, runtime, result and remaining limits. Unsupported tool/platform means `needs-review`, not `reviewed`. Missing execution, tool crash and product violation are separate facts.

`findings.json` is canonical for concrete findings and uses `schema.json`. A finding pins the observed source line/hash, input→transformation→sink, concrete impact, reproduction, owner issue and evidence. Fixed findings keep the original source hash; their evidence pins the repaired revision/hash and regression. CS-013/014 reuse candidates also need `reuse` intent, public contract, stability evidence, consumer requirements/future divergence counterexample, decision/reason and verification; other findings use null. Stable IDs are never silently reused. Related findings may link one root cause without losing affected paths. Empty findings at intake means none recorded yet, NOT an assertion of no violations.

Initial counts (2026-11-01): 11501 tracked entries; asset=39, current-code=365, current-config=258, current-guidance=315, current-template=63, current-test=1187, historical=9153, protected-human-copy=121. All are explicitly unreviewed except symlinks needing review. The final #692 audit must reconcile the whole current population, all confirmed violations and new files before claiming closure. This intake census is not that final audit.

`rule-index.json` is a compact navigation index for the 30 rule sections, not an execution or gate registry. The native tool configuration, verification catalog and existing Full/Lite gate own execution. A native lint success never closes the context-review obligations of CS-013–016 or CS-027–030.

The [reuse decision ledger](../reuse/decisions.md) owns consumer-specific CS-013–017 candidate assessments, including justified separation. Its candidate count is not a violation count. Concrete corrected violations remain in `findings.json`; language audit evidence and native reports provide their execution detail.

## Snapshot bytes and derived artifacts

`population-schema.json` fixes the existing population v1 shape and requires
nonempty evidence for terminal judgments. Shape validation does not establish
context review. Exact path-set equality, unique paths, blob/hash consistency and
review evidence must also be checked. Four negative controls actually rejected
unknown state, reviewed-without-evidence, malformed hash and empty population.

A published census is a snapshot of its stated `base_commit`, not a promise
that every subsequent HEAD is identical. Generate from a clean tree to make
`git_blob` and `source_sha256` refer to the same committed bytes. The population
file's own entry identifies its **previous committed bytes at the snapshot**,
not the newly emitted JSON; a file cannot contain its own cryptographic hash.
The enclosing Git commit binds the new census artifact. List and review the
post-snapshot delta separately, including the census/evidence artifacts; do not
keep rewriting hashes until pretending to reach a self-hash fixed point.
Dirty census output remains useful discovery but must not be labeled a clean
commit-byte attestation.

`template-review.json` records full text/context review of all63 distributed
templates, including applicable rules, actual parser/consumer controls and
limits. `scope-review.json` records positive historical references and active
classification corrections. Its absence-of-literal result is not exclusion
evidence; dynamic consumers and actual staged executables remain in scope.
