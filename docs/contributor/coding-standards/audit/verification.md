# Intake verification (2026-11-01)

This records checks of the #686 deliverables, not a whole-repository compliance
verdict. Source baseline: `82b536954626e73b36853711b264cbf5df400d22`.

- Compared the 11,501 population paths against `git ls-files -z`: exact set,
  no duplicates. For every recorded `git_blob`, read `git cat-file blob` and
  recomputed SHA-256: all matched `source_sha256`. This checks enumeration and
  byte pins, not semantic review of those files. The symlink is represented by
  target text and was not followed.
- Validated `findings.json` against `schema.json` with the installed `jsonschema`.
  The original intake had no finding records; this was not zero observed violations. Later handoffs are recorded below.
- Checked that the rule index has exactly CS-001 through CS-030, all rule source
  references resolve to Source records, and local Markdown links exist.
- Ran `python plugins/sdd-quality-loop/scripts/validate-research-evidence.py
  --file docs/contributor/coding-standards/research/records/research-evidence.json`:
  `VALID coding-standards scope=file history=unchecked sources=16 claims=5`.
- Also validated `--previous` against the exact metadata in commit `212028cd`:
  `history=checked`; the six supplemental sources append without rewriting the
  initial Source/Claim revisions.
- The existing planner/merger ran over the initial ten-source set. Its strict
  graph command passed while records were staged in the proposed feature path.
  Final contributor placement intentionally has no repository-mode research-gate
  admission; graph/binder require repository inputs and no current graph/binder
  PASS is claimed. The research map explains this distinction.
- `git diff --check` passed. No protected mirror, frozen evidence or approval
  artifact was modified by the intake work.

Native language-tool execution, semantic reviews, actual code fixes and their
regressions belong to the linked language/check/reuse work. The final #692
reconciliation must refresh the population for added/changed tracked files and
retain unresolved states. Tool timings, token consumption, recurrence reduction,
and a before/after whole-repository defect count were not measured by this
intake check and remain unknown.

## Python handoff reconciliation

Imported 37 concrete finding records from #689 commit `bb868407` into the central
`findings.json`; checked each against the finding schema and recomputed every
original source SHA-256 from baseline `82b53695`. E701/E702/E731 readability
changes map to CS-015, and the deliberately invalid Python fixture maps to
CS-020 with its specific resolver control. The language owner's evidence retains
command/reproduction/fix details. This metadata reconciliation does not rerun or
claim independent execution of those regressions, and does not change any
population entry from unreviewed based on lint success.

Schema negative controls rejected unknown rule CS-999, unknown state `passed`,
empty evidence on a fixed finding, and null resolution on a fixed finding.
The actual handoff records pass the same schema. Native tool mappings and
consumer-specific reuse decisions are linked to their existing owners.

## Shell handoff reconciliation

Imported 32 #688 concrete records from the `a62daa18` handoff into the central
ledger (69 records including Python). Checked every original source SHA-256
against baseline `82b53695`, and every provided repaired-source SHA-256 against
its exact fix revision. Structured source/regression evidence is retained as
JSON strings because the version-one finding schema defines evidence as strings;
no fields are discarded. This is pin/metadata validation, not an independent
rerun of the language owner's regression commands. Remaining language findings
must still be reconciled; the whole population remains unreviewed.

Six rule-example controls executed with an input containing single/double quotes,
a newline, Japanese text, shell metacharacters, regex operators and query
separators. JSON round-trip, regex literal full-match, URL query round-trip,
SQLite parameter binding, a Bash argument array and a literal Python program
receiving an environment value each preserved the intended value. These narrow
controls substantiate the examples; they do not establish all destination rules,
Windows batch semantics or whole-repository compliance.

## TypeScript/JavaScript handoff reconciliation

Imported 11 #690 records after the language owner supplied original baseline
line numbers and SHA-256 values; verified every source hash against `82b53695`.
Repaired source hashes remain in evidence. The language owner's durable summary
is `audit/typescript/summary.md` at `9a68aefc`, including six actual baseline
regression failures and the signed-epoch rejection control. Temporary log paths
are not the final evidence destination. TS690-008 maps to CS-021 (external input
narrowing), not parser-reuse CS-014: accepting a numeric prefix is the defect,
and no consolidation decision is asserted. Schema and unique-ID checks pass
for 80 central records. Record counts are grouped audit observations, not a
normalized defect-frequency estimate or proof of whole-population closure.

## Further shell boundaries and known unresolved violation

Imported four #688 follow-up records from `28ecd8ce`, validating both original
and current source pins. Installer URI-component fixes map to CS-008; the release
option-terminator fix maps to CS-009. SH-008 remains `confirmed-violation` with
null resolution: an inaccessible stop-marker directory can cause the POSIX
predicate to treat an inspection failure as absence. The actual unprivileged
EACCES reproduction is recorded by its owner. The central ledger now has 84
records and explicitly does **not** report zero confirmed violations. Further
PowerShell argument-boundary findings are still being investigated by #688.

The corresponding isolated negative controls also executed: interpolated JSON
failed to parse a quote; an unescaped regex matched unrelated text; concatenated
query data introduced a second parameter; concatenated SQLite text changed the
query predicate while binding did not; unquoted shell text split into two
arguments; and embedded Python source failed on an ordinary apostrophe. These
controls used an in-memory database and local child processes, and did not
contact providers or mutate repository data.

## Embedded JavaScript handoff

Added TS690-012–014 from #690 commit `6e49f016`, bringing the central ledger to
87 records. Rechecked original installer source pins and schema. These record
read-error fallback, temporary-file exclusive creation and permission issues in
embedded installer programs; the owner's durable summary covers four affected
install/uninstall bodies, 12 actual baseline failures and 12 passing corrected
controls. File suffix alone did not define the language audit scope. No claim
of whole-population context review is added.

## Native argv, AWK and template follow-up

Imported PS-030–032 and SH-030–031 from shell handoff `a3241e56`, checking
all five original hashes against `82b53695` and repaired hashes against the
integrated files. The central ledger now has 93 records including DOC-001.

DOC-001 was independently reproduced during template review: an untouched Lite
quality report admitted an Approved/Done T-001 through the actual state consumer.
The new existing-suite control gave 23 passed/1 failed before repair and
24 passed/0 failed afterward. The default is now FAIL with NOT_RUN check labels;
the explicit completed PASS normal control still succeeds. This does not claim
that a report alone proves live project execution or full Lite acceptance.

Mirror check found eight already integrated stale manifest entries unrelated to
the template/parity test; integration owns their existing synchronizer update.
Pending mirrors were left intact.

DOC-002: all 10 JSON and four YAML templates were parsed. GitLab's echo
command contained colon-space inside an unquoted YAML scalar and parsed as a
mapping. The pinned repository js-yaml parser independently reproduced this,
with the added existing-suite control failing (24/1); a YAML literal block
repairs it (25/0). Both CI placeholder programs were actually run and returned
1 as intended. No remote GitLab pipeline execution is claimed.

## Final source-bound reconciliation

Snapshot: clean `b0c131121d5b3bc9875d4424f9f46a11dc5c53c7` (2026-11-02).
Production and executable-test source equals code freeze `bd94f864`; later
commits up to this snapshot only add/reconcile evidence metadata. The exact
population is 11,792 entries: reviewed=1,586; fixed=1; out-of-scope=10,204;
justified-exception=1; unreviewed=0; needs-review=0; confirmed-violation=0.
This is finite, source-bound contextual coverage, not a universal no-defect claim.

Actual checks performed for this snapshot:

- Existing census enumerator `tests/coding_standards.py` read a clean tree.
  Exact unique path set equals `git ls-tree -r --name-only -z` at the snapshot.
  All 11,792 recorded blobs were independently read through `git cat-file
  --batch`; every SHA-256 matched. Symlink target text was hashed without
  following the link.
- Installed jsonschema 4.26.0 validated population and finding schemas.
  Population compaction was lossless by parsed-JSON equality. Every terminal
  population row carries evidence. All 245 finding IDs are unique: 244 fixed,
  one justified exception (PY-003). All twelve newly imported original source
  hashes match actual Git bytes at their stated owner baselines. Earlier
  source pins retain their historical verification above.
- Imported only explicit contextual `entries`, `files`, `sources`, or the
  review-contract record's explicit whole-file `source_files`. Narrow deltas
  require their exact prior hash in a whole-source review chain. Nested test
  dependencies, consumers, finding fix pins and syntax inventories never add
  whole-source coverage. Context-precheck `test_deltas` use their explicit
  `before_source_sha256`; final test/CI/installer/identity/registration deltas
  join their recorded baselines. The final 3,062-line prepare-panelist test
  review closes the last genuine test-source gap.
- `external-main-delta.json` records externally merged documentation/record
  changes and the actual joined catalog/workflow registration delta. The
  existing catalog suite ran: 15 tests, one explicit skip, overall OK. Formal
  mapping's current validator hash and unchanged reservation-tail hash were
  recomputed; no new TLC or whole-application formal proof is asserted.
- `final-record-role-review.json` binds 152 changed/new evidence records.
  Their JSON/text structures and ZIP CRCs were inspected; no captured harness
  or archive was executed merely to classify it. A literal search of current
  tests/scripts/workflows/plugins found no direct consumer of those record
  paths; structure and documented producers establish their evidence role,
  not absence of a reference alone. The two reconciliation JSON artifacts
  themselves are parsed metadata, bound by this clean snapshot and Git.
- Independent native PowerShell parent-extraction control confirms the
  root-path repair: `Split-Path -Parent /var` loses the root, while
  `IO.Path.GetDirectoryName('/var')` preserves `/`. This is a Linux primitive
  control and contextual delta review, not native macOS/Windows execution.
- `git diff --check` passed for the derived publication changes.

The matched native comparison is retained in
`reports/verification/coding-standards-20261101/native-comparison.json` and
`task-native-evidence.zip`: the same checker/tools report 285 native findings
on task baseline `82b53695` (856 inspected, 70.06 seconds), versus zero on code
freeze `bd94f864` (884 inspected of 885 selected, 70.15 seconds). One intentional
invalid-source fixture remains explicitly excepted. These are selected native
rule findings, not the count of contextual findings or a new whole-repository
performance benchmark. Historical publisher-baseline/unknown-context wording
in earlier reports is preserved as historical evidence.

Post-code-freeze metadata before this snapshot is exactly:
`audit/external-main-delta.json`, `audit/final-record-role-review.json`,
`audit/findings.json`, `audit/shell/prepare-panelist-full-context-review.json`
(all beneath `docs/contributor/coding-standards/`), plus verification report
`README.md`, `SHA256SUMS`, `native-comparison.json`, and
`task-native-evidence.zip` beneath
`reports/verification/coding-standards-20261101/`. No product source changed.

The derived publication delta after the snapshot contains only this
`verification.md`, audit `README.md`, and `population.json`. These are reviewed
explanatory/serialized evidence artifacts: counts copied from the checked
snapshot, limitations retained, no executable dispatch or acceptance policy.
The census's own entry identifies the previously committed census bytes at
`b0c13112`; it does not hash its newly emitted self. The enclosing Git commit
binds the new census. The same rule applies to updated explanatory artifacts.
Later independent review or CI evidence is a separately identified post-snapshot
delta, not silently claimed to exist inside this census.

Final required native CI is owned by PR #697 and must pass its exact final head;
this document does not assert an outcome before that run. Linux component
receipts and simulated missing-API/CRLF controls are not native Windows
PowerShell5.1 or macOS receipts. Source/Claim original web bytes remain
unavailable where the research records say reader-body-only/unassessed; this
reconciliation neither reacquires them nor upgrades those claims. No historical
report, pending mirror, task approval or external-main record was rewritten to
manufacture acceptance.
