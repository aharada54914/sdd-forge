# RT-20261009-001: scoped substitute-evidence approval

Recorded 2026-10-10. Owner: shared-review-launch-integration/sdd-forge.
Baseline HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`; existing tracked and untracked integration changes are retained.
Classification: high-risk evidence acceptance amendment, limited to RT-20261009-001 / T-001. No runtime authorization or validation threshold changes.

The user explicitly approved: 「RT-20261009-001に限り、元の実CLI失敗記録＋事後再現と明記した旧コードの失敗＋修正版の成功を代替証拠として認める」.

Accepted evidence combination:

1. Original native CLI failure: `reports/verification/shared-launch-handoff/t005-native-transport-blocker-20261009.md`.
2. Explicitly retrospective old-code failure: `specs/shared-review-launch-repair/verification/T-001/compact-bundle-20261010/retrospective-red.py` and adjacent `retrospective-red.log`. The retained old transport is hash-pinned; this is not contemporaneous pre-implementation RED.
3. Repaired-code success: adjacent `quality-nontty-transport.log` and the remaining focused suites listed in `coverage.md`.

This decision supersedes only the outstanding chronology decision in `continuation-checks-20261010.md` and the compact bundle coverage note. Those original records and all frozen evidence remain unchanged. It does not create a new review verdict, waive independent verification, mark a task Done, or establish native Windows, current-head CI, merge or post-merge success.

Adoption checks completed on 2026-10-10:

- Re-ran `retrospective-red.py`: exit 1, one expected old-code failure (`KeyError: compact_command`). This remains retrospective evidence, not a claim of contemporaneous RED.
- Re-ran `tests/quality-nontty-transport.tests.py`: exit 0, 20 tests passed.
- T-001 and T-005 contract and evidence-bundle validators passed; their dirty-checkout warnings are retained, not treated as clean-commit or CI proof.
- Independent chronology review found no remaining adoption blocker. It confirmed the T-001 frozen report and bundle were intact. The later T-005 additions to `tests/t001-evaluation-preparation.tests.py` are not covered by the historical T-001 verdict; T-005 has its own evidence.

The existing T-001 formal evaluation is `reports/quality-gate/20261009-shared-review-launch-repair-T-001-compact.md` (PASS, zero Critical/Major). This addendum resolves only the approved chronology condition; it does not rewrite that verdict. Integrated exact-head CI, merge and post-merge verification remain pending under T-004. No further human decision is required for this same chronology question.
