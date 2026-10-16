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
