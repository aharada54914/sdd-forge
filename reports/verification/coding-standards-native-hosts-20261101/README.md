# Native host observations for coding standards repairs

The current project-skill runner was invoked through Codex, Copilot and Claude on Linux. Each native model ran the documented isolated check once, read the actual owner observation and stdout, and reported the expected marker. The owner observations are v3, passed, exit 0. Native invocation exit codes are all 0.

The independent collector rejected all three cross-environment validations with `runtime-changed`. Codex's evaluation script consequently exited 1 after its successful native run. This is retained as a failed validation, not rewritten to PASS. Discovery, invocation, owner-result reading and cross-environment admission are distinct claims. Claude discovery is evidenced by its actual Skill invocation; no standalone post-cleanup native listing was performed.

`summary.json` binds the source commit/files and private original records. Raw transcripts, environment values and authentication files are not published. The fixture was removed after each run. This is bounded native Linux execution, not full app acceptance, promotion, or Windows/macOS host execution. Platform-specific CLI regression CI is recorded separately.
