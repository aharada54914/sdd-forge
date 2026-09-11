# RT-20260908-004 — admission regression baseline

Date: 2026-09-08
State: expected TDD RED; ticket remains open, no product fix applied.
Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh`
Exit code: 1
Environment: macOS, Bash and local PowerShell. Not native Windows evidence.

The suite invokes both actual admission validators with `--reserve`/`-Reserve`
against disposable fixture repositories. The real repository ledger is not used.
Both implementation reviewer roles are exercised for each runtime.

| Case | Bash A/B | PowerShell A/B | Result |
| --- | --- | --- | --- |
| Legacy round without ADR extension | success/success | success/success | 4 passed |
| Referenced ADR pinned by design, precheck and invocation | rejected/rejected | rejected/rejected | 4 failed |
| Precheck declares ADR but invocation omits it | accepted/accepted | accepted/accepted | 4 failed |

Exact rejection for a valid ADR (role varies):

```text
REVIEW_CONTEXT_PATH: impl-reviewer-a contains a real but role-unlisted path: docs/adr/0001-fixture.md
```

For omitted ADRs the validators return `REVIEW_CONTEXT_OK` and reserve an identity;
the tests require rejection without ledger mutation, so these cases fail.

Final output:

```text
ADR admission: passed=4 failed=8
```

This establishes two intended failures, not implementation acceptance. The valid
legacy controls establish that the basic identity/fixture setup is admissible.
The fixture precheck currently contains only the fields used in this admission
slice; expand it to the full precheck producer contract when testing producer and
downstream consumers. No claim of complete precheck or persisted gate coverage.

Next: implement the approved complete-set admission and producer/consumer binding,
expand negative and lifecycle fixtures, rerun existing parity suites, and obtain
independent implementation review. Keep old review failures and reservations.
