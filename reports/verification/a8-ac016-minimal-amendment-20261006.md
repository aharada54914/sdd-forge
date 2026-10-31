# AC-016 bounded amendment candidate — NOT ADOPTED

Owner: A8 checkout; observed HEAD 495c88d67af44530687ecea3ce9fb0a90a336539.
High-risk existing T-005/T-008 evidence-contract correction. Existing approval,
status, dirty changes and historical reviews are unchanged. No production code,
protected source, reservation or signature has been changed.

## Required behavior versus withdrawn additions

- requirements.md:441–448 requires five named consumers exercised per runtime,
  with entry-point name, source citation and runtime/cell in a fingerprinted
  inventory. requirements.md:163–166 and 728–732 repeat that requirement.
- design.md:517–520 explicitly puts AC-016 inside the five semantic proof cells.
  This establishes five-consumer coverage within each existing cell, not 25
  additional sessions, 25 canaries, 25 signatures or five additional OS matrices.
- attempt-9/round-2/reviewer-b.json:73–76 requests inventory format, storage and
  missing/partial rejection. It does not request separate request/result files
  per consumer or prohibit a shared transcript. Those proposed constraints are
  withdrawn. Existing native evidence and human review remain authoritative for
  whether the listed consumers really ran; an inventory is not proof by itself.

## Short alternatives assessment

Unchanged v1 plus the existing allowlist proves the five source artifacts exist,
not that they were exercised. Existing raw captures must stay unedited; imposing
an inventory grammar on native host output is inappropriate. Encoding a second
machine-readable language inside free-text `check` or `notes` is less clear than
one typed field. Recommended delta: add only `consumer_inventory` to the existing
record and explicitly version that record as v2. Retain all existing proof files,
capture references, signer identities, signature count and session structure.
No new signing mechanism, ledger, report family or standalone gate.

## Proposed normative design text

For live-host-verification-record/v2, add one required field:

```json
"consumer_inventory": [
  {"entry_point": "sdd-ship", "source_commit": "<accepted A1 commit>", "source_path": "plugins/sdd-ship/skills/ship/SKILL.md"}
]
```

The illustration is one entry, not a valid complete inventory. A non-SKIP record
requires exactly five entries, each with exactly those three string fields.
`entry_point` has the exact unique set sdd-ship, sdd-bootstrap,
sdd-bootstrap-interviewer, lite-spec, lite-gate. The containing record supplies
runtime and matrix_cell, avoiding duplicated values which could disagree.
The consumer-to-path mapping and accepted source commit reuse AC-016's existing
allowlist inventory; resolve the cited Git objects and compare the corresponding
five blob IDs with that accepted map. Review/adoption must reverify those shared
objects. Do not silently track a changing main branch.

Reject missing/null/non-array inventory, missing/extra/duplicate/unknown consumer,
unexpected entry keys, wrong path, wrong commit or unresolved/mismatched source
object before a record can discharge the aggregate. Ordering carries no meaning.
SKIP requires null inventory and retains all existing SKIP rejection/activation
rules. FAIL never discharges the aggregate; incomplete evidence can remain a
diagnostic artifact but is not a schema-complete executed record.

The inventory attests which consumers were exercised within the containing
record's runtime/cell and genuine session. Operator and independent reviewer must
confirm all five against the already-required native evidence before signing.
Shared captures are permitted; merely listing source files is insufficient.
No additional per-consumer capture or signature is required. Unavailable cells
keep their existing expected-unavailability behavior; do not invent successful
guard activation in an unavailable cell.

Existing JCS signing excludes only operator_signature and reviewer_signature;
therefore it automatically covers this complete inventory. A changed inventory
must invalidate either existing signature. No cryptographic algorithm or key
registration change is required.

## Minimal propagation candidate

1. requirements.md AC-015/026/028: change prospective record identifier to v2 and
   reference the AC-016 inventory definition. AC-016 retains the three existing
   information requirements; runtime/cell is inherited from its containing record.
   Do not add separate-session/raw-file/signature requirements.
2. design.md: adopt the normative text above in Data/API Contract Plan; update
   the record example, exact-key schema and version references coherently.
3. ADR-0028 decision 4: extend the same narrowly scoped Ed25519 signing contract
   from the historical v1 to its v2 successor. Keep Proposed status, historical
   text, signing target and all authority boundaries unchanged.
4. tasks.md T-005 owns validator/schema and negative-test implementation; T-008
   owns inventory population, existing cell classification and human proof.
   Update prospective version references, not Approval/Status/Done checkboxes.
   T-008's prohibition on agent-created genuine signed records remains intact.
5. acceptance-tests.md: define TEST-016's five names for each of the existing five
   cell fixtures, completeness/source-mismatch negatives, unchanged signature
   verification, tamper rejection and existing SKIP behavior. This is parameterized
   coverage of existing requirements, not an extra native execution matrix.
6. All four layer specs and traceability: sweep v1 and AC-016 references and
   reconcile prospective references with the same transition. Preserve explicit
   historical evidence citations. Do not claim old v1 records satisfy the new
   completeness check or rewrite historical verdicts.

## Adoption and verification boundary

This is a non-frozen proposal under the existing bounded-repair authorization,
not permission to edit frozen inputs silently. docs/development-policy.md's
existing-task transition and AGENTS.md post-review freeze require a hash-pinned
superseding amendment, preserved historical snapshots, and independent review of
the changed admitted inputs. Only then may T-005 implement the v2 validator and
T-008 populate its records. Use the sanctioned protected-application path where
actual targets are protected. Exact candidate bytes and a pinned human-only batch
are now prepared in `a8-ac016-amendment-batch-20261006.py`; dry-run and candidate
contract experiments passed. See `a8-ac016-batch-results-20261006.md`. Independent
acceptance/adoption remains pending; preparation is not authorization to mutate
the originals or reserve a reviewer.

The earlier prototype demonstrated the current gap and generic signature binding
only. Its separate-file/duplicate-path tests are NOT requirements and must not be
promoted to acceptance tests. Production regressions, formal amendment review,
native proof, CI and merge remain unperformed for this candidate.
