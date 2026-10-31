# RT-20260930-001 candidate resolver correction (2026-10-01)

Run ID: issue423-registry-migration-candidate-20261001
Task Attempt Count: 1
Scope: candidate and isolated temporary CLI repositories only. Production,
installed plugin, task approval/status, frozen specification, and quality
verdict were not changed. Historical T-002 Implementation Complete and the
earlier migration-not-complete judgment remain in force.

## Evidence-field preflight and RED

The real-CLI test was written and run against the unmodified production
resolver before candidate implementation. `registry-migration-cli.tests.py
-v` exited 1: all four `full|lite × pii true|false` legacy subcases exited 0,
published success artifacts, and failed the required Block assertion. The
unaffected and invalid-input controls passed. This is the observed silent
loss of the legacy obligation. This preflight inventory was documented after
the initial candidate insertion; the RED itself preceded that insertion.

| Persisted field | Contract/traceability counterpart | Failing mismatch test |
|---|---|---|
| `resolver-evidence.yaml` `diagnostics[].id` | `contracts/resolver-evidence.schema.json` diagnostic id and resolver's existing `registry-validation-failed` category | `test_legacy_affected_full_and_lite_pii_both_values_block_before_publication` RED: exit 0/no Block |
| `diagnostics[].detail` migration id + selected component | Resolver Evidence diagnostic detail string; RT-20260930-001 content migration identity | Same RED: no migration id or detail |
| `diagnostics[].severity` `block` and exit 1 | Resolver Evidence schema severity enum and `_block` exit contract | Same RED: exit 0 |
| evidence write, no facet/summary/projection publication | Resolver's Block-only `_write_evidence`; full/lite step-10/14 publication contract | Same RED: successful publication instead of Block-only write |

The original trigger is the fixed predicate from the canonical
`contracts/capability-registry.json` v1 durable-workflow entry. The candidate
checks it only after normal Steps 7-8 and only for affected components when
that capability is absent from the validated Registry. It reuses
`_evaluate_predicate`, the current Step-7/8 exception mapping, and `_block`.
An unavailable mandatory facet/review/gate/Lite rule is never reported as
satisfied. No config, diagnostic enum, or generic migration framework is added.

## Candidate-only checks performed

- `registry-migration-cli.tests.py -v`: initially 4 methods/8 exercised
  subcases, then 5 methods/9 subcases after one unaffected-Lite control,
  GREEN on candidate. Persisted Block evidence has the existing diagnostic
  id and versioned detail; full/lite × both PII values publish no success
  artifact. Unrelated `cli_tool` and nonlegacy `other` contexts resolve
  normally, including a legacy declaration on an **unaffected** component.
  The added Lite control exits 0 with empty diagnostics/evaluations, an empty
  required-check set, and only Capability Summary publication; it does not
  borrow Full facet/projection expectations. Invalid context retains its
  pre-existing canonicalizer Block. This was a candidate test-coverage
  supplement, not a production-code repair iteration.
- `registry-migration.tests.py -v`: 10/10 GREEN; four recovered gate masters
  remain blocking, Registry 9-check validator is clean, the illustrative
  capability/gate validates in isolated fixture only, and the baseline
  registry-data-only silent-loss gap is still demonstrated.
- Source comparison: exactly one 22-line insertion after Step 8; no
  production source change. Test CLIs use temporary git repositories and
  real resolver/dependency subprocesses. This is not current-head CI or a
  quality-gate verdict.

## Protected-batch handoff (not executed)

The candidate resolver is SHA-256
`ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511`;
the candidate Registry is
`42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1`.
The live Python resolver and its human copy both currently hash
`26a1f3e547ee3bdcaf2bd330f5c06922603facb3f2164c45095c4327929035c7`.
The live root and vendored Registry both hash
`737af6db85d6ec9e31ad087acb358ea34de1e1d57f4ad4f2ffe2017c64d91278`.
The prior four-registration human copies both hash
`b09dc7759542e9cbfe8cc81c38e4f7a1d7630d0c1be77ec13d6d981785c00d67`.

One later approved protected batch must synchronize these exact targets:

1. `contracts/capability-registry.json` and
   `plugins/sdd-quality-loop/contracts/capability-registry.json` to candidate
   Registry hash `42b884…564c1`;
2. `plugins/sdd-quality-loop/scripts/resolve-project-context.py` and
   `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py`
   to candidate resolver hash `ae27de…ed511`;
3. any required installed/plugin human-copy destinations only after current
   target inventory and protected-hook policy are independently rechecked.

The `.sh`/`.ps1` wrappers delegate to the Python master and were not edited.
The protected batch, native full-suite/PowerShell parity, installed-host run,
CI, independent quality gate, and ticket closure remain **unexecuted**.

## Existing-driver isolation attempt (2026-10-01)

The existing block/match/CLI/parity drivers hard-code the A5 human-copy
`resolve-project-context.py` as their staged implementation
(`tests/resolve-project-context-block-check.py:149-153`; parity also reads
that stage). Their test fixture repositories are created separately at run
time. A fresh isolated checkout was created with
`rtk proxy git clone --local --no-hardlinks
/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
/private/tmp/issue423-resolver-regression.CfwaIT/checkout` (exit 0, HEAD
`06bc32cc26f2d67adb02e827610b5230e1658f72`). Before any driver ran,
the first mechanical stage command,
`rtk proxy cp /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge/specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/candidate/capability-registry.candidate.json
/private/tmp/issue423-resolver-regression.CfwaIT/checkout/contracts/capability-registry.json`, was rejected by
the PreToolUse hook. The hook stated that agents cannot rewrite gate scripts,
hook configuration, or critical test files, even with sudo. The command did
not execute and has no process exit code. No alternate write path was tried.

Consequently the candidate Registry and resolver were **not** staged into
that checkout, and the existing block/match/CLI/parity drivers were **not
run against the paired candidate**. This is not a regression PASS. The
earlier candidate-specific real-CLI RED/GREEN (4 methods, 8 subcases), the
later Lite-control GREEN (5 methods, 9 subcases), and the
data-only baseline suite (10/10) are distinct, executed evidence above.
Candidate hashes remain Registry
`42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1`
and Python
`ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511`.

## Human-only isolated-clone stage handoff (prepared, not executed)

No existing helper stages this paired candidate into the isolated clone in
one bounded operation: `apply-human-copy.sh` handles same-basename Registry
destinations separately, while `sync-human-copy-mirrors.py` operates after
live publication. `human-stage-isolated-clone.py` is a stdlib-only,
hash-fixed helper for the above clone and HEAD, requiring interactive human
confirmation. It checks the two candidate hashes above, six target baseline
hashes and target cleanliness, backs up all six targets with `mkdtemp`, then
stages canonical/vendored Registry and live/A5 resolver copies, updates the
A5 manifest entry, and runs the existing gate-capability generator plus
`--check`. It verifies byte-for-byte readback. Unknown/mixed hashes or dirty
targets are refused; identical reapplication reports `ALREADY_APPLIED`.
Failure after staging begins reports `INCOMPLETE` and backup location, with
no automatic rollback. It does not run regressions, Git, CI, or production
application.

Clone baseline SHA-256: root/vendor Registry each `737af6db85d6ec9e31ad087acb358ea34de1e1d57f4ad4f2ffe2017c64d91278`;
live/A5 Python each `26a1f3e547ee3bdcaf2bd330f5c06922603facb3f2164c45095c4327929035c7`;
generated projection `aa0a6b18cdd561b08ad95c89db8fd08138d2eef0e36aac3d4f7fa15af152e575`;
A5 manifest `33c78b3c18fe27dafeba9b542a307b7b3b41a26823b100f98707c9e2bdabdd04`.
All six target paths had clean `git status --porcelain` at this check.
Helper SHA-256: `a785543de96ea7b35e1d69b31a1c8e05bc7a6138b0b3585f2a641f0ae10e5b93`.
`ast.parse` syntax check exited 0; the helper itself was **not executed**.
Human command, only if choosing to stage the isolated clone:

```sh
rtk proxy python3 /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge/specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/human-stage-isolated-clone.py
```

Type `APPLY-ISSUE423-ISOLATED-CLONE` at its prompt. Existing block/match/CLI/
parity drivers against the paired candidate remain **not run** until that
human step succeeds; no formal review or publication result is claimed.

The candidate-only CLI command
`rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration-cli.tests.py -v`
was rerun after adding unaffected Lite: exit 0, `Ran 5 tests ... OK`.

## Custom Registry compatibility supplement (2026-10-01)

The real-CLI suite now has six methods and ten exercised subcases. The new
custom-Registry control retains the published durable-workflow facet definition
but selects the candidate Registry's existing `check-contract` gate. The issued
Facet Manifest must retain `data-spec`, the applied PII conditional facet and its
predicate evidence, the capability id, and the blocking implementation gate.
This proves obligation resolution/publication, not execution of that gate or
execution of the retired illustrative migration check.

The first run exited 1 because the new assertion expected conditional facets as
strings rather than the schema's objects; no production defect was inferred.
After correcting that assertion to the existing contract shape, the complete
suite exited 0: `Ran 6 tests in 8.519s`, `OK`. An independent ordinary read-only
code review found no concrete defect and ran the new method alone successfully
(`Ran 1 test in 1.194s`, `OK`). Neither result is a formal quality-gate verdict.
Candidate production bytes, task/review state and CI were not changed.
