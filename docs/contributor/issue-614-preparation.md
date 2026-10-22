# Issue 614: measurement foundation preparation

This branch prepares the specification for [#614](https://github.com/aharada54914/sdd-forge/issues/614).
It does not implement measurements or claim performance improvement.
`Spec-Review-Status` and `Impl-Review-Status` remain `Pending`;
`tasks-proposal.md` is a draft decomposition, not an approved `tasks.md`.

## Prepared scope

- One passive, versioned measurement sidecar using monotonic timing and existing
  execution owners; no new evaluator or workflow state authority.
- Separate wall time, machine effort, human active/wait time and unknown values.
- A pinned baseline fixture and independently selected code revision so the
  benchmark executes the candidate it names. Trial counts and resume attempts
  remain separate, including failed and censored trials.
- Legacy output and exit-code equivalence, with only explicitly validated
  existing volatile fields normalized for comparisons.
- Three proposed packets: schema/helper, opt-in integration, then real baseline
  and equivalence measurements. Downstream #615, #617 and #618 depend on actual
  measurements; this draft does not satisfy those dependencies.

Drafting and corrections used actual Claude CLI sessions. Separate-context
content checks found and corrected benchmark selection, volatile-field,
generated-fixture, retry/accounting and API-return inconsistencies. The final
bounded recheck found no material residual in those six items. These checks are
not formal stage reviews and do not authorize status transitions.

## Validation and remaining work

The placeholder scan and feature-scoped workflow-state check pass. During
preparation, the whole workflow check and registry/catalog/ADR-related checks
also passed. No implementation, baseline performance samples or native platform
measurement validation exists yet. Document-only corrections did not trigger
another whole-repository test run.

Formal spec/design/task reviews must precede implementation. The current managed
Claude route has two concrete prerequisites that were not established in this
session: registration of the actual invoking/author identities through a trusted
host route, and role-specific model adoption plus fresh availability input. The
worktree ledger's chain checks passed, but current invoking identities were not
registered. The existing Copilot session-start initializer only handles fresh
projects; it is not a migration command for this existing ledger. Do not rewrite
history, reuse an old actor identity, or call informal content checks formal
Passed evidence.

The shipped Claude policy entries are candidates with no adoption entries.
Existing implementation-model evidence cannot authorize spec/design/task
reviewer roles. Resolve these operational prerequisites with genuine provenance
and the existing adoption contract, then run the formal reviews, produce the
reviewed task plan and implement the selected tasks. Keep this Issue open until
its actual code and baseline acceptance are verified.
