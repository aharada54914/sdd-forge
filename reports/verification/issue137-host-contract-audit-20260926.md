# Issue #137 host contract audit

Status: documentation and installed-version inspection only; not candidate
activation, a live lifecycle test, a review verdict or implementation approval.
Observed 2026-09-26: Codex CLI 0.155.0-alpha.16.4; Claude Code 2.1.278.

## Adapter decisions

Codex documents prompt/Stop inputs, nullable transcript paths and an unstable
transcript format. Manual PreCompact can stop via `continue: false`;
UserPromptSubmit/Stop can surface warnings with `systemMessage`. Never request
Stop continuation to retry storage. Changed hook definitions require renewed
trust. A turn ID alone is not a documented event-retry identity.
Source: [Codex hooks](https://learn.chatgpt.com/docs/hooks), Common input/output,
Review and trust hooks, PreCompact, UserPromptSubmit and Stop.

Claude documents manual PreCompact blocking through exit 2 or `decision: block`,
but discards that event's `systemMessage` and `continue`. Therefore a common
cross-host response object cannot implement this boundary. Automatic compaction
must receive a nonblocking response. UserPromptSubmit exposes expanded prompt
text and command-hook timeout allows the prompt to continue without hook output.
Source: [Claude hooks](https://code.claude.com/docs/en/hooks), UserPromptSubmit,
PreCompact, Exit code output and Timeouts.

The adapters must use host-specific output serialization, a shared normalized
event core and explicit timeout settings. Documentation is input to the tests,
not proof that these installed versions load the candidate. No trust setting,
hook registration, permission or runtime flag was changed by this audit.

## Required live checks

- On each host, register the reviewed candidate normally; prove the prompt,
  final-output, manual/auto compact and compact-resume event deliveries.
- Exercise save failure: warning visible, ordinary prompt continues, no success
  claim and no Stop-induced extra model turn.
- Exercise manual UNSAFE output and independently prove actual compact refusal.
  Exercise automatic failure and prove compact continues.
- Record only payload field names/types and synthetic fixture content in public
  evidence. Do not publish real transcript content, local paths or credentials.
- Validate transcript adapters against each supported actual format; unknown
  formats remain unavailable, never heuristically declared complete.

## Reuse candidates from read-only investigation

Known-value redaction and fixed diagnostic fields already exist in
`mcp/local-env-mcp/src/diagnostics.ts:52–100` and `:108–148`. Its stated limits
at `:23–26` still apply; replacing arbitrary environment values in conversation
text is not an approved redaction policy. Probe bounds exist at
`mcp/local-env-mcp/src/probe-engine.ts:107–114`, `:162`; UTF-8 boundary handling
at `mcp/ci-mcp/src/tools/actions.ts:569`, `:584–592`. These are investigation
pointers, not authorization to import the MCP transport into hooks.

The approved retention design uses native scheduled execution, not lazy cleanup
alone. No existing local-expiry scheduler implementation was identified in the
scoped search; native scheduling/catch-up still needs platform verification.

## OQ-010: daily expiry scheduling

Human policy approved on 2026-09-26: exclude at 30 days, delete normally within
24 hours, catch up after power-off/sleep, and touch only this feature's logs.
The following mechanisms are design candidates, not installed jobs or live proof.

| Platform | Minimal native mechanism | Boundary to verify |
|---|---|---|
| macOS | Per-user launchd job, daily `StartCalendarInterval`, plus `RunAtLoad` | Calendar jobs catch up after sleep, but not missed power-off schedules. Loading at login supplies a separate overdue check. |
| Ubuntu | User systemd calendar timer, `Persistent=true`, oneshot cleanup | Missed calendar runs are caught up when the timer is activated; suspended calendar timers catch up on resume. A working user service manager is required. |
| Windows | Per-user Task Scheduler daily job plus logon trigger, `StartWhenAvailable=true` | Validate the chosen trigger satisfies this property's documented applicability. Catch-up may be delayed; do not assume immediate execution. |

Sources inspected on 2026-09-26:

- [Apple scheduling guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html), sleep/power-off distinction;
  [Apple launchd manual](https://github.com/apple-oss-distributions/launchd/blob/main/man/launchd.plist.5), `RunAtLoad`;
  [user-agent lifecycle](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html), login/logout.
- [systemd timer contract](https://github.com/systemd/systemd/blob/main/man/systemd.timer.xml), `OnCalendar`, `Persistent`, user-manager startup and scheduling accuracy.
- [Windows missed-start behavior](https://learn.microsoft.com/en-us/windows/win32/taskschd/tasksettings-startwhenavailable), including its default ten-minute catch-up delay;
  [task settings](https://learn.microsoft.com/en-us/windows/win32/taskschd/tasksettings), battery/idle/network restrictions;
  [logon types](https://learn.microsoft.com/en-us/windows/win32/taskschd/principal-logontype), interactive-session requirement.

Design inference: use the owning account, no stored login password, elevated
service, forced wake or resident loop. Recovery after power-on may require that
account to log in; never promise deletion while its scheduler/storage is
unavailable. Registration must report this boundary and its actual readiness.
Disable unnecessary battery/idle/network prerequisites for this local job.
Do not silently enable persistence when a working retention mechanism could not
be registered. Warn and preserve ordinary work instead.

The cleanup entry point revalidates explicitly registered worktree identities,
then uses the same storage lock and expiry routine as recovery. No recursive
home-directory scan, arbitrary registry-provided delete path, or removal of host
transcripts/OS backups. Only fixed owned continuity files are eligible. File
removal is not a secure-erasure guarantee. Job overlap must not run two writers.

Daily wall-clock scheduling has timer jitter and clock/DST transitions; the
24-hour objective is not an exact OS dispatch guarantee. Record late/failed
cleanup honestly, never re-enable expired recovery, and test catch-up separately
from ordinary scheduled execution. Planned cases are TEST-044a–TEST-044i in the
acceptance draft. No scheduler was registered and no log was deleted by this audit.
