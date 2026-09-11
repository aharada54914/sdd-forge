# PR405: current-main conflict inventory

Read-only Git merge-tree inputs:
main4366438f3b243210a4ece5a17f873ca2d920600a and
A8 a1b958bc648aaf4b22a99a45262df490d64438c7.
Exit 1; conflict tree 47dc49f654d7d23ff8d1442d7a357c873f689e94.
No checkout, index merge, protected publication or resolution was performed.

Twelve conflicted paths:

- docs/workflow-improvements/WFI-048.md
- docs/workflow-improvements/WFI-051.md
- plugins/sdd-quality-loop/references/guard-invariants.json
- plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js
- plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1
- plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh
- plugins/sdd-quality-loop/scripts/generated/guard_invariants.py
- plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
- plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
- plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
- reports/review-context/identity-ledger.json
- specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256

Original git-show inspection established a backtick difference in invariant
path_boundary_chars and five different hashes in the A6 manifest. These are
not grounds to select one side wholesale. Preserve current security behavior,
reconcile invariant source before regenerating four runtime outputs, reconcile
ledger identities without dropping or rewriting history, and compute manifest
hashes from final selected bytes. WFI disposition prose must reflect verified
delivery, not merely a historical branch assertion.

A subsequent Node-based read-only extraction of guard conflict hunks was
rejected by the active PreToolUse SDD guard before execution. No extraction
results exist, and it was not retried through another executor or encoding.
The detailed guard semantic resolution is outstanding; this inventory is not
a merge-ready candidate or formal review.
