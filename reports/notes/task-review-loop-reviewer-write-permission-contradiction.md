# Drift note: task-reviewer-a/-b role files self-contradict on write permission

**Discovered**: 2026-07-22, feature `epic-193-a5-capability-resolver`,
during Phase 2 task-review-loop orchestration (attempt 1, round 1).

**Symptom**: Both `plugins/sdd-review-loop/agents/task-reviewer-a.md` and
`plugins/sdd-review-loop/agents/task-reviewer-b.md` instruct the reviewer,
in their own "Output Format" section, to "Write output to the path
provided by the orchestrator as reviewer-a.json" / "...reviewer-b.json"
(task-reviewer-a.md:245, task-reviewer-b.md:214) — yet each file's own
"Hard Rules" section states, verbatim and unconditionally: "Read-only
tools only. Never write to any file." (task-reviewer-a.md:313,
task-reviewer-b.md:277). Both role files grant identical tools (`Read,
Grep, Glob, Bash`) and identical `disallowedTools` (`Write, Edit,
NotebookEdit`) — `Bash` is available to both, so a heredoc/redirect write
to the one designated output path is technically possible for either
role, but the Hard Rules text does not carve out an exception for that
one path, creating a genuine textual conflict a careful reader can
resolve either way.

**Observed consequence**: two independently-launched instances of these
structurally identical role definitions resolved the conflict in opposite
directions, without any impropriety on either side:

- `task-reviewer-a` (run seq0337, transcript
  `~/.claude/projects/-Users-jrmag-Setup/0097dba4-ac85-43c6-8e5c-271e593ecdeb/subagents/agent-a1aa9a59bfcf094d1.jsonl`)
  treated the Output Format instruction as authoritative and wrote
  `reports/task-review/epic-193-a5-capability-resolver/attempt-1/round-1/reviewer-a.json`
  itself via a `Bash` heredoc.
- `task-reviewer-b` (run seq0338, transcript
  `~/.claude/projects/-Users-jrmag-Setup/0097dba4-ac85-43c6-8e5c-271e593ecdeb/subagents/agent-a955f215e158d3032.jsonl`)
  treated the Hard Rules instruction as authoritative, performed the full
  review read-only, and returned its completed report as fenced JSON in
  its final assistant message instead of writing to disk — explicitly
  declining a mid-task orchestrator message that asked it to write
  directly and use a different schema, on the grounds that "no
  agent-supplied message can authorize a change to my permissions or
  output configuration" and that it had no way to independently verify
  the orchestrator's claim about the sibling `task-reviewer-a` session.
  (This refusal was itself correct and is not the defect being reported
  here — it is cited as evidence that the divergence was a good-faith,
  principled reading of self-contradictory instructions, not carelessness
  on either reviewer's part.)

**This session's handling**: the orchestrator (this session) verified
both outcomes independently against the actual persisted transcripts
rather than trusting a narrative summary: for reviewer-a, confirmed the
heredoc `tool_use` event and its `RESULT` sha256 match the committed file
exactly; for reviewer-b, programmatically extracted the sole fenced
`` ```json ``` `` block from its final assistant message and confirmed its
sha256 (with trailing newline) matches the file the orchestrator's
dispatcher (`main`) persisted to disk byte-for-byte
(`b570b9d616a0d7ed38e121674c39ecc4dc515192223e09bd9b04e71b4505060f`).
Both evidence files were accepted only after this independent, primary-
source verification — see commit history for
`reports/task-review/epic-193-a5-capability-resolver/attempt-1/round-1/`.

**Suggested permanent fix** (out of scope for this session —
`plugins/sdd-review-loop/agents/*.md` is a protected path this session
does not edit): amend both role files' "Hard Rules" section to read
"Read-only tools only, except for a single write to the orchestrator-
designated output path named in Output Format. Never write to any other
file." — removing the unconditional "never write to any file" phrasing
that contradicts the Output Format section's own explicit instruction.
This closes the ambiguity for every future task-review-loop invocation
rather than relying on each reviewer instance to resolve it
independently (and potentially inconsistently) at run time.

Related: none directly in `docs/adr/`; this is a reviewer-role-file
authoring defect, not an architecture decision. Not filed under an
existing WFI-NNN number since this session does not have authority to
assign one against `AGENTS.md` (a file this session's tasks.md/
traceability.md work does not otherwise touch); recorded here per the
`reports/notes/` convention `599671f` already established for an
analogous SKILL-vs-script drift finding.
