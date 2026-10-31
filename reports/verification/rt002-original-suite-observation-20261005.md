# RT002 original-path regression observation — 2026-10-05

Checkout: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`

Observed HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8` (working-tree changes present; HEAD alone does not identify tested bytes).

The orchestrator ran both original regression drivers after the shared-launch application. Both processes completed:

| Command (in the checkout above) | Exit | PASS | FAIL |
|---|---:|---:|---:|
| `rtk proxy bash tests/check-hook-activation-handshake.tests.sh` | 0 | 984 | 0 |
| `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` | 0 | 985 | 0 |

These were local macOS executions, including PowerShell on macOS, not native Windows executions. Intermediate tool output was truncated; the final assertion summaries and exit codes were observed directly. This report is an observation summary, not a claim that a complete raw log was archived.

SHA-256 values checked in this turn:

```text
1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d  plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c  tests/check-hook-activation-handshake.tests.sh
49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd  tests/check-hook-activation-handshake.tests.ps1
```

This does not amend the stopped manifest-bound implementation run, its missing dependency inventory, or any historical review. It does not prove installed native activation, independent evaluator admission, CI, merge, or Done. No reservation, review verdict, approval, task status, commit, push, or merge was performed for this observation.

The formal recovery still requires a dependency-complete new input snapshot and fresh implementation provenance before evaluator admission; see `rt002-fresh-revalidation-stop-and-hook-diagnostic-20261005.md`. Do not re-run a denied inspection through an alternate executor or adopt this ordinary regression summary as the missing formal provenance.
