# RT004 independent static review — shared-layer historical bindings

Scope: RT-20260908-004 Bash workflow candidate DATA only. No production
application, executable extraction or candidate execution occurred. This is
not a formal quality-gate report or an RT004 completion decision.

Independent reviewer: `/root/rt004_bash_candidate_review`.
Reviewed initial candidate SHA-256:
`2ca0f5c7cd7e55b0484a5c683355d1098b3cde5ffe5d7071ce3f2ea9ae142b0f`.

## Confirmed Major and scoped correction

An empty precheck layer map makes its per-pin validation vacuous. The existing
layer-superset compatibility rule may then admit saved manifests with different
hashes for the same extra layer path before the historical opening return.
The reviewer confirmed that the original workflow validator's layer-superset
rule at lines 991–1008 is intentional issue #71 compatibility, not permission
to remove that compatibility globally. Legacy reviewer agreement in
review-precheck-common.sh:30–61 checks the core document pins, not layer pins.

The candidate correction groups layer entries from the two contract manifests
and the two actual reviewer manifests by the existing normalized relative path.
Every group must have exactly one unique saved hash. It preserves optional
superset membership and the existing nonempty layer-map requirements. The
legacy no-extension early return is unchanged. No current disk layer hash is
substituted for historical saved hashes.

Updated candidate:
`reports/verification/adr-workflow-bash-history-candidate-20260909.patch`
SHA-256: `87f3f4547b3a75e10bf57df2f1b9686add25c456c893cbb068e594fb43dab3f1`.
`rtk proxy git apply --numstat` parsed it successfully (388 additions,
11 deletions; net 377). This validates patch format only, not applicability
or behavior. No actual protected file was modified.

## Withdrawn finding — retained audit record

The initial review also classified round-3 Major handling as a Major defect.
On requested source recheck, the reviewer explicitly withdrew that finding:
impl-review-loop/SKILL.md STEP 5:180–187 persists Major as NEEDS_WORK;
STEP 6:264–268 prints BLOCKED as the terminal outcome and does not instruct a
rewrite of the persisted verdict. The candidate formula was left unchanged.
Preserving this distinction avoids inventing a new persisted-state contract.

## Required next checks

- Static independent re-review of the exact five-line correction completed:
  the reviewer verified the updated hash and marked this finding fixed on
  static inspection, explicitly retaining the behavioral-test requirement.
- Add coherent extended-history fixtures: empty map with equal additional
  layer hashes accepted; conflicting hashes rejected; legacy semantics retained.
- Exercise actual validators through the permitted application path. Do not
  execute copied candidate code to work around the protection boundary.
- Finish PowerShell workflow parity, complete runtime integration and run the
  required independent review, regression suites, native Windows and CI gates.

The documentation candidate separately makes the canonical digest serialization
explicit. Its hash and patch-format check are recorded in
adr-contract-docs-candidate-status-20260908.md. No commit, push, merge, issue
closure, historical verdict change or task completion occurred here.
