# #618: measured scope reduction

On 2026-10-31 the owner explicitly accepted: 「再利用を見送って入力整理と計測結果を成果としてクローズでよい」.
The accepted outcome is independent-review input organization plus the measured
decision not to implement heavy-result reuse. This is a scope change under the
issue's instruction to reduce scope when benefits are insufficient, not a claim
that the original cache acceptance conditions passed.

Three native executions took 17.362851 seconds. A cold BuildKit run and two
cache hits, including artifact retrieval and validation, took 46.122568 seconds.
Previously observed image preparation added 24.907200 seconds. Warm hits retained
the original run and bytes; they were not new executions. The retained product
receipt still says `reusable:false`. These small, uncontrolled samples justify
this workload's no-go decision, not a universal claim about cache performance.

The retained [original evaluation](README.md) records the method, setup failures,
negative controls and unimplemented trust/admission boundaries. Its historical
description is unchanged. [published-index.json](published-index.json) covers
only the 13 original files selected for publication; it is not the full scratch
archive inventory. Images, source exports, tar files and credentials are excluded.

The existing [reviewer preparation comparison](../reviewer-preparation-20261031/README.md)
records all five matched pairs and negative controls. The implemented
`reviewer-index` keeps commit/inventory binding and every required original's
path/hash; it supplies navigation, not a reviewer verdict or permission to skip
originals. Both routes read six originals (35,038 bytes). The 0.901 ms median
difference is smaller than variability: no human time or causal speedup is claimed.
Dirty selected input, tampered snapshot and missing required inputs are rejected.

Product integration remains tracked by PR #676. Source
`1d41e7d8baeead19bf7225f0752d4783a1c8b660` passed CI run 41169382064
(41 successful jobs, one inactive capability-mode Gate skip) and native Codex
review reported no major findings. Required GitHub approving review and merge
are still pending. Closing this scoped investigation does not imply main was
updated, grant task/release approval, or close parent #613.
