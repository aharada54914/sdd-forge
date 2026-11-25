# Addendum: full schema conformance of validate-domain-contract (#804)

Date: 2026-11-25
Issue: https://github.com/aharada54914/sdd-forge/issues/804 (audit D2)
Decision: owner decision of 2026-11-25, approved on the issue

This addendum widens the scope of `plugins/sdd-domain/scripts/validate-domain-contract.sh`
and `.ps1`. This feature's review gates have passed, so `requirements.md`,
`design.md`, `acceptance-tests.md`, `tasks.md` and `traceability.md` are
content-frozen (AGENTS.md "Post-review artifact freeze"). They are not edited.
Where those artifacts and this addendum disagree about what the validator
checks, this addendum governs.

## Problem

The validator is the pre-publish check for `domain/domain-contract.json`
(`plugins/sdd-domain/skills/domain-review-loop/SKILL.md`, publish step 3).
The downstream Concept Test runs a full JSON-Schema check of the same file
against `contracts/domain-contract.v2.schema.json`
(`plugins/sdd-domain/scripts/validate-concept-test.py:88-90`, through
`_schema_validate` in `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py`).
Before this change the validator exited 0 on contracts that check rejects.
The issue records three reproductions:

| Contract defect | Validator before | Concept Test |
|---|---|---|
| `contexts[0].aggregates` absent | exit 0 | `invalid v2 domain contract` |
| `meta.status: "Bogus"` | exit 0 | `invalid v2 domain contract` |
| `meta.version: "1.0"` | exit 0 | `invalid v2 domain contract` |

A contract could therefore pass the documented publish procedure and then
block every Concept Test.

## Decision

The validator rejects every contract that the Concept Test's schema check
rejects, in both twins, with identical verdicts. The expected-version check
(old patch + 1) and the check that `meta.status` equals the canonical
`Approved` stay with the human publish procedure. The validator has no old
version to compare against.

## Superseded statements

Each statement below remains true for the fields it names. It no longer
limits the validator's scope.

1. `requirements.md` REQ-004(c) defines type conformance as conformance to
   the types that `## Field Definitions` declares. `tasks.md` T-003
   "Must Read" calls that table "the authority for every type, pattern,
   required flag, minItems, and minLength". After this addendum the
   structural pass enforces every rule of `contracts/domain-contract.v2.schema.json`.
   The Field Definitions rows still hold, and the schema agrees with them.
2. `acceptance-tests.md` `## Negative-path coverage matrix` calls itself the
   product of "every constraint requirements.md declares". It covers only
   the Field Definitions rows. The constraints this addendum adds are not
   matrix rows. Their negative coverage is the test set under
   [Verification](#verification). The matrix is frozen and is not extended.
3. `design.md` `## Error Handling` lists the structural rule ids
   `V2-TYPE-MISMATCH`, `V2-MISSING-KEY`, `V2-PATTERN`, `V2-EMPTY-ARRAY` and
   `V2-EMPTY-STRING`. This addendum adds `V2-ENUM` and `V2-UNKNOWN-KEY`
   (see [Rule ids](#rule-ids)).
4. `design.md` `## Test Strategy` counts 73 negative fixtures. That count
   is still the T-002..T-004 allocation, which the T-005 tally tests
   assert. The #804 fixtures are a separate set and are not added to it.
5. The `check_contexts` docstring (`.sh`) and the `Test-ContextsStructure`
   comment (`.ps1`) said the v1-inherited boundedContext / term shape was
   "outside this pass's authority table and outside the Negative-path
   coverage matrix", so a non-conforming element was skipped. Both
   functions are replaced by per-definition checks (`check_context`,
   `check_term`, `check_aggregate`, `check_relation` and their `.ps1`
   counterparts). The header comments and the `check_structure` /
   `Invoke-StructureCheck` docstrings now state the full-schema scope.
6. `design.md` `## Architecture` step 3 lists "型適合 → required / pattern /
   minLength / minItems". The pass now also checks `enum` and
   `additionalProperties: false`, in this order for each object: its
   declared members (presence and type, then pattern, enum, minLength or
   minItems), then its undeclared keys in document order. A value whose type
   does not conform is still excluded from the later checks.

7. The RT-20260819-002 regression block in
   `tests/sdd-domain/contract-v2-schema.Tests.ps1` pinned exit 0 for two
   "inverted" contracts whose only change was a case-variant optional key
   (`Must_Not_Own`, `Concept_Id`). The schema rejects both as undeclared
   keys, so they were instances of this defect. The block now pins exit 1
   with a single `V2-UNKNOWN-KEY` line for each. The ordinal-lookup property
   it guards is unchanged: a case-folding lookup would add a
   `V2-SELF-CONTRADICTION` or `V2-DANGLING-TERM` line. The other pinned
   outputs gain the `V2-UNKNOWN-KEY` or boundedContext `V2-PATTERN` line the
   schema rules now produce.

REQ-007 is not affected. The eleven pre-existing `tests/sdd-domain/*.Tests.ps1`
suites are unchanged. The new tests live in this feature's own suite and in
`tests/concept-test.tests.py`.

## New guarantee

For any input that the dispatch admits as `domain-contract/v2`:

- If `_schema_validate` with `contracts/domain-contract.v2.schema.json`
  reports an error, both twins exit 1.
- If it reports no error, the only rule ids either twin can report are the
  cross-reference rules `V2-DUP-CONCEPT-ID`, `V2-DANGLING-CONTEXT`,
  `V2-DANGLING-DISTINCTION`, `V2-DANGLING-TERM`, `V2-SELF-CONTRADICTION` and
  `V2-DUP-NAME-IN-CONTEXT`, which draft-07 cannot express (DD-1, INV-003).

The twins encode the schema's rules. They do not read `contracts/` at run
time, because an installed plugin cache has no `contracts/` directory
(#812). The agreement test below keeps the encoding and the schema from
drifting. It fails when the schema gains a keyword the twins do not encode.

Not covered: the Concept Test also parses with a duplicate-key check
(`validate-concept-test.py` `parse`). That check is part of its JSON parse,
not its schema check. The validator keeps `json.loads` semantics (the last
duplicate wins), as the `.ps1` scanner documents.

## Rules added

| Schema location | Rule |
|---|---|
| root | `relations` optional array of `contextRelation`; `contexts` minItems 1; no undeclared key |
| `meta` | `version` pattern `^[0-9]+\.[0-9]+\.[0-9]+$`; `status` enum `Pending` / `Reviewed` / `Approved`; `generated_from` items are strings, minItems 1; no undeclared key |
| `boundedContext` | required `name` (pattern `^[a-z][a-z0-9-]*$`), `description`, `terms`, `aggregates`; string and array types; no undeclared key |
| `term` | required `canonical`, `definition`; optional `ja`, `forbidden_synonyms` (string items), `concept_id` (type here, pattern and resolution unchanged in the cross-reference pass); no undeclared key |
| `aggregate` | required `name` (pattern `^[A-Z][A-Za-z0-9]*$`), `root_entity`, `invariants` (string items, minItems 1), `transaction_boundary`, `card`; no undeclared key |
| `contextRelation` | required `from`, `to`, `pattern` (enum of the eight relation patterns); optional `note`; no undeclared key |
| `concept`, `stakeholderPerspective`, `distinguishedFrom` | no undeclared key (their other rules were already enforced) |

Pattern and enum checks are case-sensitive in both twins: `approved`,
`Order-Taking` and `Partnership` are rejected.

## Rule ids

Existing rule ids and messages are unchanged. Two rule ids are new:

| Rule id | Message shape |
|---|---|
| `V2-ENUM` | `<path>: value <value> is not one of <allowed values>` |
| `V2-UNKNOWN-KEY` | `<path>.<key>: key is not declared by the domain-contract/v2 schema` (`<key>` alone at the root) |

The new checks reuse `V2-MISSING-KEY`, `V2-TYPE-MISMATCH`, `V2-PATTERN` and
`V2-EMPTY-ARRAY` with their existing message shapes. An empty `contexts`
array reports `V2-EMPTY-ARRAY: contexts: array is empty; at least one entry
is required`.

## Verification

- `tests/sdd-domain/contract-v2-schema.Tests.ps1`, the two Describe blocks
  named "validate-domain-contract full schema conformance (#804)": 50
  single-point negatives, each run on both twins with its expected rule id
  and field path, including the three reproductions and mis-cased values;
  acceptance cases for every `meta.status` and relation-pattern value and
  the loose boundedContext / aggregate name boundaries; and a check that
  both twins print byte-identical stderr for every negative.
- `tests/concept-test.tests.py` `DomainContractSchemaAgreementTests`: about
  360 generated mutations of a contract that populates every property the
  schema declares. The test checks the guarantee above for each twin with
  the Concept Test's own `_schema_validate`, checks that the twins print
  identical stderr, and checks that the schema uses only keywords the twins
  encode.
