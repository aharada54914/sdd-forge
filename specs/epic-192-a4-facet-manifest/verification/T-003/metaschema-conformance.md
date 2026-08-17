# T-003 — `contracts/context-projection.schema.json` draft-07 metaschema conformance

Spec-Authoring-Time Manual Review Record (acceptance-tests.md), one-time,
not part of the regression suite — per design.md `validate-context-
projection` contract's shared statement (design.md, "Each of the three
committed schema documents ... is additionally validated once, at
spec-authoring/registration time, not by an automated `tests/*.tests.sh`
regression suite, against the official draft-07 metaschema").

## Method

The hand-rolled validator this task ships
(`validate-context-projection.py`) implements the same deliberately closed
subset of draft-07 T-001's `validate-facet-manifest.py`/T-002's
`validate-capability-summary.py` implement (INV-014: no third-party
`jsonschema` dependency in the shipped code). This one-time check therefore
uses **a tool outside that closed-subset engine**, as design.md requires:
the `jsonschema` PyPI package (v4.26.0), installed into a throwaway
virtualenv under the session scratchpad (never added to this repository,
never referenced by any shipped script, `requirements.txt`, or CI step) —
the identical method T-001's/T-002's own `metaschema-conformance.md` used,
reused here rather than re-derived.

## Result

```
$ python -c "
import json
from jsonschema import Draft7Validator
schema = json.load(open('contracts/context-projection.schema.json'))
Draft7Validator.check_schema(schema)
print('check_schema(): OK')
"
check_schema(): OK
```

`Draft7Validator.check_schema()` raises `jsonschema.exceptions.SchemaError`
on any metaschema non-conformance; it raised nothing. Every keyword actually
used by `contracts/context-projection.schema.json` — confirmed by a
recursive walk of the committed schema document, not by design.md's own
audit paragraph (see the note below) — is a valid draft-07 metaschema
keyword used in a valid position: `type`, `additionalProperties`,
`required`, `properties`, `const`, `pattern`, `items`, `minLength`,
`oneOf`, `enum`, `propertyNames`, `$ref`, `definitions`.

**Note on `pattern`/`minLength`**: design.md's own keyword-audit paragraph
("API / Contract Plan", "keywords each committed schema instance actually
uses, cross-checked against this list") states `context-projection.
schema.json` uses `type, additionalProperties, required, properties, enum,
propertyNames, items, oneOf, const, $ref/definitions` — omitting **both**
`pattern` (used by `source_sha256`'s and `provider_bindings_sha256`'s
`^sha256:[0-9a-f]{64}$` constraint) **and** `minLength` (used by
`components.propertyNames: {"minLength": 1}`, the very keyword B3's own fix
introduces for this schema). This is a design.md self-contradiction, of the
same class T-002's own `metaschema-conformance.md` already reported for
`capability-summary.schema.json`'s `pattern` omission (RT-20260817-003
expected_fix item 2 asked a future task to check the omission's full scope
rather than stop at the first keyword found — this note covers both
keywords the audit paragraph drops for this schema, not just `pattern`).
`contracts/context-projection.schema.json` above is authored verbatim from
design.md's own committed JSON block (Goal), so it correctly includes both
constraints; `validate-context-projection.py`'s engine correctly implements
`pattern` and `minLength` support (needed to enforce them) rather than
following the audit paragraph's incomplete list. Not corrected in design.md
by this task (design.md is not a Planned File of T-003); reported here for
a future design.md revision, matching this feature's own precedent
(T-002's own note) of documenting a design.md self-contradiction without
patching it directly out-of-scope.

## Cross-validation against the reference implementation

As a second, independent confidence check (not required by design.md, but
directly relevant since this task's own validator is hand-rolled), every
fixture under `tests/fixtures/facet-manifest/context-projection/` (24 JSON
fixtures — this suite has no YAML fixture at all, since
`validate-context-projection.py` never parses YAML, design.md's own
`validate-context-projection` contract) was evaluated with
`jsonschema.Draft7Validator(schema).iter_errors(doc)` and compared against
`validate-context-projection.py`'s own schema-conformance exit code.

Full comparison transcript:
`specs/epic-192-a4-facet-manifest/verification/T-003/metaschema-cross-validation.log`.

23 of 24 fixtures agree exactly. The one disagreement is expected and
intentional, not a defect:

- `source-sha256-trailing-newline.json` (`source_sha256:
  "sha256:1a2aa6f2...427\n"`): the reference `jsonschema` library reports
  this fixture **valid** (Python's `re` module's bare `$` matches
  immediately before a trailing `"\n"`, which is more permissive than
  draft-07's own ECMA-262, non-multiline `$` semantics), while
  `validate-context-projection.py` correctly reports it **invalid** — this
  validator's own `_ecma_anchor`/`_compile_pattern` pair (copied into this
  task's independent copy of the engine; a T-001 quality-gate lesson,
  RT-20260817-003, not a design.md/tasks.md instruction) rewrites
  unescaped, non-character-class `$` to `\Z` before compiling, so it
  enforces the schema's `pattern` constraint more strictly and more
  correctly than the reference implementation's default Python-`re`
  behavior for this one input shape. This is the intended behavior, not a
  validator bug; the `jsonschema` reference implementation itself would
  need `re.compile(pattern, re.X)` tuning it does not perform by default to
  match strict ECMA-262 `$` semantics here.

## Conclusion

`contracts/context-projection.schema.json` is draft-07 metaschema-conformant.
The vendored copy
(`plugins/sdd-quality-loop/contracts/context-projection.schema.json`) is
byte-identical (verified via `diff`/`shasum -a 256`).
