# T-002 — `contracts/capability-summary.schema.json` draft-07 metaschema conformance

Spec-Authoring-Time Manual Review Record (acceptance-tests.md), one-time,
not part of the regression suite — per design.md `validate-capability-
summary` contract (shared verbatim with `validate-facet-manifest`'s own
statement): "Each of the three committed schema documents ... is
additionally validated once, at spec-authoring/registration time, not by an
automated `tests/*.tests.sh` regression suite, against the official
draft-07 metaschema."

## Method

The hand-rolled validator this task ships (`validate-capability-summary.py`)
implements the same deliberately closed subset of draft-07 T-001's
`validate-facet-manifest.py` implements (INV-014: no third-party
`jsonschema` dependency in the shipped code). This one-time check therefore
uses **a tool outside that closed-subset engine**, as design.md requires:
the `jsonschema` PyPI package (v4.26.0), installed into a throwaway
virtualenv under the session scratchpad (never added to this repository,
never referenced by any shipped script, `requirements.txt`, or CI step) —
the identical method T-001's own `metaschema-conformance.md` used, reused
here rather than re-derived.

## Result

```
$ python -c "
import json
from jsonschema import Draft7Validator
schema = json.load(open('contracts/capability-summary.schema.json'))
Draft7Validator.check_schema(schema)
print('check_schema(): OK')
"
check_schema(): OK
```

`Draft7Validator.check_schema()` raises `jsonschema.exceptions.SchemaError`
on any metaschema non-conformance; it raised nothing. Every keyword used by
`contracts/capability-summary.schema.json` (`type`, `additionalProperties`,
`required`, `properties`, `const`, `pattern`, `items`, `uniqueItems`,
`minLength`) is confirmed a valid draft-07 metaschema keyword used in a
valid position.

**Note on `pattern`**: design.md's own keyword-audit paragraph ("API /
Contract Plan", "keywords each committed schema instance actually uses,
cross-checked against this list") states `capability-summary.schema.json`
uses `type, additionalProperties, required, properties, const, items,
uniqueItems` — omitting `pattern`. This is a design.md self-contradiction:
the very same document's own committed JSON block for this schema (the
paragraph immediately above the audit list) declares
`"feature": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" }`.
`contracts/capability-summary.schema.json` above is authored verbatim from
that committed JSON block (Goal), so it correctly includes `feature`'s
`pattern` constraint; `validate-capability-summary.py`'s engine correctly
implements `pattern` support (needed to enforce it) rather than following
the audit paragraph's incomplete list. Not corrected in design.md by this
task (design.md is not a Planned File of T-002); reported here for a future
design.md revision, matching this feature's own precedent of documenting a
design.md self-contradiction without patching it directly out-of-scope.

## Cross-validation against the reference implementation

As a second, independent confidence check (not required by design.md, but
directly relevant since this task's own validator is hand-rolled), every
fixture under `tests/fixtures/facet-manifest/capability-summary/` (12 JSON
fixtures; the one `.yaml` fixture is excluded from this JSON-only
comparison, since it exercises the YAML parse contract rather than the
schema engine directly) was evaluated with
`jsonschema.Draft7Validator(schema).iter_errors(doc)` and compared against
`validate-capability-summary.py`'s own schema-conformance exit code.

Full comparison transcript:
`specs/epic-192-a4-facet-manifest/verification/T-002/metaschema-cross-validation.log`.

11 of 12 fixtures agree exactly. The one disagreement is expected and
intentional, not a defect:

- `feature-trailing-newline.json` (`feature: "epic-192-a4-facet-manifest\n"`):
  the reference `jsonschema` library reports this fixture **valid**
  (Python's `re` module's bare `$` matches immediately before a trailing
  `"\n"`, which is more permissive than draft-07's own ECMA-262,
  non-multiline `$` semantics), while `validate-capability-summary.py`
  correctly reports it **invalid** — this validator's own
  `_ecma_anchor`/`_compile_pattern` pair (copied from T-001's
  `validate-facet-manifest.py`, itself a quality-gate cycle-2 fix for the
  identical bug class) rewrites unescaped, non-character-class `$` to `\Z`
  before compiling, so it enforces the schema's `pattern` constraint more
  strictly and more correctly than the reference implementation's default
  Python-`re` behavior for this one input shape. This is the intended
  behavior (design.md's "Include the ECMA-262 `$`->`\Z` pattern fix from
  the start" instruction for this task), not a validator bug; the `jsonschema`
  reference implementation itself would need `re.compile(pattern, re.X)`
  tuning it does not perform by default to match strict ECMA-262 `$`
  semantics here.

## Conclusion

`contracts/capability-summary.schema.json` is draft-07 metaschema-conformant.
The vendored copy
(`plugins/sdd-quality-loop/contracts/capability-summary.schema.json`) is
byte-identical (verified via `diff`/`shasum -a 256`).
