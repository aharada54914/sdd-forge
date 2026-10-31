# Maintenance unexecuted-list follow-up

Replayed the four actual HTTP/CLI scenarios using the current shared implementation and added a document-only procedure with three indexed features mapped to two checks. All assertions passed. The original `maintenance-behavior/` evidence remains byte-identical; `prior-evidence-sha256.json` records and the script checks those historical hashes.

- Missing declared CLI: blocked / environment-unavailable; `unexecuted_checks` is `["aggregate"]`, and `unexecuted` lists all three feature files. There are no feature execution logs.
- Document-only procedure: baseline and both maintenance checks are `not-run`; blocked / procedure-not-executable. The helper lists both checks (`read-pages`, `read-cli`) and all three feature files. The execution entrypoint was never called.
- Route/auth drift and actual product regression: all three features execute and their observed failures are retained, so both unexecuted lists correctly remain empty. The route/auth minimal helper repair plus explicit reseal still restores all three paths. Product regression still blocks without expectation relaxation.

`result.json` retains current source SHA and actual results; `evaluate.py` reproduces the five cases. This follow-up closes the earlier helper reporting gap. No repository code was edited, and no native Windows/macOS behavior is inferred.
