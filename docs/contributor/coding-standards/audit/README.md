# Whole-population audit contract v1

`population.json` is the current working reconciliation of every tracked entry at its `base_commit`, including code, configuration, tests, templates, embedded fences, unknown executable labels and symlinks. The original 11,501-entry all-unknown intake at `82b536954626e73b36853711b264cbf5df400d22` remains in Git history. `git_blob` pins the snapshot index blob; `source_sha256` pins observed bytes (symlink target text for symlinks). Re-run `tests/coding_standards.py census --root .` on a clean integration tree and join only explicit contextual owner records whose source hashes match. Dependency inventories, finding hashes and native syntax results alone are not whole-file review.

Classification is routing, not an exemption. Historical/spec/report paths can still be runtime inputs; inspect references before declaring them out of scope. Current generated outputs remain auditable together with their generator. Human-copy artifacts require the existing pending/stale/fresh mirror owner; do not rewrite protected evidence. Intentional bad fixtures need a named negative test and a normal control. Third-party bytes require owner/license/provenance; no directory name alone proves vendor status. Embedded commands in current Markdown, heredocs/here-strings, workflow run bodies and inline scripts require their receiving-language review. The initial classifier's surface tags are candidate discovery, not proof that all embedded grammar was parsed.

States are `unreviewed`, `needs-review`, `confirmed-violation`, `false-positive`, `fixed`, `justified-exception`, `out-of-scope`, `reviewed`. Unknown is never zero. `reviewed` means the entry has applicable tool coverage AND context judgment (or a precise explanation of why a category cannot apply), pinned to bytes and execution evidence. `fixed` needs regression and fix evidence. `false-positive` needs a demonstrated normal control. `justified-exception` needs exact assumptions, scope, rationale and contrasting verification. Neither exceptions nor out-of-scope records may be used as a blanket baseline.

Population fields: `path`, `git_blob`, `source_sha256`, `classification`, `surfaces`, `state`, `owner_issue` (null until assigned), `evidence` (repository links or revision/command/result references), `reason`. Evidence must identify executed tools/versions, actual scope, runtime, result and remaining limits. Unsupported tool/platform means `needs-review`, not `reviewed`. Missing execution, tool crash and product violation are separate facts.

`findings.json` is canonical for concrete findings and uses `schema.json`. A finding pins the observed source line/hash, input→transformation→sink, concrete impact, reproduction, owner issue and evidence. Fixed findings keep the original source hash; their evidence pins the repaired revision/hash and regression. CS-013/014 reuse candidates also need `reuse` intent, public contract, stability evidence, consumer requirements/future divergence counterexample, decision/reason and verification; other findings use null. Stable IDs are never silently reused. Related findings may link one root cause without losing affected paths. Empty findings at intake means none recorded yet, NOT an assertion of no violations.

Initial counts (2026-11-01): 11501 tracked entries; asset=39, current-code=365, current-config=258, current-guidance=315, current-template=63, current-test=1187, historical=9153, protected-human-copy=121. At intake all were unreviewed except the symlink needing review. The current working census supersedes that routing status, but the final #692 audit must still reconcile remaining unknowns, new fixes and post-snapshot changes before closure.

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

## Historical working reconciliation

At snapshot `78a72054`, the census contains 11,639 entries: 1,467 context-reviewed,
10,065 scoped non-program/historical inputs, one intentional symlink-fixture
exception, 75 unreviewed current implementation files and 31 entries requiring
owner review after source changes (six implementations and 25 tests). This is
**not a zero-unknown or final audit claim**. Production shell owner records and
source-bound change reviews remain in progress.

Role exclusions bind file hashes, observed record structure and consumers in
`record-role-scope.json`, `fixture-role-review.json`, historical role records and
`protected-role-delta.json`. Frozen test inputs remain executable where their
consumer deliberately invokes them in isolation; exclusion means the original
input is not a newly distributed implementation, not that it is safe or compliant.
Current validators, fixtures' executable consumers and generators stay audited.
The read-only mirror classifier reported no stale mirrors and preserved pending
pairs. Generated audit JSON/logs are evidence data; parsing them does not turn a
stored PASS into a new execution or repair unavailable original-source bytes.

Coverage imports use only the explicit `entries`, `files` or `sources` of the
listed contextual review artifacts. Source/dependency pins nested inside a test
inventory do not close the referenced program. Partial boundary reviews must be
combined with remaining owner coverage; stale pins remain unknown until a
contextual change review binds the new bytes. Machine ledgers use compact entry
rows; lossless compaction was checked by parsed JSON equality.

## Prior source-bound reconciliation (b0c13112)

The final census snapshots clean commit `b0c131121d5b3bc9875d4424f9f46a11dc5c53c7`:
11,792 tracked entries, with 1,586 reviewed, one fixed, 10,204 scoped data or
historical exclusions, and one bounded symlink-fixture exception. There are zero
unreviewed, needs-review or confirmed-violation entries **at that snapshot**.
Exclusions are not code PASS. Exact whole-source owner reviews or verified
baseline-plus-delta chains support the source judgments; nested dependency pins
and native lint success do not establish them.

The canonical finding ledger separately records 245 findings: 244 fixed and
PY-003's bounded invalid-Python fixture exception. That finding exception and
the population's symlink exception are different records. The finite review
establishes recorded coverage, not proof that no further defect can exist.

See [final verification](verification.md#final-source-bound-reconciliation) for
checks, post-snapshot artifact semantics, native comparison and remaining
platform/source-acquisition limits. Earlier reports and earlier sections retain
their historical scope, including then-unknown contextual coverage. Native scan
results are narrower than this reconciliation and final PR CI remains separate.

## Prior source-bound reconciliation (c259c736)

This supersedes the preceding snapshot after native macOS CI exposed ROOT-008,
a valid-path rejection in evidence link-cycle detection. Snapshot `c259c73610119a5ceafad79634fd8c38918c6a03`
contains 11,797 entries: reviewed=1,586; fixed=1; out-of-scope=10,209;
justified-exception=1; unresolved review states=0. The canonical finding ledger
now has 246 findings: 245 fixed and the separate PY-003 fixture exception.
Role exclusions remain data judgments, not code PASS or universal correctness.

Exact helper/test deltas, paired failing/passing controls, renewed native scan,
full blob checks and post-snapshot publication limits are recorded in the latest
[verification section](verification.md#final-source-bound-reconciliation).
Final-head native CI remains separately required by PR #697.

## Prior source-bound reconciliation (c35176a0)

Snapshot `c35176a068f42ec417feb4e3e213fc926e6ad084` supersedes the preceding snapshots
following actual BSD byte-count, size-admission and cap-argument defects.
It contains 11,810 entries: reviewed=1,586; fixed=1; out-of-scope=10,222;
justified-exception=1; unresolved review states=0. Canonical findings are now
250 records: 249 fixed and the separate PY-003 invalid-source exception.
Finding-record counts do not measure defect frequency; ROOT-010 explicitly
retains several causes and both affected runtime implementations.

The user-requested Claude audit and implementation are recorded with their
precise scope, actual before/after tests and separate Astra delta review.
They do not claim a Claude whole-repository review. See the latest
[verification section](verification.md#final-source-bound-reconciliation) for
source bindings, evidence limits and the three-file derived publication delta.
Exact-final-head PR #697 CI remains separately required.

## Final source-bound reconciliation

Latest-main snapshot `bb50ad4fa2e8805a7a0f46b66428c1e97a13a6bc` includes main #705's
eight documentation changes and preserves the rejected deployment-guard
prototype as data. It contains 11,817 entries: reviewed=1,590; fixed=1;
out-of-scope=10,225; justified-exception=1; unresolved review states=0.
Canonical findings remain 250: 249 fixed and the separate PY-003 exception.

[External-main review](external-main-705-delta.json) binds all eight changes
and the clarification distinguishing direct Python guard checks from unverified
native host/cloud calls. Existing documentation checks passed on 232 Markdown
files and 19 Mermaid blocks. No rejected prototype was applied or new cloud
permission/capability added. See the latest [verification](verification.md#final-source-bound-reconciliation)
for complete snapshot and publication-delta limits. Exact-final-head CI remains
separate from this finite contextual review.
