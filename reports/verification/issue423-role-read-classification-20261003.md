# Role read classification investigation — 2026-10-03

Status: source-level diagnosis only; no guard repair or evaluator launch.

The T-002 build and installed Registry validator passed in FilesOnly isolation.
The remaining evaluator startup failure is distinct from that build result.
The exact rejected read and its failure are preserved in
`specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/evaluator-launch-blocked.md`.

Source inspection of the primary checkout's
`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` found:

- Lines 74–76: `SHELL_AGENT_ROLE_READ_ONLY_RE` recognizes bare reader commands,
  but not the required `rtk proxy` prefix.
- Lines 1714–1720: `_shell_writes_agent_role` checks raw command text for
  compound syntax before applying the read-only expression. Quoted search
  patterns containing a pipe therefore require a quoting-aware diagnostic.
- The case-insensitive `.codex/agents` path expression can also match the
  prefix of the instruction filename `.codex/AGENTS.md`; this needs a separate
  path-boundary regression if a repair is adopted.

These are source-level explanations, not observed predicate execution. A
proposed in-memory predicate experiment containing read and redirect examples
was itself denied by the live PreToolUse hook before execution. It produced no
test verdict. The experiment was not rerouted through another executor.

Any repair must retain rejection of actual role writes, shell redirects,
compound commands and indirect execution. It must recognize only demonstrably
read-only commands and preserve quoting and path boundaries. A string-only
candidate suite is not proof that the installed host admits the original read.
The normal protected-change path and a fresh native read remain required.

No protected file, reviewer reservation, review verdict, task status or Git
history was changed by this investigation.
