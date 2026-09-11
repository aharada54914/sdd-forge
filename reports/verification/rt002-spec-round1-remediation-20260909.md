# RT-20260909-002 specification round-1 remediation

Date: 2026-09-09
State: specification round 2 PASS recorded; implementation and activation incomplete.

## Update after human collection and formal round 2

The human supplied the full snapshot commit
`e1f343b44706fc2eb3d09744feed0e034225a0fc` and individual document SHA-256
values. Collection's missing staged workflow was traced to intentional deletion
commit `c8ac93a27e2f8fc351100fb8fa76958781532797`, verified as an ancestor of
the snapshot. The workflow was not recreated, and collection was not falsely
reported as a whole-command success. The declaration in investigation.md binds
the human-collected hashes and this commit-bound absence.

The first next-round invocation used a malformed option and returned usage;
no review launched from that invocation. The corrected `--edit-summary=...`
invocation succeeded for attempt 2 round 2. Original identity reservations 972
and 973 preceded fresh read-only Astra reviews A and B. Both completed with PASS.
Both raw schemas, identities, distinct sessions, current input hashes,
precheck bindings, sanitized summary and verdict derivation were checked:
12 PASS, 2 domain-absence SKIP, zero FAIL. The canonical round-2 contract,
integrated verdict and report were recorded; only Spec-Review-Status changed
to Passed. No implementation, test, task Done, native activation, push or merge
success is inferred. Historical records below describe the earlier state.

Next: restore the approved RT-20260909-002 design amendment scope and frozen
design provenance, propagate the reviewed semantics through formal
implementation-policy and task provenance reviews, then perform the authorized
repair and required native exit checks. Unrelated implementation/integration
remains outside the temporary recovery admission until its exit is proven.

## Completed

- Recorded both independent Astra review outputs and the validated derived
  NEEDS_WORK result in spec attempt 2, round 1. The four failed checks describe
  two root defects: missing amendment authorization provenance and conflicting
  cleanup guarantees. Historical evidence was not rewritten.
- Added a dated governing cleanup-precedence section to requirements.md:
  existing AC-032's denied-write, confirmed-cleanup and unconfirmed-cleanup
  branches prevail over the enumerated unconditional sentinel summaries.
  Approval sidecar non-mutation remains unconditional. Existing cleanup-failure
  and stale-start tests remain mandatory; no runtime acceptance was weakened.
- Recorded the two verbatim human authorization messages, dated 2026-09-09,
  in investigation.md. This record is not itself a passing declaration.
- Created local commit e1f343b4 (short identity reported by git commit) containing
  exactly requirements.md, acceptance-tests.md and investigation.md for A1.
  Its subject is "docs(rt002): record pending recovery amendment and human authority".
  No push, merge, issue closure or status promotion was performed.
- git diff --cached --check passed before that commit. The index was checked
  and contained only these three paths before commit.

## Actual collection refusal

A Node read-only collection command used fs.readFileSync, SHA-256 and
child_process.execFileSync for git rev-parse/git show. The native PreToolUse
hook rejected the command before execution with the bilingual SDD deterministic
gate protection message. It returned no commit fingerprint or file hashes.
This is an actual command refusal, not proof that the intended reads modified
anything. Do not claim hash collection succeeded and do not reroute the denied
operation through another agent executor.

## Next action

A human must obtain the full commit ID, confirm the three spec files still
match that commit, and collect their and the referenced later-phase artifacts'
SHA-256 values using the read-only commands supplied in the conversation.
Then append a conforming Amendment Re-Review Context to investigation.md,
pinning the actual committed approval record and amended-document bytes.
Do not pretend an uncommitted revision was present in a historical commit.

Preserve the old investigation sections as historical observations. Bind the
later-phase design, tasks, traceability and layer artifacts, plus the referenced
staged inventory/workflow and decision documents. The identifier sweep found
older unconditional cleanup summaries in design.md and the infra/security
layers; carry their exact supersession forward in the scoped design provenance
review rather than silently editing frozen later-stage inputs now.

After the declaration is complete, run the original next-round precheck with
an edit summary, reserve fresh independent identities, and perform spec round 2.
Do not run implementation-policy/task reviews or apply the production candidate
before their required predecessor conditions. The recovery admission still
excludes unrelated implementation and integration until fresh native dispatch
and installed-path verification establish HOOK_ACTIVE.
