# Native executable discovery

The initial requested `/Applications/ChatGPT.app/Contents/Resources/codex` failed with ENOENT before thread creation. No worker turn or reservation occurred.

The same installed ChatGPT application now provides `codex-cli/bin/codex`; its version is `codex-cli 0.160.0` and wrapper SHA-256 is `50ab38ba21d0d9f8346f32f41848382f15b556190f3c7a07e885a4fb73e379c8`. The runner uses this application-provided entry point, not a shell alias. This changes executable location, not permissions.
