# T-005 acceptance plan

Recorded before execution: 2026-11-13T04:43:52.630369+00:00

All rows are expected observations, not PASS results.

| AC | Test | Expected observation |
|---|---|---|
| AC-001 | TEST-001 | Japanese heading, labeled input, add and list directly on /; no login/navigation. |
| AC-002 | TEST-001 | Adding spaced 買い物 creates exactly one trimmed task and clears/focuses input. |
| AC-003 | TEST-002 | Empty, ASCII/full-width whitespace and newline rejected without mutation; 500 astral code points accepted, 501 rejected. |
| AC-004 | TEST-003 | Checkbox check/reload and uncheck/reload both persist. |
| AC-005 | TEST-004 | Cancel preserves bytes/focus; confirmed delete absent after reload and focus restored. |
| AC-006 | TEST-005 | Actual process restart returns identical id/title/completed and JSON bytes. |
| AC-007 | TEST-006 | Delayed save disables all mutations, repeated events send exactly one request, later updates work. |
| AC-008 | TEST-007 | Japanese save error preserves input/unlocks controls; no automatic retry; lost response recovers on reload; timeout ~10s. |
| AC-009 | TEST-008 | Hash-check and view ImageGen reference; actual 1440/390/320px renders, long-title reflow, navy/teal/white, rounded rows, spacing and 44px controls. CSS zoom 2 only, not native browser zoom. 100-task input/toggle <200ms and assets <100KiB. |
| AC-010 | TEST-009 | HTML title literal; invalid JSON/types/UUID/size/Host/Origin/path/method rejected without data change. |
| AC-011 | TEST-010 | Empty/loading/GET-error/reload recovery; Tab/Enter/Space and delete cancel focus. |
| AC-012 | TEST-011 | Corruption and write failures return errors, preserve bytes/state; atomic precommit fault coverage. |
| AC-013 | TEST-012 | Actual child PID has only 127.0.0.1 listener, loopback GET 200; proxy-free direct TCP to real nonloopback IPv4 fails; no interface means unverified. |

Execution uses only the admitted immutable snapshot, Python bytecode disabled, task-owned temporary directories, existing unittest/browser harness, real /usr/bin/chromium. Outputs are fresh T-005 paths. Parent owns lifecycle and independent review.
