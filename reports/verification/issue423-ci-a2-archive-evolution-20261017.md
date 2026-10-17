# Issue 423: A2 applied archive versus additive live evolution

## Contract decision and scope

Baseline: `3ab6fa0eda130cc96c30e918f6ec0fa861c98cbe`.
The existing A2 contract requires actual human application, not a fresh candidate:
`specs/epic-190-a2-capability-registry/acceptance-tests.md` AC-029(a-c),
AC-030, and `tasks.md` T-006 Done When (human apply and GREEN proof).
Commit `86b9aa7b` records the regenerated bundle application; the candidate
README's T-007 append records T-006 becoming 21/0/0 after that application.
Those historical facts and bytes remain unchanged. This repair neither certifies
a new apply nor changes the historical Done conditions.

The two current assertions compare the *already applied archive* against all
later live additions in the wrong direction: replaying an archive would drop the
T-005 protection, but replay is not the current operation. The current candidate
is separately checked against live JSON and generator, including independent
removal controls for `plugins/sdd-bootstrap/scripts/resolve-design-sync.py`.
Keeping the archive immutable and verifying archive-to-live monotonic evolution
preserves the original protected-file contract. No contract amendment is needed
for this bounded CI check; any future policy/code change outside additive
baseline protection still fails and requires its own authorization.

## Repair

Both Bash and PowerShell suites require the existing
`tests/lib/guard-invariants-evolution.py --self-test` to succeed against the A2
archive and live tree. This authenticates archive source hashes, preserves every
ordered historical protection and all other policy, compares generator ASTs
except literal baseline inventory, and renders all four current projections with
the archived renderer. Coherent negative controls reject protection removal,
reorder/duplicates, policy weakening, generator bypass, archive tampering and
stale projections. The original candidate checks and mutation controls remain.

Only after that mandatory strict check succeeds may the two archive comparisons
accept additive live evolution. A missing runtime/helper, tampering or semantic
change remains a genuine failure, regardless of the old superset checks. The
suite's failure counters, designed-red counters and exit rules are unchanged.
Frozen human-copy/manifests, live production bytes, candidates, T-004 records,
task states, approvals and identity ledgers are untouched.

## Actual cloud validation

- `bash tests/generate-gate-capabilities.tests.sh`: exit 0, 33 passed,
  0 failed, 0 designed-red.
- `python3 -B tests/lib/guard-invariants-evolution.py specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop plugins/sdd-quality-loop --self-test`:
  exit 0, including coherent positive and negative controls.
- `bash -n tests/generate-gate-capabilities.tests.sh` and `git diff --check`:
  exit 0.
- Native PowerShell is unavailable (`pwsh` and `powershell` absent); local
  native parity is BLOCKED/unverified, not a success. Exact-head CI must supply
  the separate runtime observation.

A fresh conversation-isolated independent Codex diff review is recorded below
before publication. Any findings from that review remain part of development
history and are not formal task-quality verdicts.

## Independent development diff review

Conversation-isolated Codex reviewer `a2_archive_review`: final Critical 0,
Major 0, Minor 0; contract judgment acceptable. It independently reran Bash
(33/0/0, exit 0), helper self-test (0), missing-helper integration (1; one
failure and two designed-red), archive-JSON tamper (1; frozen-manifest
rejection), duplicate generator assignment (1), syntax/diff checks and unchanged
archive comparisons (0). PowerShell was reviewed statically, not executed.

An intermediate editing mistake removed comparator definitions; the reviewer
identified it. Those definitions and all candidate regression controls were
restored from the baseline before the final 33-check run and review. The earlier
28-check output is not accepted as validation of the final repair.

## Publication CI

Baseline run 39004837030 was observed failing the A2 Bash step in Ubuntu
version-gates; the Windows ownership lane's test step succeeded. Publication-head
CI is reported separately by exact SHA and run URL; baseline results are not
attributed to the new commit. No task Done or merge decision is made here.
