# FilesOnly exit-message repair candidate — 2026-10-03

Status: bounded installer repair applied in this worktree; not committed or
pushed. This behavior is outside `sdd-domain-multitarget` T-002's Done When and
remains separate from T-002's frozen implementation report and formal
quality-gate inputs.

## Root cause

`install.sh:710` calls `rollback` from the `EXIT` trap even when the captured
exit code is zero. `install.sh:1022` sets `REGISTRATION_STARTED=1` before the
FilesOnly branch; `install.sh:1046-1048` reports that registration was skipped;
the successful tail at `install.sh:1069-1070` clears only
`NEW_INSTALL_PLACED`. Thus `rollback` reaches `install.sh:691-697` and prints
the registration-failed note on a successful FilesOnly run. The retained
install tree and exit code are correct; the note is false.

## Minimal applied diff sketch

```diff
diff --git a/install.sh b/install.sh
--- a/install.sh
+++ b/install.sh
@@
-trap 'rc=$?; rollback; cleanup; exit $rc' EXIT
+trap 'rc=$?; if [[ $rc -ne 0 ]]; then rollback; fi; cleanup; exit $rc' EXIT
diff --git a/tests/install.tests.sh b/tests/install.tests.sh
--- a/tests/install.tests.sh
+++ b/tests/install.tests.sh
@@
     if [[ -n "$fail_pattern" ]]; then
         if [[ $installer_failed -eq 0 ]]; then
             fail "installer should have failed for pattern '${fail_pattern}'"
         fi
+        if [[ "$out" != *"Note: registration failed"* ]]; then
+            fail "real registration failure did not report the retained install"
+        fi
@@
 _m_orig_codex_home="${SDD_CODEX_HOME:-}"
+_m_stdout="${_m_root}/stdout.log"
+_m_stderr="${_m_root}/stderr.log"
@@
     --skip-plugin-install \
     --skip-agent-install \
-    2>/dev/null || _m_failed=1
+    >"$_m_stdout" 2>"$_m_stderr" || _m_failed=1
@@
 if [[ $_m_failed -ne 0 ]]; then
     fail "lock scenario (m): successful install failed unexpectedly"
     _m_ok=0
 fi
+if ! grep -Fq 'Plugin registration was skipped because --target=FilesOnly.' "$_m_stdout"; then
+    fail "lock scenario (m): FilesOnly skip message missing"
+    _m_ok=0
+fi
+if grep -Fq 'registration failed' "$_m_stderr"; then
+    fail "lock scenario (m): successful FilesOnly install reported registration failure"
+    _m_ok=0
+fi
```

The source change conditions rollback on the original nonzero exit code, while
`cleanup` still runs on both paths and `exit $rc` preserves that original
status. The existing registration-failure scenarios at
`tests/install.tests.sh:347-393,577-585` already assert a nonzero exit and
retained new tree; the additional assertion covers the real warning. The
FilesOnly success scenario at `tests/install.tests.sh:928-964` previously
discarded stderr, which hid this defect. The test now captures both
streams and checks the success/skip/no-false-warning contract.

## Observed RED before source change

The human-executed FilesOnly log is
`reports/verification/issue423-t002-build-human.log.h2HQDSYl`, SHA-256
`450aba84af3339e078ec3f9f6e69d57928b1177fa24705edc294ddaf964a2fe8`.
It records `Plugin registration was skipped because --target=FilesOnly.`, then
the false `Note: registration failed`, followed by the installed validator's
`all 9 checks passed` and final PASS. This is a real successful run, not a
synthetic warning fixture. The read-only negative assertion against that log
returned exit 1:

```text
not ok: successful FilesOnly output falsely reports registration failed
```

With the new assertion in place and before changing `install.sh`, the actual
`bash tests/install.tests.sh` run exited 1 with `Results: 42 passed, 1 failed`.
Its sole failure was `lock scenario (m): successful FilesOnly install reported
registration failure`. After applying the one-line trap change, the same suite
exited 0 with `Results: 43 passed, 0 failed`. The real registration-failure
scenario still asserted the warning in its captured output. `bash -n install.sh
tests/install.tests.sh` and `git diff --check` both exited 0. These tests do
not constitute a new installed-host build, formal T-002 quality-gate, CI, or
merge proof; the T-002 evaluator startup refusal remains separate.

The old human build log bound `install.sh` SHA-256
`9b43d5eaf93a9cefffc562a3108f43ab2bc2a64c675a710ec5c59250f7abe719`.
This repair changes that source to
`87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50`;
the old build PASS is not proof for the new installer byte. T-002's four Done
When clauses in `specs/sdd-domain-multitarget/tasks.md` concern ownership and
contract boundaries, not installer output. Any current-byte distribution
claim for this repaired installer therefore needs separate execution evidence;
none is claimed here.

The standalone two-file patch is
`reports/verification/issue423-filesonly-exit-message-20261003.patch` (SHA-256
`a33a7e00564d38335d244a41fbd12c38e736a6d7d2b0780a702dbdd898285f24`).
`git apply --reverse --check` succeeds against this worktree. At inspection,
`HEAD=3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9` and
`origin/main=49e1602459108fd8ef318b644b51301a3b61d0b1` had identical
`install.sh` and `tests/install.tests.sh` blob IDs (`de98b494a44cd1c1984f8272526cddd89d37e1c5`
and `491a30dfd8fad22705ea6eff2f141dd20d83928d`, respectively). The
patch excludes all unrelated dirty files. This is patch applicability evidence,
not a commit, PR, CI, or independent review.

## Separate bugfix contract candidate (not an Approved task)

The clean delivery worktree is based on `origin/main` at
`49e1602459108fd8ef318b644b51301a3b61d0b1`, branch
`codex/issue423-filesonly-exit-message`. Only `install.sh` and
`tests/install.tests.sh` are modified there. The current-byte installer suite
exited 0 with `Results: 43 passed, 0 failed`; `bash -n` and `git diff --check`
also exited 0. The source and test SHA-256 values are
`87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50`
and `648d093acbda64a1c3dff445fb2a97f537688a6f6426a64bd2701e36ff444bf4`.

Proposed scope: correct only the Unix installer's success-path `EXIT` trap;
retain the existing nonzero rollback behavior, cleanup on both paths, and
original exit status. Acceptance cases: (1) successful `--target FilesOnly`
exits 0, says registration was skipped, does not say registration failed, and
releases its lock; (2) a real plugin-registration failure exits nonzero,
retains the placed install as currently designed, and still emits the
registration-failed warning. Security assessment: this changes no credential,
authorization, or remote API path, but the trap governs an installer cleanup
boundary; independent review must check both exit paths. Proposed risk:
`medium` if the scope is accepted as diagnostic-only; the human must confirm
the tier, particularly whether the installer mutation boundary instead calls
for `high` and TDD evidence.

No existing task in the clean base covers this exact bugfix. In particular,
`specs/sdd-domain-multitarget/tasks.md` T-002 is Draft on that base and its
Done When covers ownership/contracts, while
`specs/epic-196-a8-integration/tasks.md` explicitly excludes FilesOnly's own
behavior. The repository requires a separate approved task and independent
quality gate before Done. `check-sdd-structure.sh` passed on the clean base;
`sdd/project-context.yaml` is physically absent, so a future bugfix bootstrap
would resolve its full-profile compatibility track only after its required
hook-activation handshake. No new Phase 1/Phase 2 artifact, review verdict,
approval field, reservation, commit, push, PR, or gate result is claimed here.

## Independent bugfix bootstrap precheck (blocked, 2026-10-03)

On the clean delivery worktree, `rtk proxy bash scripts/check-sdd-structure.sh`
exited 0 (`check-sdd-structure: OK`). The required capability handshake in
`sdd-bootstrap-interviewer` was then attempted before track selection or
Phase 1 artifact creation:

1. `rtk proxy bash plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh --emit-challenge` exited 0 and supplied a fresh nonce and the canary target `sdd/.hook-canary-sentinel`.
2. One real `apply_patch` call attempted the prescribed canary addition. The PreToolUse hook refused the edit. The canary remains absent. Its raw response was saved verbatim outside this repository (SHA-256 `40248932290535da1a0c37ee37ab8bb739daba8b7910fb5a8bda7b239fcb62f2`); that private record must not be published because it contains a workstation path.
3. `rtk proxy bash plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh --verify-response --nonce <challenge nonce> --recorded-result <private raw result> --runtime codex-cli` exited 61 with `CAPABILITY_RUNTIME_UNAVAILABLE` / `RECORDED_RESULT_UNREADABLE`. The visible PreToolUse refusal was prose, not the verifier's required machine-readable event response. It was not normalized, inferred, or replaced with invented JSON.

`sdd-bootstrap-interviewer` Track Detection requires `HOOK_ACTIVE` and says
any other result stops with `CAPABILITY_RUNTIME_UNAVAILABLE`; therefore no
track was selected and no Phase 1 artifacts were created. This is the current
single formal blocker, independent of the two-file regression result and not
caused merely by a Draft task. The minimal legitimate next step is for the
host/human to provide the actual raw machine-readable result of its canary
tool event to the verifier (or repair the host's response recording under
separate authorization), then rerun the official handshake. A prose denial
alone cannot establish `HOOK_ACTIVE`. Do not retry the refused edit through
another executor, fabricate flags, reserve identities, or mark an approval.
