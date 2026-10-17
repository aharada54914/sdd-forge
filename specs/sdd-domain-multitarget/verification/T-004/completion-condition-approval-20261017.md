# T-004 limited completion-condition approval

## Authority and exact scope

On 2026-10-17 the user explicitly authorized replacing only T-004's
"failure before the fix, success after the fix" completion condition with:
comparison against the existing verified version, compatibility regression
through actual usage paths, independent evaluation, and successful required
CI for the latest head. Discovered defects must still be fixed and covered by
regression tests. This decision is recorded from the current user instruction;
it is not a recovered historical approval or review verdict.

The verified comparison baseline is
`7848ad97cfbead8e67245d94cc03c2adf33ad209`. The user reports CI run
[38992708299](https://github.com/aharada54914/sdd-forge/actions/runs/38992708299)
completed all 37 jobs, including required-checks, and reports four PowerShell
runner cases and five T-004 Python tests passing on that version. These are
attributed user observations, not newly executed cloud checks or CI proof for
a subsequent commit.

## Preserved boundaries

- Keep T-004 high risk and its other compatibility obligations unchanged.
- Preserve old implementation reports, evidence, approvals and review verdicts.
- Do not manufacture production RED or classify fixture/mutation failures as it.
- Do not amend the global TDD/check-contract schema or another task's conditions.
- Task-stage provenance re-review and the ordinary quality gate remain required.
- This approval alone does not mark Implementation Complete, PASS or Done.
- Do not begin T-005 implementation until T-004 is Done; do not merge PR #535.

## Evidence-field integration

The global contract still requires nonempty `red_evidence` and `green_evidence`
for required TDD test checks. Any proposed mapping of baseline comparison to
those fields must explicitly cite this scoped decision and distinguish the
baseline from a failing production run. The independent gate must validate
the mapping and underlying captures; this note is neither a test capture nor
a substitute for either evidence file. No existing contract has been marked
passing by this amendment.
