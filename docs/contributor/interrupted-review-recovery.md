# Interrupted specification review recovery

The specification precheck supports a separate recovery transition when reviewer A
was blocked **before substantive reading**, reviewer B was not launched, and the
latest source round is round 2 or 3. It creates attempt N+1, round 1; it does not
turn the interrupted review into a passing review or issue task approval.

```sh
bash plugins/sdd-review-loop/scripts/spec-review-precheck.sh FEATURE NEXT_ATTEMPT 1 \
  --recover-interrupted=path/to/recovery-record.json
```

```powershell
./plugins/sdd-review-loop/scripts/spec-review-precheck.ps1 `
  -Feature FEATURE -Attempt NEXT_ATTEMPT -Round 1 `
  -RecoverInterrupted path/to/recovery-record.json
```

The closed record and its eight authorization bindings are defined in
[the existing data contract](../../contracts/spec-review-interrupted-recovery.v1.data-contract.md).
The orchestrator must first establish the genuine, bounded human authorization
and application required by AUTH-001 in
[the recovery requirements](../../specs/a9-interrupted-review-recovery/requirements.md).
The validator checks contents, hashes and bindings; it does **not** authenticate
human authorship. An agent-created file or summary is not sufficient authority.
Unknown or mismatched authorization provenance blocks actual recovery.

Validation binds the previous NEEDS_WORK contract, current input and calibration
hashes, the complete interrupted artifact inventory, persisted reviewer identity,
and absence of a competing source launch. It revalidates under the existing lock
before publishing a fresh Pending precheck and blank report. Evidence inputs must
be regular files; native PowerShell also rejects POSIX FIFOs before hashing or
reading them. Reviewer identities
are allocated later through the normal launch path. The ordinary reset route and
three-round limit are unchanged; recovery cannot be combined with reset, input
verification or fixed-input transition options.

A failed publication leaves a quarantined partial destination. Do not erase,
reuse or promote it automatically. Saved recovery references are checked for
contained paths and unchanged hashes when consumed; normal verdict and input
checks still apply. Research and ADR manifests in historical contracts retain
the current main validation rules.

## Adoption and verification

The implementation and synthetic recovery test pair were selectively recovered
from PR #640 at `55fb04ee2c1f6af182305eb85882b5719bc62cb6`. The older branch's
research/ADR manifest handling was excluded from the transplant. Its old task
approvals, criteria amendments and incomplete formal binding remain historical;
this integration does not rewrite them or claim that a historical recovery ran.

Run `tests/spec-review-interrupted-recovery.tests.sh` for Bash and
`tests/spec-review-interrupted-recovery.tests.ps1` for native PowerShell. The
shared suite uses disposable synthetic evidence, exercises admission, locked
publication, races, quarantined failure and downstream consumption, and does not
read the working repository's identity ledger. Both suites are in the verification
catalog. The dedicated `interrupted-recovery` CI matrix runs native PowerShell on
Linux, macOS and Windows, and Bash on Linux and macOS. Its result is mandatory in
`required-checks`; existing regression job budgets and checks are unchanged.
Actual CI results, not registration alone, establish execution.
