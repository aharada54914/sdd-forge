Task: issue #359 main verification
Date: 2026-09-05
Repo: /Users/jrmag/sdd-forge
Head: ca023cc85d9db5d44f63ec77e4d3ff73f3f9bfdf

Scope:
- tests/collection-layer.tests.sh
- tests/collection-layer.tests.ps1
- tests/run-panelist-effort.tests.sh
- tests/run-panelist-effort.tests.ps1

Command lines used:
- PATH=/bin:/usr/bin:/opt/homebrew/bin /bin/bash tests/collection-layer.tests.sh </dev/null
- PATH=/bin:/usr/bin:/opt/homebrew/bin pwsh -NoProfile -ExecutionPolicy Bypass -File tests/collection-layer.tests.ps1 </dev/null
- PATH=/bin:/usr/bin:/opt/homebrew/bin /bin/bash tests/run-panelist-effort.tests.sh </dev/null
- PATH=/bin:/usr/bin:/opt/homebrew/bin pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-panelist-effort.tests.ps1 </dev/null

Suite results:
- collection-layer.tests.sh: exit 0; 52 passed, 0 failed
- collection-layer.tests.ps1: exit 1; 38 passed, 8 failed
- run-panelist-effort.tests.sh: exit 0; 28 passed, 0 failed
- run-panelist-effort.tests.ps1: exit 0; 28 passed, 0 failed

Skip check:
- No assertion-level SKIP lines were present in any of the four captured outputs.
- The only skip-related text observed was diagnostic/source commentary, not a suite skip result.

Claim mapping:
- modern codex argv:
  - tests/run-panelist-effort.tests.sh:138-158
  - tests/run-panelist-effort.tests.ps1:138-176
  - plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:278-295
- async stdin preservation:
  - plugins/sdd-quality-loop/scripts/lib/panelist-common.sh:51-56
  - plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:258-265
  - plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh:151-169
  - tests/collection-layer.tests.sh:415-458
  - tests/collection-layer.tests.ps1:421-464
- greedy JSON extraction:
  - plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:316-324
  - plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:358-359
  - tests/collection-layer.tests.sh:514-627
  - tests/collection-layer.tests.sh:631-762
  - tests/collection-layer.tests.ps1:539-654
  - tests/collection-layer.tests.ps1:658-789

Notes:
- The PS1 collection-layer suite is red in this checkout. The failing assertions were CL-012c, CL-014b, CL-019a, CL-019b, CL-020, CL-021b, CL-022, and CL-023b.
- The three issue claims have test coverage, but the failing PowerShell suite does not establish successful acceptance. The primary addendum below distinguishes transport-fixture failure from extractor behavior.

Raw output artifacts:
- /tmp/issue359-verify.tUZU0H/collection-layer.tests.sh.out
- /tmp/issue359-verify.tUZU0H/collection-layer.tests.ps1.out
- /tmp/issue359-verify.tUZU0H/run-panelist-effort.tests.sh.out
- /tmp/issue359-verify.tUZU0H/run-panelist-effort.tests.ps1.out

## Primary causal probe addendum — 2026-09-05

The transcript stubs at `tests/collection-layer.tests.ps1:321–334` and the CL-014 fixture exit without reading stdin. The unchanged runner redirects a combined file through Start-Process (`plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1:247–275`). CL-012c separately expects an obsolete `disable-model-invocation: true` value; the currently shipped false value supports delegated invocation. No production code or protected test was edited.

Primary executed two otherwise identical synthetic stubs through the actual runner, with `SDD_PANELIST_CODEX_CMD` explicitly selecting each stub:

```sh
rtk proxy env PATH=/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin SDD_PANELIST_CODEX_CMD=/tmp/issue359-probe/codex-no-drain.sh pwsh -NoProfile -File plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1 --task T-PROBE --feature feat --input /tmp/issue359-probe/input.txt --spec-root /tmp/issue359-primary.uZDXl3/no-drain/specs </dev/null > /tmp/issue359-primary.uZDXl3/no-drain.log 2>&1
rtk proxy env PATH=/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin SDD_PANELIST_CODEX_CMD=/tmp/issue359-probe/codex-drain.sh pwsh -NoProfile -File plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1 --task T-PROBE --feature feat --input /tmp/issue359-probe/input.txt --spec-root /tmp/issue359-primary.uZDXl3/drain/specs </dev/null > /tmp/issue359-primary.uZDXl3/drain.log 2>&1
```

No-drain: actual exit 1, `failed to start codex: Broken pipe`; log SHA-256 `c0c7a45f8cd4cd0152389649c82a42e60b954fc1cb380e5433a916d626acc54d`. Drain: actual exit 0 and a T-PROBE verdict JSON written; log SHA-256 `a4c752212466475e3f02fe9c0f10076212eee455f0e32e03c3f65755118cf820`.

Stub SHA-256 values: no-drain `d59433dd635f912f7ce2b8c8cbfe5e5ac944ed4880e03e44922d2e8ce86d2ade`; drain `89ebd05c810db8a60b61bb9b7513730494013a09663684a43a73259a6d75be3c`. Input was synthetic `bundle content` only. Both primary logs name the intended local stub. An earlier delegated attempt accidentally selected real Codex and failed; it is excluded from causal evidence and must not be described as an offline stub execution.

Conclusion: the stdin-consumption fixture explains the reproduced transport failure before extraction. This does not prove every failed JSON case passes, and does not replace a fresh full-suite run after approved fixture repair. Issue #359 remains unresolved.

## Scope distinction verified 2026-09-06

PR 400 head `c3b3dd21f56a923baf0ca5ac3c8b9ec6f359398d` changes `tests/cross-model.tests.ps1`, not `tests/collection-layer.tests.ps1`. Its RT-20260906-001 target.files contains only the former. The primary verified the exact commit diff and ticket body. The agent's statement that this PR includes the collection-layer stdin repair was rejected: similar stub behavior in two different suites is not evidence that both were changed. CL-012c's obsolete true assertion remains in the collection-layer suite. Neither that assertion change nor a collection-layer implementation is silently included in the narrower T-002 ticket.
