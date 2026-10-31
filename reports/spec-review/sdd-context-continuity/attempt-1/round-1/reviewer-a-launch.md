# Actual reviewer A launch

The native app-server allocated idle, empty thread/session
`01a0e0bd-6540-73c3-aede-a9647ce68de6`. The allocation receipt is retained
in `reviewer-a-host-allocation.json`.

The original validator reserved the pinned invocation successfully:

```text
REVIEW_CONTEXT_OK 486fa0dc2a16fcc681b941f527606ce65ab3ebc237001066828ef76786f0c3ac sequence=1191 previous_record_sha256=7b7cf3b6c258961280b151989cf9841b628c41e5910c2df1cdf215412244b835 pre_append_tip_sequence=1190 identity_unique=yes
```

Only afterward, request 3 started the first model turn
`01a0e0c7-eb05-7e71-bb1a-553a660b2a08`, with `sandboxPolicy.type=readOnly`,
model `gpt-6-sol`, effort `medium`. Its prompt names the shipped reviewer
role, boundary, reserved manifest and actual receipt. No review verdict is
inferred from launch.

Request 2 exceeded the PTY canonical input buffer and was not accepted by
the server: no turn or rollout existed. Its pending terminal line was cleared,
and the shorter request 3 was accepted. This was transport repair, not a
replayed reviewer turn or an enforcement denial.

Before launch, all five manifest hashes matched. The shared-state inspection
still found PreToolUse registrations only in both quality-loop hook files,
no context ignore entry, and the existing esbuild index-only package build.
The guard invariant source was inspected without modifying it. These are
current repository observations, not installed lifecycle support.

The prior readiness note's installed-handshake pending statement is historical.
In this invoking session, one real native canary denial was verified by the
installed original verifier as HOOK_ACTIVE; evidence remains at
`/Users/jrmag/sdd-forge/specs/epic-189-a1-rt002-repair/verification/installed-host-activation-20260927.md`.
This proves that enforcement dispatch only, not the proposed continuity events.
