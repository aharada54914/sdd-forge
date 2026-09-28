# macOS UTF-8 admission failure

Status: human-applied repair verified; independent design review is NEEDS_WORK.

The design bytes decode with Python strict UTF-8, with 3975 bytes and no NUL.
The same bytes passed to `/usr/bin/iconv -f UTF-8 -t UTF-8` succeed with a
pipe output, but fail with `/dev/null` output: `Inappropriate ioctl for device`.
ASCII-only precheck JSON succeeds with both sinks. Individual characters also
all succeed; this is not malformed input.

The production pipeline is at
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:850`.
The applied change retains `set -euo pipefail` and UTF-8 validation,
but drains iconv output through `cat` instead of writing it directly to null:

```diff
-      printf '%s' "$content_base64" | base64 -d | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 ||
+      printf '%s' "$content_base64" | base64 -d | iconv -f UTF-8 -t UTF-8 2>/dev/null | cat >/dev/null ||
```

Focused experiment: the proposed pipeline accepts the unchanged design (exit
0) and rejects byte FF (exit 1, iconv stage exit 1). These are diagnostic
experiments, not an executed product regression suite.

An ordinary apply_patch of this line was denied by the actual PreToolUse SDD
guard. The user subsequently applied the authorized one-line repair.
Original validator SHA256:
`8e5e885c026041a4059f0f5462d2c213f6072c0d8cc9e7056ee3713f48450d32`.

Applied validator SHA256:
`8c760abc0081f5f91f04efe0a73d4a2ec82bf3cad3a40b94a36017ca3b5dad72`.

Post-apply checks on macOS: the original pipeline fails on the unchanged
Japanese design (exit 1), the repaired pipeline accepts it (exit 0), and the
repaired pipeline rejects byte FF (exit 1). These are focused checks, not a
full regression or native-host activation proof.

Normal persisted-identity admission, without a second reservation, succeeds:

```text
REVIEW_CONTEXT_OK 83ea62d5d10aa7afc5f6dee2faa1f09644b467304683a2a496e6c0108e44df0d sequence=1194 previous_record_sha256=5414ce5d690a931dab0e2980800747afe9d04e69df3521bd1980ca7bb8df4266 pre_append_tip_sequence=- identity_unique=yes
```

Independent native reviewer A completed with NEEDS_WORK (one Major:
TEST-STRATEGY-COVERAGE); independent reviewer B completed with PASS. Canonical
outputs and their hash-bound contract are persisted in
reports/impl-review/sdd-domain-concept-test/attempt-1/round-1/. The remaining
finding concerns explicit unit-test and mock boundaries, not UTF-8 admission.
Existing reservations and historical outputs are preserved. Design repair,
repeat review, implementation, CI and integration remain pending.

## Product regression after human application

On 2026-09-28, `rtk proxy bash tests/review-context-boundary.tests.sh`
completed with exit 0 in this worktree on macOS, using both the Bash and
installed PowerShell runtimes. The suite verified all 32 source citations,
the reservation/verification boundary (including double reservations and
identity mismatches), and three investigation-runtime unit tests.
Investigation completeness fixtures also passed: regular files 116/116,
hardlinks 84/84, and symlinks 84/84. No expected rejection was relaxed.

This is executed product regression evidence, not native Windows execution,
live hook activation, a passed design review, CI, or main integration proof.
The Japanese-input acceptance and malformed-byte rejection above remain the
focused before/after reproduction of the macOS iconv defect.
