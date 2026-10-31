# A8 caller repair: verified next operation

2026-10-05. Preparation only; no guard repair, protected application, model launch, reservation or formal verdict.

Current installed Python SHA-256 remains `248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227`; #536 source remains `7392cccf47ece13bd6af919bcd319926f92911b11a41a6e7dd243eb41f68c77a`. These match the exact proxy-cat refusal analysis in `a8-caller-cat-current-refusal-20261005.md`. No refused role payload was retried. The missing complete-invocation proxy-cat read classification is separate from the rg Unicode/no-config repair.

In #536 owner, `requirements.md:3` and `design.md:3` for both guard-role-read-regression and spec-review-prelaunch-recovery remain Pending. The recovery data contract line 3 remains Draft. Bounded file inventory shows neither feature has tasks.md. `read-policy-implementation-boundary-20261004.md` explicitly requires complete-invocation classification rather than another prefix exemption and states no Approved implementation task exists. Therefore no production guard candidate may be invented/applied in A8 to bypass these gates.

## Verified immediate human-only prerequisite

Read the entire script and ran its non-applying mode through rtk proxy, login=false:

`rtk proxy python3 -B reports/verification/spec-boundary-consumers-human-apply.py`

cwd: `/private/tmp/sdd-guard-main.3JEj4I/repo`.
Exit 0; all eight original pins matched, eight candidates constructed; final output: `DRY_RUN_OK: candidates constructed in memory only. No files changed or candidate code executed.`

Script SHA-256: `a62c3328b05ebbcb71b03921d2d7e08fee2e1c9b67212a53dfb72efc32a4967c`.

Human-only command, NOT executed:

```text
rtk proxy python3 -B /private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/spec-boundary-consumers-human-apply.py --apply-human
```

Exact targets and computed after pins:

```text
115f2acd62c302ab7f6175ef41d1553977c7fb9f813b59f496d4a0492eb041fc plugins/sdd-review-loop/scripts/spec-review-precheck.sh
3e34cea91223e002efa5454c1b1753b9f06d636bdbc4a40a6ce085d40b3cc654 plugins/sdd-review-loop/scripts/spec-review-precheck.ps1
fa60037ca2d48f8f0ed5ddbfe2a4a4f9a51109e1a7b0617cc5ef64f1ee298684 plugins/sdd-quality-loop/scripts/check-workflow-state.sh
1d8ded3fcdad96fb1287136ef3d312f52a20480c05ae6f53f3713010ac275e91 plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
c871c839ace06114fbc8fd20546a3cb6ea5632827fb9237e9dd8196a529945bb plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md
96fbd341f8ffe9e18594be0610a22b079bf9f8b08a9cc4e0708c431c99cf2284 tests/spec-review-loop.tests.sh
a6abd5f5f06b5b38cfe4dc4b7621692fb189bfd8ae8d2ec174be32b745d65b13 tests/lib/loop-driver.sh
dd4257963e6f3d8e6177aa0d616c3d9da8f86851e8354abb89f8a492583bfae5 tests/lib/loop-driver.ps1
```

The script validates all before hashes, backs up all originals under a newly allocated sdd-boundary-consumers directory, rechecks all originals before first write, and compares each readback byte-for-byte. It stops on drift; partial failure requires using the printed backup. This is consumer manifest synchronization, NOT proxy-cat guard repair. Its application must be followed by regressions and the changed-input recovery/spec/design/task path before guarded implementation and normal caller-read verification. Existing generic repair approval is not requested again.

No meaningful fresh implementation launch is currently established by this prerequisite alone. No repeated green fixture run was performed. An initial lookup used a missing historical note name (ordinary cat exit 1), corrected by bounded file discovery; no protective refusal occurred in this investigation. Existing evidence and dirty sources were preserved.
