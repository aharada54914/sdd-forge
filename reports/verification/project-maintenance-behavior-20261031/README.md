# Independent #597 maintenance behavior evaluation

The actual `project-skill.py` helper was exercised against temporary local HTTP/CLI product fixtures, with no repository implementation edits. One skill has three indexed feature documents, each mapped to the aggregate check: browsing items, viewing an account, and obtaining CLI status. Captured per-feature JSON records prove all three paths ran in every executable aggregate invocation; this is more than an aggregate exit-code assertion.

Four scenarios passed their expected behavior:

1. Route change: the old `/items` procedure actually received HTTP 404. Only the helper's route constant was changed to `/v2/items`; explicit removal of the old manifest and resealing was necessary. All three paths then passed; maintenance reported `changed` / `source-drift` relative to the original baseline.
2. Authentication prerequisite: `/account` actually received HTTP 401 after the fixture began requiring a synthetic bearer value. Only the helper's authentication-header constant changed. Explicit resealing and rerun restored all three paths.
3. CLI disappeared: the declared `fixture-cli` prerequisite was removed. Maintenance reported `blocked` / `environment-unavailable`. The aggregate never started, and **all three features were unexecuted**. The generic helper's own `unexecuted: []` does not establish feature execution; the independent `unexecuted_features` field explicitly records all three names from the absence of execution records.
4. Product regression: `/items` returned HTTP 200 with wrong body `BROKEN`. The expected value was not weakened, the helper was not edited, and a second maintenance attempt remained blocked.

The helper itself labels route, auth and product failures `product-regression-or-harness-gap`. The narrower explanations above come from actual HTTP status/body and CLI observations plus controlled fixture changes; they are not claimed as exact built-in diagnoses.

For every case, the synthetic handwritten extension remained byte-identical. After each intentional fixture product mutation, subsequent maintenance/helper repair did not change the product source. CLI loss was not repaired to fake a pass. The reproduction script, result receipts, source SHA and per-feature outputs are retained here; temporary projects were removed. Only Linux execution was evaluated, not native Windows/macOS or arbitrary applications.
