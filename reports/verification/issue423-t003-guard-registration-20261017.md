# Issue 423 T-003: enforcement-chain registration repair

## Scope before editing

- Owner: the isolated PR 535 publishing checkout; branch `codex/issue423-cloud-publish`.
- Baseline HEAD: `3e7c70c941f48bbb8f9ef2ac3493fef9ee504f91`; working tree clean.
- Risk: protected enforcement inventory. No approval, task state, historical evidence, or runtime decision semantics are changed.
- Contract: every script invoked by the enforcement chain must be included in the canonical protected suffix inventory (WFI-037).
- Affected surfaces: canonical invariant JSON, generator baseline membership, and four generated runtime modules. Existing guard-parity coverage remains mandatory.

## Reproduction

GitHub Actions run `38948823921`, job `117134716189`, on the baseline HEAD failed:

```text
FAIL: wfi037: chain-invoked scripts are unprotected: plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py
guard-parity.tests.sh: 113 passed, 1 failed
```

The quality-gate skill invokes this T-003 evaluator, but its path was omitted from the protected inventory. The existing structural regression correctly detected the omission.

## Planned repair and verification

Add only that path to the canonical inventory and generator baseline, then regenerate the runtime modules. Verify generator consistency, guard parity, focused write-denial/read-allowance, and T-003 regressions. Obtain an independent diff review and rerun applicable CI on the resulting head. This repair does not establish formal T-003 acceptance or Done.

## Executed local verification

- `bash tests/guard-parity.tests.sh`: 114 passed, 0 failed; the existing WFI-037 regression now passes.
- T-003 selected-plan regression driver: 28 tests passed.
- `python3 plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check`: exit 0.
- Python, Node and PowerShell guard probes for the evaluator path: Read allowed (exit 0), Write denied (exit 2), six checks passed. Only payload classification ran; no protected write was attempted.
- `git diff --check`: exit 0.

Independent diff review: PASS, with no required findings. The reviewer independently reran guard parity (114 passed), generator consistency, whitespace validation, and the six runtime authorization probes. The reviewer did not independently rerun the T-003 suite or native Windows execution.

Latest-head CI is pending. These local results do not replace the prerequisite evidence migration or the formal T-003 quality-gate decision.

## Applied-mirror repair scope

Baseline HEAD `211645a156043a2ca0537a7d88b19052f88f8cee` was clean before this repair. Its CI run `38954829996` rejected stale applied copies of the invariant inventory and generator in the A1/A2/A3 distribution bundles. The existing mirror synchronizer identifies 24 stale files and leaves 19 unrelated pending candidate entries unchanged.

This repair synchronizes those 24 applied copies and their four hash manifests only. It retains the protected-inventory risk classification, changes no runtime decisions, and preserves pending workflow and guard candidates. Required verification: mirror freshness, A1 registration, A2 capability generation, A3 component coverage, guard parity, T-003 regression, independent diff review, and exact-head CI. No historical verdict or task state is changed.

### Mirror repair results

| Regression | Bash | PowerShell |
| --- | ---: | ---: |
| A1 guard invariant registration | 82 passed | 86 passed |
| A2 capability generation | 30 passed | 30 passed |
| A3 component coverage | 46 passed | 47 passed |
| Human-copy freshness | 6 passed | 6 passed |

Guard parity passed 114 checks; the T-003 Python driver passed 28 tests. These runs total 575 passes and zero failures. Both freshness runs retain 19 informational pending candidates. The mirror-classification Python driver additionally passed two tests. Generator consistency and whitespace checks exited 0.

Independent read-only diff review: PASS with no required findings. The reviewer verified all 24 copies and four manifests, confirmed the 19 pending entries were unchanged, and independently reran freshness (6 passes), A1 (82 passes), synchronizer check, generator check and whitespace validation. The reviewer did not rerun A2/A3, PowerShell or T-003. Exact-head CI and formal task acceptance remain pending.

## Protected inventory regression baseline repair

Owner: the isolated PR #535 publishing checkout, branch `codex/issue423-cloud-publish`, clean HEAD `d11b1fec9c0ebe600b8e52b40e4dabe322e8ea1c`. Scope: the host-review regression's fixed inventory digest and explicit membership assertion. This test-only correction follows the approved protected registration above; it does not change authorization, task state, or historical evidence.

CI run `38959804089`, job `117171696132`, and a focused local reproduction both reject the old inventory digest in `ProtectedEntrypointTests.test_012d_unrelated_membership_unchanged`. Comparing the canonical inventory before commit `211645a` with the current inventory proves that the only change outside this suite's six entrypoints is the addition of `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py`; no key or membership was removed. The old normalized digest is `8a4f78310312882d4780d30d4f3a491b63507036647f2c28695ad2555c12c883`; the new digest is `ea6c2029371e9dada288c6d1b877ddb789ab2b6089e3d7783a6b3d29772290e9`.

Keep the evaluator inside the pinned inventory, update the expected digest, and assert its unique membership and rejection on removal. Required checks: the complete host-review preflight suite, generator consistency, T-003 regressions, independent diff review, and exact-head CI.

Validation: the complete host-review preflight suite passed 21 tests; T-003 passed 28 tests; generator `--check` and `git diff --check` exited 0. Independent diff review returned PASS, independently recomputed both inventory digests and the one-member difference, and reran all 21 host-review tests without skips plus generator and whitespace checks. This is regression and diff-review evidence, not a formal T-003 quality-gate verdict. Exact-head CI and the formal Done decision remain pending.
