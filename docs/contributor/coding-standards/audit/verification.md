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
