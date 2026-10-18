# Local verification environment

The initial full POSIX suite encountered an environment prerequisite failure:
`tests/scenario.tests.sh:534: xxd: command not found`. Product assertions before
that point passed; this is not recorded as a passing suite.

No administrative package installation was available. The actual Vim xxd source
from the upstream `v9.1.0000` tag was downloaded and compiled with the installed
GCC into `/workspace/.tools/sdd-forge-dev/bin/xxd`. No test stub or product test
replacement was introduced.

- Source: https://raw.githubusercontent.com/vim/vim/v9.1.0000/src/xxd/xxd.c
- Source SHA-256: 081c52b38668bb1f68afbb9fef4d73eec88fc12f6ac0f8bef5abf4332d8a61d0
- Binary SHA-256: 3225334e5ad020b466c66a8760a1355127c5b526f2d55256f7de3742c60f3e01
- Version: xxd 2023-10-25 by Juergen Weigert et al.
- Compile: `gcc -O2 -DUNIX xxd.c -o /workspace/.tools/sdd-forge-dev/bin/xxd`
- Rerun: `PATH=/workspace/.tools/sdd-forge-dev/bin:$PATH bash tests/scenario.tests.sh`
- Result: 32 passed, 0 failed; caller log `/tmp/cloud-scenario-after-xxd.log`.

The initial full-suite log remains `/tmp/cloud-current-full-suite.log`; its
failed prerequisite is preserved and is not retroactively rewritten to PASS.
Final release verification must use the final source commit and hosted CI.

`origin/main` was fetched without changing the working branch. Both local HEAD
and fetched origin/main resolved to ebf77988270b848b4c58c65721a10c135fc6db0d on
2026-10-18, so structural compatibility checks can now inspect the actual local
remote-tracking baseline instead of relying on the earlier diagnostic fixture.

## PowerShell wrapper under a restricted PATH

The fallback dispatcher suite initially failed 12 checks because the local
PowerShell wrapper used `/usr/bin/env bash`, while the suite deliberately
removes Bash from its runtime-discovery PATH. The actual PowerShell engine and
product dispatcher were unchanged. The environment wrapper now uses `/bin/sh`
and an absolute `/usr/bin/mkdir`; its XDG paths and PowerShell target are
unchanged. This permits the real engine to run under the restricted PATH.

Rerun: `PATH=/workspace/.tools/sdd-forge-dev/bin:$PATH bash tests/guard-dispatch-fallback.tests.sh`
Result: 47 passed, 0 failed.

Before wrapper SHA-256: 05529ecb3e4a5bf10b7c2f55a77d9c7a66e891065e174e1e9eec5b2867be492b

After wrapper SHA-256: 11ff6b0a844bc44bab028d08018a1986a7f9f90745c2cbff0c579fafa311a28a

## Ruby discovery in the full baseline run

Three Lite fixture suites failed because Ruby was installed under `/workspace/.tools/bin` but absent from the baseline runner PATH. The existing Ruby 3.3.8 wrapper loads YAML/JSON correctly. Re-running with that directory on PATH passed 15, 5 and 6 checks respectively; no product/test code changed. Preserve the original failed full-run log. Four parity suites also assert that `.github/workflows/test.yml` is committed; their dirty-tree failures require rerun from the final committed release tree, not weakening the assertions.

## Pester parity with hosted CI

The baseline `tests/sdd-domain.tests.ps1` run failed because Pester 4.10.1 was not installed. Installed that exact version with the same CurrentUser command declared by `.github/workflows/test.yml:179`. Rerun: 698 passed, 0 failed, 0 skipped; no product/test changes. Evidence: `cloud-local-environment-20261018/domain-pester-pass.log`.

## RTK discovery

The existing RTK 0.51.0 binary at `/workspace/.tools/rtk/0.51.0/rtk` was absent from the baseline runner PATH. With that directory available, `unified-launch-order.tests.py` passes 9 tests and `task-structured-output.tests.py` passes 15. No source/fixture change was made. Final runner PATH must include the RTK directory, `/workspace/.tools/bin`, and `/workspace/.tools/sdd-forge-dev/bin`. The original full baseline invocation exited 1 and is not relabeled successful.

## Baseline summary and final-run isolation

The full baseline completed with 14 failing suites: 4 protected-workflow dirty-tree assertions, 1 repository/install/home byte-stability assertion while authorized implementation/review processes were concurrently writing this workspace, and 9 missing-tool/wrapper suites (xxd, PowerShell wrapper, three Ruby fixtures, Pester, three RTK suites). Existing RTK transport reruns are tracked separately. The five tree-stability checks will run from an isolated exact committed checkout and hosted CI after implementation. Do not infer a checker defect from concurrent workspace changes, do not weaken its assertions, and do not label this baseline PASS.

RTK transport rerun completed: `quality-nontty-transport.tests.py` ran 20 cases, 19 passed and one designed platform skip (exit 0). Saved `quality-transport-rtk-pass.log`. All nine environmental failures now have passing reruns; five tree-stability cases remain pending an isolated committed checkout.

## Local cloud toolchain acquisition

`cloud-local-environment-20261018/cloud-toolchain.json` records the acquired
Bicep 0.48.1 Linux binary, its matching GitHub-published SHA-256, and CDK CLI
2.1145.0 / aws-cdk-lib 2.273.0 / constructs 10.5.0 with npm lock integrity.
Installation disabled package lifecycle scripts. An initial constructs 10.4.2
peer-version conflict was rejected by npm and corrected to the required 10.5.0;
no force or legacy peer-dependency option was used. These are tool acquisition
and native version checks only. Provider task evidence must separately record
actual compile/synthesis. No sandbox or cloud deployment was used.
