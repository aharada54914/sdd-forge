# Commands, evidence and limits

All commands run locally on Linux. PATH prepends
`/workspace/.tools/sdd-forge-dev/bin` for actual PowerShell 7.6.7. The selected
model/effort are caller-native gpt-6-astra/high; test identities such as
synthetic-run are fixtures, not implementation or reviewer identities.

- `PATH=/workspace/.tools/sdd-forge-dev/bin:$PATH bash tests/guard-parity.tests.sh`:
  original new-test Red 327/55 (exit 1); 15 Set-Content failures there used an
  unsupported tool alias and are not enforcement proof. Corrected shell-tool
  registration-only result 373/9 (exit 1) isolates resolved invocation refusal.
  Final with all controls: 403/0 (exit 0), plus 7 reader tests. No test relaxation.
- Canonical JSON-only generation failed the existing exact ordered union check;
  the corresponding five generator baseline entries were added. All four
  generated modules now agree exactly; prior inventory members/order preserved.
- `final-results.json` records static and focused guard commands/exits. Its first
  mirror and invariant failures were before refreshing genuinely stale applied
  mirrors; `post-mirror-results.json` and logs supersede exactly those checks.
  Original intermediate failures/partial interrupted run remain preserved.
- `scoped-results.json` records existing bootstrap/CI/cloud routing checks.
  Those cloud/provider/bootstrap sources were unchanged throughout this repair.
  The existing routing suite passed all 93 tests without skips, including local
  pinned Bicep compile/CDK synthesis; no cloud writes. Root retains original
  exact-source six-suite evidence; this was not a whole-repository run.
- `python3 -B .../guarded-local-invocation.py`: 12 actual installed fixture CLI
  subprocesses, each first admitted by actual Python/Node/Bash/PowerShell guards.
  Both provider routes pass and prepare/apply remain BLOCKED. Initial Node path
  lookup failure is retained; final harness resolves the existing Node binary.
- Strict Ruff and mypy use `tests/shared-launch-python/pyproject.toml` and
  `MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts`.
  Changed Python generator, generated module, guard and evidence scripts are
  checked without suppressions. Existing guard typing errors were fixed using
  exact shape annotations/local optional-value narrowing, not skipped.
- PowerShell operator sweep: new metadata match is `-cmatch`, flag equality
  `-ceq`, interpreter membership `-ccontains`. New logic has no Select-String,
  filter, split, sort or regex-default cmdlet; existing string EndsWith operands
  remain unchanged. Mis-cased metadata and `-b` controls deny in every runtime.
- No newly enabled platform-SKIP branch. PowerShell ran for real on Linux;
  Windows NTFS/junction tests and macOS are not claimed. The existing staged
  runner install-path branch remains skipped pending its separate refresh
  candidate; no pending bundle was applied to remove that skip. No live cloud, full
  repository suite, independent review, quality verdict, push, tag or merge.

Rollback operates only in the named scratch checkout, restoring the nine
current code/config files from captured entry bytes while retaining corrected
regression tests. Baseline bootstrap and generator checks run; write-denial Red
returns. Exact reapply restores the final guard result. The first archive CI
wiring baseline attempt lacked the pinned workflow YAML parser; it is retained,
not counted as a product failure. The later rollback baseline exercises actual
installed bootstrap without that unavailable archive-only dependency.

All runtime/guard source bytes were declared stable before root's trial2 pin.
Root owns ALL8 cache refresh, actual native delivery, source recheck, first
independent cycle and full suite in a committed isolated checkout. Original
trial1 is historical provider/helper proof, not proof of new guard registration.

## Root-delivered native follow-up

Root subsequently delivered trial2 PASS (verified_at 2026-10-18T17:33:26.949105+00:00).
The public acceptance.json and follow-up-scope.md supersede the earlier pending
native-follow-up note only. Root refreshed ALL8 packages, validated 455 cache
files / 426 source bindings and two trusted actual hooks, then restored the
original profile/cache. Azure had five individual host calls; AWS five grouped
CLI subprocesses. Capture provenance is explicit. No live cloud or independent
review verdict. These native deliveries have their own root-supplied identities;
this implementer neither launched nor impersonates them.
