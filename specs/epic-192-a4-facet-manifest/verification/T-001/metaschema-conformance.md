# T-001 — `contracts/facet-manifest.schema.json` draft-07 metaschema conformance

Spec-Authoring-Time Manual Review Record (acceptance-tests.md), one-time,
not part of the regression suite — per design.md `validate-facet-manifest`
contract: "Each of the three committed schema documents ... is additionally
validated once, at spec-authoring/registration time, not by an automated
`tests/*.tests.sh` regression suite, against the official draft-07
metaschema."

## Method

The hand-rolled validator this feature ships (`validate-facet-manifest.py`)
implements a deliberately closed subset of draft-07 (INV-014: no
third-party `jsonschema` dependency in the shipped code). This one-time
check therefore uses **a tool outside that closed-subset engine**, as
design.md requires: the `jsonschema` PyPI package (v4.26.0), installed into
a throwaway virtualenv under the session scratchpad
(`/private/tmp/claude-501/.../scratchpad/metaschema-venv`) — never added to
this repository, never referenced by any shipped script, `requirements.txt`,
or CI step.

A direct network fetch of `http://json-schema.org/draft-07/schema#` from
this sandbox returned `HTTP 403 Forbidden` (outbound fetch to that specific
host is blocked here); `pip install` against the configured package index
was reachable, so the metaschema check below uses the `jsonschema` library's
own bundled copy of the official draft-07 metaschema
(`jsonschema.validators.Draft7Validator.check_schema`), not a locally
re-typed one.

## Result

```
$ python -c "
import json
from jsonschema import Draft7Validator
schema = json.load(open('contracts/facet-manifest.schema.json'))
Draft7Validator.check_schema(schema)
print('check_schema(): OK')
"
check_schema(): OK -- schema conforms to the official draft-07 metaschema
```

`Draft7Validator.check_schema()` raises `jsonschema.exceptions.SchemaError`
on any metaschema non-conformance; it raised nothing. Every keyword used by
`contracts/facet-manifest.schema.json` (`type` incl. array-form,
`additionalProperties`, `required`, `properties`, `const`, `pattern`,
`items`, `uniqueItems`, `if`/`then`/`else`, `not`, `enum`, `minItems`,
`minLength`, `$ref`/`definitions`) is confirmed a valid draft-07 metaschema
keyword used in a valid position.

## Cross-validation against the reference implementation

As a second, independent confidence check (not required by design.md, but
directly relevant since this feature's own validator is hand-rolled), every
fixture under `tests/fixtures/facet-manifest/{schema,semantics}/` (41 files)
was evaluated with `jsonschema.Draft7Validator(schema).iter_errors(doc)` and
compared against `validate-facet-manifest.py`'s own schema-conformance exit
code:

- All 31 `schema/` fixtures: the reference validator's pass/fail verdict
  matches this feature's hand-rolled engine's `schema-invalid`
  pass/fail verdict on every fixture, with no disagreement.
- All 10 `semantics/` fixtures: the reference validator reports all 10 as
  schema-valid (expected — these fixtures exercise the four REQ-006
  *semantic* checks, which are not draft-07 schema constructs at all), and
  this feature's hand-rolled engine's own schema-conformance layer agrees
  (reports no `schema-invalid` diagnostic for any of the 10); each is
  correctly flagged only by its intended semantic check
  (`resolved-gate-id-duplicate`, `facet-classification-conflict`,
  `conditional-facet-duplicate`, or `array-not-stable-sorted`).

Full comparison transcript: `specs/epic-192-a4-facet-manifest/verification/T-001/metaschema-cross-validation.log`.

## Conclusion

`contracts/facet-manifest.schema.json` is draft-07 metaschema-conformant.
The vendored copy (`plugins/sdd-quality-loop/contracts/facet-manifest.schema.json`)
is byte-identical (verified via `diff`/`shasum -a 256`, both
`81d4f1621923133e55875621ba81b30ad9d21688d9442c5a371fc1023b4a4c51`), so this
result applies to both copies.
