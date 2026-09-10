# PR391 local golden-test hang

Status: runtime cause isolated; full package verification still incomplete.

## Exact target

- PR head: `e75b8f804ec381a12e92dc5a5509bb00ad426357`.
- Detached worktree: `/private/tmp/sdd-forge-mcp-pr391-l5Lu7f`.
- Node 24.13.0; Homebrew Bash `5.3.9(1)-release` (aarch64-apple-darwin25.1.0).
- Test: `dist-test/tests/golden/deep-verify-parity.test.js`.

## Primary observations

1. The targeted process was live at 2m39, with tree 45211 (node:test) -> 45586 (test worker) -> 45619 (Bash evidence checker) -> 45624 (Bash child), on fixture `golden-parity-pass-hMEGNl`. The last child had no child process and stdin `/dev/null`.
2. One-second native process sampling of 45624 recorded 786/786 samples at `execute_disk_command -> do_redirections -> do_redirection_internal -> heredoc_write -> write`. Original sample: `/tmp/bash_2026-09-06_133602_zTdN.sample.txt`. This establishes blocking at heredoc delivery, not slow TypeScript assertions or Python bundle validation.
3. A fresh nonblocking `os.pipe()` probe accepted exactly 512 bytes before BlockingIOError. Both descriptors were closed in a finally block. No system configuration was changed.
4. A separate 1024-character heredoc passed to `cat` timed out after three seconds under `/opt/homebrew/bin/bash`, emitting zero bytes. The owned diagnostic process group was terminated. Identical input under `/bin/bash` completed with exit 0 and 1025 output bytes in 0.011 seconds. This reproduction contains no repository files, hooks, credentials or test overrides.
5. Queries for `kern.ipc.maxpipekva` and `kern.ipc.pipekva` returned unknown OID. No kernel high-water measurement is claimed.

## Upstream corroboration

The original reporter describes Darwin's dynamic pipe capacity and Bash's build-time heredoc pipe-size assumption; the maintainer acknowledged the defect and intended a development-branch fix:

- https://www.mail-archive.com/bug-bash@gnu.org/msg36149.html
- https://www.mail-archive.com/bug-bash@gnu.org/msg36160.html

The GNU-hosted archive URL could not be opened through the web tool; the above mirrors carry the original author/maintainer messages. No particular released Bash version is claimed fixed. Local sampling plus the isolated comparison support an environment-level heredoc deadlock; the probe does not identify which unrelated process owns pipe memory.

## Decision and next action

Do not change production gates, remove tests, increase assertion margins, disable hooks, alter kernel settings, or terminate unrelated processes. The worker is instructed to stop its owned hung diagnostic, then run the unchanged package suite with `/bin` prepended to the existing PATH while retaining Node and other tooling. This is a clearly labelled runtime comparison, not a successful Homebrew-Bash test. Check Bash-version requirements and report any incompatibility rather than skipping it. Record full results and exact-head clean status before claiming package verification success. All required GitHub CI remains independently mandatory.
