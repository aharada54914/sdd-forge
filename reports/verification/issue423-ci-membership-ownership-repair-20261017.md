# Issue 423: protected membership and ownership CI repair

## Scope and proven cause

Repair baseline: `e0669f061f90ce7098a1ec66fe520d6f994e5b59`, following the
candidate-only A2 repair. The additional failures were observed on
`10072e8a952e26c6678c6a975d73013fffecad41`, run
[39001712985](https://github.com/aharada54914/sdd-forge/actions/runs/39001712985):

- POSIX job 117306945866: host-review `test_012d` measured
  `60f8e636fb3853737e82392e2e6c06cfb18efc6da71e63faa57f17ed742c5c14`
  instead of the pinned
  `ea6c2029371e9dada288c6d1b877ddb789ab2b6089e3d7783a6b3d29772290e9`.
- Windows job 117306945884: ownership TEST-036.4 reported
  addOk=True, manifestOk=False, candidates=12, live=12; 46 pass / 1 fail.

Comparing canonical JSON at `7848ad97` and T-005 commit `7e110ebb` proves exactly
one added protected member:
`plugins/sdd-bootstrap/scripts/resolve-design-sync.py`. The file exists and is
referenced by both the full design-sync and lite skill consumers. No other
canonical key or ordered historical membership changed. Removing only that new
member from the unrelated projection restores the original pinned digest.
The old `10072e8a` test was executed unchanged and reproduced the exact CI digest
assertion, rather than a fixture/runtime error.

All twelve A3 staged rows match their frozen manifest. The only six live-byte
mismatches are the invariant JSON, generator and four native projections changed
by that same addition. The other six live rows remain byte-identical. Thus the
Windows symptom is an archive-versus-authorized-addition assumption, not a
Windows hash algorithm defect.

## Minimal repair and retained checks

`tests/host-review-preflight.tests.py` keeps the original UNRELATED_SHA256
unchanged. One exact acknowledged member must exist and occur once; only it is
removed when comparing the original unrelated baseline. New negative assertions
reject its removal/duplication, arbitrary additions and reordered historical
members. Existing removal and policy-key mutation tests remain intact.

The two ownership suites preserve all twelve archive digest checks and all
non-invariant live equality checks. Only the six exact invariant paths can use
the existing `tests/lib/guard-invariants-evolution.py --self-test` contract when
their live digest differs. That shared helper authenticates archived source,
retains ordered unique historical protections and identical policy, allows only
literal baseline additions in generator source, and compares every live
projection against the archived renderer. Its coherent mutation controls must
also pass; missing helpers, runtimes or nonzero results cannot satisfy the check.
The existing separately declared pending-argument-guard conditions are unchanged.

No frozen human-copy bytes or manifests, live protection inventories/generators,
T-004 task plans/reports, identity ledger, approvals, or historical verdicts were
edited. This delivery changes three test files and this independent CI report.
No installation, trust/permission change, PR merge or task completion occurred.

## Actual cloud verification

| Command / reproduction | Exit and result |
|---|---|
| Original `10072e8a` host test_012d, unchanged source loaded with its original repository-relative fixture root | Exactly one assertion failure; actual/expected digests match the CI failure |
| `python3 -B tests/host-review-preflight.tests.py` | 0; 22 tests, 6 PowerShell subcase skips; skips are not successful runtime observations |
| Focused current test_012d and new test_012e | 0; 2 tests OK, including mandatory/unique/new-member and unrelated mutations |
| `bash tests/check-component-coverage.tests.sh` | 0; 46 passed / 0 failed |
| `python3 -B tests/lib/guard-invariants-evolution.py specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop plugins/sdd-quality-loop --self-test` | 0; positive addition and all embedded coherent negative controls completed |
| Actual ownership checker extracted unchanged into a disposable fixture | Control 0; non-invariant live drift 1; archived candidate tamper 1; live policy mutation 1; restored control 0 |
| `bash -n tests/check-component-coverage.tests.sh` | 0 |
| `git diff --check` | 0 |

The disposable ownership fixture copies repository-relative inputs and executes
the actual suite's Python check, not a substitute model of its logic. It never
changes repository evidence. Neither `pwsh` nor `powershell` is installed here;
native Windows/PowerShell execution is **BLOCKED / unverified**, not PASS.

## Independent development diff review

Fresh conversation-isolated Codex reviewer `ci_membership_ownership_review`:
PASS, zero Critical/Major/Minor findings. It independently reran the host suite
(22 tests, 6 PowerShell skips), Bash ownership (46/0), the shared self-test, and
disposable outsider-live/archive-tamper rejection controls. It confirmed the
exact historical JSON delta, retained original digest, six-path case-sensitive
restriction and fail-closed PowerShell handling. No review identity was reserved
and this is not a formal T-004 quality verdict.

## Remaining CI status

The A2 candidate defects were separately repaired in `e0669f06`; that suite still
has two frozen-copy designed-red observations and deliberately exits 1. This
repair does not waive or apply those frozen copies. Publication-head CI and
native PowerShell results remain separate from the successful available cloud
checks above; no overall CI success is claimed here.
