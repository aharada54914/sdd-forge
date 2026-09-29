# T-001 implementation handoff

Implement only approved T-001 in the immutable task snapshot. Read all listed
specifications, the repository instructions and implementation policies before
editing. Do not use conversation history or read unrelated working-tree files.
The native thread is assigned this task only; it must never implement another task.

Use Node built-ins and the smallest contract/privacy/path implementation matching
the approved design. No new dependency, workflow command, installer, journal,
scheduler, capture of real conversation, or permission change. Do not edit frozen
specifications, tasks.md, Git state, hook configuration or existing protected files.
All commands use rtk proxy, login=false; use apply_patch for source edits. Respect
every actual hook/sandbox refusal and stop that operation without another route.
Only declared output directories are writable; network and general temp writes
are disabled. Put synthetic test scratch under the declared verification directory,
and remove only your exact owned scratch after testing; never touch real logs.

First persist the high-risk WFI-001 preflight in the implementation report: every
persisted field, its governing contract/traceability counterpart, and the concrete
failing mismatch test. Then add the smallest meaningful failing TDD slice, run
it, save its actual Red output, and publish verification/T-001/red-ready.json with
the test path, command, exit code, and report/evidence paths. Production code must
remain absent until the orchestrator commits that failing test and publishes
verification/T-001/red-commit.json. Check for that marker using waits no longer
than 30 seconds, for at most 5 minutes; otherwise return RED_READY. This deliberate
test-first checkpoint is not implementation completion. Do not run git yourself.

Once the real Red commit is present, record it and implement T-001. Expand the
task-required synthetic branches, run checks, and save observed results. Required
native Windows/Ubuntu filesystem/ACL evidence remains pending on this macOS host;
never substitute fixtures for native proof or declare Implementation Complete
while corresponding completion conditions are unmet. Do not invent missing
requirements or weaken limits. Stop after at most three correction loops and
record the precise blocker. Do not declare a reviewer verdict or Done.

Persist the bundled implementation-report/v2 shape with bare Run ID and Task
Attempt Count lines as well as the required isolation fields, output hashes,
spec_revision and environment. Describe only tests actually run and unresolved
native conditions. Return paths and status only; the orchestrator owns final
self-review, shared task state, commits, CI, and independent review dispatch.
